-- DoorManager
-- Starts the doors and repairs broken ones every morning.
-- The real work is in the DoorControl ModuleScript (same folder).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- require() loads a ModuleScript and gives back what it returns.
-- Here that's the DoorControl table of door functions.
local DoorControl = require(ServerScriptService:WaitForChild("DoorControl"))
DoorControl.start() -- find every door, set up its state and its prompts

-- GameManager keeps the current phase ("Day" or "Night") in ReplicatedStorage
local phase = ReplicatedStorage:WaitForChild("Phase")

-- Each time a new day starts, workers fix anything Dracula broke the night before
phase.Changed:Connect(function()
	if phase.Value == "Day" then
		DoorControl.repairAll()
	end
end)
