-- SpineLizard: a low sprawling desert lizard with a tall orange and gold sail. Epic.
-- Converted from QM's old Blockbench model by tools/convert_designs.py (the pose is in its bones'
-- rest rotations), animated by tools/convert_rig.py and converted into SpineLizardModel.luau by
-- tools/bbmodel_to_luau.py from designs/converted/SpineLizard.bbmodel. You ride at the front of its back, just ahead of the sail.

local Horse = require(script.Parent.Horse)
local SpineLizardModel = require(script.Parent.SpineLizardModel)

return Horse.variant("SpineLizard", SpineLizardModel, "Epic", {
	seat = Vector3.new(0, 4.2, -4.08),
	neck = { center = Vector3.new(0, 2.84, -4.42), radius = 2.04 },
})
