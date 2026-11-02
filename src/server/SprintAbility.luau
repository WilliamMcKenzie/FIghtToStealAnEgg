-- Sprint abilities (QM, Oct 30; Config.SprintPets, Config.SprintAbility). The rider's own
-- client says when their sprint starts and stops (client/Sprint: Sprint.Delay seconds of
-- riding without stopping); if their pet has an ability, it's on in their SprintAbility
-- attribute till then, which everyone draws (client/SprintAbility) and the rest of the
-- server reads:
--   Burrow, Fly, Leap  Server/BossAttacks lets the hits through or not (BossAttacks.dodges)
--   Glow         Server/Regen heals faster
--   Smash, Crabwalk  here: running into an enemy hits it, knocks it back (Combat.knock)
--                and ends the sprint (the SprintEnd remote tells the rider's client)
--   Frost        here: freezes the boss minions round you (Minions.freezeNear)
--   Bombs        here: a bomb thrown every Every seconds, landing and going off Fuse
--                seconds later (every client draws it from the PetLob remote: client/Bombs)
--   Rage         Shared/Pets.rage: bigger, faster attacks and regen the lower your health
-- On top of that, a pet in Config.SprintFire fires things of its own while it's on (QM,
-- Nov 2): projectiles (the PetShot remote: every client draws them, client/Shots), bombs
-- lobbed at the nearest enemy (PetLob: client/Bombs), blasts where you are (BossSplash's
-- look), or an echo of each of your own attacks (Server's Slash and Shoot handlers ask
-- SprintAbility.echoes).
-- It's off again whenever the pet changes or the rider dies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Weapons = require(Shared:WaitForChild("Weapons"):WaitForChild("Weapons"))
local Combat = require(script.Parent.Combat)
local Minions = require(script.Parent.Minions)

local SprintAbility = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "SprintAbility" -- (client -> server: on, a boolean)
remote.Parent = ReplicatedStorage

local endRemote = Instance.new("RemoteEvent")
endRemote.Name = "SprintEnd" -- (server -> the rider: your sprint's over, ride on to start it again)
endRemote.Parent = ReplicatedStorage

local bombRemote = Instance.new("RemoteEvent")
bombRemote.Name = "PetBomb" -- (server -> everyone: { at, start, fuse, radius, style })
bombRemote.Parent = ReplicatedStorage

local shotRemote = Instance.new("RemoteEvent")
shotRemote.Name = "PetShot" -- (server -> everyone: rider, weapon id, yaw, seed)
shotRemote.Parent = ReplicatedStorage

local lobRemote = Instance.new("RemoteEvent")
lobRemote.Name = "PetLob" -- (server -> everyone: { from, to, start, airtime, radius, height, style })
lobRemote.Parent = ReplicatedStorage

local riders = {} -- [player] = { kind, wait (seconds to the next bomb), count, fire (seconds to the next SprintFire) }

local function abilityOf(player)
	return Config.SprintPets[player:GetAttribute("Pet") or "Horse"]
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and Combat.alive(player) then root else nil
end

local function stop(player, tell)
	if riders[player] then
		riders[player] = nil
		player:SetAttribute("SprintAbility", nil)
		if tell then
			endRemote:FireClient(player)
		end
	end
end

-- a hit's damage: the player's slash with their weapon, x the ability's Damage
local function damage(player, k)
	return Combat.damage(player) * Weapons.get(player:GetAttribute("Weapon")).Damage * k
end

remote.OnServerEvent:Connect(function(player, on)
	local kind = abilityOf(player)
	if on == true and kind and rootOf(player) then
		if not riders[player] then
			riders[player] = { kind = kind, wait = 0, since = os.clock() }
			player:SetAttribute("SprintAbility", kind)
		end
	else
		stop(player, false)
	end
end)

local function fireOf(player)
	return Config.SprintFire.Pets[player:GetAttribute("Pet") or "Horse"]
end

-- is this rider's sprint echoing their attacks (the Mimic)?
function SprintAbility.echoes(player)
	local f = fireOf(player)
	return f ~= nil and f.Echo == true and riders[player] ~= nil
end

-- a volley of weapon id's shots from the rider, drawn by everyone; damage: each shot's
-- (nil: the weapon's own)
function SprintAbility.shoot(player, id, yaw, seed, damage)
	shotRemote:FireAllClients(player, id, yaw, seed)
	Combat.shoot(player, id, yaw, seed, nil, damage)
end

local function yawTo(from, to)
	local v = (to - from) * Vector3.new(1, 0, 1)
	return math.atan2(-v.X, -v.Z)
end

local function nearest(player, pos)
	local best, gap = nil, math.huge
	for _, t in Combat.touching(pos, Config.SprintFire.Range, player) do
		local d = ((t.body.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
		if d < gap then
			best, gap = t.body, d
		end
	end
	return best
end

local function blast(player, at, radius, k)
	for _, t in Combat.touching(at, radius, player) do
		Combat.hit(player, t.handler, damage(player, k))
	end
end

-- one go of the pet's SprintFire (f) from root
local function fire(player, root, f)
	local pos = root.Position
	local k = f.Damage or 1
	if f.Shot then
		local yaw
		if f.Aim then
			local target = nearest(player, pos)
			if not target then
				return
			end
			yaw = yawTo(pos, target.Position)
		else
			yaw = yawTo(Vector3.zero, root.CFrame.LookVector)
		end
		local each = damage(player, k)
		if f.Directions then
			for i = 0, f.Directions - 1 do
				SprintAbility.shoot(player, f.Shot, yaw + i * 2 * math.pi / f.Directions, math.random(0, 2 ^ 30 - 1), each)
			end
		else
			for _, a in f.Angles or { 0 } do
				SprintAbility.shoot(player, f.Shot, yaw + math.rad(a), math.random(0, 2 ^ 30 - 1), each)
			end
		end
	elseif f.Lob then
		local target = nearest(player, pos)
		if not target then
			return
		end
		local cfg = Config.SprintFire
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		local feet = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 0)
		local to = Vector3.new(target.Position.X, pos.Y - feet, target.Position.Z)
		lobRemote:FireAllClients({
			from = pos,
			to = to,
			start = workspace:GetServerTimeNow(),
			airtime = cfg.LobAirtime,
			radius = f.Radius,
			height = cfg.LobHeight,
			style = f.Lob,
		})
		task.delay(cfg.LobAirtime, function()
			if player.Parent ~= nil and Combat.alive(player) then
				blast(player, to, f.Radius, k)
			end
		end)
	elseif f.Blast then
		local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
		local at = pos - Vector3.new(0, root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 0), 0)
		local splash = ReplicatedStorage:FindFirstChild("BossSplash")
		if splash then
			splash:FireAllClients(at, f.Radius, f.Blast)
		end
		blast(player, at, f.Radius, k)
	end
end

-- one bomb thrown up out of its back (QM, Nov 2: visibly flung through the air like the
-- Cactus Boss's, not just put down): it lands Near..Far studs off where it was thrown from,
-- any way round, Fuse seconds later, and goes off there (drawn from PetLob: client/Bombs)
local function bomb(player, root)
	local cfg = Config.SprintAbility.Bombs
	local r = riders[player]
	r.count = (r.count or 0) + 1
	local pos = root.Position
	local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
	local feet = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 0)
	local angle = math.random() * 2 * math.pi
	local out = cfg.Near + math.random() * (cfg.Far - cfg.Near)
	local to = Vector3.new(pos.X + math.cos(angle) * out, pos.Y - feet, pos.Z + math.sin(angle) * out)
	lobRemote:FireAllClients({
		from = pos + Vector3.new(0, feet * 0.5, 0),
		to = to,
		start = workspace:GetServerTimeNow(),
		airtime = cfg.Fuse,
		radius = cfg.Radius,
		height = cfg.Height,
		style = if r.count % 2 == 0 then "PetYellow" else "PetOrange",
	})
	task.delay(cfg.Fuse, function()
		if player.Parent == nil then
			return
		end
		for _, t in Combat.touching(to, cfg.Radius, player) do
			Combat.hit(player, t.handler, damage(player, cfg.Damage))
		end
	end)
end

RunService.Heartbeat:Connect(function(dt)
	for player, r in riders do
		local root = rootOf(player)
		if not root or player.Parent == nil or abilityOf(player) ~= r.kind then
			stop(player, player.Parent ~= nil)
			continue
		end
		local pos = root.Position
		local f = fireOf(player)
		if f and f.Every then
			r.fire = (r.fire or 0) - dt
			if r.fire <= 0 then
				r.fire = f.Every
				fire(player, root, f)
			end
		end
		if r.kind == "Frost" then
			local cfg = Config.SprintAbility.Frost
			Minions.freezeNear(pos, cfg.Radius, cfg.Freeze, cfg.Again)
		elseif r.kind == "Smash" or r.kind == "Crabwalk" then
			local cfg = Config.SprintAbility.Smash
			local reach = Pets.stats(player:GetAttribute("Pet")).Hitbox * cfg.Grow + cfg.Reach
			local hits = Combat.touching(pos, reach, player)
			if #hits > 0 then
				-- (harder the longer it's been charging)
				local built = math.clamp((os.clock() - r.since) / cfg.Ramp, 0, 1)
				local k = cfg.Damage + (cfg.MaxDamage - cfg.Damage) * built
				for _, t in hits do
					Combat.hit(player, t.handler, damage(player, k))
					local studs = cfg.Knockback * (if t.body:GetAttribute("Boss") then cfg.BossKnock else 1)
					Combat.knock(t.body, t.body.Position - pos, studs, cfg.KnockTime)
				end
				stop(player, true)
			end
		elseif r.kind == "Bombs" then
			local cfg = Config.SprintAbility.Bombs
			r.wait -= dt
			if r.wait <= 0 then
				r.wait = cfg.Every
				bomb(player, root)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	riders[player] = nil
end)

return SprintAbility
