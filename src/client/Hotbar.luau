-- The eggs you've stolen this life (QM, Oct 25: "after stealing an egg it appears to the
-- right of the backpack, like an inventory"): one slot per kind in your EggBag (Server/
-- Hatchery), right of the Backpack button, in LassoAPet's inventory slots (QM, Oct 25): its
-- egg's icon with "x2" when there's more than one. Click one (or press its number) to hold it instead of your weapon; click it again
-- to put it away. The one you hold is outlined white. Put it down in your pen by clicking
-- there (client/PenEggs).
--
--   Hotbar.init(root, hudFrames)  -- once, from Hud (root = its scaled frame)
--
-- In Studio: StarterGui > Hud > Root > EggHotbar > SlotTemplate is the slot every egg is
-- copied from (tick its Visible to see it): its Background, Picture, Number, Count and the
-- held one's Ring (client/Ui).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Egg = require(Shared.Eggs.Egg)
local PetIcons = require(Shared.PetIcons)
local Stacks = require(Shared.Stacks)
local Popups = require(script.Parent.Popups)
local Ui = require(script.Parent.Ui)

local Hotbar = {}

local player = Players.LocalPlayer
local SLOT = 96
local PANEL = "rbxassetid://118593193834683" -- LassoAPet's InventoryBG (assets/ui/InventoryBG.png: grey, dark border)
local PANEL_SIZE = 96
local PANEL_CORNER = 18 / 96 -- (its corners' radius, of its width)
local GAP = 12
local FROM_CENTRE = 112 -- design px from the screen's middle to the first slot (past the Backpack button)
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

-- the egg's picture: its icon in the slot's Picture, or (until icons are uploaded) the egg
-- itself in a viewport where the Picture is
local function picture(slot, kind)
	local img = slot:FindFirstChild("Picture")
	if not img then
		return
	end
	if PetIcons.Eggs[kind] then
		img.Image = PetIcons.Eggs[kind]
		return
	end
	img.Visible = false
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.AnchorPoint = img.AnchorPoint
	vp.Position = img.Position
	vp.Size = UDim2.new(img.Size.X.Scale * 1.18, img.Size.X.Offset, img.Size.Y.Scale * 1.18, img.Size.Y.Offset)
	vp.ZIndex = img.ZIndex
	vp.Ambient = Color3.new(1, 1, 1)
	vp.LightColor = Color3.new(0, 0, 0)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local ok, egg = pcall(Egg.new, kind, 1)
	if ok then
		egg.model.Parent = vp
		local box, size = egg.model:GetBoundingBox()
		local d = size.Magnitude * 0.5 / math.tan(math.rad(15)) * 0.95
		cam.CFrame = CFrame.lookAt(box.Position + Vector3.new(0.5, 0.3, -1).Unit * d, box.Position)
	end
	vp.Parent = slot
end

-- (LassoAPet's slot, QM Oct 25: its InventoryBG 9-sliced, the number top left, "xN" across
-- the middle, a thin white ring on the one in hand)
local function slotTemplate()
	local b = Instance.new("TextButton")
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Size = UDim2.fromOffset(SLOT, SLOT)
	local scale = Instance.new("UIScale")
	scale.Name = "Hover"
	scale.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(PANEL_CORNER, 0)
	corner.Parent = b
	local bg = Instance.new("ImageLabel")
	bg.Name = "Background"
	bg.BackgroundTransparency = 1
	bg.Size = UDim2.fromScale(1, 1)
	bg.Image = PANEL
	bg.ScaleType = Enum.ScaleType.Slice
	bg.SliceCenter = Rect.new(24, 24, 72, 72)
	bg.SliceScale = SLOT / PANEL_SIZE
	bg.ZIndex = 0
	bg.Parent = b
	local ring = Instance.new("UIStroke")
	ring.Name = "Ring"
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 3
	ring.Parent = b
	local img = Instance.new("ImageLabel")
	img.Name = "Picture"
	img.BackgroundTransparency = 1
	img.Image = PetIcons.Eggs.Bunny or ""
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.54)
	img.Size = UDim2.fromScale(0.72, 0.72)
	img.ZIndex = 2
	img.Parent = b
	local number = Popups.text(b, {
		Name = "Number",
		Text = "1",
		TextSize = 24,
		Position = UDim2.fromOffset(6, 3),
		Size = UDim2.fromOffset(28, 28),
		ZIndex = 3,
	})
	number:FindFirstChildOfClass("UIStroke").Thickness = 2.4
	local count = Popups.text(b, {
		Name = "Count",
		Text = "x2",
		TextSize = 40,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	count:FindFirstChildOfClass("UIStroke").Thickness = 3.6
	return b
end

function Hotbar.init(root, hudFrames)
	local bar, fresh = Ui.make(root, "EggHotbar", "Frame")
	if fresh then
		bar.BackgroundTransparency = 1
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0.5, FROM_CENTRE, 1, -28)
		bar.Size = UDim2.fromOffset(9 * (SLOT + GAP), SLOT)
	end
	table.insert(hudFrames, bar)
	local layout
	layout, fresh = Ui.make(bar, "Layout", "UIListLayout")
	if fresh then
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Padding = UDim.new(0, GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
	end
	local template = Ui.template(bar, "SlotTemplate", slotTemplate)
	if not Ui.live then
		return
	end
	local holdRemote = ReplicatedStorage:WaitForChild("HoldEgg", 10)

	local order = {} -- kinds in their slots' order (first stolen first)

	local function hold(kind)
		if holdRemote then
			holdRemote:FireServer(kind)
		end
	end

	local function rebuild()
		for _, child in bar:GetChildren() do
			if child:IsA("GuiObject") and not Ui.isTemplate(child) then
				child:Destroy()
			end
		end
		table.clear(order)
		local holding = player:GetAttribute("Holding")
		for i, s in
			Stacks.parse(player:GetAttribute("EggBag"), function(kind)
				return Config.Pets[kind] ~= nil
			end)
		do
			if i > #KEYS then
				break
			end
			order[i] = s.id
			local b = Ui.copy(template, s.id, bar)
			b.LayoutOrder = i
			local ring = b:FindFirstChild("Ring")
			if ring then
				ring.Enabled = holding == s.id
			end
			picture(b, s.id)
			local number = b:FindFirstChild("Number")
			if number then
				number.Text = tostring(i)
			end
			local count = b:FindFirstChild("Count")
			if count then
				count.Text = "x" .. s.n
				count.Visible = s.n > 1
			end
			local scale = b:FindFirstChildOfClass("UIScale")
			if scale then
				local rest = scale.Scale
				b.MouseEnter:Connect(function()
					TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = rest + 0.06 })
						:Play()
				end)
				b.MouseLeave:Connect(function()
					TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = rest }):Play()
				end)
			end
			b.Activated:Connect(function()
				hold(s.id)
			end)
		end
	end
	player:GetAttributeChangedSignal("EggBag"):Connect(rebuild)
	player:GetAttributeChangedSignal("Holding"):Connect(rebuild)
	rebuild()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local i = table.find(KEYS, input.KeyCode)
		if i and order[i] then
			hold(order[i])
		end
	end)
end

return Hotbar
