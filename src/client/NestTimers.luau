-- The nests' cooldown over them (QM, Oct 26): get close to a nest whose eggs are gone
-- and its biome's countdown to the next refill shows over it, in the pen eggs' style
-- (client/PenEggs). Each nest (tagged "Nest" by Server/Eggs) holds the cooldown's end
-- in CooldownEnds (server time); none while it has eggs or its fight is on.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local INK = Color3.fromRGB(14, 12, 16)
local HEIGHT = 7 -- studs over the nest's egg spot

local folder = Instance.new("Folder")
folder.Name = "NestTimers"
folder.Parent = workspace

local timers = {} -- [nest] = { spot, board, label }

local function timeText(left)
	left = math.max(0, math.ceil(left))
	if left >= 3600 then
		return string.format("%dh %dm", left // 3600, (left % 3600) // 60)
	elseif left >= 60 then
		return string.format("%dm %ds", left // 60, left % 60)
	end
	return left .. "s"
end

local function add(nest)
	local x, y, z = nest:GetAttribute("EggX"), nest:GetAttribute("EggY") or 1, nest:GetAttribute("EggZ")
	if timers[nest] or not (x and z) then
		return
	end
	local spot = Instance.new("Part")
	spot.Name = nest.Name
	spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
	spot.Transparency = 1
	spot.Size = Vector3.one * 0.2
	spot.CFrame = CFrame.new(x, y + HEIGHT, z)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 40)
	board.AlwaysOnTop = true
	board.MaxDistance = Config.Eggs.TimerRange
	board.LightInfluence = 0
	board.Enabled = false
	board.Adornee = spot
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.TextSize = 26
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = INK
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = board
	board.Parent = spot
	spot.Parent = folder
	timers[nest] = { spot = spot, board = board, label = label }
end

local function remove(nest)
	local t = timers[nest]
	timers[nest] = nil
	if t then
		t.spot:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal("Nest"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Nest"):Connect(remove)
for _, nest in CollectionService:GetTagged("Nest") do
	add(nest)
end

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for nest, t in timers do
		local ends = nest:GetAttribute("CooldownEnds")
		local left = ends and ends - now
		t.board.Enabled = left ~= nil and left > 0
		if t.board.Enabled then
			t.label.Text = timeText(left)
		end
	end
end)

return nil
