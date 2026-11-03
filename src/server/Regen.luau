-- Healing (QM, Oct 30: a constant thing, set by your pet): every living player heals their
-- pet's Regen (health a second: Shared/Pets, Config.PetStats.Regen) all the time, in a
-- fight or not, up to full. A sprint ability can speed it up (the player's SprintAbility
-- attribute: Config.SprintAbility[it].Regen, the Snake's 2x; RegenAdd adds a flat amount). Roblox's default Health
-- script (its slow regen) is removed from every character.
--
--   Regen.start()   -- once

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Alive = require(Shared:WaitForChild("Alive")) -- (knocked down on the death screen: no healing)

local Regen = {}

local function strip(character)
	local default = character:WaitForChild("Health", 5)
	if default and default:IsA("BaseScript") then
		default:Destroy()
	end
end

function Regen.start()
	local function joined(player)
		player.CharacterAdded:Connect(strip)
		if player.Character then
			task.spawn(strip, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if Alive(humanoid) and humanoid.Health < humanoid.MaxHealth then
				local kind = player:GetAttribute("Pet") or "Horse"
				local rate = Pets.stats(kind).Regen
				local ability = Config.SprintAbility[player:GetAttribute("SprintAbility") or ""]
				rate *= ability and ability.Regen or 1
				rate += ability and ability.RegenAdd or 0 -- (a flat bonus: Burrow, Grow)
				rate = ability and ability.RegenSet or rate -- (set outright: Giant)
				local set = Config.Pets[kind] and Config.Pets[kind].Stats
				rate *= ability and set and set.SprintRegen or 1 -- (the pet's own: the Phoenix's 2x)
				rate *= Pets.rage(player) -- (the Living Armor: faster the lower it is)
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + rate * dt)
			end
		end
	end)
end

return Regen
