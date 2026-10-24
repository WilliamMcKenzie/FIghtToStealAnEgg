-- The sword slash: a flat crescent lying on the ground plane in front of the player,
-- best seen from above (QM, Oct 23: Archero-style, like Born Again's polygonal slash).
--
-- Shape, in the slash's own frame (Y up, the player faces -Z, angle 0 = straight ahead):
--   outer edge  a polygon of OuterSegments segments, corners on a circle of Radius
--   inner edge  a polygon of InnerSegments segments, corners Radius - Width * profile(u)
--               out, with profile = Ends + (1 - Ends) * sin(pi u^Skew)^Belly: thickest
--               near the middle, still Ends wide at both (flat) ends
--   seed        each slash rolls its own shape from a seed (roll(), c.Variety) and then
--               its corners (corners()): evenly spaced, then each nudged by up to Jitter
--               of a segment, so the segments are uneven and no two slashes match;
--               the inner edge's corners start half a segment out of step with the
--               outer's, and each corner's radius wobbles by up to RadiusJitter
--   ends        flat: a straight cut from the outer edge's end to the inner edge's
-- where u runs 0..1 along the swing. Both edges are straight between their corners, so
-- the crescent is cut into strips at every corner of either edge (plus extra cuts so no
-- strip is longer than MaxStrip, for the fade), and each strip is one Beam: a Beam is a
-- quad whose width at each end follows its own attachment, so neighbouring strips share
-- their edge exactly and each strip's Transparency is a smooth 0..1 sequence, which makes
-- the fade continuous across the arc even though the outline is faceted.
--
-- Animation (t = seconds since the swing):
--   lead   u_L = easeOut(t / Sweep): the leading edge, clipped exactly (no popping)
--   trail  a strip's brightness = 1 - (u_L - u) / Trail, so the arc fades toward the tail
--   fade   after Sweep + Hold, Trail shrinks to 0 over Fade: the arc dissolves from the
--          tail into the leading edge
--   pop    the radius grows from Pop * Radius to Radius during the sweep
--
-- SlashFx.play(cframe, dir, config, follow, seed) -> handle; cframe = the slash's centre on the
-- plane (look vector = forward), dir = 1 swings left to right, -1 right to left. `follow`
-- (optional) returns the centre's position each frame, so the slash moves with the player.
-- handle.leadCFrame() gives the leading edge (for the sword riding it).

local RunService = game:GetService("RunService")

local SlashFx = {}

local function easeOut(x, power)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ power
end

local function angle(c, u, dir)
	local half = math.rad(c.Arc) / 2
	return dir * (-half + u * 2 * half)
end

local function onCircle(a, r)
	return Vector3.new(math.sin(a), 0, -math.cos(a)) * r
end

local function profile(c, u)
	-- (Skew warps u so the thickest point slides toward one end)
	return c.Ends + (1 - c.Ends) * math.sin(math.pi * math.clamp(u, 0, 1) ^ c.Skew) ^ c.Belly
end

-- A polygon's corners for one slash: n segments, each corner u = (k + nudge) / n with
-- nudge in +-Jitter/2 (ends pinned at 0 and 1), `offset` segments out of step, and a
-- radius factor 1 +- RadiusJitter. Returns { { u, radiusFactor }, ... } sorted by u.
local function corners(c, n, offset, rng)
	local list = { { 0, 1 } }
	for k = 1, if offset > 0 then n else n - 1 do
		local u = (k - offset + (rng:NextNumber() - 0.5) * c.Jitter) / n
		if u > 0.02 and u < 0.98 then
			table.insert(list, { u, 1 + (rng:NextNumber() * 2 - 1) * c.RadiusJitter })
		end
	end
	table.insert(list, { 1, 1 })
	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)
	return list
end

-- the point at u along a polygon with those corners, a corner at u0 sitting r(u0) times
-- its radius factor out
local function polyline(c, list, u, dir, r)
	u = math.clamp(u, 0, 1)
	for i = 1, #list - 1 do
		local u0, u1 = list[i][1], list[i + 1][1]
		if u <= u1 or i == #list - 1 then
			local p0 = onCircle(angle(c, u0, dir), r(u0) * list[i][2])
			local p1 = onCircle(angle(c, u1, dir), r(u1) * list[i + 1][2])
			return p0:Lerp(p1, (u - u0) / math.max(u1 - u0, 1e-6))
		end
	end
	return Vector3.zero
end

-- Points of the crescent at parameter u, in the slash frame: outer, inner, and the
-- radial direction at u.
local function shape(c, poly, u, dir, radius)
	local scale = radius / c.Radius
	local outer = polyline(c, poly.outer, u, dir, function()
		return radius
	end)
	local inner = polyline(c, poly.inner, u, dir, function(v)
		return radius - c.Width * scale * profile(c, v)
	end)
	return outer, inner, onCircle(angle(c, u, dir), 1)
end

-- where the strips are cut: every corner of either edge, then evenly within each gap so
-- none is longer than MaxStrip
local function cuts(c, poly)
	local marks = {}
	for _, corner in poly.outer do
		marks[corner[1]] = true
	end
	for _, corner in poly.inner do
		marks[corner[1]] = true
	end
	local sorted = {}
	for u in marks do
		table.insert(sorted, u)
	end
	table.sort(sorted)
	local out = { sorted[1] }
	for i = 2, #sorted do
		local a, b = sorted[i - 1], sorted[i]
		local n = math.max(1, math.ceil((b - a) / c.MaxStrip - 1e-6))
		for k = 1, n do
			table.insert(out, a + (b - a) * k / n)
		end
	end
	return out
end

-- An attachment at `pos` whose beam width runs along `across` and lies flat. A Beam with
-- FaceCamera off spans its width along each attachment's UpVector (checked in Studio).
local UP = Vector3.yAxis
local function place(att, pos, across)
	local width = across.Unit
	att.CFrame = CFrame.fromMatrix(pos, width:Cross(UP).Unit, width)
end

local function makeLayer(parent, count, c, color, zoffset)
	local strips = table.create(count)
	for i = 1, count do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent = parent
		a1.Parent = parent
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = false
		beam.Segments = 1
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = c.Glow
		beam.LightInfluence = 0
		beam.Brightness = 1
		beam.ZOffset = zoffset
		beam.Transparency = NumberSequence.new(1)
		beam.Parent = parent
		strips[i] = { a0 = a0, a1 = a1, beam = beam }
	end
	return strips
end

-- This slash's own look, rolled from its seed: every number named in c.Variety is
-- scaled by a random factor in its { min, max } (segment counts are rounded), so each
-- slash has its own reach, thickness, belly, ends and facets. The same seed always
-- rolls the same slash (other players get the seed through the relay).
function SlashFx.roll(c, rng)
	local v = table.clone(c)
	for name, range in c.Variety do
		local value = c[name] * (range[1] + rng:NextNumber() * (range[2] - range[1]))
		v[name] = if name:find("Segments") then math.max(2, math.round(value)) else value
	end
	return v
end

-- The slash's parts and its step(dt) (returns true once it's finished and gone), without
-- running it: SlashFx.play runs it every frame, and a Studio preview can step it to any t.
function SlashFx.new(origin, dir, c, follow, seed)
	local rng = Random.new(seed)
	c = SlashFx.roll(c, rng)
	local poly = {
		outer = corners(c, c.OuterSegments, 0, rng),
		inner = corners(c, c.InnerSegments, 0.5, rng),
	}
	local at = cuts(c, poly)
	local steps = #at - 1
	local part = Instance.new("Part")
	part.Name = "Slash"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = origin
	local body = makeLayer(part, steps, c, c.Color, 0)
	part.Parent = workspace

	local handle = { t = 0, lead = 0, radius = c.Radius * c.Pop, done = false }
	local t = 0

	-- strip i covering u in [ua, ub], with brightness ba..bb
	local function draw(strip, ua, ub, ba, bb, radius, opacity)
		if ub <= ua or (ba <= 0 and bb <= 0) then
			strip.beam.Enabled = false
			return
		end
		local oa, ia, ra = shape(c, poly, ua, dir, radius)
		local ob, ib, rb = shape(c, poly, ub, dir, radius)
		local wa, wb = (oa - ia).Magnitude, (ob - ib).Magnitude
		-- (a zero-width end, if Ends is 0, still needs a direction: use the radial)
		place(strip.a0, (oa + ia) / 2, if wa > 1e-3 then oa - ia else ra)
		place(strip.a1, (ob + ib) / 2, if wb > 1e-3 then ob - ib else rb)
		strip.beam.Width0 = wa
		strip.beam.Width1 = wb
		strip.beam.Transparency =
			NumberSequence.new(1 - math.clamp(ba, 0, 1) * opacity, 1 - math.clamp(bb, 0, 1) * opacity)
		strip.beam.Enabled = true
	end

	local function step(dt)
		t += dt
		if follow then
			origin = CFrame.new(follow()) * origin.Rotation
			part.CFrame = origin
		end
		local lead = easeOut(t / c.Sweep, c.Ease)
		local radius = c.Radius * (c.Pop + (1 - c.Pop) * easeOut(t / c.Sweep, 2))
		local fade = math.clamp((t - c.Sweep - c.Hold) / c.Fade, 0, 1)
		local trail = c.Trail * (1 - easeOut(fade, 2))
		handle.t, handle.lead, handle.radius = t, lead, radius

		for i = 1, steps do
			local ua, ub = at[i], at[i + 1]
			ub = math.min(ub, lead) -- clip at the leading edge
			local function bright(u)
				if trail <= 1e-4 then
					return 0
				end
				return 1 - (lead - u) / trail
			end
			local ba, bb = bright(ua), bright(ub)
			draw(body[i], ua, ub, ba, bb, radius, c.Opacity)
		end

		if t >= c.Sweep + c.Hold + c.Fade then
			handle.done = true
			part:Destroy()
			return true
		end
		return false
	end

	-- the leading edge's frame in world space: position on the outer polygon, LookVector
	-- pointing outward along the radial, UpVector up
	function handle.leadCFrame()
		local outer, _, radial = shape(c, poly, handle.lead, dir, handle.radius)
		return origin * CFrame.lookAt(outer, outer + radial)
	end

	handle.part = part
	handle.step = step
	step(0)
	return handle
end

function SlashFx.play(origin, dir, c, follow, seed)
	local handle = SlashFx.new(origin, dir, c, follow, seed)
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if handle.step(dt) then
			conn:Disconnect()
		end
	end)
	return handle
end

return SlashFx
