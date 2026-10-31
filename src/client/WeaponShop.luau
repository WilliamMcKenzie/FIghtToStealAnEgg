-- The Weapon Shop (QM's NewUI Figma, Oct 27), opened by Talking to Carl the cactus vendor
-- (client/Vendor). An orange header with "Weapon Shop", two shine stripes across it and the
-- red X (HudKit.popup: the Shop popup is the same one, in lime); under it a dark panel with a row of cards, one per weapon: the starter first (Config.Arsenal.Start),
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
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Weapons = require(Shared.Weapons.Weapons)
local Abbrev = require(Shared.Abbrev)
local RarityLook = require(Shared.RarityLook)
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local WeaponShop = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button -- (backs: HudKit.back)
local DPS_COLOR = "#00FFF6"
local NAME_STROKE = Color3.fromRGB(70, 70, 70)
-- each rarity's card (QM's Figma, Oct 27): its back's gradient and its rarity's text
-- colours are Config.Rarities'. From Mythic up they move: the back's gradient turns round
-- with a light sheen sweeping across it (QM, Oct 27: the backs should visibly move), and
-- a band sweeps across the rarity (Shared/RarityLook, as everywhere rarities show).
local RARITY = Config.Rarities
local SPIN = 45 -- degrees a second a moving card's back turns
local SHEEN = 0.45 -- transparency at the middle of the sheen's band
local ICON_OUTLINE = 3 -- px of black round the Robux icon (QM, Oct 27: like its text's)
local FAIL_SHOW = 1.2 -- seconds a failed buy's message shows on the button

local gui -- the WeaponShop frame
local cards -- its scrolling row
local template
local moving = {} -- { { back's Fill, sheen's UIGradient } } of the moving cards

-- ---- building ---------------------------------------------------------------------------

-- a price in cash, short: $500, $50K, $1.5M (as the Cash counter)
local function price(n)
	return "$" .. Abbrev(n or 0)
end

-- the Robux button's icon outlined black like the text beside it (HudKit.outlineArt)
local function outlineRobux(robux)
	local icon = robux:FindFirstChild("RobuxIcon")
	if icon then
		HudKit.outlineArt(icon, ICON_OUTLINE)
	end
end

-- a card (Figma: 729 x 991 Figma px), its content filled in by fill()
local function cardTemplate()
	local card = Instance.new("Frame")
	card.BackgroundTransparency = 1
	card.Size = UDim2.fromOffset(fig(729), fig(991))
	local back = HudKit.back(card, "Card", {})
	-- (Figma: an inset white glow, 16px, on every rarity but Common)
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Position = UDim2.fromOffset(fig(5 + 16), fig(5 + 16))
	glow.Size = UDim2.new(1, -2 * fig(5 + 16), 1, -2 * fig(5 + 16))
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = Color3.new(1, 1, 1)
	glowStroke.Transparency = 0.5
	glowStroke.Thickness = fig(16)
	glowStroke.Parent = glow
	glow.Parent = back
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	-- (QM's new cards, Oct 27: every weapon fits a 512 square, so none spills off the card)
	picture.Position = UDim2.fromOffset(fig(109), fig(237))
	picture.Size = UDim2.fromOffset(fig(512), fig(512))
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
	local dps = HudKit.back(card, "Dark", {
		Name = "ShopDps",
		Position = UDim2.fromOffset(fig(24), fig(631)),
		Size = UDim2.fromOffset(fig(674), fig(128)),
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
	local equip = button(card, "ShopEquip", 674, 160, { Position = UDim2.fromOffset(fig(24), fig(799)), ZIndex = 4 }, "GreenEdged")
	label(equip, "Text", {
		Text = "Equip",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(80),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local buy = button(card, "ShopBuy", 413, 160, { Position = UDim2.fromOffset(fig(24), fig(799)), ZIndex = 4 }, "GreenEdged")
	label(buy, "Text", {
		Text = "$800",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(80),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local robux = button(card, "ShopRobux", 213, 160, { Position = UDim2.fromOffset(fig(479), fig(799)), ZIndex = 4 }, "PinkEdged")
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
	outlineRobux(robux)
	return card
end

local function build(root)
	local fresh
	local close
	gui, close = HudKit.popup(root, "WeaponShop", "Weapon Shop", "Header")

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
	local look = RARITY[w.Rarity] or RARITY.Common
	card.WeaponName.Text = w.Name or id
	RarityLook.paint(card.Rarity, w.Rarity or "Common", card.Rarity.Outline)
	local back = card:FindFirstChild("Back")
	if look.top then
		-- (Figma: bottom colour up to the top one, which it reaches `at` of the way up)
		if back then
			back.Fill.Color = if look.at < 1
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, look.top),
					ColorSequenceKeypoint.new(1 - look.at, look.top),
					ColorSequenceKeypoint.new(1, look.bottom),
				})
				else ColorSequence.new(look.top, look.bottom)
			back.Fill.Rotation = 90
			if look.move then
				-- the sheen: a white band, slanted, made here (only moving cards have one)
				local sheen = Instance.new("Frame")
				sheen.Name = "Sheen"
				sheen.BackgroundColor3 = Color3.new(1, 1, 1)
				sheen.BorderSizePixel = 0
				sheen.Size = UDim2.fromScale(1, 1)
				local corner = back:FindFirstChildOfClass("UICorner")
				if corner then
					corner:Clone().Parent = sheen
				end
				local band = Instance.new("UIGradient")
				band.Rotation = 60
				band.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.4, 1),
					NumberSequenceKeypoint.new(0.5, SHEEN),
					NumberSequenceKeypoint.new(0.6, 1),
					NumberSequenceKeypoint.new(1, 1),
				})
				band.Offset = Vector2.new(-1.5, 0)
				band.Parent = sheen
				sheen.Parent = back
				table.insert(moving, { back.Fill, band })
			end
		end
	end
	if back and back:FindFirstChild("Glow") then
		back.Glow.Visible = look.top ~= nil
	end
	card.Picture.Image = ItemIcons.Weapons[id] or ""
end

local function refresh(card, id, mine)
	local dps = Weapons.dps(id, player:GetAttribute("Strength") or 0)
	card.ShopDps.Dps.Text = string.format('<font color="%s">%s</font> DPS', DPS_COLOR, Abbrev(math.round(dps)))
	local w = Config.Weapons[id] or {}
	local equipped = player:GetAttribute("Weapon") == id
	card.ShopEquip.Visible = mine[id] == true
	card.ShopEquip.Text.Text = if equipped then "Equipped" else "Equip"
	card.ShopBuy.Visible = not mine[id]
	card.ShopRobux.Visible = not mine[id] and Weapons.robux(id) ~= nil
	if not mine[id] then
		if not card.ShopBuy:GetAttribute("Failing") then
			card.ShopBuy.Text.Text = price(w.Price)
		end
		card.ShopRobux.Text.Text = if Weapons.robux(id) then Abbrev(Weapons.robux(id)) else ""
		if not card.ShopRobux.Visible then
			-- (no Robux price: the cash one takes the whole width, on the Equip button's back)
			card.ShopBuy.Position, card.ShopBuy.Size = card.ShopEquip.Position, card.ShopEquip.Size
		end
	end
end

function WeaponShop.isOpen()
	return gui ~= nil and UiFx.isOpen(gui)
end

-- (pops in and out with its sounds: client/UiFx)
function WeaponShop.open()
	if gui then
		UiFx.popIn(gui)
	end
end

function WeaponShop.close()
	if gui then
		UiFx.popOut(gui)
	end
end

function WeaponShop.init(root)
	local close = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	UiFx.menu(gui) -- (one menu at a time: client/UiFx)
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
		outlineRobux(card.ShopRobux) -- (a template baked before it had one)
		for _, b in { card.ShopEquip, card.ShopBuy, card.ShopRobux } do
			HudKit.hover(b) -- (a copy doesn't keep the template's)
		end
		card.ShopEquip.Activated:Connect(function()
			if equipRemote and player:GetAttribute("Weapon") ~= id then
				UiFx.play("Equip")
				equipRemote:FireServer(id)
			end
		end)
		card.ShopBuy.Activated:Connect(function()
			if not buyRemote or card.ShopBuy:GetAttribute("Failing") then
				return
			end
			local ok, why = buyRemote:InvokeServer(id)
			if ok then
				UiFx.play("Buy")
			else
				-- (says why on the button for a moment, with a shake)
				UiFx.shake(card.ShopBuy)
				card.ShopBuy:SetAttribute("Failing", true)
				card.ShopBuy.Text.Text = if why == "not enough cash" then "Need cash!" else "Can't buy"
				task.delay(FAIL_SHOW, function()
					card.ShopBuy:SetAttribute("Failing", nil)
					card.ShopBuy.Text.Text = price((Config.Weapons[id] or {}).Price)
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

	-- the moving cards, while the shop's open: each back's gradient turns (from its light
	-- top) and its sheen sweeps across in step with the band on its rarity (RarityLook)
	RunService.RenderStepped:Connect(function()
		if not gui.Visible or #moving == 0 then
			return
		end
		local t = os.clock()
		local turn = (90 + t * SPIN) % 360
		local sweep = RarityLook.sweep()
		for _, m in moving do
			m[1].Rotation = turn
			m[2].Offset = Vector2.new(sweep * 1.5, 0) -- (further: its band is slanted)
		end
	end)

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
