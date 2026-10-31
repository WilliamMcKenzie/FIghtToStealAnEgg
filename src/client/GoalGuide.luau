-- Where the guide arrows lead once the tutorial's done (QM, Oct 31: "always just point to the
-- current objective"). client/Hud draws them (client/ArrowTrail) from you to this target:
--   - in a boss fight, or during the tutorial: nowhere
--   - a stolen egg in your bag: home to your pen, to put it down (then on with the goal)
--   - Train Power: the best training ground you own (the dearest open one)
--   - Steal eggs: the nearest egg waiting in that goal's regions (else their boss's spot)
--   - Unlock a region / a training ground, buy a weapon: once you've the cash, its gate (or
--     Carl, the weapon vendor); till then the eggs (and boss) of the best region you own,
--     where the cash comes from
--
--   GoalGuide.target(player, goalState, penArea) -> Instance | Vector3 | nil, stopWithin
--     goalState: Shared/Goals.current(player); penArea: your pen's Area part (or nil);
--     stopWithin: studs from it the arrows stop

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local MapData = require(Shared:WaitForChild("MapData"))

local GoalGuide = {}

local NEAR = 8 -- studs from a spot the arrows stop

local function map()
	return workspace:FindFirstChild("Map")
end

-- the middle of a training ground (the Base area's Training bounds) and half its narrow side
local function groundCentre(name)
	for _, area in MapData.Areas or {} do
		for _, t in area.Training or {} do
			if t[1] == name and #t >= 5 then
				local half = math.min(math.abs(t[4] - t[2]), math.abs(t[5] - t[3])) / 2
				return Vector3.new((t[2] + t[4]) / 2, 0, (t[3] + t[5]) / 2), math.max(half, NEAR)
			end
		end
	end
	return nil
end

local function ownsGround(player, name)
	local g = Config.Training.Grounds[name]
	return g ~= nil and (g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
end

local function ownsRegion(player, name)
	local cost = Config.Regions.Cost[name]
	return cost ~= nil and (cost <= 0 or player:GetAttribute("Region" .. name) == true)
end

-- the open training ground that cost the most
local function bestGround(player)
	local best, bestCost = nil, -1
	for name, g in Config.Training.Grounds do
		if ownsGround(player, name) and g.Cost > bestCost and groundCentre(name) then
			best, bestCost = name, g.Cost
		end
	end
	return best
end

-- the boss regions you own that cost the most (both sides past the fork, if you've both)
local function bestRegions(player)
	local list, top = {}, -1
	for name, cost in Config.Regions.Cost do
		if ownsRegion(player, name) then
			if cost > top then
				list, top = { name }, cost
			elseif cost == top then
				table.insert(list, name)
			end
		end
	end
	return list
end

local function nearestOf(list, from)
	local best, bestDist = nil, math.huge
	for _, item in list do
		local at = if typeof(item) == "Vector3" then item else item.Position
		local d = (at - from).Magnitude
		if d < bestDist then
			best, bestDist = item, d
		end
	end
	return best
end

-- the nearest egg you may take in these regions, else the nearest of their boss spots
local function eggsIn(player, regions, from)
	local want = {}
	for _, name in regions do
		if not player:GetAttribute("TookEgg" .. string.gsub(name, "[^%w_]", "")) then
			want[name] = true
		end
	end
	local now = workspace:GetServerTimeNow()
	local eggs = {}
	for _, egg in CollectionService:GetTagged("Egg") do
		if
			egg:IsA("BasePart")
			and want[egg:GetAttribute("Biome")]
			and egg.Parent
			and CollectionService:HasTag(egg.Parent, "Nest")
			and not egg:GetAttribute("Vanish")
			and (egg:GetAttribute("PopAt") or 0) <= now
		then
			table.insert(eggs, egg)
		end
	end
	local egg = nearestOf(eggs, from)
	if egg then
		return egg
	end
	local biomes = map() and map():FindFirstChild("Biomes")
	local spots = {}
	for _, name in regions do
		local f = biomes and biomes:FindFirstChild(name)
		local spot = f and f:FindFirstChild("BossSpot")
		if spot then
			table.insert(spots, spot)
		end
	end
	return nearestOf(spots, from)
end

-- the gate of a region (or, training, of its training ground)
local function gate(region, training)
	local gates = map() and map():FindFirstChild("Gates")
	for _, g in if gates then gates:GetChildren() else {} do
		if
			g:IsA("BasePart")
			and g:GetAttribute("Region") == region
			and (g:GetAttribute("Training") == true) == (training == true)
		then
			return g
		end
	end
	return nil
end

local function carl()
	local vendors = map() and map():FindFirstChild("Vendors")
	for _, stall in if vendors then vendors:GetChildren() else {} do
		local spot = stall:FindFirstChild("CarlSpot", true)
		if spot and spot:IsA("BasePart") then
			return spot
		end
	end
	return nil
end

function GoalGuide.target(player, state, penArea)
	local character = player.Character
	local me = character and character:FindFirstChild("HumanoidRootPart")
	if not me or player:GetAttribute("Tutorial") == true or player:GetAttribute("LockedIn") then
		return nil
	end
	-- (a stolen egg to put down first: home)
	if player:GetAttribute("EggBag") ~= nil then
		if penArea then
			local p = penArea.CFrame:PointToObjectSpace(me.Position)
			if math.abs(p.X) <= penArea.Size.X / 2 and math.abs(p.Z) <= penArea.Size.Z / 2 then
				return nil
			end
		end
		return penArea, NEAR
	end
	local g = state and state.goal
	if not g then
		return nil
	end
	local from = me.Position
	if g.Power then
		local name = bestGround(player)
		if not name then
			return nil
		end
		return groundCentre(name)
	elseif g.Steal then
		return eggsIn(player, g.In or {}, from), NEAR
	end
	-- the rest cost cash: where to spend it once you've enough
	if state.have >= state.need then
		if g.Weapon then
			return carl(), NEAR
		elseif g.Train then
			return gate(g.Train, true), NEAR
		elseif g.Region then
			local gates = {}
			for _, name in g.Region do
				local cost = Config.Regions.Cost[name]
				local found = not ownsRegion(player, name) and cost and cost <= state.have and gate(name, false)
				if found then
					table.insert(gates, found)
				end
			end
			return nearestOf(gates, from), NEAR
		end
	end
	-- not yet: earn it from the best region's eggs and boss
	return eggsIn(player, bestRegions(player), from), NEAR
end

return GoalGuide
