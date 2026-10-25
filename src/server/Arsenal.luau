-- Weapons a player owns, the one they hold, and the spin a boss kill gives (QM, Oct 25).
--
-- Player attributes (saved by Server/Data): Weapons, the ids owned with how many of each
-- (Shared/Stacks: "Axe:3,Staff"; everyone has Config.WeaponDrops.Start); Weapon, the one
-- equipped. The equipped one's tool (Shared/Weapons) is put in the Roblox backpack
-- whenever it changes and on every spawn; the client equips it at once. The Backpack
-- popup (client/Backpack) picks between owned weapons through EquipWeapon.
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
local Stacks = require(Shared.Stacks)
local Weapons = require(Shared.Weapons.Weapons)
local Bosses = require(script.Parent.Bosses)

local Arsenal = {}

local spinRemote = Instance.new("RemoteEvent")
spinRemote.Name = "WeaponSpin"
spinRemote.Parent = ReplicatedStorage

local START = Config.WeaponDrops.Start

-- what they own, with how many of each ({ { id, n }, ... }), the starting weapon first
function Arsenal.stacks(player)
	local list = Stacks.parse(player:GetAttribute("Weapons"), Weapons.exists)
	if Stacks.count(list, START) == 0 then
		table.insert(list, 1, { id = START, n = 1 })
	end
	return list
end

function Arsenal.owned(player)
	local list = {}
	for _, s in Arsenal.stacks(player) do
		table.insert(list, s.id)
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

-- one more of it (a duplicate stacks: x2, x3... in the backpack), and equips it
function Arsenal.give(player, id, equip)
	if not Weapons.exists(id) then
		return
	end
	player:SetAttribute("Weapons", Stacks.format(Stacks.add(Arsenal.stacks(player), id, 1)))
	if equip then
		Arsenal.equip(player, id)
	end
end

-- an egg in your hands (QM, Oct 25: Server/Hatchery): an invisible handle the arm holds,
-- the egg drawn at it by each client (client/PenEggs)
local function eggTool(kind)
	local tool = Instance.new("Tool")
	tool.Name = kind .. " Egg"
	tool.CanBeDropped = false
	tool:SetAttribute("EggTool", kind)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- the equipped weapon's tool in the backpack, or the egg they're holding (Holding) in
-- its place (any other weapon or egg tool goes)
local function arm(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (character and backpack) then
		return
	end
	local egg = player:GetAttribute("Holding")
	local id = player:GetAttribute("Weapon")
	if not Weapons.exists(id) then
		id = START
	end
	local have = false
	for _, holder in { character, backpack } do
		for _, tool in holder:GetChildren() do
			if tool:IsA("Tool") and (tool:GetAttribute("Weapon") ~= nil or tool:GetAttribute("EggTool") ~= nil) then
				local wanted = if egg then tool:GetAttribute("EggTool") == egg else tool:GetAttribute("Weapon") == id
				if wanted and not have then
					have = true -- (already holding it)
				else
					tool:Destroy()
				end
			end
		end
	end
	if not have then
		(if egg then eggTool(egg) else Weapons.makeTool(id)).Parent = backpack
	end
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
			local list = Stacks.format(Arsenal.stacks(player))
			if player:GetAttribute("Weapons") ~= list then
				player:SetAttribute("Weapons", list)
			end
		end
		player:GetAttributeChangedSignal("Weapons"):Connect(migrate)
		player:GetAttributeChangedSignal("Weapon"):Connect(function()
			migrate()
			arm(player)
		end)
		player:GetAttributeChangedSignal("Holding"):Connect(function()
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
