-- The Offline Cash popup (QM, Oct 31): what your pen earned while you were away (Server/Data's
-- saved OfflineCash attribute) pops up a moment after you join. A lime header with its shine
-- and "Offline Cash", then "You earned:" over the amount on a cash stack, a sunburst slowly
-- turning behind it, and two buttons: green Claim pays it, the pink Robux one (with its "2x"
-- badge) pays twice it (Config.Data.OfflineDoubleProduct; in Studio, till it has an id, it's
-- free). There's no X: unclaimed, it waits for next time (and adds up). Claimed, the popup
-- pops out and the "+$X" flies into the Cash counter (client/BossBounty.fly).
--
-- Built like the other popups (client/HudKit's looks, laid out in QM's Figma px through
-- HudKit.fig), so it's a real object in StarterGui > Hud > Root > OfflineCash for QM to edit
-- in Studio (client/Ui); in Play this only fills in what's missing and wires it up.
--
--   OfflineCash.init(root)  -- client/Hud, in Play and in Edit (tools/studio/uibake.luau)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abbrev = require(Shared:WaitForChild("Abbrev"))
local Config = require(Shared:WaitForChild("Config"))
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local OfflineCash = {}

local fig = HudKit.fig
local label = HudKit.label
local W, H = 1500, 1120 -- the whole popup (Figma px)
local HEADER = 230 -- the header's height; the panel is tucked under its bottom edge
local BUTTON_W, BUTTON_H, BUTTON_Y = 650, 230, 830 -- Claim's and the 2x's size, and top
local STACK = 560 -- the cash stack's size
local BURST = 1000 -- the sunburst behind it
local PILE_Y = 610 -- the middle of the stack, the burst and the amount
local SPIN = 12 -- degrees a second the sunburst turns
local ICON_OUTLINE = 3 -- px of black round the Robux icon (as the Shop's)
local GREEN_TOP = Color3.fromHex("d8ff3a") -- the amount: lit lime at the top...
local GREEN_BOTTOM = Color3.fromHex("1fd31f") -- ...to a deeper green at the bottom
local PINK_TOP = Color3.fromHex("ff6bf6") -- the "2x" badge, the same way
local PINK_BOTTOM = Color3.fromHex("b100ff")

local player = Players.LocalPlayer

local function gradient(parent, top, bottom)
	local g, fresh = Ui.make(parent, "Shade", "UIGradient")
	if fresh then
		g.Rotation = 90
		g.Color = ColorSequence.new(top, bottom)
	end
	return g
end

local function build(root)
	local gui, fresh = Ui.make(root, "OfflineCash", "Frame")
	if fresh then
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(0.5, 0.5)
		gui.Position = UDim2.fromScale(0.5, 0.5)
		gui.Size = UDim2.fromOffset(fig(W), fig(H))
		gui.ZIndex = 12
		gui.Visible = not Ui.live -- (shown in Studio to edit; in Play when there's cash to claim)
	end
	Ui.make(gui, "Pop", "UIScale")

	-- the dark studded panel, and the lime header over its top
	HudKit.back(gui, "Panel", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, fig(HEADER - 20)),
		Size = UDim2.fromOffset(fig(W), fig(H - HEADER + 20)),
	})
	local header = HudKit.back(gui, "LimeHeader", {
		Name = "Header",
		Size = UDim2.fromOffset(fig(W), fig(HEADER)),
		ZIndex = 2,
	})
	local shine
	shine, fresh = Ui.make(header, "Shine", "CanvasGroup")
	if fresh then
		shine.BackgroundTransparency = 1
		shine.Size = UDim2.fromScale(1, 1)
		shine.GroupTransparency = 0.7
		shine.ZIndex = 2
		for i, st in { { 0.6, 0.08 }, { 0.71, 0.03 } } do
			local stripe = Instance.new("Frame")
			stripe.Name = "Stripe" .. i
			stripe.BackgroundColor3 = Color3.new(1, 1, 1)
			stripe.BorderSizePixel = 0
			stripe.AnchorPoint = Vector2.new(0.5, 0.5)
			stripe.Position = UDim2.fromScale(st[1], 0.5)
			stripe.Size = UDim2.new(st[2], 0, 2, 0)
			stripe.Rotation = 22
			stripe.Parent = shine
		end
	end
	for _, t in { { "TitleShadow", 8, HudKit.BLACK, 3 }, { "Title", 0, Color3.new(1, 1, 1), 4 } } do
		label(gui, t[1], {
			Text = "Offline Cash",
			TextSize = fig(120),
			TextColor3 = t[3],
			Position = UDim2.fromOffset(fig(60), fig(40 + t[2])),
			Size = UDim2.fromOffset(fig(1100), fig(150)),
			ZIndex = t[4],
		})
	end

	-- "You earned:", the burst, the stack, the amount
	label(gui, "Earned", {
		Text = "You earned:",
		FontFace = HudKit.ITALIC,
		TextSize = fig(110),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(W / 2), fig(HEADER + 110)),
		Size = UDim2.fromOffset(fig(1200), fig(140)),
		ZIndex = 6,
	})
	local clip
	clip, fresh = Ui.make(gui, "Burst", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromOffset(fig(8), fig(HEADER))
		clip.Size = UDim2.fromOffset(fig(W - 16), fig(H - HEADER - 8))
		clip.ZIndex = 2
	end
	HudKit.art(clip, "Sunburst", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(W / 2 - 8), fig(PILE_Y - HEADER)),
		Size = UDim2.fromOffset(fig(BURST), fig(BURST)),
		ImageColor3 = Color3.fromHex("b8ff6a"),
		ImageTransparency = 0.55,
		ZIndex = 2,
	})
	HudKit.art(gui, "CashStack", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(W / 2), fig(PILE_Y + 20)),
		Size = UDim2.fromOffset(fig(STACK), fig(STACK)),
		ZIndex = 4,
	})
	local amount = label(gui, "Amount", {
		Text = "$450K",
		TextSize = fig(210),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(W / 2), fig(PILE_Y + 10)),
		Size = UDim2.fromOffset(fig(1300), fig(250)),
		ZIndex = 6,
	})
	if not amount:GetAttribute("Thick") then -- (once: an outline QM changed in Studio stays)
		amount:SetAttribute("Thick", true)
		amount.Outline.Thickness = fig(16)
	end
	gradient(amount, GREEN_TOP, GREEN_BOTTOM)

	-- Claim, and the Robux 2x
	local claim = HudKit.button(gui, "Claim", BUTTON_W, BUTTON_H, {
		Position = UDim2.fromOffset(fig(60), fig(BUTTON_Y)),
		ZIndex = 6,
	}, "GreenEdged")
	label(claim, "Text", {
		Text = "Claim",
		TextSize = fig(130),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
	})
	local double = HudKit.button(gui, "Double", BUTTON_W, BUTTON_H, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(fig(W - 60), fig(BUTTON_Y)),
		ZIndex = 6,
	}, "PinkEdged")
	local price
	price, fresh = Ui.make(double, "Price", "Frame")
	if fresh then
		price.BackgroundTransparency = 1
		price.AnchorPoint = Vector2.new(0.5, 0.5)
		price.Position = UDim2.fromScale(0.5, 0.5)
		price.Size = UDim2.fromOffset(0, fig(130))
		price.AutomaticSize = Enum.AutomaticSize.X
		price.ZIndex = 7
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, fig(18))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = price
	end
	local holder
	holder, fresh = Ui.make(price, "Robux", "Frame")
	if fresh then
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(fig(110), fig(120))
		holder.LayoutOrder = 1
		holder.ZIndex = 7
	end
	local icon = HudKit.art(holder, "RobuxIcon", { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	HudKit.outlineArt(icon, ICON_OUTLINE)
	label(price, "Text", {
		Text = tostring(Config.Data.OfflineDoubleRobux),
		TextSize = fig(120),
		Size = UDim2.fromOffset(0, fig(130)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		ZIndex = 8,
	})
	-- (the "2x" badge leans over the button's top right corner, outside it, so it doesn't grow
	-- with the hover)
	local badge = label(gui, "TwoX", {
		Text = "2x",
		FontFace = HudKit.ITALIC,
		TextSize = fig(130),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(W - 110), fig(BUTTON_Y - 10)),
		Size = UDim2.fromOffset(fig(220), fig(150)),
		Rotation = -14,
		ZIndex = 9,
	})
	gradient(badge, PINK_TOP, PINK_BOTTOM)
	return gui, amount, claim, double, price.Text, clip.Sunburst
end

local function wire(gui, amount, claim, double, priceText, burst)
	local remote = ReplicatedStorage:WaitForChild("OfflineClaim", 10)
	local product = Config.Data.OfflineDoubleProduct
	local buying = false -- (the 2x's purchase prompt is up: Claim waits)
	local spinning

	-- the 2x's price: the product's own, once it has one
	if product then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				priceText.Text = tostring(info.PriceInRobux)
			end
		end)
	end

	local function close()
		if spinning then
			spinning:Disconnect()
			spinning = nil
		end
		UiFx.popOut(gui, false)
	end

	local function open()
		local waiting = player:GetAttribute("OfflineCash") or 0
		if waiting <= 0 or UiFx.isOpen(gui) then
			return
		end
		amount.Text = "$" .. Abbrev(waiting)
		UiFx.popIn(gui)
		if not spinning then
			spinning = RunService.RenderStepped:Connect(function(dt)
				burst.Rotation = (burst.Rotation + SPIN * dt) % 360
			end)
		end
	end

	claim.Activated:Connect(function()
		if buying or not remote then
			UiFx.shake(claim)
			return
		end
		remote:FireServer("Claim")
	end)
	double.Activated:Connect(function()
		if product then
			buying = true
			MarketplaceService:PromptProductPurchase(player, product)
		elseif remote and RunService:IsStudio() then
			remote:FireServer("Double")
		else
			UiFx.shake(double)
		end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id)
		if userId == player.UserId and id == product then
			buying = false
		end
	end)

	-- paid (Server/Data fires this just before the cash goes in): out it pops, and the "+$X"
	-- flies from where the amount was into the Cash counter
	if remote then
		remote.OnClientEvent:Connect(function(paid)
			if typeof(paid) ~= "number" then
				return
			end
			local from = amount.AbsolutePosition + amount.AbsoluteSize / 2
			if not UiFx.isOpen(gui) then
				from = workspace.CurrentCamera.ViewportSize * Vector2.new(0.5, 0.45)
			end
			close()
			require(script.Parent.BossBounty).fly(paid, from, 1.6)
		end)
	end

	-- up it pops a moment after joining, once the saved data's in (Server/Data's Loaded); after
	-- that, whenever more comes in (the /offline command), it opens or its amount goes up
	local ready = false
	task.spawn(function()
		while not player:GetAttribute("Loaded") do
			player:GetAttributeChangedSignal("Loaded"):Wait()
		end
		task.wait(Config.Data.OfflinePopupDelay)
		ready = true
		open()
	end)
	player:GetAttributeChangedSignal("OfflineCash"):Connect(function()
		local waiting = player:GetAttribute("OfflineCash") or 0
		if waiting > 0 and UiFx.isOpen(gui) then
			amount.Text = "$" .. Abbrev(waiting)
		elseif ready then
			open()
		end
	end)
end

function OfflineCash.init(root)
	local gui, amount, claim, double, priceText, burst = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	task.spawn(wire, gui, amount, claim, double, priceText, burst) -- (it waits for the server's remote)
end

return OfflineCash
