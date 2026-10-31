-- The sky's colour per biome (QM, Oct 31): workspace.SkyColor, a Configuration with a
-- Color3 attribute per area (Base, Meadow, Desert, Ice, Lava, Dungeon, Castle, Forest =
-- the Magic Forest, Ocean) and TweenTime, the seconds it takes to blend into the next.
-- The sky you see is the fog (Lighting.FogStart = FogEnd, so everything past it, the
-- skybox too, is FogColor), so on the client Lighting.FogColor tweens to the colour of
-- the area you're standing in: a biome's Bounds, or a training ground's (its biome's
-- colour), Base north of the Meadow; in the corridors between areas it keeps the last.
-- Change them in the Properties panel, in Edit mode to keep them or during Play to try
-- them out; they're kept with the place, so your values win over Config.SkyColor, which
-- only seeds a place that has none.
--
--   SkyColor.ensure()  -- server, once: makes workspace.SkyColor and its colours
--   SkyColor.watch()   -- client, once: follows you round the map

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local SkyColor = {}

SkyColor.NAME = "SkyColor"

local DEFAULT = Color3.fromRGB(71, 125, 166) -- (QM's steel blue fog, Oct 24)

local seeds = nil
local function config()
	if not seeds then
		local module = script.Parent and script.Parent:FindFirstChild("Config")
		local ok, c = pcall(require, module)
		seeds = if ok and type(c) == "table" and type(c.SkyColor) == "table" then c.SkyColor else {}
	end
	return seeds
end

local function style()
	return workspace:FindFirstChild(SkyColor.NAME)
end

local function colourOf(name)
	local s = style()
	local value = s and s:GetAttribute(name)
	if typeof(value) == "Color3" then
		return value
	end
	local seed = config()[name]
	return if typeof(seed) == "Color3" then seed else config().Base or DEFAULT
end

local function tweenTime()
	local s = style()
	local value = s and s:GetAttribute("TweenTime")
	if typeof(value) == "number" then
		return math.max(value, 0)
	end
	return if type(config().TweenTime) == "number" then config().TweenTime else 1.5
end

function SkyColor.ensure()
	local s = style()
	if not s then
		s = Instance.new("Configuration")
		s.Name = SkyColor.NAME
		s.Parent = workspace
	end
	for name, value in config() do
		if s:GetAttribute(name) == nil then
			s:SetAttribute(name, value)
		end
	end
	return s
end

-- each area as { name, x0, z0, x1, z1 }: the biomes and the training grounds
local boxes = nil
local meadowNorth = nil
local function areas()
	if boxes then
		return boxes
	end
	boxes = {}
	local MapData = require(script.Parent.MapData)
	for _, area in MapData.Areas do
		local b = area.Bounds
		if b then
			table.insert(boxes, { area.Name, math.min(b[1], b[3]), math.min(b[2], b[4]), math.max(b[1], b[3]), math.max(b[2], b[4]) })
			if area.Name == "Meadow" then
				meadowNorth = math.max(b[2], b[4])
			end
		end
		for _, t in area.Training or {} do
			table.insert(boxes, { t[1], math.min(t[2], t[4]), math.min(t[3], t[5]), math.max(t[2], t[4]), math.max(t[3], t[5]) })
		end
	end
	return boxes
end

local function areaAt(p)
	for _, box in areas() do
		if p.X >= box[2] and p.X <= box[4] and p.Z >= box[3] and p.Z <= box[5] then
			return box[1]
		end
	end
	if meadowNorth and p.Z > meadowNorth then
		return "Base"
	end
	return nil
end

function SkyColor.watch()
	local player = Players.LocalPlayer
	local current = "Base"
	local tween = nil
	local function blend(instant)
		if tween then
			tween:Cancel()
		end
		local goal = colourOf(current)
		local t = if instant then 0 else tweenTime()
		if t <= 0 then
			Lighting.FogColor = goal
			return
		end
		tween = TweenService:Create(Lighting, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FogColor = goal })
		tween:Play()
	end
	task.spawn(function()
		local s = workspace:WaitForChild(SkyColor.NAME, 30)
		if s then
			s.AttributeChanged:Connect(function()
				blend(false)
			end)
		end
	end)
	blend(true)
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local name = root and areaAt(root.Position)
		if name and name ~= current then
			current = name
			blend(false)
		end
		task.wait(0.25)
	end
end

return SkyColor
