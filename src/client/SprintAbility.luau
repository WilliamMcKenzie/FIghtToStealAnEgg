-- How a sprint ability looks (QM, Oct 30; Config.SprintPets, Server/SprintAbility), on
-- every rider whose SprintAbility attribute is on. client/Riding lifts, sinks or grows
-- the pet itself; this adds the rest:
--   Burrow  LassoAPet's Sandworm burrow over where you are (client/BurrowFx: sand mounds
--           pushing up and sinking away behind you, dirt spraying), a burst of sand as you
--           dive in and come back up
--   Smash   a white outline and LassoAPet's charge wind (its Rhino's: sharp wind sheets
--           parting round the head, speed lines streaming past the body)
--   Bombs   an orange outline (the bombs themselves: client/Bombs, PetBomb)
--   Crabwalk  Smash's outline and wind, the wind breaking round its side
--   Leap    LassoAPet's Unicorn rainbow (its rainbowFx): bands of its Trail colours
--           streaming out behind it
--   Glow    LassoAPet's snakeGlow: the parts in Glow.Color (the Snake's horns and
--           spikes) turn Neon, their stud textures hidden so the glow shows
--   Frost   LassoAPet's Icebringer blizzard (its frostFx: a burst of snow, then snow
--           swirling round it), and every minion it's frozen (FrozenUntil, Server/
--           Minions) in a block of ice till it thaws (LassoAPet's setFrosted ice)
-- (Fly needs nothing more: the pet's up in the air.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local Riding = require(script.Parent.Riding)
local BurrowFx = require(script.Parent.BurrowFx)

local SprintAbility = {}

-- Charge VFX, as LassoAPet has them (from free Creator Store packs: the "Anime/Sharp Wind"
-- beam texture and the speed-line shard; only the texture ids are used)
local WIND_TEXTURE = "rbxassetid://17520182385"
local SHARD_TEXTURE = "rbxassetid://7216979807"
local WIND_SHEETS = 6 -- beams in the cone of air parting round the head

-- LassoAPet's chargeFx: a cone of sharp wind sheets sweeping back from the pet's nose,
-- and speed lines streaming past its body. Returns the instances to destroy after.
-- turn: radians the model is turned from the way it's going (a crab walking sideways,
-- pi / 2): the wind then breaks round its side.
local function chargeFx(model, turn)
	local root = model.PrimaryPart
	local middle, full = model:GetBoundingBox()
	local ahead = CFrame.Angles(0, -(turn or 0), 0) -- (from the way it's going to the model's own axes)
	if turn then
		full = Vector3.new(full.Z, full.Y, full.X) -- (going along its width)
		middle *= ahead
	end
	local base = CFrame.new(root.CFrame:ToObjectSpace(middle).Position) * ahead
	-- the nose: the front of the box (the model faces -Z), a little above the middle
	local nose = Vector3.new(0, full.Y * 0.1, -full.Z / 2 - 0.5)
	local radius = math.max(full.X, full.Y) * 0.95
	local length = full.Z * 0.9
	local fx = {}
	for k = 1, WIND_SHEETS do
		-- round the cone, missing the underside (the ground)
		local angle = math.rad(-110 + 220 * (k - 1) / (WIND_SHEETS - 1))
		local out = Vector3.new(math.sin(angle), math.cos(angle), 0) -- radial, 0 = straight up
		local around = Vector3.new(0, 0, -1):Cross(out)
		local a0 = Instance.new("Attachment")
		a0.CFrame = base * CFrame.fromMatrix(nose, out, around)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.CFrame = base * CFrame.fromMatrix(nose + out * radius + Vector3.new(0, 0, length), out, around)
		a1.Parent = root
		local beam = Instance.new("Beam")
		beam.Texture = WIND_TEXTURE
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		beam.TextureSpeed = 2.2 + 0.3 * (k % 2)
		beam.Width0, beam.Width1 = 0.8, radius * 1.5
		beam.CurveSize0, beam.CurveSize1 = radius * 0.7, 0
		beam.Segments = 16
		beam.LightInfluence = 0
		beam.LightEmission = 0.8
		beam.FaceCamera = false
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Parent = a0
		table.insert(fx, a0)
		table.insert(fx, a1)
	end
	-- speed lines streaming back past the whole body
	local shards = Instance.new("ParticleEmitter")
	shards.Texture = SHARD_TEXTURE
	shards.Orientation = Enum.ParticleOrientation.VelocityParallel
	shards.EmissionDirection = Enum.NormalId.Back -- (the model faces -Z: lines fly backwards)
	shards.Shape = Enum.ParticleEmitterShape.Box
	shards.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	shards.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	shards.Speed = NumberRange.new(90, 120)
	shards.Lifetime = NumberRange.new(0.12, 0.2)
	shards.Rate = 70
	shards.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 4), NumberSequenceKeypoint.new(1, 0) })
	shards.Squash = NumberSequence.new({ NumberSequenceKeypoint.new(0, -4), NumberSequenceKeypoint.new(1, -2.2) })
	shards.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	shards.LightEmission = 0.5
	shards.LockedToPart = false
	-- the box: the pet's size, a bit wider, so lines pass all round it
	local box = Instance.new("Part")
	box.Name = "SmashFx"
	box.Size = Vector3.new(full.X + 4, full.Y + 2, full.Z)
	box.Transparency = 1
	box.CanCollide, box.CanQuery, box.CanTouch, box.Massless = false, false, false, true
	box.CFrame = middle
	box.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = box, root
	weld.Parent = box
	box.Parent = model
	shards.Parent = box
	table.insert(fx, box)
	return fx
end

-- LassoAPet's rainbowFx: a band of each colour trailing off its back, stacked one over
-- another (no taller than a big horse's)
local function trailFx(model, colors)
	local root = model.PrimaryPart
	local middle, size = model:GetBoundingBox()
	local back = root.CFrame:ToObjectSpace(middle * CFrame.new(0, 0, size.Z * 0.3)) -- (toward its tail: it faces -Z)
	local tall = math.min(size.Y, 10)
	local band = tall * 0.6 / #colors
	local fx = {}
	for k, color in colors do
		local y = tall * 0.3 - (k - 1) * band
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.CFrame = back * CFrame.new(0, y, 0)
		a1.CFrame = back * CFrame.new(0, y - band, 0)
		a0.Parent, a1.Parent = root, root
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(color)
		trail.Lifetime = 0.8
		trail.MinLength = 0.2
		trail.LightEmission = 0.4
		trail.LightInfluence = 0
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.05),
			NumberSequenceKeypoint.new(0.8, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Parent = root
		table.insert(fx, trail)
		table.insert(fx, a0)
		table.insert(fx, a1)
	end
	return fx
end

-- LassoAPet's snakeGlow: the parts in `color` go Neon (their studs hidden), or back
local function glow(model, color, on, saved)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Color == color then
			if on then
				saved[part] = part.Material
				part.Material = Enum.Material.Neon
			elseif saved[part] then
				part.Material = saved[part]
			end
			for _, texture in part:GetChildren() do
				if texture:IsA("Texture") then
					texture.Transparency = if on then 1 else 0
				end
			end
		end
	end
end

local FLAKE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local FROST_TINT = Color3.fromRGB(150, 215, 255)
local ICE_COLOR = Color3.fromRGB(170, 225, 255)

local function flakes(rate, speed, life, sizeMax)
	local e = Instance.new("ParticleEmitter")
	e.Texture = FLAKE_TEXTURE
	e.Color = ColorSequence.new(Color3.new(1, 1, 1), FROST_TINT)
	e.LightEmission = 0.7
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, sizeMax), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.6) })
	e.Lifetime = life
	e.Speed = speed
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Rate = rate
	return e
end

-- LassoAPet's frostFx: a burst of snow thrown out low all round, then snow falling and
-- blowing round the pet while it lasts
local function frostFx(model)
	local root = model.PrimaryPart
	local middle, size = model:GetBoundingBox()
	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch = true, false, false, false
	burst.Transparency = 1
	burst.Size = Vector3.one
	burst.CFrame = CFrame.new(middle.Position.X, middle.Position.Y - size.Y / 2 + 2, middle.Position.Z)
	burst.Parent = workspace
	local blast = flakes(0, NumberRange.new(40, 70), NumberRange.new(0.6, 1.1), 2.4)
	blast.SpreadAngle = Vector2.new(180, 15)
	blast.EmissionDirection = Enum.NormalId.Top
	blast.Drag = 3
	blast.Parent = burst
	blast:Emit(140)
	task.delay(1.5, burst.Destroy, burst)
	local box = Instance.new("Part")
	box.Name = "FrostFx"
	box.Size = Vector3.new(size.X + 16, 1, size.Z + 16)
	box.Transparency = 1
	box.CanCollide, box.CanQuery, box.CanTouch, box.Massless = false, false, false, true
	box.CFrame = middle * CFrame.new(0, size.Y / 2 + 4, 0)
	box.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = box, root
	weld.Parent = box
	box.Parent = model
	local swirl = flakes(90, NumberRange.new(4, 9), NumberRange.new(1, 1.6), 1.2)
	swirl.Shape = Enum.ParticleEmitterShape.Box
	swirl.EmissionDirection = Enum.NormalId.Bottom
	swirl.SpreadAngle = Vector2.new(35, 35)
	swirl.Acceleration = Vector3.new(0, -4, 0)
	swirl.Parent = box
	return { box }
end

local function outline(model, color)
	local h = Instance.new("Highlight")
	h.Name = "SprintOutline"
	h.Adornee = model
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.OutlineColor = color
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	return h
end

local shown = {} -- [character] = { kind, model, fx = { instances }, mound }

local function clear(s)
	for _, i in s.fx do
		i:Destroy()
	end
	if s.glow and s.model.Parent then
		glow(s.model, Config.SprintAbility.Glow.Color, false, s.glow)
	end
	if s.mound then
		s.mound:stop()
	end
end

local function groundUnder(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) then
		return nil
	end
	return root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
end

RunService.RenderStepped:Connect(function()
	local cfg = Config.SprintAbility
	local seen = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local pet = character and Riding.pet(character)
		local kind = pet and player:GetAttribute("SprintAbility")
		if not (kind and pet.model.Parent) then
			continue
		end
		seen[character] = true
		local s = shown[character]
		if s and (s.kind ~= kind or s.model ~= pet.model) then
			clear(s)
			s = nil
		end
		if not s then
			s = { kind = kind, model = pet.model, fx = {} }
			shown[character] = s
			if kind == "Smash" or kind == "Crabwalk" then
				table.insert(s.fx, outline(pet.model, cfg.Smash.Outline))
			elseif kind == "Leap" then
				local colors = cfg.Leap.Trail[player:GetAttribute("Pet")] or cfg.Leap.Trail.Unicorn
				s.fx = trailFx(pet.model, colors)
			elseif kind == "Glow" then
				s.glow = {}
				glow(pet.model, cfg.Glow.Color, true, s.glow)
			elseif kind == "Frost" then
				s.fx = frostFx(pet.model)
			elseif kind == "Bombs" then
				table.insert(s.fx, outline(pet.model, cfg.Bombs.Outline))
			elseif kind == "Burrow" then
				local ground = groundUnder(character)
				local pk = player:GetAttribute("Pet")
				s.sand = { cfg.Burrow.Sand[pk] or cfg.Burrow.Sand.Sandworm, cfg.Burrow.Sand2[pk] or cfg.Burrow.Sand2.Sandworm }
				if ground then
					BurrowFx.burst(ground, pet.height or 6, s.sand[1])
				end
				s.mound = BurrowFx.mound(cfg.Burrow.Mound, s.sand)
			end
		end
		-- (the wind once it's grown, so it fits the bigger pet)
		if (kind == "Smash" or kind == "Crabwalk") and not s.wind and math.abs(pet.scale - cfg.Smash.Grow) < 0.02 then
			s.wind = true
			for _, i in chargeFx(pet.model, if kind == "Crabwalk" then math.rad(cfg.Crabwalk.Turn) else nil) do
				table.insert(s.fx, i)
			end
		end
		if s.mound then
			local ground = groundUnder(character)
			if ground then
				s.mound:place(ground)
			end
		end
	end
	for character, s in shown do
		if not seen[character] then
			if s.kind == "Burrow" and character.Parent then
				local ground = groundUnder(character)
				if ground then
					BurrowFx.burst(ground, 6, s.sand[1]) -- (back up out of the ground)
				end
			end
			clear(s)
			shown[character] = nil
		end
	end
end)

-- the minions an Icebringer's frozen: each in a block of ice over where it stands, popping
-- in, melting away once it thaws
local ice = {} -- [body] = part
RunService.Heartbeat:Connect(function()
	local mobs = workspace:FindFirstChild("Mobs")
	local now = workspace:GetServerTimeNow()
	if mobs then
		for _, body in mobs:GetChildren() do
			local frozen = body:IsA("BasePart") and (body:GetAttribute("FrozenUntil") or 0) > now
			if frozen and not ice[body] then
				local r = body:GetAttribute("Radius") or 3
				local block = Instance.new("Part")
				block.Name = "Ice"
				block.Anchored, block.CanCollide, block.CanQuery, block.CanTouch = true, false, false, false
				block.CastShadow = false
				block.Material = Enum.Material.Ice
				block.Color = ICE_COLOR
				block.Transparency = 0.35
				block.Size = Vector3.new(r * 2.2, r * 2, r * 2.2) * 0.6
				block.CFrame = CFrame.new(body.Position.X, body.Position.Y - body.Size.Y / 2 + r, body.Position.Z)
				block.Parent = workspace
				TweenService:Create(block, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = block.Size / 0.6 }):Play()
				ice[body] = block
			end
		end
	end
	for body, block in ice do
		if not (body.Parent and (body:GetAttribute("FrozenUntil") or 0) > now) then
			ice[body] = nil
			TweenService:Create(block, TweenInfo.new(0.3), { Size = block.Size * Vector3.new(0.6, 0.05, 0.6), Transparency = 1 }):Play()
			task.delay(0.3, block.Destroy, block)
		end
	end
end)

return SprintAbility
