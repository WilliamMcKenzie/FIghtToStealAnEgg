-- Wading (QM, Oct 24): a biome's liquid tiles (water, magma; Map marks their parts Liquid)
-- sink you a little (their beds sit Config.Map.LiquidSink under the surface) and slow
-- you to Config.Map.LiquidSlow of your speed (your pet's, Shared/Pets) while you're in them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Pets = require(ReplicatedStorage.Shared:WaitForChild("Pets"))

local player = Players.LocalPlayer
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local floor = workspace:WaitForChild("Map"):WaitForChild("Floor")
params.FilterDescendantsInstances = { floor }

local wading = false
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.1 then
		return
	end
	clock = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return
	end
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	local now = hit ~= nil and hit.Instance:GetAttribute("Liquid") == true
	local speed = Pets.stats(player:GetAttribute("Pet") or "Horse").Speed * (if now then Config.Map.LiquidSlow else 1)
	if now ~= wading or math.abs(humanoid.WalkSpeed - speed) > 0.01 then -- (or a new pet)
		wading = now
		humanoid.WalkSpeed = speed
	end
end)

player.CharacterAdded:Connect(function()
	wading = false
end)

return {}
