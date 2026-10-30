-- Firebird: a terror bird from the Volcano (QM, Oct 11): orange, with a dark grey hooked
-- beak full of teeth, a black crest, stubby barred wings and long legs. Uncommon.
-- QM's file designs/volcano/Firebird.bbmodel (Claude's idle, walk and gallop, and a Jaw
-- bone that chomps: tools/firebird_design.py animate), converted with
-- `tools/bbmodel_to_luau.py --zyx`. You ride on its back behind the neck.

local Horse = require(script.Parent.Horse)
local FirebirdModel = require(script.Parent.FirebirdModel)

return Horse.variant("Firebird", FirebirdModel, "Uncommon", {
	seat = Vector3.new(0, 8.6, 0.8),
	neck = { center = Vector3.new(0, 11, -4.6), radius = 2 },
})
