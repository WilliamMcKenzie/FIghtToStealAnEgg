-- Everything bought with Robux (QM, Oct 30: the Shop popup, client/Shop; Config.Shop).
-- It owns MarketplaceService.ProcessReceipt: each developer product's handler is added with
-- Store.product (Server/Arsenal's weapons too), and the Shop's are made here:
--   Game Passes  bought as Roblox game passes (Id), or gifted through a developer product
--                (Gift). Each one owned sets the player's Pass<Name> attribute (Shared/Passes):
--                bought ones are checked with Roblox on joining, gifted ones are kept in the
--                saved Passes attribute ("Cash,Life").
--   Cash / Power packs  a developer product each (Product): its Amount of cash, or of
--                Strength (the Power counter). The same product is used for a gift.
--   +1 Equip     the Active Pets popup's (Config.Backpack.SlotProduct): one more pen slot
--                for good, each time (saved ExtraSlots attribute: Server/PetInventory).
-- A gift: the client says who it's for first (ShopBuy with a UserId); the next receipt for
-- that product from that buyer goes to them (to the buyer, if they've left).
-- In Studio, anything without its id yet is simply given (so the Shop can be tried out).
--
--   Store.start()                                   -- once
--   Store.product(id, handler(player) -> ok?)       -- a developer product's handler
--   ShopBuy (RemoteEvent, kind, index, giftTo?)     -- kind "Passes", "Cash" or "Power"

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Combat = require(script.Parent.Combat)

local Store = {}

local SHOP = Config.Shop
local handlers = {} -- [product id] = handler(player, receipt) -> ok
local pending = {} -- [buyer] = { product = id, to = UserId }
local done = {} -- [PurchaseId] = true (a receipt Roblox sends again isn't given twice)

function Store.product(id, handler)
	if id then
		handlers[id] = handler
	end
end

-- ---- what each thing gives -------------------------------------------------------------

local function gifted(player)
	local list = {}
	for name in string.gmatch(player:GetAttribute("Passes") or "", "[^,%s]+") do
		list[name] = true
	end
	return list
end

local function givePass(player, name)
	local list = gifted(player)
	if not list[name] then
		list[name] = true
		local names = {}
		for n in list do
			table.insert(names, n)
		end
		table.sort(names)
		player:SetAttribute("Passes", table.concat(names, ","))
	end
	player:SetAttribute("Pass" .. name, true)
end

local function givePack(player, kind, pack)
	if kind == "Cash" then
		player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + pack.Amount)
	else
		player:SetAttribute("Strength", (player:GetAttribute("Strength") or 0) + pack.Amount)
		Combat.refresh(player)
	end
end

local function give(player, kind, index)
	local item = SHOP[kind] and SHOP[kind][index]
	if not item then
		return
	end
	if kind == "Passes" then
		givePass(player, item.Name)
	else
		givePack(player, kind, item)
	end
end

-- ---- buying -----------------------------------------------------------------------------

local function buy(player, kind, index, giftTo)
	local item = type(kind) == "string" and SHOP[kind] and type(index) == "number" and SHOP[kind][index]
	if not item then
		return
	end
	local target = player
	if giftTo ~= nil then
		target = type(giftTo) == "number" and Players:GetPlayerByUserId(giftTo)
		if not target or target == player then
			return
		end
	end
	if kind == "Passes" and target == player then
		if player:GetAttribute("Pass" .. item.Name) then
			return -- (already theirs)
		end
		if item.Id then
			MarketplaceService:PromptGamePassPurchase(player, item.Id)
		elseif RunService:IsStudio() then
			give(player, kind, index)
		end
		return
	end
	local product = if kind == "Passes" then item.Gift else item.Product
	if kind == "Passes" and target:GetAttribute("Pass" .. item.Name) then
		return -- (they have it already)
	end
	if product then
		pending[player] = { product = product, to = target.UserId }
		MarketplaceService:PromptProductPurchase(player, product)
	elseif RunService:IsStudio() then
		give(target, kind, index)
	end
end

local function receipt(info)
	if done[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local handler = handlers[info.ProductId]
	if not (player and handler) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- (asked again when they're back)
	end
	local ok, granted = pcall(handler, player, info)
	if not ok or granted == false then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	done[info.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- who a product bought by `player` is for: the gift's target if they asked for one
local function recipient(player, product)
	local p = pending[player]
	if p and p.product == product then
		pending[player] = nil
		return Players:GetPlayerByUserId(p.to) or player
	end
	return player
end

function Store.start()
	for kind, list in { Passes = SHOP.Passes, Cash = SHOP.Cash, Power = SHOP.Power } do
		for index, item in list do
			local product = if kind == "Passes" then item.Gift else item.Product
			Store.product(product, function(player, info)
				give(recipient(player, info.ProductId), kind, index)
			end)
		end
	end
	Store.product(Config.Backpack.SlotProduct, function(player)
		player:SetAttribute("ExtraSlots", (player:GetAttribute("ExtraSlots") or 0) + 1)
	end)
	MarketplaceService.ProcessReceipt = receipt

	local remote = Instance.new("RemoteEvent")
	remote.Name = "ShopBuy"
	remote.OnServerEvent:Connect(buy)
	remote.Parent = ReplicatedStorage

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
		if not bought then
			return
		end
		for _, pass in SHOP.Passes do
			if pass.Id == id then
				player:SetAttribute("Pass" .. pass.Name, true)
			end
		end
	end)

	local function joined(player)
		for _, pass in SHOP.Passes do
			if pass.Id then
				task.spawn(function()
					local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
					if ok and owns then
						player:SetAttribute("Pass" .. pass.Name, true)
					end
				end)
			end
		end
		-- the gifted ones (saved; Server/Data loads them in after joining)
		local function fromGifts()
			for name in gifted(player) do
				player:SetAttribute("Pass" .. name, true)
			end
		end
		player:GetAttributeChangedSignal("Passes"):Connect(fromGifts)
		fromGifts()
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return Store
