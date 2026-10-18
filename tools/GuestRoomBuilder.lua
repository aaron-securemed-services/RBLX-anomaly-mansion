--[[
=======================================================================
  GUEST ROOM BUILDER  -  Dracula's BnB
=======================================================================
  Furnishes all 16 guest rooms (201-208 and 301-308). Each room gets:
    * a four-poster-style bed with headboard, pillows and a red blanket
    * two nightstands with candles (the candles flicker like the rest)
    * a gothic window on the far wall with curtains and a glass sash
    * an armchair and side table in the far corner
    * a wardrobe on one side wall
    * a writing desk and chair on the other side wall, with a mirror
      hung above the desk

  GAME HOOKS (named parts that later scripts will use)
    Window  (Model)  attribute IsOpen = false. The glass pane inside is
                     called "Sash". A script can swing or slide it open.
    Mirror  (Model)  attribute Covered = false
    CrucifixSpot     an invisible marker above the headboard, where a
                     crucifix can be hung
    GarlicSpot       an invisible marker beside the door, in the
                     corridor, where garlic can be hung
    GuestSpot        an invisible marker on the floor at the foot of the
                     bed, where a checked-in guest stands
    Every marker is a Part with the attribute  Spot = "<its name>".

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Run tools/CastleBuilder.lua first if you haven't already.
    3. Open the Command Bar, paste this WHOLE file in and click Run.
       It takes a few seconds. You'll see "Guest rooms furnished!".

  Running it again removes the old furniture and builds a fresh set.
  (Running CastleBuilder again wipes the castle, so run this one again
  afterwards.)

  Everything is measured from each room's own size, and the far wall is
  always the castle's outer wall, so the windows face outside.
=======================================================================
]]

------------------------------------------------------------------------
-- 1. SETTINGS
------------------------------------------------------------------------
local COLORS = {
	DarkWood  = Color3.fromRGB(58, 38, 26),
	PanelWood = Color3.fromRGB(84, 55, 38),
	Iron      = Color3.fromRGB(32, 30, 30),
	Gold      = Color3.fromRGB(176, 141, 62),
	Cream     = Color3.fromRGB(236, 226, 205),
	Velvet    = Color3.fromRGB(96, 20, 30),
	Blanket   = Color3.fromRGB(120, 18, 28),
	Night     = Color3.fromRGB(12, 14, 28),     -- the dark sky outside the window
	Glass     = Color3.fromRGB(170, 195, 215),
	Silver    = Color3.fromRGB(205, 212, 220),
	Flame     = Color3.fromRGB(255, 170, 70),
	Light     = Color3.fromRGB(255, 160, 85),
}

------------------------------------------------------------------------
-- 2. FIND THE ROOMS
------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local castle = workspace:FindFirstChild("DraculaCastle")
if not castle then
	error("No DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
end

local rooms = {}
for _, object in ipairs(castle:GetDescendants()) do
	if object:IsA("Model") and object:GetAttribute("RoomKind") == "Guest" then
		table.insert(rooms, object)
	end
end
if #rooms == 0 then
	error("Found no guest rooms in DraculaCastle.")
end

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Furnish Guest Rooms") end)

local partCount = 0

------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS
------------------------------------------------------------------------
-- Makes one block.
--   at      a CFrame: the point on the floor the object is built around.
--           A Roblox part's "front" is its -Z side, so an object faces
--           the way -Z points. Its back is +Z (that's the side against a wall).
--   offset  where the middle of this block is, relative to `at`
--   solid   true = players bump into it, false = they walk through it
--   opts    optional: rot = extra CFrame rotation, class = "Seat" etc.,
--           shape = Enum.PartType.Ball / Cylinder
local function put(parent, name, at, offset, size, material, color, solid, opts)
	opts = opts or {}
	local p = Instance.new(opts.class or "Part")
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

-- A candle with a flickering light, standing at `offset`
local function candle(parent, at, offset)
	put(parent, "Candle", at, offset + Vector3.new(0, 0.45, 0), Vector3.new(0.9, 0.3, 0.3),
		Enum.Material.SmoothPlastic, COLORS.Cream, false,
		{ shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) }) -- a cylinder lies on its side, so stand it up
	local flame = put(parent, "Flame", at, offset + Vector3.new(0, 1.0, 0), Vector3.new(0.3, 0.3, 0.3),
		Enum.Material.Neon, COLORS.Flame, false, { shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = COLORS.Light
	light.Range = 14
	light.Brightness = 0.9
	light.Parent = flame
	CollectionService:AddTag(light, "CandleLight") -- the CandleFlicker script finds candles by this tag
end

-- An invisible marker part that game scripts can find by name
local function marker(parent, name, at, offset)
	local p = put(parent, name, at, offset, Vector3.new(0.5, 0.5, 0.5), Enum.Material.SmoothPlastic,
		COLORS.Gold, false)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p:SetAttribute("Spot", name)
	return p
end

------------------------------------------------------------------------
-- 4. THE FURNITURE
-- Each function builds one piece in its own local space: x is right,
-- y is up, and the piece faces -Z with its back at +Z.
------------------------------------------------------------------------
local function bed(parent, at, farZ)
	-- `farZ` is the local z of the wall behind the head of the bed. Here
	-- the bed is built facing the door, so the head is at the far wall.
	local m = Instance.new("Model")
	m.Name = "Bed"
	m.Parent = parent
	put(m, "Headboard", at, Vector3.new(0, 2.5, farZ + 0.3), Vector3.new(7.6, 5.0, 0.6), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "HeadboardCap", at, Vector3.new(0, 5.2, farZ + 0.3), Vector3.new(8.0, 0.4, 0.8), Enum.Material.Wood, COLORS.PanelWood, false)
	put(m, "Frame", at, Vector3.new(0, 0.6, farZ + 4.6), Vector3.new(7, 1.2, 8), Enum.Material.Wood, COLORS.PanelWood, true)
	put(m, "Footboard", at, Vector3.new(0, 1.1, farZ + 8.85), Vector3.new(7, 2.2, 0.5), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "Mattress", at, Vector3.new(0, 1.6, farZ + 4.6), Vector3.new(6.6, 0.8, 7.6), Enum.Material.Fabric, COLORS.Cream, false)
	for _, side in ipairs({ -1, 1 }) do
		put(m, "Pillow", at, Vector3.new(side * 1.7, 2.25, farZ + 1.8), Vector3.new(2.4, 0.5, 1.4), Enum.Material.Fabric, COLORS.Cream, false)
	end
	put(m, "Blanket", at, Vector3.new(0, 2.1, farZ + 6.2), Vector3.new(6.7, 0.2, 4.6), Enum.Material.Fabric, COLORS.Blanket, false)
end

local function nightstand(parent, at)
	local m = Instance.new("Model")
	m.Name = "Nightstand"
	m.Parent = parent
	put(m, "Body", at, Vector3.new(0, 1.2, 0), Vector3.new(2.4, 2.4, 2.0), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "Top", at, Vector3.new(0, 2.5, 0), Vector3.new(2.6, 0.2, 2.2), Enum.Material.Wood, COLORS.PanelWood, false)
	candle(m, at, Vector3.new(0, 2.6, 0))
end

local function armchair(parent, at)
	local m = Instance.new("Model")
	m.Name = "Armchair"
	m.Parent = parent
	put(m, "Base", at, Vector3.new(0, 0.7, 0), Vector3.new(3, 1.4, 3), Enum.Material.Fabric, COLORS.Velvet, true)
	put(m, "Back", at, Vector3.new(0, 2.4, 1.1), Vector3.new(3, 2.0, 0.7), Enum.Material.Fabric, COLORS.Velvet, true)
	for _, side in ipairs({ -1, 1 }) do
		put(m, "Arm", at, Vector3.new(side * 1.25, 1.9, 0), Vector3.new(0.5, 1.0, 2.4), Enum.Material.Fabric, COLORS.Velvet, true)
	end
	put(m, "Cushion", at, Vector3.new(0, 1.8, -0.3), Vector3.new(2.2, 0.8, 2.2), Enum.Material.Fabric, COLORS.Velvet, true, { class = "Seat" })
end

local function sideTable(parent, at)
	local m = Instance.new("Model")
	m.Name = "SideTable"
	m.Parent = parent
	put(m, "Top", at, Vector3.new(0, 2.3, 0), Vector3.new(1.8, 0.2, 1.8), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "Stem", at, Vector3.new(0, 1.15, 0), Vector3.new(0.5, 2.3, 0.5), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "Foot", at, Vector3.new(0, 0.1, 0), Vector3.new(1.4, 0.2, 1.4), Enum.Material.Wood, COLORS.DarkWood, true)
	candle(m, at, Vector3.new(0, 2.4, 0))
end

local function wardrobe(parent, at)
	local m = Instance.new("Model")
	m.Name = "Wardrobe"
	m.Parent = parent
	put(m, "Body", at, Vector3.new(0, 4.5, 0), Vector3.new(6, 9, 2.6), Enum.Material.Wood, COLORS.DarkWood, true)
	put(m, "Crown", at, Vector3.new(0, 9.2, 0), Vector3.new(6.4, 0.4, 3.0), Enum.Material.Wood, COLORS.PanelWood, false)
	for _, side in ipairs({ -1, 1 }) do
		put(m, "DoorPanel", at, Vector3.new(side * 1.5, 4.5, -1.35), Vector3.new(2.7, 7.6, 0.15), Enum.Material.Wood, COLORS.PanelWood, false)
		put(m, "Handle", at, Vector3.new(side * 0.35, 4.5, -1.5), Vector3.new(0.15, 0.7, 0.15), Enum.Material.Metal, COLORS.Gold, false)
	end
end

local function desk(parent, at)
	local m = Instance.new("Model")
	m.Name = "Desk"
	m.Parent = parent
	put(m, "Top", at, Vector3.new(0, 3.05, 0), Vector3.new(5, 0.3, 2.4), Enum.Material.Wood, COLORS.DarkWood, true)
	for _, lx in ipairs({ -2.3, 2.3 }) do
		for _, lz in ipairs({ -1.0, 1.0 }) do
			put(m, "Leg", at, Vector3.new(lx, 1.45, lz), Vector3.new(0.3, 2.9, 0.3), Enum.Material.Wood, COLORS.DarkWood, true)
		end
	end
	put(m, "Drawers", at, Vector3.new(1.4, 2.2, 0), Vector3.new(1.9, 1.5, 2.0), Enum.Material.Wood, COLORS.PanelWood, false)
end

local function chair(parent, at)
	local m = Instance.new("Model")
	m.Name = "Chair"
	m.Parent = parent
	put(m, "Seat", at, Vector3.new(0, 1.65, 0), Vector3.new(1.8, 0.3, 1.8), Enum.Material.Wood, COLORS.PanelWood, true, { class = "Seat" })
	put(m, "Back", at, Vector3.new(0, 2.95, 0.8), Vector3.new(1.8, 2.2, 0.25), Enum.Material.Wood, COLORS.DarkWood, true)
	for _, lx in ipairs({ -0.7, 0.7 }) do
		for _, lz in ipairs({ -0.7, 0.7 }) do
			put(m, "Leg", at, Vector3.new(lx, 0.75, lz), Vector3.new(0.25, 1.5, 0.25), Enum.Material.Wood, COLORS.DarkWood, false)
		end
	end
end

-- The window sits on the wall: z = 0 is the wall surface, and the room is
-- in front (-Z). It's made of a dark "view" of the night, a frame, a
-- curtain on each side, and a glass pane called "Sash".
local function window(parent, at)
	local m = Instance.new("Model")
	m.Name = "Window"
	m:SetAttribute("IsOpen", false)
	m.Parent = parent
	put(m, "View", at, Vector3.new(0, 10, -0.05), Vector3.new(6, 9.6, 0.1), Enum.Material.SmoothPlastic, COLORS.Night, false)
	local sash = put(m, "Sash", at, Vector3.new(0, 10, -0.2), Vector3.new(5.8, 9.4, 0.08), Enum.Material.Glass, COLORS.Glass, false)
	sash.Transparency = 0.6
	put(m, "Sill", at, Vector3.new(0, 4.9, -0.5), Vector3.new(7.2, 0.5, 1.0), Enum.Material.Wood, COLORS.DarkWood, false)
	put(m, "Lintel", at, Vector3.new(0, 15.2, -0.25), Vector3.new(7.2, 0.6, 0.5), Enum.Material.Wood, COLORS.DarkWood, false)
	for _, side in ipairs({ -1, 1 }) do
		put(m, "FrameSide", at, Vector3.new(side * 3.3, 10, -0.25), Vector3.new(0.6, 10.2, 0.5), Enum.Material.Wood, COLORS.DarkWood, false)
		put(m, "Curtain", at, Vector3.new(side * 3.0, 9.8, -0.8), Vector3.new(1.6, 10.8, 0.5), Enum.Material.Fabric, COLORS.Velvet, false)
	end
	put(m, "MullionV", at, Vector3.new(0, 10, -0.35), Vector3.new(0.2, 9.6, 0.25), Enum.Material.Wood, COLORS.DarkWood, false)
	put(m, "MullionH", at, Vector3.new(0, 11.2, -0.35), Vector3.new(6, 0.2, 0.25), Enum.Material.Wood, COLORS.DarkWood, false)
	put(m, "CurtainRod", at, Vector3.new(0, 15.9, -0.8), Vector3.new(8.4, 0.2, 0.2), Enum.Material.Metal, COLORS.Gold, false)
end

-- A wall mirror, hung on the wall (z = 0 is the wall surface)
local function mirror(parent, at)
	local m = Instance.new("Model")
	m.Name = "Mirror"
	m:SetAttribute("Covered", false)
	m.Parent = parent
	put(m, "MirrorFrame", at, Vector3.new(0, 8.5, -0.15), Vector3.new(3.6, 6.2, 0.3), Enum.Material.Metal, COLORS.Gold, false)
	local glass = put(m, "MirrorGlass", at, Vector3.new(0, 8.5, -0.32), Vector3.new(3.2, 5.8, 0.1), Enum.Material.Metal, COLORS.Silver, false)
	glass.Reflectance = 0.7
end

------------------------------------------------------------------------
-- 5. WALL CANDLES THAT LAND ON FURNITURE
-- The castle builder hangs wall candles (sconces) on the walls, and some
-- end up right where a window, mirror or wardrobe goes. This lifts any
-- sconce inside a rectangle up above the piece. It keeps its light.
-- (lx0..lx1, lz0..lz1) is the rectangle in room space; topHeight is the
-- height of the furniture above the floor.
------------------------------------------------------------------------
local SCONCE_PARTS = { SconceArm = true, SconceCup = true, Candle = true, Flame = true }

local function liftSconces(room, at, floorY, lx0, lx1, lz0, lz1, topHeight)
	-- turn the room-space rectangle into a rectangle in the world
	local xs, zs = {}, {}
	for _, lx in ipairs({ lx0, lx1 }) do
		for _, lz in ipairs({ lz0, lz1 }) do
			local world = at:PointToWorldSpace(Vector3.new(lx, 0, lz))
			table.insert(xs, world.X)
			table.insert(zs, world.Z)
		end
	end
	local minX, maxX = math.min(xs[1], xs[2], xs[3], xs[4]), math.max(xs[1], xs[2], xs[3], xs[4])
	local minZ, maxZ = math.min(zs[1], zs[2], zs[3], zs[4]), math.max(zs[1], zs[2], zs[3], zs[4])

	for _, plate in ipairs(room:GetChildren()) do
		if plate.Name == "SconcePlate" and plate:IsA("BasePart") then
			local pos = plate.Position
			if pos.X > minX and pos.X < maxX and pos.Z > minZ and pos.Z < maxZ
				and pos.Y < floorY + topHeight + 1 then
				local lift = (floorY + topHeight + 1.8) - pos.Y
				for _, piece in ipairs(room:GetChildren()) do
					if piece == plate or (SCONCE_PARTS[piece.Name] and piece:IsA("BasePart")) then
						local offset = piece.Position - pos
						if math.abs(offset.X) < 2 and math.abs(offset.Y) < 3 and math.abs(offset.Z) < 2 then
							piece.Position = piece.Position + Vector3.new(0, lift, 0)
						end
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- 6. FURNISH EACH ROOM
-- Room space: the origin is the middle of the wall the door is in,
-- on the floor. x is right, y is up, and -Z points deeper into the room,
-- toward the far (outer) wall. A room's depth is `depth`.
------------------------------------------------------------------------
local function furnish(room)
	local zone = room:FindFirstChild("Zone")
	if not zone then
		warn("Skipping " .. room.Name .. " (no Zone)")
		return
	end

	-- remove furniture from an earlier run
	for _, child in ipairs(room:GetChildren()) do
		if child:GetAttribute("GuestRoomBuilder") then
			child:Destroy()
		end
	end

	local width, depth = zone.Size.X, zone.Size.Z
	local halfW = width / 2

	-- floor height: the top of the floorboards, or 0.2 above the slab
	local boards = room:FindFirstChild("Floorboards")
	local floorY = boards and (boards.Position.Y + boards.Size.Y / 2) or (zone.Position.Y - zone.Size.Y / 2 + 0.2)

	-- Front-row rooms (z > 0) have their door on the -Z side and the outer wall
	-- on +Z. Back-row rooms are the opposite. We always build facing the outer
	-- wall, so front-row rooms are turned around (yaw 180 degrees).
	local isFront = zone.Position.Z > 0
	local doorWallZ = isFront and (zone.Position.Z - depth / 2) or (zone.Position.Z + depth / 2)
	local at = CFrame.new(zone.Position.X, floorY, doorWallZ) * CFrame.Angles(0, isFront and math.pi or 0, 0)
	local farZ = -depth -- the outer wall

	-- a position in room space, with an optional turn (degrees) for the piece
	local function frame(lx, lz, yawDegrees)
		return at * CFrame.new(lx, 0, lz) * CFrame.Angles(0, math.rad(yawDegrees or 0), 0)
	end

	local folder = Instance.new("Folder")
	folder.Name = "GuestFurniture"
	folder:SetAttribute("GuestRoomBuilder", true)
	folder.Parent = room

	-- Bed against the far wall, nightstands either side
	bed(folder, at, farZ)
	for _, side in ipairs({ -1, 1 }) do
		nightstand(folder, frame(side * 5.6, farZ + 1.2))
	end

	-- Window on the far wall, to the left of the bed
	local windowX = -(halfW - 6)
	window(folder, frame(windowX, farZ, 180)) -- turned 180 so it faces into the room

	-- Armchair and side table in the far right corner, facing the door
	armchair(folder, frame(halfW - 8, farZ + 2.0, 180))
	sideTable(folder, frame(halfW - 2.2, farZ + 1.6))

	-- Wardrobe on the left wall, facing the room (yaw -90 faces +X)
	local sideZ = farZ + 14
	wardrobe(folder, frame(-halfW + 1.3, sideZ, -90))

	-- Writing desk on the right wall facing the room (yaw +90 faces -X),
	-- with its chair in front, and a mirror on the wall above
	desk(folder, frame(halfW - 1.4, sideZ, 90))
	chair(folder, frame(halfW - 4.6, sideZ, -90))
	mirror(folder, frame(halfW - 0.05, sideZ, 90))

	-- Markers for game scripts
	marker(folder, "CrucifixSpot", at, Vector3.new(0, 8.5, farZ + 0.4))
	marker(folder, "GarlicSpot", at, Vector3.new(4.8, 8, 1.4)) -- on the corridor side of the door frame
	marker(folder, "GuestSpot", at, Vector3.new(0, 3.5, farZ + 13)) -- floor at the foot of the bed

	-- Lift wall candles that landed on top of the furniture
	local margin = 1.5
	liftSconces(room, at, floorY, windowX - 3.8 - margin, windowX + 3.8 + margin, farZ - 1, farZ + 2.5, 15.4)
	liftSconces(room, at, floorY, -5.3, 5.3, farZ - 1, farZ + 2.5, 5.5)
	liftSconces(room, at, floorY, -halfW - 1, -halfW + 4, sideZ - 3 - margin, sideZ + 3 + margin, 9.4)
	liftSconces(room, at, floorY, halfW - 4, halfW + 1, sideZ - 1.8 - margin, sideZ + 1.8 + margin, 11.4)
end

for _, room in ipairs(rooms) do
	furnish(room)
end

------------------------------------------------------------------------
-- 7. FINISH
------------------------------------------------------------------------
if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Furnish Guest Rooms") end)
end

print(string.format("Guest rooms furnished! %d rooms, %d parts. Open a room's GuestFurniture folder to see the pieces.", #rooms, partCount))
