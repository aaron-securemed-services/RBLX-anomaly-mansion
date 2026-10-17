-- CandleFlicker
-- Makes every light tagged "CandleLight" flicker like a real flame.
-- The Castle Builder adds the tag to every candle and chandelier.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local lights = {} -- light -> { base brightness, random offset }

local function add(light)
	lights[light] = { base = light.Brightness, seed = math.random() * 100 }
end
for _, light in ipairs(CollectionService:GetTagged("CandleLight")) do
	add(light)
end
CollectionService:GetInstanceAddedSignal("CandleLight"):Connect(add)
CollectionService:GetInstanceRemovedSignal("CandleLight"):Connect(function(light)
	lights[light] = nil
end)

local clock, sinceUpdate = 0, 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	sinceUpdate += dt
	if sinceUpdate < 1 / 20 then return end -- update 20 times a second, plenty for a flicker
	sinceUpdate = 0
	for light, info in pairs(lights) do
		-- math.noise gives a smooth random wobble between about -0.5 and 0.5
		local wobble = math.noise(clock * 4, info.seed)
		light.Brightness = info.base * (0.85 + wobble * 0.35)
	end
end)
