local Loop={}

function Loop:new(o)
  o=o or {}
  setmetatable(o,self)
  self.__index=self
  o:init()
  return o
end

function Loop:init()
    self.oneshot=self.oneshot or false
    self.db=self.db or 0
    self.tick=0
    self.loaded=false
    self.playing=false
    self.primed=false
end

function Loop:load_sample(path)
    self.path=path
    self.pathname,self.filename,self.ext=string.match(self.path,"(.-)([^\\/]-%.?([^%.\\/]*))$")

    self.bpm=nil
    for word in string.gmatch(self.path,'([^_]+)') do
      if string.find(word,"bpm") then
        self.bpm=tonumber(word:match("%d+"))
      end
    end
    if self.bpm~=nil then 
        -- stretch the current smaple to the closest bpm
        self.scale_ratio=100
        for i,v in ipairs({0.5,1,2}) do 
            local scale_ratio = clock.get_tempo()*v/self.bpm
            if scale_ratio<self.scale_ratio then 
                self.scale_ratio=scale_ratio
            end
        end
        local path_new=_path.data.."amenbreak/resampled/"..string.format("%s_scale%2.6f.flac",self.filename,self.scale_ratio)
        if not util.file_exists(path_new) then 
            local cmd=string.format("sox %s %s tempo -m %2.6f",self.path,path_new,self.scale_ratio)
            print(cmd)
            os.execute(cmd)    
        end
        self.path=path_new
        self.pathname,self.filename,self.ext=string.match(self.path,"(.-)([^\\/]-%.?([^%.\\/]*))$")
    end

  engine.load_buffer(self.path)
 
  self.ch,self.samples,self.sample_rate=audio.file_info(self.path)
  if self.samples<10 or self.samples==nil then
    print("ERROR PROCESSING FILE: "..path)
    do return end
  end
  self.duration=self.samples/self.sample_rate
  self.ticks=math.floor(util.round(self.duration/(clock.get_beat_sec()/2)))
  print(string.format("[loop] loaded %s with %d ticks",self.filename,self.ticks))

  self.loaded=true
end

function Loop:emit(beat)
    if not self.loaded then 
        do return end 
    end
    if (not self.playing) and (not self.primed) then 
        do return end 
    end
    if self.primed then 
        self.playing=true 
        self.primed = false 
        engine.loop_stop(self.path)
        engine.loop(self.path,self.db,(beat%self.ticks)/self.ticks,self.oneshot and 0 or 1)
        do return end 
    elseif beat%self.ticks==0 then 
        print("reset loop")
        engine.loop_stop(self.path)
        engine.loop(self.path,self.db,0,self.oneshot and 0 or 1)
    end
end

function Loop:play()
	if not self.oneshot then 
        self.playing=true
        engine.loop(self.path,self.db,0,1)
        self.primed=true
    else
        engine.loop(self.path,self.db,0,0)
    end
end

function Loop:stop()
    self.playing=false
    self.primed=false
    engine.loop_stop(self.path)
end

function Loop:toggle()
if self.playing then 
	self:stop()
elseif not self.primed then 
	self:play()
end
end

return Loop
