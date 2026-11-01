-- Pen pets' overhead UI (QM, Nov 1: LassoAPet's PetPlates and pay popups, 1:1).
-- Near a pen pet, yours or anyone's, a nameplate floats over it: its rarity (Shared/RarityLook),
-- the cash it earns a second and its speed. Only the nearest few within Config.PetPlate.Reach
-- get one. Each time your pets pay (the server's PetIncome, Server/PetInventory) every one of
-- yours without its plate up pops "+$N" over its head, following it as it rises and fades.
-- Tuning in Config.PetPlate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abbrev = require(Shared:WaitForChild("Abbrev"))
local Config = require(Shared:WaitForChild("Config"))
local Passes = require(Shared:WaitForChild("Passes"))
local Pets = require(Shared:WaitForChild("Pets"))
local RarityLook = require(Shared:WaitForChild("RarityLook"))
local HudImages = require(script.Parent.HudImages)

local player = Players.LocalPlayer
local C = Config.PetPlate
local WIDTH = C.Height * 300 / 125
local TALL = C.Height * 1.45 -- studs: the plate's height with the cash line between them
local CASH = Color3.fromRGB(0, 255, 0) -- (Cash's green: client/Hud)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local CHECK = 0.1 -- seconds between looks round
local POPUP_ICON, POPUP_TEXT = 34, 30 -- px
local POPUP_OUTLINE = 3 -- px

local folder = Instance.new("Folder")
folder.Name = "PetPlates"
folder.Parent = workspace

local plates = {} -- [body] = { board, scale, rarity, cash, speed, key, on }

local function text(parent, size, position, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = size
	label.Position = position
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function build(body)
	local board = Instance.new("BillboardGui")
	board.Name = "PetPlate"
	-- (twice as wide as the plate, which sits in its middle, so a long line isn't cut off)
	board.Size = UDim2.fromScale(WIDTH * 2, TALL)
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.Enabled = false
	board.Adornee = body
	local plate = Instance.new("Frame")
	plate.BackgroundTransparency = 1
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.fromScale(0.5, 1)
	plate.Parent = board
	local scale = Instance.new("UIScale")
	scale.Parent = plate
	local p = {
		board = board,
		scale = scale,
		rarity = text(plate, UDim2.fromScale(2, 0.41), UDim2.fromScale(0.5, 0.2), Color3.new(1, 1, 1)),
		cash = text(plate, UDim2.fromScale(2, 0.32), UDim2.fromScale(0.5, 0.555), CASH),
		speed = text(plate, UDim2.fromScale(2, 0.37), UDim2.fromScale(0.5, 0.83), Color3.new(1, 1, 1)),
	}
	board.Parent = folder
	plates[body] = p
	body.Destroying:Once(function()
		board:Destroy()
		plates[body] = nil
	end)
	return p
end

-- cash a second this pet pays its owner (as Server/PetInventory.income)
local function earns(body, kind)
	local owner = Players:GetPlayerByUserId(body:GetAttribute("Owner") or 0)
	local rebirths = owner and owner:GetAttribute("Rebirths") or 0
	return (Config.Pets[kind].Cash or 0) * (1 + Config.Rebirth.CashBonus * rebirths) * Passes.mult(owner, "Cash")
end

-- still jumping out of its egg (client/BossView)
local function hatching(body)
	local pop = body:GetAttribute("HatchPop")
	return pop ~= nil and workspace:GetServerTimeNow() < pop + Config.Hatch.JumpTime
end

local function show(body, kind)
	local p = plates[body] or build(body)
	local stats = Pets.stats(kind)
	local cash = earns(body, kind)
	local key = kind .. "/" .. cash
	if p.key ~= key then
		p.key = key
		RarityLook.paint(p.rarity, stats.Rarity)
		p.cash.Text = "$" .. Abbrev(cash) .. "/s"
		p.speed.Text = Abbrev(stats.Speed) .. "m/s"
	end
	local grow = C.TierGrowth ^ ((Config.Pets[kind].Tier or 1) - 1)
	p.board.Size = UDim2.fromScale(WIDTH * 2 * grow, TALL * grow)
	p.board.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + C.Above + TALL * grow / 2, 0)
	if not p.on then
		p.on = true
		p.board.Enabled = true
		p.scale.Scale = 0.3
		TweenService:Create(p.scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local candidates = {}
local untilCheck = 0
RunService.Heartbeat:Connect(function(dt)
	untilCheck -= dt
	if untilCheck > 0 then
		return
	end
	untilCheck = CHECK
	table.clear(candidates)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local bodies = workspace:FindFirstChild("PenPets")
	if root and bodies and not player:GetAttribute("EggPromptUp") and not player:GetAttribute("Tutorial") then
		for _, body in bodies:GetChildren() do
			local kind = body:GetAttribute("Model")
			if kind and Config.Pets[kind] and not hatching(body) then
				local d = Vector2.new(body.Position.X - root.Position.X, body.Position.Z - root.Position.Z).Magnitude
				if d <= (if plates[body] and plates[body].on then C.Leave else C.Reach) then
					table.insert(candidates, { body = body, kind = kind, d = d })
				end
			end
		end
		table.sort(candidates, function(a, b)
			return a.d < b.d
		end)
	end
	local keep = {}
	for i = 1, math.min(#candidates, C.Most) do
		local c = candidates[i]
		keep[c.body] = true
		show(c.body, c.kind)
	end
	for body, p in plates do
		if p.on and not keep[body] then
			p.on = false
			p.board.Enabled = false
		end
	end
end)

local function popupIcon(parent, color, size, z)
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = HudImages.CashGainIcon or ""
	icon.ImageColor3 = color
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(size, size)
	icon.ZIndex = z
	icon.Parent = parent
	return icon
end

-- "+$N" over `body`: pops in, rises a few studs and fades
local depth = 0
local function popup(body, amount)
	local height = body.Size.Y / 2 + 1
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(200, 80)
	board.Adornee = body
	board.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	depth = (depth + 1) % 400
	board.StudsOffset = Vector3.new(0, 0, depth * 0.005) -- (each a hair nearer the camera: overlapping ones don't z-fight)
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.MaxDistance = C.PopupDistance
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.XY
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, -POPUP_ICON * 0.2)
	layout.Parent = row
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(POPUP_ICON, POPUP_ICON)
	holder.Parent = row
	local outline = popupIcon(holder, Color3.new(0, 0, 0), POPUP_ICON + 2 * POPUP_OUTLINE, 1)
	local icon = popupIcon(holder, Color3.new(1, 1, 1), POPUP_ICON, 2)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = POPUP_TEXT
	label.TextColor3 = CASH
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, POPUP_ICON)
	label.LayoutOrder = 1
	label.ZIndex = 3 -- (the text overlaps the icon's edge, drawn on top)
	label.Text = "+$" .. Abbrev(amount)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = POPUP_OUTLINE
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = row
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = row
	board.Parent = folder

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(board, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, height + 3, 0),
	}):Play()
	task.delay(0.65, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(icon, fade, { ImageTransparency = 1 }):Play()
		TweenService:Create(outline, fade, { ImageTransparency = 1 }):Play()
	end)
	task.delay(1.05, function()
		board:Destroy()
	end)
end

task.spawn(function()
	ReplicatedStorage:WaitForChild("PetIncome").OnClientEvent:Connect(function()
		local bodies = workspace:FindFirstChild("PenPets")
		local camera = workspace.CurrentCamera
		if not (bodies and camera) then
			return
		end
		for _, body in bodies:GetChildren() do
			local kind = body:GetAttribute("Model")
			local p = plates[body]
			if body:GetAttribute("Owner") == player.UserId and kind and Config.Pets[kind] and not (p and p.on) and not hatching(body)
				and (body.Position - camera.CFrame.Position).Magnitude <= C.PopupDistance then
				local amount = earns(body, kind)
				if amount > 0 then
					popup(body, amount)
				end
			end
		end
	end)
end)

return nil
