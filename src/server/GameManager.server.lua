-- GameManager
-- Runs the game's schedule: 7 days, each with a Day phase then a Night phase
-- of fixed length.
-- It moves the sky, tracks the current phase and day number, and counts
-- down the time left. Other scripts read these values to know what's happening.

------------------------------------------------------------------
-- SERVICES
-- A "service" is a built-in Roblox system. GetService fetches one so
-- we can use it. Nearly every script starts with a few of these.
------------------------------------------------------------------
local Lighting = game:GetService("Lighting")           -- controls the sky, sun, and time of day
local RunService = game:GetService("RunService")       -- gives us a signal that fires every frame
local ReplicatedStorage = game:GetService("ReplicatedStorage") -- shared storage that server AND players can see

------------------------------------------------------------------
-- SETTINGS
-- Constants are written in CAPITALS by convention. They're values we
-- may want to tweak later, kept in one place at the top.
------------------------------------------------------------------

-- Speeds up the whole schedule for testing. 1 = normal speed,
-- 10 = ten times faster. REMEMBER to set it back to 1 before publishing!
local TIME_SCALE = 1

-- The sky's in-game hours (24-hour clock). The sun is up from 6 AM to 6 PM.
local DAY_START_HOUR = 6    -- 6:00 AM, sunrise
local NIGHT_START_HOUR = 18 -- 6:00 PM, sunset

-- How long each phase lasts, in real SECONDS. These are the same every day.
-- 210 seconds = 3:30 for the day, 180 seconds = 3:00 for the night.
local DAY_SECONDS = 210
local NIGHT_SECONDS = 180

-- How many days the players must survive. 7 days is about 45 minutes in total.
local TOTAL_DAYS = 7

------------------------------------------------------------------
-- SHARED VALUES
-- These are tiny objects in the game that each hold one value. Putting
-- them in ReplicatedStorage lets other scripts, including ones running
-- on the player's screen, read them (for example, to show a clock).
-- This helper function creates one so we don't repeat ourselves 3 times.
-- Parameters: className = what kind of value, name = its name in Explorer,
-- startValue = what it starts as.
------------------------------------------------------------------
local function makeValue(className, name, startValue)
	local valueObject = Instance.new(className) -- Instance.new creates a new object
	valueObject.Name = name                     -- the name it will have in Explorer
	valueObject.Value = startValue
	valueObject.Parent = ReplicatedStorage      -- setting the Parent puts it into the game world
	return valueObject                          -- hand it back so the caller can keep using it
end

local phase = makeValue("StringValue", "Phase", "Day")     -- "Day", "Night", or "Survived"
local dayNumber = makeValue("IntValue", "DayNumber", 1)    -- which day of the 7 we're on
local timeLeft = makeValue("IntValue", "TimeLeft", 0)      -- whole seconds left in this phase

------------------------------------------------------------------
-- FUNCTION: runPhase
-- Plays out ONE phase (a Day or a Night) from start to finish.
--   name       = the phase name to announce ("Day" or "Night")
--   duration   = how many real seconds the phase lasts
--   startHour  = the sky's time of day when the phase begins
--   endHour    = the sky's time of day when the phase ends
-- The sky slides smoothly from startHour to endHour, so a shorter
-- phase just means the sun moves faster. It doesn't skip anything.
------------------------------------------------------------------
local function runPhase(name, duration, startHour, endHour)
	duration = duration / TIME_SCALE -- apply the testing speed-up (does nothing when TIME_SCALE is 1)
	phase.Value = name
	print("Day", dayNumber.Value, "-", name, "begins")

	local startTime = os.clock() -- seconds since the game started; we measure from this moment

	-- "while true do ... break" loops forever until we say break.
	while true do
		local elapsed = os.clock() - startTime
		if elapsed >= duration then
			break -- the phase is over, leave the loop
		end

		-- alpha is how far through the phase we are: 0 at the start, 1 at the end
		local alpha = elapsed / duration

		-- Slide the sky from startHour to endHour. The % 24 wraps hours past
		-- midnight back to 0-24 (for example, hour 30 becomes 6 AM).
		Lighting.ClockTime = (startHour + (endHour - startHour) * alpha) % 24

		-- math.ceil rounds UP, so the countdown reads 1 until it hits 0
		timeLeft.Value = math.ceil(duration - elapsed)

		RunService.Heartbeat:Wait() -- pause until the next frame, then loop again
	end

	timeLeft.Value = 0
end

------------------------------------------------------------------
-- THE GAME LOOP
-- "for day = 1, TOTAL_DAYS do" repeats the block below once for each
-- day, with day counting 1, 2, 3 ... up to TOTAL_DAYS.
-- In Python this is like: for day in range(1, TOTAL_DAYS + 1)
------------------------------------------------------------------
for day = 1, TOTAL_DAYS do
	dayNumber.Value = day

	-- Day: the sky goes from sunrise (6) to sunset (18)
	runPhase("Day", DAY_SECONDS, DAY_START_HOUR, NIGHT_START_HOUR)

	-- Night: the sky goes from sunset (18) through midnight to the next
	-- sunrise. 6 + 24 = 30, which wraps to 6 AM inside runPhase.
	runPhase("Night", NIGHT_SECONDS, NIGHT_START_HOUR, DAY_START_HOUR + 24)
end

-- The loop finished, so the players lasted all 7 nights.
phase.Value = "Survived"
print("The week is over - the police arrive! Players survived.")
