-- The training grounds (QM, Oct 30: regions now, not pens): one region per biome off the
-- base, joined to it by a corridor through the base wall (Ice and Meadow west, Lava and
-- Desert east; the Base area's Training in the map: each one's bounds). Strength only
-- ever comes from attacking (Server/Combat): each hit trains the enemy's Strength
-- (Config.Training.Grounds), so these are for standing and swinging, RuneScape sand-crab
-- style. A ground is shut off by a blocker at its corridor, like a boss region's, until
-- you buy it (Cost in cash, the Buy button on the blocker: Server/Regions; player
-- attribute Train<Name>, which a rebirth will clear).
--
-- Mobs are invisible bodies in workspace.Mobs (attributes Model, ModelSize, Tint, Name,
-- Health, MaxHealth, Radius, Ground), drawn by client/BossView.luau like the bosses.
-- They roam their region's floor (never through its walls); one that falls is back
-- Respawn seconds later somewhere else in it. Hit one and
-- it fights back (QM, Oct 26): it follows whoever last hit it round its region and bites
-- with its Attacks (Config.Training.Grounds, run by Server/BossAttacks like a boss's),
-- hard enough to kill you (QM, Oct 26), until you leave the region, die, or stop hitting it
-- for Config.Training.Calm seconds. Each mob is a random pet from its biome's eggs
-- (Config.Eggs.Kinds), as big as when you ride it, or (QM, Oct 30) its ground's Mobs taking
-- turns: Meadow pigs and fish, Desert cactus monsters and scorpions that keep their
-- distance casting sand, Tundra boars, snowmen casting snow and penguins that run from you
-- lobbing bombs, Lava fire boars and firebirds casting fire. A mob's Magic and bombs
-- only ever hit whoever it's angry with (its b.foes). Only players inside a region can
-- hit what's in it (QM, Oct 30: each body carries its region's bounds for Shared/Yards;
-- Server/Combat drops hits from outside).
--
--   Training.start()   -- once, after Map.ensure()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapData = require(ReplicatedStorage.Shared.MapData)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Yards = require(ReplicatedStorage.Shared.Yards)
local Combat = require(script.Parent.Combat)
local BossAttacks = require(script.Parent.BossAttacks)

local Training = {}

local folder = Instance.new("Folder")
folder.Name = "Mobs"
folder.Parent = workspace

local mobs = {} -- [body] = { ground, zone, goal, wait, yaw, g, rng, radius, target, angry, b }

-- ---- the regions' floors ------------------------------------------------------------------

local GRID = MapData.Grid
local zones = {} -- [ground] = { bounds = { x0, z0, x1, z1 }, cells = { Vector3 } (each floor cell's centre) }

-- floor a mob can stand on: a tile there that isn't a wall, inside its region
local function floorAt(zone, x, z)
	local b = zone.bounds
	if x < b[1] or x > b[3] or z < b[2] or z > b[4] then
		return false
	end
	local c = math.floor((x - GRID.X0) / GRID.Cell) + 1
	local r = math.floor((z - GRID.Z0) / GRID.Cell) + 1
	local row = GRID.Rows[r]
	local tile = row and c >= 1 and c <= GRID.Cols and GRID.Tiles[string.sub(row, c, c)]
	return tile ~= nil and tile ~= false and not tile.wall
end

-- room for a body `radius` across at (x, z): floor under its middle and its sides
local function room(zone, x, z, radius)
	local r = radius * 0.7
	return floorAt(zone, x, z)
		and floorAt(zone, x + r, z)
		and floorAt(zone, x - r, z)
		and floorAt(zone, x, z + r)
		and floorAt(zone, x, z - r)
end

-- a straight walk from a to b that stays on the floor
local function clear(zone, a, b, radius)
	local d = (b - a) * Vector3.new(1, 0, 1)
	local n = math.max(1, math.ceil(d.Magnitude / 2))
	for i = 1, n do
		local p = a + d * (i / n)
		if not room(zone, p.X, p.Z, radius) then
			return false
		end
	end
	return true
end

local function zoneOf(name, bounds)
	local x0, z0 = math.min(bounds[1], bounds[3]), math.min(bounds[2], bounds[4])
	local x1, z1 = math.max(bounds[1], bounds[3]), math.max(bounds[2], bounds[4])
	local zone = { bounds = { x0, z0, x1, z1 }, cells = {} }
	local half = GRID.Cell / 2
	for x = x0 + half, x1 - half, GRID.Cell do
		for z = z0 + half, z1 - half, GRID.Cell do
			-- (a cell with floor all round it, so a mob there isn't half in a wall)
			if room(zone, x, z, GRID.Cell * 1.4) then
				table.insert(zone.cells, Vector3.new(x, 0, z))
			end
		end
	end
	zones[name] = zone
	return zone
end

-- a random spot on the region's floor (one of its cells, anywhere in it)
local function spotIn(zone, rng)
	local c = zone.cells[rng:NextInteger(1, #zone.cells)]
	return c + Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
end

function Training.unlocked(player, name)
	local g = Config.Training.Grounds[name]
	return g ~= nil and (g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
end

-- where a fleeing mob runs to: of a few spots it can run straight to, the one furthest from `from`
local function fleeSpot(m, at, from)
	local best, far = nil, -1
	for _ = 1, 12 do
		local p = at + Vector3.new(m.rng:NextNumber(-30, 30), 0, m.rng:NextNumber(-30, 30))
		if clear(m.zone, at, p, m.wide) then
			local d = ((p - from) * Vector3.new(1, 0, 1)).Magnitude
			if d > far then
				best, far = p, d
			end
		end
	end
	return best or at
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

-- (whoever's hitting it is standing in its region)
local function fromInside(player, body)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and Yards.inside(body, root.Position)
end

local function spawnMob(name, zone, slot)
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
	local at = spotIn(zone, rng) + Vector3.new(0, 2, 0)
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
	Yards.stamp(body, zone.bounds)
	local attacks = def.Attacks or g.Attacks
	local m = {
		ground = name,
		zone = zone,
		wide = math.min(radius, 3.5), -- (how far off a wall it keeps: a big pet's hitbox would keep it out of corridors)
		wait = rng:NextNumber(0, 2),
		yaw = yaw,
		g = g,
		rng = rng,
		radius = radius,
		def = def,
		b = { c = { Attacks = attacks, Radius = radius }, foes = {} }, -- (for BossAttacks.update)
	}
	m.b.biome = m.b -- (its attacks hit only its foes: BossAttacks' fighters)
	m.b.region = name -- (its swipes' size: Config.EnemySwipe.Scale)
	mobs[body] = m
	Combat.add(body, function(player, damage)
		if not mobs[body] or not Training.unlocked(player, name) or not fromInside(player, body) then
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
			task.delay(Config.Training.Respawn, spawnMob, name, zone, slot)
		end
	end)
	body.Parent = folder
end

function Training.start()
	local base
	for _, a in MapData.Areas do
		if a.Name == "Base" then
			base = a
		end
	end
	for _, t in base.Training or {} do
		local name = t[1]
		local g = Config.Training.Grounds[name]
		if g and #t >= 5 then
			local zone = zoneOf(name, { t[2], t[3], t[4], t[5] })
			if #zone.cells > 0 then
				for slot = 1, g.Count or 0 do
					spawnMob(name, zone, slot)
				end
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for body, m in mobs do
			-- angry: after whoever hit it, while they're alive, in its region and still hitting
			if m.target then
				m.angry -= dt
				local f = m.target.Parent and BossAttacks.fighter(m.target)
				if not f or m.angry <= 0 or not Yards.inside(body, f.root.Position) then
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
							m.flee, m.fleeIn = fleeSpot(m, pos, f.root.Position), 0.8
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
					-- (winding up a Swipe it turns to face it; any other hold, it stays as it is)
					local face = if (m.b.rooted or 0) > 0 then m.b.facing else nil
					if face or not hold then
						want = face or want
						local rate = if face then 14 else 6
						m.yaw += ((want - m.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * rate))
					end
					local from = pos
					if not hold then
						pos += move
					end
					pos = Combat.pushed(body, pos, dt) -- (knocked back by a Smash sprint)
					-- (it stays on its region's floor: sliding along a wall it runs into)
					if not room(m.zone, pos.X, pos.Z, m.wide) then
						if room(m.zone, pos.X, from.Z, m.wide) then
							pos = Vector3.new(pos.X, pos.Y, from.Z)
						elseif room(m.zone, from.X, pos.Z, m.wide) then
							pos = Vector3.new(from.X, pos.Y, pos.Z)
						else
							pos = from
						end
					end
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
				-- (somewhere not far off it can walk straight to)
				local goal = pos + Vector3.new(m.rng:NextNumber(-24, 24), 0, m.rng:NextNumber(-24, 24))
				if not clear(m.zone, pos, goal, m.wide) then
					m.wait = m.rng:NextNumber(0.2, 0.6)
					continue
				end
				m.goal = goal
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
