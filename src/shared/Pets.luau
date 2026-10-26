-- Pets (QM, Oct 25): LassoAPet's animals, each in Config.Pets with its rarity, cash a
-- second and size tier. The pet you ride is all your health and speed (QM): its rarity's
-- (Config.PetStats.Rarity), traded one for the other by its Lean, plus more health the
-- bigger its hitbox. Server and clients both work it out from the same model data.
--
--   Pets.class(kind)  -> its Animals class (Horse.variant), the Horse for an unknown kind
--   Pets.stats(kind)  -> { Kind, Name, Rarity, Cash, Health, Speed, Hitbox }
--   Pets.name(kind)   -> how players see it ("SpineLizard" -> "Spine Lizard")
--   Pets.kinds()      -> every kind in Config.Pets, sorted

local Config = require(script.Parent.Config)
local Animals = script.Parent.Animals
local Horse = require(Animals.Horse)

local Pets = {}

local classes = {}
function Pets.class(kind)
	if classes[kind] == nil then
		local module = Config.Pets[kind] and Animals:FindFirstChild(kind)
		local ok, class = false, nil
		if module then
			ok, class = pcall(require, module)
		end
		classes[kind] = if ok and class then class else false
	end
	return classes[kind] or Horse
end

function Pets.name(kind)
	return (kind:gsub("(%l)(%u)", "%1 %2"))
end

-- half its footprint at the size it's drawn, in studs
local function hitbox(class)
	local d = Horse.extent(class.data) * class.size
	return math.sqrt(d.X * d.Z) / 2
end

local HORSE_HITBOX = hitbox(Horse)
local stats = {}
function Pets.stats(kind)
	kind = if Config.Pets[kind] then kind else "Horse"
	if not stats[kind] then
		local pet = Config.Pets[kind]
		local tune = Config.PetStats
		local base = tune.Rarity[pet.Rarity] or tune.Rarity.Common
		local lean = math.clamp(pet.Lean or 0, -1, 1) * tune.Lean
		local box = hitbox(Pets.class(kind))
		stats[kind] = {
			Kind = kind,
			Name = Pets.name(kind),
			Rarity = pet.Rarity,
			Cash = pet.Cash or 0,
			Health = math.round(base.Health * (1 + lean) * (box / HORSE_HITBOX) ^ tune.Hitbox),
			Speed = math.round((if pet.Speed then tune.MountSpeed * pet.Speed else base.Speed * (1 - lean)) * 10) / 10, -- (LassoAPet's speeds: QM, Oct 26)
			Hitbox = math.round(box * 10) / 10,
		}
	end
	return stats[kind]
end

function Pets.kinds()
	local out = {}
	for kind in Config.Pets do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end

return Pets
