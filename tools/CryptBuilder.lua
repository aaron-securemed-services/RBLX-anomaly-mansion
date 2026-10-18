--[[
=======================================================================
  CRYPT BUILDER  -  Dracula's BnB
=======================================================================
  Furnishes Dracula's Crypt (run CastleBuilder.lua first):
    * finds your coffin and MOVES it into the Crypt model
    * makes it bigger (COFFIN_SCALE times its current size)
    * stands it against the back wall, directly opposite the door and
      facing it, on a low stone platform
    * a red runner from the crypt door to the platform
    * two iron candle stands beside the platform
    * hidden markers for game scripts:
        CoffinSpot    in front of the coffin, where Dracula steps out
        DraculaSpawn  on the floor in front of the platform

  The coffin keeps whichever way up you have it (standing, lying, ...).
  This script only turns it around to face the door, so stand it up
  yourself first if you want it upright.

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Have your coffin model somewhere in the place. This script looks
       for a Model called "DraculaCoffin" first inside the castle
       (it gets MOVED into the Crypt), then anything with "coffin" in
       its name in ServerStorage, ReplicatedStorage or Workspace (it
       gets COPIED, so the original stays where it is).
    3. Open the Command Bar, paste this WHOLE file in and click Run.
       You'll see "Crypt built!" in the Output window.

  Running it again rebuilds the platform and candles, and re-places
  the coffin without making it any bigger. (Changing COFFIN_SCALE and
  running again changes its size, because the size is always worked out
  from the coffin's original size, which is remembered.)

  SETTINGS below let you change the size and which way it faces.
=======================================================================
]]

------------------------------------------------------------------------
-- 1. SETTINGS
------------------------------------------------------------------------
local COFFIN_SCALE = 2     -- times bigger than the coffin's size when this first runs
local TURN_COFFIN = 0      -- if the coffin faces the wrong way, try 90, 180 or 270 here
local PLATFORM_HEIGHT = 1  -- studs. How high the stone platform is.
local WALL_GAP = 0.3       -- studs of space between the coffin's back and the wall

local COLORS = {
	Slate  = Color3.fromRGB(75, 72, 70),
	Stone  = Color3.fromRGB(92, 88, 84),
	Iron   = Color3.fromRGB(32, 30, 30),
	Cream  = Color3.fromRGB(236, 226, 205),
	Carpet = Color3.fromRGB(110, 16, 24),
	Gold   = Color3.fromRGB(176, 141, 62),
	Flame  = Color3.fromRGB(255, 170, 70),
	Light  = Color3.fromRGB(255, 160, 85),
}

------------------------------------------------------------------------
-- 2. FIND THE CRYPT AND THE COFFIN
------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local castle = workspace:FindFirstChild("DraculaCastle")
if not castle then
	error("No DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
end
local crypt = castle:FindFirstChild("Crypt", true)
local zone = crypt and crypt:FindFirstChild("Zone")
if not zone then
	error("Couldn't find the Crypt (or its Zone) inside DraculaCastle.")
end

-- Finds the coffin. Returns the coffin and true if it's a copy
-- (the original stays where it is), or false if we're moving the original.
local function findCoffin()
	-- 1. Already in the crypt (from an earlier run, or one the old crypt builder made).
	-- We only want the Model, not the mesh inside it that has the same name.
	for _, object in ipairs(crypt:GetDescendants()) do
		if object:IsA("Model") and object.Name == "DraculaCoffin" then
			return object, false
		end
	end

	-- 2. Somewhere else in the castle (like a CastleFurniture folder): we'll move it
	for _, object in ipairs(castle:GetDescendants()) do
		if object:IsA("Model") and object.Name == "DraculaCoffin" then
			return object, false
		end
	end

	-- 3. Outside the castle (like ServerStorage): we'll copy it
	for _, place in ipairs({ game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), workspace }) do
		for _, object in ipairs(place:GetDescendants()) do
			local isCoffin = (object:IsA("Model") or object:IsA("MeshPart"))
				and string.find(string.lower(object.Name), "coffin") ~= nil
			if isCoffin and not object:IsDescendantOf(castle) then
				return object, true
			end
		end
	end
	return nil, false
end

local source, isCopy = findCoffin()
if not source then
	error("Couldn't find your coffin. Put a model called 'DraculaCoffin' anywhere in the place.")
end
print("Using coffin: " .. source:GetFullName() .. (isCopy and " (copying it)" or " (moving it into the Crypt)"))

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Build Crypt") end)

------------------------------------------------------------------------
-- 3. TAKE THE COFFIN, THEN CLEAR OUT THE OLD CRYPT FURNITURE
-- We take the coffin first, because an older version of this script
-- kept it inside a folder that gets deleted below.
------------------------------------------------------------------------
local coffin
if isCopy then
	coffin = source:Clone()
	if coffin:IsA("BasePart") then
		-- a lone mesh: wrap it in a Model so we can move and scale it as one
		local wrapper = Instance.new("Model")
		coffin.Parent = wrapper
		wrapper.PrimaryPart = coffin
		coffin = wrapper
	end
else
	coffin = source
end
coffin.Name = "DraculaCoffin"
coffin.Parent = crypt                  -- this is the "move into the Crypt" step
coffin:SetAttribute("CryptBuilder", nil) -- so the cleanup below can't delete it
coffin:SetAttribute("IsOpen", false)
for _, d in ipairs(coffin:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end

-- Remove furniture from an earlier run, and the castle builder's block placeholder
for _, child in ipairs(crypt:GetChildren()) do
	if child ~= coffin and (child:GetAttribute("CryptBuilder") or child.Name == "Coffin" or child.Name == "CoffinLid") then
		child:Destroy()
	end
end

-- Also remove the castle builder's leftover floor candles (the ones that stood
-- beside its block coffin). Wall and chandelier candles hang much higher, and
-- candles on furniture are inside other objects, so they're not touched.
local roomFloorY = zone.Position.Y - zone.Size.Y / 2 + 0.2
for _, child in ipairs(crypt:GetChildren()) do
	local isCandle = child.Name == "Candle" or child.Name == "Flame"
	if isCandle and child:IsA("BasePart") and child.Position.Y - roomFloorY < 2 then
		child:Destroy()
	end
end

------------------------------------------------------------------------
-- 4. HELPER FUNCTION
------------------------------------------------------------------------
local partCount = 0

-- Makes one block. `at` is a CFrame on the floor; `offset` is the middle
-- of the block relative to it. solid = true means players bump into it.
local function put(parent, name, at, offset, size, material, color, solid, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = at * CFrame.new(offset) * (opts.rot or CFrame.new())
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if opts.shape then
		p.Shape = opts.shape
	end
	if not solid then
		p.CanCollide = false
		p.CastShadow = false
	end
	p:SetAttribute("CryptBuilder", true)
	p.Parent = parent
	partCount = partCount + 1
	return p
end

------------------------------------------------------------------------
-- 5. THE CRYPT'S SPACE
-- The corridor runs through the middle of the castle at z = 0. The crypt
-- is on one side of it, with its door on the side facing the corridor.
-- doorSign is +1 if that is the +Z side, or -1 if it's the -Z side.
-- The back wall is the opposite side.
------------------------------------------------------------------------
local boards = crypt:FindFirstChild("StoneFloor")
local floorY = boards and (boards.Position.Y + boards.Size.Y / 2) or (zone.Position.Y - zone.Size.Y / 2 + 0.2)
local ceilingY = zone.Position.Y + zone.Size.Y / 2
local cx = zone.Position.X                                   -- the door is in the middle of this wall
local doorSign = (zone.Position.Z < 0) and 1 or -1
local doorZ = zone.Position.Z + doorSign * zone.Size.Z / 2   -- the wall with the door
local backZ = zone.Position.Z - doorSign * zone.Size.Z / 2   -- the back wall

local furniture = Instance.new("Folder")
furniture.Name = "CryptFurniture"
furniture:SetAttribute("CryptBuilder", true)
furniture.Parent = crypt

------------------------------------------------------------------------
-- 6. SIZE AND TURN THE COFFIN
-- Step 1: scale it. The first run remembers the coffin's original scale
--         (the "BaseScale" attribute), so running again never stacks.
-- Step 2: turn it (only left and right, never tipping it) so its front
--         looks at the door. We treat the model's -Z side as its "front",
--         which is how Roblox models normally face.
------------------------------------------------------------------------
local baseScale = coffin:GetAttribute("BaseScale")
if not baseScale then
	baseScale = coffin:GetScale()
	coffin:SetAttribute("BaseScale", baseScale)
end
coffin:ScaleTo(baseScale * COFFIN_SCALE)

-- The direction the coffin's front points now, flattened to the ground.
-- A heading is the angle of a direction, measured from +Z toward +X.
local pivot = coffin:GetPivot()
local look = pivot.LookVector
local flatLength = math.sqrt(look.X * look.X + look.Z * look.Z)
if flatLength > 0.1 then
	local currentHeading = math.atan2(look.X, look.Z)
	local wantedHeading = math.atan2(0, doorSign) -- the direction from the back wall to the door
	local turn = wantedHeading - currentHeading + math.rad(TURN_COFFIN)
	-- Spin around the coffin's own middle: put it at the origin's rotation, then turn it.
	coffin:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, turn, 0) * pivot.Rotation)
else
	warn("The coffin's front points straight up or down, so I couldn't tell which way to turn it. Check TURN_COFFIN.")
end

-- How far the coffin reaches along each world direction (x, y, z), counting
-- however it's turned. A box turned a quarter reaches differently than
-- one that isn't, so we add up each of the box's own sides.
local boxCFrame, boxSize = coffin:GetBoundingBox()
local right, up, backward = boxCFrame.RightVector, boxCFrame.UpVector, boxCFrame.LookVector
local reachX = (math.abs(right.X) * boxSize.X + math.abs(up.X) * boxSize.Y + math.abs(backward.X) * boxSize.Z)
local reachY = (math.abs(right.Y) * boxSize.X + math.abs(up.Y) * boxSize.Y + math.abs(backward.Y) * boxSize.Z)
local reachZ = (math.abs(right.Z) * boxSize.X + math.abs(up.Z) * boxSize.Y + math.abs(backward.Z) * boxSize.Z)

------------------------------------------------------------------------
-- 7. THE PLATFORM, RUNNER AND CANDLES
-- The platform is flush against the back wall, a little wider than the coffin
-- and sticking out in front of it.
------------------------------------------------------------------------
local platformWidth = reachX + 4
local platformDepth = reachZ + 5
local platformCenterZ = backZ + doorSign * platformDepth / 2
local platformTopY = floorY + PLATFORM_HEIGHT

put(furniture, "Platform", CFrame.new(cx, floorY, platformCenterZ), Vector3.new(0, PLATFORM_HEIGHT / 2, 0),
	Vector3.new(platformWidth, PLATFORM_HEIGHT, platformDepth), Enum.Material.Slate, COLORS.Stone, true)
put(furniture, "PlatformEdge", CFrame.new(cx, floorY, platformCenterZ), Vector3.new(0, PLATFORM_HEIGHT * 0.3, 0),
	Vector3.new(platformWidth + 1, PLATFORM_HEIGHT * 0.6, platformDepth + 1), Enum.Material.Slate, COLORS.Slate, true)

-- A red runner from the door toward the platform
local runnerStart = backZ + doorSign * (platformDepth + 1)
local runnerLength = math.abs(doorZ - runnerStart) - 0.5
if runnerLength > 1 then
	local runnerCenterZ = runnerStart + doorSign * runnerLength / 2
	put(furniture, "Runner", CFrame.new(cx, floorY, runnerCenterZ), Vector3.new(0, 0.04, 0),
		Vector3.new(4, 0.08, runnerLength), Enum.Material.Fabric, COLORS.Carpet, false)
end

-- Two iron candle stands, one each side of the platform
for _, side in ipairs({ -1, 1 }) do
	local sat = CFrame.new(cx + side * (platformWidth / 2 + 2), floorY, backZ + doorSign * (platformDepth - 1))
	put(furniture, "StandPole", sat, Vector3.new(0, 2.2, 0), Vector3.new(0.4, 4.4, 0.4), Enum.Material.Metal, COLORS.Iron, false)
	put(furniture, "StandBase", sat, Vector3.new(0, 0.15, 0), Vector3.new(1.4, 0.3, 1.4), Enum.Material.Metal, COLORS.Iron, true)
	put(furniture, "StandDish", sat, Vector3.new(0, 4.5, 0), Vector3.new(1.4, 0.2, 1.4), Enum.Material.Metal, COLORS.Iron, false)
	put(furniture, "Candle", sat, Vector3.new(0, 5.15, 0), Vector3.new(1.0, 0.35, 0.35), Enum.Material.SmoothPlastic, COLORS.Cream, false,
		{ shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) }) -- stands the cylinder up
	local flame = put(furniture, "Flame", sat, Vector3.new(0, 5.85, 0), Vector3.new(0.3, 0.3, 0.3), Enum.Material.Neon, COLORS.Flame, false,
		{ shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = COLORS.Light
	light.Range = 24
	light.Brightness = 1.3
	light.Parent = flame
	CollectionService:AddTag(light, "CandleLight") -- the CandleFlicker script finds candles by this tag
end

------------------------------------------------------------------------
-- 8. PLACE THE COFFIN
-- Back against the wall (with a small gap), centered on the door, and
-- standing on the platform.
------------------------------------------------------------------------
local coffinCenterZ = backZ + doorSign * (reachZ / 2 + WALL_GAP)
local target = Vector3.new(cx, platformTopY + reachY / 2, coffinCenterZ)
coffin:PivotTo(coffin:GetPivot() + (target - boxCFrame.Position))
coffin:SetAttribute("CryptCoffin", true)

if platformTopY + reachY > ceilingY - 0.5 then
	warn(string.format("The coffin is %.1f studs tall, which won't fit under the ceiling. Lower COFFIN_SCALE and run again.", reachY))
end

------------------------------------------------------------------------
-- 9. MARKERS FOR GAME SCRIPTS
------------------------------------------------------------------------
local function marker(name, position)
	local p = put(furniture, name, CFrame.new(position), Vector3.new(0, 0, 0), Vector3.new(0.5, 0.5, 0.5),
		Enum.Material.SmoothPlastic, COLORS.Gold, false)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Spot", name)
end
marker("CoffinSpot", Vector3.new(cx, platformTopY + 3.5, coffinCenterZ + doorSign * (reachZ / 2 + 2))) -- just in front of the coffin
marker("DraculaSpawn", Vector3.new(cx, floorY + 3.5, backZ + doorSign * (platformDepth + 3)))       -- on the floor in front of the platform

------------------------------------------------------------------------
-- 10. FINISH
------------------------------------------------------------------------
if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Build Crypt") end)
end
pcall(function() game:GetService("Selection"):Set({ crypt }) end)

print(string.format("Crypt built! Coffin is %.1f wide, %.1f tall and %.1f deep. If it faces the wrong way, change TURN_COFFIN at the top.",
	reachX, reachY, reachZ))
