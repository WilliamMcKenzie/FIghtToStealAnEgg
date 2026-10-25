-- Saving (QM, Oct 24): each player's progress lives in their attributes while they play
-- (Cash, Strength, Eggs, Rebirths, Train<Name> for each training ground bought,
-- Region<Name> for each region, and Weapons and Weapon: Server/Arsenal) and is
-- saved to a DataStore when they leave, every Config.Data.AutoSave seconds, and when the
-- server shuts down. Nothing is saved for a player whose data failed to load (so a
-- DataStore outage can't wipe anyone), and in a Studio playtest without API access it
-- just doesn't save (it warns once).
--
-- Rebirth lives here too: with enough cash (Config.Rebirth), your cash, Strength,
-- training grounds and regions reset, and every hit trains StrengthBonus more for each rebirth.
--
--   Data.start()                 -- once
--   Data.rebirthCost(player) -> cash needed for their next rebirth
--   Data.reset(player)       -- a brand new account (the /reset command)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Combat = require(script.Parent.Combat)

local Data = {}

local store = nil
local loaded = {} -- [player] = true once their data is in
local warned = false

local function keys()
	local list = { "Cash", "Strength", "Eggs", "Rebirths", "Weapons", "Weapon" }
	for name in Config.Training.Grounds do
		table.insert(list, "Train" .. name)
	end
	for name in Config.Regions.Cost do
		table.insert(list, "Region" .. name)
	end
	return list
end

local function snapshot(player)
	local out = {}
	for _, key in keys() do
		out[key] = player:GetAttribute(key)
	end
	return out
end

local function save(player)
	if not (store and loaded[player]) then
		return
	end
	local data = snapshot(player)
	local ok, err = pcall(function()
		store:UpdateAsync("player_" .. player.UserId, function()
			return data
		end)
	end)
	if not ok then
		warn("Data: couldn't save " .. player.Name .. ": " .. tostring(err))
	end
end

local function load(player)
	if not store then
		loaded[player] = true
		return
	end
	local ok, data = pcall(function()
		return store:GetAsync("player_" .. player.UserId)
	end)
	if not ok then
		if not warned then
			warned = true
			warn("Data: no DataStore here (Studio needs API access): progress won't save. " .. tostring(data))
		end
		return
	end
	if player.Parent == nil then
		return
	end
	if type(data) == "table" then
		for _, key in keys() do
			local value = data[key]
			if value ~= nil then
				player:SetAttribute(key, value)
			end
		end
	end
	-- (free grounds stay open whatever was saved)
	for name, g in Config.Training.Grounds do
		if g.Cost <= 0 then
			player:SetAttribute("Train" .. name, true)
		end
	end
	Combat.refresh(player)
	loaded[player] = true
end

function Data.rebirthCost(player)
	local r = Config.Rebirth
	return math.floor(r.Cost * r.Growth ^ (player:GetAttribute("Rebirths") or 0))
end

local function rebirth(player)
	local cost = Data.rebirthCost(player)
	if (player:GetAttribute("Cash") or 0) < cost or player:GetAttribute("LockedIn") then
		return false
	end
	player:SetAttribute("Rebirths", (player:GetAttribute("Rebirths") or 0) + 1)
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Strength", 0)
	for name, g in Config.Training.Grounds do
		player:SetAttribute("Train" .. name, g.Cost <= 0)
	end
	for name in Config.Regions.Cost do
		player:SetAttribute("Region" .. name, nil)
	end
	Combat.refresh(player)
	task.spawn(save, player)
	return true
end

-- back to a brand new account (QM, Oct 25: the /reset command): nothing bought, earned or
-- owned, the Horse to ride and the starting weapon; saved straight away
function Data.reset(player)
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Strength", 0)
	player:SetAttribute("Eggs", 0)
	player:SetAttribute("Rebirths", 0)
	player:SetAttribute("Weapons", Config.WeaponDrops.Start)
	player:SetAttribute("Weapon", Config.WeaponDrops.Start)
	player:SetAttribute("Pet", "Horse")
	player:SetAttribute("HeldEgg", nil)
	player:SetAttribute("HeldEggKind", nil)
	player:SetAttribute("LockedIn", nil)
	for name, g in Config.Training.Grounds do
		player:SetAttribute("Train" .. name, g.Cost <= 0)
	end
	for name in Config.Regions.Cost do
		player:SetAttribute("Region" .. name, nil)
	end
	Combat.refresh(player)
	task.spawn(save, player)
end

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.Store)
	end)
	store = if ok then result else nil

	local remote = Instance.new("RemoteFunction")
	remote.Name = "Rebirth"
	remote.OnServerInvoke = rebirth
	remote.Parent = ReplicatedStorage

	local function joined(player)
		player:SetAttribute("Rebirths", player:GetAttribute("Rebirths") or 0)
		player:SetAttribute("Eggs", player:GetAttribute("Eggs") or 0)
		load(player)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		task.spawn(joined, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutoSave)
			for _, player in Players:GetPlayers() do
				task.spawn(save, player)
			end
		end
	end)
	game:BindToClose(function()
		local left = 0
		for _, player in Players:GetPlayers() do
			left += 1
			task.spawn(function()
				save(player)
				left -= 1
			end)
		end
		local t = os.clock()
		while left > 0 and os.clock() - t < 20 do
			task.wait(0.1)
		end
	end)
end

return Data
