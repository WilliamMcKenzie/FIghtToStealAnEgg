-- Over every player (QM's Figma Healthbar, Page 1, Oct 27): their name, and their health as
-- QM's little green bar (assets/ui/HpBack.png under HpFill.png, the fill cut from the right
-- as they're hurt) with the number over its middle. (It showed their ride's name before.)
-- Roblox's own name and health over characters is turned off.

local Players = game:GetService("Players")

local FILL, BACK = "rbxassetid://90275415984527", "rbxassetid://133695040857929"
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
-- (the Figma's 216 x 67: the name 30 tall at the top, the bar 18 tall 41 down, the health
-- 37 tall from 30 down, over the bar)
local W, H = 216, 67
local NAME_STROKE = Color3.fromRGB(70, 70, 70)

local function attach(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not (humanoid and head) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild("PlayerBar")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PlayerBar"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(6, 6 * H / W) -- (studs: it shrinks with distance like the world)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	-- (each text fills its Figma box: Montserrat ExtraBold, white, outlined)
	local function text(name, y, h, outline)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y / H)
		label.Size = UDim2.fromScale(1, h / H)
		label.FontFace = FONT
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = 2
		local stroke = Instance.new("UIStroke")
		stroke.Color = outline
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		label.Parent = gui
		return label, stroke
	end
	local player = Players:GetPlayerFromCharacter(character)
	local name, nameStroke = text("PlayerName", 0, 30, NAME_STROKE)
	name.Text = if player then player.DisplayName else character.Name
	local hp, hpStroke = text("Health", 30, 37, Color3.new(0, 0, 0))
	hp.ZIndex = 3
	-- the health bar (216 x 18 art)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.fromScale(0.5, 41 / H)
	bar.Size = UDim2.fromScale(1, 18 / H)
	bar.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 216 / 18
	ratio.Parent = bar
	local back = Instance.new("ImageLabel")
	back.BackgroundTransparency = 1
	back.Image = BACK
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = bar
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.Parent = bar
	local fill = Instance.new("ImageLabel")
	fill.BackgroundTransparency = 1
	fill.Image = FILL
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = clip
	local function health()
		local f = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		clip.Size = UDim2.fromScale(f, 1)
		-- (the art keeps its full width inside the clip, so it's cut, not squashed)
		fill.Size = UDim2.fromScale(if f > 0 then 1 / f else 1, 1)
		hp.Text = tostring(math.max(0, math.ceil(humanoid.Health)))
	end
	humanoid.HealthChanged:Connect(health)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(health)
	health()
	-- (the text's outlines as thick as the bar's black border, 4 of its 18 pixels, at
	-- whatever size the billboard is drawn: QM)
	local function outline()
		local t = math.max(1, bar.AbsoluteSize.Y * 4 / 18)
		nameStroke.Thickness, hpStroke.Thickness = t, t
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(outline)
	outline()
	gui.Parent = head
end

local function watch(player)
	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

return nil
