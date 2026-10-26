-- Wading (QM, Oct 24): a biome's liquid tiles (water, magma; Map marks their parts Liquid)
-- sink you a little (their beds sit Config.Map.LiquidSink under the surface) and slow
-- you to Config.Map.LiquidSlow of your speed (your pet's, Shared/Pets) while you're in them
-- (client/Sprint sets the speed, with Liquid.slow()).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

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
	if not root then
		return
	end
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
	wading = hit ~= nil and hit.Instance:GetAttribute("Liquid") == true
end)

player.CharacterAdded:Connect(function()
	wading = false
end)

local Liquid = {}

-- x your speed: Config.Map.LiquidSlow while you're wading, else 1
function Liquid.slow()
	return if wading then Config.Map.LiquidSlow else 1
end

return Liquid
