-- The Backpack (QM, Oct 26: remade from QM's reference, designs/backpack_ref_*.png). A tiled
-- beige panel titled "Backpack", with Weapons and Pets tabs down its left side (the open one
-- gold), a list of every weapon or pet on the left and the one you've picked on the right.
--
--   The list: a section per rarity, its name in a pill of the rarity's colour (weapons with
--   how many there are) and a line of it running off to the right; under it every weapon or
--   pet of that rarity, the ones you have on their rarity's square ("x5" when there's more
--   than one), the rest locked ("?" under a padlock). The Pets tab has your pen on top:
--   "Equipped · 4/5" and its slots, an empty one dashed with a "+". What's equipped has a
--   green tick; what you've picked has a gold ring.
--   The right: the picked one big, its name, its rarity, how many you have (or "Equipped"),
--   and Equip (green) or Unequip (orange). Weapons: Equip holds it (EquipWeapon,
--   Server/Arsenal). Pets: Equip puts one in your pen, Unequip takes it out (PetEquip,
--   Server/PetInventory).
--   MERGE (weapons, while you can) sits on the list's bottom edge; the X on the top right.
--
-- In Studio it's StarterGui > Hud > Root > BackpackPopup (client/Ui). The squares are copied
-- from each section's OwnedTemplate and the LockedTemplate, so edit those; in Studio the list
-- is filled with a made-up mid-game player's things (PREVIEW) to see it by.
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
local Weapons = require(Shared.Weapons.Weapons)
local WeaponIcons = require(Shared.Weapons.WeaponIcons)
local Popups = require(script.Parent.Popups)
local Snappy = require(script.Parent.Snappy)
local Ui = require(script.Parent.Ui)

local Backpack = {}

local player = Players.LocalPlayer
local WHITE = Color3.new(1, 1, 1)
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local TYPE_ORDER = { Melee = 1, Ranged = 2, Magic = 3 }

-- the layout, in design px (the Hud's 1080-tall frame)
local SIZE = Vector2.new(1180, 760) -- the panel
local TAB_RAIL = 150 -- how far the tabs stick out past the panel's left edge
local PAD = 22 -- inside the panel, round the list and the details
local LIST_W = 740 -- the list's width (the details take the rest)
local ITEM = 100 -- a square
local ITEM_GAP = 14

local FONT = Font.fromEnum(Enum.Font.FredokaOne)
local MONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold) -- (MERGE)
local INK = Color3.fromHex("3B2416") -- the dark brown outline on the white text
local INSET = Color3.fromHex("F3E3CC") -- the list's and the details' panels
local INSET_LINE = Color3.fromHex("DCC3A3")
local LOCKED = Color3.fromHex("D9C3A6") -- a locked square
local LOCK_INK = Color3.fromHex("B49C7F") -- its padlock
local INFO = Color3.fromHex("EBD8BF") -- the details' "Owned: 9" bar
local INFO_TEXT = Color3.fromHex("5A4330")
local TAB_ON, TAB_ON_LINE = Color3.fromHex("F9C964"), Color3.fromHex("E79B22")
local TAB_OFF, TAB_OFF_LINE = Color3.fromHex("D7BC98"), Color3.fromHex("B48F69")
local TICK = Color3.fromHex("2DBE3C") -- the equipped tick's circle
local PEN_PILL = Color3.fromHex("8A6A4C") -- "Equipped · 4/5"
local BUTTONS = { -- the details' button: { face, outline and shadow }
	Equip = { Color3.fromHex("3CCB3C"), Color3.fromHex("1D8B25") },
	Unequip = { Color3.fromHex("F58F1E"), Color3.fromHex("B65A08") },
	Equipped = { Color3.fromHex("B9A88F"), Color3.fromHex("8E7C63") },
}

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
-- a rarity's pill (its section's name, the details' rarity): between its square's two colours
local function pillColor(rarity)
	local c = ITEM_COLORS[rarity] or ITEM_COLORS.Common
	return c.Dark:Lerp(c.Light, 0.45)
end
local ITEM_OUTLINE = 4 -- px
local RADIAL = "rbxassetid://106131181340173" -- (assets/ui/RadialGlow.png: white in the middle fading out)
local GOLD_RING = Color3.fromHex("F5B53F") -- round the one you've picked
local MERGE_TEXTURE = "rbxassetid://87121220953662" -- (assets/ui/merge_button_texture.png: QM's green checker)
local MERGE_DARK = Color3.fromHex("00A529") -- the MERGE button's outline and shadow
local CLOSE_DARK = Color3.fromHex("720006") -- the X's outline and shadow
local MERGE_PULSE = 0.05 -- how much bigger it swells at the top of each pulse
local MERGE_PULSE_TIME = 1.1 -- seconds a pulse takes
local MERGE_SPIN = 40 -- degrees a second the sunburst behind it turns

-- in Studio (not playing) the list shows a made-up mid-game player's things to edit by
local PREVIEW = {
	Weapons = "KendoStick:10,Staff:7,Axe,Longsword:15,Longbow,WindStaff:6,LightningStaff:7,Club:9,Waraxe:14,WaterStaff:6,NatureBow:9,BloodBow:6,FireStaff:10,UnholyLance:6,RafflesiaBloom:6",
	Weapon = "Club",
	PetsOwned = "Horse,Pinto,Fish:2,Rhino,Penguin,Snowman:3",
	PenPets = "Horse,Rhino,Pinto,Snowman",
}
local function attr(name)
	if Ui.live then
		return player:GetAttribute(name)
	end
	return PREVIEW[name]
end

local function tween(obj, t, goal, style)
	TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- ---- what you have --------------------------------------------------------------------

-- [weapon id] = how many (everyone has the starting one)
local function ownedWeapons()
	local list = Stacks.parse(attr("Weapons"), Weapons.exists)
	local map = { [Config.WeaponDrops.Start] = 1 }
	for _, s in list do
		map[s.id] = s.n
	end
	return map
end

local function heldWeapon()
	local id = attr("Weapon")
	return if Weapons.exists(id) then id else Config.WeaponDrops.Start
end

-- [pet kind] = how many
local function ownedPets()
	local map = {}
	for _, s in
		Stacks.parse(attr("PetsOwned"), function(kind)
			return Config.Pets[kind] ~= nil
		end)
	do
		map[s.id] = s.n
	end
	return map
end

-- the pets in your pen, in its slots' order
local function penPets()
	local list = {}
	for kind in string.gmatch(attr("PenPets") or "", "[^,]+") do
		if Config.Pets[kind] then
			table.insert(list, kind)
		end
	end
	return list
end

local function nameOf(tab, id)
	return if tab == "Weapons" then Weapons.get(id).Name else Pets.name(id)
end

local function rarityOf(tab, id)
	return if tab == "Weapons" then Config.Weapons[id].Rarity else Config.Pets[id].Rarity
end

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

-- ---- pieces ---------------------------------------------------------------------------

local function rounded(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent, color, thickness, border)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
	return s
end

-- white Fredoka One text with QM's dark brown outline (`outline` px; 0 for none)
local function label(parent, name, outline, props)
	local t, fresh = Ui.make(parent, name, "TextLabel")
	if fresh then
		t.BackgroundTransparency = 1
		t.FontFace = FONT
		t.TextColor3 = WHITE
		for k, v in props do
			t[k] = v
		end
		if outline > 0 then
			stroke(t, INK, outline)
		end
	end
	return t
end

-- a rounded panel: `fill` with a `line` outline
local function box(parent, name, fill, line, radius, props, class)
	local f, fresh = Ui.make(parent, name, class or "Frame")
	if fresh then
		f.BackgroundColor3 = fill
		f.BorderSizePixel = 0
		for k, v in props do
			f[k] = v
		end
		rounded(f, radius)
		if line then
			stroke(f, line, 3, true)
		end
	end
	return f, fresh
end

-- a green tick in a white-edged circle (the equipped mark): two bars, as there's no tick glyph
local function tick(parent, size, props)
	local c = Instance.new("Frame")
	c.Name = "Tick"
	c.BackgroundColor3 = TICK
	c.BorderSizePixel = 0
	c.Size = UDim2.fromOffset(size, size)
	for k, v in props do
		c[k] = v
	end
	rounded(c, size // 2)
	stroke(c, WHITE, math.max(2, size // 12), true)
	local function bar(len, x, y, angle)
		local b = Instance.new("Frame")
		b.BackgroundColor3 = WHITE
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.fromScale(x, y)
		b.Size = UDim2.new(len, 0, 0.14, 0)
		b.Rotation = angle
		b.ZIndex = c.ZIndex + 1
		rounded(b, 3)
		b.Parent = c
	end
	bar(0.3, 0.37, 0.56, 45)
	bar(0.52, 0.56, 0.47, -50)
	c.Parent = parent
	return c
end

-- the square of something you have: its rarity's radial square, its icon, "x5" top right
-- when there's more than one, a gold Ring round it when it's picked and a Tick when it's
-- equipped (both shown by the game)
local function ownedTemplate(rarity)
	return function()
		local colors = ITEM_COLORS[rarity] or ITEM_COLORS.Common
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.Size = UDim2.fromOffset(ITEM, ITEM)
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.fromScale(1, 1)
		ring.ZIndex = 1
		ring.Visible = false
		rounded(ring, 10)
		stroke(ring, GOLD_RING, 9, true)
		ring.Parent = b
		local panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.BackgroundColor3 = colors.Dark
		panel.BorderSizePixel = 0
		panel.Size = UDim2.fromScale(1, 1)
		panel.ZIndex = 2
		rounded(panel, 8)
		stroke(panel, colors.Outline, ITEM_OUTLINE, true).Name = "Outline"
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.BackgroundTransparency = 1
		glow.Image = RADIAL
		glow.ImageColor3 = colors.Light
		glow.Size = UDim2.fromScale(1, 1)
		glow.ZIndex = 2
		rounded(glow, 8)
		glow.Parent = panel
		panel.Parent = b
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.82, 0.82)
		img.ZIndex = 3
		img.Parent = b
		-- "x5": white on a dark pill in the top right corner
		local count = Instance.new("Frame")
		count.Name = "Count"
		count.BackgroundColor3 = Color3.fromHex("2A1E14")
		count.BackgroundTransparency = 0.25
		count.BorderSizePixel = 0
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -4, 0, 4)
		count.AutomaticSize = Enum.AutomaticSize.X
		count.Size = UDim2.fromOffset(0, 26)
		count.ZIndex = 4
		rounded(count, 8)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 6)
		pad.PaddingRight = UDim.new(0, 6)
		pad.Parent = count
		local n = Instance.new("TextLabel")
		n.Name = "Label"
		n.BackgroundTransparency = 1
		n.FontFace = FONT
		n.Text = "x5"
		n.TextSize = 22
		n.TextColor3 = WHITE
		n.AutomaticSize = Enum.AutomaticSize.X
		n.Size = UDim2.fromScale(0, 1)
		n.ZIndex = 5
		n.Parent = count
		count.Parent = b
		tick(b, 30, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, -6),
			Visible = false,
			ZIndex = 6,
		})
		return b
	end
end

-- something you haven't got yet: a beige square, a padlock, a "?"
local function lockedTemplate()
	local f = Instance.new("Frame")
	f.BackgroundColor3 = LOCKED
	f.BorderSizePixel = 0
	f.Size = UDim2.fromOffset(ITEM, ITEM)
	rounded(f, 8)
	local shackle = Instance.new("Frame")
	shackle.Name = "Shackle"
	shackle.BackgroundTransparency = 1
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Position = UDim2.fromScale(0.5, 0.14)
	shackle.Size = UDim2.fromOffset(18, 24)
	rounded(shackle, 9)
	stroke(shackle, LOCK_INK, 4, true)
	shackle.Parent = f
	local body = Instance.new("Frame")
	body.Name = "Lock"
	body.BackgroundColor3 = LOCK_INK
	body.BorderSizePixel = 0
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.fromScale(0.5, 0.3)
	body.Size = UDim2.fromOffset(28, 20)
	body.ZIndex = 2
	rounded(body, 4)
	body.Parent = f
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.FontFace = FONT
	mark.Text = "?"
	mark.TextSize = 46
	mark.TextColor3 = WHITE
	mark.TextTransparency = 0.3
	mark.AnchorPoint = Vector2.new(0.5, 0)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.new(1, 0, 0.45, 0)
	mark.Parent = f
	return f
end

-- an empty pen slot: a dashed outline, a "+" and "Empty"
local function emptySlotTemplate()
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(ITEM, ITEM)
	local dash, gap = 10, 7
	for side = 1, 4 do
		local along = 0
		while along < ITEM do
			local len = math.min(dash, ITEM - along)
			local d = Instance.new("Frame")
			d.BackgroundColor3 = LOCK_INK
			d.BorderSizePixel = 0
			if side == 1 then
				d.Position, d.Size = UDim2.fromOffset(along, 0), UDim2.fromOffset(len, 3)
			elseif side == 2 then
				d.Position, d.Size = UDim2.fromOffset(along, ITEM - 3), UDim2.fromOffset(len, 3)
			elseif side == 3 then
				d.Position, d.Size = UDim2.fromOffset(0, along), UDim2.fromOffset(3, len)
			else
				d.Position, d.Size = UDim2.fromOffset(ITEM - 3, along), UDim2.fromOffset(3, len)
			end
			d.Parent = f
			along += dash + gap
		end
	end
	for _, s in { UDim2.fromOffset(30, 8), UDim2.fromOffset(8, 30) } do
		local p = Instance.new("Frame")
		p.BackgroundColor3 = LOCK_INK
		p.BorderSizePixel = 0
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromScale(0.5, 0.4)
		p.Size = s
		rounded(p, 3)
		p.Parent = f
	end
	local t = Instance.new("TextLabel")
	t.Name = "Label"
	t.BackgroundTransparency = 1
	t.FontFace = FONT
	t.Text = "Empty"
	t.TextSize = 20
	t.TextColor3 = LOCK_INK
	t.AnchorPoint = Vector2.new(0.5, 0)
	t.Position = UDim2.fromScale(0.5, 0.66)
	t.Size = UDim2.new(1, 0, 0, 24)
	t.Parent = f
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

-- ---- the popup ------------------------------------------------------------------------

function Backpack.init()
	local _, holder = Popups.frame("Backpack", "Backpack", SIZE, true) -- (QM's tiled panel)
	Popups.grow("Backpack", 1, TAB_RAIL)
	local tab = "Weapons"
	local picked = {} -- [tab] = the id picked in it (shown on the right)
	local petRemote, weaponRemote, mergeRemote -- (in Play)
	local rebuild, showDetails -- (below)

	-- the title, over the panel's top edge
	label(holder, "Title", 6, {
		Text = "Backpack",
		TextSize = 84,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(500, 100),
		ZIndex = 8,
	})

	-- the tabs: a rail behind the panel's left edge, a square each (the open one gold)
	local rail = box(holder, "Tabs", TAB_OFF:Lerp(WHITE, 0.45), Color3.fromHex("C1A283"), 18, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(24, 40),
		Size = UDim2.fromOffset(TAB_RAIL + 24, 2 * 150 + 3 * 14),
		ZIndex = 0,
	})
	local tabButtons = {}
	for i, name in { "Weapons", "Pets" } do
		local b = box(rail, name .. "Tab", TAB_OFF, TAB_OFF_LINE, 14, {
			Position = UDim2.fromOffset(14, 14 + (i - 1) * 164),
			Size = UDim2.fromOffset(TAB_RAIL - 22, 150),
			ZIndex = 1,
			Text = "",
			AutoButtonColor = false,
		}, "TextButton")
		local art, artFresh = Ui.make(b, "Icon", "ImageLabel")
		if artFresh then
			art.BackgroundTransparency = 1
			art.ScaleType = Enum.ScaleType.Fit
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.fromScale(0.5, 0.06)
			art.Size = UDim2.fromScale(0.72, 0.6)
			art.ZIndex = 2
			art.Image = if name == "Pets" then PetIcons.Pets.Horse or "" else WeaponIcons.Club or ""
		end
		label(b, "Label", 3, {
			Text = name,
			TextSize = 30,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.new(1, 0, 0, 34),
			ZIndex = 3,
		})
		tabButtons[name] = b
	end
	local function paintTabs()
		for name, b in tabButtons do
			local on = name == tab
			b.BackgroundColor3 = if on then TAB_ON else TAB_OFF
			local s = b:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = if on then TAB_ON_LINE else TAB_OFF_LINE
				s.Thickness = if on then 5 else 3
			end
		end
	end

	-- the list (left) and the details (right), on lighter panels
	local list = box(holder, "List", INSET, INSET_LINE, 16, {
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.new(0, LIST_W, 1, -2 * PAD),
		ZIndex = 2,
	})
	local details = box(holder, "Details", INSET, INSET_LINE, 16, {
		Position = UDim2.fromOffset(PAD * 2 + LIST_W, PAD),
		Size = UDim2.new(1, -(PAD * 3 + LIST_W), 1, -2 * PAD),
		ZIndex = 2,
	})

	-- a scrolling column of rarity sections
	local function column(parent, name, top)
		local s, sFresh = Ui.make(parent, name, "ScrollingFrame")
		if sFresh then
			s.BackgroundTransparency = 1
			s.BorderSizePixel = 0
			s.Position = UDim2.fromOffset(0, top)
			s.Size = UDim2.new(1, 0, 1, -top)
			s.CanvasSize = UDim2.new()
			s.AutomaticCanvasSize = Enum.AutomaticSize.Y
			s.ScrollingDirection = Enum.ScrollingDirection.Y
			s.ScrollBarThickness = 6
			s.ScrollBarImageColor3 = INSET_LINE
			s.ZIndex = 3
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 16)
			pad.PaddingLeft = UDim.new(0, 18)
			pad.PaddingRight = UDim.new(0, 18)
			pad.PaddingBottom = UDim.new(0, 60) -- (room for MERGE on the bottom edge)
			pad.Parent = s
			local layout = Instance.new("UIListLayout")
			layout.Name = "Layout"
			layout.Padding = UDim.new(0, 10)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = s
		end
		return s
	end

	-- a section's header: its name on a pill of `color`, a line of it off to the right
	local function header(parent, name, text, color, order)
		local h, hFresh = Ui.make(parent, name, "Frame")
		if hFresh then
			h.BackgroundTransparency = 1
			h.Size = UDim2.new(1, 0, 0, 38)
			h.LayoutOrder = order
			h.ZIndex = 3
			local line = Instance.new("Frame")
			line.Name = "Line"
			line.BackgroundColor3 = color
			line.BackgroundTransparency = 0.45
			line.BorderSizePixel = 0
			line.AnchorPoint = Vector2.new(0, 0.5)
			line.Position = UDim2.fromScale(0, 0.5)
			line.Size = UDim2.new(1, 0, 0, 4)
			line.ZIndex = 3
			rounded(line, 2)
			line.Parent = h
		end
		local pill = box(h, "Pill", color, nil, 19, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 38),
			ZIndex = 4,
		})
		if not pill:FindFirstChildOfClass("UIPadding") then
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 16)
			pad.PaddingRight = UDim.new(0, 16)
			pad.Parent = pill
		end
		local t = label(pill, "Label", 3, {
			TextSize = 28,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 5,
		})
		t.Text = text
		return h
	end

	-- a section's squares, as many to a row as fit
	local function grid(parent, name, order)
		local g, gFresh = Ui.make(parent, name, "Frame")
		if gFresh then
			g.BackgroundTransparency = 1
			g.AutomaticSize = Enum.AutomaticSize.Y
			g.Size = UDim2.new(1, 0, 0, ITEM)
			g.LayoutOrder = order
			g.ZIndex = 3
			local layout = Instance.new("UIGridLayout")
			layout.Name = "Layout"
			layout.CellSize = UDim2.fromOffset(ITEM, ITEM)
			layout.CellPadding = UDim2.fromOffset(ITEM_GAP, ITEM_GAP)
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.Parent = g
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 6)
			pad.PaddingLeft = UDim.new(0, 4)
			pad.PaddingBottom = UDim.new(0, 6)
			pad.Parent = g
		end
		return g
	end

	-- the Weapons tab's list: every rarity that has weapons
	local weaponsBy = weaponsByRarity()
	local weaponsPage = column(list, "WeaponsList", 0)
	local weaponSections = {} -- { { rarity, header, grid, template } }
	for i, rarity in RARITIES do
		if weaponsBy[rarity] then
			local h = header(
				weaponsPage,
				rarity .. "Header",
				string.format("%s (%d)", rarity, #weaponsBy[rarity]),
				pillColor(rarity),
				i * 2 - 1
			)
			local g = grid(weaponsPage, rarity, i * 2)
			table.insert(weaponSections, { rarity, h, g, Ui.template(g, "OwnedTemplate", ownedTemplate(rarity)) })
		end
	end
	local lockedOne = Ui.template(weaponsPage, "LockedTemplate", lockedTemplate)

	-- the Pets tab: your pen on top ("Equipped · 4/5", its slots), the rarities under it
	local petsPage, petsFresh = Ui.make(list, "PetsList", "Frame")
	if petsFresh then
		petsPage.BackgroundTransparency = 1
		petsPage.Size = UDim2.fromScale(1, 1)
		petsPage.ZIndex = 3
	end
	local penTop, penTopFresh = Ui.make(petsPage, "Pen", "Frame")
	if penTopFresh then
		penTop.BackgroundTransparency = 1
		penTop.Position = UDim2.fromOffset(18, 16)
		penTop.Size = UDim2.new(1, -36, 0, 38 + 10 + ITEM + 24)
		penTop.ZIndex = 3
	end
	local penHeader = header(penTop, "Header", "Equipped", PEN_PILL, 0)
	local penBox = box(penTop, "Slots", INSET:Lerp(INSET_LINE, 0.35), INSET_LINE, 14, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, ITEM + 24),
		ZIndex = 3,
	})
	if not penBox:FindFirstChild("Layout") then
		local layout = Instance.new("UIListLayout")
		layout.Name = "Layout"
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, ITEM_GAP + 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = penBox
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.Parent = penBox
	end
	local emptyOne = Ui.template(penBox, "EmptyTemplate", emptySlotTemplate)
	local petsBy = petsByRarity()
	local petsColumn = column(petsPage, "Rarities", 16 + 38 + 10 + ITEM + 24 + 10)
	local petSections = {}
	for i, rarity in RARITIES do
		if petsBy[rarity] then
			local h = header(petsColumn, rarity .. "Header", rarity, pillColor(rarity), i * 2 - 1)
			local g = grid(petsColumn, rarity, i * 2)
			table.insert(petSections, { rarity, h, g, Ui.template(g, "OwnedTemplate", ownedTemplate(rarity)) })
		end
	end
	local petLocked = Ui.template(petsColumn, "LockedTemplate", lockedTemplate)
	local function petTemplate(rarity)
		for _, s in petSections do
			if s[1] == rarity then
				return s[4]
			end
		end
		return petSections[1][4]
	end

	-- the details: the picked one big, its name, its rarity, how many, and its button
	local big = box(details, "Big", ITEM_COLORS.Rare.Dark, nil, 16, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(290, 290),
		ZIndex = 3,
	})
	local bigOutline = big:FindFirstChild("Outline") or stroke(big, ITEM_COLORS.Rare.Outline, 6, true)
	bigOutline.Name = "Outline"
	local bigGlow, glowFresh = Ui.make(big, "Glow", "ImageLabel")
	if glowFresh then
		bigGlow.BackgroundTransparency = 1
		bigGlow.Image = RADIAL
		bigGlow.Size = UDim2.fromScale(1, 1)
		bigGlow.ZIndex = 3
		rounded(bigGlow, 16)
	end
	local bigIcon, bigIconFresh = Ui.make(big, "Icon", "ImageLabel")
	if bigIconFresh then
		bigIcon.BackgroundTransparency = 1
		bigIcon.ScaleType = Enum.ScaleType.Fit
		bigIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		bigIcon.Position = UDim2.fromScale(0.5, 0.5)
		bigIcon.Size = UDim2.fromScale(0.84, 0.84)
		bigIcon.ZIndex = 4
	end
	local nameLabel = label(details, "ItemName", 5, {
		TextSize = 48,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 330),
		Size = UDim2.new(1, -20, 0, 56),
		TextScaled = false,
		ZIndex = 3,
	})
	local rarityPill = box(details, "Rarity", pillColor("Rare"), nil, 22, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 396),
		Size = UDim2.fromOffset(220, 44),
		ZIndex = 3,
	})
	local rarityLabel = label(rarityPill, "Label", 0, {
		TextSize = 30,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	local info = box(details, "Info", INFO, nil, 12, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 458),
		Size = UDim2.new(1, -44, 0, 62),
		ZIndex = 3,
	})
	local infoTick = info:FindFirstChild("Tick")
		or tick(info, 40, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 26, 0.5, 0),
			ZIndex = 4,
		})
	local infoLabel = label(info, "Label", 0, {
		TextSize = 32,
		TextColor3 = INFO_TEXT,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	})
	-- the button: a face on a solid shadow of its outline's colour
	local action, actionFresh = Ui.make(details, "Action", "TextButton")
	if actionFresh then
		action.Text = ""
		action.AutoButtonColor = false
		action.BackgroundTransparency = 1
		action.AnchorPoint = Vector2.new(0.5, 0)
		action.Position = UDim2.new(0.5, 0, 0, 542)
		action.Size = UDim2.new(1, -44, 0, 84)
		action.ZIndex = 3
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.BorderSizePixel = 0
		shadow.Position = UDim2.fromOffset(0, 7)
		shadow.Size = UDim2.fromScale(1, 1)
		shadow.ZIndex = 3
		rounded(shadow, 16)
		shadow.Parent = action
		local face = Instance.new("Frame")
		face.Name = "Face"
		face.BorderSizePixel = 0
		face.Size = UDim2.fromScale(1, 1)
		face.ZIndex = 4
		rounded(face, 16)
		stroke(face, BUTTONS.Equip[2], 4, true)
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
		shine.Rotation = 90
		shine.Parent = face
		face.Parent = action
	end
	local actionLabel = label(action, "Label", 4, {
		TextSize = 50,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local function paintAction(kind)
		local c = BUTTONS[kind]
		action.Shadow.BackgroundColor3 = c[2]
		action.Face.BackgroundColor3 = c[1]
		action.Face:FindFirstChildOfClass("UIStroke").Color = c[2]
		actionLabel.Text = kind
		action.Active = kind ~= "Equipped"
		action:SetAttribute("Does", kind)
	end

	-- the X, over the top right corner (QM's Figma, designs/figma/close_button.md)
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
		stroke(bodyFrame, CLOSE_DARK, math.round(10 * k), true)
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
			t.Position = UDim2.fromOffset(0, dy - 4) -- (a lowercase x sits low in its line: up to centre it)
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
		Snappy.hook(close, { 9, 6 })
		close.Activated:Connect(function()
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
		mergeButton.Position = UDim2.new(0, PAD + LIST_W // 2, 1, -math.round(114 * k))
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
		stroke(bodyImg, MERGE_DARK, math.round(10 * k), true)
		bodyImg.Parent = plate
		local function word(name, color, dy, z, transparency)
			local t = Instance.new("TextLabel")
			t.Name = name
			t.BackgroundTransparency = 1
			t.FontFace = MONT
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
		Snappy.hook(mergeButton, { 9, 6 })
		-- while it's up: a gentle pulse, and the sunburst behind it turning (QM)
		local rays = mergeButton:FindFirstChild("Rays")
		local t = 0
		RunService.RenderStepped:Connect(function(dt)
			if not (mergeButton.Visible and holder.Visible) then
				return
			end
			t += dt
			scale.Scale = 1 + MERGE_PULSE * math.sin(t * math.pi * 2 / MERGE_PULSE_TIME)
			if rays then
				rays.Rotation = (rays.Rotation + dt * MERGE_SPIN) % 360
			end
		end)
		mergeButton.Activated:Connect(function()
			if mergeRemote and playMerge then
				playMerge()
			end
		end)
	end

	-- ---- filling it in ---------------------------------------------------------------

	local weaponSquares = {} -- [id] = its square in the list (for the merge's flights)

	local function clear(parent)
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") and not Ui.isTemplate(child) then
				child:Destroy()
			end
		end
	end

	-- a square of something you have, copied from `template`
	local function square(template, parent, id, order, count, equipped)
		local b = Ui.copy(template, id, parent)
		b.LayoutOrder = order
		local img = b:FindFirstChild("Icon")
		if img then
			icon(img, tab, id)
		end
		local c = b:FindFirstChild("Count")
		if c then
			c.Visible = count > 1
			local n = c:FindFirstChild("Label")
			if n then
				n.Text = "x" .. count
			end
		end
		local t = b:FindFirstChild("Tick")
		if t then
			t.Visible = equipped
		end
		local ring = b:FindFirstChild("Ring")
		if ring then
			ring.Visible = picked[tab] == id
		end
		if Ui.live then
			b.Activated:Connect(function()
				picked[tab] = id
				for _, other in list:GetDescendants() do
					if other.Name == "Ring" and other.Parent and not Ui.isTemplate(other.Parent) then
						other.Visible = other.Parent.Name == id
					end
				end
				showDetails()
			end)
		end
		return b
	end

	local function locked(template, parent, name, order)
		local l = Ui.copy(template, name, parent)
		l.LayoutOrder = order
		return l
	end

	local function fillWeapons()
		local owned, held = ownedWeapons(), heldWeapon()
		if not (picked.Weapons and owned[picked.Weapons]) then
			picked.Weapons = held
		end
		table.clear(weaponSquares)
		for _, s in weaponSections do
			local rarity, g, template = s[1], s[3], s[4]
			clear(g)
			for i, id in weaponsBy[rarity] do
				if owned[id] then
					weaponSquares[id] = square(template, g, id, i, owned[id], id == held)
				else
					locked(lockedOne, g, id, i)
				end
			end
		end
	end

	local function fillPets()
		local owned, pen = ownedPets(), penPets()
		local inPen = {}
		for _, kind in pen do
			inPen[kind] = true
		end
		if not (picked.Pets and owned[picked.Pets]) then
			picked.Pets = pen[1] or next(owned)
		end
		local slots = Config.Backpack.PenSlots
		penHeader.Pill.Label.Text = string.format("Equipped · %d/%d", #pen, slots)
		clear(penBox)
		for i = 1, slots do
			local kind = pen[i]
			if kind then
				square(petTemplate(Config.Pets[kind].Rarity), penBox, kind, i, 1, false)
			else
				Ui.copy(emptyOne, "Empty" .. i, penBox).LayoutOrder = i
			end
		end
		for _, s in petSections do
			local rarity, g, template = s[1], s[3], s[4]
			clear(g)
			for i, kind in petsBy[rarity] do
				if owned[kind] then
					square(template, g, kind, i, owned[kind], inPen[kind] == true)
				else
					locked(petLocked, g, kind, i)
				end
			end
		end
	end

	-- the right: what's picked in the open tab
	function showDetails()
		local id = picked[tab]
		local has = id and (if tab == "Weapons" then ownedWeapons()[id] else ownedPets()[id])
		for _, child in details:GetChildren() do
			if child:IsA("GuiObject") then
				child.Visible = has ~= nil
			end
		end
		if not has then
			return
		end
		local rarity = rarityOf(tab, id)
		local colors = ITEM_COLORS[rarity] or ITEM_COLORS.Common
		big.BackgroundColor3 = colors.Dark
		bigOutline.Color = colors.Outline
		bigGlow.ImageColor3 = colors.Light
		for _, child in big:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
		icon(bigIcon, tab, id)
		nameLabel.Text = nameOf(tab, id)
		rarityPill.BackgroundColor3 = pillColor(rarity)
		rarityLabel.Text = rarity
		local equipped
		if tab == "Weapons" then
			equipped = heldWeapon() == id
			paintAction(if equipped then "Equipped" else "Equip")
		else
			equipped = table.find(penPets(), id) ~= nil
			paintAction(if equipped then "Unequip" else "Equip")
		end
		infoTick.Visible = equipped
		infoLabel.Text = if equipped then "      Equipped" else "Owned: " .. has
	end

	local merging = false
	function rebuild()
		weaponsPage.Visible = tab == "Weapons"
		petsPage.Visible = tab == "Pets"
		paintTabs()
		if tab == "Weapons" then
			fillWeapons()
		else
			fillPets()
		end
		showDetails()
		local owned = ownedWeapons()
		local can = false
		for id, n in owned do
			if Config.Merge.Into[id] and n >= Config.Merge.Cost then
				can = true
			end
		end
		mergeButton.Visible = tab == "Weapons" and can and not merging
	end

	if not Ui.live then
		-- (in Studio: the Weapons tab, filled with PREVIEW's things)
		rebuild()
		return
	end

	petRemote = ReplicatedStorage:WaitForChild("PetEquip", 10)
	weaponRemote = ReplicatedStorage:WaitForChild("EquipWeapon", 10)
	mergeRemote = ReplicatedStorage:WaitForChild("MergeWeapon", 10)

	-- the details' button
	Snappy.hook(action, { 16, 6 })
	action.Activated:Connect(function()
		local id = picked[tab]
		local does = action:GetAttribute("Does")
		if not id or does == "Equipped" then
			return
		end
		if tab == "Weapons" then
			if weaponRemote then
				weaponRemote:FireServer(id)
			end
		elseif does == "Unequip" then
			local at = table.find(penPets(), id)
			if at and petRemote then
				petRemote:FireServer("unequip", at)
			end
		elseif #penPets() < Config.Backpack.PenSlots then
			if petRemote then
				petRemote:FireServer("equip", id)
			end
		else
			-- (the pen's full: a quick red flash on the button says so)
			actionLabel.Text = "Pen full!"
			action.Face.BackgroundColor3 = Color3.fromHex("E5484D")
			task.delay(0.6, showDetails)
		end
	end)

	-- the tabs
	for name, b in tabButtons do
		local reset = Snappy.hook(b, { 14, 4 })
		b.Activated:Connect(function()
			if tab ~= name then
				reset() -- (its look's about to change: let go of the faded one first)
				tab = name
				weaponsPage.CanvasPosition = Vector2.zero
				petsColumn.CanvasPosition = Vector2.zero
				rebuild()
			end
		end)
	end

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
	-- a weapon's square in the list (locked or not)
	local function squareOf(id)
		for _, s in weaponSections do
			local sq = s[3]:FindFirstChild(id)
			if sq then
				return sq
			end
		end
		return nil
	end
	-- one merge's flight: id's square flashes and squashes, what it makes pops up out of it and
	-- drifts over to its own square (yields until it's there)
	local function flight(id, into, from, to, template)
		whiteFlash(from, 0.05)
		local fromScale = from:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", from)
		tween(fromScale, 0.08, { Scale = 0.82 })
		task.delay(0.1, function()
			tween(fromScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		local fly = template:Clone()
		fly.Name = "Merging"
		fly.Visible = true
		fly.Active = false
		fly.AnchorPoint = Vector2.new(0.5, 0.5)
		fly.ZIndex = 50
		for _, d in fly:GetDescendants() do
			if d.Name == "Ring" or d.Name == "Count" or d.Name == "Tick" then
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
		-- pops up out of it...
		tween(flyScale, 0.22, { Scale = 1.35 }, Enum.EasingStyle.Back)
		local lift = a - Vector2.new(0, 70)
		local t = Instance.new("NumberValue")
		t.Changed:Connect(function(v)
			local p = a:Lerp(lift, v)
			fly.Position = UDim2.fromOffset(p.X, p.Y)
		end)
		tween(t, 0.22, { Value = 1 })
		task.wait(0.3)
		-- ...and drifts over to its square on a gentle arc, settling to its size
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
		fly:Destroy()
	end

	-- MERGE does every merge you can at once (QM): each weapon you've Config.Merge.Cost or more
	-- of goes up its ladder as many times as it can, counted from what you have now (what the
	-- merges make doesn't merge again till the next press). Each one flies, a beat apart; only
	-- when they've all landed do their squares fill in or count up.
	function playMerge()
		if merging then
			return
		end
		local owned = ownedWeapons()
		local flights = {}
		for _, rarity in RARITIES do
			for _, id in weaponsBy[rarity] or {} do
				local into = Config.Merge.Into[id]
				if into and (owned[id] or 0) >= Config.Merge.Cost then
					local from, to = squareOf(id), squareOf(into)
					local template = nil
					for _, s in weaponSections do
						if s[1] == Config.Weapons[into].Rarity then
							template = s[4]
						end
					end
					if from and to and template then
						table.insert(flights, { id, into, from, to, template })
					end
				end
			end
		end
		merging = true
		mergeButton.Visible = false
		local before = player:GetAttribute("Weapons")
		mergeRemote:FireServer()
		local flying = #flights
		for i, f in flights do
			task.delay((i - 1) * 0.12, function()
				flight(table.unpack(f))
				flying -= 1
			end)
		end
		while flying > 0 do
			task.wait()
		end
		-- they've landed: (once the server's caught up) the squares fill in or count up
		local waited = 0
		while player:GetAttribute("Weapons") == before and waited < 2 do
			waited += task.wait()
		end
		merging = false
		rebuild()
		for _, f in flights do
			local landed = squareOf(f[2])
			if landed then
				whiteFlash(landed, 0.15)
				bounce(landed, 1.3)
				local count = landed:FindFirstChild("Count")
				if count and count.Visible then
					bounce(count, 1.6)
				end
			end
		end
	end

	-- kept up to date while it's open (and fresh each time it opens)
	local dirty = false
	local function changed()
		if merging then
			return -- (playMerge rebuilds once its weapons land)
		end
		if holder.Visible then
			rebuild()
		else
			dirty = true
		end
	end
	for _, name in { "Weapons", "PetsOwned", "PenPets" } do
		player:GetAttributeChangedSignal(name):Connect(changed)
	end
	-- (switching weapons only moves the tick and the details: rebuilding every square made
	-- their counts flicker, QM)
	player:GetAttributeChangedSignal("Weapon"):Connect(function()
		if merging then
			return
		end
		local held = heldWeapon()
		for id, sq in weaponSquares do
			local t = sq:FindFirstChild("Tick")
			if t then
				t.Visible = id == held
			end
		end
		if tab == "Weapons" then
			showDetails()
		end
	end)
	holder:GetPropertyChangedSignal("Visible"):Connect(function()
		if holder.Visible and dirty then
			dirty = false
			rebuild()
		end
	end)
	rebuild()
end

return Backpack
