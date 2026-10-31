-- Stolen eggs and hatching them (QM, Oct 25, LassoAPet's way: "place egg in pen, wait to
-- hatch, hold to hatch, boom new pet").
--
-- An egg is yours the moment you steal it (Server/Eggs calls Hatchery.give): it goes in
-- your EggBag (player attribute, Shared/Stacks: "Pig:2,Unicorn"), shown in the hotbar
-- right of the Backpack button (client/Hotbar). The bag isn't saved, and dying empties it.
-- Click an egg there to hold it instead of your weapon (HoldEgg: player attribute
-- Holding = its kind; Server/Arsenal swaps the tool), click in your pen to put it down
-- (PlaceEgg). A placed egg is ready Config.Hatch.Time seconds later; stand by it and hold
-- F (client/PenEggs), or press its HATCH in the Growing Eggs panel (client/EggsPanel), to
-- hatch it (HatchEgg) into its pet, which goes in your Backpack
-- (Server/PetInventory) and into your pen if there's room, jumping out of the egg onto
-- its spot (Pens.hatching). Everyone sees the hatch (Hatched, to every client).
--
-- Placed eggs are saved: player attribute PenEggs, JSON of { { id, k = kind, x, z, t =
-- os.time() it's ready } }, x and z in studs from the middle of the pen's Area (in its
-- frame), drawn for everyone by client/PenEggs.
--
-- Hatch now for Robux (QM, Oct 31: LassoAPet's SpeedupEgg): holding F by one of your eggs
-- that's still growing (SpeedupEgg) prompts the developer product for its time left
-- (Config.Hatch.Speedup, Hatchery.speedupTier); bought, that egg hatches at once. A
-- receipt whose egg is gone (hatched meanwhile, or the player left) goes to the egg with
-- the most time left, or is kept for the next one (saved HatchCredits attribute).
--
--   Hatchery.start()                -- once, after Pens.start and PetInventory.start
--   Hatchery.give(player, kind)     -- one more egg in their bag (a steal)

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Passes = require(Shared.Passes)
local Stacks = require(Shared.Stacks)
local Pens = require(script.Parent.Pens)
local PetInventory = require(script.Parent.PetInventory)
local Store = require(script.Parent.Store)

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
			table.insert(out, { id = tostring(e.id), k = e.k, x = e.x, z = e.z, t = tonumber(e.t) or 0, d = tonumber(e.d) })
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
	if player:GetAttribute("Tutorial") then
		player:SetAttribute("TutorialPlaced", true) -- (Server/Tutorial stops handing it back)
	end
	local grow = Passes.hatchTime(player, Hatchery.hatchTime(kind)) -- (halved by x2 Growth)
	if player:GetAttribute("Tutorial") then
		grow = Config.Tutorial.HatchTime -- (the tutorial's egg is ready at once)
	end
	table.insert(list, {
		id = HttpService:GenerateGUID(false):sub(1, 8),
		k = kind,
		x = math.round(x * 10) / 10,
		z = math.round(z * 10) / 10,
		t = os.time() + grow,
		d = grow, -- (how long it grows: the clients' progress bars count from it)
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
	if not (area and type(id) == "string") then
		return
	end
	local list = placed(player)
	for i, e in list do
		if e.id == id then
			local at = area.CFrame:PointToWorldSpace(Vector3.new(e.x, -area.Size.Y / 2, e.z))
			-- (from anywhere: the F prompt by the egg, or the Growing Eggs panel's HATCH)
			if workspace:GetServerTimeNow() < e.t then
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

-- ---- hatch now, for Robux ---------------------------------------------------------------

local SPEEDUP = Config.Hatch.Speedup

-- the tier (Config.Hatch.Speedup) for an egg with secondsLeft to go
function Hatchery.speedupTier(secondsLeft)
	for _, tier in SPEEDUP do
		if secondsLeft <= tier.Upto then
			return tier
		end
	end
	return SPEEDUP[#SPEEDUP]
end

local speedupTarget = {} -- [player] = the egg id they're buying a hatch for

-- one of their eggs still growing that a bought hatch goes to: `id` if it still is, else
-- the one with the most time left
local function growingEgg(player, id)
	local now = workspace:GetServerTimeNow()
	local best, left = nil, 0
	for _, e in placed(player) do
		if e.t > now then
			if e.id == id then
				return e.id
			end
			if e.t - now > left then
				best, left = e.id, e.t - now
			end
		end
	end
	return best
end

-- a bought hatch: the egg's ready now, and hatches
local function hatchNow(player, id)
	local list = placed(player)
	for _, e in list do
		if e.id == id then
			e.t = math.min(e.t, os.time())
			setPlaced(player, list)
			hatch(player, id)
			return true
		end
	end
	return false
end

local function speedup(player, id)
	if type(id) ~= "string" or player:GetAttribute("Tutorial") then
		return
	end
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (area and root) then
		return
	end
	for _, e in placed(player) do
		if e.id == id then
			local left = e.t - workspace:GetServerTimeNow()
			if left <= 0 then
				return -- (ready: plain F hatches it)
			end
			local at = area.CFrame:PointToWorldSpace(Vector3.new(e.x, -area.Size.Y / 2, e.z))
			if ((root.Position - at) * Vector3.new(1, 0, 1)).Magnitude > Config.Hatch.Range + 4 then
				return
			end
			local credits = player:GetAttribute("HatchCredits") or 0
			if credits > 0 then
				player:SetAttribute("HatchCredits", if credits > 1 then credits - 1 else nil)
				hatchNow(player, id)
				return
			end
			local tier = Hatchery.speedupTier(left)
			if tier.Product then
				speedupTarget[player] = id
				pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, tier.Product)
			elseif RunService:IsStudio() then
				hatchNow(player, id) -- (no product yet: free in Studio, to try it out)
			end
			return
		end
	end
end

local function bought(player)
	local id = growingEgg(player, speedupTarget[player])
	speedupTarget[player] = nil
	if not (id and hatchNow(player, id)) then
		player:SetAttribute("HatchCredits", (player:GetAttribute("HatchCredits") or 0) + 1)
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
	remote("SpeedupEgg", speedup)
	for _, tier in SPEEDUP do
		Store.product(tier.Product, bought)
	end
	Players.PlayerRemoving:Connect(function(player)
		speedupTarget[player] = nil
	end)

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
