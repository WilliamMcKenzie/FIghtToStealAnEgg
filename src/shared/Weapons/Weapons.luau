-- Every weapon (Config.Weapons): its tool, its model, and how it attacks.
--   Weapons.get(id) -> its Config.Weapons entry (the Sword's for an unknown id)
--   Weapons.makeTool(id)       -- the Tool players hold (attributes Weapon, WeaponType)
--   Weapons.makeModel(id, k)   -- an anchored copy, k times the held size (spin, shots)
--   Weapons.slash(c, id)       -- Config.Slash (or SlashTuning's live copy) with a melee
--                              -- weapon's Slash values over it
--   Weapons.range(id, c)       -- how close a target has to be before it attacks
--   Weapons.cooldown(id, c)    -- seconds between attacks
--   Weapons.drops(bossKind)    -- { { id, weight } }: what that boss can drop
--
-- Models point up +Y with the grip at y -0.5..0 (see WeaponModels), so every tool's
-- Grip is the sword's.

local Config = require(script.Parent.Parent.Config)
local Rig = require(script.Parent.Parent.Rig)
local Studs = require(script.Parent.Parent.Studs)
local SwordModel = require(script.Parent.SwordModel)
local WeaponModels = require(script.Parent.WeaponModels)

local Weapons = {}

local STUDS = { image = Studs.IMAGE, tile = 0.5 }
local SCALE = 1.6 -- held size, times the drawing (the sword's: QM, Oct 23)
local GRIP_Y = -0.25 * SCALE -- the middle of the grip, where the hand closes

function Weapons.get(id)
	return Config.Weapons[id] or Config.Weapons.Sword
end

function Weapons.exists(id)
	return type(id) == "string" and Config.Weapons[id] ~= nil
end

function Weapons.makeModel(id, scale)
	local data = if id == "Sword" then SwordModel else WeaponModels[id] or SwordModel
	return Rig.fromData(data, id, STUDS, SCALE * (scale or 1))
end

function Weapons.makeTool(id)
	if not Weapons.exists(id) then
		id = "Sword"
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
	for k, v in w.Slash do
		if k == "Variety" then
			c.Variety = table.clone(c.Variety)
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
	return Weapons.slash(c, id).AttackRange
end

function Weapons.cooldown(id, c)
	local w = Weapons.get(id)
	if w.Shot then
		return w.Shot.Cooldown or 0.6
	end
	return Weapons.slash(c, id).Cooldown
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
