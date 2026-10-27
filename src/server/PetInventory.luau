-- The pets a player owns and the ones they keep in their pen (QM, Oct 25: the Backpack,
-- client/Backpack). Player attributes, saved by Server/Data:
--   PetsOwned  every pet owned, with how many of each (Shared/Stacks: "Pig:3,Unicorn")
--   PenPets    the ones equipped, comma separated ("Pig,Pig,Unicorn"), at most
--              Config.Backpack.PenSlots; each one wanders in their pen (Pens.setPets)
-- The client asks through the PetEquip remote: ("equip", kind), ("unequip", slot) or
-- ("best") for the pets earning the most cash a second.
--
--   PetInventory.start()               -- once, after Pens.start
--   PetInventory.give(player, kind, n) -- n more of it (1 if nil), into the pen if there's room

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stacks = require(Shared.Stacks)
local Pens = require(script.Parent.Pens)

local PetInventory = {}

local function isPet(kind)
	return Config.Pets[kind] ~= nil
end

local function slots()
	return Config.Backpack.PenSlots
end

function PetInventory.owned(player)
	return Stacks.parse(player:GetAttribute("PetsOwned"), isPet)
end

-- the pen's pets, only ones they own (never more of a kind than they have), at most PenSlots
function PetInventory.equipped(player)
	local owned = PetInventory.owned(player)
	local used, list = {}, {}
	for kind in string.gmatch(player:GetAttribute("PenPets") or "", "[^,]+") do
		if #list < slots() and (used[kind] or 0) < Stacks.count(owned, kind) then
			used[kind] = (used[kind] or 0) + 1
			table.insert(list, kind)
		end
	end
	return list
end

local function setEquipped(player, list)
	local text = table.concat(list, ",")
	if player:GetAttribute("PenPets") ~= text then
		player:SetAttribute("PenPets", text)
	end
end

function PetInventory.give(player, kind, n)
	if not isPet(kind) then
		return
	end
	player:SetAttribute("PetsOwned", Stacks.format(Stacks.add(PetInventory.owned(player), kind, n or 1)))
	local list = PetInventory.equipped(player)
	if #list < slots() then
		table.insert(list, kind)
		setEquipped(player, list)
	end
end

local function equip(player, kind)
	local list = PetInventory.equipped(player)
	if not isPet(kind) or #list >= slots() then
		return
	end
	local used = 0
	for _, k in list do
		if k == kind then
			used += 1
		end
	end
	if used < Stacks.count(PetInventory.owned(player), kind) then
		table.insert(list, kind)
		setEquipped(player, list)
	end
end

local function unequip(player, slot)
	local list = PetInventory.equipped(player)
	if type(slot) == "number" and list[slot] then
		table.remove(list, slot)
		setEquipped(player, list)
	end
end

-- the pets earning the most cash a second, one per owned copy, rarest first on a tie
local RANK = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6,
	Divine = 7, Celestial = 8, Cosmic = 9, Void = 10, Omega = 11,
}
local function best(player)
	local all = {}
	for _, s in PetInventory.owned(player) do
		for _ = 1, s.n do
			table.insert(all, s.id)
		end
	end
	table.sort(all, function(a, b)
		local pa, pb = Config.Pets[a], Config.Pets[b]
		if (pa.Cash or 0) ~= (pb.Cash or 0) then
			return (pa.Cash or 0) > (pb.Cash or 0)
		end
		if (RANK[pa.Rarity] or 0) ~= (RANK[pb.Rarity] or 0) then
			return (RANK[pa.Rarity] or 0) > (RANK[pb.Rarity] or 0)
		end
		return a < b
	end)
	setEquipped(player, table.move(all, 1, math.min(#all, slots()), 1, {}))
end

function PetInventory.start()
	local remote = Instance.new("RemoteEvent")
	remote.Name = "PetEquip"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, arg)
		if action == "equip" and type(arg) == "string" then
			equip(player, arg)
		elseif action == "unequip" then
			unequip(player, arg)
		elseif action == "best" then
			best(player)
		end
	end)

	local function joined(player)
		local function show()
			-- (tidied first: a save holding a pet that's gone, or one too many, loses it)
			local list = PetInventory.equipped(player)
			setEquipped(player, list)
			Pens.setPets(player, list)
		end
		player:GetAttributeChangedSignal("PetsOwned"):Connect(show)
		player:GetAttributeChangedSignal("PenPets"):Connect(show)
		player:GetAttributeChangedSignal("Pen"):Connect(show)
		show()
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return PetInventory
