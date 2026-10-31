-- Hands the testing chat commands on to the server: /buy, /weapon, /swords, /staffs,
-- /bows, /cash, /reset, /bossfight, /bosslist, /tutorial and /skiptutorial (TextChatService runs a command's
-- Triggered where it's typed), and shows what they reply (CommandReply) in your chat.
-- (Moved out of the old WeaponSpin screen, deleted with the rest of the UI on Oct 27.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

task.spawn(function()
	local commands = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	for _, name in { "Buy", "Weapon", "Swords", "Staffs", "Bows", "Cash", "Reset", "Bossfight", "Bosslist", "Tutorial", "Skiptutorial" } do
		local command = commands:WaitForChild(name .. "Command", 10)
		local request = ReplicatedStorage:WaitForChild(name .. "Request", 10)
		if command and request then
			command.Triggered:Connect(function(_source, text)
				request:FireServer(text)
			end)
		end
	end
end)

task.spawn(function()
	local reply = ReplicatedStorage:WaitForChild("CommandReply", 30)
	if not reply then
		return
	end
	reply.OnClientEvent:Connect(function(text)
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			for line in string.gmatch(text, "[^\n]+") do
				general:DisplaySystemMessage(line)
			end
		end
	end)
end)

return nil
