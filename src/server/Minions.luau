-- A boss's helpers (QM, Oct 27, trying it on the Cactus Boss first): once it's down to
-- its Minions.At share of health it calls up Minions.Count of them (Config.Bosses[kind]
-- .Minions), dropping out of the sky round it (QM, Oct 30). Each is an invisible body in
-- workspace.Mobs (attributes Model, ModelSize, Name, Health, MaxHealth, Radius, Biome,
-- Minion, and Drop, DropAt, DropFrom, Dust: client/BossView drops it from DropFrom studs
-- up over Drop seconds from server time DropAt), drawn like a training mob. It can't be
-- hit or bite till it's landed. They chase the nearest player in the boss's fight round its
-- arena and bite with their Attacks (Server/BossAttacks, like the boss's), and hitting one
-- trains its Strength. They all crumble when their boss's fight ends, however it ends.
--
--   Minions.call(boss, b)    -- the boss's minions arrive (b: its Server/Bosses entry)
--   Minions.clear(biome)     -- every minion of that biome's fight goes

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Horse = require(Shared.Animals.Horse)
local Pets = require(Shared.Pets)
local BossAttacks = require(script.Parent.BossAttacks)
local Combat = require(script.Parent.Combat)

local Minions = {}

local live = {} -- [body] = { m (its Config), biome, bounds, yaw, b (for BossAttacks) }

-- (training mobs live in workspace.Mobs too: Server/Training makes it)
local function folder()
	local f = workspace:FindFirstChild("Mobs")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Mobs"
		f.Parent = workspace
	end
	return f
end

local function kill(body)
	local e = live[body]
	live[body] = nil
	Combat.remove(body)
	-- (the last of a Shield boss's troops down: it can be hurt again)
	if e and e.boss and e.boss.Parent then
		local left = false
		for _, other in live do
			if other.boss == e.boss then
				left = true
			end
		end
		if not left then
			e.boss:SetAttribute("Shielded", nil)
		end
	end
	body:SetAttribute("Health", 0) -- (clients play its death)
	task.delay(0.6, body.Destroy, body)
end

-- its model and size: a pet's (Scale x its riding size), or a model of its own (Size x its
-- drawing; its StandIn pet till that's made)
local function look(m)
	local own = Shared.Animals:FindFirstChild(m.Model .. "Model")
	local class = Pets.class(m.Model)
	if class then
		return m.Model, class.size * (m.Scale or 1), class.data
	elseif own then
		return m.Model, m.Size or 1, require(own)
	end
	local stand = Pets.class(m.StandIn[1])
	return m.StandIn[1], stand.size * m.StandIn[2], stand.data
end

local function spawnOne(m, biome, bounds, at, yaw, boss)
	local model, size, data = look(m)
	local box = Horse.extent(data) * size
	local radius = m.Radius or math.max(math.sqrt(box.X * box.Z) / 2, 1.5)
	local body = Instance.new("Part")
	body.Name = "Minion"
	body.Anchored, body.CanCollide, body.CanTouch = true, false, false
	body.Transparency = 1
	body.Size = Vector3.new(radius * 2, 4, radius * 2)
	body.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Model", model)
	body:SetAttribute("ModelSize", size)
	body:SetAttribute("Name", m.Name or Pets.name(m.Model))
	body:SetAttribute("Health", m.Health)
	body:SetAttribute("MaxHealth", m.Health)
	body:SetAttribute("Radius", radius)
	body:SetAttribute("Biome", biome)
	body:SetAttribute("Minion", true)
	local drop = m.Drop or 0.8
	body:SetAttribute("Drop", drop)
	body:SetAttribute("DropAt", workspace:GetServerTimeNow())
	body:SetAttribute("DropFrom", m.DropFrom or 60)
	body:SetAttribute("Dust", m.Dust)
	local entry = {
		m = m,
		biome = biome,
		bounds = bounds,
		yaw = yaw,
		radius = radius,
		boss = if m.Shield then boss else nil, -- (it shields this boss while it lives)
		-- (not biting till it's landed)
		wait = drop,
		b = { c = { Attacks = m.Attacks, Radius = radius }, biome = biome },
	}
	live[body] = entry
	body.Parent = folder()
	-- (no hitting it in mid-air)
	task.delay(drop, function()
		if not live[body] then
			return
		end
		Combat.add(body, function(player, damage)
			if not live[body] then
				return
			end
			Combat.train(player, damage, m.Strength or 1)
			local health = math.max(0, body:GetAttribute("Health") - damage)
			body:SetAttribute("Health", health)
			if health <= 0 then
				kill(body)
			end
		end)
	end)
end

function Minions.call(boss, b)
	local m = b.c.Minions
	if not (m and b.biome) then
		return
	end
	local centre = boss.Position * Vector3.new(1, 0, 1)
	local spin = math.random() * 2 * math.pi
	for k = 1, m.Count do
		-- (round it, evenly, a little way out from its edge)
		local angle = spin + k / m.Count * 2 * math.pi
		local at = centre + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (b.c.Radius + (m.Spread or 10))
		if b.bounds then
			local x0, x1 = math.min(b.bounds[1], b.bounds[3]) + 4, math.max(b.bounds[1], b.bounds[3]) - 4
			local z0, z1 = math.min(b.bounds[2], b.bounds[4]) + 4, math.max(b.bounds[2], b.bounds[4]) - 4
			at = Vector3.new(math.clamp(at.X, x0, x1), 0, math.clamp(at.Z, z0, z1))
		end
		-- (facing outward, the way it's about to go)
		spawnOne(m, b.biome, b.bounds, at, math.atan2(-math.cos(angle), -math.sin(angle)), boss)
	end
	-- (its call: an animation of its own, if it has one; it stands still till they've landed)
	BossAttacks.animate(boss, m, 0)
	BossAttacks.root(b, (m.Drop or 0.8) + 0.4)
	-- (a Shield: it can't be hurt till they're all down, raid style: client/BossView's bubble)
	if m.Shield then
		boss:SetAttribute("Shielded", true)
	end
end

function Minions.clear(biome)
	for body, e in live do
		if e.biome == biome then
			kill(body)
		end
	end
end

-- the nearest living player in this biome's fight
local function nearest(position, biome)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("LockedIn") == biome then
			local f = BossAttacks.fighter(player)
			if f then
				local d = ((f.root.Position - position) * Vector3.new(1, 0, 1)).Magnitude
				if d < bestDist then
					best, bestDist = f, d
				end
			end
		end
	end
	return best, bestDist
end

RunService.Heartbeat:Connect(function(dt)
	for body, e in live do
		if e.wait > 0 then
			e.wait -= dt
			continue
		end
		local pos = body.Position
		local target, distance = nearest(pos, e.biome)
		if not target then
			continue
		end
		local hold = BossAttacks.update(body, e.b, dt, BossAttacks.fighters(e.biome))
		local offset = (target.root.Position - pos) * Vector3.new(1, 0, 1)
		-- (rooted: it holds still, or turns to face its Swipe)
		local want = if (e.b.rooted or 0) > 0 then e.b.facing or e.yaw else math.atan2(-offset.X, -offset.Z)
		e.yaw += ((want - e.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 6))
		local gap = distance - e.radius - target.extra - 1
		if not hold and gap > 0 then
			pos += offset.Unit * math.min(e.m.Speed * dt, gap)
		end
		if e.bounds then
			local r = e.radius + 2
			local x0, x1 = math.min(e.bounds[1], e.bounds[3]) + r, math.max(e.bounds[1], e.bounds[3]) - r
			local z0, z1 = math.min(e.bounds[2], e.bounds[4]) + r, math.max(e.bounds[2], e.bounds[4]) - r
			pos = Vector3.new(math.clamp(pos.X, x0, x1), pos.Y, math.clamp(pos.Z, z0, z1))
		end
		body.CFrame = CFrame.new(pos) * CFrame.Angles(0, e.yaw, 0)
	end
end)

return Minions
