-- KeyBoard (LocalScript)
-- The screen that opens when you use one of the key boards behind the
-- front desk. It lists every room. Vacant rooms are dim, and occupied
-- rooms show the guest's first name. Pick a room to see who is staying
-- there, when they arrived, and the clues you noticed about them.
-- This is a LocalScript, so it runs on each player's own screen.
--
-- Works with mouse, touch and controller:
--   Mouse / touch   click or tap a room
--   Controller      D-pad or left stick moves between rooms, A (Xbox) or
--                   X/cross (PlayStation) picks one, B / circle closes

------------------------------------------------------------------
-- SERVICES AND REMOTE EVENTS
------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local showKeyBoard = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ShowKeyBoard")

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local CLOSE_DISTANCE = 25 -- the screen closes if you walk this far from the key board

local COLORS = {
	Panel = Color3.fromRGB(24, 18, 22),
	Inset = Color3.fromRGB(38, 29, 34),
	Cream = Color3.fromRGB(236, 226, 205),
	Gold = Color3.fromRGB(176, 141, 62),
	Muted = Color3.fromRGB(150, 138, 138),
	Vacant = Color3.fromRGB(52, 44, 48),
	Occupied = Color3.fromRGB(96, 20, 30),
}

-- Creates a UI object, sets its properties from a table, and parents it.
-- Example: make("TextLabel", { Text = "Hi" }, frame)
local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

------------------------------------------------------------------
-- BUILD THE SCREEN (hidden until a key board is used)
------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "KeyBoardGui",
	ResetOnSpawn = false,
	DisplayOrder = 10,
	Enabled = false,
}, playerGui)

local card = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(660, 420),
	BackgroundColor3 = COLORS.Panel,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
make("UIStroke", { Color = COLORS.Gold, Thickness = 2 }, card)

-- Shrinks the screen on small windows so it always fits
local cardScale = make("UIScale", {}, card)
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		cardScale.Scale = math.clamp(camera.ViewportSize.Y / 560, 0.55, 1)
	end
end
updateScale()

make("TextLabel", {
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.Antique,
	TextSize = 30,
	TextColor3 = COLORS.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Room Keys",
}, card)

make("TextLabel", {
	Position = UDim2.fromOffset(16, 46),
	Size = UDim2.new(1, -32, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Pick a room to see who is staying there.",
}, card)

-- Left: the grid of rooms, 4 across (one floor per two rows)
local roomGrid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 80),
	Size = UDim2.fromOffset(384, 270),
	BackgroundColor3 = COLORS.Inset,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Selectable = false, -- a controller should skip the frame and move between the room buttons
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, roomGrid)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(84, 50),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, roomGrid)
make("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, roomGrid)

-- Right: details about the picked room
local details = make("Frame", {
	Position = UDim2.fromOffset(412, 80),
	Size = UDim2.fromOffset(232, 270),
	BackgroundColor3 = COLORS.Inset,
	BorderSizePixel = 0,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, details)

local detailTitle = make("TextLabel", {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 24),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 18,
	TextColor3 = COLORS.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, details)

local detailSubtitle = make("TextLabel", {
	Position = UDim2.fromOffset(12, 32),
	Size = UDim2.new(1, -24, 0, 18),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, details)

local clueList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(8, 58),
	Size = UDim2.new(1, -16, 1, -66),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Selectable = false,
}, details)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, clueList)
make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, clueList)

local closeButton = make("TextButton", {
	Position = UDim2.fromOffset(518, 364),
	Size = UDim2.fromOffset(126, 40),
	BackgroundColor3 = COLORS.Inset,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = COLORS.Cream,
	Text = "Close",
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, closeButton)

------------------------------------------------------------------
-- CONTROLLER ICON
-- With a controller we show the B button (circle on PlayStation) on the
-- Close button. Roblox picks the right icon for the controller plugged in.
------------------------------------------------------------------
local function usingGamepad()
	local lastInput = UserInputService:GetLastInputType()
	return string.find(lastInput.Name, "Gamepad") ~= nil
end

local closeGlyph = make("ImageLabel", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(26, 26),
	BackgroundTransparency = 1,
	Visible = false,
}, closeButton)

local function updateGlyph()
	local gamepad = usingGamepad()
	closeGlyph.Visible = gamepad
	if gamepad then
		pcall(function() -- pcall means "try this, don't crash if it fails"
			closeGlyph.Image = UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonB)
		end)
	end
end
updateGlyph()
UserInputService.LastInputTypeChanged:Connect(updateGlyph)

------------------------------------------------------------------
-- STATE
------------------------------------------------------------------
local isOpen = false
local boardPosition = nil  -- where the key board is, so we can close if the player walks away
local roomButtons = {}     -- room number -> its button
local roomInfo = {}        -- room number -> its entry from the server
local selectedRoom = nil

-- Updates the colors of the room buttons to show the picked one
local function refreshButtons()
	for number, button in pairs(roomButtons) do
		if number == selectedRoom then
			button.BackgroundColor3 = COLORS.Gold
			button.TextColor3 = COLORS.Panel
		elseif roomInfo[number].occupied then
			button.BackgroundColor3 = COLORS.Occupied
			button.TextColor3 = COLORS.Cream
		else
			button.BackgroundColor3 = COLORS.Vacant
			button.TextColor3 = COLORS.Muted
		end
	end
end

-- Shows the details of one room on the right
local function showRoom(number)
	selectedRoom = number
	local info = roomInfo[number]

	-- clear the old clues
	for _, child in ipairs(clueList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	-- A line of wrapped text in the details list
	local function addLine(order, text, color)
		make("TextLabel", {
			LayoutOrder = order,
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, -- grows tall enough for the wrapped text
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = color or COLORS.Cream,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
		}, clueList)
	end

	if info.guest then
		detailTitle.Text = "Room " .. number .. ": " .. info.guest.name
		detailSubtitle.Text = "Arrived on day " .. info.guest.day
		addLine(0, "What you noticed:", COLORS.Gold)
		for i, clue in ipairs(info.guest.clues) do
			addLine(i, "•  " .. clue)
		end
	elseif info.occupied then
		detailTitle.Text = "Room " .. number
		detailSubtitle.Text = "Occupied"
	else
		detailTitle.Text = "Room " .. number
		detailSubtitle.Text = "Vacant"
		addLine(1, "The key is on its hook, ready for a guest.", COLORS.Muted)
	end
	refreshButtons()
end

------------------------------------------------------------------
-- OPEN AND CLOSE
------------------------------------------------------------------
local function closeBoard()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil -- let go of the controller's selection
	end
	gui.Enabled = false
	isOpen = false
end

-- Builds the room buttons from the server's list and shows the screen.
--   data.rooms          list of { number, occupied, guest = { name, day, clues } }
--   data.boardPosition  where the key board is
local function openBoard(data)
	boardPosition = data.boardPosition
	roomInfo = {}
	roomButtons = {}
	selectedRoom = nil

	for _, child in ipairs(roomGrid:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local firstOccupied, firstRoom
	for i, room in ipairs(data.rooms) do
		roomInfo[room.number] = room
		firstRoom = firstRoom or room.number
		if room.occupied and not firstOccupied then
			firstOccupied = room.number
		end

		-- Two lines: the room number in bold, and the guest's first name (or "Vacant")
		local label = "Vacant"
		if room.guest then
			label = string.match(room.guest.name, "^%S+") or room.guest.name -- the first word of the name
		elseif room.occupied then
			label = "Occupied"
		end
		local button = make("TextButton", {
			LayoutOrder = i,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			RichText = true, -- lets us use <b> for bold in the text
			Text = "<b><font size=\"17\">" .. room.number .. "</font></b>\n" .. label,
		}, roomGrid)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		roomButtons[room.number] = button

		-- Activated fires on a click, a tap, or the A button when selected
		button.Activated:Connect(function()
			showRoom(room.number)
		end)
	end

	-- Start on the first occupied room, or the first room if nobody is in yet
	showRoom(firstOccupied or firstRoom)
	gui.Enabled = true
	isOpen = true

	-- With a controller, start with a room selected so the D-pad works straight away
	if usingGamepad() and roomButtons[firstOccupied or firstRoom] then
		GuiService.SelectedObject = roomButtons[firstOccupied or firstRoom]
	end
end

closeButton.Activated:Connect(closeBoard)
showKeyBoard.OnClientEvent:Connect(openBoard)

-- B on the controller (circle on PlayStation) closes the screen
UserInputService.InputBegan:Connect(function(input)
	if isOpen and input.KeyCode == Enum.KeyCode.ButtonB then
		closeBoard()
	end
end)

------------------------------------------------------------------
-- HOUSEKEEPING
-- Close the screen if the player walks away from the key board.
-- Check four times a second, which is plenty.
------------------------------------------------------------------
local sinceCheck = 0
RunService.Heartbeat:Connect(function(deltaTime)
	sinceCheck = sinceCheck + deltaTime
	if sinceCheck < 0.25 then
		return
	end
	sinceCheck = 0

	if not isOpen or not boardPosition then
		return
	end
	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if playerRoot and (playerRoot.Position - boardPosition).Magnitude > CLOSE_DISTANCE then
		closeBoard()
	end
end)

local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
