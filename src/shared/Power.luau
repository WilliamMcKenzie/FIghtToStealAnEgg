-- What Strength does (QM, Oct 25): it doesn't add to your damage one for one, it scales
-- it, and your attack speed a little, both on a log curve (Config.Power): a lot at first,
-- less and less the more you have. The weapon's own Damage multiplies on top.
--
--   Power.damage(strength) -> times Slash.Damage (1 at 0 Strength)
--   Power.speed(strength)  -> attacks this many times faster (cooldowns divided by it)

local Config = require(script.Parent:WaitForChild("Config"))

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

function Power.damage(strength)
	return 1 + Config.Power.Damage * curve(strength)
end

function Power.speed(strength)
	return math.min(1 + Config.Power.Speed * curve(strength), Config.Power.MaxSpeed)
end

return Power
