--[[
=======================================================================
  CRYPT BUILDER  -  Dracula's BnB
=======================================================================
  Furnishes Dracula's Crypt (run CastleBuilder.lua first):
    * finds your imported coffin model and places it in the middle of
      the crypt, lying flat, scaled to a sensible length
    * a stone dais for it to rest on
    * a red runner from the crypt door to the dais
    * four iron candle stands around the coffin
    * hidden markers for game scripts:
        CoffinSpot    on top of the coffin, where Dracula lies
        DraculaSpawn  on the floor beside the dais, where he appears

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Import your coffin into Studio (it needs to exist in the place).
       Best home for it: ServerStorage > Assets. This script looks for
       anything with "coffin" in its name in ServerStorage,
       ReplicatedStorage and Workspace (outside the castle), so any of
       those work, and re-running the castle builder won't delete it.
    3. Open the Command Bar, paste this WHOLE file in and click Run.
       You'll see "Crypt built!" in the Output window.

  Running it again removes the old crypt furniture and builds it fresh.
  (Running CastleBuilder again wipes the castle, so run this afterwards.)

  SETTINGS below let you change the coffin's length and how it's turned.
=======================================================================
]]

------------------------------------------------------------------------
-- 1. SETTINGS
------------------------------------------------------------------------
local COFFIN_LENGTH = 9     -- studs, head to foot. A character is about 5 studs tall.
local TURN_COFFIN = 0       -- extra turn in degrees (try 180 to swap head and foot)

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

-- Look for something called "...coffin..." in the places you might have put it
local source
for _, place in ipairs({ game:GetService("ServerStorage"), game:GetService("ReplicatedStorage"), workspace }) do
	for _, object in ipairs(place:GetDescendants()) do
		local isModel = object:IsA("Model") or object:IsA("MeshPart")
		if isModel and string.find(string.lower(object.Name), "coffin") and not object:IsDescendantOf(castle)
			and not object:GetAttribute("CryptBuilder") then
			source = object
			break
		end
	end
	if source then break end
end
if not source then
	error("Couldn't find your coffin. Import it, then put it in ServerStorage (a model with 'coffin' in its name).")
end
print("Using coffin: " .. source:GetFullName())

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Build Crypt") end)

-- Remove things from an earlier run, and the castle builder's block placeholder
for _, child in ipairs(crypt:GetChildren()) do
	if child:GetAttribute("CryptBuilder") or child.Name == "Coffin" or child.Name == "CoffinLid" then
		child:Destroy()
	end
end

------------------------------------------------------------------------
-- 3. HELPER FUNCTION
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
-- 4. THE CRYPT'S SPACE
-- The crypt is a back-row room, so its door is on the +Z side.
------------------------------------------------------------------------
local boards = crypt:FindFirstChild("StoneFloor")
local floorY = boards and (boards.Position.Y + boards.Size.Y / 2) or (zone.Position.Y - zone.Size.Y / 2 + 0.2)
local cx, cz = zone.Position.X, zone.Position.Z
local doorZ = zone.Position.Z + zone.Size.Z / 2

local furniture = Instance.new("Folder")
furniture.Name = "CryptFurniture"
furniture:SetAttribute("CryptBuilder", true)
furniture.Parent = crypt

local at = CFrame.new(cx, floorY, cz)

-- Stone dais: a wide low step with a smaller platform on top
local stepHeight, topHeight = 0.5, 1.0
put(furniture, "DaisStep", at, Vector3.new(0, stepHeight / 2, 0), Vector3.new(11, stepHeight, 17), Enum.Material.Slate, COLORS.Slate, true)
put(furniture, "DaisTop", at, Vector3.new(0, stepHeight + (topHeight - stepHeight) / 2, 0), Vector3.new(8.5, topHeight - stepHeight, 14.5), Enum.Material.Slate, COLORS.Stone, true)
local daisTopY = floorY + topHeight

-- Red runner from the door toward the dais
local runnerStart = cz + 8.5
local runnerEnd = doorZ - 0.5
if runnerEnd > runnerStart then
	local rat = CFrame.new(cx, floorY, (runnerStart + runnerEnd) / 2)
	put(furniture, "Runner", rat, Vector3.new(0, 0.04, 0), Vector3.new(4, 0.08, runnerEnd - runnerStart), Enum.Material.Fabric, COLORS.Carpet, false)
end

-- Four iron candle stands around the dais
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local sat = CFrame.new(cx + sx * 6.5, floorY, cz + sz * 9.5)
		put(furniture, "StandPole", sat, Vector3.new(0, 2.2, 0), Vector3.new(0.4, 4.4, 0.4), Enum.Material.Metal, COLORS.Iron, false)
		put(furniture, "StandBase", sat, Vector3.new(0, 0.15, 0), Vector3.new(1.4, 0.3, 1.4), Enum.Material.Metal, COLORS.Iron, true)
		put(furniture, "StandDish", sat, Vector3.new(0, 4.5, 0), Vector3.new(1.4, 0.2, 1.4), Enum.Material.Metal, COLORS.Iron, false)
		put(furniture, "Candle", sat, Vector3.new(0, 5.15, 0), Vector3.new(1.0, 0.35, 0.35), Enum.Material.SmoothPlastic, COLORS.Cream, false,
			{ shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) }) -- stands the cylinder up
		local flame = put(furniture, "Flame", sat, Vector3.new(0, 5.85, 0), Vector3.new(0.3, 0.3, 0.3), Enum.Material.Neon, COLORS.Flame, false,
			{ shape = Enum.PartType.Ball })
		local light = Instance.new("PointLight")
		light.Color = COLORS.Light
		light.Range = 22
		light.Brightness = 1.2
		light.Parent = flame
		CollectionService:AddTag(light, "CandleLight") -- the CandleFlicker script finds candles by this tag
	end
end

------------------------------------------------------------------------
-- 5. PLACE THE COFFIN
-- Steps: copy it, lock it in place, lay it flat with its long side along
-- the crypt's length, scale it to COFFIN_LENGTH, and set it on the dais.
------------------------------------------------------------------------
local coffin = source:Clone()
if coffin:IsA("BasePart") then
	-- a lone mesh: wrap it in a Model so we can move and scale it as one
	local wrapper = Instance.new("Model")
	coffin.Parent = wrapper
	wrapper.PrimaryPart = coffin
	coffin = wrapper
end
coffin.Name = "DraculaCoffin"
coffin:SetAttribute("CryptBuilder", true)
coffin:SetAttribute("IsOpen", false)
for _, d in ipairs(coffin:GetDescendants()) do
	if d:IsA("BasePart") then
		d.Anchored = true
	end
end
coffin.Parent = furniture

-- Start from a known pose, so the model's size is measured along the world axes
coffin:PivotTo(CFrame.new(cx, daisTopY + 20, cz))
local _, size = coffin:GetBoundingBox()

-- Lying on its end? Tip it over so the long side is horizontal.
if size.Y > size.X and size.Y > size.Z then
	coffin:PivotTo(coffin:GetPivot() * CFrame.Angles(math.rad(90), 0, 0))
	_, size = coffin:GetBoundingBox()
end
-- Long side along X? Turn it a quarter so it runs along Z, the crypt's length.
if size.X > size.Z then
	coffin:PivotTo(coffin:GetPivot() * CFrame.Angles(0, math.rad(90), 0))
	_, size = coffin:GetBoundingBox()
end
if TURN_COFFIN ~= 0 then
	coffin:PivotTo(coffin:GetPivot() * CFrame.Angles(0, math.rad(TURN_COFFIN), 0))
end

-- Scale so the length is COFFIN_LENGTH
coffin:ScaleTo(coffin:GetScale() * (COFFIN_LENGTH / size.Z))
local boxCFrame, boxSize = coffin:GetBoundingBox()

-- Move it onto the dais, centered, with its bottom touching the top
local target = Vector3.new(cx, daisTopY + boxSize.Y / 2, cz)
coffin:PivotTo(coffin:GetPivot() + (target - boxCFrame.Position))
coffin:SetAttribute("Length", COFFIN_LENGTH)

------------------------------------------------------------------------
-- 6. MARKERS FOR GAME SCRIPTS
------------------------------------------------------------------------
local function marker(name, position)
	local p = put(furniture, name, CFrame.new(position), Vector3.new(0, 0, 0), Vector3.new(0.5, 0.5, 0.5),
		Enum.Material.SmoothPlastic, COLORS.Gold, false)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Spot", name)
end
marker("CoffinSpot", Vector3.new(cx, daisTopY + boxSize.Y, cz))
marker("DraculaSpawn", Vector3.new(cx + 7.5, floorY + 3.5, cz))

------------------------------------------------------------------------
-- 7. FINISH
------------------------------------------------------------------------
if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Build Crypt") end)
end
pcall(function() game:GetService("Selection"):Set({ crypt }) end)

print(string.format("Crypt built! %d parts. Coffin size: %.1f x %.1f x %.1f studs. Press F to zoom to it.",
	partCount, boxSize.X, boxSize.Y, boxSize.Z))
