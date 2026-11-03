-- Dying (QM, Nov 2: "like LassoAPet, where you just fall on the floor", then back to base;
-- Nov 3: with LassoAPet's crash screen, Continue or a Robux Revive).
--
-- Roblox breaks a character's joints when it dies, and every part but the
-- HumanoidRootPart is in the RiderBody collision group (Server/init: it collides with
-- nothing), so the loose body dropped straight through the floor. Now the joints stay
-- (BreakJointsOnDeath off) and the HumanoidRootPart is anchored where it died, so nothing
-- of it can fall anywhere. Every client then tips the rider and their pet over onto their
-- side together (client/Riding: the character's FallSide attribute, 1 right or -1 left).
--
-- Knocked down (Config.Death.Revive): a hit that would kill you (Server/Lives.hurt) doesn't.
-- You're left a hair above 0 HP with the character's Downed attribute set, frozen and
-- tipped over just like dying (Shared/Alive: nothing targets, hits or heals you, you don't
-- attack), and the death screen asks (client/DeathScreen, the Death remote):
--   "Continue"  you die for real (the egg you stole and your fight go, as any death) and
--               ContinueRespawn seconds later you're back in front of your pen (Server/Pens'
--               spawnAtPen). Also what happens after Decide seconds of nothing.
--   "Revive"    the Revive developer product's prompt; paid, you're up again right where you
--               fell at full HP, still holding your egg and in your fight, with Shield seconds
--               of a force field. (In Studio, till it has an id, it's free.)
-- The tutorial (and anything that kills without Lives.hurt) dies at once, as before:
-- Respawn seconds and you're back at your pen.
--
--   Death.start()                       -- once
--   Death.down(player, humanoid) -> ok  -- Server/Lives: knock them down instead of killing
--   Death (RemoteEvent)  client -> server "Continue" / "Revive"

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Store = require(script.Parent.Store)

local Death = {}

local REVIVE = Config.Death.Revive
local DOWN_HP = 0.01 -- (a hair above 0: Roblox's death can't be undone, so we never let it happen)

local rng = Random.new()
local downed = {} -- [player] = { character, humanoid, since, buying }

local function freeze(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	end
	if not character:GetAttribute("FallSide") then -- (knocked down first: it stays on that side)
		character:SetAttribute("FallSide", if rng:NextNumber() < 0.5 then -1 else 1)
	end
end

local function spawned(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		character:SetAttribute("Downed", nil)
		freeze(character)
	end)
end

-- can Revive be offered (and bought) at all?
local function canRevive()
	return REVIVE.On and (REVIVE.Product ~= nil or RunService:IsStudio())
end

function Death.down(player, humanoid)
	local character = humanoid.Parent
	if not (REVIVE.On and player and character and player.Character == character) then
		return false
	end
	if player:GetAttribute("Tutorial") or downed[player] then
		return downed[player] ~= nil
	end
	local d = { character = character, humanoid = humanoid, since = os.clock(), buying = false }
	downed[player] = d
	humanoid.Health = DOWN_HP
	character:SetAttribute("Downed", true)
	freeze(character)
	-- (the screen: Revive shown only when it can be bought)
	player:SetAttribute("CanRevive", canRevive())
	return true
end

-- Continue (or Decide ran out): dead for real, then home
local function goHome(player)
	local d = downed[player]
	if not d then
		return
	end
	downed[player] = nil
	local character, humanoid = d.character, d.humanoid
	if humanoid.Parent then
		humanoid.Health = 0 -- (Died: the egg, the fight, the stats all go as any death)
	end
	task.delay(REVIVE.ContinueRespawn, function()
		if player.Parent and player.Character == character then
			player:LoadCharacter()
		end
	end)
end

-- Revive: up where you fell, full HP, a moment of shield
local function revive(player)
	local d = downed[player]
	if not d then
		return false
	end
	downed[player] = nil
	local character, humanoid = d.character, d.humanoid
	if not humanoid.Parent or humanoid.Health <= 0 then
		return false
	end
	character:SetAttribute("Downed", nil)
	character:SetAttribute("FallSide", nil)
	humanoid.Health = humanoid.MaxHealth
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	local shield = Instance.new("ForceField")
	shield.Visible = false
	shield.Parent = character
	task.delay(REVIVE.Shield, function()
		shield:Destroy()
	end)
	player:SetAttribute("Revived", workspace:GetServerTimeNow()) -- (the client's screen closes)
	return true
end

local function asked(player, what)
	local d = downed[player]
	if not d then
		return
	end
	if what == "Continue" then
		if not d.buying then
			goHome(player)
		end
	elseif what == "Revive" then
		if REVIVE.Product then
			d.buying = true
			MarketplaceService:PromptProductPurchase(player, REVIVE.Product)
		elseif RunService:IsStudio() then
			revive(player)
		end
	end
end

function Death.start()
	Players.RespawnTime = Config.Death.Respawn

	local remote = Instance.new("RemoteEvent")
	remote.Name = "Death"
	remote.OnServerEvent:Connect(asked)
	remote.Parent = ReplicatedStorage

	-- paid: revived (a receipt after you'd already gone home just heals you)
	Store.product(REVIVE.Product, function(player)
		if not revive(player) then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = humanoid.MaxHealth
			end
		end
		return true
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id, bought)
		local player = Players:GetPlayerByUserId(userId)
		local d = player and downed[player]
		if d and id == REVIVE.Product and not bought then
			d.buying = false
			d.since = os.clock() -- (a fresh Decide after saying no to the prompt)
		end
	end)

	local function joined(player)
		player.CharacterAdded:Connect(function(character)
			downed[player] = nil
			spawned(character)
		end)
		if player.Character then
			task.spawn(spawned, player.Character)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		downed[player] = nil
	end)

	-- nobody chose in time: Continue
	RunService.Heartbeat:Connect(function()
		for player, d in downed do
			if not d.humanoid.Parent or d.humanoid.Health <= 0 then
				downed[player] = nil
			elseif not d.buying and os.clock() - d.since > REVIVE.Decide then
				goHome(player)
			end
		end
	end)
end

return Death
