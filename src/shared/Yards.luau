-- Training grounds keep their mobs to themselves (QM, Oct 30: no attacking training
-- animals unless you're inside the training zone). Each ground is a region off the base
-- (QM, Oct 30: Ice and Meadow west, Lava and Desert east), its bounds in the map (the Base
-- area's Training: { name, x0, z0, x1, z1 }, its corridor through the base wall and all).
-- Server/Training stamps each mob with them (attribute Yard, a Rect: x0, z0 to x1, z1); a
-- body without one (a boss) can be hit from anywhere. Server/Combat drops hits from
-- outside, and the client won't aim at them from outside (client/init, Shots).
--
--   Yards.inside(body, position) -> boolean -- position is in body's ground (or it has none)
--   Yards.stamp(body, bounds)               -- { x0, z0, x1, z1 }

local Yards = {}

local SLACK = 0.5 -- studs past the bounds that still count

function Yards.stamp(body, b)
	body:SetAttribute(
		"Yard",
		Rect.new(math.min(b[1], b[3]), math.min(b[2], b[4]), math.max(b[1], b[3]), math.max(b[2], b[4]))
	)
end

function Yards.inside(body, position)
	local yard = body:GetAttribute("Yard")
	if typeof(yard) ~= "Rect" then
		return true
	end
	if not position then
		return false
	end
	return position.X >= yard.Min.X - SLACK
		and position.X <= yard.Max.X + SLACK
		and position.Z >= yard.Min.Y - SLACK
		and position.Z <= yard.Max.Y + SLACK
end

return Yards
