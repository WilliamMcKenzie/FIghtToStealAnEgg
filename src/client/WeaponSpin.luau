-- The weapon spin when a boss dies (QM, Oct 25, in the style of QM's screenshots), and the
-- weapon chip that switches between the weapons you own.
--
-- The spin: weapons flick past one at a time in the middle of the screen, big and
-- glowing, slowing down until one lands (the server picked it: Server/Arsenal). Behind
-- the weapon a burst of light rays turns, in its rarity's colour; under it its name in
-- its rarity's colour, outlined black; tilted above-left, its odds as a white "1/N";
-- white streaks either side kick out on every flick. A boss's own super rare weapon
-- brings up the BONUS badge (orange text on a dark oval) whenever it's on show.
-- It lands with a pop, stays up Config.WeaponDrops.Show seconds and shrinks away. Spins
-- that arrive during one wait their turn.
--
-- The chip (bottom right, until the backpack comes: QM, TBD): the weapon you hold, its
-- name and type; click it for the next weapon you own (EquipWeapon).
--
-- Also hands /spin and /weapon on to the server (SpinRequest, WeaponRequest).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons.Weapons)
local WeaponIcons = require(Shared.Weapons.WeaponIcons)
local Popups = require(script.Parent.Popups)

local player = Players.LocalPlayer

local DESIGN_HEIGHT = 1080
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(14, 12, 16)
local RAYS = 14
local TICK_SOUND = "rbxasset://sounds/clickfast.wav"
local LAND_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = WHITE
	f.BorderSizePixel = 0
	for k, v in props do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function round(parent, scale)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = parent
end

local function fade(parent, keys, rotation)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(keys)
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

local function rarityOf(id)
	local w = Weapons.get(id)
	return Config.Rarities[w.Rarity] or Config.Rarities.Common, w.Rarity
end

local function sound(id, volume, pitch)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = pitch or 1
	s.Parent = SoundService
	s:Play()
	task.delay(2, s.Destroy, s)
end

-- ---- screen ------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponSpin"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 5 -- (over the HUD)
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- (while a spin shows: the screen behind it dimmed and blurred like glass, every other bit
-- of HUD hidden: QM)
local backdrop = frame(gui, {
	Name = "Backdrop",
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 0,
})
local blur = Instance.new("BlurEffect")
blur.Name = "SpinBlur"
blur.Size = 0
blur.Parent = Lighting
local root = frame(gui, { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fit()
	local h = workspace.CurrentCamera.ViewportSize.Y
	uiScale.Scale = h / DESIGN_HEIGHT
	root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
end
fit()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- a weapon in the spin or the chip: its outlined icon (QM, Oct 25: drawn once, Shared/
-- Weapons/WeaponIcons), rocking gently; or, for one without an icon yet, the 3D model in a
-- ViewportFrame, turning slowly, blade tilted like an item icon. Flat, like the held ones
-- (QM, Oct 25): full ambient and no light, so every face shows its colour as it is, and no
-- stud texture (Weapons.flatten)
local function viewport(parent, props)
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = WHITE
	vp.LightColor = Color3.new(0, 0, 0)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in props do
		vp[k] = v
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = parent
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(1, 1)
	icon.Visible = false
	icon.Parent = vp
	local models = {} -- [id] = model (made once each)
	local shown, centre = nil, Vector3.zero
	local view = { frame = vp }
	function view.show(id)
		if shown then
			shown.Parent = nil
			shown = nil
		end
		icon.Visible = WeaponIcons[id] ~= nil
		if WeaponIcons[id] then
			icon.Image = WeaponIcons[id]
			return
		end
		local m = models[id]
		if not m then
			m = Weapons.makeModel(id, 1)
			m:PivotTo(CFrame.identity)
			for _, d in m:GetDescendants() do
				if d:IsA("Texture") or d:IsA("Decal") then
					d:Destroy()
				elseif d:IsA("BasePart") and d.Material ~= Enum.Material.Neon then
					d.Material = Enum.Material.SmoothPlastic
					d.MaterialVariant = ""
					d.Reflectance = 0
				end
			end
			models[id] = m
		end
		m.Parent = vp
		shown = m
		-- (framed by its size, so a dagger and a staff both fill it; it turns round its middle)
		local box, size = m:GetBoundingBox()
		centre = m:GetPivot():PointToObjectSpace(box.Position)
		local r = math.max(size.X, size.Y, size.Z) * 0.5
		local d = r / math.tan(math.rad(cam.FieldOfView / 2)) * 1.1
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0, d), Vector3.zero)
	end
	function view.turn(t)
		icon.Rotation = math.sin(t * 0.8) * 6
		if shown then
			shown:PivotTo(CFrame.Angles(0, 0, math.rad(-40)) * CFrame.Angles(0, t, 0) * CFrame.new(-centre))
		end
	end
	return view
end

-- ---- the spin ----------------------------------------------------------------------

local stage = frame(root, {
	Name = "Stage",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(700, 700),
	Visible = false,
})
local stageScale = Instance.new("UIScale")
stageScale.Parent = stage

-- the burst: rays out from the middle, each a rotated holder with the ray in its top half,
-- bright at the middle and fading to its tip
local burst = frame(stage, {
	Name = "Burst",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
})
local burstScale = Instance.new("UIScale")
burstScale.Parent = burst
local rays = {}
-- (QM's sunburst image, tinted the rarity's colour, once it's uploaded: WeaponDrops.RaysImage)
local raysImage = nil
if Config.WeaponDrops.RaysImage ~= "" then
	raysImage = Instance.new("ImageLabel")
	raysImage.Name = "Rays"
	raysImage.BackgroundTransparency = 1
	raysImage.Image = Config.WeaponDrops.RaysImage
	raysImage.AnchorPoint = Vector2.new(0.5, 0.5)
	raysImage.Position = UDim2.fromScale(0.5, 0.5)
	raysImage.Size = UDim2.fromOffset(680, 680)
	raysImage.Parent = burst
end
for i = 1, if raysImage then 0 else RAYS do
	local long = i % 2 == 1
	local len = if long then 330 else 230
	local holder = frame(burst, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(if long then 54 else 40, len * 2),
		Rotation = (i - 1) * 360 / RAYS,
	})
	local ray = frame(holder, { Size = UDim2.fromScale(1, 0.5), BackgroundTransparency = 0 })
	round(ray)
	fade(ray, { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.75, 0.55), NumberSequenceKeypoint.new(1, 0.25) }, 90)
	table.insert(rays, ray)
end

local item = viewport(stage, {
	Name = "Item",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(340, 340),
})
local itemScale = Instance.new("UIScale")
itemScale.Parent = item.frame

local nameLabel = Popups.text(stage, {
	Name = "WeaponName",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 150),
	Size = UDim2.fromOffset(700, 70),
	TextSize = 64,
	Text = "",
})
nameLabel:FindFirstChildOfClass("UIStroke").Color = Color3.new(0, 0, 0)
local oddsLabel = Popups.text(stage, {
	Name = "Odds",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, -100, 0.5, -110), -- (tucked in at the weapon's top left: QM's ref)
	Size = UDim2.fromOffset(220, 60),
	TextSize = 54,
	Rotation = -14,
	Text = "",
})
oddsLabel.TextColor3 = WHITE -- (white on a black outline: QM)
oddsLabel:FindFirstChildOfClass("UIStroke").Color = Color3.new(0, 0, 0)

-- the streaks: white, bright at the end nearest the middle
local streaks = {}
for _, side in { -1, 1 } do
	local s = frame(stage, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, side * 290, 0.5, 0),
		Size = UDim2.fromOffset(150, 12),
	})
	round(s)
	-- (left one: clear at its left end; right one: clear at its right end)
	fade(s, { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }, if side < 0 then 0 else 180)
	streaks[side] = s
end

-- BONUS: orange text on a dark oval with a pale rim
local bonus = frame(stage, {
	Name = "Bonus",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, -235),
	Size = UDim2.fromOffset(330, 140),
	BackgroundColor3 = Color3.fromRGB(24, 26, 44),
	Visible = false,
})
round(bonus)
local bonusBack = Instance.new("UIGradient")
bonusBack.Color = Popups.ramp(Color3.fromRGB(30, 32, 56))
bonusBack.Rotation = 90
bonusBack.Parent = bonus
local rim = Instance.new("UIStroke")
rim.Color = Color3.fromRGB(220, 226, 255)
rim.Thickness = 5
rim.Transparency = 0.25
rim.Parent = bonus
local bonusText = Popups.text(bonus, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1.1, 1),
	TextSize = 92,
	Text = "BONUS",
})
bonusText:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(90, 30, 8)
bonusText:FindFirstChildOfClass("UIStroke").Thickness = 7
bonusText.TextColor3 = Color3.fromRGB(255, 170, 70) -- (solid, no gradient: QM)
local bonusScale = Instance.new("UIScale")
bonusScale.Parent = bonus

local current = nil -- the spin playing: { odds, ... }
local spinT = 0

local function raysColour(c)
	if raysImage then
		raysImage.ImageColor3 = c
	end
	for _, ray in rays do
		ray.BackgroundColor3 = c
	end
end
local function raysFade(t, transparency)
	if raysImage then
		if t > 0 then
			tween(raysImage, t, { ImageTransparency = transparency })
		else
			raysImage.ImageTransparency = transparency
		end
	end
	for _, ray in rays do
		if t > 0 then
			tween(ray, t, { BackgroundTransparency = transparency })
		else
			ray.BackgroundTransparency = transparency
		end
	end
end

local function showItem(id, odds, landed)
	local r = rarityOf(id)
	local w = Weapons.get(id)
	item.show(id)
	nameLabel.Text = w.Name
	-- (its rarity's colour, a little softer: QM)
	nameLabel.TextColor3 = r.Fill:Lerp(WHITE, 0.3)
	oddsLabel.Text = "1/" .. tostring(odds[id] or 1)
	raysColour(r.Fill)
	local isBonus = w.Boss ~= nil
	if isBonus and not bonus.Visible then
		bonusScale.Scale = 0.6
		tween(bonusScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	bonus.Visible = isBonus
	-- the flick: the weapon pops, the streaks kick out and settle
	itemScale.Scale = if landed then 1.45 else 1.14
	tween(itemScale, if landed then 0.45 else 0.12, { Scale = 1 }, if landed then Enum.EasingStyle.Back else Enum.EasingStyle.Quad)
	for side, s in streaks do
		s.Position = UDim2.new(0.5, side * 250, 0.5, 0)
		tween(s, 0.16, { Position = UDim2.new(0.5, side * 290, 0.5, 0) })
	end
end

local queue = {}
local playing = false

local hidden = {} -- what dim(true) hid, to put back
local CORE = { Enum.CoreGuiType.PlayerList, Enum.CoreGuiType.Chat, Enum.CoreGuiType.EmotesMenu }
local function dim(on)
	if on then
		backdrop.Visible = true
		backdrop.BackgroundTransparency = 1
		tween(backdrop, 0.25, { BackgroundTransparency = 0.7 }) -- (black at 30%)
		tween(blur, 0.25, { Size = 16 })
		hidden = { guis = {}, core = {} }
		for _, g in player:WaitForChild("PlayerGui"):GetChildren() do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hidden.guis, g)
			end
		end
		for _, kind in CORE do
			local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, kind)
			if ok and was then
				pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, false)
				table.insert(hidden.core, kind)
			end
		end
	else
		tween(backdrop, 0.22, { BackgroundTransparency = 1 })
		tween(blur, 0.22, { Size = 0 })
		task.delay(0.22, function()
			if not playing then
				backdrop.Visible = false
			end
		end)
		for _, g in hidden.guis or {} do
			if g.Parent then
				g.Enabled = true
			end
		end
		for _, kind in hidden.core or {} do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, kind, true)
		end
		hidden = {}
	end
end

local function play(data)
	playing = true
	local d = Config.WeaponDrops
	local reel = data.reel
	current = data
	spinT = 0
	if not backdrop.Visible or backdrop.BackgroundTransparency > 0.95 then
		dim(true)
	end
	stage.Visible = true
	stageScale.Scale = 0.3
	tween(stageScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	raysFade(0, 0.35)
	burstScale.Scale = 0.85
	-- flicks spaced further and further apart, adding up to SpinTime
	local n = #reel - 1
	local growth = 1.12
	local first = d.SpinTime * (growth - 1) / (growth ^ n - 1)
	for i, id in reel do
		local landed = i == #reel
		showItem(id, data.odds, landed)
		if landed then
			sound(LAND_SOUND, 0.6, 1)
			tween(burstScale, 0.4, { Scale = 1.25 }, Enum.EasingStyle.Back)
			raysFade(0.3, 0)
			if data.bonus then
				bonusScale.Scale = 1.5
				tween(bonusScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		else
			sound(TICK_SOUND, 0.35, 0.9 + 0.4 * i / n)
			task.wait(first * growth ^ (i - 1))
		end
	end
	task.wait(d.Show)
	tween(stageScale, 0.22, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	task.wait(0.24)
	stage.Visible = false
	current = nil
	playing = false
	if #queue == 0 then
		dim(false)
	end
	if #queue > 0 then
		task.spawn(play, table.remove(queue, 1))
	end
end

ReplicatedStorage:WaitForChild("WeaponSpin").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or type(data.reel) ~= "table" or #data.reel == 0 then
		return
	end
	if playing then
		table.insert(queue, data)
	else
		task.spawn(play, data)
	end
end)

-- ---- the weapon chip ---------------------------------------------------------------

local chip = Instance.new("ImageButton")
chip.Name = "WeaponChip"
chip.BackgroundTransparency = 1
chip.Image = ""
chip.AnchorPoint = Vector2.new(1, 1)
chip.Position = UDim2.new(1, -24, 1, -24)
chip.Size = UDim2.fromOffset(330, 104)
chip.Parent = root
Popups.card(chip, { Size = UDim2.fromScale(1, 1), Active = false })
local chipItem = viewport(chip, {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 8, 0.5, 0),
	Size = UDim2.fromOffset(92, 92),
})
local chipName = Popups.text(chip, {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(108, 14),
	Size = UDim2.fromOffset(212, 40),
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextScaled = true,
	Text = "",
})
local chipInfo = Popups.text(chip, {
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.fromOffset(108, 56),
	Size = UDim2.fromOffset(212, 30),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "",
})
local chipStroke = chipInfo:FindFirstChildOfClass("UIStroke")
local chipScale = Instance.new("UIScale")
chipScale.Parent = chip

local function owned()
	local list = {}
	for id in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		if Weapons.exists(id) then
			table.insert(list, id)
		end
	end
	if #list == 0 then
		list = { Config.WeaponDrops.Start }
	end
	return list
end

local function refreshChip()
	local id = player:GetAttribute("Weapon") or Config.WeaponDrops.Start
	if not Weapons.exists(id) then
		id = Config.WeaponDrops.Start
	end
	local w = Weapons.get(id)
	local r = rarityOf(id)
	local list = owned()
	chipItem.show(id)
	chipName.Text = w.Name
	chipInfo.Text = string.upper(w.Type)
		.. (if #list > 1 then "  ·  " .. (table.find(list, id) or 1) .. "/" .. #list else "")
	chipInfo.TextColor3 = r.Fill
	chipStroke.Color = r.Stroke
end
player:GetAttributeChangedSignal("Weapon"):Connect(refreshChip)
player:GetAttributeChangedSignal("Weapons"):Connect(refreshChip)
refreshChip()

local equipRemote = ReplicatedStorage:WaitForChild("EquipWeapon")
chip.Activated:Connect(function()
	local list = owned()
	if #list < 2 then
		return
	end
	local i = table.find(list, player:GetAttribute("Weapon")) or 0
	equipRemote:FireServer(list[i % #list + 1])
	chipScale.Scale = 0.92
	tween(chipScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end)
chip.MouseEnter:Connect(function()
	tween(chipScale, 0.15, { Scale = 1.05 }, Enum.EasingStyle.Back)
end)
chip.MouseLeave:Connect(function()
	tween(chipScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
end)

RunService.RenderStepped:Connect(function(dt)
	chip.Visible = not Popups.isOpen() and not stage.Visible
	chipItem.turn(os.clock() * 0.8)
	if current then
		spinT += dt
		burst.Rotation = spinT * 25
		item.turn(spinT * 1.6)
	end
end)

-- /spin, /rng, /weapon, /swords, /staffs, /bows, /cash and /reset (TextChatService runs a command's Triggered where it's typed: pass it on)
task.spawn(function()
	local commands = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	for _, name in { "Spin", "Rng", "Weapon", "Swords", "Staffs", "Bows", "Cash", "Reset" } do
		local command = commands:WaitForChild(name .. "Command", 10)
		local request = ReplicatedStorage:WaitForChild(name .. "Request", 10)
		if command and request then
			command.Triggered:Connect(function(_source, text)
				request:FireServer(text)
			end)
		end
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

return {}
