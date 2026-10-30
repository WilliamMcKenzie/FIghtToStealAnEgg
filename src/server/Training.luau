-- The training grounds (QM, Oct 24): five pen-sized yards along the south of the base,
-- the free straw dummies and one per biome (Meadow pets, Desert cactus monsters, Ice
-- pets, Lava rock hogs). Strength only ever comes from attacking (Server/Combat):
-- each hit trains the enemy's Strength (Config.Training.Grounds), so these are for
-- standing and swinging, RuneScape sand-crab style. A biome's ground is fenced off until
-- you buy it (Cost in cash, the prompt at its gate; player attribute Train<Name>, which a
-- rebirth will clear); the client keeps its gate solid for you until then
-- (client/Barriers.luau).
--
-- Mobs are invisible bodies in workspace.Mobs (attributes Model, ModelSize, Tint, Name,
-- Health, MaxHealth, Radius, Ground), drawn by client/BossView.luau like the bosses.
-- They amble about their yard; one that falls is back Respawn seconds later. Hit one and
-- it fights back (QM, Oct 26): it follows whoever last hit it round its yard and bites
-- with its Attacks (Config.Training.Grounds, run by Server/BossAttacks like a boss's),
-- hard enough to kill you (QM, Oct 26), until you leave the yard, die, or stop hitting it
-- for Config.Training.Calm seconds. Each mob is a random pet from its biome's eggs
-- (Config.Eggs.Kinds), as big as when you ride it, or (QM, Oct 30) its ground's Mobs taking
-- turns: Meadow pigs and fish, Desert cactus monsters and scorpions that keep their
-- distance casting sand, Tundra boars, snowmen casting snow and penguins that run from you
-- lobbing bombs, Lava fire boars (0.6x) and firebirds casting fire. A mob's Magic and bombs
-- only ever hit whoever it's angry with (its b.foes). Higher grounds are bigger:
-- Config.Training's Grow.
--
--   Training.start(map)   -- once, after Map.ensure()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapData = require(ReplicatedStorage.Shared.MapData)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Combat = require(script.Parent.Combat)
local BossAttacks = require(script.Parent.BossAttacks)

local Training = {}

local folder = Instance.new("Folder")
folder.Name = "Mobs"
folder.Parent = workspace

local mobs = {} -- [body] = { ground, x, z, half, goal, wait, yaw, g, rng, radius, target, angry, b }

function Training.unlocked(player, name)
	local g = Config.Training.Grounds[name]
	return g ~= nil and (g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
end

-- where a fleeing mob runs to: of a few spots round its yard, the one furthest from `from`
local function fleeSpot(m, from)
	local best, far = nil, -1
	for _ = 1, 8 do
		local p = Vector3.new(m.x + m.rng:NextNumber(-m.half, m.half), 0, m.z + m.rng:NextNumber(-m.half, m.half))
		local d = ((p - from) * Vector3.new(1, 0, 1)).Magnitude
		if d > far then
			best, far = p, d
		end
	end
	return best
end

-- the pets a biome's eggs hatch (any with odds), or none while they're only the Horse
-- placeholder
local function petsOf(biome)
	local pet = Config.Training.Grounds[biome].Pet
	if pet then
		return { pet }
	end
	local list = {}
	for kind, weight in Config.Eggs.Kinds[biome] or {} do
		if weight > 0 and kind ~= "Horse" and Config.Pets[kind] then
			table.insert(list, kind)
		end
	end
	table.sort(list)
	return list
end

local function spawnMob(name, x, z, half, slot)
	local g = Config.Training.Grounds[name]
	local rng = Random.new()
	-- what it looks like: one of the biome's pets, as big as when you ride it
	local model, size, label, tint = g.Mob, g.Size, g.Name or g.Mob, g.Tint
	local radius = g.Radius or Config.Training.MobRadius
	local def = g.Mobs and g.Mobs[(slot - 1) % #g.Mobs + 1] or {}
	local pets = petsOf(name)
	if def.Pet then
		local scale = def.Scale or 1
		model, size, label, tint = def.Pet, Pets.class(def.Pet).size * scale, def.Name or Pets.name(def.Pet), nil
		radius = math.max(Pets.stats(def.Pet).Hitbox * scale, 1.5)
	elseif #pets > 0 then
		local kind = pets[rng:NextInteger(1, #pets)]
		model, size, label, tint = kind, Pets.class(kind).size, g.Name or Pets.name(kind), nil
		radius = math.max(Pets.stats(kind).Hitbox, 1.5)
	end
	local body = Instance.new("Part")
	body.Name = name .. "Mob"
	body.Anchored, body.CanCollide, body.CanTouch = true, false, false
	body.Transparency = 1
	body.Size = Vector3.new(radius * 2, 4, radius * 2)
	local at = Vector3.new(x + rng:NextNumber(-half, half), 0 + 2, z + rng:NextNumber(-half, half))
	local yaw = rng:NextNumber(-math.pi, math.pi)
	body.CFrame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Model", model)
	body:SetAttribute("ModelSize", size)
	body:SetAttribute("Tint", tint)
	body:SetAttribute("Name", label)
	body:SetAttribute("Health", g.Health)
	body:SetAttribute("MaxHealth", g.Health)
	body:SetAttribute("Radius", radius)
	body:SetAttribute("Ground", name)
	body:SetAttribute("Slot", slot) -- (client/Shots finds its Magic by it)
	local attacks = def.Attacks or g.Attacks
	local m = {
		ground = name,
		x = x,
		z = z,
		half = half,
		wait = rng:NextNumber(0, 2),
		yaw = yaw,
		g = g,
		rng = rng,
		radius = radius,
		def = def,
		b = { c = { Attacks = attacks, Radius = radius }, foes = {} }, -- (for BossAttacks.update)
	}
	m.b.biome = m.b -- (its attacks hit only its foes: BossAttacks' fighters)
	mobs[body] = m
	Combat.add(body, function(player, damage)
		if not mobs[body] or not Training.unlocked(player, name) then
			return
		end
		Combat.train(player, damage, g.Strength)
		-- (it turns on whoever hit it last)
		if attacks then
			m.target, m.angry = player, Config.Training.Calm
			body:SetAttribute("Target", player.UserId)
		end
		local health = math.max(0, body:GetAttribute("Health") - damage)
		body:SetAttribute("Health", health)
		if health <= 0 then
			mobs[body] = nil
			Combat.remove(body)
			task.delay(0.6, body.Destroy, body)
			task.delay(Config.Training.Respawn, spawnMob, name, x, z, half, slot)
		end
	end)
	body.Parent = folder
end

-- a straw dummy: never falls, wobbles when it's hit
local function dummyTarget(model)
	local pivot = model:GetPivot()
	local body = Instance.new("Part")
	body.Name = "DummyBody"
	body.Anchored, body.CanCollide, body.CanTouch, body.CanQuery = true, false, false, false
	body.Transparency = 1
	body.Size = Vector3.new(4, 9, 4)
	body.CFrame = CFrame.new(pivot.Position.X, 5.5, pivot.Position.Z)
	body:SetAttribute("Radius", 2)
	body:SetAttribute("Health", 1)
	body:SetAttribute("MaxHealth", 1)
	body:SetAttribute("Dummy", true)
	body.Parent = folder
	local wobbling = false
	Combat.add(body, function(player, damage)
		Combat.train(player, damage, Config.Training.Grounds.Dummies.Strength)
		local character = player.Character
		if wobbling or not character then
			return
		end
		wobbling = true
		local look = (pivot.Position - character:GetPivot().Position) * Vector3.new(1, 0, 1)
		local axis = if look.Magnitude > 0.01 then Vector3.new(0, 1, 0):Cross(look.Unit) else Vector3.xAxis
		for _, angle in { 12, -6, 3, 0 } do
			local base = CFrame.new(pivot.Position.X, pivot.Position.Y, pivot.Position.Z)
			model:PivotTo(base * CFrame.fromAxisAngle(axis, math.rad(angle)) * pivot.Rotation)
			task.wait(0.06)
		end
		wobbling = false
	end)
end

function Training.start(map)
	local base
	for _, a in MapData.Areas do
		if a.Name == "Base" then
			base = a
		end
	end
	for _, t in base.Training do
		local name, x, z = t[1], t[2], t[3]
		local g = Config.Training.Grounds[name]
		local zone = map.Base.Training:FindFirstChild(name)
		if g and zone then
			local half = base.TrainSize / 2 + (g.Grow or 0) * Config.Training.Tile / 2 - 6
			if g.Count then
				for slot = 1, g.Count do
					spawnMob(name, x, z, half, slot)
				end
			end
			local dummies = zone:FindFirstChild("Dummies")
			for _, d in if dummies then dummies:GetChildren() else {} do
				dummyTarget(d)
			end
			-- buying it: the prompt at its gate
			local gate = zone:FindFirstChild("Gate")
			if gate and g.Cost > 0 then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Unlock"
				prompt.ActionText = "Unlock ($" .. tostring(g.Cost) .. ")"
				prompt.ObjectText = (Config.Regions.Names[name] or name) .. " Training"
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = gate
				prompt.Triggered:Connect(function(player)
					if Training.unlocked(player, name) then
						return
					end
					local cash = player:GetAttribute("Cash") or 0
					if cash >= g.Cost then
						player:SetAttribute("Cash", cash - g.Cost)
						player:SetAttribute("Train" .. name, true)
					end
				end)
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for body, m in mobs do
			-- angry: after whoever hit it, while they're alive, near its yard and still hitting
			if m.target then
				m.angry -= dt
				local f = m.target.Parent and BossAttacks.fighter(m.target)
				local away = f and math.max(math.abs(f.root.Position.X - m.x), math.abs(f.root.Position.Z - m.z))
				if not f or m.angry <= 0 or away > m.half + 12 then
					m.target, m.goal, m.wait = nil, nil, m.rng:NextNumber(1, 3)
					m.b.timers, m.b.still, m.b.foes, m.flee = nil, nil, {}, nil
					body:SetAttribute("Target", nil)
				else
					m.b.foes = { f }
					local hold = BossAttacks.update(body, m.b, dt, m.b.foes)
					local pos = body.Position
					local offset = (f.root.Position - pos) * Vector3.new(1, 0, 1)
					local gap = offset.Magnitude - m.radius - f.extra - 1
					local step = m.g.Speed * Config.Training.Chase * dt
					local mode = m.def.Mode
					-- which way it heads: at you (Melee), to Keep studs off (Range), or away (Flee)
					local move = Vector3.zero
					if mode == "Flee" then
						m.fleeIn = (m.fleeIn or 0) - dt
						if not m.flee or m.fleeIn <= 0 or ((m.flee - pos) * Vector3.new(1, 0, 1)).Magnitude < 1 then
							m.flee, m.fleeIn = fleeSpot(m, f.root.Position), 0.8
						end
						local to = (m.flee - pos) * Vector3.new(1, 0, 1)
						if to.Magnitude > 0.01 then
							move = to.Unit * math.min(step, to.Magnitude)
						end
					elseif mode == "Range" then
						local keep = m.def.Keep or 14
						if gap > keep + 3 then
							move = offset.Unit * math.min(step, gap - keep)
						elseif gap < keep - 3 and offset.Magnitude > 0.01 then
							move = -offset.Unit * step
						end
					elseif gap > 0 then
						move = offset.Unit * math.min(step, gap)
					end
					-- (it faces you, except running away, when it faces where it's going)
					local look = if mode == "Flee" and move.Magnitude > 0.01 then move else offset
					local want = math.atan2(-look.X, -look.Z)
					if not hold then
						m.yaw += ((want - m.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 6))
						pos += move
					end
					-- (it stays in its yard)
					pos = Vector3.new(
						math.clamp(pos.X, m.x - m.half, m.x + m.half),
						pos.Y,
						math.clamp(pos.Z, m.z - m.half, m.z + m.half)
					)
					body.CFrame = CFrame.new(pos) * CFrame.Angles(0, m.yaw, 0)
					continue
				end
			end
			if m.wait > 0 then
				m.wait -= dt
				continue
			end
			local pos = body.Position
			if not m.goal then
				m.goal =
					Vector3.new(m.x + m.rng:NextNumber(-m.half, m.half), pos.Y, m.z + m.rng:NextNumber(-m.half, m.half))
			end
			local offset = (m.goal - pos) * Vector3.new(1, 0, 1)
			if offset.Magnitude < 0.5 then
				m.goal = nil
				m.wait = m.rng:NextNumber(1, 4)
				continue
			end
			local want = math.atan2(-offset.X, -offset.Z)
			m.yaw += ((want - m.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 5))
			pos += offset.Unit * math.min(m.g.Speed * dt, offset.Magnitude)
			body.CFrame = CFrame.new(pos) * CFrame.Angles(0, m.yaw, 0)
		end
	end)

	local function joined(player)
		for name, g in Config.Training.Grounds do
			player:SetAttribute("Train" .. name, g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Training
