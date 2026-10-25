-- Bosses, on the server: each is an invisible anchored body in workspace.Bosses (its
-- hitbox and position, replicated), with attributes Kind (its Config.Bosses entry),
-- Model and ModelSize (what clients draw: client/BossView.luau), Name, Health, MaxHealth,
-- Radius, and for an arena's boss Biome and Asleep. The HUD's boss bar shows the
-- nearest awake one.
--
-- Each biome's boss sleeps on its dais (Map's BossSpot) until it's woken: someone steals
-- one of its eggs, or hits it (Server/Eggs locks them into its fight). Awake, it chases
-- the nearest player locked into its fight, never leaving its arena, and attacks
-- (Config.Bosses[biome].Attacks, Server/BossAttacks). With nobody left in
-- the fight for Config.BossCalmDown seconds it walks home, heals and sleeps. At 0 health
-- it dies (Bosses.defeated fires: the fight's players go free) and comes back asleep
-- Respawn seconds later.
--
--   Bosses.spawn(kind, player)       -- a boss in front of the player (the /boss command)
--   Bosses.arena(biome, spot, bounds) -- a biome's sleeping boss on its spot (one of its
--                                        Config.BossPools at random)
--   Bosses.reroll()                  -- every biome's boss swapped for a fresh random one
--   Bosses.wake(biome)
--   Bosses.alive(biome) -> its boss is up (not dead, waiting to respawn)
--   Bosses.defeated                  -- BindableEvent: Event(biome)
--   Bosses.engaged                   -- BindableEvent: Event(player, biome), on a hit

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local BossAttacks = require(script.Parent.BossAttacks)
local Combat = require(script.Parent.Combat)

local Bosses = {}
Bosses.defeated = Instance.new("BindableEvent")
Bosses.engaged = Instance.new("BindableEvent")

local folder = Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace

local live = {} -- [body] = { kind, c, yaw, home, bounds, biome, calm }
local arenas = {} -- [biome] = { spot, bounds }
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
	if health <= 0 then
		local b = live[body]
		live[body] = nil
		Combat.remove(body)
		task.delay(0.6, function() -- (time for clients to play its death)
			body:Destroy()
		end)
		if b and b.biome then
			Bosses.defeated:Fire(b.biome)
			local arena = arenas[b.biome]
			task.delay(b.c.Respawn or 20, function()
				if arenas[b.biome] == arena then
					Bosses.arena(b.biome, arena.spot, arena.bounds)
				end
			end)
		end
	end
end

local function make(kind, at, yaw)
	local c = Config.Bosses[kind]
	local box = extent(c.Model) * c.Size
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
	body:SetAttribute("Model", c.Model)
	body:SetAttribute("ModelSize", c.Size)
	body:SetAttribute("Name", c.Name or c.Model)
	body:SetAttribute("Health", c.Health)
	body:SetAttribute("MaxHealth", c.Health)
	body:SetAttribute("Radius", c.Radius)
	local b = { kind = kind, c = c, yaw = yaw, home = at, calm = 0 }
	live[body] = b
	Combat.add(body, function(player, damage)
		if not live[body] then
			return
		end
		if b.biome then
			Bosses.engaged:Fire(player, b.biome)
			Bosses.wake(b.biome)
		end
		Combat.train(player, c.Strength or 1)
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

-- bounds = { x0, z0 (south), x1, z1 (north) }: the arena it never leaves. Which boss: one
-- of Config.BossPools[biome] at random, each time.
function Bosses.arena(biome, spot, bounds)
	local pool = Config.BossPools[biome]
	local list = {}
	for _, kind in pool or {} do
		if Config.Bosses[kind] then
			table.insert(list, kind)
		end
	end
	if #list == 0 then
		return nil
	end
	arenas[biome] = { spot = spot, bounds = bounds }
	-- (asleep facing south, the way intruders come in from: QM)
	local body, b = make(list[math.random(#list)], spot * Vector3.new(1, 0, 1), HOME_YAW)
	b.biome, b.bounds = biome, bounds
	body:SetAttribute("Biome", biome)
	body:SetAttribute("Asleep", true)
	body.Parent = folder
	return body
end

-- every arena's boss gone and a fresh one rolled in its place, asleep (the /reboss
-- command); anyone in a fight goes free
function Bosses.reroll()
	for body, b in live do
		if b.biome then
			live[body] = nil
			Combat.remove(body)
			body:Destroy()
			Bosses.defeated:Fire(b.biome)
		end
	end
	for biome, arena in arenas do
		Bosses.arena(biome, arena.spot, arena.bounds)
	end
end

-- is this biome's boss there to fight (not dead and waiting to come back)?
function Bosses.alive(biome)
	for _, b in live do
		if b.biome == biome then
			return true
		end
	end
	return false
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
	b.yaw += turn * (1 - math.exp(-dt * b.c.Turn))
end

RunService.Heartbeat:Connect(function(dt)
	for body, b in live do
		local c = b.c
		local pos = body.Position
		if body:GetAttribute("Asleep") then
			continue
		end
		local target, distance = nearestPlayer(pos, b.biome)
		-- (its attacks, Server/BossAttacks: a slam's wind-up holds it still)
		local hold = b.biome ~= nil and BossAttacks.update(body, b, dt, BossAttacks.fighters(b.biome))
		if target then
			b.calm = 0
			local offset = (target.Position - pos) * Vector3.new(1, 0, 1)
			turnToward(b, offset, dt)
			if not hold and distance - c.Radius > c.StopAt then
				local step = math.min(c.Speed * dt, distance - c.Radius - c.StopAt)
				-- (it walks where it faces, so it curves round rather than sliding sideways)
				pos += CFrame.Angles(0, b.yaw, 0).LookVector * step
			end
		elseif b.biome then
			-- nobody left in the fight: wait, then walk home, heal and sleep
			b.calm += dt
			if b.calm > Config.BossCalmDown then
				local offset = (b.home - pos) * Vector3.new(1, 0, 1)
				if offset.Magnitude < 1 then
					body:SetAttribute("Health", c.Health)
					body:SetAttribute("Asleep", true)
					b.yaw = HOME_YAW
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
