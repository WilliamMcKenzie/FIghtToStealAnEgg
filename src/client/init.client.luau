-- Your weapon (the sword to start; bosses drop more: client/WeaponSpin): it's always
-- out, and it attacks by itself (QM, Oct 24, Archero-style). Melee weapons slash as
-- below; Ranged and Magic ones shoot at the nearest target in their Range (client/Shots
-- draws the shots, the server runs them for the damage).
-- While a boss (or a training mob or dummy) is within AimRange the torso turns toward it, eased (not snapped), and
-- whenever one is within AttackRange and the cooldown allows, it slashes along that aim:
-- the upper body swings the held sword (SwingPose) along the arc (SlashFx). It plays
-- here at once and is relayed through the server, which also deals the damage.
-- Press T to toggle a top-down camera (the angle the slash is made for).

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Power = require(Shared.Power)
local SlashFx = require(Shared.SlashFx)
local SlashTuning = require(Shared.SlashTuning)
local WorldColors = require(Shared.WorldColors)
local Weapons = require(Shared.Weapons.Weapons)
local Riding = require(script.Riding)
local Shots = require(script.Shots)
local SlashCam = require(script.SlashCam)
local SwingPose = require(script.SwingPose)
require(script.BossView)
require(script.EggView)
require(script.PlayerBars)
require(script.Hud)
require(script.Barriers)
require(script.FightBarrierFx)
require(script.Regions)
require(script.Liquid)
require(script.WeaponSpin)
require(script.WeaponTuning)
require(script.PoseTuning)
local remote = ReplicatedStorage:WaitForChild("Slash")
local shootRemote = ReplicatedStorage:WaitForChild("Shoot")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Config.Slash, with workspace.SlashTuning's live values applied (see SlashTuning), and
-- the tool's weapon's own Slash values over them
local function settings(tool)
	local c = SlashTuning.read()
	local id = tool and tool:GetAttribute("Weapon")
	return if id then Weapons.slash(c, id) else c
end
SlashTuning.watchPrint()
task.spawn(WorldColors.watch)

-- the slash's centre on its plane, facing world yaw `yaw` (or where the character faces)
local function slashFrame(character, c, yaw)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return nil
	end
	-- (the plane is set from the rider's hips, which Riding lifts into the saddle)
	local hips = Riding.hips(character)
	local ground = if hips then hips.Y else root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local look = if yaw then CFrame.Angles(0, yaw, 0).LookVector else root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local function follow()
		return Vector3.new(root.Position.X, ground + c.Height, root.Position.Z) + look * c.Forward
	end
	local pos = follow()
	return CFrame.lookAt(pos, pos + look), follow
end

-- one of Config.Slash.Sounds, picked by the seed (so everyone hears the same one), from
-- the character, started past its lead-in so the whoosh begins on the click
local playing = setmetatable({}, { __mode = "k" }) -- [character] = its swing Sound
local function swingSound(character, c, seed)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or #c.Sounds == 0 then
		return
	end
	-- one swing sound per character: a new slash cuts the last one's tail off (a quick
	-- fade) instead of stacking on it
	local last = playing[character]
	if last and last.Parent then
		TweenService:Create(last, TweenInfo.new(c.SoundCut), { Volume = 0 }):Play()
		Debris:AddItem(last, c.SoundCut + 0.05)
	end
	local sound = Instance.new("Sound")
	local pick = c.Sounds[Random.new(seed):NextInteger(1, #c.Sounds)]
	sound.SoundId = pick.id
	sound.Volume = c.Volume
	sound.Parent = root
	sound.TimePosition = pick.start
	sound:Play()
	playing[character] = sound
	Debris:AddItem(sound, 5)
end

local function play(character, dir, tool, seed, yaw)
	local c = settings(tool)
	local origin, follow = slashFrame(character, c, yaw)
	if not origin then
		return
	end
	-- the sound starts on the click; the body winds up and the arc starts with the strike
	swingSound(character, c, seed)
	SwingPose.play(character, dir, c)
	task.delay(c.Windup, SlashFx.play, origin, dir, c, follow, seed)
end

-- local player's sword: aim and auto-attack
local nextDir = 1
local ready = 0 -- os.clock() when the next slash may start
local aimYaw = nil -- world yaw the slashes point along (SwingPose eases the torso onto it)

local function yawOf(v)
	return math.atan2(-v.X, -v.Z)
end
local function wrap(a)
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- the nearest thing to hit within `range` of the character (flat distance to its edge):
-- a boss (workspace.Bosses), or a training mob or dummy (workspace.Mobs) in a ground
-- you've unlocked
local function nearestBoss(root, range)
	local best, bestDist = nil, range
	for _, name in { "Bosses", "Mobs" } do
		local folder = workspace:FindFirstChild(name)
		for _, body in if folder then folder:GetChildren() else {} do
			local ground = body:GetAttribute("Ground")
			if
				body:IsA("BasePart")
				and (body:GetAttribute("Health") or 0) > 0
				and (ground == nil or player:GetAttribute("Train" .. ground) ~= false)
			then
				local d = ((body.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude
					- (body:GetAttribute("Radius") or 0)
				if d < bestDist then
					best, bestDist = body, d
				end
			end
		end
	end
	return best
end

local function slash(tool, yaw)
	local character = player.Character
	if not character then
		return
	end
	local c = settings(tool)
	local dir = nextDir
	if c.Alternate then
		nextDir = -nextDir
	end
	ready = os.clock() + c.Cooldown / Power.speed(player:GetAttribute("Strength")) -- (Strength swings faster)
	local seed = math.random(1, 2 ^ 30)
	play(character, dir, tool, seed, yaw)
	task.delay(c.Windup, SlashCam.zoom, c) -- the camera feels the strike
	remote:FireServer(dir, seed, yaw)
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("Weapon")
	local c = settings(tool)
	local range = if id then Weapons.range(id, c) else c.AttackRange
	local facing = yawOf(root.CFrame.LookVector)
	local target = nearestBoss(root, math.max(c.AimRange, range + 8))
	local want = if target then yawOf((target.Position - root.Position) * Vector3.new(1, 0, 1)) else facing
	aimYaw = want
	SwingPose.aim(character, math.clamp(wrap(aimYaw - facing), -math.rad(c.AimTwist), math.rad(c.AimTwist)))

	if not id or os.clock() < ready then
		return
	end
	local inRange = nearestBoss(root, range)
	if not inRange then
		return
	end
	if Weapons.get(id).Shot then
		-- (shots go straight at it, not along the eased aim)
		local yaw = yawOf((inRange.Position - root.Position) * Vector3.new(1, 0, 1))
		local interval = Weapons.cooldown(id, c) / Power.speed(player:GetAttribute("Strength"))
		ready = os.clock() + interval
		local seed = math.random(0, 2 ^ 30 - 1) -- (the same shots here, on the server and for everyone)
		Shots.fire(character, id, yaw, seed)
		SwingPose.shoot(character, id, yaw, interval)
		local root = character:FindFirstChild("HumanoidRootPart")
		shootRemote:FireServer(yaw, seed, root and root.Position) -- (from where it's drawn here)
	else
		slash(tool, aimYaw)
	end
end)

-- the weapon is always out: no inventory bar (so no keys to put it away), and it's
-- equipped whenever it's in the backpack
local function hideBackpack()
	-- (SetCoreGuiEnabled can fail if the core scripts aren't up yet: retry briefly)
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
			return
		end
		task.wait(0.25)
	end
end
task.spawn(hideBackpack)
local function autoEquip(character)
	local humanoid = character:WaitForChild("Humanoid")
	local backpack = player:WaitForChild("Backpack")
	local function equip(tool)
		if tool:IsA("Tool") and tool:GetAttribute("Weapon") and humanoid.Health > 0 then
			task.defer(function()
				if tool.Parent == backpack then
					humanoid:EquipTool(tool)
				end
			end)
		end
	end
	for _, tool in backpack:GetChildren() do
		equip(tool)
	end
	backpack.ChildAdded:Connect(equip)
end
player.CharacterAdded:Connect(autoEquip)
if player.Character then
	task.spawn(autoEquip, player.Character)
end

-- other players' slashes
remote.OnClientEvent:Connect(function(other, dir, seed, yaw)
	local character = other.Character
	if character then
		play(character, dir, character:FindFirstChildOfClass("Tool"), seed, yaw)
	end
end)
shootRemote.OnClientEvent:Connect(function(other, id, yaw, seed)
	Shots.fire(other.Character, id, yaw, seed)
	if other.Character then
		-- (their Strength speeds them up too: SwingPose times the draw by their shots' gaps)
		SwingPose.shoot(other.Character, id, yaw, Weapons.cooldown(id))
	end
end)

-- top-down camera toggle (T): straight down onto the player, for judging the slash
local topDown = false
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.T then
		topDown = not topDown
		camera.CameraType = if topDown then Enum.CameraType.Scriptable else Enum.CameraType.Custom
	end
end)
RunService:BindToRenderStep("TopDownCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local root = topDown and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		local at = root.Position
		camera.CFrame = CFrame.lookAt(at + Vector3.new(0, 40, 6), at)
		camera.Focus = CFrame.new(at)
	end
end)
