-- "Level up!" over a player's head when their level goes up (QM, Oct 31, from their
-- reference): cyan Montserrat with a dark outline, popping in past full size and settling,
-- then floating up and fading, with white square sparkles bursting out round it. Everyone
-- nearby sees it. The level comes from Server/Combat's Level attribute (Shared/Levels);
-- it doesn't pop for the level you join with (Server/Data's Loaded), or for going down
-- (a rebirth).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local OUTLINE = Color3.fromRGB(20, 40, 60)
local WIDE, TALL = 10, 4 -- studs the popup spans (sparkles fly inside it)
local HEIGHT = 6.5 -- studs over the head it starts (just over the name and health bar)
local RISE = 2 -- studs it floats up
local HOLD = 0.9 -- seconds before it starts to fade
local FADE = 0.6 -- seconds it takes to fade
local POP = 1.3 -- how far past full size it pops in
local SPARKS = 16 -- white squares
local SPARK_LIFE = 0.9

local function sparkle(holder)
	for _ = 1, SPARKS do
		local s = Instance.new("Frame")
		local px = math.random(3, 6) / 100
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.4, 0.5 + (math.random() - 0.5) * 0.3)
		s.Size = UDim2.fromScale(px * TALL / WIDE, px)
		s.BackgroundColor3 = Color3.new(1, 1, 1)
		s.BorderSizePixel = 0
		s.ZIndex = 1
		s.Parent = holder
		local angle = math.random() * math.pi * 2
		local reach = 0.25 + math.random() * 0.25
		local life = SPARK_LIFE * (0.6 + math.random() * 0.4)
		TweenService:Create(s, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = s.Position + UDim2.fromScale(math.cos(angle) * reach, math.sin(angle) * reach * WIDE / TALL * 0.5),
			BackgroundTransparency = 1,
			Rotation = math.random(-90, 90),
		}):Play()
	end
end

local function pop(player)
	local head = player.Character and player.Character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LevelUp"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	gui.Size = UDim2.fromScale(WIDE, TALL)
	gui.StudsOffset = Vector3.new(0, HEIGHT, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 0.45)
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = "Level up!"
	label.TextColor3 = Config.Levels.PopupColor
	label.ZIndex = 2
	label.Parent = holder
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = 2
	stroke.Parent = label
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		stroke.Thickness = math.max(1, label.AbsoluteSize.Y * 0.08)
	end)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = label
	gui.Parent = head
	sparkle(holder)
	local grow = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = POP })
	grow.Completed:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	grow:Play()
	TweenService:Create(gui, TweenInfo.new(HOLD + FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(0, RISE, 0),
	}):Play()
	task.delay(HOLD, function()
		local fade = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	end)
	task.delay(HOLD + FADE + 0.05, function()
		gui:Destroy()
	end)
end

local function watch(player)
	local last = player:GetAttribute("Level")
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level")
		if level and last and level > last and player:GetAttribute("Loaded") then
			pop(player)
		end
		last = level
	end)
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

return nil
