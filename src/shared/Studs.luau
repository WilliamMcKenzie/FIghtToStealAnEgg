-- Studs as a material (Config.StudMaterial, QM Oct 7): instead of a stud Texture on
-- every face (tens of thousands of them, each drawn on its own), a part gets a stud
-- MaterialVariant from MaterialService: "Studs" for the 1-stud studs (ground), and
-- "StudsHalf" for the 0.5-stud ones (animals, eggs, Carl's stall), and StudsNNN for
-- the scaled obstacles' sizes in between (NAMES). They're
-- from the "2008-2024 Studs As PBR Materials" pack (Glacier base material), tinted by
-- the part's colour like the textures were. Without them in MaterialService, or with
-- Config.StudMaterial off, everything keeps its textures.
--
--   Studs.apply(part, tile) -- the stud material for that tile size; false if there's none
--   Studs.convert(part)     -- swaps a part's stud Textures for the material (not ground
--                           -- with a checker: its studs lie over the checker)
--   Studs.mesh(part, tile)  -- stud Textures on all six sides of a MeshPart (QM, Oct 31:
--                           -- the bushes, rocks and other meshes were flat). A Texture on a
--                           -- mesh is projected on it from that side of its box, so faces
--                           -- square to a side get round studs and slanted ones stretched studs.
--   Studs.meshAll(root, tile) -- Studs.mesh on every plain MeshPart under root -> how many

local MaterialService = game:GetService("MaterialService")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

-- (a client sees MaterialService's variants once the place has loaded in: without
-- this, the first animals and eggs built at join could miss them and keep textures)
-- (not in Studio's Edit mode, where game.Loaded never fires: the lineup tool builds animals there)
if Config.StudMaterial and RunService:IsClient() and RunService:IsRunning() and not game:IsLoaded() then
	game.Loaded:Wait()
end

local Studs = {}

Studs.IMAGE = "rbxassetid://7447638591" -- the classic stud decal every stud Texture uses
-- One variant per stud size, each the same pack material with its own StudsPerTile.
-- The map's obstacles were scaled, so their studs run from about 0.29 to 0.65 studs:
-- a stud Texture takes the variant nearest its size, as long as that's within
-- MATCH (the sizes below are 10% apart, so a stud is never more than ~5% off).
local NAMES = {
	[0.29] = "Studs290",
	[0.32] = "Studs320",
	[0.35] = "Studs350",
	[0.385] = "Studs385",
	[0.425] = "Studs425",
	[0.465] = "Studs465",
	[0.5] = "StudsHalf",
	[0.55] = "Studs550",
	[0.605] = "Studs605",
	[0.665] = "Studs665",
	[1] = "Studs",
}
-- Bigger studs for scaled-up animals and eggs (a Kraken, a Godlands egg in a big nest):
-- 0.5 x 1.1^k studs for k = 4..27 (0.73 to 6.6), named "Studs" .. its size x 1000.
for k = 4, 27 do
	local size = 0.5 * 1.1 ^ k
	NAMES[size] = "Studs" .. math.round(size * 1000)
end
local isStuds = {}
for _, name in NAMES do
	isStuds[name] = true
end
local MATCH = 1.06
-- Glacier is slippery: anything you can stand on keeps plastic's grip.
local PLASTIC = PhysicalProperties.new(Enum.Material.SmoothPlastic)

function Studs.variant(tile)
	if not Config.StudMaterial or not tile or tile <= 0 then
		return nil
	end
	local name, off = nil, MATCH
	for size, n in NAMES do
		local ratio = math.max(size / tile, tile / size)
		if ratio <= off then
			name, off = n, ratio
		end
	end
	local variant = name and MaterialService:FindFirstChild(name)
	return if variant and variant:IsA("MaterialVariant") then variant else nil
end

function Studs.apply(part, tile)
	local variant = Studs.variant(tile)
	if not variant then
		return false
	end
	part.Material = variant.BaseMaterial
	part.MaterialVariant = variant.Name
	if part.CanCollide then
		part.CustomPhysicalProperties = PLASTIC
	end
	return true
end

-- A model scaled up or down (Model:ScaleTo) scales its stud Textures with it, but not
-- a material: this gives its stud-material parts the variant for studSize, its stud
-- size now (the stud tile it was built with x its scale). Only when that changes.
local fitted = setmetatable({}, { __mode = "k" })
function Studs.fit(model, studSize)
	local variant = Studs.variant(studSize)
	if not variant or fitted[model] == variant.Name then
		return
	end
	fitted[model] = variant.Name
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and isStuds[part.MaterialVariant] then
			part.MaterialVariant = variant.Name
		end
	end
end

function Studs.convert(part)
	if part.Material ~= Enum.Material.SmoothPlastic and part.Material ~= Enum.Material.Plastic then
		return false -- (Neon lava and the like have no studs)
	end
	local textures, tile = {}, nil
	for _, child in part:GetChildren() do
		if child:IsA("Texture") then
			if child.Name == "Checker" then
				return false
			elseif child.Texture == Studs.IMAGE then
				tile = tile or child.StudsPerTileU
				table.insert(textures, child)
			end
		end
	end
	if #textures == 0 or not Studs.apply(part, tile) then
		return false
	end
	for _, texture in textures do
		texture:Destroy()
	end
	return true
end

-- (the stud look on meshes, not on glowing, see-through or already-studded ones)
local function studdable(part)
	if not part:IsA("MeshPart") or part.Transparency > 0.5 then
		return false
	end
	local m = part.Material
	if m == Enum.Material.Neon or m == Enum.Material.Glass or m == Enum.Material.ForceField then
		return false
	end
	for _, child in part:GetChildren() do
		if child:IsA("Texture") and child.Texture == Studs.IMAGE then
			return false
		end
	end
	return true
end

function Studs.mesh(part, tile, transparency)
	if not studdable(part) then
		return false
	end
	-- (workspace.StudStyle: Shared/StudStyle sets every stud Texture's transparency and scale)
	local StudStyle = require(script.Parent.StudStyle)
	for _, face in Enum.NormalId:GetEnumItems() do
		local t = Instance.new("Texture")
		t.Name = "Studs"
		t.Face = face
		t.Texture = Studs.IMAGE
		t.StudsPerTileU, t.StudsPerTileV = tile, tile
		t.ZIndex = 2
		t.Transparency = transparency or StudStyle.transparency()
		t.Parent = part
	end
	return true
end

function Studs.meshAll(root, tile)
	local n = 0
	for _, part in root:GetDescendants() do
		if Studs.mesh(part, tile) then
			n += 1
		end
	end
	return n
end

return Studs
