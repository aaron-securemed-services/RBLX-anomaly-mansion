--[[
=======================================================================
  LOBBY BUILDER  -  Dracula's BnB
=======================================================================
  Redecorates the Grand Lobby (run CastleBuilder.lua first):
    * a straight, full-size front desk: toe-kick base, carved front
      panels, gold trim, a "RECEPTION" nameplate, a service bell and
      a guest book on top
    * two room-key boards behind the desk, one key hook per guest room
      (the keys are named Key_201, Key_202 ... so game scripts can find
      them later, for example to take a key down when a guest checks in)
    * two grandfather clocks against the back wall
    * a red runner rug from the front door to the desk
    * any wall candles that land on a key board are lifted just above it
    * two waiting lounges (sofa, coffee table, two armchairs, rug) on
      either side of the runner. Players can sit on the cushions.

  HOW TO USE
    1. Stop Play mode first (anything built while testing is lost).
    2. Run tools/CastleBuilder.lua first if you haven't already.
    3. Open the Command Bar (View tab > Command Bar), paste this WHOLE
       file in and click Run.
    4. You'll see "Lobby built!" in the Output window.

  Running it again removes the old desk and furniture and builds a
  fresh set, so change the settings below and re-run as often as you
  like. (Running CastleBuilder again wipes the whole castle, so run this
  one again afterwards.)

  Everything sizes from the lobby itself, so it still fits if you
  change the castle layout. The desk keeps the name "CheckInDesk" at the
  same spot as the original, so GuestManager still finds it and the guest
  queue still lines up in front of it.

  WHERE THINGS END UP
    Workspace > DraculaCastle > Floor1 > Grand Lobby
        CheckInDesk, CheckInDeskTop, ...   the desk parts
        LobbyFurniture                     a folder with everything else
=======================================================================
]]

------------------------------------------------------------------------
-- 1. SETTINGS
------------------------------------------------------------------------
local DESK_WIDTH = 20        -- studs. The original desk was 16. Staff walk around either end.
local ADD_FURNITURE = true   -- false = only rebuild the desk

local COLORS = {
	DarkWood  = Color3.fromRGB(58, 38, 26),
	PanelWood = Color3.fromRGB(84, 55, 38),
	DeskTop   = Color3.fromRGB(72, 46, 32),
	Iron      = Color3.fromRGB(32, 30, 30),
	Gold      = Color3.fromRGB(176, 141, 62),
	Cream     = Color3.fromRGB(236, 226, 205),
	Leather   = Color3.fromRGB(70, 14, 20),
	Velvet    = Color3.fromRGB(96, 20, 30),
	Carpet    = Color3.fromRGB(110, 16, 24),   -- same blood red as the castle's rugs
	RugDark   = Color3.fromRGB(62, 12, 20),
	RugOuter  = Color3.fromRGB(84, 18, 28),
}

------------------------------------------------------------------------
-- 2. FIND THE LOBBY
-- The castle builder tags every room with a "Zone" box that fills the
-- room, so we can read the lobby's edges from that.
------------------------------------------------------------------------
local castle = workspace:FindFirstChild("DraculaCastle")
if not castle then
	error("No DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
end
local lobby = castle:FindFirstChild("Grand Lobby", true)
local zone = lobby and lobby:FindFirstChild("Zone")
if not zone then
	error("Couldn't find the Grand Lobby (or its Zone) inside DraculaCastle.")
end

local cx = zone.Position.X                       -- middle of the lobby, left to right
local z0 = zone.Position.Z - zone.Size.Z / 2     -- back wall (toward the corridor)
local z1 = zone.Position.Z + zone.Size.Z / 2     -- front wall (the front door is here)

-- Height of the floor and position of the desk. We read these from the
-- desk that's already there (the original, or ours from an earlier run).
local oldDesk = lobby:FindFirstChild("CheckInDesk")
local floorY = lobby:GetAttribute("FloorY")
if not floorY then
	if oldDesk then
		floorY = oldDesk.Position.Y - oldDesk.Size.Y / 2 -- the original desk stands on the floor
	else
		floorY = zone.Position.Y - zone.Size.Y / 2 + 0.2
	end
	lobby:SetAttribute("FloorY", floorY) -- remember it for re-runs
end
local dz = oldDesk and oldDesk.Position.Z or (z0 + 12) -- the desk's front-to-back position

------------------------------------------------------------------------
-- 3. HELPER FUNCTIONS
------------------------------------------------------------------------
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Build Lobby") end)

-- Remove the old desk and any furniture from an earlier run
for _, child in ipairs(lobby:GetChildren()) do
	if child:GetAttribute("LobbyBuilder") or child.Name == "CheckInDesk" or child.Name == "CheckInDeskTop" then
		child:Destroy()
	end
end

local furniture = Instance.new("Folder")
furniture.Name = "LobbyFurniture"
furniture:SetAttribute("LobbyBuilder", true)
furniture.Parent = lobby

local partCount = 0

-- Makes one block.
--   at       a CFrame: the point on the floor the object is built around.
--            Objects face the way `at` faces. By default a Roblox part's
--            "front" is -Z, so furniture built with its front toward -Z
--            looks toward the desk.
--   offset   where the middle of this block is, relative to `at`
--   solid    true = players bump into it, false = they walk through it
--            (small decorations shouldn't catch on anything)
--   opts     optional: rot = extra CFrame rotation, class = "Seat" etc.,
--            shape = Enum.PartType.Ball / Cylinder
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
	p:SetAttribute("LobbyBuilder", true)
	p.Parent = parent
	partCount = partCount + 1
	return p
end

------------------------------------------------------------------------
-- 4. THE FRONT DESK
-- Straight desk, running left to right. Staff stand behind it (the -Z
-- side, toward the corridor), guests in front of it (the +Z side).
-- Heights: base 0.6 + body 2.8 = 3.4, and the 0.4 top brings it to
-- 3.8, the same height as the original desk so the candles still sit on it.
------------------------------------------------------------------------
local deskAt = CFrame.new(cx, floorY, dz)

-- GuestManager looks for this part by name to line the guests up
put(lobby, "CheckInDesk", deskAt, Vector3.new(0, 2.0, 0), Vector3.new(DESK_WIDTH, 2.8, 3),
	Enum.Material.Wood, COLORS.DarkWood, true)
put(lobby, "CheckInDeskTop", deskAt, Vector3.new(0, 3.6, 0), Vector3.new(DESK_WIDTH + 1, 0.4, 4),
	Enum.Material.Wood, COLORS.DeskTop, true)
put(lobby, "DeskBase", deskAt, Vector3.new(0, 0.3, 0), Vector3.new(DESK_WIDTH - 0.4, 0.6, 2.6),
	Enum.Material.Metal, COLORS.Iron, true)

-- Three carved front panels, with a gold strip along the top edge
local panelSpacing = DESK_WIDTH / 3
for i = -1, 1 do
	put(lobby, "DeskPanel", deskAt, Vector3.new(i * panelSpacing, 2.0, 1.6),
		Vector3.new(panelSpacing - 0.8, 2.0, 0.2), Enum.Material.Wood, COLORS.PanelWood, false)
end
put(lobby, "DeskTrim", deskAt, Vector3.new(0, 3.3, 1.6), Vector3.new(DESK_WIDTH + 0.4, 0.2, 0.2),
	Enum.Material.Metal, COLORS.Gold, false)

-- "RECEPTION" nameplate on the middle panel, facing the guests (+Z)
local plate = put(lobby, "DeskNameplate", deskAt, Vector3.new(0, 2.0, 1.775), Vector3.new(6, 1.1, 0.15),
	Enum.Material.Metal, COLORS.Gold, false)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back -- the +Z face
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 80
gui.Parent = plate
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "RECEPTION"
label.Font = Enum.Font.Antique
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(40, 25, 15)
label.Parent = gui

-- Things on the desk. The desk top surface is 3.8 above the floor.
-- The service bell: a gold base with a dome and a button
put(lobby, "BellBase", deskAt, Vector3.new(4, 3.875, 0.3), Vector3.new(1.0, 0.15, 1.0),
	Enum.Material.Metal, COLORS.Gold, false)
put(lobby, "BellDome", deskAt, Vector3.new(4, 4.1, 0.3), Vector3.new(0.9, 0.9, 0.9),
	Enum.Material.Metal, COLORS.Gold, false, { shape = Enum.PartType.Ball })
put(lobby, "BellButton", deskAt, Vector3.new(4, 4.55, 0.3), Vector3.new(0.25, 0.25, 0.25),
	Enum.Material.Metal, COLORS.Gold, false, { shape = Enum.PartType.Ball })
-- The guest book, a little crooked like someone just used it
put(lobby, "GuestBookCover", deskAt, Vector3.new(-3, 3.85, 0.2), Vector3.new(1.8, 0.1, 2.4),
	Enum.Material.Leather, COLORS.Leather, false, { rot = CFrame.Angles(0, math.rad(10), 0) })
put(lobby, "GuestBookPages", deskAt, Vector3.new(-3, 3.95, 0.2), Vector3.new(1.6, 0.1, 2.2),
	Enum.Material.SmoothPlastic, COLORS.Cream, false, { rot = CFrame.Angles(0, math.rad(10), 0) })

------------------------------------------------------------------------
-- 5. FURNITURE
------------------------------------------------------------------------
if ADD_FURNITURE then
	-- The red runner from the front door to the desk, with gold edges.
	-- The guests walk (and queue) along it.
	local runnerFront = z1 - 0.5
	local runnerBack = dz + 4
	local runnerLength = runnerFront - runnerBack
	local runnerAt = CFrame.new(cx, floorY, (runnerFront + runnerBack) / 2)
	put(furniture, "Runner", runnerAt, Vector3.new(0, 0.04, 0), Vector3.new(8, 0.08, runnerLength),
		Enum.Material.Fabric, COLORS.Carpet, false)
	for _, side in ipairs({ -1, 1 }) do
		put(furniture, "RunnerEdge", runnerAt, Vector3.new(side * 3.85, 0.06, 0), Vector3.new(0.3, 0.1, runnerLength),
			Enum.Material.Metal, COLORS.Gold, false)
	end

	----------------------------------------------------------------------
	-- ROOM KEY BOARDS (behind the desk, either side of the corridor door)
	-- The board's face points into the lobby (+Z), so `at` has no rotation.
	-- One gold key per guest room, in order of room number.
	----------------------------------------------------------------------
	local roomNumbers = {}
	for _, d in ipairs(castle:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("RoomKind") == "Guest" and d:GetAttribute("RoomNumber") then
			table.insert(roomNumbers, d:GetAttribute("RoomNumber"))
		end
	end
	table.sort(roomNumbers)

	for board = 1, 2 do
		local side = (board == 1) and -1 or 1 -- board 1 on the left, board 2 on the right
		local at = CFrame.new(cx + side * 13.5, floorY, z0)
		-- the wooden backing and a dark frame around it
		put(furniture, "KeyBoardBack", at, Vector3.new(0, 7, 0.3), Vector3.new(10, 6, 0.6),
			Enum.Material.Wood, COLORS.PanelWood, false)
		put(furniture, "KeyBoardFrame", at, Vector3.new(0, 10.2, 0.45), Vector3.new(10.4, 0.4, 0.9),
			Enum.Material.Wood, COLORS.DarkWood, false)
		put(furniture, "KeyBoardFrame", at, Vector3.new(0, 3.8, 0.45), Vector3.new(10.4, 0.4, 0.9),
			Enum.Material.Wood, COLORS.DarkWood, false)
		for _, edge in ipairs({ -1, 1 }) do
			put(furniture, "KeyBoardFrame", at, Vector3.new(edge * 5.2, 7, 0.45), Vector3.new(0.4, 6.8, 0.9),
				Enum.Material.Wood, COLORS.DarkWood, false)
		end
		-- 8 hooks per board: 2 rows of 4. Board 1 gets rooms 1-8, board 2 gets 9-16.
		for k = 0, 7 do
			local row, col = math.floor(k / 4), k % 4
			local hx = (col - 1.5) * 2.5
			local hy = 8.2 - row * 2.4
			put(furniture, "KeyHook", at, Vector3.new(hx, hy, 0.75), Vector3.new(0.15, 0.15, 0.3),
				Enum.Material.Metal, COLORS.Iron, false)
			local number = roomNumbers[(board - 1) * 8 + k + 1]
			if number then
				local key = put(furniture, "Key_" .. number, at, Vector3.new(hx, hy - 0.5, 0.85),
					Vector3.new(0.35, 0.7, 0.1), Enum.Material.Metal, COLORS.Gold, false)
				key:SetAttribute("RoomNumber", number)
			end
		end
	end

	----------------------------------------------------------------------
	-- MOVE WALL CANDLES OUT OF THE WAY
	-- The castle builder hangs wall candles (sconces) along the back wall at
	-- about the height of the key boards, and two of them land on a board.
	-- Lift any sconce that overlaps a board to just above its frame. It
	-- keeps its light, it just no longer sits in front of the keys.
	----------------------------------------------------------------------
	local SCONCE_PARTS = { SconceArm = true, SconceCup = true, Candle = true, Flame = true }
	local liftedCount = 0
	for _, plate in ipairs(lobby:GetChildren()) do
		if plate.Name == "SconcePlate" and plate:IsA("BasePart") then
			local pos = plate.Position
			local onBackWall = pos.Z < z0 + 3
			local atBoardHeight = pos.Y > floorY + 3 and pos.Y < floorY + 11
			local overBoard = math.abs(math.abs(pos.X - cx) - 13.5) < 6.2 -- within a board's width, left or right
			if onBackWall and atBoardHeight and overBoard then
				local lift = (floorY + 13.2) - pos.Y -- puts the plate 13.2 studs above the floor
				-- the sconce is the plate plus its arm, cup, candle and flame, which
				-- all sit within a couple of studs of the plate
				for _, piece in ipairs(lobby:GetChildren()) do
					if piece == plate or (SCONCE_PARTS[piece.Name] and piece:IsA("BasePart")) then
						local offset = piece.Position - pos
						if math.abs(offset.X) < 2 and math.abs(offset.Z) < 2 and math.abs(offset.Y) < 3 then
							piece.Position = piece.Position + Vector3.new(0, lift, 0)
						end
					end
				end
				liftedCount = liftedCount + 1
			end
		end
	end

	----------------------------------------------------------------------
	-- GRANDFATHER CLOCKS against the back wall, facing the lobby
	----------------------------------------------------------------------
	for _, side in ipairs({ -1, 1 }) do
		local at = CFrame.new(cx + side * 24, floorY, z0)
		put(furniture, "ClockBase", at, Vector3.new(0, 0.75, 0.8), Vector3.new(2.2, 1.5, 1.6),
			Enum.Material.Wood, COLORS.DarkWood, true)
		put(furniture, "ClockShaft", at, Vector3.new(0, 3.7, 0.75), Vector3.new(1.7, 4.0, 1.3),
			Enum.Material.Wood, COLORS.PanelWood, true)
		put(furniture, "ClockHead", at, Vector3.new(0, 6.25, 0.8), Vector3.new(2.2, 1.9, 1.6),
			Enum.Material.Wood, COLORS.DarkWood, true)
		put(furniture, "ClockCrown", at, Vector3.new(0, 7.4, 0.8), Vector3.new(2.4, 0.4, 1.8),
			Enum.Material.Wood, COLORS.DarkWood, false)
		-- the clock face: a flat cream disc on the front of the head
		put(furniture, "ClockFace", at, Vector3.new(0, 6.25, 1.65), Vector3.new(0.1, 1.5, 1.5),
			Enum.Material.SmoothPlastic, COLORS.Cream, false,
			{ shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, math.rad(90), 0) })
		put(furniture, "ClockHourHand", at, Vector3.new(0.12, 6.45, 1.72), Vector3.new(0.12, 0.5, 0.05),
			Enum.Material.Metal, COLORS.Iron, false, { rot = CFrame.Angles(0, 0, math.rad(-30)) })
		put(furniture, "ClockMinuteHand", at, Vector3.new(-0.2, 6.5, 1.72), Vector3.new(0.08, 0.7, 0.05),
			Enum.Material.Metal, COLORS.Iron, false, { rot = CFrame.Angles(0, 0, math.rad(50)) })
		-- the pendulum in the shaft
		put(furniture, "ClockPendulum", at, Vector3.new(0, 4.2, 1.45), Vector3.new(0.12, 2.2, 0.08),
			Enum.Material.Metal, COLORS.Gold, false)
		put(furniture, "ClockBob", at, Vector3.new(0, 3.2, 1.45), Vector3.new(0.7, 0.7, 0.2),
			Enum.Material.Metal, COLORS.Gold, false, { shape = Enum.PartType.Ball })
	end

	----------------------------------------------------------------------
	-- WAITING LOUNGES against the front wall, either side of the front door
	-- Sofas have their backs to the wall and face the desk (-Z). The
	-- cushions are real Seats, so players can sit down.
	----------------------------------------------------------------------
	local function sofa(at)
		put(furniture, "SofaBase", at, Vector3.new(0, 0.7, 0), Vector3.new(7, 1.4, 3), Enum.Material.Fabric, COLORS.Velvet, true)
		put(furniture, "SofaBack", at, Vector3.new(0, 2.5, 1.1), Vector3.new(7, 2.2, 0.8), Enum.Material.Fabric, COLORS.Velvet, true)
		for _, side in ipairs({ -1, 1 }) do
			put(furniture, "SofaArm", at, Vector3.new(side * 3.1, 2.0, 0), Vector3.new(0.8, 1.2, 3), Enum.Material.Fabric, COLORS.Velvet, true)
			put(furniture, "SofaCushion", at, Vector3.new(side * 1.35, 1.8, -0.3), Vector3.new(2.6, 0.8, 2.2),
				Enum.Material.Fabric, COLORS.Velvet, true, { class = "Seat" })
		end
	end

	local function armchair(at)
		put(furniture, "ArmchairBase", at, Vector3.new(0, 0.7, 0), Vector3.new(3, 1.4, 3), Enum.Material.Fabric, COLORS.Velvet, true)
		put(furniture, "ArmchairBack", at, Vector3.new(0, 2.4, 1.1), Vector3.new(3, 2.0, 0.7), Enum.Material.Fabric, COLORS.Velvet, true)
		for _, side in ipairs({ -1, 1 }) do
			put(furniture, "ArmchairArm", at, Vector3.new(side * 1.25, 1.9, 0), Vector3.new(0.5, 1.0, 2.4), Enum.Material.Fabric, COLORS.Velvet, true)
		end
		put(furniture, "ArmchairCushion", at, Vector3.new(0, 1.8, -0.3), Vector3.new(2.2, 0.8, 2.2),
			Enum.Material.Fabric, COLORS.Velvet, true, { class = "Seat" })
	end

	local function coffeeTable(at)
		put(furniture, "TableTop", at, Vector3.new(0, 1.5, 0), Vector3.new(4, 0.3, 2), Enum.Material.Wood, COLORS.DarkWood, true)
		for _, lx in ipairs({ -1.7, 1.7 }) do
			for _, lz in ipairs({ -0.7, 0.7 }) do
				put(furniture, "TableLeg", at, Vector3.new(lx, 0.675, lz), Vector3.new(0.3, 1.35, 0.3), Enum.Material.Wood, COLORS.DarkWood, true)
			end
		end
	end

	-- One lounge centred on lx (a left-right position). The sofa sits against
	-- the front wall, the table in front of it, and an armchair at each end
	-- of the table turned to face it.
	local function lounge(lx)
		local rugZ = z1 - 5.5
		put(furniture, "LoungeRug", CFrame.new(lx, floorY, rugZ), Vector3.new(0, 0.04, 0), Vector3.new(15, 0.08, 10),
			Enum.Material.Fabric, COLORS.RugOuter, false)
		put(furniture, "LoungeRugInner", CFrame.new(lx, floorY, rugZ), Vector3.new(0, 0.06, 0), Vector3.new(13.4, 0.12, 8.4),
			Enum.Material.Fabric, COLORS.RugDark, false)
		sofa(CFrame.new(lx, floorY, z1 - 1.6))
		coffeeTable(CFrame.new(lx, floorY, z1 - 7.5))
		-- yaw -90 turns an armchair to face +X, yaw +90 to face -X
		armchair(CFrame.new(lx - 4.1, floorY, z1 - 7.5) * CFrame.Angles(0, math.rad(-90), 0))
		armchair(CFrame.new(lx + 4.1, floorY, z1 - 7.5) * CFrame.Angles(0, math.rad(90), 0))
	end

	-- Far enough out that the front door and the runner stay clear
	lounge(cx - 17)
	lounge(cx + 17)
end

------------------------------------------------------------------------
-- 6. FINISH
------------------------------------------------------------------------
if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Build Lobby") end)
end
pcall(function() game:GetService("Selection"):Set({ lobby }) end)

print(string.format("Lobby built! %d parts. Select the Grand Lobby and press F to zoom to it.", partCount))
