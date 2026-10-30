-- Sound effects for things in the world, heard if you can see them (QM, Oct 30: in a boss
-- fight the camera sits far back, so sounds that faded with distance from the camera
-- were silent). A sound from something on the screen plays flat (not 3D) at its full
-- volume, wherever the camera is; one from something off the screen doesn't play.
--
--   Sfx.play(id, volume, at, start?) -> Sound?  -- at: a Vector3 or a part (its position);
--                                               start: a TimePosition to begin from

local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sfx = {}

local FAR = 600 -- studs from the camera: not heard past this
local MARGIN = 0.05 -- of the screen's size, all round (just past the edge still counts)
local LIFE = 6 -- seconds a one-shot is kept

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = SoundService

local function seen(position)
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local away = (position - camera.CFrame.Position).Magnitude
	if away > FAR then
		return false
	end
	if away < 15 then
		return true
	end
	local at = camera:WorldToViewportPoint(position)
	if at.Z < 0 then
		return false
	end
	local size = camera.ViewportSize
	local mx, my = size.X * MARGIN, size.Y * MARGIN
	return at.X > -mx and at.X < size.X + mx and at.Y > -my and at.Y < size.Y + my
end

function Sfx.play(id, volume, at, start)
	if type(id) ~= "string" or id == "" or (volume or 0) <= 0 then
		return nil
	end
	local position = if typeof(at) == "Instance" then at.Position else at
	if typeof(position) == "Vector3" and not seen(position) then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	if start then
		s.TimePosition = start
	end
	s.Parent = folder -- (not in a part, so it's flat: no fall-off with distance)
	s:Play()
	Debris:AddItem(s, LIFE)
	return s
end

return Sfx
