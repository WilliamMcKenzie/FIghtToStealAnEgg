-- What Strength does (QM, Oct 25): it doesn't add to your damage one for one, it scales
-- it, and your attack speed a little, both on a log curve (Config.Power): a lot at first,
-- less and less the more you have. The weapon's own Damage multiplies on top.
--
-- It counts by level (Config.Levels, Shared/Levels; QM Oct 31): you get the curve at your
-- level's Power, so damage and speed step up each level. Level 1 has level 2's divided by
-- Levels.First, so the first level up is a big jump. Levels.Bonus adds extra per level.
--
--   Power.damage(strength) -> times Slash.Damage
--   Power.speed(strength)  -> attacks this many times faster (cooldowns divided by it)

local Config = require(script.Parent:WaitForChild("Config"))
local Levels = require(script.Parent:WaitForChild("Levels"))

local Power = {}

-- the curve's shape (Config.Power.Curve, set from the powerscaling dashboard): Log (each
-- point counts for less, never stops growing), Power ((S / Scale) ^ Exponent: 0.5 is a
-- square root), Linear (S / Scale), Exp (1 - e^(-S / Scale): fast, then levels off at 1)
local function curve(strength)
	local tune = Config.Power
	local x = math.max(strength or 0, 0) / tune.Scale
	if tune.Curve == "Power" then
		return x ^ (tune.Exponent or 0.5)
	elseif tune.Curve == "Linear" then
		return x
	elseif tune.Curve == "Exp" then
		return 1 - math.exp(-x)
	end
	return math.log(1 + x)
end

-- the curve's damage and speed at a Power, before levels
local function rawDamage(strength)
	return 1 + Config.Power.Damage * curve(strength)
end
local function rawSpeed(strength)
	return 1 + Config.Power.Speed * curve(strength)
end

-- (level 1: level 2's, cut by Levels.First; then the curve at the level's own Power, and
-- Levels.Bonus for every level past 1)
local function stepped(strength, raw, key)
	local c = Config.Levels
	local level = Levels.of(strength)
	local bonus = 1 + (c.Bonus[key] or 0) * (level - 1)
	if level <= 1 then
		return raw(Levels.at(2)) / (c.First[key] or 1)
	end
	return raw(Levels.at(level)) * bonus
end

function Power.damage(strength)
	return stepped(strength, rawDamage, "Damage")
end

function Power.speed(strength)
	return math.min(stepped(strength, rawSpeed, "Speed"), Config.Power.MaxSpeed)
end

return Power
