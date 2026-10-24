-- The Shop, Index and Rebirth popups (QM, Oct 24), in the style of his references: a
-- dark rounded panel with a thick black outline, a big title sitting on its top-left
-- edge, a red X on its top-right corner, and dark cards inside with green (buy) and
-- grey (action) buttons. There's no content yet, so each is laid out with placeholder
-- items built from the same pieces the real content will use (Popups.card, .slot,
-- .button, .bar), ready to be filled in.
--
-- Behaviour (QM's rule from Lasso For Eggs): opening one hides the rest of the HUD and
-- blurs the world behind it; it pops in with a Back ease and out with a little swell
-- before it shrinks away. One at a time: opening another swaps them. The X, Escape, or
-- clicking the same HUD button again closes it.
--
--   Popups.init(root, hudFrames)  -- once, from Hud (root = its scaled frame; the boss
--                                  -- bar hides itself while Popups.isOpen())
--   Popups.toggle(name)                     -- "Shop", "Index", "Rebirth"

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Popups = {}
Popups.abbreviate = tostring -- (Hud hands its own over before init: 1.5K, 12M...)

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(14, 12, 16) -- outlines
local WHITE = Color3.new(1, 1, 1)
-- gradient base colours: each is drawn as a hue-shifted ramp (see ramp())
local GREEN = Color3.fromRGB(122, 222, 58)
local GREY = Color3.fromRGB(196, 197, 204)
local RED = Color3.fromRGB(232, 52, 62)
local GOLD = Color3.fromRGB(246, 186, 66)
local MINT = Color3.fromRGB(160, 238, 104)
local TEAL = Color3.fromRGB(88, 216, 192)
local BLUR = 14
local ICONS = { -- (the HUD counters' art, cropped to the icon)
	Power = "rbxassetid://108359754385647",
	Cash = "rbxassetid://83332868999001",
}

local player = Players.LocalPlayer

-- ---- pieces -------------------------------------------------------------------------

local function corner(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function outline(parent, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

-- Hue shifting (QM's style): a gradient doesn't just go lighter and darker, its hue
-- moves too: the lit top slides toward warm yellow and the shaded bottom toward cool
-- blue-violet, the way painted light and shadow do. For a colour `c`:
--   top    hue nudged SHIFT toward yellow (1/6), value up LIGHT, saturation down a touch
--   bottom hue nudged SHIFT toward blue-violet (0.7), value down DARK, saturation up
-- Greys get a little saturation so their ends can lean warm and cool too, and dark
-- colours (the panel, the cards) get gentler steps, scaled by how bright they are.
local SHIFT, LIGHT, DARK = 0.045, 0.14, 0.24
local function towards(h, target, amount)
	local d = (target - h + 0.5) % 1 - 0.5 -- shortest way round the hue circle
	return (h + math.clamp(d, -amount, amount)) % 1
end
local function ramp(c)
	local h, s, v = c:ToHSV()
	local minS = 0.08
	local top =
		Color3.fromHSV(towards(h, 1 / 6, SHIFT), math.max(s * 0.85, minS), math.min(v + LIGHT * (0.4 + 0.6 * v), 1))
	local bottom =
		Color3.fromHSV(towards(h, 0.7, SHIFT), math.min(math.max(s * 1.15, minS + 0.04), 1), math.max(v - DARK * v, 0))
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(0.45, c),
		ColorSequenceKeypoint.new(1, bottom),
	})
end
Popups.ramp = ramp

local function gradient(parent, base)
	local g = Instance.new("UIGradient")
	g.Color = ramp(base)
	g.Rotation = 90
	g.Parent = parent
end

function Popups.text(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = props.bold and BOLD or FONT
	props.bold = nil
	label.TextColor3 = WHITE
	label.TextSize = 36
	for k, v in props do
		label[k] = v
	end
	local s = Instance.new("UIStroke")
	s.Thickness = math.max(2, label.TextSize / 12)
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	label.Parent = parent
	return label
end

-- a card: a darker rounded panel (or a coloured one) inside a popup
-- QM's dark background (assets/ui/DarkPanel.png: a radial gradient in a black rounded
-- outline), 9-sliced so it stretches to any size with its corners and outline intact
local DARK_PANEL = "rbxassetid://76862497378032"
local DARK_SLICE = Rect.new(26, 26, 490, 492)
local function darkPanel(props, sliceScale)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = DARK_PANEL
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = DARK_SLICE
	img.SliceScale = sliceScale
	for k, v in props do
		img[k] = v
	end
	return img
end

-- a card inside a popup: QM's dark panel, or with `colors` a coloured one (hue-shifted)
function Popups.card(parent, props, colors)
	if not colors then
		local img = darkPanel(props, 0.5)
		img.Parent = parent
		return img
	end
	local f = Instance.new("Frame")
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	corner(f, 14)
	outline(f, 4)
	gradient(f, colors)
	f.Parent = parent
	return f
end

-- an item slot: a square card with a name on top and an amount bottom-right
function Popups.slot(parent, props, name, amount, icon)
	local s = Popups.card(parent, props)
	if icon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.55)
		img.Size = UDim2.fromScale(0.62, 0.62)
		img.Image = ICONS[icon] or icon
		if ICONS[icon] then
			img.ImageRectSize = Vector2.new(103, 103)
		end
		img.Parent = s
	end
	Popups.text(
		s,
		{ Text = name or "???", TextSize = 22, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4) }
	)
	if amount then
		Popups.text(s, {
			Text = amount,
			TextSize = 28,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -8, 1, -2),
			Size = UDim2.new(1, -8, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end
	return s
end

-- a chunky button: green to buy, grey for actions; it squashes when pressed
function Popups.button(parent, props, label, colors, onClick)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = WHITE
	b.BorderSizePixel = 0
	for k, v in props do
		b[k] = v
	end
	corner(b, 12)
	outline(b, 4)
	gradient(b, colors or GREEN)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	Popups.text(b, { Text = label, TextSize = 44, Size = UDim2.fromScale(1, 1) })
	local function to(s, t)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back), { Scale = s }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.05, 0.12)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.12)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.92, 0.06)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.05, 0.15)
	end)
	if onClick then
		b.Activated:Connect(onClick)
	end
	b.Parent = parent
	return b
end
Popups.GREEN, Popups.GREY, Popups.GOLD, Popups.MINT = GREEN, GREY, GOLD, MINT

-- a progress bar with an icon on its left end and "have/need" on it; returns a setter
function Popups.bar(parent, props, icon, colors)
	local back = Popups.card(parent, props)
	local track = Instance.new("Frame") -- (inside the card's outline)
	track.BackgroundTransparency = 1
	track.Position = UDim2.fromOffset(5, 5)
	track.Size = UDim2.new(1, -10, 1, -10)
	track.Parent = back
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = WHITE
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	corner(fill, 30)
	gradient(fill, colors or TEAL)
	fill.Parent = track
	local label = Popups.text(back, { Text = "0/0", TextSize = 38, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	if icon then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.new(0, 0, 0.5, 0)
		img.Size = UDim2.fromOffset(96, 96)
		img.Image = ICONS[icon] or icon
		if ICONS[icon] then
			img.ImageRectSize = Vector2.new(103, 103)
		end
		img.ZIndex = 4
		img.Parent = back
	end
	return function(have, need, text)
		fill.Size = UDim2.fromScale(math.clamp(have / math.max(need, 1), 0, 1), 1)
		label.Text = text or (tostring(have) .. "/" .. tostring(need))
	end
end

-- ---- the frame every popup shares ---------------------------------------------------

local scaled, hud = nil, {}
local popups = {}
local open = nil
local blur = nil

local function frame(name, title, size)
	local holder = Instance.new("Frame")
	holder.Name = name
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 20)
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.Visible = false
	holder.ZIndex = 10
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local panel = darkPanel({ Name = "Panel", Size = UDim2.fromScale(1, 1) }, 0.8)
	panel.Parent = holder

	Popups.text(holder, {
		Name = "Title",
		Text = title,
		TextSize = 76,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(-24, 30),
		Size = UDim2.fromOffset(700, 90),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = ""
	close.AutoButtonColor = false
	close.BackgroundColor3 = WHITE
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -6, 0, 6)
	close.Size = UDim2.fromOffset(84, 84)
	close.ZIndex = 5
	corner(close, 12)
	outline(close, 6)
	gradient(close, RED)
	Popups.text(close, { Text = "X", TextSize = 64, Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	close.Activated:Connect(function()
		Popups.close()
	end)
	close.Parent = holder

	-- (content goes in here, inset from the outline)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(28, 50)
	body.Size = UDim2.new(1, -56, 1, -78)
	body.ZIndex = 2
	body.Parent = holder

	holder.Parent = scaled
	popups[name] = { holder = holder, scale = scale, body = body }
	return body
end

-- ---- the three popups (placeholder content in the real layout) ----------------------

local function buildShop()
	local body = frame("Shop", "SHOP", Vector2.new(1120, 650))
	-- an offer: a gold card with its name, the items in it, the old and new price
	local pack = Popups.card(body, { Size = UDim2.new(1, 0, 0, 270) }, GOLD)
	Popups.text(
		pack,
		{ Text = "Starter Pack", TextSize = 64, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, 10) }
	)
	for i = 1, 5 do
		Popups.slot(pack, {
			Position = UDim2.fromOffset(20 + (i - 1) * 152, 105),
			Size = UDim2.fromOffset(138, 138),
		}, "Item", "x1")
	end
	Popups.button(pack, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 170),
		Size = UDim2.fromOffset(222, 72),
	}, "R$ --", GREEN)
	Popups.text(pack, {
		Text = "R$ --",
		TextSize = 40,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 110),
		Size = UDim2.fromOffset(222, 50),
		TextColor3 = Color3.fromRGB(230, 230, 230),
	})
	-- a boost: a green card with a headline and a price
	local boost = Popups.card(body, { Position = UDim2.fromOffset(0, 300), Size = UDim2.new(1, 0, 0, 220) }, MINT)
	Popups.text(boost, {
		Text = "BOOST Coming Soon!",
		TextSize = 58,
		Position = UDim2.fromOffset(220, 20),
		Size = UDim2.new(1, -240, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Popups.slot(boost, { Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(170, 170) }, "Boost", "x2")
	Popups.text(boost, {
		Text = "x1  ->  x2",
		TextSize = 64,
		Position = UDim2.fromOffset(220, 110),
		Size = UDim2.fromOffset(420, 90),
	})
	Popups.button(boost, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(222, 72),
	}, "R$ --", GREEN)
end

local function buildIndex()
	local body = frame("Index", "Pet Index", Vector2.new(1180, 680))
	-- the grid of pets: ??? until discovered
	local grid = Popups.card(body, { Size = UDim2.fromOffset(760, 470) })
	for row = 0, 2 do
		for col = 0, 4 do
			Popups.slot(grid, {
				Position = UDim2.fromOffset(20 + col * 146, 18 + row * 150),
				Size = UDim2.fromOffset(132, 136),
			}, "???", "1/?")
		end
	end
	-- the picked pet's details
	local detail = Popups.card(body, { Position = UDim2.fromOffset(790, 0), Size = UDim2.fromOffset(334, 310) })
	Popups.text(
		detail,
		{ Text = "???", TextSize = 46, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 50) }
	)
	Popups.text(detail, {
		Text = "Pick a pet",
		TextSize = 30,
		bold = true,
		Position = UDim2.fromOffset(0, 205),
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = Color3.fromRGB(200, 200, 210),
	})
	-- rewards for unlocking enough of them
	local rewards = Popups.card(body, { Position = UDim2.fromOffset(790, 330), Size = UDim2.fromOffset(334, 230) })
	Popups.text(rewards, {
		Text = "Rewards:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(200, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for i = 0, 2 do
		Popups.slot(
			rewards,
			{ Position = UDim2.fromOffset(20 + i * 102, 48), Size = UDim2.fromOffset(92, 92) },
			"",
			"x1",
			if i == 1 then "Cash" else nil
		)
	end
	Popups.button(rewards, { Position = UDim2.fromOffset(40, 152), Size = UDim2.fromOffset(254, 64) }, "CLAIM", GREY)
	-- progress to the next reward
	Popups.text(body, {
		Text = "Unlocks Needed:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(80, 486),
		Size = UDim2.fromOffset(300, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local set = Popups.bar(body, { Position = UDim2.fromOffset(40, 524), Size = UDim2.fromOffset(720, 66) })
	set(0, 10)
end

local function buildRebirth()
	local body = frame("Rebirth", "REBIRTH", Vector2.new(1100, 640))
	Popups.text(body, {
		Text = "Your pets and items are all kept!",
		TextSize = 32,
		TextColor3 = Color3.fromRGB(150, 245, 90),
		Position = UDim2.fromOffset(200, 0),
		Size = UDim2.fromOffset(700, 40),
	})
	-- each stat: what you have -> what you'll have (QM, Oct 24: a rebirth resets your cash,
	-- Strength and training grounds; every hit trains more for each one: Config.Rebirth)
	local rows = {
		{ "Cash", Color3.fromRGB(255, 120, 110) },
		{ "Power", Color3.fromRGB(150, 245, 90) },
	}
	local labels = {}
	for i, row in rows do
		local y = 60 + (i - 1) * 108
		labels[row[1]] = {}
		for side = 0, 1 do
			local x = 110 + side * 520
			local pill =
				Popups.card(body, { Position = UDim2.fromOffset(x + 50, y + 10), Size = UDim2.fromOffset(310, 78) })
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Image = ICONS[row[1]]
			img.ImageRectSize = Vector2.new(103, 103)
			img.Position = UDim2.fromOffset(x, y)
			img.Size = UDim2.fromOffset(100, 100)
			img.ZIndex = 3
			img.Parent = body
			labels[row[1]][side] = Popups.text(pill, {
				Text = "",
				TextSize = 52,
				TextColor3 = if side == 0 then WHITE else row[2],
				Position = UDim2.fromOffset(64, 0),
				Size = UDim2.new(1, -72, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		Popups.text(
			body,
			{ Text = "->", TextSize = 60, Position = UDim2.fromOffset(470, y + 10), Size = UDim2.fromOffset(150, 78) }
		)
	end
	Popups.text(body, {
		Text = "Cash Needed:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(120, 400),
		Size = UDim2.fromOffset(300, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local set =
		Popups.bar(body, { Position = UDim2.fromOffset(90, 440), Size = UDim2.fromOffset(470, 70) }, "Cash", GREEN)
	local rebirths = Popups.text(body, {
		Text = "You have 0 rebirths",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(700, 400),
		Size = UDim2.fromOffset(300, 36),
	})
	local remote = ReplicatedStorage:WaitForChild("Rebirth", 10)
	local busy = false
	Popups.button(
		body,
		{ Position = UDim2.fromOffset(700, 440), Size = UDim2.fromOffset(300, 80) },
		"REBIRTH",
		GREY,
		function()
			if busy or not remote then
				return
			end
			busy = true
			pcall(remote.InvokeServer, remote)
			busy = false
		end
	)
	local function count()
		local r = player:GetAttribute("Rebirths") or 0
		local c = Config.Rebirth
		local cost = math.floor(c.Cost * c.Growth ^ r)
		rebirths.Text = string.format("You have %d rebirths", r)
		labels.Cash[0].Text = Popups.abbreviate(player:GetAttribute("Cash") or 0)
		labels.Cash[1].Text = "0"
		labels.Power[0].Text = string.format("%gx", 1 + r * c.StrengthBonus)
		labels.Power[1].Text = string.format("%gx", 1 + (r + 1) * c.StrengthBonus)
		set(math.min(player:GetAttribute("Cash") or 0, cost), cost)
	end
	count()
	player:GetAttributeChangedSignal("Rebirths"):Connect(count)
	player:GetAttributeChangedSignal("Cash"):Connect(count)
end

-- ---- opening and closing ------------------------------------------------------------

local function setHud(visible)
	for _, f in hud do
		f.Visible = visible
	end
end

local function show(name)
	local p = popups[name]
	open = name
	p.holder.Visible = true
	p.scale.Scale = 0.6
	TweenService:Create(p.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(blur, TweenInfo.new(0.25), { Size = BLUR }):Play()
	setHud(false)
end

function Popups.close()
	if not open then
		return
	end
	local p = popups[open]
	open = nil
	-- a little swell first (anticipation), then shrink away
	local swell = TweenService:Create(
		p.scale,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 1.06 }
	)
	swell.Completed:Once(function()
		local shrink = TweenService:Create(
			p.scale,
			TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.3 }
		)
		shrink.Completed:Once(function()
			if popups[open or ""] ~= p then
				p.holder.Visible = false
			end
		end)
		shrink:Play()
	end)
	swell:Play()
	TweenService:Create(blur, TweenInfo.new(0.2), { Size = 0 }):Play()
	setHud(true)
end

function Popups.toggle(name)
	if open == name then
		Popups.close()
	elseif open then
		popups[open].holder.Visible = false
		open = nil
		show(name)
	else
		show(name)
	end
end

function Popups.isOpen()
	return open
end

function Popups.init(root, hudFrames)
	scaled, hud = root, hudFrames
	blur = Instance.new("BlurEffect")
	blur.Name = "PopupBlur"
	blur.Size = 0
	blur.Parent = Lighting
	buildShop()
	buildIndex()
	buildRebirth()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and open and not processed then
			Popups.close()
		end
	end)
end

return Popups
