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
