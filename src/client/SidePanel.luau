-- The popups that slide in on the right (QM's Figma ActivePets and EggsPopup, Oct 27): a
-- header (its `look`, with a title), a dark panel under it holding a scrolling column of
-- rows, and the red ">" tab on its left that slides it away. client/PetsPanel and
-- client/EggsPanel each fill one in; only one is open at a time.
--
--   SidePanel.new(root, name, look, title, titleOutline) -> panel
--     panel.gui, panel.header, panel.rows (the ScrollingFrame), panel.title (its label)
--     panel:open() / panel:close() / panel:toggle() / panel:isOpen()
--
-- Its numbers are Figma px (HudKit.fig): the whole thing 1168 x 734, 30 in from the right
-- and centred up and down; the tab 174 square, 273 down; the header 934 x 130, 234 in.

local TweenService = game:GetService("TweenService")

local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local SidePanel = {}
SidePanel.__index = SidePanel

local fig, label, button = HudKit.fig, HudKit.label, HudKit.button
local W, H = 1168, 734
local SLIDE = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local SLIDE_OUT = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP_FROM = 0.85 -- it grows from this as it slides in (QM, Oct 30: popups pop)

local current -- the one open

function SidePanel.new(root, name, look, title, titleOutline)
	local self = setmetatable({}, SidePanel)
	local gui, fresh = Ui.make(root, name, "Frame")
	if fresh then
		gui.BackgroundTransparency = 1
		gui.AnchorPoint = Vector2.new(1, 0.5)
		gui.Position = UDim2.new(1, -fig(30), 0.5, 0)
		gui.Size = UDim2.fromOffset(fig(W), fig(H))
		gui.ZIndex = 10
		gui.Visible = not Ui.live -- (shown in Studio to edit)
	end
	self.gui = gui
	self.shownAt = gui.Position
	local close = button(gui, name .. "Close", 174, 174, { Position = UDim2.fromOffset(0, fig(273)), ZIndex = 4 }, "Red")
	label(close, "Arrow", {
		Text = ">",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(120),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	HudKit.back(gui, "Panel", {
		Name = "Body",
		-- (tucked under the header, so only its bottom corners show rounded)
		Position = UDim2.fromOffset(fig(234), fig(110)),
		Size = UDim2.fromOffset(fig(934), fig(624)),
	})
	self.header = HudKit.back(gui, look, {
		Name = "Header",
		Position = UDim2.fromOffset(fig(234), 0),
		Size = UDim2.fromOffset(fig(934), fig(130)),
		ZIndex = 2,
	})
	self.title = label(gui, "Title", {
		Text = title,
		TextSize = fig(70),
		Position = UDim2.fromOffset(fig(265), fig(23)),
		Size = UDim2.fromOffset(fig(560), fig(85)),
		ZIndex = 4,
	})
	self.title.Outline.Color = titleOutline
	local rows
	rows, fresh = Ui.make(gui, "Rows", "ScrollingFrame")
	if fresh then
		rows.BackgroundTransparency = 1
		rows.BorderSizePixel = 0
		rows.Position = UDim2.fromOffset(fig(265) - 4, fig(160) - 4)
		rows.Size = UDim2.fromOffset(fig(876) + 8 + 10, fig(544))
		rows.CanvasSize = UDim2.new()
		rows.AutomaticCanvasSize = Enum.AutomaticSize.Y
		rows.ScrollingDirection = Enum.ScrollingDirection.Y
		rows.ScrollBarThickness = 6
		rows.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
		rows.ZIndex = 3
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingTop = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = rows
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, fig(36))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = rows
	end
	self.rows = rows
	if Ui.live then
		gui.Visible = false
		close.Activated:Connect(function()
			self:close()
		end)
	end
	return self
end

function SidePanel:isOpen()
	return self.shown == true
end

-- slides in from off the right edge (closing the other one)
function SidePanel:open()
	if self.shown then
		return
	end
	self.shown = true
	if current and current ~= self then
		current:close()
	end
	current = self
	local gui = self.gui
	gui.Visible = true
	gui.Position = self.shownAt + UDim2.fromOffset(fig(W) + fig(60), 0)
	TweenService:Create(gui, SLIDE, { Position = self.shownAt }):Play()
	local pop = gui:FindFirstChild("Pop") or Ui.make(gui, "Pop", "UIScale")
	pop.Scale = POP_FROM
	TweenService:Create(pop, SLIDE, { Scale = 1 }):Play()
	UiFx.play("Open")
end

function SidePanel:close()
	local gui = self.gui
	if not self.shown then
		return
	end
	self.shown = false
	if current == self then
		current = nil
	end
	local out = TweenService:Create(gui, SLIDE_OUT, { Position = self.shownAt + UDim2.fromOffset(fig(W) + fig(60), 0) })
	out.Completed:Connect(function(how)
		if how == Enum.PlaybackState.Completed and not self.shown then
			gui.Visible = false
			gui.Position = self.shownAt
		end
	end)
	out:Play()
	UiFx.play("Close")
end

function SidePanel:toggle()
	if self.shown then
		self:close()
	else
		self:open()
	end
end

return SidePanel
