-- The new player tutorial, server side (QM, Oct 31; the steps are client/Tutorial's). A
-- player is in it while their Tutorial attribute is on: Server/Data turns it on for a
-- brand new account (no save at all) and TutorialDone (saved) keeps it off for good.
-- (QM, Nov 2: no more starting egg or "Buy a bow!". A new player starts on their Horse
-- holding a Shortbow, steals an egg, beats its boss, then puts that egg down, hatches it
-- and rides what comes out.) While it's on:
--   the bow       a new account starts with Config.Tutorial.Weapon owned and equipped (the
--                 Kendo Stick's still theirs, free in Carl's shop, to switch back to)
--   their eggs    every egg they steal is a Config.Tutorial.Egg (Server/Eggs; client/EggView
--                 shows them every nest's egg as one), so their first pet is always that
--   hatching      Config.Tutorial.HatchTime (Server/Hatchery)
--   the boss      always Config.Tutorial.Boss (Server/Eggs), hits on them x
--                 Config.Tutorial.Damage (Server/Lives), and it pays at least
--                 Config.Tutorial.BossCash (Server/Bosses)
--   the end       the client says TutorialDone once it's shown the training grounds (a
--                 first hit on a Meadow training mob ends it too: Server/Training calls
--                 Tutorial.hit)
-- TutorialEggs (client asks, at "Steal an egg!"): the Meadow's nests fill now if they're
-- empty with no fight on, so a new player never waits out a cooldown.
--
--   Tutorial.start()            -- once, after Hatchery.start and Eggs.start
--   Tutorial.begin(player, fresh) -- (re)starts it; fresh: a new account (back to just the
--                                  -- starter Horse, and the bow), else /tutorial (pets and
--                                  -- weapons kept)
--   Tutorial.finish(player)     -- it's over, for good (/skiptutorial too)
--   Tutorial.hit(player, ground) -- a hit on a training mob

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stacks = require(Shared.Stacks)
local Funnels = require(script.Parent.Funnels)

local Tutorial = {}

local T = Config.Tutorial

function Tutorial.begin(player, fresh)
	player:SetAttribute("OnFoot", nil) -- (an old run's)
	if fresh then
		Funnels.tutorialJoined(player) -- (the tutorial funnel's "Joined game")
		player:SetAttribute("PetsOwned", "")
		player:SetAttribute("PenPets", "")
		-- (owning nothing, they're given the starter to ride: Server/PetInventory)
		player:SetAttribute("Pet", nil)
		player:SetAttribute("Pet", Config.Backpack.Starter)
		-- the bow, in hand (QM, Nov 2: no buying it in the tutorial any more)
		local owned = Stacks.parse(player:GetAttribute("Weapons") or Config.Arsenal.Start)
		if Stacks.count(owned, T.Weapon) == 0 then
			player:SetAttribute("Weapons", Stacks.format(Stacks.add(owned, T.Weapon, 1)))
		end
		player:SetAttribute("Weapon", T.Weapon)
	end
	player:SetAttribute("Tutorial", nil) -- (off then on: one already running starts over)
	player:SetAttribute("Tutorial", true)
end

function Tutorial.finish(player)
	if player:GetAttribute("Tutorial") then
		player:SetAttribute("Tutorial", nil)
	end
	player:SetAttribute("TutorialDone", true) -- (Server/Data saves it straight away)
end

function Tutorial.hit(player, ground)
	if player:GetAttribute("Tutorial") and ground == T.Ground then
		Tutorial.finish(player)
	end
end

function Tutorial.start(eggs)
	local done = Instance.new("RemoteEvent")
	done.Name = "TutorialDone"
	done.Parent = ReplicatedStorage
	done.OnServerEvent:Connect(function(player)
		if player:GetAttribute("Tutorial") then
			Tutorial.finish(player)
		end
	end)

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
