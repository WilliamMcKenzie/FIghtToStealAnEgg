-- Live weapon tuning (QM, Oct 25): Workspace > Weapon holds every value of the weapon
-- you're holding, as attributes, while you play (in Studio, or as the game's owner).
-- Change one in the Properties panel and the next attack uses it, here and on the server
-- (WeaponTune), so damage, speed, homing and range all follow; /weapon <name> to hold
-- another and its values replace these. Edit it in the Client view (it's made here).
--
--   Damage                     times your Power, per hit
--   Melee: every Config.Slash value (Arc, Radius, Width, OuterSegments, Cooldown,
--          AttackRange, Color...), each Variety range as Variety_<name> (X min, Y max)
--   Ranged and Magic: every Config.Shots.Ranged / .Magic value (Speed, Size, Homing,
--          HomingCone, Launch, and the orb: Color, Color2, sizes, Flares, Sparks...)
--
-- Tuned values last until Play stops. Tick PrintConfig to print the weapon's block, ready
-- to paste into Config.Weapons (or send to Claude); tick Reset to go back to Config.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Weapons = require(Shared.Weapons.Weapons)

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("WeaponTune")

-- tunes from the server (made by someone else in this server) apply here too
local folder = nil
local shown = nil
local quiet = false -- (while this script writes the attributes itself)

local function show(id)
	if not folder then
		return
	end
	quiet = true
	for name in folder:GetAttributes() do
		folder:SetAttribute(name, nil)
	end
	shown = id
	folder:SetAttribute("Weapon", Weapons.get(id).Name)
	folder:SetAttribute("PrintConfig", false)
	folder:SetAttribute("Reset", false)
	for _, pair in Weapons.tunables(id) do
		folder:SetAttribute(pair[1], pair[2])
	end
	quiet = false
end

local function held()
	local id = player:GetAttribute("Weapon")
	return if Weapons.exists(id) then id else Config.WeaponDrops.Start
end

remote.OnClientEvent:Connect(function(id, key, value)
	if key == false then
		Weapons.untune(id)
	else
		Weapons.tune(id, key, value)
	end
	if id == shown then
		show(id)
	end
end)

if not (RunService:IsStudio() or player.UserId == game.CreatorId) then
	return {}
end

folder = Instance.new("Configuration")
folder.Name = "Weapon"
folder.Parent = workspace

folder.AttributeChanged:Connect(function(name)
	if quiet or not shown then
		return
	end
	local id = shown
	local value = folder:GetAttribute(name)
	if name == "PrintConfig" then
		if value then
			print("-- " .. Weapons.get(id).Name .. ", for Config.Weapons:\n" .. Weapons.source(id))
			quiet = true
			folder:SetAttribute("PrintConfig", false)
			quiet = false
		end
	elseif name == "Reset" then
		if value then
			Weapons.untune(id)
			remote:FireServer(id, false)
			show(id)
		end
	elseif name == "Weapon" then
		show(id) -- (just a label: put it back)
	elseif Weapons.tune(id, name, value) then
		remote:FireServer(id, name, value)
	else
		show(id) -- (not a value it has, or the wrong type: put it back)
	end
end)

player:GetAttributeChangedSignal("Weapon"):Connect(function()
	show(held())
end)
show(held())

return {}
