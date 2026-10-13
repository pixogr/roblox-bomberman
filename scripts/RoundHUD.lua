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
