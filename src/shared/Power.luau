-- What Strength does (QM, Oct 25): it doesn't add to your damage one for one, it scales
-- it, and your attack speed a little, both on a log curve (Config.Power): a lot at first,
-- less and less the more you have. The weapon's own Damage multiplies on top.
--
--   Power.damage(strength) -> times Slash.Damage (1 at 0 Strength)
--   Power.speed(strength)  -> attacks this many times faster (cooldowns divided by it)

local Config = require(script.Parent:WaitForChild("Config"))

local Power = {}

local function curve(strength)
	return math.log(1 + math.max(strength or 0, 0) / Config.Power.Scale)
end

function Power.damage(strength)
	return 1 + Config.Power.Damage * curve(strength)
end

function Power.speed(strength)
	return math.min(1 + Config.Power.Speed * curve(strength), Config.Power.MaxSpeed)
end

return Power
