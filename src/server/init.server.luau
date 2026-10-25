-- Readies the map (Server/Map: the one baked into the place) and starts what runs on
-- it: pens, eggs and the bosses' fights, the training grounds, and the weapons bosses
-- drop (Server/Arsenal: everyone starts with the sword). Relays slashes and shots so
-- other players see them (and lets them hit bosses, mobs and dummies: Server/Combat),
-- and spawns a boss on /boss. Your pet (player attribute Pet,
-- the Horse to start) is all your health and speed (Shared/Pets); /ride <pet> swaps it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local SlashTuning = require(Shared.SlashTuning)
local Weapons = require(Shared.Weapons.Weapons)
local Arsenal = require(script.Arsenal)
local WorldColors = require(Shared.WorldColors)
local Bosses = require(script.Bosses)
local Combat = require(script.Combat)
local Data = require(script.Data)
local Eggs = require(script.Eggs)
local Map = require(script.Map)
local Pens = require(script.Pens)
local Regions = require(script.Regions)
local Training = require(script.Training)

SlashTuning.create() -- workspace.SlashTuning: live slash values to edit during Play
-- workspace.FightBarrierStyle: the red fight barriers' quasicrystal knobs (beside
-- SlashTuning; client/FightBarrierFx), kept with the place when it's there, made here when
-- it isn't
if not workspace:FindFirstChild("FightBarrierStyle") then
	local style = Instance.new("Configuration")
	style.Name = "FightBarrierStyle"
	style.Parent = workspace
end
local map = Map.ensure() -- workspace.Map (baked into the place in Studio, or built now)
WorldColors.create() -- workspace.WorldColors: live world colours (after the map: it paints it)
Pens.start(map)
Eggs.start(map)
Training.start(map)
Regions.start()
Data.start() -- (after Training: it loads over the grounds' defaults)
Arsenal.start() -- (each player's weapon tool, and the spin when a boss dies)

local remote = Instance.new("RemoteEvent")
remote.Name = "Slash"
remote.Parent = ReplicatedStorage

-- Everyone rides (client/Riding.luau): their pet's health and speed (QM, Oct 25: nothing
-- else adds to them), and no jumping
local function ride(character)
	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	local pet = Pets.stats(player and player:GetAttribute("Pet") or "Horse")
	local hurt = humanoid.MaxHealth - humanoid.Health -- (a swap mid-fight keeps your damage)
	humanoid.MaxHealth = pet.Health
	humanoid.Health = math.max(1, pet.Health - hurt)
	humanoid.WalkSpeed = pet.Speed -- (client/Liquid slows it in water)
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
end
local requestBoss, reboss, swapPet, givePet, testSpin, giveWeapon, giveCash, resetPlayer -- (below)
local function joined(player)
	-- the HUD's counters (client/Hud.luau): Power is your slash's damage (Server/Combat
	-- keeps it), Cash starts at 0 (no saving yet)
	player:SetAttribute("Cash", player:GetAttribute("Cash") or 0)
	player:SetAttribute("Pet", player:GetAttribute("Pet") or "Horse")
	player.CharacterAdded:Connect(ride)
	player:GetAttributeChangedSignal("Pet"):Connect(function()
		if player.Character then
			ride(player.Character)
		end
	end)
	-- (/boss typed in chat also works when the place uses the legacy chat)
	player.Chatted:Connect(function(message)
		if message:lower():match("^/reboss") then
			reboss(player)
		elseif message:lower():match("^/boss") then
			requestBoss(player)
		elseif message:lower():match("^/ride") then
			swapPet(player, message)
		elseif message:lower():match("^/give") then
			givePet(player, message)
		elseif message:lower():match("^/spin") then
			testSpin(player, message)
		elseif message:lower():match("^/weapon") then
			giveWeapon(player, message)
		elseif message:lower():match("^/cash") then
			giveCash(player, message)
		elseif message:lower():match("^/reset") then
			resetPlayer(player)
		end
	end)
	if player.Character then
		task.spawn(ride, player.Character)
	end
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do
	joined(player)
end

local last = {}
remote.OnServerEvent:Connect(function(player, dir, seed, yaw)
	if (dir ~= 1 and dir ~= -1) or typeof(seed) ~= "number" or seed ~= seed then
		return
	end
	if typeof(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > 10 then
		return
	end
	-- (only with a melee weapon equipped, at most as often as it swings)
	local id = player:GetAttribute("Weapon")
	if Weapons.get(id).Type ~= "Melee" then
		return
	end
	local c = Weapons.slash(Config.Slash, id)
	local now = os.clock()
	if last[player] and now - last[player] < c.Cooldown * 0.8 then
		return
	end
	last[player] = now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			remote:FireClient(other, player, dir, seed, yaw)
		end
	end
	-- the hit lands as the arc sweeps through (wind-up, then half the sweep)
	task.delay(c.Windup + c.Sweep * 0.5, Combat.slash, player, yaw, c)
end)

-- Ranged and Magic weapons: the client fires (Shoot, with the yaw), the server runs the
-- shots for the damage (Server/Combat) and tells everyone else to draw them (client/Shots)
local shoot = Instance.new("RemoteEvent")
shoot.Name = "Shoot"
shoot.Parent = ReplicatedStorage
local lastShot = {}
shoot.OnServerEvent:Connect(function(player, yaw)
	if typeof(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > 10 then
		return
	end
	local id = player:GetAttribute("Weapon")
	local w = Weapons.get(id)
	if not w.Shot then
		return
	end
	local now = os.clock()
	if lastShot[player] and now - lastShot[player] < w.Shot.Cooldown * 0.8 then
		return
	end
	lastShot[player] = now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			shoot:FireClient(other, player, id, yaw)
		end
	end
	Combat.shoot(player, id, yaw)
end)

-- /boss: a chicken boss in front of you. The command is a TextChatCommand; its client
-- side asks through BossRequest (Triggered fires where the command is run), and the
-- server's own Triggered is a fallback. Once a second per player either way.
local bossRequest = Instance.new("RemoteEvent")
bossRequest.Name = "BossRequest"
bossRequest.Parent = ReplicatedStorage
local lastBoss = {}
function requestBoss(player)
	local now = os.clock()
	if lastBoss[player] and now - lastBoss[player] < 1 then
		return
	end
	lastBoss[player] = now
	Bosses.spawn("Chicken", player)
end
bossRequest.OnServerEvent:Connect(requestBoss)
local command = Instance.new("TextChatCommand")
command.Name = "BossCommand"
command.PrimaryAlias = "/boss"
command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
command.Triggered:Connect(function(source)
	local player = source and Players:GetPlayerByUserId(source.UserId)
	if player then
		requestBoss(player)
	end
end)
-- /reboss: every biome's boss re-rolled from its pool (QM, Oct 25). The game's owner, or
-- anyone in a Studio playtest.
local RunService = game:GetService("RunService")
local function mayReboss(player)
	if RunService:IsStudio() or player.UserId == game.CreatorId then
		return true
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rank == 255
	end
	return false
end
local lastReboss = 0
function reboss(player)
	if not mayReboss(player) or os.clock() - lastReboss < 2 then
		return
	end
	lastReboss = os.clock()
	Bosses.reroll()
end
local rebossCommand = Instance.new("TextChatCommand")
rebossCommand.Name = "RebossCommand"
rebossCommand.PrimaryAlias = "/reboss"
rebossCommand.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
rebossCommand.Triggered:Connect(function(source)
	local player = source and Players:GetPlayerByUserId(source.UserId)
	if player then
		reboss(player)
	end
end)
local rebossRequest = Instance.new("RemoteEvent")
rebossRequest.Name = "RebossRequest"
rebossRequest.Parent = ReplicatedStorage
rebossRequest.OnServerEvent:Connect(reboss)

-- /ride <pet>: ride that pet (QM, Oct 25: for trying the pets out until hatching comes),
-- "/ride" alone lists them. The game's owner, or anyone in a Studio playtest.
function swapPet(player, message)
	if not mayReboss(player) then
		return
	end
	local want = (message:match("^/%a+%s+(.-)%s*$") or ""):lower():gsub("%s", "")
	for _, kind in Pets.kinds() do
		if kind:lower() == want then
			player:SetAttribute("Pet", kind)
			return
		end
	end
	print("/ride one of: " .. table.concat(Pets.kinds(), ", "))
end
local rideCommand = Instance.new("TextChatCommand")
rideCommand.Name = "RideCommand"
rideCommand.PrimaryAlias = "/ride"
rideCommand.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
local rideRequest = Instance.new("RemoteEvent")
rideRequest.Name = "RideRequest"
rideRequest.Parent = ReplicatedStorage
rideRequest.OnServerEvent:Connect(function(player, message)
	if typeof(message) == "string" and #message < 100 then
		swapPet(player, message)
	end
end)

-- /give <pet>: that pet in your pen (QM, Oct 25), wandering about. The game's owner, or
-- anyone in a Studio playtest.
function givePet(player, message)
	if not mayReboss(player) then
		return
	end
	local want = (message:match("^/%a+%s+(.-)%s*$") or ""):lower():gsub("%s", "")
	for _, kind in Pets.kinds() do
		if kind:lower() == want then
			Pens.addPet(player, kind)
			return
		end
	end
	print("/give one of: " .. table.concat(Pets.kinds(), ", "))
end
local giveCommand = Instance.new("TextChatCommand")
giveCommand.Name = "GiveCommand"
giveCommand.PrimaryAlias = "/give"
giveCommand.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
local giveRequest = Instance.new("RemoteEvent")
giveRequest.Name = "GiveRequest"
giveRequest.Parent = ReplicatedStorage
giveRequest.OnServerEvent:Connect(function(player, message)
	if typeof(message) == "string" and #message < 100 then
		givePet(player, message)
	end
end)

-- /spin [boss]: the weapon spin a boss kill gives (QM, Oct 25: for trying it), as if that
-- boss (a Config.Bosses key or name, the Mother Hen if none) had died. /weapon <weapon>
-- owns and equips one ("/weapon" alone lists them). The game's owner, or anyone in a
-- Studio playtest.
local function squash(text)
	return (text:lower():gsub("[%s_']", ""))
end
function testSpin(player, message)
	if not mayReboss(player) then
		return
	end
	local want = squash(message:match("^/%a+%s+(.-)%s*$") or "")
	local kind = "MotherHen"
	for key, c in Config.Bosses do
		if want ~= "" and (squash(key) == want or squash(c.Name or "") == want) then
			kind = key
		end
	end
	Arsenal.spin(player, kind)
end
function giveWeapon(player, message)
	if not mayReboss(player) then
		return
	end
	local want = squash(message:match("^/%a+%s+(.-)%s*$") or "")
	local ids = {}
	for id, w in Config.Weapons do
		table.insert(ids, id)
		if want ~= "" and (squash(id) == want or squash(w.Name) == want) then
			Arsenal.give(player, id, true)
			return
		end
	end
	table.sort(ids)
	print("/weapon one of: " .. table.concat(ids, ", "))
end
-- /cash [n]: n more cash (a million without a number); /reset: a brand new account, saved
-- (QM, Oct 25). The game's owner, or anyone in a Studio playtest.
function giveCash(player, message)
	if not mayReboss(player) then
		return
	end
	local digits = (message:match("^/%a+%s+(.-)%s*$") or ""):gsub("[,%s_]", "")
	local n = tonumber(digits) or 1e6
	if n ~= n or math.abs(n) == math.huge then
		return
	end
	player:SetAttribute("Cash", math.max(0, (player:GetAttribute("Cash") or 0) + math.floor(n)))
end
function resetPlayer(player)
	if not mayReboss(player) then
		return
	end
	Pens.clear(player)
	Data.reset(player)
	if player.Character then
		player:LoadCharacter() -- (a fresh start: off any fight, back at the spawn)
	end
end
for _, cmd in { { "Spin", testSpin }, { "Weapon", giveWeapon }, { "Cash", giveCash }, { "Reset", resetPlayer } } do
	local command = Instance.new("TextChatCommand")
	command.Name = cmd[1] .. "Command"
	command.PrimaryAlias = "/" .. cmd[1]:lower()
	command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	local request = Instance.new("RemoteEvent")
	request.Name = cmd[1] .. "Request"
	request.Parent = ReplicatedStorage
	request.OnServerEvent:Connect(function(player, message)
		if typeof(message) == "string" and #message < 100 then
			cmd[2](player, message)
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
	lastShot[player] = nil
	lastBoss[player] = nil
end)
