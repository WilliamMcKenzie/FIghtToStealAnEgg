-- How bosses fight back (QM's progression: melee you kite and outskill, then ranged, then
-- RotMG-style "bombs" with floor indicators, then all of it). Each boss's Attacks in
-- Config.Bosses is a list of these, each on its own timer:
--
--   Contact { Every, Reach, Damage, Gentle }: everyone in the fight within Reach studs of
--         its edge takes Damage, at most every Every seconds (QM, Oct 24: all bosses, for
--         now). Gentle ones never take anyone below 1 health (unused: QM, Oct 26 wants the
--         biomes' mobs to be able to kill you).
--   Slam  { Every, Range, Radius, Windup, Damage }: when a fighter is within Range, it
--         stops, a red circle grows in front of it for Windup seconds, then everything
--         inside takes Damage. Step out of the circle.
--   Shot  { Every, Count, Spread, Speed, Size, Damage, Range }: a fan of Count glowing
--         balls (Spread degrees apart) at its target, flying Speed studs/s.
--   Nova  { Every, Count, Speed, Size, Damage, Range }: Count balls out all round it.
--   Bombs { Every, Count, Radius, Windup, Damage, Scatter }: a circle under every fighter
--         (and Count more scattered round them, up to Scatter studs off) that blows up
--         after Windup.
--
-- Only players locked into its fight (LockedIn = its biome) are hit, so someone passing
-- through is never caught. All of it is server parts in workspace.BossFx. A pet bigger
-- than the Horse is easier to hit: everything reaches its hitbox's extra (Shared/Pets).
--
--   BossAttacks.update(body, b, dt, fighters) -> true while it should stand still
--         (b: { c = { Attacks, Radius }, biome }; Server/Mobs' mobs use it too)
--   BossAttacks.fighter(player) -> { root, humanoid, extra } or nil, if they're alive

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pets"))
local HORSE_HITBOX = Pets.stats("Horse").Hitbox

local BossAttacks = {}

local fx = Instance.new("Folder")
fx.Name = "BossFx"
fx.Parent = workspace

local RED = Color3.fromRGB(255, 50, 40)
local SHOT = Color3.fromRGB(255, 140, 40)
local FLOOR_Y = 0.15

local shots = {} -- [part] = { dir, speed, travelled, range, damage, radius, biome }

-- a living player's root, humanoid and extra: how much further their pet's hitbox reaches
-- than the Horse's
local function fighter(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		local extra = Pets.stats(player:GetAttribute("Pet") or "Horse").Hitbox - HORSE_HITBOX
		return { root = root, humanoid = humanoid, extra = extra }
	end
	return nil
end
BossAttacks.fighter = fighter

-- every living root of a player in this biome's fight
local function fighters(biome)
	local out = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("LockedIn") == biome then
			local f = fighter(player)
			if f then
				table.insert(out, f)
			end
		end
	end
	return out
end
BossAttacks.fighters = fighters

local function flat(v)
	return v * Vector3.new(1, 0, 1)
end

-- the ground's height under a point (the map's floors, walls excluded)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local function groundAt(position)
	local floor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Floor")
	if not floor then
		return 0
	end
	params.FilterDescendantsInstances = { floor }
	local hit = workspace:Raycast(Vector3.new(position.X, 30, position.Z), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else 0
end

-- a flat red circle on the ground that fills over `windup`, then hurts everyone in the
-- fight inside it
local function circle(biome, centre, radius, windup, damage)
	local y = groundAt(centre) + FLOOR_Y
	local function disc(name, r, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = RED
		p.Transparency = transparency
		p.Size = Vector3.new(0.2, r * 2, r * 2)
		p.CFrame = CFrame.new(centre.X, y, centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
		p.Parent = fx
		return p
	end
	local rim = disc("Warning", radius, 0.75)
	local fill = disc("WarningFill", 0.2, 0.45)
	fill.CFrame += Vector3.new(0, 0.02, 0)
	TweenService
		:Create(
			fill,
			TweenInfo.new(windup, Enum.EasingStyle.Linear),
			{ Size = Vector3.new(0.2, radius * 2, radius * 2) }
		)
		:Play()
	task.delay(windup, function()
		for _, f in fighters(biome) do
			if flat(f.root.Position - centre).Magnitude <= radius + 1 + f.extra then
				f.humanoid:TakeDamage(damage)
			end
		end
		rim.Transparency = 0.2
		fill:Destroy()
		TweenService
			:Create(rim, TweenInfo.new(0.25), { Transparency = 1, Size = rim.Size * Vector3.new(1, 1.15, 1.15) })
			:Play()
		task.delay(0.3, rim.Destroy, rim)
	end)
end

local function fire(biome, from, dir, a)
	local ball = Instance.new("Part")
	ball.Name = "Shot"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Material = Enum.Material.Neon
	ball.Color = SHOT
	ball.Size = Vector3.one * a.Size
	ball.Position = from + Vector3.new(0, 3, 0)
	ball.Parent = fx
	shots[ball] = {
		dir = dir,
		speed = a.Speed,
		travelled = 0,
		range = a.Range or 140,
		damage = a.Damage,
		radius = a.Size / 2,
		biome = biome,
	}
end

local function nearest(position, list)
	local best, bestDist = nil, math.huge
	for _, f in list do
		local d = flat(f.root.Position - position).Magnitude
		if d < bestDist then
			best, bestDist = f, d
		end
	end
	return best, bestDist
end

function BossAttacks.update(body, b, dt, list)
	local attacks = b.c.Attacks
	if not attacks then
		return false
	end
	b.timers = b.timers or {}
	b.still = math.max(0, (b.still or 0) - dt)
	local pos = body.Position * Vector3.new(1, 0, 1)
	local target, distance = nearest(pos, list)
	if not target then
		return b.still > 0
	end
	local edge = distance - b.c.Radius
	for i, a in attacks do
		-- (staggered starts, so they don't all go at once)
		b.timers[i] = (b.timers[i] or a.Every * (0.5 + i * 0.25)) - dt
		if b.timers[i] > 0 or b.still > 0 then
			continue
		end
		local toward = flat(target.root.Position - pos)
		toward = if toward.Magnitude > 0.01 then toward.Unit else Vector3.new(0, 0, -1)
		if a.Kind == "Contact" then
			-- too close and it hurts: everyone within Reach of its edge, every Every seconds
			local hit = false
			for _, f in list do
				if flat(f.root.Position - pos).Magnitude - b.c.Radius - f.extra <= a.Reach then
					local damage = if a.Gentle then math.min(a.Damage, f.humanoid.Health - 1) else a.Damage
					if damage > 0 then
						f.humanoid:TakeDamage(damage)
					end
					hit = true
				end
			end
			if hit then
				b.timers[i] = a.Every
			end
		elseif a.Kind == "Slam" then
			if edge <= a.Range then
				b.timers[i] = a.Every
				b.still = a.Windup + 0.25
				circle(b.biome, pos + toward * (b.c.Radius + a.Radius * 0.55), a.Radius, a.Windup, a.Damage)
			end
		elseif a.Kind == "Shot" then
			b.timers[i] = a.Every
			for k = 1, a.Count do
				local angle = math.rad((k - (a.Count + 1) / 2) * a.Spread)
				fire(b.biome, pos + toward * b.c.Radius, CFrame.Angles(0, angle, 0):VectorToWorldSpace(toward), a)
			end
		elseif a.Kind == "Nova" then
			b.timers[i] = a.Every
			local spin = math.random() * math.pi
			for k = 1, a.Count do
				local angle = spin + k / a.Count * 2 * math.pi
				local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
				fire(b.biome, pos + dir * b.c.Radius, dir, a)
			end
		elseif a.Kind == "Bombs" then
			b.timers[i] = a.Every
			for _, f in list do
				circle(b.biome, flat(f.root.Position), a.Radius, a.Windup, a.Damage)
			end
			for _ = 1, a.Count do
				local f = list[math.random(1, #list)]
				local off = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * a.Scatter
				circle(b.biome, flat(f.root.Position) + off, a.Radius, a.Windup, a.Damage)
			end
		end
	end
	return b.still > 0
end

RunService.Heartbeat:Connect(function(dt)
	for ball, s in shots do
		local step = s.speed * dt
		ball.Position += s.dir * step
		s.travelled += step
		local hit = false
		for _, f in fighters(s.biome) do
			if flat(f.root.Position - ball.Position).Magnitude <= s.radius + 1.5 + f.extra then
				f.humanoid:TakeDamage(s.damage)
				hit = true
				break
			end
		end
		if hit or s.travelled >= s.range then
			shots[ball] = nil
			ball:Destroy()
		end
	end
end)

return BossAttacks
