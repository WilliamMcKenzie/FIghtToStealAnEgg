-- IceGolem: a knuckle-walking ice golem with ice crystals growing out of its back. Epic.
-- First converted from QM's old Blockbench model by tools/convert_designs.py and animated by
-- tools/convert_rig.py; since Oct 2 designs/converted/IceGolem.bbmodel is QM's own edit (three
-- eyes, no fingers, QM's animations), converted into IceGolemModel.luau with
-- `tools/bbmodel_to_luau.py --zyx`. Don't rerun convert_designs/convert_rig on it. You ride on its snowy shoulders, in front of the crystals.

local Horse = require(script.Parent.Horse)
local IceGolemModel = require(script.Parent.IceGolemModel)

return Horse.variant("IceGolem", IceGolemModel, "Epic", {
	seat = Vector3.new(0, 13.36, 0.4),
	neck = { center = Vector3.new(0, 9.2, -1.6), radius = 2.8 },
})
