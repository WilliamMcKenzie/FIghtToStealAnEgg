-- Riding a pet from your pen (QM, Oct 27: the pet you ride IS one of your pen's pets, you
-- just choose to ride it). Each pet wandering in your own pen gets a Ride prompt; taking
-- it asks the server to ride that one (PetEquip "ride", Server/PetInventory), and the one
-- you were riding goes back in the pen. A stand-in until the pen tools on the right of the
-- screen come: they only need to fire the same remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("PetEquip")

local function add(body)
	if not body:IsA("BasePart") or body:GetAttribute("Owner") ~= player.UserId then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Ride"
	prompt.ObjectText = body:GetAttribute("Name") or body:GetAttribute("Model") or ""
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	-- (an egg's Hatch is F too: Ride hides while one's up, as LassoAPet's does; client/PenEggs)
	local function eggUp()
		prompt.Enabled = not player:GetAttribute("EggPromptUp")
	end
	player:GetAttributeChangedSignal("EggPromptUp"):Connect(eggUp)
	eggUp()
	prompt.Triggered:Connect(function()
		remote:FireServer("ride", body:GetAttribute("Model"))
	end)
	prompt.Parent = body
end

task.spawn(function()
	local folder = workspace:WaitForChild("PenPets")
	for _, body in folder:GetChildren() do
		add(body)
	end
	folder.ChildAdded:Connect(add)
end)

return {}
