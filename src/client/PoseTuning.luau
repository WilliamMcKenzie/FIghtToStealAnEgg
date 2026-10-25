-- Live pose tuning (QM, Oct 25): Workspace > Pose holds how the weapon you're holding sits
-- in your hand and how you ride with it, as attributes, while you play (in Studio, or as
-- the game's owner). Change one in the Properties panel (Client view: it's made here) and
-- you see it straight away; /weapon <name> to hold another and its values replace these.
--
--   GripAngle    turns the weapon in the hand (degrees X, Y, Z)
--   GripOffset   slides it in the hand (studs; Y is along the handle)
--   Waist, Neck, RightShoulder, RightElbow, RightWrist, LeftShoulder, LeftElbow
--                each joint's riding pose (degrees X, Y, Z: Config.RidePose explains them)
--   Still        holds the pose still (no breathing or gallop bob) while you tune
--
-- Only you see it while tuning (the grip and pose aren't sent to the server). Values last
-- until Play stops: tick PrintConfig to print the weapon's block, ready to paste into
-- Config.WeaponPoses (or send to Claude); tick Reset to go back to Config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons.Weapons)
local SwingPose = require(script.Parent.SwingPose)

local player = Players.LocalPlayer

if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
	return {}
end

local JOINTS = { "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow" }
local ORDER = { "GripAngle", "GripOffset", table.unpack(JOINTS) }

-- each weapon's pose as Config had it, for Reset
local original = {}
for id, pose in Config.WeaponPoses do
	original[id] = table.clone(pose)
end

local folder = Instance.new("Configuration")
folder.Name = "Pose"
folder.Parent = workspace

local shown = nil
local quiet = false -- (while this script writes the attributes itself)

local function held()
	local id = player:GetAttribute("Weapon")
	return if Weapons.exists(id) then id else Config.WeaponDrops.Start
end

-- every value of weapon `id`'s pose: its own, else the default
local function value(id, key)
	local own = Config.WeaponPoses[id]
	if own and own[key] then
		return own[key]
	end
	if key == "GripAngle" or key == "GripOffset" then
		return Config.WeaponGrip[key]
	end
	local j = Config.RidePose.Joints[key]
	return Vector3.new(j.X, j.Y, j.Z)
end

-- the held tool's grip (and its weld, already made) follows the tuned values
local function regrip(id)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not (tool and tool:GetAttribute("Weapon") == id) then
		return
	end
	local grip = Weapons.grip(id)
	tool.Grip = grip
	local hand = character:FindFirstChild("RightHand")
	local weld = hand and hand:FindFirstChild("RightGrip")
	if weld and weld:IsA("JointInstance") then
		weld.C1 = grip
	end
end

local function show(id)
	quiet = true
	for name in folder:GetAttributes() do
		folder:SetAttribute(name, nil)
	end
	shown = id
	folder:SetAttribute("Weapon", Weapons.get(id).Name)
	folder:SetAttribute("Still", SwingPose.still)
	folder:SetAttribute("PrintConfig", false)
	folder:SetAttribute("Reset", false)
	for _, key in ORDER do
		folder:SetAttribute(key, value(id, key))
	end
	quiet = false
end

local function literal(v)
	local function n(x)
		x = math.round(x * 100) / 100
		return if x == math.floor(x) then string.format("%d", x) else tostring(x)
	end
	return string.format("Vector3.new(%s, %s, %s)", n(v.X), n(v.Y), n(v.Z))
end

local function source(id)
	local lines = { "\t\t" .. id .. " = {" }
	for _, key in ORDER do
		table.insert(lines, "\t\t\t" .. key .. " = " .. literal(value(id, key)) .. ",")
	end
	table.insert(lines, "\t\t},")
	return table.concat(lines, "\n")
end

folder.AttributeChanged:Connect(function(name)
	if quiet or not shown then
		return
	end
	local id = shown
	local v = folder:GetAttribute(name)
	if name == "PrintConfig" then
		if v then
			print("-- " .. Weapons.get(id).Name .. ", for Config.WeaponPoses:\n" .. source(id))
			quiet = true
			folder:SetAttribute("PrintConfig", false)
			quiet = false
		end
	elseif name == "Reset" then
		if v then
			Config.WeaponPoses[id] = if original[id] then table.clone(original[id]) else nil
			regrip(id)
			show(id)
		end
	elseif name == "Still" and type(v) == "boolean" then
		SwingPose.still = v
	elseif table.find(ORDER, name) and typeof(v) == "Vector3" then
		local own = Config.WeaponPoses[id] or {}
		own[name] = v
		Config.WeaponPoses[id] = own
		if name == "GripAngle" or name == "GripOffset" then
			regrip(id)
		end
	else
		show(id) -- (a label, not a value it has, or the wrong type: put it back)
	end
end)

player:GetAttributeChangedSignal("Weapon"):Connect(function()
	show(held())
end)
-- (a new tool is made with Config's grip: put the tuned one back on it)
local function watch(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("Weapon") then
			task.defer(regrip, child:GetAttribute("Weapon"))
		end
	end)
end
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
show(held())

return {}
