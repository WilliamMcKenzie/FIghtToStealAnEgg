-- Eggs in hands and in pens: LassoAPet's, 1:1 (QM, Oct 27: its client/Pen and
-- client/HeldEgg; the server side is Server/Hatchery).
--
--   Held: anyone holding an egg (a Tool with EggTool) gets that egg drawn at its real
--     size, level with the hand and out in front so a big one clears the body.
--   Placing: while you hold one, a see-through egg follows the mouse over your pen; click
--     or tap to put it down there (PlaceEgg).
--   In pens: every player's placed eggs (their PenEggs attribute) stand in their pen
--     facing out of it, growing from 1x to Config.Hatch.GrowScale x as they wait and
--     twitching now and then. Near one, its countdown ("m:ss", "2h", then "Ready") pops
--     in over it. A big white arrow bobs over one of your own that's ready till its
--     prompt's up; hold F by it to hatch it (HatchEgg). The hatch plays for everyone
--     (Hatched): the egg shakes, its top pops off and the pet jumps out onto the spot
--     (client/BossView draws that jump: its pen body's HatchPop), then the empty shell
--     fades away.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Egg = require(Shared.Eggs.Egg)
local Pets = require(Shared.Pets)
local Studs = require(Shared.Studs)
local OnScreen = require(script.Parent.OnScreen)
local RideSounds = require(script.Parent.RideSounds)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local placeRemote = ReplicatedStorage:WaitForChild("PlaceEgg")
local hatchRemote = ReplicatedStorage:WaitForChild("HatchEgg")

local HATCH = Config.Hatch
local EGG_CENTER = 1.6 -- an egg's middle above its base, at 1x (LassoAPet's Egg.luau)
local TOP_POPS = HATCH.TopPops
local JUMP_TIME = HATCH.JumpTime
local TIMER_SIZE = Vector2.new(4, 1.28) -- studs: an egg's "Ready" / countdown
local HATCH_SOUND_PEAK = 0.46 -- seconds into egg_hatch where it's loudest
local TWITCH_EVERY = { 3, 6 }
local EDGE = HATCH.Edge -- (as Server/Hatchery)
local STUD_TILE = 0.5 -- (Egg.luau's stud decal)
-- An egg's countdown shows only while you're near it: in at TIMER_REACH studs, out past
-- TIMER_LEAVE, popping in.
local TIMER_REACH, TIMER_LEAVE = 16, 19
-- held: the egg's middle from the Handle, in studs per unit of the egg's size
local HELD_UP, HELD_FORWARD = 0, 1.1
local READY_ARROW = "rbxassetid://127821178410489" -- LassoAPet's assets/ui/TutorialArrow.png

local rng = Random.new()

local folder = Instance.new("Folder")
folder.Name = "PenEggs"
folder.Parent = workspace

-- an egg model that never gets in the way
local function newEgg(kind)
	local ok, egg = pcall(Egg.new, kind)
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
	egg.size = Egg.sizeOf(kind)
	egg.model.Parent = folder
	return egg
end

-- an egg's model at `scale` times its drawing (its studs picked for that size)
local function scaleEgg(egg, scale)
	egg.model:ScaleTo(scale)
	Studs.fit(egg.model, STUD_TILE * scale)
end

local function penOf(owner)
	local index = owner:GetAttribute("Pen")
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen
		end
	end
	return nil
end

local function penArea(owner)
	local pen = penOf(owner)
	return pen and pen:FindFirstChild("Area")
end

-- out of the pen, toward its gate (as Server/Pens.facing)
local function facing(area)
	local sign = area.Parent:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if not board then
		return 0
	end
	local d = board.Position - area.Position
	return math.atan2(-d.X, -d.Z)
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
				local egg = newEgg(kind)
				if egg then
					scaleEgg(egg, egg.size) -- (its real size)
					for _, part in egg.model:GetDescendants() do
						if part:IsA("BasePart") then
							part.CastShadow = false
						end
					end
				end
				held[tool] = egg or false
			end
			local egg = held[tool]
			if egg then
				-- upright, facing the way the character faces (its pivot is its base)
				local middle = handle.Position
					+ Vector3.new(0, HELD_UP * egg.size, 0)
					+ root.CFrame.LookVector * HELD_FORWARD * egg.size
				egg.model:PivotTo(CFrame.new(middle - Vector3.new(0, EGG_CENTER * egg.size, 0)) * root.CFrame.Rotation)
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
			ghost = newEgg(kind)
			if ghost then
				scaleEgg(ghost, ghost.size)
				for _, part in ghost.model:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = 0.6
					end
				end
			end
		end
	end
	if ghost then
		local area, x, z = spotAt(UserInputService:GetMouseLocation())
		ghost.model.Parent = if area then folder else nil
		if area then
			ghost.model:PivotTo(CFrame.new(floorAt(area, x, z)) * CFrame.Angles(0, facing(area), 0))
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

-- [id] = { egg, owner, kind, ready, at, yaw, grown, scale, timer, timerOn, prompt,
--          attachment, arrow, nextTwitch, hatching }
local shown = {}

-- An egg's time left: "2h" from an hour up (whole hours), else "m:ss".
local function countdown(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh", seconds // 3600)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function newTimer(parent)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(TIMER_SIZE.X, TIMER_SIZE.Y) -- (studs: smaller as you zoom out)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) -- above the egg (its root is at its base)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.Enabled = false -- (on only near you: nearTimer)
	gui.AlwaysOnTop = true -- (drawn over the egg, never hidden behind it)
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = gui
	gui.Parent = parent
	return text
end

-- How big an egg is by now: it grows from 1x when placed to GrowScale x when it's ready.
local function eggScale(s, now)
	local total = s.total or HATCH.Time[s.kind] or HATCH.Default
	local grown = math.clamp(1 - (s.ready - now) / total, 0, 1)
	return 1 + (HATCH.GrowScale - 1) * grown
end

-- grown: how far it's grown (eggScale); s.scale is that times the egg's own size
-- (bigger pets' eggs are bigger, Egg.sizeOf): how big it really is.
local function sizeEgg(s, grown)
	s.grown = grown
	s.scale = grown * s.egg.size
	scaleEgg(s.egg, s.scale)
	s.egg.model:PivotTo(CFrame.new(s.at) * CFrame.Angles(0, s.yaw, 0))
	if s.timer and s.timer.Parent then
		s.timer.Parent.StudsOffsetWorldSpace = Vector3.new(0, 4.6 * s.scale, 0)
	end
end

-- The big white arrow bobbing over one of your eggs that's ready to hatch, till you're
-- close enough for its prompt. One at a time: the egg that wanted it first.
local arrowFor = nil
local function readyArrow(s, show)
	if show and not s.arrow then
		local gui = Instance.new("BillboardGui")
		gui.Name = "ReadyArrow"
		gui.Size = UDim2.fromScale(7, 7)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Image = READY_ARROW
		image.Size = UDim2.fromScale(1, 1)
		image.Parent = gui
		gui.Parent = player:WaitForChild("PlayerGui")
		s.arrow = gui
	end
	if show and not arrowFor then
		arrowFor = s
	elseif not show and arrowFor == s then
		arrowFor = nil
	end
	if s.arrow then
		local on = show and arrowFor == s and s.egg ~= nil
		s.arrow.Adornee = if on then s.egg.model.PrimaryPart else nil
		s.arrow.Enabled = on
		s.arrow.StudsOffsetWorldSpace = Vector3.new(0, 14 + math.abs(math.sin(os.clock() * 3)) * 1.5, 0)
	end
end

-- While one of your eggs' prompts is up, everything else over the pen hides: the eggs'
-- countdowns and arrows here, and Ride (client/PenRide), on this client's EggPromptUp.
local eggPrompts = {}
ProximityPromptService.PromptShown:Connect(function(prompt)
	if prompt.Name == "HatchEgg" then
		eggPrompts[prompt] = true
		player:SetAttribute("EggPromptUp", true)
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if eggPrompts[prompt] then
		eggPrompts[prompt] = nil
		player:SetAttribute("EggPromptUp", next(eggPrompts) ~= nil)
	end
end)

local function dropPrompt(s)
	if s.prompt then
		eggPrompts[s.prompt] = nil
		player:SetAttribute("EggPromptUp", next(eggPrompts) ~= nil)
	end
	if s.attachment then
		s.attachment:Destroy()
	end
	s.attachment, s.prompt = nil, nil
end

local function show(owner, e, area)
	local egg = newEgg(e.k)
	if not egg then
		return
	end
	local s = {
		egg = egg,
		owner = owner,
		kind = e.k,
		ready = e.t,
		total = tonumber(e.d), -- (how long it grows: shorter with x2 Growth)
		at = floorAt(area, e.x, e.z),
		yaw = facing(area),
		nextTwitch = rng:NextNumber(TWITCH_EVERY[1], TWITCH_EVERY[2]),
	}
	shown[e.id] = s
	s.timer = newTimer(egg.model.PrimaryPart)
	if owner == player then
		-- Hold F by it once it's ready. (Kept outside the growing model: ScaleTo would
		-- scale its range too.)
		local rarity = Config.Pets[e.k] and Config.Pets[e.k].Rarity
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchEgg"
		prompt:SetAttribute("ObjectColor", rarity and Config.Rarities[rarity] and Config.Rarities[rarity].text) -- (its pet's rarity colour: client/PromptUi)
		prompt.ObjectText = Pets.name(e.k) .. " Egg"
		prompt.ActionText = "Hatch"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = HATCH.HoldTime
		prompt.Style = Enum.ProximityPromptStyle.Custom -- (Roblox's look without its panel: client/PromptUi)
		prompt.MaxActivationDistance = HATCH.Range
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		local attachment = Instance.new("Attachment")
		attachment.Name = "EggHatchPrompt"
		attachment.Position = area.CFrame:PointToObjectSpace(s.at + Vector3.new(0, 2, 0))
		attachment.Parent = area
		prompt.Parent = attachment
		prompt.Triggered:Connect(function()
			if not s.hatching and s.ready <= workspace:GetServerTimeNow() then
				hatchRemote:FireServer(e.id)
			end
		end)
		s.prompt, s.attachment = prompt, attachment
	end
	sizeEgg(s, eggScale(s, workspace:GetServerTimeNow()))
end

local function forget(id)
	local s = shown[id]
	if s and not s.hatching then
		shown[id] = nil
		dropPrompt(s)
		readyArrow(s, false)
		if s.arrow then
			s.arrow:Destroy()
		end
		if s.egg then
			s.egg.model:Destroy()
		end
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

-- The egg hatched (at server time `at`): it shakes, its top pops off at TOP_POPS as the
-- pet jumps out (BossView), and once the pet's out the empty shell fades away.
ReplicatedStorage:WaitForChild("Hatched").OnClientEvent:Connect(function(owner, id, kind, spot, at)
	local s = shown[id]
	if not s then
		-- (gone already: a fresh one where it stood, to hatch)
		local egg = newEgg(kind)
		if not egg or typeof(spot) ~= "Vector3" then
			return
		end
		local area = penArea(owner)
		s = { egg = egg, owner = owner, kind = kind, ready = 0, at = spot, yaw = area and facing(area) or 0 }
		shown[id] = s
		sizeEgg(s, HATCH.GrowScale)
	end
	s.hatching = true
	dropPrompt(s)
	readyArrow(s, false)
	if s.arrow then
		s.arrow:Destroy()
		s.arrow = nil
	end
	if s.timer and s.timer.Parent then
		s.timer.Parent:Destroy() -- the countdown
	end
	s.timer = nil
	sizeEgg(s, HATCH.GrowScale) -- (full grown as it hatches)
	local late = if type(at) == "number" then math.clamp(workspace:GetServerTimeNow() - at, 0, TOP_POPS) else 0
	if owner == player then
		-- timed so its climax lands as the pet jumps out, not as the hatch starts
		task.delay(math.max(TOP_POPS - HATCH_SOUND_PEAK - late, 0), RideSounds.play, "egg_hatch")
	end
	s.egg:play("hatch")
	s.egg.t = late
	-- the empty shell fades away once the pet is out
	task.delay(TOP_POPS + JUMP_TIME - late, function()
		local egg = s.egg
		if shown[id] ~= s or not egg then
			return
		end
		for _, part in egg.model:GetDescendants() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			s.hatching = nil
			forget(id)
		end)
	end)
end)

-- (a countdown pops in when you come near one, out when you leave; none while an egg's
-- prompt is up)
local function nearTimer(s, root)
	local egg = s.egg.model.PrimaryPart
	local d = if root and egg then ((egg.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude else math.huge
	local on = d <= (if s.timerOn then TIMER_LEAVE else TIMER_REACH) and not player:GetAttribute("EggPromptUp")
	if on ~= s.timerOn then
		s.timerOn = on
		local gui = s.timer.Parent
		if gui then
			gui.Enabled = on
		end
		if on then
			local pop = s.timer:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			pop.Scale = 0
			pop.Parent = s.timer
			TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	drawHeld()
	drawGhost()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for _, s in shown do
		if s.hatching then
			-- (holds its last frame, the top off, till the shell's faded)
			local anim = s.egg.playing
			if anim and s.egg.t + dt < anim.length then
				s.egg:update(dt)
			end
			continue
		end
		local ready = s.ready <= now
		s.timer.Text = if ready then "Ready" else countdown(s.ready - now)
		if s.prompt then
			s.prompt.Enabled = ready
		end
		readyArrow(s, ready and s.owner == player and not player:GetAttribute("EggPromptUp"))
		nearTimer(s, root)
		if not OnScreen.near(s.egg.model:GetPivot().Position, 8 * s.scale) then
			continue -- (off screen: not grown or twitching till it's back, QM Oct 27)
		end
		local grown = eggScale(s, now)
		if math.abs(grown - s.grown) > 0.004 then
			sizeEgg(s, grown)
		end
		s.nextTwitch -= dt
		if s.nextTwitch <= 0 and not s.egg:isPlaying() then
			s.egg:play("twitch")
			s.nextTwitch = rng:NextNumber(TWITCH_EVERY[1], TWITCH_EVERY[2])
		end
		s.egg:update(dt)
	end
end)

return nil
