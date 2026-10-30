-- Fire Lobster: a lava-red lobster from the Volcano (QM, Oct 11) on the Scorpion's base:
-- big crusher claws, a three-spike nose, antennae arching back with glowing tips and a
-- flat tail ending in a glowing fan. Rare.
-- QM's file designs/volcano/FireLobster.bbmodel (Claude's idle, walk and gallop: the
-- Scorpion's tripod legs, the tail flicking down; tools/fire_lobster_design.py animate),
-- converted by tools/bbmodel_to_luau.py. You ride on its back, as on the Scorpion.

local Horse = require(script.Parent.Horse)
local FireLobsterModel = require(script.Parent.FireLobsterModel)

return Horse.variant("FireLobster", FireLobsterModel, "Rare", {
	seat = Vector3.new(0, 4.42, -0.52),
	neck = { center = Vector3.new(0, 2.99, -3.9), radius = 2.2 },
})
