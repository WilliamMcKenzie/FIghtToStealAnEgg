-- What only you see and bump into (QM, Oct 24):
-- - Locked into a boss's fight (your LockedIn attribute: you stole one of its eggs or
--   hit it; server/Eggs.luau), red barriers stand across that biome's ways out until the
--   boss is dead. Everyone else walks through, unless they join the fight too. They're
--   local parts, so they only block you.
-- - A training ground you haven't bought keeps its gate shut (a local bar across it),
--   and its Unlock prompt shows; once bought, the bar goes and the prompt hides.
-- - A banner at the top says what to do: beat the boss, or take your egg home.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local RED = Color3.fromRGB(255, 60, 50)

local map = workspace:WaitForChild("Map")

-- ---- the fight's barriers ------------------------------------------------------------

-- (the barriers are built into the map, visible in Studio: here they start hidden and
-- only the ones round your fight show, solid for you alone)
local function barriers()
	local biome = player:GetAttribute("LockedIn")
	local markers = map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	for _, wall in if markers then markers:GetChildren() else {} do
		local mine = biome ~= nil and (wall:GetAttribute("South") == biome or wall:GetAttribute("North") == biome)
		wall.Color = RED
		wall.Material = Enum.Material.ForceField
		wall.CanCollide = mine
		if mine then
			wall.Transparency = 1
			TweenService:Create(wall, TweenInfo.new(0.35), { Transparency = 0.1 }):Play()
		else
			wall.Transparency = 1
		end
	end
end

-- ---- training gates --------------------------------------------------------------------

local bars = {} -- [zone] = local bar
local function gates()
	local training = map:WaitForChild("Base"):WaitForChild("Training")
	for _, zone in training:GetChildren() do
		local gate = zone:FindFirstChild("Gate")
		if gate then
			local open = player:GetAttribute("Train" .. zone.Name) ~= false
			local prompt = gate:FindFirstChild("Unlock")
			if prompt then
				prompt.Enabled = not open
			end
			if open and bars[zone] then
				bars[zone]:Destroy()
				bars[zone] = nil
			elseif not open and not bars[zone] then
				local bar = Instance.new("Part")
				bar.Name = "LockedGate"
				bar.Anchored = true
				bar.CanCollide = true
				bar.Size = Vector3.new(gate.Size.X, 4, 0.6)
				bar.CFrame = gate.CFrame - Vector3.new(0, gate.Size.Y / 2 - 2, 0)
				bar.Material = Enum.Material.ForceField
				bar.Color = Color3.fromRGB(255, 196, 60)
				bar.Parent = workspace
				bars[zone] = bar
			end
		end
	end
end

-- ---- the banner --------------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FightBanner"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 70)
label.Size = UDim2.fromOffset(640, 44)
label.BackgroundTransparency = 1
label.FontFace = FONT
label.TextSize = 30
label.TextColor3 = Color3.new(1, 1, 1)
label.Visible = false
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Parent = label
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Parent = label
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function banner()
	local locked = player:GetAttribute("LockedIn")
	local egg = player:GetAttribute("HeldEgg")
	if locked then
		label.Text = "DEFEAT THE BOSS TO ESCAPE!"
		-- (warm lit top, cool dark bottom: QM's gradient rule)
		gradient.Color = ColorSequence.new(Color3.fromRGB(255, 150, 110), Color3.fromRGB(220, 40, 70))
	elseif egg then
		label.Text = "TAKE THE EGG HOME TO YOUR PEN!"
		gradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(120, 220, 110))
	end
	label.Visible = locked ~= nil or egg ~= nil
end

player:GetAttributeChangedSignal("LockedIn"):Connect(function()
	barriers()
	banner()
end)
player:GetAttributeChangedSignal("HeldEgg"):Connect(banner)
player.AttributeChanged:Connect(function(name)
	if name:sub(1, 5) == "Train" then
		gates()
	end
end)
barriers()
banner()
task.spawn(gates)

return {}
