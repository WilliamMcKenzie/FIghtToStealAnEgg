-- Buying regions (QM, Oct 25): each biome past the Meadow costs cash (Config.Regions.Cost).
-- Owning one is the player's Region<Name> attribute (saved by Server/Data); client/Regions
-- shows the blocker at its gate until then and asks to buy through the BuyRegion remote.
-- A training ground (QM, Oct 30: a region off the base, its blocker at its corridor) is
-- bought the same way, BuyRegion(name, true): Config.Training.Grounds' Cost, owned as
-- Train<Name> (a rebirth locks it again: Server/Data).
--
--   Regions.start()              -- once
--   Regions.owns(player, name)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Regions = {}

function Regions.owns(player, name)
	local cost = Config.Regions.Cost[name]
	return cost == nil or cost <= 0 or player:GetAttribute("Region" .. name) == true
end

local function buy(player, name, training)
	if typeof(name) ~= "string" then
		return false, "no such region"
	end
	local ground = training == true and Config.Training.Grounds[name]
	local cost = if training == true then ground and ground.Cost else Config.Regions.Cost[name]
	if not cost then
		return false, "no such region"
	end
	local owns = (if training == true then "Train" else "Region") .. name
	if cost <= 0 or player:GetAttribute(owns) == true then
		return true
	end
	local cash = player:GetAttribute("Cash") or 0
	if cash < cost then
		return false, "not enough cash"
	end
	player:SetAttribute("Cash", cash - cost)
	player:SetAttribute(owns, true)
	return true
end

function Regions.start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "BuyRegion"
	remote.OnServerInvoke = buy
	remote.Parent = ReplicatedStorage
end

return Regions
