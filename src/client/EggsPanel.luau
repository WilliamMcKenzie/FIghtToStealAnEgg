-- The Growing Eggs popup (QM's Figma EggsPopup, Oct 27), opened by the egg (Eggs) button on
-- the right: a tan header with "Growing Eggs" and the yellow GROW ALL (every egg ready at
-- once, for Robux: not sold yet, Config.Hatch.GrowAllProduct), and under it a row per egg
-- in your pen (your PenEggs attribute: Server/Hatchery): its render (Shared/ItemIcons) and
-- a green bar filling as it grows, with the time left over it ("12s", "4:05", "2h"); once
-- it's grown the bar pops into a green HATCH button (GROW ALL's look) that hatches it from
-- wherever you are (HatchEgg). The red ">" tab on its left slides it away (client/SidePanel).
--
--   EggsPanel.init(root, eggsButton)   -- once, from Hud
--
-- In Studio: StarterGui > Hud > Root > EggsPanel. Rows are copies of Rows > RowTemplate
-- (its HatchPop > Hatch button sits over the bar, hidden till the egg's ready).

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemIcons = require(Shared.ItemIcons)
local HudKit = require(script.Parent.HudKit)
local SidePanel = require(script.Parent.SidePanel)
local Ui = require(script.Parent.Ui)

local EggsPanel = {}

local player = Players.LocalPlayer
local fig, label, button = HudKit.fig, HudKit.label, HudKit.button
local TITLE_OUTLINE = Color3.fromHex("8a3a00")
local TICK = 0.2 -- seconds between the bars' updates while it's open
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- (HATCH growing in)

-- (Figma px, through fig: the popup itself is client/SidePanel's)
-- a row (Figma Card: 876 x 207): the egg, then the bar (639 x 72 with its 6px border)
local function rowTemplate()
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromOffset(fig(876), fig(207))
	HudKit.back(row, "EggCard", {})
	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Position = UDim2.fromOffset(fig(13), fig(15))
	picture.Size = UDim2.fromOffset(fig(177), fig(177))
	picture.ZIndex = 2
	picture.Parent = row
	local track = HudKit.back(row, "EggTrack", {
		Name = "Track",
		Position = UDim2.fromOffset(fig(202 + 6), fig(67 + 6)),
		Size = UDim2.fromOffset(fig(639 - 12), fig(72 - 12)),
		ZIndex = 2,
	})
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 3
	clip.Parent = track
	-- (the green keeps the whole track's size, so it's cut, not squashed)
	HudKit.back(clip, "EggGrow", { Name = "Grow", Size = UDim2.fromOffset(fig(639 - 12), fig(72 - 12)), ZIndex = 3 })
	label(track, "Left", {
		Text = "12s",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(40),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	return row
end

-- the HATCH button over the bar (made missing only, so a baked RowTemplate gets it too): in a
-- holder whose Pop UIScale grows it in from its middle, as the button's own UIScale is its hover
local function hatchButton(row)
	local pop, fresh = Ui.make(row, "HatchPop", "Frame")
	if fresh then
		pop.BackgroundTransparency = 1
		pop.AnchorPoint = Vector2.new(0.5, 0.5)
		pop.Position = UDim2.fromOffset(fig(202 + 639 / 2), fig(67 + 72 / 2))
		pop.Size = UDim2.fromOffset(fig(639), fig(90))
		pop.ZIndex = 6
		pop.Visible = false
	end
	Ui.make(pop, "Pop", "UIScale")
	local b = button(pop, "Hatch", 639, 90, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 6,
	}, "GreenYellow")
	label(b, "Text", {
		Text = "HATCH",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(40),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
	})
	return b
end

-- time left: "12s" under a minute, "4:05" under an hour, then whole hours ("2h")
local function left(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%dh", seconds // 3600)
	elseif seconds >= 60 then
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end

local function placed()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PenEggs") or "[]")
	return if ok and type(list) == "table" then list else {}
end

function EggsPanel.init(root, eggsButton)
	local panel = SidePanel.new(root, "EggsPanel", "TanHeader", "Growing Eggs", TITLE_OUTLINE)
	local grow = button(panel.gui, "EggsGrowAll", 302, 90, { Position = UDim2.fromOffset(fig(850), fig(19)), ZIndex = 4 }, "Yellow")
	label(grow, "Text", {
		Text = "GROW ALL",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = fig(35),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})
	local template = Ui.template(panel.rows, "RowTemplate", rowTemplate)
	hatchButton(template)
	if not Ui.live then
		return
	end
	if eggsButton then
		eggsButton.Activated:Connect(function()
			panel:toggle()
		end)
	end
	local hatchRemote = ReplicatedStorage:WaitForChild("HatchEgg")
	grow.Activated:Connect(function()
		-- (not sold yet: needs its developer product and the server side)
		if Config.Hatch.GrowAllProduct then
			MarketplaceService:PromptProductPurchase(player, Config.Hatch.GrowAllProduct)
		end
	end)

	local made = {} -- { { row, egg, ready } }
	local function update()
		local now = workspace:GetServerTimeNow()
		for _, m in made do
			local row, egg = m[1], m[2]
			local total = tonumber(egg.d) or Config.Hatch.Time[egg.k] or Config.Hatch.Default
			local rest = (tonumber(egg.t) or 0) - now
			local done = math.clamp(1 - rest / math.max(total, 1), 0, 1)
			row.Track.Clip.Size = UDim2.fromScale(done, 1)
			row.Track.Left.Text = if rest <= 0 then "Ready" else left(rest)
			local ready = rest <= 0
			local was = m[3]
			if ready ~= was then
				m[3] = ready
				local pop = row.HatchPop
				row.Track.Visible = not ready
				pop.Visible = ready
				if ready then
					-- (it grows in where you can see it; it's just there if it was ready already)
					if panel:isOpen() and was ~= nil then
						pop.Pop.Scale = 0
						TweenService:Create(pop.Pop, POP, { Scale = 1 }):Play()
					else
						pop.Pop.Scale = 1
					end
				end
			end
		end
	end
	local function refresh()
		for _, m in made do
			m[1]:Destroy()
		end
		table.clear(made)
		local eggs = placed()
		-- (the soonest ready first)
		table.sort(eggs, function(a, b)
			return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
		end)
		for i, egg in eggs do
			local row = Ui.copy(template, "Row" .. i, panel.rows)
			row.LayoutOrder = i
			row.Picture.Image = ItemIcons.Eggs[egg.k] or ""
			local hatch = row.HatchPop.Hatch
			HudKit.hover(hatch) -- (copies aren't wired: the template's wiring stays with it)
			local sent = false
			hatch.Activated:Connect(function()
				if not sent and (tonumber(egg.t) or 0) <= workspace:GetServerTimeNow() then
					sent = true -- (once: the row goes when PenEggs drops it)
					hatchRemote:FireServer(egg.id)
				end
			end)
			table.insert(made, { row, egg })
		end
		update()
	end
	refresh()
	player:GetAttributeChangedSignal("PenEggs"):Connect(refresh)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since >= TICK and panel:isOpen() then
			since = 0
			update()
		end
	end)
end

return EggsPanel
