-- The Index (QM's Figma Index refs, Oct 30), opened by the blue Index button on the left:
-- the Weapon Shop's popup (client/WeaponShop: its header's shine, the red X, the dark panel)
-- with a pink and purple header. In it:
--   left    a box scrolling through a section per biome (Config.Index.Order): the biome's
--           picture (a Studio screenshot, HudImages Biome<Name>) and its pets as tiles in
--           a collage, then a bar of how many of them you've found. A pet you've never
--           owned (player attribute PetIndex: Server/PetIndex) is a dark "???" silhouette.
--   bottom  Unlocked: found / every pet, by the Index book
--   right   the picked pet's card (its rarity's colours: name, rarity, cash a second; "???"
--           for one not found), and under it its reward (Shared/IndexList.reward: Power and
--           cash) with Claim! (IndexClaim remote). Once that's claimed the card shows the
--           pet's Health, Regen and Speed instead (QM, Oct 30).
-- A red "!" sits on the Index button while there's a reward to claim.
--
-- The collage (QM: biomes have different numbers of pets and every grid should be full): a
-- biome's grid is COLS cells across and 2 down (more rows when it has more than 2 x COLS
-- pets), tiled by exactly its number of pets with 2x2, 1x2, 2x1 and 1x1 tiles, as many big
-- ones as fit; its rarest pets get the biggest tiles.
--
--   IndexPanel.init(root, indexButton)   -- once, from Hud
--   IndexPanel.open() / IndexPanel.close() / IndexPanel.isOpen()
--
-- In Studio: StarterGui > Hud > Root > IndexPanel (tick its Visible to see it). Sections are
-- copies of Box > Sections > SectionTemplate and tiles of Sections > TileTemplate: edit those.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local IndexList = require(Shared.IndexList)
local Pets = require(Shared.Pets)
local Abbrev = require(Shared.Abbrev)
local RarityLook = require(Shared.RarityLook)
local HudImages = require(script.Parent.HudImages)
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local IndexPanel = {}

local player = Players.LocalPlayer
local fig, art, label, button = HudKit.fig, HudKit.art, HudKit.label, HudKit.button
local function hex(h)
	return Color3.fromHex(h)
end

-- (Figma px, through fig: the popup is the Weapon Shop's 2268 x 1370)
local W, H = 2268, 1370
local SHINE = { { at = 0.62, width = 0.07 }, { at = 0.72, width = 0.025 } } -- (the shop's)
local SHINE_SLANT = 22
local SHINE_ALPHA = 0.7
local LEFT_W = 1600 -- the sections' box
local BOX_TOP, BOX_H = 323, 800
local RIGHT_X = 1680
local RIGHT_W = W - 40 - RIGHT_X
local CARD_H = 560 -- the picked pet's card
-- a section: the biome picture on its left, the collage, the bar under it
local PAD = 22
local PICTURE_W = 400
local COLS = 5
local GAP = 14
local BAR_H = 100
local CASH_GREEN = Color3.fromRGB(0, 255, 0)
local LOCKED_SHADE = 0.45 -- the dark over a tile not found (its transparency)
local SILHOUETTE = 0.35 -- a pet not found's picture: black, this transparent
local PICK = 8 -- the picked tile's white ring (Figma px)

local gui, sections, sectionTemplate, tileTemplate
local card, rewards, unlocked, badge
local tiles = {} -- [kind] = tile
local bars = {} -- [biome] = section
local picked

-- ---- the collage ------------------------------------------------------------------------

local SHAPES = { { 2, 2 }, { 1, 2 }, { 2, 1 }, { 1, 1 } } -- (tried biggest first)

-- n tiles exactly filling a COLS-wide grid: { { x, y, w, h } } (cells, from 0) and its rows
local function collage(n)
	local rows = math.max(2, math.ceil(n / COLS))
	while true do
		local cells = COLS * rows
		local taken, placed = {}, {}
		local best, bestScore
		local function score()
			local s = 0
			for _, p in placed do
				if p[3] == 2 and p[4] == 2 then
					s += 3
				elseif p[3] ~= p[4] then
					s -= 1
				end
			end
			return s
		end
		local function solve(free)
			local first
			for i = 0, cells - 1 do
				if not taken[i] then
					first = i
					break
				end
			end
			if not first then
				if #placed == n then
					local s = score()
					if not bestScore or s > bestScore then
						bestScore, best = s, table.clone(placed)
					end
				end
				return
			end
			local left = n - #placed
			if left <= 0 or free < left or free > 4 * left then
				return
			end
			local x, y = first % COLS, first // COLS
			for _, shape in SHAPES do
				local w, h = shape[1], shape[2]
				if x + w <= COLS and y + h <= rows then
					local fits = true
					for dy = 0, h - 1 do
						for dx = 0, w - 1 do
							if taken[(y + dy) * COLS + x + dx] then
								fits = false
							end
						end
					end
					if fits then
						for dy = 0, h - 1 do
							for dx = 0, w - 1 do
								taken[(y + dy) * COLS + x + dx] = true
							end
						end
						table.insert(placed, { x, y, w, h })
						solve(free - w * h)
						table.remove(placed)
						for dy = 0, h - 1 do
							for dx = 0, w - 1 do
								taken[(y + dy) * COLS + x + dx] = nil
							end
						end
					end
				end
			end
		end
		if n <= cells then
			solve(cells)
		end
		if best then
			return best, rows
		end
		rows += 1
	end
end

-- ---- building ---------------------------------------------------------------------------

-- a rarity's colours on a back's Fill (the Weapon Shop's cards': Config.Rarities)
local function paintBack(back, rarity)
	local fill = back and back:FindFirstChild("Fill")
	if not fill then
		return
	end
	local look = Config.Rarities[rarity] or Config.Rarities.Common
	fill.Rotation = 90
	if look.top then
		fill.Color = if look.at < 1
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, look.top),
				ColorSequenceKeypoint.new(1 - look.at, look.top),
				ColorSequenceKeypoint.new(1, look.bottom),
			})
			else ColorSequence.new(look.top, look.bottom)
	else
		fill.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	end
end

-- a pet's tile (any size: the collage sets it), a button
local function tileTemplateBuild()
	local tile = Instance.new("ImageButton")
	tile.BackgroundTransparency = 1
	tile.Image = ""
	tile.AutoButtonColor = false
	tile.Size = UDim2.fromOffset(fig(200), fig(200))
	HudKit.back(tile, "Card", {})
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, fig(10))
	round.Parent = tile
	local grow = Instance.new("UIScale")
	grow.Name = "Hover"
	grow.Parent = tile
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BackgroundColor3 = HudKit.BLACK
	shade.BackgroundTransparency = LOCKED_SHADE
	shade.BorderSizePixel = 0
	shade.Size = UDim2.fromScale(1, 1)
	shade.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, fig(10))
	corner.Parent = shade
	shade.Parent = tile
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.55)
	picture.Size = UDim2.fromScale(0.86, 0.8)
	picture.ZIndex = 3
	picture.Parent = tile
	local name = label(tile, "PetName", {
		Text = "???",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, fig(6)),
		Size = UDim2.new(0.92, 0, 0, fig(40)),
		ZIndex = 4,
	})
	name.Outline.Thickness = 2
	local ring = Instance.new("UIStroke")
	ring.Name = "Pick"
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = fig(PICK)
	ring.Enabled = false
	ring.Parent = tile
	return tile
end

-- a biome's section (its height is set when it's filled)
local function sectionTemplateBuild()
	local section = Instance.new("Frame")
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, 0, 0, fig(560))
	local picture = HudKit.back(section, "IndexCard", {
		Name = "Biome",
		Position = UDim2.fromOffset(fig(PAD), fig(PAD)),
		Size = UDim2.new(0, fig(PICTURE_W), 1, -2 * fig(PAD)),
		ClipsDescendants = true,
	})
	local shot = Instance.new("ImageLabel")
	shot.Name = "Shot"
	shot.BackgroundTransparency = 1
	shot.ScaleType = Enum.ScaleType.Crop
	shot.Size = UDim2.fromScale(1, 1)
	shot.ZIndex = 2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, fig(10))
	corner.Parent = shot
	shot.Parent = picture
	label(picture, "BiomeName", {
		Text = "Meadow",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -fig(16)),
		Size = UDim2.new(0.9, 0, 0, fig(70)),
		ZIndex = 3,
	})
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(fig(PAD + PICTURE_W + PAD), fig(PAD))
	grid.Size = UDim2.new(1, -fig(PAD + PICTURE_W + 2 * PAD), 1, -fig(2 * PAD + BAR_H + PAD))
	grid.Parent = section
	-- the bar: dark track, green fill, "4/7", the biome's rarest egg at its end
	local track = HudKit.back(section, "EggTrack", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, fig(PAD + PICTURE_W + PAD), 1, -fig(PAD)),
		Size = UDim2.new(1, -fig(PAD + PICTURE_W + 2 * PAD + 60), 0, fig(BAR_H)),
	})
	local fill = Instance.new("Frame")
	fill.Name = "Found"
	fill.BackgroundTransparency = 1
	fill.ClipsDescendants = true
	fill.Size = UDim2.fromScale(0.5, 1)
	fill.ZIndex = 2
	fill.Parent = track
	HudKit.back(fill, "EggGrow", { Name = "Green", ZIndex = 2 })
	label(track, "Count", {
		Text = "0/0",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(75),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	local egg = Instance.new("ImageLabel")
	egg.Name = "Egg"
	egg.BackgroundTransparency = 1
	egg.ScaleType = Enum.ScaleType.Fit
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = UDim2.new(1, fig(10), 0.5, 0)
	egg.Size = UDim2.fromOffset(fig(150), fig(150))
	egg.Rotation = 15
	egg.ZIndex = 4
	egg.Parent = track
	return section
end

local function build(root)
	local fresh
	gui, fresh = Ui.make(root, "IndexPanel", "Frame")
	if fresh then
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(0.5, 0.5)
		gui.Position = UDim2.fromScale(0.5, 0.5)
		gui.Size = UDim2.fromOffset(fig(W), fig(H))
		gui.ZIndex = 10
		gui.Visible = not Ui.live
	end
	Ui.make(gui, "Pop", "UIScale")
	HudKit.back(gui, "Panel", {
		Name = "Panel",
		Position = UDim2.fromOffset(0, fig(263)),
		Size = UDim2.fromOffset(fig(W), fig(H - 263)),
	})
	local header = HudKit.back(gui, "PinkHeader", {
		Name = "Header",
		Size = UDim2.fromOffset(fig(W), fig(283)),
		ZIndex = 2,
	})
	local shine
	shine, fresh = Ui.make(header, "Shine", "CanvasGroup")
	if fresh then
		shine.BackgroundTransparency = 1
		shine.Size = UDim2.fromScale(1, 1)
		shine.GroupTransparency = SHINE_ALPHA
		shine.ZIndex = 2
		for i, s in SHINE do
			local stripe = Instance.new("Frame")
			stripe.Name = "Stripe" .. i
			stripe.BackgroundColor3 = Color3.new(1, 1, 1)
			stripe.BorderSizePixel = 0
			stripe.AnchorPoint = Vector2.new(0.5, 0.5)
			stripe.Position = UDim2.fromScale(s.at, 0.5)
			stripe.Size = UDim2.new(s.width, 0, 2, 0)
			stripe.Rotation = SHINE_SLANT
			stripe.Parent = shine
		end
	end
	for _, t in { { "TitleShadow", 8, HudKit.BLACK }, { "Title", 0, Color3.new(1, 1, 1) } } do
		label(gui, t[1], {
			Text = "Index",
			TextSize = fig(130),
			TextColor3 = t[3],
			Position = UDim2.fromOffset(fig(70), fig(66 + t[2])),
			Size = UDim2.fromOffset(fig(1100), fig(158)),
			ZIndex = if t[2] > 0 then 3 else 4,
		})
	end
	local close = button(gui, "IndexClose", 174, 174, { Position = UDim2.fromOffset(fig(2046), fig(54)), ZIndex = 4 }, "Red")
	label(close, "X", {
		Text = "X",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})

	-- the sections' box
	local box = HudKit.back(gui, "IndexBox", {
		Name = "Box",
		Position = UDim2.fromOffset(fig(40), fig(BOX_TOP)),
		Size = UDim2.fromOffset(fig(LEFT_W), fig(BOX_H)),
		ZIndex = 2,
	})
	sections, fresh = Ui.make(box, "Sections", "ScrollingFrame")
	if fresh then
		sections.BackgroundTransparency = 1
		sections.BorderSizePixel = 0
		sections.Position = UDim2.fromOffset(fig(8), fig(8))
		sections.Size = UDim2.new(1, -fig(16), 1, -fig(16))
		sections.CanvasSize = UDim2.new()
		sections.AutomaticCanvasSize = Enum.AutomaticSize.Y
		sections.ScrollingDirection = Enum.ScrollingDirection.Y
		sections.ScrollBarThickness = 6
		sections.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
		sections.ZIndex = 2
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, fig(10))
		layout.Parent = sections
	end
	sectionTemplate = Ui.template(sections, "SectionTemplate", sectionTemplateBuild)
	tileTemplate = Ui.template(sections, "TileTemplate", tileTemplateBuild)

	-- Unlocked: X/Y, the book over its left end
	unlocked = HudKit.back(gui, "IndexBox", {
		Name = "Unlocked",
		Position = UDim2.fromOffset(fig(40 + 110), fig(BOX_TOP + BOX_H + 40)),
		Size = UDim2.fromOffset(fig(LEFT_W - 110), fig(H - 40 - (BOX_TOP + BOX_H + 40))),
		ZIndex = 2,
	})
	label(unlocked, "Count", {
		Text = "Unlocked: 0/0",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(95),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
	})
	local book
	book, fresh = Ui.make(gui, "BookIcon", "ImageLabel")
	if fresh then
		book.BackgroundTransparency = 1
		book.Image = HudImages.IndexIcon or ""
		book.ScaleType = Enum.ScaleType.Fit
		book.AnchorPoint = Vector2.new(0.5, 0.5)
		book.Position = UDim2.fromOffset(fig(40 + 110), fig(BOX_TOP + BOX_H + 40 + 80))
		book.Size = UDim2.fromOffset(fig(220), fig(220))
		book.Rotation = -8
		book.ZIndex = 5
	end
	HudKit.outlineArt(book, 3)

	-- the picked pet's card
	card = HudKit.back(gui, "Card", {
		Name = "PetCard",
		Position = UDim2.fromOffset(fig(RIGHT_X), fig(BOX_TOP)),
		Size = UDim2.fromOffset(fig(RIGHT_W), fig(CARD_H)),
		ZIndex = 2,
	})
	local frame = HudKit.back(card, "Dark", {
		Name = "PictureBox",
		Position = UDim2.fromOffset(fig(60), fig(40)),
		Size = UDim2.new(1, -fig(120), 0, fig(260)),
		ZIndex = 3,
	})
	local picture
	picture, fresh = Ui.make(frame, "Picture", "ImageLabel")
	if fresh then
		picture.BackgroundTransparency = 1
		picture.ScaleType = Enum.ScaleType.Fit
		picture.Position = UDim2.fromScale(0.05, 0.05)
		picture.Size = UDim2.fromScale(0.9, 0.9)
		picture.ZIndex = 4
	end
	for i, l in {
		{ "PetName", "Chicken", Color3.new(1, 1, 1) },
		{ "Rarity", "Common", Color3.new(1, 1, 1) },
		{ "PetCash", "$1/s", CASH_GREEN },
	} do
		local t = label(card, l[1], {
			Text = l[2],
			TextColor3 = l[3],
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			Position = UDim2.fromOffset(fig(20), fig(310 + (i - 1) * 76)),
			Size = UDim2.new(1, -fig(40), 0, fig(76)),
			ZIndex = 4,
		})
		if not t:FindFirstChildOfClass("UITextSizeConstraint") then
			local limit = Instance.new("UITextSizeConstraint")
			limit.MaxTextSize = fig(85)
			limit.Parent = t
		end
	end

	-- under it: its reward and Claim!, or once claimed its stats
	rewards = HudKit.back(gui, "IndexCard", {
		Name = "Rewards",
		Position = UDim2.fromOffset(fig(RIGHT_X), fig(BOX_TOP + CARD_H + 40)),
		Size = UDim2.fromOffset(fig(RIGHT_W), fig(H - 40 - (BOX_TOP + CARD_H + 40))),
		ZIndex = 2,
	})
	local claim
	claim, fresh = Ui.make(rewards, "Claim", "Frame")
	if fresh then
		claim.BackgroundTransparency = 1
		claim.Size = UDim2.fromScale(1, 1)
		claim.ZIndex = 3
	end
	label(claim, "Heading", {
		Text = "Rewards:",
		TextSize = fig(48),
		Position = UDim2.fromOffset(fig(30), fig(14)),
		Size = UDim2.fromOffset(fig(300), fig(56)),
		ZIndex = 4,
	})
	for i, r in { { "PowerReward", "PowerGainIcon", "+60" }, { "CashReward", "CashGainIcon", "$1K" } } do
		local slot = HudKit.back(claim, "Dark", {
			Name = r[1],
			Position = UDim2.new(0.5, (i == 1) and -fig(175) or fig(15), 0, fig(68)),
			Size = UDim2.fromOffset(fig(160), fig(160)),
			ZIndex = 4,
		})
		art(slot, "Icon", {
			Image = HudImages[r[2]] or "",
			Position = UDim2.fromScale(0.1, 0.02),
			Size = UDim2.fromScale(0.8, 0.8),
			ZIndex = 5,
		})
		label(slot, "Amount", {
			Text = r[3],
			TextXAlignment = Enum.TextXAlignment.Center,
			TextScaled = true,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -fig(6)),
			Size = UDim2.new(0.95, 0, 0, fig(52)),
			ZIndex = 6,
		})
	end
	for _, b in { { "ClaimButton", "Claim!", "GreenPlain" }, { "LockedButton", "Locked", "GreyPlain" } } do
		local btn = button(claim, b[1], RIGHT_W - 120, 110, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -fig(20)),
			ZIndex = 4,
		}, b[3])
		label(btn, "Text", {
			Text = b[2],
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = fig(75),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
		})
	end
	local stats
	stats, fresh = Ui.make(rewards, "Stats", "Frame")
	if fresh then
		stats.BackgroundTransparency = 1
		stats.Size = UDim2.fromScale(1, 1)
		stats.ZIndex = 3
		stats.Visible = false
	end
	for i, s in { { "Health", "HealthIcon", "100" }, { "Regen", "RegenIcon", "2.5/s" }, { "Speed", "SpeedIcon", "44" } } do
		local row
		row, fresh = Ui.make(stats, s[1], "Frame")
		if fresh then
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromOffset(fig(40), fig(22 + (i - 1) * 100))
			row.Size = UDim2.new(1, -fig(80), 0, fig(96))
			row.ZIndex = 4
		end
		art(row, "Icon", {
			Image = HudImages[s[2]] or "",
			Size = UDim2.fromOffset(fig(96), fig(96)),
			ZIndex = 5,
		})
		label(row, "Value", {
			Text = s[3],
			TextSize = fig(70),
			Position = UDim2.fromOffset(fig(120), 0),
			Size = UDim2.new(1, -fig(120), 1, 0),
			ZIndex = 5,
		})
	end

	-- the red "!" on the Index button (as the paw button's: client/PetsPanel)
	return close
end

local function buildBadge(indexButton)
	local b, fresh = Ui.make(indexButton, "IndexBadge", "Frame")
	if fresh then
		b.BackgroundColor3 = hex("ff0000")
		b.Position = UDim2.new(1, -fig(36), 0, -fig(26))
		b.Size = UDim2.fromOffset(fig(64), fig(64))
		b.ZIndex = 10
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = b
		local border = Instance.new("UIStroke")
		border.Name = "Border"
		border.Color = hex("770000")
		border.Thickness = fig(5)
		border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		border.Parent = b
		local mark = label(b, "Mark", {
			Text = "!",
			TextSize = fig(55),
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
		})
		mark.Outline.Color = hex("770000")
		mark.Outline.Thickness = fig(3)
	end
	b.Visible = not Ui.live
	return b
end

-- ---- filling in -------------------------------------------------------------------------

local function set(attr)
	local out = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,%s]+") do
		out[id] = true
	end
	return out
end

-- one biome's section: its picture, and its pets laid out in the collage
local function makeSection(name, order)
	local section = Ui.copy(sectionTemplate, "Section" .. name, sections)
	section.LayoutOrder = order
	local biome = section.Biome
	biome.Shot.Image = HudImages["Biome" .. name] or ""
	local tint = Config.Index.Tint[name] or Color3.fromRGB(80, 80, 80)
	local fill = biome:FindFirstChild("Fill")
	if fill then
		fill.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.25), tint:Lerp(HudKit.BLACK, 0.35))
		fill.Rotation = 90
	end
	biome.BiomeName.Text = Config.Regions.Names[name] or name
	biome.BiomeName.Visible = biome.Shot.Image == "" -- (the screenshot says where it is)

	local kinds = IndexList.biome(name)
	local layout, rows = collage(#kinds)
	-- the biggest tiles to the rarest pets (kinds are commonest first)
	local byArea = {}
	for i = 1, #layout do
		byArea[i] = i
	end
	table.sort(byArea, function(a, b)
		local la, lb = layout[a], layout[b]
		local area = la[3] * la[4] - lb[3] * lb[4]
		if area ~= 0 then
			return area > 0
		end
		return a < b
	end)
	-- (the grid is square cells: the section is as tall as its rows need)
	local gridW = fig(LEFT_W) - 2 * fig(8) - 6 - fig(PAD + PICTURE_W + 2 * PAD) -- (6: the scroll bar)
	local cell = (gridW - (COLS - 1) * fig(GAP)) / COLS
	local gridH = rows * cell + (rows - 1) * fig(GAP)
	section.Size = UDim2.new(1, 0, 0, math.round(gridH + fig(2 * PAD + BAR_H + PAD)))
	for rank, at in byArea do
		local kind = kinds[#kinds - rank + 1]
		local p = layout[at]
		local tile = Ui.copy(tileTemplate, kind, section.Grid)
		tile.Position = UDim2.fromOffset(math.round(p[1] * (cell + fig(GAP))), math.round(p[2] * (cell + fig(GAP))))
		tile.Size = UDim2.fromOffset(math.round(p[3] * cell + (p[3] - 1) * fig(GAP)), math.round(p[4] * cell + (p[4] - 1) * fig(GAP)))
		tile.LayoutOrder = p[2] * COLS + p[1]
		paintBack(tile:FindFirstChild("Back"), (Config.Pets[kind] or {}).Rarity)
		tile.Picture.Image = ItemIcons.Pets[kind] or ""
		if p[3] == 2 and p[4] == 2 then
			tile.PetName.Size = UDim2.new(0.92, 0, 0, fig(60))
		end
		HudKit.hover(tile)
		tiles[kind] = tile
	end
	-- the rarest pet's egg at the bar's end
	section.Bar.Egg.Image = ItemIcons.Eggs[kinds[#kinds]] or ""
	bars[name] = section
	return section
end

local function showCard(kind, found, claimed)
	local pet = Config.Pets[kind] or {}
	paintBack(card, pet.Rarity)
	local picture = card.PictureBox.Picture
	picture.Image = ItemIcons.Pets[kind] or ""
	picture.ImageColor3 = if found then Color3.new(1, 1, 1) else HudKit.BLACK
	picture.ImageTransparency = if found then 0 else SILHOUETTE
	card.PetName.Text = if found then Pets.name(kind) else "???"
	card.Rarity.Text = pet.Rarity or "Common"
	RarityLook.paint(card.Rarity, pet.Rarity or "Common", card.Rarity:FindFirstChild("Outline"))
	card.PetCash.Text = if found then "$" .. Abbrev(pet.Cash or 0) .. "/s" else "???"

	local claim, stats = rewards.Claim, rewards.Stats
	local done = found and claimed
	claim.Visible = not done
	stats.Visible = done
	if done then
		local s = Pets.stats(kind)
		stats.Health.Value.Text = Abbrev(math.round(s.Health or 0)) .. " Health"
		stats.Regen.Value.Text = string.format("%.1f/s Regen", s.Regen or 0)
		stats.Speed.Value.Text = Abbrev(math.round(s.Speed or 0)) .. " Speed"
	else
		local cash, power = IndexList.reward(kind)
		claim.PowerReward.Amount.Text = "+" .. Abbrev(power)
		claim.CashReward.Amount.Text = "$" .. Abbrev(cash)
		claim.ClaimButton.Visible = found
		claim.LockedButton.Visible = not found
	end
end

local function refresh()
	local found, claimed = set("PetIndex"), set("IndexClaimed")
	local total, have, claimable = 0, 0, false
	for _, name in Config.Index.Order do
		local kinds = IndexList.biome(name)
		local n = 0
		for _, kind in kinds do
			local tile = tiles[kind]
			local f = found[kind] == true
			if f then
				n += 1
				if not claimed[kind] then
					claimable = true
				end
			end
			if tile then
				tile.Shade.Visible = not f
				tile.Picture.ImageColor3 = if f then Color3.new(1, 1, 1) else HudKit.BLACK
				tile.Picture.ImageTransparency = if f then 0 else SILHOUETTE
				tile.PetName.Text = if f then Pets.name(kind) else "???"
				tile.Pick.Enabled = kind == picked
			end
		end
		total += #kinds
		have += n
		local section = bars[name]
		if section then
			section.Bar.Found.Size = UDim2.fromScale(if #kinds > 0 then n / #kinds else 0, 1)
			section.Bar.Found.Visible = n > 0
			section.Bar.Count.Text = n .. "/" .. #kinds
		end
	end
	unlocked.Count.Text = "Unlocked: " .. have .. "/" .. total
	if picked then
		showCard(picked, found[picked] == true, claimed[picked] == true)
	end
	if badge then
		badge.Visible = claimable
	end
end

-- (popping in and out: client/UiFx)
function IndexPanel.isOpen()
	return gui ~= nil and UiFx.isOpen(gui)
end

function IndexPanel.open()
	if gui then
		UiFx.popIn(gui)
	end
end

function IndexPanel.close()
	if gui then
		UiFx.popOut(gui)
	end
end

function IndexPanel.init(root, indexButton)
	local close = build(root)
	if indexButton then
		badge = buildBadge(indexButton)
	end
	if not Ui.live then
		return
	end
	gui.Visible = false
	close.Activated:Connect(IndexPanel.close)
	if indexButton then
		indexButton.Activated:Connect(function()
			UiFx.toggle(gui)
		end)
	end

	for i, name in Config.Index.Order do
		makeSection(name, i)
	end
	for kind, tile in tiles do
		UiFx.button(tile)
		tile.Activated:Connect(function()
			picked = kind
			refresh()
		end)
	end
	-- (starts on the first pet you've found: your starter)
	local found = set("PetIndex")
	for _, kind in IndexList.all() do
		if found[kind] or not picked then
			picked = kind
			if found[kind] then
				break
			end
		end
	end

	local claimRemote = ReplicatedStorage:WaitForChild("IndexClaim", 10)
	local claimButton = rewards.Claim.ClaimButton
	claimButton.Activated:Connect(function()
		if claimRemote and picked and not claimButton:GetAttribute("Busy") then
			claimButton:SetAttribute("Busy", true)
			local ok, done = pcall(claimRemote.InvokeServer, claimRemote, picked)
			if ok and done then
				UiFx.play("Claim")
			else
				UiFx.shake(claimButton)
			end
			claimButton:SetAttribute("Busy", nil)
		end
	end)
	for _, attr in { "PetIndex", "IndexClaimed" } do
		player:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	refresh()
end

return IndexPanel
