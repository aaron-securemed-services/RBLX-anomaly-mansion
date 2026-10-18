-- GuestManager
-- Brings guests to the castle during the day. For each guest it:
--   1. makes a character with a random name and random traits,
--   2. walks them in through the front door to the check-in desk,
--   3. lets a player check them in with a prompt, which gives them a room.
-- At night, any guests still waiting in the lobby leave.
--
-- Needs: GameManager (for the Phase and DayNumber values),
--        GuestTraits (ModuleScript in ReplicatedStorage), and the castle
--        built by tools/CastleBuilder.lua.

------------------------------------------------------------------
-- SERVICES AND SHARED VALUES
------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- require() loads a ModuleScript and gives us back whatever it returns.
-- Here that's the GuestTraits table full of data and functions.
local GuestTraits = require(ReplicatedStorage:WaitForChild("GuestTraits"))

-- These values are created by GameManager. WaitForChild pauses until they exist.
local phase = ReplicatedStorage:WaitForChild("Phase")
local dayNumber = ReplicatedStorage:WaitForChild("DayNumber")

------------------------------------------------------------------
-- SETTINGS
-- Lists are indexed by day: the 1st number is day 1, and so on.
------------------------------------------------------------------
local GUESTS_PER_DAY = { 2, 3, 3, 4, 4, 5, 6 } -- how many guests arrive each day
local TRAITS_PER_DAY = {                       -- { fewest, most } traits per guest
	{ 1, 2 }, { 1, 2 }, { 2, 3 }, { 2, 3 }, { 2, 4 }, { 3, 4 }, { 3, 5 },
}
local ARRIVAL_GAP = 25        -- seconds between one guest arriving and the next
local GUEST_WALK_SPEED = 10   -- studs per second (players walk at 16)

-- While testing, print each guest's real traits and score to Output.
-- Set to false once the clue system exists so players have to find them out.
local DEBUG_SHOW_TRAITS = true

local NAMES = {
	"Edwin Harker", "Mina Brightwell", "Lucas Moreau", "Priya Nair", "Gustav Lindqvist",
	"Beatrice Okoye", "Tomas Varga", "Hana Sato", "Winston Pike", "Carmen Ruiz",
	"Olga Petrova", "Declan Byrne", "Yuki Tanaka", "Marcus Webb", "Ingrid Solberg",
	"Rafael Ortega", "Fiona McAllister", "Dmitri Kozlov", "Amara Diallo", "Henry Thorne",
}
local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189), Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(198, 134, 66), Color3.fromRGB(141, 85, 36), Color3.fromRGB(94, 58, 30),
}
local CLOTHES = {
	Color3.fromRGB(60, 80, 120), Color3.fromRGB(120, 60, 60), Color3.fromRGB(70, 100, 70),
	Color3.fromRGB(90, 80, 60), Color3.fromRGB(40, 40, 50), Color3.fromRGB(130, 110, 150),
}

------------------------------------------------------------------
-- FIND THE CASTLE PARTS WE NEED
-- WaitForChild waits for the castle to exist. FindFirstChild("name", true)
-- searches inside everything for an object with that name.
------------------------------------------------------------------
local castle = workspace:WaitForChild("DraculaCastle", 10)
if not castle then
	warn("GuestManager: no DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
	return -- stop this script here
end

local lobby = castle:FindFirstChild("Grand Lobby", true)
local desk = lobby and lobby:FindFirstChild("CheckInDesk")
local lobbyZone = lobby and lobby:FindFirstChild("Zone") -- invisible box filling the room
if not (lobby and desk and lobbyZone) then
	warn("GuestManager: couldn't find the Grand Lobby, its CheckInDesk or its Zone.")
	return
end

-- A folder to keep all guest characters in, so Explorer stays tidy
local guestsFolder = Instance.new("Folder")
guestsFolder.Name = "Guests"
guestsFolder.Parent = workspace

-- Y height of the lobby floor and the spot just inside the front door.
-- Zone parts aren't rotated, so Position and Size give us the edges.
-- The front door is on the +Z side of the lobby.
local floorY = lobbyZone.Position.Y - lobbyZone.Size.Y / 2
local entrance = Vector3.new(
	lobbyZone.Position.X,
	floorY + 3.5, -- 3.5 studs up so the character stands on the floor, not in it
	lobbyZone.Position.Z + lobbyZone.Size.Z / 2 - 2
)

------------------------------------------------------------------
-- GUEST BOOKKEEPING
-- `waiting` is the line of guests at the desk, first in line first.
-- Each entry is a table: { model, humanoid, prompt, checkedIn }.
------------------------------------------------------------------
local waiting = {}

-- Where the guest in line position `slot` stands: just in front of the
-- desk, with each person behind them standing further back toward the door.
local function slotPosition(slot)
	return Vector3.new(desk.Position.X, floorY + 3.5, desk.Position.Z + 6 + (slot - 1) * 3.5)
end

-- Tells every waiting guest to walk to their place in line.
-- Called whenever someone arrives or leaves the line.
local function updateQueue()
	for slot, guest in ipairs(waiting) do
		guest.humanoid:MoveTo(slotPosition(slot))
	end
end

------------------------------------------------------------------
-- FUNCTION: pickFreeRoom
-- Returns a random guest room Model that nobody is staying in, or nil
-- if the castle is full. The castle builder tagged every room Model with
-- a "RoomKind" attribute (an attribute is a named value stored on an object).
------------------------------------------------------------------
local function pickFreeRoom()
	local free = {}
	for _, object in ipairs(castle:GetDescendants()) do
		if object:IsA("Model")
			and object:GetAttribute("RoomKind") == "Guest"
			and not object:GetAttribute("Occupied") then
			table.insert(free, object)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[math.random(1, #free)]
end

------------------------------------------------------------------
-- FUNCTION: checkIn
-- Runs when a player triggers the "Check in" prompt on a guest.
-- It gives the guest a room and moves them into it.
-- (For now the guest is placed straight in the room. Walking up the
-- stairs needs pathfinding, which we'll add later.)
------------------------------------------------------------------
local function checkIn(guest, player)
	if guest.checkedIn then
		return -- two players pressed at once, only the first counts
	end

	local room = pickFreeRoom()
	if not room then
		print("No free rooms! Can't check in", guest.model.Name)
		return
	end

	guest.checkedIn = true
	guest.prompt:Destroy() -- the prompt is no longer needed

	-- Take the guest out of the line and close up the gap
	table.remove(waiting, table.find(waiting, guest))
	updateQueue()

	-- Mark the room as taken, and note the room on the guest
	room:SetAttribute("Occupied", true)
	guest.model:SetAttribute("CheckedIn", true)
	guest.model:SetAttribute("RoomName", room:GetAttribute("RoomName"))

	-- Put the guest in their room. If the room has been furnished (by
	-- tools/GuestRoomBuilder.lua) it has an invisible "GuestSpot" marker at
	-- the foot of the bed. Otherwise we use the middle of the room.
	local spot = room:FindFirstChild("GuestSpot", true) -- true = look inside everything in the room
	if spot then
		guest.model:PivotTo(CFrame.new(spot.Position))
	else
		local zone = room:FindFirstChild("Zone")
		local roomFloorY = zone.Position.Y - zone.Size.Y / 2
		guest.model:PivotTo(CFrame.new(zone.Position.X, roomFloorY + 3.5, zone.Position.Z))
	end

	print(player.Name, "checked in", guest.model.Name, "to", room:GetAttribute("RoomName"))
end

------------------------------------------------------------------
-- FUNCTION: spawnGuest
-- Creates one guest for the given day and sends them to the desk.
------------------------------------------------------------------
local function spawnGuest(day)
	-- Roll this guest's traits. The number depends on the day, so later
	-- days give more traits and a mix of harder-to-spot ones.
	local range = TRAITS_PER_DAY[day] or TRAITS_PER_DAY[#TRAITS_PER_DAY]
	local traits = GuestTraits.rollTraits(math.random(range[1], range[2]))

	-- Build a character with random colors. HumanoidDescription is
	-- Roblox's "recipe" for how a character looks.
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN_TONES[math.random(#SKIN_TONES)]
	local clothes = CLOTHES[math.random(#CLOTHES)]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = clothes
	description.LeftLegColor = clothes
	description.RightLegColor = clothes

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	local name = NAMES[math.random(#NAMES)]
	model.Name = name
	local humanoid = model:WaitForChild("Humanoid")
	humanoid.DisplayName = name
	humanoid.WalkSpeed = GUEST_WALK_SPEED

	-- Store the secret information as attributes on the guest. Other scripts
	-- (like Dracula's) can read these later.
	local traitIds = {}
	for _, trait in ipairs(traits) do
		table.insert(traitIds, trait.id)
	end
	model:SetAttribute("Traits", table.concat(traitIds, ","))
	model:SetAttribute("VictimScore", GuestTraits.victimScore(traits))
	model:SetAttribute("CheckedIn", false)

	model.Parent = guestsFolder
	model:PivotTo(CFrame.new(entrance)) -- place them just inside the front door

	-- The "Check in" prompt players press (like pressing E on a door)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Check in"
	prompt.ObjectText = name
	prompt.HoldDuration = 0.5           -- hold the button for half a second
	prompt.MaxActivationDistance = 10   -- how close the player must be
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:WaitForChild("HumanoidRootPart")

	local guest = { model = model, humanoid = humanoid, prompt = prompt, checkedIn = false }
	prompt.Triggered:Connect(function(player)
		checkIn(guest, player)
	end)

	table.insert(waiting, guest)
	updateQueue() -- sends the new guest to the end of the line

	-- Output messages for testing. The clues are what players will eventually
	-- see in the game itself.
	print("Guest arrives:", name)
	for _, trait in ipairs(traits) do
		print("   clue:", trait.clue)
	end
	if DEBUG_SHOW_TRAITS then
		print("   [debug] traits:", table.concat(traitIds, ", "), "| victim score:", model:GetAttribute("VictimScore"))
	end
end

------------------------------------------------------------------
-- DAY AND NIGHT REACTIONS
------------------------------------------------------------------

-- Spawns the day's guests one at a time. If the day ends (or a new day
-- starts) before everyone has arrived, the rest don't come.
local function runArrivals(day)
	local count = GUESTS_PER_DAY[day] or GUESTS_PER_DAY[#GUESTS_PER_DAY]
	for _ = 1, count do
		if phase.Value ~= "Day" or dayNumber.Value ~= day then
			return
		end
		spawnGuest(day)
		task.wait(ARRIVAL_GAP)
	end
end

-- At night, guests who never got checked in give up and leave.
local function dismissWaiting()
	for _, guest in ipairs(waiting) do
		print(guest.model.Name, "gave up waiting and left.")
		guest.model:Destroy()
	end
	table.clear(waiting)
end

-- Runs every time the Phase value changes. task.spawn starts the arrivals
-- in their own thread, so waiting between guests doesn't block anything else.
phase.Changed:Connect(function()
	if phase.Value == "Day" then
		task.spawn(runArrivals, dayNumber.Value)
	elseif phase.Value == "Night" then
		dismissWaiting()
	end
end)

-- Day 1 is already underway when this script starts, and GameManager sets
-- the phase to "Day" without changing it, so the event above never fires
-- for day 1. Start day 1's arrivals by hand.
if phase.Value == "Day" then
	task.spawn(runArrivals, dayNumber.Value)
end
