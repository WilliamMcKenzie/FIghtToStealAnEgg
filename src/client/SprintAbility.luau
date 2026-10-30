-- How a sprint ability looks (QM, Oct 30; Config.SprintPets, Server/SprintAbility), on
-- every rider whose SprintAbility attribute is on. client/Riding lifts, sinks or grows
-- the pet itself; this adds the rest:
--   Burrow  LassoAPet's Sandworm burrow over where you are (client/BurrowFx: sand mounds
--           pushing up and sinking away behind you, dirt spraying), a burst of sand as you
--           dive in and come back up
--   Smash   a white outline and LassoAPet's charge wind (its Rhino's: sharp wind sheets
--           parting round the head, speed lines streaming past the body)
--   Bombs   an orange outline (the bombs themselves: client/Bombs, PetBomb)
-- (Fly needs nothing more: the pet's up in the air.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local function chargeFx(model)
	local root = model.PrimaryPart
	local middle, full = model:GetBoundingBox()
	local base = CFrame.new(root.CFrame:ToObjectSpace(middle).Position)
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
			if kind == "Smash" then
				table.insert(s.fx, outline(pet.model, cfg.Smash.Outline))
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
		if kind == "Smash" and not s.wind and math.abs(pet.scale - cfg.Smash.Grow) < 0.02 then
			s.wind = true
			for _, i in chargeFx(pet.model) do
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

return SprintAbility
