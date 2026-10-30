-- Bosses, on the server: each is an invisible anchored body in workspace.Bosses (its
-- hitbox and position, replicated), with attributes Kind (its Config.Bosses entry),
-- Model and ModelSize (what clients draw: client/BossView.luau), Name, Health, MaxHealth,
-- Radius, and for an arena's boss Biome and Intro (and Asleep, unused for now). The HUD's
-- boss bar shows the nearest awake one.
--
-- A biome's boss isn't there until someone steals one of its eggs (QM, Oct 25): then it
-- appears on its dais (Map's BossSpot), one of Config.BossPools[biome] at random, with
-- Intro set for Config.BossIntro's length while client/BossIntro shows it arriving. Until
-- that's over it can't be hit and doesn't move or attack. Then it chases the nearest
-- player locked into its fight (Server/Eggs locks them in), never leaving its arena, and
-- attacks (Config.Bosses[biome].Attacks, Server/BossAttacks). With nobody left in the
-- fight for Config.BossCalmDown seconds it walks home and leaves. At 0 health it dies
-- (Bosses.defeated fires: the fight's players go free). Either way Bosses.ended fires and
-- Server/Eggs starts the biome's nest cooldown: it's called up again by the next egg
-- taken once the nests refill (QM, Oct 26).
-- A boss with Minions (Config.Bosses) calls them up once it's down to Minions.At of its
-- health (Server/Minions); they go when the fight ends.
-- A boss with a Burrow (the Sandworm, QM Oct 27) never walks: it surfaces, spits its Magic
-- attacks' bursts at you, lingers, dives back down and tunnels to a new spot nearby, over
-- and over. Its Burrow attribute says which part it's in (Emerge, Up, Hide, Under, from
-- server time BurrowAt, for client/BossView), and while Under it's Burrowed: it can't be
-- hit and shots pass over it.
-- (The old sleeping bosses, QM Oct 25: Asleep bodies can't be hit and stand still, and
-- client/BossView still draws them sleeping; nothing sets Asleep now.)
--
--   Bosses.spawn(kind, player)       -- a boss in front of the player (the /boss command)
--   Bosses.arena(biome, spot, bounds) -- a biome's arena, empty until summoned
--   Bosses.summon(biome, player)     -- its boss arrives (facing the player), if it's not
--                                        there yet and not dead and waiting -> body or nil
--   Bosses.reroll()                  -- every biome's boss gone, ready to be summoned again
--   Bosses.fight(kind, player)       -- that boss in its biome's arena now, whatever was
--                                        there gone (the /bossfight command) -> body, biome
--   Bosses.wake(biome)
--   Bosses.alive(biome) -> its boss is up or can be summoned (not dead, waiting)
--   Bosses.defeated                  -- BindableEvent: Event(biome)
--   Bosses.ended                     -- BindableEvent: Event(biome), when its fight's over:
--                                       the boss died, went home, or was rerolled
--   Bosses.engaged                   -- BindableEvent: Event(player, biome), on a hit
--   Bosses.killed                    -- BindableEvent: Event(kind, players), when one is
--                                       beaten (not on /reboss): everyone in its fight and
--                                       everyone who hit it (each is paid its Cash first; nothing else listens now: QM, Oct 27, no more weapon drops)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BossAttacks = require(script.Parent.BossAttacks)
local Combat = require(script.Parent.Combat)
local Pets = require(Shared:WaitForChild("Pets"))
local Minions = require(script.Parent.Minions)

local Bosses = {}
Bosses.defeated = Instance.new("BindableEvent")
Bosses.engaged = Instance.new("BindableEvent")
Bosses.killed = Instance.new("BindableEvent")
Bosses.ended = Instance.new("BindableEvent")

local folder = Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace

-- (however a fight ends, its minions go with it)
Bosses.ended.Event:Connect(Minions.clear)

local live = {} -- [body] = { kind, c, yaw, home, bounds, biome, calm, minions (called yet) }
local arenas = {} -- [biome] = { spot, bounds, ready (a boss can be summoned) }
local extents = {}
local HOME_YAW = math.pi -- (facing +z, south: every arena's gateway is on its south side)

-- the drawing's box (studs, at 1x), for the body's size
local function extent(model)
	if extents[model] then
		return extents[model]
	end
	local data = require(Shared.Animals:FindFirstChild(model .. "Model"))
	local hi = Vector3.zero
	for _, part in data.parts do
		local p, h = part.cframe.Position, part.size / 2
		hi = hi:Max(Vector3.new(math.abs(p.X) + h.X, p.Y + h.Y, math.abs(p.Z) + h.Z))
	end
	extents[model] = hi
	return hi
end

local function hurt(body, amount)
	local health = math.max(0, body:GetAttribute("Health") - amount)
	body:SetAttribute("Health", health)
	-- (down to its Minions.At share: its helpers arrive, once a fight: Server/Minions)
	local m = live[body] and live[body].c.Minions
	if m and health > 0 and not live[body].minions and health <= body:GetAttribute("MaxHealth") * m.At then
		live[body].minions = true
		Minions.call(body, live[body])
	end
	if health <= 0 then
		local b = live[body]
		live[body] = nil
		Combat.remove(body)
		if b then
			-- (gathered before Bosses.defeated sets the fight's players free)
			local winners = {}
			for _, player in Players:GetPlayers() do
				if b.hitters[player] or (b.biome and player:GetAttribute("LockedIn") == b.biome) then
					table.insert(winners, player)
				end
			end
			-- its Cash to each of them (Config.Bosses)
			local cash = b.c.Cash or 0
			if cash > 0 then
				for _, player in winners do
					player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + cash)
				end
			end
			Bosses.killed:Fire(b.kind, winners)
		end
		task.delay(0.6, function() -- (time for clients to play its death)
			body:Destroy()
		end)
		if b and b.biome then
			Bosses.defeated:Fire(b.biome)
			-- (summonable again at once: the nests' cooldown keeps it away till they refill)
			if arenas[b.biome] then
				arenas[b.biome].ready = true
			end
			Bosses.ended:Fire(b.biome)
		end
	end
end

-- the model it's drawn as and its size: its own, or (till its model's made) its StandIn,
-- { pet model, size }, an existing pet scaled up (QM, Oct 30: new bosses playable at once)
local function look(c)
	if Shared.Animals:FindFirstChild(c.Model .. "Model") or not c.StandIn then
		return c.Model, c.Size
	end
	return c.StandIn[1], c.StandIn[2]
end
Bosses.look = look

local function make(kind, at, yaw)
	local c = Config.Bosses[kind]
	local model, modelSize = look(c)
	local box = extent(model) * modelSize
	local size = Vector3.new(c.Radius * 2, box.Y, c.Radius * 2)
	local body = Instance.new("Part")
	body.Name = kind .. "Boss"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Transparency = 1
	body.Size = size
	body.CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Kind", kind)
	body:SetAttribute("Model", model)
	body:SetAttribute("ModelSize", modelSize)
	body:SetAttribute("Name", c.Name or c.Model)
	body:SetAttribute("Health", c.Health)
	body:SetAttribute("MaxHealth", c.Health)
	body:SetAttribute("Radius", c.Radius)
	local b = { kind = kind, c = c, yaw = yaw, home = at, calm = 0, hitters = {} }
	if c.Burrow then
		-- (it arrives already up, and spits once the intro's over)
		b.burrow = { state = "Up", t = 0 }
		body:SetAttribute("Burrow", "Up")
		body:SetAttribute("BurrowAt", workspace:GetServerTimeNow())
	end
	live[body] = b
	Combat.add(body, function(player, damage)
		-- (arriving, or asleep, it can't be hurt at all: QM Oct 25)
		if
			not live[body]
			or body:GetAttribute("Asleep")
			or body:GetAttribute("Intro")
			or body:GetAttribute("Burrowed")
			or body:GetAttribute("Shielded")
		then
			return
		end
		if b.biome then
			Bosses.engaged:Fire(player, b.biome)
		end
		Combat.train(player, damage, c.Strength or 1)
		b.hitters[player] = true
		hurt(body, damage)
	end)
	return body, b
end

function Bosses.spawn(kind, player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (Config.Bosses[kind] and root) then
		return nil
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local at = root.Position * Vector3.new(1, 0, 1) + look * 30
	local body = make(kind, at, math.atan2(look.X, look.Z)) -- (facing back toward the player)
	body.Parent = folder
	return body
end

local function pool(biome)
	local list = {}
	for _, kind in Config.BossPools[biome] or {} do
		if Config.Bosses[kind] then
			table.insert(list, kind)
		end
	end
	return list
end

-- bounds = { x0, z0 (south), x1, z1 (north) }: the arena its boss never leaves
function Bosses.arena(biome, spot, bounds)
	if #pool(biome) == 0 then
		return nil
	end
	arenas[biome] = { spot = spot, bounds = bounds, ready = true }
	return arenas[biome]
end

function Bosses.summon(biome, player, kind)
	for body, b in live do
		if b.biome == biome then
			return body
		end
	end
	local arena = arenas[biome]
	local list = pool(biome)
	if not (arena and arena.ready) or #list == 0 then
		return nil
	end
	arena.ready = false
	kind = kind or list[math.random(#list)]
	local at = arena.spot * Vector3.new(1, 0, 1)
	-- (a rooted boss, Centre: the middle of its arena instead of the dais)
	local bounds = arena.bounds
	if Config.Bosses[kind].Centre and bounds then
		at = Vector3.new((bounds[1] + bounds[3]) / 2, 0, (bounds[2] + bounds[4]) / 2)
	end
	-- (facing whoever called it up; else south, the way intruders come in from: QM)
	local yaw = HOME_YAW
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local look = (at - root.Position) * Vector3.new(1, 0, 1)
		if look.Magnitude > 1e-3 then
			yaw = math.atan2(look.X, look.Z)
		end
	end
	local body, b = make(kind, at, yaw)
	b.biome, b.bounds = biome, arena.bounds
	body:SetAttribute("Biome", biome)
	body:SetAttribute("Intro", true)
	body.Parent = folder
	local intro = Config.BossIntro
	task.delay(intro.PanIn + intro.Hold + intro.PanOut, function()
		if live[body] then
			body:SetAttribute("Intro", false)
		end
	end)
	return body
end

-- every arena's boss gone, each ready to be summoned again (a fresh roll from its pool:
-- the /reboss command); anyone in a fight goes free
function Bosses.reroll()
	for body, b in live do
		if b.biome then
			live[body] = nil
			Combat.remove(body)
			body:Destroy()
			Bosses.defeated:Fire(b.biome)
			Bosses.ended:Fire(b.biome)
		end
	end
	for _, arena in arenas do
		arena.ready = true
	end
end

-- /bossfight: this boss in the arena of the biome whose pool has it, now (QM, Oct 30). The
-- boss there already goes (its fight's players stay locked in, into the new one).
function Bosses.fight(kind, player)
	local biome
	for name in arenas do
		if table.find(pool(name), kind) then
			biome = name
		end
	end
	if not biome then
		return nil
	end
	for body, b in live do
		if b.biome == biome then
			live[body] = nil
			Combat.remove(body)
			body:Destroy()
			Bosses.ended:Fire(biome)
		end
	end
	arenas[biome].ready = true
	return Bosses.summon(biome, player, kind), biome
end

-- a biome's arena, { spot, bounds, ready } (for /bossfight's teleport)
function Bosses.arenaOf(biome)
	return arenas[biome]
end

-- is this biome's boss there to fight, or ready to be summoned (not dead and waiting)?
function Bosses.alive(biome)
	for _, b in live do
		if b.biome == biome then
			return true
		end
	end
	return arenas[biome] ~= nil and arenas[biome].ready
end

function Bosses.wake(biome)
	for body, b in live do
		if b.biome == biome and body:GetAttribute("Asleep") then
			body:SetAttribute("Asleep", false)
			b.calm = 0
		end
	end
end

-- the nearest living player in this biome's fight (or, for /boss bosses, anyone)
local function nearestPlayer(position, biome)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		if biome == nil or player:GetAttribute("LockedIn") == biome then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local d = ((root.Position - position) * Vector3.new(1, 0, 1)).Magnitude
				if d < bestDist then
					best, bestDist = root, d
				end
			end
		end
	end
	return best, bestDist
end

local function turnToward(b, offset, dt)
	local want = math.atan2(-offset.X, -offset.Z)
	local turn = (want - b.yaw + math.pi) % (2 * math.pi) - math.pi
	-- (eased, but never faster than its TurnRate, so a fast pet circling it gets behind it
	-- and out of its melee cone: Config.BossMelee)
	local most = math.rad(b.c.TurnRate or Config.BossMelee.TurnRate) * dt
	b.yaw += math.clamp(turn * (1 - math.exp(-dt * b.c.Turn)), -most, most)
end

-- gone home (or back down its hole) with nobody left to fight: summonable again
local function leave(body, b)
	live[body] = nil
	Combat.remove(body)
	body:Destroy()
	if arenas[b.biome] then
		arenas[b.biome].ready = true
	end
	Bosses.ended:Fire(b.biome)
end

local function flat(v)
	return v * Vector3.new(1, 0, 1)
end

local function setBurrow(body, w, state)
	w.state, w.t = state, 0
	body:SetAttribute("Burrow", state)
	body:SetAttribute("BurrowAt", workspace:GetServerTimeNow())
	body:SetAttribute("Burrowed", state == "Under")
end

-- where a burrowing boss comes up next: inside its arena (or near home, for a /boss one),
-- Near..Far from its target and at least Hop from where it went down
local function nextSpot(b, pos, target)
	local cfg = b.c.Burrow
	local x0, z0, x1, z1
	if b.bounds then
		local r = b.c.Radius + 4
		x0, x1 = math.min(b.bounds[1], b.bounds[3]) + r, math.max(b.bounds[1], b.bounds[3]) - r
		z0, z1 = math.min(b.bounds[2], b.bounds[4]) + r, math.max(b.bounds[2], b.bounds[4]) - r
	else
		x0, x1, z0, z1 = b.home.X - cfg.Far, b.home.X + cfg.Far, b.home.Z - cfg.Far, b.home.Z + cfg.Far
	end
	local best, bestScore = nil, math.huge
	for _ = 1, 24 do
		local p = Vector3.new(x0 + math.random() * (x1 - x0), pos.Y, z0 + math.random() * (z1 - z0))
		-- (how far off it is from what it wants: 0 is a spot that fits)
		local score = math.max(0, cfg.Hop - flat(p - pos).Magnitude)
		if target then
			local d = flat(p - target.Position).Magnitude
			score += math.max(0, cfg.Near - d) + math.max(0, d - cfg.Far)
		end
		if score < bestScore then
			best, bestScore = p, score
			if score <= 0 then
				break
			end
		end
	end
	return best or pos
end

local function faceNow(b, pos, target)
	local offset = flat(target.Position - pos)
	if offset.Magnitude > 1e-3 then
		b.yaw = math.atan2(-offset.X, -offset.Z)
	end
end

-- how fast a burrowing boss tunnels (studs/s): its Burrow.Speed, or as fast as LassoAPet's
-- pet of its Model burrows (the pet's speed x LassoSprint), scaled up by how much bigger the
-- boss is than that pet (QM, Oct 27)
local function tunnelSpeed(c)
	local cfg = c.Burrow
	if cfg.Speed then
		return cfg.Speed
	end
	local pet = Pets.class(c.Model)
	return Pets.stats(c.Model).Speed * (cfg.LassoSprint or 2) * c.Size / (if pet then pet.size else 1)
end

-- a burrowing boss's cycle, a frame of it -> where it is now (nil: it's gone)
local function burrowStep(body, b, dt, target, pos)
	local cfg = b.c.Burrow
	local w = b.burrow
	w.t += dt
	-- (nobody left in the fight: it goes back down its hole and leaves)
	if target then
		b.calm = 0
	elseif b.biome then
		b.calm += dt
	end
	local leaving = b.calm > Config.BossCalmDown
	if w.state == "Emerge" or w.state == "Up" then
		if target then
			turnToward(b, flat(target.Position - pos), dt)
		end
		if w.state == "Emerge" then
			if w.t >= cfg.Emerge then
				setBurrow(body, w, "Up")
				w.spat = nil
			end
		elseif leaving then
			setBurrow(body, w, "Hide")
		elseif not w.spat then
			if target and w.t >= cfg.Aim then
				-- spits its bursts, then stays up Linger seconds after the last
				local last = 0
				for _, a in b.c.Attacks or {} do
					if a.Kind == "Magic" then
						last = math.max(last, (math.max(1, a.Burst or 1) - 1) * (a.BurstGap or 0.3))
					end
				end
				BossAttacks.burst(body, b)
				w.spat = w.t + last + cfg.Linger
			end
		elseif w.t >= w.spat then
			setBurrow(body, w, "Hide")
		end
	elseif w.state == "Hide" then
		if w.t >= cfg.Hide then
			if leaving then
				leave(body, b)
				return nil
			end
			setBurrow(body, w, "Under")
			w.to = nextSpot(b, pos, target)
		end
	elseif w.state == "Under" then
		if leaving then
			leave(body, b)
			return nil
		end
		-- tunnelling to its next spot (facing the way it goes: the mound's heading)
		local offset = flat(w.to - pos)
		w.speed = w.speed or tunnelSpeed(b.c)
		local step = w.speed * dt
		if offset.Magnitude > step then
			b.yaw = math.atan2(-offset.X, -offset.Z)
			pos += offset.Unit * step
		else
			pos = Vector3.new(w.to.X, pos.Y, w.to.Z)
			if w.t >= cfg.Travel then
				if target then
					faceNow(b, pos, target)
				end
				setBurrow(body, w, "Emerge")
			end
		end
	end
	return pos
end

RunService.Heartbeat:Connect(function(dt)
	for body, b in live do
		local c = b.c
		local pos = body.Position
		if body:GetAttribute("Asleep") or body:GetAttribute("Intro") then
			continue
		end
		local target, distance = nearestPlayer(pos, b.biome)
		if b.burrow then
			pos = burrowStep(body, b, dt, target, pos)
			if pos then
				body.CFrame = CFrame.new(pos) * CFrame.Angles(0, b.yaw, 0)
			end
			continue
		end
		-- (its attacks, Server/BossAttacks: a slam's wind-up holds it still)
		local hold = b.biome ~= nil and BossAttacks.update(body, b, dt, BossAttacks.fighters(b.biome))
		-- (mid-charge, mid-leap or blinking: its attack moves it, not its legs)
		local moved = BossAttacks.move(body, b, dt, pos)
		if moved then
			pos = moved
			b.calm = 0
		elseif target then
			b.calm = 0
			local offset = (target.Position - pos) * Vector3.new(1, 0, 1)
			turnToward(b, offset, dt)
			if not hold and distance - c.Radius > c.StopAt then
				local step = math.min(c.Speed * dt, distance - c.Radius - c.StopAt)
				-- (it walks where it faces, so it curves round rather than sliding sideways)
				pos += CFrame.Angles(0, b.yaw, 0).LookVector * step
			end
		elseif b.biome then
			-- nobody left in the fight: wait, then walk home and leave (till its next egg's
			-- stolen)
			b.calm += dt
			if b.calm > Config.BossCalmDown then
				local offset = (b.home - pos) * Vector3.new(1, 0, 1)
				if offset.Magnitude < 1 then
					leave(body, b)
					continue
				else
					turnToward(b, offset, dt)
					pos += offset.Unit * math.min(c.Speed * dt, offset.Magnitude)
				end
			end
		end
		if b.bounds then
			local r = c.Radius + 2
			local x0, x1 = math.min(b.bounds[1], b.bounds[3]) + r, math.max(b.bounds[1], b.bounds[3]) - r
			local z0, z1 = math.min(b.bounds[2], b.bounds[4]) + r, math.max(b.bounds[2], b.bounds[4]) - r
			pos = Vector3.new(math.clamp(pos.X, x0, x1), pos.Y, math.clamp(pos.Z, z0, z1))
		end
		body.CFrame = CFrame.new(pos) * CFrame.Angles(0, b.yaw, 0)
	end
end)

return Bosses
