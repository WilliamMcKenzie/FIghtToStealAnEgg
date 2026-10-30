-- AncientTreant: LassoAPet's Ancient Treant grown in the Magic Circle (QM: recoloured to fit
-- it): slate-blue bark, a violet canopy, a teal moss beard, glowing eyes and glowing fruit
-- hanging from the canopy. Its trunk, beard, arms and canopy are meshes in
-- ReplicatedStorage.AnimalMeshes (tools/animal_meshes.luau). You ride on the canopy.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local AncientTreantModel = require(script.Parent.AncientTreantModel)

return Horse.variant("AncientTreant", AncientTreantModel, "Divine", {
	seat = Vector3.new(0, 32, 0),
	neck = { center = Vector3.new(0, 20.2, 0), radius = 5.1 },
	seatBone = "neck",
	size = 0.868, -- (its longest side 28 studs)
})
