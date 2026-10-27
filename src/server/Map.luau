-- Builds the map from Shared/MapData (maps/world.map, edited in tools/mapeditor; QM, Oct 24):
-- the base (a grass square, its dirt yard round the spawn, pens, training grounds), and the
-- biome arenas north of it (Meadow, Desert, Ice, Lava), walled down their sides (stone
-- pillars at the corners and joints, big ones where one biome opens onto the next; no
-- walls between them), a gateway (two big pillars and an arch) from the base, a barrier
-- where areas meet for those in a fight (Server/Eggs), egg nests and the boss's spot, and
-- the cactus vendor's stall.
--
-- Everything goes in workspace.Map. It's baked into the place in Studio's Edit mode (QM,
-- Oct 24: see it without playing) by the Map Baker plugin (tools/studio/MapBaker.lua),
-- from Shared/MapData (maps/world.map, the map editor's file) or a .map picked from disk;
-- the game then plays on the baked map, and only builds one if the place has none. The
-- lineup from tools/lineup.luau (workspace.World) and any Baseplate are moved out of the
-- way while the game runs.
--
-- Stone pillars and pines use the meshes in ServerStorage.WorldAssets (made by
-- tools/lineup.luau); without them the pillars are plain studded blocks and there are no
-- pines. Every colour is a ColorKey in Config.WorldColors (live-tunable in Play).
--
--   Map.ensure() -> workspace.Map  -- once, on the server's start: the baked map (or builds it)
--   Map.build(data?) -> workspace.Map -- builds it fresh (data: a decoded .map; default MapData)
--   Map.data                        -- Shared/MapData (or the data last built)
--   Map.area(name)                  -- an area's data ("Base", "Meadow", ...)

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

-- (the Map Baker plugin requires a fresh copy of this beside a fresh copy of Shared)
local Shared = script.Parent:FindFirstChild("Shared") or ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local MapData = require(Shared.MapData)
local WorldColors = require(Shared.WorldColors)
local RegionBlocker = require(Shared.RegionBlocker)
local Studs = require(Shared.Studs)
local VendorStallModel = require(Shared.VendorStallModel)
local Egg = require(Shared.Eggs.Egg)
local Cactus = require(Shared.Animals.Cactus)
local HiddenFaces = require(Shared.HiddenFaces)

local Map = {}
Map.data = MapData
local gates -- (region gates, below)

local COLORS = Config.WorldColors
-- (the map's own colours, from the editor, over Config's: WorldColors paints from these too)
local MapFile = require(Shared.MapFile)
MapFile.applyColours(MapData, COLORS)
local CHECKER, STUDS = "rbxassetid://84747779882944", "rbxassetid://7447638591"
local STONE_MESH = "rbxassetid://128149382332662" -- StoneBlock_Block (assets/meshes/ids.json)
local SIDES = { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local ALL = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local FLOOR_BOTTOM = -2
local SEAM = 0.03 -- how far each floor part reaches past its edges
local LIP = 0.25 -- how far a wall's cap overhangs it (as the lineup's showcase)

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function color(key)
	return COLORS[key] or Color3.new(1, 0, 1)
end

local function texture(part, face, image, tile, key, z, aligned)
	local t = Instance.new("Texture")
	t.Name = if image == STUDS then "Studs" else "Checker"
	t.Face = face
	t.Texture = image
	t.StudsPerTileU, t.StudsPerTileV = tile, tile
	t.ZIndex = z or 1
	if key then
		t:SetAttribute("ColorKey", key)
		t.Color3 = color(key)
	end
	if image == STUDS then
		t.Transparency = Config.StudTransparency
	end
	-- (lined up with the world grid, whatever the part's corner: axis-aligned parts only)
	if aligned then
		local corner = part.Position - part.Size / 2
		if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
			-- (a Top texture runs from the part's +x +z corner toward -x and -z, measured in
			-- Studio: this offset puts every part's checker on one world-wide board, whatever
			-- its size; the half tile mirrors the checker back the right way round, which the
			-- studs, symmetric, don't need)
			local far = part.Position + part.Size / 2
			local half = if image == STUDS then 0 else tile / 2
			t.OffsetStudsU, t.OffsetStudsV = (half - far.X) % tile, (half - far.Z) % tile
		elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
			t.OffsetStudsU, t.OffsetStudsV = corner.X % tile, corner.Y % tile
		else
			t.OffsetStudsU, t.OffsetStudsV = corner.Z % tile, corner.Y % tile
		end
	end
	t.Parent = part
	return t
end

-- a part coloured `key`, its checker (key .. "Checker") and studs on `faces`
local function block(name, parent, cframe, size, key, faces, aligned)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("ColorKey", key)
	p.Color = color(key)
	for _, face in faces or ALL do
		if COLORS[key .. "Checker"] then
			texture(p, face, CHECKER, 8, key .. "Checker", 1, aligned)
		end
		texture(p, face, STUDS, 1, nil, 2, aligned)
	end
	p.Parent = parent
	return p
end

-- an axis-aligned box from (x0, y0, z0) to (x1, y1, z1), in any corner order
local function box(name, parent, x0, y0, z0, x1, y1, z1, key, faces)
	x0, x1 = math.min(x0, x1), math.max(x0, x1)
	y0, y1 = math.min(y0, y1), math.max(y0, y1)
	z0, z1 = math.min(z0, z1), math.max(z0, z1)
	return block(
		name,
		parent,
		CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		Vector3.new(x1 - x0, y1 - y0, z1 - z0),
		key,
		faces,
		true
	)
end

function Map.area(name)
	for _, area in MapData.Areas do
		if area.Name == name then
			return area
		end
	end
	return nil
end

-- ---- the floors ----------------------------------------------------------------------

-- (wall tiles go in wallParent, kept out of the Floor: Server/BossAttacks finds the ground there)
local function floors(parent, wallParent)
	for _, area in MapData.Areas do
		local f = folder(area.Name, parent)
		local lowest = math.huge
		for _, tile in area.Tiles do
			if not tile[4] then
				lowest = math.min(lowest, tile[2])
			end
		end
		for _, rect in area.Floor do
			local tile = area.Tiles[rect[1]]
			local key, top = tile[1], tile[2]
			local x0, z0, sx, sz = rect[2], rect[3], rect[4], rect[5]
			if tile[4] then
				-- a painted wall: its sides, and a stud-high cap of the cap's colour
				local model = Instance.new("Model")
				model.Name = area.Name .. "Wall"
				box("Wall", model, x0, FLOOR_BOTTOM, z0, x0 + sx, top - 1, z0 - sz, key, SIDES).Locked = true
				box("Cap", model, x0, top - 1, z0, x0 + sx, top, z0 - sz, tile[4]).Locked = true
				model.Parent = wallParent
				continue
			end
			-- (only raised tiles show their sides; the lowest one's are always buried)
			local faces = if top > lowest then ALL else { Enum.NormalId.Top }
			if tile[3] then
				-- a liquid (water, magma): a see-through surface you wade through, its bed
				-- LiquidSink below it (client/Liquid.luau slows you in it)
				local bed = top - Config.Map.LiquidSink
				local floor = box(key, f, x0, FLOOR_BOTTOM - 2, z0, x0 + sx, bed, z0 - sz, key, { Enum.NormalId.Top })
				floor.Locked = true
				floor:SetAttribute("Liquid", true)
				local p = box(key, f, x0, bed, z0, x0 + sx, top - 0.2, z0 - sz, key, {})
				p.Name = key .. "Surface"
				p.Locked = true
				p.CanCollide = false
				p:SetAttribute("Liquid", true)
				local t = texture(p, Enum.NormalId.Top, CHECKER, 8, key .. "Checker", 1, true)
				if area.Name == "Lava" then
					-- magma glows: Neon, only a faint checker on top (as LassoAPet's lava)
					p.Material = Enum.Material.Neon
					p.Transparency = 0.15
					t.Transparency = 0.55
					p:SetAttribute("Lava", true)
				else
					p.Material = Enum.Material.Glass
					p.Transparency = 0.35
					t.Transparency = 0.5
				end
				continue
			end
			local p = box(key, f, x0, FLOOR_BOTTOM, z0, x0 + sx, top, z0 - sz, key, faces)
			p.Locked = true
			-- a hair bigger all round, so neighbours overlap and no crack shows between them
			-- (QM, Oct 24: creases between plates). The top's textures shift back by the same
			-- hair, so the overlap shows the same squares from both parts.
			p.Size += Vector3.new(2 * SEAM, 0, 2 * SEAM)
			for _, t in p:GetChildren() do
				if t:IsA("Texture") and t.Face == Enum.NormalId.Top then
					t.OffsetStudsU = (t.OffsetStudsU - SEAM) % t.StudsPerTileU
					t.OffsetStudsV = (t.OffsetStudsV - SEAM) % t.StudsPerTileV
				end
			end
		end
	end
end

-- ---- walls ---------------------------------------------------------------------------

local function wallKeys(style)
	if style == "Base" then
		return "WallDirt", "Grass"
	end
	return style .. "Wall", style .. "Cap"
end

local function walls(parent)
	local h = MapData.WallHeight
	for _, w in MapData.Walls do
		local key, cap = wallKeys(w[1])
		local model = Instance.new("Model")
		model.Name = w[1] .. "Wall"
		box("Wall", model, w[2], FLOOR_BOTTOM, w[3], w[4], h - 1, w[5], key)
		box("Cap", model, w[2] - LIP, h - 1, w[3] + LIP, w[4] + LIP, h, w[5] - LIP, cap)
		model.Parent = parent
	end
	for _, w in MapData.Ring do
		local key, cap = wallKeys(w[1])
		local model = Instance.new("Model")
		model.Name = w[1] .. "RingWall"
		local at = CFrame.new(w[2], 0, w[3]) * CFrame.Angles(0, w[6], 0)
		local length, thick = w[4], w[5]
		block(
			"Wall",
			model,
			at * CFrame.new(0, (FLOOR_BOTTOM + h - 1) / 2, 0),
			Vector3.new(length, h - 1 - FLOOR_BOTTOM, thick),
			key
		)
		block("Cap", model, at * CFrame.new(0, h - 0.5, 0), Vector3.new(length + 2 * LIP, 1, thick + 2 * LIP), cap)
		model.Parent = parent
	end
end

-- ---- stone: pillars, arches, rubble ----------------------------------------------------

-- The stone block mesh, and where its middle sits: `lift` is how far above the part's
-- position the block's centre is, as a fraction of its height (0 when Roblox centres an
-- imported mesh on its box, 0.5 when it keeps the mesh's origin at the base). Measured
-- once with a ray, so pillars stand right either way.
local stoneTemplate, lift = nil, 0

local function measure(template)
	local probe = template:Clone()
	probe.Anchored = true
	probe.CanQuery = true
	probe.CFrame = CFrame.new(0, 5000, 0)
	probe.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local hit = workspace:Raycast(Vector3.new(0, 5200, 0), Vector3.new(0, -400, 0), params)
	local h = probe.Size.Y
	probe:Destroy()
	if not hit then
		return 0
	end
	return math.clamp((hit.Position.Y - 5000) / h - 0.5, 0, 0.5)
end

local function loadStone()
	local assets = ServerStorage:FindFirstChild("WorldAssets")
	local item = assets and assets:FindFirstChild("StoneBlock")
	local part = item and item:FindFirstChild("Block")
	if not (part and part:IsA("MeshPart")) then
		local ok, made = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromUri(STONE_MESH), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
			})
		end)
		part = if ok then made else nil
	end
	if part then
		stoneTemplate = part:Clone()
		stoneTemplate.Anchored = true
		stoneTemplate.Material = Enum.Material.SmoothPlastic
		lift = measure(stoneTemplate)
	end
end

-- a stone block's shade, from where it stands now (run again once a pillar built at the
-- origin is moved, so identical pillars don't share a pattern)
local function shadeStone(p)
	local at = p.Position
	local shade = Random.new(math.floor(at.X * 7.3 + at.Y * 13.1 + at.Z * 17.9)):NextNumber(0.86, 1.1)
	p:SetAttribute("Shade", math.round(shade * 100) / 100)
	p.Color = WorldColors.shaded(color(p:GetAttribute("ColorKey")), p)
end

-- one stone block, its centre at `centre` (a CFrame: position and tilt), `size` studs.
-- Each block takes its own shade of its colour (a Shade attribute, kept by Shared/
-- WorldColors when it repaints), so a pillar reads as many stones (QM, Oct 24); picked
-- from where it stands, so the layout's own random numbers don't change.
local function stone(parent, centre, size, key, collide)
	local p
	if stoneTemplate then
		p = stoneTemplate:Clone()
		p.Size = size
		p.CFrame = centre * CFrame.new(0, -lift * size.Y, 0)
		p:SetAttribute("ColorKey", key)
	else
		p = block("Stone", parent, centre, size, key, ALL, false)
	end
	shadeStone(p)
	p.Name = "Stone"
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.Locked = true
	p.Parent = parent
	return p
end

local function pillarKeys(style)
	if style == "Base" then
		return "Stone", "StoneDark"
	end
	return style .. "Pillar", style .. "PillarDark"
end

-- A prop piece's ColorKey in its style: boulders and monoliths have each biome's own
-- colours (Config.WorldColors MeadowBoulder, LavaMonolith, IceRune...), other grey stone
-- wears the biome's pillar colours. (tools/render3d.py prop() does the same for the editor.)
local function propKey(item, key, style)
	local prefix = if style == "Base" then "" else style
	if item == "Boulders" and (key == "Stone" or key == "StoneDark") then
		return prefix .. (if key == "Stone" then "Boulder" else "BoulderDark")
	elseif item == "Monolith" then
		if key == "Rune" then
			return prefix .. "Rune"
		elseif key == "LavaPillar" or key == "Stone" then
			return prefix .. "Monolith"
		elseif key == "LavaPillarDark" or key == "StoneDark" then
			return prefix .. "MonolithDark"
		end
	elseif style ~= "Base" and (key == "Stone" or key == "StoneDark") then
		return if key == "Stone" then style .. "Pillar" else style .. "PillarDark"
	end
	return key
end

-- A pillar of rough stone blocks (LassoAPet's portal gate style): a wide plinth, a shaft
-- of courses (each one or two blocks, a little off true), a stepped capital. `size` is
-- its footprint, `height` its top.
local function pillar(parent, style, x, z, size, height, kind, rng)
	local light, dark = pillarKeys(style)
	local model = Instance.new("Model")
	model.Name = style .. "Pillar"
	local function pick()
		return if rng:NextNumber() < 0.3 then dark else light
	end
	local function jitter(a)
		return (rng:NextNumber() * 2 - 1) * a
	end
	if kind == "rubble" then
		-- a tumbled heap filling a sealed gateway
		for _ = 1, 9 do
			local s = rng:NextNumber(6, 11)
			local at = CFrame.new(
				x + jitter(MapData.GateHalf - 6),
				s * 0.35 + rng:NextNumber(0, height - s * 0.6),
				z + jitter(4)
			) * CFrame.Angles(math.rad(jitter(25)), math.rad(rng:NextNumber(0, 90)), math.rad(jitter(25)))
			stone(model, at, Vector3.new(s, s * rng:NextNumber(0.7, 1), s * rng:NextNumber(0.8, 1.1)), pick())
		end
		model.Parent = parent
		return model
	end
	local y = 0
	local plinth = math.max(2, height * 0.12)
	stone(model, CFrame.new(x, plinth / 2, z), Vector3.new(size + 3, plinth, size + 3), dark)
	y = plinth
	local capH = math.max(2, size * 0.15)
	local shaftTop = height - capH * 2
	local course = 0
	while y < shaftTop - 0.5 do
		local h = math.clamp(size * rng:NextNumber(0.45, 0.7), 3, 10)
		if shaftTop - (y + h) < 2.5 then
			h = shaftTop - y
		end
		local split = size >= 18
		local alongX = course % 2 == 0
		local tilt = CFrame.Angles(math.rad(jitter(1.5)), math.rad(jitter(4)), math.rad(jitter(1.5)))
		if split then
			local cut = 0.5 + jitter(0.12)
			for side = 0, 1 do
				local a0, a1 = if side == 0 then 0 else cut, if side == 0 then cut else 1
				local w = (a1 - a0) * size - 0.15
				local mid = -size / 2 + (a0 + a1) / 2 * size
				local offset = if alongX then Vector3.new(mid, 0, 0) else Vector3.new(0, 0, mid)
				local s = if alongX then Vector3.new(w, h, size) else Vector3.new(size, h, w)
				local inset = rng:NextNumber(0, 0.6)
				stone(
					model,
					CFrame.new(Vector3.new(x, y + h / 2, z) + offset + Vector3.new(jitter(0.3), 0, jitter(0.3))) * tilt,
					s - Vector3.new(inset, 0, inset),
					pick()
				)
			end
		else
			stone(
				model,
				CFrame.new(x + jitter(0.4), y + h / 2, z + jitter(0.4)) * tilt,
				Vector3.new(size, h, size) * Vector3.new(rng:NextNumber(0.94, 1), 1, rng:NextNumber(0.94, 1)),
				pick()
			)
		end
		y += h
		course += 1
	end
	-- the capital: a wide course, a wider one, and for a gate a crowning block
	stone(
		model,
		CFrame.new(x, y + capH / 2, z) * CFrame.Angles(0, math.rad(jitter(3)), 0),
		Vector3.new(size + 1.5, capH, size + 1.5),
		light
	)
	y += capH
	stone(
		model,
		CFrame.new(x, y + capH / 2, z) * CFrame.Angles(0, math.rad(jitter(3)), 0),
		Vector3.new(size + 3, capH, size + 3),
		dark
	)
	y += capH
	if kind == "gate" then
		stone(
			model,
			CFrame.new(x, y + 1.5, z) * CFrame.Angles(0, math.rad(45 + jitter(4)), 0),
			Vector3.new(size * 0.55, 3, size * 0.55),
			light
		)
	end
	model.Parent = parent
	return model
end

-- An arch over a gateway, springing from its two pillars' capitals: chunky voussoirs
-- round a flattened half ring, a keystone at the crown poking out at the front.
local ARCH_SPRING = 36 -- (the gate pillars' shafts end here, under their capitals)
local ARCH_SQUASH = 0.7 -- the arch's height over its half width
local function arch(parent, style, x, z, rng)
	local light, dark = pillarKeys(style)
	local model = Instance.new("Model")
	model.Name = style .. "Arch"
	local rIn = MapData.GateHalf
	local rOut = rIn + 9
	local n = 7
	local depth = 14
	for i = 0, n - 1 do
		local a0, a1 = math.pi * i / n + 0.012, math.pi * (i + 1) / n - 0.012
		local am = (a0 + a1) / 2
		local rm = (rIn + rOut) / 2
		local keystone = i == (n - 1) / 2
		local pos = Vector3.new(x + math.cos(am) * rm, ARCH_SPRING + 10 + math.sin(am) * rm * ARCH_SQUASH, z)
		local tangent = Vector3.new(-math.sin(am), math.cos(am) * ARCH_SQUASH, 0).Unit
		local up = Vector3.new(0, 0, 1):Cross(tangent)
		local length = (a1 - a0) * rm * (1 + ARCH_SQUASH) / 2 + 1.2
		local size = Vector3.new(
			length,
			rOut - rIn + (if keystone then 3 else rng:NextNumber(-0.4, 0.6)),
			depth + (if keystone then 2 else 0)
		)
		stone(
			model,
			CFrame.fromMatrix(pos, tangent, up),
			size,
			if keystone or rng:NextNumber() < 0.3 then dark else light,
			false
		)
	end
	-- the course the arch rests on, across the top of both pillars
	model.Parent = parent
	return model
end

-- ---- the base's furniture: pens, training grounds, spawn --------------------------------

local SIGN_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

-- a board on two posts with outlined Montserrat text (QM's UI style)
function Map.sign(parent, at, text, width)
	local model = Instance.new("Model")
	model.Name = "Sign"
	for _, sx in { -1, 1 } do
		block(
			"Post",
			model,
			at * CFrame.new(sx * (width / 2 - 0.6), 2.5, 0),
			Vector3.new(0.8, 5, 0.8),
			"WoodDark",
			SIDES
		)
	end
	local board =
		block("Board", model, at * CFrame.new(0, 5.2, 0), Vector3.new(width, 2.6, 0.6), "Wood", { Enum.NormalId.Top })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = SIGN_FONT
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 4
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Parent = label
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
		pad.Parent = label
		label.Parent = gui
		gui.Parent = board
	end
	model.Parent = parent
	return model
end

-- a wooden fence round a pen: posts at most 6 apart, two rails, a gap in the side that
-- faces the middle of the base (gate: the outward direction of that side)
local function fence(parent, cx, cz, size, top, gate)
	local model = Instance.new("Model")
	model.Name = "Fence"
	local half = size / 2 - 1
	local GAP = 10
	local corners = {
		{ Vector3.new(-half, 0, -half), Vector3.new(half, 0, -half) },
		{ Vector3.new(half, 0, -half), Vector3.new(half, 0, half) },
		{ Vector3.new(half, 0, half), Vector3.new(-half, 0, half) },
		{ Vector3.new(-half, 0, half), Vector3.new(-half, 0, -half) },
	}
	local base = Vector3.new(cx, top, cz)
	for _, side in corners do
		local a, b = side[1], side[2]
		local mid = (a + b) / 2
		local isGate = (gate.X ~= 0 and math.sign(mid.X) == gate.X and math.abs(mid.X) > 1)
			or (gate.Z ~= 0 and math.sign(mid.Z) == gate.Z and math.abs(mid.Z) > 1)
		local function run(p0, p1)
			local length = (p1 - p0).Magnitude
			local n = math.max(1, math.ceil(length / 6))
			for i = 0, n do
				local p = p0:Lerp(p1, i / n)
				block(
					"Post",
					model,
					CFrame.new(base + p + Vector3.new(0, 2, 0)),
					Vector3.new(1.2, 4, 1.2),
					"WoodDark",
					ALL
				)
			end
			local dir = (p1 - p0).Unit
			for _, y in { 1.2, 3.2 } do
				local at = CFrame.lookAt(base + (p0 + p1) / 2 + Vector3.new(0, y, 0), base + p1 + Vector3.new(0, y, 0))
				block("Rail", model, at, Vector3.new(0.5, 0.5, length), "Wood", SIDES)
			end
			return dir
		end
		if isGate then
			local dir = (b - a).Unit
			run(a, mid - dir * GAP / 2)
			run(mid + dir * GAP / 2, b)
		else
			run(a, b)
		end
	end
	model.Parent = parent
	return model
end

-- a training dummy: a post, a straw body with a crossbar, a sack head
local function dummy(parent, at)
	local model = Instance.new("Model")
	model.Name = "Dummy"
	block("Post", model, at * CFrame.new(0, 2.5, 0), Vector3.new(1, 5, 1), "WoodDark", ALL)
	local body = block("Body", model, at * CFrame.new(0, 5.5, 0), Vector3.new(3, 4, 2), "Straw", ALL)
	block("Arms", model, at * CFrame.new(0, 6.6, 0), Vector3.new(7, 0.8, 0.8), "WoodDark", ALL)
	block("Head", model, at * CFrame.new(0, 8.6, 0), Vector3.new(2.2, 2.2, 2.2), "StrawDark", ALL)
	block("Belt", model, at * CFrame.new(0, 4.4, 0), Vector3.new(3.2, 0.6, 2.2), "Wood", SIDES)
	model.PrimaryPart = body
	model.Parent = parent
	return model
end

-- A yard's gate: toward the spawn, in a north or south side for a pen (they stand in a row
-- along the south wall) and an east or west side for a training ground (down the sides:
-- QM, Oct 25). Its outward direction, and a frame at the middle of that side turned to
-- face out (a sign or gate part runs along its X).
local function gateOf(base, x, z, size, alongX)
	local dx, dz = base.Spawn[1] - x, base.Spawn[2] - z
	local out = if alongX
		then Vector3.new(if dx < 0 then -1 else 1, 0, 0)
		else Vector3.new(0, 0, if dz < 0 then -1 else 1)
	local at = Vector3.new(x, 0, z) + out * (size / 2)
	return out, CFrame.lookAt(at, at + out)
end

local function baseFurniture(parent)
	local base = Map.area("Base")
	local pens = folder("Pens", parent)
	for i, p in base.Pens do
		local x, z = p[1], p[2]
		local pen = Instance.new("Model")
		pen.Name = "Pen" .. i
		pen:SetAttribute("Index", i)
		local out, side = gateOf(base, x, z, base.PenSize, false)
		fence(pen, x, z, base.PenSize, 0, out)
		local marker = Instance.new("Part")
		marker.Name = "Area"
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
		marker.Transparency = 1
		marker.Size = Vector3.new(base.PenSize, 12, base.PenSize)
		marker.CFrame = CFrame.new(x, 6, z)
		marker.Parent = pen
		-- (no sign board, QM Oct 25: the owner's name floats over the gate instead; Server/
		-- Pens writes it into OwnerSign.Board's label)
		local owner = Instance.new("Model")
		owner.Name = "OwnerSign"
		local board = Instance.new("Part")
		board.Name = "Board"
		board.Anchored, board.CanCollide, board.CanQuery, board.CanTouch = true, false, false, false
		board.Transparency = 1
		board.Size = Vector3.new(1, 1, 1)
		board.CFrame = side * CFrame.new(0, 9, 0)
		board.Parent = owner
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(16, 2.4)
		gui.MaxDistance = 120
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = SIGN_FONT
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = ""
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		label.Parent = gui
		owner.Parent = pen
		pen.Parent = pens
	end
	-- the training grounds: fenced yards, their gates facing the spawn (Server/Training
	-- fills them and sells their gates; client/Barriers keeps a locked gate solid)
	local training = folder("Training", parent)
	for _, t in base.Training do
		local name, x, z = t[1], t[2], t[3]
		-- (each tier up a tile wider: Config.Training's Grow, QM Oct 27)
		local g = Config.Training.Grounds[name]
		local size = base.TrainSize + (g and g.Grow or 0) * Config.Training.Tile
		local zone = Instance.new("Model")
		zone.Name = name
		zone:SetAttribute("X", x)
		zone:SetAttribute("Z", z)
		local out, side = gateOf(base, x, z, size, true)
		fence(zone, x, z, size, 0, out)
		if name == "Dummies" then
			local dummies = folder("Dummies", zone)
			for k = -1, 1 do
				for row = 0, 1 do
					dummy(
						dummies,
						CFrame.new(x + k * 12 + row * 6 - 3, 0, z - 4 + row * 12)
							* CFrame.Angles(0, math.rad(k * -10), 0)
					)
				end
			end
		end
		local gate = Instance.new("Part")
		gate.Name = "Gate"
		gate.Anchored, gate.CanCollide, gate.CanQuery, gate.CanTouch = true, false, false, false
		gate.Transparency = 1
		gate.Size = Vector3.new(10, 8, 1.2)
		gate.CFrame = side * CFrame.new(0, 4, 1)
		gate.Parent = zone
		zone.Parent = training
	end
	-- the spawn: an invisible point in the dirt yard (QM, Oct 24: no spawn plate), you
	-- land on the floor under it
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(base.Spawn[1], 1, base.Spawn[2])
	spawn.Transparency = 1
	spawn.CanCollide, spawn.CanQuery, spawn.CanTouch = false, false, false
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = parent
end

-- ---- nests, boss spots, barriers --------------------------------------------------------

-- a nest: LassoAPet's woven stick bowl (its tools/nest_design.py: a criss-cross mat, five
-- rings of sticks leaning out, a few strays), the egg on the mat (the egg is Server/Eggs')
local NEST_SCALE = 1.3 -- (the nest egg's scale too: Config.Eggs.Scale.Nest)
local NEST_KEYS = { "NestStick", "NestStickDark" }
local function nest(parent, x, z, rng)
	local model = Instance.new("Model")
	model.Name = "Nest"
	local y = MapFile.groundAt(MapData, x, z) -- (on whatever floor it's on)
	local origin = CFrame.new(x, y, z)
	local S = NEST_SCALE
	local function stick(name, length, w, h, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Size = Vector3.new(length, h, w) * S
		p.CFrame = origin * CFrame.new(cf.Position * S) * cf.Rotation
		local key = NEST_KEYS[rng:NextInteger(1, #NEST_KEYS)]
		p:SetAttribute("ColorKey", key)
		p:SetAttribute("Shade", math.round(rng:NextNumber(0.86, 1.12) * 100) / 100)
		p.Color = WorldColors.shaded(color(key), p)
		p.Locked = true
		p.Parent = model
	end
	local function deg(a)
		return math.rad(a)
	end
	-- (a stick on a ring: local X along the ring, Y up, Z pointing inward)
	local function ring(a, r, h)
		return CFrame.fromMatrix(
			Vector3.new(r * math.cos(a), h, r * math.sin(a)),
			Vector3.new(-math.sin(a), 0, math.cos(a)),
			Vector3.yAxis
		)
	end
	-- floor: a criss-cross mat the egg sits on
	for i = 1, 30 do
		local a, d = rng:NextNumber(0, 2 * math.pi), math.sqrt(rng:NextNumber()) * 2
		stick(
			"Floor" .. i,
			rng:NextNumber(3.2, 4.6),
			rng:NextNumber(0.3, 0.42),
			0.24,
			CFrame.new(d * math.cos(a), rng:NextNumber(0.12, 0.3), d * math.sin(a))
				* CFrame.Angles(0, deg(rng:NextNumber(0, 180)), 0)
				* CFrame.Angles(0, 0, deg(rng:NextNumber(-5, 5)))
				* CFrame.Angles(deg(rng:NextNumber(-8, 8)), 0, 0)
		)
	end
	-- rim: rings of sticks woven round, each layer wider and leaning further out
	for layer = 0, 4 do
		local r, h = 2.2 + 0.34 * layer, 0.22 + 0.24 * layer
		local n, lean = 13 + 2 * layer, 18 + 7 * layer
		for j = 0, n - 1 do
			local a = 2 * math.pi * (j + rng:NextNumber(-0.25, 0.25)) / n
			local length = 2 * math.pi * r / n * rng:NextNumber(1.35, 1.8)
			stick(
				"Rim" .. layer .. "_" .. j,
				length,
				rng:NextNumber(0.38, 0.5),
				rng:NextNumber(0.26, 0.34),
				ring(a, r + rng:NextNumber(-0.12, 0.12), h + rng:NextNumber(-0.06, 0.06))
					* CFrame.Angles(0, deg(rng:NextNumber(-12, 12)), 0)
					* CFrame.Angles(0, 0, deg(rng:NextNumber(-9, 9)))
					* CFrame.Angles(deg(-lean + rng:NextNumber(-6, 6)), 0, 0)
			)
		end
	end
	-- strays: loose sticks poking out of the rim at odd angles
	for i = 0, 13 do
		local a = 2 * math.pi * (i + rng:NextNumber(-0.4, 0.4)) / 14
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		stick(
			"Stray" .. i,
			rng:NextNumber(2.2, 3.4),
			rng:NextNumber(0.24, 0.32),
			rng:NextNumber(0.2, 0.26),
			ring(a, rng:NextNumber(3.1, 3.7), rng:NextNumber(0.7, 1.3))
				* CFrame.Angles(0, deg(side * rng:NextNumber(25, 50)), 0)
				* CFrame.Angles(0, 0, deg(rng:NextNumber(-18, 18)))
				* CFrame.Angles(deg(-rng:NextNumber(20, 45)), 0, 0)
		)
	end
	model:SetAttribute("EggX", x)
	model:SetAttribute("EggY", y + 0.4 * S) -- (where its egg sits: on the mat)
	model:SetAttribute("EggZ", z)
	model.Parent = parent
	return model
end

local function biomeFurniture(parent)
	local rng = Random.new(1024)
	for _, area in MapData.Areas do
		-- (every biome with nests gets them, boss or not: the nests QM places in the editor)
		local hasNests = area.Nests and #area.Nests > 0
		if area.Boss or hasNests then
			local f = folder(area.Name, parent)
			local nests = folder("Nests", f)
			for i, p in area.Nests or {} do
				local n = nest(nests, p[1], p[2], rng)
				n.Name = "Nest" .. i
				n:SetAttribute("Biome", area.Name)
			end
		end
		if area.Boss then
			local f = parent:FindFirstChild(area.Name)
			local spot = Instance.new("Part")
			spot.Name = "BossSpot"
			spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
			spot.Transparency = 1
			spot.Size = Vector3.new(4, 1, 4)
			spot.CFrame = CFrame.new(area.Boss[1], 0.5, area.Boss[2])
			spot:SetAttribute("Biome", area.Name)
			spot.Parent = f
		end
	end
	local barriers = folder("Barriers", parent)
	for _, b in MapData.Barriers do
		local p = Instance.new("Part")
		p.Name = "Barrier"
		-- (invisible itself: Shared/BarrierSwirl draws it, in Studio by the Map Baker plugin and
		-- in game by client/FightBarrierFx for those locked into either side's fight, who
		-- client/Barriers makes it solid for)
		p.Anchored = true
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.ForceField
		p.Color = Color3.fromRGB(255, 80, 60)
		-- (as tall as a region's blocker, from the floor: QM)
		p.Size = Vector3.new(b[5] or MapData.GateHalf * 2, 40, 0.2) -- (a flat plane across the gate: QM)
		-- (its yaw as the map editor's: the wall runs along x turned -yaw degrees)
		p.CFrame = CFrame.new(b[3], MapFile.groundAt(MapData, b[3], b[4]) + 40 / 2 - 0.5, b[4])
			* CFrame.Angles(0, math.rad(b[6] or 0), 0)
		p:SetAttribute("South", b[1])
		p:SetAttribute("North", b[2])
		-- its red shadow on the floor either side (QM, Oct 25: like a region blocker's), a
		-- beam a side; Shared/BarrierSwirl.shadows tunes and shows it with the swirl
		local y = MapFile.groundAt(MapData, b[3], b[4]) + 0.06
		for _, side in { 1, -1 } do
			local n = p.CFrame.LookVector * side
			local at = Vector3.new(p.Position.X, y, p.Position.Z) + n * (p.Size.Z / 2)
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "ShadowFrom", "ShadowTo"
			a0.CFrame = p.CFrame:ToObjectSpace(CFrame.fromMatrix(at, n, p.CFrame.RightVector))
			a1.CFrame = p.CFrame:ToObjectSpace(CFrame.fromMatrix(at + n * 20, n, p.CFrame.RightVector))
			a0.Parent, a1.Parent = p, p
			local beam = Instance.new("Beam")
			beam.Name = "Shadow"
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.Width0, beam.Width1 = p.Size.X, p.Size.X
			beam.FaceCamera = false
			beam.Segments = 1
			beam.LightInfluence = 0
			beam.Color = ColorSequence.new(Color3.fromRGB(255, 40, 30))
			beam.Transparency = NumberSequence.new(0.6, 1)
			beam.Parent = a0
		end
		p.Parent = barriers
	end
end

-- ---- pines on the plateaus -------------------------------------------------------------

-- Stone stand-ins for the ruin and biome meshes until they're uploaded (tools/ruin_assets.py
-- writes them; tools/lineup.luau puts them in ServerStorage.WorldAssets). Trees have none.
local function standIn(parent, item, at, scale, style, rng)
	local light, dark = pillarKeys(style)
	local model = Instance.new("Model")
	model.Name = item
	local function piece(offset, size, key, tilt)
		key = propKey(item, key, style)
		stone(model, at * CFrame.new(offset * scale) * (tilt or CFrame.identity), size * scale, key)
	end
	if item == "RuinPillar" or item == "RuinPillarBroken" then
		local broken = item == "RuinPillarBroken"
		piece(Vector3.new(0, 0.7, 0), Vector3.new(6.8, 1.4, 6.8), dark)
		local y, n = 1.4, if broken then 2 else 4
		for k = 1, n do
			piece(
				Vector3.new(0, y + 1.5, 0),
				Vector3.new(4.6, 3, 4.6),
				light,
				CFrame.Angles(0, rng:NextNumber(0, 1), 0)
			)
			y += 3.05
		end
		if broken then
			piece(Vector3.new(5.6, 2.3, 2.4), Vector3.new(2.4, 4.6, 4.6), light, CFrame.Angles(0, 0.6, 0))
		else
			piece(Vector3.new(0, y + 1, 0), Vector3.new(7, 2, 7), dark)
		end
	elseif item == "Boulders" then
		piece(Vector3.new(0, 1.8, 0), Vector3.new(6.4, 4.2, 5.6), dark, CFrame.Angles(0.15, rng:NextNumber(0, 3), 0.1))
		piece(
			Vector3.new(3.6, 1, 1.4),
			Vector3.new(3.6, 2.6, 3.4),
			dark,
			CFrame.Angles(-0.1, rng:NextNumber(0, 3), 0.2)
		)
		piece(Vector3.new(-2.4, 0.6, 3), Vector3.new(2.4, 1.5, 2.2), light, CFrame.Angles(0, rng:NextNumber(0, 3), 0))
	elseif item == "Monolith" then
		piece(Vector3.new(0, 0.3, 0), Vector3.new(8.4, 1.4, 5.6), dark)
		piece(Vector3.new(0, 7.5, 0), Vector3.new(5.6, 15, 3), "LavaPillar", CFrame.Angles(0.07, 0, -0.05))
		for k = 0, 3 do
			local rune = block(
				"Rune",
				model,
				at * CFrame.new(Vector3.new(0, 3.4 + k * 3, -1.55) * scale),
				Vector3.new(1.4, 1.8, 0.2) * scale,
				propKey(item, "Rune", style),
				{}
			)
			rune.Material = Enum.Material.Neon
			rune.CanCollide = false
		end
	elseif item == "Cactus" or item == "CactusBarrel" then
		local function green(offset, size)
			block("Cactus", model, at * CFrame.new(offset * scale), size * scale, "CactusGreen", ALL)
		end
		if item == "Cactus" then
			green(Vector3.new(0, 8, 0), Vector3.new(3.6, 16, 3.6))
			green(Vector3.new(2.6, 6.4, 0), Vector3.new(3, 2.2, 2.2))
			green(Vector3.new(3.8, 9.4, 0), Vector3.new(2.2, 6, 2.2))
			green(Vector3.new(-2.4, 9.4, 0), Vector3.new(2.6, 2, 2))
			green(Vector3.new(-3.4, 11.6, 0), Vector3.new(2, 4.6, 2))
		else
			green(Vector3.new(0, 1.2, 0), Vector3.new(3.6, 2.4, 3.6))
		end
	else
		model:Destroy()
		return nil
	end
	model.Parent = parent
	return model
end

-- The props (pines, ruins, cacti, monoliths...) from ServerStorage.WorldAssets: grey stone
-- pieces wear their biome's colours (propKey), runes glow.
local function props(parent)
	local assets = ServerStorage:FindFirstChild("WorldAssets")
	local rng = Random.new(77)
	for _, p in MapData.Props do
		local item, scale, style = p[1], p[6], p[7]
		local template = assets and assets:FindFirstChild(item)
		local at = CFrame.new(p[2], p[4], p[3]) * CFrame.Angles(0, math.rad(p[5]), 0)
		if template then
			local copy = template:Clone()
			for _, part in copy:GetChildren() do
				if part:IsA("BasePart") then
					part.Size *= scale
					-- (centred on its box, or at its own origin: see lift)
					local centre = MapData.MeshCentres[item .. "_" .. part.Name] or Vector3.zero
					part.CFrame = if lift < 0.25 then at * CFrame.new(centre * scale) else at
					part.Anchored = true
					part.Locked = true
					local key = part:GetAttribute("ColorKey")
					-- (always recoloured: the template keeps the colour it was made with, and the
					-- map's colours or the style's keys may differ; a Neon rune glows its colour)
					if key then
						key = propKey(item, key, style)
						part:SetAttribute("ColorKey", key)
						part.Color = color(key)
					end
					if key and (string.sub(key, -4) == "Rune" or string.sub(key, -5) == "Flame") then
						part.Material = Enum.Material.Neon
						part.CanCollide = false
					end
					-- (flames light up round them: QM, Oct 24, the new biomes' torches and candles)
					if key and string.sub(key, -5) == "Flame" and not part:FindFirstChildOfClass("PointLight") then
						local light = Instance.new("PointLight")
						light.Color = part.Color
						light.Range = 14 * math.clamp(scale, 0.5, 3)
						light.Brightness = 1.6
						light.Shadows = false
						light.Parent = part
					end
				end
			end
			copy.Parent = parent
		else
			standIn(parent, item, at, scale, style, rng)
		end
	end
end

-- A ruined brick wall (QM, Oct 24: old broken stone-brick walls): courses of rough
-- bricks along its length, its top crumbling away unevenly, a few fallen bricks at its
-- foot. Bricks are the stone block mesh, so they're bevelled and a little off true.
local BRICK_H = 1.8
local function ruin(parent, r)
	local style, x, z, length, yaw, height, seed = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
	local light, dark = pillarKeys(style)
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = style .. "Ruin"
	local at = CFrame.new(x, -1, z) * CFrame.Angles(0, math.rad(yaw), 0)
	local depth = 3
	-- the top's profile: high in one place, crumbling toward the ends
	local peak = rng:NextNumber(-0.3, 0.3)
	local function top(u) -- u in -0.5..0.5 along the wall
		local h = height * (1 - math.abs(u - peak) * 1.4) + rng:NextNumber(-1.2, 1.2)
		return math.max(BRICK_H, h)
	end
	local courses = math.ceil(height / BRICK_H) + 1
	for c = 0, courses - 1 do
		local y = c * BRICK_H
		local u = -length / 2 + (if c % 2 == 0 then 0 else -rng:NextNumber(1, 2))
		while u < length / 2 do
			local w = rng:NextNumber(3, 4.6)
			local u0, u1 = math.max(u, -length / 2), math.min(u + w, length / 2)
			local mid = (u0 + u1) / 2
			if u1 - u0 > 1 and y + BRICK_H <= top(mid / length) then
				stone(
					model,
					at
						* CFrame.new(mid, y + BRICK_H / 2, rng:NextNumber(-0.2, 0.2))
						* CFrame.Angles(0, math.rad(rng:NextNumber(-3, 3)), math.rad(rng:NextNumber(-2, 2))),
					Vector3.new(u1 - u0 - 0.15, BRICK_H - 0.08, depth * rng:NextNumber(0.9, 1)),
					if rng:NextNumber() < 0.35 then dark else light
				)
			end
			u += w
		end
	end
	for _ = 1, rng:NextInteger(3, 6) do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		stone(
			model,
			at
				* CFrame.new(rng:NextNumber(-length / 2, length / 2), 1.6, side * rng:NextNumber(3, 6))
				* CFrame.Angles(
					math.rad(rng:NextNumber(-20, 20)),
					rng:NextNumber(0, math.pi),
					math.rad(rng:NextNumber(-20, 20))
				),
			Vector3.new(rng:NextNumber(2.6, 4), BRICK_H, depth * 0.9),
			if rng:NextNumber() < 0.5 then dark else light
		)
	end
	model.Parent = parent
	return model
end

-- ---- region gates ----------------------------------------------------------------------

-- Each region's gate (QM, Oct 25: regions are bought with cash): a Barrier object in the
-- map editor (MapData.RegionGates: region, x, z, yaw, width, height), so QM can move, turn
-- and size it there. Here an invisible marker fills it, its Region attribute the area's
-- name and its local X along the opening, facing away from the region, and the region's
-- blocker stands in it (Shared/RegionBlocker; client/Regions hides it for a player who's
-- bought it).
gates = function(parent, blockers)
	for _, g in MapData.RegionGates or {} do
		local region, x, z, yaw, width, height = g[1], g[2], g[3], g[4], g[5], g[6]
		local area = Map.area(region)
		if not area then
			continue
		end
		-- (the editor's yaw: the opening runs along x turned -yaw degrees, seen from above)
		local a = -math.rad(yaw)
		local along = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = Vector3.new(x, 0, z)
		local normal = Vector3.new(-along.Z, 0, along.X)
		if area.Bounds then
			local centre = Vector3.new((area.Bounds[1] + area.Bounds[3]) / 2, 0, (area.Bounds[2] + area.Bounds[4]) / 2)
			if normal:Dot(centre - mid) > 0 then
				normal = -normal
			end
		end
		local floor = MapFile.groundAt(MapData, x, z)
		local centre = mid + Vector3.new(0, floor + height / 2 - 0.5, 0)
		local marker = Instance.new("Part")
		marker.Name = region .. "Gate"
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
		marker.Transparency = 1
		marker.Size = Vector3.new(width, height, 1.5)
		marker.CFrame = CFrame.lookAt(centre, centre + normal)
		marker:SetAttribute("Region", region)
		marker.Parent = parent
		local blocker = RegionBlocker.build(marker, function(px, pz)
			return MapFile.groundAt(MapData, px, pz)
		end)
		if blocker then
			blocker.Parent = blockers
		end
	end
end

-- ---- all of it ---------------------------------------------------------------------------

-- out of the way: the lineup (tools/lineup.luau's workspace.World: its 1024-stud grass
-- floor at y 0 z-fights the map's grass and covers the dirt a stud below it) and a fresh
-- place's baseplate. In Play they go; in Edit mode they're kept in ServerStorage.
local function clearSite()
	if RunService:IsRunning() then
		if Config.Map.HideLineup then
			local lineup = workspace:FindFirstChild("World")
			if lineup then
				lineup.Parent = ServerStorage
			end
			for _, name in { "Baseplate", "SpawnLocation" } do
				local thing = workspace:FindFirstChild(name)
				if thing then
					thing:Destroy()
				end
			end
		end
		return
	end
	for _, name in { "World", "Baseplate", "SpawnLocation" } do
		local thing = workspace:FindFirstChild(name)
		if thing and (name ~= "World" or Config.Map.HideLineup) then
			local keep = ServerStorage:FindFirstChild("MovedByMapBaker") or Instance.new("Folder")
			keep.Name = "MovedByMapBaker"
			keep.Parent = ServerStorage
			thing.Parent = keep
		end
	end
end

-- ---- the cactus vendor ------------------------------------------------------------------

-- LassoAPet's Carl stall (QM, Oct 27; Shared/VendorStallModel): posts, beams, a counter, a
-- striped cloth roof with a cactus growing up through it, a heap of eggs behind, and Carl
-- (a cactus guy) behind the counter with a Talk prompt. Built at the origin, its counter
-- facing -z; Map.build turns and moves it. Client/Vendor swaps this Carl for one that idles.
local function vendor(parent, name)
	local model = Instance.new("Model")
	model.Name = "Vendor"
	model:SetAttribute("Name", name)
	local counter
	for _, spec in VendorStallModel.parts do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = spec.size
		part.CFrame = spec.cframe
		part.Color = spec.color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if not Studs.apply(part, 0.5) then
			for _, face in Enum.NormalId:GetEnumItems() do
				local t = Instance.new("Texture")
				t.Texture = STUDS
				t.StudsPerTileU, t.StudsPerTileV = 0.5, 0.5
				t.Face = face
				t.Parent = part
			end
		end
		part.Parent = model
		if spec.name == "Counter" then
			counter = part
		end
	end
	for _, spec in VendorStallModel.pile do
		local egg = Egg.new(spec.kind).model
		for _, part in egg:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			end
		end
		egg:PivotTo(spec.cframe)
		egg.Parent = model
	end
	-- where his feet go (Client/Vendor stands its own Carl here)
	local spot = Instance.new("Part")
	spot.Name = "CarlSpot"
	spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
	spot.Transparency = 1
	spot.Size = Vector3.new(1, 1, 1)
	spot.CFrame = CFrame.new(VendorStallModel.carl)
	spot.Parent = model
	local carl = Cactus.new().model
	carl.Name = "Carl"
	for _, part in carl:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		end
	end
	carl:PivotTo(spot.CFrame)
	carl.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TalkPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = name
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.Vendor.Reach
	prompt.Parent = counter
	model.Parent = parent
	return model
end

function Map.ensure()
	local map = workspace:FindFirstChild("Map")
	if map and map:GetAttribute("Baked") then
		clearSite()
		if map:GetAttribute("Saved") ~= MapData.Saved then
			warn(
				"[Map] the baked workspace.Map isn't from Shared/MapData's map (baked "
					.. tostring(map:GetAttribute("Saved"))
					.. ", MapData "
					.. tostring(MapData.Saved)
					.. "): Map Baker > Rebuild to bake it again"
			)
		end
		-- (a map baked before Shared/HiddenFaces: drop its unseen textures now, QM Oct 27)
		if not map:GetAttribute("HiddenFacesCulled") then
			HiddenFaces.cull(map)
		end
		return map
	end
	return Map.build()
end

function Map.build(data)
	if data then
		data.MeshCentres = data.MeshCentres or MapData.MeshCentres
		MapFile.applyColours(data, COLORS)
		MapData = data
		Map.data = data
	end
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	clearSite()
	loadStone()
	local map = Instance.new("Folder")
	map.Name = "Map"
	local wallFolder = folder("Walls", map)
	floors(folder("Floor", map), wallFolder)
	walls(wallFolder)
	local rng = Random.new(24)
	local pillars = folder("Pillars", map)
	-- (each built at the origin, then turned, scaled and moved to its spot: they're
	-- objects in the map editor now, QM Oct 24)
	local function put(model, x, z, yaw, scale, y)
		model.WorldPivot = CFrame.identity
		if scale and scale ~= 1 then
			model:ScaleTo(scale)
		end
		model:PivotTo(CFrame.new(x, y or 0, z) * CFrame.Angles(0, math.rad(yaw or 0), 0))
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part:GetAttribute("Shade") then
				shadeStone(part)
			end
		end
	end
	for _, p in MapData.Pillars do
		local height = if p[6] == "gate" then ARCH_SPRING + 6 else p[5]
		put(pillar(pillars, p[1], 0, 0, p[4], height, p[6], rng), p[2], p[3], p[7], p[8], p[9])
	end
	gates(folder("Gates", map), folder("Blockers", map))
	for _, a in MapData.Arches do
		put(arch(pillars, a[1], 0, 0, rng), a[2], a[3], a[4], a[5], a[6])
	end
	local base = folder("Base", map)
	baseFurniture(base)
	biomeFurniture(folder("Biomes", map))
	props(folder("Props", map))
	local ruins = folder("Ruins", map)
	for _, r in MapData.Ruins do
		ruin(ruins, r)
	end
	local vendors = folder("Vendors", map)
	for _, v in MapData.Vendors or {} do
		local model = vendor(vendors, v[1])
		model:SetAttribute("Scale", v[5])
		put(model, v[2], v[3], v[4], v[5], v[6])
	end
	-- (the textures on faces nobody sees, thousands of them: QM Oct 27, the game lagged)
	HiddenFaces.cull(map)
	map:SetAttribute("Baked", not RunService:IsRunning())
	map:SetAttribute("Saved", MapData.Saved)
	map.Parent = workspace
	return map
end

return Map
