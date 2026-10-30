-- The pets a player owns and the ones they keep in their pen (QM, Oct 25: the Backpack,
-- client/Backpack). Player attributes, saved by Server/Data:
--   PetsOwned  every pet owned, with how many of each (Shared/Stacks: "Pig:3,Unicorn")
--   PenPets    the ones equipped, comma separated ("Pig,Pig,Unicorn"), at most
--              Config.Backpack.PenSlots; each one wanders in their pen (Pens.setPets)
--   Pet        the one they ride (QM, Oct 27: the pet you ride IS one of your pen's
--              pets, you just choose to ride it). Always one of PenPets: it's out of the
--              pen while ridden (one copy, if there are more) but still pays its Cash.
--              Unequip it and they ride another pen pet; the pen is never left empty.
-- A new player (owning no pets) is given Config.Backpack.Starter to ride.
-- The client asks through the PetEquip remote: ("equip", kind), ("unequip", slot),
-- ("best") for the pets earning the most cash a second, or ("ride", kind): ride that
-- pet (client/PenRide's Ride prompt in the pen; one not in the pen goes in, swapped for
-- the one ridden if the pen's full).
-- The pen's pets pay their Cash a second (Config.Income, x the rebirth bonus): the
-- game's main income. Player attribute Income is that rate, for the HUD.
--
--   PetInventory.start()               -- once, after Pens.start
--   PetInventory.give(player, kind, n) -- n more of it (1 if nil), into the pen if there's room
--   PetInventory.ride(player, kind)    -- ride that pet they own (see "ride" above); false if they don't

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

-- true when it went into the pen, false when the pen was full (storage)
function PetInventory.give(player, kind, n)
	if not isPet(kind) then
		return
	end
	player:SetAttribute("PetsOwned", Stacks.format(Stacks.add(PetInventory.owned(player), kind, n or 1)))
	local list = PetInventory.equipped(player)
	if #list < slots() then
		table.insert(list, kind)
		setEquipped(player, list)
		return true
	end
	return false -- (pen full: it's owned, in storage)
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

function PetInventory.ride(player, kind)
	-- (not mid-fight: a fresh mount would be a free heal)
	if not isPet(kind) or Stacks.count(PetInventory.owned(player), kind) == 0 or player:GetAttribute("LockedIn") then
		return false
	end
	local list = PetInventory.equipped(player)
	if not table.find(list, kind) then
		if #list >= slots() then
			-- (a full pen: it takes the place of the one ridden)
			local at = table.find(list, player:GetAttribute("Pet")) or #list
			list[at] = kind
		else
			table.insert(list, kind)
		end
		setEquipped(player, list)
	end
	player:SetAttribute("Pet", kind)
	return true
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
	local list = table.move(all, 1, math.min(#all, slots()), 1, {})
	-- (mid-fight the one ridden stays: a fresh mount would be a free heal, see ride)
	local ridden = player:GetAttribute("Pet")
	if player:GetAttribute("LockedIn") and ridden and not table.find(list, ridden) and #list > 0 then
		list[#list] = ridden
	end
	setEquipped(player, list)
end

-- cash a second from the pen's pets (Config.Income)
function PetInventory.income(player)
	local total = 0
	for _, kind in PetInventory.equipped(player) do
		total += Config.Pets[kind].Cash or 0
	end
	return total * (1 + Config.Rebirth.CashBonus * (player:GetAttribute("Rebirths") or 0))
end

local function pay()
	local carry = {} -- [player] = cash under 1 left over (rebirth bonuses aren't whole)
	while true do
		local every = Config.Income.Every
		task.wait(every)
		for _, player in Players:GetPlayers() do
			local rate = PetInventory.income(player)
			if player:GetAttribute("Income") ~= rate then
				player:SetAttribute("Income", rate)
			end
			local due = rate * every + (carry[player] or 0)
			local whole = math.floor(due)
			carry[player] = due - whole
			if whole > 0 then
				player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + whole)
			end
		end
		for player in carry do
			if player.Parent == nil then
				carry[player] = nil
			end
		end
	end
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
		elseif action == "ride" and type(arg) == "string" then
			PetInventory.ride(player, arg)
		end
	end)

	local function joined(player)
		local function show()
			local owned = PetInventory.owned(player)
			if #owned == 0 then
				-- (a new player: their starter, which comes back round here)
				player:SetAttribute("Pet", Config.Backpack.Starter)
				PetInventory.give(player, Config.Backpack.Starter)
				return
			end
			-- (tidied first: a save holding a pet that's gone, or one too many, loses it)
			local list = PetInventory.equipped(player)
			local ridden = player:GetAttribute("Pet")
			if not table.find(list, ridden) then
				if #list > 0 then
					ridden = list[1]
				else
					-- (an empty pen: the one they rode goes back in, if they still own it)
					if Stacks.count(owned, ridden) == 0 then
						ridden = owned[1].id
					end
					table.insert(list, ridden)
				end
			end
			setEquipped(player, list)
			if player:GetAttribute("Pet") ~= ridden then
				player:SetAttribute("Pet", ridden)
			end
			-- (the one ridden is under them, not in the pen)
			local wandering = table.clone(list)
			table.remove(wandering, table.find(wandering, ridden))
			Pens.setPets(player, wandering)
		end
		player:GetAttributeChangedSignal("PetsOwned"):Connect(show)
		player:GetAttributeChangedSignal("PenPets"):Connect(show)
		player:GetAttributeChangedSignal("Pen"):Connect(show)
		player:GetAttributeChangedSignal("Pet"):Connect(show)
		show()
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	task.spawn(pay)
end

return PetInventory
