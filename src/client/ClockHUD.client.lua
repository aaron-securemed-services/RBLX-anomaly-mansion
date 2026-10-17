-- ClockHUD (LocalScript)
-- Shows the in-game time, the day number, and the phase on the player's
-- screen. This is a LocalScript: it runs on each player's own computer,
-- not on the server, which is where all screen/UI code belongs.

------------------------------------------------------------------
-- SERVICES AND SHARED VALUES
------------------------------------------------------------------
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LocalPlayer is the player running this script. PlayerGui is the folder
-- where that player's on-screen UI lives.
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- WaitForChild pauses until the object exists. We use it because
-- GameManager creates these values on the server, and they may not have
-- arrived at the player's computer yet when this script starts.
local phase = ReplicatedStorage:WaitForChild("Phase")
local dayNumber = ReplicatedStorage:WaitForChild("DayNumber")

------------------------------------------------------------------
-- BUILD THE UI
-- Normally you'd draw UI by hand in Studio. Building it in code means
-- there's nothing to set up: just add this script and it works.
------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui") -- the container that holds all on-screen UI
screenGui.Name = "ClockHUD"
screenGui.ResetOnSpawn = false              -- keep the HUD when the player's character respawns
screenGui.Parent = playerGui

local label = Instance.new("TextLabel")     -- a box of text
label.Size = UDim2.new(0, 260, 0, 70)       -- UDim2 is (scale, pixels) for width, then height: 260 x 70 pixels
label.Position = UDim2.new(0.5, -130, 0, 10) -- centered horizontally (50% across, minus half the width), 10px from the top
label.BackgroundColor3 = Color3.fromRGB(20, 15, 25) -- Color3 colors are red, green, blue from 0 to 255
label.BackgroundTransparency = 0.3          -- 0 = solid, 1 = invisible
label.TextColor3 = Color3.fromRGB(240, 230, 220)
label.Font = Enum.Font.GothamBold
label.TextSize = 22
label.Parent = screenGui

------------------------------------------------------------------
-- FUNCTION: formatTime
-- Turns the sky's hour (like 21.75) into clock text (like "9:45 PM").
------------------------------------------------------------------
local function formatTime(hour)
	local wholeHour = math.floor(hour)                      -- 21.75 -> 21
	local minutes = math.floor((hour - wholeHour) * 60)     -- the .75 part -> 45 minutes
	local suffix = wholeHour >= 12 and "PM" or "AM"         -- Luau's version of Python's: "PM" if ... else "AM"
	local displayHour = wholeHour % 12                      -- 21 -> 9
	if displayHour == 0 then
		displayHour = 12                                    -- 0 and 12 should both read as 12
	end
	-- string.format fills in the %d (whole number) and %s (text) slots.
	-- %02d means "at least 2 digits", so 5 minutes shows as 05.
	return string.format("%d:%02d %s", displayHour, minutes, suffix)
end

------------------------------------------------------------------
-- UPDATE EVERY FRAME
-- Lighting.ClockTime is set by the server and copied to every player,
-- so we can read it here directly.
------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	label.Text = string.format(
		"Day %d - %s\n%s",
		dayNumber.Value,
		phase.Value,
		formatTime(Lighting.ClockTime)
	)
end)
