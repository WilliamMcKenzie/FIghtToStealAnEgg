-- The Active Pets popup (QM's Figma ActivePets, Oct 27), opened by the paw (Pets) button on
-- the right: a gold header with "1/5 Active" and the pink "+1 Equip [30R]" (more pen slots
-- for Robux: not sold yet, Config.Backpack.SlotProduct), and under it a row per pet owned
-- (each copy): its render (Shared/ItemIcons), its name (white: QM), its cash a second, and
-- Unequip (red, the pen's pets first), Equip (green) or Full (grey, no room in the pen). The red ">" tab on its left slides
-- it away. Equip and Unequip go through Server/PetInventory's PetEquip remote.
--
--   PetsPanel.init(root, petsButton)   -- once, from Hud
--   PetsPanel.open() / PetsPanel.close() / PetsPanel.isOpen()
--
-- In Studio: StarterGui > Hud > Root > PetsPanel (tick its Visible to see it). Rows are
-- copies of Rows > RowTemplate, edit that one.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local Pets = require(Shared.Pets)
local RegionBlocker = require(Shared.RegionBlocker)
local Stacks = require(Shared.Stacks)
local HudKit = require(script.Parent.HudKit)
local SidePanel = require(script.Parent.SidePanel)
local Ui = require(script.Parent.Ui)

local PetsPanel = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button
local function hex(h)
	return Color3.fromHex(h)
end
-- (Figma px, through fig: the popup itself is client/SidePanel's)
local OUTLINES = { -- text outlines (Figma)
	Title = hex("8a3a00"),
	Cash = hex("0a5a00"),
	Unequip = hex("7a0000"),
	Equip = hex("006b10"),
	Full = hex("3a3a3a"),
}

local panel, rows, template, countLabel

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
	-- (Full: QM's grey one, when the pen has no room)
	for _, b in {
		{ "PetUnequip", "RedPlain", "Unequip" },
		{ "PetEquip", "GreenPlain", "Equip" },
		{ "PetFull", "GreyPlain", "Full" },
	} do
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
	panel = SidePanel.new(root, "PetsPanel", "GoldHeader", "1/5 Active", OUTLINES.Title)
	countLabel = panel.title
	local buy = button(panel.gui, "PetsBuySlot", 384, 90, { Position = UDim2.fromOffset(fig(768), fig(19)), ZIndex = 4 }, "Pink")
	label(buy, "Text", {
		Text = "+1 Equip [" .. Config.Backpack.SlotRobux .. "R]",
		TextSize = fig(35),
		Position = UDim2.fromOffset(fig(12), 0),
		Size = UDim2.new(0, fig(290), 1, 0),
		ZIndex = 5,
	})
	local robux = art(buy, "RobuxIcon", {
		Position = UDim2.fromOffset(fig(312), fig(9)),
		Size = UDim2.fromOffset(fig(61), fig(67)),
		ZIndex = 5,
	})
	HudKit.outlineArt(robux, 3) -- (QM: outlined like its text)
	rows = panel.rows
	template = Ui.template(rows, "RowTemplate", rowTemplate)
	return buy
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
	return panel ~= nil and panel:isOpen()
end

function PetsPanel.open()
	if panel then
		panel:open()
	end
end

function PetsPanel.close()
	if panel then
		panel:close()
	end
end

function PetsPanel.init(root, petsButton)
	local buy = build(root)
	if not Ui.live then
		return
	end
	if petsButton then
		petsButton.Activated:Connect(function()
			panel:toggle()
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
			local full = entry.slot == nil and inPen >= slots
			row.PetUnequip.Visible = entry.slot ~= nil
			row.PetEquip.Visible = entry.slot == nil and not full
			row.PetFull.Visible = full
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
