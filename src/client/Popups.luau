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
--   Popups.toggle(name)                     -- "Shop", "Index", "Rebirth", "Backpack"
--   Popups.frame(name, title, size, tiled) -> body, holder  -- another popup (client/Backpack),
--                                  -- after init: its content goes in body; `tiled` gives it
--                                  -- QM's plain tiled beige panel (no title or X) instead
--
-- They're real objects QM edits in Studio (StarterGui > Hud > Root > ShopPopup ...: see
-- client/Ui). Every piece is made with a Name and only when it isn't there yet, and its
-- strokes, corners and gradients only when it's new, so QM's edits are what shows in Play.
-- The helpers below (text, card, slot, button, bar) take that name as props.Name; without
-- one they always make a new piece (WeaponSpin's, built fresh each time).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Ui = require(script.Parent.Ui)

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

-- props.Name's child of parent if it's there already, otherwise a new `class` (fresh = true:
-- the caller sets it up). props.Name is taken out of props.
local function make(parent, class, props)
	local name = props.Name
	props.Name = nil
	if name then
		return Ui.make(parent, name, class)
	end
	local inst = Instance.new(class)
	inst.Parent = parent
	return inst, true
end

local function apply(inst, props)
	for k, v in props do
		inst[k] = v
	end
end

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
	local bold = props.bold
	props.bold = nil
	local label, fresh = make(parent, "TextLabel", props)
	if not fresh then
		return label, false
	end
	label.BackgroundTransparency = 1
	label.FontFace = bold and BOLD or FONT
	label.TextColor3 = WHITE
	label.TextSize = 36
	apply(label, props)
	local s = Instance.new("UIStroke")
	s.Thickness = math.max(2, label.TextSize / 12)
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	return label, true
end

-- a card: a darker rounded panel (or a coloured one) inside a popup
-- QM's dark background (assets/ui/DarkPanel.png: a radial gradient in a black rounded
-- outline), 9-sliced so it stretches to any size with its corners and outline intact
local DARK_PANEL = "rbxassetid://76862497378032"
local DARK_SLICE = Rect.new(26, 26, 490, 492)
local function darkPanel(parent, props, sliceScale)
	local img, fresh = make(parent, "ImageLabel", props)
	if fresh then
		img.BackgroundTransparency = 1
		img.Image = DARK_PANEL
		img.ScaleType = Enum.ScaleType.Slice
		img.SliceCenter = DARK_SLICE
		img.SliceScale = sliceScale
		apply(img, props)
	end
	return img, fresh
end

-- a card inside a popup: QM's dark panel, or with `colors` a coloured one (hue-shifted)
function Popups.card(parent, props, colors)
	if not colors then
		return darkPanel(parent, props, 0.5)
	end
	local f, fresh = make(parent, "Frame", props)
	if fresh then
		f.BackgroundColor3 = WHITE
		f.BorderSizePixel = 0
		apply(f, props)
		corner(f, 14)
		outline(f, 4)
		gradient(f, colors)
	end
	return f, fresh
end

-- an item slot: a square card with a name on top and an amount bottom-right
function Popups.slot(parent, props, name, amount, icon)
	local s = Popups.card(parent, props)
	if icon then
		local img, fresh = Ui.make(s, "Icon", "ImageLabel")
		if fresh then
			img.BackgroundTransparency = 1
			img.AnchorPoint = Vector2.new(0.5, 0.5)
			img.Position = UDim2.fromScale(0.5, 0.55)
			img.Size = UDim2.fromScale(0.62, 0.62)
			img.Image = ICONS[icon] or icon
			if ICONS[icon] then
				img.ImageRectSize = Vector2.new(103, 103)
			end
		end
	end
	Popups.text(s, {
		Name = "ItemName",
		Text = name or "???",
		TextSize = 22,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 4),
	})
	if amount then
		Popups.text(s, {
			Name = "Amount",
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
	local b, fresh = make(parent, "TextButton", props)
	if fresh then
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = WHITE
		b.BorderSizePixel = 0
		apply(b, props)
		corner(b, 12)
		outline(b, 4)
		gradient(b, colors or GREEN)
	end
	local scale = Ui.make(b, "Press", "UIScale")
	Popups.text(b, { Name = "Label", Text = label, TextSize = 44, Size = UDim2.fromScale(1, 1) })
	if not Ui.live then
		return b, fresh
	end
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
	return b, fresh
end
Popups.GREEN, Popups.GREY, Popups.GOLD, Popups.MINT = GREEN, GREY, GOLD, MINT

-- a progress bar with an icon on its left end and "have/need" on it; returns a setter
function Popups.bar(parent, props, icon, colors)
	local back = Popups.card(parent, props)
	local track, fresh = Ui.make(back, "Track", "Frame") -- (inside the card's outline)
	if fresh then
		track.BackgroundTransparency = 1
		track.Position = UDim2.fromOffset(5, 5)
		track.Size = UDim2.new(1, -10, 1, -10)
	end
	local fill
	fill, fresh = Ui.make(track, "Fill", "Frame")
	if fresh then
		fill.BackgroundColor3 = WHITE
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		corner(fill, 30)
		gradient(fill, colors or TEAL)
	end
	local label =
		Popups.text(back, { Name = "Label", Text = "0/0", TextSize = 38, Size = UDim2.fromScale(1, 1), ZIndex = 3 })
	local img
	if icon then
		img, fresh = Ui.make(back, "Icon", "ImageLabel")
	end
	if img and fresh then
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.new(0, 0, 0.5, 0)
		img.Size = UDim2.fromOffset(96, 96)
		img.Image = ICONS[icon] or icon
		if ICONS[icon] then
			img.ImageRectSize = Vector2.new(103, 103)
		end
		img.ZIndex = 4
	end
	return function(have, need, text)
		fill.Size = UDim2.fromScale(math.clamp(have / math.max(need, 1), 0, 1), 1)
		label.Text = text or (tostring(have) .. "/" .. tostring(need))
	end
end

-- QM's tiled panel (Oct 26, for the Backpack): the beige checker texture (assets/ui/TileBG.png,
-- two squares a side) repeated over it, rounded, with a C1A283 outline. Until the texture's
-- uploaded it's plain beige.
local TILE_PANEL = "rbxassetid://82411896099201" -- (rbxassetid of assets/ui/TileBG.png)
local TILE = 80 -- design px of one repeat (two checker squares)
local function tiledPanel(parent, props)
	local img, fresh = make(parent, "ImageLabel", props)
	if fresh then
		img.BackgroundColor3 = Color3.fromRGB(231, 206, 181)
		img.BorderSizePixel = 0
		img.Image = TILE_PANEL
		img.ScaleType = Enum.ScaleType.Tile
		img.TileSize = UDim2.fromOffset(TILE, TILE)
		apply(img, props)
		corner(img, 18)
		local s = Instance.new("UIStroke")
		s.Thickness = 6
		s.Color = Color3.fromHex("C1A283")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = img
	end
	return img, fresh
end

-- ---- the frame every popup shares ---------------------------------------------------

local scaled, hud = nil, {}
local popups = {}
local open = nil
local blur = nil

local function frame(name, title, size, tiled)
	-- (StarterGui > Hud > Root > ShopPopup: in Studio, tick its Visible to see it while editing;
	-- the game hides it again until it's opened)
	local holder, fresh = Ui.make(scaled, name .. "Popup", "Frame")
	if fresh then
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.new(0.5, 0, 0.5, 20)
		holder.Size = UDim2.fromOffset(size.X, size.Y)
		holder.ZIndex = 10
	end
	holder.Visible = false
	local scale = Ui.make(holder, "Pop", "UIScale")
	scale.Scale = 1

	if tiled then
		tiledPanel(holder, { Name = "Panel", Size = UDim2.fromScale(1, 1) })
	else
		darkPanel(holder, { Name = "Panel", Size = UDim2.fromScale(1, 1) }, 0.8)
	end

	-- (QM's tiled panel is plain for now, Oct 26: no title or X; Escape still closes it)
	if not tiled then
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

		local close
		close, fresh = Ui.make(holder, "Close", "TextButton")
		if fresh then
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
		end
		Popups.text(close, { Name = "X", Text = "X", TextSize = 64, Size = UDim2.fromScale(1, 1), ZIndex = 6 })
		if Ui.live then
			close.Activated:Connect(function()
				Popups.close()
			end)
		end
	end

	-- (content goes in here, inset from the outline)
	local body
	body, fresh = Ui.make(holder, "Body", "Frame")
	if fresh then
		body.BackgroundTransparency = 1
		body.Position = UDim2.fromOffset(28, 50)
		body.Size = UDim2.new(1, -56, 1, -78)
		body.ZIndex = 2
	end

	popups[name] = { holder = holder, scale = scale, body = body }
	return body
end

Popups.frame = function(name, title, size, tiled)
	local body = frame(name, title, size, tiled)
	return body, popups[name].holder
end
Popups.darkPanel = darkPanel

-- ---- the three popups (placeholder content in the real layout) ----------------------

local function buildShop()
	local body = frame("Shop", "SHOP", Vector2.new(1120, 650))
	-- an offer: a gold card with its name, the items in it, the old and new price
	local pack = Popups.card(body, { Name = "StarterPack", Size = UDim2.new(1, 0, 0, 270) }, GOLD)
	Popups.text(pack, {
		Name = "PackName",
		Text = "Starter Pack",
		TextSize = 64,
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, 10),
	})
	for i = 1, 5 do
		Popups.slot(pack, {
			Name = "Item" .. i,
			Position = UDim2.fromOffset(20 + (i - 1) * 152, 105),
			Size = UDim2.fromOffset(138, 138),
		}, "Item", "x1")
	end
	Popups.button(pack, {
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 170),
		Size = UDim2.fromOffset(222, 72),
	}, "R$ --", GREEN)
	Popups.text(pack, {
		Name = "OldPrice",
		Text = "R$ --",
		TextSize = 40,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 110),
		Size = UDim2.fromOffset(222, 50),
		TextColor3 = Color3.fromRGB(230, 230, 230),
	})
	-- a boost: a green card with a headline and a price
	local boost =
		Popups.card(body, { Name = "Boost", Position = UDim2.fromOffset(0, 300), Size = UDim2.new(1, 0, 0, 220) }, MINT)
	Popups.text(boost, {
		Name = "Headline",
		Text = "BOOST Coming Soon!",
		TextSize = 58,
		Position = UDim2.fromOffset(220, 20),
		Size = UDim2.new(1, -240, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Popups.slot(
		boost,
		{ Name = "Item", Position = UDim2.fromOffset(24, 24), Size = UDim2.fromOffset(170, 170) },
		"Boost",
		"x2"
	)
	Popups.text(boost, {
		Name = "Multiplier",
		Text = "x1  ->  x2",
		TextSize = 64,
		Position = UDim2.fromOffset(220, 110),
		Size = UDim2.fromOffset(420, 90),
	})
	Popups.button(boost, {
		Name = "Buy",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.fromOffset(222, 72),
	}, "R$ --", GREEN)
end

local function buildIndex()
	local body = frame("Index", "Pet Index", Vector2.new(1180, 680))
	-- the grid of pets: ??? until discovered
	local grid = Popups.card(body, { Name = "Grid", Size = UDim2.fromOffset(760, 470) })
	for row = 0, 2 do
		for col = 0, 4 do
			Popups.slot(grid, {
				Name = "Pet" .. (row * 5 + col + 1),
				Position = UDim2.fromOffset(20 + col * 146, 18 + row * 150),
				Size = UDim2.fromOffset(132, 136),
			}, "???", "1/?")
		end
	end
	-- the picked pet's details
	local detail =
		Popups.card(body, { Name = "Detail", Position = UDim2.fromOffset(790, 0), Size = UDim2.fromOffset(334, 310) })
	Popups.text(detail, {
		Name = "PetName",
		Text = "???",
		TextSize = 46,
		Position = UDim2.fromOffset(0, 150),
		Size = UDim2.new(1, 0, 0, 50),
	})
	Popups.text(detail, {
		Name = "Hint",
		Text = "Pick a pet",
		TextSize = 30,
		bold = true,
		Position = UDim2.fromOffset(0, 205),
		Size = UDim2.new(1, 0, 0, 40),
		TextColor3 = Color3.fromRGB(200, 200, 210),
	})
	-- rewards for unlocking enough of them
	local rewards = Popups.card(
		body,
		{ Name = "Rewards", Position = UDim2.fromOffset(790, 330), Size = UDim2.fromOffset(334, 230) }
	)
	Popups.text(rewards, {
		Name = "Heading",
		Text = "Rewards:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.fromOffset(200, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	for i = 0, 2 do
		Popups.slot(rewards, {
			Name = "Reward" .. (i + 1),
			Position = UDim2.fromOffset(20 + i * 102, 48),
			Size = UDim2.fromOffset(92, 92),
		}, "", "x1", if i == 1 then "Cash" else nil)
	end
	Popups.button(
		rewards,
		{ Name = "Claim", Position = UDim2.fromOffset(40, 152), Size = UDim2.fromOffset(254, 64) },
		"CLAIM",
		GREY
	)
	-- progress to the next reward
	Popups.text(body, {
		Name = "UnlocksNeeded",
		Text = "Unlocks Needed:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(80, 486),
		Size = UDim2.fromOffset(300, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local set =
		Popups.bar(body, { Name = "Progress", Position = UDim2.fromOffset(40, 524), Size = UDim2.fromOffset(720, 66) })
	set(0, 10)
end

local function buildRebirth()
	local body = frame("Rebirth", "REBIRTH", Vector2.new(1100, 640))
	Popups.text(body, {
		Name = "Kept",
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
			local which = row[1] .. (if side == 0 then "Now" else "After")
			local pill = Popups.card(body, {
				Name = which,
				Position = UDim2.fromOffset(x + 50, y + 10),
				Size = UDim2.fromOffset(310, 78),
			})
			local img, fresh = Ui.make(body, which .. "Icon", "ImageLabel")
			if fresh then
				img.BackgroundTransparency = 1
				img.Image = ICONS[row[1]]
				img.ImageRectSize = Vector2.new(103, 103)
				img.Position = UDim2.fromOffset(x, y)
				img.Size = UDim2.fromOffset(100, 100)
				img.ZIndex = 3
			end
			labels[row[1]][side] = Popups.text(pill, {
				Name = "Value",
				Text = "",
				TextSize = 52,
				TextColor3 = if side == 0 then WHITE else row[2],
				Position = UDim2.fromOffset(64, 0),
				Size = UDim2.new(1, -72, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
		end
		Popups.text(body, {
			Name = row[1] .. "Arrow",
			Text = "->",
			TextSize = 60,
			Position = UDim2.fromOffset(470, y + 10),
			Size = UDim2.fromOffset(150, 78),
		})
	end
	Popups.text(body, {
		Name = "CashNeeded",
		Text = "Cash Needed:",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(120, 400),
		Size = UDim2.fromOffset(300, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local set = Popups.bar(
		body,
		{ Name = "Progress", Position = UDim2.fromOffset(90, 440), Size = UDim2.fromOffset(470, 70) },
		"Cash",
		GREEN
	)
	local rebirths = Popups.text(body, {
		Name = "Rebirths",
		Text = "You have 0 rebirths",
		TextSize = 28,
		bold = true,
		Position = UDim2.fromOffset(700, 400),
		Size = UDim2.fromOffset(300, 36),
	})
	local remote = Ui.live and ReplicatedStorage:WaitForChild("Rebirth", 10)
	local busy = false
	Popups.button(
		body,
		{ Name = "RebirthButton", Position = UDim2.fromOffset(700, 440), Size = UDim2.fromOffset(300, 80) },
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
	if not Ui.live then
		return
	end
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
	buildShop()
	buildIndex()
	buildRebirth()
	if not Ui.live then
		return
	end
	blur = Instance.new("BlurEffect")
	blur.Name = "PopupBlur"
	blur.Size = 0
	blur.Parent = Lighting
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and open and not processed then
			Popups.close()
		end
	end)
end

return Popups
