local GGrid={}

function GGrid:new(args)
  local m=setmetatable({},{__index=GGrid})
  local args=args==nil and {} or args

  m.apm=args.apm or {}
  m.grid_on=args.grid_on==nil and true or args.grid_on

  -- initiate the grid
  local midigrid=util.file_exists(_path.code.."midigrid")
  local grid=midigrid and include "midigrid/lib/mg_128" or grid
  m.g=grid.connect()
  m.g.key=function(x,y,z)
    if m.grid_on then
      m:grid_key(x,y,z)
    end
  end
  print("grid columns: "..m.g.cols)

  -- setup visual
  m.visual={}
  m.grid_width=16
  for i=1,8 do
    m.visual[i]={}
    for j=1,16 do
      m.visual[i][j]=0
    end
  end

  -- keep track of pressed buttons
  m.pressed_buttons={}

  -- grid refreshing
  m.grid_refresh=metro.init()
  m.grid_refresh.time=midigrid and 0.12 or 0.07
  m.grid_refresh.event=function()
    if m.grid_on then
      m:grid_redraw()
    end
  end
  m.grid_refresh:start()

  -- musical keyboard
  m.octave=0
  m.reese_keys_on=0
  m.keyboard={}
  m.reese_amp=-8
  m.reese_off=function()
	  m.reese_keys_on=m.reese_keys_on-1
    print(m.reese_keys_on)
    if m.reese_keys_on==0 then 
      engine.reese_off()
    end
  end
  m.root_note=36
  m.note_on=function(x)
    local note=x+m.root_note+m.octave*12
    engine.reese_on(note,util.dbamp(params:get("bass_db")),
      params:get("bass_mod1"),
      params:get("bass_mod2"),
      params:get("bass_mod3"),
      params:get("bass_mod4"),
      params:get("bass_attack"),
      params:get("bass_decay"),
      params:get("bass_sustain"),
      params:get("bass_release"),
      params:get("bass_pan"),
      params:get("bass_portamento")
    )
    m.reese_keys_on=m.reese_keys_on+1
    while note>36 do 
      note = note - 12
    end
    while note<24 do 
      note = note + 12
    end
    params:set("kick_basenote",note)
  end
  m.keyboard[1]={
    {on=function() m.octave=m.octave-1 end},
    {on=function() m.note_on(1) end,off=m.reese_off},
    {on=function() m.note_on(3) end,off=m.reese_off},
    {},
    {on=function() m.note_on(6) end,off=m.reese_off},
    {on=function() m.note_on(8) end,off=m.reese_off},
    {on=function() m.note_on(10) end,off=m.reese_off},
    {on=function() m.octave=m.octave+1 end},
  }
  m.keyboard[2]={
    {on=function() m.note_on(0) end,off=m.reese_off},
    {on=function() m.note_on(2) end,off=m.reese_off},
    {on=function() m.note_on(4) end,off=m.reese_off},
    {on=function() m.note_on(5) end,off=m.reese_off},
    {on=function() m.note_on(7) end,off=m.reese_off},
    {on=function() m.note_on(9) end,off=m.reese_off},
    {on=function() m.note_on(11) end,off=m.reese_off},
    {on=function() m.note_on(12) end,off=m.reese_off},
  }

  -- in the grid loop, set the button fns
  m.button_fns={}
  table.insert(m.button_fns,{
    {retrig=function() return math.random(1,5) end,light=function() return (global_played.retrig~=nil and global_played.retrig>0 and global_played.retrig<5) and 14 or 4 end},
    {retrig=function() return math.random(3,7) end,light=function() return (global_played.retrig~=nil and global_played.retrig>3 and global_played.retrig<7) and 14 or 4 end},
    {retrig=function() return math.random(6,15) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
  })
  table.insert(m.button_fns,{
    {retrig=function() return math.random(1,5) end,steps=function() return math.random(2,4) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
    {retrig=function() return math.random(3,7) end,steps=function() return math.random(2,4) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
    {retrig=function() return math.random(6,15) end,steps=function() return math.random(2,4) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
  })
  table.insert(m.button_fns,{
    {retrig=function() return math.random(1,5) end,steps=function() return math.random(5,8) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
    {retrig=function() return math.random(3,7) end,steps=function() return math.random(5,8) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
    {retrig=function() return math.random(6,15) end,steps=function() return math.random(5,8) end,light=function() return (global_played.retrig~=nil and global_played.retrig>6 and global_played.retrig<15) and 14 or 4 end},
  })
  table.insert(m.button_fns,{
    {uselast=function() return 1 end,light=function() return  (global_played.uselast~=nil and global_played.uselast>0) and 14 or 4 end},
    {db=function() return math.random(1,2) end,light=function() return (global_played.db~=nil and global_played.db>0) and 14 or 4 end},
    {pitch=function() return math.random(1,2) end,light=function() return (global_played.pitch~=nil and global_played.pitch~=0) and 14 or 2 end},
  })
  table.insert(m.button_fns,{
    {delay=function() return 1 end,light=function() return  (global_played.delay~=nil and global_played.delay>0) and 14 or 2 end},
    {rate=function() return -1 end,light=function() return (global_played.rate~=nil and global_played.rate<0) and 14 or 2 end},
    {stretch=function() return -1 end,light=function() return (global_played.stretch~=nil and global_played.stretch>0) and 14 or 2 end},
  })
  table.insert(m.button_fns,{
    {on=function() params:set("tape_gate",1) end,off=function() params:set("tape_gate",0) end,light=function() return params:get("tape_gate")>0 and 14 or 4 end},
    {on=function() engine.filter_set(200,clock.get_beat_sec()*math.random(1,4)) end,off=function() engine.filter_set(musicutil.note_num_to_freq(params:get("lpf")),clock.get_beat_sec()*math.random(1,4)) end,light=function() return params:get("db")<-32 and 14 or 4 end},
    {on=function() m.db_store=params:get("db"); params:set("db",-96) end,off=function() params:set("db",m.db_store) end,light=function() return params:get("db")<-32 and 14 or 4 end},
  })

  return m
end

function GGrid:grid_key(x,y,z)
  self:key_press(y,x,z==1)
  self:grid_redraw()
end

function GGrid:key_press(row,col,on)
  local ct=clock.get_beats()*clock.get_beat_sec()
  hold_time=0
  if on then
    self.pressed_buttons[row..","..col]={ct,0}
  else
    hold_time=ct-self.pressed_buttons[row..","..col][1]
    self.pressed_buttons[row..","..col]=nil
  end

  if on and row==8 and col==1 then 
    toggle_clock()
   elseif row>=1 and row<=4 and col>=9 then 
    if on then
	   loops[row][col-8]:toggle()
    end
   elseif row>=7 and col>=9 then 
    local fn = self.keyboard[row-6][col-8]
    if on and fn.on then 
		   fn.on()
	   elseif (not on) and fn.off then 
		   fn.off()
	   end
  elseif on and row==6 and col>=11 then 
    local x=(col-11)/5
    params:set_raw("db",x)
    params:set("kick_db",params:get("db")-6)
  elseif on and row==7 and col>=11 then 
    local x=(col-11)/5
    params:set_raw("lpf",x)
  elseif on and row==8 and col>=12 then 
    local x=(col-12)/4
    params:set_raw("gate",x)
  elseif row>=3 and row<=8 and col>=6 and col<=8 then 
    local r=row-2
    local c=col-5
    local fns=self.button_fns[r][c]
    if fns==nil then 
      do return end 
    end
    if on and fns.on~=nil then 
      fns.on()
      do return end 
    elseif (not on) and fns.off~=nil then 
      fns.off()
      do return end
    else
      for k,fn in pairs(fns) do 
        if k=="off" or k=="on" or k=="light" then 
        else
          button_fns[k]=on and fn or nil
        end
      end
    end
  elseif on and col==1 then 
    local bin=binary.encode(params:get("track"))
    bin[row]=1-bin[row]
    params:set("track",binary.decode(bin))
  elseif (not on) and col>=2 and col<=5 then 
    local i=(row-1)*4+col-1
    button_fns.ci=nil
  elseif on and col>=2 and col<=5 then 
    local i=(row-1)*4+col-1
    button_fns.ci=function() return i end 
    if clock_run==nil then 
      ws[params:get("track")]:play{ci=i}
    end  
    if self.pattern_held~=nil then 
      if self.pattern_held.first then 
        pattern_store[self.pattern_held.row][self.pattern_held.col]={}
        self.pattern_held.first=false
      end
      table.insert(pattern_store[self.pattern_held.row][self.pattern_held.col],i)
      print(string.format("[grid] updating %s to pattern %d",PTTRN_NAME[self.pattern_held.row],self.pattern_held.col))
      tab.print(pattern_store[self.pattern_held.row][self.pattern_held.col])
    end
  elseif col>5 and row<=5 then 
    col=col-5
    if on then
      self.pattern_held={row=row,col=col,first=true}
      if pattern_current[row]==col then 
        print(string.format("[grid] disabling %s patterns",PTTRN_NAME[row]))
        pattern_current[row]=0
      elseif next(pattern_store[row][col])~=nil then 
        print(string.format("[grid] switching %s to pattern %d",PTTRN_NAME[row],col))
        pattern_current[row]=col
      end
    else
      self.pattern_held=nil
    end
  end
end

function GGrid:get_visual()
  -- clear visual
  for row=1,8 do
    for col=1,self.grid_width do
      if self.visual[row][col]>0 then
        self.visual[row][col]=0
      end
    end
  end

  -- illuminate the current position
  for i=1,params:get(params:get("track").."beats")*2 do 
    local row=math.floor((i-1)/4)+1
    local col=(i-1)%4+2
    if ws[params:get("track")]~=nil then 
      self.visual[row][col]=pos_last==i and 15
      if ws[params:get("track")].kick~=nil and pos_last~=i then 
        self.visual[row][col]=ws[params:get("track")].kick[i]>-48 and 9 or 4
      end
    end
  end

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    row=tonumber(row)
    col=tonumber(col)
    self.visual[row][col]=14
  end

  -- illuminate the current track
  local bin=binary.encode(params:get("track"))
  for i,v in ipairs(bin) do 
    if i<8 then 
      self.visual[i][1]=v==1 and 15 or 2
    end
  end

  -- illuminate which patterns are availble
  for row,_ in ipairs(pattern_store) do 
    for coll,v in ipairs(pattern_store[row]) do 
      local col=coll+5
      self.visual[row][col]=next(v)~=nil and 2 or 0
    end
  end
  for row,col in ipairs(pattern_current) do 
    if col>0 then
      self.visual[row][col+5]=7
    end
  end

  -- illuminate retrig / fx buttons
  for row=3,8 do 
    for col=6,8 do
      if global_played~=nil then 
        if self.button_fns[row-2][col-5].light~=nil then
          self.visual[row][col]=self.button_fns[row-2][col-5].light()
        end
      end
    end
  end

  -- illuminate loops
  for row=1,4 do 
	  for col=1,8 do 
      if loops[row][col].playing then 
        self.visual[row][col+8]=14
      elseif loops[row][col].loaded then 
        self.visual[row][col+8]=4
      end
    end
  end

  -- illuminate keyboard
  for col=9,16 do 
    self.visual[row][col]=4
  end
  self.visual[7][10]=8
  self.visual[7][11]=8
  self.visual[7][13]=8
  self.visual[7][14]=8
  self.visual[7][15]=8
  self.visual[7][9]=util.round(util.clamp(util.linlin(-1,4,0,15,self.octave),0,15))
  self.visual[7][16]=self.visual[7][9]

  -- illuminate playing screen
  self.visual[8][1]=clock_run==nil and 2 or 15
  
  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    row=tonumber(row)
    col=tonumber(col)
    if col>=9 then 
      self.visual[row][col]=15
    end
  end

  return self.visual
end

function GGrid:grid_redraw()
  self.g:all(0)
  local gd=self:get_visual()
  local s=1
  local e=self.grid_width
  local adj=0
  for row=1,8 do
    for col=s,e do
      if gd~=nil and gd[row]~=nil and gd[row][col]~=0 then
        self.g:led(col+adj,row,gd[row][col])
      end
    end
  end
  self.g:refresh()
end

function GGrid:redraw()

end

return GGrid
