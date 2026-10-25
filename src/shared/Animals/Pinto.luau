-- Pinto: the Horse in a white coat with brown patches, the Uncommon horse.
-- Same shape, bones and animations as the Horse; its colours come from
-- designs/horses/Pinto.bbmodel (made by tools/horse_variants.py), converted
-- into PintoModel.luau by tools/bbmodel_to_luau.py.

local Horse = require(script.Parent.Horse)
local PintoModel = require(script.Parent.PintoModel)

return Horse.variant("Pinto", PintoModel, "Uncommon")
