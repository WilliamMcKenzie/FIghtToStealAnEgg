-- The six pens (two rows of three either side of the spawn; QM, Oct 24: 6 players a
-- server). Each player who joins gets the first free one (player attribute Pen) and its
-- sign shows their name; the eggs they bring home sit in rows inside it.
--
--   Pens.start(map)                       -- once, after Map.ensure()
--   Pens.of(player) -> the pen Model or nil
--   Pens.addEgg(player, biome, makeEgg)   -- one more egg sat in their pen

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Pens = {}

local pens = {} -- [index] = Model
local owners = {} -- [index] = player

local function setSign(pen, text)
	local sign = pen:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if board then
		for _, gui in board:GetChildren() do
			local label = gui:FindFirstChild("Text")
			if label then
				label.Text = text
			end
		end
	end
end

function Pens.of(player)
	local i = player:GetAttribute("Pen")
	return i and pens[i]
end

local function clearEggs(pen)
	local shown = pen:FindFirstChild("Eggs")
	if shown then
		shown:ClearAllChildren()
	end
end

function Pens.addEgg(player, biome, makeEgg)
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	if not area then
		return
	end
	local shown = pen:FindFirstChild("Eggs")
	if not shown then
		shown = Instance.new("Folder")
		shown.Name = "Eggs"
		shown.Parent = pen
	end
	local n = #shown:GetChildren()
	if n >= Config.Eggs.PenShows then
		shown:GetChildren()[1]:Destroy()
		n -= 1
	end
	-- (rows of 6, from the back of the pen)
	local col, row = n % 6, n // 6
	local half = area.Size.X / 2 - 8
	local egg = makeEgg(biome)
	egg.Anchored = true
	local floor = area.Position.Y - area.Size.Y / 2 -- (the pen's floor: its Area marker's bottom)
	egg.CFrame = CFrame.new(
		area.Position.X - half + col * (2 * half / 5),
		floor + egg.Size.Y / 2,
		area.Position.Z - half + row * 7
	)
	egg.Parent = shown
end

function Pens.start(map)
	for _, pen in map.Base.Pens:GetChildren() do
		pens[pen:GetAttribute("Index")] = pen
	end
	local function joined(player)
		for i = 1, #pens do
			if not owners[i] then
				owners[i] = player
				player:SetAttribute("Pen", i)
				setSign(pens[i], player.DisplayName .. "'s Pen")
				return
			end
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for i, owner in owners do
			if owner == player then
				owners[i] = nil
				setSign(pens[i], "")
				clearEggs(pens[i])
			end
		end
	end)
end

return Pens
