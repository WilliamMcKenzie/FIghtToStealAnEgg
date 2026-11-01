-- Analytics funnels (QM, Oct 31), seen in Creator Hub > the experience > Analytics >
-- Funnels. Every funnel's first step is "Joined game" (QM). Logged here, on the server,
-- through Roblox's AnalyticsService, each step once per player.
--
-- Tutorial (Roblox's onboarding funnel: once per player, for good):
--    1 Joined game        a brand new account starts the tutorial (Server/Tutorial.begin)
--    2 Placed egg         the starting Horse egg down in the pen
--    3 Hatched egg
--    4 Rode pet
--    5 Stole egg          locked in with the Meadow boss
--    6 Beat boss
--    7 Placed boss egg    the egg they stole, down in the pen
--    8 Hatched boss egg
--    9 Bought bow
--   10 Tutorial complete
-- (Steps 2-10 are only counted while the tutorial's on; a step skipped, say by
-- /skiptutorial, is just missing.)
--
-- Biome progress (a funnel named "BiomeProgress", one session per player, by UserId):
--    1 Joined game        every join (counted once)
--    2 Desert             each gate bought (Server/Regions); the Meadow's free
--    3 Tundra
--    4 Lava Valley
--    5 Dungeon / Magic Circle      the first region past the fork, either side
--    6 Red Castle / Ocean Trench   the first region at the end of either side
--
--   Funnels.start(bosses)              -- once, after Server/Bosses
--   Funnels.tutorialJoined(player)     -- a new account's tutorial begins
--   Funnels.regionBought(player, name) -- a region gate bought
--   Funnels.TUTORIAL                   -- the tutorial's step names (player attribute
--                                         TutorialStepAt = the last one done, unsaved)

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Funnels = {}

local TUTORIAL = {
	"Joined game",
	"Placed egg",
	"Hatched egg",
	"Rode pet",
	"Stole egg",
	"Beat boss",
	"Placed boss egg",
	"Hatched boss egg",
	"Bought bow",
	"Tutorial complete",
}
Funnels.TUTORIAL = TUTORIAL
local BIOME_FUNNEL = "BiomeProgress"
local BIOMES = { -- [region] = { step, name }
	Desert = { 2, "Desert" },
	Ice = { 3, "Tundra" },
	Lava = { 4, "Lava Valley" },
	Dungeon = { 5, "Dungeon / Magic Circle" },
	Forest = { 5, "Dungeon / Magic Circle" },
	Castle = { 6, "Red Castle / Ocean Trench" },
	Ocean = { 6, "Red Castle / Ocean Trench" },
}

local logged = {} -- [player] = { [step] = true } (the tutorial's, this server)

local function tutorialStep(player, step)
	local mine = logged[player]
	if not mine then
		mine = {}
		logged[player] = mine
	end
	if mine[step] then
		return
	end
	mine[step] = true
	-- (Server/Stats names where a player in the tutorial left: "Tutorial 3/10: Hatched egg")
	pcall(player.SetAttribute, player, "TutorialStepAt", step)
	pcall(AnalyticsService.LogOnboardingFunnelStepEvent, AnalyticsService, player, step, TUTORIAL[step])
end

local function biomeStep(player, step, name)
	pcall(AnalyticsService.LogFunnelStepEvent, AnalyticsService, player, BIOME_FUNNEL, tostring(player.UserId), step, name)
end

function Funnels.tutorialJoined(player)
	logged[player] = {}
	tutorialStep(player, 1)
end

function Funnels.regionBought(player, name)
	local b = BIOMES[name]
	if b then
		biomeStep(player, b[1], b[2])
	end
end

local function done(player, step)
	return logged[player] ~= nil and logged[player][step] == true
end

local function watch(player)
	biomeStep(player, 1, "Joined game")

	local function inTutorial()
		return player:GetAttribute("Tutorial") == true
	end
	local function eggCount()
		local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PenEggs") or "[]")
		return if ok and type(list) == "table" then #list else 0
	end
	local eggs = eggCount()
	player:GetAttributeChangedSignal("PenEggs"):Connect(function()
		local now = eggCount()
		if inTutorial() then
			if now > eggs then
				tutorialStep(player, if done(player, 6) then 7 else 2)
			elseif now < eggs then
				tutorialStep(player, if done(player, 6) then 8 else 3)
			end
		end
		eggs = now
	end)
	player:GetAttributeChangedSignal("OnFoot"):Connect(function()
		if inTutorial() and not player:GetAttribute("OnFoot") then
			tutorialStep(player, 4)
		end
	end)
	player:GetAttributeChangedSignal("LockedIn"):Connect(function()
		if inTutorial() and player:GetAttribute("LockedIn") then
			tutorialStep(player, 5)
		end
	end)
	player:GetAttributeChangedSignal("Weapons"):Connect(function()
		if inTutorial() then
			for owned in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
				if owned:match("^[^:]+") == Config.Tutorial.Weapon then
					tutorialStep(player, 9)
				end
			end
		end
	end)
	player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		if player:GetAttribute("TutorialDone") and done(player, 1) then
			tutorialStep(player, 10)
		end
	end)
end

function Funnels.start(bosses)
	bosses.killed.Event:Connect(function(_, winners)
		for _, player in winners do
			if player:GetAttribute("Tutorial") then
				tutorialStep(player, 6)
			end
		end
	end)
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		logged[player] = nil
	end)
end

return Funnels
