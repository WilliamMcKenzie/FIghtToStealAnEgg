-- Hands the testing chat commands on to the server: /buy, /weapon, /swords, /staffs,
-- /bows, /cash and /reset (TextChatService runs a command's Triggered where it's typed).
-- (Moved out of the old WeaponSpin screen, deleted with the rest of the UI on Oct 27.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

task.spawn(function()
	local commands = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	for _, name in { "Buy", "Weapon", "Swords", "Staffs", "Bows", "Cash", "Reset" } do
		local command = commands:WaitForChild(name .. "Command", 10)
		local request = ReplicatedStorage:WaitForChild(name .. "Request", 10)
		if command and request then
			command.Triggered:Connect(function(_source, text)
				request:FireServer(text)
			end)
		end
	end
end)

return nil
