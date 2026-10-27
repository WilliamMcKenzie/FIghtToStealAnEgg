-- Weapons a player owns and the one they hold (QM, Oct 25), bought from Carl the cactus
-- vendor (QM, Oct 27: no more boss drops, spins or merging; you own each weapon once).
--
-- Player attributes (saved by Server/Data): Weapons, the ids owned ("Axe,Staff"; everyone
-- has Config.Arsenal.Start); Weapon, the one equipped. The equipped one's tool
-- (Shared/Weapons) is put in the Roblox backpack whenever it changes and on every spawn;
-- the client equips it at once. EquipWeapon switches between owned weapons.
--
--   Arsenal.start()                  -- once
--   Arsenal.give(player, id, equip)  -- owns it (and equips it); /weapon <id>, owner only
--   Arsenal.buy(player, id) -> ok, why  -- for its Price in cash: owned and equipped
--                                       -- (the BuyWeapon RemoteFunction: Carl's shop)
--   BuyWeaponRobux (RemoteEvent, id)    -- prompts its developer product (Config.Vendor.Products);
--                                       -- ProcessReceipt owns and equips it once paid

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Stacks = require(Shared.Stacks)
local Weapons = require(Shared.Weapons.Weapons)

local Arsenal = {}

local START = Config.Arsenal.Start

-- what they own ({ { id, n = 1 }, ... }), the starting weapon first (an old save's
-- duplicates, "Axe:3" from the spins, count once)
function Arsenal.stacks(player)
	local list = Stacks.parse(player:GetAttribute("Weapons"), Weapons.exists)
	for _, s in list do
		s.n = 1
	end
	if Stacks.count(list, START) == 0 then
		table.insert(list, 1, { id = START, n = 1 })
	end
	return list
end

function Arsenal.owned(player)
	local list = {}
	for _, s in Arsenal.stacks(player) do
		table.insert(list, s.id)
	end
	return list
end

function Arsenal.owns(player, id)
	return table.find(Arsenal.owned(player), id) ~= nil
end

function Arsenal.equip(player, id)
	if Weapons.exists(id) and Arsenal.owns(player, id) then
		player:SetAttribute("Weapon", id)
	end
end

-- owns it (once: owning it already changes nothing), and equips it
function Arsenal.give(player, id, equip)
	if not Weapons.exists(id) then
		return
	end
	if not Arsenal.owns(player, id) then
		player:SetAttribute("Weapons", Stacks.format(Stacks.add(Arsenal.stacks(player), id, 1)))
	end
	if equip then
		Arsenal.equip(player, id)
	end
end

-- Carl's sale: its Config.Weapons Price in cash. One they own already just equips.
function Arsenal.buy(player, id)
	local w = typeof(id) == "string" and Config.Weapons[id]
	if not (w and w.Price) then
		return false, "not for sale"
	end
	if Arsenal.owns(player, id) then
		Arsenal.equip(player, id)
		return true
	end
	local cash = player:GetAttribute("Cash") or 0
	if cash < w.Price then
		return false, "not enough cash"
	end
	player:SetAttribute("Cash", cash - w.Price)
	Arsenal.give(player, id, true)
	return true
end

-- an egg in your hands (QM, Oct 25: Server/Hatchery): an invisible handle the arm holds,
-- the egg drawn at it by each client (client/PenEggs)
local function eggTool(kind)
	local tool = Instance.new("Tool")
	tool.Name = kind .. " Egg"
	tool.CanBeDropped = false
	tool:SetAttribute("EggTool", kind)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery = false, false, false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

-- the equipped weapon's tool in the backpack, or the egg they're holding (Holding) in
-- its place (any other weapon or egg tool goes)
local function arm(player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not (character and backpack) then
		return
	end
	local egg = player:GetAttribute("Holding")
	local id = player:GetAttribute("Weapon")
	if not Weapons.exists(id) then
		id = START
	end
	local have = false
	for _, holder in { character, backpack } do
		for _, tool in holder:GetChildren() do
			if tool:IsA("Tool") and (tool:GetAttribute("Weapon") ~= nil or tool:GetAttribute("EggTool") ~= nil) then
				local wanted = if egg then tool:GetAttribute("EggTool") == egg else tool:GetAttribute("Weapon") == id
				if wanted and not have then
					have = true -- (already holding it)
				else
					tool:Destroy()
				end
			end
		end
	end
	if not have then
		(if egg then eggTool(egg) else Weapons.makeTool(id)).Parent = backpack
	end
end

function Arsenal.start()
	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipWeapon"
	equipRemote.Parent = ReplicatedStorage
	equipRemote.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			Arsenal.equip(player, id)
		end
	end)
	local buyRemote = Instance.new("RemoteFunction")
	buyRemote.Name = "BuyWeapon"
	buyRemote.OnServerInvoke = Arsenal.buy
	buyRemote.Parent = ReplicatedStorage

	-- Robux: each weapon's developer product (QM's Weapon Shop, Oct 27)
	local weaponOf = {} -- [product id] = weapon id
	for id, product in Config.Vendor.Products do
		weaponOf[product] = id
	end
	local robuxRemote = Instance.new("RemoteEvent")
	robuxRemote.Name = "BuyWeaponRobux"
	robuxRemote.OnServerEvent:Connect(function(player, id)
		local product = typeof(id) == "string" and Config.Vendor.Products[id]
		if product and Config.Weapons[id] and Config.Weapons[id].Price and not Arsenal.owns(player, id) then
			MarketplaceService:PromptProductPurchase(player, product)
		end
	end)
	robuxRemote.Parent = ReplicatedStorage
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local id = weaponOf[receipt.ProductId]
		if not (player and id) then
			return Enum.ProductPurchaseDecision.NotProcessedYet -- (asked again when they're back)
		end
		Arsenal.give(player, id, true)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local function joined(player)
		player:SetAttribute("Weapons", player:GetAttribute("Weapons") or START)
		player:SetAttribute("Weapon", player:GetAttribute("Weapon") or START)
		-- (a save from before a weapon was cut, like the Sword: QM, Oct 25, holds the
		-- starting weapon instead, and the cut ones leave the list; duplicates from the old
		-- spins count once)
		local function migrate()
			if not Weapons.exists(player:GetAttribute("Weapon")) then
				player:SetAttribute("Weapon", START)
			end
			local list = Stacks.format(Arsenal.stacks(player))
			if player:GetAttribute("Weapons") ~= list then
				player:SetAttribute("Weapons", list)
			end
		end
		player:GetAttributeChangedSignal("Weapons"):Connect(migrate)
		player:GetAttributeChangedSignal("Weapon"):Connect(function()
			migrate()
			arm(player)
		end)
		player:GetAttributeChangedSignal("Holding"):Connect(function()
			arm(player)
		end)
		migrate()
		player.CharacterAdded:Connect(function(character)
			player:WaitForChild("Backpack")
			character:WaitForChild("Humanoid")
			task.defer(arm, player)
		end)
		-- (each spawn brings a fresh Backpack: arm that one too)
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				task.defer(arm, player)
			end
		end)
		if player.Character then
			task.defer(arm, player)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Arsenal
