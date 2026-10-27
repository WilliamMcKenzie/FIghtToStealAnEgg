-- Drops the stud and checker Textures on faces nobody can see (QM, Oct 27: the game lagged
-- in Studio; the map had ~22,000 Textures, each drawn on its own). A face is hidden when
-- it's wholly inside other solid blocks: a floor plate's sides against its neighbours, a
-- stall plank's underside on the ground, an egg's faces buried in the pile. Like
-- Rig.covered, but sampled every couple of studs, so a long face with a low neighbour
-- partway along keeps its studs.
--
--   HiddenFaces.cull(root) -> how many Textures it dropped
--     (marks root HiddenFacesCulled, so Server/Map can skip a baked map that's done)

local HiddenFaces = {}

local CELL = 16 -- studs: the grid the blocks are bucketed in, so each test only looks nearby
local STEP = 2 -- studs between the points tested on a face
local OFF = 0.02 -- how far off the face each point is

-- a solid, see-nothing-through box: only these can hide another's face
local function solid(part)
	return part.ClassName == "Part" and part.Shape == Enum.PartType.Block and part.Transparency <= 0.01
end

local function cellsOf(cf, size, fn)
	-- the world box round the part, in CELLs
	local half = size / 2
	local ext = Vector3.new(
		math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
		math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
		math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
	)
	local lo, hi = cf.Position - ext, cf.Position + ext
	for x = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
		for y = math.floor(lo.Y / CELL), math.floor(hi.Y / CELL) do
			for z = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				fn(x .. "," .. y .. "," .. z)
			end
		end
	end
end

local function inside(at, part)
	local l = part.CFrame:PointToObjectSpace(at)
	local h = part.Size / 2
	return math.abs(l.X) <= h.X + 1e-3 and math.abs(l.Y) <= h.Y + 1e-3 and math.abs(l.Z) <= h.Z + 1e-3
end

local function steps(half)
	-- points across -half..half, about STEP apart, just in from the edges
	local n = math.max(1, math.ceil(2 * half / STEP))
	local list = {}
	for i = 0, n do
		table.insert(list, (i / n * 2 - 1) * math.max(half - 0.05, 0))
	end
	return list
end

function HiddenFaces.cull(root)
	local grid = {}
	local textured = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			if solid(part) then
				cellsOf(part.CFrame, part.Size, function(key)
					local list = grid[key]
					if not list then
						list = {}
						grid[key] = list
					end
					table.insert(list, part)
				end)
			end
		elseif part:IsA("Texture") then
			local p = part.Parent
			if p and p.ClassName == "Part" and p.Shape == Enum.PartType.Block then
				textured[p] = textured[p] or {}
				table.insert(textured[p], part)
			end
		end
	end

	local dropped = 0
	for part, textures in textured do
		local verdict = {} -- [face] = hidden?
		for _, texture in textures do
			local face = texture.Face
			if verdict[face] == nil then
				local n = Vector3.FromNormalId(face)
				local half = part.Size / 2
				local out = n * (half + Vector3.one * OFF)
				local us, vs
				if n.X ~= 0 then
					us, vs = steps(half.Y), steps(half.Z)
				elseif n.Y ~= 0 then
					us, vs = steps(half.X), steps(half.Z)
				else
					us, vs = steps(half.X), steps(half.Y)
				end
				local hidden = true
				for _, u in us do
					for _, v in vs do
						local along = if n.X ~= 0
							then Vector3.new(0, u, v)
							elseif n.Y ~= 0 then Vector3.new(u, 0, v)
							else Vector3.new(u, v, 0)
						local at = part.CFrame:PointToWorldSpace(out + along)
						local key = math.floor(at.X / CELL)
							.. ","
							.. math.floor(at.Y / CELL)
							.. ","
							.. math.floor(at.Z / CELL)
						local covered = false
						for _, other in grid[key] or {} do
							if other ~= part and inside(at, other) then
								covered = true
								break
							end
						end
						if not covered then
							hidden = false
							break
						end
					end
					if not hidden then
						break
					end
				end
				verdict[face] = hidden
			end
			if verdict[face] then
				texture:Destroy()
				dropped += 1
			end
		end
	end
	root:SetAttribute("HiddenFacesCulled", true)
	return dropped
end

return HiddenFaces
