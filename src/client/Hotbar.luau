-- The eggs you've stolen this life (QM, Oct 25: "after stealing an egg it appears to the
-- right of the backpack, like an inventory"): one slot per kind in your EggBag (Server/
-- Hatchery), right of the Backpack button, in LassoAPet's inventory slots (QM, Oct 25): its
-- egg's icon with "x2" when there's more than one. Click one (or press its number) to hold it instead of your weapon; click it again
-- to put it away. The one you hold is outlined white. Put it down in your pen by clicking
-- there (client/PenEggs).
--
--   Hotbar.init(root, hudFrames)  -- once, from Hud (root = its scaled frame)

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

-- the egg's picture: its icon, or (until icons are uploaded) the egg itself in a viewport
local function picture(parent, kind)
	if PetIcons.Eggs[kind] then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = PetIcons.Eggs[kind]
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.54)
		img.Size = UDim2.fromScale(0.72, 0.72)
		img.ZIndex = 2
		img.Parent = parent
		return
	end
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.AnchorPoint = Vector2.new(0.5, 0.5)
	vp.Position = UDim2.fromScale(0.5, 0.52)
	vp.Size = UDim2.fromScale(0.85, 0.85)
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
	vp.Parent = parent
end

function Hotbar.init(root, hudFrames)
	local holdRemote = ReplicatedStorage:WaitForChild("HoldEgg", 10)
	local bar = Instance.new("Frame")
	bar.Name = "EggHotbar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0.5, FROM_CENTRE, 1, -28)
	bar.Size = UDim2.fromOffset(9 * (SLOT + GAP), SLOT)
	bar.Parent = root
	table.insert(hudFrames, bar)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	local order = {} -- kinds in their slots' order (first stolen first)

	local function hold(kind)
		if holdRemote then
			holdRemote:FireServer(kind)
		end
	end

	local function rebuild()
		for _, child in bar:GetChildren() do
			if child:IsA("GuiObject") then
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
			local b = Instance.new("TextButton")
			b.Name = s.id
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.LayoutOrder = i
			b.Size = UDim2.fromOffset(SLOT, SLOT)
			local scale = Instance.new("UIScale")
			scale.Parent = b
			-- (LassoAPet's slot, QM Oct 25: its InventoryBG 9-sliced, the number top left,
			-- "xN" across the middle, a thin white ring on the one in hand)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(PANEL_CORNER, 0)
			corner.Parent = b
			local bg = Instance.new("ImageLabel")
			bg.BackgroundTransparency = 1
			bg.Size = UDim2.fromScale(1, 1)
			bg.Image = PANEL
			bg.ScaleType = Enum.ScaleType.Slice
			bg.SliceCenter = Rect.new(24, 24, 72, 72)
			bg.SliceScale = SLOT / PANEL_SIZE
			bg.ZIndex = 0
			bg.Parent = b
			if holding == s.id then
				local ring = Instance.new("UIStroke")
				ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				ring.Color = Color3.new(1, 1, 1)
				ring.Thickness = 3
				ring.Parent = b
			end
			picture(b, s.id)
			local number = Popups.text(b, {
				Text = tostring(i),
				TextSize = 24,
				Position = UDim2.fromOffset(6, 3),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = 3,
			})
			number:FindFirstChildOfClass("UIStroke").Thickness = 2.4
			if s.n > 1 then
				local count = Popups.text(b, {
					Text = "x" .. s.n,
					TextSize = 40,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
				})
				count:FindFirstChildOfClass("UIStroke").Thickness = 3.6
			end
			local rest = scale.Scale
			b.MouseEnter:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = rest + 0.06 }):Play()
			end)
			b.MouseLeave:Connect(function()
				TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = rest }):Play()
			end)
			b.Activated:Connect(function()
				hold(s.id)
			end)
			b.Parent = bar
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
