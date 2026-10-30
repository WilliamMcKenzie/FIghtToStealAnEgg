-- The hotbar (QM's NewUI Figma, Oct 27), bottom centre: 192 (Figma px) slots of 40% black
-- with rounded corners, the slot's number top left, and what's in it filling it. Slot 1 is
-- your weapon; after it, one slot per kind of egg you've stolen this life (your EggBag:
-- Server/Hatchery), with "xN" when there's more than one. Click a slot (or press its
-- number) to hold that: an egg instead of your weapon (HoldEgg), or the weapon again. The
-- one in hand has a thick white ring. Put a held egg down in your pen by clicking there
-- (client/PenEggs).
--
--   Hotbar.init(root, fig)  -- once, from Hud (root = its scaled frame, fig = Figma px -> design px)
--
-- In Studio: StarterGui > Hud > Root > Hotbar > SlotTemplate is the slot every one is copied
-- from (tick its Visible to see it): its Picture, Number, Count and Ring (client/Ui). The
-- pictures are the weapon and egg renders (Shared/ItemIcons; QM, Oct 27).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ItemIcons = require(Shared.ItemIcons)
local Stacks = require(Shared.Stacks)
local Abbrev = require(Shared.Abbrev)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local Hotbar = {}

local player = Players.LocalPlayer
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function slotTemplate(fig)
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.new(0, 0, 0)
	b.BackgroundTransparency = 0.6
	b.Size = UDim2.fromOffset(fig(192), fig(192))
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, fig(20))
	corner.Parent = b
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Size = UDim2.fromScale(1, 1)
	picture.ZIndex = 2
	picture.Parent = b
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = fig(8)
	ring.Enabled = false
	ring.Parent = b
	for _, t in {
		{ "Number", "1", 40, Vector2.new(0, 0), UDim2.fromOffset(fig(18), fig(9)), Enum.TextXAlignment.Left },
		{ "Count", "x2", 48, Vector2.new(1, 1), UDim2.new(1, -fig(14), 1, -fig(6)), Enum.TextXAlignment.Right },
	} do
		local label = Instance.new("TextLabel")
		label.Name = t[1]
		label.BackgroundTransparency = 1
		label.FontFace = FONT
		label.Text = t[2]
		label.TextSize = fig(t[3])
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = t[6]
		label.AnchorPoint = t[4]
		label.Position = t[5]
		label.Size = UDim2.fromOffset(fig(100), fig(t[3] + 9))
		label.ZIndex = 3
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = b
	end
	return b
end

function Hotbar.init(root, fig)
	-- three slots 218.5 apart (Figma), centred, 39 up from the bottom
	local bar, fresh = Ui.make(root, "Hotbar", "Frame")
	if fresh then
		bar.BackgroundTransparency = 1
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.new(0.5, 0, 1, -fig(39))
		bar.Size = UDim2.fromOffset(fig(9 * 218.5), fig(192))
	end
	local layout
	layout, fresh = Ui.make(bar, "Layout", "UIListLayout")
	if fresh then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, fig(218.5 - 192))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	local template = Ui.template(bar, "SlotTemplate", function()
		return slotTemplate(fig)
	end)
	if not Ui.live then
		return
	end

	local holdRemote = ReplicatedStorage:WaitForChild("HoldEgg", 10)
	local slots = {} -- { { kind = egg kind or nil for the weapon } } in order
	local function pick(i)
		local s = slots[i]
		if s and holdRemote then
			holdRemote:FireServer(s.kind) -- (nil: the weapon)
		end
	end

	local shownWeapon, shownBag = nil, nil
	local function rebuild()
		local weapon = player:GetAttribute("Weapon")
		local bagText = player:GetAttribute("EggBag")
		local holding = player:GetAttribute("Holding")
		if weapon ~= shownWeapon or bagText ~= shownBag then
			shownWeapon, shownBag = weapon, bagText
			for _, child in bar:GetChildren() do
				if child:IsA("GuiObject") and not Ui.isTemplate(child) then
					child:Destroy()
				end
			end
			table.clear(slots)
			local list = { { kind = nil, count = 1 } }
			for _, e in Stacks.parse(bagText) do
				table.insert(list, { kind = e.id, count = e.n })
			end
			for i, s in list do
				if i > #KEYS then
					break
				end
				local slot = Ui.copy(template, "Slot" .. i, bar)
				slot.LayoutOrder = i
				slot.Number.Text = tostring(i)
				slot.Count.Visible = s.count > 1
				slot.Count.Text = "x" .. Abbrev(s.count)
				slot.Picture.Image = (if s.kind then ItemIcons.Eggs[s.kind] else ItemIcons.Weapons[weapon or ""]) or ""
				UiFx.button(slot) -- (its press and click)
				slot.Activated:Connect(function()
					pick(i)
				end)
				slots[i] = s
			end
		end
		for i, s in slots do
			local slot = bar:FindFirstChild("Slot" .. i)
			if slot then
				slot.Ring.Enabled = s.kind == holding
			end
		end
	end
	rebuild()
	for _, name in { "Weapon", "EggBag", "Holding" } do
		player:GetAttributeChangedSignal(name):Connect(rebuild)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local i = table.find(KEYS, input.KeyCode)
		if i then
			pick(i)
		end
	end)
end

return Hotbar
