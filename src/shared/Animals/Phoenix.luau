-- Phoenix: the first flying animal (QM, Oct 11), a crimson firebird with huge spread
-- wings whose feathers burn orange to gold to glowing flame tips, a fan of flame
-- streamers for a tail and two curly plumes. Legendary, from the Volcano. It never
-- lands: idle hovers, walk and gallop are flaps (tools/phoenix_design.py animate).
-- Sprint flies it up over everything like the Whale (Config.SprintSpecials).
-- QM's file designs/volcano/Phoenix.bbmodel, converted by tools/bbmodel_to_luau.py --zyx.

local Horse = require(script.Parent.Horse)
local PhoenixModel = require(script.Parent.PhoenixModel)

return Horse.variant("Phoenix", PhoenixModel, "Legendary", {
	seat = Vector3.new(0, 4.5, 0.8),
	neck = { center = Vector3.new(0, 6.9, -4.3), radius = 1.8 },
})
