-- Saving (QM, Oct 24): each player's progress lives in their attributes while they play
-- (Cash, Strength, Eggs, Rebirths, Train<Name> for each training ground bought,
-- Region<Name> for each region, Weapons and Weapon: Server/Arsenal, PetsOwned,
-- PenPets and Pet (the one ridden): Server/PetInventory, PenEggs: Server/Hatchery, PetIndex
-- and IndexClaimed: Server/PetIndex) and is
-- saved to a DataStore when they leave, every Config.Data.AutoSave seconds, and when the
-- server shuts down. Nothing is saved for a player whose data failed to load (so a
-- DataStore outage can't wipe anyone), and in a Studio playtest without API access it
-- just doesn't save (it warns once).
--
-- Offline earnings (QM, Oct 27: LassoAPet's "You earn $X/Day offline!"): every save
-- stamps LastSeen (os.time()); back again, you're paid your pen's income (PetInventory.income)
-- times Config.Data.OfflineRate for the time away, up to Config.Data.OfflineMax seconds. Player attribute OfflinePaid is
-- what came in, for client/Hud's "+$X" popup.
--
-- A brand new account (nothing saved) starts the tutorial (Server/Tutorial); TutorialDone
-- is saved the moment it's over, so a returning player skips it. (Saves from before the
-- tutorial have no TutorialDone, but they aren't new: no tutorial for them either.)
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
local PetInventory = require(script.Parent.PetInventory)
local Tutorial = require(script.Parent.Tutorial)

local Data = {}

local store = nil
local loaded = {} -- [player] = true once their data is in
local warned = false

local function keys()
	local list = { "Cash", "Strength", "Eggs", "Rebirths", "Weapons", "Weapon", "PetsOwned", "PenPets", "Pet", "PenEggs", "ExtraSlots", "PetIndex", "IndexClaimed", "Passes", "TutorialDone" }
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
	out.LastSeen = os.time()
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
		if Config.Tutorial.On then
			Tutorial.begin(player, true) -- (no saves here: every playtest is a new account)
		end
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
	-- (a brand new account, nothing saved: the tutorial, Server/Tutorial)
	if data == nil and Config.Tutorial.On then
		Tutorial.begin(player, true)
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
	-- the time away, paid at the pen's rate
	if type(data) == "table" and type(data.LastSeen) == "number" then
		local away = math.clamp(os.time() - data.LastSeen, 0, Config.Data.OfflineMax)
		local paid = math.floor(PetInventory.income(player) * Config.Data.OfflineRate * away)
		if paid > 0 then
			player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + paid)
			player:SetAttribute("OfflinePaid", paid)
		end
	end
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
-- owned but the starter pet (Server/PetInventory gives it) and the starting weapon; saved straight away
function Data.reset(player)
	player:SetAttribute("Cash", 0)
	player:SetAttribute("Strength", 0)
	player:SetAttribute("Eggs", 0)
	player:SetAttribute("Rebirths", 0)
	player:SetAttribute("Weapons", Config.Arsenal.Start)
	player:SetAttribute("Weapon", Config.Arsenal.Start)
	player:SetAttribute("PetsOwned", "")
	player:SetAttribute("PenPets", "")
	player:SetAttribute("ExtraSlots", nil)
	player:SetAttribute("IndexClaimed", nil)
	player:SetAttribute("PetIndex", "")
	player:SetAttribute("PenEggs", nil)
	player:SetAttribute("EggBag", nil)
	player:SetAttribute("Holding", nil)
	player:SetAttribute("Pet", Config.Backpack.Starter)
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
	player:SetAttribute("TutorialDone", nil)
	if Config.Tutorial.On then
		Tutorial.begin(player, true) -- (a new account gets the tutorial)
	end
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
		-- (the tutorial's done: saved now, so leaving straight after can't lose it)
		player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
			task.spawn(save, player)
		end)
		-- (the HUD's gain popups count from here, so the saved Cash and Power don't pop up)
		player:SetAttribute("Loaded", true)
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
