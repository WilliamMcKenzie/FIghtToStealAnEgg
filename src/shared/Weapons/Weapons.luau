-- Every weapon (Config.Weapons): its tool, its model, and how it attacks.
--   Weapons.get(id) -> its Config.Weapons entry (the starting weapon's for an unknown id), with its
--                      Shot filled in from Config.Shots[Type] and any live tuning applied
--   Weapons.makeTool(id)       -- the Tool players hold (attributes Weapon, WeaponType)
--   Weapons.makeModel(id, k)   -- an anchored copy, k times the held size (spin, shots)
--   Weapons.slash(c, id)       -- Config.Slash (or SlashTuning's live copy) with a melee
--                              -- weapon's Slash values over it
--   Weapons.range(id, c)       -- how close a target has to be before it attacks
--   Weapons.cooldown(id, c)    -- seconds between attacks
--   Weapons.drops(bossKind)    -- { { id, weight } }: what that boss can drop
--
-- Live tuning (QM, Oct 25; client/WeaponTuning shows the held weapon's values under
-- Workspace > Weapon): every number, colour, switch and Look can be changed in Play.
--   Weapons.tunables(id)       -- { { key, value } }: the values it can tune, as they are now
--   Weapons.tune(id, key, v)   -- change one (false if it isn't one, or the wrong type)
--   Weapons.untune(id)         -- back to Config
--   Weapons.source(id)         -- its Config entry as Luau, with the tuned values, to paste
--
-- Models point up +Y with the grip at y -0.5..0 (see WeaponModels), so every tool's
-- Grip is the sword's.

local Config = require(script.Parent.Parent.Config)
local Rig = require(script.Parent.Parent.Rig)
local Studs = require(script.Parent.Parent.Studs)
local KendoStickModel = require(script.Parent.KendoStickModel)
local ShortswordModel = require(script.Parent.ShortswordModel)
local LongswordModel = require(script.Parent.LongswordModel)
local AxeModel = require(script.Parent.AxeModel)
local WaraxeModel = require(script.Parent.WaraxeModel)
local ClubModel = require(script.Parent.ClubModel)
local ShortbowModel = require(script.Parent.ShortbowModel)
local LongbowModel = require(script.Parent.LongbowModel)
local NatureBowModel = require(script.Parent.NatureBowModel)
local BloodBowModel = require(script.Parent.BloodBowModel)
local WeaponModels = require(script.Parent.WeaponModels)

local Weapons = {}

-- (QM's, designs/weapons/*.bbmodel)
-- a bow drawn round its middle, moved down so the hand closes on the middle (y -0.25)
local function centred(data)
	local out = table.clone(data)
	out.parts = {}
	for i, part in data.parts do
		local p = table.clone(part)
		p.cframe = CFrame.new(0, -0.25, 0) * part.cframe
		out.parts[i] = p
	end
	return out
end

local DRAWN = {
	KendoStick = KendoStickModel,
	Shortsword = ShortswordModel,
	Longsword = LongswordModel,
	Axe = AxeModel,
	Waraxe = WaraxeModel,
	Club = ClubModel,
	Shortbow = centred(ShortbowModel),
	Longbow = centred(LongbowModel),
	NatureBow = centred(NatureBowModel),
	BloodBow = centred(BloodBowModel),
}

local STUDS = { image = Studs.IMAGE, tile = 0.5 }
local SCALE = 1.6 -- held size, times the drawing (as the old sword's: QM, Oct 23)
local GRIP_Y = -0.25 * SCALE -- the middle of the grip, where the hand closes

-- live tuning: [id] = { Damage = n, Slash = { k = v }, Shot = { k = v } }
local tuned = {}
local merged = {} -- [id] = its entry as get() hands it out (rebuilt after a tune)

local function shotDefaults(w)
	return Config.Shots[w.Type] or {}
end

function Weapons.get(id)
	if not Config.Weapons[id] then
		id = Config.WeaponDrops.Start
	end
	local out = merged[id]
	if out then
		return out
	end
	local w = Config.Weapons[id]
	local t = tuned[id] or {}
	out = table.clone(w)
	if t.Damage then
		out.Damage = t.Damage
	end
	if w.Type == "Melee" then
		local slash = table.clone(w.Slash or {})
		slash.Variety = table.clone(slash.Variety or {})
		for k, v in t.Slash or {} do
			local variety = k:match("^Variety_(.+)$")
			if variety then
				slash.Variety[variety] = { v.X, v.Y }
			else
				slash[k] = v
			end
		end
		out.Slash = slash
	else
		local shot = table.clone(shotDefaults(w))
		for k, v in w.Shot or {} do
			shot[k] = v
		end
		for k, v in t.Shot or {} do
			shot[k] = v
		end
		out.Shot = shot
	end
	merged[id] = out
	return out
end

-- (Config.Slash values that aren't the slash's own look, or that belong to every weapon)
local NOT_TUNED = {
	Damage = true, -- (the weapon's own Damage is the one to tune)
	ZoomStep = true,
	ZoomMax = true,
	ZoomIn = true,
	ZoomReturn = true,
	ZoomPower = true,
	SoundCut = true,
	Volume = true,
	AimTurn = true,
	AimTwist = true,
	AimRange = true,
}
local SIMPLE = { number = true, boolean = true, Color3 = true, string = true, Vector2 = true }

function Weapons.tunables(id)
	local w = Weapons.get(id)
	local list = { { "Damage", w.Damage } }
	if w.Type == "Melee" then
		local c = Weapons.slash(Config.Slash, id)
		local keys = {}
		for k, v in c do
			if SIMPLE[typeof(v)] and not NOT_TUNED[k] then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			table.insert(list, { k, c[k] })
		end
		local names = {}
		for name in c.Variety do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local range = c.Variety[name]
			table.insert(list, { "Variety_" .. name, Vector2.new(range[1], range[2]) })
		end
	else
		local keys = {}
		for k, v in w.Shot do
			if SIMPLE[typeof(v)] then
				table.insert(keys, k)
			end
		end
		table.sort(keys)
		for _, k in keys do
			table.insert(list, { k, w.Shot[k] })
		end
	end
	return list
end

function Weapons.tune(id, key, value)
	if not Config.Weapons[id] or type(key) ~= "string" then
		return false
	end
	local current = nil
	for _, pair in Weapons.tunables(id) do
		if pair[1] == key then
			current = pair[2]
		end
	end
	if current == nil or typeof(current) ~= typeof(value) or value ~= value then
		return false
	end
	local t = tuned[id] or {}
	tuned[id] = t
	if key == "Damage" then
		t.Damage = value
	else
		local section = if Config.Weapons[id].Type == "Melee" then "Slash" else "Shot"
		t[section] = t[section] or {}
		t[section][key] = value
	end
	merged[id] = nil
	return true
end

function Weapons.untune(id)
	tuned[id] = nil
	merged[id] = nil
end

-- ---- Weapons.source: the entry as Luau ------------------------------------------------

local function literal(v)
	local kind = typeof(v)
	if kind == "number" then
		local r = math.round(v * 1000) / 1000
		return if r == math.floor(r) then tostring(math.floor(r)) else tostring(r)
	elseif kind == "string" then
		return string.format("%q", v)
	elseif kind == "boolean" then
		return tostring(v)
	elseif kind == "Color3" then
		return string.format("Color3.fromRGB(%d, %d, %d)", math.round(v.R * 255), math.round(v.G * 255), math.round(v.B * 255))
	elseif kind == "table" then
		return "{ " .. literal(v[1]) .. ", " .. literal(v[2]) .. " }"
	end
	return tostring(v)
end

local function same(a, b)
	if type(a) == "table" and type(b) == "table" then
		return a[1] == b[1] and a[2] == b[2]
	elseif typeof(a) == "number" and typeof(b) == "number" then
		return math.abs(a - b) < 1e-6
	end
	return a == b
end

local ORDER = { "Name", "Type", "Rarity", "Boss", "Damage", "Weight" }

-- its Config.Weapons block: the fixed fields, then Slash or Shot with every value that
-- differs from the base (Config.Slash, or Config.Shots[Type])
function Weapons.source(id)
	local w = Weapons.get(id)
	local lines = { "\t\t" .. id .. " = {" }
	for _, k in ORDER do
		if w[k] ~= nil then
			table.insert(lines, "\t\t\t" .. k .. " = " .. literal(w[k]) .. ",")
		end
	end
	local section, values, base
	if w.Type == "Melee" then
		section, values, base = "Slash", Weapons.slash(Config.Slash, id), Config.Slash
	else
		section, values, base = "Shot", w.Shot, Config.Shots[w.Type] or {}
	end
	local keys = {}
	for k, v in values do
		if k ~= "Variety" and SIMPLE[typeof(v)] and not NOT_TUNED[k] and not same(v, base[k]) then
			table.insert(keys, k)
		end
	end
	table.sort(keys)
	local inner = {}
	for _, k in keys do
		table.insert(inner, "\t\t\t\t" .. k .. " = " .. literal(values[k]) .. ",")
	end
	if values.Variety and base.Variety then
		local variety = {}
		local names = {}
		for name in values.Variety do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			if not same(values.Variety[name], base.Variety[name]) then
				table.insert(variety, name .. " = " .. literal(values.Variety[name]))
			end
		end
		if #variety > 0 then
			table.insert(inner, "\t\t\t\tVariety = { " .. table.concat(variety, ", ") .. " },")
		end
	end
	if #inner > 0 then
		table.insert(lines, "\t\t\t" .. section .. " = {")
		for _, line in inner do
			table.insert(lines, line)
		end
		table.insert(lines, "\t\t\t},")
	end
	table.insert(lines, "\t\t},")
	return table.concat(lines, "\n")
end

function Weapons.exists(id)
	return type(id) == "string" and Config.Weapons[id] ~= nil
end

function Weapons.makeModel(id, scale)
	-- (QM's Blockbench ones, via tools/bbmodel_to_luau.py, then the hand-made blocks)
	local data = DRAWN[id] or WeaponModels[id] or KendoStickModel
	return Rig.fromData(data, id, STUDS, SCALE * (scale or 1))
end

function Weapons.makeTool(id)
	if not Weapons.exists(id) then
		id = Config.WeaponDrops.Start
	end
	local w = Weapons.get(id)
	local model = Weapons.makeModel(id, 1)
	local tool = Instance.new("Tool")
	tool.Name = id
	tool.ToolTip = w.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("Weapon", id)
	tool:SetAttribute("WeaponType", w.Type)
	-- Wielded, not pointed: the blade (+Y) comes out of the top of the fist, square to
	-- the forearm (the R15 grip attachment's +Y), with the hand on the middle of the grip.
	tool.Grip = CFrame.new(0, GRIP_Y, 0)
	local root = model.PrimaryPart
	root.Name = "Handle"
	root.Anchored = false
	root.Massless = true
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	return tool
end

function Weapons.slash(c, id)
	local w = Weapons.get(id)
	if not w.Slash then
		return c
	end
	c = table.clone(c)
	c.Variety = table.clone(c.Variety)
	for k, v in w.Slash do
		if k == "Variety" then
			for name, range in v do
				c.Variety[name] = range
			end
		else
			c[k] = v
		end
	end
	return c
end

function Weapons.range(id, c)
	local w = Weapons.get(id)
	if w.Shot then
		return w.Shot.Range or 50
	end
	return Weapons.slash(c or Config.Slash, id).AttackRange
end

function Weapons.cooldown(id, c)
	local w = Weapons.get(id)
	if w.Shot then
		return w.Shot.Cooldown or 0.6
	end
	return Weapons.slash(c or Config.Slash, id).Cooldown
end

-- every droppable weapon, and the boss's own one (a boss-only weapon drops from its boss only)
function Weapons.drops(bossKind)
	local list = {}
	for id, w in Config.Weapons do
		if w.Weight and w.Weight > 0 and (w.Boss == nil or w.Boss == bossKind) then
			table.insert(list, { id = id, weight = w.Weight })
		end
	end
	table.sort(list, function(a, b) -- (a steady order, so odds and rolls don't depend on hashing)
		return a.id < b.id
	end)
	return list
end

return Weapons
