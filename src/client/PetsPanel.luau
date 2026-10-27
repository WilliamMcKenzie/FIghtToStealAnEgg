-- The Active Pets popup (QM's Figma ActivePets, Oct 27), opened by the paw (Pets) button on
-- the right: a gold header with "1/5 Active" and the pink "+1 Equip [30R]" (more pen slots
-- for Robux: not sold yet, Config.Backpack.SlotProduct), and under it a row per pet owned
-- (each copy): its render (Shared/ItemIcons), its name (white: QM), its cash a second, and
-- Unequip (red, the pen's pets first) or Equip (green). The red ">" tab on its left slides
-- it away. Equip and Unequip go through Server/PetInventory's PetEquip remote.
--
--   PetsPanel.init(root, petsButton)   -- once, from Hud
--   PetsPanel.open() / PetsPanel.close() / PetsPanel.isOpen()
--
-- In Studio: StarterGui > Hud > Root > PetsPanel (tick its Visible to see it). Rows are
-- copies of Body > Rows > RowTemplate, edit that one.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Pets = require(Shared.Pets)
local RegionBlocker = require(Shared.RegionBlocker)
local Stacks = require(Shared.Stacks)
local HudImages = require(script.Parent.HudImages)
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)

local PetsPanel = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button
local function hex(h)
	return Color3.fromHex(h)
end
-- (Figma: the frame is 1168 x 734, the tab 234 of it on the left; everything below is in its px)
local W, H = 1168, 734
local SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local OUTLINES = { -- text outlines (Figma)
	Title = hex("8a3a00"),
	Cash = hex("0a5a00"),
	Unequip = hex("7a0000"),
	Equip = hex("006b10"),
}

local gui, rows, template, countLabel, shownAt

-- a row (Figma Card: 876 x 207)
local function rowTemplate()
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(fig(876), fig(207))
	HudKit.back(row, "PetCard", {})
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Position = UDim2.fromOffset(fig(13), fig(15))
	picture.Size = UDim2.fromOffset(fig(177), fig(177))
	picture.ZIndex = 2
	picture.Parent = row
	label(row, "PetName", {
		Text = "Rhino",
		TextSize = fig(50),
		Position = UDim2.fromOffset(fig(252), fig(28)),
		Size = UDim2.fromOffset(fig(300), fig(61)),
		ZIndex = 2,
	})
	local cash = label(row, "PetCash", {
		Text = "($100/s)",
		FontFace = HudKit.ITALIC,
		TextColor3 = Color3.fromRGB(0, 255, 0),
		TextSize = fig(40),
		Position = UDim2.fromOffset(fig(243), fig(91)),
		Size = UDim2.fromOffset(fig(300), fig(49)),
		ZIndex = 2,
	})
	cash.Outline.Color = OUTLINES.Cash
	for _, b in { { "PetUnequip", "RedPlain", "Unequip" }, { "PetEquip", "GreenPlain", "Equip" } } do
		local btn = button(row, b[1], 272, 112, { Position = UDim2.fromOffset(fig(567), fig(47)), ZIndex = 3 }, b[2])
		local text = label(btn, "Text", {
			Text = b[3],
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = fig(45),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
		})
		text.Outline.Color = OUTLINES[b[3]]
	end
	return row
end

local function build(root)
	local fresh
	gui, fresh = Ui.make(root, "PetsPanel", "Frame")
	if fresh then
		-- (Figma: 30 in from the right, centred up and down)
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(1, 0.5)
		gui.Position = UDim2.new(1, -fig(30), 0.5, 0)
		gui.Size = UDim2.fromOffset(fig(W), fig(H))
		gui.ZIndex = 10
		gui.Visible = not Ui.live
	end
	shownAt = gui.Position
	local close = button(gui, "PetsClose", 174, 174, { Position = UDim2.fromOffset(0, fig(273)), ZIndex = 4 }, "Red")
	label(close, "Arrow", {
		Text = ">",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	HudKit.back(gui, "Panel", {
		Name = "Body",
		-- (tucked under the header, so only its bottom corners show rounded)
		Position = UDim2.fromOffset(fig(234), fig(110)),
		Size = UDim2.fromOffset(fig(934), fig(624)),
	})
	HudKit.back(gui, "GoldHeader", {
		Name = "Header",
		Position = UDim2.fromOffset(fig(234), 0),
		Size = UDim2.fromOffset(fig(934), fig(130)),
		ZIndex = 2,
	})
	countLabel = label(gui, "Count", {
		Text = "1/5 Active",
		TextSize = fig(70),
		Position = UDim2.fromOffset(fig(265), fig(23)),
		Size = UDim2.fromOffset(fig(480), fig(85)),
		ZIndex = 4,
	})
	countLabel.Outline.Color = OUTLINES.Title
	local buy = button(gui, "PetsBuySlot", 384, 90, { Position = UDim2.fromOffset(fig(768), fig(19)), ZIndex = 4 }, "Pink")
	label(buy, "Text", {
		Text = "+1 Equip [" .. Config.Backpack.SlotRobux .. "R]",
		TextSize = fig(35),
		Position = UDim2.fromOffset(fig(12), 0),
		Size = UDim2.new(0, fig(290), 1, 0),
		ZIndex = 5,
	})
	art(buy, "RobuxIcon", {
		Image = HudImages.RobuxIcon or "",
		Position = UDim2.fromOffset(fig(312), fig(9)),
		Size = UDim2.fromOffset(fig(61), fig(67)),
		ZIndex = 5,
	})

	rows, fresh = Ui.make(gui, "Rows", "ScrollingFrame")
	if fresh then
		rows.BackgroundTransparency = 1
		rows.BorderSizePixel = 0
		rows.Position = UDim2.fromOffset(fig(265) - 4, fig(160) - 4)
		rows.Size = UDim2.fromOffset(fig(876) + 8 + 10, fig(544))
		rows.CanvasSize = UDim2.new()
		rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
		rows.ScrollingDirection = Enum.ScrollingDirection.Y
		rows.ScrollBarThickness = 6
		rows.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
		rows.ZIndex = 3
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = rows
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, fig(36))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = rows
	end
	template = Ui.template(rows, "RowTemplate", rowTemplate)
	return close, buy
end

-- ---- filling in -------------------------------------------------------------------------

-- the pen's pets in their slots, then every other copy owned (Shared/Stacks text: "Pig:3,Unicorn")
local function listed()
	local pen = {}
	for kind in string.gmatch(player:GetAttribute("PenPets") or "", "[^,]+") do
		table.insert(pen, kind)
	end
	local left = {}
	for _, stack in Stacks.parse(player:GetAttribute("PetsOwned")) do
		left[stack.id] = stack.n
	end
	local list = {}
	for slot, kind in pen do
		left[kind] = (left[kind] or 0) - 1
		table.insert(list, { kind = kind, slot = slot })
	end
	local spare = {}
	for kind, n in left do
		if Config.Pets[kind] then
			for _ = 1, n do
				table.insert(spare, kind)
			end
		end
	end
	-- (the ones earning most first)
	table.sort(spare, function(a, b)
		local ca, cb = Config.Pets[a].Cash or 0, Config.Pets[b].Cash or 0
		if ca ~= cb then
			return ca > cb
		end
		return a < b
	end)
	for _, kind in spare do
		table.insert(list, { kind = kind })
	end
	return list, #pen
end

function PetsPanel.isOpen()
	return gui ~= nil and gui.Visible
end

function PetsPanel.open()
	if not gui or gui.Visible then
		return
	end
	gui.Visible = true
	gui.Position = shownAt + UDim2.fromOffset(fig(W) + fig(60), 0)
	TweenService:Create(gui, SLIDE, { Position = shownAt }):Play()
end

function PetsPanel.close()
	if not gui or not gui.Visible then
		return
	end
	local out = TweenService:Create(gui, SLIDE_OUT, { Position = shownAt + UDim2.fromOffset(fig(W) + fig(60), 0) })
	out.Completed:Connect(function(how)
		if how == Enum.PlaybackState.Completed then
			gui.Visible = false
			gui.Position = shownAt
		end
	end)
	out:Play()
end

function PetsPanel.init(root, petsButton)
	local close, buy = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	close.Activated:Connect(PetsPanel.close)
	if petsButton then
		petsButton.Activated:Connect(function()
			if PetsPanel.isOpen() then
				PetsPanel.close()
			else
				PetsPanel.open()
			end
		end)
	end
	buy.Activated:Connect(function()
		-- (not sold yet: needs its developer product and the server side)
		if Config.Backpack.SlotProduct then
			MarketplaceService:PromptProductPurchase(player, Config.Backpack.SlotProduct)
		end
	end)

	local remote = ReplicatedStorage:WaitForChild("PetEquip", 10)
	local made = {}
	local function refresh()
		for _, r in made do
			r:Destroy()
		end
		table.clear(made)
		local list, inPen = listed()
		local slots = Config.Backpack.PenSlots
		countLabel.Text = string.format("%d/%d Active", inPen, slots)
		for i, entry in list do
			local row = Ui.copy(template, "Row" .. i, rows)
			row.LayoutOrder = i
			local kind = entry.kind
			row.Picture.Image = (ItemIcons.Pets or {})[kind] or ""
			row.PetName.Text = Pets.name(kind)
			row.PetCash.Text = "($" .. RegionBlocker.abbreviate(Config.Pets[kind].Cash or 0) .. "/s)"
			row.PetUnequip.Visible = entry.slot ~= nil
			row.PetEquip.Visible = entry.slot == nil
			if entry.slot == nil and inPen >= slots then
				row.PetEquip.Text.Text = "Full"
			end
			for _, b in { row.PetUnequip, row.PetEquip } do
				HudKit.hover(b) -- (a copy doesn't keep the template's)
			end
			row.PetUnequip.Activated:Connect(function()
				if remote then
					remote:FireServer("unequip", entry.slot)
				end
			end)
			row.PetEquip.Activated:Connect(function()
				if remote and inPen < slots then
					remote:FireServer("equip", kind)
				end
			end)
			table.insert(made, row)
		end
	end
	refresh()
	for _, name in { "PetsOwned", "PenPets" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
end

return PetsPanel
