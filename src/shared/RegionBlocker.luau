-- A region's blocker (QM, Oct 25), built into the map at its gate (Server/Map), so it's
-- there in Studio: a solid navy wall (WorldColors RegionBarrier: the map editor's Colours
-- list) filling the opening, on both
-- its faces the region's name, a coin and its price (400K) and a green Buy button, and a
-- shadow in the same navy across the floor either side, fading out over
-- Config.Regions.Shadow studs.
-- client/Regions hides it for a player who owns the region and wires up the Buy buttons.
-- A training ground's (QM, Oct 30: its marker's Training attribute) is the same wall across
-- its corridor, "<name> Training" and Config.Training.Grounds' Cost; the player owns it
-- with Train<Name> instead of Region<Name> (the model's Owns attribute says which).
--
--   RegionBlocker.build(marker, groundAt) -> Model   (marker: the gate's Part; groundAt(x, z) -> floor top)

local Config = require(script.Parent.Config)

local RegionBlocker = {}

local REGIONS = Config.Regions
local COIN = "rbxassetid://128139739160102" -- assets/ui/CashIcon.png: the HUD's cash, cropped
local PIXELS = 10 -- the faces: pixels per stud (text stops at 100 pixels: 10 studs)
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local INK = Color3.fromRGB(14, 12, 16)

RegionBlocker.abbreviate = require(script.Parent.Abbrev).format

local function text(parent, props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextColor3 = Color3.new(1, 1, 1)
	-- (Roblox stops TextSize at 100: bigger text scales to fill its label instead)
	local size = props.TextSize or 36
	props.TextSize = math.min(size, 100)
	for k, v in props do
		label[k] = v
	end
	label.TextScaled = size > 100
	local s = Instance.new("UIStroke")
	s.Thickness = math.max(2, size / 12)
	s.Color = INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	label.Parent = parent
	return label
end

-- QM's Buy button art (assets/ui/BuyButton.png: green, outlined, "Buy" drawn in)
local BUY = "rbxassetid://137022984457520"
local function button(parent, props)
	local b = Instance.new("ImageButton")
	b.Name = "Buy"
	b.Image = BUY
	b.BackgroundTransparency = 1
	b.ScaleType = Enum.ScaleType.Fit
	b.AutoButtonColor = false
	for k, v in props do
		b[k] = v
	end
	Instance.new("UIScale").Parent = b
	b.Parent = parent
	return b
end

local function face(wall, normalId, title, cost)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face" .. normalId.Name
	gui.Face = normalId
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- (a narrow wall, a training corridor's: drawn finer, so its price and button fit)
	local pixels = if wall.Size.X * PIXELS < 400 then PIXELS * 1.6 else PIXELS
	gui.PixelsPerStud = pixels
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	-- (and a name too long for it wraps and shrinks to fit)
	local narrow = wall.Size.X * pixels < #title * 60 + 40
	local name = text(list, {
		Text = title,
		TextSize = if narrow then 101 else 100,
		Size = if narrow then UDim2.new(1, -24, 0, 170) else UDim2.new(1, 0, 0, 110),
		LayoutOrder = 1,
	})
	name.TextWrapped = narrow
	if narrow then
		name:FindFirstChildOfClass("UIStroke").Thickness = 5
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 80)
	row.LayoutOrder = 2
	row.Parent = list
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row
	local coin = Instance.new("ImageLabel")
	coin.BackgroundTransparency = 1
	coin.Image = COIN
	coin.ScaleType = Enum.ScaleType.Fit
	coin.Size = UDim2.fromOffset(80, 80)
	coin.LayoutOrder = 1
	coin.Parent = row
	text(row, {
		Text = RegionBlocker.abbreviate(cost),
		TextSize = 80,
		Size = UDim2.fromOffset(#RegionBlocker.abbreviate(cost) * 52, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
	})
	button(list, { Size = UDim2.fromOffset(240, 89), LayoutOrder = 3 })
	gui.Parent = wall
end

-- a flat band of navy from p0 (solid) to p1 (gone), `width` wide along `across`
local function shade(holder, p0, p1, width, across)
	local dir = (p1 - p0).Unit
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	-- (a beam's width runs along its attachments' UpVector)
	a0.CFrame = holder.CFrame:ToObjectSpace(CFrame.fromMatrix(p0, dir, across))
	a1.CFrame = holder.CFrame:ToObjectSpace(CFrame.fromMatrix(p1, dir, across))
	a0.Parent, a1.Parent = holder, holder
	local beam = Instance.new("Beam")
	beam.Name = "Shadow"
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = width, width
	beam.FaceCamera = false
	beam.Segments = 1
	beam:SetAttribute("ColorKey", "RegionBarrier")
	beam.Color = ColorSequence.new(Config.WorldColors.RegionBarrier)
	beam.Transparency = NumberSequence.new(0, 1)
	beam.LightInfluence = 0
	beam.Parent = a0
end

function RegionBlocker.build(marker, groundAt)
	local region = marker:GetAttribute("Region")
	local training = marker:GetAttribute("Training") == true
	local ground = training and Config.Training.Grounds[region]
	local cost = if training then ground and ground.Cost else REGIONS.Cost[region]
	if not cost or cost <= 0 then
		return nil
	end
	local title = REGIONS.Names[region] or region
	local model = Instance.new("Model")
	model.Name = region .. (if training then "TrainingBlocker" else "Blocker")
	model:SetAttribute("Region", region)
	model:SetAttribute("Training", training or nil)
	model:SetAttribute("Owns", (if training then "Train" else "Region") .. region) -- (the player attribute that opens it)
	if training then
		title ..= " Training"
	end
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Anchored = true
	wall.CanCollide = true
	wall.CastShadow = false
	wall.Size = marker.Size
	wall.CFrame = marker.CFrame
	wall:SetAttribute("ColorKey", "RegionBarrier")
	wall.Color = Config.WorldColors.RegionBarrier
	wall.Material = Enum.Material.SmoothPlastic
	wall.TopSurface, wall.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	wall.Locked = true
	wall.Parent = model
	face(wall, Enum.NormalId.Front, title, cost)
	face(wall, Enum.NormalId.Back, title, cost)
	-- the shadow: over the floor either side (QM: the floor only)
	local cf, size = wall.CFrame, wall.Size
	local right, out = cf.RightVector, cf.LookVector
	local len = REGIONS.Shadow
	local centre = cf.Position
	for _, side in { 1, -1 } do
		local n = out * side
		local at = centre + n * (size.Z / 2)
		local y = groundAt(at.X + n.X * 2, at.Z + n.Z * 2)
		local p0 = Vector3.new(at.X, y + 0.06, at.Z)
		shade(wall, p0, p0 + n * len, size.X, right)
	end
	return model
end

return RegionBlocker
