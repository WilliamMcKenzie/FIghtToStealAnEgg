-- The red fight barriers' quasicrystal (QM, Oct 25): his swirl from LassoAPet's portal
-- (client/PortalFx there, ported from his JS), shared so the game (client/FightBarrierFx)
-- and the Map Baker plugin (in Studio's Edit mode, without pressing Play) draw the same.
-- A low-res EditableImage on both faces of a barrier; each pixel sums cos waves over
-- Angles directions, drifting with time, which sets how much of the fill colour shows over
-- the backdrop, fading out toward the top.
--
-- Its knobs are attributes on workspace.FightBarrierStyle (DEFAULTS; a missing one
-- takes its default):
--   Angles      how many wave directions (2 to 12 or so; fractions twist it)
--   Speed       how fast it drifts
--   Scale       how big the pattern is: wave cycles per pixel (smaller: bigger blobs)
--   Modifier    twists each direction by 2 x modifier x (pi / angles x i)
--   Seed        shifts each wave's phase at random (0: none)
--   Contrast    how hard edged each wave is
--   FillColor / FillAlpha   the pattern's colour and how opaque it is (0..1)
--   BackColor / BackAlpha   the backdrop behind it (0: see-through)
--   FadeStart / FadeEnd     it fades out toward the top: from FadeStart of the way up (0
--               bottom, 1 top) to gone at FadeEnd
--   FadePulse   tick it to make the fade's start breathe instead (a sine wave between
--               FadePulseMin and FadePulseMax, FadePulseSpeed times a second)
--   PixelsPerStud           the pixel size (1: stud pixels; more costs more)
--   Glow        how bright it is (above 1 it glows)
--   FPS         redraws a second
--   PreviewAll  (in game) tick it to see every barrier drawn, fight or not
--   ShadowColor / ShadowAlpha / ShadowLength   its red shadow on the floor either side:
--               colour, opacity at the barrier, and how far it spreads
--
--   local swirl = BarrierSwirl.new(wall, guiParent)   -- guiParent: where its SurfaceGuis live
--   swirl:draw(offset, style)                        -- offset: time drift (BarrierSwirl.step)
--   swirl:show(on)                                   -- hide it without throwing it away
--   swirl:destroy()
--   BarrierSwirl.knob(style, name)
--
-- Kept cheap (QM, Oct 25: the barriers lagged hard when they came up):
-- - every wave drifts by the same offset, so the sum of cos waves at a pixel is
--   A cos(offset) - B sin(offset), with A and B worked out once per pixel (again only when
--   Angles, Scale, Modifier, Seed or the size change): two multiplies a pixel a frame
--   instead of Angles cosines
-- - the colour for each pattern strength is a 256-step lookup, made when the colour knobs
--   change, so a pixel is one packed write
-- - barriers the same size show the same picture, so they share one EditableImage drawn
--   once a frame however many there are
-- - the floor shadows are only touched when they or their knobs change

local AssetService = game:GetService("AssetService")

local BarrierSwirl = {}
BarrierSwirl.__index = BarrierSwirl

BarrierSwirl.DEFAULTS = { -- (QM's picks, Oct 25)
	Angles = 5,
	Speed = 1,
	Scale = 0.25,
	Modifier = 0,
	Seed = 0,
	Contrast = 10,
	FillColor = Color3.fromRGB(255, 13, 0),
	FillAlpha = 0.1,
	BackColor = Color3.fromRGB(255, 70, 60),
	BackAlpha = 0.4,
	FadeStart = 0.6,
	FadeEnd = 1,
	FadePulse = true,
	FadePulseMin = 0.45,
	FadePulseMax = 0.7,
	FadePulseSpeed = 0.25,
	PixelsPerStud = 2,
	Glow = 3,
	FPS = 30,
	PreviewAll = false,
	ShadowColor = Color3.fromRGB(255, 40, 30),
	ShadowAlpha = 0.4, -- (how opaque the floor shadow is at the barrier)
	ShadowLength = 20, -- (studs it spreads before it's gone)
}
local DEFAULTS = BarrierSwirl.DEFAULTS

function BarrierSwirl.knob(style, name)
	local v = style and style:GetAttribute(name)
	return if typeof(v) == typeof(DEFAULTS[name]) then v else DEFAULTS[name]
end
local knob = BarrierSwirl.knob

-- how far the pattern drifts in dt seconds
function BarrierSwirl.step(style, dt)
	return knob(style, "Speed") / 16 * dt * 60
end

-- one shared picture per pixel size: [W .. "x" .. H] = canvas
local canvases = {}

local function canvasFor(W, H)
	local key = W .. "x" .. H
	local canvas = canvases[key]
	if canvas then
		canvas.users += 1
		return canvas
	end
	local ok, made = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(W, H) })
	if not ok or not made then
		return nil -- (no EditableImage here: no swirl)
	end
	canvas = {
		key = key,
		image = made,
		content = Content.fromObject(made),
		W = W,
		H = H,
		pixels = buffer.create(W * H * 4),
		users = 1,
	}
	canvases[key] = canvas
	return canvas
end

local function release(canvas)
	canvas.users -= 1
	if canvas.users <= 0 then
		canvases[canvas.key] = nil
		canvas.image:Destroy()
	end
end

function BarrierSwirl.new(wall, guiParent)
	local self = setmetatable({ wall = wall, surfaces = {}, labels = {}, shown = true }, BarrierSwirl)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "BarrierSwirl"
		surface.Adornee = wall
		surface.Face = face
		surface.CanvasSize = Vector2.new(wall.Size.X * 8, wall.Size.Y * 8)
		surface.LightInfluence = 0
		surface.Parent = guiParent or wall
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.Parent = surface
		table.insert(self.surfaces, surface)
		table.insert(self.labels, label)
	end
	return self
end

function BarrierSwirl:show(on)
	if self.shown ~= on then
		self.shown = on
		for _, surface in self.surfaces do
			surface.Enabled = on
		end
	end
end

function BarrierSwirl:destroy()
	for _, surface in self.surfaces do
		surface:Destroy()
	end
	if self.canvas then
		release(self.canvas)
	end
	self.canvas = nil
end

function BarrierSwirl:build(perStud)
	perStud = math.clamp(math.floor(perStud + 0.5), 1, 6)
	local size = self.wall.Size
	if self.builtFor == perStud and self.builtSize == size and self.canvas then
		return true
	end
	local W, H = math.max(1, math.floor(size.X * perStud)), math.max(1, math.floor(size.Y * perStud))
	local made = canvasFor(W, H)
	if not made then
		return false
	end
	if self.canvas then
		release(self.canvas)
	end
	self.builtFor, self.builtSize, self.canvas = perStud, size, made
	for i, label in self.labels do
		label.ImageContent = made.content
		self.surfaces[i].CanvasSize = Vector2.new(size.X * 8, size.Y * 8)
	end
	return true
end

-- his waves for the knobs now: { cos, sin, phase } a direction
local function waves(style)
	local angles = math.max(knob(style, "Angles"), 1)
	local mod = knob(style, "Modifier")
	local seed = knob(style, "Seed")
	local rng = Random.new(math.floor(seed))
	local list = {}
	local angle = 2 * math.pi
	local i = 0
	while i < angles do
		local bonus = math.pi / angles * i
		local phase = if seed ~= 0 then rng:NextNumber() * 2 * math.pi else 0
		table.insert(list, { math.cos(angle - 2 * (mod * bonus)), math.sin(angle + 2 * (mod * bonus)), phase })
		angle -= 2 * math.pi / angles
		i += 1
	end
	return list, angles
end

-- A and B a pixel: the waves' sum at drift 0 and a quarter turn on (see the top)
local function shape(canvas, style)
	local sig = table.concat({
		knob(style, "Angles"),
		knob(style, "Modifier"),
		knob(style, "Seed"),
		knob(style, "Scale"),
	}, ",")
	if canvas.shapeSig == sig then
		return
	end
	canvas.shapeSig = sig
	local dirs = waves(style)
	local scale = knob(style, "Scale")
	local W, H = canvas.W, canvas.H
	local A, B = table.create(W * H, 0), table.create(W * H, 0)
	local i = 1
	for py = 0, H - 1 do
		local y = (py - H / 2) * scale
		for px = 0, W - 1 do
			local x = (px - W / 2) * scale
			local a, b = 0, 0
			for _, d in dirs do
				local u = d[1] * x + d[2] * y + d[3]
				a += math.cos(u)
				b += math.sin(u)
			end
			A[i], B[i] = a, b
			i += 1
		end
	end
	canvas.A, canvas.B = A, B
end

-- the colour for each of 256 pattern strengths: rgb packed, alpha (0..255) apart
local LEVELS = 255
local function palette(canvas, style)
	local fill, back = knob(style, "FillColor"), knob(style, "BackColor")
	local fa, ba = math.clamp(knob(style, "FillAlpha"), 0, 1), math.clamp(knob(style, "BackAlpha"), 0, 1)
	local sig = table.concat({ tostring(fill), tostring(back), fa, ba }, ",")
	if canvas.paletteSig == sig then
		return
	end
	canvas.paletteSig = sig
	local rgb, alpha, full = {}, {}, {}
	for idx = 0, LEVELS do
		local a = idx / LEVELS * fa
		local outA = a + ba * (1 - a)
		local r, g, b = 0, 0, 0
		if outA > 0 then
			r = (fill.R * a + back.R * ba * (1 - a)) / outA
			g = (fill.G * a + back.G * ba * (1 - a)) / outA
			b = (fill.B * a + back.B * ba * (1 - a)) / outA
		end
		rgb[idx] = math.floor(r * 255) + math.floor(g * 255) * 256 + math.floor(b * 255) * 65536
		alpha[idx] = outA * 255
		full[idx] = rgb[idx] + math.floor(outA * 255) * 16777216
	end
	canvas.rgb, canvas.alpha, canvas.full = rgb, alpha, full
end

local function paint(canvas, offset, style)
	local f0 = knob(style, "FadeStart")
	if knob(style, "FadePulse") then
		local lo, hi = knob(style, "FadePulseMin"), knob(style, "FadePulseMax")
		f0 = lo + (hi - lo) * (0.5 + 0.5 * math.sin(os.clock() * knob(style, "FadePulseSpeed") * 2 * math.pi))
	end
	local f1 = math.max(knob(style, "FadeEnd"), f0 + 0.001)
	shape(canvas, style)
	palette(canvas, style)
	local k = knob(style, "Contrast") / math.max(knob(style, "Angles"), 1) * LEVELS
	local sig = table.concat({ offset, f0, f1, k, canvas.shapeSig, canvas.paletteSig }, ",")
	if canvas.paintSig == sig then
		return -- (drawn already this frame, for another barrier this size)
	end
	canvas.paintSig = sig
	local W, H, pixels = canvas.W, canvas.H, canvas.pixels
	local A, B = canvas.A, canvas.B
	local rgb, alpha, full = canvas.rgb, canvas.alpha, canvas.full
	local c, s = math.cos(offset) * k, math.sin(offset) * k
	local floor = math.floor
	local writeu32 = buffer.writeu32
	local i = 1
	for py = 0, H - 1 do
		-- (the fade toward the top: smooth, from f0 of the way up to f1)
		local t = math.clamp(((1 - (py + 0.5) / H) - f0) / (f1 - f0), 0, 1)
		local keep = 1 - t * t * (3 - 2 * t)
		local o = py * W * 4
		if keep <= 0 then
			buffer.fill(pixels, o, 0, W * 4)
			i += W
		elseif keep >= 1 then
			for _ = 1, W do
				local idx = floor(A[i] * c - B[i] * s)
				idx = if idx < 0 then 0 elseif idx > LEVELS then LEVELS else idx
				writeu32(pixels, o, full[idx])
				o += 4
				i += 1
			end
		else
			for _ = 1, W do
				local idx = floor(A[i] * c - B[i] * s)
				idx = if idx < 0 then 0 elseif idx > LEVELS then LEVELS else idx
				writeu32(pixels, o, rgb[idx] + floor(alpha[idx] * keep) * 16777216)
				o += 4
				i += 1
			end
		end
	end
	canvas.image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
end

function BarrierSwirl:draw(offset, style)
	if not self:build(knob(style, "PixelsPerStud")) then
		return
	end
	local glow = knob(style, "Glow")
	if self.glow ~= glow then
		self.glow = glow
		for _, surface in self.surfaces do
			surface.Brightness = glow
		end
	end
	paint(self.canvas, offset, style)
end

-- a barrier's floor shadows (beams Server/Map put on it) tuned from the style, shown or not;
-- only touched when that changes
local shadowState = setmetatable({}, { __mode = "k" }) -- [wall] = { sig, beams }
function BarrierSwirl.shadows(wall, style, shown)
	local colour = knob(style, "ShadowColor")
	local alpha = math.clamp(knob(style, "ShadowAlpha"), 0, 1)
	local length = math.max(knob(style, "ShadowLength"), 0.1)
	local state = shadowState[wall]
	local sig = if shown then table.concat({ tostring(colour), alpha, length }, ",") else "off"
	if state and state.sig == sig then
		return
	end
	if not state then
		state = { beams = {} }
		for _, beam in wall:GetDescendants() do
			if beam:IsA("Beam") and beam.Name == "Shadow" then
				table.insert(state.beams, beam)
			end
		end
		shadowState[wall] = state
	end
	state.sig = sig
	for _, beam in state.beams do
		beam.Enabled = shown
		if shown then
			beam.Color = ColorSequence.new(colour)
			beam.Transparency = NumberSequence.new(1 - alpha, 1)
			local a0, a1 = beam.Attachment0, beam.Attachment1
			if a0 and a1 then
				local dir = (a1.Position - a0.Position)
				if dir.Magnitude > 1e-3 then
					a1.Position = a0.Position + dir.Unit * length
				end
			end
		end
	end
end

return BarrierSwirl
