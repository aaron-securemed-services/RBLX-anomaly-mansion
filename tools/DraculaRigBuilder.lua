--[[
=======================================================================
  DRACULA RIG BUILDER  -  Dracula's BnB
=======================================================================
  Turns the imported Dracula_Rig.glb (6 body pieces + joint markers)
  into a walking, animated R15 character.

  Each visible piece (head, torso + cape, arms, legs) moves as one
  solid block, like a classic blocky Roblox avatar, so the cape always
  stays with his body and never sticks to his arms.

  HOW TO USE
    1. Stop Play mode.
    2. Import 3D -> Dracula_Rig.glb -> Import.
    3. Click the imported model once so it's selected.
    4. Paste this whole file into the Command Bar and click Run.

  Result: Workspace > NPCs > Dracula, standing in the Crypt in front
  of his coffin, breathing (idle animation). While DEMO_PACING is on
  he paces back and forth so you can see him walk; your GameManager
  can take over his movement later.
=======================================================================
]]

local TARGET_HEIGHT = 8     -- studs, head to toe (a player is about 5.5)
local PLACE_IN_CRYPT = true -- stand him in front of his coffin
local DEMO_PACING = true    -- walk back and forth so you can test the animation
local WALK_SPEED = 8        -- slow and menacing (players walk at 16)

------------------------------------------------------------------------
-- 1. FIND THE IMPORTED PIECES
------------------------------------------------------------------------
local Selection = game:GetService("Selection")
local src = Selection:Get()[1]
if not src then
	error("Click the imported Dracula_Rig model first, then run this again")
end

-- finds the piece whose name contains "DR_<tag>"
local function piece(tag)
	local want = "DR_" .. tag
	local candidates = src:GetDescendants()
	table.insert(candidates, src)
	for _, d in ipairs(candidates) do
		if d:IsA("BasePart") then
			local n = d.Name
			-- match "DR_Head", "DR_Head.001", but not "DR_HeadSomethingElse"
			if n == want or string.sub(n, 1, #want + 1) == want .. "." or string.sub(n, 1, #want + 1) == want .. "_" then
				return d
			end
		end
	end
	error("Couldn't find " .. want .. " inside the selected model. Did you select the imported Dracula_Rig?")
end

local BODY = {
	Head = piece("Head"), Torso = piece("Torso"),
	LeftArm = piece("LeftArm"), RightArm = piece("RightArm"),
	LeftLeg = piece("LeftLeg"), RightLeg = piece("RightLeg"),
}
local MARK_NAMES = {
	"J_Neck", "J_Root", "M_Front", "M_Floor",
	"J_LeftShoulder", "J_LeftElbow", "J_LeftWrist", "J_RightShoulder", "J_RightElbow", "J_RightWrist",
	"J_LeftHip", "J_LeftKnee", "J_LeftAnkle", "J_RightHip", "J_RightKnee", "J_RightAnkle",
}
local MARK = {}
for _, n in ipairs(MARK_NAMES) do
	MARK[n] = piece(n)
end
local function at(n) return MARK[n].Position end

------------------------------------------------------------------------
-- 2. STAND HIM UPRIGHT, FACING -Z (Roblox's "forward")
-- The markers tell us where his head, hips and face are, so this works
-- no matter which way the importer turned him.
------------------------------------------------------------------------
local everything = {}
for _, p in pairs(BODY) do table.insert(everything, p) end
for _, p in pairs(MARK) do table.insert(everything, p) end

local up = (at("J_Neck") - at("J_Root")).Unit
local toFront = at("M_Front") - at("J_Neck")
local forward = (toFront - up * toFront:Dot(up)).Unit
local right = forward:Cross(up)
local now = CFrame.fromMatrix(at("J_Root"), right, up, -forward)
local fix = CFrame.new(at("J_Root")) * now:Inverse()
for _, p in ipairs(everything) do
	p.CFrame = fix * p.CFrame
end

------------------------------------------------------------------------
-- 3. RESIZE TO TARGET_HEIGHT
------------------------------------------------------------------------
local function topOf(p)
	local top = -math.huge
	for _, sx in ipairs({ -0.5, 0.5 }) do
		for _, sy in ipairs({ -0.5, 0.5 }) do
			for _, sz in ipairs({ -0.5, 0.5 }) do
				local c = p.CFrame * Vector3.new(sx * p.Size.X, sy * p.Size.Y, sz * p.Size.Z)
				top = math.max(top, c.Y)
			end
		end
	end
	return top
end
local floorY = at("M_Floor").Y
local scale = TARGET_HEIGHT / (topOf(BODY.Head) - floorY)
local pivot = at("J_Root")
for _, p in ipairs(everything) do
	local rotation = p.CFrame - p.Position
	p.Size = p.Size * scale
	p.CFrame = CFrame.new(pivot + (p.Position - pivot) * scale) * rotation
end
floorY = at("M_Floor").Y

------------------------------------------------------------------------
-- 4. BUILD THE R15 CHARACTER
------------------------------------------------------------------------
local npcs = workspace:FindFirstChild("NPCs") or Instance.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = workspace
local old = npcs:FindFirstChild("Dracula")
if old then old:Destroy() end

local rig = Instance.new("Model")
rig.Name = "Dracula"

-- the visible pieces: R15 names, so Roblox's animations know what to move
local function visible(p, name)
	p.Name = name
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.Parent = rig
	return p
end
local head = visible(BODY.Head, "Head")
local upperTorso = visible(BODY.Torso, "UpperTorso")
local rUpperArm = visible(BODY.RightArm, "RightUpperArm")
local lUpperArm = visible(BODY.LeftArm, "LeftUpperArm")
local rUpperLeg = visible(BODY.RightLeg, "RightUpperLeg")
local lUpperLeg = visible(BODY.LeftLeg, "LeftUpperLeg")

-- invisible helper pieces: R15 needs 15 parts, but a blocky body only shows 6
local function hidden(name, pos)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(pos)
	p.Transparency = 1
	p.CanCollide = false
	p.Massless = true
	p.Parent = rig
	return p
end
local lowerTorso = hidden("LowerTorso", at("J_Root"))
local rLowerArm = hidden("RightLowerArm", at("J_RightElbow"))
local rHand = hidden("RightHand", at("J_RightWrist"))
local lLowerArm = hidden("LeftLowerArm", at("J_LeftElbow"))
local lHand = hidden("LeftHand", at("J_LeftWrist"))
local rLowerLeg = hidden("RightLowerLeg", at("J_RightKnee"))
local rFoot = hidden("RightFoot", at("J_RightAnkle"))
local lLowerLeg = hidden("LeftLowerLeg", at("J_LeftKnee"))
local lFoot = hidden("LeftFoot", at("J_LeftAnkle"))

-- the root part Roblox moves around; everything else hangs off it
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1) * (TARGET_HEIGHT / 5.5)
hrp.CFrame = CFrame.new(at("J_Root"))
hrp.Transparency = 1
hrp.CanCollide = true
hrp.Parent = rig

-- a joint between two pieces at a point (R15 joints use straight, unrotated frames)
local function joint(name, part0, part1, pos)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	local frame = CFrame.new(pos)
	m.C0 = part0.CFrame:ToObjectSpace(frame)
	m.C1 = part1.CFrame:ToObjectSpace(frame)
	m.Parent = part1
end
joint("Root", hrp, lowerTorso, at("J_Root"))
joint("Waist", lowerTorso, upperTorso, at("J_Root"))
joint("Neck", upperTorso, head, at("J_Neck"))
joint("RightShoulder", upperTorso, rUpperArm, at("J_RightShoulder"))
joint("RightElbow", rUpperArm, rLowerArm, at("J_RightElbow"))
joint("RightWrist", rLowerArm, rHand, at("J_RightWrist"))
joint("LeftShoulder", upperTorso, lUpperArm, at("J_LeftShoulder"))
joint("LeftElbow", lUpperArm, lLowerArm, at("J_LeftElbow"))
joint("LeftWrist", lLowerArm, lHand, at("J_LeftWrist"))
joint("RightHip", lowerTorso, rUpperLeg, at("J_RightHip"))
joint("RightKnee", rUpperLeg, rLowerLeg, at("J_RightKnee"))
joint("RightAnkle", rLowerLeg, rFoot, at("J_RightAnkle"))
joint("LeftHip", lowerTorso, lUpperLeg, at("J_LeftHip"))
joint("LeftKnee", lUpperLeg, lLowerLeg, at("J_LeftKnee"))
joint("LeftAnkle", lLowerLeg, lFoot, at("J_LeftAnkle"))

local humanoid = Instance.new("Humanoid")
humanoid.RigType = Enum.HumanoidRigType.R15
humanoid.AutomaticScalingEnabled = false
humanoid.HipHeight = (hrp.Position.Y - hrp.Size.Y / 2) - floorY -- keeps his feet on the floor
humanoid.WalkSpeed = WALK_SPEED
humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
humanoid.Parent = rig
local animator = Instance.new("Animator")
animator.Parent = humanoid
rig.PrimaryPart = hrp
rig:SetAttribute("NPC", "Dracula")

-- the markers and the empty imported model aren't needed any more
for _, p in pairs(MARK) do p:Destroy() end
if src.Parent then src:Destroy() end

------------------------------------------------------------------------
-- 5. ANIMATIONS (Roblox's standard R15 idle / walk / run)
------------------------------------------------------------------------
local animate = Instance.new("Script")
animate.Name = "DraculaAnimate"
animate.Source = string.format([==[
-- DraculaAnimate
-- Plays Roblox's standard R15 animations on Dracula: idle when he stands
-- still, walk or run when he moves. Built by tools/DraculaRigBuilder.lua.
local DEMO_PACING = %s -- walk back and forth to show off the animation

local ANIMS = {
	idle = "rbxassetid://507766666",
	walk = "rbxassetid://507777826",
	run = "rbxassetid://507767714",
}

local rig = script.Parent
local humanoid = rig:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local tracks = {}
for name, id in pairs(ANIMS) do
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	tracks[name] = animator:LoadAnimation(anim)
	tracks[name].Looped = true
end

local current
local function play(name, speed)
	if current ~= tracks[name] then
		if current then current:Stop(0.25) end
		current = tracks[name]
		current:Play(0.25)
	end
	if speed then current:AdjustSpeed(speed) end
end

humanoid.Running:Connect(function(speed)
	if speed > 12 then
		play("run")
	elseif speed > 0.5 then
		play("walk", speed / 10)
	else
		play("idle")
	end
end)
play("idle")

if DEMO_PACING then
	local root = rig:WaitForChild("HumanoidRootPart")
	local home = root.Position
	local away = home + root.CFrame.LookVector * 10
	while rig.Parent do
		humanoid:MoveTo(away)
		humanoid.MoveToFinished:Wait()
		task.wait(2)
		humanoid:MoveTo(home)
		humanoid.MoveToFinished:Wait()
		task.wait(3)
	end
end
]==], tostring(DEMO_PACING))
animate.Parent = rig

------------------------------------------------------------------------
-- 6. PUT HIM IN THE CRYPT
------------------------------------------------------------------------
rig.Parent = npcs
local castle = workspace:FindFirstChild("DraculaCastle")
local crypt = castle and castle:FindFirstChild("Floor1") and castle.Floor1:FindFirstChild("Crypt")
if PLACE_IN_CRYPT and crypt and crypt:FindFirstChild("Zone") then
	local zone = crypt.Zone
	local rootHeight = hrp.Position.Y - floorY
	local spot, facing
	-- CryptBuilder leaves a "DraculaSpawn" marker (3.5 studs above the floor) in front of the coffin
	local marker = crypt:FindFirstChild("DraculaSpawn", true)
	if marker then
		spot = marker.Position - Vector3.new(0, 3.5, 0)
		local toMiddle = zone.Position - marker.Position
		facing = Vector3.new(toMiddle.X, 0, toMiddle.Z) -- the marker is by the back wall, so this points at the door
	else
		-- no CryptBuilder yet: stand 8 studs from the middle toward the door (+Z)
		spot = Vector3.new(zone.Position.X, zone.Position.Y - zone.Size.Y / 2 + 0.2, zone.Position.Z + 8)
		facing = Vector3.new(0, 0, 1)
	end
	if facing.Magnitude < 0.1 then facing = Vector3.new(0, 0, 1) end
	local base = spot + Vector3.new(0, rootHeight + 0.1, 0)
	rig:PivotTo(CFrame.lookAt(base, base + facing.Unit))
end

Selection:Set({ rig })
print(string.format("Dracula is ready! %.1f studs tall%s. Press Play to see him move.",
	TARGET_HEIGHT, (PLACE_IN_CRYPT and crypt) and ", standing in the Crypt" or ""))
