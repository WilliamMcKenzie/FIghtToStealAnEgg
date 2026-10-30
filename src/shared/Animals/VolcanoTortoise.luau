-- Volcano Tortoise: the Volcano's only animal (QM, Oct 11). A stumpy tortoise with a
-- stepped stone volcano on its shell, its crater rim and drips glowing lava, and a beak
-- of downward-facing triangular prisms. QM's file designs/volcano/VolcanoTortoise.bbmodel
-- (Claude's idle, walk and gallop: tools/tortoise_design.py animate), converted with
-- `tools/bbmodel_to_luau.py --zyx` (its brows turn about two axes). You ride on the
-- shell behind the volcano.

local Horse = require(script.Parent.Horse)
local VolcanoTortoiseModel = require(script.Parent.VolcanoTortoiseModel)

return Horse.variant("VolcanoTortoise", VolcanoTortoiseModel, "Rare", { -- (QM, Oct 11: was Epic)
	seat = Vector3.new(0, 5.2, 2.35),
	neck = { center = Vector3.new(0, 4, -5.6), radius = 1.8 },
})
