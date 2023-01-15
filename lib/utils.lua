binary={}

-- binary.encode encodes with smallest number first
function binary.encode(num)
  local r={}
  while num>1 do
    table.insert(r,num%2)
    num=math.floor(num/2)
  end
  table.insert(r,1)
  for i=0,6-#r do 
    table.insert(r,0)
  end
  return r
end

function binary.decode(t)
  local num=0

  for i,v in ipairs(t) do
    if v>0 then
      num=num+2^(i-1)
    end
  end
  return math.floor(num)
end


function lines_from(file)
  if not util.file_exists(file) then return {} end
  local lines={}
  for line in io.lines(file) do
    lines[#lines+1]=line
  end
  table.sort(lines)
  return lines
end


function find_files(folder)
  os.execute("find "..folder.."* -print -type f -name '*.flac' | grep 'wav\\|flac' > /tmp/foo")
  os.execute("find "..folder.."* -print -type f -name '*.wav' | grep 'wav\\|flac' >> /tmp/foo")
  os.execute("cat /tmp/foo | sort | uniq > /tmp/files")
  return lines_from("/tmp/files")
end
