-- Squid: LassoAPet's Squid (the Kraken's model in pink and orange). You ride on top of its
-- mantle, which is on the root bone (Lasso: the neck bone swung it off into thin air).
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SquidModel = require(script.Parent.SquidModel)

return Horse.variant("Squid", SquidModel, "Divine", {
	seat = Vector3.new(0, 29.1, 3.9),
	neck = { center = Vector3.new(0, 5.8, 0), radius = 2.4 },
	seatBone = "root",
	seatOnNeck = true,
})
