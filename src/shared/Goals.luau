-- Goals (QM, Oct 31): what the top-left Goal panel (client/GoalPanel) asks of you next.
-- Config.Goals.List in order; the first one you haven't done is yours. After the last
-- (Collect Pets: every pet in the Index, QM) there's none, and the panel goes.
--
--   Goals.current(player) -> nil once every goal's done, else {
--     index = its place in the list,
--     goal = its Config.Goals.List entry (client/GoalGuide points the arrows by it),
--     title = "Train Power" (RichText: a rarity's name is in its colour),
--     have, need = the bar's numbers (have can pass need),
--     text = "5.9K/10K" (or "$1.2K/$2K" for cash),
--   }
--   Goals.found(player) -> { [pet] = true } for the pets in your Index
--   Goals.stolen(player, region) -> eggs stolen there ever (saved attribute Stolen)
--   Goals.RANKS                  -- the rarities, worst to best

local Config = require(script.Parent:WaitForChild("Config"))
local Abbrev = require(script.Parent:WaitForChild("Abbrev"))
local Levels = require(script.Parent:WaitForChild("Levels"))
local Stacks = require(script.Parent:WaitForChild("Stacks"))
local IndexList = require(script.Parent:WaitForChild("IndexList"))

local Goals = {}

Goals.RANKS = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Celestial", "Cosmic", "Void", "Omega" }
local rankOf = {}
for i, name in Goals.RANKS do
	rankOf[name] = i
end

local function regionName(name)
	return Config.Regions.Names[name] or name
end

-- the pets you've found, for the Index (PetIndex: Server/PetIndex): { [kind] = true }
function Goals.found(player)
	local out = {}
	for id in string.gmatch(player:GetAttribute("PetIndex") or "", "[^,%s]+") do
		out[id] = true
	end
	return out
end

function Goals.stolen(player, region)
	return Stacks.count(Stacks.parse(player:GetAttribute("Stolen")), region)
end

local function ownsRegion(player, name)
	local cost = Config.Regions.Cost[name]
	return cost == nil or cost <= 0 or player:GetAttribute("Region" .. name) == true
end

local function ownedWeapons(player)
	local list = {}
	for id in string.gmatch(player:GetAttribute("Weapons") or "", "[^,:%s]+") do
		list[id] = true
	end
	list[Config.Arsenal.Start] = true
	return list
end

local function cashText(have, need)
	return "$" .. Abbrev(have) .. "/$" .. Abbrev(need)
end

-- the goal's state: nil when it's done, else { title, have, need, text }
local function check(player, g)
	local cash = player:GetAttribute("Cash") or 0
	if g.Power then
		local power = player:GetAttribute("Power") or player:GetAttribute("Strength") or 0
		local need = Levels.at(g.Power)
		if power >= need then
			return nil
		end
		return { title = g.Title or "Train Power", have = power, need = need, text = Abbrev(power) .. "/" .. Abbrev(need) }
	elseif g.Steal then
		local have = 0
		for _, region in g.In or {} do
			have += Goals.stolen(player, region)
		end
		if have >= g.Steal then
			return nil
		end
		local where = if g.In and #g.In == 1 then regionName(g.In[1]) .. " " else ""
		return {
			title = g.Title or string.format("Steal %d %seggs", g.Steal, where),
			have = have,
			need = g.Steal,
			text = have .. "/" .. g.Steal,
		}
	elseif g.Region then
		local missing, owned = math.huge, 0
		for _, name in g.Region do
			if ownsRegion(player, name) then
				owned += 1
			else
				missing = math.min(missing, Config.Regions.Cost[name])
			end
		end
		local done = if g.All then owned == #g.Region else owned > 0
		if done or missing == math.huge then
			return nil
		end
		return {
			title = g.Title or ("Unlock " .. regionName(g.Region[1])),
			have = cash,
			need = missing,
			text = cashText(cash, missing),
		}
	elseif g.Weapon then
		local want = rankOf[g.Weapon] or 1
		for id in ownedWeapons(player) do
			local w = Config.Weapons[id]
			if w and (rankOf[w.Rarity] or 0) >= want then
				return nil
			end
		end
		local cheapest = math.huge
		for _, w in Config.Weapons do
			if type(w) == "table" and w.Rarity == g.Weapon and w.Price then
				cheapest = math.min(cheapest, w.Price)
			end
		end
		if cheapest == math.huge then
			return nil
		end
		local look = Config.Rarities[g.Weapon]
		local a = if string.find(g.Weapon, "^[AEIOUaeiou]") then "an" else "a"
		local title = g.Title
			or string.format(
				'Buy %s <font color="#%s">%s</font> weapon',
				a,
				(look and look.text or Color3.new(1, 1, 1)):ToHex(),
				g.Weapon
			)
		return { title = title, have = cash, need = cheapest, text = cashText(cash, cheapest) }
	elseif g.Collect then
		local found = Goals.found(player)
		local have, need = 0, 0
		for _, kind in IndexList.all() do
			need += 1
			if found[kind] then
				have += 1
			end
		end
		if have >= need then
			return nil
		end
		return { title = g.Title or "Collect Pets", have = have, need = need, text = have .. "/" .. need }
	elseif g.Train then
		local ground = Config.Training.Grounds[g.Train]
		if not ground or ground.Cost <= 0 or player:GetAttribute("Train" .. g.Train) == true then
			return nil
		end
		return {
			title = g.Title or ("Unlock " .. regionName(g.Train) .. " Training"),
			have = cash,
			need = ground.Cost,
			text = cashText(cash, ground.Cost),
		}
	end
	return nil
end

function Goals.current(player)
	for i, g in Config.Goals.List do
		local state = check(player, g)
		if state then
			state.index = i
			state.goal = g
			return state
		end
	end
	return nil -- (all done: the panel's gone for good)
end

return Goals
