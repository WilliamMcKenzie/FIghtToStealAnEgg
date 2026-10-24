-- The .map file (QM, Oct 24): the map editor's format (tools/mapeditor), decoded into the
-- layout Server/Map builds. Shared/MapData is maps/world.map baked in (tools/map_bake.py);
-- the Map Baker plugin (tools/studio/MapBaker.lua) decodes a file straight from disk.
--
-- A .map is JSON: a grid of 4-stud cells (one checker square each), `rows` north to
-- south, one character a cell ("." is no floor: under the walls), each character a tile
-- from `tiles` ({ id, area, key (ColorKey), top, liquid? }); the areas' settings; the
-- objects placed on it (Prop, Ruin, Pillar, Arch, Nest, Boss); `colours`, the ColorKeys QM changed from
-- Config.WorldColors ({ key: [r, g, b] }: they win over Config's); and `fixed`: walls, pillars, arches and
-- barriers, shown in the editor but laid out by tools/map_gen.py.
--
--   MapFile.decode(text) -> the layout (as Shared/MapData: Areas, Walls, Props, ...)
--   MapFile.groundAt(data, x, z) -> the floor's top there (WallHeight off the floor)
--   MapFile.applyColours(data, colours) -- the map's colours over a WorldColors table

local HttpService = game:GetService("HttpService")

local MapFile = {}

local MAX_PART = 512 -- (no floor part longer than this)

-- Greedy merge of same-tile cells into rectangles: { tile, col0, row0, col1, row1 } (ends
-- exclusive). `kind[row][col]` is a tile number or 0.
local function rects(kind, cols, rows)
	local done = {}
	for r = 1, rows do
		done[r] = {}
	end
	local out = {}
	local most = MAX_PART // 4
	for r = 1, rows do
		for c = 1, cols do
			local k = kind[r][c]
			if k ~= 0 and not done[r][c] then
				local c1 = c
				while c1 <= cols and c1 - c < most and kind[r][c1] == k and not done[r][c1] do
					c1 += 1
				end
				local r1 = r + 1
				while r1 <= rows and r1 - r < most do
					local ok = true
					for cc = c, c1 - 1 do
						if kind[r1][cc] ~= k or done[r1][cc] then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					r1 += 1
				end
				for rr = r, r1 - 1 do
					for cc = c, c1 - 1 do
						done[rr][cc] = true
					end
				end
				table.insert(out, { k, c, r, c1, r1 })
			end
		end
	end
	return out
end

function MapFile.groundAt(data, x, z)
	local g = data.Grid
	local c = math.floor((x - g.X0) / g.Cell) + 1
	local r = math.floor((z - g.Z0) / g.Cell) + 1
	local row = g.Rows[r]
	local ch = if row and c >= 1 and c <= g.Cols then string.sub(row, c, c) else "."
	local tile = g.Tiles[ch]
	return if tile then tile.top else data.WallHeight
end

function MapFile.applyColours(data, colours)
	for key, c in data.Colours or {} do
		colours[key] = Color3.fromRGB(c[1], c[2], c[3])
	end
end

function MapFile.decode(text)
	local file = HttpService:JSONDecode(text)
	assert(file.format == "StealAndFightPets.map", "not a .map file")
	local cell, cols, rows = file.cell, file.size[1], file.size[2]
	local x0, z0 = file.origin[1], file.origin[2]
	local fixed = file.fixed

	local data = {
		Saved = file.saved, -- (the editor stamps a download; Server/Map compares the baked map's)
		Colours = file.colours or {},
		WallHeight = fixed.wallHeight,
		GateHalf = fixed.gateHalf,
		Walls = fixed.walls,
		Ring = fixed.ring,
		-- { style, x, z, size, height, kind, yaw, scale, y } and { style, x, z, yaw, scale, y }:
		-- objects now (QM, Oct 24: every mesh adjustable); older files had them in `fixed`
		Pillars = table.clone(fixed.pillars or {}),
		Arches = table.clone(fixed.arches or {}),
		Barriers = fixed.barriers,
		Areas = {},
		Props = {},
		Ruins = {},
		Grid = { X0 = x0, Z0 = z0, Cell = cell, Cols = cols, Rows = file.rows, Tiles = {} },
	}

	-- the areas, and each one's tiles in the file's order
	local byName = {}
	for _, a in file.areas do
		local area = { Name = a.name, Tiles = {}, Floor = {} }
		if a.spawn then
			area.Spawn, area.Pens, area.PenSize = a.spawn, a.pens, a.penSize
			area.Training, area.TrainSize = a.training, a.trainSize
		end
		if a.bounds then
			area.Bounds, area.DaisRadius, area.Nests = a.bounds, a.daisRadius, {}
		end
		table.insert(data.Areas, area)
		byName[a.name] = area
	end
	local tileOf = {} -- tile id -> { area, its index in the area's Tiles }
	for _, t in file.tiles do
		local area = byName[t.area]
		assert(area, "tile " .. t.id .. ": no area " .. tostring(t.area))
		table.insert(area.Tiles, { t.key, t.top, t.liquid or nil })
		tileOf[t.id] = { area, #area.Tiles }
		data.Grid.Tiles[t.id] = t
	end

	-- the floor: each area's cells merged into parts
	local kinds = {}
	for _, area in data.Areas do
		local k = {}
		for r = 1, rows do
			k[r] = table.create(cols, 0)
		end
		kinds[area] = k
	end
	for r = 1, rows do
		local row = file.rows[r]
		for c = 1, cols do
			local ch = string.sub(row, c, c)
			local t = tileOf[ch]
			if t then
				kinds[t[1]][r][c] = t[2]
			end
		end
	end
	for _, area in data.Areas do
		for _, p in rects(kinds[area], cols, rows) do
			-- { tile, x0, z0 (south edge), size x, size z }, as Server/Map wants
			table.insert(area.Floor, {
				p[1],
				x0 + (p[2] - 1) * cell,
				z0 + (p[5] - 1) * cell,
				(p[4] - p[2]) * cell,
				(p[5] - p[3]) * cell,
			})
		end
	end

	-- the objects
	for _, o in file.objects do
		if o.type == "Prop" then
			local y = o.y or MapFile.groundAt(data, o.x, o.z)
			table.insert(data.Props, { o.item, o.x, o.z, y, o.yaw or 0, o.scale or 1, o.style or "Base" })
		elseif o.type == "Ruin" then
			table.insert(data.Ruins, { o.style, o.x, o.z, o.length, o.yaw or 0, o.height, o.seed or 1 })
		elseif o.type == "Pillar" then
			table.insert(
				data.Pillars,
				{ o.style, o.x, o.z, o.size, o.height, o.kind, o.yaw or 0, o.scale or 1, o.y or 0 }
			)
		elseif o.type == "Arch" then
			table.insert(data.Arches, { o.style, o.x, o.z, o.yaw or 0, o.scale or 1, o.y or 0 })
		elseif o.type == "Nest" and byName[o.area] and byName[o.area].Nests then
			table.insert(byName[o.area].Nests, { o.x, o.z })
		elseif o.type == "Boss" and byName[o.area] then
			byName[o.area].Boss = { o.x, o.z }
		end
	end
	return data
end

return MapFile
