local Bombs={}
local Players=game:GetService('Players')
local Grid=require(script.Parent.GridManager)
local Power=require(script.Parent.PowerUpSystem)
local active={}; local counts={}; local generation=0
local function key(x,z) return x..':'..z end
local directions={{1,0},{-1,0},{0,1},{0,-1}}
local explode
local function flame(x,z)
 local pos=Grid.Position(x,z)
 local f=Instance.new('Part'); f.Name='ExplosionHitbox'; f.Size=Vector3.new(3.8,3.8,3.8); f.Position=pos
 f.Anchored=true; f.CanCollide=false; f.CanTouch=false; f.Material=Enum.Material.Neon; f.Color=Color3.fromRGB(255,105,20); f.Parent=Grid.Folder
 local function hitPlayers()
  local filter=OverlapParams.new(); filter.FilterType=Enum.RaycastFilterType.Exclude; filter.FilterDescendantsInstances={Grid.Folder}
  for _,piece in ipairs(workspace:GetPartBoundsInBox(f.CFrame,f.Size,filter)) do
   local model=piece:FindFirstAncestorOfClass('Model'); local h=model and model:FindFirstChildOfClass('Humanoid')
   if h and h.Health>0 then h.Health=0 end
  end
 end
 hitPlayers()
 local connection=game:GetService('RunService').Heartbeat:Connect(hitPlayers)
 task.delay(0.5,function() connection:Disconnect(); if f.Parent then f:Destroy() end end)
 -- Remove power-ups in the affected cell.
 for _,obj in ipairs(Grid.Folder:GetChildren()) do
  if obj:IsA('BasePart') and obj.Name:sub(1,8)=='PowerUp_' and (obj.Position-pos).Magnitude<0.1 then obj:Destroy() end
 end
end
explode=function(b)
 if b.exploded or b.generation~=generation then return end
 b.exploded=true; active[key(b.x,b.z)]=nil
 counts[b.userId]=math.max(0,(counts[b.userId] or 1)-1)
 if b.part.Parent then b.part:Destroy() end
 flame(b.x,b.z)
 for _,dir in ipairs(directions) do
  for step=1,b.radius do
   local x,z=b.x+dir[1]*step,b.z+dir[2]*step
   local cell=Grid.Get(x,z)
   if cell==nil or cell==Grid.Type.Hard then break end
   if cell==Grid.Type.Soft then
    Grid.DestroySoft(x,z); flame(x,z)
    -- Delay spawning until after the flame ends.
    local g=generation; task.delay(0.55,function() if g==generation and Grid.Get(x,z)==Grid.Type.Empty then Power.Spawn(x,z) end end)
    break
   end
   flame(x,z)
   local other=active[key(x,z)]; if other then task.defer(explode,other) end
  end
 end
end
function Bombs.Reset()
 generation+=1
 for _,b in pairs(active) do if b.part.Parent then b.part:Destroy() end end
 active={}; counts={}
end
-- Core placement shared by human players and computer bots.
function Bombs.PlaceAt(ownerId,x,z,radius,maxBombs)
 if not Grid.InBounds(x,z) then return false end
 if Grid.Get(x,z)~=Grid.Type.Empty or active[key(x,z)] then return false end
 local n=counts[ownerId] or 0
 if n>=(maxBombs or 1) then return false end
 local p=Instance.new('Part'); p.Name='Bomb'; p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(3,3,3)
 p.Position=Grid.Position(x,z); p.Anchored=true; p.CanCollide=false; p.Color=Color3.fromRGB(20,20,25); p.Parent=Grid.Folder
 local b={x=x,z=z,userId=ownerId,part=p,radius=math.clamp(radius or 2,1,10),generation=generation,exploded=false}
 active[key(x,z)]=b; counts[ownerId]=n+1
 -- Noncolliding bombs avoid trapping the owner on placement.
 task.delay(3,function() explode(b) end)
 return true
end
-- True if a cell holds a live flame or sits in an active bomb's blast path. Used by bot AI to flee.
function Bombs.IsCellDangerous(x,z)
 for _,obj in ipairs(Grid.Folder:GetChildren()) do
  if obj:IsA('BasePart') and obj.Name=='ExplosionHitbox' then
   local fx,fz=Grid.Coordinates(obj.Position)
   if fx==x and fz==z then return true end
  end
 end
 for _,b in pairs(active) do
  if b.x==x and b.z==z then return true end
  for _,dir in ipairs(directions) do
   for step=1,b.radius do
    local cx,cz=b.x+dir[1]*step,b.z+dir[2]*step
    local cell=Grid.Get(cx,cz)
    if cell==nil or cell==Grid.Type.Hard then break end
    if cx==x and cz==z then return true end
    if cell==Grid.Type.Soft then break end
   end
  end
 end
 return false
end
-- Grid cells of every live bomb, so bots can retreat away from them.
function Bombs.ActiveBombCells()
 local t={}
 for _,b in pairs(active) do t[#t+1]={b.x,b.z} end
 return t
end
function Bombs.Place(player)
 if player:GetAttribute('AliveInRound')~=true then return end
 local character=player.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
 local h=character and character:FindFirstChildOfClass('Humanoid')
 if not root or not h or h.Health<=0 then return end
 local x,z=Grid.Coordinates(root.Position); if not x then return end
 if (Vector3.new(root.Position.X,0,root.Position.Z)-Grid.Position(x,z)).Magnitude>2.8 then return end
 Bombs.PlaceAt(player.UserId,x,z,player:GetAttribute('BlastRadius') or 2,player:GetAttribute('MaxBombs') or 1)
end
Players.PlayerRemoving:Connect(function(player) counts[player.UserId]=nil end)
return Bombs
