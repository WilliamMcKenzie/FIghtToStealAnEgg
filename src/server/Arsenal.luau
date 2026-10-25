-- Weapons a player owns, the one they hold, and the spin a boss kill gives (QM, Oct 25).
--
-- Player attributes (saved by Server/Data): Weapons, the ids owned, comma separated
-- (everyone has Config.WeaponDrops.Start); Weapon, the one equipped. The equipped one's
-- tool (Shared/Weapons) is put in the backpack whenever it changes and on every spawn;
-- the client equips it at once. The backpack proper is still to come (QM: TBD): the chip
-- bottom right (client/WeaponSpin) switches between owned weapons through EquipWeapon.
--
-- When a boss dies (Bosses.killed) everyone in its fight gets a spin: the server rolls
-- the weapon from that boss's drops (Weapons.drops: every droppable weapon by Weight,
-- plus the boss's own super rare one), owns it at once, and sends WeaponSpin to the
-- client to play the roulette (Config.WeaponDrops); it's equipped as the spin lands.
--
--   Arsenal.start()                  -- once
--   Arsenal.spin(player, bossKind)   -- a spin (also /spin [boss], owner only)
--   Arsenal.give(player, id, equip)  -- owns it (and equips it); /weapon <id>, owner only

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons.Weapons)
local Bosses = require(script.Parent.Bosses)

local Arsenal = {}

local spinRemote = Instance.new("RemoteEvent")
spinRemote.Name = "WeaponSpin"
spinRemote.Parent = ReplicatedStorage

local START = Config.WeaponDrops.Start

function Arsenal.owned(player)
	local list, seen = {}, {}
	for id in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		if Weapons.exists(id) and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	if not seen[START] then
		table.insert(list, 1, START)
	end
	return list
end

function Arsenal.owns(player, id)
	return table.find(Arsenal.owned(player), id) ~= nil
end

function Arsenal.equip(player, id)
	if Weapons.exists(id) and Arsenal.owns(player, id) then
		player:SetAttribute("Weapon", id)
	end
end

function Arsenal.give(player, id, equip)
	if not Weapons.exists(id) then
		return
	end
	local list = Arsenal.owned(player)
	if not table.find(list, id) then
		table.insert(list, id)
		player:SetAttribute("Weapons", table.concat(list, ","))
	end
	if equip then
		Arsenal.equip(player, id)
	end
end

-- the equipped weapon's tool, in the backpack (any other weapon tool goes)
local function arm(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (character and backpack) then
		return
	end
	local id = player:GetAttribute("Weapon")
	if not Weapons.exists(id) then
		id = START
	end
	for _, holder in { character, backpack } do
		for _, tool in holder:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("Weapon") ~= nil then
				if tool:GetAttribute("Weapon") == id then
					return -- (already holding it)
				end
				tool:Destroy()
			end
		end
	end
	Weapons.makeTool(id).Parent = backpack
end

local function roll(list)
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local r = math.random() * total
	for _, entry in list do
		r -= entry.weight
		if r <= 0 then
			return entry.id
		end
	end
	return list[#list].id
end

function Arsenal.spin(player, bossKind)
	local list = Weapons.drops(bossKind)
	if #list == 0 then
		return
	end
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local odds = {}
	for _, entry in list do
		odds[entry.id] = math.max(1, math.round(total / entry.weight))
	end
	local result = roll(list)
	-- the reel it flicks through: any of the drops, evenly (so the rare one teases now and
	-- then), never the same twice running, ending on the result
	local reel = {}
	local d = Config.WeaponDrops
	for i = 1, d.Reel - 1 do
		local pick
		repeat
			pick = list[math.random(#list)].id
		until #list < 3 or (pick ~= reel[i - 1] and (i < d.Reel - 1 or pick ~= result))
		reel[i] = pick
	end
	table.insert(reel, result)
	local boss = Config.Bosses[bossKind]
	Arsenal.give(player, result, false)
	spinRemote:FireClient(player, {
		reel = reel,
		odds = odds,
		result = result,
		bonus = Weapons.get(result).Boss ~= nil,
		boss = boss and (boss.Name or bossKind) or bossKind,
	})
	if d.Equip then
		task.delay(d.SpinTime, function()
			if player.Parent then
				Arsenal.equip(player, result)
			end
		end)
	end
end

function Arsenal.start()
	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipWeapon"
	equipRemote.Parent = ReplicatedStorage
	equipRemote.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			Arsenal.equip(player, id)
		end
	end)

	local function joined(player)
		player:SetAttribute("Weapons", player:GetAttribute("Weapons") or START)
		player:SetAttribute("Weapon", player:GetAttribute("Weapon") or START)
		-- (a save from before a weapon was cut, like the Sword: QM, Oct 25, holds the
		-- starting weapon instead, and the cut ones leave the list)
		local function migrate()
			if not Weapons.exists(player:GetAttribute("Weapon")) then
				player:SetAttribute("Weapon", START)
			end
			local list = table.concat(Arsenal.owned(player), ",")
			if player:GetAttribute("Weapons") ~= list then
				player:SetAttribute("Weapons", list)
			end
		end
		player:GetAttributeChangedSignal("Weapons"):Connect(migrate)
		player:GetAttributeChangedSignal("Weapon"):Connect(function()
			migrate()
			arm(player)
		end)
		migrate()
		player.CharacterAdded:Connect(function(character)
			player:WaitForChild("Backpack")
			character:WaitForChild("Humanoid")
			task.defer(arm, player)
		end)
		-- (each spawn brings a fresh Backpack: arm that one too)
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				task.defer(arm, player)
			end
		end)
		if player.Character then
			task.defer(arm, player)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end

	Bosses.killed.Event:Connect(function(kind, players)
		for _, player in players do
			if player.Parent then
				Arsenal.spin(player, kind)
			end
		end
	end)
end

return Arsenal
