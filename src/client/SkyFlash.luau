-- The sky flashes white as your mount breaks into a new sprint tier (QM, Oct 9), then
-- fades back over Config.SkyFlash.Time seconds. The sky itself can't be tinted (a
-- Skybox has no colour, and an Atmosphere's haze doesn't show on this one), so it's a
-- white Neon box round the camera, Distance studs out each way (no floor): the sky, and
-- whatever's further off than that, goes white. Config.SkyFlash.
--
--   SkyFlash.flash()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local SkyFlash = {}

local SIDES = { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis, Vector3.yAxis }
local folder, panels = nil, {}
local t -- seconds into the flash (nil: none)

local function build()
	folder = Instance.new("Folder")
	folder.Name = "SkyFlash"
	table.clear(panels)
	for _ in SIDES do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.new(1, 1, 1)
		p.Size = Vector3.new(2048, 2048, 1) -- (the biggest a part can be)
		p.Transparency = 1
		p.Parent = folder
		table.insert(panels, p)
	end
	folder.Parent = workspace
end

local function set(transparency)
	local at = workspace.CurrentCamera.CFrame.Position
	local d = Config.SkyFlash.Distance
	for i, side in SIDES do
		panels[i].CFrame = CFrame.lookAt(at + side * d, at)
		panels[i].Transparency = transparency
	end
end

RunService.RenderStepped:Connect(function(dt)
	if not t then
		return
	end
	local cfg = Config.SkyFlash
	t += dt
	local k = math.min(t / cfg.Time, 1)
	set(1 - (1 - k) * (1 - k) * (1 - cfg.Start)) -- (white, then easing out to clear)
	if k >= 1 then
		t = nil
	end
end)

function SkyFlash.flash()
	if not Config.SkyFlash.On then
		return
	end
	if not folder or not folder:IsDescendantOf(workspace) then
		build()
	end
	t = 0
end

return SkyFlash
