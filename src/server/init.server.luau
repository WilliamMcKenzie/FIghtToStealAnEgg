-- Gives every player the sword, relays slashes so other players see them (and lets
-- them hurt bosses), and spawns a boss on /boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local SlashTuning = require(Shared.SlashTuning)
local Sword = require(Shared.Weapons.Sword)
local WorldColors = require(Shared.WorldColors)
local Bosses = require(script.Bosses)

SlashTuning.create() -- workspace.SlashTuning: live slash values to edit during Play
WorldColors.create() -- workspace.WorldColors: live world colours

local remote = Instance.new("RemoteEvent")
remote.Name = "Slash"
remote.Parent = ReplicatedStorage

-- StarterPack hands a copy to each character as it spawns; players already in the
-- game (a Studio playtest can start before this runs) get one now.
local tool = Sword.makeTool()
tool.Parent = StarterPack
for _, player in Players:GetPlayers() do
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild(tool.Name) then
		tool:Clone().Parent = backpack
	end
end

-- Everyone rides (client/Riding.luau): horse speed, and no jumping
local function ride(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = Config.RideSpeed
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
end
local requestBoss -- (below)
local function joined(player)
	-- the HUD's counters (client/Hud.luau): no stats system yet, so Power is the sword's
	-- damage and Cash starts at 0
	player:SetAttribute("Power", Config.Slash.Damage)
	player:SetAttribute("Cash", 0)
	player.CharacterAdded:Connect(ride)
	-- (/boss typed in chat also works when the place uses the legacy chat)
	player.Chatted:Connect(function(message)
		if message:lower():match("^/boss") then
			requestBoss(player)
		end
	end)
	if player.Character then
		task.spawn(ride, player.Character)
	end
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do
	joined(player)
end

local last = {}
remote.OnServerEvent:Connect(function(player, dir, seed, yaw)
	if (dir ~= 1 and dir ~= -1) or typeof(seed) ~= "number" or seed ~= seed then
		return
	end
	if typeof(yaw) ~= "number" or yaw ~= yaw or math.abs(yaw) > 10 then
		return
	end
	local now = os.clock()
	if last[player] and now - last[player] < Config.Slash.Cooldown * 0.8 then
		return
	end
	last[player] = now
	for _, other in Players:GetPlayers() do
		if other ~= player then
			remote:FireClient(other, player, dir, seed, yaw)
		end
	end
	-- the hit lands as the arc sweeps through (wind-up, then half the sweep)
	local c = Config.Slash
	task.delay(c.Windup + c.Sweep * 0.5, Bosses.slash, player, yaw, c)
end)

-- /boss: a chicken boss in front of you. The command is a TextChatCommand; its client
-- side asks through BossRequest (Triggered fires where the command is run), and the
-- server's own Triggered is a fallback. Once a second per player either way.
local bossRequest = Instance.new("RemoteEvent")
bossRequest.Name = "BossRequest"
bossRequest.Parent = ReplicatedStorage
local lastBoss = {}
function requestBoss(player)
	local now = os.clock()
	if lastBoss[player] and now - lastBoss[player] < 1 then
		return
	end
	lastBoss[player] = now
	Bosses.spawn("Chicken", player)
end
bossRequest.OnServerEvent:Connect(requestBoss)
local command = Instance.new("TextChatCommand")
command.Name = "BossCommand"
command.TriggerText = "/boss"
command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
command.Triggered:Connect(function(source)
	local player = source and Players:GetPlayerByUserId(source.UserId)
	if player then
		requestBoss(player)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
	lastBoss[player] = nil
end)
