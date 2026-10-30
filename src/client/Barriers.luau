-- What only you see and bump into (QM, Oct 24):
-- - Locked into a boss's fight (your LockedIn attribute: you stole one of its eggs or
--   hit it; server/Eggs.luau), red barriers stand across that biome's ways out until the
--   boss is dead. Everyone else walks through, unless they join the fight too. They're
--   local parts, so they only block you.
-- - A training ground you haven't bought keeps its gate shut (a local bar across it),
--   and its Unlock prompt shows; once bought, the bar goes and the prompt hides.

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

-- ---- training gates --------------------------------------------------------------------

local bars = {} -- [zone] = local bar
local function gates()
	local training = map:WaitForChild("Base"):WaitForChild("Training")
	for _, zone in training:GetChildren() do
		local gate = zone:FindFirstChild("Gate")
		if gate then
			local open = player:GetAttribute("Train" .. zone.Name) ~= false
			local prompt = gate:FindFirstChild("Unlock")
			if prompt then
				prompt.Enabled = not open
			end
			if open and bars[zone] then
				bars[zone]:Destroy()
				bars[zone] = nil
			elseif not open and not bars[zone] then
				local bar = Instance.new("Part")
				bar.Name = "LockedGate"
				bar:SetAttribute("NoHop", true) -- (client/Hop: no hopping it)
				bar.Anchored = true
				bar.CanCollide = true
				bar.Size = Vector3.new(gate.Size.X, 4, 0.6)
				bar.CFrame = gate.CFrame - Vector3.new(0, gate.Size.Y / 2 - 2, 0)
				bar.Material = Enum.Material.ForceField
				bar.Color = Color3.fromRGB(255, 196, 60)
				bar.Parent = workspace
				bars[zone] = bar
			end
		end
	end
end

player:GetAttributeChangedSignal("LockedIn"):Connect(barriers)
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Train" then
		gates()
	end
end)
barriers()
task.spawn(gates)

return {}
