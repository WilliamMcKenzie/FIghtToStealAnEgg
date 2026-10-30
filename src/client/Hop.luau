-- Hopping over low things (QM, Oct 30: it was easy to get stuck outside your pen). Riding,
-- you can't jump, so when your pet's pushing into something low (a fence, a rail, a low
-- wall: anything solid up to Config.Hop.Height studs over the ground just ahead, with
-- room above it), it hops over it on its own: thrown up just high enough to clear it,
-- carrying on forward. Tall walls stay walls, and so does anything with a NoHop attribute. Only your own character (this client
-- moves it); client/Riding keeps it upright through the hop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Pets = require(ReplicatedStorage.Shared.Pets)

local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local cooldown = 0

RunService.Heartbeat:Connect(function(dt)
	cooldown -= dt
	local cfg = Config.Hop
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (cfg.On and root and humanoid and humanoid.Health > 0) or cooldown > 0 then
		return
	end
	local move = humanoid.MoveDirection * Vector3.new(1, 0, 1)
	if move.Magnitude < 0.1 or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	move = move.Unit
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("BossFx"), workspace:FindFirstChild("PenPets") }
	local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local reach = Pets.stats(player:GetAttribute("Pet") or "Horse").Hitbox + cfg.Ahead
	-- something solid just ahead, low down...
	local low = workspace:Raycast(Vector3.new(root.Position.X, feet + 1, root.Position.Z), move * reach, params)
	if not low or low.Normal.Y > 0.7 then -- (a slope it can walk up isn't in the way)
		return
	end
	if low.Instance:GetAttribute("NoHop") then
		return
	end
	-- ...that isn't too tall: the way's clear just over Height
	local high = workspace:Raycast(Vector3.new(root.Position.X, feet + cfg.Height + 0.5, root.Position.Z), move * reach, params)
	if high then
		return
	end
	-- how tall it is right there (from over it, down)
	local over = low.Position + move * 0.6
	local top = workspace:Raycast(Vector3.new(over.X, feet + cfg.Height + 0.5, over.Z), Vector3.new(0, -cfg.Height - 1, 0), params)
	local tall = if top then top.Position.Y - feet else cfg.Height
	local up = math.sqrt(2 * workspace.Gravity * (math.max(tall, 1) + cfg.Clear))
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, up), v.Z) + move * cfg.Push
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	cooldown = 0.4
end)

return {}
