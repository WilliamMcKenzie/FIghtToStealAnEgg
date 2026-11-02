-- What a boss, minion or training mob takes up on the ground, for the player's hits (QM,
-- Nov 2: "boss hitbox doesn't really increase with boss size": on the Volcano Tortoise
-- you had to walk almost inside it to land a melee hit). Every target used to be a circle
-- of its Radius, a hand-set number that didn't grow with the drawing (the Tortoise's 11
-- studs against a body 50 studs across, drawn x its PetScale too). Now each one's body
-- carries the flat box its drawing fills, worked out from the same model data and size it's
-- drawn at, turned with the body as it turns, so a slash or a shot lands at the edge you
-- can see, on every boss, minion and mob alike.
--
-- Body attributes (studs, in the body's own frame: X across, Z along, its front is -Z):
--   FootMid   Vector3  the box's middle, off the body's Position (Y unused)
--   FootHalf  Vector3  half its width (X) and length (Z) (Y unused)
--
-- A body without them (a player, a dummy) is still the circle of its Radius attribute.
-- Radius itself is left as it was: it places the enemy's own attacks, its walking and its
-- arena margins, all tuned to it. This is only what the player's attacks can hit.
--
--   Footprint.set(body, data, size)   -- server: from model data at `size` studs per unit
--   Footprint.closest(body, point) -> Vector3  -- the point of it nearest `point` (flat, at
--                                     point's height; point itself when it's inside)
--   Footprint.gap(body, point) -> number       -- flat studs from point to its edge (0 inside)
--   Footprint.segmentGap(body, a, b) -> number -- flat studs from the segment a..b to its
--                                     edge (0 if it crosses it); nil for a body without one

local Footprint = {}

-- the flat box a model's visible parts fill at its own size: { mid, half } (Vector3s, Y 0)
local boxes = {} -- [data] = { mid, half }
local function box(data)
	if boxes[data] then
		return boxes[data]
	end
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in data.parts do
		if not part.hidden then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.cframe:GetComponents()
			local h = part.size / 2
			local e = Vector3.new(
				math.abs(r00) * h.X + math.abs(r01) * h.Y + math.abs(r02) * h.Z,
				math.abs(r10) * h.X + math.abs(r11) * h.Y + math.abs(r12) * h.Z,
				math.abs(r20) * h.X + math.abs(r21) * h.Y + math.abs(r22) * h.Z
			)
			local c = Vector3.new(x, y, z)
			lo, hi = lo:Min(c - e), hi:Max(c + e)
		end
	end
	local out = {
		mid = Vector3.new((lo.X + hi.X) / 2, 0, (lo.Z + hi.Z) / 2),
		half = Vector3.new((hi.X - lo.X) / 2, 0, (hi.Z - lo.Z) / 2),
	}
	boxes[data] = out
	return out
end

function Footprint.set(body, data, size)
	if not data or not data.parts or #data.parts == 0 then
		return
	end
	local b = box(data)
	body:SetAttribute("FootMid", b.mid * size)
	body:SetAttribute("FootHalf", b.half * size)
end

-- its box in flat world terms: middle, across and along (unit vectors), half sizes
local function frame(body)
	local half = body:GetAttribute("FootHalf")
	if typeof(half) ~= "Vector3" then
		return nil
	end
	local mid = body:GetAttribute("FootMid") or Vector3.zero
	local cf = body.CFrame
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	local back = Vector3.new(-cf.LookVector.X, 0, -cf.LookVector.Z)
	right = if right.Magnitude > 1e-4 then right.Unit else Vector3.xAxis
	back = if back.Magnitude > 1e-4 then back.Unit else Vector3.zAxis
	local centre = Vector3.new(cf.Position.X, 0, cf.Position.Z) + right * mid.X + back * mid.Z
	return centre, right, back, half.X, half.Z
end

-- (a point in the box's own flat coordinates, and back)
local function toLocal(centre, right, back, p)
	local d = Vector3.new(p.X, 0, p.Z) - centre
	return d:Dot(right), d:Dot(back)
end

function Footprint.closest(body, point)
	local centre, right, back, hx, hz = frame(body)
	if not centre then
		local r = body:GetAttribute("Radius") or 0
		local d = Vector3.new(point.X - body.Position.X, 0, point.Z - body.Position.Z)
		if d.Magnitude <= r then
			return point
		end
		local edge = Vector3.new(body.Position.X, 0, body.Position.Z) + d.Unit * r
		return Vector3.new(edge.X, point.Y, edge.Z)
	end
	local x, z = toLocal(centre, right, back, point)
	local p = centre + right * math.clamp(x, -hx, hx) + back * math.clamp(z, -hz, hz)
	return Vector3.new(p.X, point.Y, p.Z)
end

function Footprint.gap(body, point)
	local p = Footprint.closest(body, point)
	return Vector3.new(point.X - p.X, 0, point.Z - p.Z).Magnitude
end

-- (studs from a point to a flat segment)
local function toSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 1e-9 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

-- (studs from a point to the box, in its own coordinates)
local function toBox(x, z, hx, hz)
	local dx, dz = math.max(math.abs(x) - hx, 0), math.max(math.abs(z) - hz, 0)
	return math.sqrt(dx * dx + dz * dz)
end

function Footprint.segmentGap(body, a, b)
	local centre, right, back, hx, hz = frame(body)
	if not centre then
		return nil
	end
	local ax, az = toLocal(centre, right, back, a)
	local bx, bz = toLocal(centre, right, back, b)
	-- crossing it (Liang-Barsky clip of the segment against the box): 0
	local t0, t1 = 0, 1
	local dx, dz = bx - ax, bz - az
	local inside = true
	for _, edge in { { -dx, ax + hx }, { dx, hx - ax }, { -dz, az + hz }, { dz, hz - az } } do
		local p, q = edge[1], edge[2]
		if math.abs(p) < 1e-9 then
			if q < 0 then
				inside = false
				break
			end
		else
			local r = q / p
			if p < 0 then
				t0 = math.max(t0, r)
			else
				t1 = math.min(t1, r)
			end
			if t0 > t1 then
				inside = false
				break
			end
		end
	end
	if inside then
		return 0
	end
	-- else the nearest of its ends to the box, or of the box's corners to it
	local best = math.min(toBox(ax, az, hx, hz), toBox(bx, bz, hx, hz))
	for _, corner in { { -hx, -hz }, { hx, -hz }, { -hx, hz }, { hx, hz } } do
		best = math.min(best, toSegment(corner[1], corner[2], ax, az, bx, bz))
	end
	return best
end

return Footprint
