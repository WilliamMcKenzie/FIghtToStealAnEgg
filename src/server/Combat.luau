-- What a slash can hit, and what hitting trains (QM, Oct 24: Strength is a byproduct of
-- attacking). Bosses, training mobs and dummies register their invisible bodies here
-- with a handler; a slash checks every one of them (the reach and arc test bosses had)
-- and calls the handler of each it catches with the slash's damage.
--
-- Damage is Config.Slash.Damage scaled by the player's Strength (Shared/Power's log curve);
-- the player's Power attribute (the HUD's counter) shows it.
--
--   Combat.add(body, handler)        -- handler(player, damage); body has a Radius attribute
--   Combat.remove(body)
--   Combat.slash(player, yaw, c)     -- a player's slash along world yaw `yaw`
--   Combat.shoot(player, id, yaw)    -- a Ranged or Magic weapon's volley (Shared/Projectiles)
--   Combat.train(player, amount, ground) -- adds Strength (and updates Power); ground is a
--                                      Config.Training.Grounds entry whose band applies
--   Combat.refresh(player)           -- updates Power after Strength is set directly
--   Combat.damage(player) -> number
--
-- Each hit deals that damage times the equipped weapon's Damage (Config.Weapons; the
-- player's Weapon attribute, Server/Arsenal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Power = require(Shared:WaitForChild("Power"))
local Projectiles = require(Shared:WaitForChild("Projectiles"))
local Weapons = require(Shared:WaitForChild("Weapons"):WaitForChild("Weapons"))

local Combat = {}

local targets = {} -- [body] = handler

function Combat.add(body, handler)
	targets[body] = handler
end

function Combat.remove(body)
	targets[body] = nil
end

function Combat.damage(player)
	return Config.Slash.Damage * Power.damage(player:GetAttribute("Strength"))
end

local function showPower(player)
	player:SetAttribute("Power", Combat.damage(player))
end

-- how much of `amount` a hit trains at this Strength, by the ground's band (Config.Training:
-- full inside Need..Outgrow, less below or past it)
function Combat.gain(strength, amount, ground)
	if not ground then
		return amount
	end
	local t = Config.Training
	local need, outgrow = ground.Need or 0, ground.Outgrow
	if strength < need then
		return amount * (math.max(strength, 1) / need) ^ t.Under
	elseif outgrow and strength > outgrow then
		return amount * (outgrow / strength) ^ t.Over
	end
	return amount
end

-- at most one training hit every Training.Every seconds: within that window only the best
-- hit counts (a swing through a dummy and a crab trains the crab's)
local window = {} -- [player] = { at, given }

-- (each rebirth makes every hit train Config.Rebirth.StrengthBonus more)
function Combat.train(player, amount, ground)
	local strength = player:GetAttribute("Strength") or 0
	amount = Combat.gain(strength, amount or 0, ground)
	if amount <= 0 then
		return
	end
	local now = os.clock()
	local w = window[player]
	if not w or now - w.at >= Config.Training.Every then
		w = { at = now, given = 0 }
		window[player] = w
	end
	if amount > w.given then
		local bonus = 1 + (player:GetAttribute("Rebirths") or 0) * Config.Rebirth.StrengthBonus
		player:SetAttribute("Strength", strength + (amount - w.given) * bonus)
		w.given = amount
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
	if not root then
		return
	end
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local reach = c.Forward + c.Radius * 1.15 + 2
	local damage = Combat.damage(player) * Weapons.get(player:GetAttribute("Weapon")).Damage
	local hits = {}
	for body, handler in targets do
		if body.Parent then
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
		task.spawn(handler, player, damage)
	end
end

-- shots in the air: { shot, player, damage }, stepped every frame against every target
local flying = {}
local MAX_FLYING = 300

function Combat.shoot(player, id, yaw)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or #flying > MAX_FLYING then
		return
	end
	local damage = Combat.damage(player) * Weapons.get(id).Damage
	for _, shot in Projectiles.spawn(id, root.Position, yaw) do
		table.insert(flying, { shot = shot, player = player, damage = damage })
	end
end

RunService.Heartbeat:Connect(function(dt)
	if #flying == 0 then
		return
	end
	local list = {}
	for body, handler in targets do
		if body.Parent then
			table.insert(list, { body = body, pos = body.Position, radius = body:GetAttribute("Radius") or 0, handler = handler })
		end
	end
	for i = #flying, 1, -1 do
		local f = flying[i]
		for _, t in Projectiles.step(f.shot, dt, list) do
			task.spawn(t.handler, f.player, f.damage)
			-- a splash also hits everything else that close to where it struck
			if f.shot.splash then
				for _, other in list do
					if other ~= t and ((other.pos - t.pos) * Vector3.new(1, 0, 1)).Magnitude - other.radius <= f.shot.splash then
						task.spawn(other.handler, f.player, f.damage)
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
Players.PlayerRemoving:Connect(function(player)
	window[player] = nil
end)
for _, player in Players:GetPlayers() do
	Combat.join(player)
end

return Combat
