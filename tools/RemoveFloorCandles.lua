--[[
  REMOVE FLOOR CANDLES  -  Dracula's BnB
  Quick command: deletes candles that sit on the floor of the Crypt (the
  leftover ones from the castle builder, like the ones on the red carpet).
  It keeps wall candles, chandelier candles, and the candles on the stands
  beside the coffin.

  HOW TO USE: paste the whole file into the Command Bar and click Run.
  Ctrl+Z (Cmd+Z on Mac) undoes it.

  SETTINGS
    ALL_ROOMS    false = only the Crypt. true = every room in the castle.
    MAX_HEIGHT   a candle counts as "on the floor" if it's lower than this
                 many studs above the floor. Wall candles hang at about 9,
                 so 2 is safe.
]]

local ALL_ROOMS = false
local MAX_HEIGHT = 2

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local castle = workspace:FindFirstChild("DraculaCastle")
if not castle then
	error("No DraculaCastle in Workspace.")
end

-- Work out which rooms to clean
local rooms = {}
if ALL_ROOMS then
	for _, object in ipairs(castle:GetDescendants()) do
		if object:IsA("Model") and object:FindFirstChild("Zone") then
			table.insert(rooms, object)
		end
	end
else
	local crypt = castle:FindFirstChild("Crypt", true)
	if not crypt then
		error("Couldn't find the Crypt.")
	end
	rooms = { crypt }
end

local recording
pcall(function() recording = ChangeHistoryService:TryBeginRecording("Remove Floor Candles") end)

local removed = 0
for _, room in ipairs(rooms) do
	local zone = room:FindFirstChild("Zone")
	if zone then
		-- the floor is 0.2 above the bottom of the room's invisible Zone box
		local floorY = zone.Position.Y - zone.Size.Y / 2 + 0.2
		-- Only the room's own parts (GetChildren, not GetDescendants), so
		-- candles on furniture and on the candle stands are never touched.
		for _, part in ipairs(room:GetChildren()) do
			local isCandle = part.Name == "Candle" or part.Name == "Flame"
			if isCandle and part:IsA("BasePart") and part.Position.Y - floorY < MAX_HEIGHT then
				part:Destroy()
				removed = removed + 1
			end
		end
	end
end

if recording then
	pcall(function() ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit) end)
else
	pcall(function() ChangeHistoryService:SetWaypoint("Remove Floor Candles") end)
end
print("Removed " .. removed .. " floor candle pieces (each candle is a stick and a flame).")
