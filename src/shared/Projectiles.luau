-- Ranged and Magic shots, as plain maths: the server runs them to deal the damage
-- (Server/Combat) and every client runs the same ones to draw them (client/Shots), so
-- nothing about a shot is replicated but the trigger (who, which weapon, which way).
--
-- A shot flies flat from the rider, at its weapon's Speed, until it's gone its Range or
-- hit as many targets as it may (1 + Pierce). A Magic shot with Homing bends toward the
-- nearest target ahead of it (within its HomingCone) by up to Homing degrees a
-- second: enough to curve onto a target that's moving, not enough to turn round. Targets
-- are flat circles: { body, pos, radius } (a boss's or mob's body and its Radius), so a
-- shot hits whatever height it flies at; Config.Shots.Slack widens every one a little.
--
--   Projectiles.spawn(id, origin, yaw, seed) -> { shot, ... }   -- a weapon's volley
--   Projectiles.step(shot, dt, targets) -> { target, ... } -- what it hit this step;
--                                                         -- shot.dead once it's spent

local Config = require(script.Parent.Config)
local Weapons = require(script.Parent.Weapons.Weapons)

local Projectiles = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function dirOf(yaw)
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

function Projectiles.spawn(id, origin, yaw, seed)
	local w = Weapons.get(id) -- (with any live tuning: Weapons.tune)
	local s = w.Shot
	if not s then
		return {}
	end
	local count = math.max(1, math.floor(s.Count or 1))
	local spread = math.rad(s.Spread or 0)
	local shots = {}
	-- (a Magic shot sets off up to its Launch degrees off the aim, at random
	-- from the shot's seed, so its homing curves it in: QM; the server and every client use
	-- the same seed, so they all fly it the same way)
	local wobble = if w.Type == "Magic" then math.rad(s.Launch or 0) else 0
	local rng = Random.new(math.floor(seed or 0))
	for i = 1, count do
		local offset = if count > 1 then spread * ((i - 1) / (count - 1) - 0.5) else 0
		if wobble > 0 then
			offset += rng:NextNumber(-wobble, wobble)
		end
		table.insert(shots, {
			id = id,
			pos = origin,
			dir = dirOf(yaw + offset),
			speed = s.Speed or 100,
			left = s.Range or 50,
			radius = Config.Shots.Radius * (s.Size or 1),
			homing = math.rad(s.Homing or 0),
			hits = 1 + math.max(0, math.floor(s.Pierce or 0)),
			splash = if (s.Splash or 0) > 0 then s.Splash else nil,
			cone = math.cos(math.rad(s.HomingCone or 135)),
			hit = {}, -- [body] = true: each target only once
			age = 0,
			dead = false,
		})
	end
	return shots
end

-- the closest point of segment a-b to p, flat
local function closest(a, b, p)
	local ab = b - a
	local len2 = ab:Dot(ab)
	local t = if len2 > 1e-6 then math.clamp((p - a):Dot(ab) / len2, 0, 1) else 0
	return a + ab * t
end

function Projectiles.step(shot, dt, targets)
	if shot.dead then
		return {}
	end
	shot.age += dt
	-- homing: turn toward the nearest target ahead, up to `homing` radians a second
	if shot.homing > 0 then
		local cone = shot.cone
		local best, bestDist = nil, math.huge
		for _, t in targets do
			if not shot.hit[t.body] then
				local to = flat(t.pos - shot.pos)
				local d = to.Magnitude
				if d > 1e-3 and d < bestDist and to.Unit:Dot(shot.dir) >= cone then
					best, bestDist = to.Unit, d
				end
			end
		end
		if best then
			local angle = math.acos(math.clamp(shot.dir:Dot(best), -1, 1))
			local turn = math.min(angle, shot.homing * dt)
			if angle > 1e-4 then
				local side = if shot.dir:Cross(best).Y >= 0 then 1 else -1
				shot.dir = (CFrame.Angles(0, side * turn, 0) * shot.dir).Unit
			end
		end
	end
	local move = math.min(shot.speed * dt, shot.left)
	local from = shot.pos
	local to = from + shot.dir * move
	shot.left -= move
	local hits = {}
	-- what it passed through this step, nearest first
	for _, t in targets do
		if not shot.hit[t.body] then
			local p = flat(t.pos)
			local c = closest(flat(from), flat(to), p)
			if (c - p).Magnitude <= t.radius + shot.radius + Config.Shots.Slack then
				table.insert(hits, { t = t, d = (c - flat(from)).Magnitude, at = Vector3.new(c.X, from.Y, c.Z) })
			end
		end
	end
	table.sort(hits, function(a, b)
		return a.d < b.d
	end)
	local out = {}
	for _, h in hits do
		if shot.hits <= 0 then
			break
		end
		shot.hits -= 1
		shot.hit[h.t.body] = true
		table.insert(out, h.t)
		if shot.hits <= 0 then
			to = h.at -- (it stops where it struck)
			shot.dead = true
		end
	end
	shot.pos = to
	if shot.left <= 1e-3 then
		shot.dead = true
	end
	return out
end

return Projectiles
