-- FishSchool: LassoAPet's School of Fish: 25 little yellow tangs packed into a rough ball
-- behind a bigger lead fish. You ride on the backs of the top fish.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local FishSchoolModel = require(script.Parent.FishSchoolModel)

return Horse.variant("FishSchool", FishSchoolModel, "Celestial", {
	seat = Vector3.new(0, 4.65, 0.4),
	neck = { center = Vector3.new(0, 2.5, -4.6), radius = 1.1 },
})
