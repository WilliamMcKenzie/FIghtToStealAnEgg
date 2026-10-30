-- Horse: the mount every player rides (copied from Lasso For Eggs' animal driver).
-- The shape, bones and animations come from QM's Blockbench model
-- (designs/Horse.bbmodel), converted into Animals/HorseModel.luau by
--   python3 tools/bbmodel_to_luau.py --zyx designs/Horse.bbmodel src/shared/Animals/HorseModel.luau
-- Units are studs; the horse faces -Z. Every pet, the horse too, is sized like LassoAPet's
-- (tierSize below), so Lasso's seats and riding positions carry over as they are.
--
--   local horse = Horse.new()
--   horse.model.Parent = workspace
--   horse:update(dt, speed, turn) -- every frame; speed in studs/s, turn -1..1 (+ = right);
--                                 -- returns true on the frame a gallop leap lands
--   horse:getSeatCFrame()         -- where the rider's hips go
--   horse:setSaddled(true)        -- no saddle on this design; kept for callers
--   horse:getNeck()               -- { cframe, radius } for a lasso loop around the neck
--   horse:setScale(s)             -- grow or shrink the whole horse about its feet (pop-ins)
--   horse:playOnce(name, rate)    -- play one of its other animations once over the blend
--                                 -- (the Loong's "special" fire breath)
--
-- Every other animal (Pinto, Pig, Fish, Rhino, Unicorn) shares all of this and
-- only swaps the model data, plus its seat and neck-loop points if they differ
-- from the horse's (designs/animals/meta.json):
--   Horse.variant("Pinto", PintoModel, "Uncommon")
--   Horse.variant("Pig", PigModel, "Uncommon", { seat = ..., neck = { center = ..., radius = ... } })
--
-- Idle, walk and gallop are blended by speed. The gallop is a leap: front legs
-- reach forward and hind legs back while the horse is in the air. The blocks
-- only ever rotate one way from rest (front legs and neck forward, hind legs
-- back), so blending never shows hidden faces.

local Config = require(script.Parent.Parent.Config)
local Rig = require(script.Parent.Parent.Rig)
local HorseModel = require(script.Parent.HorseModel)

-- Classic stud decal from the Creator Store (asset 7447638611), tiled at half-stud size.
local STUD_TEXTURE = { image = "rbxassetid://7447638591", tile = 0.5 }

local SEAT = Vector3.new(0, 7.3, 1) -- rider hips, on the back stripe
local NECK_LOOP = { center = Vector3.new(0, 7.4, -1.9), radius = 1.35 }

-- Blending by speed (studs/s)
local WALK_IN = 6 -- idle -> walk fully in
local GALLOP_FROM, GALLOP_IN = 12, 24 -- walk -> gallop
local WALK_SPEED = 8 -- walk plays at 1x at this speed
local GALLOP_SPEED = 36 -- gallop plays at 1x at this speed
local LEAN = 0.18 -- body roll into turns, radians at full gallop
local ONCE_FADE_IN, ONCE_FADE_OUT = 0.15, 0.3 -- seconds a playOnce animation blends in and out

-- When a gallop leap lands: the front legs are back at rest after reaching out.
-- nil for animals without legs (the Fish), which never kick up dust.
local function landAt(data)
	local legs = data.animations.gallop.tracks.LegFL
	if not (legs and legs.rotation) then
		return nil
	end
	local reached = false
	for _, key in legs.rotation.keys do
		if key[2] ~= 0 then
			reached = true
		elseif reached then
			return key[1]
		end
	end
	return 0
end

local function clamp01(x)
	return math.max(0, math.min(1, x))
end

local Horse = {} -- the methods every variant shares

-- A model's box at its own size, in studs (x wide, y tall, z long).
local function extent(data)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in data.parts do
		if not part.hidden then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.cframe:GetComponents()
			local h = part.size / 2
			local e = Vector3.new(
				math.abs(r00) * h.X + math.abs(r01) * h.Y + math.abs(r02) * h.Z,
				math.abs(r10) * h.X + math.abs(r11) * h.Y + math.abs(r12) * h.Z,
				math.abs(r20) * h.X + math.abs(r21) * h.Y + math.abs(r22) * h.Z
			)
			local c = Vector3.new(x, y, z)
			lo, hi = lo:Min(c - e), hi:Max(c + e)
		end
	end
	return hi - lo
end

-- How big a model reads: the square root of its box's two biggest sides multiplied (so a
-- long snake and a tall cactus compare fairly; LassoAPet's sizing).
local function silhouette(data)
	local d = extent(data)
	local sides = { d.X, d.Y, d.Z }
	table.sort(sides)
	return math.sqrt(sides[2] * sides[3])
end

-- A pet's size from its model, exactly LassoAPet's (QM, Oct 27: the same sizes as there): a
-- tier 1 pet reads Config.PetStats.SmallSize studs (the Horse at its drawing's own size),
-- each tier up Config.PetStats.TierGrowth x the one below.
local function tierSize(name, data)
	local pet = Config.Pets[name]
	local tier = pet and pet.Tier or 1
	local size = Config.PetStats.SmallSize * Config.PetStats.TierGrowth ^ (tier - 1) / silhouette(data)
	return math.round(size * 100) / 100 -- (one template per animal: Rig caches by size)
end

-- A kind of animal: its own model data and rarity, Horse's methods.
-- points (optional): { seat = Vector3, neck = { center = Vector3, radius = number },
-- seatOnNeck = true (the seat rides on the neck bone, e.g. a squid's mantle, which
-- its run swings about: the rider moves with it but stays upright),
-- seatBone = bone name (the same, on any bone: the Loong's saddle is on its chest,
-- which its slither swings about),
-- size = number (the whole animal scaled from its model; by default sized to its tier,
-- Config.Pets), gallopOnSprint = true (its gallop only while it's ridden
-- at a sprint, its walk otherwise) }
local function variant(name, data, rarity, points)
	points = points or {}
	local class = setmetatable({
		Name = name,
		Rarity = rarity, -- sets the coins for lassoing one (Config.RarityCoins)
		data = data,
		landAt = landAt(data),
		seat = points.seat or SEAT,
		seatOnNeck = points.seatOnNeck,
		seatBone = points.seatBone,
		gallopOnSprint = points.gallopOnSprint, -- gallops only while self.sprinting (Ride sets it)
		gallopOnly = points.gallopOnly, -- never walks: gallops whenever it moves (QM, Oct 23)
		neckLoop = points.neck or NECK_LOOP,
		-- (x Config.AnimalScale: how big it looks, QM, Oct 11)
		size = (points.size or tierSize(name, data)) * (Config.AnimalScale[name] or 1),
	}, { __index = Horse })
	class.__index = class

	function class.new()
		local model, byName, bones, pivots = Rig.fromData(data, name, STUD_TEXTURE, class.size)

		local clocks = {}
		for anim in pairs(data.animations) do
			clocks[anim] = 0
		end

		-- Reused every frame (see update): one { x, y, z, rx, ry, rz } per bone.
		local pose = {}
		for bone in pairs(bones) do
			pose[bone] = { 0, 0, 0, 0, 0, 0 }
		end
		pose.root = pose.root or { 0, 0, 0, 0, 0, 0 }

		return setmetatable({
			model = model,
			root = byName.rootBone,
			neck = byName.neckBone,
			seatPart = points.seatBone and byName[points.seatBone .. "Bone"],
			pivots = pivots,
			bones = bones,
			clocks = clocks,
			pose = pose,
			-- What ScaleTo calls this model's own size (class.size, if the copy kept
			-- its template's scale factor), so setScale works either way.
			baseScale = model:GetScale(),
			speed = 0,
			turn = 0,
			scale = 1,
		}, class)
	end

	return class
end

function Horse:update(dt, speed, turn)
	local k = clamp01(dt * 6)
	self.speed += (math.max(0, speed or 0) - self.speed) * k
	self.turn += (math.clamp(turn or 0, -1, 1) - self.turn) * k
	local s = self.speed

	local moving = clamp01(s / WALK_IN)
	local galloping = if self.gallopOnly then 1 else clamp01((s - GALLOP_FROM) / (GALLOP_IN - GALLOP_FROM))
	if self.gallopOnSprint and not self.sprinting then
		galloping = 0 -- (the Kraken: its gallop only while you sprint on it, else its walk; QM)
	end
	-- No tables made here: this runs for every animal every frame, and fresh
	-- tables each time pile up garbage that the collector stops the game to clear.
	local wIdle, wWalk, wGallop = 1 - moving, moving * (1 - galloping), moving * galloping
	local rWalk, rGallop = math.clamp(s / WALK_SPEED, 0.6, 1.8), math.clamp(s / GALLOP_SPEED, 0.8, 1.4)

	-- A one-shot (playOnce) fades in over the blend and back out at its end.
	local once = self.once
	local wOnce = 0
	if once then
		once.t += dt * once.rate
		local length = self.data.animations[once.name].length
		if once.t >= length then
			self.once, once = nil, nil
		else
			wOnce = math.min(1, once.t / ONCE_FADE_IN, (length - once.t) / ONCE_FADE_OUT)
		end
	end

	local before = self.clocks.gallop
	local pose = self.pose
	for _, p in pairs(pose) do
		p[1], p[2], p[3], p[4], p[5], p[6] = 0, 0, 0, 0, 0, 0
	end
	for name, anim in pairs(self.data.animations) do
		local w, rate = 0, 1
		if name == "idle" then
			w = wIdle
		elseif name == "walk" then
			w, rate = wWalk, rWalk
		elseif name == "gallop" then
			w, rate = wGallop, rGallop
		end
		self.clocks[name] = (self.clocks[name] + dt * rate) % anim.length
		local t = self.clocks[name]
		if once and name == once.name then
			w, t = wOnce, once.t
		else
			w *= 1 - wOnce
		end
		if w > 0 then
			for bone, track in pairs(anim.tracks) do
				local p = pose[bone]
				if not p then
					p = { 0, 0, 0, 0, 0, 0 } -- x, y, z, rx, ry, rz
					pose[bone] = p
				end
				if track.position then
					local x, y, z = Rig.sample(track.position, t)
					p[1] += x * w
					p[2] += y * w
					p[3] += z * w
				end
				if track.rotation then
					local x, y, z = Rig.sample(track.rotation, t)
					p[4] += x * w
					p[5] += y * w
					p[6] += z * w
				end
			end
		end
	end

	-- roll into turns (+turn = right)
	local rootPose = pose.root
	rootPose[6] -= LEAN * self.turn * (0.4 + 0.6 * galloping)

	local sc = self.scale * self.size -- animation offsets are in studs at the model's own size
	for bone, motor in pairs(self.bones) do
		local p = pose[bone]
		motor.Transform = CFrame.new(p[1] * sc, p[2] * sc, p[3] * sc) * CFrame.Angles(p[4], p[5], p[6])
	end

	local after = self.clocks.gallop
	local land = self.landAt
	if not land then
		return false
	end
	local crossed = if after >= before then before < land and after >= land else before < land or after >= land
	return crossed and wGallop > 0.5
end

function Horse:getSeatCFrame()
	if self.seatPart then
		local at = self.seatPart.CFrame * CFrame.new((self.seat - self.pivots[self.seatBone]) * self.size * self.scale)
		return CFrame.new(at.Position) * self.model.PrimaryPart.CFrame.Rotation
	end
	-- (scaled with the animal too: the seat rises as it grows, e.g. the Robo Shark's hunt)
	if self.seatOnNeck then
		local at = self.neck.CFrame * CFrame.new((self.seat - self.pivots.neck) * self.size * self.scale)
		return CFrame.new(at.Position) * self.root.CFrame.Rotation
	end
	return self.root.CFrame * CFrame.new((self.seat - self.pivots.root) * self.size * self.scale)
end

function Horse:getNeck()
	local loop = self.neckLoop
	local k = self.size * self.scale -- (at the size it really is)
	return { cframe = self.neck.CFrame * CFrame.new((loop.center - self.pivots.neck) * k), radius = loop.radius * k }
end

function Horse:setSaddled(_saddled) end

-- Plays one of this animal's own animations (not idle, walk or gallop) once, over
-- whatever it's doing; ignored if it has no animation of that name. rate: how fast
-- (a boss's attack plays so its `hit` lands as the attack does: client/BossView).
function Horse:playOnce(name, rate)
	if self.data.animations[name] then
		self.once = { name = name, t = 0, rate = rate or 1 }
	end
end

-- Model:ScaleTo scales relative to the current size, so keep it well above the
-- smallest part size (0.001): the thinnest plates are 0.05 studs.
local MIN_SCALE = 0.05

-- s is relative to the animal's own size (its `size` point).
function Horse:setScale(s)
	s = math.max(s, MIN_SCALE)
	if s ~= self.scale then
		self.model:ScaleTo(s * self.baseScale)
		self.scale = s
	end
end

-- Rebirths and the Giant Pets pass (QM, Oct 13): your pets are k x their own size
-- everywhere (k in all: a later call sets it again, not on top). Its own size grows, so
-- every later setScale, its animations, its seat and its neck loop all scale with it.
function Horse:grow(k)
	local was = self.grown or 1
	if k == was then
		return
	end
	self.grown = k
	self.size *= k / was
	self.baseScale *= k / was
	self.model:ScaleTo(self.scale * self.baseScale)
end

local Common = variant("Horse", HorseModel, "Common", { gallopOnly = true })
Common.variant = variant
Common.extent = extent
return Common
