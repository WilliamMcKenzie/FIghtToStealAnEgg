-- Every pet's size (QM, Oct 31): workspace.PetScale, a Configuration with a number
-- attribute per pet (Config.Pets' kinds), how much bigger than its own size it's drawn:
-- 1 is its tier's size (LassoAPet's), 2 twice that. Change them in the Properties panel
-- in Edit mode, where the pet lineup in the base (Shared/PetLineup) resizes to match as
-- you type; they're kept with the place, so your values win over Config.AnimalScale,
-- which only seeds a place that has none. Tick CopyValues to print them to the Output
-- as a Config.AnimalScale line, ready to paste into Config.
--
--   PetScale.of(kind)  -> its scale (workspace.PetScale, else Config.AnimalScale, else 1)
--   PetScale.ensure()  -- makes workspace.PetScale and an attribute for every pet
--   PetScale.text()    -> the Config.AnimalScale line for the current values

local PetScale = {}

PetScale.NAME = "PetScale"
PetScale.COPY = "CopyValues" -- (the tick box that prints them)

local Config = require(script.Parent.Config)

local function style()
	return workspace:FindFirstChild(PetScale.NAME)
end

function PetScale.of(kind)
	local s = style()
	local value = s and s:GetAttribute(kind)
	if type(value) == "number" and value > 0 then
		return value
	end
	return Config.AnimalScale[kind] or 1
end

function PetScale.ensure()
	local s = style()
	if not s then
		s = Instance.new("Configuration")
		s.Name = PetScale.NAME
		s.Parent = workspace
	end
	for kind in Config.Pets do
		if s:GetAttribute(kind) == nil then
			s:SetAttribute(kind, Config.AnimalScale[kind] or 1)
		end
	end
	if s:GetAttribute(PetScale.COPY) == nil then
		s:SetAttribute(PetScale.COPY, false)
	end
	return s
end

function PetScale.text()
	local kinds = {}
	for kind in Config.Pets do
		if math.abs(PetScale.of(kind) - 1) > 1e-4 then
			table.insert(kinds, kind)
		end
	end
	table.sort(kinds)
	local entries = {}
	for _, kind in kinds do
		table.insert(entries, string.format("%s = %s", kind, tostring(math.round(PetScale.of(kind) * 1000) / 1000)))
	end
	return "\tAnimalScale = { " .. table.concat(entries, ", ") .. " }, -- (workspace.PetScale)"
end

return PetScale
