-- The free gift's Claim (QM, Oct 31; client/FreeReward is its popup, Shared/GiftModel the
-- present by the gateway): Config.FreeGift.Amount Power (Strength), once per player. Saved
-- as the player attribute FreeGift (Server/Data keeps it, and saves the moment it's set).
--
-- Of the popup's three steps only the group can be checked: Roblox doesn't tell a game who
-- liked it, and favoriting happens in Roblox's own prompt on the client. So the server
-- checks the group (once Config.FreeGift.GroupId is set) and that you're by the gift, and
-- takes the like and favorite on the popup's word.
--
--   FreeGift.start()   -- once: the FreeGiftClaim RemoteFunction -> ok, why
--                      -- (why: "claimed", "far", "group", "busy")

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Combat = require(script.Parent.Combat)

local FreeGift = {}

local busy = {} -- [player] = true while a Claim is being checked

-- in the group? (GroupService asks Roblox fresh: Player:IsInGroup remembers the answer from
-- when they joined the server, so it'd miss a group joined from the popup)
local function inGroup(player, id)
	local ok, groups = pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
	if ok and type(groups) == "table" then
		for _, g in groups do
			if g.Id == id then
				return true
			end
		end
		return false
	end
	local ok2, member = pcall(player.IsInGroup, player, id)
	return ok2 and member == true
end

local function near(player)
	local s = Config.FreeGift
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local away = (root.Position - Vector3.new(s.X, root.Position.Y, s.Z)).Magnitude
	return away <= s.Reach
end

local function claim(player)
	local s = Config.FreeGift
	if player:GetAttribute("FreeGift") then
		return false, "claimed"
	end
	if not player:GetAttribute("Loaded") then
		return false, "busy" -- (their save isn't in yet: it may say they already have)
	end
	if busy[player] then
		return false, "busy"
	end
	if not near(player) then
		return false, "far"
	end
	busy[player] = true
	local member = not s.GroupId or inGroup(player, s.GroupId)
	busy[player] = nil
	if not member then
		return false, "group"
	end
	if player.Parent == nil or player:GetAttribute("FreeGift") then
		return false, "claimed"
	end
	player:SetAttribute("Strength", (player:GetAttribute("Strength") or 0) + s.Amount)
	Combat.refresh(player)
	player:SetAttribute("FreeGift", true) -- (last: setting it saves, Server/Data)
	return true
end

function FreeGift.start()
	local remote = Instance.new("RemoteFunction")
	remote.Name = "FreeGiftClaim"
	remote.OnServerInvoke = claim
	remote.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return FreeGift
