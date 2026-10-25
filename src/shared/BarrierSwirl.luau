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
--
--   local swirl = BarrierSwirl.new(wall, guiParent)   -- guiParent: where its SurfaceGuis live
--   swirl:draw(offset, style)                        -- offset: time drift (BarrierSwirl.step)
--   swirl:destroy()
--   BarrierSwirl.knob(style, name)

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

function BarrierSwirl.new(wall, guiParent)
	local self = setmetatable({ wall = wall, surfaces = {}, labels = {} }, BarrierSwirl)
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

function BarrierSwirl:destroy()
	for _, surface in self.surfaces do
		surface:Destroy()
	end
	if self.image then
		self.image:Destroy()
	end
	self.image = nil
end

function BarrierSwirl:build(perStud)
	perStud = math.clamp(math.floor(perStud + 0.5), 1, 6)
	local size = self.wall.Size
	if self.builtFor == perStud and self.builtSize == size and self.image then
		return true
	end
	self.builtFor, self.builtSize = perStud, size
	local W, H = math.max(1, math.floor(size.X * perStud)), math.max(1, math.floor(size.Y * perStud))
	local ok, made = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(W, H) })
	if not ok or not made then
		return false -- (no EditableImage here: no swirl)
	end
	if self.image then
		self.image:Destroy()
	end
	self.image, self.W, self.H = made, W, H
	self.pixels = buffer.create(W * H * 4)
	for i, label in self.labels do
		label.ImageContent = Content.fromObject(made)
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

function BarrierSwirl:draw(offset, style)
	if not self:build(knob(style, "PixelsPerStud")) then
		return
	end
	for _, surface in self.surfaces do
		surface.Brightness = knob(style, "Glow")
	end
	local dirs, angles = waves(style)
	local scale = knob(style, "Scale")
	local contrast = knob(style, "Contrast")
	local fill, back = knob(style, "FillColor"), knob(style, "BackColor")
	local fa, ba = math.clamp(knob(style, "FillAlpha"), 0, 1), math.clamp(knob(style, "BackAlpha"), 0, 1)
	local fr, fg, fb = fill.R, fill.G, fill.B
	local br, bg, bb = back.R, back.G, back.B
	local n = #dirs
	local W, H, pixels = self.W, self.H, self.pixels
	local f0 = knob(style, "FadeStart")
	if knob(style, "FadePulse") then
		local lo, hi = knob(style, "FadePulseMin"), knob(style, "FadePulseMax")
		f0 = lo + (hi - lo) * (0.5 + 0.5 * math.sin(os.clock() * knob(style, "FadePulseSpeed") * 2 * math.pi))
	end
	local f1 = math.max(knob(style, "FadeEnd"), f0 + 0.001)
	for py = 0, H - 1 do
		local y = (py - H / 2) * scale
		-- (the fade toward the top: smooth, from f0 of the way up to f1)
		local t = math.clamp(((1 - (py + 0.5) / H) - f0) / (f1 - f0), 0, 1)
		local keep = 1 - t * t * (3 - 2 * t)
		for px = 0, W - 1 do
			local x = (px - W / 2) * scale
			local sum = 0
			for k = 1, n do
				local d = dirs[k]
				sum += math.cos(d[1] * x + d[2] * y + offset + d[3])
			end
			local a = math.clamp(sum * contrast / angles, 0, 1) * fa
			local outA = a + ba * (1 - a)
			local r, g, b = 0, 0, 0
			if outA > 0 then
				r = (fr * a + br * ba * (1 - a)) / outA
				g = (fg * a + bg * ba * (1 - a)) / outA
				b = (fb * a + bb * ba * (1 - a)) / outA
			end
			local o = (py * W + px) * 4
			buffer.writeu8(pixels, o, math.floor(r * 255))
			buffer.writeu8(pixels, o + 1, math.floor(g * 255))
			buffer.writeu8(pixels, o + 2, math.floor(b * 255))
			buffer.writeu8(pixels, o + 3, math.floor(outA * keep * 255))
		end
	end
	self.image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
end

return BarrierSwirl
