-- amenbreak v1.0.0
--
--
-- amen+break
--
--
--
--    ▼ instructions below ▼
--
-- E1 changes sample
-- E2 amens
-- E3 breaks
-- K3 stops/starts
-- K1+K2 toggles edit mode
-- in edit mode:
-- E1 changes kick
-- E2 zooms
-- E3 jogs slice
-- K2 select slice
-- K3 auditions slice

if not string.find(package.cpath,"/home/we/dust/code/amenbreak/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/amenbreak/lib/?.so"
end
musicutil=require("musicutil")
json=require("cjson")
sample_=include("lib/sample")
s=require("sequins")

engine.name="AmenBreak1"

param_switch=true
performance=true
debounce_fn={}
osc_fun={}
screen_fade_in=15
k1_on=false
posit={
  beg=1,
  inc={1},
dur={1}}

function init()
  debounce_fn["startup"]={30,function()end}
  os.execute(_path.code.."amenbreak/lib/oscnotify/run.sh &")

  if not util.file_exists(_path.data.."amenbreak/dats/") then
    os.execute("mkdir -p ".._path.data.."amenbreak/dats/")
    os.execute("mkdir -p ".._path.data.."amenbreak/cursors/")
    os.execute("mkdir -p ".._path.data.."amenbreak/pngs/")
    -- run installer
    os.execute(_path.code.."amenbreak/lib/install.sh")
  end

  -- find all the amen files
  amen_files={}
  for _,fname in ipairs(util.scandir(_path.audio.."amenbreak")) do
    if not string.find(fname,"slow") then
      if util.file_exists(_path.audio.."amenbreak/"..fname..".slow.flac") then
        print(fname)
        table.insert(amen_files,fname)
        -- if #amen_files==4 then
        --   break
        -- end
      end
    end
  end
  print(string.format("[amenbreak] found %s files",#amen_files))

  -- choose audiowaveform binary
  audiowaveform="audiowaveform"
  local foo=util.os_capture(audiowaveform.." --help")
  if not string.find(foo,"Options") then
    audiowaveform="/home/we/dust/code/amenbreak/lib/audiowaveform"
  end

  -- add major parameters
  params_sidechain()
  params_kick()

  local params_menu={
    {id="db",name="volume",min=-48,max=12,exp=false,div=0.1,default=-6,unit="db"},
    {id="punch",name="punch",min=0,max=1,exp=false,div=0.01,default=0,unit="punches"},
    {id="amen",name="amen",min=0,max=1,exp=false,div=0.01,default=0,unit="amens"},
    {id="break",name="break",min=0,max=1,exp=false,div=0.01,default=0,unit="break"},
    {id="track",name="track",min=1,max=#amen_files,exp=false,div=1,default=1},
  }
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
  end
  params:set_action("track",function(x)
    for i=1,#amen_files do
      ws[i]:select(x==i)
    end
  end)
  params:set_action("punch",function(x)
    for i=1,#amen_files do
      params:set_raw(i.."drive",easing_function(x,0.1,2))
      params:set_raw(i.."compression",easing_function(x,5.4,4))
      params:set_raw(i.."decimate",easing_function(x,8.8,12))
      params:set_raw(i.."filter",easing_function(x,-5.5,10)+0.65)
    end
  end)

  -- setup ws
  ws={}
  for i=1,#amen_files do
    table.insert(ws,sample_:new{id=i})
  end

  -- bang params
  params:bang()

  -- setup osc
  osc_fun={
    progressbar=function(args)
      show_message(args[1])
      show_progress(tonumber(args[2]))
    end,
    progress=function(args)
      ws[params:get("track")]:set_position(tonumber(args[1]))
    end,
    oscnotify=function(args)
      print("file edited ok!")
      rerun()
    end,
    aubiodone=function(args)
      local id=tonumber(args[1])
      local data_s=args[2]
      ws[params:get("track")]:got_onsets(data_s)
    end,
  }
  osc.event=function(path,args,from)
    if string.sub(path,1,1)=="/" then
      path=string.sub(path,2)
    end
    if osc_fun[path]~=nil then osc_fun[path](args) else
      -- print("osc.event: '"..path.."' ?")
    end
  end

  -- start redrawing clock
  clock.run(function()
    while true do
      debounce_params()
      clock.sleep(1/15)
      redraw()
    end
  end)

  -- startup
  -- for i,fname in ipairs({"lyncollins_beats16_bpm114","winstons1_beats16_bpm138","bamboo1_beats16_bpm145","bamboo2_beats16_bpm145"}) do
  -- for i,v in ipairs({"Crot_Break_bpm165","lyncollins_beats16_bpm114","amen5_beats4_bpm160"}) do
  --   params:set(i.."sample_file",_path.code.."amenbreak/lib/flacs/"..v..".flac")
  -- end
  for i,v in ipairs(amen_files) do
    params:set(i.."sample_file",_path.audio.."amenbreak/"..v)
  end

  -- debug
  clock.run(function()
    clock.sleep(1)
    --   params:set("amen",0)
    params:set("break",0.6)
    --   params:set("punch",0.5)
    -- params:set("track",3)
    toggle_clock(true)
  end)
end

-- https://www.desmos.com/calculator/oimuzwwcop
function easing_function(x,k,n)
  return (math.exp(k*x)-1)/((math.exp(k)-1)*4)*
  math.cos(2*3.14159*x*n)+
  (math.exp(k*x)-1)*0.75/(math.exp(k)-1)
end

-- https://www.desmos.com/calculator/3mmmijzncm
function easing_function2(x,k,a,t,u)
  return math.abs(
    math.tanh(
      a*math.exp(
      -1*(x-u)^2/(2*t^2))+
    (math.exp(k*x)-1)/(math.exp(k)-1)))
end

-- https://www.desmos.com/calculator/evz8ulsg7v
function easing_function3(x,k,n,b,a)
  return (math.exp(k*x)-1)*(b-a)/((math.exp(k)-1)*b)*
  math.cos(2*3.14159*x*n)+
  (math.exp(k*x)-1)*a/((math.exp(k)-1)*b)
end

function toggle_clock(on)
  if on==nil then
    on=clock_run==nil
  end
  if clock_run~=nil then
    clock.cancel(clock_run)
    clock_run=nil
  end
  if not on then
    do return end
  end
  clock_beat=-1
  local d={steps=0,ci=1}
  local switched_direction=false
  params:set("clock_reset",1)
  clock_run=clock.run(function()
    while true do
      local track_beats=params:get(params:get("track").."beats")
      clock_beat=clock_beat+1
      if d.steps==0 then
        d={ci=d.ci}
        d.beat=math.floor(clock_beat)
        d.steps=1
        d.retrig=0
        d.db=0
        d.delay=0
        d.stretch=0
        d.gate=1
        d.rate=1
        d.pitch=0
        d.steps=d.steps>0 and d.steps or 1

        -- retriggering
        local refractory=math.random(15*1,15*10)
        if d.beat==0 then
        elseif math.random()<easing_function2(params:get("break"),1.6,2,0.041,0.3)*2 and debounce_fn["retrig"]==nil then
          -- local retrig_beats=util.clamp(track_beats-(d.beat%track_beats),1,6)
          local retrig_beats=math.random(1,3)
          d.steps=retrig_beats*math.random(1,4)
          d.retrig=2*math.random(1,4)*retrig_beats-1
          d.db=math.random(1,2)
          if math.random()<0.25 then
            d.pitch=-2
          end
          debounce_fn["retrig"]={math.floor(refractory/2),function()end}
        elseif math.random()<easing_function2(params:get("break"),1.6,2,0.041,0.5) and debounce_fn["stretch"]==nil then
          d.stretch=1
          d.steps=d.steps*math.random(4,8)
          debounce_fn["stretch"]={refractory,function()end}
          -- elseif math.random()<easing_function2(params:get("break"),1.6,2,0.041,0.7)*0.2 and d.beat%8>3 and debounce_fn["delay"]==nil then
          --   d.delay=1
          --   d.gate=math.random(25,75)/100
          --   d.steps=(8-d.beat%8)*ticks_per_beat
          --   debounce_fn["delay"]={refractory,function()end}
        end
        if math.random()<easing_function2(params:get("break"),-3.1,-1.3,0.177,0.5) then
          d.rate=-1
        end

        -- calculate the next position
        if d.beat%(track_beats*4)==0 then
          d.ci=ws[params:get("track")]:random_kick_pos()
        else
          -- switching directions
          local p=easing_function3(params:get("amen"),2.1,5.9,1.4,0.8)
          if switched_direction and math.random()>p then 
            switched_direction=false 
          elseif not switched_direction and math.random()<p then 
            switched_direction=true
          end
          d.ci=d.ci+(switched_direction and -1 or 1)
          -- jumping 
          local p=easing_function3(params:get("amen"),0.8,12,1.1,0.8)
          if math.random()<p then 
            -- do a jump 
            d.ci=d.ci+math.random(-1*track_beats,track_beats)
          end
        end

        -- do a small retrig sometimes based on amen
        local p=easing_function3(params:get("amen"),2.6,7.6,1.8,1.2)
        if d.retrig==0 and math.random()<p then 
          d.retrig=math.random(1,3)*2-1
        end

        print("d",json.encode(d))
        d.duration=d.steps*clock.get_beat_sec()/2
        ws[params:get("track")]:play(d)
      end
      d.steps=d.steps-1
      clock.sync(1/2)
    end
  end)
end

function rerun()
  norns.script.load(norns.state.script)
end

function cleanup()
  os.execute("pkill -f oscnotify")
end

function reset_clocks()
  clock_pulse=0
  tli:reset()
end

function show_progress(val)
  show_message_progress=util.clamp(val,0,100)
end

function show_message(message,seconds)
  seconds=seconds or 2
  show_message_clock=10*seconds
  show_message_text=message
end

function draw_message()
  if show_message_clock~=nil and show_message_text~=nil and show_message_clock>0 and show_message_text~="" then
    show_message_clock=show_message_clock-1
    screen.blend_mode(0)
    local x=64
    local y=28
    local w=screen.text_extents(show_message_text)+8
    screen.rect(x-w/2,y,w+2,10)
    screen.level(0)
    screen.fill()
    screen.rect(x-w/2,y,w+2,10)
    screen.level(15)
    screen.stroke()
    screen.move(x,y+7)
    screen.level(math.floor(screen_fade_in*2/3))
    screen.text_center(show_message_text)
    if show_message_progress~=nil and show_message_progress>0 then
      -- screen.update()
      screen.blend_mode(13)
      screen.rect(x-w/2,y,w*(show_message_progress/100)+2,9)
      screen.level(math.floor(screen_fade_in*2/3))
      screen.fill()
      screen.blend_mode(0)
    else
      -- screen.update()
      screen.blend_mode(13)
      screen.rect(x-w/2,y,w+2,9)
      screen.level(math.floor(screen_fade_in*2/3))
      screen.fill()
      screen.blend_mode(0)
      screen.level(0)
      screen.rect(x-w/2,y,w+2,10)
      screen.stroke()
    end
    if show_message_clock==0 then
      show_message_text=""
      show_message_progress=0
    end
  end
end

function debounce_params()
  for k,v in pairs(debounce_fn) do
    if v~=nil and v[1]~=nil and v[1]>0 then
      v[1]=v[1]-1
      if v[1]~=nil and v[1]==0 then
        if v[2]~=nil then
          local status,err=pcall(v[2])
          if err~=nil then
            print(status,err)
          end
        end
        debounce_fn[k]=nil
      else
        debounce_fn[k]=v
      end
    end
  end
end

function enc(k,d)
  if performance then
    if k==2 and param_switch then
      params:delta("amen",d)
    elseif k==3 and param_switch then
      params:delta("break",d)
    elseif k==2 and not param_switch then
      params:delta("track",d)
    elseif k==3 and not param_switch then
      params:delta("punch",d)
    elseif k==1 then
      params:delta("db",d)
    end
  else
    ws[params:get("track")]:enc(k,d)
  end
end


function key(k,z)
  if k==1 then
    k1_on=z==1
    do return end
  end
  if k1_on and k==2 and z==1 then
    performance=not performance
    if performance then
      ws[params:get("track")]:zoom(false,1000)
    end
    do return end
  end
  if performance then
    if k==3 and z==1 then
      toggle_clock()
    elseif k==2 and z==1 then 
      param_switch=not param_switch
    end
  else
    ws[params:get("track")]:key(k,z)
  end
end

ff=1
function redraw()
  screen.clear()
  ws[params:get("track")]:redraw()
  screen.font_face(63)
  screen.level(5)
  screen.rect(0,0,128,7)
  screen.fill()
  screen.level(0)
  screen.move(8,6)
  screen.move(64,8)
  screen.font_size(8)
  screen.text_center(performance and (clock_run==nil and "stopped" or "playing") or "edit")
  if performance then
    screen.level(15)
    screen.font_size(13)
    screen.move(32,30)
    screen.text_center(param_switch and "AMEN" or "TRACK")
    screen.move(32,30+24)
    screen.text_center(param_switch and (math.floor(params:get("amen")*100).."%") or params:get("track"))

    screen.font_face(62)
    screen.move(32+60,30)
    screen.text_center(param_switch and "BREAK" or "PUNCH")
    screen.move(32+60,30+24)
    screen.text_center(param_switch and (math.floor(params:get("break")*100).."%") or (math.floor(params:get("punch")*100).."%"))
    screen.font_size(8)
  end

  draw_message()
  screen.update()
end

function params_kick()
  -- kick
  local params_menu={
    {id="db",name="db adj",min=-96,max=16,exp=false,div=1,default=0.0,unit="db"},
    {id="preamp",name="preamp",min=0,max=4,exp=false,div=0.01,default=1,unit="amp"},
    {id="basenote",name="base note",min=10,max=200,exp=false,div=1,default=24,formatter=function(param) return musicutil.note_num_to_name(param:get(),true)end},
    {id="ratio",name="ratio",min=1,max=20,exp=false,div=1,default=6},
    {id="sweeptime",name="sweep time",min=0,max=200,exp=false,div=1,default=50,unit="ms"},
    {id="decay1",name="decay1",min=5,max=2000,exp=false,div=10,default=300,unit="ms"},
    {id="decay1L",name="decay1L",min=5,max=2000,exp=false,div=10,default=800,unit="ms"},
    {id="decay2",name="decay2",min=5,max=2000,exp=false,div=10,default=150,unit="ms"},
    {id="clicky",name="clicky",min=0,max=100,exp=false,div=1,default=0,unit="%"},
    {id="compressing",name="compressing",min=0,max=1,exp=false,div=1,default=1.0,response=1,formatter=function(param) return param:get()==1 and "yes" or "no" end},
    {id="compressible",name="compressible",min=0,max=1,exp=false,div=1,default=0.0,response=1,formatter=function(param) return param:get()==1 and "yes" or "no" end},
  }
  params:add_group("KICK",#params_menu)
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id="kick_"..pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
  end
end

function params_sidechain()
  local params_menu={
    {id="sidechain_mult",name="amount",min=0,max=8,exp=false,div=0.1,default=2.0},
    {id="compress_thresh",name="threshold",min=0,max=1,exp=false,div=0.01,default=0.1},
    {id="compress_level",name="level",min=0,max=1,exp=false,div=0.01,default=0.1},
    {id="compress_attack",name="attack",min=0,max=1,exp=false,div=0.001,default=0.01,formatter=function(param) return (param:get()*1000).." ms" end},
    {id="compress_release",name="release",min=0,max=2,exp=false,div=0.01,default=0.2,formatter=function(param) return (param:get()*1000).." ms" end},
    {id="lpshelf",name="lp boost freq",min=12,max=127,exp=false,div=1,default=23,formatter=function(param) return musicutil.note_num_to_name(math.floor(param:get()),true)end,fn=function(x) return musicutil.note_num_to_freq(x) end},
    {id="lpgain",name="lp boost db",min=-48,max=36,exp=false,div=1,default=0,unit="dB"},
    {id="delay_feedback",name="tape feedback time",min=0.001,max=12,exp=false,div=0.1,default=clock.get_beat_sec()*8,unit="s"},
    {id="delay_time",name="tape delay time",min=0.01,max=4,exp=false,div=clock.get_beat_sec()/32,default=clock.get_beat_sec()/2,unit="s"},
    {id="tape_slow",name="tape slow",min=0,max=2,exp=false,div=0.01,default=0.0,formatter=function(param) return string.format("%2.0f%%",param:get()*100) end},
  }
  params:add_group("AUDIO OUT",#params_menu)
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(pram.id,function(v)
      engine.main_set(pram.id,pram.fn~=nil and pram.fn(v) or v)
    end)
  end
end
