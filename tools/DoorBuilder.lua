--[[
=======================================================================
  DOOR BUILDER  -  Dracula's BnB
=======================================================================
  Builds the castle's doors (run CastleBuilder.lua first):
    * the FRONT DOOR: a tall gothic double door with a pointed top, like
      the reference picture: dark planks, an iron frame, iron straps with
      pointed ends, diamond studs, and a ring knocker on each leaf
    * 16 GUEST ROOM DOORS (201-208, 301-308): a single dark wooden door
      with iron straps, studs, a ring handle, a gold room-number plate
      and a small lock light

  Each door is a Model inside Workspace > DraculaCastle > Doors, tagged
  "CastleDoor". The behaviour (opening, closing, locking, breaking) is
  in the DoorControl and DoorManager scripts. This builder only makes
  how they look and where they hang.

  Each door Model has attributes the scripts read and update:
      DoorType     "Front" or "Guest"
      RoomNumber   (guest doors only)
      IsOpen, IsLocked, IsBroken, BeingBroken
  Each leaf (the part that swings) is a Model with an invisible "Hinge"
  part that it turns around, and an attribute OpenSign (+1 or -1) that
  says which way it swings. Guest doors swing into the room. The front
  door swings into the lobby.

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Run tools/CastleBuilder.lua first if you haven't already.
    3. Open the Command Bar, paste this WHOLE file in and click Run.
       You'll see "Doors built!" in the Output window.

  Running it again removes the old doors and builds fresh ones.
  (Running CastleBuilder again wipes the castle, so run this one again
  afterwards.)
=======================================================================
]]

------------------------------------------------------------------------
-- 1. SETTINGS
------------------------------------------------------------------------
-- Doorway sizes, as the castle builder makes them
local FRONT_WIDTH, FRONT_HEIGHT = 12, 18   -- the opening in the front wall
local GUEST_WIDTH, GUEST_HEIGHT = 7, 12    -- the opening of a guest room door

local FRONT_LEAF_HEIGHT = 12   -- the swinging doors stop here; a fixed pointed top fills the rest
local FRONT_ARCH_STEPS = 6     -- how many steps the pointed top is made of
local LEAF_THICKNESS = 0.6

local COLORS = {
	Wood     = Color3.fromRGB(46, 34, 28),   -- dark planks
	Plank    = Color3.fromRGB(20, 14, 12),   -- the dark lines between planks
	Iron     = Color3.fromRGB(34, 33, 36),
	IronDark = Color3.fromRGB(24, 23, 26),
	Gold     = Color3.fromRGB(176, 141, 62),
	Stone    = Color3.fromRGB(62, 60, 60),   -- matches the castle's outer wall
	LockOff  = Color3.fromRGB(70, 68, 70),
}

------------------------------------------------------------------------
-- 2. FIND THINGS
------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local castle = workspace:FindFirstChild("DraculaCastle")
if not castle then
	error("No DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
end
local lobby = castle:FindFirstChild("Grand Lobby", true)
local lobbyZone = lobby and lobby:FindFirstChild("Zone")
if not lobbyZone then
	error("Couldn't find the Grand Lobby (or its Zone) inside DraculaCastle.")
end

local rooms = {}
for _, object in ipairs(castle:GetDescendants()) do
	if object:IsA("Model") and object:GetAttribute("RoomKind") == "Guest" and object:FindFirstChild("Zone") then
		table.insert(rooms, object)
	end
end

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Build Doors") end)

-- Remove doors from an earlier run
local old = castle:FindFirstChild("Doors")
if old then
	old:Destroy()
end
local doorsFolder = Instance.new("Folder")
doorsFolder.Name = "Doors"
doorsFolder.Parent = castle

------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS
------------------------------------------------------------------------
local partCount = 0

-- Makes one block.
--   at       a CFrame: the point the object is built around
--   offset   where the middle of this block is, relative to `at`
--   solid    true = players bump into it, false = they walk through it
--   opts     optional: rot = extra CFrame rotation, shape = Enum.PartType.Ball etc.
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
	p.Parent = parent
	partCount = partCount + 1
	return p
end

------------------------------------------------------------------------
-- 4. BUILD ONE LEAF (the part of a door that swings)
-- Built in "leaf space": the origin is the hinge, on the floor. x runs
-- along the leaf, away from the hinge. y is up. z is through the thickness.
-- `at` puts that space in the world. Details are made on BOTH faces of
-- the leaf (side = -1 and +1), so the door looks the same from both sides.
--   corridorSide  which face (-1 or +1) looks out into the corridor, so
--                 the room-number plate goes there. nil = no plate.
--   roomNumber    the number on that plate
------------------------------------------------------------------------
local function buildLeaf(parent, name, at, width, height, openSign, corridorSide, roomNumber)
	local leaf = Instance.new("Model")
	leaf.Name = name
	leaf:SetAttribute("OpenSign", openSign)
	leaf.Parent = parent

	-- The hinge: an invisible post the whole leaf turns around
	local hinge = put(leaf, "Hinge", at, Vector3.new(0, height / 2, 0), Vector3.new(0.3, height, 0.3),
		Enum.Material.Metal, COLORS.Iron, false)
	hinge.Transparency = 1
	leaf.PrimaryPart = hinge

	local half = LEAF_THICKNESS / 2

	-- The wooden body
	put(leaf, "Body", at, Vector3.new(width / 2, height / 2, 0), Vector3.new(width, height, LEAF_THICKNESS),
		Enum.Material.Wood, COLORS.Wood, true)

	for _, side in ipairs({ -1, 1 }) do
		local face = half + 0.02 -- just in front of the wood

		-- Dark lines between the planks, about a stud apart
		for i = 1, math.floor(width) - 1 do
			put(leaf, "PlankLine", at, Vector3.new(i * (width / math.floor(width)), height / 2, side * face),
				Vector3.new(0.06, height - 0.6, 0.04), Enum.Material.SmoothPlastic, COLORS.Plank, false)
		end

		-- The iron frame around the edge: top, bottom, and the free edge
		local band = half + 0.08
		put(leaf, "FrameBottom", at, Vector3.new(width / 2, 0.35, side * band), Vector3.new(width, 0.7, 0.14),
			Enum.Material.Metal, COLORS.Iron, false)
		put(leaf, "FrameTop", at, Vector3.new(width / 2, height - 0.3, side * band), Vector3.new(width, 0.6, 0.14),
			Enum.Material.Metal, COLORS.Iron, false)
		put(leaf, "FrameEdge", at, Vector3.new(width - 0.25, height / 2, side * band), Vector3.new(0.5, height, 0.14),
			Enum.Material.Metal, COLORS.Iron, false)

		-- Two iron straps across the planks, each with a pointed end, and a
		-- short upright bar by the hinge, like the reference door
		local strapZ = side * (half + 0.075)
		for _, fraction in ipairs({ 0.78, 0.2 }) do
			local y = height * fraction
			put(leaf, "Strap", at, Vector3.new((width - 0.9) / 2 + 0.3, y, strapZ), Vector3.new(width - 1.2, 0.7, 0.15),
				Enum.Material.Metal, COLORS.Iron, false)
			put(leaf, "StrapTip", at, Vector3.new(width - 0.8, y, strapZ), Vector3.new(0.6, 0.6, 0.15),
				Enum.Material.Metal, COLORS.Iron, false, { rot = CFrame.Angles(0, 0, math.rad(45)) })
			put(leaf, "StrapHinge", at, Vector3.new(0.6, y, strapZ), Vector3.new(0.35, 1.8, 0.15),
				Enum.Material.Metal, COLORS.IronDark, false)
		end

		-- Diamond studs between the straps
		for _, fx in ipairs({ 0.3, 0.5 }) do
			for _, fy in ipairs({ 0.34, 0.46, 0.58, 0.7 }) do
				put(leaf, "Stud", at, Vector3.new(width * fx, height * fy, side * (half + 0.07)), Vector3.new(0.3, 0.3, 0.14),
					Enum.Material.Metal, COLORS.IronDark, false, { rot = CFrame.Angles(0, 0, math.rad(45)) })
			end
		end

		-- The ring handle: a backplate and a ring made of ten short pieces
		local handleX = width - 1.6
		local ringY = height * 0.5 - 0.2
		local plateZ = side * (half + 0.07)
		put(leaf, "HandlePlate", at, Vector3.new(handleX, ringY + 1.0, plateZ), Vector3.new(0.9, 1.6, 0.14),
			Enum.Material.Metal, COLORS.IronDark, false, { rot = CFrame.Angles(0, 0, math.rad(0)) })
		local segments, radius = 10, 0.75
		for i = 0, segments - 1 do
			local angle = i * (2 * math.pi / segments)
			put(leaf, "HandleRing", at,
				Vector3.new(handleX + radius * math.cos(angle), ringY + radius * math.sin(angle), side * (half + 0.2)),
				Vector3.new(0.55, 0.22, 0.2), Enum.Material.Metal, COLORS.Iron, false,
				{ rot = CFrame.Angles(0, 0, angle + math.pi / 2) }) -- turn each piece along the ring
		end

		-- A small lock plate with a light that DoorControl turns red when locked
		local lockY = height * 0.5 - 2.3
		put(leaf, "LockPlate", at, Vector3.new(handleX, lockY, plateZ), Vector3.new(0.8, 1.1, 0.14),
			Enum.Material.Metal, COLORS.IronDark, false)
		put(leaf, "LockIndicator", at, Vector3.new(handleX, lockY, side * (half + 0.17)), Vector3.new(0.28, 0.28, 0.06),
			Enum.Material.Metal, COLORS.LockOff, false)

		-- The room-number plate, on the corridor side only
		if roomNumber and side == corridorSide then
			local plate = put(leaf, "NumberPlate", at, Vector3.new(width * 0.5, height * 0.62, side * (half + 0.09)),
				Vector3.new(1.6, 0.9, 0.12), Enum.Material.Metal, COLORS.Gold, false)
			local gui = Instance.new("SurfaceGui")
			-- the +Z face of a part is its "Back", and the -Z face is its "Front"
			gui.Face = (side == 1) and Enum.NormalId.Back or Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 80
			gui.Parent = plate
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = tostring(roomNumber)
			label.Font = Enum.Font.Antique
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(40, 25, 15)
			label.Parent = gui
		end
	end
	return leaf
end

-- Makes the empty Model for one door, and the invisible anchor the prompts attach to
local function newDoor(name, doorType, anchorPosition, promptDistance)
	local door = Instance.new("Model")
	door.Name = name
	door:SetAttribute("DoorType", doorType)
	door:SetAttribute("IsOpen", false)
	door:SetAttribute("IsLocked", false)
	door:SetAttribute("IsBroken", false)
	door:SetAttribute("BeingBroken", false)
	door:SetAttribute("PromptDistance", promptDistance)
	door.Parent = doorsFolder
	CollectionService:AddTag(door, "CastleDoor") -- DoorControl finds every door by this tag

	local anchor = put(door, "PromptAnchor", CFrame.new(anchorPosition), Vector3.new(0, 0, 0), Vector3.new(1, 1, 1),
		Enum.Material.SmoothPlastic, COLORS.Gold, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	anchor.CanTouch = false
	return door
end

------------------------------------------------------------------------
-- 5. THE 16 GUEST ROOM DOORS
-- Each guest room has its door in the wall facing the corridor. Front-row
-- rooms (z > 0) have it on their -Z side, and back-row rooms on their +Z
-- side. The door hangs in the middle of the wall, hinged on the left, and
-- swings into the room.
------------------------------------------------------------------------
local guestCount = 0
for _, room in ipairs(rooms) do
	local zone = room:FindFirstChild("Zone")
	local number = room:GetAttribute("RoomNumber")
	local isFront = zone.Position.Z > 0
	local depth = zone.Size.Z
	local interiorSign = isFront and 1 or -1                 -- which way is INTO the room
	local innerZ = zone.Position.Z - interiorSign * depth / 2 -- the inside face of the door wall
	local planeZ = innerZ - interiorSign * 0.5                -- the middle of the wall (1 stud thick)
	local slabY = zone.Position.Y - zone.Size.Y / 2           -- the floor slab's top
	local cx = zone.Position.X
	local leafHeight = GUEST_HEIGHT - 0.35
	local leafWidth = GUEST_WIDTH - 0.1

	local door = newDoor("Door_" .. number, "Guest", Vector3.new(cx, slabY + 6, planeZ), 9)
	door:SetAttribute("RoomNumber", number)

	-- hinged on the left (-X side) of the doorway; the leaf reaches toward +X
	local at = CFrame.new(cx - GUEST_WIDTH / 2 + 0.05, slabY + 0.25, planeZ)
	-- A positive turn sends a leaf that reaches along +X toward -Z. We want it to
	-- go toward the room, so the sign is the opposite of the room direction.
	local openSign = -interiorSign
	local corridorSide = -interiorSign -- the face looking out to the corridor (local z follows world z here)
	buildLeaf(door, "Leaf", at, leafWidth, leafHeight, openSign, corridorSide, number)
	guestCount = guestCount + 1
end

------------------------------------------------------------------------
-- 6. THE FRONT DOOR
-- A double door in the thick outer wall at the front of the lobby. The wall
-- is 1 stud of lobby wall plus 2 studs of outer wall, so the door hangs in the
-- middle of the outer wall. Two leaves, hinged at the left and right, swing
-- inward (toward the lobby, which is -Z). Above them a fixed pointed top
-- fills the rest of the 18 stud opening, with stone filling the corners.
------------------------------------------------------------------------
local lobbyInnerZ = lobbyZone.Position.Z + lobbyZone.Size.Z / 2 -- the inside face of the lobby's front wall
local planeZ = lobbyInnerZ + 1 + 1                              -- 1 stud of lobby wall + half of the 2 stud outer wall
local slabY = lobbyZone.Position.Y - lobbyZone.Size.Y / 2
local cx = lobbyZone.Position.X
local halfGap = FRONT_WIDTH / 2
local leafWidth = halfGap - 0.05
local leafBottom = slabY + 0.05

local front = newDoor("Door_Front", "Front", Vector3.new(cx, slabY + 6, planeZ), 16)

-- Left leaf: hinged at the left, reaching toward +X. A positive turn sends it toward -Z (the lobby).
buildLeaf(front, "LeafL", CFrame.new(cx - halfGap + 0.05, leafBottom, planeZ), leafWidth, FRONT_LEAF_HEIGHT, 1, nil, nil)
-- Right leaf: the same, turned around so it reaches toward -X. Its turn toward the lobby is negative.
buildLeaf(front, "LeafR", CFrame.new(cx + halfGap - 0.05, leafBottom, planeZ) * CFrame.Angles(0, math.pi, 0),
	leafWidth, FRONT_LEAF_HEIGHT, -1, nil, nil)

-- The fixed pointed top
local arch = Instance.new("Model")
arch.Name = "PointedTop"
arch.Parent = front
local archAt = CFrame.new(cx, 0, planeZ)
local archBottom = leafBottom + FRONT_LEAF_HEIGHT
local archTop = slabY + FRONT_HEIGHT
local stepHeight = (archTop - archBottom) / FRONT_ARCH_STEPS
for k = 0, FRONT_ARCH_STEPS - 1 do
	local halfWidth = halfGap - k * ((halfGap - 1) / (FRONT_ARCH_STEPS - 1)) -- narrows from full width to 1 stud
	local y = archBottom + k * stepHeight + stepHeight / 2
	put(arch, "ArchStep", archAt, Vector3.new(0, y, 0), Vector3.new(halfWidth * 2, stepHeight, 0.7),
		Enum.Material.Wood, COLORS.Wood, true)
	for _, side in ipairs({ -1, 1 }) do
		-- an iron edge along the end of each step
		put(arch, "ArchEdge", archAt, Vector3.new(side * (halfWidth - 0.15), y, 0), Vector3.new(0.3, stepHeight, 0.84),
			Enum.Material.Metal, COLORS.Iron, false)
		-- stone filling the corner outside the step, so you can't see through the gaps
		local fill = halfGap - halfWidth
		if fill > 0.05 then
			put(arch, "ArchFill", archAt, Vector3.new(side * (halfWidth + fill / 2), y, 0), Vector3.new(fill, stepHeight, 2),
				Enum.Material.Slate, COLORS.Stone, true)
		end
	end
end
-- the iron band down the middle where the doors meet, carried up through the arch, and a spike on top
put(arch, "CenterBand", archAt, Vector3.new(0, (archBottom + archTop) / 2, 0), Vector3.new(0.5, archTop - archBottom, 0.84),
	Enum.Material.Metal, COLORS.Iron, false)
put(arch, "Spike", archAt, Vector3.new(0, archTop + 0.7, 0), Vector3.new(0.3, 1.6, 0.3), Enum.Material.Metal, COLORS.Iron, false)
put(arch, "SpikeDiamond", archAt, Vector3.new(0, archTop + 0.2, 0), Vector3.new(0.8, 0.8, 0.3),
	Enum.Material.Metal, COLORS.Iron, false, { rot = CFrame.Angles(0, 0, math.rad(45)) })
-- the iron band down the middle of the lower doors too, where the two leaves meet
put(front, "CenterBandLower", archAt, Vector3.new(0, leafBottom + FRONT_LEAF_HEIGHT / 2, 0),
	Vector3.new(0.3, FRONT_LEAF_HEIGHT, 1.0), Enum.Material.Metal, COLORS.IronDark, false)

------------------------------------------------------------------------
-- 7. FINISH
------------------------------------------------------------------------
if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Build Doors") end)
end
pcall(function() game:GetService("Selection"):Set({ doorsFolder }) end)

print(string.format("Doors built! %d guest doors and the front door, %d parts. Add the DoorControl and DoorManager scripts to make them work.",
	guestCount, partCount))
