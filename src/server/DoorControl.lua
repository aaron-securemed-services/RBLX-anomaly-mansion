-- DoorControl (ModuleScript)
-- Everything doors do. It opens and closes them, locks and unlocks them,
-- and lets Dracula break a locked one down. Other scripts load it with
-- require() and call the functions at the bottom, like Dracula's script will.
--
-- Rules:
--   * Players press E (A on Xbox, X/cross on PlayStation) to open or close a door,
--     and F (X on Xbox, square on PlayStation) to lock or unlock it.
--   * Only players can lock or unlock a door. Guests and monsters can't.
--   * A locked door can't be opened by a player until it's unlocked.
--   * Dracula can't walk through a locked door. He has to break it down,
--     which takes BREAK_SECONDS seconds and makes noise. After that the door
--     is broken and stays open until the next morning, when it's repaired.
--     (Set Settings.DraculaCanBreak to false and a locked door stops him completely.)
--
-- Doors are built by tools/DoorBuilder.lua. Each is a Model tagged "CastleDoor"
-- with one or two "leaf" Models that swing around an invisible Hinge.
-- This module keeps each door's state and mirrors it into attributes on the
-- door Model: IsOpen, IsLocked, IsBroken, BeingBroken.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local DoorControl = {}

------------------------------------------------------------------
-- SETTINGS
-- These live in a table so other scripts can read or change them.
------------------------------------------------------------------
DoorControl.Settings = {
	OpenAngle = 100,        -- how far a door swings open, in degrees
	OpenSeconds = 0.7,      -- how long opening or closing takes
	DraculaCanBreak = true, -- false = a locked door can never be passed
	BreakSeconds = 4,       -- how long Dracula takes to break a locked door down
	NoiseSoundId = "",      -- an optional "rbxassetid://..." sound played while a door is being broken
}

local LOCKED_COLOR = Color3.fromRGB(255, 40, 40)
local UNLOCKED_COLOR = Color3.fromRGB(70, 68, 70)

------------------------------------------------------------------
-- STATE
-- `states` finds a door's record from its Model. Each record is:
--   door, leaves = { { model, closed, sign } }, angle (0 shut .. 1 open),
--   open, locked, broken, breaking, token, openPrompt, lockPrompt
------------------------------------------------------------------
local states = {}

-- Moves every leaf of a door to a pose.
--   fraction  0 = shut, 1 = fully open (more than 1 swings further)
--   shake     an extra wobble in degrees, used while a door is being broken
local function setPose(state, fraction, shake)
	for _, leaf in ipairs(state.leaves) do
		local degrees = leaf.sign * DoorControl.Settings.OpenAngle * fraction + (shake or 0)
		-- `closed` is where the leaf hung when shut. Turning it by an angle
		-- around its own up axis (the hinge) swings the door.
		leaf.model:PivotTo(leaf.closed * CFrame.Angles(0, math.rad(degrees), 0))
	end
end

-- Smoothly swings a door to `target` (0 or 1) over `seconds`.
-- Starting a new swing cancels one that's still going: each swing gets
-- a number (token), and an old swing stops when the number has changed.
local function animateTo(state, target, seconds)
	state.token = state.token + 1
	local myToken = state.token
	task.spawn(function() -- run in the background so the caller doesn't wait
		local start = state.angle
		local elapsed = 0
		while elapsed < seconds do
			elapsed = elapsed + RunService.Heartbeat:Wait() -- wait one frame, and add how long it took
			if state.token ~= myToken then
				return -- a newer swing took over
			end
			local alpha = math.clamp(elapsed / seconds, 0, 1)
			local smooth = alpha * alpha * (3 - 2 * alpha) -- eases in and out
			state.angle = start + (target - start) * smooth
			setPose(state, state.angle, 0)
		end
		if state.token == myToken then
			state.angle = target
			setPose(state, target, 0)
		end
	end)
end

-- Updates the prompts and the red lock lights to match the state
local function refresh(state)
	local door = state.door
	door:SetAttribute("IsOpen", state.open)
	door:SetAttribute("IsLocked", state.locked)
	door:SetAttribute("IsBroken", state.broken)
	door:SetAttribute("BeingBroken", state.breaking)

	local usable = not state.broken and not state.breaking
	if state.openPrompt then
		state.openPrompt.Enabled = usable and not state.locked -- a locked door can't be opened
		state.openPrompt.ActionText = state.open and "Close" or "Open"
	end
	if state.lockPrompt then
		state.lockPrompt.Enabled = usable
		state.lockPrompt.ActionText = state.locked and "Unlock" or "Lock"
	end

	-- the small light on the lock plate turns red when locked
	for _, object in ipairs(door:GetDescendants()) do
		if object.Name == "LockIndicator" and object:IsA("BasePart") then
			object.Color = state.locked and LOCKED_COLOR or UNLOCKED_COLOR
			object.Material = state.locked and Enum.Material.Neon or Enum.Material.Metal
		end
	end
end

------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-- Each takes the door's Model. They return true if it worked.
------------------------------------------------------------------

-- Opens (open = true) or closes (open = false) a door
function DoorControl.setOpen(door, open)
	local state = states[door]
	if not state or state.broken or state.breaking then
		return false
	end
	if open and state.locked then
		return false -- locked doors don't open
	end
	state.open = open
	animateTo(state, open and 1 or 0, DoorControl.Settings.OpenSeconds)
	refresh(state)
	return true
end

-- Locks (locked = true) or unlocks a door. Locking an open door shuts it first.
function DoorControl.setLocked(door, locked)
	local state = states[door]
	if not state or state.broken or state.breaking then
		return false
	end
	if locked and state.open then
		state.open = false
		animateTo(state, 0, DoorControl.Settings.OpenSeconds)
	end
	state.locked = locked
	refresh(state)
	return true
end

-- Dracula's script calls this when he reaches a door. It WAITS until he's
-- through, so call it from his own thread. Returns true if he got through,
-- or false if he can't (breaking is switched off, or the door was repaired mid-break).
--   * unlocked door: he opens it straight away
--   * locked door:   he shakes and breaks it down over BreakSeconds, with noise
function DoorControl.breakDown(door)
	local state = states[door]
	if not state then
		return false
	end
	if state.broken then
		return true -- already broken, he walks through
	end
	if not state.locked then
		return DoorControl.setOpen(door, true)
	end
	if not DoorControl.Settings.DraculaCanBreak then
		return false -- the lock holds
	end

	-- start breaking: cancel any swing, show it, start the noise
	state.token = state.token + 1
	state.breaking = true
	refresh(state)

	local sound
	if DoorControl.Settings.NoiseSoundId ~= "" then
		sound = Instance.new("Sound")
		sound.SoundId = DoorControl.Settings.NoiseSoundId
		sound.Looped = true
		sound.Volume = 1
		sound.RollOffMaxDistance = 120 -- the noise carries far down the corridors
		sound.Parent = door:FindFirstChild("PromptAnchor") or door
		sound:Play()
	end

	local elapsed = 0
	local total = DoorControl.Settings.BreakSeconds
	while elapsed < total do
		elapsed = elapsed + RunService.Heartbeat:Wait()
		if not state.breaking then
			if sound then sound:Destroy() end
			return false -- the door was repaired while he was breaking it
		end
		-- the door shakes harder and harder as it gives way
		local intensity = 0.5 + 3 * (elapsed / total)
		setPose(state, 0, (math.random() - 0.5) * 2 * intensity)
	end

	if sound then sound:Destroy() end
	state.breaking = false
	state.locked = false
	state.broken = true
	state.open = true
	state.angle = 0
	animateTo(state, 1.1, 0.35) -- it bursts open a little wider than normal
	refresh(state)
	return true
end

-- Fixes a broken door: shut, unlocked, working again
function DoorControl.repair(door)
	local state = states[door]
	if not state then
		return
	end
	state.token = state.token + 1
	state.breaking = false
	state.broken = false
	state.locked = false
	state.open = false
	animateTo(state, 0, 0.4)
	refresh(state)
end

-- Repairs every broken door (DoorManager does this each morning)
function DoorControl.repairAll()
	for door, state in pairs(states) do
		if state.broken or state.breaking then
			DoorControl.repair(door)
		end
	end
end

-- Handy lookups for other scripts
function DoorControl.getDoors()
	local list = {}
	for door in pairs(states) do
		table.insert(list, door)
	end
	return list
end

function DoorControl.getGuestDoor(roomNumber)
	for door in pairs(states) do
		if door:GetAttribute("RoomNumber") == roomNumber then
			return door
		end
	end
	return nil
end

function DoorControl.getFrontDoor()
	for door in pairs(states) do
		if door:GetAttribute("DoorType") == "Front" then
			return door
		end
	end
	return nil
end

function DoorControl.isLocked(door)
	return states[door] ~= nil and states[door].locked
end

------------------------------------------------------------------
-- START
-- Finds every tagged door, sets up its state, and adds the prompts.
-- Call this once.
------------------------------------------------------------------
function DoorControl.start()
	local count = 0
	for _, door in ipairs(CollectionService:GetTagged("CastleDoor")) do
		-- the leaves: the Models that have an OpenSign attribute
		local leaves = {}
		for _, child in ipairs(door:GetChildren()) do
			if child:IsA("Model") and child:GetAttribute("OpenSign") then
				table.insert(leaves, {
					model = child,
					closed = child:GetPivot(), -- where it hangs when shut
					sign = child:GetAttribute("OpenSign"),
				})
			end
		end

		local state = {
			door = door, leaves = leaves, angle = 0,
			open = false, locked = false, broken = false, breaking = false, token = 0,
		}
		states[door] = state

		-- The prompts hang on an invisible part in the middle of the doorway, so they
		-- stay in the same place however far the door is open.
		local anchor = door:FindFirstChild("PromptAnchor")
		if anchor then
			local distance = door:GetAttribute("PromptDistance") or 9
			local objectText = (door:GetAttribute("DoorType") == "Front") and "Castle door"
				or ("Room " .. tostring(door:GetAttribute("RoomNumber")))

			-- Open / Close: E on keyboard, A on Xbox, X (cross) on PlayStation
			local openPrompt = Instance.new("ProximityPrompt")
			openPrompt.ObjectText = objectText
			openPrompt.ActionText = "Open"
			openPrompt.KeyboardKeyCode = Enum.KeyCode.E
			openPrompt.GamepadKeyCode = Enum.KeyCode.ButtonA
			openPrompt.HoldDuration = 0
			openPrompt.MaxActivationDistance = distance
			openPrompt.RequiresLineOfSight = false
			openPrompt.Parent = anchor
			openPrompt.Triggered:Connect(function()
				DoorControl.setOpen(door, not state.open)
			end)

			-- Lock / Unlock: F on keyboard, X on Xbox, square on PlayStation
			local lockPrompt = Instance.new("ProximityPrompt")
			lockPrompt.ObjectText = objectText
			lockPrompt.ActionText = "Lock"
			lockPrompt.KeyboardKeyCode = Enum.KeyCode.F
			lockPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			lockPrompt.HoldDuration = 0.3 -- a short hold, so you don't lock a door by accident
			lockPrompt.MaxActivationDistance = distance
			lockPrompt.RequiresLineOfSight = false
			lockPrompt.UIOffset = Vector2.new(0, 70) -- sits below the Open prompt
			lockPrompt.Parent = anchor
			lockPrompt.Triggered:Connect(function()
				DoorControl.setLocked(door, not state.locked)
			end)

			state.openPrompt = openPrompt
			state.lockPrompt = lockPrompt
		end

		refresh(state)
		count = count + 1
	end

	if count == 0 then
		warn("DoorControl: no doors found. Run tools/DoorBuilder.lua to build them.")
	else
		print("DoorControl: " .. count .. " doors ready.")
	end
end

return DoorControl
