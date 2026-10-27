-- Over every player (QM's Figma Healthbar, Page 1, Oct 27): their name, and their health as
-- QM's little green bar (assets/ui/HpBack.png under HpFill.png, the fill cut from the right
-- as they're hurt) with the number over its middle. (It showed their ride's name before.)
-- A hit (QM, Oct 27, like the boss bar) flashes the green white, leaves a white trail where
-- it was that catches up, and pops a red "-10" over their head (client/DamageNumbers).
-- Roblox's own name and health over characters is turned off.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local DamageNumbers = require(script.Parent.DamageNumbers)

local FILL, BACK = "rbxassetid://90275415984527", "rbxassetid://133695040857929"
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
-- (the Figma's 216 x 67: the name 30 tall at the top, the bar 18 tall 41 down, the health
-- 37 tall from 30 down, over the bar)
local W, H = 216, 67
local NAME_STROKE = Color3.fromRGB(70, 70, 70)
local WIDE = 7.8 -- studs across (QM, Oct 27: 30% up from 6, to read from further off)
local FLASH = 0.1 -- seconds the green takes to fade back from white on a hit
local TRAIL = 0.3 -- seconds the white trail takes to catch up
local HURT = Color3.fromRGB(255, 60, 60) -- the damage numbers over players

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
	gui.Size = UDim2.fromScale(WIDE, WIDE * H / W) -- (studs: it shrinks with distance like the world)
	gui.StudsOffset = Vector3.new(0, 2.9, 0)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
	-- a white pill inside the art's 4px black border (216 x 18: 208 x 10 inside)
	local function pill(parent, name)
		local p = Instance.new("Frame")
		p.Name = name
		p.BackgroundColor3 = Color3.new(1, 1, 1)
		p.BorderSizePixel = 0
		p.Position = UDim2.fromScale(4 / 216, 4 / 18)
		p.Size = UDim2.fromScale(208 / 216, 10 / 18)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = p
		p.Parent = parent
		return p
	end
	-- the trail: the stretch the green just lost, white, cut to it (as the fill is)
	local trailClip = Instance.new("Frame")
	trailClip.BackgroundTransparency = 1
	trailClip.ClipsDescendants = true
	trailClip.Size = UDim2.fromScale(0, 1)
	trailClip.ZIndex = 2
	trailClip.Parent = bar
	local trail = Instance.new("Frame")
	trail.BackgroundTransparency = 1
	trail.Parent = trailClip
	pill(trail, "Pill")
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 3
	clip.Parent = bar
	local fill = Instance.new("ImageLabel")
	fill.BackgroundTransparency = 1
	fill.Image = FILL
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = clip
	local flash = pill(fill, "Flash") -- (over the green, fading out after a hit)
	flash.BackgroundTransparency = 1
	local f = 1 -- the green's width
	local trailAt = Instance.new("NumberValue") -- the trail's right end (tweened)
	local function drawTrail()
		local to = math.max(trailAt.Value, f)
		trailClip.Position = UDim2.fromScale(f, 0)
		trailClip.Size = UDim2.fromScale(to - f, 1)
		-- (the pill keeps the whole bar's size and place, so it's cut, not squashed)
		trail.Position = UDim2.fromScale(if to > f then -f / (to - f) else 0, 0)
		trail.Size = UDim2.fromScale(if to > f then 1 / (to - f) else 1, 1)
	end
	trailAt.Changed:Connect(drawTrail)
	local last = humanoid.Health
	local function health()
		local was = f
		f = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		clip.Size = UDim2.fromScale(f, 1)
		-- (the art keeps its full width inside the clip, so it's cut, not squashed)
		fill.Size = UDim2.fromScale(if f > 0 then 1 / f else 1, 1)
		hp.Text = tostring(math.max(0, math.ceil(humanoid.Health)))
		local lost = last - humanoid.Health
		last = humanoid.Health
		if f < was and lost > 0 then
			-- a hit: the green flashes white, the trail starts where it was and catches up
			flash.BackgroundTransparency = 0
			TweenService:Create(flash, TweenInfo.new(FLASH), { BackgroundTransparency = 1 }):Play()
			trailAt.Value = math.max(trailAt.Value, was)
			TweenService:Create(trailAt, TweenInfo.new(TRAIL, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = f }):Play()
			DamageNumbers.pop(head, lost, gui.StudsOffset.Y + 1.5, HURT)
		else
			trailAt.Value = f
		end
		drawTrail()
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
