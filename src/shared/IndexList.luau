-- The Index's pets (QM, Oct 30; Config.Index): which pets each biome's section shows and
-- what finding each one pays. Server/PetIndex and client/IndexPanel both use it.
--
--   IndexList.biome(name) -> its pets, commonest first (by rarity, then cash a second)
--   IndexList.all()       -> every pet in the Index, biome by biome
--   IndexList.rank(rarity) -> 1 for Common, 2 for Uncommon ...
--   IndexList.reward(kind) -> cash, power for claiming it

local Config = require(script.Parent.Config)

local IndexList = {}

local RANKS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Celestial", "Cosmic", "Void", "Omega" }
local rank = {}
for i, r in RANKS do
	rank[r] = i
end

function IndexList.rank(rarity)
	return rank[rarity] or 1
end

local cache = {}
function IndexList.biome(name)
	if cache[name] then
		return cache[name]
	end
	local list, seen = {}, {}
	local function add(kind)
		if Config.Pets[kind] and not seen[kind] then
			seen[kind] = true
			table.insert(list, kind)
		end
	end
	for _, kind in (Config.Index.Extra[name] or {}) do
		add(kind)
	end
	for kind in (Config.Eggs.Kinds[name] or {}) do
		add(kind)
	end
	table.sort(list, function(a, b)
		local pa, pb = Config.Pets[a], Config.Pets[b]
		local ra, rb = IndexList.rank(pa.Rarity), IndexList.rank(pb.Rarity)
		if ra ~= rb then
			return ra < rb
		end
		if (pa.Cash or 0) ~= (pb.Cash or 0) then
			return (pa.Cash or 0) < (pb.Cash or 0)
		end
		return a < b
	end)
	cache[name] = list
	return list
end

function IndexList.all()
	local out = {}
	for _, name in Config.Index.Order do
		for _, kind in IndexList.biome(name) do
			table.insert(out, kind)
		end
	end
	return out
end

function IndexList.reward(kind)
	local pet = Config.Pets[kind] or {}
	local cash = math.floor((pet.Cash or 0) * Config.Index.CashSeconds)
	local power = Config.Index.Power[pet.Rarity or "Common"] or 0
	return cash, power
end

return IndexList
