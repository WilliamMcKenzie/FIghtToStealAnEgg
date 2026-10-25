-- Region blockers (QM, Oct 25): each region's gate has its blocker built into the map
-- (Map.Blockers, Shared/RegionBlocker: the navy wall with its name, price and Buy button,
-- and its shadow). Here: once you own the region (your Region<Name> attribute) it's
-- taken out of your world, so only you walk through; until then its Buy buttons ask
-- Server/Regions (BuyRegion), and a little shake says you can't afford it yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local blockers = map:WaitForChild("Blockers", 30)

local hidden = {} -- [region] = its blocker, kept out of the world while you own it
local all = {} -- [region] = its blocker

local function press(button, region)
	local scale = button:FindFirstChildOfClass("UIScale")
	local function to(s, t)
		if scale then
			TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Back), { Scale = s }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		to(1.05, 0.12)
	end)
	button.MouseLeave:Connect(function()
		to(1, 0.12)
	end)
	button.Activated:Connect(function()
		to(0.92, 0.06)
		local ok = ReplicatedStorage:WaitForChild("BuyRegion"):InvokeServer(region)
		to(1, 0.15)
		if not ok then
			local at = button.Position
			for _, dx in { 12, -10, 7, -4, 0 } do
				TweenService:Create(button, TweenInfo.new(0.04), { Position = at + UDim2.fromOffset(dx, 0) }):Play()
				task.wait(0.04)
			end
		end
	end)
end

local function refresh()
	for region, model in all do
		local owned = player:GetAttribute("Region" .. region) == true
		if owned and not hidden[region] then
			hidden[region] = model
			model.Parent = nil
		elseif not owned and hidden[region] then
			hidden[region] = nil
			model.Parent = blockers
		end
	end
end

for _, model in if blockers then blockers:GetChildren() else {} do
	local region = model:GetAttribute("Region")
	all[region] = model
	for _, d in model:GetDescendants() do
		if d:IsA("GuiButton") and d.Name == "Buy" then
			press(d, region)
		end
	end
end
refresh()
player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 6) == "Region" then
		refresh()
	end
end)

return nil
