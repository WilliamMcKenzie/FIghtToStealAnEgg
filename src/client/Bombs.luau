-- Bosses' bombs (Server/BossAttacks' Lob; the Cactus Boss's first, QM Oct 27). Every
-- client draws each one from the BossBomb remote: the bomb flung in an arc from the boss,
-- spinning and swelling at the top of its flight like the bombs in QM's Kingdom game, and
-- under where it'll land a red ring like the target ring (client/TargetRing) whose middle
-- fills out toward the ring as it comes down, so the ring is full the moment it lands.
-- Then it bursts. The server times the hit off the same start, so what you see is when
-- you're hit.
--
-- A Style is how a bomb looks (STYLES below); the Cactus Boss's is a green ball of
-- spines with a pink flower on top, trailing green.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
local SWELL = 0.4 -- how much bigger a bomb is at the top of its flight
local SPIN = 9 -- radians a second at the top of its flight (3 at either end)

local STYLES = {
	Cactus = {
		Body = Color3.fromRGB(92, 168, 70), -- (Config's CactusGreen)
		Dark = Color3.fromRGB(62, 124, 50),
		Spine = Color3.fromRGB(242, 232, 184),
		Flower = Color3.fromRGB(255, 120, 170), -- (CactusFlower)
		FlowerMiddle = Color3.fromRGB(255, 220, 90),
		Trail = Color3.fromRGB(120, 220, 90),
		Burst = Color3.fromRGB(140, 235, 100),
		Size = 3, -- the ball's width, studs
	},
}

local folder = Instance.new("Folder")
folder.Name = "BombFx"
folder.Parent = workspace

local active = {} -- { { model, carrier, mark, fill, edge, inner, from, to, ground, start, airtime, radius, height, axis, spin, style } }

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

-- the bomb itself, round its core (a Model so it can swell with ScaleTo)
local function build(s)
	local model = Instance.new("Model")
	model.Name = "Bomb"
	local r = s.Size / 2
	local core = part({ Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.one * s.Size, Color = s.Body })
	core.Parent = model
	model.PrimaryPart = core
	-- (a darker band round its middle, so the spin reads)
	local band = part({
		Name = "Band",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(s.Size * 0.3, s.Size * 1.02, s.Size * 1.02),
		Color = s.Dark,
	})
	band.Parent = model
	-- spines all over it (a Fibonacci sphere)
	local n = 16
	for k = 0, n - 1 do
		local y = 1 - (k + 0.5) / n * 2
		local ring = math.sqrt(1 - y * y)
		local a = k * math.pi * (3 - math.sqrt(5))
		local out = Vector3.new(math.cos(a) * ring, y, math.sin(a) * ring)
		if out.Y > 0.85 then
			continue -- (the flower's there)
		end
		local spine = part({ Name = "Spine", Size = Vector3.new(0.18, 0.18, 0.9), Color = s.Spine })
		spine.CFrame = CFrame.lookAt(out * (r + 0.2), out * (r + 1))
		spine.Parent = model
	end
	local flower = part({
		Name = "Flower",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s.Size * 0.38,
		Color = s.Flower,
		CFrame = CFrame.new(0, r * 0.95, 0),
	})
	flower.Parent = model
	local middle = part({
		Name = "FlowerMiddle",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s.Size * 0.16,
		Color = s.FlowerMiddle,
		Material = Enum.Material.Neon,
		CFrame = CFrame.new(0, r * 0.95 + s.Size * 0.15, 0),
	})
	middle.Parent = model
	return model
end

-- what trails it: an unturning carrier with a ribbon and a few sparks, so the bomb's spin
-- doesn't twist the trail
local function carrier(s)
	local c = part({ Name = "BombTrail", Size = Vector3.one * 0.2, Transparency = 1 })
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Position, bottom.Position = Vector3.new(0, s.Size * 0.35, 0), Vector3.new(0, -s.Size * 0.35, 0)
	top.Parent, bottom.Parent = c, c
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(s.Trail)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Lifetime = 0.3
	trail.FaceCamera = true
	trail.LightEmission = 0.5
	trail.Parent = c
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(s.Trail)
	sparks.LightEmission = 0.6
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new(0.2)
	sparks.Lifetime = NumberRange.new(0.3, 0.5)
	sparks.Rate = 30
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = c
	return c
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

local function burst(at, radius, s)
	-- a green flash swelling to the blast's size
	local flash = part({
		Name = "BombBurst",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * s.Size,
		Color = s.Burst,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CFrame = CFrame.new(at + Vector3.new(0, 1, 0)),
	})
	flash.Parent = folder
	TweenService
		:Create(
			flash,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(radius * 1.6, radius * 0.9, radius * 1.6), Transparency = 1 }
		)
		:Play()
	-- a flat shockwave out to its edge
	local wave = part({
		Name = "BombWave",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius, radius),
		Color = s.Burst,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CFrame = CFrame.new(at + Vector3.new(0, LIFT + 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	wave.Parent = folder
	TweenService
		:Create(
			wave,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.2, radius * 2.2, radius * 2.2), Transparency = 1 }
		)
		:Play()
	-- bits flung out to the blast's edge (like Kingdom's radiating particles)
	local spray = part({ Name = "BombSpray", Size = Vector3.one * 0.2, Transparency = 1 })
	spray.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
	spray.Parent = folder
	local bits = Instance.new("ParticleEmitter")
	bits.Color = ColorSequence.new(s.Burst, s.Body)
	bits.LightEmission = 0.4
	bits.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	bits.Lifetime = NumberRange.new(0.35, 0.5)
	bits.Speed = NumberRange.new(radius * 2, radius * 3)
	bits.Drag = 5
	bits.SpreadAngle = Vector2.new(180, 180)
	bits.Acceleration = Vector3.new(0, -30, 0)
	bits.Rate = 0
	bits.Parent = spray
	bits:Emit(28)
	for _, p in { flash, wave, spray } do
		task.delay(0.8, p.Destroy, p)
	end
end

ReplicatedStorage:WaitForChild("BossBomb").OnClientEvent:Connect(function(info)
	local s = STYLES[info.style] or STYLES.Cactus
	if workspace:GetServerTimeNow() - info.start >= info.airtime then
		return -- (it's already landed)
	end
	local model = build(s)
	model.Parent = folder
	local trail = carrier(s)
	trail.CFrame = CFrame.new(info.from)
	trail.Parent = folder
	local mark, fill, edge, inner = warning(info.to, info.radius)
	local axis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	table.insert(active, {
		model = model,
		carrier = trail,
		mark = mark,
		fill = fill,
		edge = edge,
		inner = inner,
		from = info.from,
		to = info.to + Vector3.new(0, s.Size / 2, 0), -- (it lands sat on the ground)
		ground = info.to,
		start = info.start,
		airtime = info.airtime,
		radius = info.radius,
		height = info.height or 15,
		axis = if axis.Magnitude > 0.01 then axis.Unit else Vector3.yAxis,
		spin = CFrame.new(),
		style = s,
	})
end)

RunService.RenderStepped:Connect(function(dt)
	local now = workspace:GetServerTimeNow()
	for i = #active, 1, -1 do
		local b = active[i]
		local t = math.clamp((now - b.start) / b.airtime, 0, 1)
		local arc = math.sin(t * math.pi)
		if t >= 1 then
			table.remove(active, i)
			b.model:Destroy()
			b.mark:Destroy()
			b.carrier.ParticleEmitter.Enabled = false
			task.delay(0.4, b.carrier.Destroy, b.carrier)
			burst(b.ground, b.radius, b.style)
			continue
		end
		local pos = b.from:Lerp(b.to, t) + Vector3.new(0, b.height * 4 * t * (1 - t), 0)
		b.spin = CFrame.fromAxisAngle(b.axis, (3 + (SPIN - 3) * arc) * dt) * b.spin
		b.model:ScaleTo(1 + SWELL * arc)
		b.model:PivotTo(CFrame.new(pos) * b.spin)
		b.carrier.CFrame = CFrame.new(pos)
		-- the fill grows out from the middle, reaching the ring as it lands
		local r = b.inner * t
		b.fill.Radius = math.max(r, 0.01)
		b.edge.Radius = math.max(r, 0.01)
		b.edge.InnerRadius = math.max(r - b.radius * EDGE_WIDTH, 0)
	end
end)

return nil
