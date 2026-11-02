-- Gameplay stats (QM, Nov 1): what players get stuck on. Logged on the server through
-- Roblox's AnalyticsService, seen in Creator Hub > the experience > Analytics:
--   Custom Events  the events below (each one's chart can be split by its fields)
--   Funnels        "Goals": Joined game, then each Goal panel goal (Config.Goals.List)
--   Economy        cash in (pen income, boss bounties, eggs, Index, offline, Robux packs)
--                  and out (regions, training grounds, weapons, rebirths)
-- (Server/Funnels has the tutorial and biome progress funnels.)
--
-- Custom events (value; field 1, field 2, field 3):
--   BossAttempt        1;                  Boss, Level, Weapon   -- locked into a boss fight
--   BossWin            seconds to kill;    Boss, Level, Weapon
--   BossDeath          seconds survived;   Boss, Level, Weapon
--   BossQuit           seconds in;         Boss, Level, Weapon   -- left the game mid-fight
--   BossWinDetail      seconds to kill;    Boss, Pet, Group
--   BossDeathDetail    boss health left %; Boss, Pet, Group
--     (Level is "Lv 7" at the fight's start, Group "Solo" / "Group of 3"; the tutorial's
--     boss is "Chicken (tutorial)", so it doesn't skew the real one. Death rate for a boss
--     = BossDeath / BossAttempt, both filtered to it.)
--   PlayerDeath        1;                  Where ("Boss fight", "Training Meadow", "Other"), Level
--   TrainingSession    minutes;            Ground, Level         -- hitting its mobs, no 20s+ gap
--   LevelReached       minutes played;     Level, Rebirth
--   RegionUnlocked     minutes played;     Region, Rebirth, Level
--   TrainingUnlocked   minutes played;     Ground, Rebirth, Level
--   WeaponBought       minutes played;     Weapon, Rebirth, Level
--   Rebirth            minutes played;     Rebirth, Level
--   GoalComplete       minutes on it;      Goal ("3. Unlock Desert"), Level
--
-- Sessions (QM, Nov 1: Roblox's own session numbers lag ~3 days). A session runs from
-- joining to leaving; the saved Sessions attribute counts them, so "Session 1" is a brand
-- new player's first visit. (Players from before Nov 1 with the tutorial done count as
-- "Session 4+".)
--   SessionStart       1;                  Session ("Session 1".."Session 3", "Session 4+"), Level
--   SessionLength      session minutes;    Session, Length ("3-5 min"), Tutorial ("In tutorial" / "Past tutorial")
--   SessionLeave       session minutes;    Goal, Progress, Session      -- every leave
--   Bounce             session minutes;    Goal, Progress, Length       -- a first session ending
--   QuickLeave         session minutes;    Goal, Progress, Session      -- under Config.Sessions.Short
--     Goal is the Goal panel goal they were on ("2. Steal 3 Meadow eggs"), or in the
--     tutorial its last step done ("Tutorial 6/7: Rode pet"); Progress is the bar ("1/3"
--     for small counts, else "50-75%"). "Not loaded" = left before their save came in.
--   How to read them (Custom Events, pick the event, value = average):
--     p1 / p2 / p3 avg  SessionLength split by Session (filter one to see it alone)
--     overall avg       SessionLength, no split
--     bounce rate       1 - (SessionStart "Session 2" count / SessionStart "Session 1" count),
--                       over the same days (give returners a day or two to come back)
--     where they bounce Bounce split by Goal, then Progress (also SessionLeave filtered
--                       to "Session 1"); QuickLeave the same for the very short ones
-- "Minutes played" is all-time play (the saved PlayTime attribute, from Nov 1 on), so with
-- Rebirth "Rebirth 0" picked, RegionUnlocked's average value is how long the gate takes.
--
-- Every AnalyticsService call is pcall'd, and so is every hook: a bug here only warns.
--
--   Stats.start(bosses)                 -- once, after Server/Bosses
--   Stats.earned(player, amount, sku)   -- cash paid in (Server/PetInventory, Bosses, ...)
--   Stats.trained(player, ground)       -- a training mob hit (Server/Training)

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local Stats = {}

local warned = {}
local function safe(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not warned[name] then
		warned[name] = true
		warn("Stats." .. name .. " failed: " .. tostring(err))
	end
end

-- (required inside a pcall: a broken shared module mustn't stop the server)
local Goals, Levels, Funnels
safe("require", function()
	Goals = require(Shared:WaitForChild("Goals"))
	Levels = require(Shared:WaitForChild("Levels"))
end)
safe("requireFunnels", function()
	Funnels = require(script.Parent:WaitForChild("Funnels"))
end)

local TICK = 5 -- seconds between play time / goal / training checks
local TRAIN_GAP = 20 -- seconds without a training hit that end a training session
local GOAL_FUNNEL = "Goals"

local function fields(a, b, c)
	local out = {}
	local keys = Enum.AnalyticsCustomFieldKeys
	if a then
		out[keys.CustomField01.Name] = tostring(a)
	end
	if b then
		out[keys.CustomField02.Name] = tostring(b)
	end
	if c then
		out[keys.CustomField03.Name] = tostring(c)
	end
	return out
end

local function event(player, name, value, a, b, c)
	safe(name, function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields(a, b, c))
	end)
end

local function round(x, step)
	return math.floor(x / step + 0.5) * step
end

local function minutesPlayed(player)
	return round((player:GetAttribute("PlayTime") or 0) / 60, 0.1)
end

local function levelText(player)
	return "Lv " .. tostring(player:GetAttribute("Level") or 1)
end

local function rebirthText(player)
	return "Rebirth " .. tostring(player:GetAttribute("Rebirths") or 0)
end

local function regionName(name)
	return Config.Regions.Names[name] or name
end

-- a goal's name for the funnel and GoalComplete: "3. Unlock Desert"
local function goalName(i, g)
	local name
	if g.Power then
		name = "Reach level " .. g.Power
	elseif g.Steal then
		local where = {}
		for _, r in g.In or {} do
			table.insert(where, regionName(r))
		end
		name = "Steal " .. g.Steal .. " " .. table.concat(where, "/") .. " eggs"
	elseif g.Region then
		local where = {}
		for _, r in g.Region do
			table.insert(where, regionName(r))
		end
		name = (if g.All then "Unlock all of " else "Unlock ") .. table.concat(where, "/")
	elseif g.Weapon then
		name = "Buy " .. g.Weapon .. " weapon"
	elseif g.Train then
		name = "Unlock " .. regionName(g.Train) .. " training"
	elseif g.Collect then
		name = "Collect Pets"
	else
		name = g.Title or "Goal"
	end
	return i .. ". " .. name
end

local function goalIndex(player)
	if not Goals then
		return nil
	end
	local now = Goals.current(player)
	return if now then now.index else #Config.Goals.List + 1
end

---------------------------------------------------------------------------------------
-- sessions: p1/p2/p3 lengths, bounces, and what they were on when they left

local joinedAt = {} -- [player] = os.clock() they joined
local sessionNo = {} -- [player] = "Session 2" once their save's in

local SESSIONS = Config.Sessions or {}
local SHORT = SESSIONS.Short or 3 -- minutes: a QuickLeave under this
local LENGTHS = SESSIONS.Lengths or { 1, 3, 5, 10, 20, 40 } -- the Length buckets' edges, minutes

local function sessionText(n)
	return if n >= 4 then "Session 4+" else "Session " .. n
end

local function lengthText(minutes)
	local lo = 0
	for _, edge in LENGTHS do
		if minutes < edge then
			return if lo == 0 then "<" .. edge .. " min" else lo .. "-" .. edge .. " min"
		end
		lo = edge
	end
	return lo .. "+ min"
end

-- the save's in: count this session (Server/Data saves Sessions)
local function countSession(player)
	local n = player:GetAttribute("Sessions")
	if type(n) ~= "number" then
		-- before Nov 1 nobody was counted: a done tutorial means they've been before
		n = if player:GetAttribute("TutorialDone") then 3 else 0
	end
	n += 1
	player:SetAttribute("Sessions", n)
	sessionNo[player] = sessionText(n)
	event(player, "SessionStart", 1, sessionNo[player], levelText(player))
end

local function progressText(have, need)
	have, need = tonumber(have) or 0, tonumber(need) or 0
	if need <= 0 then
		return "?"
	end
	if need <= 10 and have == math.floor(have) then
		return math.min(have, need) .. "/" .. need
	end
	local pct = math.clamp(have / need, 0, 0.9999) * 100
	local lo = math.floor(pct / 25) * 25
	return lo .. "-" .. (lo + 25) .. "%"
end

-- where they are: Goal, Progress
local function standing(player)
	if not sessionNo[player] then
		return "Not loaded", "-"
	end
	if player:GetAttribute("Tutorial") then
		local step = player:GetAttribute("TutorialStepAt") or 1
		local names = Funnels and Funnels.TUTORIAL or {}
		local total = math.max(#names, step)
		return string.format("Tutorial %d/%d: %s", step, total, names[step] or "?"), step .. "/" .. total
	end
	local now = Goals and Goals.current(player)
	if not now then
		return (if Goals then "All goals done" else "?"), "-"
	end
	return goalName(now.index, now.goal), progressText(now.have, now.need)
end

local function sessionEnd(player)
	local from = joinedAt[player]
	if not from then
		return
	end
	local minutes = round((os.clock() - from) / 60, 0.1)
	local which = sessionNo[player] or "Not loaded"
	local tutorial = if player:GetAttribute("Tutorial") then "In tutorial" else "Past tutorial"
	local goal, progress = standing(player)
	local length = lengthText(minutes)
	event(player, "SessionLength", minutes, which, length, tutorial)
	event(player, "SessionLeave", minutes, goal, progress, which)
	-- a first visit ending (or one that never got its save in: those are new players' too, mostly)
	if which == "Session 1" or (which == "Not loaded" and not player:GetAttribute("TutorialDone")) then
		event(player, "Bounce", minutes, goal, progress, length)
	end
	if minutes < SHORT then
		event(player, "QuickLeave", minutes, goal, progress, which)
	end
end

---------------------------------------------------------------------------------------
-- economy

-- sources are added up and sent once a minute (pen income pays every second)
local pending = {} -- [player] = { [sku] = { amount, kind } }

local function economy(player, flow, amount, sku, kind)
	if amount <= 0 then
		return
	end
	safe("economy", function()
		AnalyticsService:LogEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType[flow],
			"Cash",
			math.floor(amount),
			math.max(0, math.floor(player:GetAttribute("Cash") or 0)),
			Enum.AnalyticsEconomyTransactionType[kind].Name,
			sku
		)
	end)
end

local SOURCE_KIND = { OfflineCash = "TimedReward", CashPack = "IAP" }

function Stats.earned(player, amount, sku)
	safe("earned", function()
		amount = tonumber(amount) or 0
		if amount <= 0 or not player or player.Parent == nil then
			return
		end
		local mine = pending[player]
		if not mine then
			mine = {}
			pending[player] = mine
		end
		mine[sku] = (mine[sku] or 0) + amount
	end)
end

local function flushEarned(player)
	local mine = pending[player]
	pending[player] = nil
	for sku, amount in mine or {} do
		economy(player, "Source", amount, sku, SOURCE_KIND[sku] or "Gameplay")
	end
end

---------------------------------------------------------------------------------------
-- training: a session is hits on one ground's mobs with no TRAIN_GAP gap

local training = {} -- [player] = { ground, from, last }

local function endTraining(player)
	local t = training[player]
	training[player] = nil
	if t then
		event(player, "TrainingSession", round((t.last - t.from) / 60, 0.1), regionName(t.ground), levelText(player))
	end
end

function Stats.trained(player, ground)
	safe("trained", function()
		local now = os.clock()
		local t = training[player]
		if t and (t.ground ~= ground or now - t.last > TRAIN_GAP) then
			endTraining(player)
			t = nil
		end
		if not t then
			training[player] = { ground = ground, from = now, last = now }
		else
			t.last = now
		end
	end)
end

---------------------------------------------------------------------------------------
-- boss fights

local fights = {} -- [player] = { biome, body, kind, from, level, weapon, pet, won, attempted }
local fightDeath = {} -- [player] = os.clock() of their last death in a boss fight

local function introLength()
	local i = Config.BossIntro
	return (i.PanIn or 0) + (i.Hold or 0) + (i.PanOut or 0)
end

-- the boss of this biome's fight, once it's there
local function bossOf(biome)
	local folder = workspace:FindFirstChild("Bosses")
	for _, body in if folder then folder:GetChildren() else {} do
		if body:GetAttribute("Biome") == biome then
			return body
		end
	end
	return nil
end

local function findBoss(f)
	if f.body and f.body.Parent then
		return f.body
	end
	local body = bossOf(f.biome)
	if body then
		f.body = body
		local kind = body:GetAttribute("Kind") or "?"
		f.kind = if f.tutorial then kind .. " (tutorial)" else kind
		-- (the clock starts once its intro's over)
		if body:GetAttribute("Intro") then
			f.from = f.lockedAt + introLength()
		end
	end
	return body
end

local function groupText(n)
	return if n <= 1 then "Solo" else "Group of " .. n
end

local function inFight(biome)
	local n = 0
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("LockedIn") == biome then
			n += 1
		end
	end
	return n
end

-- (logged once the boss is there to name, or at the end if it's over sooner)
local function attempt(player, f)
	if not f.attempted then
		f.attempted = true
		findBoss(f)
		event(player, "BossAttempt", 1, f.kind, f.level, f.weapon)
	end
end

local function seconds(f)
	return round(math.max(0, os.clock() - f.from), 1)
end

local function startFight(player, biome)
	local now = os.clock()
	local f = {
		biome = biome,
		lockedAt = now,
		from = now,
		kind = biome .. " boss",
		level = levelText(player),
		weapon = player:GetAttribute("Weapon") or "None",
		pet = player:GetAttribute("Pet") or "On foot",
		tutorial = player:GetAttribute("Tutorial") == true,
	}
	fights[player] = f
	-- (the boss is summoned just after the lock: Server/Eggs)
	task.delay(0.5, function()
		safe("fightStart", function()
			if fights[player] == f then
				attempt(player, f)
			end
		end)
	end)
end

-- the fight's over for them without a win: dead, gone, or the boss rerolled
local function endFight(player, how)
	local f = fights[player]
	fights[player] = nil
	if not f or f.won then
		return
	end
	attempt(player, f)
	local body = findBoss(f)
	if how == "Death" then
		fightDeath[player] = os.clock()
		event(player, "PlayerDeath", 1, "Boss fight", f.level)
		local left = 0
		if body then
			local max = body:GetAttribute("MaxHealth") or 0
			left = if max > 0 then round(100 * (body:GetAttribute("Health") or 0) / max, 1) else 0
		end
		event(player, "BossDeath", seconds(f), f.kind, f.level, f.weapon)
		event(player, "BossDeathDetail", left, f.kind, f.pet, groupText(inFight(f.biome) + 1))
	elseif how == "Quit" then
		event(player, "BossQuit", seconds(f), f.kind, f.level, f.weapon)
	end
end

local function won(kind, winners)
	for _, player in winners do
		local f = fights[player]
		if f and not f.won then
			attempt(player, f)
			f.won = true
			if f.kind == f.biome .. " boss" then
				f.kind = if f.tutorial then kind .. " (tutorial)" else kind
			end
			event(player, "BossWin", seconds(f), f.kind, f.level, f.weapon)
			event(player, "BossWinDetail", seconds(f), f.kind, f.pet, groupText(#winners))
		end
	end
end

---------------------------------------------------------------------------------------
-- progress: play time, levels, regions, weapons, rebirths, goals

local session = {} -- [player] = { from, level, rebirths, weapons }

local function weaponSet(player)
	local out = {}
	-- ("Bow:2,Kendo": Shared/Stacks, the id before any count)
	for entry in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		local id = string.match(entry, "^%s*([^:%s]+)")
		if id then
			out[id] = true
		end
	end
	return out
end

local function checkGoals(player)
	if player:GetAttribute("Tutorial") then
		return -- (the Goal panel's hidden in the tutorial)
	end
	local now = goalIndex(player)
	if not now then
		return
	end
	local was = player:GetAttribute("GoalAt")
	local played = player:GetAttribute("PlayTime") or 0
	if was == nil then
		-- first time seen (or before this was added): their goals so far, timed from here
		for i = 1, math.min(now - 1, #Config.Goals.List) do
			safe("goalFunnel", function()
				AnalyticsService:LogFunnelStepEvent(player, GOAL_FUNNEL, tostring(player.UserId), i + 1, goalName(i, Config.Goals.List[i]))
			end)
		end
		player:SetAttribute("GoalAt", now)
		player:SetAttribute("GoalSince", played)
		return
	end
	if now <= was then
		return
	end
	local spent = round((played - (player:GetAttribute("GoalSince") or played)) / 60, 0.1)
	for i = was, math.min(now - 1, #Config.Goals.List) do
		local name = goalName(i, Config.Goals.List[i])
		event(player, "GoalComplete", if i == was then spent else 0, name, levelText(player))
		safe("goalFunnel", function()
			AnalyticsService:LogFunnelStepEvent(player, GOAL_FUNNEL, tostring(player.UserId), i + 1, name)
		end)
	end
	player:SetAttribute("GoalAt", now)
	player:SetAttribute("GoalSince", played)
end

local function watchProgress(player)
	local s = {
		from = os.clock(),
		level = player:GetAttribute("Level") or 1,
		rebirths = player:GetAttribute("Rebirths") or 0,
		weapons = weaponSet(player),
	}
	session[player] = s
	safe("countSession", countSession, player)
	player:SetAttribute("PlayTime", player:GetAttribute("PlayTime") or 0)
	safe("goalFunnel", function()
		AnalyticsService:LogFunnelStepEvent(player, GOAL_FUNNEL, tostring(player.UserId), 1, "Joined game")
	end)

	player:GetAttributeChangedSignal("Level"):Connect(function()
		safe("level", function()
			local level = player:GetAttribute("Level") or 1
			if level > s.level then
				for l = s.level + 1, level do
					event(player, "LevelReached", minutesPlayed(player), "Lv " .. l, rebirthText(player))
				end
			end
			s.level = level -- (a rebirth puts it back down)
		end)
	end)
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		safe("rebirth", function()
			local n = player:GetAttribute("Rebirths") or 0
			if n > s.rebirths then
				event(player, "Rebirth", minutesPlayed(player), "Rebirth " .. n, levelText(player))
				local r = Config.Rebirth
				economy(player, "Sink", math.floor(r.Cost * r.Growth ^ (n - 1)), "Rebirth", "Gameplay")
			end
			s.rebirths = n
		end)
	end)
	player:GetAttributeChangedSignal("Weapons"):Connect(function()
		safe("weapons", function()
			local now = weaponSet(player)
			for id in now do
				if not s.weapons[id] then
					event(player, "WeaponBought", minutesPlayed(player), id, rebirthText(player), levelText(player))
					local w = Config.Weapons[id]
					economy(player, "Sink", w and w.Price or 0, "Weapon " .. id, "Shop")
				end
			end
			s.weapons = now
		end)
	end)
	for name, cost in Config.Regions.Cost do
		player:GetAttributeChangedSignal("Region" .. name):Connect(function()
			if player:GetAttribute("Region" .. name) == true then
				event(player, "RegionUnlocked", minutesPlayed(player), regionName(name), rebirthText(player), levelText(player))
				economy(player, "Sink", cost, "Region " .. regionName(name), "Gameplay")
			end
		end)
	end
	for name, g in Config.Training.Grounds do
		if g.Cost > 0 then
			player:GetAttributeChangedSignal("Train" .. name):Connect(function()
				if player:GetAttribute("Train" .. name) == true then
					event(player, "TrainingUnlocked", minutesPlayed(player), regionName(name), rebirthText(player), levelText(player))
					economy(player, "Sink", g.Cost, "Training " .. regionName(name), "Gameplay")
				end
			end)
		end
	end
	checkGoals(player)
end

---------------------------------------------------------------------------------------

local function joined(player)
	joinedAt[player] = joinedAt[player] or os.clock()
	-- boss fights: LockedIn is the biome of the fight they're in (Server/Eggs)
	player:GetAttributeChangedSignal("LockedIn"):Connect(function()
		safe("lockedIn", function()
			local biome = player:GetAttribute("LockedIn")
			local f = fights[player]
			if f and f.biome ~= biome then
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local dead = not humanoid or humanoid.Health <= 0
				endFight(player, if dead then "Death" else "Over")
			end
			if biome and not fights[player] then
				startFight(player, biome)
			end
		end)
	end)
	-- deaths, and where
	local function character(char)
		local humanoid = char:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
			safe("died", function()
				-- (a death in a boss fight is logged as its fight ends: endFight)
				if player:GetAttribute("LockedIn") or fights[player] or os.clock() - (fightDeath[player] or -10) < 2 then
					return
				end
				local where = "Other"
				local t = training[player]
				if t and os.clock() - t.last < 8 then
					where = "Training " .. regionName(t.ground)
				end
				event(player, "PlayerDeath", 1, where, levelText(player))
			end)
		end)
	end
	player.CharacterAdded:Connect(function(char)
		safe("character", character, char)
	end)
	if player.Character then
		task.spawn(safe, "character", character, player.Character)
	end
	-- progress, once their save's in (Server/Data sets Loaded)
	task.spawn(function()
		local t = os.clock()
		while player.Parent and not player:GetAttribute("Loaded") and os.clock() - t < 60 do
			task.wait(1)
		end
		if player.Parent and player:GetAttribute("Loaded") then
			safe("watchProgress", watchProgress, player)
		end
	end)
end

local function left(player)
	safe("left", function()
		endFight(player, "Quit")
		endTraining(player)
		flushEarned(player)
	end)
	safe("sessionEnd", sessionEnd, player)
	fights[player], training[player], session[player], pending[player], fightDeath[player] = nil, nil, nil, nil, nil
	joinedAt[player], sessionNo[player] = nil, nil
end

function Stats.start(bosses)
	bosses.killed.Event:Connect(function(kind, winners)
		safe("won", won, kind, winners)
	end)
	Players.PlayerAdded:Connect(function(player)
		joinedAt[player] = os.clock() -- (straight away: joined's hooks come after)
		joined(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(joined, player)
	end
	Players.PlayerRemoving:Connect(left)

	-- play time, goals, training sessions run out, cash earned sent on
	task.spawn(function()
		local sinceFlush = 0
		while true do
			task.wait(TICK)
			sinceFlush += TICK
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if session[player] then
					safe("tick", function()
						player:SetAttribute("PlayTime", (player:GetAttribute("PlayTime") or 0) + TICK)
						checkGoals(player)
					end)
				end
				local t = training[player]
				if t and now - t.last > TRAIN_GAP then
					safe("trainingEnd", endTraining, player)
				end
				if sinceFlush >= 60 then
					safe("flush", flushEarned, player)
				end
			end
			if sinceFlush >= 60 then
				sinceFlush = 0
			end
		end
	end)
end

return Stats
