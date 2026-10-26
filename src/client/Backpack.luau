-- The Backpack (QM, Oct 25, in the style of QM's reference): a popup with two tabs on its
-- left, Pets and Weapons. Each shows what's equipped in a row at the top and everything
-- else you own in a grid below, duplicates stacked into one tile with "x5" top right and
-- the odds of getting it ("1/57", in its rarity's colour) bottom right. Equipping one
-- moves it up into the row (so its tile's count drops by one, and goes once none are
-- left). Sorted rarest first. (QM, Oct 26: on QM's plain tiled panel for now, no title,
-- X, SORT or EQUIP BEST; Escape or the Backpack button closes it.)
--
--   Pets: the ones in the row wander in your pen (Config.Backpack.PenSlots of them).
--         Click a pet below to put it in, one in the row to take it out (PetEquip,
--         Server/PetInventory).
--   Weapons: the row is the one you hold. Click another to hold it instead (EquipWeapon,
--         Server/Arsenal).
--
-- Hovering a tile shows its name and details over the row.
--
-- In Studio it's StarterGui > Hud > Root > BackpackPopup (client/Ui): the tiles are copied
-- from Grid > TileTemplate and Equipped > EquippedTemplate / EmptyTemplate, so edit those.
--
--   Backpack.init()   -- once, from Hud, after Popups.init (Popups.toggle("Backpack") opens it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
-- the Items tab (QM's mockup, Oct 26): a row per rarity holding every weapon of it
local ITEM = 118 -- design px of an item's square
local ITEM_GAP = 26
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
-- each rarity's square: a radial gradient (lighter middle, darker edge) with a lighter outline.
-- (These only colour the templates when they're first made: after that, StarterGui > Hud >
-- Root > BackpackPopup > Body > Items > <rarity> > OwnedTemplate is what to edit.)
-- each rarity's square (QM, Oct 26): { dark (its edges), light (the glow in the middle), outline }
local function hexes(dark, light, outline)
	return { Dark = Color3.fromHex(dark), Light = Color3.fromHex(light), Outline = Color3.fromHex(outline) }
end
local ITEM_COLORS = {
	Common = hexes("6E7385", "C6C6C6", "B1B1B1"),
	Uncommon = hexes("009356", "08E600", "29E200"),
	Rare = hexes("004699", "0097E6", "00C5EE"),
	Epic = hexes("7710CC", "B246DE", "D567FF"),
	Legendary = hexes("BE8800", "EEC315", "FFE985"),
	Mythic = hexes("A0103C", "E8305C", "FF7A9A"), -- (not QM's yet)
}
local ITEM_OUTLINE = 4 -- px
local RADIAL = "rbxassetid://106131181340173" -- (rbxassetid of assets/ui/RadialGlow.png: white in the middle fading out)
local UNKNOWN = Color3.fromHex("C1A283")
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local MERGE_TEXTURE = "rbxassetid://87121220953662" -- (assets/ui/merge_button_texture.png: QM's green checker)
local MERGE_DARK = Color3.fromHex("00A529") -- the MERGE button's outline and shadow
local CLOSE_DARK = Color3.fromHex("720006") -- the X's outline and shadow
local MERGE_PULSE = 0.05 -- how much bigger it swells at the top of each pulse
local MERGE_PULSE_TIME = 1.1 -- seconds a pulse takes
local MERGE_SPIN = 40 -- degrees a second the sunburst behind it turns
local TYPE_ORDER = { Melee = 1, Ranged = 2, Magic = 3 }
-- the Pets tab (QM's mockup, Oct 26): your pen's slots along the top, a gap, then a row per
-- rarity like the Items tab
local PEN_GAP = 56 -- design px between the pen's slots and the rows
local LAST_ONE = 0.5 -- how see-through a pet's square goes once your last one's in the pen

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

-- ---- the Items tab's squares ----------------------------------------------------------

local function rounded(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

-- a weapon you own: its rarity's radial square, its icon, "x5" when there's more than one,
-- and a white ring round the one you hold (Ring, shown by the game)
local function ownedTemplate(rarity)
	return function()
		local colors = ITEM_COLORS[rarity] or ITEM_COLORS.Common
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(ITEM, ITEM)
		local scale = Instance.new("UIScale")
		scale.Name = "Hover"
		scale.Parent = b
		-- (the white ring: a wider stroke under the square's own, so it shows just outside it)
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.fromScale(1, 1)
		ring.ZIndex = 1
		rounded(ring, 8)
		local white = Instance.new("UIStroke")
		white.Color = WHITE
		white.Thickness = 8
		white.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		white.Parent = ring
		ring.Parent = b
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.BackgroundColor3 = if RADIAL ~= "" then colors.Dark else colors.Light
		panel.BorderSizePixel = 0
		panel.Size = UDim2.fromScale(1, 1)
		panel.ZIndex = 2
		rounded(panel, 6)
		local outline = Instance.new("UIStroke")
		outline.Name = "Outline"
		outline.Color = colors.Outline
		outline.Thickness = ITEM_OUTLINE
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = panel
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = RADIAL
		glow.ImageColor3 = colors.Light
		glow.Size = UDim2.fromScale(1, 1)
		glow.ZIndex = 2
		rounded(glow, 6)
		glow.Parent = panel
		panel.Parent = b
		iconLabel(b, {
			Image = WeaponIcons.Shortsword or "",
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.82, 0.82),
			ZIndex = 3,
		})
		-- "x5" over the top right corner: white, black outline, a hard 25% black shadow
		local count = Instance.new("Frame")
		count.Name = "Count"
		count.BackgroundTransparency = 1
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, 10, 0, -12)
		count.Size = UDim2.fromOffset(80, 40)
		count.ZIndex = 4
		local function label(parent, color, z)
			local t = Instance.new("TextLabel")
			t.Name = "Label"
			t.BackgroundTransparency = 1
			t.FontFace = FONT
			t.Text = "x5"
			t.TextSize = 32
			t.TextColor3 = color
			t.TextXAlignment = Enum.TextXAlignment.Right
			t.Size = UDim2.fromScale(1, 1)
			t.ZIndex = z
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(0, 0, 0)
			stroke.Thickness = 3
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = t
			t.Parent = parent
			return t
		end
		local shadow = Instance.new("CanvasGroup") -- (one see-through layer, so it's an even 25%)
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.GroupTransparency = 0.75
		shadow.Position = UDim2.fromOffset(3, 3)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.ZIndex = 4
		label(shadow, Color3.new(0, 0, 0), 4)
		shadow.Parent = count
		label(count, WHITE, 5)
		count.Parent = b
		return b
	end
end

-- a weapon you haven't found yet: a see-through C1A283 square with a faint "?"
local function unknownTemplate()
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UNKNOWN
	f.BackgroundTransparency = 0.5
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(ITEM, ITEM)
	rounded(f, 6)
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.FontFace = FONT
	mark.Text = "?"
	mark.TextSize = 64
	mark.TextColor3 = WHITE
	mark.TextTransparency = 0.5
	mark.Size = UDim2.fromScale(1, 1)
	mark.Parent = f
	return f
end

-- every weapon, by rarity: melee, then ranged, then magic, each by name
local function weaponsByRarity()
	local lists = {}
	for id, w in Config.Weapons do
		if type(w) == "table" and w.Rarity and Weapons.exists(id) then
			lists[w.Rarity] = lists[w.Rarity] or {}
			table.insert(lists[w.Rarity], id)
		end
	end
	for _, list in lists do
		table.sort(list, function(a, b)
			local wa, wb = Config.Weapons[a], Config.Weapons[b]
			local ta, tb = TYPE_ORDER[wa.Type] or 9, TYPE_ORDER[wb.Type] or 9
			if ta ~= tb then
				return ta < tb
			end
			return (wa.Name or a) < (wb.Name or b)
		end)
	end
	return lists
end

-- every pet, by rarity: cheapest first, then by name
local function petsByRarity()
	local lists = {}
	for kind, p in Config.Pets do
		if type(p) == "table" and p.Rarity then
			lists[p.Rarity] = lists[p.Rarity] or {}
			table.insert(lists[p.Rarity], kind)
		end
	end
	for _, list in lists do
		table.sort(list, function(a, b)
			local ca, cb = Config.Pets[a].Cash or 0, Config.Pets[b].Cash or 0
			if ca ~= cb then
				return ca < cb
			end
			return a < b
		end)
	end
	return lists
end

-- a square (and everything on it) made `k` more see-through: a pet whose last one's in the pen
local function fade(b, k)
	for _, d in b:GetDescendants() do
		if d:IsA("ImageLabel") or d:IsA("ImageButton") then
			d.ImageTransparency = 1 - (1 - d.ImageTransparency) * (1 - k)
		end
		if d:IsA("TextLabel") then
			d.TextTransparency = 1 - (1 - d.TextTransparency) * (1 - k)
		end
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			d.BackgroundTransparency = 1 - (1 - d.BackgroundTransparency) * (1 - k)
		end
		if d:IsA("UIStroke") then
			d.Transparency = 1 - (1 - d.Transparency) * (1 - k)
		end
		if d:IsA("CanvasGroup") then
			d.GroupTransparency = 1 - (1 - d.GroupTransparency) * (1 - k)
		end
	end
end

-- ---- the popup ------------------------------------------------------------------------

function Backpack.init()
	local body, holder = Popups.frame("Backpack", "Backpack", SIZE, true) -- (QM's tiled panel, Oct 26)
	Popups.grow("Backpack", 1, 184) -- (its own size: 1.3x ran off the screen, QM; the side buttons stick out 24 + 160)
	local tab = "Weapons" -- (Items first, QM's mockup)
	local sortBy = "Rarity"
	local flashUntil = 0
	local rebuild -- (below)
	local fresh
	local petRemote, weaponRemote, mergeRemote -- (in Play)

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

	local petParts = { header, dashes[-1], dashes[1], row, line, grid, emptyNote } -- (the Pets tab's)

	-- the Items tab: a row per rarity, every weapon in it, owned ones filled in
	local items
	items, fresh = Ui.make(body, "Items", "ScrollingFrame")
	if fresh then
		items.BackgroundTransparency = 1
		items.BorderSizePixel = 0
		items.Position = UDim2.fromOffset(0, -20)
		items.Size = UDim2.new(1, 0, 1, 10)
		items.CanvasSize = UDim2.new()
		items.AutomaticCanvasSize = Enum.AutomaticSize.Y
		items.ScrollingDirection = Enum.ScrollingDirection.Y
		items.ScrollBarThickness = 8
		items.ScrollBarImageColor3 = UNKNOWN
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.Parent = items
		local layout = Instance.new("UIListLayout")
		layout.Name = "Layout"
		layout.Padding = UDim.new(0, ITEM_GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = items
	end
	local byRarity = weaponsByRarity()
	local itemRows = {} -- { { rarity, row, template }, ... }
	for i, rarity in RARITIES do
		if byRarity[rarity] then
			local r
			r, fresh = Ui.make(items, rarity, "Frame")
			if fresh then
				r.BackgroundTransparency = 1
				r.LayoutOrder = i
				r.Size = UDim2.new(1, -24, 0, ITEM)
				local layout = Instance.new("UIListLayout")
				layout.Name = "Layout"
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, ITEM_GAP)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = r
			end
			table.insert(itemRows, { rarity, r, Ui.template(r, "OwnedTemplate", ownedTemplate(rarity)) })
		end
	end
	local unknownOne = Ui.template(items, "UnknownTemplate", unknownTemplate)

	-- the Pets tab: your pen's slots along the top (a "?" where one's empty), then a row per
	-- rarity of every pet, owned ones filled in. (In Studio: Body > Pets > Rows > <rarity> >
	-- OwnedTemplate and Rows > UnknownTemplate; the pen's slots are copied from those too.)
	local pets
	pets, fresh = Ui.make(body, "Pets", "Frame")
	if fresh then
		pets.BackgroundTransparency = 1
		pets.Position = UDim2.fromOffset(0, -20)
		pets.Size = UDim2.new(1, 0, 1, 10)
	end
	local pen
	pen, fresh = Ui.make(pets, "Pen", "Frame")
	if fresh then
		pen.BackgroundTransparency = 1
		pen.Position = UDim2.fromOffset(0, 16)
		pen.Size = UDim2.new(1, 0, 0, ITEM)
		local layout = Instance.new("UIListLayout")
		layout.Name = "Layout"
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding = UDim.new(0, ITEM_GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = pen
	end
	-- a soft line between the pen and the rows, fading out at both ends (QM)
	local separator
	separator, fresh = Ui.make(pets, "Separator", "Frame")
	if fresh then
		separator.BackgroundColor3 = UNKNOWN
		separator.BackgroundTransparency = 0.4
		separator.BorderSizePixel = 0
		separator.AnchorPoint = Vector2.new(0.5, 0.5)
		separator.Position = UDim2.new(0.5, 0, 0, 16 + ITEM + PEN_GAP / 2)
		separator.Size = UDim2.new(1, -60, 0, 6)
		rounded(separator, 3)
		local fadeEnds = Instance.new("UIGradient")
		fadeEnds.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0),
			NumberSequenceKeypoint.new(0.88, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fadeEnds.Parent = separator
	end
	local petRowsFrame
	petRowsFrame, fresh = Ui.make(pets, "Rows", "ScrollingFrame")
	if fresh then
		local top = 16 + ITEM + PEN_GAP - 16
		petRowsFrame.BackgroundTransparency = 1
		petRowsFrame.BorderSizePixel = 0
		petRowsFrame.Position = UDim2.fromOffset(0, top)
		petRowsFrame.Size = UDim2.new(1, 0, 1, -top)
		petRowsFrame.CanvasSize = UDim2.new()
		petRowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		petRowsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
		petRowsFrame.ScrollBarThickness = 8
		petRowsFrame.ScrollBarImageColor3 = UNKNOWN
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 16)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.Parent = petRowsFrame
		local layout = Instance.new("UIListLayout")
		layout.Name = "Layout"
		layout.Padding = UDim.new(0, ITEM_GAP)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = petRowsFrame
	end
	local petsBy = petsByRarity()
	local petRows = {} -- { { rarity, row, template }, ... }
	local petTemplates = {} -- [rarity] = its OwnedTemplate (the pen's slots use them too)
	for i, rarity in RARITIES do
		if petsBy[rarity] then
			local r
			r, fresh = Ui.make(petRowsFrame, rarity, "Frame")
			if fresh then
				r.BackgroundTransparency = 1
				r.LayoutOrder = i
				r.Size = UDim2.new(1, -24, 0, ITEM)
				local layout = Instance.new("UIListLayout")
				layout.Name = "Layout"
				layout.FillDirection = Enum.FillDirection.Horizontal
				layout.Padding = UDim.new(0, ITEM_GAP)
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Parent = r
			end
			petTemplates[rarity] = Ui.template(r, "OwnedTemplate", ownedTemplate(rarity))
			table.insert(petRows, { rarity, r, petTemplates[rarity] })
		end
	end
	local petUnknown = Ui.template(petRowsFrame, "UnknownTemplate", unknownTemplate)

	-- the selector, down the outside of the panel's left edge: the open one on a 20% black
	-- square with rounded corners, the other faded to half
	local tabButtons = {}
	for i, name in { "Weapons", "Pets" } do
		local b
		b, fresh = Ui.make(holder, if name == "Weapons" then "ItemsTab" else "PetsTab", "TextButton")
		if fresh then
			b.Text = ""
			b.AutoButtonColor = false
			b.BackgroundColor3 = Color3.new(0, 0, 0)
			b.BackgroundTransparency = if i == 1 then 0.8 else 1
			b.BorderSizePixel = 0
			-- (the pair centred on the panel's height, QM)
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(0, -24, 0.5, (i - 1.5) * 176)
			b.Size = UDim2.fromOffset(160, 160)
			b.ZIndex = 4
			rounded(b, 10)
		end
		local scale = Ui.make(b, "Hover", "UIScale")
		local art = iconLabel(b, {
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			ZIndex = 5,
			ImageTransparency = if i == 1 then 0 else 0.5,
		})
		if art.Image == "" then
			icon(art, name, if name == "Pets" then "Horse" else "Club")
		end
		tabButtons[name] = { button = b, scale = scale, art = art }
	end
	-- MERGE (QM, Oct 26): under the Items tab, sat on the panel's bottom edge, only while
	-- you've Config.Merge.Cost of a weapon that merges into another (Config.Merge.Into)
	-- the X (QM's Figma, designs/figma/close_button.md): a red square over the panel's top
	-- right corner, its lowercase "x" in Fredoka One, closing the Backpack
	local close = Ui.make(holder, "Close", "TextButton")
	if not close:FindFirstChild("Plate") then
		local k = SIZE.X / 2710
		close.Text = ""
		close.AutoButtonColor = false
		close.BackgroundTransparency = 1
		close.Position = UDim2.fromOffset(math.round(2566 * k), math.round(-54 * k))
		close.Size = UDim2.fromOffset(math.round(192 * k), math.round(192 * k))
		close.ZIndex = 6
		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.BackgroundTransparency = 1
		plate.AnchorPoint = Vector2.new(0.5, 0.5)
		plate.Position = UDim2.fromScale(0.5, 0.5)
		plate.Size = UDim2.fromScale(1, 1)
		plate.ZIndex = 6
		Instance.new("UIScale").Parent = plate
		plate.Parent = close
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BackgroundColor3 = CLOSE_DARK
		shadow.BorderSizePixel = 0
		shadow.Position = UDim2.fromOffset(0, math.round(16 * k))
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.ZIndex = 6
		rounded(shadow, math.round(20 * k))
		shadow.Parent = plate
		-- (the radial gradient: the glow's lighter red in the middle over the edge's red)
		local bodyFrame = Instance.new("Frame")
		bodyFrame.Name = "Body"
		bodyFrame.BackgroundColor3 = Color3.fromHex("F32020")
		bodyFrame.BorderSizePixel = 0
		bodyFrame.Size = UDim2.fromScale(1, 1)
		bodyFrame.ZIndex = 7
		rounded(bodyFrame, math.round(20 * k))
		local stroke = Instance.new("UIStroke")
		stroke.Color = CLOSE_DARK
		stroke.Thickness = math.round(10 * k)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = bodyFrame
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = RADIAL
		glow.ImageColor3 = Color3.fromHex("FF5656")
		glow.Size = UDim2.fromScale(1, 1)
		glow.ZIndex = 7
		rounded(glow, math.round(20 * k))
		glow.Parent = bodyFrame
		bodyFrame.Parent = plate
		local function glyph(name, color, dy, z, transparency)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
			t.Text = "x"
			t.TextSize = math.round(130 * k)
			t.TextColor3 = color
			t.TextTransparency = transparency
			t.Position = UDim2.fromOffset(0, dy - 2)
			t.Size = UDim2.fromScale(1, 1)
			t.ZIndex = z
			local o = Instance.new("UIStroke")
			o.Color = Color3.new(0, 0, 0)
			o.Thickness = 3
			o.Transparency = transparency
			o.LineJoinMode = Enum.LineJoinMode.Round
			o.Parent = t
			t.Parent = plate
		end
		glyph("XShadow", Color3.new(0, 0, 0), math.round(8 * k), 8, 0.75)
		glyph("X", WHITE, 0, 9, 0)
	end
	if Ui.live then
		local scale = close.Plate:FindFirstChildOfClass("UIScale")
		close.MouseEnter:Connect(function()
			tween(scale, 0.12, { Scale = 1.08 }, Enum.EasingStyle.Back)
		end)
		close.MouseLeave:Connect(function()
			tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		close.MouseButton1Down:Connect(function()
			tween(scale, 0.06, { Scale = 0.9 })
		end)
		close.Activated:Connect(function()
			tween(scale, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
			Popups.close()
		end)
	end

	local playMerge -- (below: the merge's animation, then the merge)
	local mergeButton = Ui.make(holder, "Merge", "TextButton")
	if not mergeButton:FindFirstChild("Plate") then
		-- QM's Figma (designs/figma/merge_button.md, scaled from its 2710-wide panel to ours):
		-- a green checker with a darker green outline and a solid shadow under it, "MERGE"
		-- in white with a black outline and a soft shadow
		local k = SIZE.X / 2710
		mergeButton.Text = ""
		mergeButton.AutoButtonColor = false
		mergeButton.BackgroundTransparency = 1
		mergeButton.AnchorPoint = Vector2.new(0.5, 0)
		mergeButton.Position = UDim2.new(0.5, 0, 1, -math.round(114 * k))
		mergeButton.Size = UDim2.fromOffset(math.round(690 * k), math.round(228 * k))
		mergeButton.ZIndex = 6
		-- (the green plate pulses and squashes; the word stays put, at one size, QM)
		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.BackgroundTransparency = 1
		plate.AnchorPoint = Vector2.new(0.5, 0.5)
		plate.Position = UDim2.fromScale(0.5, 0.5)
		plate.Size = UDim2.fromScale(1, 1)
		plate.ZIndex = 6
		Instance.new("UIScale").Parent = plate
		plate.Parent = mergeButton
		-- (a sunburst turning behind it while it's up: QM's spin screen rays)
		local rays = Instance.new("ImageLabel")
		rays.Name = "Rays"
		rays.BackgroundTransparency = 1
		rays.Image = Config.WeaponDrops.RaysImage
		rays.ImageColor3 = Color3.fromHex("C8FF8A")
		rays.ImageTransparency = 0.35
		rays.AnchorPoint = Vector2.new(0.5, 0.5)
		rays.Position = UDim2.fromScale(0.5, 0.5)
		rays.Size = UDim2.fromOffset(math.round(690 * k * 1.25), math.round(690 * k * 1.25))
		rays.ZIndex = 5
		rays.Parent = mergeButton
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BackgroundColor3 = MERGE_DARK
		shadow.BorderSizePixel = 0
		shadow.Position = UDim2.fromOffset(0, math.round(16 * k))
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.ZIndex = 6
		rounded(shadow, math.round(20 * k))
		shadow.Parent = plate
		local bodyImg = Instance.new("ImageLabel")
		bodyImg.Name = "Body"
		bodyImg.BackgroundColor3 = Color3.fromHex("88F421")
		bodyImg.BorderSizePixel = 0
		bodyImg.Image = MERGE_TEXTURE
		bodyImg.ScaleType = Enum.ScaleType.Tile
		bodyImg.TileSize = UDim2.fromOffset(math.round(180 * k), math.round(180 * k))
		bodyImg.Size = UDim2.fromScale(1, 1)
		bodyImg.ZIndex = 7
		rounded(bodyImg, math.round(20 * k))
		local stroke = Instance.new("UIStroke")
		stroke.Color = MERGE_DARK
		stroke.Thickness = math.round(10 * k)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = bodyImg
		bodyImg.Parent = plate
		local function word(name, color, dy, z, transparency)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.FontFace = FONT
			t.Text = "MERGE"
			t.TextSize = math.round(100 * k)
			t.TextColor3 = color
			t.TextTransparency = transparency
			t.Position = UDim2.fromOffset(0, dy)
			t.Size = UDim2.fromScale(1, 1)
			t.ZIndex = z
			local o = Instance.new("UIStroke")
			o.Color = Color3.new(0, 0, 0)
			o.Thickness = 3
			o.Transparency = transparency
			o.LineJoinMode = Enum.LineJoinMode.Round
			o.Parent = t
			t.Parent = mergeButton
		end
		word("LabelShadow", Color3.new(0, 0, 0), math.round(8 * k), 8, 0.75)
		word("Label", WHITE, 0, 9, 0)
	end
	if Ui.live then
		local plate = mergeButton:FindFirstChild("Plate") or mergeButton
		local scale = plate:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", plate)
		-- (hover and press tween this; it's multiplied by the pulse each frame)
		local press = Instance.new("NumberValue")
		press.Value = 1
		mergeButton.MouseEnter:Connect(function()
			tween(press, 0.12, { Value = 1.05 }, Enum.EasingStyle.Back)
		end)
		mergeButton.MouseLeave:Connect(function()
			tween(press, 0.12, { Value = 1 }, Enum.EasingStyle.Back)
		end)
		mergeButton.MouseButton1Down:Connect(function()
			tween(press, 0.06, { Value = 0.92 })
		end)
		-- while it's up: a gentle pulse, and the sunburst behind it turning (QM)
		local rays = mergeButton:FindFirstChild("Rays")
		local t = 0
		RunService.RenderStepped:Connect(function(dt)
			if not (mergeButton.Visible and holder.Visible) then
				return
			end
			t += dt
			scale.Scale = press.Value * (1 + MERGE_PULSE * math.sin(t * math.pi * 2 / MERGE_PULSE_TIME))
			if rays then
				rays.Rotation = (rays.Rotation + dt * MERGE_SPIN) % 360
			end
		end)
		mergeButton.Activated:Connect(function()
			tween(press, 0.15, { Value = 1.05 }, Enum.EasingStyle.Back)
			local id = mergeButton:GetAttribute("Merges")
			if id and mergeRemote and playMerge then
				playMerge(id)
			end
		end)
	end
	-- what MERGE would merge: the weapon you hold if it can, else the first one that can
	-- (commons first, as the rows run)
	local function toMerge()
		local owned = {}
		for _, s in TABS.Weapons.owned() do
			owned[s.id] = s.n
		end
		local function can(id)
			return Config.Merge.Into[id] ~= nil and (owned[id] or 0) >= Config.Merge.Cost
		end
		local held = TABS.Weapons.equipped()[1]
		if held and can(held) then
			return held
		end
		for _, rarity in RARITIES do
			for _, id in byRarity[rarity] or {} do
				if can(id) then
					return id
				end
			end
		end
		return nil
	end

	if not Ui.live then
		-- (in Studio: show the Items tab, as it opens)
		items.Visible = true
		pets.Visible = false
		for _, part in petParts do
			part.Visible = false
		end
		return
	end

	petRemote = ReplicatedStorage:WaitForChild("PetEquip", 10)
	weaponRemote = ReplicatedStorage:WaitForChild("EquipWeapon", 10)
	mergeRemote = ReplicatedStorage:WaitForChild("MergeWeapon", 10)
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

	local function rebuildItems()
		local owned = {}
		for _, s in TABS.Weapons.owned() do
			owned[s.id] = s.n
		end
		local held = TABS.Weapons.equipped()[1]
		for _, entry in itemRows do
			local rarity, r, template = entry[1], entry[2], entry[3]
			for _, child in r:GetChildren() do
				if child:IsA("GuiObject") and not Ui.isTemplate(child) then
					child:Destroy()
				end
			end
			for i, id in byRarity[rarity] do
				if not owned[id] then
					Ui.copy(unknownOne, id, r).LayoutOrder = i
					continue
				end
				local b = Ui.copy(template, id, r)
				b.LayoutOrder = i
				local img = b:FindFirstChild("Icon")
				if img then
					icon(img, "Weapons", id)
				end
				local ring = b:FindFirstChild("Ring")
				if ring then
					ring.Visible = id == held
				end
				local count = b:FindFirstChild("Count")
				if count then
					count.Visible = owned[id] > 1
					for _, label in count:GetDescendants() do
						if label:IsA("TextLabel") then
							label.Text = "x" .. owned[id]
						end
					end
				end
				local scale = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", b)
				b.MouseEnter:Connect(function()
					tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
				end)
				b.MouseLeave:Connect(function()
					tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
				end)
				b.MouseButton1Down:Connect(function()
					tween(scale, 0.06, { Scale = 0.92 })
				end)
				b.Activated:Connect(function()
					tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
					if weaponRemote and id ~= held then
						weaponRemote:FireServer(id)
					end
				end)
			end
		end
	end

	-- a pet's square, wired up: grows a little on hover, squashes on press
	local function pressable(b, onClick)
		local scale = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", b)
		b.MouseEnter:Connect(function()
			tween(scale, 0.12, { Scale = 1.06 }, Enum.EasingStyle.Back)
		end)
		b.MouseLeave:Connect(function()
			tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		b.MouseButton1Down:Connect(function()
			tween(scale, 0.06, { Scale = 0.92 })
		end)
		b.Activated:Connect(function()
			tween(scale, 0.15, { Scale = 1.06 }, Enum.EasingStyle.Back)
			onClick()
		end)
	end

	local function petSquare(template, kind, parent, order, count, ring)
		local b = Ui.copy(template, kind, parent)
		b.LayoutOrder = order
		local img = b:FindFirstChild("Icon")
		if img then
			icon(img, "Pets", kind)
		end
		local r = b:FindFirstChild("Ring")
		if r then
			r.Visible = ring
		end
		local c = b:FindFirstChild("Count")
		if c then
			c.Visible = count > 1
			for _, label in c:GetDescendants() do
				if label:IsA("TextLabel") then
					label.Text = "x" .. count
				end
			end
		end
		return b
	end

	-- the Pets tab: click a pet below to put one in your pen, one in the pen to take it out
	local function rebuildPets()
		local holders = { pen }
		for _, entry in petRows do
			table.insert(holders, entry[2])
		end
		for _, f in holders do
			for _, child in f:GetChildren() do
				if child:IsA("GuiObject") and not Ui.isTemplate(child) then
					child:Destroy()
				end
			end
		end
		local owned = {}
		for _, s in TABS.Pets.owned() do
			owned[s.id] = s.n
		end
		local equipped = TABS.Pets.equipped()
		local inPen = {}
		for _, kind in equipped do
			inPen[kind] = (inPen[kind] or 0) + 1
		end
		-- the pen's slots
		for i = 1, TABS.Pets.slots() do
			local kind = equipped[i]
			if kind then
				local template = petTemplates[TABS.Pets.rarity(kind)] or petRows[1][3]
				local b = petSquare(template, kind, pen, i, 1, false) -- (no white ring in the pen, QM)
				pressable(b, function()
					if petRemote then
						petRemote:FireServer("unequip", i)
					end
				end)
			else
				Ui.copy(petUnknown, "Empty" .. i, pen).LayoutOrder = i
			end
		end
		-- the rows: what's left of each once the pen's are taken out; your last one in the pen
		-- just goes see-through (not a "?": you have it)
		for _, entry in petRows do
			local rarity, r, template = entry[1], entry[2], entry[3]
			for i, kind in petsBy[rarity] do
				local have = owned[kind] or 0
				if have == 0 then
					Ui.copy(petUnknown, kind, r).LayoutOrder = i
					continue
				end
				local left = have - (inPen[kind] or 0)
				local b = petSquare(template, kind, r, i, left, false)
				if left <= 0 then
					fade(b, LAST_ONE)
					pressable(b, function()
						-- (takes it back out of the pen)
						local at = table.find(TABS.Pets.equipped(), kind)
						if at and petRemote then
							petRemote:FireServer("unequip", at)
						end
					end)
				else
					pressable(b, function()
						if #TABS.Pets.equipped() < TABS.Pets.slots() and petRemote then
							petRemote:FireServer("equip", kind)
						end
					end)
				end
			end
		end
	end

	function rebuild()
		items.Visible = tab == "Weapons"
		pets.Visible = tab == "Pets"
		local merges = if tab == "Weapons" then toMerge() else nil
		mergeButton:SetAttribute("Merges", merges)
		mergeButton.Visible = merges ~= nil
		for _, part in petParts do
			part.Visible = false -- (the old Pets tab, before QM's rows)
		end
		if tab == "Weapons" then
			rebuildItems()
			return
		end
		if tab == "Pets" then
			rebuildPets()
			return
		end
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

	-- the merge (QM, Oct 26): the merged weapon's square flashes white and squashes, the new
	-- one pops up out of it and drifts over to its own square, and only when it lands does
	-- that square fill in (or its "xN" count up), with a bounce and a flash of its own. The
	-- Backpack holds still (no rebuilds) until then.
	local merging = false
	local function whiteFlash(square, peak)
		local f = Instance.new("Frame")
		f.Name = "Flash"
		f.BackgroundColor3 = WHITE
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Size = UDim2.fromScale(1, 1)
		f.ZIndex = 20
		rounded(f, 6)
		f.Parent = square
		local up = TweenService:Create(f, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { BackgroundTransparency = peak })
		up.Completed:Once(function()
			local down =
				TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
			down.Completed:Once(function()
				f:Destroy()
			end)
			down:Play()
		end)
		up:Play()
	end
	local function bounce(gui, size)
		local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", gui)
		scale.Scale = size
		tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	-- a square's middle, in the popup's own (unscaled) pixels
	local function middle(gui)
		local k = holder.AbsoluteSize.X / math.max(holder.Size.X.Offset, 1)
		return (gui.AbsolutePosition + gui.AbsoluteSize / 2 - holder.AbsolutePosition) / k
	end
	local function squareOf(id)
		for _, entry in itemRows do
			local sq = entry[2]:FindFirstChild(id)
			if sq then
				return sq, entry[3]
			end
		end
		return nil, nil
	end
	function playMerge(id)
		local into = Config.Merge.Into[id]
		local from, _ = squareOf(id)
		local to, _ = squareOf(into or "")
		local templateFor = nil
		for _, entry in itemRows do
			if table.find(byRarity[entry[1]], into) then
				templateFor = entry[3]
			end
		end
		if merging or not (into and from and to and templateFor) then
			mergeRemote:FireServer(id)
			return
		end
		merging = true
		mergeButton.Visible = false
		local before = player:GetAttribute("Weapons")
		mergeRemote:FireServer(id)
		-- 1: the merged ones flash white and squash
		whiteFlash(from, 0.05)
		local fromScale = from:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", from)
		tween(fromScale, 0.08, { Scale = 0.82 })
		task.delay(0.1, function()
			tween(fromScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		-- 2: the new one pops up out of it...
		local fly = templateFor:Clone()
		fly.Name = "Merging"
		fly.Visible = true
		fly.Active = false
		fly.AnchorPoint = Vector2.new(0.5, 0.5)
		fly.ZIndex = 50
		for _, d in fly:GetDescendants() do
			if d.Name == "Ring" or d.Name == "Count" then
				d.Visible = false
			end
		end
		local img = fly:FindFirstChild("Icon")
		if img then
			icon(img, "Weapons", into)
		end
		local a, b = middle(from), middle(to)
		fly.Position = UDim2.fromOffset(a.X, a.Y)
		local flyScale = fly:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", fly)
		flyScale.Scale = 0
		fly.Parent = holder
		task.wait(0.12)
		tween(flyScale, 0.22, { Scale = 1.35 }, Enum.EasingStyle.Back)
		local lift = a - Vector2.new(0, 70)
		local t = Instance.new("NumberValue")
		tween(t, 0.22, { Value = 0.25 })
		t.Changed:Connect(function(v)
			if v <= 0.25 then
				local p = a:Lerp(lift, v / 0.25)
				fly.Position = UDim2.fromOffset(p.X, p.Y)
			end
		end)
		task.wait(0.3)
		-- 3: ...and drifts over to its square on a gentle arc, settling to its size
		local start = Vector2.new(fly.Position.X.Offset, fly.Position.Y.Offset)
		local control = (start + b) / 2 - Vector2.new(0, 90)
		local drift = Instance.new("NumberValue")
		drift.Changed:Connect(function(v)
			local p = start:Lerp(control, v):Lerp(control:Lerp(b, v), v)
			fly.Position = UDim2.fromOffset(p.X, p.Y)
			fly.Rotation = math.sin(v * math.pi) * -8
		end)
		TweenService:Create(drift, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
			:Play()
		tween(flyScale, 0.6, { Scale = 1 })
		task.wait(0.6)
		-- 4: it lands: (once the server's caught up) the square fills in or counts up
		local waited = 0
		while player:GetAttribute("Weapons") == before and waited < 2 do
			waited += task.wait()
		end
		fly:Destroy()
		merging = false
		rebuild()
		local landed = squareOf(into)
		if landed then
			whiteFlash(landed, 0.15)
			bounce(landed, 1.3)
			local count = landed:FindFirstChild("Count")
			if count and count.Visible then
				bounce(count, 1.6)
			end
		end
	end

	local function selectTab(name)
		tab = name
		for n, b in tabButtons do
			local on = n == name
			b.button.BackgroundTransparency = if on then 0.8 else 1
			b.art.ImageTransparency = if on then 0 else 0.5
		end
		grid.CanvasPosition = Vector2.zero
		items.CanvasPosition = Vector2.zero
		petRowsFrame.CanvasPosition = Vector2.zero
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
		if merging then
			return -- (playMerge rebuilds once its weapon lands)
		end
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
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		if holder.Visible and dirty then
			dirty = false
			rebuild()
		end
	end)
	selectTab("Weapons")
end

return Backpack
