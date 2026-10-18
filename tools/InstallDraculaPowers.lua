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
-- DraculaPowers
-- Dracula's shadow pool and teleport.
--
--  * A pool of shadow mist always sits on the floor under Dracula and follows him.
--  * TELEPORT: a second pool opens where he is going, so players get a warning.
--    A few seconds later he sinks into his pool, and rises out of the new one.
--
--  * He only appears at NIGHT (follows GameManager's ReplicatedStorage.Phase): at
--    nightfall he rises from a pool in front of his coffin; at dawn he sinks into his
--    pool and stays hidden under his coffin until the next night. His rig gets the
--    attribute Awake = true/false so other scripts know.
--
-- Other scripts (like GameManager) can send him somewhere at night:
--     local teleport = game.ServerStorage:WaitForChild("DraculaTeleport")
--     teleport:Invoke(somePosition)   -- a Vector3, a part, or a room Model with a Zone
-- It returns true when he has arrived (false if he's asleep or already teleporting).
--
-- Looks: if ReplicatedStorage (or ServerStorage) has a model called "ShadowPool" (your
-- Meshy pool) it's used for the pool; otherwise a pool is built from parts.
-- Bats: the BatSwarm LocalScript draws a burst of bats on every player's screen when
-- he teleports (this script tells it where, through ReplicatedStorage.DraculaFX).

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local POOL_SIZE = 10      -- studs across
local WARNING_TIME = 3    -- seconds the destination pool shows before he arrives
local SINK_TIME = 1.2     -- seconds to sink into the floor
local RISE_TIME = 1.2     -- seconds to rise out of the new pool
local DEMO = true         -- for testing: teleport to a random room every DEMO_EVERY seconds
local DEMO_EVERY = 20

local POOL_DARK = Color3.fromRGB(12, 0, 4)
local POOL_RED = Color3.fromRGB(150, 0, 20)

------------------------------------------------------------------
-- FIND DRACULA
------------------------------------------------------------------
local rig = workspace:WaitForChild("NPCs"):WaitForChild("Dracula")
local humanoid = rig:WaitForChild("Humanoid")
local root = rig:WaitForChild("HumanoidRootPart")
local standHeight = humanoid.HipHeight + root.Size.Y / 2 -- root height above the floor

local poolFolder = Instance.new("Folder")
poolFolder.Name = "DraculaPools"
poolFolder.Parent = workspace

-- rays that look for the floor ignore Dracula, the pools, and anything you can walk through
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { rig, poolFolder }
rayParams.RespectCanCollide = true

local function floorBelow(position, searchUp)
	local start = position + Vector3.new(0, searchUp or 2, 0)
	local hit = workspace:Raycast(start, Vector3.new(0, -60, 0), rayParams)
	return hit and hit.Position or nil
end

------------------------------------------------------------------
-- THE POOL
------------------------------------------------------------------
local function decorate(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function disc(parent, name, diameter, thickness, color, material, transparency, y)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(thickness, diameter, diameter) -- a cylinder's length runs along X...
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)) -- ...so lay it flat
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	decorate(p)
	p.Parent = parent
	return p
end

-- builds a pool with its centre at (0,0,0); placePool moves it
local function makePool()
	local pool = Instance.new("Model")
	pool.Name = "ShadowPool"

	-- an invisible flat base: the pool's anchor point, mist comes out of it
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(POOL_SIZE * 0.8, 0.2, POOL_SIZE * 0.8)
	base.CFrame = CFrame.new(0, 0, 0) -- half sunk into the floor; the discs sit on top of it
	base.Transparency = 1
	decorate(base)
	base.Parent = pool
	pool.PrimaryPart = base

	local template = ReplicatedStorage:FindFirstChild("ShadowPool") or ServerStorage:FindFirstChild("ShadowPool")
	if template then
		-- your Meshy pool, scaled to POOL_SIZE and sat on the base
		local look = template:Clone()
		if look:IsA("BasePart") then
			local m = Instance.new("Model")
			look.Parent = m
			look = m
		end
		for _, d in ipairs(look:GetDescendants()) do
			if d:IsA("BasePart") then decorate(d) end
		end
		local cf, size = look:GetBoundingBox()
		look:ScaleTo(look:GetScale() * POOL_SIZE / math.max(size.X, size.Z))
		cf, size = look:GetBoundingBox()
		look:PivotTo(look:GetPivot() + (Vector3.new(0, size.Y / 2, 0) - cf.Position))
		look.Parent = pool
	else
		-- built from parts: dark disc, glowing red rim, a deeper centre
		disc(pool, "Rim", POOL_SIZE, 0.1, POOL_RED, Enum.Material.Neon, 0.35, 0.05)
		disc(pool, "Shadow", POOL_SIZE * 0.9, 0.14, POOL_DARK, Enum.Material.SmoothPlastic, 0.05, 0.07)
		disc(pool, "Depths", POOL_SIZE * 0.5, 0.16, Color3.fromRGB(40, 0, 8), Enum.Material.Neon, 0.55, 0.08)
	end

	-- rising red-black mist
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Color = ColorSequence.new(POOL_RED, POOL_DARK)
	mist.LightEmission = 0.3
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Lifetime = NumberRange.new(1.2, 2)
	mist.Speed = NumberRange.new(1, 3)
	mist.SpreadAngle = Vector2.new(25, 25)
	mist.Rate = 12
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Parent = base

	-- a faint red glow on the floor and on Dracula
	local glow = Instance.new("PointLight")
	glow.Color = POOL_RED
	glow.Range = POOL_SIZE * 1.2
	glow.Brightness = 1.2
	glow.Parent = base

	pool.Parent = poolFolder
	return pool
end

local function placePool(pool, floorPoint, spin)
	pool:PivotTo(CFrame.new(floorPoint + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, spin, 0))
end

-- grows (or shrinks) a pool smoothly between two sizes
local function growPool(pool, from, to, seconds)
	local t = 0
	while t < seconds do
		t += RunService.Heartbeat:Wait()
		local a = math.min(t / seconds, 1)
		pool:ScaleTo(math.max(0.02, from + (to - from) * a))
	end
end

------------------------------------------------------------------
-- BATS: tell every player's BatSwarm script to release a burst of bats
------------------------------------------------------------------
local fx = ReplicatedStorage:FindFirstChild("DraculaFX") or Instance.new("RemoteEvent")
fx.Name = "DraculaFX"
fx.Parent = ReplicatedStorage

local function batBurst(center)
	fx:FireAllClients("BatBurst", center)
end

------------------------------------------------------------------
-- FADE AND MOVE DRACULA
------------------------------------------------------------------
local original = {}
for _, d in ipairs(rig:GetDescendants()) do
	if d:IsA("BasePart") then original[d] = d.Transparency end
end

local function setFade(amount) -- 0 = normal, 1 = invisible
	for part, t in pairs(original) do
		if part.Parent then
			part.Transparency = t + (1 - t) * amount
		end
	end
end

local function smooth(a) return a * a * (3 - 2 * a) end

------------------------------------------------------------------
-- SINKING AND RISING
------------------------------------------------------------------
local currentPool = nil  -- the pool under him (none while he sleeps)
local spin = 0
local busy = false       -- true while he's sinking, rising or teleporting
local awake = false      -- he only walks the castle at night
local DEPTH = standHeight * 2 + 1 -- how far below the floor he goes

-- his resting place: where DraculaRigBuilder stood him, in front of his coffin
local homeCF = root.CFrame
local homeFloor = floorBelow(homeCF.Position, 0) or (homeCF.Position - Vector3.new(0, standHeight, 0))
local homeFacing = homeCF - homeCF.Position

-- a pool opens on the floor at floorPoint
local function openPool(floorPoint)
	local pool = makePool()
	placePool(pool, floorPoint, spin)
	pool:ScaleTo(0.02)
	growPool(pool, 0.02, 1, 0.6)
	pool.Base.Mist:Emit(25)
	return pool
end

-- a pool shrinks away and disappears (in the background)
local function closePool(pool)
	task.spawn(function()
		growPool(pool, 1, 0.02, 0.6)
		pool:Destroy()
	end)
end

-- he sinks into the pool under him and fades out; returns where he was standing
local function sink()
	humanoid:MoveTo(root.Position) -- stop walking
	root.Anchored = true
	local startCF = root.CFrame
	if currentPool then currentPool.Base.Mist:Emit(30) end
	batBurst(startCF.Position - Vector3.new(0, standHeight, 0))
	local t = 0
	while t < SINK_TIME do
		t += RunService.Heartbeat:Wait()
		local a = smooth(math.min(t / SINK_TIME, 1))
		root.CFrame = startCF * CFrame.new(0, -DEPTH * a, 0)
		setFade(a)
	end
	setFade(1)
	return startCF
end

-- he rises out of currentPool at floorPoint, facing the given way
local function rise(floorPoint, facing)
	local standCF = CFrame.new(floorPoint + Vector3.new(0, standHeight + 0.05, 0)) * facing
	root.Anchored = true
	root.CFrame = standCF * CFrame.new(0, -DEPTH, 0)
	if currentPool then currentPool.Base.Mist:Emit(30) end
	batBurst(floorPoint)
	local t = 0
	while t < RISE_TIME do
		t += RunService.Heartbeat:Wait()
		local a = smooth(math.min(t / RISE_TIME, 1))
		root.CFrame = standCF * CFrame.new(0, -DEPTH * (1 - a), 0)
		setFade(1 - a)
	end
	setFade(0)
	root.CFrame = standCF
	root.Anchored = false
end

local function waitUntilFree()
	while busy do task.wait(0.1) end
end

------------------------------------------------------------------
-- DAY AND NIGHT: he wakes at nightfall and returns to his coffin at dawn
------------------------------------------------------------------
-- hidden under his coffin, invisible, not moving
local function hideAtHome()
	setFade(1)
	root.Anchored = true
	root.CFrame = CFrame.new(homeFloor + Vector3.new(0, standHeight, 0)) * homeFacing * CFrame.new(0, -DEPTH, 0)
end

local function wakeUp()
	waitUntilFree()
	if awake then return end
	busy = true
	currentPool = openPool(homeFloor) -- a pool opens in front of his coffin...
	task.wait(1.5)
	rise(homeFloor, homeFacing)         -- ...and he rises out of it
	awake = true
	rig:SetAttribute("Awake", true)
	busy = false
	print("Night falls. Dracula has awoken.")
end

local function goToSleep()
	waitUntilFree()
	if not awake then return end
	busy = true
	awake = false
	rig:SetAttribute("Awake", false) -- BatSwarm hides his bats
	sink()                            -- he sinks into his pool wherever he is...
	if currentPool then
		closePool(currentPool)
		currentPool = nil
	end
	hideAtHome()                      -- ...and waits under his coffin for the next night
	busy = false
	print("Dawn. Dracula has returned to his coffin.")
end

------------------------------------------------------------------
-- TELEPORT (night only)
------------------------------------------------------------------
-- turns whatever we were given into a spot on the floor
local function destinationFor(target)
	if typeof(target) == "Vector3" then
		return floorBelow(target, 4)
	end
	if typeof(target) == "Instance" then
		local zone = target:IsA("Model") and target:FindFirstChild("Zone") or nil
		if zone then
			local bottom = zone.Position - Vector3.new(0, zone.Size.Y / 2, 0)
			return floorBelow(bottom, 6)
		end
		if target:IsA("BasePart") then return floorBelow(target.Position, 4) end
		if target:IsA("Model") then return floorBelow(target:GetPivot().Position, 4) end
	end
	return nil
end

local function teleport(target)
	if busy or not awake then return false end
	local floorPoint = destinationFor(target)
	if not floorPoint then
		warn("DraculaPowers: couldn't find a floor at that destination")
		return false
	end
	busy = true
	rig:SetAttribute("Teleporting", true) -- BatSwarm hides his circling bats while this is on

	-- 1. the warning: a new pool opens where he will appear
	local nextPool = openPool(floorPoint)
	task.wait(WARNING_TIME)

	-- 2. he sinks into the pool under him
	local startCF = sink()

	-- 3. the old pool closes, he rises out of the new one
	if currentPool then closePool(currentPool) end
	currentPool = nextPool
	rise(floorPoint, startCF - startCF.Position)

	busy = false
	rig:SetAttribute("Teleporting", false)
	return true
end

------------------------------------------------------------------
-- THE POOL FOLLOWS HIM
------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	spin = (spin + dt * 0.4) % (math.pi * 2)
	if busy or not awake or not currentPool or not root.Parent then return end
	local floorPoint = floorBelow(root.Position, 0)
	if floorPoint then
		placePool(currentPool, floorPoint, spin)
	end
end)

------------------------------------------------------------------
-- FOLLOW GAMEMANAGER'S CLOCK (ReplicatedStorage.Phase = "Day" / "Night")
------------------------------------------------------------------
rig:SetAttribute("Awake", false)
rig:SetAttribute("Teleporting", false)
hideAtHome() -- he starts asleep

local phase = ReplicatedStorage:WaitForChild("Phase", 10)
local function onPhase()
	if phase and phase.Value ~= "Night" then
		task.spawn(goToSleep)
	else
		task.spawn(wakeUp)
	end
end
if phase then
	phase.Changed:Connect(onPhase)
else
	warn("DraculaPowers: no ReplicatedStorage.Phase (is GameManager running?). Dracula stays awake for testing.")
end
onPhase()

------------------------------------------------------------------
-- LET OTHER SCRIPTS USE IT
------------------------------------------------------------------
local bindable = ServerStorage:FindFirstChild("DraculaTeleport") or Instance.new("BindableFunction")
bindable.Name = "DraculaTeleport"
bindable.OnInvoke = teleport
bindable.Parent = ServerStorage

------------------------------------------------------------------
-- DEMO: hop to a random room so you can see it working
------------------------------------------------------------------
if DEMO then
	local castle = workspace:WaitForChild("DraculaCastle")
	local rooms = {}
	for _, d in ipairs(castle:GetDescendants()) do
		if d:IsA("Model") and d:FindFirstChild("Zone") then
			local kind = d:GetAttribute("RoomKind")
			if kind and kind ~= "Stairs" then table.insert(rooms, d) end
		end
	end
	while rig.Parent do
		task.wait(DEMO_EVERY)
		if awake and #rooms > 0 then -- only at night
			local room = rooms[math.random(1, #rooms)]
			print("Dracula is teleporting to " .. (room:GetAttribute("RoomName") or room.Name))
			teleport(room)
		end
	end
end
]===])

install(StarterPlayer:WaitForChild("StarterPlayerScripts"), "LocalScript", "BatSwarm", [===[
-- BatSwarm
-- Bats with flapping wings, drawn on each player's own screen (smooth, and no work for
-- the server):
--   * a few bats circle Dracula while he's awake (at night); they vanish while he teleports
--   * at night, bats swoop up and down every corridor near the ceiling
--   * at night, bats circle the spires of the castle towers outside
--   * a burst of bats flies out of the shadow pools when Dracula teleports
--     (DraculaPowers tells us when, through ReplicatedStorage.DraculaFX)
--
-- The bat's look: if ReplicatedStorage has a Model called "Bat" (made by
-- tools/BatSetup.lua from your Meshy bat) it's used. Its parts should be called
-- Body, LeftWing and RightWing so the wings can flap. Otherwise a simple bat is built.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local BAT_SIZE = 3              -- wingspan in studs
local DRACULA_BATS = 4          -- circling Dracula
local CORRIDOR_BATS = 2         -- per floor, at night only
local TOWER_BATS = 3            -- per tower
local BURST_BATS = 6            -- each time he teleports
local FLAP_ANGLE = math.rad(50) -- how far the wings move up and down
local FLAP_SPEED = 14           -- how fast they flap

local folder = Instance.new("Folder")
folder.Name = "Bats"
folder.Parent = workspace

------------------------------------------------------------------
-- MAKING A BAT
------------------------------------------------------------------
local function quiet(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

-- a simple bat from parts, facing -Z with wings along X
local function simpleBat()
	local bat = Instance.new("Model")
	bat.Name = "Bat"
	local black = Color3.fromRGB(20, 16, 18)
	local function part(name, shape, size, pos, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = CFrame.new(pos)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		quiet(p)
		p.Parent = bat
		return p
	end
	local body = part("Body", Enum.PartType.Ball, Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 0, 0), black)
	part("Head", Enum.PartType.Ball, Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 0.15, -0.45), black)
	part("Eye", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1), Vector3.new(-0.1, 0.22, -0.68), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	part("Eye", Enum.PartType.Ball, Vector3.new(0.1, 0.1, 0.1), Vector3.new(0.1, 0.22, -0.68), Color3.fromRGB(255, 30, 30), Enum.Material.Neon)
	part("LeftWing", Enum.PartType.Block, Vector3.new(1.3, 0.05, 0.8), Vector3.new(-0.95, 0.05, 0), black)
	part("RightWing", Enum.PartType.Block, Vector3.new(1.3, 0.05, 0.8), Vector3.new(0.95, 0.05, 0), black)
	bat.PrimaryPart = body
	return bat
end

local function batTemplate()
	local custom = ReplicatedStorage:FindFirstChild("Bat")
	local bat = custom and custom:Clone() or simpleBat()
	for _, d in ipairs(bat:GetDescendants()) do
		if d:IsA("BasePart") then quiet(d) end
	end
	if not bat.PrimaryPart then
		bat.PrimaryPart = bat:FindFirstChild("Body", true) or bat:FindFirstChildWhichIsA("BasePart", true)
	end
	local _, size = bat:GetBoundingBox()
	bat:ScaleTo(bat:GetScale() * BAT_SIZE / math.max(size.X, size.Z))
	bat:PivotTo(CFrame.new())
	return bat
end
local TEMPLATE = batTemplate()

-- a bat we can move and flap
local function newBat()
	local model = TEMPLATE:Clone()
	local frame = model:GetPivot() -- the bat's own frame: facing -Z, wings along X
	local bat = { model = model, parts = {}, phase = math.random() * 10 }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- where each part sits relative to the bat, so we can move them together
			table.insert(bat.parts, { part = d, offset = frame:ToObjectSpace(d.CFrame) })
		end
	end
	for _, info in ipairs(bat.parts) do
		local name = info.part.Name
		if name == "LeftWing" or name == "RightWing" then
			local cf, size = info.offset, info.part.Size
			local side = cf.Position.X >= 0 and 1 or -1
			-- how far the wing reaches sideways (works even if the part is turned)
			local reach = math.abs(cf.RightVector.X) * size.X / 2 + math.abs(cf.UpVector.X) * size.Y / 2
				+ math.abs(cf.LookVector.X) * size.Z / 2
			-- the hinge is the wing's inner edge, next to the body
			info.hinge = Vector3.new(cf.Position.X - side * reach, cf.Position.Y, cf.Position.Z)
			info.side = side
		end
	end
	model.Parent = folder
	return bat
end

local function setVisible(bat, visible)
	if bat.visible == visible then return end
	bat.visible = visible
	for _, info in ipairs(bat.parts) do
		info.base = info.base or info.part.Transparency
		info.part.Transparency = visible and info.base or 1
	end
end

-- puts the bat at `pos`, facing along `dir`, wings at the right point of the flap
local function placeBat(bat, pos, dir, clock)
	if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
	local bodyCF = CFrame.lookAt(pos, pos + dir)
	local flap = math.sin(clock * FLAP_SPEED + bat.phase) * FLAP_ANGLE
	for _, info in ipairs(bat.parts) do
		if info.hinge then
			local h = info.hinge
			info.part.CFrame = bodyCF * CFrame.new(h) * CFrame.Angles(0, 0, flap * info.side) * CFrame.new(-h) * info.offset
		else
			info.part.CFrame = bodyCF * info.offset
		end
	end
end

------------------------------------------------------------------
-- 1. BATS AROUND DRACULA
------------------------------------------------------------------
local draculaBats = {}
for i = 1, DRACULA_BATS do
	local bat = newBat()
	bat.radius = 5 + math.random() * 3
	bat.speed = (0.9 + math.random() * 0.6) * (i % 2 == 0 and 1 or -1)
	bat.height = 5 + math.random() * 3
	bat.angle = (i / DRACULA_BATS) * math.pi * 2
	table.insert(draculaBats, bat)
end

local function draculaRoot()
	local npcs = workspace:FindFirstChild("NPCs")
	local rig = npcs and npcs:FindFirstChild("Dracula")
	return rig, rig and rig:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------
-- 2. BATS IN THE CORRIDORS (night only)
------------------------------------------------------------------
local corridorBats = {}
local handled = {} -- corridors and towers that already have bats
local function setupCorridors()
	local castle = workspace:FindFirstChild("DraculaCastle")
	if not castle then return end
	for _, d in ipairs(castle:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("RoomKind") == "Corridor" and d:FindFirstChild("Zone") and not handled[d] then
			handled[d] = true
			local zone = d.Zone
			for _ = 1, CORRIDOR_BATS do
				local bat = newBat()
				bat.zone = zone
				bat.speed = 0.25 + math.random() * 0.2
				table.insert(corridorBats, bat)
			end
		end
	end
end

local function isNight()
	local phase = ReplicatedStorage:FindFirstChild("Phase") -- made by GameManager: "Day" / "Night"
	return phase == nil or phase.Value == "Night"
end

------------------------------------------------------------------
-- 3. BATS AROUND THE TOWERS
------------------------------------------------------------------
local towerBats = {}
local function setupTowers()
	local castle = workspace:FindFirstChild("DraculaCastle")
	local exterior = castle and castle:FindFirstChild("Exterior")
	if not exterior then return end
	for _, tower in ipairs(exterior:GetChildren()) do
		if tower:IsA("Model") and tower.Name == "Tower" and not handled[tower] then
			handled[tower] = true
			local cf, size = tower:GetBoundingBox()
			for i = 1, TOWER_BATS do
				local bat = newBat()
				bat.center = cf.Position + Vector3.new(0, size.Y / 2 - 12, 0)
				bat.radius = 14 + math.random() * 8
				bat.speed = (0.35 + math.random() * 0.25) * (i % 2 == 0 and 1 or -1)
				bat.height = math.random() * 10
				bat.angle = math.random() * math.pi * 2
				table.insert(towerBats, bat)
			end
		end
	end
end

------------------------------------------------------------------
-- 4. BURSTS WHEN DRACULA TELEPORTS
------------------------------------------------------------------
local bursts = {}
task.spawn(function()
	local fx = ReplicatedStorage:WaitForChild("DraculaFX") -- made by the DraculaPowers script
	fx.OnClientEvent:Connect(function(kind, center)
		if kind ~= "BatBurst" then return end
		for i = 1, BURST_BATS do
			local bat = newBat()
			local angle = (i / BURST_BATS) * math.pi * 2 + math.random()
			bat.from = center + Vector3.new(0, 2, 0)
			bat.to = center + Vector3.new(math.cos(angle) * 16, 10 + math.random() * 5, math.sin(angle) * 16)
			bat.age = 0
			bat.life = 1.4 + math.random() * 0.4
			table.insert(bursts, bat)
		end
	end)
end)

------------------------------------------------------------------
-- EVERY FRAME: MOVE ALL THE BATS
------------------------------------------------------------------
-- parts of the castle far from the player may load in later, so look again now and then
task.spawn(function()
	while true do
		setupCorridors()
		setupTowers()
		task.wait(5)
	end
end)
local clock = 0

RunService.RenderStepped:Connect(function(dt)
	clock += dt

	-- around Dracula
	local rig, root = draculaRoot()
	-- only while he's awake (night) and not in the middle of a teleport
	local show = root ~= nil and rig:GetAttribute("Awake") == true and not rig:GetAttribute("Teleporting")
	for _, bat in ipairs(draculaBats) do
		setVisible(bat, show)
		if show then
			bat.angle += bat.speed * dt
			local bob = math.sin(clock * 1.7 + bat.phase) * 0.8
			local offset = Vector3.new(math.cos(bat.angle) * bat.radius, bat.height + bob - 3, math.sin(bat.angle) * bat.radius)
			local tangent = Vector3.new(-math.sin(bat.angle), 0, math.cos(bat.angle)) * math.sign(bat.speed)
			placeBat(bat, root.Position + offset, tangent, clock)
		end
	end

	-- corridors (night only)
	local night = isNight()
	for _, bat in ipairs(corridorBats) do
		local here = night and bat.zone.Parent ~= nil
		setVisible(bat, here)
		if here then
			local z = bat.zone
			local halfLength = z.Size.X / 2 - 6
			local t = clock * bat.speed + bat.phase
			local x = math.sin(t) * halfLength
			local vx = math.cos(t)
			local pos = z.Position + Vector3.new(x, z.Size.Y / 2 - 4 + math.sin(t * 3) * 1.2, math.sin(t * 2.3) * 3)
			placeBat(bat, pos, Vector3.new(vx, 0, math.cos(t * 2.3) * 0.5), clock)
		end
	end

	-- towers (night only)
	for _, bat in ipairs(towerBats) do
		setVisible(bat, night)
		bat.angle += bat.speed * dt
		local pos = bat.center + Vector3.new(math.cos(bat.angle) * bat.radius, bat.height + math.sin(clock + bat.phase) * 2, math.sin(bat.angle) * bat.radius)
		local tangent = Vector3.new(-math.sin(bat.angle), 0, math.cos(bat.angle)) * math.sign(bat.speed)
		placeBat(bat, pos, tangent, clock)
	end

	-- bursts
	for i = #bursts, 1, -1 do
		local bat = bursts[i]
		bat.age += dt
		local a = math.min(bat.age / bat.life, 0.98)
		local pos = bat.from:Lerp(bat.to, a)
		placeBat(bat, pos, bat.to - bat.from, clock)
		if bat.age >= bat.life then
			bat.model:Destroy()
			table.remove(bursts, i)
		end
	end
end)
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
