-- The free gift's model (QM, Oct 31: his reference's FREE! present, in our own blocks): a red
-- studded present wrapped both ways in a yellow ribbon, a yellow bow on top (a knot, two
-- loops leaning out, two tails), "FREE!" floating over it, a glowing yellow ring on the
-- ground round it and sparkles drifting up. Built at the origin, its front facing -z;
-- Server/Map turns and moves it to Config.FreeGift's spot. Colours and sizes in Config.FreeGift.
--
--   GiftModel.build() -> Model "FreeGift" with:
--     Present   -- the box, ribbon and bow (client/FreeGift bobs it)
--     Ring      -- the glowing ring on the ground
--     Label     -- an invisible part holding the "FREE!" BillboardGui
--     Sparkles  -- an invisible part holding the sparkle ParticleEmitter and the glow

local Config = require(script.Parent.Config)
local Studs = require(script.Parent.Studs)

local GiftModel = {}

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
local BOX = Vector3.new(5, 4.4, 5) -- the present
local BAND = 1.1 -- the ribbon's width
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function block(parent, name, size, cframe, color, studded)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if studded and not Studs.apply(part, 0.5) then
		for _, face in Enum.NormalId:GetEnumItems() do
			local t = Instance.new("Texture")
			t.Texture = Studs.IMAGE
			t.StudsPerTileU, t.StudsPerTileV = 0.5, 0.5
			t.Face = face
			t.Parent = part
		end
	end
	part.Parent = parent
	return part
end

local function present(s)
	local model = Instance.new("Model")
	model.Name = "Present"
	local h = BOX.Y
	local box = block(model, "Box", BOX, CFrame.new(0, h / 2, 0), s.BoxColor, true)
	box.CanCollide = true -- (you bump into it, as into Carl's counter)
	model.PrimaryPart = box
	-- the ribbon, both ways round: each band a little proud of the box
	block(model, "RibbonX", Vector3.new(BOX.X + 0.12, h + 0.12, BAND), CFrame.new(0, h / 2, 0), s.RibbonColor, true)
	block(model, "RibbonZ", Vector3.new(BAND, h + 0.12, BOX.Z + 0.12), CFrame.new(0, h / 2, 0), s.RibbonColor, true)
	-- the bow: a knot, a loop leaning out each side (a hollow frame of four bars), two tails
	local top = h + 0.06
	block(model, "Knot", Vector3.new(1.3, 1, 1.3), CFrame.new(0, top + 0.45, 0), s.RibbonColor, true)
	local L, H, T, D = 2.5, 1.7, 0.45, 0.8 -- a loop's length, height, bar thickness, depth
	for _, side in { -1, 1 } do
		local at = CFrame.new(side * 1.7, top + 1.15, 0) * CFrame.Angles(0, 0, side * math.rad(28))
		for _, bar in {
			{ Vector3.new(L, T, D), Vector3.new(0, H / 2 - T / 2, 0) },
			{ Vector3.new(L, T, D), Vector3.new(0, -(H / 2 - T / 2), 0) },
			{ Vector3.new(T, H, D), Vector3.new(L / 2 - T / 2, 0, 0) },
			{ Vector3.new(T, H, D), Vector3.new(-(L / 2 - T / 2), 0, 0) },
		} do
			block(model, "Loop", bar[1], at * CFrame.new(bar[2]), s.RibbonColor, true)
		end
		-- (a tail down over the front, splaying out)
		block(
			model,
			"Tail",
			Vector3.new(0.9, 0.3, 2.4),
			CFrame.new(side * 0.7, top + 0.1, -1.3) * CFrame.Angles(0, side * math.rad(-22), 0) * CFrame.Angles(math.rad(-8), 0, 0),
			s.RibbonColor,
			true
		)
	end
	return model
end

-- the ring: a see-through disc with a glowing rim of short neon blocks round it (as Carl's)
local function ring(s)
	local model = Instance.new("Model")
	model.Name = "Ring"
	local r = s.RingRadius
	local disc = block(model, "Disc", Vector3.new(0.12, r * 2, r * 2), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2), s.RingColor)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.12, r * 2, r * 2) -- (again: a new Shape can square it off)
	disc.Transparency = 0.65
	disc.CastShadow = false
	local n = 40
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local rim = block(
			model,
			"Rim",
			Vector3.new(0.6, 0.3, 2 * math.pi * r / n + 0.12),
			CFrame.Angles(0, a, 0) * CFrame.new(r - 0.3, 0.15, 0),
			s.RingColor
		)
		rim.Material = Enum.Material.Neon
		rim.Transparency = 0.1
		rim.CastShadow = false
	end
	return model
end

local function label(s)
	local anchor = block(nil, "Label", Vector3.new(1, 1, 1), CFrame.new(0, BOX.Y + 5, 0), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "Free"
	gui.Size = UDim2.fromScale(s.LabelHeight * 2.6, s.LabelHeight)
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.FontFace = FONT
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = "FREE!"
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(s.LabelTop, s.LabelBottom)
	gradient.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3.5
	stroke.Color = Color3.fromRGB(14, 40, 8)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = text
	text.Parent = gui
	return anchor
end

local function sparkles(s)
	local box = block(nil, "Sparkles", Vector3.new(s.RingRadius * 1.6, BOX.Y + 2, s.RingRadius * 1.6), CFrame.new(0, BOX.Y / 2 + 1, 0), Color3.new(1, 1, 1))
	box.Transparency = 1
	local fx = Instance.new("ParticleEmitter")
	fx.Name = "Sparkle"
	fx.Texture = SPARKLE
	fx.Shape = Enum.ParticleEmitterShape.Box
	fx.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fx.Rate = 7
	fx.Lifetime = NumberRange.new(0.7, 1.4)
	fx.Speed = NumberRange.new(0.4, 1)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Acceleration = Vector3.new(0, 0.8, 0)
	fx.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 0),
	})
	fx.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 240, 150))
	fx.LightEmission = 1
	fx.Rotation = NumberRange.new(0, 360)
	fx.Parent = box
	local light = Instance.new("PointLight")
	light.Name = "Glow"
	light.Color = s.RingColor
	light.Range = s.RingRadius * 2
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = box
	return box
end

function GiftModel.build()
	local s = Config.FreeGift
	local model = Instance.new("Model")
	model.Name = "FreeGift"
	present(s).Parent = model
	ring(s).Parent = model
	label(s).Parent = model
	sparkles(s).Parent = model
	model.WorldPivot = CFrame.identity
	return model
end

return GiftModel
