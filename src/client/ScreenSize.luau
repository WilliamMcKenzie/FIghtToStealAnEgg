-- Overhead billboards drawn at a fixed size on the screen (QM, Oct 30: the player's health bar
-- and the egg labels got tiny with the boss fight camera zoomed out). Sized in design px at
-- a 1080-tall screen, like the Hud, and kept fitted to the screen's height as it changes.
--
--   ScreenSize.fit(gui, w, h) -- gui.Size = w x h design px, now and whenever the screen resizes

local ScreenSize = {}

local DESIGN_HEIGHT = 1080

local fitted = setmetatable({}, { __mode = "k" }) -- [gui] = Vector2 design px

local function size(gui, px)
	local k = workspace.CurrentCamera.ViewportSize.Y / DESIGN_HEIGHT
	gui.Size = UDim2.fromOffset(math.round(px.X * k), math.round(px.Y * k))
end

function ScreenSize.fit(gui, w, h)
	local px = Vector2.new(w, h)
	fitted[gui] = px
	size(gui, px)
end

local watching = nil
local function watch()
	if watching then
		watching:Disconnect()
	end
	watching = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for gui, px in fitted do
			size(gui, px)
		end
	end)
end
watch()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)

return ScreenSize
