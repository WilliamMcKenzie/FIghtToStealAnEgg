-- The Backpack (QM, Oct 25, in the style of QM's reference): a popup with two tabs on its
-- left, Pets and Weapons. Each shows what's equipped in a row at the top and everything
-- else you own in a grid below, duplicates stacked into one tile with "x5" top right and
-- the odds of getting it ("1/57", in its rarity's colour) bottom right. Equipping one
-- moves it up into the row (so its tile's count drops by one, and goes once none are
-- left). SORT switches between rarity and name; EQUIP BEST fills the row with the best.
--
--   Pets: the ones in the row wander in your pen (Config.Backpack.PenSlots of them).
--         Click a pet below to put it in, one in the row to take it out (PetEquip,
--         Server/PetInventory). Best = the most cash a second.
--   Weapons: the row is the one you hold. Click another to hold it instead (EquipWeapon,
--         Server/Arsenal). Best = the rarest, then the most damage.
--
-- Hovering a tile shows its name and details over the row.
--
-- In Studio it's StarterGui > Hud > Root > BackpackPopup (client/Ui): the tiles are copied
-- from Grid > TileTemplate and Equipped > EquippedTemplate / EmptyTemplate, so edit those.
--
--   Backpack.init()   -- once, from Hud, after Popups.init (Popups.toggle("Backpack") opens it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PetIcons = require(Shared.PetIcons)
local Pets = require(Shared.Pets)
local Stacks = require(Shared.Stacks)
local Power = require(Shared.Power)
local Weapons = require(Shared.Weapons.Weapons)
local WeaponIcons = require(Shared.Weapons.WeaponIcons)
local Popups = require(script.Parent.Popups)
local Ui = require(script.Parent.Ui)

local Backpack = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local SOFT = Color3.fromRGB(200, 200, 212)
local BLUE = Color3.fromRGB(64, 150, 255)
local RED_TEXT = Color3.fromRGB(255, 110, 110)
local RANK = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
local SIZE = Vector2.new(1180, 780)
local CELL = Vector2.new(160, 160)
local SLOT = 140
-- (the layout inside the panel, top down: the header, the equipped row, the line, the grid)
local HEADER_Y = 22
local ROW_Y = 84
local LINE_Y = ROW_Y + SLOT + 26
local GRID_Y = LINE_Y + 18
local SIDE = 28 -- (margin either side of the row's line and the grid)

local function rarityColors(rarity)
	return Config.Rarities[rarity] or Config.Rarities.Common
end

local function tween(obj, t, goal, style)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- ---- what each tab lists ------------------------------------------------------------

-- one in 1/N: a pet's odds in the egg it hatches from (the likeliest one), a weapon's in a
-- boss's spin; nil when there's no chance to show (a starting weapon, a Robux pet)
local function petOdds(kind)
	local best = nil
	for _, pool in Config.Eggs.Kinds do
		local w = pool[kind]
		if w and w > 0 then
			local total = 0
			for _, v in pool do
				total += v
			end
			local n = math.max(1, math.round(total / w))
			best = if best then math.min(best, n) else n
		end
	end
	return if best and best > 1 then best else nil
end

local function weaponOdds(id)
	local w = Config.Weapons[id]
	if not (w and w.Weight and w.Weight > 0) then
		return nil
	end
	local total = 0
	for _, entry in Weapons.drops(w.Boss) do
		total += entry.weight
	end
	return math.max(1, math.round(total / w.Weight))
end

-- a weapon's damage a second at your Strength: each hit (Server/Combat) x shots per attack,
-- over its cooldown (Strength attacks faster too: Power.speed)
local function dps(id)
	local w = Weapons.get(id)
	local strength = player:GetAttribute("Strength")
	local hit = Config.Slash.Damage * Power.damage(strength) * (w.Damage or 1)
	local count = if w.Shot then w.Shot.Count or 1 else 1
	return hit * count * Power.speed(strength) / math.max(Weapons.cooldown(id), 0.05)
end

local TABS = {}

TABS.Pets = {
	slots = function()
		return Config.Backpack.PenSlots
	end,
	owned = function()
		return Stacks.parse(player:GetAttribute("PetsOwned"), function(kind)
			return Config.Pets[kind] ~= nil
		end)
	end,
	equipped = function()
		local list = {}
		for kind in string.gmatch(player:GetAttribute("PenPets") or "", "[^,]+") do
			if Config.Pets[kind] then
				table.insert(list, kind)
			end
		end
		return list
	end,
	rarity = function(kind)
		return Config.Pets[kind].Rarity
	end,
	score = function(kind)
		return Config.Pets[kind].Cash or 0
	end,
	name = Pets.name,
	odds = petOdds,
	detail = function(kind)
		local p = Config.Pets[kind]
		return string.format("%s  •  %s  •  %s Cash/s", Pets.name(kind), p.Rarity, Popups.abbreviate(p.Cash or 0))
	end,
	header = function(equipped)
		local cash = 0
		for _, kind in equipped do
			cash += Config.Pets[kind].Cash or 0
		end
		return string.format(
			"%d/%d In Your Pen  •  %s Cash/s",
			#equipped,
			Config.Backpack.PenSlots,
			Popups.abbreviate(cash)
		)
	end,
	empty = "No pets yet! Steal eggs to get some.",
	attributes = { "PetsOwned", "PenPets" },
}

TABS.Weapons = {
	slots = function()
		return 1
	end,
	owned = function()
		local list = Stacks.parse(player:GetAttribute("Weapons"), Weapons.exists)
		local start = Config.WeaponDrops.Start
		if Stacks.count(list, start) == 0 then
			table.insert(list, 1, { id = start, n = 1 })
		end
		return list
	end,
	equipped = function()
		local id = player:GetAttribute("Weapon")
		return { if Weapons.exists(id) then id else Config.WeaponDrops.Start }
	end,
	rarity = function(id)
		return Config.Weapons[id].Rarity
	end,
	score = function(id)
		return Weapons.get(id).Damage or 0
	end,
	name = function(id)
		return Weapons.get(id).Name
	end,
	odds = weaponOdds,
	detail = function(id)
		local w = Weapons.get(id)
		return string.format("%s  •  %s DPS", w.Name, Popups.abbreviate(math.round(dps(id))))
	end,
	header = function(equipped)
		local id = equipped[1]
		return string.format("%s  •  %s DPS", Weapons.get(id).Name, Popups.abbreviate(math.round(dps(id))))
	end,
	empty = "Beat bosses to win weapons!",
	attributes = { "Weapons", "Weapon" },
}

-- ---- icons ----------------------------------------------------------------------------

-- a pet, standing three-quarters on in a ViewportFrame (one model per kind, cloned)
local petModels = {}
local function petModel(kind)
	if not petModels[kind] then
		local ok, horse = pcall(function()
			return Pets.class(kind).new()
		end)
		petModels[kind] = if ok and horse then horse.model else false
	end
	return petModels[kind] and petModels[kind]:Clone()
end

-- the item's picture in `img` (a tile's Icon): its icon, or (when there's none yet) its
-- model in a viewport over where the Icon is
local function icon(img, tab, id)
	local image = if tab == "Weapons" then WeaponIcons[id] else PetIcons.Pets[id]
	if image then
		img.Image = image
		img.Visible = true
		return
	end
	img.Visible = false
	if not Ui.live then
		return
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Model"
	vp.BackgroundTransparency = 1
	vp.AnchorPoint = img.AnchorPoint
	vp.Position = img.Position
	vp.Size = UDim2.new(img.Size.X.Scale * 1.1, img.Size.X.Offset, img.Size.Y.Scale * 1.1, img.Size.Y.Offset)
	vp.ZIndex = img.ZIndex
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = WHITE
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vp
	vp.CurrentCamera = cam
	local model = if tab == "Pets" then petModel(id) else Weapons.makeModel(id, 1)
	if model then
		model.Parent = vp
		local box, size = model:GetBoundingBox()
		local r = size.Magnitude * 0.5
		local d = r / math.tan(math.rad(cam.FieldOfView / 2)) * 0.95
		-- (pets face -Z: seen from in front, a little to the side and above)
		local from = Vector3.new(0.75, 0.45, -1).Unit
		cam.CFrame = CFrame.lookAt(box.Position + from * d, box.Position)
	end
	vp.Parent = img.Parent
end

local function iconLabel(parent, props)
	local img, fresh = Ui.make(parent, "Icon", "ImageLabel")
	if fresh then
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		for k, v in props do
			img[k] = v
		end
	end
	return img
end

-- a tile: the item on a dark card, "x5" top right, its odds bottom right (the template the
-- grid's tiles, and the equipped row's, are copied from)
local function tileTemplate(size)
	return function()
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(size, size)
		local scale = Instance.new("UIScale")
		scale.Name = "Hover"
		scale.Parent = b
		Popups.card(b, { Name = "Card", Size = UDim2.fromScale(1, 1), Active = false })
		iconLabel(b, {
			Image = PetIcons.Pets.Horse or "",
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.78, 0.78),
		})
		Popups.text(b, {
			Name = "Count",
			Text = "x2",
			TextSize = 30,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 6),
			Size = UDim2.new(1, -20, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
		})
		local c = rarityColors("Common")
		local odds = Popups.text(b, {
			Name = "Odds",
			Text = "1/57",
			TextSize = 30,
			TextColor3 = c.Fill,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -4),
			Size = UDim2.new(1, -20, 0, 34),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
		})
		odds:FindFirstChildOfClass("UIStroke").Color = c.Stroke
		return b
	end
end

-- an empty slot in the row: a faded card
local function emptyTemplate()
	local s = Popups.darkPanel(nil, { Size = UDim2.fromOffset(SLOT, SLOT), ImageTransparency = 0.55 }, 0.5)
	Popups.text(s, {
		Name = "Label",
		Text = "Empty",
		TextSize = 26,
		TextColor3 = SOFT,
		TextTransparency = 0.4,
		Size = UDim2.fromScale(1, 1),
	})
	return s
end

-- ---- the popup ------------------------------------------------------------------------

function Backpack.init()
	local body, holder = Popups.frame("Backpack", "Backpack", SIZE, true) -- (QM's tiled panel, Oct 26)
	local tab = "Pets"
	local sortBy = "Rarity"
	local flashUntil = 0
	local rebuild -- (below)
	local fresh
	local petRemote, weaponRemote -- (in Play)

	-- the header: how many are equipped (or the hovered tile's details)
	local header = Popups.text(body, {
		Name = "Header",
		Text = "",
		TextSize = 32,
		Position = UDim2.fromOffset(0, HEADER_Y),
		Size = UDim2.new(1, 0, 0, 40),
	})
	-- (short soft lines either side of it, like QM's reference)
	local dashes = {}
	for side = -1, 1, 2 do
		local d
		d, fresh = Ui.make(body, if side < 0 then "DashLeft" else "DashRight", "Frame")
		if fresh then
			d.BackgroundColor3 = WHITE
			d.BorderSizePixel = 0
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Position = UDim2.new(0.5, side * 150, 0, HEADER_Y + 20)
			d.Size = UDim2.fromOffset(110, 4)
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Parent = d
		end
		dashes[side] = d
	end
	local function placeDashes()
		local half = header.TextBounds.X / 2 + 90
		for side, d in dashes do
			d.Position = UDim2.new(0.5, side * half, d.Position.Y.Scale, d.Position.Y.Offset)
		end
	end
	local headerText = ""
	local function setHeader(text, color)
		header.Text = text
		header.TextColor3 = color or WHITE
		placeDashes()
	end

	-- the equipped row
	local row
	row, fresh = Ui.make(body, "Equipped", "Frame")
	if fresh then
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(0, ROW_Y)
		row.Size = UDim2.new(1, 0, 0, SLOT)
	end
	local rowLayout
	rowLayout, fresh = Ui.make(row, "Layout", "UIListLayout")
	if fresh then
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowLayout.Padding = UDim.new(0, 30)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	end

	-- a soft white line between the row and the grid, fading out at both ends
	local line
	line, fresh = Ui.make(body, "Line", "Frame")
	if fresh then
		line.BackgroundColor3 = WHITE
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, LINE_Y)
		line.Size = UDim2.new(1, -2 * SIDE, 0, 3)
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.35),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = line
	end

	-- the grid of everything else owned
	local gridTop = GRID_Y
	local grid
	grid, fresh = Ui.make(body, "Grid", "ScrollingFrame")
	if fresh then
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.Position = UDim2.fromOffset(SIDE, gridTop)
		grid.Size = UDim2.new(1, -2 * SIDE, 1, -gridTop - 6)
		grid.CanvasSize = UDim2.new()
		grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
		grid.ScrollingDirection = Enum.ScrollingDirection.Y
		grid.ScrollBarThickness = 8
		grid.ScrollBarImageColor3 = WHITE
		grid.ScrollBarImageTransparency = 0.5
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 14)
		pad.PaddingBottom = UDim.new(0, 14)
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = grid
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.Name = "Layout"
		gridLayout.CellSize = UDim2.fromOffset(CELL.X, CELL.Y)
		gridLayout.CellPadding = UDim2.fromOffset(18, 16)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gridLayout.Parent = grid
	end
	local emptyNote = Popups.text(body, {
		Name = "EmptyNote",
		Text = "",
		TextSize = 34,
		TextColor3 = SOFT,
		Position = UDim2.fromOffset(0, gridTop + 120),
		Size = UDim2.new(1, 0, 0, 50),
		Visible = false,
	})
	-- (in Studio: Equipped > EquippedTemplate / EmptyTemplate and Grid > TileTemplate)
	local templates = {
		[row] = Ui.template(row, "EquippedTemplate", tileTemplate(SLOT)),
		[grid] = Ui.template(grid, "TileTemplate", tileTemplate(CELL.X)),
	}
	local emptyOne = Ui.template(row, "EmptyTemplate", emptyTemplate)

	-- SORT and EQUIP BEST, on the panel's top edge beside the X
	local function smallText(button, size)
		local label = button:FindFirstChildOfClass("TextLabel")
		label.TextSize = size
		label:FindFirstChildOfClass("UIStroke").Thickness = 3
	end
	local sortButton, bestButton
	sortButton, fresh = Popups.button(
		holder,
		{
			Name = "Sort",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -370, 0, 6),
			Size = UDim2.fromOffset(250, 66),
			ZIndex = 5,
		},
		"SORT: RARITY",
		Popups.GREEN,
		function()
			sortBy = if sortBy == "Rarity" then "Name" else "Rarity"
			sortButton:FindFirstChildOfClass("TextLabel").Text = "SORT: " .. string.upper(sortBy)
			rebuild()
		end
	)
	if fresh then
		smallText(sortButton, 32)
	end
	bestButton, fresh = Popups.button(
		holder,
		{
			Name = "EquipBest",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -100, 0, 6),
			Size = UDim2.fromOffset(250, 66),
			ZIndex = 5,
		},
		"EQUIP BEST",
		BLUE,
		function()
			if tab == "Pets" then
				if petRemote then
					petRemote:FireServer("best")
				end
			elseif weaponRemote then
				-- (rarest first, then the most damage, whatever the grid's sorted by)
				local list = TABS.Weapons.owned()
				local t = TABS.Weapons
				table.sort(list, function(a, b)
					local ra, rb = RANK[t.rarity(a.id)] or 0, RANK[t.rarity(b.id)] or 0
					if ra ~= rb then
						return ra > rb
					end
					return t.score(a.id) > t.score(b.id)
				end)
				if list[1] then
					weaponRemote:FireServer(list[1].id)
				end
			end
		end
	)
	if fresh then
		smallText(bestButton, 32)
	end

	-- the tabs, down the panel's left side
	local tabButtons = {}
	for i, name in { "Pets", "Weapons" } do
		local b
		b, fresh = Ui.make(holder, name .. "Tab", "TextButton")
		if fresh then
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundTransparency = 1
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(0, -14, 0, 130 + (i - 1) * 160)
			b.Size = UDim2.fromOffset(140, 140)
			b.ZIndex = 4
		end
		local scale = Ui.make(b, "Hover", "UIScale")
		local card = Popups.card(b, { Name = "Card", Size = UDim2.fromScale(1, 1), Active = false })
		local ring -- (the selected tab's white outline)
		ring, fresh = Ui.make(b, "Ring", "Frame")
		if fresh then
			ring.BackgroundTransparency = 1
			ring.Size = UDim2.fromScale(1, 1)
			local rc = Instance.new("UICorner")
			rc.CornerRadius = UDim.new(0, 14)
			rc.Parent = ring
		end
		local stroke
		stroke, fresh = Ui.make(ring, "Selected", "UIStroke")
		if fresh then
			stroke.Color = WHITE
			stroke.Thickness = 4
		end
		local art = iconLabel(b, { Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.72, 0.72) })
		if art.Image == "" then
			icon(art, name, if name == "Pets" then "Horse" else "Shortsword")
		end
		local label = Popups.text(b, {
			Name = "Label",
			Text = name,
			TextSize = 28,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -4),
			Size = UDim2.new(1, 0, 0, 34),
			ZIndex = 3,
		})
		tabButtons[name] = { button = b, scale = scale, card = card, stroke = stroke, label = label }
	end
	if not Ui.live then
		return
	end

	petRemote = ReplicatedStorage:WaitForChild("PetEquip", 10)
	weaponRemote = ReplicatedStorage:WaitForChild("EquipWeapon", 10)
	header:GetPropertyChangedSignal("TextBounds"):Connect(placeDashes)

	local function tile(parent, id, count, order, onClick)
		local t = TABS[tab]
		local b = Ui.copy(templates[parent], id, parent)
		b.LayoutOrder = order
		local scale = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", b)
		local img = b:FindFirstChild("Icon")
		if img then
			icon(img, tab, id)
		end
		local countLabel = b:FindFirstChild("Count")
		if countLabel then
			countLabel.Text = "x" .. (count or 1)
			countLabel.Visible = count ~= nil and count > 1
		end
		local oddsLabel = b:FindFirstChild("Odds")
		if oddsLabel then
			local odds = t.odds(id)
			oddsLabel.Visible = odds ~= nil
			if odds then
				local c = rarityColors(t.rarity(id))
				oddsLabel.Text = "1/" .. Popups.abbreviate(odds)
				oddsLabel.TextColor3 = c.Fill
				local stroke = oddsLabel:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = c.Stroke
				end
			end
		end
		b.MouseEnter:Connect(function()
			tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
			if os.clock() > flashUntil then
				setHeader(t.detail(id), rarityColors(t.rarity(id)).Fill)
			end
		end)
		b.MouseLeave:Connect(function()
			tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
			if os.clock() > flashUntil then
				setHeader(headerText)
			end
		end)
		b.MouseButton1Down:Connect(function()
			tween(scale, 0.06, { Scale = 0.92 })
		end)
		b.Activated:Connect(function()
			tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
			onClick()
		end)
		return b
	end

	local function emptySlot(order)
		local s = Ui.copy(emptyOne, "Empty" .. order, row)
		s.LayoutOrder = order
	end

	local function flash(text)
		flashUntil = os.clock() + 1.6
		setHeader(text, RED_TEXT)
		task.delay(1.65, function()
			if os.clock() >= flashUntil then
				setHeader(headerText)
			end
		end)
	end

	-- best first: rarest (then highest score), or by name
	local function sorted(list)
		local t = TABS[tab]
		table.sort(list, function(a, b)
			if sortBy == "Name" then
				return t.name(a.id) < t.name(b.id)
			end
			local ra, rb = RANK[t.rarity(a.id)] or 0, RANK[t.rarity(b.id)] or 0
			if ra ~= rb then
				return ra > rb
			end
			local sa, sb = t.score(a.id), t.score(b.id)
			if sa ~= sb then
				return sa > sb
			end
			return t.name(a.id) < t.name(b.id)
		end)
		return list
	end

	function rebuild()
		local t = TABS[tab]
		for _, holderFrame in { row, grid } do
			for _, child in holderFrame:GetChildren() do
				if child:IsA("GuiObject") and not Ui.isTemplate(child) then
					child:Destroy()
				end
			end
		end
		local owned = t.owned()
		local equipped = t.equipped()
		-- the row
		for i = 1, t.slots() do
			local id = equipped[i]
			if id then
				tile(row, id, nil, i, function()
					if tab == "Pets" and petRemote then
						petRemote:FireServer("unequip", i)
					end
				end)
			else
				emptySlot(i)
			end
		end
		-- the grid: what's left once the equipped ones are taken out
		local left = {}
		for _, s in owned do
			local n = s.n
			for _, id in equipped do
				if id == s.id then
					n -= 1
				end
			end
			if n > 0 then
				table.insert(left, { id = s.id, n = n })
			end
		end
		for i, s in sorted(left) do
			tile(grid, s.id, s.n, i, function()
				if tab == "Pets" then
					if #t.equipped() >= t.slots() then
						flash("Your pen is full! Click a pet above to take it out.")
					elseif petRemote then
						petRemote:FireServer("equip", s.id)
					end
				elseif weaponRemote then
					weaponRemote:FireServer(s.id)
				end
			end)
		end
		emptyNote.Text = t.empty
		emptyNote.Visible = #left == 0 and #equipped == 0
		headerText = t.header(equipped)
		if os.clock() > flashUntil then
			setHeader(headerText)
		end
	end

	local function selectTab(name)
		tab = name
		for n, b in tabButtons do
			local on = n == name
			b.stroke.Enabled = on
			b.card.ImageTransparency = if on then 0 else 0.25
			b.label.TextColor3 = if on then WHITE else SOFT
		end
		grid.CanvasPosition = Vector2.zero
		rebuild()
	end
	for name, b in tabButtons do
		b.button.MouseEnter:Connect(function()
			tween(b.scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
		end)
		b.button.MouseLeave:Connect(function()
			tween(b.scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		b.button.Activated:Connect(function()
			if tab ~= name then
				selectTab(name)
			end
		end)
	end

	-- kept up to date while it's open (and fresh each time it opens)
	local dirty = false
	local function changed()
		if holder.Visible then
			rebuild()
		else
			dirty = true
		end
	end
	for _, t in TABS do
		for _, attr in t.attributes do
			player:GetAttributeChangedSignal(attr):Connect(changed)
		end
	end
	-- (the held weapon's DPS goes up with your Strength)
	player:GetAttributeChangedSignal("Strength"):Connect(function()
		if tab == "Weapons" then
			headerText = TABS.Weapons.header(TABS.Weapons.equipped())
			if os.clock() > flashUntil then
				setHeader(headerText)
			end
		end
	end)
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		if holder.Visible and dirty then
			dirty = false
			rebuild()
		end
	end)
	selectTab("Pets")
end

return Backpack
