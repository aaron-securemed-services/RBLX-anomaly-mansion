-- GuestCard (LocalScript)
-- The card that opens when you talk to a guest. It shows the guest's name,
-- the clues you notice about them, and a grid of rooms. Pick a room and
-- press "Check in".
-- This is a LocalScript, so it runs on each player's own screen. Each
-- player sees their own card, and nobody else's.
--
-- It works with mouse, touch and controller:
--   Mouse / touch   click or tap the buttons
--   Controller      D-pad or left stick moves between buttons, A (Xbox) or
--                   X/cross (PlayStation) presses the selected one, and
--                   B (Xbox) or circle (PlayStation) closes the card

------------------------------------------------------------------
-- SERVICES AND REMOTE EVENTS
-- GuestManager (on the server) creates these. WaitForChild pauses until
-- they've arrived on this player's computer.
------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService") -- keyboard, mouse and controller input
local GuiService = game:GetService("GuiService")             -- controls which button a controller has selected

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local showGuestCard = remotes:WaitForChild("ShowGuestCard")
local requestCheckIn = remotes:WaitForChild("RequestCheckIn")
local checkInResult = remotes:WaitForChild("CheckInResult")

------------------------------------------------------------------
-- SETTINGS
------------------------------------------------------------------
local CLOSE_DISTANCE = 25 -- the card closes if you walk this far from the guest

local COLORS = {
	Panel = Color3.fromRGB(24, 18, 22),
	Inset = Color3.fromRGB(38, 29, 34),
	Cream = Color3.fromRGB(236, 226, 205),
	Gold = Color3.fromRGB(176, 141, 62),
	Red = Color3.fromRGB(122, 24, 36),
	Muted = Color3.fromRGB(150, 138, 138),
	Taken = Color3.fromRGB(52, 44, 48),
	Free = Color3.fromRGB(70, 52, 60),
	Disabled = Color3.fromRGB(70, 60, 64),
}

------------------------------------------------------------------
-- HELPER FUNCTION: make
-- Creates a UI object, sets its properties from a table, and puts it
-- inside a parent. It saves us writing "thing.X = ..." over and over.
-- Example: make("TextLabel", { Text = "Hi", Size = UDim2.new(1, 0, 0, 20) }, frame)
------------------------------------------------------------------
local function make(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

------------------------------------------------------------------
-- BUILD THE CARD (hidden until a guest is talked to)
-- UDim2.new(scaleX, offsetX, scaleY, offsetY): scale is a fraction of
-- the parent's size (0.5 = half), offset is a fixed number of pixels.
------------------------------------------------------------------
local gui = make("ScreenGui", {
	Name = "GuestCardGui",
	ResetOnSpawn = false, -- keep the card if the player's character respawns
	DisplayOrder = 10,
	Enabled = false,
}, playerGui)

local card = make("Frame", {
	Name = "Card",
	AnchorPoint = Vector2.new(0.5, 0.5), -- the middle of the card is its position point
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 590),
	BackgroundColor3 = COLORS.Panel,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, card)
make("UIStroke", { Color = COLORS.Gold, Thickness = 2 }, card)

-- Shrinks the whole card on small screens so it always fits
local cardScale = make("UIScale", {}, card)
local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		cardScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.55, 1)
	end
end
updateScale()

local title = make("TextLabel", {
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -32, 0, 36),
	BackgroundTransparency = 1,
	Font = Enum.Font.Antique,
	TextSize = 30,
	TextColor3 = COLORS.Gold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "Guest",
}, card)

local subtitle = make("TextLabel", {
	Position = UDim2.fromOffset(16, 48),
	Size = UDim2.new(1, -32, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextColor3 = COLORS.Muted,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, card)

-- A small heading above each section
local function heading(text, y)
	make("TextLabel", {
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, 18),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = COLORS.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
	}, card)
end

-- The clues: a list that scrolls if there are a lot of them
heading("WHAT YOU NOTICE", 80)
local clueList = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 102),
	Size = UDim2.new(1, -32, 0, 170),
	BackgroundColor3 = COLORS.Inset,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, -- the scrollable area grows to fit the clues
	Selectable = false, -- a controller should skip this and jump between the buttons
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, clueList)
make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, clueList) -- stacks the clues top to bottom
make("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, clueList)

-- The rooms: a grid of buttons, 4 across
heading("CHOOSE A ROOM", 286)
local roomGrid = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 308),
	Size = UDim2.new(1, -32, 0, 170),
	BackgroundColor3 = COLORS.Inset,
	BorderSizePixel = 0,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	Selectable = false,
}, card)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, roomGrid)
make("UIGridLayout", {
	CellSize = UDim2.fromOffset(90, 34),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, roomGrid)
make("UIPadding", {
	PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, roomGrid)

-- A line of text for messages like "Room 204 is already taken."
local status = make("TextLabel", {
	Position = UDim2.fromOffset(16, 486),
	Size = UDim2.new(1, -32, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	TextSize = 14,
	TextColor3 = COLORS.Cream,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
}, card)

-- A button with the card's look. Returns the button.
local function makeButton(text, position, size, color)
	local button = make("TextButton", {
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = COLORS.Cream,
		Text = text,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	return button
end

local checkInButton = makeButton("Choose a room", UDim2.fromOffset(16, 524), UDim2.fromOffset(290, 44), COLORS.Disabled)
local closeButton = makeButton("Close", UDim2.fromOffset(318, 524), UDim2.fromOffset(126, 44), COLORS.Inset)

------------------------------------------------------------------
-- CONTROLLER SUPPORT
-- With a controller we show the button to press (A and B on Xbox, cross
-- and circle on PlayStation) as a small icon on the Check in and Close
-- buttons. Roblox picks the right icon for the controller plugged in.
------------------------------------------------------------------

-- True if the last thing the player used was a controller
local function usingGamepad()
	local lastInput = UserInputService:GetLastInputType()
	return string.find(lastInput.Name, "Gamepad") ~= nil
end

-- Makes a small icon on the left of a button, hidden until a controller is used
local function makeGlyph(button, keyCode)
	local image = make("ImageLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Visible = false,
	}, button)
	return { image = image, keyCode = keyCode }
end

local glyphs = {
	makeGlyph(checkInButton, Enum.KeyCode.ButtonA), -- A on Xbox, X (cross) on PlayStation
	makeGlyph(closeButton, Enum.KeyCode.ButtonB),   -- B on Xbox, circle on PlayStation
}

local function updateGlyphs()
	local gamepad = usingGamepad()
	for _, glyph in ipairs(glyphs) do
		glyph.image.Visible = gamepad
		if gamepad then
			-- pcall means "try this, and don't crash if it fails"
			pcall(function()
				glyph.image.Image = UserInputService:GetImageForKeyCode(glyph.keyCode)
			end)
		end
	end
end
updateGlyphs()
UserInputService.LastInputTypeChanged:Connect(updateGlyphs) -- runs whenever they switch between controller and keyboard/mouse

------------------------------------------------------------------
-- STATE
-- Variables that remember what the card is showing right now.
------------------------------------------------------------------
local currentGuest = nil   -- the guest character this card is about (nil = card closed)
local selectedRoom = nil   -- the room number the player has picked
local roomButtons = {}     -- room number -> its button
local waitingForReply = false -- true after pressing Check in, until the server answers

------------------------------------------------------------------
-- FUNCTION: refreshButtons
-- Updates the colors of the room buttons and the Check in button to
-- match the current choice.
------------------------------------------------------------------
local function refreshButtons()
	for number, button in pairs(roomButtons) do
		if button:GetAttribute("Occupied") then
			button.BackgroundColor3 = COLORS.Taken
			button.TextColor3 = COLORS.Muted
		elseif number == selectedRoom then
			button.BackgroundColor3 = COLORS.Gold
			button.TextColor3 = COLORS.Panel
		else
			button.BackgroundColor3 = COLORS.Free
			button.TextColor3 = COLORS.Cream
		end
	end

	if selectedRoom then
		checkInButton.Text = "Check in to room " .. selectedRoom
		checkInButton.BackgroundColor3 = COLORS.Red
	else
		checkInButton.Text = "Choose a room"
		checkInButton.BackgroundColor3 = COLORS.Disabled
	end
end

------------------------------------------------------------------
-- FUNCTION: closeCard
-- Hides the card and forgets the guest.
------------------------------------------------------------------
local function closeCard()
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil -- let go of the controller's selection
	end
	gui.Enabled = false
	currentGuest = nil
	selectedRoom = nil
	waitingForReply = false
end

------------------------------------------------------------------
-- FUNCTION: openCard
-- Fills the card in with a guest's information and shows it.
--   guestModel  the guest's character in the world
--   info        a table from the server: name, day, clues, rooms
------------------------------------------------------------------
local function openCard(guestModel, info)
	currentGuest = guestModel
	selectedRoom = nil
	waitingForReply = false
	status.Text = ""

	title.Text = info.name
	subtitle.Text = "Arrived on day " .. info.day

	-- Remove the old clues and room buttons (the layout objects stay)
	for _, child in ipairs(clueList:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for _, child in ipairs(roomGrid:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	roomButtons = {}

	-- One line of text per clue. ipairs walks the list in order, and i is
	-- the position (1, 2, 3 ...), which sets the order they stack in.
	for i, clue in ipairs(info.clues) do
		make("TextLabel", {
			LayoutOrder = i,
			Size = UDim2.new(1, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, -- grows tall enough for the wrapped text
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 15,
			TextColor3 = COLORS.Cream,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "•  " .. clue,
		}, clueList)
	end

	-- One button per room. Taken rooms are greyed out and can't be picked.
	for i, room in ipairs(info.rooms) do
		local button = make("TextButton", {
			LayoutOrder = i,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			Text = tostring(room.number),
			AutoButtonColor = not room.occupied,
		}, roomGrid)
		make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
		button:SetAttribute("Occupied", room.occupied)
		roomButtons[room.number] = button

		-- Activated fires on a click or a tap. Taken rooms ignore it.
		button.Activated:Connect(function()
			if room.occupied or waitingForReply then
				return
			end
			selectedRoom = room.number
			status.Text = ""
			refreshButtons()
			if usingGamepad() then
				GuiService.SelectedObject = checkInButton -- jump straight to the Check in button
			end
		end)
	end

	refreshButtons()
	gui.Enabled = true

	-- With a controller, start with the first free room selected so the
	-- D-pad and A button work straight away
	if usingGamepad() then
		for _, room in ipairs(info.rooms) do
			if not room.occupied then
				GuiService.SelectedObject = roomButtons[room.number]
				break
			end
		end
	end
end

------------------------------------------------------------------
-- BUTTONS
------------------------------------------------------------------
closeButton.Activated:Connect(closeCard)

checkInButton.Activated:Connect(function()
	if not currentGuest or not selectedRoom or waitingForReply then
		return -- nothing to do yet
	end
	waitingForReply = true
	status.Text = "Checking in..."
	-- Ask the server. It decides whether it's allowed, and answers on CheckInResult.
	requestCheckIn:FireServer(currentGuest, selectedRoom)
end)

-- B on the controller (circle on PlayStation) closes the card.
-- InputBegan fires for every key or button the player presses.
UserInputService.InputBegan:Connect(function(input)
	if currentGuest and input.KeyCode == Enum.KeyCode.ButtonB then
		closeCard()
	end
end)

------------------------------------------------------------------
-- MESSAGES FROM THE SERVER
------------------------------------------------------------------

-- The server says "open the card for this guest". OnClientEvent runs our
-- function when the message arrives.
showGuestCard.OnClientEvent:Connect(openCard)

-- The server's answer to a check-in. `success` is true or false.
-- A success message goes to every player, so anyone looking at this
-- guest's card sees it close. A failure goes only to the player who asked.
checkInResult.OnClientEvent:Connect(function(guestModel, success, message)
	if guestModel ~= currentGuest then
		return -- this isn't about the guest we're looking at
	end
	if success then
		closeCard()
	else
		waitingForReply = false
		status.Text = message
	end
end)

------------------------------------------------------------------
-- HOUSEKEEPING
-- Close the card if the guest disappears (they leave at nightfall) or
-- if the player walks away. Check four times a second, which is plenty.
------------------------------------------------------------------
local sinceCheck = 0
RunService.Heartbeat:Connect(function(deltaTime)
	sinceCheck = sinceCheck + deltaTime
	if sinceCheck < 0.25 then
		return
	end
	sinceCheck = 0

	if not currentGuest then
		return
	end
	if not currentGuest:IsDescendantOf(workspace) then
		closeCard() -- the guest has left
		return
	end

	local character = player.Character
	local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
	local guestRoot = currentGuest:FindFirstChild("HumanoidRootPart")
	if playerRoot and guestRoot and (playerRoot.Position - guestRoot.Position).Magnitude > CLOSE_DISTANCE then
		closeCard()
	end
end)

-- Keep the card's size right if the window is resized
local camera = workspace.CurrentCamera
if camera then
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end
