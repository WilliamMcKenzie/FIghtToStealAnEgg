-- Eggs in hands and in pens (QM, Oct 25, LassoAPet's hatching: Server/Hatchery).
--
--   Held: anyone holding an egg (a Tool with EggTool) gets that egg
--     drawn out in front of their hand.
--   Placing: while you hold one, a see-through egg follows the mouse over your pen; click
--     or tap to put it down there (PlaceEgg).
--   In pens: every player's placed eggs (their PenEggs attribute) stand in their pen,
--     twitching now and then, a countdown over each ("Ready!" once it's up). By one of
--     your own that's ready, hold E to hatch it (HatchEgg). The hatch plays for everyone
--     (Hatched): the egg shakes and its top pops off.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Egg = require(Shared.Eggs.Egg)
local Pets = require(Shared.Pets)
local OnScreen = require(script.Parent.OnScreen)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local placeRemote = ReplicatedStorage:WaitForChild("PlaceEgg")
local hatchRemote = ReplicatedStorage:WaitForChild("HatchEgg")

local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local INK = Color3.fromRGB(14, 12, 16)
local READY = Color3.fromRGB(150, 255, 120)
local EDGE = 3 -- (as Server/Hatchery)
local TWITCH = Config.Eggs.Twitch
local PEN_SCALE = Config.Eggs.Scale.Pen

local folder = Instance.new("Folder")
folder.Name = "PenEggs"
folder.Parent = workspace

-- an egg model that never gets in the way
local function newEgg(kind, scale)
	local ok, egg = pcall(Egg.new, kind, scale)
	if not ok then
		return nil
	end
	for _, part in egg.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	egg.model.Parent = folder
	return egg
end

local function height(egg)
	local _, size = egg.model:GetBoundingBox()
	return size.Y
end

local function penArea(owner)
	local index = owner:GetAttribute("Pen")
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen:FindFirstChild("Area")
		end
	end
	return nil
end

-- where (x, z) in a pen's Area stands on its floor
local function floorAt(area, x, z)
	return area.CFrame:PointToWorldSpace(Vector3.new(x, -area.Size.Y / 2, z))
end

-- ---- held eggs -----------------------------------------------------------------------

local held = {} -- [tool] = egg or false

local function drawHeld()
	local seen = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local kind = tool and tool:GetAttribute("EggTool")
		local handle = kind and tool:FindFirstChild("Handle")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if handle and root then
			seen[tool] = true
			if held[tool] == nil then
				held[tool] = newEgg(kind, Config.Hatch.Scale.Held) or false
			end
			local egg = held[tool]
			if egg then
				-- (upright, level with the hand, out in front so it clears the body)
				local h = height(egg)
				local at = handle.Position + root.CFrame.LookVector * h * 0.45 - Vector3.new(0, h / 2, 0)
				egg.model:PivotTo(CFrame.new(at) * root.CFrame.Rotation)
			end
		end
	end
	for tool, egg in held do
		if not seen[tool] then
			if egg then
				egg.model:Destroy()
			end
			held[tool] = nil
		end
	end
end

-- ---- placing ---------------------------------------------------------------------------

local ghost, ghostKind = nil, nil

local function holding()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("EggTool")
end

-- the spot in your pen under the screen point (x, z in its Area), or nil
local function spotAt(screen)
	local area = penArea(player)
	if not (area and screen) then
		return nil
	end
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local floor = area.Position.Y - area.Size.Y / 2
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (floor - ray.Origin.Y) / ray.Direction.Y
	if t <= 0 then
		return nil
	end
	local p = area.CFrame:PointToObjectSpace(ray.Origin + ray.Direction * t)
	if math.abs(p.X) > area.Size.X / 2 - EDGE or math.abs(p.Z) > area.Size.Z / 2 - EDGE then
		return nil
	end
	return area, p.X, p.Z
end

local function drawGhost()
	local kind = holding()
	if kind ~= ghostKind then
		if ghost then
			ghost.model:Destroy()
			ghost = nil
		end
		ghostKind = kind
		if kind then
			ghost = newEgg(kind, PEN_SCALE)
			if ghost then
				for _, part in ghost.model:GetDescendants() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0.5
					end
				end
			end
		end
	end
	if ghost then
		local area, x, z = spotAt(UserInputService:GetMouseLocation())
		ghost.model.Parent = if area then folder else nil
		if area then
			ghost.model:PivotTo(CFrame.new(floorAt(area, x, z)) * area.CFrame.Rotation)
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not holding() then
		return
	end
	local screen
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		screen = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		screen = Vector2.new(input.Position.X, input.Position.Y)
	end
	local area, x, z = spotAt(screen)
	if area then
		placeRemote:FireServer(x, z)
	end
end)

-- ---- eggs in pens ----------------------------------------------------------------------

local shown = {} -- [id] = { egg, owner, kind, ready, at, label, prompt, nextTwitch, hatching }

local function timeText(left)
	left = math.max(0, math.ceil(left))
	if left >= 3600 then
		return string.format("%dh %dm", left // 3600, (left % 3600) // 60)
	elseif left >= 60 then
		return string.format("%dm %ds", left // 60, left % 60)
	end
	return left .. "s"
end

local function show(owner, e, area)
	local egg = newEgg(e.k, PEN_SCALE)
	if not egg then
		return
	end
	local yaw = (tonumber(string.sub(e.id, 1, 6), 16) or 0) % 628 / 100 -- (its own turn, the same for everyone)
	egg.model:PivotTo(CFrame.new(floorAt(area, e.x, e.z)) * area.CFrame.Rotation * CFrame.Angles(0, yaw, 0))
	local s = {
		egg = egg,
		owner = owner,
		kind = e.k,
		ready = e.t,
		nextTwitch = os.clock() + math.random() * TWITCH[2],
	}
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(160, 40)
	board.StudsOffsetWorldSpace = Vector3.new(0, height(egg) + 1.2, 0)
	board.AlwaysOnTop = true
	board.MaxDistance = 80
	board.LightInfluence = 0
	board.Adornee = egg.model.PrimaryPart
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
	board.Parent = egg.model
	s.label = label
	if owner == player then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hatch"
		prompt.ObjectText = Pets.name(e.k) .. " Egg"
		prompt.HoldDuration = Config.Hatch.HoldTime
		prompt.MaxActivationDistance = Config.Hatch.Range
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = egg.model.PrimaryPart
		prompt.Triggered:Connect(function()
			hatchRemote:FireServer(e.id)
		end)
		s.prompt = prompt
	end
	shown[e.id] = s
end

local function forget(id)
	local s = shown[id]
	if s and not s.hatching then
		shown[id] = nil
		s.egg.model:Destroy()
	end
end

-- each player's PenEggs, drawn (only the difference comes and goes)
local function refresh(owner)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, owner:GetAttribute("PenEggs") or "[]")
	list = if ok and type(list) == "table" then list else {}
	local area = penArea(owner)
	local want = {}
	if area then
		for _, e in list do
			if type(e) == "table" and e.id and Config.Pets[e.k] then
				e.id = tostring(e.id)
				want[e.id] = true
				if not shown[e.id] then
					show(owner, e, area)
				end
			end
		end
	end
	for id, s in shown do
		if s.owner == owner and not want[id] then
			-- (a moment's grace: if it hatched, Hatched comes just after and plays it)
			task.delay(0.4, forget, id)
		end
	end
end

local function watch(owner)
	owner:GetAttributeChangedSignal("PenEggs"):Connect(function()
		refresh(owner)
	end)
	owner:GetAttributeChangedSignal("Pen"):Connect(function()
		for id, s in shown do
			if s.owner == owner then
				s.hatching = nil
				forget(id)
			end
		end
		refresh(owner)
	end)
	refresh(owner)
end
Players.PlayerAdded:Connect(watch)
for _, owner in Players:GetPlayers() do
	task.spawn(watch, owner)
end
Players.PlayerRemoving:Connect(function(owner)
	for id, s in shown do
		if s.owner == owner then
			s.hatching = nil
			forget(id)
		end
	end
end)

-- ---- hatching --------------------------------------------------------------------------

ReplicatedStorage:WaitForChild("Hatched").OnClientEvent:Connect(function(owner, id, kind, at)
	local s = shown[id]
	if not s then
		-- (gone already: a fresh one where it stood, to hatch)
		local egg = newEgg(kind, PEN_SCALE)
		if not egg or typeof(at) ~= "Vector3" then
			return
		end
		egg.model:PivotTo(CFrame.new(at))
		s = { egg = egg, owner = owner, kind = kind, ready = 0, nextTwitch = math.huge }
		shown[id] = s
	end
	s.hatching = true
	if s.prompt then
		s.prompt:Destroy()
		s.prompt = nil
	end
	if s.label then
		s.label.Parent.Enabled = false
	end
	s.egg:play("hatch")
	local length = s.egg.animations and s.egg.animations.hatch and s.egg.animations.hatch.length or 2
	task.delay(length, function()
		s.hatching = nil
		forget(id)
	end)
end)

RunService.RenderStepped:Connect(function(dt)
	drawHeld()
	drawGhost()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	for _, s in shown do
		if s.label and not s.hatching then
			local left = s.ready - now
			if left <= 0 then
				s.label.Text = "Ready!"
				s.label.TextColor3 = READY
			else
				s.label.Text = timeText(left)
				s.label.TextColor3 = Color3.new(1, 1, 1)
			end
			if s.prompt then
				s.prompt.Enabled = left <= 0
			end
		end
		if not s.hatching and not OnScreen.near(s.egg.model:GetPivot().Position, 8) then
			continue -- (off screen: no twitching, QM Oct 27)
		end
		if not s.hatching and clock >= s.nextTwitch then
			s.egg:play("twitch")
			s.nextTwitch = clock + TWITCH[1] + math.random() * (TWITCH[2] - TWITCH[1])
		end
		s.egg:update(dt)
	end
end)

return nil
