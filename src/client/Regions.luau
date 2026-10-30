-- Region blockers (QM, Oct 25): each region's gate has its blocker built into the map
-- (Map.Blockers, Shared/RegionBlocker: the navy wall with its name, price and Buy button,
-- and its shadow). Here: once you own the region (your Region<Name> attribute; a training
-- ground's blocker, Train<Name>: the model's Owns attribute) it's taken out of your world,
-- so only you walk through; until then its Buy buttons ask Server/Regions (BuyRegion), and
-- a little shake says you can't afford it yet. The dark over the region (the blocker's Dark
-- part) goes with it, lifting over Config.Regions.Dark.Fade when you buy it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local blockers = map:WaitForChild("Blockers", 30)

local hidden = {} -- [blocker] = true while you own it (kept out of the world)
local all = {} -- [blocker] = the player attribute that opens it

local function press(button, region, training)
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
		local ok = ReplicatedStorage:WaitForChild("BuyRegion"):InvokeServer(region, training)
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

-- the region's dark lifting (a copy, so the blocker itself can go at once)
local function lift(model)
	local dark = model:FindFirstChild("Dark")
	if not dark then
		return
	end
	local copy = dark:Clone()
	copy.Parent = workspace
	local info = TweenInfo.new(Config.Regions.Dark.Fade, Enum.EasingStyle.Quad)
	local tween = TweenService:Create(copy, info, { Transparency = 1 })
	tween.Completed:Connect(function()
		copy:Destroy()
	end)
	tween:Play()
end

local ready = false -- (owned at join: no fade)

local function refresh()
	for model, owns in all do
		local owned = player:GetAttribute(owns) == true
		if owned and not hidden[model] then
			hidden[model] = true
			if ready then
				lift(model)
			end
			model.Parent = nil
		elseif not owned and hidden[model] then
			hidden[model] = nil
			model.Parent = blockers
		end
	end
end

for _, model in if blockers then blockers:GetChildren() else {} do
	local region = model:GetAttribute("Region")
	local training = model:GetAttribute("Training") == true
	all[model] = model:GetAttribute("Owns") or ((if training then "Train" else "Region") .. region)
	for _, d in model:GetDescendants() do
		if d:IsA("GuiButton") and d.Name == "Buy" then
			press(d, region, training)
		end
	end
end
refresh()
ready = true
player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 6) == "Region" or string.sub(name, 1, 5) == "Train" then
		refresh()
	end
end)

return nil
