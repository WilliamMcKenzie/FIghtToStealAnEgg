-- Buying regions (QM, Oct 25): each biome past the Meadow costs cash (Config.Regions.Cost).
-- Owning one is the player's Region<Name> attribute (saved by Server/Data); client/Regions
-- shows the blocker at its gate until then and asks to buy through the BuyRegion remote.
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

local function buy(player, name)
	local cost = typeof(name) == "string" and Config.Regions.Cost[name]
	if not cost then
		return false, "no such region"
	end
	if Regions.owns(player, name) then
		return true
	end
	local cash = player:GetAttribute("Cash") or 0
	if cash < cost then
		return false, "not enough cash"
	end
	player:SetAttribute("Cash", cash - cost)
	player:SetAttribute("Region" .. name, true)
	return true
end

function Regions.start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "BuyRegion"
	remote.OnServerInvoke = buy
	remote.Parent = ReplicatedStorage
end

return Regions
