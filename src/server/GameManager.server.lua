-- GameManager
-- Runs the game's clock. It moves the in-game time forward, updates the
-- sky lighting to match, and tracks whether it is Day, Night, or Dawn.

------------------------------------------------------------------
-- SERVICES
-- A "service" is a built-in Roblox system. GetService fetches one so
-- we can use it. Nearly every script starts with a few of these.
------------------------------------------------------------------
local Lighting = game:GetService("Lighting")           -- controls the sky, sun, and time of day
local RunService = game:GetService("RunService")       -- lets us run code every frame
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- shared storage that server AND players can see

------------------------------------------------------------------
-- SETTINGS
-- Constants are written in CAPITALS by convention. They're values we
-- may want to tweak later, kept in one place at the top.
-- ("local" means the variable only exists inside this script.)
------------------------------------------------------------------
local SECONDS_PER_GAME_HOUR = 60 -- 60 real seconds = 1 in-game hour, so a full day is 24 real minutes
local START_HOUR = 8             -- the game starts at 8:00 AM

-- Phase boundaries, as hours on a 24-hour clock (e.g. 21 = 9:00 PM)
local DAWN_START = 3   -- 3:00 AM
local DAY_START = 5    -- 5:00 AM
local NIGHT_START = 21 -- 9:00 PM

------------------------------------------------------------------
-- FUNCTION: phaseForHour
-- Takes an hour (a number from 0 to 24) and returns the name of the
-- phase for that time, as text. In Python this would be:
--   def phase_for_hour(hour): ...
-- "return" hands a value back to whoever called the function.
------------------------------------------------------------------
local function phaseForHour(hour)
	-- "or" means either condition can be true. Night is 9 PM onward,
	-- or anything before 3 AM (after midnight the hour wraps back to 0).
	if hour >= NIGHT_START or hour < DAWN_START then
		return "Night"
	elseif hour < DAY_START then -- here the hour is 3 to 5, so it's Dawn
		return "Dawn"
	else                          -- everything else, 5 AM to 9 PM
		return "Day"
	end -- every if/function/loop in Luau closes with "end"
end

------------------------------------------------------------------
-- PHASE VALUE
-- We create a StringValue, a tiny object in the game that holds text.
-- Putting it in ReplicatedStorage lets other scripts, including ones
-- running on the player's screen, read the current phase.
------------------------------------------------------------------
local phase = Instance.new("StringValue") -- Instance.new creates a new object
phase.Name = "Phase"                       -- the name it will have in Explorer
phase.Value = phaseForHour(START_HOUR)     -- starting value, e.g. "Day"
phase.Parent = ReplicatedStorage           -- setting the Parent puts it into the game world

------------------------------------------------------------------
-- THE CLOCK
-- os.clock() returns the seconds elapsed since the program started.
-- We remember the time right now so we can measure how much has
-- passed later.
------------------------------------------------------------------
local startTime = os.clock()

-- Heartbeat fires every frame (about 60 times a second).
-- :Connect(...) says "run this function every time that happens".
-- This is called an event connection.
RunService.Heartbeat:Connect(function()
	-- Real seconds since the game started, divided by 60, gives game hours passed
	local elapsedHours = (os.clock() - startTime) / SECONDS_PER_GAME_HOUR

	-- Add the starting hour, then use % (modulo, same as Python) so the
	-- time wraps back to 0 after 24 instead of counting up forever
	local hour = (START_HOUR + elapsedHours) % 24

	-- ClockTime is the sky's time of day, so this moves the sun and darkness
	Lighting.ClockTime = hour

	-- Work out the phase and only act if it changed since last frame.
	-- Without this check we'd print 60 messages a second.
	local newPhase = phaseForHour(hour)
	if phase.Value ~= newPhase then -- "~=" means "not equal" (Python's !=)
		phase.Value = newPhase
		print("Phase is now:", newPhase, "at hour", math.floor(hour)) -- math.floor rounds down
	end
end)
