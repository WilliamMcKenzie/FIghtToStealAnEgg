-- What only you see and bump into (QM, Oct 24):
-- - Locked into a boss's fight (your LockedIn attribute: you stole one of its eggs or
--   hit it; server/Eggs.luau), red barriers stand across that biome's ways out until the
--   boss is dead. Everyone else walks through, unless they join the fight too. They're
--   local parts, so they only block you.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local map = workspace:WaitForChild("Map")

-- ---- the fight's barriers ------------------------------------------------------------

-- (the barriers are built into the map, visible in Studio: here they start hidden and
-- only the ones round your fight show, solid for you alone)
local function barriers()
	local biome = player:GetAttribute("LockedIn")
	local markers = map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	for _, wall in if markers then markers:GetChildren() else {} do
		local mine = biome ~= nil and (wall:GetAttribute("South") == biome or wall:GetAttribute("North") == biome)
		-- (solid for you when it's yours; client/FightBarrierFx draws it, quasicrystal)
		wall.CanCollide = mine
		wall.Transparency = 1
	end
end

player:GetAttributeChangedSignal("LockedIn"):Connect(barriers)
barriers()

return {}
