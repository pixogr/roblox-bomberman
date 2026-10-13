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
