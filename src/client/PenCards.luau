-- Every pen's card (QM, Oct 31, from their reference): high over each owned pen floats its
-- owner's avatar (a headshot) with "@name" under it, big white Montserrat ExtraBold with a
-- black outline, readable from the zoomed-out camera. Over your own pen it's the same card
-- at the same size and place with QM's blue house and "Your Base" instead (QM: "on your own
-- base swap for the base icon with the same scale"). Yours goes away while you're inside your
-- pen (QM: "goes away once you actually walk in the pen") and comes back when you leave.
-- An empty pen has no card. The server names each pen's owner (OwnerId, OwnerName:
-- Server/Pens). Tuning in Config.PenCard; the house is HudImages.BaseHouse
-- (assets/ui/hud/BaseHouse.png).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HudImages = require(script.Parent.HudImages)

local player = Players.LocalPlayer
local C = Config.PenCard
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)

local folder = Instance.new("Folder")
folder.Name = "PenCards"
folder.Parent = workspace

local cards = {} -- [pen] = { spot, board, picture, label, owner }
local headshots = {} -- [userId] = image

local function headshot(userId, picture)
	if headshots[userId] then
		picture.Image = headshots[userId]
		return
	end
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
		end)
		if ok and image then
			headshots[userId] = image
			if picture.Parent then
				picture.Image = image
			end
		end
	end)
end

local function build(pen)
	local spot = Instance.new("Part")
	spot.Name = pen.Name
	spot.Anchored, spot.CanCollide, spot.CanQuery, spot.CanTouch = true, false, false, false
	spot.Transparency = 1
	spot.Size = Vector3.one * 0.2
	local board = Instance.new("BillboardGui")
	-- (in studs, so it sits in the world like the pen does: the picture, square, over the text)
	board.Size = UDim2.fromScale(C.Width, C.Width + C.Text)
	board.LightInfluence = 0
	board.AlwaysOnTop = false
	board.Adornee = spot
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Size = UDim2.fromScale(1, C.Width / (C.Width + C.Text))
	picture.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.fromScale(1.4, C.Text / (C.Width + C.Text)) -- (a long @name can run wider)
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = board
	board.Parent = spot
	spot.Parent = folder
	local card = { spot = spot, board = board, picture = picture, label = label }
	cards[pen] = card
	return card
end

local function inside(area)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local p = area.CFrame:PointToObjectSpace(root.Position)
	return math.abs(p.X) <= area.Size.X / 2 and math.abs(p.Z) <= area.Size.Z / 2
end

RunService.RenderStepped:Connect(function()
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	local seen = {}
	for _, pen in (if pens then pens:GetChildren() else {}) do
		local area = pen:FindFirstChild("Area")
		local userId = pen:GetAttribute("OwnerId")
		if not (area and userId) then
			continue
		end
		seen[pen] = true
		local card = cards[pen] or build(pen)
		local mine = userId == player.UserId
		if card.owner ~= userId then
			card.owner = userId
			card.picture.Image = ""
			if mine then
				card.picture.Image = HudImages.BaseHouse or ""
				card.label.Text = "Your Base"
			else
				card.label.Text = "@" .. (pen:GetAttribute("OwnerName") or "")
				headshot(userId, card.picture)
			end
		end
		card.board.Enabled = not (mine and inside(area))
		-- over the pen's middle (or back from it, away from the gate), the text's bottom
		-- C.Bottom up
		local at = area.Position
		local sign = pen:FindFirstChild("OwnerSign")
		local gate = sign and sign:FindFirstChild("Board")
		if gate and C.Back ~= 0 then
			local out = gate.Position - area.Position
			out = Vector3.new(out.X, 0, out.Z)
			if out.Magnitude > 0 then
				at -= out.Unit * C.Back
			end
		end
		local floor = area.Position.Y - area.Size.Y / 2
		card.spot.CFrame = CFrame.new(at.X, floor + C.Bottom + (C.Width + C.Text) / 2, at.Z)
	end
	for pen, card in cards do
		if not seen[pen] then
			card.spot:Destroy()
			cards[pen] = nil
		end
	end
end)

return nil
