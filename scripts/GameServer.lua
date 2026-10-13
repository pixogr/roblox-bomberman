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
