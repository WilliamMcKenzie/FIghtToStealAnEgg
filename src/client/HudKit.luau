-- The pieces QM's NewUI is made of (Oct 27), shared by client/Hud and client/WeaponShop.
-- Everything is laid out in design px (1080 tall: the Hud's Root scales it to the screen);
-- QM's Figma frame is 2190 tall, so its numbers go through HudKit.fig. Each piece is made
-- with Ui.make, so a copy QM edited in StarterGui is kept as it is (client/Ui).
--
--   HudKit.fig(n) -> design px           -- Figma px to design px
--   HudKit.art(parent, name, props)      -- a Figma layer exported as it is (HudImages[name])
--   HudKit.label(parent, name, props)    -- white Montserrat ExtraBold, black outline
--   HudKit.button(parent, name, w, h, props) -- a button whose back is HudImages[name]
--     (w x h Figma px; the back holds the black outline, 8 Figma px past the edge). Under the
--     mouse it grows from its centre and its back darkens (QM, Oct 27), its icon and text not.

local TweenService = game:GetService("TweenService")

local HudImages = require(script.Parent.HudImages)
local Ui = require(script.Parent.Ui)

local HudKit = {}

local DESIGN_HEIGHT = 1080
local FIGMA_HEIGHT = 2190 -- (QM's NewUI frame)
local HOVER_GROW = 1.08 -- a button grows this much under the mouse (QM: snappy)
local HOVER_DARK = Color3.fromRGB(205, 205, 205) -- its back's tint then
local HOVER_TIME = 0.08

HudKit.FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
HudKit.ITALIC = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
HudKit.BLACK = Color3.new(0, 0, 0)

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
		stroke.Thickness = 3
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

-- anchors `b` on its centre without moving it (so the hover's UIScale grows it from there;
-- also fixes a copy baked before, anchored on its left)
local function centre(b)
	local a = b.AnchorPoint
	if a == Vector2.new(0.5, 0.5) then
		return
	end
	local size, pos = b.Size, b.Position
	b.Position = UDim2.new(
		pos.X.Scale + (0.5 - a.X) * size.X.Scale,
		pos.X.Offset + math.round((0.5 - a.X) * size.X.Offset),
		pos.Y.Scale + (0.5 - a.Y) * size.Y.Scale,
		pos.Y.Offset + math.round((0.5 - a.Y) * size.Y.Offset)
	)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
end

function HudKit.button(parent, name, w, h, props)
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
	centre(b)
	HudKit.art(b, name, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, fig(16), 1, fig(16)),
		ScaleType = Enum.ScaleType.Stretch,
	})
	Ui.make(b, "Hover", "UIScale")
	HudKit.hover(b)
	return b
end

-- wires a button's hover (in Play): its Hover UIScale grows, its back (the child named like
-- it) darkens
function HudKit.hover(b)
	local grow, back = b:FindFirstChild("Hover"), b:FindFirstChild(b.Name)
	if not (Ui.live and grow) then
		return
	end
	local info = TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad)
	local function hover(on)
		TweenService:Create(grow, info, { Scale = if on then HOVER_GROW else 1 }):Play()
		if back then
			TweenService:Create(back, info, { ImageColor3 = if on then HOVER_DARK else Color3.new(1, 1, 1) }):Play()
		end
	end
	b.MouseEnter:Connect(function()
		hover(true)
	end)
	b.MouseLeave:Connect(function()
		hover(false)
	end)
end

return HudKit
