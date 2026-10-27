-- The cactus vendor (QM, Oct 27: LassoAPet's Carl). Server/Map builds his stall from each
-- Vendor object in the map, with a still Carl in it so he shows in Studio's Edit mode; here
-- each client swaps that Carl for one that idles, turns to watch you when you're near and
-- hops hello when you Talk. He sells weapons (QM, Oct 27): Talk fires Vendor.talked, which
-- the shop popup listens to (it buys through the BuyWeapon RemoteFunction, Server/Arsenal;
-- what's for sale is Shared/Weapons' forSale(), with each Config.Weapons Price).
--
--   Vendor.talked   -- RBXScriptSignal: fires when the player Talks to a vendor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cactus = require(Shared.Animals.Cactus)

local player = Players.LocalPlayer
local settings = Config.Vendor

local Vendor = {}
local talked = Instance.new("BindableEvent")
Vendor.talked = talked.Event

local live = {} -- [stall] = { carl, spot, scale, rootY, yaw, hop }

local function add(stall)
	if live[stall] or not stall:IsA("Model") then
		return
	end
	local spot = stall:WaitForChild("CarlSpot", 10)
	if not spot then
		return
	end
	local still = stall:FindFirstChild("Carl")
	if still then
		still:Destroy()
	end
	local scale = stall:GetAttribute("Scale") or 1
	local carl = Cactus.new()
	carl:setSaddled(false)
	carl:setScale(scale)
	for _, part in carl.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		end
	end
	local v = { carl = carl, spot = spot, rootY = carl.model.PrimaryPart.Position.Y, yaw = 0, hop = 0 }
	carl.model.Parent = stall
	live[stall] = v
	local prompt = stall:FindFirstChild("TalkPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function()
			v.hop = settings.Hop
			talked:Fire()
		end)
	end
	stall.AncestryChanged:Connect(function()
		if not stall:IsDescendantOf(workspace) then
			live[stall] = nil
			carl.model:Destroy()
		end
	end)
end

local function watch(map)
	local vendors = map:WaitForChild("Vendors", 30)
	if not vendors then
		return
	end
	vendors.ChildAdded:Connect(add)
	for _, stall in vendors:GetChildren() do
		task.spawn(add, stall)
	end
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "Map" then
		watch(child)
	end
end)
local map = workspace:FindFirstChild("Map")
if map then
	task.spawn(watch, map)
end

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	for _, v in live do
		local origin = v.spot.CFrame
		local away = if hrp then (hrp.Position - origin.Position) * Vector3.new(1, 0, 1) else nil
		if away and away.Magnitude > 200 then
			continue -- too far to see him move
		end
		-- (turns to you while you're close, at most about 60 degrees off his counter)
		local target = 0
		if away and away.Magnitude > 0.1 and away.Magnitude < settings.LookRange then
			local inFrame = origin:VectorToObjectSpace(away)
			target = math.clamp(math.atan2(-inFrame.X, -inFrame.Z), -1, 1)
		end
		v.yaw += (target - v.yaw) * math.min(1, dt * 8)
		v.hop = math.max(0, v.hop - dt)
		local lift = math.sin(v.hop / settings.Hop * math.pi) * 0.6 -- (low: the roof is just over his head)
		v.carl:update(dt, 0, 0)
		v.carl.model.PrimaryPart.CFrame = origin
			* CFrame.new(0, v.rootY + lift * (v.carl.scale or 1), 0)
			* CFrame.Angles(0, v.yaw, 0)
	end
end)

return Vendor
