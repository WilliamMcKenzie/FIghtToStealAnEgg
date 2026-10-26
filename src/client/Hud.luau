-- The HUD (QM's Figma, Oct 24): the boss bar with the boss's name over it (top
-- centre), the Shop / Index / Rebirth buttons (stacked on the right edge), and the Power and Cash counters
-- (bottom left). Laid out in pixels at QM's 1080-tall design size, each image at its own
-- size, and scaled to the screen by a UIScale (screen height / 1080). Text is Montserrat
-- ExtraBold 45, white with a dark outline.
--
-- Counters show the player's Power and Cash attributes (abbreviated: 288T). The boss bar
-- follows the nearest awake boss in workspace.Bosses and hides when there's none (or a popup is open).
-- Under the red sits QM's trail bar, cut to wherever the red was TRAIL_LAG seconds ago,
-- so a hit drops the red and exposes the trail, which follows it down half a second on. The buttons don't open anything yet.
--
-- Images were uploaded from assets/ui (ids in assets/ui/ids.json).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Popups = require(script.Parent.Popups)

local Hud = {}

local IMAGES = {
	Shop = "rbxassetid://72208658536040",
	Index = "rbxassetid://129626627303335",
	Rebirth = "rbxassetid://88567858926697",
	Cash = "rbxassetid://83332868999001",
	Power = "rbxassetid://108359754385647",
	BossBarFill = "rbxassetid://139297500668654",
	BossBarBack = "rbxassetid://88593547866423",
	BossBarTrail = "rbxassetid://110382419429261", -- QM's TRAIL 1
	Backpack = "rbxassetid://120170272419141", -- QM's (assets/ui/Backpack.png)
}
local DESIGN_HEIGHT = 1080
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local TEXT = 45
local BAR_EASE = 25 -- how fast the red catches up with the health (quick, not a pop)
local TRAIL_LAG = 0.5 -- seconds the trail bar lags behind the red (QM, Oct 24)
local FILL_IN = 0.4 -- seconds the bar takes to fill from empty when a fight starts (QM, Oct 25)

local player = Players.LocalPlayer

local function text(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = TEXT
	label.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		label[k] = v
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(20, 12, 16)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function image(parent, name, props)
	local img = Instance.new(props.button and "ImageButton" or "ImageLabel")
	props.button = nil
	img.Name = name
	img.BackgroundTransparency = 1
	img.Image = IMAGES[name]
	for k, v in props do
		img[k] = v
	end
	img.Parent = parent
	return img
end

-- 288, 1.5K, 12M, 288T ...
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Hud.abbreviate(n)
	n = math.floor(n or 0)
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	local s = if math.abs(n) < 10 then string.format("%.1f", n) else tostring(math.floor(n))
	return (s:gsub("%.0$", "")) .. SUFFIXES[i]
end

-- a little bounce on hover and press, so the buttons feel alive before they do anything
local function bouncy(button)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local function to(s, t)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = s })
			:Play()
	end
	button.MouseEnter:Connect(function()
		to(1.08, 0.15)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.92, 0.08)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.08, 0.2)
	end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- everything inside `root` is in design pixels; the UIScale fits it to the screen
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local h = workspace.CurrentCamera.ViewportSize.Y
	uiScale.Scale = h / DESIGN_HEIGHT
	-- (the root is scaled down, so it's made bigger by the same factor to fill the screen)
	root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- boss bar
local bar = Instance.new("Frame")
bar.Name = "BossBar"
bar.BackgroundTransparency = 1
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.Position = UDim2.new(0.5, 0, 0, 44)
bar.Size = UDim2.fromOffset(646, 91)
bar.Visible = false
bar.Parent = root
image(bar, "BossBarBack", { Size = UDim2.fromScale(1, 1) })
local trailClip = Instance.new("Frame")
trailClip.Name = "TrailClip"
trailClip.BackgroundTransparency = 1
trailClip.ClipsDescendants = true
trailClip.Size = UDim2.fromScale(1, 1)
trailClip.Parent = bar
local trailImage = image(trailClip, "BossBarTrail", { Size = UDim2.fromOffset(646, 91) })
local clip = Instance.new("Frame")
clip.Name = "Clip"
clip.BackgroundTransparency = 1
clip.ClipsDescendants = true
clip.Size = UDim2.fromScale(1, 1)
clip.Parent = bar
image(clip, "BossBarFill", { Size = UDim2.fromOffset(646, 91) })
local bossName = text(bar, {
	Name = "BossName",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, -6),
	Size = UDim2.fromOffset(600, 50),
	ZIndex = 3,
})

-- buttons: stacked down the right edge, centred on the screen's middle (QM's mockup, Oct 26).
-- They stay up during fights now, beside the boss bar, as in the mockup.
local hudFrames = {} -- (hidden while a popup is open)
local SIDE_MARGIN = 30 -- design px from the right edge
local SIDE_GAP = 165 -- design px between the buttons' centres
for i, b in { { "Shop", 128, 140 }, { "Index", 128, 137 }, { "Rebirth", 132, 146 } } do
	local img = image(root, b[1], {
		button = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -SIDE_MARGIN - (132 - b[2]) / 2, 0.5, (i - 2) * SIDE_GAP),
		Size = UDim2.fromOffset(b[2], b[3]),
	})
	bouncy(img)
	img.Activated:Connect(function()
		Popups.toggle(b[1])
	end)
	table.insert(hudFrames, img)
end

-- the Backpack button (QM, Oct 25), bottom centre: opens client/Backpack
do
	local img = image(root, "Backpack", {
		button = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(173, 149),
	})
	if img.Image == "" then
		text(img, {
			Text = "Backpack",
			TextSize = 40,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 50),
		})
	end
	bouncy(img)
	img.Activated:Connect(function()
		Popups.toggle("Backpack")
	end)
	table.insert(hudFrames, img)
end

-- counters
local counters = {}
for i, name in { "Power", "Cash" } do
	local row = image(root, name, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -8 - (2 - i) * 103),
		Size = UDim2.fromOffset(411, 103),
	})
	table.insert(hudFrames, row)
	counters[name] = text(row, {
		Name = "Value",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 136, 0.5, 0),
		Size = UDim2.fromOffset(270, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "0",
	})
end
local function count(name)
	counters[name].Text = Hud.abbreviate(player:GetAttribute(name))
	player:GetAttributeChangedSignal(name):Connect(function()
		counters[name].Text = Hud.abbreviate(player:GetAttribute(name))
	end)
end
count("Power")
count("Cash")

Popups.abbreviate = Hud.abbreviate
Popups.init(root, hudFrames)
require(script.Parent.Backpack).init()
require(script.Parent.Hotbar).init(root, hudFrames) -- (stolen eggs, right of the Backpack button)
gui.Parent = player:WaitForChild("PlayerGui")
-- (no Roblox health bar in the top right: QM, Oct 25)
task.spawn(function()
	for _ = 1, 10 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) then
			return
		end
		task.wait(1)
	end
end)

-- the boss bar follows the nearest living, awake boss within BAR_RANGE
local BAR_RANGE = 260
local shown = 1 -- the red's width
local history = {} -- { { os.clock(), red width }, ... } over the last TRAIL_LAG seconds
local following = nil
local filling = 0 -- (os.clock() the bar started filling up from empty)
RunService.RenderStepped:Connect(function(dt)
	local folder = workspace:FindFirstChild("Bosses")
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	local best, bestDist = nil, math.huge
	if folder and me then
		for _, body in folder:GetChildren() do
			-- (awake ones close enough to matter: the arenas' sleeping bosses don't count)
			if body:IsA("BasePart") and (body:GetAttribute("Health") or 0) > 0 and not body:GetAttribute("Asleep") then
				local d = (body.Position - me.Position).Magnitude
				if d < bestDist and d < BAR_RANGE then
					best, bestDist = body, d
				end
			end
		end
	end
	bar.Visible = best ~= nil and not Popups.isOpen()
	if not best then
		following = nil
		return
	end
	local fraction = math.clamp(best:GetAttribute("Health") / best:GetAttribute("MaxHealth"), 0, 1)
	local now = os.clock()
	if best ~= following then
		following = best
		shown = 0
		filling = now
		table.clear(history)
		bossName.Text = string.upper(best:GetAttribute("Name") or best:GetAttribute("Kind") or "Boss")
	end
	if now - filling < FILL_IN then
		-- (a new fight: up from empty, easing out, to its health)
		local t = (now - filling) / FILL_IN
		shown = fraction * (1 - (1 - t) ^ 3)
		table.clear(history)
	else
		shown += (fraction - shown) * (1 - math.exp(-dt * BAR_EASE))
	end
	clip.Size = UDim2.fromScale(shown, 1)

	-- the trail: the red's width TRAIL_LAG seconds ago (the oldest sample not newer)
	table.insert(history, { now, shown })
	local lagged = history[1][2]
	while #history > 1 and history[2][1] <= now - TRAIL_LAG do
		table.remove(history, 1)
		lagged = history[1][2]
	end
	-- (only the stretch the red has left behind: cropped from the left at the red's edge, so
	-- it never sits under the red, and it's gone when they meet; QM, Oct 25)
	local from, to = shown, math.max(lagged, shown)
	trailClip.Position = UDim2.fromScale(from, 0)
	trailClip.Size = UDim2.fromScale(to - from, 1)
	trailImage.Position = UDim2.fromOffset(-from * 646, 0)
end)

return Hud
