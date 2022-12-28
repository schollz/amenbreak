local GGrid={}

local RETRIG=3
local STRETCH=4
local DELAY=5
local GATE=6

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
  m.retrigs={
    {1,0},
    {1,1},
    {1,3},
    {2,9},
    {3,5},
    {3,7},
    {3,9},
    {3,11},
    {4,9},
    {4,5},
    {4,7},
    {5,9},
    {5,11},
    {5,13},
    {6,15},
    {6,17},       
  }
  m.d={retrig=0,ci=0,steps=1,retrigi=1,stretch=1,delay=1,gate=1}
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


  if row<=2 and on then 
    self.d.ci=col+16*(row-1)
elseif row==STRETCH and on then 
    self.d.stretch=col
elseif row==DELAY and on then 
    self.d.delay=col
elseif row==GATE and on then 
    self.d.gate=col
    print(self.d.gate)
  elseif row==RETRIG and on then 
    self.d.retrigi=col
    self.d.steps=self.retrigs[self.d.retrigi][1]
    self.d.retrig=self.retrigs[self.d.retrigi][2]
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

  if d_.ci~=nil then 
    local row=1
    local col=d_.ci 
    while col>16 do 
        col=col-16
        row=row+1
    end
    self.visual[row][col]=14
  end

  self.visual[RETRIG][self.d.retrigi]=14
  self.visual[STRETCH][self.d.stretch]=14
  self.visual[DELAY][self.d.delay]=14
  self.visual[GATE][self.d.gate]=14

  -- illuminate currently pressed button
  for k,_ in pairs(self.pressed_buttons) do
    local row,col=k:match("(%d+),(%d+)")
    row=tonumber(row)
    col=tonumber(col)
    self.visual[row][col]=14
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
