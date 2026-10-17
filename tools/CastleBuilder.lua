--[[
=======================================================================
  CASTLE BUILDER  -  Dracula's BnB
=======================================================================
  Builds Dracula's whole castle in one go:
    * 4 floors (+ flat roof with battlements)
    * 29 rooms: lobby, dining hall, great hall, kitchen, library,
      parlor, crypt, 16 guest rooms, ballroom, chapel, Dracula's
      chamber and study, gallery and observatory
    * a corridor through the middle of every floor
    * a stone switch-back staircase that connects all 4 floors
    * candles everywhere: iron chandeliers, wall sconces, a candle
      on every stair post (they flicker when you press Play)
    * outside: thick stone walls, battlements, 4 corner towers and
      an entrance gatehouse with the grand gothic window

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Open the Command Bar (Window > Command Bar).
    3. Paste this WHOLE file in and click Run. It takes a few seconds.
    4. You'll see "Castle built!" in the Output window.

  Running it again deletes the old castle and builds a fresh one, so
  you can change the settings below and re-run as often as you like.
  It also deletes the old test hall (Floor_MainHall, Walls_MainHall,
  Ceiling_MainHall, Lights_MainHall).

  WHERE THINGS END UP
    Workspace > DraculaCastle
        Exterior   outer walls, towers, gatehouse, roof
        Floor1..4  one folder per floor: the floor slab, the
                   corridor, and one Model per room
    Every room Model has attributes your game scripts can read:
        RoomName, RoomKind (Lobby / Guest / Common / Staff /
        Dracula / Stairs / Corridor), Floor, RoomNumber (guest rooms)
    and an invisible part called "Zone" filling the room, handy for
    checking which room a player or guest is standing in.
=======================================================================
]]

------------------------------------------------------------------------
-- 1. TEXTURE IDS
-- These are the images you uploaded in the Asset Manager.
------------------------------------------------------------------------
local TEX = {
	GOTHIC_PANEL  = "rbxassetid://76266295071293",  -- Gothic Wall Texture Map (pointed arches)
	MARBLE_PANEL  = "rbxassetid://117017022480893", -- Gothic Flat Marble Wall Texture
	STONE_WALL    = "rbxassetid://97942067976603",  -- Dracula Solid Stone Wall
	EXTERIOR      = "rbxassetid://124520103692522", -- Dracula Exterior Wall Texture
	GRAND_WINDOW  = "rbxassetid://137659895876166", -- Dracula Grand Window Wall
	GOTHIC_FLOOR  = "rbxassetid://82856515984682",  -- Gothic Floor Texture Map
	VAULT_CEILING = "rbxassetid://75687684579689",  -- High Gothic Vault Ceiling Texture
}

-- The black marble floor material you made in the Material Manager
local MARBLE_VARIANT = "BlackMarbleFloor"

------------------------------------------------------------------------
-- 2. SETTINGS
------------------------------------------------------------------------
-- Where the castle goes. (0,0,0) = centre of the world, sitting on the Baseplate.
local ORIGIN = Vector3.new(0, 0, 0)

-- Floor-to-floor height of each floor in studs (a character is ~5 studs tall).
-- The ground floor is extra tall. Add a number to add a floor: every floor
-- between the ground floor and the top floor becomes a guest floor.
local FLOOR_HEIGHTS = { 28, 24, 24, 24 }

-- Gap between wall candles (studs). Bigger number = fewer candles = faster game.
local SCONCE_SPACING = 20

-- How far the light from candles reaches (studs) and how bright it is.
local CHANDELIER_RANGE, CHANDELIER_BRIGHTNESS = 40, 1.6
local SCONCE_RANGE, SCONCE_BRIGHTNESS = 18, 0.9

------------------------------------------------------------------------
-- 3. LAYOUT
-- Seen from above, the castle is a rectangle 176 studs wide (X) and
-- 96 deep (Z). The front door faces +Z. On every floor a corridor runs
-- east-west through the middle, with a row of rooms on each side:
--
--     z = -48  +----------------- BACK ROW ------------------+
--              | room | room | STAIRS | room | room          |
--     z = -7   +---------------- corridor --------------------+
--     z =  7   | room |   room   |   room   | room           |
--     z =  48  +----------------- FRONT ROW -----------------+
--                              [ front door ]
------------------------------------------------------------------------
local HALF_W = 88          -- half the castle width  (x goes -88 .. 88)
local HALF_D = 48          -- half the castle depth  (z goes -48 .. 48)
local CORRIDOR_HALF = 7    -- corridor is 14 studs wide (z -7 .. 7)
local T = 1                -- thickness of inside walls
local SHELL_T = 2          -- thickness of the outer castle walls
local PARAPET = 3          -- how far the outer walls rise above the roof

local FRONT = { CORRIDOR_HALF, HALF_D }    -- z range of the front row of rooms
local BACK = { -HALF_D, -CORRIDOR_HALF }   -- z range of the back row
local STAIRS_X = { -10, 10 }               -- x range of the stair hall (back row, centre)

-- Room styles: which texture goes on the walls and what the floor is made of.
--   floor: "Marble" = your black marble, "GothicTiles" = the gothic floor
--          texture, "Wood" = dark floorboards, "Stone" = rough slate
local STYLES = {
	Grand  = { wall = TEX.GOTHIC_PANEL, floor = "Marble" },
	Lobby  = { wall = TEX.GOTHIC_PANEL, floor = "GothicTiles" },
	Guest  = { wall = TEX.MARBLE_PANEL, floor = "Wood", rug = true },
	Study  = { wall = TEX.MARBLE_PANEL, floor = "Wood", rug = true },
	Stone  = { wall = TEX.STONE_WALL,   floor = "Stone" },
	Stair  = { wall = TEX.STONE_WALL,   floor = "Marble" },
}
local CORRIDOR_WALL_TEXTURE = TEX.STONE_WALL   -- the corridor side of room walls

-- Colours used for parts (anything a texture doesn't cover)
local COLORS = {
	WallCore   = Color3.fromRGB(45, 40, 40),
	Trim       = Color3.fromRGB(72, 68, 64),    -- door frames, stair posts
	StairStone = Color3.fromRGB(92, 88, 84),
	DarkWood   = Color3.fromRGB(58, 38, 26),
	Carpet     = Color3.fromRGB(110, 16, 24),   -- blood-red rugs and runners
	Iron       = Color3.fromRGB(32, 30, 30),
	Wax        = Color3.fromRGB(236, 226, 205),
	Flame      = Color3.fromRGB(255, 170, 70),
	Light      = Color3.fromRGB(255, 160, 85),  -- warm candle glow
	OuterStone = Color3.fromRGB(62, 60, 60),
	Roof       = Color3.fromRGB(55, 53, 52),
	Ceiling    = Color3.fromRGB(60, 45, 30),
	Slate      = Color3.fromRGB(75, 72, 70),
}

------------------------------------------------------------------------
-- 4. THE ROOM LIST
-- room(floor, name, x range, z range, style, kind, doors, extras)
-- A door is { side, width, height }. Side is the wall it's in:
--   "N" = +Z side, "S" = -Z side, "W" = -X side, "E" = +X side.
-- Doors are cut through BOTH rooms when two rooms share a wall.
------------------------------------------------------------------------
local NUM_FLOORS = #FLOOR_HEIGHTS
local ROOMS = {}
local function room(f, name, xr, zr, style, kind, doors, extras)
	local r = {
		floor = f, name = name, x0 = xr[1], x1 = xr[2], z0 = zr[1], z1 = zr[2],
		style = style, kind = kind, doors = doors or {},
	}
	for k, v in pairs(extras or {}) do r[k] = v end
	table.insert(ROOMS, r)
end

-- GROUND FLOOR: where guests arrive
room(1, "Dining Hall", { -88, -30 }, FRONT, "Grand", "Common", { { "S", 12, 16 } })
room(1, "Grand Lobby", { -30, 30 }, FRONT, "Lobby", "Lobby",
	{ { "S", 16, 18 }, { "N", 12, 18 }, { "W", 10, 16 }, { "E", 10, 16 } }, { lobby = true })
room(1, "Great Hall", { 30, 88 }, FRONT, "Grand", "Common", { { "S", 12, 16 } })
room(1, "Kitchen", { -88, -49 }, BACK, "Stone", "Staff", { { "N", 8, 12 } })
room(1, "Library", { -49, -10 }, BACK, "Study", "Common", { { "N", 8, 12 } })
room(1, "Parlor", { 10, 49 }, BACK, "Study", "Common", { { "N", 8, 12 } })
room(1, "Crypt", { 49, 88 }, BACK, "Stone", "Dracula", { { "N", 8, 12 } }, { coffin = true })

-- MIDDLE FLOORS: 8 guest rooms each, numbered 201-208, 301-308, ...
for f = 2, NUM_FLOORS - 1 do
	local n = 1
	for _, xr in ipairs({ { -88, -44 }, { -44, 0 }, { 0, 44 }, { 44, 88 } }) do
		local num = f * 100 + n
		room(f, "Guest Room " .. num, xr, FRONT, "Guest", "Guest", { { "S", 7, 12 } }, { number = num })
		n += 1
	end
	for _, xr in ipairs({ { -88, -49 }, { -49, -10 }, { 10, 49 }, { 49, 88 } }) do
		local num = f * 100 + n
		room(f, "Guest Room " .. num, xr, BACK, "Guest", "Guest", { { "N", 7, 12 } }, { number = num })
		n += 1
	end
end

-- TOP FLOOR: Dracula's private floor
local TOP = NUM_FLOORS
room(TOP, "Dracula's Study", { -88, -44 }, FRONT, "Study", "Dracula", { { "S", 7, 12 } })
room(TOP, "Ballroom", { -44, 44 }, FRONT, "Grand", "Common", { { "S", 14, 18 }, { "W", 8, 14 }, { "E", 8, 14 } })
room(TOP, "Portrait Gallery", { 44, 88 }, FRONT, "Grand", "Common", { { "S", 7, 12 } })
room(TOP, "Dracula's Chamber", { -88, -10 }, BACK, "Grand", "Dracula", { { "N", 8, 14 } })
room(TOP, "Chapel", { 10, 49 }, BACK, "Grand", "Common", { { "N", 8, 14 } })
room(TOP, "Observatory", { 49, 88 }, BACK, "Stone", "Common", { { "N", 8, 12 } })

-- The stair hall is on every floor, in the same spot
for f = 1, NUM_FLOORS do
	room(f, "Stair Hall", STAIRS_X, BACK, "Stair", "Stairs", { { "N", 14, 16 } }, { isStair = true })
end

------------------------------------------------------------------------
-- 5. HEIGHTS OF EACH FLOOR
-- LEVEL[f] is the height of the walking surface of floor f.
-- LEVEL[NUM_FLOORS + 1] is the top of the roof.
------------------------------------------------------------------------
local LEVEL = { 1 }
for f = 1, NUM_FLOORS do
	LEVEL[f + 1] = LEVEL[f] + FLOOR_HEIGHTS[f]
end
local ROOF = LEVEL[NUM_FLOORS + 1]
local SHELL_TOP = ROOF + PARAPET

-- Staircase geometry (inside the stair hall). Two flights side by side:
-- flight A climbs away from the corridor to a landing, then flight B
-- turns around and climbs back to the floor above.
local MID = (STAIRS_X[1] + STAIRS_X[2]) / 2
local ST = {
	x0 = STAIRS_X[1] + T,          -- inside face of the west wall
	x1 = STAIRS_X[2] - T,          -- inside face of the east wall
	zNear = BACK[2] - T - 8,       -- end of the 8-stud entry area, bottom of flight A
	zFar = BACK[2] - T - 8 - 21,   -- top of flight A / start of the landing
	zEnd = BACK[1] + T,            -- back wall of the landing
}
local LANE_A = { x0 = ST.x0, x1 = MID - 0.5 }   -- going up, away from the corridor
local LANE_B = { x0 = MID + 0.5, x1 = ST.x1 }   -- going up, back toward the corridor
LANE_A.c = (LANE_A.x0 + LANE_A.x1) / 2
LANE_B.c = (LANE_B.x0 + LANE_B.x1) / 2
-- The opening in each upper floor where flight B comes up through it
local HOLE = { x0 = LANE_B.x0, x1 = LANE_B.x1, z0 = ST.zFar, z1 = ST.zNear }

------------------------------------------------------------------------
-- 6. HELPER FUNCTIONS
------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local candleCount, lightCount, partCount = 0, 0, 0

-- Makes an anchored block between two corners (x0..x1, y0..y1, z0..z1).
-- Coordinates are relative to ORIGIN.
local function box(parent, name, x0, x1, y0, y1, z0, z1, material, color)
	local sx, sy, sz = math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)
	if sx < 0.05 or sy < 0.05 or sz < 0.05 then
		return nil -- too thin to bother with
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = Vector3.new(sx, sy, sz)
	p.Position = ORIGIN + Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color or COLORS.WallCore
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	partCount += 1
	return p
end

-- Makes a block centred on `center`, turned `yaw` degrees around the up axis.
local function turnedBox(parent, name, center, size, yaw, material, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(ORIGIN + center) * CFrame.Angles(0, math.rad(yaw), 0)
	p.Material = material
	p.Color = color
	p.Parent = parent
	partCount += 1
	return p
end

-- Decorations shouldn't block players or cast blocky shadows
local function decor(p)
	if p then
		p.CanCollide = false
		p.CastShadow = false
	end
	return p
end

-- Puts an image on one face of a part. tileU/tileV = size of one copy in studs.
local function addTexture(part, id, face, tileU, tileV)
	if not part or not id or id == "" then return end
	local t = Instance.new("Texture")
	t.Texture = id
	t.Face = face
	t.StudsPerTileU = tileU
	t.StudsPerTileV = tileV
	t.Parent = part
end

-- Tile size close to `target` that fits a whole number of times into `length`,
-- so patterns never get cut off at the corners.
local function fit(length, target)
	local n = math.max(1, math.floor(length / target + 0.5))
	return length / n
end

-- Removes a rectangle (the stair opening) from another rectangle.
-- Returns up to 4 rectangles that cover what's left.
local function subtractRect(r, h)
	local out = {}
	local function add(x0, x1, z0, z1)
		if x1 - x0 > 0.01 and z1 - z0 > 0.01 then
			table.insert(out, { x0 = x0, x1 = x1, z0 = z0, z1 = z1 })
		end
	end
	local hx0, hx1 = math.max(r.x0, h.x0), math.min(r.x1, h.x1)
	local hz0, hz1 = math.max(r.z0, h.z0), math.min(r.z1, h.z1)
	if hx0 >= hx1 or hz0 >= hz1 then
		add(r.x0, r.x1, r.z0, r.z1)
		return out
	end
	add(r.x0, hx0, r.z0, r.z1)  -- strip on the -X side of the hole
	add(hx1, r.x1, r.z0, r.z1)  -- strip on the +X side
	add(hx0, hx1, r.z0, hz0)    -- piece on the -Z side
	add(hx0, hx1, hz1, r.z1)    -- piece on the +Z side
	return out
end

------------------------------------------------------------------------
-- DOORS
-- First turn every room's door list into exact positions, so that a
-- wall shared by two rooms gets the same hole cut on both sides.
------------------------------------------------------------------------
local DOORS = {}
for _, r in ipairs(ROOMS) do
	for _, d in ipairs(r.doors) do
		local side, w, h = d[1], d[2], d[3]
		local door = { floor = r.floor, w = w, h = h }
		if side == "S" then door.line, door.at, door.center = "z", r.z0, (r.x0 + r.x1) / 2 end
		if side == "N" then door.line, door.at, door.center = "z", r.z1, (r.x0 + r.x1) / 2 end
		if side == "W" then door.line, door.at, door.center = "x", r.x0, (r.z0 + r.z1) / 2 end
		if side == "E" then door.line, door.at, door.center = "x", r.x1, (r.z0 + r.z1) / 2 end
		table.insert(DOORS, door)
	end
end

-- Finds the doorways in a wall that sits on the line x = at or z = at,
-- between a0 and a1. onlyFloor = nil means "any floor" (used for the outer walls).
local function gapsOnLine(line, at, a0, a1, onlyFloor)
	local gaps = {}
	for _, d in ipairs(DOORS) do
		if d.line == line and math.abs(d.at - at) < 0.01 and d.center > a0 and d.center < a1
			and (onlyFloor == nil or d.floor == onlyFloor) then
			local bottom = LEVEL[d.floor]
			table.insert(gaps, { s = d.center - d.w / 2, e = d.center + d.w / 2, bottom = bottom, top = bottom + d.h })
		end
	end
	table.sort(gaps, function(g1, g2) return g1.s < g2.s end)
	return gaps
end

-- True if position `a` along a wall is clear of all doorways (with a margin)
local function clearOfDoors(gaps, a, margin)
	for _, g in ipairs(gaps) do
		if a > g.s - margin and a < g.e + margin then return false end
	end
	return true
end

-- A stone frame around a doorway (two posts and a lintel)
local function doorFrame(parent, along, s, e, c0, c1, yb, yt)
	local d0, d1 = c0 - 0.3, c1 + 0.3  -- sticks out 0.3 studs on both sides of the wall
	local function piece(a0, a1, y0, y1)
		if along == "X" then
			box(parent, "DoorFrame", a0, a1, y0, y1, d0, d1, Enum.Material.Slate, COLORS.Trim)
		else
			box(parent, "DoorFrame", d0, d1, y0, y1, a0, a1, Enum.Material.Slate, COLORS.Trim)
		end
	end
	piece(s - 1, s, yb, yt + 1.2)
	piece(e, e + 1, yb, yt + 1.2)
	piece(s - 1, e + 1, yt, yt + 1.2)
end

-- Builds one straight wall with doorways cut out of it.
--   along   "X" or "Z": the direction the wall runs
--   a0..a1  where it starts and ends along that direction
--   c0..c1  its thickness, in the other direction
--   y0..y1  bottom and top
--   gaps    doorways (from gapsOnLine)
--   faces   list of { face = NormalId, tex = id, tile = optional size }
-- Panel textures are sized so ONE panel fills the wall floor-to-ceiling.
local function wallRun(parent, name, along, a0, a1, c0, c1, y0, y1, gaps, faces, withFrames)
	local H = y1 - y0
	local function piece(kind, s, e, yb, yt)
		local p
		if along == "X" then
			p = box(parent, name, s, e, yb, yt, c0, c1)
		else
			p = box(parent, name, c0, c1, yb, yt, s, e)
		end
		if not p then return end
		for _, spec in ipairs(faces) do
			if spec.tile then
				addTexture(p, spec.tex, spec.face, spec.tile, spec.tile)
			elseif kind == "full" then
				addTexture(p, spec.tex, spec.face, fit(e - s, H), H)
			else
				-- the piece above a door shows the top of the panel, lined up with the walls beside it
				addTexture(p, spec.tex, spec.face, H, H)
			end
		end
	end

	local cursor = a0
	for _, g in ipairs(gaps) do
		local s, e = math.max(g.s, a0), math.min(g.e, a1)
		if e > s then
			if s > cursor then piece("full", cursor, s, y0, y1) end
			if g.bottom > y0 + 0.05 then piece("sill", s, e, y0, g.bottom) end
			if g.top < y1 - 0.05 then piece("header", s, e, g.top, y1) end
			if withFrames then doorFrame(parent, along, s, e, c0, c1, g.bottom, g.top) end
			cursor = math.max(cursor, e)
		end
	end
	if a1 > cursor then piece("full", cursor, a1, y0, y1) end
end

------------------------------------------------------------------------
-- CANDLES
------------------------------------------------------------------------
-- One candle standing at `base` (the point under the middle of the candle).
-- If light is true it also gets a glowing PointLight.
local function candle(parent, base, light, range, brightness, shadows)
	local stick = Instance.new("Part")
	stick.Name = "Candle"
	stick.Shape = Enum.PartType.Cylinder
	stick.Size = Vector3.new(1.2, 0.35, 0.35) -- a cylinder's length runs along X...
	stick.CFrame = CFrame.new(ORIGIN + base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)) -- ...so stand it up
	stick.Anchored = true
	stick.Material = Enum.Material.SmoothPlastic
	stick.Color = COLORS.Wax
	stick.Parent = parent
	decor(stick)

	local flame = Instance.new("Part")
	flame.Name = "Flame"
	flame.Shape = Enum.PartType.Ball
	flame.Size = Vector3.new(0.3, 0.3, 0.3)
	flame.Position = ORIGIN + base + Vector3.new(0, 1.35, 0)
	flame.Anchored = true
	flame.Material = Enum.Material.Neon
	flame.Color = COLORS.Flame
	flame.Parent = parent
	decor(flame)
	partCount += 2
	candleCount += 1

	if light then
		local l = Instance.new("PointLight")
		l.Color = COLORS.Light
		l.Range = range
		l.Brightness = brightness
		l.Shadows = shadows or false
		l.Parent = flame
		CollectionService:AddTag(l, "CandleLight") -- the flicker script finds candles by this tag
		lightCount += 1
	end
end

-- A wall candle. `pos` is the spot on the wall's surface, `dir` points into the room.
local function sconce(parent, pos, dir)
	local alongX = math.abs(dir.X) > 0.5
	local function sized(along, across, tall)
		if alongX then return Vector3.new(along, tall, across) end
		return Vector3.new(across, tall, along)
	end
	decor(turnedBox(parent, "SconcePlate", pos + dir * 0.1, sized(0.2, 0.9, 1.4), 0, Enum.Material.Metal, COLORS.Iron))
	decor(turnedBox(parent, "SconceArm", pos + dir * 0.6 + Vector3.new(0, -0.3, 0), sized(1.0, 0.25, 0.25), 0, Enum.Material.Metal, COLORS.Iron))
	decor(turnedBox(parent, "SconceCup", pos + dir * 1.15 + Vector3.new(0, -0.15, 0), Vector3.new(0.6, 0.2, 0.6), 0, Enum.Material.Metal, COLORS.Iron))
	candle(parent, pos + dir * 1.15 + Vector3.new(0, -0.05, 0), true, SCONCE_RANGE, SCONCE_BRIGHTNESS, false)
end

-- A row of wall candles along a wall's inside face.
--   along "X"/"Z", a0..a1 = length of the wall, c = position of the face,
--   sign = +1/-1 which way is "into the room", y = height
local function sconceRow(parent, along, a0, a1, c, sign, y, gaps)
	local count = math.max(1, math.floor((a1 - a0) / SCONCE_SPACING))
	for i = 1, count do
		local a = a0 + (a1 - a0) * (i - 0.5) / count
		if clearOfDoors(gaps, a, 2) then
			if along == "X" then
				sconce(parent, Vector3.new(a, y, c), Vector3.new(0, 0, sign))
			else
				sconce(parent, Vector3.new(c, y, a), Vector3.new(sign, 0, 0))
			end
		end
	end
end

-- An iron ring chandelier hanging from the ceiling on a chain.
local function chandelier(parent, center, radius, candles, ceilingY)
	decor(box(parent, "Chain", center.X - 0.12, center.X + 0.12, center.Y + 0.15, ceilingY, center.Z - 0.12, center.Z + 0.12, Enum.Material.Metal, COLORS.Iron))
	local ring = Instance.new("Part")
	ring.Name = "ChandelierRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(ORIGIN + center) * CFrame.Angles(0, 0, math.rad(90)) -- lie the disc flat
	ring.Anchored = true
	ring.Material = Enum.Material.Metal
	ring.Color = COLORS.Iron
	ring.Parent = parent
	decor(ring)
	partCount += 1
	for k = 1, candles do
		local a = (k / candles) * math.pi * 2
		candle(parent, center + Vector3.new(math.cos(a) * radius * 0.8, 0.15, math.sin(a) * radius * 0.8), false)
	end
	-- one light for the whole chandelier, at flame height
	local glow = decor(box(parent, "ChandelierGlow", center.X - 0.1, center.X + 0.1, center.Y + 1.4, center.Y + 1.6, center.Z - 0.1, center.Z + 0.1))
	glow.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = COLORS.Light
	l.Range = CHANDELIER_RANGE
	l.Brightness = CHANDELIER_BRIGHTNESS
	l.Shadows = true
	l.Parent = glow
	CollectionService:AddTag(l, "CandleLight")
	lightCount += 1
end

------------------------------------------------------------------------
-- FLOOR FINISHES, CEILINGS, ROOM ZONES
------------------------------------------------------------------------
-- Puts a floor finish on top of the slab. Returns the height of the new surface.
local function floorFinish(parent, kind, x0, x1, z0, z1, y)
	if kind == "Wood" then
		box(parent, "Floorboards", x0, x1, y, y + 0.2, z0, z1, Enum.Material.WoodPlanks, COLORS.DarkWood)
		return y + 0.2
	elseif kind == "Stone" then
		box(parent, "StoneFloor", x0, x1, y, y + 0.2, z0, z1, Enum.Material.Slate, COLORS.Slate)
		return y + 0.2
	elseif kind == "GothicTiles" then
		local p = box(parent, "GothicFloor", x0, x1, y, y + 0.2, z0, z1, Enum.Material.Marble, COLORS.WallCore)
		addTexture(p, TEX.GOTHIC_FLOOR, Enum.NormalId.Top, fit(x1 - x0, 24), fit(z1 - z0, 24))
		return y + 0.2
	end
	return y -- "Marble": the slab itself is already black marble
end

-- A thin ceiling panel just under the slab above, with the vault texture underneath
local function ceilingPanel(parent, rc, y)
	local p = box(parent, "Ceiling", rc.x0, rc.x1, y - 0.2, y, rc.z0, rc.z1, Enum.Material.SmoothPlastic, COLORS.Ceiling)
	addTexture(p, TEX.VAULT_CEILING, Enum.NormalId.Bottom, fit(rc.x1 - rc.x0, 20), fit(rc.z1 - rc.z0, 20))
end

-- Invisible box filling a room, for game scripts ("which room is this player in?")
local function zone(parent, x0, x1, y0, y1, z0, z1)
	local p = box(parent, "Zone", x0, x1, y0, y1, z0, z1)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
end

------------------------------------------------------------------------
-- 7. START BUILDING
------------------------------------------------------------------------
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Build Dracula's Castle") end)

-- Clear out the old castle and the old test hall
for _, oldName in ipairs({ "DraculaCastle", "Floor_MainHall", "Walls_MainHall", "Ceiling_MainHall", "Lights_MainHall" }) do
	local old = workspace:FindFirstChild(oldName)
	while old do
		old:Destroy()
		old = workspace:FindFirstChild(oldName)
	end
end

local castle = Instance.new("Model")
castle.Name = "DraculaCastle"
local exterior = Instance.new("Folder")
exterior.Name = "Exterior"
exterior.Parent = castle
local FLOOR_FOLDERS = {}
for f = 1, NUM_FLOORS do
	local folder = Instance.new("Folder")
	folder.Name = "Floor" .. f
	folder.Parent = castle
	FLOOR_FOLDERS[f] = folder
end

------------------------------------------------------------------------
-- 8. FLOOR SLABS AND ROOF
-- Every floor is one big slab of black marble. Upper floors have an
-- opening where the staircase comes up through them.
------------------------------------------------------------------------
local FOOTPRINT = { x0 = -HALF_W, x1 = HALF_W, z0 = -HALF_D, z1 = HALF_D }
for f = 1, NUM_FLOORS do
	local slabs = Instance.new("Folder")
	slabs.Name = "FloorSlab"
	slabs.Parent = FLOOR_FOLDERS[f]
	local rects = (f >= 2) and subtractRect(FOOTPRINT, HOLE) or { FOOTPRINT }
	for _, rc in ipairs(rects) do
		local p = box(slabs, "Slab", rc.x0, rc.x1, LEVEL[f] - 1, LEVEL[f], rc.z0, rc.z1, Enum.Material.Marble, Color3.fromRGB(255, 255, 255))
		if p then p.MaterialVariant = MARBLE_VARIANT end
	end
end
box(exterior, "Roof", -HALF_W, HALF_W, ROOF - 1, ROOF, -HALF_D, HALF_D, Enum.Material.Slate, COLORS.Roof)

------------------------------------------------------------------------
-- 9. THE STAIRCASE (built inside the stair hall on each floor)
------------------------------------------------------------------------
local function buildStairs(model, f)
	local y0 = LEVEL[f]
	local yTop = LEVEL[f + 1] - 1 -- underside of the floor above

	-- Stone wall between the two flights, so nobody falls into the stairwell
	local spine = box(model, "StairSpine", MID - 0.5, MID + 0.5, y0, yTop, ST.zFar, ST.zNear, Enum.Material.Slate, COLORS.StairStone)
	addTexture(spine, TEX.STONE_WALL, Enum.NormalId.Left, fit(ST.zNear - ST.zFar, yTop - y0), yTop - y0)
	addTexture(spine, TEX.STONE_WALL, Enum.NormalId.Right, fit(ST.zNear - ST.zFar, yTop - y0), yTop - y0)

	-- Stone post at the foot of the stairs with a candle on top
	box(model, "NewelPost", MID - 1, MID + 1, y0, y0 + 4.5, ST.zNear, ST.zNear + 2, Enum.Material.Slate, COLORS.Trim)
	candle(model, Vector3.new(MID, y0 + 4.5, ST.zNear + 1), true, 14, 1, false)

	-- Candles by the stair hall door
	sconce(model, Vector3.new(MID - 8, y0 + 9, BACK[2] - T), Vector3.new(0, 0, -1))
	sconce(model, Vector3.new(MID + 8, y0 + 9, BACK[2] - T), Vector3.new(0, 0, -1))

	if f == NUM_FLOORS then
		-- Top floor: the stairs end here. A stone railing guards the opening.
		box(model, "Balustrade", HOLE.x0, HOLE.x1, y0, y0 + 3.5, ST.zFar - 0.6, ST.zFar, Enum.Material.Slate, COLORS.Trim)
		sconce(model, Vector3.new(MID - 5, y0 + 9, ST.zEnd), Vector3.new(0, 0, 1))
		sconce(model, Vector3.new(MID + 5, y0 + 9, ST.zEnd), Vector3.new(0, 0, 1))
		return
	end

	local half = FLOOR_HEIGHTS[f] / 2              -- each flight climbs half a floor
	local steps = math.max(1, math.floor(half + 0.5)) -- about 1 stud per step
	local rise = half / steps
	local tread = (ST.zNear - ST.zFar) / steps

	-- Flight A: solid stone steps climbing away from the corridor
	for i = 1, steps do
		local top = y0 + i * rise
		local zHi = ST.zNear - (i - 1) * tread
		local zLo = ST.zNear - i * tread
		box(model, "Step", LANE_A.x0, LANE_A.x1, y0, top, zLo, zHi, Enum.Material.Slate, COLORS.StairStone)
		decor(box(model, "StairRunner", LANE_A.c - 2, LANE_A.c + 2, top, top + 0.05, zLo, zHi, Enum.Material.Fabric, COLORS.Carpet))
	end

	-- The landing, halfway up
	box(model, "Landing", ST.x0, ST.x1, y0, y0 + half, ST.zEnd, ST.zFar, Enum.Material.Slate, COLORS.StairStone)
	decor(box(model, "StairRunner", LANE_A.c - 2, LANE_B.c + 2, y0 + half, y0 + half + 0.05, ST.zEnd + 2, ST.zFar, Enum.Material.Fabric, COLORS.Carpet))

	-- Flight B: steps climbing back toward the corridor, up through the opening
	-- in the floor above. They're thick slabs (not solid to the ground) so
	-- the flight below has headroom.
	for j = 1, steps do
		local top = y0 + half + j * rise
		local zLo = ST.zFar + (j - 1) * tread
		local zHi = ST.zFar + j * tread
		box(model, "Step", LANE_B.x0, LANE_B.x1, top - 1.5, top, zLo, zHi, Enum.Material.Slate, COLORS.StairStone)
		decor(box(model, "StairRunner", LANE_B.c - 2, LANE_B.c + 2, top, top + 0.05, zLo, zHi, Enum.Material.Fabric, COLORS.Carpet))
	end

	-- Candles: above the landing, and halfway up flight A
	sconce(model, Vector3.new(MID - 5, y0 + half + 7, ST.zEnd), Vector3.new(0, 0, 1))
	sconce(model, Vector3.new(MID + 5, y0 + half + 7, ST.zEnd), Vector3.new(0, 0, 1))
	sconce(model, Vector3.new(ST.x0, y0 + half / 2 + 7, (ST.zNear + ST.zFar) / 2), Vector3.new(1, 0, 0))
end

------------------------------------------------------------------------
-- 10. ROOMS
------------------------------------------------------------------------
local function buildRoom(r)
	local f = r.floor
	local y0, y1 = LEVEL[f], LEVEL[f + 1] - 1 -- floor surface .. ceiling
	local style = STYLES[r.style]

	local model = Instance.new("Model")
	model.Name = r.name
	model:SetAttribute("RoomName", r.name)
	model:SetAttribute("RoomKind", r.kind)
	model:SetAttribute("Floor", f)
	if r.number then model:SetAttribute("RoomNumber", r.number) end
	model.Parent = FLOOR_FOLDERS[f]

	-- inside edges of the room (inside the walls)
	local ix0, ix1, iz0, iz1 = r.x0 + T, r.x1 - T, r.z0 + T, r.z1 - T
	local frontRow = r.z0 >= 0 -- front-row rooms have the corridor on their -Z side

	-- textures for a wall: the room's own texture inside, stone on the corridor side
	local function faces(insideFace, outsideFace, outsideIsCorridor)
		local list = { { face = insideFace, tex = style.wall } }
		if outsideIsCorridor then
			table.insert(list, { face = outsideFace, tex = CORRIDOR_WALL_TEXTURE })
		end
		return list
	end

	local gS = gapsOnLine("z", r.z0, r.x0, r.x1, f)
	local gN = gapsOnLine("z", r.z1, r.x0, r.x1, f)
	local gW = gapsOnLine("x", r.x0, r.z0, r.z1, f)
	local gE = gapsOnLine("x", r.x1, r.z0, r.z1, f)

	-- the four walls (the -Z and +Z walls run the full width, the side walls fit between them)
	wallRun(model, "Wall", "X", r.x0, r.x1, r.z0, r.z0 + T, y0, y1, gS, faces(Enum.NormalId.Back, Enum.NormalId.Front, frontRow), true)
	wallRun(model, "Wall", "X", r.x0, r.x1, r.z1 - T, r.z1, y0, y1, gN, faces(Enum.NormalId.Front, Enum.NormalId.Back, not frontRow), true)
	wallRun(model, "Wall", "Z", iz0, iz1, r.x0, r.x0 + T, y0, y1, gW, faces(Enum.NormalId.Right, Enum.NormalId.Left, false), true)
	wallRun(model, "Wall", "Z", iz0, iz1, r.x1 - T, r.x1, y0, y1, gE, faces(Enum.NormalId.Left, Enum.NormalId.Right, false), true)

	-- floor finish and rug
	local floorY = floorFinish(model, style.floor, ix0, ix1, iz0, iz1, y0)
	if style.rug then
		local w, d = ix1 - ix0, iz1 - iz0
		local cx, cz = (ix0 + ix1) / 2, (iz0 + iz1) / 2
		decor(box(model, "Rug", cx - w * 0.3, cx + w * 0.3, floorY, floorY + 0.08, cz - d * 0.28, cz + d * 0.28, Enum.Material.Fabric, COLORS.Carpet))
	end

	-- ceiling (the stair hall's ceiling has the stair opening cut out of it)
	local interior = { x0 = ix0, x1 = ix1, z0 = iz0, z1 = iz1 }
	local ceilingRects = (r.isStair and f < NUM_FLOORS) and subtractRect(interior, HOLE) or { interior }
	for _, rc in ipairs(ceilingRects) do
		ceilingPanel(model, rc, y1)
	end

	-- candles
	if r.isStair then
		buildStairs(model, f)
	else
		local w, d = ix1 - ix0, iz1 - iz0
		local long = math.max(w, d)
		local count = (long >= 70 and 3) or (long >= 45 and 2) or 1
		local hang = math.min(7, (y1 - y0) * 0.3)
		for i = 1, count do
			local t = (i - 0.5) / count
			local cx = (w >= d) and (ix0 + w * t) or (ix0 + ix1) / 2
			local cz = (w >= d) and (iz0 + iz1) / 2 or (iz0 + d * t)
			chandelier(model, Vector3.new(cx, y1 - hang, cz), 3, 6, y1 - 0.2)
		end
		-- wall candles along the two long walls
		if w >= d then
			sconceRow(model, "X", ix0, ix1, iz0, 1, y0 + 9, gS)
			sconceRow(model, "X", ix0, ix1, iz1, -1, y0 + 9, gN)
		else
			sconceRow(model, "Z", iz0, iz1, ix0, 1, y0 + 9, gW)
			sconceRow(model, "Z", iz0, iz1, ix1, -1, y0 + 9, gE)
		end
	end

	-- special furniture
	if r.lobby then
		-- check-in desk facing the front door
		local dz = iz0 + 12
		box(model, "CheckInDesk", -8, 8, floorY, floorY + 3.5, dz - 1.5, dz + 1.5, Enum.Material.Wood, COLORS.DarkWood)
		box(model, "CheckInDeskTop", -8.5, 8.5, floorY + 3.5, floorY + 3.8, dz - 2, dz + 2, Enum.Material.Wood, COLORS.DarkWood)
		candle(model, Vector3.new(-7.5, floorY + 3.8, dz), true, 14, 1, false)
		candle(model, Vector3.new(7.5, floorY + 3.8, dz), true, 14, 1, false)
		-- where players appear when they join
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "CastleSpawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 0.2, 8)
		spawn.Position = ORIGIN + Vector3.new(0, floorY + 0.1, iz1 - 10)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = model
	end
	if r.coffin then
		-- Dracula's coffin (placeholder until you make a real one in Meshy)
		local cx, cz = (ix0 + ix1) / 2, (iz0 + iz1) / 2
		box(model, "Coffin", cx - 2.2, cx + 2.2, floorY, floorY + 2.2, cz - 4.5, cz + 4.5, Enum.Material.Wood, Color3.fromRGB(25, 15, 12))
		box(model, "CoffinLid", cx - 2.5, cx + 2.5, floorY + 2.2, floorY + 2.7, cz - 4.8, cz + 4.8, Enum.Material.Wood, Color3.fromRGB(40, 22, 18))
		candle(model, Vector3.new(cx, floorY, cz - 7), true, 14, 1, true)
		candle(model, Vector3.new(cx, floorY, cz + 7), true, 14, 1, true)
	end

	zone(model, ix0, ix1, y0, y1, iz0, iz1)
end

for _, r in ipairs(ROOMS) do
	buildRoom(r)
end

------------------------------------------------------------------------
-- 11. CORRIDORS (one per floor)
------------------------------------------------------------------------
for f = 1, NUM_FLOORS do
	local y0, y1 = LEVEL[f], LEVEL[f + 1] - 1
	local model = Instance.new("Model")
	model.Name = "Corridor"
	model:SetAttribute("RoomName", "Corridor")
	model:SetAttribute("RoomKind", "Corridor")
	model:SetAttribute("Floor", f)
	model.Parent = FLOOR_FOLDERS[f]

	local cz0, cz1 = -CORRIDOR_HALF, CORRIDOR_HALF
	local floorY = floorFinish(model, "GothicTiles", -HALF_W, HALF_W, cz0, cz1, y0)
	decor(box(model, "Runner", -HALF_W + 4, HALF_W - 4, floorY, floorY + 0.08, -2.5, 2.5, Enum.Material.Fabric, COLORS.Carpet))
	ceilingPanel(model, { x0 = -HALF_W, x1 = HALF_W, z0 = cz0, z1 = cz1 }, y1)

	-- three chandeliers down the middle
	for i = 1, 3 do
		local x = -HALF_W + (2 * HALF_W) * (i - 0.5) / 3
		chandelier(model, Vector3.new(x, y1 - 6, 0), 2.5, 5, y1 - 0.2)
	end
	-- wall candles on both sides, skipping doorways
	sconceRow(model, "X", -HALF_W, HALF_W, cz1, -1, y0 + 9, gapsOnLine("z", cz1, -HALF_W, HALF_W, f))
	sconceRow(model, "X", -HALF_W, HALF_W, cz0, 1, y0 + 9, gapsOnLine("z", cz0, -HALF_W, HALF_W, f))

	zone(model, -HALF_W, HALF_W, y0, y1, cz0, cz1)
end

------------------------------------------------------------------------
-- 12. OUTSIDE: walls, battlements, towers, gatehouse
------------------------------------------------------------------------
local W2, D2 = HALF_W + SHELL_T, HALF_D + SHELL_T -- outside edge of the outer walls

-- the four outer walls (outside: windows & gargoyles; inside: plain stone)
wallRun(exterior, "OuterWall", "X", -W2, W2, HALF_D, D2, 0, SHELL_TOP, gapsOnLine("z", HALF_D, -W2, W2),
	{ { face = Enum.NormalId.Back, tex = TEX.EXTERIOR, tile = 48 }, { face = Enum.NormalId.Front, tex = TEX.STONE_WALL, tile = 24 } }, false)
wallRun(exterior, "OuterWall", "X", -W2, W2, -D2, -HALF_D, 0, SHELL_TOP, gapsOnLine("z", -HALF_D, -W2, W2),
	{ { face = Enum.NormalId.Front, tex = TEX.EXTERIOR, tile = 48 }, { face = Enum.NormalId.Back, tex = TEX.STONE_WALL, tile = 24 } }, false)
wallRun(exterior, "OuterWall", "Z", -HALF_D, HALF_D, -W2, -HALF_W, 0, SHELL_TOP, gapsOnLine("x", -HALF_W, -HALF_D, HALF_D),
	{ { face = Enum.NormalId.Left, tex = TEX.EXTERIOR, tile = 48 }, { face = Enum.NormalId.Right, tex = TEX.STONE_WALL, tile = 24 } }, false)
wallRun(exterior, "OuterWall", "Z", -HALF_D, HALF_D, HALF_W, W2, 0, SHELL_TOP, gapsOnLine("x", HALF_W, -HALF_D, HALF_D),
	{ { face = Enum.NormalId.Right, tex = TEX.EXTERIOR, tile = 48 }, { face = Enum.NormalId.Left, tex = TEX.STONE_WALL, tile = 24 } }, false)

-- battlements: a row of stone blocks along the top of a wall
local function battlements(parent, along, a0, a1, c0, c1, y)
	local a = a0 + 2
	while a + 1 <= a1 do
		if along == "X" then
			box(parent, "Merlon", a - 1, a + 1, y, y + 3, c0, c1, Enum.Material.Slate, COLORS.OuterStone)
		else
			box(parent, "Merlon", c0, c1, y, y + 3, a - 1, a + 1, Enum.Material.Slate, COLORS.OuterStone)
		end
		a += 4
	end
end
battlements(exterior, "X", -W2, W2, HALF_D, D2, SHELL_TOP)
battlements(exterior, "X", -W2, W2, -D2, -HALF_D, SHELL_TOP)
battlements(exterior, "Z", -HALF_D, HALF_D, -W2, -HALF_W, SHELL_TOP)
battlements(exterior, "Z", -HALF_D, HALF_D, HALF_W, W2, SHELL_TOP)

-- A pointed gothic spire: a stack of round slate discs, each one smaller
-- than the one below, with an iron spike on top.
local SPIRE_COLOR = Color3.fromRGB(38, 38, 46)
local function spire(parent, cx, cz, baseY, radius, height, layers)
	local layerH = height / layers
	for i = 0, layers - 1 do
		local r = radius * (1 - i / layers) + 0.3
		local disc = Instance.new("Part")
		disc.Name = "Spire"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(layerH, r * 2, r * 2)
		disc.CFrame = CFrame.new(ORIGIN + Vector3.new(cx, baseY + (i + 0.5) * layerH, cz)) * CFrame.Angles(0, 0, math.rad(90))
		disc.Anchored = true
		disc.Material = Enum.Material.Slate
		disc.Color = SPIRE_COLOR
		disc.Parent = parent
		partCount += 1
	end
	decor(box(parent, "Finial", cx - 0.2, cx + 0.2, baseY + height, baseY + height + 4, cz - 0.2, cz + 0.2, Enum.Material.Metal, COLORS.Iron))
end

-- Corner towers: 8-sided, built from 4 overlapping blocks turned 0/45/90/135 degrees.
-- They sit just outside each corner so they don't poke into the rooms.
local TOWER_R = 10                       -- distance from the centre to each flat side
local TOWER_SIDE = 2 * TOWER_R * math.tan(math.rad(22.5))
local TOWER_TOP = SHELL_TOP + 16
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local cx, cz = sx * (HALF_W + 7.5), sz * (HALF_D + 7.5)
		local tower = Instance.new("Model")
		tower.Name = "Tower"
		tower.Parent = exterior
		for k = 0, 3 do
			local p = turnedBox(tower, "TowerWall", Vector3.new(cx, TOWER_TOP / 2, cz), Vector3.new(TOWER_R * 2, TOWER_TOP, TOWER_SIDE),
				k * 45, Enum.Material.Slate, COLORS.OuterStone)
			addTexture(p, TEX.EXTERIOR, Enum.NormalId.Left, 44, 44)
			addTexture(p, TEX.EXTERIOR, Enum.NormalId.Right, 44, 44)
		end
		for k = 0, 11 do
			local a = k * 30
			local pos = Vector3.new(cx + math.cos(math.rad(a)) * (TOWER_R - 1.2), TOWER_TOP + 1.5, cz + math.sin(math.rad(a)) * (TOWER_R - 1.2))
			turnedBox(tower, "Merlon", pos, Vector3.new(2, 3, 2.6), -a, Enum.Material.Slate, COLORS.OuterStone)
		end
		spire(tower, cx, cz, TOWER_TOP, TOWER_R - 2.5, 30, 15)
	end
end

-- Gatehouse: a tall block in front of the main door with the grand window
local GATE_Z0, GATE_Z1 = D2, D2 + 8
local GATE_HALF = 24
local GATE_TOP = SHELL_TOP + 10
local lobbyDoor = gapsOnLine("z", HALF_D, -W2, W2)[1]
local gate = Instance.new("Model")
gate.Name = "Gatehouse"
gate.Parent = exterior
if lobbyDoor then
	local doorTop = lobbyDoor.top
	local pl = box(gate, "GatePier", -GATE_HALF, lobbyDoor.s, 0, doorTop, GATE_Z0, GATE_Z1, Enum.Material.Slate, COLORS.OuterStone)
	local pr = box(gate, "GatePier", lobbyDoor.e, GATE_HALF, 0, doorTop, GATE_Z0, GATE_Z1, Enum.Material.Slate, COLORS.OuterStone)
	addTexture(pl, TEX.STONE_WALL, Enum.NormalId.Back, 24, 24)
	addTexture(pr, TEX.STONE_WALL, Enum.NormalId.Back, 24, 24)
	local head = box(gate, "GateTower", -GATE_HALF, GATE_HALF, doorTop, GATE_TOP, GATE_Z0, GATE_Z1, Enum.Material.Slate, COLORS.OuterStone)
	addTexture(head, TEX.GRAND_WINDOW, Enum.NormalId.Back, GATE_HALF * 2, GATE_HALF * 2)
	addTexture(head, TEX.EXTERIOR, Enum.NormalId.Left, 48, 48)
	addTexture(head, TEX.EXTERIOR, Enum.NormalId.Right, 48, 48)
	box(gate, "Threshold", lobbyDoor.s, lobbyDoor.e, 0, LEVEL[1], HALF_D, GATE_Z1, Enum.Material.Slate, COLORS.Slate)
	doorFrame(gate, "X", lobbyDoor.s, lobbyDoor.e, GATE_Z1 - 1, GATE_Z1, LEVEL[1], doorTop)
	battlements(gate, "X", -GATE_HALF, GATE_HALF, GATE_Z1 - 2, GATE_Z1, GATE_TOP)
	spire(gate, -GATE_HALF + 3, GATE_Z0 + 4, GATE_TOP, 2.5, 14, 7)
	spire(gate, GATE_HALF - 3, GATE_Z0 + 4, GATE_TOP, 2.5, 14, 7)
	-- candles either side of the entrance
	sconce(gate, Vector3.new(lobbyDoor.s - 3, LEVEL[1] + 10, GATE_Z1), Vector3.new(0, 0, 1))
	sconce(gate, Vector3.new(lobbyDoor.e + 3, LEVEL[1] + 10, GATE_Z1), Vector3.new(0, 0, 1))
end

------------------------------------------------------------------------
-- 13. LIGHTING AND FLICKERING CANDLES
------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")
local ok = pcall(function() Lighting.Technology = Enum.Technology.Future end)
if not ok then
	warn("Couldn't switch lighting to Future automatically: select Lighting in the Explorer and set Technology = Future")
end
Lighting.Ambient = Color3.fromRGB(20, 14, 18)        -- very dark indoors, so candles matter
Lighting.OutdoorAmbient = Color3.fromRGB(70, 64, 80)
Lighting.EnvironmentDiffuseScale = 0.25
Lighting.EnvironmentSpecularScale = 1                -- shiny marble reflections

-- A LocalScript that makes every candle flicker (runs on each player's screen).
-- A copy of it is in the repo at src/client/CandleFlicker.client.lua
local FLICKER_SOURCE = [==[
-- CandleFlicker
-- Makes every light tagged "CandleLight" flicker like a real flame.
-- The Castle Builder adds the tag to every candle and chandelier.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local lights = {} -- light -> { base brightness, random offset }

local function add(light)
	lights[light] = { base = light.Brightness, seed = math.random() * 100 }
end
for _, light in ipairs(CollectionService:GetTagged("CandleLight")) do
	add(light)
end
CollectionService:GetInstanceAddedSignal("CandleLight"):Connect(add)
CollectionService:GetInstanceRemovedSignal("CandleLight"):Connect(function(light)
	lights[light] = nil
end)

local clock, sinceUpdate = 0, 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	sinceUpdate += dt
	if sinceUpdate < 1 / 20 then return end -- update 20 times a second, plenty for a flicker
	sinceUpdate = 0
	for light, info in pairs(lights) do
		-- math.noise gives a smooth random wobble between about -0.5 and 0.5
		local wobble = math.noise(clock * 4, info.seed)
		light.Brightness = info.base * (0.85 + wobble * 0.35)
	end
end)
]==]
local playerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if playerScripts then
	local flicker = playerScripts:FindFirstChild("CandleFlicker")
	if not flicker then
		flicker = Instance.new("LocalScript")
		flicker.Name = "CandleFlicker"
		flicker.Parent = playerScripts
	end
	flicker.Source = FLICKER_SOURCE
end

------------------------------------------------------------------------
-- 14. FINISH
------------------------------------------------------------------------
castle.Parent = workspace

-- warn about other spawn points (players might appear outside the castle)
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") and d.Name ~= "CastleSpawn" then
		warn("There's another SpawnLocation at " .. d:GetFullName() .. ". Delete it so players always start in the lobby.")
	end
end

if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Build Dracula's Castle") end)
end
pcall(function() game:GetService("Selection"):Set({ castle }) end)

local roomCount = 0
for _, r in ipairs(ROOMS) do
	if not r.isStair then roomCount += 1 end
end
print(string.format("Castle built! %d rooms on %d floors, %d candles (%d lights), %d parts. Press F to zoom to it.",
	roomCount, NUM_FLOORS, candleCount, lightCount, partCount))
