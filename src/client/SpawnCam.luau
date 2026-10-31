-- The camera at each spawn (QM, Oct 31: "spawn in front of their pen turned to face pen,
-- with camera facing pen also"): Server/Pens puts you in front of your pen's gate facing
-- it (Shared/PenSpawn), and once you're there this turns the usual camera round behind
-- you, looking past you at the pen. It's set once, so the camera is yours again at once
-- (the first spawn also starts at Config.PenSpawn.CamDistance; later ones keep your zoom).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PenSpawn = require(Shared:WaitForChild("PenSpawn"))

local player = Players.LocalPlayer
local C = Config.PenSpawn
local first = true

local function aim(character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	-- wait for the server to put you at your pen (a few seconds at most)
	local spot
	local started = os.clock()
	while os.clock() - started < 5 and player.Character == character do
		spot = PenSpawn.spot(PenSpawn.pen(player:GetAttribute("Pen")))
		local d = spot and (root.Position - spot.Position) * Vector3.new(1, 0, 1)
		if d and d.Magnitude < 4 then
			break
		end
		spot = nil
		task.wait()
	end
	if not spot or player.Character ~= character then
		return
	end
	RunService.RenderStepped:Wait() -- (after the camera has picked up its new subject)
	local camera = workspace.CurrentCamera
	if camera.CameraType ~= Enum.CameraType.Custom then
		return -- (the T top-down view, or a scripted shot)
	end
	local focus = root.Position + Vector3.new(0, 2, 0)
	local distance = if first then C.CamDistance else (camera.CFrame.Position - camera.Focus.Position).Magnitude
	if distance < 1 then
		distance = C.CamDistance
	end
	first = false
	local back = -spot.LookVector
	local pitch = math.rad(C.CamPitch)
	local eye = focus + back * math.cos(pitch) * distance + Vector3.new(0, math.sin(pitch) * distance, 0)
	camera.CFrame = CFrame.lookAt(eye, focus)
	camera.Focus = CFrame.new(focus)
end

player.CharacterAdded:Connect(aim)
if player.Character then
	task.spawn(aim, player.Character)
end

return {}
