-- The new player tutorial, server side (QM, Oct 31; the steps are client/Tutorial's). A
-- player is in it while their Tutorial attribute is on: Server/Data turns it on for a
-- brand new account (no save at all) and TutorialDone (saved) keeps it off for good.
-- While it's on:
--   their egg     Config.Tutorial.Egg in their bag and in hand (EggBag, Holding), given
--                 again each life till it's placed (Hatchery sets TutorialPlaced)
--   hatching      Config.Tutorial.HatchTime (Server/Hatchery)
--   the boss      always Config.Tutorial.Boss (Server/Eggs), hits on them x
--                 Config.Tutorial.Damage (Server/Lives), and it pays at least
--                 Config.Tutorial.BossCash (Server/Bosses)
--   training      Config.Tutorial.Ground's ground is free (Server/Regions); their first hit
--                 on a mob there ends it (Server/Training calls Tutorial.hit)
-- TutorialEggs (client asks, at "Steal an egg!"): the Meadow's nests fill now if they're
-- empty with no fight on, so a new player never waits out a cooldown.
--
--   Tutorial.start()            -- once, after Hatchery.start and Eggs.start
--   Tutorial.begin(player)      -- (re)starts it (a new account; /tutorial)
--   Tutorial.finish(player)     -- it's over, for good (/skiptutorial too)
--   Tutorial.hit(player, ground) -- a hit on a training mob

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Tutorial = {}

local T = Config.Tutorial

-- the starting egg in hand, unless it's already down in the pen
local function giveEgg(player)
	if not player:GetAttribute("Tutorial") or player:GetAttribute("TutorialPlaced") then
		return
	end
	if not player:GetAttribute("EggBag") then
		player:SetAttribute("EggBag", T.Egg)
	end
	player:SetAttribute("Holding", T.Egg)
end

function Tutorial.begin(player)
	player:SetAttribute("TutorialPlaced", nil)
	player:SetAttribute("Tutorial", nil) -- (off then on: one already running starts over)
	player:SetAttribute("Tutorial", true)
	giveEgg(player)
end

function Tutorial.finish(player)
	if player:GetAttribute("Tutorial") then
		player:SetAttribute("Tutorial", nil)
	end
	player:SetAttribute("TutorialPlaced", nil)
	player:SetAttribute("TutorialDone", true) -- (Server/Data saves it straight away)
end

function Tutorial.hit(player, ground)
	if player:GetAttribute("Tutorial") and ground == T.Ground then
		Tutorial.finish(player)
	end
end

function Tutorial.start(eggs)
	local function joined(player)
		player.CharacterAdded:Connect(function()
			task.defer(giveEgg, player) -- (after Hatchery empties the bag for the new life)
		end)
		player:GetAttributeChangedSignal("Tutorial"):Connect(function()
			giveEgg(player)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "TutorialEggs"
	remote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player)
		if player:GetAttribute("Tutorial") then
			eggs.ensure("Meadow")
		end
	end)
end

return Tutorial
