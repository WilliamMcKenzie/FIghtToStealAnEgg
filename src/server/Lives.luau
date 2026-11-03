-- The Extra Life game pass (QM, Oct 30; Config.Shop.Passes): a hit that would kill you
-- brings you back at full HP instead, once a life (and once a fight: it's ready again
-- when the fight ends), with Config.Shop.LifeShield seconds of a force field after.
-- Every hit a player takes goes through Lives.hurt (Server/BossAttacks). A hit that would
-- still kill you knocks you down onto the death screen instead (Server/Death.down), and
-- nothing hurts you while you're down.
--
--   Lives.hurt(humanoid, damage)
--   Lives.start()  -- once
--
-- The humanoid's LifeUsed attribute is set while it's spent; LifeSaved (on the player, the
-- server time) when it saves you, for the client to show.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Passes = require(Shared.Passes)
local Death = require(script.Parent.Death)

local Lives = {}

function Lives.hurt(humanoid, damage)
	if humanoid.Parent and humanoid.Parent:GetAttribute("Downed") then
		return -- (lying on the death screen: Server/Death)
	end
	local player = Players:GetPlayerFromCharacter(humanoid.Parent)
	if player and player:GetAttribute("Tutorial") then
		damage *= Config.Tutorial.Damage -- (the tutorial's boss barely scratches you: QM, Oct 31)
	end
	if
		player
		and humanoid.Health > 0
		and humanoid.Health - damage <= 0
		and Passes.has(player, "Life")
		and not humanoid:GetAttribute("LifeUsed")
		and not humanoid.Parent:FindFirstChildOfClass("ForceField")
	then
		humanoid:SetAttribute("LifeUsed", true)
		humanoid.Health = humanoid.MaxHealth
		local shield = Instance.new("ForceField")
		shield.Parent = humanoid.Parent
		task.delay(Config.Shop.LifeShield, function()
			shield:Destroy()
		end)
		player:SetAttribute("LifeSaved", workspace:GetServerTimeNow())
		return
	end
	if
		player
		and humanoid.Health > 0
		and humanoid.Health - damage <= 0
		and not humanoid.Parent:FindFirstChildOfClass("ForceField")
		and Death.down(player, humanoid)
	then
		return
	end
	humanoid:TakeDamage(damage)
end

function Lives.start()
	local function joined(player)
		-- (the fight's over: it's ready for the next one)
		player:GetAttributeChangedSignal("LockedIn"):Connect(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and not player:GetAttribute("LockedIn") then
				humanoid:SetAttribute("LifeUsed", nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Lives
