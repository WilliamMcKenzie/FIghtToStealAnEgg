-- The Index (QM, Oct 30; client/IndexPanel): every pet a player has ever owned, in player
-- attribute PetIndex ("Pig,Unicorn,..."), so selling or losing one doesn't hide it again;
-- it's saved (Server/Data) and kept through rebirths. Each one found has a reward to claim
-- once (Shared/IndexList.reward: cash and Power), the claimed ones in IndexClaimed.
--
--   PetIndex.start()   -- once, after PetInventory
--
-- Remote: IndexClaim (RemoteFunction) kind -> true, or false and why

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local IndexList = require(Shared.IndexList)
local Stacks = require(Shared.Stacks)
local Combat = require(script.Parent.Combat)

local PetIndex = {}

local function set(text)
	local out = {}
	for id in string.gmatch(text or "", "[^,%s]+") do
		out[id] = true
	end
	return out
end

local function list(found)
	local out = {}
	for _, kind in IndexList.all() do
		if found[kind] then
			table.insert(out, kind)
		end
	end
	return table.concat(out, ",")
end

-- adds every pet they own to their Index
local function record(player)
	local found = set(player:GetAttribute("PetIndex"))
	local before = list(found)
	for _, s in Stacks.parse(player:GetAttribute("PetsOwned")) do
		found[s.id] = true
	end
	local after = list(found)
	if after ~= before or player:GetAttribute("PetIndex") == nil then
		player:SetAttribute("PetIndex", after)
	end
end

local function claim(player, kind)
	if type(kind) ~= "string" or not Config.Pets[kind] then
		return false, "no such pet"
	end
	if not set(player:GetAttribute("PetIndex"))[kind] then
		return false, "not found yet"
	end
	local claimed = set(player:GetAttribute("IndexClaimed"))
	if claimed[kind] then
		return false, "already claimed"
	end
	claimed[kind] = true
	player:SetAttribute("IndexClaimed", list(claimed))
	local cash, power = IndexList.reward(kind)
	player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + cash)
	player:SetAttribute("Strength", (player:GetAttribute("Strength") or 0) + power)
	Combat.refresh(player)
	return true
end

function PetIndex.start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "IndexClaim"
	remote.OnServerInvoke = claim
	remote.Parent = ReplicatedStorage

	local function joined(player)
		player:GetAttributeChangedSignal("PetsOwned"):Connect(function()
			record(player)
		end)
		-- (a saved Index loads over this; the owned pets are added again after)
		player:GetAttributeChangedSignal("PetIndex"):Connect(function()
			task.defer(record, player)
		end)
		record(player)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		task.spawn(joined, player)
	end
end

return PetIndex
