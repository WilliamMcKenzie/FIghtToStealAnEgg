-- Healing out of a fight (QM, Oct 26): after Config.Regen.Delay seconds without taking
-- damage, a player heals Config.Regen.Rate of their max health a second until full. Any
-- damage (bosses, mobs, anything that lowers Health) restarts the wait. Roblox's default
-- Health script (its slow regen) is removed from every character.
--
--   Regen.start()   -- once

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Regen = {}

local tracked = {} -- humanoid -> { hurt = damage taken so far, hitAt = os.clock() of the last hit }

local function track(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local default = character:WaitForChild("Health", 5)
	if default and default:IsA("BaseScript") then
		default:Destroy()
	end
	local t = { hurt = humanoid.MaxHealth - humanoid.Health, hitAt = os.clock() }
	tracked[humanoid] = t
	-- damage is what's missing from full going up (so a pet swap, which keeps your damage
	-- while MaxHealth changes, isn't a hit)
	humanoid.HealthChanged:Connect(function()
		local hurt = humanoid.MaxHealth - humanoid.Health
		if hurt > t.hurt + 1e-3 then
			t.hitAt = os.clock()
		end
		t.hurt = hurt
	end)
	humanoid.Destroying:Connect(function()
		tracked[humanoid] = nil
	end)
	humanoid.Died:Connect(function()
		tracked[humanoid] = nil
	end)
end

function Regen.start()
	local function joined(player)
		player.CharacterAdded:Connect(track)
		if player.Character then
			task.spawn(track, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for humanoid, t in tracked do
			local max = humanoid.MaxHealth
			if humanoid.Health > 0 and humanoid.Health < max and now - t.hitAt >= Config.Regen.Delay then
				humanoid.Health = math.min(max, humanoid.Health + max * Config.Regen.Rate * dt)
				t.hurt = max - humanoid.Health
			end
		end
	end)
end

return Regen
