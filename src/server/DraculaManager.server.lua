-- DraculaManager
-- Runs Dracula, the monster. Each night he:
--   1. wakes up in his coffin (DraculaPowers raises him out of a shadow pool),
--      then waits a short while so players have time to lock doors,
--   2. picks the guest he wants most: the highest victim score among guests
--      who aren't protected,
--   3. walks to that guest's room. A closed door he opens. A locked door he
--      has to break down, which takes a few seconds and makes noise,
--   4. feeds on the guest. Half the time the guest dies, half the time they are
--      only drained. A drained guest becomes a vampire helper the next night,
--   5. hunts again if the night allows, then vanishes before dawn.
-- If he touches a player, the player is thrown back and stunned for a few seconds.
-- He never kills players.
--
-- Which Dracula: if Workspace > NPCs > Dracula exists (built by
-- tools/DraculaRigBuilder.lua) this script drives that animated character,
-- and DraculaPowers handles him rising at nightfall and sinking at dawn.
-- If he doesn't exist, this script builds a plain stand-in figure instead.
-- Long trips to a guest's room use DraculaPowers' teleport (a warning pool
-- opens first), and short trips are walked.
--
-- Needs: GameManager (Phase, DayNumber), GuestManager (the guests),
--        DoorControl and DoorManager (the doors), and the castle.

------------------------------------------------------------------
-- SERVICES AND SHARED VALUES
------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local PathfindingService = game:GetService("PathfindingService") -- finds routes through the castle

local DoorControl = require(ServerScriptService:WaitForChild("DoorControl"))
local phase = ReplicatedStorage:WaitForChild("Phase")
local dayNumber = ReplicatedStorage:WaitForChild("DayNumber")

------------------------------------------------------------------
-- SETTINGS
-- Everything you might want to tweak is here.
------------------------------------------------------------------
local SETTINGS = {
	AwakenDelay = 12,           -- seconds after nightfall before he appears
	PlaceholderWalkSpeed = 12,  -- speed of the stand-in Dracula, in studs per second. Players walk at 16.
	RigWalkSpeed = 0,           -- the animated Dracula keeps his own speed (set in DraculaRigBuilder). Put a number here to override it.
	TeleportIfFartherThan = 60, -- he teleports to the corridor outside a room when it's farther than this many studs.
	                            -- 0 = always teleport. A huge number (like 99999) = always walk.
	HuntsPerNight = { 1, 1, 2, 2, 2, 3, 3 }, -- how many guests he goes after on night 1, 2, 3 ...
	PauseBetweenHunts = 8,      -- seconds he waits between guests
	FeedSeconds = 6,            -- how long feeding takes
	DeathChance = 0.5,          -- 0.5 = half the time the guest dies, half the time they're drained
	HuntTimeLimit = 90,         -- seconds. If a hunt takes longer than this he gives up on that guest.
	DoorReach = 5,              -- how close he must be to a closed door before he deals with it
	ContactDistance = 5,        -- how close to a player counts as touching them
	StunSeconds = 6,            -- how long a touched player is stunned
	StunImmunitySeconds = 4,    -- after being stunned, a player can't be stunned again for this long
	HeightScale = 1.35,         -- how much taller than a normal character he is
}

------------------------------------------------------------------
-- FIND THINGS IN THE CASTLE
------------------------------------------------------------------
local castle = workspace:WaitForChild("DraculaCastle", 10)
if not castle then
	warn("DraculaManager: no DraculaCastle in Workspace. Run tools/CastleBuilder.lua first.")
	return -- stop this script here
end
local guestsFolder = workspace:WaitForChild("Guests", 30) -- GuestManager makes this folder
if not guestsFolder then
	warn("DraculaManager: no Guests folder. Is GuestManager running?")
	return
end

-- Where he appears: the DraculaSpawn marker that tools/CryptBuilder.lua makes.
-- If it's missing, use the middle of the crypt.
local function getSpawnPosition()
	local marker = castle:FindFirstChild("DraculaSpawn", true)
	if marker then
		return marker.Position
	end
	local crypt = castle:FindFirstChild("Crypt", true)
	local zone = crypt and crypt:FindFirstChild("Zone")
	if zone then
		return Vector3.new(zone.Position.X, zone.Position.Y - zone.Size.Y / 2 + 5, zone.Position.Z)
	end
	return Vector3.new(0, 10, 0)
end

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------
-- The animated Dracula, if you built one with tools/DraculaRigBuilder.lua
local npcs = workspace:WaitForChild("NPCs", 5)
local rig = npcs and npcs:FindFirstChild("Dracula")
local usingRig = rig ~= nil

local dracula = nil        -- his character model (nil while the stand-in isn't out)
local draculaHumanoid = nil
local draculaRoot = nil
if usingRig then
	-- the rig is always there. DraculaPowers hides him by day and shows him by night.
	dracula = rig
	draculaHumanoid = rig:WaitForChild("Humanoid")
	draculaRoot = rig:WaitForChild("HumanoidRootPart")
	if SETTINGS.RigWalkSpeed > 0 then
		draculaHumanoid.WalkSpeed = SETTINGS.RigWalkSpeed
	end
end
local nightToken = 0       -- a number that changes every night, so an old night's thread can tell it should stop
local stunnedUntil = {}    -- player -> the time (os.clock) until which they can't be stunned again

-- True while this night is still the current one and it is still night
local function stillNight(token)
	return token == nightToken and phase.Value == "Night"
end

-- Waits `seconds`, in small steps, and stops early if the night ends.
-- Returns false if the night ended while waiting.
local function waitDuringNight(seconds, token)
	local waited = 0
	while waited < seconds do
		waited = waited + task.wait(0.25)
		if not stillNight(token) then
			return false
		end
	end
	return true
end

-- Distance between two positions ignoring height
local function flatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

------------------------------------------------------------------
-- BUILDING DRACULA (a placeholder: a tall dark figure with a cape and red eyes)
-- To use your own model later, replace this function so that it returns
-- a character Model with a Humanoid and a HumanoidRootPart.
------------------------------------------------------------------
local function buildDracula()
	local scale = SETTINGS.HeightScale
	local pale = Color3.fromRGB(205, 198, 208)
	local black = Color3.fromRGB(16, 12, 18)

	-- HumanoidDescription is Roblox's "recipe" for how a character looks
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = pale
	description.LeftArmColor = black
	description.RightArmColor = black
	description.TorsoColor = black
	description.LeftLegColor = black
	description.RightLegColor = black
	description.HeightScale = scale
	description.WidthScale = 1.05

	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = "Dracula"
	local humanoid = model:WaitForChild("Humanoid")
	humanoid.DisplayName = "Dracula"
	humanoid.WalkSpeed = SETTINGS.PlaceholderWalkSpeed
	humanoid.JumpPower = 0
	humanoid.MaxHealth = 1e9 -- he can't be hurt
	humanoid.Health = 1e9

	local head = model:WaitForChild("Head")
	local torso = model:WaitForChild("UpperTorso")
	local root = model:WaitForChild("HumanoidRootPart")

	-- Glowing red eyes, stuck to the front of the head
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.22, 0.22, 0.22) * scale
		eye.Material = Enum.Material.Neon
		eye.Color = Color3.fromRGB(255, 20, 20)
		eye.CanCollide = false
		eye.Massless = true
		eye.CFrame = head.CFrame * CFrame.new(side * 0.22 * scale, 0.1 * scale, -0.52 * scale)
		eye.Parent = model
		local weld = Instance.new("WeldConstraint") -- glues the eye to the head
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye
	end

	-- A long dark red cape hanging from his shoulders
	local cape = Instance.new("Part")
	cape.Name = "Cape"
	cape.Size = Vector3.new(2.6, 4.2, 0.2) * scale
	cape.Material = Enum.Material.Fabric
	cape.Color = Color3.fromRGB(88, 10, 22)
	cape.CanCollide = false
	cape.Massless = true
	cape.CFrame = torso.CFrame * CFrame.new(0, -1.4 * scale, 0.75 * scale)
	cape.Parent = model
	local capeWeld = Instance.new("WeldConstraint")
	capeWeld.Part0 = torso
	capeWeld.Part1 = cape
	capeWeld.Parent = cape

	-- A faint red glow around him, so players can see him coming in the dark
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 40, 40)
	glow.Range = 16
	glow.Brightness = 0.7
	glow.Parent = root

	return model, humanoid, root
end

-- Gets Dracula out and ready. Returns false if the night ended while waiting.
local function spawnDracula(token)
	if usingRig then
		-- DraculaPowers raises him out of a shadow pool at nightfall and sets his Awake
		-- attribute to true when he is up. Wait for that. (With no powers script he has
		-- no Awake attribute at all, and we treat him as always out.)
		local waited = 0
		while rig:GetAttribute("Awake") == false and waited < 20 do
			waited = waited + task.wait(0.25)
			if not stillNight(token) then
				return false
			end
		end
	elseif not dracula then
		dracula, draculaHumanoid, draculaRoot = buildDracula()
		dracula.Parent = workspace
		dracula:PivotTo(CFrame.new(getSpawnPosition()))
		pcall(function()
			draculaRoot:SetNetworkOwner(nil) -- keep his movement on the server, so players can't push it around
		end)
	end
	local coffin = castle:FindFirstChild("DraculaCoffin", true)
	if coffin then
		coffin:SetAttribute("IsOpen", true) -- other scripts can react to the coffin opening
	end
	print("Dracula is ready to hunt.")
	return stillNight(token)
end

-- Ends his night. The animated Dracula is put to bed by DraculaPowers at dawn, so
-- only the stand-in is removed here.
local function despawnDracula()
	if not usingRig and dracula then
		dracula:Destroy()
		dracula, draculaHumanoid, draculaRoot = nil, nil, nil
	end
	local coffin = castle:FindFirstChild("DraculaCoffin", true)
	if coffin then
		coffin:SetAttribute("IsOpen", false)
	end
end

------------------------------------------------------------------
-- DOORS
-- A door in his way: unlocked, he opens it. Locked, he breaks it
-- (DoorControl.breakDown waits until he is through).
-- Returns false if a locked door stops him completely.
------------------------------------------------------------------
local function handleDoorsAt(position)
	for _, door in ipairs(DoorControl.getDoors()) do
		-- Breaking a door takes seconds, and dawn can come meanwhile and send him
		-- home. So after every wait we check he is still out.
		if not dracula or phase.Value ~= "Night" then
			return true -- he's gone, or it's day; walkTo notices and stops
		end
		local anchor = door:FindFirstChild("PromptAnchor")
		if anchor and flatDistance(anchor.Position, position) < SETTINGS.DoorReach
			and not door:GetAttribute("IsOpen") and not door:GetAttribute("IsBroken") then
			draculaHumanoid:MoveTo(draculaRoot.Position) -- stop and deal with the door
			local through = DoorControl.breakDown(door)
			if not dracula or phase.Value ~= "Night" then
				return true
			end
			if not through then
				return false -- the lock holds
			end
			task.wait(0.9) -- give the door time to swing open
		end
	end
	return true
end

------------------------------------------------------------------
-- WALKING
-- walkTo sends him along a path to a position. It returns:
--   "arrived"   he got there
--   "blocked"   a locked door stopped him (only if breaking doors is switched off)
--   "nopath"    no route could be found
--   "stopped"   the night ended, or it took too long
------------------------------------------------------------------
local function walkTo(goal, token, deadline)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.5,   -- how wide he is
		AgentHeight = 8,     -- how tall he is
		AgentCanJump = false,
		WaypointSpacing = 4, -- how far apart the steps of the route are
	})
	local ok = pcall(function()
		path:ComputeAsync(draculaRoot.Position, goal)
	end)
	if not ok or path.Status ~= Enum.PathStatus.Success then
		return "nopath"
	end

	for _, waypoint in ipairs(path:GetWaypoints()) do
		if not stillNight(token) or not dracula or os.clock() > deadline then
			return "stopped"
		end
		-- if he is near a closed door, deal with it before walking on
		local doorsOk = handleDoorsAt(draculaRoot.Position)
		if doorsOk and dracula then
			doorsOk = handleDoorsAt(waypoint.Position)
		end
		if not dracula or not stillNight(token) then
			return "stopped" -- dawn came while he was at a door
		end
		if not doorsOk then
			return "blocked"
		end
		draculaHumanoid:MoveTo(waypoint.Position)
		local timeout = 0
		while flatDistance(draculaRoot.Position, waypoint.Position) > 3 and timeout < 4 do
			timeout = timeout + task.wait(0.1)
			if not stillNight(token) or not dracula then
				return "stopped"
			end
		end
	end
	return "arrived"
end

-- Used only by the stand-in Dracula (the animated one teleports instead): if no
-- walking route exists, he vanishes and reappears outside the guest's door.
local function mistTo(roomNumber)
	local door = DoorControl.getGuestDoor(roomNumber)
	local anchor = door and door:FindFirstChild("PromptAnchor")
	if not anchor or not draculaRoot then
		return false
	end
	-- the corridor is on the side of the door nearest z = 0
	local towardCorridor = (anchor.Position.Z > 0) and -1 or 1
	local floorY = anchor.Position.Y - 5.75
	dracula:PivotTo(CFrame.new(anchor.Position.X, floorY + 5, anchor.Position.Z + towardCorridor * 5))
	return true
end

------------------------------------------------------------------
-- GUESTS
-- Guests are characters in the Guests folder. The scripts keep these
-- attributes on them:
--   CheckedIn, RoomNumber, VictimScore   (GuestManager)
--   Status      "Healthy" (or missing), "Drained", "Vampire" or "Dead"   (this script)
--   Protected   true if the protections make them untouchable  (the protections step will set this)
--   ProtectionPoints  how much their score is lowered by protections (also set later)
------------------------------------------------------------------
local function statusOf(guest)
	return guest:GetAttribute("Status") or "Healthy"
end

-- How much Dracula wants this guest right now: their victim score,
-- lowered by any protections in place
local function appetiteFor(guest)
	if guest:GetAttribute("Protected") == true then
		return 0
	end
	local score = guest:GetAttribute("VictimScore") or 0
	local protection = guest:GetAttribute("ProtectionPoints") or 0
	return score - protection
end

-- Picks the guest he wants most: checked in, still healthy, not already
-- hunted tonight, and worth hunting (appetite above 0). Ties are decided at random.
local function pickTarget()
	local best, bestScore = {}, 0
	for _, guest in ipairs(guestsFolder:GetChildren()) do
		if guest:GetAttribute("CheckedIn") and statusOf(guest) == "Healthy"
			and not guest:GetAttribute("HuntedTonight") then
			local appetite = appetiteFor(guest)
			if appetite > bestScore then
				best, bestScore = { guest }, appetite
			elseif appetite == bestScore and appetite > 0 then
				table.insert(best, guest)
			end
		end
	end
	if #best == 0 then
		return nil
	end
	return best[math.random(1, #best)]
end

-- Paints every part of a guest a color (used to show drained and vampire guests)
local function tintGuest(guest, color)
	for _, part in ipairs(guest:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Color = color
		end
	end
end

-- A drained guest turns into a vampire helper the next night
local function turnDrainedIntoVampires()
	for _, guest in ipairs(guestsFolder:GetChildren()) do
		if statusOf(guest) == "Drained" then
			guest:SetAttribute("Status", "Vampire")
			guest:SetAttribute("IsVampire", true)
			tintGuest(guest, Color3.fromRGB(70, 20, 30))
			print(guest.Name .. " has turned into a vampire.")
		end
	end
end

-- Dead guests are carried out in the morning: the room is freed and
-- its key goes back on the board
local function clearDeadGuests()
	for _, guest in ipairs(guestsFolder:GetChildren()) do
		if statusOf(guest) == "Dead" then
			local number = guest:GetAttribute("RoomNumber")
			for _, object in ipairs(castle:GetDescendants()) do
				if object:IsA("Model") and object:GetAttribute("RoomKind") == "Guest"
					and object:GetAttribute("RoomNumber") == number then
					object:SetAttribute("Occupied", false)
				elseif object:IsA("BasePart") and object.Name == "Key_" .. tostring(number) then
					object.Transparency = 0 -- the key is back on its hook
				end
			end
			print(guest.Name .. " was found dead and carried out.")
			guest:Destroy()
		end
	end
end

------------------------------------------------------------------
-- FEEDING
-- He stands at the guest and feeds. Then the guest either dies or is drained.
------------------------------------------------------------------
local function feedOn(guest, token)
	local guestRoot = guest:FindFirstChild("HumanoidRootPart")
	if not guestRoot or not draculaRoot then
		return
	end
	-- turn to face the guest
	local from = draculaRoot.Position
	local to = Vector3.new(guestRoot.Position.X, from.Y, guestRoot.Position.Z)
	if flatDistance(from, to) > 0.1 then
		dracula:PivotTo(CFrame.lookAt(from, to))
	end

	guest:SetAttribute("BeingFed", true)
	dracula:SetAttribute("Feeding", true)
	print("Dracula is feeding on " .. guest.Name)
	local finished = waitDuringNight(SETTINGS.FeedSeconds, token)
	guest:SetAttribute("BeingFed", false)
	if dracula then
		dracula:SetAttribute("Feeding", false)
	end
	if not finished then
		return -- dawn came, the guest is saved
	end

	if math.random() < SETTINGS.DeathChance then
		guest:SetAttribute("Status", "Dead")
		local humanoid = guest:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
		print(guest.Name .. " has died.")
	else
		guest:SetAttribute("Status", "Drained")
		tintGuest(guest, Color3.fromRGB(215, 210, 222)) -- pale and weak
		print(guest.Name .. " has been drained, and will turn tomorrow night.")
	end
end

------------------------------------------------------------------
-- ONE HUNT: choose a guest, get to their room, feed
------------------------------------------------------------------
-- Teleports the animated Dracula to the corridor just outside a guest's door.
-- DraculaPowers opens a warning pool there first, so players get a few seconds'
-- notice. This waits until he has arrived. Returns true if he did.
local function teleportToDoor(roomNumber)
	local teleport = ServerStorage:FindFirstChild("DraculaTeleport")
	local door = DoorControl.getGuestDoor(roomNumber)
	local anchor = door and door:FindFirstChild("PromptAnchor")
	if not (usingRig and teleport and anchor) then
		return false
	end
	-- the corridor is on the side of the door nearest z = 0, so step 8 studs that way
	local towardCorridor = (anchor.Position.Z > 0) and -1 or 1
	local spot = anchor.Position + Vector3.new(0, 0, towardCorridor * 8)
	return teleport:Invoke(spot) == true
end

local function hunt(guest, token)
	guest:SetAttribute("HuntedTonight", true)
	local deadline = os.clock() + SETTINGS.HuntTimeLimit
	local guestRoot = guest:FindFirstChild("HumanoidRootPart")
	if not guestRoot then
		return
	end
	local roomNumber = guest:GetAttribute("RoomNumber")
	print("Dracula hunts " .. guest.Name .. " in room " .. tostring(roomNumber))

	-- A long way off? Teleport to the corridor outside the door first.
	local distance = (draculaRoot.Position - guestRoot.Position).Magnitude
	if usingRig and distance > SETTINGS.TeleportIfFartherThan then
		teleportToDoor(roomNumber)
		if not stillNight(token) then
			return
		end
	end

	local result = walkTo(guestRoot.Position, token, deadline)
	if result == "nopath" then
		-- no walking route from here (a staircase he can't use, say)
		if usingRig then
			if teleportToDoor(roomNumber) and stillNight(token) then
				result = walkTo(guestRoot.Position, token, deadline)
			end
		elseif mistTo(roomNumber) then
			result = walkTo(guestRoot.Position, token, deadline)
		end
		if result == "nopath" and dracula and stillNight(token) then
			-- still no route: he reaches them straight through the wall, as shadow
			dracula:PivotTo(guestRoot.CFrame * CFrame.new(0, 0, 4))
			result = "arrived"
		end
	end

	if result == "arrived" and stillNight(token) and dracula then
		feedOn(guest, token)
	elseif result == "blocked" then
		print("A locked door stopped Dracula from reaching " .. guest.Name .. ".")
	end
end

------------------------------------------------------------------
-- PLAYERS: Dracula's touch
-- Every fifth of a second, if a player is close to him, they are
-- thrown back and stunned for a few seconds.
------------------------------------------------------------------
local function stunPlayer(player, character, root)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	stunnedUntil[player] = os.clock() + SETTINGS.StunSeconds + SETTINGS.StunImmunitySeconds

	-- throw them away from him
	local away = (root.Position - draculaRoot.Position) * Vector3.new(1, 0, 1)
	if away.Magnitude < 0.1 then
		away = Vector3.new(0, 0, 1)
	end
	root.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 25, 0)

	humanoid.PlatformStand = true -- the character goes limp and can't move

	-- a red glow and a label, so everyone can see who is stunned
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(200, 20, 30)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3.fromRGB(255, 60, 60)
	highlight.Parent = character

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(160, 36)
	label.StudsOffset = Vector3.new(0, 4, 0)
	label.AlwaysOnTop = true
	label.Adornee = root
	label.Parent = character
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 70, 70)
	text.Text = "Stunned!"
	text.Parent = label

	task.delay(SETTINGS.StunSeconds, function()
		humanoid.PlatformStand = false
		highlight:Destroy()
		label:Destroy()
	end)
end

-- Watches for players near him for as long as it is still the same night
local function watchForPlayers(token)
	task.spawn(function()
		while stillNight(token) and dracula do
			-- (while he sinks, rises or teleports he is locked in place, so he can't touch anyone)
			if draculaRoot and not draculaRoot.Anchored then
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and (root.Position - draculaRoot.Position).Magnitude < SETTINGS.ContactDistance
						and (stunnedUntil[player] or 0) < os.clock() then
						stunPlayer(player, character, root)
					end
				end
			end
			task.wait(0.2)
		end
	end)
end

------------------------------------------------------------------
-- THE NIGHT
------------------------------------------------------------------
local function runNight(day)
	nightToken = nightToken + 1
	local token = nightToken

	-- tonight, drained guests become vampires, and nobody has been hunted yet
	turnDrainedIntoVampires()
	for _, guest in ipairs(guestsFolder:GetChildren()) do
		guest:SetAttribute("HuntedTonight", nil)
	end

	-- time for the players to lock their doors
	if not waitDuringNight(SETTINGS.AwakenDelay, token) then
		return
	end
	if not spawnDracula(token) then
		return
	end
	watchForPlayers(token)

	local hunts = SETTINGS.HuntsPerNight[day] or SETTINGS.HuntsPerNight[#SETTINGS.HuntsPerNight]
	for number = 1, hunts do
		if not stillNight(token) then
			break
		end
		local target = pickTarget()
		if not target then
			print("Dracula finds no guest worth hunting.")
			break
		end
		hunt(target, token)
		if number < hunts and not waitDuringNight(SETTINGS.PauseBetweenHunts, token) then
			break
		end
	end

	-- hunting is over for tonight. He vanishes (if dawn didn't already send him home).
	if token == nightToken then
		despawnDracula()
	end
end

------------------------------------------------------------------
-- START
-- Doors have a solid slab in the way even when open paths exist, so the route
-- finder is told it can plan a path straight through each door's slab. Dracula
-- opens or breaks the door when he reaches it.
------------------------------------------------------------------
local waited = 0
while #DoorControl.getDoors() == 0 and waited < 10 do -- DoorManager may still be starting
	waited = waited + task.wait(0.5)
end
for _, door in ipairs(DoorControl.getDoors()) do
	for _, leaf in ipairs(door:GetChildren()) do
		local body = leaf:IsA("Model") and leaf:FindFirstChild("Body")
		if body and not body:FindFirstChildOfClass("PathfindingModifier") then
			local modifier = Instance.new("PathfindingModifier")
			modifier.PassThrough = true
			modifier.Parent = body
		end
	end
end

-- React to the phase changing. Night: start a hunt. Day: send him home and clear up.
phase.Changed:Connect(function()
	if phase.Value == "Night" then
		task.spawn(runNight, dayNumber.Value)
	else
		nightToken = nightToken + 1 -- stops any night still running
		despawnDracula()
		clearDeadGuests()
	end
end)

-- If the game starts at night, start the hunt now
if phase.Value == "Night" then
	task.spawn(runNight, dayNumber.Value)
end
