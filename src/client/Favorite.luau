-- The favourite prompt (QM, Nov 1): right after you unlock the Desert, Server/Regions fires
-- PromptFavorite (once per player ever) and this shows Roblox's own "Favorite this
-- experience?" prompt. Config.Favorite has the region and the delay.

local AvatarEditorService = game:GetService("AvatarEditorService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

ReplicatedStorage:WaitForChild("PromptFavorite").OnClientEvent:Connect(function()
	task.wait(Config.Favorite.Delay) -- (let the blocker go and the Buy sound play first)
	pcall(function()
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
	end)
end)

return {}
