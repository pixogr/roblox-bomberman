local Rounds={}
local Players=game:GetService('Players')
local Grid=require(script.Parent.GridManager)
local Power=require(script.Parent.PowerUpSystem)
local Bombs=require(script.Parent.BombController)
local Bots=require(script.Parent.BotController)
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local status=ReplicatedStorage:WaitForChild('RoundStatusEvent')
local MIN_PLAYERS=1; local ROUND_SECONDS=120; local INTERMISSION=10
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
 for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute('AliveInRound')==true then count+=1; last=p.DisplayName end end
 for _,bot in ipairs(Bots.AliveList()) do if bot.alive then count+=1; last=bot.name end end
 return count,last
end
function Rounds.Start()
 if running then return end; running=true
 Players.PlayerAdded:Connect(function(p) p:SetAttribute('AliveInRound',false) end)
 while true do
  while #Players:GetPlayers()<MIN_PLAYERS do broadcast('Waiting',0); task.wait(2) end
  for t=INTERMISSION,1,-1 do broadcast('Intermission',t); task.wait(1) end
  Bombs.Reset(); Bots.ResetAll(); Grid.Generate()
  local participants=Players:GetPlayers()
  -- Four unique spawn corners: max four players per match.
  for i,p in ipairs(participants) do
   if i<=4 then spawn(p,i) else p:SetAttribute('AliveInRound',false) end
  end
  -- Fill the remaining corners with computer opponents (up to four total).
  local humanCount=math.min(#participants,4)
  for i=humanCount+1,4 do Bots.Spawn(i,'Bot '..(i-humanCount)) end
  local winner=nil
  for t=ROUND_SECONDS,0,-1 do
   local count,last=aliveCount()
   if count<=1 then winner=last; break end
   broadcast('Playing',t); task.wait(1)
  end
  broadcast('Finished',5,winner or 'Draw')
  for _,p in ipairs(Players:GetPlayers()) do p:SetAttribute('AliveInRound',false) end
  Bombs.Reset(); Bots.ResetAll(); task.wait(5)
 end
end
return Rounds
