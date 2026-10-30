-- The knobs for every stud Texture in the game (QM, Oct 30): workspace.StudStyle, a
-- Configuration with these attributes, the ground (everything under workspace.Map.Floor)
-- and everything else apart:
--   GroundTransparency, Transparency   0 = full studs, 1 = none
--   GroundTileScale, TileScale         how big the studs are: 1 = as built, 2 = twice as big
-- Change them in the Properties panel in Edit mode (the Map Baker plugin repaints the
-- place) or during Play (server or client view): every stud Texture follows at once, and
-- new ones (pets, eggs, weapons) take them too. They're kept with the place, like
-- FightBarrierStyle, so your values win over Config.StudStyle, which only seeds a place
-- that has none.
-- A Texture's StudScale attribute is the tile scale it wears now (none = 1), so it's
-- rescaled from what it is, however it was built or scaled since.
--
--   StudStyle.transparency()  -- everything-else value, for whatever makes a stud Texture
--   StudStyle.ensure()        -- server, once: makes workspace.StudStyle and its knobs
--   StudStyle.watch()         -- server and client, once: applies them, live
--   StudStyle.applyAll()      -- (the Map Baker plugin, in Edit mode)

local StudStyle = {}

StudStyle.NAME = "StudStyle"
StudStyle.IMAGE = "rbxassetid://7447638591" -- the classic stud decal every stud Texture uses
StudStyle.KNOBS = { "GroundTransparency", "GroundTileScale", "Transparency", "TileScale" }

local DEFAULTS = { GroundTransparency = 0.5, GroundTileScale = 1, Transparency = 0.4, TileScale = 2 }

-- (Config.StudStyle's value for a knob, as a place with none starts)
local seeds = nil
local function seed(name)
	if not seeds then
		local module = script.Parent and script.Parent:FindFirstChild("Config")
		local ok, config = pcall(require, module)
		seeds = if ok and type(config) == "table" and type(config.StudStyle) == "table" then config.StudStyle else {}
	end
	local value = seeds[name]
	return if type(value) == "number" then value else DEFAULTS[name]
end

local function style()
	return workspace:FindFirstChild(StudStyle.NAME)
end

local function knob(name, default)
	local s = style()
	local value = s and s:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

function StudStyle.transparency()
	return knob("Transparency", seed("Transparency"))
end

function StudStyle.ensure()
	local s = style()
	if not s then
		s = Instance.new("Configuration")
		s.Name = StudStyle.NAME
		s.Parent = workspace
	end
	for _, name in StudStyle.KNOBS do
		if typeof(s:GetAttribute(name)) ~= "number" then
			s:SetAttribute(name, seed(name))
		end
	end
	return s
end

local function isStud(thing)
	return thing:IsA("Texture") and thing.Texture == StudStyle.IMAGE
end

local function isGround(texture)
	local map = workspace:FindFirstChild("Map")
	local floor = map and map:FindFirstChild("Floor")
	return floor ~= nil and texture:IsDescendantOf(floor)
end

-- (as Server/Map lines them up with the world grid, so neighbouring parts' studs meet)
local function realign(texture, part, tile)
	if not part.CFrame.Rotation:FuzzyEq(CFrame.identity) then
		return false
	end
	local face = texture.Face
	if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		local far = part.Position + part.Size / 2
		texture.OffsetStudsU, texture.OffsetStudsV = -far.X % tile, -far.Z % tile
	else
		local corner = part.Position - part.Size / 2
		local u = if face == Enum.NormalId.Front or face == Enum.NormalId.Back then corner.X else corner.Z
		texture.OffsetStudsU, texture.OffsetStudsV = u % tile, corner.Y % tile
	end
	return true
end

function StudStyle.apply(texture, ground)
	if ground == nil then
		ground = isGround(texture)
	end
	texture.Transparency = if ground then knob("GroundTransparency", seed("GroundTransparency")) else StudStyle.transparency()
	local want = math.max(knob(if ground then "GroundTileScale" else "TileScale", seed(if ground then "GroundTileScale" else "TileScale")), 0.01)
	local have = texture:GetAttribute("StudScale")
	have = if typeof(have) == "number" and have > 0 then have else 1
	if math.abs(want - have) < 1e-6 then
		return
	end
	local k = want / have
	texture.StudsPerTileU *= k
	texture.StudsPerTileV *= k
	texture:SetAttribute("StudScale", if math.abs(want - 1) < 1e-6 then nil else want)
	local part = texture.Parent
	local map = workspace:FindFirstChild("Map")
	if not (part and part:IsA("BasePart") and map and part:IsDescendantOf(map) and realign(texture, part, texture.StudsPerTileU)) then
		texture.OffsetStudsU *= k
		texture.OffsetStudsV *= k
	end
end

function StudStyle.applyAll()
	local map = workspace:FindFirstChild("Map")
	local floor = map and map:FindFirstChild("Floor")
	for _, thing in workspace:GetDescendants() do
		if isStud(thing) then
			StudStyle.apply(thing, floor ~= nil and thing:IsDescendantOf(floor))
		end
	end
end

function StudStyle.watch()
	local s = workspace:WaitForChild(StudStyle.NAME, 30)
	if not s then
		return
	end
	StudStyle.applyAll()
	s.AttributeChanged:Connect(function(name)
		if table.find(StudStyle.KNOBS, name) then
			StudStyle.applyAll()
		end
	end)
	-- (anything made later, or before the knobs reached this side)
	workspace.DescendantAdded:Connect(function(thing)
		if isStud(thing) then
			StudStyle.apply(thing)
		end
	end)
end

return StudStyle
