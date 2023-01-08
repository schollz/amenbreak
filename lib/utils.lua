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