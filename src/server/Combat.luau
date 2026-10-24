-- What a slash can hit, and what hitting trains (QM, Oct 24: Strength is a byproduct of
-- attacking). Bosses, training mobs and dummies register their invisible bodies here
-- with a handler; a slash checks every one of them (the reach and arc test bosses had)
-- and calls the handler of each it catches with the slash's damage.
--
-- Damage is Config.Slash.Damage plus the player's Strength x Training.DamagePerStrength;
-- the player's Power attribute (the HUD's counter) shows it.
--
--   Combat.add(body, handler)        -- handler(player, damage); body has a Radius attribute
--   Combat.remove(body)
--   Combat.slash(player, yaw, c)     -- a player's slash along world yaw `yaw`
--   Combat.train(player, amount)     -- adds Strength (and updates Power)
--   Combat.refresh(player)           -- updates Power after Strength is set directly
--   Combat.damage(player) -> number

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Combat = {}

local targets = {} -- [body] = handler

function Combat.add(body, handler)
	targets[body] = handler
end

function Combat.remove(body)
	targets[body] = nil
end

function Combat.damage(player)
	return Config.Slash.Damage + (player:GetAttribute("Strength") or 0) * Config.Training.DamagePerStrength
end

local function showPower(player)
	player:SetAttribute("Power", Combat.damage(player))
end

-- (each rebirth makes every hit train Config.Rebirth.StrengthBonus more)
function Combat.train(player, amount)
	if amount and amount > 0 then
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
	if not root then
		return
	end
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local reach = c.Forward + c.Radius * 1.15 + 2
	local damage = Combat.damage(player)
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

Players.PlayerAdded:Connect(Combat.join)
for _, player in Players:GetPlayers() do
	Combat.join(player)
end

return Combat
