-- How every button feels (QM, Oct 26: "snappy and satisfying", no transitions): nothing grows
-- or eases. Hovering one fades it 10% and, where it has one, shows its white outline;
-- pressing fades it a little more. All at once, on the frame it happens. An icon outlined by
-- client/Outline has its outline turn white instead of getting a ring, and the icon grows
-- 1.2x and tilts 12 degrees over 0.1s (QM, Oct 26). It grows by its Size, not a UIScale, so the
-- outline stays the same width.
--
--   Snappy.hook(button, ring)   -- once per button; ring = { radius, inflate } gives it a white
--                               -- outline on hover (a HoverRing frame, inflate px bigger all
--                               -- round), nil for none (an image with see-through edges)

local TweenService = game:GetService("TweenService")

local Snappy = {}

local HOVER_FADE = 0.1
local PRESS_FADE = 0.2
local RING_THICKNESS = 3
local WHITE = Color3.new(1, 1, 1)
local ICON_GROW = 1.2
local ICON_TILT = 12 -- degrees
local ICON_EASE = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- what fades: every image, text, filled background and stroke on it (not its HoverRing, or
-- anything named Rays: the MERGE button's sunburst)
local function fadeable(button)
	local base = {} -- { { object, property, value } }
	local function add(obj)
		if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			table.insert(base, { obj, "ImageTransparency", obj.ImageTransparency })
		end
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			table.insert(base, { obj, "TextTransparency", obj.TextTransparency })
		end
		if obj:IsA("GuiObject") and obj.BackgroundTransparency < 1 then
			table.insert(base, { obj, "BackgroundTransparency", obj.BackgroundTransparency })
		end
		if obj:IsA("UIStroke") then
			table.insert(base, { obj, "Transparency", obj.Transparency })
		end
	end
	add(button)
	for _, d in button:GetDescendants() do
		if
			not (
				d:FindFirstAncestor("HoverRing")
				or d.Name == "HoverRing"
				or d:FindFirstAncestor("Rays")
				or d.Name == "Rays"
			)
		then
			add(d)
		end
	end
	return base
end

local function makeRing(button, ring)
	local r = button:FindFirstChild("HoverRing")
	if r then
		return r
	end
	r = Instance.new("Frame")
	r.Name = "HoverRing"
	r.BackgroundTransparency = 1
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = UDim2.fromScale(0.5, 0.5)
	r.Size = UDim2.new(1, ring[2] * 2, 1, ring[2] * 2)
	r.ZIndex = 30
	r.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, ring[1] + ring[2])
	c.Parent = r
	local s = Instance.new("UIStroke")
	s.Color = WHITE
	s.Thickness = RING_THICKNESS
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = r
	r.Parent = button
	return r
end

-- the copies making up client/Outline's ring on the button's icon, if it has one
local function outlineCopies(button)
	local art = button:FindFirstChild("Art")
	local ring = art and art:FindFirstChild("Outline")
	return if ring then ring:GetChildren() else {}
end

function Snappy.hook(button, ring)
	local base = nil -- (read the first time it's hovered: the button's settled by then)
	local hoverRing = if ring then makeRing(button, ring) else nil
	local over, down = false, false
	local outlineColor = nil -- (the outline's own colour, while it's white)
	local art = button:FindFirstChild("Art")
	local artSize = nil -- (the icon's own size, while it's grown)
	local function pop(on)
		if not (art and art:FindFirstChild("Outline")) then
			return
		end
		if on and not artSize then
			artSize = art.Size
		end
		if not artSize then
			return
		end
		local s = artSize
		local k = if on then ICON_GROW else 1
		TweenService:Create(art, ICON_EASE, {
			Size = UDim2.new(s.X.Scale * k, s.X.Offset * k, s.Y.Scale * k, s.Y.Offset * k),
			Rotation = if on then ICON_TILT else 0,
		}):Play()
		if not on then
			artSize = nil
		end
	end
	local function whiten(on)
		local copies = outlineCopies(button)
		if on and not outlineColor and copies[1] then
			outlineColor = copies[1].ImageColor3
		end
		if not outlineColor then
			return
		end
		for _, copy in copies do
			copy.ImageColor3 = if on then WHITE else outlineColor
		end
		if not on then
			outlineColor = nil
		end
	end
	local function apply()
		base = base or fadeable(button)
		whiten(over)
		pop(over)
		local k = if down then PRESS_FADE elseif over then HOVER_FADE else 0
		for _, entry in base do
			local obj, prop, v = entry[1], entry[2], entry[3]
			if obj.Parent then
				obj[prop] = 1 - (1 - v) * (1 - k)
			end
		end
		if hoverRing then
			hoverRing.Visible = over
		end
	end
	button.MouseEnter:Connect(function()
		over = true
		apply()
	end)
	button.MouseLeave:Connect(function()
		over, down = false, false
		apply()
		base = nil -- (read afresh next time, in case its look changed meanwhile)
	end)
	button.MouseButton1Down:Connect(function()
		down = true
		apply()
	end)
	button.MouseButton1Up:Connect(function()
		down = false
		apply()
	end)
	-- (something that changes its look, like the Backpack's tabs, calls this to re-read it)
	return function()
		if base then
			for _, entry in base do
				if entry[1].Parent then
					entry[1][entry[2]] = entry[3]
				end
			end
		end
		base = nil
		over, down = false, false
		whiten(false)
		pop(false)
		if hoverRing then
			hoverRing.Visible = false
		end
	end
end

return Snappy
