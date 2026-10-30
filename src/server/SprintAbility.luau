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
--   Bombs        here: a bomb every Every seconds, going off Fuse seconds later (every
--                client draws it from the PetBomb remote: client/Bombs)
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

local riders = {} -- [player] = { kind, wait (seconds to the next bomb), count }

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
			riders[player] = { kind = kind, wait = 0 }
			player:SetAttribute("SprintAbility", kind)
		end
	else
		stop(player, false)
	end
end)

local function bomb(player, at)
	local cfg = Config.SprintAbility.Bombs
	local r = riders[player]
	r.count = (r.count or 0) + 1
	bombRemote:FireAllClients({
		at = at,
		start = workspace:GetServerTimeNow(),
		fuse = cfg.Fuse,
		radius = cfg.Radius,
		style = if r.count % 2 == 0 then "PetYellow" else "PetOrange",
	})
	task.delay(cfg.Fuse, function()
		if player.Parent == nil then
			return
		end
		for _, t in Combat.touching(at, cfg.Radius) do
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
		if r.kind == "Frost" then
			local cfg = Config.SprintAbility.Frost
			Minions.freezeNear(pos, cfg.Radius, cfg.Freeze, cfg.Again)
		elseif r.kind == "Smash" or r.kind == "Crabwalk" then
			local cfg = Config.SprintAbility.Smash
			local reach = Pets.stats(player:GetAttribute("Pet")).Hitbox * cfg.Grow + cfg.Reach
			local hits = Combat.touching(pos, reach)
			if #hits > 0 then
				for _, t in hits do
					Combat.hit(player, t.handler, damage(player, cfg.Damage))
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
				local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
				bomb(player, pos - Vector3.new(0, root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 0), 0))
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	riders[player] = nil
end)

return SprintAbility
