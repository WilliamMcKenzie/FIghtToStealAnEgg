-- Bat: the Halloween world's Haunted Hills Uncommon (QM, Oct 15): a round purple bat (a faceted mesh body) with big ears, little fangs and jointed wings; it flies.
-- designs/halloween/Bat.bbmodel (tools/halloween_bat.py), converted (--zyx --meshes) into
-- BatModel.luau by tools/bbmodel_to_luau.py. Ripped from LassoAPet as a Dungeon pet (QM, Oct 30);
-- its meshes (ReplicatedStorage.AnimalMeshes) are the ones the Blood Bat boss uses.

local Horse = require(script.Parent.Horse)
local BatModel = require(script.Parent.BatModel)

return Horse.variant("Bat", BatModel, "Uncommon", {
	seat = Vector3.new(0, 5.4, 0.3),
	neck = { center = Vector3.new(0, 4.1, -2.2), radius = 1.8 },
})
