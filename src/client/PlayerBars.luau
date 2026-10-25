-- Over every player (QM, Oct 25): the name of the animal they ride, coloured by its rarity
-- (Config.Rarities, its Config.Pets rarity), and their health as QM's little green bar
-- (assets/ui/HpBack.png under HpFill.png, the fill cut from the right as they're hurt).
-- Roblox's own name and health over characters is turned off.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))

local FILL, BACK = "rbxassetid://90275415984527", "rbxassetid://133695040857929"
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local function attach(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local head = character:WaitForChild("Head", 10)
	if not (humanoid and head) then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild("PlayerBar")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PlayerBar"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(6, 1.6) -- (studs: it shrinks with distance like the world)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	-- the animal's name
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.FontFace = FONT
	name.TextScaled = true
	local stroke = Instance.new("UIStroke")
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = name
	name.Parent = gui
	local player = Players:GetPlayerFromCharacter(character)
	local function pet()
		local stats = Pets.stats(player and player:GetAttribute("Pet") or "Horse")
		local rarity = Config.Rarities[stats.Rarity] or Config.Rarities.Common
		name.Text = stats.Name
		name.TextColor3 = rarity.Fill
		stroke.Color = rarity.Stroke
	end
	pet()
	if player then
		local changed = player:GetAttributeChangedSignal("Pet"):Connect(pet)
		gui.Destroying:Connect(function()
			changed:Disconnect()
		end)
	end
	-- the health bar (216 x 18 art)
	local bar = Instance.new("Frame")
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 1)
	bar.Size = UDim2.fromScale(1, 0.32)
	bar.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 216 / 18
	ratio.Parent = bar
	local back = Instance.new("ImageLabel")
	back.BackgroundTransparency = 1
	back.Image = BACK
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = bar
	local clip = Instance.new("Frame")
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.Parent = bar
	local fill = Instance.new("ImageLabel")
	fill.BackgroundTransparency = 1
	fill.Image = FILL
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = clip
	local function health()
		local f = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		clip.Size = UDim2.fromScale(f, 1)
		-- (the art keeps its full width inside the clip, so it's cut, not squashed)
		fill.Size = UDim2.fromScale(if f > 0 then 1 / f else 1, 1)
	end
	humanoid.HealthChanged:Connect(health)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(health)
	health()
	-- (the name's outline as thick as the bar's black border, 4 of its 18 pixels, at
	-- whatever size the billboard is drawn: QM)
	local function outline()
		stroke.Thickness = math.max(1, bar.AbsoluteSize.Y * 4 / 18)
	end
	bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(outline)
	outline()
	gui.Parent = head
end

local function watch(player)
	player.CharacterAdded:Connect(attach)
	if player.Character then
		task.spawn(attach, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

return nil
