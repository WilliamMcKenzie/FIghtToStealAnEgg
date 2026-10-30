-- Training yards keep their mobs and dummies to themselves (QM, Oct 30: no attacking
-- training animals unless you're inside the training zone). Server/Training stamps each
-- body with its yard (attributes YardX, YardZ, YardHalf: the fence's centre and half
-- its side); a body without them (a boss) can be hit from anywhere. Server/Combat drops
-- hits from outside, and the client won't aim at them from outside (client/init, Shots).
--
--   Yards.inside(body, position) -> boolean -- position is in body's yard (or it has none)

local Yards = {}

local SLACK = 0.5 -- studs past the fence that still count (standing on it)

function Yards.inside(body, position)
	local half = body:GetAttribute("YardHalf")
	if not half then
		return true
	end
	if not position then
		return false
	end
	local x, z = body:GetAttribute("YardX") or 0, body:GetAttribute("YardZ") or 0
	return math.abs(position.X - x) <= half + SLACK and math.abs(position.Z - z) <= half + SLACK
end

return Yards
