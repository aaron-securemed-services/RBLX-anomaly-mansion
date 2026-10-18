--[[
=======================================================================
  INSTALL DRACULA POWERS  -  Dracula's BnB
=======================================================================
  Sets up Dracula's shadow pool, teleport and bats in one go:
    * your Meshy bat and shadow pool (from DraculaFX.glb), if imported
    * ServerScriptService > DraculaPowers  (pool under him + teleport)
    * StarterPlayerScripts > BatSwarm       (flapping bats, on each screen)
    * turns off the old back-and-forth pacing demo

  HOW TO USE
    1. Stop Play mode. Dracula must already be built (DraculaRigBuilder.lua).
    2. (Optional) Import 3D -> DraculaFX.glb -> Import, and click it once.
       Without it you get the stand-in bat and pool made from parts.
    3. Paste this whole file into the Command Bar and click Run.

  The script sources are copies of src/server/DraculaPowers.server.lua and
  src/client/BatSwarm.client.lua in the repo.
=======================================================================
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Selection = game:GetService("Selection")

------------------------------------------------------------------------
-- 1. YOUR MESHY BAT AND SHADOW POOL (if imported)
------------------------------------------------------------------------
-- looks for a part called <name> in the selection first, then anywhere in Workspace
local function findPart(name)
	for _, root in ipairs({ Selection:Get()[1], workspace }) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("BasePart") and (d.Name == name or string.sub(d.Name, 1, #name + 1) == name .. ".") then
					return d
				end
			end
		end
	end
	return nil
end

-- turns the pieces so `up` points up and `front` points -Z, centred on the origin
local function straighten(pieces, center, up, front)
	up = up.Unit
	if not front then
		front = math.abs(up.X) < 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	end
	front = (front - up * front:Dot(up)).Unit
	local right = front:Cross(up)
	local now = CFrame.fromMatrix(center, right, up, -front)
	local fix = now:Inverse()
	for _, p in ipairs(pieces) do
		p.CFrame = fix * p.CFrame
	end
end

local function quiet(p)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
end

local imported = {}
local batBody = findPart("BAT_Body")
if batBody then
	local left, right = findPart("BAT_LeftWing"), findPart("BAT_RightWing")
	local c, f, u = findPart("BAT_M_Center"), findPart("BAT_M_Front"), findPart("BAT_M_Up")
	if left and right and c and f and u then
		table.insert(imported, batBody.Parent)
		straighten({ batBody, left, right }, c.Position, u.Position - c.Position, f.Position - c.Position)
		local old = ReplicatedStorage:FindFirstChild("Bat")
		if old then old:Destroy() end
		local bat = Instance.new("Model")
		bat.Name = "Bat"
		for p, name in pairs({ [batBody] = "Body", [left] = "LeftWing", [right] = "RightWing" }) do
			p.Name = name
			quiet(p)
			p.Parent = bat
		end
		bat.PrimaryPart = batBody
		batBody.PivotOffset = batBody.CFrame:Inverse() -- the bat's pivot: the origin, facing -Z
		bat.Parent = ReplicatedStorage
		for _, m in ipairs({ c, f, u }) do m:Destroy() end
		print("Installed your Meshy bat (ReplicatedStorage > Bat)")
	else
		warn("Found BAT_Body but not all the bat pieces; using the stand-in bat")
	end
end

local poolPart = findPart("POOL_Pool")
if poolPart then
	local c, u = findPart("POOL_M_Center"), findPart("POOL_M_Up")
	if c and u then
		table.insert(imported, poolPart.Parent)
		straighten({ poolPart }, c.Position, u.Position - c.Position, nil)
		local old = ReplicatedStorage:FindFirstChild("ShadowPool")
		if old then old:Destroy() end
		local pool = Instance.new("Model")
		pool.Name = "ShadowPool"
		poolPart.Name = "Pool"
		quiet(poolPart)
		poolPart.Parent = pool
		pool.PrimaryPart = poolPart
		poolPart.PivotOffset = poolPart.CFrame:Inverse()
		pool.Parent = ReplicatedStorage
		for _, m in ipairs({ c, u }) do m:Destroy() end
		print("Installed your Meshy shadow pool (ReplicatedStorage > ShadowPool)")
	else
		warn("Found POOL_Pool but not its markers; using the stand-in pool")
	end
end

-- remove what's left of the imported model
for _, container in ipairs(imported) do
	if container and container.Parent and container ~= workspace and #container:GetDescendants() == 0 then
		container:Destroy()
	end
end

------------------------------------------------------------------------
-- 2. THE SCRIPTS
------------------------------------------------------------------------
local function install(parent, className, name, source)
	local old = parent:FindFirstChild(name)
	if old then old:Destroy() end
	local s = Instance.new(className)
	s.Name = name
	s.Source = source
	s.Parent = parent
end

install(ServerScriptService, "Script", "DraculaPowers", [===[
{{POWERS}}
]===])

install(StarterPlayer:WaitForChild("StarterPlayerScripts"), "LocalScript", "BatSwarm", [===[
{{BATS}}
]===])

------------------------------------------------------------------------
-- 3. TURN OFF THE OLD PACING DEMO (the teleport demo replaces it)
------------------------------------------------------------------------
local npcs = workspace:FindFirstChild("NPCs")
local dracula = npcs and npcs:FindFirstChild("Dracula")
local animate = dracula and dracula:FindFirstChild("DraculaAnimate")
if animate then
	animate.Source = string.gsub(animate.Source, "local DEMO_PACING = true", "local DEMO_PACING = false")
end
if not dracula then
	warn("No Workspace > NPCs > Dracula yet. Run DraculaRigBuilder.lua first, or the powers script will wait for him.")
end

print("Dracula's powers installed! He sleeps by day. At nightfall he rises from a shadow pool by his coffin, bats circle him, and every 20 seconds he teleports to a random room. At dawn he sinks back into his pool.")
