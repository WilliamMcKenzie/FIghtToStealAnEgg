-- Icebringer: a hulking ice ape that knuckle-walks on its fists, with an armoured crest,
-- Snake-style teeth on a jaw that opens, and a long tail. Legendary.
-- QM's model designs/converted/Icebringer.bbmodel (their old Mixcoatl, restyled), animated
-- by tools/icebringer_rig.py and converted into IcebringerModel.luau by tools/bbmodel_to_luau.py.
-- You ride high on its back between the shoulders. Its Frost ability (Config.Abilities)
-- slows the animals round it.

local Horse = require(script.Parent.Horse)
local IcebringerModel = require(script.Parent.IcebringerModel)

return Horse.variant("Icebringer", IcebringerModel, "Legendary", {
	seat = Vector3.new(0, 9.8, 1.1),
	neck = { center = Vector3.new(0, 9, -0.8), radius = 1.3 },
	size = 3, -- (LassoAPet's: tier 3, like the Snake, then QM wanted it 2x its model and 1.5x that)
})
