// Engine_AmenBreak1

// Inherit methods from CroneEngine
Engine_AmenBreak1 : CroneEngine {

    // AmenBreak1 specific v0.1.0
    var buses;
    var syns;
    var mods;
    var im;
    var bufs; 
    var oscs;
    var bufsDelay;
    // AmenBreak1 ^

    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }

    synthWatch {
        arg id,syn;
        id=id.asString;
        if (mods[id].isNil,{
            mods[id]=Array.newClear(10);
            im[id]=1.neg;
        });
        im[id]=(im[id]+1)%10;
        mods[id][im[id]]=syn;
    }

    synthChange {
        arg id,k,v;
        id=id.asString;
        if (mods[id].notNil,{
            10.do({ arg i;
                if (mods[id][i].notNil,{
                    if (mods[id][i].isRunning,{
                        ["synthChange",id,k,v,i].postln;
                        mods[id][i].set(k.asString,v);
                    });                    
                });
            });
        });
    }

    alloc {
        // AmenBreak1 specific v0.0.1
        var s=context.server;
        var n, mu, unit, expandCurve, compressCurve;

        var mips=0.0;
        var piped = Pipe.new("lscpu | grep BogoMIPS | awk '{print $2}'", "r"); 
        var oversample=1;
        var oversampleDist=1;
        mips = piped.getLine.asFloat;
        piped.close;
        ["BogoMIPS: ",mips].postln;
        if (mips>200,{
            oversample=3;
            oversampleDist=2;
        });


        n = 512*2;
        mu = 255*2;
        unit = Array.fill(n, {|i| i.linlin(0, n-1, -1, 1) });
        compressCurve = unit.collect({ |x|
            x.sign * log(1 + mu * x.abs) / log(1 + mu);
        });
        expandCurve = unit.collect({ |y|
            y.sign / mu * ((1+mu)**(y.abs) - 1);
        });
        context.server.sync;

        buses = Dictionary.new();
        syns = Dictionary.new();
        bufs = Dictionary.new();
        oscs = Dictionary.new();
        mods = Dictionary.new();
        im = Dictionary.new();
        bufsDelay = Buffer.allocConsecutive(2,context.server,48000*4,1);
        bufs.put("tape",Buffer.alloc(context.server, context.server.sampleRate * 18.0, 2));
        bufs.put("sine",Buffer.alloc(context.server,512,1));
        bufs.at("sine").sine2([2],[0.5],false); // https://ableton-production.imgix.net/manual/en/Saturator.png?auto=compress%2Cformat&w=716
        bufs.put("compress",Buffer.loadCollection(context.server,Signal.newFrom(compressCurve).asWavetableNoWrap));
        bufs.put("expand",Buffer.loadCollection(context.server,Signal.newFrom(expandCurve).asWavetableNoWrap));
        context.server.sync;


        oscs.put("position",OSCFunc({ |msg| NetAddr("127.0.0.1", 10111).sendMsg("progress",msg[3],msg[3]); }, '/position'));
        oscs.put("lfos",OSCFunc({ |msg| NetAddr("127.0.0.1", 10111).sendMsg("lfos",msg[3],msg[4]); }, '/lfos'));
        
        SynthDef("rise",{|out,duration=1,min=0.1,max=1|
            Out.kr(out,EnvGen.kr(Env.new([min,max],[duration],\exponential),doneAction:2));
        }).send(context.server);        
        SynthDef("set",{|out,val,slew=2|
            Out.kr(out,VarLag.kr(val,slew,warp:\exponential));
        }).send(context.server);        
        SynthDef("tremolo",{|out,min=0.1,max=1,rate=0.5,duration=1|
            FreeSelf.kr(TDelay.kr(Impulse.kr(0), duration));
            Out.kr(out,Pulse.kr(rate).range(min,max));
        }).send(context.server);

        SynthDef("kick", { |basefreq = 40, ratio = 6, sweeptime = 0.05, preamp = 1, amp = 1,
            decay1 = 0.3, decay1L = 0.8, decay2 = 0.15, clicky=0.0, out|
            var snd;
            var    fcurve = EnvGen.kr(Env([basefreq * ratio, basefreq], [sweeptime], \exp)),
            env = EnvGen.kr(Env([clicky,1, decay1L, 0], [0.0,decay1, decay2], -4), doneAction: Done.freeSelf),
            sig = SinOsc.ar(fcurve, 0.5pi, preamp).distort * env ;
            snd = (sig*amp).tanh!2;
            Out.ar(\out.kr(0),\compressible.kr(0)*snd);
            Out.ar(\outsc.kr(0),\compressing.kr(0)*snd);
            Out.ar(\outnsc.kr(0),(1-\compressible.kr(0))*snd);
            Out.ar(\outdelay.kr(0),\senddelay.kr(0)*snd);
        }).send(context.server);

        (1..2).do({arg ch;
        SynthDef("loop"++ch,{ 
            arg buf,amp=1,startPos=0,gate=1;
            var env = EnvGen.ar(Env.asr(0.5,1,0.5),gate,doneAction:2);
            var snd = PlayBuf.ar(numChannels:ch, bufnum: buf, rate: BufRateScale.ir(buf), startPos: startPos*BufFrames.ir(buf), loop: 1, doneAction: 0);
            snd = snd * env * Lag.kr(amp);
            Out.ar(\out.kr(0),\compressible.kr(0)*snd);
            Out.ar(\outsc.kr(0),\compressing.kr(0)*snd);
            Out.ar(\outnsc.kr(0),(1-\compressible.kr(0))*snd);
            Out.ar(\outdelay.kr(0),\senddelay.kr(0)*snd);            
        }).send(context.server);
        });

        SynthDef("reese", { |note=32,amp=1.0,gate=1|
            var snd;
            var env = EnvGen.ar(Env.asr(0.1,1,3),gate:gate,doneAction:2);
        	var detune=VarLag.kr(LFNoise0.kr(1/2),2,warp:\sine).range(0,2);
            var distLFO=VarLag.kr(LFNoise0.kr(1/2),2,warp:\sine).range(0.1,4);
            snd = SinOsc.ar((note+12).midicps+detune);
            snd = snd + SinOsc.ar((note+12).midicps-detune);	
        	snd = Splay.ar(snd);
	        snd = RHPF.ar(snd,(note+12).midicps,0.7);
	        snd = snd + SinOsc.ar((note).midicps!2);
	        snd = (snd*distLFO).softclip;
            Out.ar(\out.kr(0),\compressible.kr(0)*snd);
            Out.ar(\outsc.kr(0),\compressing.kr(0)*snd);
            Out.ar(\outnsc.kr(0),(1-\compressible.kr(0))*snd);
        }).send(context.server);
        
        SynthDef("lfos", {
            5.do({ arg i;
                var period=Rand(1*(i+1),2*(i+1)*(i+1));
                var lfo=VarLag.kr(LFNoise0.kr(1/period),period,0,\sine).range(0,1);
                SendReply.kr(Impulse.kr(4),'/lfos',[i,lfo]);
            });
        }).send(context.server);

        SynthDef("defAudioIn",{
            arg ch=0,lpf=20000,lpfqr=0.707,hpf=20,hpfqr=0.909,pan=0,amp=1.0;
            var snd;
            snd=SoundIn.ar([0,1])*amp;
            // snd=RHPF.ar(snd,hpf,hpfqr);
            // snd=RLPF.ar(snd,lpf,lpfqr);
            Out.ar(\out.kr(0),\compressible.kr(0)*snd);
            Out.ar(\outsc.kr(0),\compressing.kr(0)*snd);
            Out.ar(\outnsc.kr(0),(1-\compressible.kr(0))*snd);
            Out.ar(\outdelay.kr(0),\senddelay.kr(0)*snd);
        }).add;

        SynthDef(\main, {
            arg outBus=0,inBusNSC,inSC,inDelay,lpshelf=60,lpgain=0,sidechain_mult=2,compress_thresh=0.1,compress_level=0.1,compress_attack=0.01,compress_release=1,inBus,
            tape_buf,tape_slow=0,tape_stretch=0,delay_bufs=#[0,1],delay_time=0.25,delay_feedback=0.5,tape_gate=0,
            tape_wet=0.9,tape_bias=0.9,saturation=0.9,tape_drive=0.7,
			tape_oversample=2,mode=0,sine_drive=0,sine_buf=0,noise_gate_db=60.neg,noise_gate_attack=0.01,noise_gate_release=0.05,
            compress_curve_wet=0,compress_curve_drive=1,bufCompress,
            expand_curve_wet=0,expand_curve_drive=1,bufExpand,
			dist_wet=0.05,dist_on=0,drivegain=0.5,dist_bias=0,lowgain=0.1,highgain=0.1,
			shelvingfreq=600,dist_oversample=2;
            var snd,sndSC,sndNSC,sndDelay,tapePosRec,tapePosStretch,local,tape_slow2,snd_db,snd_db_max;
            snd=In.ar(inBus,2);
            sndNSC=In.ar(inBusNSC,2);
            sndSC=In.ar(inSC,2);
            sndDelay=In.ar(inDelay,2)*0.4;

            snd = Compander.ar(snd, (sndSC*sidechain_mult), 
                compress_thresh, 1, compress_level, 
                compress_attack, compress_release);
            snd = snd + sndNSC;

            // tape delay
            local = LocalIn.ar(2);
            local = OnePole.ar(local,0.4);
            local = OnePole.ar(local, -0.08);
            local = Rotate2.ar(local[0],local[1],0.2);
            local = BufDelayL.ar(delay_bufs,local,Lag.kr(delay_time),mul:EnvGen.ar(Env.new([1,0.1,0.1,1],[0.01,0.01,0.01]),Trig.kr(Changed.kr(delay_time))));
            local = LeakDC.ar(local);
            LocalOut.ar((local + (sndDelay))*Clip.kr((36.neg.dbamp.log/(delay_feedback/delay_time+1)).exp,0,0.99999));
            snd = snd + local;

            snd = LeakDC.ar(snd);

            snd=BLowShelf.ar(snd, lpshelf, 1, lpgain);

            // noise gate
            snd_db=Amplitude.ar(snd).ampdb;
            snd_db_max=RunningMax.kr(snd_db,Impulse.kr(1));
            snd = snd * EnvGen.ar(Env.asr(noise_gate_attack,1,noise_gate_release),snd_db>(snd_db_max+noise_gate_db));

            // // tape
            tapePosRec=Phasor.ar(end:BufFrames.ir(tape_buf));
            BufWr.ar(snd,tape_buf,tapePosRec);
            // tape slow
            tape_slow2=EnvGen.kr(Env.new([1,0.047,1],[LFNoise0.kr(1).range(0.75,1.5),LFNoise0.kr(1).range(0.25,0.75)],\exponential,releaseNode:1),tape_gate);
            snd = SelectX.ar(VarLag.kr((tape_slow>0)+(tape_slow2<1),0.05,warp:\sine),[snd,PlayBuf.ar(2,tape_buf,tape_slow2*Lag.kr(1/(tape_slow+1),1),startPos:tapePosRec-10,loop:1,trigger:Trig.kr((tape_slow+tape_gate)>0))]);
            snd = snd*Lag.kr(tape_slow2>0.04701);

            // sinoid drive
            snd=SelectX.ar(Lag.kr(sine_drive),[snd,Shaper.ar(sine_buf,snd)]);

            // compress curve
            snd=SelectX.ar(Lag.kr(compress_curve_wet),[snd,Shaper.ar(bufCompress,snd*compress_curve_drive)]);

            // expand cruve
            snd=SelectX.ar(Lag.kr(expand_curve_wet),[snd,Shaper.ar(bufExpand,snd*expand_curve_drive)]);

            // tape in the tape
			snd=SelectX.ar(Lag.kr(tape_wet,1),[snd,AnalogTape.ar(snd,tape_bias,saturation,tape_drive,oversample,mode)]);
			
			snd=SelectX.ar(Lag.kr(dist_on*dist_wet/5,1),[snd,AnalogVintageDistortion.ar(snd,drivegain,dist_bias,lowgain,highgain,shelvingfreq,oversampleDist)]);			
		

            // reduce stereo spread in the bass
            snd = BHiPass.ar(snd,200)+Pan2.ar(BLowPass.ar(snd[0]+snd[1],200));
            
            snd = (snd*2).tanh/2; // limit

            Out.ar(outBus,snd*EnvGen.ar(Env.new([0,1],[1])));
        }).send(context.server);


        (1..2).do({arg ch;
        SynthDef("slice"++ch,{
            arg amp=0, buf1,buf2,buf3,buf4,buf5, rate=1, pos=0, drive=1,stretch=0, compression=0, gate=1, duration=100000, pan=0, send_pos=0, lpfIn,res=0.707, attack=0.01,release=0.01; 
            var snd,sndD,snd1,snd2,snd3,snd4,snd5;
            var startFrame = pos / BufDur.ir(buf1) * BufFrames.ir(buf1);
            var snd_pos = Phasor.ar(
                trig: Impulse.kr(0),
                rate: rate * BufRateScale.ir(buf1),
                end: BufFrames.ir(buf1),
            );
            SendReply.kr(Impulse.kr(15)*send_pos,'/position',[(startFrame+snd_pos) / BufFrames.ir(buf1) * BufDur.ir(buf1)]);
            snd1 = BufRd.ar(ch,buf1,(startFrame+snd_pos).mod(BufFrames.ir(buf1)),interpolation:4);
            snd2 = BufRd.ar(ch,buf2,(startFrame*2+snd_pos).mod(BufFrames.ir(buf2)),interpolation:1);
            snd=SelectX.ar(Lag.kr(Select.kr(stretch*1.999,[0,1]),0.2),[snd1,snd2],0);
            
            snd = snd * Env.asr(attack, 1, release).ar(Done.freeSelf, gate * ToggleFF.kr(1-TDelay.kr(DC.kr(1),duration)) );
            snd=Pan2.ar(snd,0.0);
            snd=Pan2.ar(snd[0],1.neg+(2*pan))+Pan2.ar(snd[1],1+(2*pan));
            snd=Balance2.ar(snd[0],snd[1],pan);

            // fx
            snd = SelectX.ar(\decimate.kr(0).lag(0.01), [snd, Latch.ar(snd, Impulse.ar(LFNoise2.kr(0.3).exprange(1000,16e3)))]);

            // drive
            sndD = (snd * 30.dbamp).tanh * -10.dbamp;
            sndD = BHiShelf.ar(BLowShelf.ar(sndD, 500, 1, -10), 3000, 1, -10);
            sndD = (sndD * 10.dbamp).tanh * -10.dbamp;
            sndD = BHiShelf.ar(BLowShelf.ar(sndD, 500, 1, 10), 3000, 1, 10);
            sndD = sndD * -10.dbamp;

            snd = SelectX.ar(drive,[snd,sndD]);

            snd = Compander.ar(snd,snd,compression,0.5,clampTime:0.01,relaxTime:0.01);

            snd = RLPF.ar(snd,In.kr(lpfIn,1),res);

            Out.ar(\out.kr(0),\compressible.kr(0)*snd*amp);
            Out.ar(\outsc.kr(0),\compressing.kr(0)*snd);
            Out.ar(\outnsc.kr(0),(1-\compressible.kr(0))*snd*amp);
            Out.ar(\outdelay.kr(0),\senddelay.kr(0)*snd);
        }).send(context.server);
        });

        context.server.sync;
        buses.put("filter",Bus.control(s,1));
        buses.put("busCompressible",Bus.audio(s,2));
        buses.put("busNotCompressible",Bus.audio(s,2));
        buses.put("busCompressing",Bus.audio(s,2));
        buses.put("busDelay",Bus.audio(s,2));

        10.do({ arg i;
            buses.put("bus"++i,Bus.audio(s,2));
        });
        context.server.sync;
        syns.put("main",Synth.new(\main,[\bufExpand,bufs.at("expand"),\bufCompress,bufs.at("compress"),\sine_buf,bufs.at("sine"),\tape_buf,bufs.at("tape"),\outBus,0,\sidechain_mult,8,\inBus,buses.at("busCompressible"),\inBusNSC,buses.at("busNotCompressible"),\inSC,buses.at("busCompressing"),\delay_bufs,bufsDelay,\inDelay,buses.at("busDelay")]));
        syns.put("lfos",Synth.new("lfos"));

        syns.put("audioIn",Synth.new("defAudioIn",[
            out: buses.at("busCompressible"),
            outsc: buses.at("busCompressing"),
            outnsc: buses.at("busNotCompressible"),
            outdelay: buses.at("busDelay"),
            compressible: 0,
            compressing: 0,
        ], syns.at("main"), \addBefore));
        NodeWatcher.register(syns.at("audioIn"));
        NodeWatcher.register(syns.at("main"));
        syns.put("filter",Synth.new("set",[\out,buses.at("filter"),\val,18000],s,\addToHead));
        NodeWatcher.register(syns.at("filter"));
        context.server.sync;

        this.addCommand("audionin_set","sf",{ arg msg;
            var key=msg[1];
            var val=msg[2];
            ["audioIn",key,val].postln;
            syns.at("audioIn").set(key,val);
        });

        this.addCommand("synth_set","ssf",{ arg msg;
            var id=msg[1];
            var k=msg[2];
            var v=msg[3];
            this.synthChange(id,k,v);
        });

        this.addCommand("filter_set","ff", { arg msg;
            var val=msg[1];
            var slew=msg[2];
            if (syns.at("filter").isRunning,{
                syns.at("filter").set(\val,val,\slew,slew);
            });
        });

        this.addCommand("slice_on","ssffffffffffffffffffffffff",{ arg msg;
            var id=msg[1];
            var filename=msg[2];
            var db=msg[3];
            var db_add=msg[4];
            var pan=msg[5];
            var rate=msg[6];
            var pitch=msg[7];
            var pos=msg[8];
            var duration_slice=msg[9];
            var duration_total=msg[10];
            var retrig=msg[11];
            var gate=msg[12];
            var lpf=msg[13];
            var decimate=msg[14];
            var compressible=msg[15];
            var compressing=msg[16];
            var send_reverb=msg[17];
            var drive=msg[18];
            var compression=msg[19];
            var send_pos=msg[20];
            var attack=msg[21];
            var release=msg[22];
            var stretch=msg[23];
            var sendTape=msg[24];
            var sendDelay=msg[25];
            var res=msg[26];
            var db_first=db+db_add;
            var db_orig=db_first;
            if (retrig>0,{
                db_first=db;
                if (db_add>0,{
                    db_first=db-(db_add*retrig);
                    db=db_first;
                });
                if (db<36.neg,{
                    db=36.neg;
                });
                if (retrig>3,{
                    if (100.rand<25,{
                        // create filter sweep
                        Routine {
                            syns.at("filter").set(\slew,0.1);
                            syns.at("filter").set(\val,200);
                            0.1.wait;
                            syns.at("filter").set(\slew,duration_total,\val,lpf);
                        }.play;
                    });
                });
            });
            // ["duration_slice",duration_slice,"duration_total",duration_total,"retrig",retrig].postln;
            if (bufs.at(filename).notNil,{
                if (syns.at(id).notNil,{
                    if (syns.at(id).isRunning,{
                        syns.at(id).set(\gate,0);
                    });
                });
                syns.put(id,Synth.new("slice"++bufs.at(filename).numChannels, [
                    out: buses.at("busCompressible"),
                    outsc: buses.at("busCompressing"),
                    outnsc: buses.at("busNotCompressible"),
                    outdelay: buses.at("busDelay"),
                    compressible: compressible,
                    compressing: compressing,
                    sendreverb: send_reverb,
                    buf1: bufs.at(filename),
                    buf2: bufs.at("slow"),
                    attack: attack,
                    release: release,
                    amp: db_first.dbamp,
                    pan: pan,
                    lpfIn: buses.at("filter"),
                    res: res,
                    rate: rate*pitch.midiratio,
                    pos: pos,
                    duration: (duration_slice * gate / (retrig + 1)),
                    decimate: decimate,
                    drive: drive,
                    compression: compression,
                    stretch: stretch,
                    send_pos: send_pos,
                    sendtape: sendTape,
                    senddelay: sendDelay,
                    outtrack: buses.at("bus"++id.asString.split($_)[0].asString),
                ], syns.at("main"), \addBefore));
                if (retrig>0,{
                    Routine {
                        (retrig).do{ arg i;
                            var db_next=db+(db_add*(i+1));
                            if (db_next>db_orig,{
                                db_next=db_orig;
                            });
                            (duration_total/ (retrig+1) ).wait;
                            syns.put(id,Synth.new("slice"++bufs.at(filename).numChannels, [
                                out: buses.at("busCompressible"),
                                outsc: buses.at("busCompressing"),
                                outnsc: buses.at("busNotCompressible"),
                                outdelay: buses.at("busDelay"),
                                sendreverb: send_reverb,
                                compressible: compressible,
                                compressing: compressing,
                                buf1: bufs.at(filename),
                                buf2: bufs.at("slow"),
                                pan: pan,
                                attack: attack,
                                release: release,
                                amp: db_next.dbamp,
                                stretch: stretch,
                                rate: rate*((pitch.sign)*(i+1)+pitch).midiratio,
                                duration: duration_slice * gate / (retrig + 1),
                                lpfIn: buses.at("filter"),
                                res: res,
                                pos: pos,
                                decimate: decimate,
                                drive: drive,
                                compression: compression,
                                send_pos: send_pos,
                                sendtape: sendTape,
                                senddelay: sendDelay,
                                outtrack: buses.at("bus"++id.asString.split($_)[0].asString),
                            ], syns.at("main"), \addBefore));
                        };
                        NodeWatcher.register(syns.at(id));
                        this.synthWatch(id.asString.split($_)[0].asString,syns.at(id));
                    }.play;
                 },{ 
                    NodeWatcher.register(syns.at(id));
                    this.synthWatch(id.asString.split($_)[0].asString,syns.at(id));
                });
            });
        });

        this.addCommand("load_buffer","s",{ arg msg;
            var id=msg[1];
            // ["loading"+id].postln;
            if (bufs.at(id).isNil,{
                Buffer.read(context.server, id, action: {arg buf;
                    // ["[amenbreak] loaded"+id].postln;
                    bufs.put(id,buf);
                });
            });
        });

        this.addCommand("load_slow","s",{ arg msg;
            var id=msg[1];
            // ["loading"+id].postln;
            if (bufs.at("slow").isNil,{
                Buffer.read(context.server, id, action: {arg buf;
                    // ["[amenbreak] loaded slow"+id].postln;
                    bufs.put("slow",buf);
                });
            });
        });

        this.addCommand("kick","ffffffffffffff",{arg msg;
            var basefreq=msg[1];
            var ratio=msg[2];
            var sweeptime=msg[3];
            var preamp=msg[4];
            var amp=msg[5].dbamp;
            var decay1=msg[6];
            var decay1L=msg[7];
            var decay2=msg[8];
            var clicky=msg[9];
            var compressing=msg[10];
            var compressible=msg[11];
            var send_reverb=msg[12];
            var sendTape=msg[13];
            var sendDelay=msg[14];
            Synth.new("kick",[
                basefreq: basefreq,
                ratio: ratio,
                sweeptime: sweeptime,
                preamp: preamp,
                amp: amp,
                decay1: decay1,
                decay1L: decay1L,
                decay2: decay2,
                clicky: clicky,
                out: buses.at("busCompressible"),
                outsc: buses.at("busCompressing"),
                outnsc: buses.at("busNotCompressible"),
                outdelay: buses.at("busDelay"),
                compressible: compressible,
                compressing: compressing,
                sendreverb: send_reverb,
                sendtape: sendTape,
                senddelay: sendDelay,
            ],syns.at("main"),\addBefore).onFree({"freed!"});
        });

        this.addCommand("reese_on","ff",{ arg msg;
            var note=msg[1];
            var amp=msg[2].dbamp;
            var synExists=false;
            if (syns.at("reese").notNil,{
                if (syns.at("reese").isRunning,{
                    synExists=true;
                });
            });
            if (synExists,{
                syns.at("reese").set(\note,note);
            },{
                syns.put("reese",Synth.new("reese", [
                    out: buses.at("busCompressible"),
                    outsc: buses.at("busCompressing"),
                    outnsc: buses.at("busNotCompressible"),
                    compressible: 1,
                    compressing: 0,
                    amp: amp,
                ], syns.at("main"), \addBefore));
                NodeWatcher.register(syns.at("reese"));
            });
        });

        this.addCommand("reese_off","",{ arg msg;
            if (syns.at("reese").notNil,{
                if (syns.at("reese").isRunning,{
                    syns.at("reese").set(\gate,0);
                });
            });
        });

        this.addCommand("main_set","sf",{ arg msg;
            var k=msg[1];
            var v=msg[2];
            if (syns.at("main").notNil,{
                if (syns.at("main").isRunning,{
                    ["Main: setting",k,v].postln;
                    syns.at("main").set(k.asString,v);
                });
            });
        });

        this.addCommand("loop","sfff",{ arg msg;
            var filename=msg[1];
            var amp=msg[2].dbamp;
            var startPos=msg[3];
            if (syns.at(filename).notNil,{
                if (syns.at(filename).isRunning,{
                    syns.at(filename).set(\gate,0);
                });
            });
            if (bufs.at(filename).notNil,{
                syns.put(filename,Synth.new("loop"++bufs.at(filename).numChannels, [
                    out: buses.at("busCompressible"),
                    outsc: buses.at("busCompressing"),
                    outnsc: buses.at("busNotCompressible"),
                    compressible: 1,
                    compressing: 0,
                    amp: amp,
                    startPos: startPos,
                    buf: bufs.at(filename)
                ], syns.at("main"), \addBefore));
                NodeWatcher.register(syns.at(filename));
            });
        });

        this.addCommand("loop_set","ssf",{ arg msg;
	    var filename=msg[1];
            if (syns.at(filename).notNil,{
                if (syns.at(filename).isRunning,{
                    syns.at(filename).set(msg[2],msg[3]);
                });
            });
        });

        this.addCommand("loop_stop","s",{ arg msg;
	    var filename=msg[1];
            if (syns.at(filename).notNil,{
                if (syns.at(filename).isRunning,{
                    syns.at(filename).set(\gate,0);
                });
            });
        });

    }

    free {
        // AmenBreak1 Specific v0.0.1
        bufs.keysValuesDo({ arg buf, val;
            val.free;
        });
        syns.keysValuesDo({ arg buf, val;
            val.free;
        });
        buses.keysValuesDo({ arg buf, val;
            val.free;
        });
        bufsDelay.do(_.free);
        // ^ AmenBreak1 specific
    }
}
