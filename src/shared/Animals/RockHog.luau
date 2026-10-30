-- Rock Hog: a Volcano boar (QM, Oct 11): slate basalt coat, fiery red-to-yellow horns and
-- tusks, and fiery spikes fanned out of its back like the Ice Golem's crystals. Rare.
-- QM's file designs/volcano/RockHog.bbmodel (the Boar's idle, walk and gallop; spikes from
-- tools/rock_hog.py spikes), converted with `tools/bbmodel_to_luau.py --zyx`. You ride on its
-- back between the shoulder spikes and the rear ones.

local Horse = require(script.Parent.Horse)
local RockHogModel = require(script.Parent.RockHogModel)

return Horse.variant("RockHog", RockHogModel, "Rare", {
	seat = Vector3.new(0, 6.27, 0.9),
	neck = { center = Vector3.new(0, 4.94, -4.56), radius = 2.66 },
})
