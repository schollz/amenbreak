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
  m.reese_keys_on={}
  m.keyboard={}
  m.note_on=function(x,sequenced)
    note=x+params:get("bass_basenote")
    if sequenced==nil then 
      table.insert(m.reese_keys_on,x)
      if m.bass_pattern_held~=nil then 
        if m.bass_pattern_held.first then 
          bass_pattern_store[m.bass_pattern_held.col]={}
          m.bass_pattern_held.first=false
        end
        table.insert(bass_pattern_store[m.bass_pattern_held.col],x)
        print(string.format("[grid] updating to pattern %d",m.bass_pattern_held.col))
        tab.print(bass_pattern_store[m.bass_pattern_held.col])
      end
    end
    bass_note_on(note)
  end
  m.reese_off=function(x)
    local new_keys={}
    for _, v in ipairs(m.reese_keys_on) do 
      if v~=x then 
        table.insert(new_keys,v)
      end
    end
    m.reese_keys_on=new_keys
    if next(m.reese_keys_on)==nil then 
      engine.reese_off()
    else
      m.note_on(m.reese_keys_on[#m.reese_keys_on])
    end
  end
  m.keyboard[1]={
    {},
    {on=function() m.note_on(1) end,off=function() m.reese_off(1) end,light=function() return bass_sequenced==1 and 14 or 8 end},
    {on=function() m.note_on(3) end,off=function() m.reese_off(3) end,light=function() return bass_sequenced==3 and 14 or 8 end},
    {},
    {on=function() m.note_on(6) end,off=function() m.reese_off(6) end,light=function() return bass_sequenced==6 and 14 or 8 end},
    {on=function() m.note_on(8) end,off=function() m.reese_off(8) end,light=function() return bass_sequenced==8 and 14 or 8 end},
    {on=function() m.note_on(10) end,off=function() m.reese_off(10) end,light=function() return bass_sequenced==10 and 14 or 8 end},
    {},
  }
  m.keyboard[2]={
    {on=function() m.note_on(0) end,off=function() m.reese_off(0) end,light=function() return bass_sequenced==0 and 14 or 4 end},
    {on=function() m.note_on(2) end,off=function() m.reese_off(2) end,light=function() return bass_sequenced==2 and 14 or 4 end},
    {on=function() m.note_on(4) end,off=function() m.reese_off(4) end,light=function() return bass_sequenced==4 and 14 or 4 end},
    {on=function() m.note_on(5) end,off=function() m.reese_off(5) end,light=function() return bass_sequenced==5 and 14 or 4 end},
    {on=function() m.note_on(7) end,off=function() m.reese_off(7) end,light=function() return bass_sequenced==7 and 14 or 4 end},
    {on=function() m.note_on(9) end,off=function() m.reese_off(9) end,light=function() return bass_sequenced==9 and 14 or 4 end},
    {on=function() m.note_on(11) end,off=function() m.reese_off(11) end,light=function() return bass_sequenced==11 and 14 or 4 end},
    {on=function() m.note_on(12) end,off=function() m.reese_off(12) end,light=function() return bass_sequenced==12 and 14 or 4 end},
  }

  -- in the grid loop, set the button fns
  m.button_fns={}
  local choices_steps={{1,4},{5,12},{13,32}}
  local choices_retrigs={{1,5},{6,13},{14,24}}
  for row=1,3 do 
    m.button_fns[row]={}
    for col=1,3 do 
      m.button_fns[row][col]={
        retrig=function() return math.random(choices_retrigs[col][1],choices_retrigs[col][2]) end,
        steps=function() return math.random(choices_steps[row][1],choices_steps[row][2]) end,
        light=function() 
          return (global_played.retrig~=nil and 
          global_played.retrig>=choices_retrigs[col][1] and 
          global_played.retrig<=choices_retrigs[col][2] and
          global_played.steps>=choices_steps[row][1] and 
          global_played.steps<=choices_steps[row][2]) and 14 or (row*1+col*1) 
        end}
    end
  end
  m.toggle_mute=function()
    print("TOGGLE")
    if params:get("db")>-32 then 
      m.db_store=params:get("db")
      m.kick_db_store=params:get("kick_db")
      params:set("db",-96)
      params:set("kick_db",-96)
    elseif m.db_store~=nil then 
      params:set("db",m.db_store)
      params:set("kick_db",m.kick_db_store)
    end
  end
  m.filter_on=false
  m.gate_last=params:get("gate")
  m.rel_last=params:get("release")
  table.insert(m.button_fns,{
    {stretch=function() return 1 end,steps=function() return math.random(1,3)*4 end,light=function() return  (global_played.stretch~=nil and global_played.stretch>0) and 14 or 2 end},
    {db=function() return math.random(1,2) end,light=function() return (global_played.db~=nil and global_played.db>0) and 14 or 2 end},
    {pitch=function() return math.random(1,2) end,light=function() return (global_played.pitch~=nil and global_played.pitch~=0) and 14 or 2 end},
  })
  table.insert(m.button_fns,{
    {delay=function() return 1 end,light=function() return  (global_played.delay~=nil and global_played.delay>0) and 14 or 2 end},
    {rate=function() return -1 end,light=function() return (global_played.rate~=nil and global_played.rate<0) and 14 or 2 end},
    {on=function() m.rel_last=params:get("release"); m.gate_last=params:get("gate"); params:set("gate",m.gate_last*0.5); params:set("release",m.rel_last*0.25) end,off=function() params:set("gate",m.gate_last); params:set("release",m.rel_last) end,light=function() return (global_played.stretch~=nil and global_played.stretch>0) and 14 or 2 end},
  })
  table.insert(m.button_fns,{
    {on=function() params:set("tape_gate",1) end,off=function() params:set("tape_gate",0) end,light=function() return params:get("tape_gate")>0 and 14 or 2 end},
    {on=function() m.filter_on=true;engine.filter_set(200,clock.get_beat_sec()*math.random(1,4)) end,off=function() m.filter_on=false;engine.filter_set(musicutil.note_num_to_freq(params:get("lpf")),clock.get_beat_sec()*math.random(1,4)*2) end,light=function() return m.filter_on and 14 or 2 end},
    {on=m.toggle_mute,light=function() return params:get("db")<-32 and 14 or 2 end},
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
    -- main start
    toggle_clock()
  elseif row==6 and col>=15 then 
    if on then 
      params:delta("bass_basenote",col==15 and -12 or 12)
    end
  elseif row>=1 and row<=5 and col>=9 then 
    -- loops
    if on then
	   loops[row][col-8]:toggle()
    end
  elseif row>=7 and col>=9 then 
    -- bass keyboard
    local fn = self.keyboard[row-6][col-8]
    if on and fn.on then 
		   fn.on()
	   elseif (not on) and fn.off then 
		   fn.off()
     elseif on and self.bass_pattern_held~=nil then 
        if self.bass_pattern_held.first then 
          bass_pattern_store[self.bass_pattern_held.col]={}
          self.bass_pattern_held.first=false
        end
        table.insert(bass_pattern_store[self.bass_pattern_held.col],-1)
        print(string.format("[grid] updating to pattern %d with reset",self.bass_pattern_held.col))
    end
  elseif row>=3 and row<=8 and col>=6 and col<=8 then 
    -- fx / retrig
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
    -- sample select
    local bin=binary.encode(params:get("track"))
    bin[row]=1-bin[row]
    params:set("track",binary.decode(bin))
  elseif (not on) and col>=2 and col<=5 then 
    -- step deselect
    local i=(row-1)*4+col-1
    button_fns.ci=nil
  elseif on and col>=2 and col<=5 then 
    -- step select
    local i=(row-1)*4+col-1
    button_fns.ci=function() return i end 
    if clock_run==nil then 
      ws[params:get("track")]:play{ci=i}
    end  
    if self.pattern_held~=nil then 
      local r=self.pattern_held.row
      local c=self.pattern_held.col
      if r==2 then 
        r=self.pattern_held.col+1
        c=1
      end
      if self.pattern_held.first then 
        pattern_store[r][c]={}
        self.pattern_held.first=false
      end
      table.insert(pattern_store[r][c],i)
      print(string.format("[grid] updating %s to pattern %d",PTTRN_NAME[r],c))
      tab.print(pattern_store[r][c])
    end
  elseif row==6 and col>=9 and col<=14 then 
    print("[grid] bass pattern click",row,col,on)
    col=col-8
    if on then
      self.bass_pattern_held={col=col,first=true}
      if bass_pattern_current==col then 
        print(string.format("[grid] disabling bass patterns"))
        bass_pattern_current=0
        bass_sequenced=-1
        engine.reese_off()
      elseif next(bass_pattern_store[col])~=nil then 
        print(string.format("[grid] switching to bass pattern %d",col))
        bass_pattern_current=col
      end
    else
      self.bass_pattern_held=nil
    end
  elseif col>5 and row<=5 then 
    col=col-5
    if on then
      self.pattern_held={row=row,col=col,first=true}
      local r=self.pattern_held.row
      local c=self.pattern_held.col
      print(r,c)
      if r==2 then 
        r=col+1
        c=1
      end
      print(r,c)
      if pattern_current[r]==c then 
        print(string.format("[grid] disabling %s patterns",PTTRN_NAME[r]))
        pattern_current[r]=0
      elseif next(pattern_store[r][c])~=nil then 
        print(string.format("[grid] switching %s to pattern %d",PTTRN_NAME[r],c))
        pattern_current[r]=c
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
      if pos_last==i then 
        self.visual[row][col] = 15
      elseif ws[params:get("track")].kick~=nil then 
        self.visual[row][col]=ws[params:get("track")].kick[i]>-48 and 9 or 4
      end
    end
  end

  -- illuminate the current track
  local bin=binary.encode(params:get("track"))
  for i,v in ipairs(bin) do 
    if i<8 then 
      self.visual[i][1]=v==1 and 15 or 2
    end
  end

  -- illuminate which patterns are availble
  for i=1,3 do 
    local row=1
    local col=i+5
    self.visual[row][col]=next(pattern_store[1][i])~=nil and (pattern_current[1]==i and 7 or 2) or 0
  end
  for j=1,3 do 
    local row=2
    local col=j+5
    self.visual[row][col]=next(pattern_store[j+1][1])~=nil and (pattern_current[j+1]==1 and 7 or 2) or 0
  end
  
  -- illuminate which bass patterns are availble
  for col,v in ipairs(bass_pattern_store) do 
    self.visual[6][col+8]=next(v)~=nil and 2 or 0
  end
  if bass_pattern_current>0 then
    self.visual[6][bass_pattern_current+8]=7
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
  for row=1,5 do 
	  for col=1,8 do 
      if loops[row][col].playing then 
        self.visual[row][col+8]=9
      elseif loops[row][col].loaded then 
        self.visual[row][col+8]=2
      end
    end
  end

  -- illuminate keyboard
  for row=7,8 do 
    for col=9,16 do 
      self.visual[row][col]=self.keyboard[row-6][col-8].light and self.keyboard[row-6][col-8].light() or 0
    end
  end
  self.visual[6][15]=util.round(params:get_raw("bass_basenote")*15)
  self.visual[6][16]=self.visual[6][15]

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
