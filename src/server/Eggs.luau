-- Eggs and the fight they start (QM, Oct 24). Every nest round a biome's edges holds an
-- egg. Hold E to steal it: it rides on your back, the biome's boss appears (Server/
-- Bosses.summon, with its arrival shown: client/BossIntro), and you're
-- locked into its fight (player attribute LockedIn = the biome): red barriers across its
-- ways out, drawn and solid only for you (client/Barriers.luau), keep you in until the
-- boss is dead. Anyone who hits the boss is locked in too, so a group fights it together.
-- With the boss dead everyone in its fight goes free; carry the egg into your pen for
-- its reward (Config.Eggs.Reward). Die holding an egg and it's lost (and you're out of
-- the fight).
-- Nests run on their biome's cooldown (QM, Oct 26): when it's up every nest pops an egg
-- (client/EggView plays the pop-in) and the boss can be called up again. Take one and the
-- boss comes as usual; anyone can take the rest mid-fight. When the fight's over (boss
-- dead, or gone home with nobody left fighting) the eggs left vanish and the cooldown
-- (Config.Eggs.Cooldown[biome]) starts again; its end is each nest's CooldownEnds attribute
-- (server time), shown over the nests to anyone close (client/NestTimers). A biome with
-- nests but no boss starts its cooldown once its nests are empty.
-- With Config.Eggs.Carry off (for now: QM, Oct 25) there's no egg to carry: stealing one
-- only calls up the boss and locks you into its fight.
--
-- Player attributes: HeldEgg (biome name), HeldEggKind (its animal), LockedIn (biome name),
-- Eggs (eggs brought home).
--
--   Eggs.start(map)   -- once, after Map.ensure()
--   Eggs.refill()     -- every nest full again now, no fight on (the /reboss command)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pets = require(ReplicatedStorage.Shared:WaitForChild("Pets"))
local Bosses = require(script.Parent.Bosses)
local Map = require(script.Parent.Map)
local Hatchery = require(script.Parent.Hatchery)
local Pens = require(script.Parent.Pens)

local Eggs = {}

local carried = {} -- [player] = egg part on their back
local biomes = {} -- [biome] = { nests, eggs = { [egg] = true }, boss, fight, round }

-- An egg is an invisible box where the egg stands (tagged "Egg", its kind in EggKind and
-- its size in EggScale): each client draws LassoAPet's egg for that animal there, AFK
-- twitch and all (client/EggView), so it's the same egg in the nest, on your back and
-- in your pen. The box is the egg's size, its bottom face on the ground.
local EGG_HEIGHT = 4 -- studs, an egg's drawing at scale 1 (about)

-- a nest's egg: one of its biome's kinds, by their weights (Config.Eggs.Kinds)
function Eggs.kindFor(biome)
	local total = 0
	for _, weight in Config.Eggs.Kinds[biome] or {} do
		total += weight
	end
	local roll = math.random() * total
	for kind, weight in Config.Eggs.Kinds[biome] or {} do
		roll -= weight
		if weight > 0 and roll <= 0 then
			return kind
		end
	end
	return "Horse"
end

function Eggs.make(biome, kind, scale)
	scale = scale or 1
	local egg = Instance.new("Part")
	egg.Name = kind .. "Egg"
	egg.Size = Vector3.new(3, EGG_HEIGHT, 3) * scale
	egg.Transparency = 1
	egg.CanCollide = false
	egg.CanTouch = false
	egg.CanQuery = false
	egg.Massless = true
	egg:SetAttribute("Biome", biome)
	egg:SetAttribute("EggKind", kind)
	egg:SetAttribute("EggScale", scale)
	CollectionService:AddTag(egg, "Egg")
	return egg
end

local function lock(player, biome)
	if player:GetAttribute("LockedIn") ~= biome then
		player:SetAttribute("LockedIn", biome)
	end
end

local function drop(player)
	local egg = carried[player]
	carried[player] = nil
	if egg then
		egg:Destroy()
	end
	player:SetAttribute("HeldEgg", nil)
	player:SetAttribute("HeldEggKind", nil)
end

local function carry(player, biome, kind)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local egg = Eggs.make(biome, kind, Config.Eggs.Scale.Carried)
	egg.Anchored = false
	-- (on your back, leaning back a little)
	egg.CFrame = root.CFrame * CFrame.new(0, 1.6, 1.3) * CFrame.Angles(math.rad(-15), 0, 0) * CFrame.new(0, egg.Size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, egg
	weld.Parent = egg
	egg.Parent = player.Character
	carried[player] = egg
	player:SetAttribute("HeldEgg", biome)
	player:SetAttribute("HeldEggKind", kind)
	return true
end

local fill, cool

-- a nest's egg and its prompt, popping in at server time popAt
local function lay(nest, biome, popAt)
	local state = biomes[biome]
	local x, y, z = nest:GetAttribute("EggX"), nest:GetAttribute("EggY") or 1, nest:GetAttribute("EggZ")
	local kind = Eggs.kindFor(biome)
	local pet = Config.Pets[kind]
	local egg = Eggs.make(biome, kind, Config.Eggs.Scale.Nest * (Config.Eggs.RarityScale[pet and pet.Rarity] or 1))
	egg.Anchored = true
	egg.CFrame = CFrame.new(x, y + egg.Size.Y / 2, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	egg:SetAttribute("PopAt", popAt)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = Pets.name(kind) .. " Egg"
	prompt.HoldDuration = Config.Eggs.StealTime
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg
	egg.Parent = nest
	state.eggs[egg] = true
	prompt.Triggered:Connect(function(player)
		if not state.eggs[egg] or player:GetAttribute("HeldEgg") then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) then
			return
		end
		if Config.Eggs.Carry and not carry(player, biome, kind) then
			return
		end
		state.eggs[egg] = nil
		egg:Destroy()
		Hatchery.give(player, kind) -- (yours at once: in your hotbar until you die, QM Oct 25)
		if state.boss then
			-- (the first egg calls the boss up; later ones join its fight)
			lock(player, biome) -- (first, so their screen knows the boss that appears is theirs)
			if Bosses.summon(biome, player) then
				state.fight = true
			end
		end
		if not state.fight and next(state.eggs) == nil then
			cool(biome) -- (no boss, or none came: the nests just wait)
		end
	end)
end

-- the cooldown's up: every nest lays, one after another
function fill(biome)
	local state = biomes[biome]
	state.round += 1
	state.fight = false
	for egg in state.eggs do
		egg:Destroy()
	end
	table.clear(state.eggs)
	local now = workspace:GetServerTimeNow()
	for i, nest in state.nests do
		nest:SetAttribute("CooldownEnds", nil)
		lay(nest, biome, now + (i - 1) * Config.Eggs.PopStagger)
	end
end

-- the eggs left vanish and the cooldown starts
function cool(biome)
	local state = biomes[biome]
	state.round += 1
	state.fight = false
	for egg in state.eggs do
		-- (clients shrink it away: client/EggView)
		egg:SetAttribute("Vanish", true)
		local prompt = egg:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false
		end
		task.delay(0.4, egg.Destroy, egg)
	end
	table.clear(state.eggs)
	local cooldown = Config.Eggs.Cooldown[biome] or Config.Eggs.DefaultCooldown
	local ends = workspace:GetServerTimeNow() + cooldown
	for _, nest in state.nests do
		nest:SetAttribute("CooldownEnds", ends)
	end
	local round = state.round
	task.delay(cooldown, function()
		if state.round == round then
			fill(biome)
		end
	end)
end

function Eggs.refill()
	for biome in biomes do
		fill(biome)
	end
end

-- inside a pen's Area box (flat)
local function inside(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2
end

function Eggs.start(map)
	for _, biome in map.Biomes:GetChildren() do
		local nests = biome:FindFirstChild("Nests")
		local list = if nests then nests:GetChildren() else {}
		table.sort(list, function(a, b)
			return (tonumber(string.match(a.Name, "%d+")) or 0) < (tonumber(string.match(b.Name, "%d+")) or 0)
		end)
		local spot = biome:FindFirstChild("BossSpot")
		local area = Map.area(biome.Name)
		local arena = spot and area and Bosses.arena(biome.Name, spot.Position, area.Bounds)
		if #list > 0 then
			for _, nest in list do
				CollectionService:AddTag(nest, "Nest")
			end
			biomes[biome.Name] = { nests = list, eggs = {}, boss = arena ~= nil, fight = false, round = 0 }
			fill(biome.Name)
		end
	end

	-- the fight's over (its boss dead or gone home): the nests' cooldown starts
	Bosses.ended.Event:Connect(function(biome)
		local state = biomes[biome]
		if state and state.fight then
			cool(biome)
		end
	end)

	-- hitting a boss locks you into its fight; its death frees everyone in it
	Bosses.engaged.Event:Connect(lock)
	Bosses.defeated.Event:Connect(function(biome)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("LockedIn") == biome then
				player:SetAttribute("LockedIn", nil)
			end
		end
	end)

	local function joined(player)
		player.CharacterAdded:Connect(function(character)
			-- (a new life: whatever you were carrying or fighting is gone)
			drop(player)
			player:SetAttribute("LockedIn", nil)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				drop(player)
				player:SetAttribute("LockedIn", nil)
			end)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		drop(player)
	end)

	-- bringing an egg home: free of the fight and inside your own pen
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.25 then
			return
		end
		clock = 0
		for player, egg in carried do
			local biome = player:GetAttribute("HeldEgg")
			local kind = player:GetAttribute("HeldEggKind") or Eggs.kindFor(biome or "")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local pen = Pens.of(player)
			local area = pen and pen:FindFirstChild("Area")
			if biome and root and area and not player:GetAttribute("LockedIn") and inside(area, root.Position) then
				carried[player] = nil
				egg:Destroy()
				player:SetAttribute("HeldEgg", nil)
				player:SetAttribute("HeldEggKind", nil)
				player:SetAttribute("Eggs", (player:GetAttribute("Eggs") or 0) + 1)
				player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + (Config.Eggs.Reward[biome] or 0))
				Pens.addEgg(player, function()
					return Eggs.make(biome, kind, Config.Eggs.Scale.Pen)
				end)
			end
		end
	end)
end

return Eggs
