-- Dying (QM, Nov 2: "like LassoAPet, where you just fall on the floor", then back to base).
--
-- Roblox breaks a character's joints when it dies, and every part but the
-- HumanoidRootPart is in the RiderBody collision group (Server/init: it collides with
-- nothing), so the loose body dropped straight through the floor. Now the joints stay
-- (BreakJointsOnDeath off) and the HumanoidRootPart is anchored where it died, so nothing
-- of it can fall anywhere. Every client then tips the rider and their pet over onto their
-- side together (client/Riding: the character's FallSide attribute, 1 right or -1 left),
-- and Config.Death.Respawn seconds after dying you're back in front of your pen (the
-- respawn: Server/Pens' spawnAtPen).
--
--   Death.start()  -- once

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Death = {}

local rng = Random.new()

local function spawned(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = true
		end
		character:SetAttribute("FallSide", if rng:NextNumber() < 0.5 then -1 else 1)
	end)
end

function Death.start()
	Players.RespawnTime = Config.Death.Respawn
	local function joined(player)
		player.CharacterAdded:Connect(spawned)
		if player.Character then
			task.spawn(spawned, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Death
