-- How bosses fight back (QM's progression: melee you kite and outskill, then ranged, then
-- RotMG-style "bombs" with floor indicators, then all of it). Each boss's Attacks in
-- Config.Bosses is a list of these, each on its own timer:
--
--   Contact { Every, Reach, Damage, Gentle }: everyone in the fight within Reach studs of
--         its edge and inside its front cone (Config.BossMelee.Cone, QM Oct 27: circle
--         behind it and its melee misses) takes Damage, at most every Every seconds (QM,
--         Oct 24: all bosses, for now). Gentle ones never take anyone below 1 health (unused: QM, Oct 26 wants the
--         training mobs to be able to kill you).
--   Slam  { Every, Range, Radius, Windup, Damage }: when a fighter is within Range, it
--         stops, a red circle grows in front of it for Windup seconds, then everything
--         inside takes Damage. Step out of the circle.
--   Shot  { Every, Count, Spread, Speed, Size, Damage, Range }: a fan of Count glowing
--         balls (Spread degrees apart) at its target, flying Speed studs/s.
--   Nova  { Every, Count, Speed, Size, Damage, Range }: Count balls out all round it.
--   Magic { Every, Like, Shot, Damage, Burst, BurstGap, Height }: a staff's volley at its
--         target, flown exactly as a player's (Shared/Projectiles, drawn by client/Shots):
--         Like is the weapon whose Shot it borrows (the Flower Staff's three orbs), Shot
--         its own values over that (weaker Homing so they can be dodged, Color, Count...).
--         Burst volleys, BurstGap seconds apart (the Sandworm's 1, 2, 3). Height: studs
--         above the ground they fly at. Every client draws them from the BossShot remote.
--   Bombs { Every, Count, Radius, Windup, Damage, Scatter }: a circle under every fighter
--         (and Count more scattered round them, up to Scatter studs off) that blows up
--         after Windup.
--   Lob   { Every, Count, Radius, Airtime, Damage, Scatter, Height, Style }: the Cactus
--         Boss's bombs (QM, Oct 27, after the bombs in QM's Kingdom game): one flung in an
--         arc at where every fighter stands now (and Count more scattered round them, up
--         to Scatter studs off), landing Airtime seconds later and hurting everyone
--         within Radius. Clients draw the bomb and its red landing ring, which fills from
--         the middle out as it comes down (client/Bombs, from the BossBomb remote).
--
--   Charge { Every, Range, Windup, Width, Length, Speed, Damage, Anim }: it stops and a red
--         rectangle Width wide runs Length studs from it toward its target, filling over
--         Windup; then it dashes down it at Speed, hurting everyone it runs into once (the
--         Majestic Unicorn's horn, the Elder Boar's tusks: QM, Oct 30, Archero's chargers).
--   Line  { Every, Range, Windup, Width, Length, Count, Spread, Segments, Gap, From, Damage,
--         Anim, Then }: Count red rectangles fanned Spread degrees apart toward its target,
--         filling over Windup, then everyone on one is hit (tail stabs, ice lances, fire
--         breath, roots, beams). From "Target" centres each on where you stand instead of
--         starting at its edge. Segments more lay end to end beyond the first, each going
--         off Gap seconds after the one before: roots creeping out at you.
--   Leap  { Every, Range, Windup, Airtime, Height, Radius, Damage, Hops, Anim, Then }: it
--         crouches for Windup, then jumps onto where its target stood when it crouched,
--         Airtime seconds in the air (Height studs up, client/BossView); a red circle Radius
--         wide fills there till it lands and hurts. Hops: that many jumps in a row.
--   Blink { Every, Fade, Near, Far, Anim, Then }: it shrinks away and pops up somewhere else
--         in its arena (Near..Far studs from its target) over Fade seconds (client/BossView).
--   Any of them can name Then = the index of another of its attacks, set off the moment
--         this one lands (a ring of shards when a Leap lands, a volley after a Blink).
--         An attack with Linked = true only ever goes off as another's Then.
--   Anim: an animation of its model played as the attack winds up, sped up or slowed so
--         its `hit` time lands just as the attack does (the BossAnim remote: client/
--         BossView). Magic, Lob and Bombs can take a Cast (seconds) to wind up first.
--
-- Only players locked into its fight (LockedIn = its biome) are hit, so someone passing
-- through is never caught. All of it is server parts in workspace.BossFx. A pet bigger
-- than the Horse is easier to hit: everything reaches its hitbox's extra (Shared/Pets).
--
--   BossAttacks.update(body, b, dt, fighters) -> true while it should stand still
--         (b: { c = { Attacks, Radius }, biome }; Server/Training's mobs use it too)
--   BossAttacks.fighter(player) -> { root, humanoid, extra } or nil, if they're alive
--   BossAttacks.burst(body, b)  -- every Magic attack's Burst now (a boss that fires on its
--         own cycle, not their timers: the Sandworm's Burrow, Server/Bosses)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pets = require(Shared:WaitForChild("Pets"))
local Projectiles = require(Shared:WaitForChild("Projectiles"))
local Config = require(Shared:WaitForChild("Config"))
local HORSE_HITBOX = Pets.stats("Horse").Hitbox

local BossAttacks = {}

local fx = Instance.new("Folder")
fx.Name = "BossFx"
fx.Parent = workspace

local RED = Color3.fromRGB(255, 50, 40)
local SHOT = Color3.fromRGB(255, 140, 40)
local FLOOR_Y = 0.15

-- (Lob: every client draws the bomb in flight and where it'll land: client/Bombs)
local bombRemote = Instance.new("RemoteEvent")
bombRemote.Name = "BossBomb"
bombRemote.Parent = ReplicatedStorage

-- (everyone plays a boss's attack animation as it winds up: (body, anim name, windup))
local animRemote = Instance.new("RemoteEvent")
animRemote.Name = "BossAnim"
animRemote.Parent = ReplicatedStorage

local shots = {} -- [part] = { dir, speed, travelled, range, damage, radius, biome }
local magic = {} -- { { shot, damage, biome } }: Magic attacks' shots in the air

-- (everyone draws a boss's Magic shots: (body, attack index, yaw, seed, origin))
local bossShot = Instance.new("RemoteEvent")
bossShot.Name = "BossShot"
bossShot.Parent = ReplicatedStorage

-- how wide a player is to a boss's Magic shot (studs, plus their pet's extra hitbox)
local PLAYER_RADIUS = 1

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

-- everyone in the fight within radius of centre (flat) takes damage
local function blast(biome, centre, radius, damage)
	for _, f in fighters(biome) do
		if flat(f.root.Position - centre).Magnitude <= radius + 1 + f.extra then
			f.humanoid:TakeDamage(damage)
		end
	end
end

-- a bomb flung from `from` to land on the ground at `centre` after a.Airtime, hurting
-- everyone within a.Radius there (the flight and the warning are the clients': client/Bombs)
local function lob(biome, from, centre, a)
	local to = Vector3.new(centre.X, groundAt(centre), centre.Z)
	bombRemote:FireAllClients({
		from = from,
		to = to,
		start = workspace:GetServerTimeNow(),
		airtime = a.Airtime,
		radius = a.Radius,
		height = a.Height,
		style = a.Style,
	})
	task.delay(a.Airtime, blast, biome, to, a.Radius, a.Damage)
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
		blast(biome, centre, radius, damage)
		rim.Transparency = 0.2
		fill:Destroy()
		TweenService
			:Create(rim, TweenInfo.new(0.25), { Transparency = 1, Size = rim.Size * Vector3.new(1, 1.15, 1.15) })
			:Play()
		task.delay(0.3, rim.Destroy, rim)
	end)
end

-- a flat red rectangle on the ground Width wide, from `from` Length studs along `dir`,
-- filling from its near end over `windup`; then (with damage) everyone in the fight on it
-- takes damage. -> nothing; the parts tidy themselves away
local function rectangle(biome, from, dir, width, length, windup, damage)
	local mid = from + dir * (length / 2)
	local y = groundAt(mid) + FLOOR_Y
	local facing = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(mid.X, y, mid.Z) + dir)
	local function plate(name, long, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = RED
		p.Transparency = transparency
		p.Size = Vector3.new(width, 0.2, long)
		p.Parent = fx
		return p
	end
	local rim = plate("Warning", length, 0.75)
	rim.CFrame = facing
	-- (the fill grows from its near end out to the far one)
	local near = facing * CFrame.new(0, 0.02, length / 2)
	local fill = plate("WarningFill", 0.2, 0.45)
	fill.CFrame = near * CFrame.new(0, 0, -0.1)
	TweenService
		:Create(fill, TweenInfo.new(windup, Enum.EasingStyle.Linear), {
			Size = Vector3.new(width, 0.2, length),
			CFrame = near * CFrame.new(0, 0, -length / 2),
		})
		:Play()
	task.delay(windup, function()
		if damage then
			for _, f in fighters(biome) do
				local off = flat(f.root.Position - from)
				local along = off:Dot(dir)
				local side = (off - dir * along).Magnitude
				local pad = 1 + f.extra
				if along >= -pad and along <= length + pad and side <= width / 2 + pad then
					f.humanoid:TakeDamage(damage)
				end
			end
		end
		rim.Transparency = 0.2
		fill:Destroy()
		TweenService:Create(rim, TweenInfo.new(0.25), { Transparency = 1 }):Play()
		task.delay(0.3, rim.Destroy, rim)
	end)
end

-- a spot inside its arena (Radius in from the edges; near home for a /boss boss)
local function inArena(b, p)
	if not b.bounds then
		return p
	end
	local r = b.c.Radius + 4
	local x0, x1 = math.min(b.bounds[1], b.bounds[3]) + r, math.max(b.bounds[1], b.bounds[3]) - r
	local z0, z1 = math.min(b.bounds[2], b.bounds[4]) + r, math.max(b.bounds[2], b.bounds[4]) - r
	return Vector3.new(math.clamp(p.X, x0, x1), p.Y, math.clamp(p.Z, z0, z1))
end

-- plays its attack's animation on every client, timed to hit `windup` seconds from now
local function animate(body, a, windup)
	if a.Anim then
		animRemote:FireAllClients(body, a.Anim, windup or 0)
	end
end
BossAttacks.animate = animate

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

-- one Magic volley from a boss at whoever's nearest (re-aimed for each of a burst)
local function cast(body, b, i, a)
	if not body.Parent or (body:GetAttribute("Health") or 0) <= 0 then
		return
	end
	local list = fighters(b.biome)
	local pos = flat(body.Position)
	local target = nearest(pos, list)
	if not target then
		return
	end
	local toward = flat(target.root.Position - pos)
	toward = if toward.Magnitude > 0.01 then toward.Unit else Vector3.new(0, 0, -1)
	local yaw = math.atan2(-toward.X, -toward.Z)
	local from = pos + toward * b.c.Radius
	local origin = Vector3.new(from.X, groundAt(from) + (a.Height or 4), from.Z)
	local seed = math.random(0, 2 ^ 30 - 1)
	local s = Projectiles.bossShot(a)
	for _, shot in Projectiles.volley(s, true, origin, yaw, seed) do
		table.insert(magic, { shot = shot, damage = a.Damage, biome = b.biome })
	end
	bossShot:FireAllClients(body, i, yaw, seed, origin)
end

function BossAttacks.burst(body, b)
	for i, a in b.c.Attacks or {} do
		if a.Kind == "Magic" then
			for k = 1, math.max(1, a.Burst or 1) do
				task.delay((k - 1) * (a.BurstGap or 0.3), cast, body, b, i, a)
			end
		end
	end
end

-- (the cos of half its melee cone: a fighter at most this far off its facing gets hit)
local coneCos = math.cos(math.rad(Config.BossMelee.Cone / 2))

local function alive(body)
	return body.Parent ~= nil and (body:GetAttribute("Health") or 0) > 0
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local go -- (go(body, b, i): an attack going off now; Then chains through it)

-- what an attack does once it's wound up (the ones that don't move it)
local function perform(body, b, i, a)
	if not alive(body) then
		return
	end
	local list = fighters(b.biome)
	local pos = flat(body.Position)
	local target = nearest(pos, list)
	if not target then
		return
	end
	local toward = flat(target.root.Position - pos)
	toward = if toward.Magnitude > 0.01 then toward.Unit else flat(body.CFrame.LookVector).Unit
	if a.Kind == "Shot" then
		for k = 1, a.Count do
			local angle = math.rad((k - (a.Count + 1) / 2) * a.Spread)
			fire(b.biome, pos + toward * b.c.Radius, CFrame.Angles(0, angle, 0):VectorToWorldSpace(toward), a)
		end
	elseif a.Kind == "Magic" then
		for k = 1, math.max(1, a.Burst or 1) do
			task.delay((k - 1) * (a.BurstGap or 0.3), cast, body, b, i, a)
		end
	elseif a.Kind == "Nova" then
		local spin = math.random() * math.pi
		for k = 1, a.Count do
			local angle = spin + k / a.Count * 2 * math.pi
			local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
			fire(b.biome, pos + dir * b.c.Radius, dir, a)
		end
	elseif a.Kind == "Bombs" then
		for _, f in list do
			circle(b.biome, flat(f.root.Position), a.Radius, a.Windup, a.Damage)
		end
		for k = 1, a.Count or 0 do
			-- (Around: in a ring round itself instead, like a fairy ring; else round you)
			if a.Around then
				local angle = k / a.Count * 2 * math.pi + math.random() * 0.3
				local out = b.c.Radius + a.Radius + math.random() * (a.Scatter or 10)
				circle(b.biome, pos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * out, a.Radius, a.Windup, a.Damage)
			else
				local f = list[math.random(1, #list)]
				local off = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * a.Scatter
				circle(b.biome, flat(f.root.Position) + off, a.Radius, a.Windup, a.Damage)
			end
		end
	elseif a.Kind == "Lob" then
		-- (out of its top, toward each spot)
		local top = body.Position + Vector3.new(0, body.Size.Y * 0.3, 0)
		local function fling(spot)
			local dir = flat(spot - pos)
			local from = top + (if dir.Magnitude > 0.01 then dir.Unit * b.c.Radius * 0.5 else Vector3.zero)
			lob(b.biome, from, spot, a)
		end
		for _, f in list do
			fling(flat(f.root.Position))
		end
		for _ = 1, a.Count or 0 do
			local f = list[math.random(1, #list)]
			local angle = math.random() * 2 * math.pi
			local out = a.Radius + math.random() * (a.Scatter - a.Radius)
			local off = Vector3.new(math.cos(angle), 0, math.sin(angle)) * out
			fling(flat(f.root.Position) + off)
		end
	end
	if a.Then and b.c.Attacks[a.Then] then
		go(body, b, a.Then)
	end
end

-- an attack going off now (its windup first, if it has one): a timer's run out, or another's
-- Then. -> false if it can't yet (its target's out of its Range), so its timer waits
go = function(body, b, i, list)
	local a = b.c.Attacks[i]
	list = list or fighters(b.biome)
	local pos = flat(body.Position)
	local target, distance = nearest(pos, list)
	if not (a and target and alive(body)) then
		return false
	end
	local edge = distance - b.c.Radius
	local toward = flat(target.root.Position - pos)
	toward = if toward.Magnitude > 0.01 then toward.Unit else Vector3.new(0, 0, -1)
	local now = serverNow()
	b.hops = b.hops or {}
	if a.Kind == "Slam" then
		if edge > a.Range then
			return false
		end
		animate(body, a, a.Windup)
		b.still = a.Windup + 0.25
		circle(b.biome, pos + toward * (b.c.Radius + a.Radius * 0.55), a.Radius, a.Windup, a.Damage)
		if a.Then then
			task.delay(a.Windup, go, body, b, a.Then)
		end
	elseif a.Kind == "Charge" then
		if edge > (a.Range or 60) then
			return false
		end
		-- (it faces you, then runs the rectangle: from its middle, past where you stand)
		b.yaw = math.atan2(-toward.X, -toward.Z)
		local length = a.Length or (distance + 15)
		local width = a.Width or b.c.Radius * 2
		local time = length / a.Speed
		animate(body, a, a.Windup)
		b.still = a.Windup + time + 0.4
		rectangle(b.biome, pos, toward, width, length + b.c.Radius, a.Windup, nil)
		b.move = {
			kind = "Dash",
			start = now + a.Windup,
			from = pos,
			dir = toward,
			length = length,
			speed = a.Speed,
			width = width,
			damage = a.Damage,
			hit = {},
			after = a.Then,
		}
	elseif a.Kind == "Line" then
		if edge > (a.Range or 80) then
			return false
		end
		animate(body, a, a.Windup)
		b.still = a.Windup + 0.25
		local count = math.max(1, a.Count or 1)
		local segments = math.max(1, a.Segments or 1)
		for k = 1, count do
			local angle = if count > 1 then math.rad((k - (count + 1) / 2) * (a.Spread or 20)) else 0
			local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(toward)
			local from = if a.From == "Target"
				then flat(target.root.Position) - dir * (a.Length / 2)
				else pos + dir * (b.c.Radius * 0.6)
			for seg = 0, segments - 1 do
				rectangle(
					b.biome,
					from + dir * (seg * a.Length),
					dir,
					a.Width,
					a.Length,
					a.Windup + seg * (a.Gap or 0.15),
					a.Damage
				)
			end
		end
		if a.Then then
			task.delay(a.Windup, go, body, b, a.Then)
		end
	elseif a.Kind == "Leap" then
		local hopping = (b.hops[i] or 0) > 0
		if not hopping and edge > (a.Range or 80) then
			return false
		end
		if not hopping then
			b.hops[i] = a.Hops or 1
		end
		local to = inArena(b, flat(target.root.Position))
		local off = flat(to - pos)
		if off.Magnitude > 0.01 then
			b.yaw = math.atan2(-off.X, -off.Z)
		end
		animate(body, a, a.Windup)
		b.still = a.Windup + a.Airtime + 0.3
		circle(b.biome, to, a.Radius, a.Windup + a.Airtime, a.Damage)
		b.move = {
			kind = "Leap",
			start = now + a.Windup,
			from = pos,
			to = to,
			airtime = a.Airtime,
			index = i,
			after = a.Then,
		}
		body:SetAttribute("LeapHeight", a.Height or 20)
		body:SetAttribute("LeapTime", a.Airtime)
		body:SetAttribute("LeapAt", now + a.Windup)
	elseif a.Kind == "Blink" then
		-- (somewhere Near..Far from its target, inside its arena)
		local best, bestScore = pos, math.huge
		for _ = 1, 16 do
			local angle = math.random() * 2 * math.pi
			local out = (a.Near or 30) + math.random() * ((a.Far or 50) - (a.Near or 30))
			local p = inArena(b, flat(target.root.Position) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * out)
			local d = flat(p - target.root.Position).Magnitude
			local score = math.max(0, (a.Near or 30) - d) + math.max(0, 15 - flat(p - pos).Magnitude)
			if score < bestScore then
				best, bestScore = p, score
			end
		end
		animate(body, a, a.Fade)
		b.still = a.Fade + 0.2
		b.move = { kind = "Blink", start = now + a.Fade / 2, done = now + a.Fade, to = best, after = a.Then }
		body:SetAttribute("BlinkTime", a.Fade)
		body:SetAttribute("BlinkAt", now)
	else
		-- (Magic, Lob, Bombs, Shot, Nova: a Cast to wind up first, if it has one)
		local castTime = a.Cast or 0
		animate(body, a, castTime)
		if castTime > 0 then
			b.still = math.max(b.still or 0, castTime + 0.1)
			task.delay(castTime, perform, body, b, i, a)
		else
			perform(body, b, i, a)
		end
	end
	return true
end

-- a Charge's dash, a Leap's flight or a Blink, this frame: where it is now, or nil if it's
-- not doing one (Server/Bosses moves it there and doesn't walk or turn it meanwhile)
function BossAttacks.move(body, b, dt, pos)
	local m = b.move
	if not m then
		return nil
	end
	local now = serverNow()
	if now < m.start then
		return pos -- (winding up: holding still, facing the way it'll go)
	end
	local y = pos.Y
	if m.kind == "Dash" then
		local t = now - m.start
		local along = math.min(m.length, t * m.speed)
		local at = inArena(b, m.from + m.dir * along)
		for _, f in fighters(b.biome) do
			if not m.hit[f.humanoid] then
				local off = flat(f.root.Position - at)
				if off.Magnitude <= b.c.Radius + 1 + f.extra then
					m.hit[f.humanoid] = true
					f.humanoid:TakeDamage(m.damage)
				end
			end
		end
		if along >= m.length then
			b.move = nil
			b.still = math.min(b.still or 0, 0.4)
			if m.after then
				go(body, b, m.after)
			end
		end
		return Vector3.new(at.X, y, at.Z)
	elseif m.kind == "Leap" then
		local k = math.clamp((now - m.start) / m.airtime, 0, 1)
		local at = m.from:Lerp(m.to, k)
		if k >= 1 then
			b.move = nil
			if m.after then
				go(body, b, m.after)
			end
			-- (more hops to go: the next one soon, wherever you've got to)
			b.hops[m.index] = math.max(0, (b.hops[m.index] or 1) - 1)
			if b.hops[m.index] > 0 then
				b.timers[m.index] = 0.25
				b.still = 0
			end
		end
		return Vector3.new(at.X, y, at.Z)
	elseif m.kind == "Blink" then
		if now >= m.done then
			b.move = nil
			if m.after then
				go(body, b, m.after)
			end
		end
		return Vector3.new(m.to.X, y, m.to.Z)
	end
	return nil
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
	for i, a in attacks do
		if a.Linked then
			continue
		end
		-- (staggered starts, so they don't all go at once)
		b.timers[i] = (b.timers[i] or a.Every * (0.5 + i * 0.25)) - dt
		if b.timers[i] > 0 or b.still > 0 or b.move then
			continue
		end
		if a.Kind == "Contact" then
			-- too close and it hurts: everyone within Reach of its edge and in front of it,
			-- every Every seconds
			local hit = false
			local facing = flat(body.CFrame.LookVector).Unit
			for _, f in list do
				local off = flat(f.root.Position - pos)
				local inFront = off.Magnitude < 0.01 or facing:Dot(off.Unit) >= coneCos
				if inFront and off.Magnitude - b.c.Radius - f.extra <= a.Reach then
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
		elseif go(body, b, i, list) then
			-- (a Leap's further hops set their own short timer)
			if not (a.Kind == "Leap" and (b.hops[i] or 0) > 0 and b.timers[i] > 0) then
				b.timers[i] = a.Every
			end
		end
	end
	return b.still > 0 or b.move ~= nil
end

RunService.Heartbeat:Connect(function(dt)
	-- Magic shots: the same maths every client draws them with, against the fight's players
	if #magic > 0 then
		local byBiome = {}
		for i = #magic, 1, -1 do
			local m = magic[i]
			local targets = byBiome[m.biome]
			if not targets then
				targets = {}
				for _, f in fighters(m.biome) do
					table.insert(targets, { body = f.root, pos = f.root.Position, radius = PLAYER_RADIUS + f.extra, f = f })
				end
				byBiome[m.biome] = targets
			end
			for _, t in Projectiles.step(m.shot, dt, targets) do
				t.f.humanoid:TakeDamage(m.damage)
			end
			if m.shot.dead then
				table.remove(magic, i)
			end
		end
	end
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
