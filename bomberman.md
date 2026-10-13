# ROBLOX BOMBERMAN — CLAUDE MCP BUILD BLUEPRINT

## Objective
Build a server-authoritative Bomberman-style Roblox game from the included Luau source files. Use the connected Roblox Studio MCP tools to create or update scripts at the exact locations below. Do not paste this Markdown into a single Roblox Script. Create each file as its own Studio instance.

## Studio hierarchy
| Roblox Studio location | Instance type | Source file |
|---|---|---|
| ServerScriptService.GridManager | ModuleScript | GridManager.lua |
| ServerScriptService.PowerUpSystem | ModuleScript | PowerUpSystem.lua |
| ServerScriptService.BombController | ModuleScript | BombController.lua |
| ServerScriptService.RoundManager | ModuleScript | RoundManager.lua |
| ServerScriptService.BotController | ModuleScript | BotController.lua |
| ServerScriptService.GameServer | Script | GameServer.lua |
| StarterPlayer.StarterPlayerScripts.PlayerInput | LocalScript | PlayerInput.lua |
| StarterPlayer.StarterPlayerScripts.RoundHUD | LocalScript | RoundHUD.lua |
| StarterPlayer.StarterPlayerScripts.CameraController | LocalScript | CameraController.lua |

GameServer automatically creates ReplicatedStorage.PlaceBombEvent and ReplicatedStorage.RoundStatusEvent. Do not create duplicate server handlers.

## Claude MCP execution instructions
1. Connect to Roblox Studio through an MCP server with permission to inspect/create Instances and set script Source.
2. Create or replace the nine script instances in the table, copying the **full source** from the matching file in `scripts/`.
3. Remove old BombEventHandler or any old map/bomb handlers to avoid duplicate listeners.
4. Set Workspace spawn settings as appropriate; RoundManager teleports participants to safe corner tiles.
5. Start a local multiplayer Studio test with two clients. Inspect Output for runtime errors.
6. Verify bomb placement, three-second fuses, wall destruction, chain reactions, power-ups, deaths, HUD, and round transitions. Report test failures instead of claiming success.

## Gameplay and architecture
- 15 × 13 grid, four safe corners, 65% soft wall probability outside safe zones.
- Up to four participants per round; players beyond four spectate (simple waiting state).
- Minimum one player to begin; empty corners (up to four total) are filled with computer-controlled bots (BotController). With 2+ humans it plays head-to-head and bots only top up the remaining slots.
- Bots are "basic survivor" AI: grid-aligned stepping, bomb soft walls only when an off-blast escape exists, and flee active bombs/flames. A bot can win the round.
- 10-second intermission, 120-second round timer, five-second results screen.
- Server derives bomb placement from the player's HumanoidRootPart, not client-supplied coordinates.
- Server validates alive state, proximity to cell center, tile occupancy, bomb limits and event rate.
- 3-second bomb fuse, 0.5-second blast, four directional rays, soft walls stop flames, hard walls block flames, chain reaction.
- BombUp, FireUp, SpeedUp, FullFire power-ups; drops after destroyed walls, after flames clear.
- Desktop Space, controller X, mobile touch button; fixed overhead angled camera and round HUD.
- This is an MVP, not a fully polished production game: bombs are intentionally non-colliding to prevent trapping, and there is no persistent progression, matchmaking, audio, art pipeline or monetization.

## Source files

> Canonical source is the `scripts/*.lua` files (that is what gets pushed into Studio). The inline code blocks below are the original v1 reference and may lag; `BombController.lua`, `RoundManager.lua`, and the new `BotController.lua` have since been updated for single-player + bots.


### BombController.lua

```lua
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
function Bombs.Place(player)
 if player:GetAttribute('AliveInRound')~=true then return end
 local character=player.Character; local root=character and character:FindFirstChild('HumanoidRootPart')
 local h=character and character:FindFirstChildOfClass('Humanoid')
 if not root or not h or h.Health<=0 then return end
 local x,z=Grid.Coordinates(root.Position); if not x then return end
 if (Vector3.new(root.Position.X,0,root.Position.Z)-Grid.Position(x,z)).Magnitude>2.8 then return end
 if Grid.Get(x,z)~=Grid.Type.Empty or active[key(x,z)] then return end
 local id=player.UserId; local n=counts[id] or 0
 if n>=(player:GetAttribute('MaxBombs') or 1) then return end
 local p=Instance.new('Part'); p.Name='Bomb'; p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(3,3,3)
 p.Position=Grid.Position(x,z); p.Anchored=true; p.CanCollide=false; p.Color=Color3.fromRGB(20,20,25); p.Parent=Grid.Folder
 local b={x=x,z=z,userId=id,part=p,radius=math.clamp(player:GetAttribute('BlastRadius') or 2,1,10),generation=generation,exploded=false}
 active[key(x,z)]=b; counts[id]=n+1
 -- Noncolliding bombs avoid trapping the player on placement.
 task.delay(3,function() explode(b) end)
end
Players.PlayerRemoving:Connect(function(player) counts[player.UserId]=nil end)
return Bombs
```


### CameraController.lua

```lua
local RunService=game:GetService('RunService')
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local camera=workspace.CurrentCamera
camera.CameraType=Enum.CameraType.Scriptable
local center=Vector3.new(28,0,24)
RunService:BindToRenderStep('BombermanCamera',Enum.RenderPriority.Camera.Value,function()
 camera.CameraType=Enum.CameraType.Scriptable
 camera.CFrame=CFrame.lookAt(center+Vector3.new(0,75,42),center)
end)
```


### GameServer.lua

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local ServerScriptService=game:GetService('ServerScriptService')
local function event(name)
 local e=ReplicatedStorage:FindFirstChild(name) or Instance.new('RemoteEvent'); e.Name=name; e.Parent=ReplicatedStorage; return e
end
local place=event('PlaceBombEvent'); event('RoundStatusEvent')
local Bombs=require(ServerScriptService.BombController)
local Rounds=require(ServerScriptService.RoundManager)
local last={}
place.OnServerEvent:Connect(function(player)
 local now=os.clock(); if now-(last[player.UserId] or 0)<0.2 then return end
 last[player.UserId]=now; Bombs.Place(player)
end)
game:GetService('Players').PlayerRemoving:Connect(function(p) last[p.UserId]=nil end)
task.spawn(Rounds.Start)
```


### GridManager.lua

```lua
local Grid = {}
Grid.Width, Grid.Height, Grid.TileSize = 15, 13, 4
Grid.Type = {Empty=0, Hard=1, Soft=2}
Grid.Cells = {}
Grid.Walls = {}
Grid.Spawns = {{1,1},{15,1},{1,13},{15,13}}
local folder = workspace:FindFirstChild('BombermanMap') or Instance.new('Folder')
folder.Name = 'BombermanMap'; folder.Parent = workspace
Grid.Folder = folder
local function key(x,z) return x..':'..z end
local function part(name,size,pos,color,parent)
 local p=Instance.new('Part'); p.Name=name; p.Size=size; p.Position=pos; p.Anchored=true; p.Color=color; p.Parent=parent or folder; return p
end
function Grid.Position(x,z) return Vector3.new((x-1)*4,0,(z-1)*4) end
function Grid.Coordinates(pos)
 local x=math.floor(pos.X/4+0.5)+1; local z=math.floor(pos.Z/4+0.5)+1
 if x<1 or x>Grid.Width or z<1 or z>Grid.Height then return nil,nil end
 return x,z
end
function Grid.InBounds(x,z) return x>=1 and x<=Grid.Width and z>=1 and z<=Grid.Height end
function Grid.Get(x,z) return Grid.InBounds(x,z) and Grid.Cells[x] and Grid.Cells[x][z] or nil end
function Grid.DestroySoft(x,z)
 if Grid.Get(x,z)~=Grid.Type.Soft then return false end
 Grid.Cells[x][z]=Grid.Type.Empty
 local k=key(x,z); if Grid.Walls[k] then Grid.Walls[k]:Destroy(); Grid.Walls[k]=nil end
 return true
end
function Grid.Generate()
 folder:ClearAllChildren(); Grid.Cells={}; Grid.Walls={}
 local floor=part('Floor',Vector3.new(60,1,52),Vector3.new(28,-2.5,24),Color3.fromRGB(85,160,95)); floor.Material=Enum.Material.Grass
 local safe={}
 for _,a in ipairs(Grid.Spawns) do
  local x,z=a[1],a[2]
  for _,d in ipairs({{0,0},{1,0},{-1,0},{0,1},{0,-1}}) do safe[key(x+d[1],z+d[2])]=true end
 end
 for x=1,Grid.Width do
  Grid.Cells[x]={}
  for z=1,Grid.Height do
   local t=Grid.Type.Empty
   if x%2==0 and z%2==0 then t=Grid.Type.Hard
   elseif not safe[key(x,z)] and math.random()<0.65 then t=Grid.Type.Soft end
   Grid.Cells[x][z]=t
   if t~=Grid.Type.Empty then
    local wall=part(t==Grid.Type.Hard and 'HardWall' or 'SoftWall',Vector3.new(4,4,4),Grid.Position(x,z),t==Grid.Type.Hard and Color3.fromRGB(75,80,90) or Color3.fromRGB(170,115,65))
    Grid.Walls[key(x,z)]=wall
   end
  end
 end
end
return Grid
```


### PlayerInput.lua

```lua
local CAS=game:GetService('ContextActionService')
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local event=ReplicatedStorage:WaitForChild('PlaceBombEvent')
local last=0
local function place(_,state)
 if state~=Enum.UserInputState.Begin or player:GetAttribute('AliveInRound')~=true then return Enum.ContextActionResult.Pass end
 local now=os.clock(); if now-last>=0.2 then last=now; event:FireServer() end
 return Enum.ContextActionResult.Sink
end
CAS:BindAction('PlaceBomb',place,true,Enum.KeyCode.Space,Enum.KeyCode.ButtonX)
CAS:SetTitle('PlaceBomb','BOMB')
CAS:SetPosition('PlaceBomb',UDim2.new(1,-100,1,-160))
```


### PowerUpSystem.lua

```lua
local Power = {}
local Players=game:GetService('Players')
local Grid=require(script.Parent.GridManager)
local options={{'BombUp',40,Color3.fromRGB(0,140,255)},{'FireUp',40,Color3.fromRGB(255,70,50)},{'SpeedUp',15,Color3.fromRGB(70,240,80)},{'FullFire',5,Color3.fromRGB(255,205,0)}}
function Power.Reset(player)
 player:SetAttribute('MaxBombs',1); player:SetAttribute('BlastRadius',2); player:SetAttribute('SpeedLevel',0)
end
function Power.ApplySpeed(player)
 local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid')
 if h then h.WalkSpeed=16+4*(player:GetAttribute('SpeedLevel') or 0) end
end
function Power.Spawn(x,z)
 if math.random()>0.2 then return end
 local roll=math.random(100); local total=0; local selected
 for _,item in ipairs(options) do total+=item[2]; if roll<=total then selected=item; break end end
 if not selected then return end
 local p=Instance.new('Part'); p.Name='PowerUp_'..selected[1]; p.Shape=Enum.PartType.Ball; p.Size=Vector3.new(2,2,2)
 p.Position=Grid.Position(x,z); p.Anchored=true; p.CanCollide=false; p.Material=Enum.Material.Neon; p.Color=selected[3]; p.Parent=Grid.Folder
 local claimed=false
 p.Touched:Connect(function(hit)
  if claimed then return end
  local character=hit:FindFirstAncestorOfClass('Model'); local player=character and Players:GetPlayerFromCharacter(character)
  if not player or player:GetAttribute('AliveInRound')~=true then return end
  local h=character:FindFirstChildOfClass('Humanoid'); if not h or h.Health<=0 then return end
  claimed=true
  if selected[1]=='BombUp' then player:SetAttribute('MaxBombs',math.min(8,(player:GetAttribute('MaxBombs') or 1)+1))
  elseif selected[1]=='FireUp' then player:SetAttribute('BlastRadius',math.min(10,(player:GetAttribute('BlastRadius') or 2)+1))
  elseif selected[1]=='SpeedUp' then player:SetAttribute('SpeedLevel',math.min(3,(player:GetAttribute('SpeedLevel') or 0)+1)); Power.ApplySpeed(player)
  else player:SetAttribute('BlastRadius',10) end
  p:Destroy()
 end)
end
return Power
```


### RoundHUD.lua

```lua
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local gui=Instance.new('ScreenGui'); gui.Name='BombermanHUD'; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild('PlayerGui')
local label=Instance.new('TextLabel'); label.Size=UDim2.fromOffset(360,54); label.Position=UDim2.new(0.5,-180,0,20)
label.BackgroundColor3=Color3.fromRGB(20,25,35); label.BackgroundTransparency=0.15
label.TextColor3=Color3.new(1,1,1); label.TextScaled=true; label.Font=Enum.Font.GothamBold; label.Text='Waiting for players'; label.Parent=gui
ReplicatedStorage:WaitForChild('RoundStatusEvent').OnClientEvent:Connect(function(state,time,winner)
 if state=='Waiting' then label.Text='Waiting for 2 players'
 elseif state=='Intermission' then label.Text='Next round in '..time..'s'
 elseif state=='Playing' then label.Text='Time: '..time..'s'
 else label.Text='Winner: '..winner end
end)
```


### RoundManager.lua

```lua
local Rounds={}
local Players=game:GetService('Players')
local Grid=require(script.Parent.GridManager)
local Power=require(script.Parent.PowerUpSystem)
local Bombs=require(script.Parent.BombController)
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local status=ReplicatedStorage:WaitForChild('RoundStatusEvent')
local MIN_PLAYERS=2; local ROUND_SECONDS=120; local INTERMISSION=10
local running=false
local function broadcast(state,seconds,winner) status:FireAllClients(state,seconds,winner or '') end
local function spawn(player,index)
 Power.Reset(player)
 player:SetAttribute('AliveInRound',true)
 player:LoadCharacter()
 local char=player.Character or player.CharacterAdded:Wait()
 local root=char:WaitForChild('HumanoidRootPart',5)
 if root then
  local spot=Grid.Spawns[index]; char:PivotTo(CFrame.new(Grid.Position(spot[1],spot[2])+Vector3.new(0,4,0)))
 end
 Power.ApplySpeed(player)
 local humanoid=char:FindFirstChildOfClass('Humanoid')
 if humanoid then humanoid.Died:Connect(function() player:SetAttribute('AliveInRound',false) end) end
end
local function aliveCount()
 local count,last=0,nil
 for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute('AliveInRound')==true then count+=1; last=p end end
 return count,last
end
function Rounds.Start()
 if running then return end; running=true
 Players.PlayerAdded:Connect(function(p) p:SetAttribute('AliveInRound',false) end)
 while true do
  while #Players:GetPlayers()<MIN_PLAYERS do broadcast('Waiting',0); task.wait(2) end
  for t=INTERMISSION,1,-1 do broadcast('Intermission',t); task.wait(1) end
  Bombs.Reset(); Grid.Generate()
  local participants=Players:GetPlayers()
  -- Four unique spawn corners: max four players per match.
  for i,p in ipairs(participants) do
   if i<=4 then spawn(p,i) else p:SetAttribute('AliveInRound',false) end
  end
  local winner=nil
  for t=ROUND_SECONDS,0,-1 do
   local count,last=aliveCount()
   if count<=1 then winner=last; break end
   broadcast('Playing',t); task.wait(1)
  end
  broadcast('Finished',5,winner and winner.DisplayName or 'Draw')
  for _,p in ipairs(Players:GetPlayers()) do p:SetAttribute('AliveInRound',false) end
  Bombs.Reset(); task.wait(5)
 end
end
return Rounds
```


## Acceptance tests
1. Two clients enter: intermission starts, both spawn in separate corners, neither is inside a wall.
2. One player presses Space; bomb spawns at their server-verified grid position.
3. A remote event fired with fake coordinates must not move the bomb (server ignores arguments).
4. Repeated input cannot exceed MaxBombs or bypass the server cooldown.
5. Explosion stops at hard walls, destroys first soft wall in each direction, and does not pass through it.
6. A bomb in a blast path detonates early; its delayed fuse cannot detonate it again.
7. Players in the flame volume die; a sole surviving player wins the round.
8. After a round, all active bombs are reset and a new map is generated.
9. Touch users see BOMB button; controller X and keyboard Space also work.
10. Check Studio Output and run multiplayer tests before publishing.

## Known follow-up improvements
- Add spectator camera, configurable lobby, join-in-progress handling, team modes, spawn protection, dynamic camera scaling, sound/animation, destructible-wall visuals, analytics and DataStore-backed progression.
- Consider more sophisticated bomb collision with owner escape grace and deterministic hitbox/cell damage if this MVP evolves.
- Test character spawning with the specific Roblox avatar rig and Studio place settings.
