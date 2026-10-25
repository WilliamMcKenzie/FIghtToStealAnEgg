-- Eggs built from Blockbench models (QM, Oct 25: LassoAPet's eggs, one per animal):
-- designs/eggs/<Kind>Egg.bbmodel, converted to <Kind>EggModel.luau beside this by
-- tools/bbmodel_to_luau.py. Every egg shares the same bones (egg, bottom, top), so its
-- AFK twitch and its hatch (for when hatching comes) fit them all.
--
--   local egg = Egg.new("Horse", scale)   -- scale: times the drawing (default 1)
--   egg.model:PivotTo(cframe)           -- pivot is the egg's base, on the ground
--   egg:play("twitch")                  -- a quick wobble (or "hatch")
--   egg:update(dt)                      -- every frame while it may be playing
--   Egg.kinds() -> { "Bat", ... }       -- every egg there's a model for
--
-- The black plates on the crack faces stay hidden inside the egg until the top shell
-- pops off.

local Rig = require(script.Parent.Parent.Rig)
local Studs = require(script.Parent.Parent.Studs)

-- classic stud decal, the same one the animals use
local STUD_TEXTURE = { image = "rbxassetid://7447638591", tile = 0.5 }

local KINDS = {} -- [kind] = model data
for _, module in script.Parent:GetChildren() do
	local kind = string.match(module.Name, "^(.+)EggModel$")
	if kind and module:IsA("ModuleScript") then
		KINDS[kind] = require(module)
	end
end

local Egg = {}
Egg.__index = Egg

function Egg.kinds()
	local out = {}
	for kind in KINDS do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end

function Egg.has(kind)
	return KINDS[kind] ~= nil
end

function Egg.new(kind, scale)
	local data = KINDS[kind] or KINDS.Horse
	local model, _, bones = Rig.fromData(data, kind .. "Egg", STUD_TEXTURE)
	model.PrimaryPart.PivotOffset = CFrame.identity
	scale = scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
		Studs.fit(model, STUD_TEXTURE.tile * scale)
	end
	return setmetatable({
		model = model,
		kind = kind,
		animations = data.animations,
		bones = bones,
		playing = nil,
		t = 0,
	}, Egg)
end

function Egg:play(name)
	self.playing = self.animations[name]
	self.t = 0
end

function Egg:isPlaying()
	return self.playing ~= nil
end

function Egg:update(dt)
	local anim = self.playing
	if not anim then
		return
	end
	self.t += dt
	local done = self.t >= anim.length
	local s = self.model:GetScale() -- (the animations are in studs at 1x)
	for bone, motor in pairs(self.bones) do
		local track = anim.tracks[bone]
		if done or not track then
			motor.Transform = CFrame.identity
		else
			local px, py, pz = 0, 0, 0
			local rx, ry, rz = 0, 0, 0
			if track.position then
				px, py, pz = Rig.sample(track.position, self.t)
			end
			if track.rotation then
				rx, ry, rz = Rig.sample(track.rotation, self.t)
			end
			motor.Transform = CFrame.new(px * s, py * s, pz * s) * CFrame.Angles(rx, ry, rz)
		end
	end
	if done then
		self.playing = nil
	end
end

return Egg
