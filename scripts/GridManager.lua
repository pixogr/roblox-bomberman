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
