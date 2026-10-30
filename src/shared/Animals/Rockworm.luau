-- Rockworm: the Sandworm in basalt (QM, Oct 11): slate segments, navy plates, glowing lava
-- fins, horn and tail spike, and QM's two lava fangs. Epic, a bit bigger than the Sandworm.
-- QM's file designs/volcano/Rockworm.bbmodel, its walk and run a leap out of the ground,
-- an arc through the air and a dive back under, then 0.8 s slithering on the ground
-- (tools/rockworm.py animate), converted with `tools/bbmodel_to_luau.py --zyx`. You ride
-- its front segment (the seat follows the root bone, so you dive with it).

local Horse = require(script.Parent.Horse)
local Sandworm = require(script.Parent.Sandworm)
local SandwormModel = require(script.Parent.SandwormModel)
-- (QM, Oct 30: it moves just as the Sandworm does: the Sandworm's animations on its own
-- model, which has the same bones at the same pivots)
local RockwormModel = table.clone(require(script.Parent.RockwormModel))
RockwormModel.animations = SandwormModel.animations

return Horse.variant("Rockworm", RockwormModel, "Epic", {
	seat = Vector3.new(0, 4.45, 1.6),
	neck = { center = Vector3.new(0, 3.2, -2.6), radius = 3 },
	size = Sandworm.size * 1.2, -- QM: a bit bigger than the Sandworm
})
