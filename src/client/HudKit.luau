-- The pieces QM's NewUI is made of (Oct 27), shared by client/Hud and client/WeaponShop.
-- Everything is laid out in design px (1080 tall: the Hud's Root scales it to the screen);
-- QM's Figma frame is 2190 tall, so its numbers go through HudKit.fig. Each piece is made
-- with Ui.make, so a copy QM edited in StarterGui is kept as it is (client/Ui).
--
--   HudKit.fig(n) -> design px           -- Figma px to design px
--   HudKit.art(parent, name, props)      -- a Figma layer exported as it is (HudImages[name])
--   HudKit.label(parent, name, props)    -- white Montserrat ExtraBold, black outline
--   HudKit.back(parent, look, props)     -- a Figma rectangle built natively (QM, Oct 27: no
--     images for flat pieces): its fill or gradient, the stud texture over it, the bevel, its
--     inside border and the black outline round it. `look` is one of HudKit.LOOKS.
--   HudKit.outlineArt(icon, px)          -- outlines an icon black (copies of it under it)
--   HudKit.button(parent, name, w, h, props, look) -- a w x h (Figma px) button on a Back of
--     that look. Under the mouse it grows from its centre and its back darkens (QM, Oct 27),
--     its icon and text not.
--   HudKit.popup(root, name, title, headerLook) -> gui, close -- the shop popup (QM's Figma,
--     Oct 27; 2268 x 1370 Figma px, centred): the dark studded panel, the header with its
--     two shine stripes, the title over its drop shadow and the red X. The Weapon Shop's
--     (orange Header) and the Shop's (LimeHeader) are this one. Hidden in Play till opened
--     (client/UiFx.popIn).

local TweenService = game:GetService("TweenService")

local HudImages = require(script.Parent.HudImages)
local Ui = require(script.Parent.Ui)

local HudKit = {}

local DESIGN_HEIGHT = 1080
local FIGMA_HEIGHT = 2190 -- (QM's NewUI frame)
local HOVER_GROW = 1.08 -- a button grows this much under the mouse (QM: snappy)
local HOVER_DARK = Color3.fromRGB(205, 205, 205) -- its back's tint then
local HOVER_TIME = 0.08
local SHINE = { { at = 0.62, width = 0.07 }, { at = 0.72, width = 0.025 } } -- across the header, of its width
local SHINE_SLANT = 22 -- degrees the stripes lean
local SHINE_ALPHA = 0.7 -- their transparency

HudKit.FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
HudKit.ITALIC = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
HudKit.BLACK = Color3.new(0, 0, 0)
HudKit.TEXT_OUTLINE = 4 -- a label's black outline, in design px (QM, Oct 30: "make these outlines 4px")

-- the Figma rectangles' looks. top/bottom: a top-to-bottom gradient (Figma: from at 15.9%,
--   or `from`);
-- across: a left-to-right one; tile: the texture's tile size in Figma (px), its
--   transparency (1 - its Figma opacity), and which of QM's Figma textures: studs
--   (assets/ui/StudTile.png) or Weld (assets/ui/WeldTile.png: the red and orange buttons);
-- bevel: the inset light (top left) and shade (bottom right) and their transparency;
-- border: an inside border's colour and width; outline: the black one round it; corner: radius
local function rgb(hex)
	return Color3.fromHex(hex)
end
local BUTTON = { tile = { 89.4, 0.8 }, outline = 8, corner = 5 }
HudKit.LOOKS = {
	Green = { top = rgb("caff00"), bottom = rgb("0aff00"), bevel = { 0.5, 0.5 }, base = BUTTON },
	Blue = { top = rgb("00f8ff"), bottom = rgb("00afff"), bevel = { 0.5, 0.5 }, base = BUTTON },
	Red = { top = rgb("ff0000"), bottom = rgb("d90000"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	Orange = { top = rgb("ff963c"), bottom = rgb("ef8832"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	Amber = { top = rgb("ffa100"), bottom = rgb("ffa100"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	GreenEdged = { top = rgb("caff00"), bottom = rgb("0aff00"), border = { rgb("caff02"), 5 }, base = BUTTON },
	PinkEdged = { top = rgb("ff00f2"), bottom = rgb("c300ff"), border = { rgb("ee51f9"), 5 }, base = BUTTON },
	Dark = { fill = Color3.new(0, 0, 0), alpha = 0.6, base = BUTTON },
	Header = {
		across = { rgb("ff5e00"), rgb("ffbf00"), rgb("ff4400") },
		bevel = { 0.5, 0.5, rgb("ffe500"), rgb("b60000"), 12 },
		tile = { 223.5, 0.8 },
		outline = 8,
	},
	-- the boss bar (QM's Figma Bossbar, Oct 27; its numbers are design px, doubled here): the
	-- red health (its 53% bottom over the maroon worked out) over the trail over the empty
	-- maroon bar, which carries the black outline
	BossRed = {
		top = rgb("ff0000"),
		bottom = rgb("b6000d"),
		bevel = { 0.75, 0.75, nil, nil, 8 }, -- (its one inner shadow: QM, no second band)
		tile = { 233, 0.8, "Weld" },
		corner = 8,
	},
	BossTrail = { top = rgb("fff3d6"), bottom = rgb("ffc27a"), tile = { 233, 0.85, "Weld" }, corner = 8 },
	BossEmpty = { fill = rgb("63001c"), bevel = { 0.75, 0.75, nil, nil, 8 }, outline = 12, corner = 8 },
	-- the Active Pets popup (QM's Figma ActivePets, Oct 27; client/PetsPanel)
	GoldHeader = {
		top = rgb("ffd300"),
		bottom = rgb("ffa200"),
		from = 0.001,
		bevel = { 0.5, 0.5, Color3.new(1, 1, 1), rgb("b60000"), 12 },
		tile = { 223.5, 0.8 },
		outline = 8,
	},
	Pink = { top = rgb("ff00f2"), bottom = rgb("c300ff"), bevel = { 0.5, 0.5 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	PetCard = { top = rgb("ff963c"), bottom = rgb("ad5810"), from = 0.683, bevel = { 0.75, 0.75 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	RedPlain = { top = rgb("ff0000"), bottom = rgb("d90000"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = false },
	GreyPlain = { top = rgb("a6a6a6"), bottom = rgb("6e6e6e"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = false },
	YellowPlain = { top = rgb("ffec3d"), bottom = rgb("f2b705"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = false },
	GreenPlain = { top = rgb("00ff11"), bottom = rgb("00d92b"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = false },
	-- (Equip Best: Green's colours on the close button's (Red's) studs and bevel, QM)
	GreenWeld = { top = rgb("caff00"), bottom = rgb("0aff00"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	-- the Growing Eggs popup (QM's Figma EggsPopup, Oct 27; client/EggsPanel)
	TanHeader = {
		across = { rgb("fac086"), rgb("e5ab74"), rgb("d09561") },
		bevel = { 0.5, 0, Color3.new(1, 1, 1), rgb("c37731"), 12 },
		tile = { 223.5, 0.8 },
		outline = 8,
	},
	Yellow = { top = rgb("fff000"), bottom = rgb("ff8a00"), bevel = { 0.5, 0.5 }, base = BUTTON, tile = { 230, 0.8, "Weld" } },
	EggCard = { fill = rgb("3f3f3f"), bevel = { 0.75, 0.75 }, base = BUTTON, tile = false },
	-- (its progress bar: the green across a dark track; the black border goes round the track)
	EggTrack = { fill = rgb("1c1c1c"), outline = 6, corner = 8 },
	EggGrow = { across = { rgb("00e900"), rgb("00b800"), rgb("008800") }, tile = { 230, 0.8, "Weld" }, corner = 8 },
	-- the Index popup (QM's Figma Index refs, Oct 30; client/IndexPanel): the Weapon Shop's
	-- popup with a pink and purple header, its boxes and its cards
	PinkHeader = {
		across = { rgb("e231ff"), rgb("c53dff"), rgb("dc6bff") },
		bevel = { 0.5, 0.5, rgb("ffc4ff"), rgb("5a0078"), 12 },
		tile = { 223.5, 0.8 },
		outline = 8,
	},
	IndexBox = { fill = rgb("1e1e1e"), alpha = 0.15, border = { Color3.new(0, 0, 0), 5, 0.4 }, outline = 6, corner = 10 },
	IndexCard = { fill = rgb("2f3a2a"), border = { Color3.new(0, 0, 0), 5, 0.4 }, tile = { 223.5, 0.85 }, outline = 6, corner = 10 },
	Panel = { fill = rgb("323232"), border = { Color3.new(0, 0, 0), 6, 0.5 }, tile = { 223.5, 0.9 }, outline = 8, corner = 20 },
	Card = { fill = Color3.new(1, 1, 1), border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	-- the Shop (QM's Figma "Shop" frame, Oct 30; client/Shop): its lime header, and its
	-- cards' backs, an angled gradient (Figma -49deg) under the studs, black edged
	LimeHeader = {
		across = { rgb("00ff00"), rgb("beff00"), rgb("00ff00") },
		bevel = { 0.5, 0.5, rgb("ffe500"), rgb("b60000"), 12 },
		tile = { 223.5, 0.8 },
		outline = 8,
	},
	CashCard = { diag = { rgb("21ff00"), rgb("f3fe0d"), rgb("31ff01"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	PowerCard = { diag = { rgb("0090ff"), rgb("8ff6ff"), rgb("1aa3ff"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	LifeCard = { diag = { rgb("ff2e74"), rgb("ffb3d6"), rgb("ff4f8f"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	DamageCard = { diag = { rgb("ff3c00"), rgb("ffc04d"), rgb("ff5500"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	GoldCard = { diag = { rgb("ffae00"), rgb("fff27a"), rgb("ffa200"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
	GrowthCard = { diag = { rgb("a83bff"), rgb("ff9cf0"), rgb("7a4dff"), -139 }, border = { Color3.new(0, 0, 0), 5 }, tile = { 223.5, 0.8 }, corner = 10 },
}

function HudKit.fig(n)
	return math.round(n * DESIGN_HEIGHT / FIGMA_HEIGHT)
end
local fig = HudKit.fig

function HudKit.art(parent, name, props)
	local img, fresh = Ui.make(parent, name, "ImageLabel")
	if fresh then
		img.BackgroundTransparency = 1
		img.Image = HudImages[name] or ""
		img.ScaleType = Enum.ScaleType.Fit
		for k, v in props do
			img[k] = v
		end
	end
	return img
end

function HudKit.label(parent, name, props)
	local l, fresh = Ui.make(parent, name, "TextLabel")
	if fresh then
		local stroke = Instance.new("UIStroke")
		stroke.Name = "Outline"
		stroke.Color = HudKit.BLACK
		stroke.Thickness = HudKit.TEXT_OUTLINE
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = l
		l.BackgroundTransparency = 1
		l.FontFace = HudKit.FONT
		l.TextSize = fig(60)
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextXAlignment = Enum.TextXAlignment.Left
		for k, v in props do
			l[k] = v
		end
	end
	return l
end

-- (a Figma look, with its base's values under it)
local function resolve(look)
	local spec = HudKit.LOOKS[look] or look
	if spec.base then
		local out = table.clone(spec.base)
		for k, v in spec do
			out[k] = v
		end
		return out
	end
	return spec
end

function HudKit.back(parent, look, props)
	local spec = resolve(look)
	local back, fresh = Ui.make(parent, props.Name or "Back", "Frame")
	if not fresh then
		return back
	end
	back.BorderSizePixel = 0
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.BackgroundTransparency = spec.alpha or 0
	for k, v in props do
		if k ~= "Name" then
			back[k] = v
		end
	end
	local corner = spec.corner and fig(spec.corner)
	local function round(frame)
		if corner then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, corner)
			c.Parent = frame
		end
	end
	round(back)
	local fill = Instance.new("UIGradient")
	fill.Name = "Fill"
	if spec.diag then
		-- (a Figma angled gradient, three stops: its colours and the UIGradient's Rotation)
		local c = spec.diag
		fill.Rotation = c[4]
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c[1]),
			ColorSequenceKeypoint.new(0.625, c[2]),
			ColorSequenceKeypoint.new(1, c[3]),
		})
	elseif spec.across then
		local c = spec.across
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c[1]),
			ColorSequenceKeypoint.new(0.476, c[2]),
			ColorSequenceKeypoint.new(1, c[3]),
		})
	elseif spec.top then
		fill.Rotation = 90
		fill.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, spec.top),
			ColorSequenceKeypoint.new(spec.from or 0.159, spec.top),
			ColorSequenceKeypoint.new(1, spec.bottom),
		})
	else
		fill.Color = ColorSequence.new(spec.fill)
	end
	fill.Parent = back
	if spec.outline then
		local outline = Instance.new("UIStroke")
		outline.Name = "Outline"
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Color = HudKit.BLACK
		outline.Thickness = fig(spec.outline)
		outline.Parent = back
	end
	-- the studs, tiled
	if spec.tile then
		local studs = Instance.new("ImageLabel")
		studs.Name = "Studs"
		studs.BackgroundTransparency = 1
		local size = math.max(fig(spec.tile[1]), 2)
		studs.Image = (if spec.tile[3] == "Weld" then HudImages.WeldTile else HudImages.StudTile) or ""
		studs.ScaleType = Enum.ScaleType.Tile
		studs.TileSize = UDim2.fromOffset(size, size)
		studs.ImageTransparency = spec.tile[2]
		studs.Size = UDim2.fromScale(1, 1)
		studs.Parent = back
		round(studs)
	end
	-- the bevel: light along the top and left, shade along the bottom and right
	if spec.bevel then
		local b = spec.bevel
		local width = fig(b[5] or 8)
		for _, e in {
			{ "Light", b[3] or Color3.new(1, 1, 1), b[1], UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, width) },
			{ "Light", b[3] or Color3.new(1, 1, 1), b[1], UDim2.new(0, 0, 0, width), UDim2.new(0, width, 1, -width) },
			{ "Shade", b[4] or HudKit.BLACK, b[2], UDim2.new(0, width, 1, -width), UDim2.new(1, -width, 0, width) },
			{ "Shade", b[4] or HudKit.BLACK, b[2], UDim2.new(1, -width, 0, width), UDim2.new(0, width, 1, -width) },
		} do
			local strip = Instance.new("Frame")
			strip.Name = e[1]
			strip.BorderSizePixel = 0
			strip.BackgroundColor3 = e[2]
			strip.BackgroundTransparency = e[3]
			strip.Position = e[4]
			strip.Size = e[5]
			strip.Parent = back
		end
	end
	-- an inside border: a stroke round a frame inset by its width
	if spec.border then
		local w = fig(spec.border[2])
		local inner = Instance.new("Frame")
		inner.Name = "Border"
		inner.BackgroundTransparency = 1
		inner.Position = UDim2.fromOffset(w, w)
		inner.Size = UDim2.new(1, -2 * w, 1, -2 * w)
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = spec.border[1]
		stroke.Transparency = spec.border[3] or 0
		stroke.Thickness = w
		stroke.Parent = inner
		if corner then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, math.max(corner - w, 0))
			c.Parent = inner
		end
		inner.Parent = back
	end
	return back
end

function HudKit.button(parent, name, w, h, props, look)
	local b, fresh = Ui.make(parent, name, "ImageButton")
	if fresh then
		b.BackgroundTransparency = 1
		b.Image = ""
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(fig(w), fig(h))
		for k, v in props do
			b[k] = v
		end
	end
	require(script.Parent.UiFx).centre(b) -- (so the hover's UIScale grows it from its middle)
	HudKit.back(b, look, {})
	Ui.make(b, "Hover", "UIScale")
	HudKit.hover(b)
	return b
end

-- an icon outlined black like the text beside it (QM, Oct 27: the Robux icons): black copies
-- of it nudged px out all round, under it. Once: a second call does nothing.
function HudKit.outlineArt(icon, px)
	local stem = string.gsub(icon.Name, "Icon$", "")
	local parent = icon.Parent
	if not parent or parent:FindFirstChild(stem .. "Outline1") then
		return
	end
	local z = icon.ZIndex
	icon.ZIndex = z + 1
	for k = 1, 8 do
		local a = (k - 1) * math.pi / 4
		local copy = icon:Clone()
		copy.Name = stem .. "Outline" .. k
		copy.ImageColor3 = HudKit.BLACK
		copy.Position = icon.Position + UDim2.fromOffset(math.round(math.cos(a) * px), math.round(math.sin(a) * px))
		copy.ZIndex = z
		copy.Parent = parent
	end
end

-- wires a button's hover (in Play): its Hover UIScale grows, its Back darkens; and its press
-- and sounds (client/UiFx.button: it ducks in, bounces back, clicks). Once per button.
local hovers = setmetatable({}, { __mode = "k" }) -- (not an attribute: copies would carry it)
function HudKit.hover(b)
	local grow, back = b:FindFirstChild("Hover"), b:FindFirstChild("Back")
	if not (Ui.live and grow) or hovers[b] then
		return
	end
	hovers[b] = true
	local info = TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad)
	local function hover(on)
		b:SetAttribute("HoverScale", if on then HOVER_GROW else 1)
		TweenService:Create(grow, info, { Scale = if on then HOVER_GROW else 1 }):Play()
		if back then
			TweenService:Create(back, info, { BackgroundColor3 = if on then HOVER_DARK else Color3.new(1, 1, 1) }):Play()
		end
	end
	b.MouseEnter:Connect(function()
		hover(true)
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
	require(script.Parent.UiFx).button(b)
end

function HudKit.popup(root, name, title, headerLook)
	local gui, fresh = Ui.make(root, name, "Frame")
	if fresh then
		-- (Figma: 2268 x 1370, centred on the screen)
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(0.5, 0.5)
		gui.Position = UDim2.fromScale(0.5, 0.5)
		gui.Size = UDim2.fromOffset(fig(2268), fig(1370))
		gui.ZIndex = 10
		gui.Visible = not Ui.live -- (shown in Studio to edit; in Play when it's opened)
	end
	Ui.make(gui, "Pop", "UIScale")
	HudKit.back(gui, "Panel", {
		Name = "Panel",
		-- (tucked under the header, so only its bottom corners show rounded)
		Position = UDim2.fromOffset(0, fig(263)),
		Size = UDim2.fromOffset(fig(2268), fig(1107)),
	})
	local header = HudKit.back(gui, headerLook, {
		Name = "Header",
		Size = UDim2.fromOffset(fig(2268), fig(283)),
		ZIndex = 2,
	})
	-- the shine: slanted white stripes, clipped to the header by a CanvasGroup (a rotated
	-- frame isn't clipped by ClipsDescendants)
	local shine
	shine, fresh = Ui.make(header, "Shine", "CanvasGroup")
	if fresh then
		shine.BackgroundTransparency = 1
		shine.Size = UDim2.fromScale(1, 1)
		shine.GroupTransparency = SHINE_ALPHA
		shine.ZIndex = 2
		for i, st in SHINE do
			local stripe = Instance.new("Frame")
			stripe.Name = "Stripe" .. i
			stripe.BackgroundColor3 = Color3.new(1, 1, 1)
			stripe.BorderSizePixel = 0
			stripe.AnchorPoint = Vector2.new(0.5, 0.5)
			stripe.Position = UDim2.fromScale(st.at, 0.5)
			stripe.Size = UDim2.new(st.width, 0, 2, 0)
			stripe.Rotation = SHINE_SLANT
			stripe.Parent = shine
		end
	end
	HudKit.label(gui, "Title", {
		Text = title,
		TextSize = fig(130),
		Position = UDim2.fromOffset(fig(70), fig(66)),
		Size = UDim2.fromOffset(fig(1100), fig(158)),
		ZIndex = 4,
	})
	-- (Figma: an 8px drop shadow under the title)
	HudKit.label(gui, "TitleShadow", {
		Text = title,
		TextSize = fig(130),
		TextColor3 = HudKit.BLACK,
		Position = UDim2.fromOffset(fig(70), fig(66 + 8)),
		Size = UDim2.fromOffset(fig(1100), fig(158)),
		ZIndex = 3,
	})
	local close = HudKit.button(gui, "ShopClose", 174, 174, { Position = UDim2.fromOffset(fig(2046), fig(54)), ZIndex = 4 }, "Red")
	HudKit.label(close, "X", {
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	if Ui.live then
		gui.Visible = false
	end
	return gui, close
end

return HudKit
