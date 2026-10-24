-- The sword, built from QM's designs/Sword.bbmodel (via SwordModel.luau).
--   Sword.makeTool()     -- the Tool players hold (Root becomes its Handle)
--   Sword.makeModel(k)   -- an anchored copy, k times the size (the one riding the slash)
--
-- The model's blade points up its +Y, guard at the origin, grip below it (y -0.5..0).

local Rig = require(script.Parent.Parent.Rig)
local Studs = require(script.Parent.Parent.Studs)
local SwordModel = require(script.Parent.SwordModel)

local Sword = {}

local STUDS = { image = Studs.IMAGE, tile = 0.5 }
local SCALE = 1.6 -- the held sword, times the size it's drawn in Blockbench (QM, Oct 23)
local GRIP_Y = -0.25 * SCALE -- the middle of the grip, where the hand closes

function Sword.makeModel(scale)
	local model = Rig.fromData(SwordModel, "Sword", STUDS, scale)
	return model
end

function Sword.makeTool()
	local model = Sword.makeModel(SCALE)
	local tool = Instance.new("Tool")
	tool.Name = "Sword"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
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

return Sword
