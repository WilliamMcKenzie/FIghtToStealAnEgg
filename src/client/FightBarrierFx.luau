-- The red fight barriers' look (QM, Oct 25): his quasicrystal from LassoAPet's portal
-- (client/PortalFx there, ported from his JS). Each barrier you're locked in by gets a
-- low-res EditableImage on both faces; each pixel sums cos waves over Angles directions,
-- drifting with time, which sets how much of the fill colour shows over the backdrop.
-- (client/Barriers makes the same barriers solid for you; this only draws them.)
--
-- Tuning, live: every knob is an attribute on ReplicatedStorage.FightBarrierStyle (DEFAULTS
-- below; a missing one takes its default). Change them in Studio's Properties, in Edit
-- (saved with the place) or while playing, and the barriers follow at once.
--   Angles      how many wave directions (2 to 12 or so; fractions twist it)
--   Speed       how fast it drifts
--   Scale       how big the pattern is: wave cycles per pixel (smaller: bigger blobs)
--   Modifier    twists each direction by 2 x modifier x (pi / angles x i)
--   Seed        shifts each wave's phase at random (0: none)
--   Contrast    how hard edged each wave is
--   FillColor / FillAlpha   the pattern's colour and how opaque it is (0..1)
--   BackColor / BackAlpha   the backdrop behind it (0: see-through)
--   PixelsPerStud           the pixel size (1: stud pixels; more costs more)
--   Glow        how bright it is (above 1 it glows)
--   FPS         redraws a second
--   FadeStart / FadeEnd     it fades out toward the top: from FadeStart of the way up (0
--               bottom, 1 top) to gone at FadeEnd
--   PreviewAll  tick it to see every barrier drawn (not solid), fight or not

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFAULTS = {
	Angles = 7,
	Speed = 1,
	Scale = 0.35,
	Modifier = 0,
	Seed = 0,
	Contrast = 10,
	FillColor = Color3.fromRGB(255, 70, 60),
	FillAlpha = 0.65,
	BackColor = Color3.fromRGB(190, 20, 40),
	BackAlpha = 0.3,
	PixelsPerStud = 2,
	Glow = 2,
	FPS = 30,
	FadeStart = 0.45, -- how far up (0 bottom, 1 top) it starts fading out
	FadeEnd = 1, -- and where it's gone
	PreviewAll = false,
}
local NEAR = 400 -- studs: no drawing further off

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local style = ReplicatedStorage:WaitForChild("FightBarrierStyle", 10)

local function knob(name)
	local v = style and style:GetAttribute(name)
	return if typeof(v) == typeof(DEFAULTS[name]) then v else DEFAULTS[name]
end

local swirls = {} -- [wall] = { surfaces, labels, image, pixels, W, H, builtFor }

local function shownFor(wall)
	local biome = player:GetAttribute("LockedIn")
	return knob("PreviewAll") or (biome ~= nil and (wall:GetAttribute("South") == biome or wall:GetAttribute("North") == biome))
end

local function makeSwirl(wall)
	local s = { surfaces = {}, labels = {} }
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = "FightSwirl"
		surface.Adornee = wall
		surface.Face = face
		surface.CanvasSize = Vector2.new(wall.Size.X * 8, wall.Size.Y * 8)
		surface.LightInfluence = 0
		surface.Parent = wall
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.Parent = surface
		table.insert(s.surfaces, surface)
		table.insert(s.labels, label)
	end
	swirls[wall] = s
	return s
end

local function dropSwirl(wall)
	local s = swirls[wall]
	swirls[wall] = nil
	if not s then
		return
	end
	for _, surface in s.surfaces do
		surface:Destroy()
	end
	if s.image then
		s.image:Destroy()
	end
end

local function build(s, wall, perStud)
	perStud = math.clamp(math.floor(perStud + 0.5), 1, 6)
	if s.builtFor == perStud and s.image then
		return true
	end
	s.builtFor = perStud
	local W, H = math.max(1, math.floor(wall.Size.X * perStud)), math.max(1, math.floor(wall.Size.Y * perStud))
	local ok, made = pcall(AssetService.CreateEditableImage, AssetService, { Size = Vector2.new(W, H) })
	if not ok or not made then
		return false -- (no EditableImage here: no swirl)
	end
	if s.image then
		s.image:Destroy()
	end
	s.image, s.W, s.H = made, W, H
	s.pixels = buffer.create(W * H * 4)
	for _, label in s.labels do
		label.ImageContent = Content.fromObject(made)
	end
	return true
end

-- his waves for the knobs now: { cos, sin, phase } a direction
local function waves()
	local angles = math.max(knob("Angles"), 1)
	local mod = knob("Modifier")
	local seed = knob("Seed")
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

local function draw(s, offset)
	local dirs, angles = waves()
	local scale = knob("Scale")
	local contrast = knob("Contrast")
	local fill, back = knob("FillColor"), knob("BackColor")
	local fa, ba = math.clamp(knob("FillAlpha"), 0, 1), math.clamp(knob("BackAlpha"), 0, 1)
	local fr, fg, fb = fill.R, fill.G, fill.B
	local br, bg, bb = back.R, back.G, back.B
	local n = #dirs
	local W, H, pixels = s.W, s.H, s.pixels
	local f0, f1 = knob("FadeStart"), math.max(knob("FadeEnd"), knob("FadeStart") + 0.001)
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
			local shownA = outA * keep
			if outA > 0 then
				r = (fr * a + br * ba * (1 - a)) / outA
				g = (fg * a + bg * ba * (1 - a)) / outA
				b = (fb * a + bb * ba * (1 - a)) / outA
			end
			local o = (py * W + px) * 4
			buffer.writeu8(pixels, o, math.floor(r * 255))
			buffer.writeu8(pixels, o + 1, math.floor(g * 255))
			buffer.writeu8(pixels, o + 2, math.floor(b * 255))
			buffer.writeu8(pixels, o + 3, math.floor(shownA * 255))
		end
	end
	s.image:WritePixelsBuffer(Vector2.zero, Vector2.new(W, H), pixels)
end

local offset = 0
local last = 0
local camera = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
	offset += knob("Speed") / 16 * dt * 60
	local markers = map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	local walls = if markers then markers:GetChildren() else {}
	-- which get drawn: yours (or all, previewing)
	for _, wall in walls do
		local want = shownFor(wall)
		if want and not swirls[wall] then
			makeSwirl(wall)
		elseif not want and swirls[wall] then
			dropSwirl(wall)
		end
	end
	local now = os.clock()
	if now - last < 1 / math.max(knob("FPS"), 1) then
		return
	end
	last = now
	for wall, s in swirls do
		if not wall.Parent then
			dropSwirl(wall)
			continue
		end
		if (camera.CFrame.Position - wall.Position).Magnitude > NEAR then
			continue
		end
		local _, onScreen = camera:WorldToViewportPoint(wall.Position)
		if not onScreen or not build(s, wall, knob("PixelsPerStud")) then
			continue
		end
		for _, surface in s.surfaces do
			surface.Brightness = knob("Glow")
		end
		draw(s, offset)
	end
end)

return nil
