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
