-- Lava Whale: the Whale in Volcano rock (QM, Oct 11): glowing lava spiral glyphs, three big
-- fins a side and a banded unicorn horn on its brow. Epic, very rare (as the Phoenix).
-- QM's file designs/volcano/LavaWhale.bbmodel (from tools/lava_whale.py; the Whale's idle,
-- walk and gallop), converted by tools/bbmodel_to_luau.py --zyx. You ride on its back, as on the Whale.

local Horse = require(script.Parent.Horse)
local LavaWhaleModel = require(script.Parent.LavaWhaleModel)

return Horse.variant("LavaWhale", LavaWhaleModel, "Epic", {
	seat = Vector3.new(0, 6.4, 1.2),
	neck = { center = Vector3.new(0, 4.5, -6.5), radius = 3.8 },
})
