-- The enemies out in the biomes (QM, Oct 26: they replace the training grounds). Each
-- biome keeps Config.Mobs.Biomes[biome].Count of its mob wandering its floor (Meadow pigs,
-- Desert sand crabs, Ice penguins, Lava rock hogs), and you farm Strength off them where
-- you fight: each hit trains the enemy's Strength (Server/Combat). One that falls is
-- replaced Config.Mobs.Respawn seconds later, somewhere on its biome's floor away from
-- everyone, but not while that biome's boss is out (someone stole one of its eggs:
-- Server/Eggs, Server/Bosses); the ones already there stay, and the biome fills up again
-- once the boss is dead or has gone home.
--
-- They're a threat, well under a boss (QM, Oct 26): come within Aggro of one, or hit it,
-- and it chases you (Chase x its Speed) and bites with its Attacks (Server/BossAttacks'
-- Contact, like the bosses), hard enough to kill you, until you're dead, Leash studs from
-- where it spawned, or out of its Aggro and not hitting it for Calm seconds.
--
-- Mobs are invisible bodies in workspace.Mobs (attributes Model, ModelSize, Tint, Name,
-- Health, MaxHealth, Radius, Biome), drawn by client/BossView.luau like the bosses.
--
--   Mobs.start(map)   -- once, after Map.ensure()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapData = require(ReplicatedStorage.Shared.MapData)
local Combat = require(script.Parent.Combat)
local Bosses = require(script.Parent.Bosses)
local BossAttacks = require(script.Parent.BossAttacks)

local Mobs = {}

local folder = Instance.new("Folder")
folder.Name = "Mobs"
folder.Parent = workspace

local C = Config.Mobs
local mobs = {} -- [body] = { biome, home, goal, wait, yaw, g, rng, radius, target, angry, b }
local zones = {} -- [biome] = { cells (walkable cell centres), bounds, count, due (respawn timers) }

-- ---- the floor ---------------------------------------------------------------------------

-- the map's cell under a point: its tile (from the .map file), or nil off the map
local grid = MapData.Grid
local function tileAt(x, z)
	local c = math.floor((x - grid.X0) / grid.Cell) + 1
	local r = math.floor((z - grid.Z0) / grid.Cell) + 1
	local row = grid.Rows[r]
	if not row or c < 1 or c > #row then
		return nil
	end
	return grid.Tiles[string.sub(row, c, c)]
end

-- where a body stands over a point (its 4-stud-tall box's middle), or nil over a wall
local function standY(x, z)
	local t = tileAt(x, z)
	if not t or t.wall then
		return nil
	end
	local top = if t.liquid then t.top - Config.Map.LiquidSink else t.top
	return top + 2
end

-- every dry, open cell of a biome at least Edge in from its bounds (so none spawn in its
-- gateways)
local function walkable(biome, bounds)
	local x0, x1 = math.min(bounds[1], bounds[3]) + C.Edge, math.max(bounds[1], bounds[3]) - C.Edge
	local z0, z1 = math.min(bounds[2], bounds[4]) + C.Edge, math.max(bounds[2], bounds[4]) - C.Edge
	local cells = {}
	for r, row in grid.Rows do
		local z = grid.Z0 + (r - 0.5) * grid.Cell
		if z >= z0 and z <= z1 then
			for c = 1, #row do
				local x = grid.X0 + (c - 0.5) * grid.Cell
				local t = grid.Tiles[string.sub(row, c, c)]
				if x >= x0 and x <= x1 and t and t.area == biome and not t.wall and not t.liquid then
					table.insert(cells, Vector3.new(x, t.top + 2, z))
				end
			end
		end
	end
	return cells
end

local function flat(v)
	return v * Vector3.new(1, 0, 1)
end

-- ---- spawning ----------------------------------------------------------------------------

local function alive(player)
	return player.Parent and BossAttacks.fighter(player)
end

-- a spot on the biome's floor with nobody within Clear (or the best of a few tries)
local function spot(zone, rng)
	local best, bestGap = nil, -1
	for _ = 1, 12 do
		local at = zone.cells[rng:NextInteger(1, #zone.cells)]
		local gap = math.huge
		for _, player in Players:GetPlayers() do
			local f = alive(player)
			if f then
				gap = math.min(gap, flat(f.root.Position - at).Magnitude)
			end
		end
		if gap >= C.Clear then
			return at
		elseif gap > bestGap then
			best, bestGap = at, gap
		end
	end
	return best
end

local function spawnMob(biome)
	local zone = zones[biome]
	local g = C.Biomes[biome]
	local rng = Random.new()
	local at = spot(zone, rng)
	local radius = g.Radius or C.MobRadius
	local body = Instance.new("Part")
	body.Name = biome .. "Mob"
	body.Anchored, body.CanCollide, body.CanTouch = true, false, false
	body.Transparency = 1
	body.Size = Vector3.new(radius * 2, 4, radius * 2)
	local yaw = rng:NextNumber(-math.pi, math.pi)
	body.CFrame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Model", g.Mob)
	body:SetAttribute("ModelSize", g.Size)
	body:SetAttribute("Tint", g.Tint)
	body:SetAttribute("Name", g.Name or g.Mob)
	body:SetAttribute("Health", g.Health)
	body:SetAttribute("MaxHealth", g.Health)
	body:SetAttribute("Radius", radius)
	body:SetAttribute("Biome", biome)
	local m = {
		biome = biome,
		home = at,
		wait = rng:NextNumber(0, 2),
		yaw = yaw,
		g = g,
		rng = rng,
		radius = radius,
		b = { c = { Attacks = g.Attacks, Radius = radius } }, -- (for BossAttacks.update)
	}
	mobs[body] = m
	zone.count += 1
	Combat.add(body, function(player, damage)
		if not mobs[body] then
			return
		end
		Combat.train(player, damage, g.Strength)
		-- (it turns on whoever hit it last)
		m.target, m.angry = player, C.Calm
		local health = math.max(0, body:GetAttribute("Health") - damage)
		body:SetAttribute("Health", health)
		if health <= 0 then
			mobs[body] = nil
			zone.count -= 1
			table.insert(zone.due, C.Respawn)
			Combat.remove(body)
			task.delay(0.6, body.Destroy, body)
		end
	end)
	body.Parent = folder
end

-- ---- moving ------------------------------------------------------------------------------

-- step toward a point, turning to face it; it stays in its biome and off the walls
-- -> how far the point was, and whether it got anywhere (false: a wall's in the way)
local function walk(body, m, goal, speed, dt, stopAt)
	local pos = body.Position
	local offset = flat(goal - pos)
	local want = math.atan2(-offset.X, -offset.Z)
	m.yaw += ((want - m.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 6))
	local left = offset.Magnitude - (stopAt or 0)
	local moved = false
	if left > 0 then
		local step = offset.Unit * math.min(speed * dt, left)
		local bounds = zones[m.biome].bounds
		local x = math.clamp(pos.X + step.X, math.min(bounds[1], bounds[3]), math.max(bounds[1], bounds[3]))
		local z = math.clamp(pos.Z + step.Z, math.min(bounds[2], bounds[4]), math.max(bounds[2], bounds[4]))
		local y = standY(x, z)
		if y then
			pos, moved = Vector3.new(x, y, z), true
		end
	end
	body.CFrame = CFrame.new(pos) * CFrame.Angles(0, m.yaw, 0)
	return offset.Magnitude, moved
end

-- the nearest living player within Aggro of its edge, near enough its home to chase
local function noticed(body, m)
	local best, bestDist = nil, C.Aggro
	for _, player in Players:GetPlayers() do
		local f = alive(player)
		if f and flat(f.root.Position - m.home).Magnitude <= C.Leash then
			local d = flat(f.root.Position - body.Position).Magnitude - m.radius - f.extra
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

function Mobs.start(_map)
	for _, area in MapData.Areas do
		local g = C.Biomes[area.Name]
		if g and area.Bounds then
			local cells = walkable(area.Name, area.Bounds)
			if #cells > 0 then
				zones[area.Name] = { cells = cells, bounds = area.Bounds, count = 0, due = {} }
				for _ = 1, g.Count do
					spawnMob(area.Name)
				end
			else
				warn("Mobs: no open floor in " .. area.Name)
			end
		end
	end

	local look = 0
	RunService.Heartbeat:Connect(function(dt)
		-- refilling: each fallen mob's timer runs down, then (with no boss out) one comes back
		for biome, zone in zones do
			local out = Bosses.out(biome)
			for i = #zone.due, 1, -1 do
				zone.due[i] -= dt
				if zone.due[i] <= 0 and not out then
					table.remove(zone.due, i)
					if zone.count < C.Biomes[biome].Count then
						spawnMob(biome)
					end
				end
			end
		end

		look -= dt
		local scan = look <= 0
		if scan then
			look = 0.25
		end
		for body, m in mobs do
			-- (a few times a second: is anyone close enough to notice?)
			if scan then
				local near = noticed(body, m)
				if near and (m.target == nil or m.target == near) then
					m.target, m.angry = near, C.Calm
				end
			end
			if m.target then
				m.angry -= dt
				local f = alive(m.target)
				if not f or m.angry <= 0 or flat(f.root.Position - m.home).Magnitude > C.Leash then
					m.target, m.goal, m.wait = nil, nil, m.rng:NextNumber(1, 3)
					m.b.timers, m.b.still = nil, nil
				else
					local hold = BossAttacks.update(body, m.b, dt, { f })
					walk(body, m, f.root.Position, if hold then 0 else m.g.Speed * C.Chase, dt, m.radius + f.extra + 1)
					continue
				end
			end
			-- wandering near where it spawned
			if m.wait > 0 then
				m.wait -= dt
				continue
			end
			if not m.goal then
				local zone = zones[m.biome]
				for _ = 1, 6 do
					local at = zone.cells[m.rng:NextInteger(1, #zone.cells)]
					if flat(at - m.home).Magnitude <= C.Leash / 2 then
						m.goal = at
						break
					end
				end
				m.goal = m.goal or m.home
			end
			local far, moved = walk(body, m, m.goal, m.g.Speed, dt)
			if far < 0.5 or not moved then
				m.goal = nil
				m.wait = m.rng:NextNumber(1, 4)
			end
		end
	end)
end

return Mobs
