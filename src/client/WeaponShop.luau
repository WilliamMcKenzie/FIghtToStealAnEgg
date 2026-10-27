-- The Weapon Shop (QM's NewUI Figma, Oct 27), opened by Talking to Carl the cactus vendor
-- (client/Vendor). An orange header with "Weapon Shop", two shine stripes across it (QM's
-- Pickaxe Shop ref: Figma couldn't do them, so they're made here) and the red X; under it a
-- dark panel with a row of cards, one per weapon: the starter first (Config.Arsenal.Start),
-- then everything Carl sells (Weapons.forSale), scrolling sideways when they don't fit.
-- Each card: the weapon's name, its rarity (in its rarity's colours), its render (Shared/
-- ItemIcons), its DPS at your Strength (Weapons.dps), and at the bottom
--   Equipped  it's the one you hold (your Weapon attribute)
--   Equip     you own it (your Weapons list): EquipWeapon
--   $Price    buy it with cash (BuyWeapon; buying equips it), beside the Robux price
--             (BuyWeaponRobux prompts its developer product: Config.Vendor.Products)
--
--   WeaponShop.init(root)   -- once, from Hud (root = its scaled frame)
--   WeaponShop.open() / WeaponShop.close() / WeaponShop.isOpen()
--
-- In Studio: StarterGui > Hud > Root > WeaponShop (tick its Visible to see it). Cards are
-- copies of Panel > Cards > CardTemplate, edit that one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Weapons = require(Shared.Weapons.Weapons)
local HudImages = require(script.Parent.HudImages)
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)

local WeaponShop = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button
local DPS_COLOR = "#00FFF6"
local NAME_STROKE = Color3.fromRGB(70, 70, 70)
local SHINE = { { at = 0.62, width = 0.07 }, { at = 0.72, width = 0.025 } } -- across the header, of its width
local SHINE_SLANT = 22 -- degrees the stripes lean
local SHINE_ALPHA = 0.7 -- their transparency
local POP = 0.12 -- seconds it takes to pop open
local FAIL_SHOW = 1.2 -- seconds a failed buy's message shows on the button

local gui -- the WeaponShop frame
local cards -- its scrolling row
local template

-- ---- building ---------------------------------------------------------------------------

-- a card (Figma: 729 x 991 Figma px), its content filled in by fill()
local function cardTemplate()
	local card = Instance.new("Frame")
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromOffset(fig(729), fig(991))
	local back = Instance.new("ImageLabel")
	back.Name = "Back"
	back.BackgroundTransparency = 1
	back.Image = HudImages.ShopCard
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = card
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Position = UDim2.fromOffset(0, fig(91))
	picture.Size = UDim2.fromOffset(fig(729), fig(729))
	picture.ZIndex = 2
	picture.Parent = card
	local name = label(card, "WeaponName", {
		Text = "Kendo Stick",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Position = UDim2.fromOffset(fig(24), fig(15)),
		Size = UDim2.fromOffset(fig(674), fig(120)),
		ZIndex = 3,
	})
	name.Outline.Color = NAME_STROKE
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = fig(120)
	limit.Parent = name
	local rarity = label(card, "Rarity", {
		Text = "Common",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(70),
		Position = UDim2.fromOffset(fig(24), fig(143)),
		Size = UDim2.fromOffset(fig(674), fig(85)),
		ZIndex = 3,
	})
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Parent = rarity
	-- the DPS bar
	local dps = art(card, "ShopDps", {
		Position = UDim2.fromOffset(fig(24 - 8), fig(631 - 8)),
		Size = UDim2.fromOffset(fig(690), fig(144)),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	})
	label(dps, "Dps", {
		RichText = true,
		Text = '<font color="' .. DPS_COLOR .. '">15</font> DPS',
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(95),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	-- the buttons: Equip (whole width) or the cash price and the Robux price
	local equip = button(card, "ShopEquip", 674, 160, { Position = UDim2.fromOffset(fig(24), fig(799)), ZIndex = 4 })
	label(equip, "Text", {
		Text = "Equip",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(80),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local buy = button(card, "ShopBuy", 413, 160, { Position = UDim2.fromOffset(fig(24), fig(799)), ZIndex = 4 })
	label(buy, "Text", {
		Text = "$800",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(80),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local robux = button(card, "ShopRobux", 213, 160, { Position = UDim2.fromOffset(fig(479), fig(799)), ZIndex = 4 })
	art(robux, "RobuxIcon", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, fig(12), 0.5, 0),
		Size = UDim2.fromOffset(fig(85), fig(93)),
		ZIndex = 5,
	})
	label(robux, "Text", {
		Text = "30",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, fig(110), 0.5, 0),
		Size = UDim2.fromOffset(fig(100), fig(98)),
		TextSize = fig(80),
		ZIndex = 5,
	})
	return card
end

local function build(root)
	local fresh
	gui, fresh = Ui.make(root, "WeaponShop", "Frame")
	if fresh then
		-- (Figma: 2268 x 1370, centred on the screen)
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(0.5, 0.5)
		gui.Position = UDim2.fromScale(0.5, 0.5)
		gui.Size = UDim2.fromOffset(fig(2268), fig(1370))
		gui.ZIndex = 10
		gui.Visible = not Ui.live -- (shown in Studio to edit; in Play when Carl's Talked to)
	end
	Ui.make(gui, "Pop", "UIScale")
	art(gui, "ShopPanel", {
		Position = UDim2.fromOffset(-fig(8), fig(283) - fig(8)),
		Size = UDim2.fromOffset(fig(2284), fig(1103)),
		ScaleType = Enum.ScaleType.Stretch,
	})
	local header = art(gui, "ShopHeader", {
		Position = UDim2.fromOffset(-fig(8), -fig(8)),
		Size = UDim2.fromOffset(fig(2284), fig(299)),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 2,
	})
	-- the shine: slanted white stripes, clipped to the header by a CanvasGroup (a rotated
	-- frame isn't clipped by ClipsDescendants)
	local shine
	shine, fresh = Ui.make(header, "Shine", "CanvasGroup")
	if fresh then
		shine.BackgroundTransparency = 1
		shine.Position = UDim2.fromOffset(fig(8) + 2, fig(8) + 2)
		shine.Size = UDim2.new(1, -fig(16) - 4, 1, -fig(16) - 4)
		shine.GroupTransparency = SHINE_ALPHA
		shine.ZIndex = 2
		for i, s in SHINE do
			local stripe = Instance.new("Frame")
			stripe.Name = "Stripe" .. i
			stripe.BackgroundColor3 = Color3.new(1, 1, 1)
			stripe.BorderSizePixel = 0
			stripe.AnchorPoint = Vector2.new(0.5, 0.5)
			stripe.Position = UDim2.fromScale(s.at, 0.5)
			stripe.Size = UDim2.new(s.width, 0, 2, 0)
			stripe.Rotation = SHINE_SLANT
			stripe.Parent = shine
		end
	end
	label(gui, "Title", {
		Text = "Weapon Shop",
		TextSize = fig(130),
		Position = UDim2.fromOffset(fig(70), fig(66)),
		Size = UDim2.fromOffset(fig(1100), fig(158)),
		ZIndex = 4,
	})
	-- (Figma: an 8px drop shadow under the title)
	label(gui, "TitleShadow", {
		Text = "Weapon Shop",
		TextSize = fig(130),
		TextColor3 = HudKit.BLACK,
		Position = UDim2.fromOffset(fig(70), fig(66 + 8)),
		Size = UDim2.fromOffset(fig(1100), fig(158)),
		ZIndex = 3,
	})
	local close = button(gui, "ShopClose", 174, 174, { Position = UDim2.fromOffset(fig(2046), fig(54)), ZIndex = 4 })
	label(close, "X", {
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})

	cards, fresh = Ui.make(gui, "Cards", "ScrollingFrame")
	if fresh then
		cards.BackgroundTransparency = 1
		cards.BorderSizePixel = 0
		cards.Position = UDim2.fromOffset(fig(46) - 4, fig(330) - 4)
		cards.Size = UDim2.fromOffset(fig(2268 - 92) + 8, fig(991) + 8 + 10)
		cards.CanvasSize = UDim2.new()
		cards.AutomaticCanvasSize = Enum.AutomaticSize.X
		cards.ScrollingDirection = Enum.ScrollingDirection.X
		cards.ScrollBarThickness = 6
		cards.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
		cards.ZIndex = 2
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = cards
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0, fig(44))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = cards
	end
	template = Ui.template(cards, "CardTemplate", cardTemplate)
	return close
end

-- ---- filling in -------------------------------------------------------------------------

local function owned()
	local list = {}
	for id in string.gmatch(player:GetAttribute("Weapons") or "", "[^,:%s]+") do
		list[id] = true
	end
	list[Config.Arsenal.Start] = true
	return list
end

local function fill(card, id)
	local w = Config.Weapons[id] or {}
	local rarity = Config.Rarities[w.Rarity] or Config.Rarities.Common
	card.WeaponName.Text = w.Name or id
	card.Rarity.Text = w.Rarity or "Common"
	card.Rarity.TextColor3 = Color3.new(1, 1, 1)
	card.Rarity.Outline.Color = rarity.Stroke
	-- (Figma's Common: white at the top to grey at the bottom; others in their colour)
	card.Rarity.UIGradient.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(rarity.Fill, 0.5), rarity.Fill:Lerp(Color3.new(0, 0, 0), 0.42))
	card.Picture.Image = ItemIcons.Weapons[id] or ""
end

local function refresh(card, id, mine)
	local dps = Weapons.dps(id, player:GetAttribute("Strength") or 0)
	card.ShopDps.Dps.Text = string.format('<font color="%s">%s</font> DPS', DPS_COLOR, tostring(math.round(dps)))
	local w = Config.Weapons[id] or {}
	local equipped = player:GetAttribute("Weapon") == id
	card.ShopEquip.Visible = mine[id] == true
	card.ShopEquip.Text.Text = if equipped then "Equipped" else "Equip"
	card.ShopBuy.Visible = not mine[id]
	card.ShopRobux.Visible = not mine[id] and Weapons.robux(id) ~= nil
	if not mine[id] then
		if not card.ShopBuy:GetAttribute("Failing") then
			card.ShopBuy.Text.Text = "$" .. tostring(w.Price or 0)
		end
		card.ShopRobux.Text.Text = tostring(Weapons.robux(id) or "")
		if not card.ShopRobux.Visible then
			-- (no Robux price: the cash one takes the whole width, on the Equip button's back)
			card.ShopBuy.Position, card.ShopBuy.Size = card.ShopEquip.Position, card.ShopEquip.Size
			card.ShopBuy.ShopBuy.Image = HudImages.ShopEquip
		end
	end
end

function WeaponShop.isOpen()
	return gui ~= nil and gui.Visible
end

function WeaponShop.open()
	if not gui then
		return
	end
	gui.Visible = true
	local pop = gui:FindFirstChild("Pop")
	if pop then
		pop.Scale = 0.85
		TweenService:Create(pop, TweenInfo.new(POP, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

function WeaponShop.close()
	if gui then
		gui.Visible = false
	end
end

function WeaponShop.init(root)
	local close = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	close.Activated:Connect(WeaponShop.close)
	-- (the template's buttons got hovers when it was made; they'd only show in Studio)

	local equipRemote = ReplicatedStorage:WaitForChild("EquipWeapon", 10)
	local buyRemote = ReplicatedStorage:WaitForChild("BuyWeapon", 10)
	local robuxRemote = ReplicatedStorage:WaitForChild("BuyWeaponRobux", 10)

	local list = { Config.Arsenal.Start }
	for _, id in Weapons.forSale() do
		if id ~= Config.Arsenal.Start then
			table.insert(list, id)
		end
	end
	local made = {} -- { { card, id } }
	for i, id in list do
		local card = Ui.copy(template, "Card" .. i, cards)
		card.LayoutOrder = i
		fill(card, id)
		for _, b in { card.ShopEquip, card.ShopBuy, card.ShopRobux } do
			HudKit.hover(b) -- (a copy doesn't keep the template's)
		end
		card.ShopEquip.Activated:Connect(function()
			if equipRemote and player:GetAttribute("Weapon") ~= id then
				equipRemote:FireServer(id)
			end
		end)
		card.ShopBuy.Activated:Connect(function()
			if not buyRemote or card.ShopBuy:GetAttribute("Failing") then
				return
			end
			local ok, why = buyRemote:InvokeServer(id)
			if not ok then
				-- (says why on the button for a moment)
				card.ShopBuy:SetAttribute("Failing", true)
				card.ShopBuy.Text.Text = if why == "not enough cash" then "Need cash!" else "Can't buy"
				task.delay(FAIL_SHOW, function()
					card.ShopBuy:SetAttribute("Failing", nil)
					card.ShopBuy.Text.Text = "$" .. tostring((Config.Weapons[id] or {}).Price or 0)
				end)
			end
		end)
		card.ShopRobux.Activated:Connect(function()
			if robuxRemote then
				robuxRemote:FireServer(id)
			end
		end)
		table.insert(made, { card, id })
	end

	local function refreshAll()
		local mine = owned()
		for _, m in made do
			refresh(m[1], m[2], mine)
		end
	end
	refreshAll()
	for _, name in { "Weapon", "Weapons", "Strength" } do
		player:GetAttributeChangedSignal(name):Connect(refreshAll)
	end

	-- Carl's Talk opens it (or closes it, if it's up)
	local Vendor = require(script.Parent.Vendor)
	Vendor.talked:Connect(function()
		if WeaponShop.isOpen() then
			WeaponShop.close()
		else
			WeaponShop.open()
		end
	end)
end

return WeaponShop
