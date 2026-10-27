-- Stolen eggs and hatching them (QM, Oct 25, LassoAPet's way: "place egg in pen, wait to
-- hatch, hold to hatch, boom new pet").
--
-- An egg is yours the moment you steal it (Server/Eggs calls Hatchery.give): it goes in
-- your EggBag (player attribute, Shared/Stacks: "Pig:2,Unicorn"), shown in the hotbar
-- right of the Backpack button (client/Hotbar). The bag isn't saved, and dying empties it.
-- Click an egg there to hold it instead of your weapon (HoldEgg: player attribute
-- Holding = its kind; Server/Arsenal swaps the tool), click in your pen to put it down
-- (PlaceEgg). A placed egg is ready Config.Hatch.Time seconds later; stand by it and hold
-- F (client/PenEggs) to hatch it (HatchEgg) into its pet, which goes in your Backpack
-- (Server/PetInventory) and into your pen if there's room, jumping out of the egg onto
-- its spot (Pens.hatching). Everyone sees the hatch (Hatched, to every client).
--
-- Placed eggs are saved: player attribute PenEggs, JSON of { { id, k = kind, x, z, t =
-- os.time() it's ready } }, x and z in studs from the middle of the pen's Area (in its
-- frame), drawn for everyone by client/PenEggs.
--
--   Hatchery.start()                -- once, after Pens.start and PetInventory.start
--   Hatchery.give(player, kind)     -- one more egg in their bag (a steal)

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stacks = require(Shared.Stacks)
local Pens = require(script.Parent.Pens)
local PetInventory = require(script.Parent.PetInventory)

local Hatchery = {}

local Egg = require(Shared.Eggs.Egg)

local EDGE = Config.Hatch.Edge -- studs kept from the pen's sides
local EGG_CENTER = 1.6 -- an egg's middle above its base, at 1x (as client/PenEggs)

local function isPet(kind)
	return Config.Pets[kind] ~= nil
end

local function bag(player)
	return Stacks.parse(player:GetAttribute("EggBag"), isPet)
end

local function setBag(player, list)
	local text = Stacks.format(list)
	player:SetAttribute("EggBag", if text == "" then nil else text)
	-- (holding one you've no more of: back to your weapon)
	local holding = player:GetAttribute("Holding")
	if holding and Stacks.count(list, holding) == 0 then
		player:SetAttribute("Holding", nil)
	end
end

function Hatchery.give(player, kind)
	if isPet(kind) then
		setBag(player, Stacks.add(bag(player), kind, 1))
	end
end

function Hatchery.hatchTime(kind)
	return Config.Hatch.Time[kind] or Config.Hatch.Default
end

local function placed(player)
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PenEggs") or "[]")
	if not ok or type(list) ~= "table" then
		return {}
	end
	local out = {}
	for _, e in list do
		if type(e) == "table" and isPet(e.k) and type(e.x) == "number" and type(e.z) == "number" then
			table.insert(out, { id = tostring(e.id), k = e.k, x = e.x, z = e.z, t = tonumber(e.t) or 0 })
		end
	end
	return out
end

local function setPlaced(player, list)
	player:SetAttribute("PenEggs", if #list == 0 then nil else HttpService:JSONEncode(list))
end

local function hold(player, kind)
	if kind == nil or kind == player:GetAttribute("Holding") then
		player:SetAttribute("Holding", nil) -- (clicked again: the weapon again)
	elseif type(kind) == "string" and Stacks.count(bag(player), kind) > 0 then
		player:SetAttribute("Holding", kind)
	end
end

local function place(player, x, z)
	local kind = player:GetAttribute("Holding")
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	if not (kind and area and type(x) == "number" and type(z) == "number" and x == x and z == z) then
		return
	end
	if math.abs(x) > area.Size.X / 2 - EDGE or math.abs(z) > area.Size.Z / 2 - EDGE then
		return
	end
	local list = placed(player)
	if #list >= Config.Hatch.PenEggs then
		return
	end
	local eggs = bag(player)
	if Stacks.count(eggs, kind) < 1 then
		return
	end
	Stacks.add(eggs, kind, -1)
	setBag(player, eggs)
	table.insert(list, {
		id = HttpService:GenerateGUID(false):sub(1, 8),
		k = kind,
		x = math.round(x * 10) / 10,
		z = math.round(z * 10) / 10,
		t = os.time() + Hatchery.hatchTime(kind),
	})
	setPlaced(player, list)
end

local hatchedRemote = Instance.new("RemoteEvent")
hatchedRemote.Name = "Hatched"
hatchedRemote.Parent = ReplicatedStorage

-- (the pen was full: the pet went to storage)
local storedRemote = Instance.new("RemoteEvent")
storedRemote.Name = "PetStored"
storedRemote.Parent = ReplicatedStorage

local function hatch(player, id)
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (area and root and type(id) == "string") then
		return
	end
	local list = placed(player)
	for i, e in list do
		if e.id == id then
			local at = area.CFrame:PointToWorldSpace(Vector3.new(e.x, -area.Size.Y / 2, e.z))
			if os.time() < e.t or ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude > Config.Hatch.Range + 4 then
				return
			end
			table.remove(list, i)
			setPlaced(player, list)
			-- (the pet jumps out of it, grown full size by now, as the top pops off)
			local now = workspace:GetServerTimeNow()
			local scale = Egg.sizeOf(e.k) * Config.Hatch.GrowScale
			Pens.hatching(player, e.k, at, now + Config.Hatch.TopPops, EGG_CENTER * scale)
			local stored = PetInventory.give(player, e.k) == false
			hatchedRemote:FireAllClients(player, e.id, e.k, at, now)
			if stored then
				storedRemote:FireClient(player, e.k) -- (client/PetsPanel: "Pet sent to storage" and the "!")
			end
			return
		end
	end
end

function Hatchery.start()
	local function remote(name, fn)
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
		r.OnServerEvent:Connect(fn)
	end
	remote("HoldEgg", hold)
	remote("PlaceEgg", place)
	remote("HatchEgg", hatch)

	local function joined(player)
		local function lose()
			player:SetAttribute("EggBag", nil)
			player:SetAttribute("Holding", nil)
		end
		player.CharacterAdded:Connect(function(character)
			lose() -- (a new life: whatever eggs you'd stolen are gone)
			character:WaitForChild("Humanoid").Died:Connect(lose)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Hatchery
