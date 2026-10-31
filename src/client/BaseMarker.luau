-- "Your Base" (QM, Oct 31: "add this above pen, which goes away once you actually walk in
-- the pen", with Steal a Brainrot's floating house as the reference): QM's blue house icon
-- with "Your Base" under it floats over your own pen's gate, just above its name card,
-- only for you, bobbing gently. The
-- first time you walk into the pen it fades out and the server saves BaseFound, so it
-- never shows again (/reset and /tutorial bring it back). Tuning in Config.BaseMarker; the icon is
-- HudImages.BaseHouse (assets/ui/hud/BaseHouse.png; just the text shows until it's uploaded).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudImages = require(script.Parent.HudImages)

local player = Players.LocalPlayer
local C = Config.BaseMarker
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local FADE = 0.35 -- seconds to fade out once you're in

local function myArea()
	local index = player:GetAttribute("Pen")
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen:FindFirstChild("Area")
		end
	end
	return nil
end

local spot, board, builtFor -- the anchored point it hangs on, its billboard, the Area
local leaving = false
local function signOf(area)
	local sign = area and area.Parent:FindFirstChild("OwnerSign")
	return sign and sign:FindFirstChild("Board")
end

local function build(area)
	if spot then
		spot:Destroy()
	end
	builtFor = area
	spot = Instance.new("Part")
	spot.Name = "BaseMarker"
	spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
	spot.Transparency = 1
	spot.Size = Vector3.one * 0.2
	board = Instance.new("BillboardGui")
	-- (in studs, so it sits in the world like the pen does; the text takes the bottom quarter)
	board.Size = UDim2.fromScale(C.Size * 1.6, C.Size * 1.3)
	board.LightInfluence = 0
	board.AlwaysOnTop = false
	board.Adornee = spot
	local house = Instance.new("ImageLabel")
	house.Name = "House"
	house.BackgroundTransparency = 1
	house.Image = HudImages.BaseHouse or ""
	house.ScaleType = Enum.ScaleType.Fit
	house.AnchorPoint = Vector2.new(0.5, 0)
	house.Position = UDim2.fromScale(0.5, 0)
	house.Size = UDim2.fromScale(1, 0.76)
	house.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.fromScale(1, 0.24)
	label.FontFace = FONT
	label.Text = "Your Base"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = board
	board.Parent = spot
	spot.Parent = workspace
end

local function clear()
	if spot then
		spot:Destroy()
	end
	spot, board, builtFor = nil, nil, nil
end

local function inside(area)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local p = area.CFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= area.Size.X / 2 and math.abs(p.Z) <= area.Size.Z / 2
end

local function leave()
	leaving = true
	ReplicatedStorage:WaitForChild("BaseFound"):FireServer()
	local s, b = spot, board
	spot, board, builtFor = nil, nil, nil
	if not b then
		return
	end
	local info = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, d in b:GetDescendants() do
		if d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(FADE, function()
		s:Destroy()
	end)
end

RunService.RenderStepped:Connect(function()
	-- (BaseFound comes in with the save, after Loaded; a /reset clears it again)
	if player:GetAttribute("BaseFound") or not player:GetAttribute("Loaded") then
		clear()
		leaving = false
		return
	end
	if leaving then
		return
	end
	local area = myArea()
	if not area then
		clear()
		return
	end
	if area ~= builtFor or not spot then
		build(area)
	end
	if inside(area) then
		leave()
		return
	end
	local bob = math.sin(os.clock() * 2 * math.pi / C.BobPeriod) * C.Bob
	local floor = area.Position.Y - area.Size.Y / 2
	local sign = signOf(area)
	local at = if sign then sign.Position else area.Position -- (over the gate, above the name card)
	spot.CFrame = CFrame.new(at.X, floor + C.Height + bob, at.Z)
end)

return nil
