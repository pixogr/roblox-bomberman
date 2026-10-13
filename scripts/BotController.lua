local Bots={}
local Grid=require(script.Parent.GridManager)
local Bombs=require(script.Parent.BombController)
local active={}
local generation=0
local STEP_TIME=0.4
local directions={{1,0},{-1,0},{0,1},{0,-1}}
local colors={Color3.fromRGB(230,80,80),Color3.fromRGB(80,120,230),Color3.fromRGB(80,200,120),Color3.fromRGB(220,200,70)}

local function makeModel(name,color)
 local model=Instance.new('Model'); model.Name=name
 local hrp=Instance.new('Part'); hrp.Name='HumanoidRootPart'; hrp.Size=Vector3.new(2.6,2.6,2.6)
 hrp.Anchored=true; hrp.CanCollide=false; hrp.Color=color; hrp.Material=Enum.Material.SmoothPlastic; hrp.Position=Vector3.new(0,0,0); hrp.Parent=model
 local head=Instance.new('Part'); head.Name='Head'; head.Shape=Enum.PartType.Ball; head.Size=Vector3.new(1.8,1.8,1.8)
 head.Anchored=true; head.CanCollide=false; head.Color=color; head.Material=Enum.Material.SmoothPlastic; head.Position=Vector3.new(0,2.2,0); head.Parent=model
 model.PrimaryPart=hrp
 local humanoid=Instance.new('Humanoid'); humanoid.RequiresNeck=false; humanoid.BreakJointsOnDeath=false
 humanoid.MaxHealth=100; humanoid.Health=100; humanoid.Parent=model
 return model,humanoid
end

local function moveTo(model,x,z)
 if model and model.PrimaryPart then model:PivotTo(CFrame.new(Grid.Position(x,z))) end
end

local function emptyNeighbors(x,z)
 local list={}
 for _,d in ipairs(directions) do
  local nx,nz=x+d[1],z+d[2]
  if Grid.Get(nx,nz)==Grid.Type.Empty then list[#list+1]={nx,nz} end
 end
 return list
end

local function safeNeighbors(x,z)
 local list={}
 for _,d in ipairs(directions) do
  local nx,nz=x+d[1],z+d[2]
  if Grid.Get(nx,nz)==Grid.Type.Empty and not Bombs.IsCellDangerous(nx,nz) then list[#list+1]={nx,nz} end
 end
 return list
end

local function adjacentSoft(x,z)
 for _,d in ipairs(directions) do
  if Grid.Get(x+d[1],z+d[2])==Grid.Type.Soft then return true end
 end
 return false
end

local function cellSafe(x,z)
 return Grid.Get(x,z)==Grid.Type.Empty and not Bombs.IsCellDangerous(x,z)
end

-- Directions perpendicular to d, used to find a refuge off the blast cross.
local function perp(d)
 if d[1]~=0 then return {{0,1},{0,-1}} else return {{1,0},{-1,0}} end
end

-- Only bomb if, from some adjacent empty cell, the bot can duck OFF the blast cross
-- (a perpendicular empty tile) or run straight past the blast radius to a clear tile.
local function hasEscape(x,z)
 for _,d in ipairs(directions) do
  local nx,nz=x+d[1],z+d[2]
  if Grid.Get(nx,nz)==Grid.Type.Empty then
   for _,pd in ipairs(perp(d)) do
    if Grid.Get(nx+pd[1],nz+pd[2])==Grid.Type.Empty then return true end
   end
   if Grid.Get(x+d[1]*2,z+d[2]*2)==Grid.Type.Empty and Grid.Get(x+d[1]*3,z+d[2]*3)==Grid.Type.Empty then return true end
  end
 end
 return false
end

-- Step toward safety: an immediately safe tile wins; otherwise a cell that neighbours a safe
-- tile (1-step lookahead); ties broken by distance from the nearest live bomb.
local function fleeStep(bot)
 local cells=Bombs.ActiveBombCells()
 local best,bestScore=nil,-math.huge
 for _,c in ipairs(emptyNeighbors(bot.gx,bot.gz)) do
  local dmin=9
  for _,bc in ipairs(cells) do dmin=math.min(dmin,math.abs(bc[1]-c[1])+math.abs(bc[2]-c[2])) end
  local score=dmin
  if cellSafe(c[1],c[2]) then
   score+=1000
  else
   for _,d in ipairs(directions) do if cellSafe(c[1]+d[1],c[2]+d[2]) then score+=200 break end end
  end
  if score>bestScore then bestScore=score; best=c end
 end
 if best then bot.gx,bot.gz=best[1],best[2]; moveTo(bot.model,bot.gx,bot.gz) end
end

function Bots.Spawn(index,name)
 local spot=Grid.Spawns[index]; if not spot then return end
 local color=colors[((index-1)%#colors)+1]
 local model,humanoid=makeModel(name,color)
 local gx,gz=spot[1],spot[2]
 moveTo(model,gx,gz)
 model.Parent=workspace
 local bot={id=-index,model=model,humanoid=humanoid,gx=gx,gz=gz,alive=true,name=name,radius=2,maxBombs=1}
 active[#active+1]=bot
 local myGen=generation
 humanoid.Died:Connect(function()
  bot.alive=false
  task.delay(0.4,function() if bot.model then bot.model:Destroy(); bot.model=nil end end)
 end)
 task.spawn(function()
  while bot.alive and myGen==generation and bot.model and bot.model.Parent do
   task.wait(STEP_TIME+math.random()*0.2)
   if not bot.alive or myGen~=generation then break end
   if Bombs.IsCellDangerous(bot.gx,bot.gz) then
    fleeStep(bot)
   elseif adjacentSoft(bot.gx,bot.gz) and hasEscape(bot.gx,bot.gz) and math.random()<0.7 then
    if Bombs.PlaceAt(bot.id,bot.gx,bot.gz,bot.radius,bot.maxBombs) then fleeStep(bot) end
   else
    local opts=safeNeighbors(bot.gx,bot.gz)
    if #opts==0 then opts=emptyNeighbors(bot.gx,bot.gz) end
    if #opts>0 then local c=opts[math.random(#opts)]; bot.gx,bot.gz=c[1],c[2]; moveTo(bot.model,bot.gx,bot.gz) end
   end
  end
 end)
 return bot
end

function Bots.AliveList() return active end

function Bots.ResetAll()
 generation+=1
 for _,bot in ipairs(active) do bot.alive=false; if bot.model then bot.model:Destroy(); bot.model=nil end end
 active={}
end

return Bots
