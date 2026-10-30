-- The Shop (QM's Figma "Shop" frame, Oct 30), opened by the HUD's Shop button. It's the
-- Weapon Shop's popup (HudKit.popup) with a lime header, and under it one scrolling list:
--   ~Game Passes~  a wide card each, two to a row: its picture on a sunburst with its
--                  badge (x2, +1), its name, what it does, and its Robux price ("Owned"
--                  once it's yours) beside the gift button
--   ~Cash Packs~   five cards, three then two wider ones (QM's reference): a pile of cash
--                  on a sunburst (QM's arrangements of the cash icon), how much, the price
--   ~Power Packs~  six blue cards, three and three: a pile of swords, how much Power
-- Everything sold is Config.Shop (its prices, piles and ids); buying goes to Server/Store
-- (ShopBuy). The pink gift button asks who it's for (the Gift To popup: everyone else in
-- the server) and buys it for them.
--
--   Shop.init(root, shopButton)   -- once, from Hud (root = its scaled frame)
--   Shop.open() / Shop.close() / Shop.toggle() / Shop.isOpen()
--
-- In Studio: StarterGui > Hud > Root > Shop (tick its Visible to see it). Every card is a
-- real object (List > Passes / Cash / Power > Row1.. > Cash1..), edit them there; a pile's
-- pictures are the card's Icons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Abbrev = require(Shared.Abbrev)
local HudImages = require(script.Parent.HudImages)
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local Shop = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button
local SHOP = Config.Shop

-- Figma px
local WIDTH = 2177 -- the list's width: three cards and two gaps
local GAP = 22 -- between cards
local CARD = { 711, 635 } -- a card (QM's Figma)
local WIDE = (WIDTH - GAP) / 2 -- a card two to a row
local EDGE = 47 -- the buttons' inset from the card's sides
local BUTTONS_Y = 443 -- their top
local GIFT_W = 213
local BURST = 620 -- the sunburst behind a pile
local PILE_Y = 229 -- the middle of a pile, from the card's top
local ICON_OUTLINE = 3 -- px of black round the Robux icon (as the Weapon Shop's)
local NUMBER = "#7CFF4D" -- a Power pack's number
local PICTURES = { -- a pile's pictures (Config.Shop's Icons) by name
	Stack = "CashStack",
	StackFlip = "CashStackFlip",
	Bills = "CashBills",
	Sword = "ShopSword",
	SwordFlip = "ShopSwordFlip",
}
-- the sections, in order: their title's gradient, their cards' look and the rows
local SECTIONS = {
	{
		key = "Passes",
		title = "~Game Passes~",
		colours = { "ffd000", "ffe700", "ffae00" },
		rows = { { 1, 2 }, { 3, 4 } },
	},
	{
		key = "Cash",
		title = "~Cash Packs~",
		colours = { "61ff00", "b9ff00", "57ff00" },
		look = "CashCard",
		rows = { { 1, 2, 3 }, { 4, 5 } },
	},
	{
		key = "Power",
		title = "~Power Packs~",
		colours = { "00c8ff", "00e5ff", "0096ff" },
		look = "PowerCard",
		rows = { { 1, 2, 3 }, { 4, 5, 6 } },
	},
}
local PASS_LOOKS = { Life = "LifeCard", Damage = "DamageCard", Gold = "GoldCard", Growth = "GrowthCard" }

local gui, picker
local made = {} -- { { card, kind, index } }

-- ---- building ---------------------------------------------------------------------------

local function gradient(parent, colours)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex(colours[1])),
		ColorSequenceKeypoint.new(0.495, Color3.fromHex(colours[2])),
		ColorSequenceKeypoint.new(1, Color3.fromHex(colours[3])),
	})
	g.Parent = parent
end

-- a section's title: gradient text over its 8px drop shadow (QM's "~Cash Packs~")
local function heading(list, section, order)
	local frame, fresh = Ui.make(list, section.key .. "Heading", "Frame")
	if fresh then
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.fromOffset(fig(WIDTH), fig(150))
		frame.LayoutOrder = order
	end
	label(frame, "Shadow", {
		Text = section.title,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		TextColor3 = HudKit.BLACK,
		Position = UDim2.fromOffset(0, fig(8)),
		Size = UDim2.fromScale(1, 1),
	})
	local had = frame:FindFirstChild("Title")
	local title = label(frame, "Title", {
		Text = section.title,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	})
	if not had then
		gradient(title, section.colours)
	end
end

-- the inset white glow every card has (Figma: 16px, half see-through)
local function glow(back)
	local g, fresh = Ui.make(back, "Glow", "Frame")
	if fresh then
		g.BackgroundTransparency = 1
		g.Position = UDim2.fromOffset(fig(5 + 16), fig(5 + 16))
		g.Size = UDim2.new(1, -2 * fig(5 + 16), 1, -2 * fig(5 + 16))
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.5
		stroke.Thickness = fig(16)
		stroke.Parent = g
	end
end

-- the sunburst behind a picture, centred at x, y (Figma px; x from the card's middle),
-- clipped to the card
local function sunburst(card, x, y, size)
	local clip, fresh = Ui.make(card, "Burst", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromOffset(fig(5), fig(5))
		clip.Size = UDim2.new(1, -fig(10), 1, -fig(10))
		clip.ZIndex = 2
	end
	art(clip, "Sunburst", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, fig(x), 0, fig(y - 5)),
		Size = UDim2.fromOffset(fig(size), fig(size)),
		ImageTransparency = 0.15,
		ZIndex = 2,
	})
end

-- the Robux price button (green) and the gift button (pink) along the card's bottom
local function buttons(card)
	local buy = button(card, "Buy", 366, 160, {
		Position = UDim2.fromOffset(fig(EDGE), fig(BUTTONS_Y)),
		Size = UDim2.new(1, -fig(2 * EDGE + 40 + GIFT_W), 0, fig(160)),
		ZIndex = 5,
	}, "GreenEdged")
	local price, fresh = Ui.make(buy, "Price", "Frame")
	if fresh then
		price.BackgroundTransparency = 1
		price.AnchorPoint = Vector2.new(0.5, 0.5)
		price.Position = UDim2.fromScale(0.5, 0.5)
		price.Size = UDim2.fromOffset(0, fig(98))
		price.AutomaticSize = Enum.AutomaticSize.X
		price.ZIndex = 6
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, fig(13))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = price
	end
	local holder
	holder, fresh = Ui.make(price, "Robux", "Frame")
	if fresh then
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(fig(85), fig(93))
		holder.LayoutOrder = 1
		holder.ZIndex = 6
	end
	local icon = art(holder, "RobuxIcon", { Size = UDim2.fromScale(1, 1), ZIndex = 7 })
	HudKit.outlineArt(icon, ICON_OUTLINE)
	label(price, "Text", {
		Text = "99",
		TextSize = fig(80),
		Size = UDim2.fromOffset(0, fig(98)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = 7,
	})
	local gift = button(card, "Gift", GIFT_W, 160, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -fig(EDGE), 0, fig(BUTTONS_Y)),
		ZIndex = 5,
	}, "PinkEdged")
	local giftIcon = art(gift, "GiftIcon", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(fig(85), fig(93)),
		ZIndex = 6,
	})
	HudKit.outlineArt(giftIcon, ICON_OUTLINE)
end

local function card(row, name, look, width, order)
	local c, fresh = Ui.make(row, name, "Frame")
	if fresh then
		c.BackgroundTransparency = 1
		c.Size = UDim2.fromOffset(fig(width), fig(CARD[2]))
		c.LayoutOrder = order
	end
	glow(HudKit.back(c, look, {}))
	return c, fresh
end

-- a Cash or Power pack: its pile, its amount, its buttons
local function pack(row, kind, index, look, width, order)
	local item = SHOP[kind][index]
	local c, fresh = card(row, kind .. index, look, width, order)
	sunburst(c, 0, PILE_Y, BURST)
	local icons
	icons, fresh = Ui.make(c, "Icons", "Frame")
	if fresh then
		icons.BackgroundTransparency = 1
		icons.AnchorPoint = Vector2.new(0.5, 0)
		icons.Position = UDim2.fromScale(0.5, 0)
		icons.Size = UDim2.fromOffset(0, 0) -- (the pictures are placed from its point)
		icons.ZIndex = 3
		for i, p in item.Icons do
			local picture = Instance.new("ImageLabel")
			picture.Name = "Icon" .. i
			picture.BackgroundTransparency = 1
			picture.Image = HudImages[PICTURES[p[1]] or p[1]] or ""
			picture.ScaleType = Enum.ScaleType.Fit
			picture.AnchorPoint = Vector2.new(0.5, 0.5)
			picture.Position = UDim2.fromOffset(fig(p[2]), fig(p[3]))
			picture.Size = UDim2.fromOffset(fig(p[4]), fig(p[4]))
			picture.ZIndex = 3 + i
			picture.Parent = icons
		end
	end
	local had = c:FindFirstChild("Amount")
	local amount = label(c, "Amount", {
		RichText = true,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(75),
		Position = UDim2.fromOffset(0, fig(285)),
		Size = UDim2.new(1, 0, 0, fig(91)),
		ZIndex = 20,
	})
	if not had then
		amount.Text = if kind == "Cash"
			then "$" .. Abbrev(item.Amount)
			else string.format('<font color="%s">+%s</font> Power', NUMBER, Abbrev(item.Amount))
	end
	buttons(c)
	return c
end

-- a Game Pass: its picture and badge on the left, its name and what it does on the right
local function pass(row, index, order)
	local item = SHOP.Passes[index]
	local c = card(row, "Pass" .. index, PASS_LOOKS[item.Look] or "GoldCard", WIDE, order)
	local x, y = 255 - WIDE / 2, 215 -- (the picture's middle: x from the card's)
	sunburst(c, x, y, 560)
	art(c, "Picture", {
		Image = HudImages[item.Icon] or "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, fig(x), 0, fig(y)),
		Size = UDim2.fromOffset(fig(330), fig(330)),
		ZIndex = 3,
	})
	local had = c:FindFirstChild("Badge")
	local badge = label(c, "Badge", {
		Text = item.Badge or "",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, fig(x + 120), 0, fig(y + 120)),
		Size = UDim2.fromOffset(fig(260), fig(140)),
		Rotation = -10,
		ZIndex = 4,
	})
	if not had then
		gradient(badge, { "ffe700", "ffd000", "ff9d00" })
	end
	label(c, "PassName", {
		Text = item.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(100),
		Position = UDim2.fromOffset(fig(480), fig(40)),
		Size = UDim2.new(1, -fig(520), 0, fig(120)),
		ZIndex = 4,
	})
	label(c, "Description", {
		RichText = true,
		Text = item.Text,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextSize = fig(68),
		Position = UDim2.fromOffset(fig(480), fig(170)),
		Size = UDim2.new(1, -fig(520), 0, fig(220)),
		ZIndex = 4,
	})
	buttons(c)
	return c
end

-- the Gift To popup: a button for everyone else in the server
local function giftPicker()
	local p, fresh = Ui.make(gui, "GiftPicker", "Frame")
	if fresh then
		p.BackgroundTransparency = 1
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromScale(0.5, 0.55)
		p.Size = UDim2.fromOffset(fig(1100), fig(950))
		p.ZIndex = 30
		p.Visible = false
	end
	HudKit.back(p, "Panel", { Name = "Panel" })
	label(p, "Title", {
		Text = "Gift to...",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(100),
		Position = UDim2.fromOffset(0, fig(30)),
		Size = UDim2.new(1, 0, 0, fig(130)),
		ZIndex = 2,
	})
	local cancel = button(p, "GiftCancel", 140, 140, { Position = UDim2.new(1, -fig(170), 0, fig(30)), ZIndex = 3 }, "Red")
	label(cancel, "X", {
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(95),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	local people
	people, fresh = Ui.make(p, "People", "ScrollingFrame")
	if fresh then
		people.BackgroundTransparency = 1
		people.BorderSizePixel = 0
		people.Position = UDim2.fromOffset(fig(60), fig(200))
		people.Size = UDim2.new(1, -fig(120), 1, -fig(250))
		people.CanvasSize = UDim2.new()
		people.AutomaticCanvasSize = Enum.AutomaticSize.Y
		people.ScrollingDirection = Enum.ScrollingDirection.Y
		people.ScrollBarThickness = 6
		people.ZIndex = 2
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, fig(30))
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = people
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, fig(12)), UDim.new(0, fig(12))
		pad.Parent = people
	end
	label(people, "Nobody", {
		Text = "Nobody else is here!",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(70),
		Size = UDim2.new(1, 0, 0, fig(120)),
		Visible = false,
		ZIndex = 3,
	})
	Ui.template(people, "PersonTemplate", function()
		local b = Instance.new("ImageButton")
		b.BackgroundTransparency = 1
		b.Image = ""
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(fig(860), fig(150))
		b.ZIndex = 3
		HudKit.back(b, "GreenEdged", {})
		local grow = Instance.new("UIScale")
		grow.Name = "Hover"
		grow.Parent = b
		label(b, "Text", {
			Text = "Player",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = fig(75),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
		return b
	end)
	return p, cancel
end

local function build(root)
	local close
	gui, close = HudKit.popup(root, "Shop", "Shop", "LimeHeader")
	local list, fresh = Ui.make(gui, "List", "ScrollingFrame")
	if fresh then
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromOffset(fig(45), fig(290))
		list.Size = UDim2.fromOffset(fig(2268 - 90) + 4, fig(1370 - 290 - 30))
		list.CanvasSize = UDim2.new()
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.ScrollingDirection = Enum.ScrollingDirection.Y
		list.ScrollBarThickness = 6
		list.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
		list.ZIndex = 2
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, fig(GAP))
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = list
		local pad = Instance.new("UIPadding")
		pad.PaddingBottom = UDim.new(0, fig(40))
		pad.Parent = list
	end
	for s, section in SECTIONS do
		heading(list, section, s * 10)
		local holder
		holder, fresh = Ui.make(list, section.key, "Frame")
		if fresh then
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(fig(WIDTH), 0)
			holder.AutomaticSize = Enum.AutomaticSize.Y
			holder.LayoutOrder = s * 10 + 1
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, fig(GAP))
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = holder
		end
		for r, indices in section.rows do
			local row
			row, fresh = Ui.make(holder, "Row" .. r, "Frame")
			if fresh then
				row.BackgroundTransparency = 1
				row.Size = UDim2.fromOffset(fig(WIDTH), fig(CARD[2]))
				row.LayoutOrder = r
				local layout = Instance.new("UIListLayout")
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, fig(GAP))
				layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = row
			end
			local width = if #indices == 3 then CARD[1] else WIDE
			for k, index in indices do
				local c = if section.key == "Passes"
					then pass(row, index, k)
					else pack(row, section.key, index, section.look, width, k)
				table.insert(made, { c, section.key, index })
			end
		end
	end
	local cancel
	picker, cancel = giftPicker()
	return close, cancel
end

-- ---- using it ---------------------------------------------------------------------------

function Shop.isOpen()
	return gui ~= nil and UiFx.isOpen(gui)
end

-- (pops in and out with its sounds: client/UiFx)
function Shop.open()
	if gui then
		UiFx.popIn(gui)
	end
end

function Shop.close()
	if gui then
		picker.Visible = false
		UiFx.popOut(gui)
	end
end

function Shop.toggle()
	if Shop.isOpen() then
		Shop.close()
	else
		Shop.open()
	end
end

function Shop.init(root, shopButton)
	local close, cancel = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	picker.Visible = false
	local remote = ReplicatedStorage:WaitForChild("ShopBuy", 10)
	close.Activated:Connect(Shop.close)
	if shopButton then
		shopButton.Activated:Connect(Shop.toggle)
	end

	-- the Gift To popup: who's here, and buying it for the one picked
	local people = picker.People
	local template = people.PersonTemplate
	local function pickFor(kind, index)
		for _, child in people:GetChildren() do
			if child:IsA("ImageButton") and child ~= template then
				child:Destroy()
			end
		end
		local others = 0
		for _, other in Players:GetPlayers() do
			if other ~= player then
				others += 1
				local b = Ui.copy(template, "Person" .. other.UserId, people)
				b.LayoutOrder = others
				b.Text.Text = other.DisplayName
				HudKit.hover(b)
				b.Activated:Connect(function()
					picker.Visible = false
					if remote then
						remote:FireServer(kind, index, other.UserId)
					end
				end)
			end
		end
		people.Nobody.Visible = others == 0
		UiFx.popIn(picker)
	end
	cancel.Activated:Connect(function()
		UiFx.popOut(picker)
	end)

	for _, m in made do
		local c, kind, index = m[1], m[2], m[3]
		for _, b in { c.Buy, c.Gift } do
			HudKit.hover(b)
		end
		c.Buy.Activated:Connect(function()
			if remote and not (kind == "Passes" and player:GetAttribute("Pass" .. SHOP.Passes[index].Name)) then
				remote:FireServer(kind, index)
			end
		end)
		c.Gift.Activated:Connect(function()
			pickFor(kind, index)
		end)
	end

	-- the prices, and "Owned" on the passes you have
	local function refresh()
		for _, m in made do
			local c, kind, index = m[1], m[2], m[3]
			local item = SHOP[kind][index]
			local owned = kind == "Passes" and player:GetAttribute("Pass" .. item.Name) == true
			local price = c.Buy.Price
			price.Robux.Visible = not owned
			price.Text.Text = if owned then "Owned" else tostring(item.Robux)
		end
	end
	refresh()
	for _, item in SHOP.Passes do
		player:GetAttributeChangedSignal("Pass" .. item.Name):Connect(function()
			refresh()
			if player:GetAttribute("Pass" .. item.Name) and Shop.isOpen() then
				UiFx.play("Claim") -- (it's yours)
			end
		end)
	end
end

return Shop
