-- One outline for every HUD icon and label (QM, Oct 26: each icon came from the pack with its own
-- outline width, so they never matched). The icons are now drawn without one
-- (assets/ui/icons, made by tools/ui_icons.py) and the outline is put back on here, the same
-- for all of them. Roblox can't stroke the shape inside an image (a UIStroke only follows the
-- frame), so the icon's white silhouette is laid behind it a few times, nudged out in a ring
-- and tinted: that ring is the outline. The nudges are in px, not a share of the icon, so a
-- bigger icon gets the same width of outline as a small one. Labels get a UIStroke of the same
-- colour.
--
-- Tuned in one place, as attributes on StarterGui > Hud (they take effect in Play, and live
-- while playing):
--   OutlineColor          the colour of every icon and label outline
--   OutlineThickness      icon outlines, in design px (the 1080-tall layout)
--   TextOutlineThickness  label outlines, in design px
--
--   Outline.settings(gui)              -- once, with the Hud ScreenGui (adds the attributes)
--   Outline.icon(parent, name, image, mask, props) -> holder
--       -- an icon in `parent`: a Frame `name` holding Outline (the ring) and Icon (the art)
--   Outline.text(label)                -- gives a TextLabel its outline (a UIStroke)

local Ui = require(script.Parent.Ui)

local Outline = {}

local DEFAULTS = {
	OutlineColor = Color3.fromRGB(4, 4, 53), -- (the icon pack's navy)
	OutlineThickness = 3, -- (QM, Oct 26: matching the labels' 3)
	TextOutlineThickness = 3, -- (QM, Oct 26: 1px less)
}
-- the ring: copies of the silhouette around a circle at the full thickness, and a sparser one at
-- half, so thin bits (the sword's tip) don't show gaps between the copies
local RINGS = { { 1, 16 }, { 0.5, 8 } }

local gui = nil
local icons = {} -- every Outline frame made, to refresh when the settings change
local texts = {} -- every UIStroke made

local function get(name)
	local v = gui and gui:GetAttribute(name)
	if v == nil then
		return DEFAULTS[name]
	end
	return v
end

-- where each copy goes: { x, y } in units of the thickness
local OFFSETS = {}
for _, ring in RINGS do
	for i = 0, ring[2] - 1 do
		local a = i / ring[2] * math.pi * 2
		table.insert(OFFSETS, { math.cos(a) * ring[1], math.sin(a) * ring[1] })
	end
end

local function paintIcon(frame)
	local t = get("OutlineThickness")
	local color = get("OutlineColor")
	for i = 0, #OFFSETS do
		local copy = frame:FindFirstChild(tostring(i))
		if copy then
			local o = OFFSETS[i] or { 0, 0 }
			copy.Position = UDim2.fromOffset(math.round(o[1] * t * 10) / 10, math.round(o[2] * t * 10) / 10)
			copy.ImageColor3 = color
		end
	end
	frame.Visible = t > 0
end

local function paintText(stroke)
	stroke.Color = get("OutlineColor")
	stroke.Thickness = get("TextOutlineThickness")
end

function Outline.settings(screen)
	gui = screen
	for name, v in DEFAULTS do
		if gui:GetAttribute(name) == nil then
			gui:SetAttribute(name, v)
		end
	end
	if Ui.live then
		gui.AttributeChanged:Connect(function(name)
			if DEFAULTS[name] == nil then
				return
			end
			for _, frame in icons do
				if frame.Parent then
					paintIcon(frame)
				end
			end
			for _, stroke in texts do
				if stroke.Parent then
					paintText(stroke)
				end
			end
		end)
	end
end

function Outline.icon(parent, name, image, mask, props)
	local holder, fresh = Ui.make(parent, name, "Frame")
	if fresh then
		holder.BackgroundTransparency = 1
		for k, v in props do
			holder[k] = v
		end
	end
	local ring
	ring, fresh = Ui.make(holder, "Outline", "Frame")
	if fresh then
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.fromScale(1, 1)
		ring.ZIndex = 1
		for i = 0, #OFFSETS do
			-- (0: one right under the icon, so its soft edge sits on the outline, not the world)
			local copy = Instance.new("ImageLabel")
			copy.Name = tostring(i)
			copy.BackgroundTransparency = 1
			copy.Image = mask
			copy.Size = UDim2.fromScale(1, 1)
			copy.ZIndex = 1
			copy.Parent = ring
		end
	end
	local art
	art, fresh = Ui.make(holder, "Icon", "ImageLabel")
	if fresh then
		art.BackgroundTransparency = 1
		art.Image = image
		art.Size = UDim2.fromScale(1, 1)
		art.ZIndex = 2
	end
	-- (baked before the images were uploaded: fill them in)
	if art.Image == "" then
		art.Image = image
	end
	for _, copy in ring:GetChildren() do
		if copy:IsA("ImageLabel") and copy.Image == "" then
			copy.Image = mask
		end
	end
	-- (the ring always follows the settings: it's how the outline is tuned in one place)
	paintIcon(ring)
	table.insert(icons, ring)
	return holder
end

function Outline.text(label)
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Name = "Outline"
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "Outline"
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
	end
	paintText(stroke)
	table.insert(texts, stroke)
	return stroke
end

return Outline
