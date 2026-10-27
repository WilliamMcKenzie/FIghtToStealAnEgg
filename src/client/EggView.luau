-- Draws every egg (QM, Oct 25): the server only has an invisible box where each egg stands
-- (tagged "Egg": in a nest, on a back, in a pen; Server/Eggs), with its animal in EggKind
-- and its size in EggScale. Here each gets LassoAPet's egg for that animal (Shared/Eggs),
-- stood on the box's bottom face and following it, twitching now and then while it waits
-- (its AFK animation; the hatch one is there for when hatching comes).
-- A nest's egg pops in when its nests refill (PopAt: the server time it pops, QM Oct 26):
-- it springs up out of the nest with a hop, a spin and a puff of sparkles. When its
-- fight's over (Vanish) it shrinks away.
-- A nest's egg has its name and rarity floating over it (QM, Oct 27: "Rhino Egg" in white,
-- "Epic" under it in its rarity's colour), there once it's popped in, gone as it vanishes.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Egg = require(Shared.Eggs.Egg)
local Pets = require(Shared.Pets)
local OnScreen = require(script.Parent.OnScreen)

local TWITCH = Config.Eggs.Twitch
local POP = 0.55 -- seconds: an egg's pop in
local VANISH = 0.3 -- seconds: shrinking away
-- the nest egg's label: outlined Montserrat (QM's UI), in studs so it shrinks with distance
local LABEL_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local LABEL_SIZE = Vector2.new(10, 3.2) -- studs: both lines
local LABEL_ABOVE = 1.2 -- studs over the egg's top
local LABEL_RANGE = 90 -- studs it shows within

local views = {} -- [box] = { egg, next twitch (clock), scale, popAt, popped, vanish }

-- a back-out spring: 0 to 1, overshooting a little on the way
local function spring(t)
	local c1 = 2.2
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function puff(at, size)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one
	part.CFrame = CFrame.new(at)
	local e = Instance.new("ParticleEmitter") -- (Roblox's default sparkle texture)
	e.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190), Color3.fromRGB(255, 255, 255))
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.6 * size, 0)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(6, 11)
	e.Drag = 5
	e.Acceleration = Vector3.new(0, -12, 0)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rate = 0
	e.Parent = part
	part.Parent = workspace
	e:Emit(16)
	task.delay(1, part.Destroy, part)
end

local function line(parent, text, colour, y, height)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, y)
	label.Size = UDim2.fromScale(1, height)
	label.FontFace = LABEL_FONT
	label.TextScaled = true
	label.TextColor3 = colour
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.Parent = parent
end

-- "Rhino Egg" over "Epic" (its rarity's colour), over a nest's egg
local function nestLabel(box, kind)
	local pet = Config.Pets[kind]
	local rarity = pet and pet.Rarity or "Common"
	local colours = Config.Rarities[rarity] or Config.Rarities.Common
	local board = Instance.new("BillboardGui")
	board.Name = "EggLabel"
	board.Size = UDim2.fromScale(LABEL_SIZE.X, LABEL_SIZE.Y)
	board.StudsOffsetWorldSpace = Vector3.new(0, box.Size.Y / 2 + LABEL_ABOVE + LABEL_SIZE.Y / 2, 0)
	board.MaxDistance = LABEL_RANGE
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.Adornee = box
	line(board, Pets.name(kind) .. " Egg", Color3.new(1, 1, 1), 0, 0.52)
	line(board, rarity, colours.Fill, 0.52, 0.48)
	board.Parent = box
	return board
end

local function add(box)
	if views[box] or not box:IsA("BasePart") then
		return
	end
	local ok, egg = pcall(Egg.new, box:GetAttribute("EggKind") or "Horse", box:GetAttribute("EggScale") or 1)
	if not ok then
		warn("EggView: " .. tostring(egg))
		return
	end
	for _, part in egg.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	local view = { egg = egg, nextTwitch = os.clock() + math.random() * TWITCH[2], scale = egg.model:GetScale() }
	-- (only one that's popping about now: a later joiner just sees it there)
	local popAt = box:GetAttribute("PopAt")
	if popAt and popAt > workspace:GetServerTimeNow() - POP then
		view.popAt = popAt
		egg.model:ScaleTo(view.scale * 0.05)
	end
	egg.model.Parent = if view.popAt then nil else workspace
	if box.Parent and CollectionService:HasTag(box.Parent, "Nest") then
		view.label = nestLabel(box, box:GetAttribute("EggKind") or "Horse")
		view.label.Enabled = view.popAt == nil and not box:GetAttribute("Vanish")
	end
	views[box] = view
end

local function remove(box)
	local view = views[box]
	views[box] = nil
	if not view then
		return
	end
	if not view.vanish then
		view.egg.model:Destroy()
		return
	end
	-- (vanishing: finish shrinking where it stood)
	local model = view.egg.model
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - view.vanish) / VANISH
		if t >= 1 or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			return
		end
		model:ScaleTo(math.max(0.02, view.scale * (1 - t) ^ 2))
	end)
end

CollectionService:GetInstanceAddedSignal("Egg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Egg"):Connect(remove)
for _, box in CollectionService:GetTagged("Egg") do
	add(box)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for box, view in views do
		if not box.Parent then
			remove(box)
			continue
		end
		local egg = view.egg
		local base = box.CFrame * CFrame.new(0, -box.Size.Y / 2, 0)
		if view.popAt then
			-- popping in: springs up out of the nest, hops and spins once
			local t = (workspace:GetServerTimeNow() - view.popAt) / POP
			if t < 0 then
				continue
			end
			if not view.popped then
				view.popped = true
				egg.model.Parent = workspace
				puff(base.Position + Vector3.new(0, box.Size.Y * 0.4, 0), view.scale)
			end
			if t >= 1 then
				view.popAt = nil
				egg.model:ScaleTo(view.scale)
				if view.label then
					view.label.Enabled = true
				end
			else
				egg.model:ScaleTo(math.max(0.05, view.scale * spring(t)))
				local hop = math.sin(math.min(t * 1.4, 1) * math.pi) * box.Size.Y * 0.5
				base = base * CFrame.new(0, hop, 0) * CFrame.Angles(0, (1 - t) ^ 2 * math.pi * 2, 0)
			end
		elseif box:GetAttribute("Vanish") and not view.vanish then
			view.vanish = os.clock()
			view.scale = egg.model:GetScale()
			if view.label then
				view.label.Enabled = false
			end
		end
		if view.vanish then
			local t = math.min(1, (os.clock() - view.vanish) / VANISH)
			egg.model:ScaleTo(math.max(0.02, view.scale * (1 - t) ^ 2))
		end
		-- (only moved when its spot does: QM Oct 27, every egg's parts moved every frame lagged)
		if view.placed ~= base then
			view.placed = base
			egg.model:PivotTo(base)
		end
		if not OnScreen.near(base.Position, 8) then
			continue -- (off screen: no twitching)
		end
		if now >= view.nextTwitch then
			egg:play("twitch")
			view.nextTwitch = now + TWITCH[1] + math.random() * (TWITCH[2] - TWITCH[1])
		end
		egg:update(dt)
	end
end)

return nil
