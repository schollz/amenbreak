local Sample={}

function Sample:new(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o:init()
  return o
end

function Sample:init()
  -- sliced sample
  params:add_file(self.id.."sample_file","file",_path.audio.."amenbreak/")
  params:set_action(self.id.."sample_file",function(x)
    if util.file_exists(x) and string.sub(x,-1)~="/" then
      self:load_sample(x)
    else
      -- print("problem loading "..x)
    end
  end)
  params:add_number(self.id.."bpm","bpm",10,600,math.floor(clock.get_tempo()))

  -- parameterse
  params_menu={
    {id="beats",name="sample length",min=1,max=64,exp=false,div=1,default=16,unit="beats"},
  }
  self.params=params_menu
  for _,pram in ipairs(params_menu) do
    params:add{
      type="control",
      id=self.id..pram.id,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
  end
  params:set_action(self.id.."beats",function(x)
    if self.duration==nil then
      do return end
    end
    if debounce_fn["startup"]~=nil then
      do return end
    end
    debounce_fn[self.id.."new_beats"]={15,function()
      self:setup_beats(x)
    end}
  end)

  table.insert(self.params,{id="sample_file"})
  table.insert(self.params,{id="bpm"})

  self.path_to_pngs=_path.data.."amenbreak/pngs/"
  self.debounce_fn={}
  self.blink=0
end

function Sample:setup_beats(x)
  self.slice_num=x*2
  self.cursors={}
  self.kick={}
  for i=1,self.slice_num do
    table.insert(self.cursors,self.duration*(i-1)/self.slice_num)
    table.insert(self.kick,-48)
  end
  -- print("[sample]: updating beats to",x)
  self:do_move(0)
end

function Sample:select(selected)
  -- first hide parameters
  for _,p in pairs(self.params) do
    if selected then
      params:show(self.id..p.id)
    else
      params:hide(self.id..p.id)
    end
  end
  debounce_fn["menu"]={
    1,function()
      _menu.rebuild_params()
    end
  }
end

function Sample:load_sample(path)
  -- print("[sample] load_sample "..path)
  -- copy file to data
  self.path=path
  self.pathname,self.filename,self.ext=string.match(self.path,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  engine.load_buffer(self.path)
  if self.id==1 then
    engine.load_slow(self.pathname.."/slow.flac")
  end

  self.ch,self.samples,self.sample_rate=audio.file_info(self.path)
  if self.samples<10 or self.samples==nil then
    print("ERROR PROCESSING FILE: "..path)
    do return end
  end
  self.duration=self.samples/self.sample_rate
  self.ci=1
  self.view={0,self.duration}
  self.height=56
  self.width=128
  self.debounce_zoom=0

  self.slice_num=16
  self.cursors={}
  self.kick={}
  self.kick_change=0
  for i=1,self.slice_num do
    table.insert(self.cursors,0)
    table.insert(self.kick,-48)
  end

  -- create dat file
  self.path_to_dat=_path.data.."amenbreak/dats/"..self.filename..".dat"
  if not util.file_exists(self.path_to_dat) then
    local delete_temp=false
    local filename=self.path
    if self.ext=="aif" then
      -- print(util.os_capture(string.format("sox '%s' '%s'",filename,filename..".wav")))
      filename=filename..".wav"
      delete_temp=true
    end
    local cmd=string.format("%s -q -i '%s' -o '%s' -z %d -b 8 &",audiowaveform,filename,self.path_to_dat,2)
    -- print(cmd)
    os.execute(cmd)
    if delete_temp then
      debounce_fn[self.id.."rm_"..filename]={45,function() os.execute("rm "..filename) end}
    end
  end

  local bpm=nil
  for word in string.gmatch(self.path,'([^_]+)') do
    if string.find(word,"bpm") then
      bpm=tonumber(word:match("%d+"))
    end
  end
  if bpm==nil then
    bpm=self:guess_bpm(self.path)
  end
  if bpm==nil then
    bpm=clock.get_tempo()
  end
  params:set(self.id.."bpm",bpm)

  self:get_onsets()
  self.loaded=true
  self:get_render()
end

function Sample:get_onsets()
  self.path_to_cursors=_path.data.."amenbreak/cursors/"..self.filename.."_"..self.slice_num..".cursors"
  if not util.file_exists(self.path_to_cursors) then
    local beats=nil
    for word in string.gmatch(self.path,'([^_]+)') do
      if string.find(word,"beats") then
        beats=tonumber(word:match("%d+"))
      end
    end
    if beats==nil then
      beats=util.round(self.duration/(60/params:get(self.id.."bpm")))
    end
    -- print("[sample] found beats: "..beats)
    params:set(self.id.."beats",beats,true)
    self:setup_beats(beats)
    local f=io.open(self.path..".json","rb")
    local content=f:read("*all")
    f:close()
    if content~=nil then
      local data=json.decode(content)
      if data~=nil then
        self.kick=data
      end
    end
    do return end
  end
  -- print("[sample] loading existing cursors")
  local f=io.open(self.path_to_cursors,"rb")
  local content=f:read("*all")
  f:close()
  if content~=nil then
    local data=json.decode(content)
    if data~=nil then
      self.cursors=data.cursors
      if data.kick~=nil then
        self.kick=data.kick
      end
      -- print("[sample] loaded existing cursors")
      params:set(self.id.."beats",#self.cursors/2,true)
      self:do_move(0)
    end
  end
end

function Sample:save_cursors()
  -- save cursors
  -- print("[sample] writing cursor file",self.path_to_cursors)
  local file=io.open(self.path_to_cursors,"w+")
  io.output(file)
  io.write(json.encode({cursors=self.cursors,kick=self.kick}))
  io.close(file)
end

function Sample:guess_bpm(fname)
  local ch,samples,samplerate=audio.file_info(fname)
  if samples==nil or samples<10 then
    print("ERROR PROCESSING FILE: "..self.path)
    do return end
  end
  local duration=samples/samplerate
  local closest={1,1000000}
  for bpm=90,179 do
    local beats=duration/(60/bpm)
    local beats_round=util.round(beats)
    -- only consider even numbers of beats
    if beats_round%4==0 then
      local dif=math.abs(beats-beats_round)/beats
      if dif<closest[2] then
        closest={bpm,dif,beats}
      end
    end
  end
end

function Sample:play(d)
  if self.slice_num==nil then
    do return end
  end
  local filename=self.path
  d.id=d.id or self.id
  d.db=d.db or 0
  d.pan=d.pan or params:get("pan")
  d.pitch=d.pitch or params:get("pitch")
  d.watch=d.watch or 1
  d.rate=d.rate or 1
  d.rate=d.rate*clock.get_tempo()/params:get(self.id.."bpm")*params:get("rate")
  if d.uselast==1 and self.last_ci~=nil then
    d.ci=self.last_ci
  else
    d.ci=d.ci or self.ci
    d.ci=(d.ci-1+params:get("rotate"))%(#self.cursors)+1
  end
  self.last_ci=d.ci
  pos_last=d.ci
  d.retrig=d.retrig or 0
  d.gate=d.gate or params:get("gate")
  d.hold=d.hold or params:get("hold")
  d.compressing=d.compressing or params:get("compressing")
  d.compressible=d.compressible or params:get("compressible")
  d.lpf=musicutil.note_num_to_freq(params:get("lpf"))
  d.res=params:get("res")
  d.decimate=d.decimate or params:get("decimate")
  d.attack=d.attack or params:get("attack")/1000
  d.release=d.release or params:get("release")/1000
  d.reverb=d.reverb or params:get("send_reverb")
  d.delay=d.delay or params:get("send_delay")
  d.drive=d.drive or params:get("drive")
  d.compression=d.compression or params:get("compression")
  d.stretch=d.stretch or params:get("stretch")
  d.send_tape=d.send_tape or 0
  local pos=self.cursors[d.ci]
  if d.duration==nil then
    local start=pos
    local finish=self.duration
    for _,c in ipairs(self.cursors) do
      if c<finish and c>start then
        finish=c
      end
    end
    d.duration=finish-start
  end
  d.duration_slice=d.duration
  d.duration_total=d.duration_slice
  if d.duration_total/d.retrig<d.duration_slice then
    d.duration_slice=d.duration_total
  end
  if d.hold>0 then
    d.duration_slice=clock.get_beat_sec()/24*d.hold
  end
  if d.duration_slice<0.01 then
    do return end
  end
  d.snare=-48
  if self.kick[d.ci]<=-48 then
    if math.random(1,3)==1 then
      d.snare=math.random(1,12)
    end
  end
  engine.slice_on(
    d.id,
    filename,
    params:get("db"),
    d.db,
    d.pan,
    d.rate,
    d.pitch,
    pos,
    d.duration_slice,
    d.duration_total,
    d.retrig,
    d.gate,
    d.lpf,
    d.decimate,
    d.compressible,
    d.compressing,
    d.reverb,d.drive,d.compression,
  d.watch,d.attack,d.release,d.stretch,d.send_tape,d.delay,d.res,d.snare)
  if self.kick[d.ci]>-48 then
    engine.kick(
      musicutil.note_num_to_freq(params:get("kick_basenote")),
      params:get("kick_ratio"),
      params:get("kick_sweeptime")/1000,
      params:get("kick_preamp"),
      params:get("kick_db")+self.kick[d.ci],
      params:get("kick_decay1")/1000,
      params:get("kick_decay1L")/1000,
      params:get("kick_decay2")/1000,
      params:get("kick_clicky")/1000,
      params:get("kick_compressing"),
      params:get("kick_compressible"),
      d.reverb,d.send_tape,d.send_delay
    )
  end
end

function Sample:debounce()
  for k,v in pairs(self.debounce_fn) do
    if v~=nil and v[1]~=nil and v[1]>0 then
      v[1]=v[1]-1
      if v[1]~=nil and v[1]==0 then
        if v[2]~=nil then
          local status,err=pcall(v[2])
          if err~=nil then
            print(status,err)
          end
        end
        self.debounce_fn[k]=nil
      else
        self.debounce_fn[k]=v
      end
    end
  end
end

function Sample:do_zoom(d)
  -- zoom
  if d>0 then
    self.debounce_fn["zoom"]={1,function() self:zoom(true) end}
  else
    self.debounce_fn["zoom"]={1,function() self:zoom(false) end}
  end
end

function Sample:do_move(d)
  if self.duration==nil then
    do return end
  end
  if self.cursors[self.ci]==nil then
    do return end
  end
  self.cursors[self.ci]=util.clamp(self.cursors[self.ci]+d*((self.view[2]-self.view[1])/128),0,self.duration)
  if d>0 then
    self.debounce_fn["save"]={15,function() self:save_cursors() end}
    self:sel_cursor(self.ci)
  end
end

function Sample:adjust_kick(i,d)
  if self.is_melodic then
    do return end
  end
  self.kick[i]=self.kick[i]+d
  if self.kick[i]<-48 then
    self.kick[i]=-48
  elseif self.kick[i]>12 then
    self.kick[i]=12
  end
  self.kick_change=16
  self.debounce_fn["save"]={15,function() self:save_cursors() end}
end

function Sample:is_kick(ci)
  return self.kick[ci]>-48
end

function Sample:get_kicks()
  local pos={}
  for i,v in ipairs(self.kick) do
    if v>-48 then
      table.insert(pos,i)
    end
  end
  if next(pos)==nil then
    pos={1}
  end
  return pos
end

function Sample:random_kick_pos()
  local kicks=self:get_kicks()
  return kicks[math.random(#kicks)]
end

function Sample:enc(k,d)
  if k==1 then
    self:adjust_kick(self.ci,d)
  elseif k==2 then
    self:do_zoom(d)
  elseif k==3 and d~=0 then
    self:do_move(d)
  end
end

function Sample:key(k,z)
  if k==1 then
    self.k1=z==1
  elseif k==2 and z==1 then
    self:sel_cursor(self.ci+1)
  elseif k==3 and z==1 then
    self:audition()
  end
end

function Sample:audition()
  self:play{}
end

function Sample:set_position(pos)
  self.show=1
  self.show_pos=pos
end

function Sample:delta_cursor(d)
  if self.cursor_sorted==nil then
    do return end
  end
  for i,v in ipairs(self.cursor_sorted) do
    if v.i==self.ci then
      self:sel_cursor(self.cursor_sorted[(i+d-1)%#self.cursor_sorted+1].i)
      do return end
    end
  end
end

function Sample:sel_cursor(ci)
  if self.duration==nil then
    do return end
  end
  if ci<1 then
    ci=ci+self.slice_num
  elseif ci>self.slice_num then
    ci=ci-self.slice_num
  end
  self.ci=ci
  local view_duration=(self.view[2]-self.view[1])
  local cursor=self.cursors[self.ci]
  if view_duration~=self.duration and (cursor<self.view[1] or cursor>self.view[2]) then
    local prev_view=cursor-view_duration/2
    local next_view=cursor+view_duration/2
    self.view={util.clamp(prev_view,0,self.duration),util.clamp(next_view,0,self.duration)}
  end
end

function Sample:zoom(zoom_in,zoom_amount)
  if self.duration==nil then
    do return end
  end

  zoom_amount=zoom_amount or 1.5
  local view_duration=(self.view[2]-self.view[1])
  local view_duration_new=zoom_in and view_duration/zoom_amount or view_duration*zoom_amount
  local cursor=self.cursors[self.ci]
  local cursor_frac=(cursor-self.view[1])/view_duration
  local view_new={0,0}
  view_new[1]=util.clamp(cursor-view_duration_new*cursor_frac,0,self.duration)
  view_new[2]=util.clamp(view_new[1]+view_duration_new,0,self.duration)
  if (view_new[2]-view_new[1])<0.005 then
    do return end
  end
  self.view={view_new[1],view_new[2]}
end

function Sample:get_render()
  local rendered=string.format("%s%s_%3.3f_%3.3f_%d_%d.png",self.path_to_pngs,self.filename,self.view[1],self.view[2],self.width,self.height)
  if not util.file_exists(rendered) then
    if self.view[1]>self.view[2] then
      self.view[1],self.view[2]=self.view[2],self.view[1]
    end
    local cmd=string.format("%s -q -i '%s' -o '%s' -s %2.4f -e %2.4f -w %2.0f -h %2.0f --background-color 000000 --waveform-color 757575 --no-axis-labels --compression 9 &",audiowaveform,self.path_to_dat,rendered,self.view[1],self.view[2],self.width,self.height)
    -- print(cmd)
    os.execute(cmd)
  end
  return rendered
end

function Sample:redraw()
  if not self.loaded then
    do return end
  end
  self.blink=self.blink-1
  if self.blink<0 then
    self.blink=8
  end
  local sel_level=self.blink>4 and 15 or 1
  sel_level=10
  local x=0
  local y=8
  if show_cursor==nil then
    show_cursor=true
  end
  self:debounce()

  if not performance then
    for i,cursor in ipairs(self.cursors) do
      if cursor>=self.view[1] and cursor<=self.view[2] then
        local pos=util.linlin(self.view[1],self.view[2],1,self.width,cursor)
        local level=i==self.ci and sel_level or 1
        screen.level(level)
        screen.move(pos+x,64-self.height)
        screen.line(pos+x,64)
        screen.stroke()
      end
    end
  end

  local png_file=self:get_render()
  if util.file_exists(png_file) then
    screen.blend_mode(8)
    screen.display_png(self:get_render(),x,y)
    screen.blend_mode(0)
  else
    print('could not find',png_file)
  end

  if self.show~=nil and self.show>0 then
    self.show=self.show-1
    self.is_playing=true
    screen.level(15)
    local cursor=self.show_pos
    if cursor>=self.view[1] and cursor<=self.view[2] then
      local pos=util.linlin(self.view[1],self.view[2],1,self.width,cursor)
      screen.aa(1)
      screen.level(15)
      screen.move(pos+x,64-self.height)
      screen.line(pos+x,64)
      screen.stroke()
      screen.aa(0)
    end
  else
    self.is_playing=false
  end

  if not performance then
    screen.move(128,17)
    screen.level(self.kick_change)
    if self.kick[self.ci]>-48 then
      screen.text_right("kick "..math.floor(self.kick[self.ci]).."dB")
    else
      screen.text_right("not kick")
    end
  end
end

return Sample
