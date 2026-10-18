-- DraculaPowers
-- Dracula's shadow pool and teleport.
--
--  * A pool of shadow mist always sits on the floor under Dracula and follows him.
--  * TELEPORT: a second pool opens where he is going, so players get a warning.
--    A few seconds later he sinks into his pool, and rises out of the new one.
--
-- Other scripts (like GameManager) can send him somewhere:
--     local teleport = game.ServerStorage:WaitForChild("DraculaTeleport")
--     teleport:Invoke(somePosition)   -- a Vector3, a part, or a room Model with a Zone
-- It returns true when he has arrived (false if he was already teleporting).
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
-- TELEPORT
------------------------------------------------------------------
local currentPool = makePool()
local spin = 0
local busy = false

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
	if busy then return false end
	local floorPoint = destinationFor(target)
	if not floorPoint then
		warn("DraculaPowers: couldn't find a floor at that destination")
		return false
	end
	busy = true
	rig:SetAttribute("Teleporting", true) -- BatSwarm hides his circling bats while this is on

	-- 1. the warning: a new pool opens where he will appear
	local nextPool = makePool()
	placePool(nextPool, floorPoint, spin)
	nextPool:ScaleTo(0.02)
	growPool(nextPool, 0.02, 1, 0.6)
	nextPool.Base.Mist:Emit(25)
	task.wait(WARNING_TIME)

	-- 2. he sinks into the pool under him
	humanoid:MoveTo(root.Position) -- stop walking
	root.Anchored = true
	local startCF = root.CFrame
	local depth = standHeight * 2 + 1
	currentPool.Base.Mist:Emit(30)
	batBurst(startCF.Position - Vector3.new(0, standHeight, 0))
	local t = 0
	while t < SINK_TIME do
		t += RunService.Heartbeat:Wait()
		local a = smooth(math.min(t / SINK_TIME, 1))
		root.CFrame = startCF * CFrame.new(0, -depth * a, 0)
		setFade(a)
	end

	-- 3. the old pool closes, he rises out of the new one
	local oldPool = currentPool
	currentPool = nextPool
	task.spawn(function()
		growPool(oldPool, 1, 0.02, 0.6)
		oldPool:Destroy()
	end)
	local facing = startCF - startCF.Position
	local standCF = CFrame.new(floorPoint + Vector3.new(0, standHeight + 0.05, 0)) * facing
	currentPool.Base.Mist:Emit(30)
	batBurst(floorPoint)
	t = 0
	while t < RISE_TIME do
		t += RunService.Heartbeat:Wait()
		local a = smooth(math.min(t / RISE_TIME, 1))
		root.CFrame = standCF * CFrame.new(0, -depth * (1 - a), 0)
		setFade(1 - a)
	end
	setFade(0)
	root.CFrame = standCF
	root.Anchored = false
	busy = false
	rig:SetAttribute("Teleporting", false)
	return true
end

------------------------------------------------------------------
-- THE POOL FOLLOWS HIM
------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	spin = (spin + dt * 0.4) % (math.pi * 2)
	if busy or not root.Parent then return end
	local floorPoint = floorBelow(root.Position, 0)
	if floorPoint then
		placePool(currentPool, floorPoint, spin)
	end
end)

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
		if #rooms > 0 then
			local room = rooms[math.random(1, #rooms)]
			print("Dracula is teleporting to " .. (room:GetAttribute("RoomName") or room.Name))
			teleport(room)
		end
	end
end
