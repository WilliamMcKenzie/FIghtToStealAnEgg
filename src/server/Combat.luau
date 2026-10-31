-- What a slash can hit, and what hitting trains (QM, Oct 24: Strength is a byproduct of
-- attacking). Bosses, training mobs and dummies register their invisible bodies here
-- with a handler; a slash checks every one of them (the reach and arc test bosses had)
-- and calls the handler of each it catches with the slash's damage.
--
-- Damage is Config.Slash.Damage scaled by the player's Strength (Shared/Power's log curve);
-- the player's Power attribute (the HUD's counter) shows their Strength.
--
--   Combat.add(body, handler)        -- handler(player, damage); body has a Radius attribute
--   Combat.remove(body)
--   Combat.slash(player, yaw, c)     -- a player's slash along world yaw `yaw`
--   Combat.shoot(player, id, yaw)    -- a Ranged or Magic weapon's volley (Shared/Projectiles)
--   Combat.train(player, damage, strength) -- a hit for `damage` on an enemy of this
--                                      Strength: adds Strength (and updates Power)
--   Combat.refresh(player)           -- updates Power after Strength is set directly
--   Combat.damage(player) -> number
--   Combat.alive(player) -> boolean  -- false once their Health hits 0 (QM, Oct 30: no
--                                      attacking from beyond the grave)
--   Combat.touching(position, reach, player?) -> { { body, handler } } -- every hittable
--                                      target whose edge is within reach studs of position
--                                      (flat); with player, only what they can reach from
--                                      where they stand (a training yard's from inside it)
--   Combat.hit(player, handler, damage) -- one hit of `damage` (rolled), as a slash's
--   Combat.knock(body, dir, studs, time) -- shoves a target studs along dir over time
--                                      seconds (a Smash sprint: Server/SprintAbility)
--   Combat.pushed(body, pos, dt) -> pos -- where its mover puts it this frame, shoved
--                                      (Server/Bosses, Minions and Training call it)
--
-- Every hit on every target rolls its own damage: the base times a random
-- Config.Slash.RollMin..RollMax, rounded to a whole number (at least 1), so the damage
-- numbers and training gains follow what that hit actually dealt.
-- Each hit deals that damage times the equipped weapon's Damage (Config.Weapons; the
-- player's Weapon attribute, Server/Arsenal).
-- A training yard's mobs and dummies are only hit by players standing in that yard
-- (QM, Oct 30: Shared/Yards), by slashes, shots and sprints alike.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Passes = require(Shared:WaitForChild("Passes"))
local Levels = require(Shared:WaitForChild("Levels"))
local Power = require(Shared:WaitForChild("Power"))
local Projectiles = require(Shared:WaitForChild("Projectiles"))
local Weapons = require(Shared:WaitForChild("Weapons"):WaitForChild("Weapons"))
local Yards = require(Shared:WaitForChild("Yards"))

local Combat = {}

local targets = {} -- [body] = handler

function Combat.add(body, handler)
	targets[body] = handler
end

function Combat.remove(body)
	targets[body] = nil
end

-- every attack checks this: a dead player's slashes, new shots and shots still in the air
-- deal nothing. It reads Health, not the Dead state, so a revive (the Phoenix's, when it
-- lands) that puts Health back above 0 brings attacking back with it.
function Combat.alive(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

-- (x2 with the x2 Damage pass: Shared/Passes)
function Combat.damage(player)
	return Config.Slash.Damage * Power.damage(player:GetAttribute("Strength")) * Passes.mult(player, "Damage")
end

local rng = Random.new()

local function roll(damage)
	local c = Config.Slash
	local lo, hi = c.RollMin or 1, c.RollMax or 1
	return math.max(1, math.round(damage * (lo + rng:NextNumber() * (hi - lo))))
end

-- (the HUD's counter shows your Strength itself: QM, Oct 25; and Level, what it makes you:
-- QM, Oct 31, Shared/Levels)
local function showPower(player)
	local strength = player:GetAttribute("Strength") or 0
	player:SetAttribute("Power", strength)
	player:SetAttribute("Level", Levels.of(strength))
end

-- a hit trains the damage it dealt x the enemy's Strength x Training.PerDamage (QM, Oct 25:
-- your gains follow your damage); each rebirth makes it Config.Rebirth.StrengthBonus more
function Combat.train(player, damage, strength)
	local amount = (damage or 0) * (strength or 1) * Config.Training.PerDamage
	if amount > 0 then
		local bonus = 1 + (player:GetAttribute("Rebirths") or 0) * Config.Rebirth.StrengthBonus
		player:SetAttribute("Strength", (player:GetAttribute("Strength") or 0) + amount * bonus)
		showPower(player)
	end
end

-- (after Strength is set from outside: loaded, or reset by a rebirth)
function Combat.refresh(player)
	showPower(player)
end

function Combat.join(player)
	player:SetAttribute("Strength", player:GetAttribute("Strength") or 0)
	showPower(player)
end

-- it catches every target whose body is within the arc's reach (Forward + Radius, plus
-- the target's own radius and a little slack) and inside its sweep (half the Arc either
-- side, plus slack for the target's width)
function Combat.slash(player, yaw, c)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not Combat.alive(player) then -- (died during the wind-up)
		return
	end
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local reach = c.Forward + c.Radius * 1.15 + 2
	local damage = Combat.damage(player) * Weapons.get(player:GetAttribute("Weapon")).Damage
	local hits = {}
	for body, handler in targets do
		if body:GetAttribute("Asleep") or body:GetAttribute("Intro") or body:GetAttribute("Burrowed") then
			continue -- (a boss arriving, asleep or underground can't be hit: QM, Oct 25)
		elseif not Yards.inside(body, root.Position) then
			continue -- (a training yard's, and you're outside it)
		elseif body.Parent then
			local radius = body:GetAttribute("Radius") or 0
			local offset = (body.Position - root.Position) * Vector3.new(1, 0, 1)
			local distance = offset.Magnitude
			if distance - radius <= reach then
				local angle = if distance > 1e-3
					then math.deg(math.acos(math.clamp(offset.Unit:Dot(look), -1, 1)))
					else 0
				local slack = math.deg(math.atan2(radius, math.max(distance, 1)))
				if angle <= c.Arc / 2 + slack + 10 then
					table.insert(hits, handler)
				end
			end
		else
			targets[body] = nil
		end
	end
	for _, handler in hits do
		task.spawn(handler, player, roll(damage))
	end
end

local function hittable(body)
	return body.Parent ~= nil
		and not body:GetAttribute("Asleep")
		and not body:GetAttribute("Intro")
		and not body:GetAttribute("Burrowed")
end

function Combat.touching(position, reach, player)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local out = {}
	for body, handler in targets do
		if hittable(body) and (not player or (root and Yards.inside(body, root.Position))) then
			local gap = ((body.Position - position) * Vector3.new(1, 0, 1)).Magnitude - (body:GetAttribute("Radius") or 0)
			if gap <= reach then
				table.insert(out, { body = body, handler = handler })
			end
		end
	end
	return out
end

function Combat.hit(player, handler, damage)
	task.spawn(handler, player, roll(damage))
end

local knocks = {} -- [body] = { velocity, left }

function Combat.knock(body, dir, studs, time)
	local flatDir = dir * Vector3.new(1, 0, 1)
	if flatDir.Magnitude < 1e-3 or time <= 0 then
		return
	end
	knocks[body] = { velocity = flatDir.Unit * (studs / time), left = time }
end

function Combat.pushed(body, pos, dt)
	local k = knocks[body]
	if not k then
		return pos
	end
	local step = math.min(dt, k.left)
	k.left -= step
	if k.left <= 0 or not body.Parent then
		knocks[body] = nil
	end
	return pos + k.velocity * step
end

-- shots in the air: { shot, player, damage }, stepped every frame against every target
local flying = {}
local MAX_FLYING = 300

-- (from where the shooter's own screen fired it, when that's close to where the server has
-- them: a rider moves a few studs in the time the message takes, and shots run from the
-- server's spot flew a little to the side of the ones drawn, missing what they hit there)
function Combat.shoot(player, id, yaw, seed, origin)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or #flying > MAX_FLYING or not Combat.alive(player) then
		return
	end
	local from = root.Position
	if origin and origin == origin then
		local off = Vector3.new(origin.X - from.X, 0, origin.Z - from.Z)
		if off.Magnitude <= Config.Shots.Trust then
			from += off
		end
	end
	local damage = Combat.damage(player) * Weapons.get(id).Damage
	for _, shot in Projectiles.spawn(id, from, yaw, seed, Projectiles.room(player:GetAttribute("LockedIn"))) do
		table.insert(flying, { shot = shot, player = player, damage = damage })
	end
end

RunService.Heartbeat:Connect(function(dt)
	if #flying == 0 then
		return
	end
	-- (a dead shooter's shots still in the air fizzle out)
	for i = #flying, 1, -1 do
		if not Combat.alive(flying[i].player) then
			table.remove(flying, i)
		end
	end
	local list = {}
	for body, handler in targets do
		if
			body.Parent
			and not body:GetAttribute("Asleep")
			and not body:GetAttribute("Intro")
			and not body:GetAttribute("Burrowed")
		then
			table.insert(list, { body = body, pos = body.Position, radius = body:GetAttribute("Radius") or 0, handler = handler })
		end
	end
	for i = #flying, 1, -1 do
		local f = flying[i]
		-- (a shot passes over a training yard's mobs unless its shooter is in that yard)
		local root = f.player.Character and f.player.Character:FindFirstChild("HumanoidRootPart")
		local at = root and root.Position
		local mine = {}
		for _, t in list do
			if Yards.inside(t.body, at) then
				table.insert(mine, t)
			end
		end
		for _, t in Projectiles.step(f.shot, dt, mine) do
			task.spawn(t.handler, f.player, roll(f.damage))
			-- a splash also hits everything else that close to where it struck
			if f.shot.splash then
				for _, other in mine do
					if other ~= t and ((other.pos - t.pos) * Vector3.new(1, 0, 1)).Magnitude - other.radius <= f.shot.splash then
						task.spawn(other.handler, f.player, roll(f.damage))
					end
				end
			end
		end
		if f.shot.dead or f.player.Parent == nil then
			table.remove(flying, i)
		end
	end
end)

Players.PlayerAdded:Connect(Combat.join)
for _, player in Players:GetPlayers() do
	Combat.join(player)
end

return Combat
