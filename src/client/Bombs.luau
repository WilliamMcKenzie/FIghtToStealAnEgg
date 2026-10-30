-- Bosses' bombs (Server/BossAttacks' Lob; the Cactus Boss's first, QM Oct 27). Every
-- client draws each one from the BossBomb remote: the bomb flung in an arc from the boss,
-- and under where it'll land a red ring like the target ring (client/TargetRing) whose
-- middle fills out toward the ring as it comes down, so the ring is full the moment it
-- lands. Then it splashes. The server times the hit off the same start, so what you see is
-- when you're hit.
--
-- Drawn flat like the bombs in QM's Kingdom Crushers (QM Oct 30; its bombs.js and
-- particles.js): the bomb is a 2D square that always faces the camera (a BillboardGui),
-- spinning fastest and swelling to 2x at the top of its flight, dropping a fading square
-- behind it every TRAIL_EVERY seconds. Where it lands, rings of SPLASH_SPOKES little
-- squares radiate out to the blast's edge, each fading where it was put. Every square is a
-- pooled BillboardGui on one anchored part, so a volley costs no parts or models.
--
-- A Style is how a bomb looks (STYLES below): its fill and outline colours.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RING_COLOR = Color3.fromRGB(255, 50, 35) -- (TargetRing's)
local RING_TRANSPARENCY = 0.15
local RING_WIDTH = 0.07 -- of the radius
local FADE_BANDS = 6 -- inside the ring, faint red to clear going in (TargetRing's fade)
local FADE_EDGE = 0.6
local FADE_DEPTH = 0.6 -- of the radius
local FILL_TRANSPARENCY = 0.5 -- the fill growing out from the middle
local EDGE_TRANSPARENCY = 0.15 -- its leading edge
local EDGE_WIDTH = 0.05 -- of the radius
local LIFT = 0.15 -- studs above the ground
local SIZE = 2.2 -- the bomb's width (studs) as it leaves and lands
local SWELL = 1 -- how much bigger it is at the top of its flight (Kingdom's: 2x)
local SPIN = 900 -- degrees a second at the top of its flight (none at either end)
local OUTLINE = 0.16 -- the dark edge, of a square's width
local TRAIL_EVERY = 0.1 -- seconds between the squares dropped behind it
local TRAIL_SIZE = 0.9 -- studs
local SPLASH_SIZE = 1 -- studs
local SPLASH_SPOKES = 7 -- squares in each ring of the splash
local SPLASH_STEP = 1.6 -- studs further out each ring goes
local SPLASH_EVERY = 0.03 -- seconds between rings
local FADE = 0.5 -- seconds for a trail or splash square to fade out
local SHRINK = 1 -- seconds for one to shrink to nothing (it's gone once faded)

local STYLES = {
	Cactus = {
		Fill = Color3.fromRGB(255, 255, 255),
		Outline = Color3.fromRGB(52, 48, 56),
		Bit = Color3.fromRGB(255, 255, 255), -- trail and splash squares
		BitOutline = Color3.fromRGB(200, 196, 204),
	},
}

local folder = Instance.new("Folder")
folder.Name = "BombFx"
folder.Parent = workspace

local active = {} -- { { sprite, mark, fill, edge, inner, from, to, ground, start, airtime, radius, height, angle, dropped, style } }
local bits = {} -- { { sprite, born, size } }: trail and splash squares fading out

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

-- every square hangs off an Attachment on this one part (sat at the origin, so an
-- attachment's Position is where it is in the world)
local anchor = part({ Name = "BombSprites", Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new() })
anchor.Parent = folder

-- (the square sits in the middle of a bigger gui so it's not cut off turned on its corner)
local ROOM = 1.5

local free = {}

-- a camera-facing square: an outline frame with the fill inset inside it
local function sprite(fill, outline, size, angle)
	local s = table.remove(free)
	if not s then
		local att = Instance.new("Attachment")
		att.Name = "Square"
		local gui = Instance.new("BillboardGui")
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.ResetOnSpawn = false
		gui.Adornee = att
		local edge = Instance.new("Frame")
		edge.AnchorPoint = Vector2.new(0.5, 0.5)
		edge.Position = UDim2.fromScale(0.5, 0.5)
		edge.Size = UDim2.fromScale(1 / ROOM, 1 / ROOM)
		edge.BorderSizePixel = 0
		edge.Parent = gui
		local inner = Instance.new("Frame")
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Size = UDim2.fromScale(1 - OUTLINE * 2, 1 - OUTLINE * 2)
		inner.BorderSizePixel = 0
		inner.Parent = edge
		gui.Parent = att
		att.Parent = anchor
		s = { att = att, gui = gui, edge = edge, inner = inner }
	end
	s.edge.BackgroundColor3 = outline
	s.inner.BackgroundColor3 = fill
	s.edge.BackgroundTransparency, s.inner.BackgroundTransparency = 0, 0
	s.edge.Rotation = angle
	s.gui.Size = UDim2.fromScale(size * ROOM, size * ROOM)
	s.gui.Enabled = true
	return s
end

local function place(s, pos, size, angle)
	s.att.Position = pos
	s.gui.Size = UDim2.fromScale(size * ROOM, size * ROOM)
	s.edge.Rotation = angle
end

local function release(s)
	s.gui.Enabled = false
	table.insert(free, s)
end

-- a trail or splash square, left to fade and shrink where it's put
local function bit(style, pos, size, angle)
	local s = sprite(style.Bit, style.BitOutline, size, angle)
	s.att.Position = pos
	table.insert(bits, { sprite = s, born = os.clock(), size = size })
end

-- a flat ring round the y axis at `height` above the mark (a cylinder adornment runs
-- along its Z axis: turned to lie flat, like TargetRing's)
local function band(mark, color, transparency, radius, inner, height)
	local a = Instance.new("CylinderHandleAdornment")
	a.Color3 = color
	a.Transparency = transparency
	a.Height = 0.05
	a.Radius = math.max(radius, 0.01)
	a.InnerRadius = inner
	a.CFrame = CFrame.new(0, height, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	a.AlwaysOnTop = false
	a.Adornee = mark
	a.Parent = mark
	return a
end

-- the red landing ring (empty in the middle till the fill grows out)
local function warning(to, radius)
	local mark = part({ Name = "BombWarning", Size = Vector3.one * 0.2, Transparency = 1 })
	mark.CFrame = CFrame.new(to + Vector3.new(0, LIFT, 0))
	mark.Parent = folder
	local inner = radius * (1 - RING_WIDTH)
	band(mark, RING_COLOR, RING_TRANSPARENCY, radius, inner, 0.1)
	local step = inner * FADE_DEPTH / FADE_BANDS
	for k = 1, FADE_BANDS do
		local t = (k - 1) / FADE_BANDS
		band(mark, RING_COLOR, FADE_EDGE + (1 - FADE_EDGE) * t ^ 0.8, inner - (k - 1) * step, inner - k * step, 0.04)
	end
	local fill = band(mark, RING_COLOR, FILL_TRANSPARENCY, 0, 0, 0.06)
	local edge = band(mark, RING_COLOR, EDGE_TRANSPARENCY, 0, 0, 0.08)
	return mark, fill, edge, inner
end

-- Kingdom's radiate: a ring of SPLASH_SPOKES squares, then another a step further out,
-- out to the blast's edge (the last ring right on it)
local function splash(at, radius, style)
	local turn = math.random() * math.pi * 2
	local r = SPLASH_STEP
	while true do
		local ring = math.min(r, radius)
		for k = 1, SPLASH_SPOKES do
			local a = turn + k / SPLASH_SPOKES * math.pi * 2
			bit(style, at + Vector3.new(math.cos(a) * ring, 1, math.sin(a) * ring), SPLASH_SIZE, 45)
		end
		if r >= radius then
			break
		end
		r += SPLASH_STEP
		task.wait(SPLASH_EVERY)
	end
end

ReplicatedStorage:WaitForChild("BossBomb").OnClientEvent:Connect(function(info)
	local s = STYLES[info.style] or STYLES.Cactus
	if workspace:GetServerTimeNow() - info.start >= info.airtime then
		return -- (it's already landed)
	end
	local mark, fill, edge, inner = warning(info.to, info.radius)
	local bomb = sprite(s.Fill, s.Outline, SIZE, 0)
	bomb.att.Position = info.from
	table.insert(active, {
		sprite = bomb,
		mark = mark,
		fill = fill,
		edge = edge,
		inner = inner,
		from = info.from,
		to = info.to + Vector3.new(0, SIZE / 2, 0), -- (it lands sat on the ground)
		ground = info.to,
		start = info.start,
		airtime = info.airtime,
		radius = info.radius,
		height = info.height or 15,
		angle = math.random() * 90,
		dropped = os.clock(),
		style = s,
	})
end)

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for i = #active, 1, -1 do
		local b = active[i]
		local t = math.clamp((now - b.start) / b.airtime, 0, 1)
		local arc = math.sin(t * math.pi)
		if t >= 1 then
			table.remove(active, i)
			release(b.sprite)
			b.mark:Destroy()
			task.spawn(splash, b.ground, b.radius, b.style)
			continue
		end
		local pos = b.from:Lerp(b.to, t) + Vector3.new(0, b.height * 4 * t * (1 - t), 0)
		b.angle = (b.angle + SPIN * arc * dt) % 360
		place(b.sprite, pos, SIZE * (1 + SWELL * arc), b.angle)
		if clock - b.dropped >= TRAIL_EVERY then
			b.dropped = clock
			bit(b.style, pos, TRAIL_SIZE, 0)
		end
		-- the fill grows out from the middle, reaching the ring as it lands
		local r = b.inner * t
		b.fill.Radius = math.max(r, 0.01)
		b.edge.Radius = math.max(r, 0.01)
		b.edge.InnerRadius = math.max(r - b.radius * EDGE_WIDTH, 0)
	end
	for i = #bits, 1, -1 do
		local q = bits[i]
		local age = clock - q.born
		if age >= FADE then
			table.remove(bits, i)
			release(q.sprite)
			continue
		end
		local fade = age / FADE
		q.sprite.edge.BackgroundTransparency = fade
		q.sprite.inner.BackgroundTransparency = fade
		local size = q.size * (1 - age / SHRINK) * ROOM
		q.sprite.gui.Size = UDim2.fromScale(size, size)
	end
end)

return nil
