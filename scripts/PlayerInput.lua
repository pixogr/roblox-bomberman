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
