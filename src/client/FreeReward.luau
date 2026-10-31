-- The free gift (QM, Oct 31: his reference's FREE! present, but Power, not Speed). The present
-- by the gateway (Shared/GiftModel, across from Carl) bobs gently; walking into its ring opens
-- the Free Reward! popup: a lime header with the red X, crossed swords on a turning sunburst,
-- "LIMITED TIME!" over "+500 Power", three cards (Like the game, Favorite the game, Join the
-- group) with a red arrow bobbing over the next one to do, each ticked once done, and Claim!.
-- Claimed (Server/FreeGift, once per player, saved), the Power goes in (its "+500" pops by the
-- Power counter: client/GainPopups) and the gift's FREE!, ring and sparkles go, for you.
--
-- The steps: Roblox doesn't tell a game who liked it, so Like ticks when pressed (on your
-- word). Favorite opens Roblox's own favorite prompt and ticks when you favorite (in Studio,
-- where there's no prompt, it just ticks). Join opens Roblox's join prompt for
-- Config.FreeGift.GroupId and the server checks you're in it on Claim (no GroupId yet: on your
-- word, like Like). Claim with a step left shakes and points the arrow at it.
--
-- Built like the other popups (client/HudKit, Figma px through HudKit.fig) with Ui.make, so
-- it's a real object in StarterGui > Hud > Root > FreeReward for QM to edit in Studio.
--
--   FreeReward.init(root)  -- client/Hud, in Play and in Edit (tools/studio/uibake.luau)

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Abbrev = require(Shared:WaitForChild("Abbrev"))
local Config = require(Shared:WaitForChild("Config"))
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local FreeReward = {}

local fig = HudKit.fig
local label = HudKit.label
local W, H = 2268, 1370 -- the popup (HudKit.popup's size, Figma px)
local HEADER = 283
local ART_X, ART_Y = 560, 590 -- the swords' and sunburst's middle
local BURST = 900
local SWORD = 470
local TEXT_X = 1500 -- the middle of "LIMITED TIME!" and the amount
local CARD_W, CARD_H, CARD_Y, CARD_GAP = 640, 290, 860, 60
local CLAIM_W, CLAIM_H, CLAIM_Y = 760, 165, 1172
local SPIN = 12 -- degrees a second the sunburst turns
local ARROW_BOB = 18 -- Figma px the arrow bobs
local RED_TOP, RED_BOTTOM = Color3.fromHex("ff6a6a"), Color3.fromHex("e00000")
local BLUE_TOP, BLUE_BOTTOM = Color3.fromHex("00ebff"), Color3.fromHex("0090ff") -- (the Power packs' blue)
local STEPS = {
	{ name = "Like", icon = "👍", text = "Like the game" },
	{ name = "Favorite", icon = "⭐", text = "Favorite the game" },
	{ name = "Group", icon = "👥", text = "Join the group" },
}
local AWAY = 12 -- studs past the ring that closes the popup again

local player = Players.LocalPlayer

local function gradient(parent, top, bottom)
	local g, fresh = Ui.make(parent, "Shade", "UIGradient")
	if fresh then
		g.Rotation = 90
		g.Color = ColorSequence.new(top, bottom)
	end
	return g
end

local function cardX(i)
	local total = 3 * CARD_W + 2 * CARD_GAP
	return (W - total) / 2 + (i - 1) * (CARD_W + CARD_GAP)
end

local function build(root)
	local gui, close = HudKit.popup(root, "FreeReward", "Free Reward!", "LimeHeader")

	-- the reward: crossed swords on a sunburst (clipped to the panel)
	local clip, fresh = Ui.make(gui, "Burst", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Position = UDim2.fromOffset(fig(8), fig(HEADER))
		clip.Size = UDim2.fromOffset(fig(W - 16), fig(H - HEADER - 8))
		clip.ZIndex = 2
	end
	HudKit.art(clip, "Sunburst", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(ART_X - 8), fig(ART_Y - HEADER)),
		Size = UDim2.fromOffset(fig(BURST), fig(BURST)),
		ImageColor3 = Color3.fromHex("7fd8ff"),
		ImageTransparency = 0.55,
		ZIndex = 2,
	})
	for _, s in { { "ShopSwordFlip", -95 }, { "ShopSword", 95 } } do
		HudKit.art(gui, s[1], {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(fig(ART_X + s[2]), fig(ART_Y)),
			Size = UDim2.fromOffset(fig(SWORD), fig(SWORD)),
			ZIndex = 4,
		})
	end

	-- "LIMITED TIME!" and the amount
	local limited = label(gui, "Limited", {
		Text = "LIMITED TIME!",
		TextSize = fig(165),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(TEXT_X), fig(440)),
		Size = UDim2.fromOffset(fig(1300), fig(200)),
		ZIndex = 5,
	})
	gradient(limited, RED_TOP, RED_BOTTOM)
	local amount = label(gui, "Amount", {
		Text = "+" .. Abbrev(Config.FreeGift.Amount) .. " Power",
		TextSize = fig(200),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(fig(TEXT_X), fig(650)),
		Size = UDim2.fromOffset(fig(1400), fig(240)),
		ZIndex = 5,
	})
	if not amount:GetAttribute("Thick") then -- (once: an outline QM changed in Studio stays)
		amount:SetAttribute("Thick", true)
		amount.Outline.Thickness = fig(14)
	end
	gradient(amount, BLUE_TOP, BLUE_BOTTOM)

	-- the three steps
	local cards = {}
	for i, step in STEPS do
		local card = HudKit.button(gui, step.name .. "Card", CARD_W, CARD_H, {
			Position = UDim2.fromOffset(fig(cardX(i)), fig(CARD_Y)),
			ZIndex = 5,
		}, "Dark")
		local icon
		icon, fresh = Ui.make(card, "Icon", "TextLabel")
		if fresh then
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.36)
			icon.Size = UDim2.fromOffset(fig(CARD_W), fig(150))
			icon.TextSize = fig(130)
			icon.Text = step.icon
			icon.ZIndex = 7
		end
		label(card, "Text", {
			Text = step.text,
			TextSize = fig(66),
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, fig(CARD_H - 110)),
			Size = UDim2.fromOffset(fig(CARD_W), fig(90)),
			ZIndex = 7,
		})
		local tick
		tick, fresh = Ui.make(card, "Done", "TextLabel")
		if fresh then
			tick.BackgroundTransparency = 1
			tick.AnchorPoint = Vector2.new(0.5, 0.5)
			tick.Position = UDim2.fromOffset(fig(CARD_W - 30), fig(30))
			tick.Size = UDim2.fromOffset(fig(130), fig(130))
			tick.TextSize = fig(110)
			tick.Text = "✅"
			tick.ZIndex = 8
			tick.Visible = not Ui.live -- (shown in Studio to edit)
		end
		cards[step.name] = card
	end
	-- the red arrow over the next step
	local arrow = label(gui, "Arrow", {
		Text = "▼",
		TextSize = fig(150),
		TextColor3 = Color3.fromHex("ff2a2a"),
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(fig(cardX(1) + CARD_W / 2), fig(CARD_Y + 30)),
		Size = UDim2.fromOffset(fig(200), fig(170)),
		ZIndex = 9,
	})

	-- Claim!
	local claim = HudKit.button(gui, "Claim", CLAIM_W, CLAIM_H, {
		Position = UDim2.fromOffset(fig((W - CLAIM_W) / 2), fig(CLAIM_Y)),
		ZIndex = 6,
	}, "GreenEdged")
	label(claim, "Text", {
		Text = "Claim!",
		TextSize = fig(120),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
	})
	return gui, close, claim, cards, arrow, clip.Sunburst
end

-- ---- the gift in the world ----------------------------------------------------------------

local gift -- workspace.Map.FreeGift
local base -- its Present's pivot as built

local function hideGift()
	if not gift then
		return
	end
	local free = gift:FindFirstChild("Label")
	local billboard = free and free:FindFirstChildOfClass("BillboardGui")
	if billboard then
		billboard.Enabled = false
	end
	local sparkles = gift:FindFirstChild("Sparkles")
	if sparkles then
		for _, fx in sparkles:GetChildren() do
			if fx:IsA("ParticleEmitter") or fx:IsA("Light") then
				fx.Enabled = false
			end
		end
	end
	local ring = gift:FindFirstChild("Ring")
	if ring then
		for _, part in ring:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = 1
				part.Transparency = 1
			end
		end
	end
end

local function findGift(map)
	local found = map:WaitForChild("FreeGift", 30)
	if not found then
		return
	end
	gift = found
	local present = gift:WaitForChild("Present", 10)
	base = present and present:GetPivot()
	if player:GetAttribute("FreeGift") then
		hideGift()
	end
end

-- ---- the popup ------------------------------------------------------------------------------

local function wire(gui, close, claim, cards, arrow, burst)
	local remote = ReplicatedStorage:WaitForChild("FreeGiftClaim", 10)
	local s = Config.FreeGift
	local done = {}
	local spinning
	local arrowAt = UDim2.fromOffset(0, 0)

	local function refresh()
		local next
		for _, step in STEPS do
			cards[step.name].Done.Visible = done[step.name] == true
			if not next and not done[step.name] then
				next = step.name
			end
		end
		arrow.Visible = next ~= nil
		if next then
			local card = cards[next]
			arrowAt = UDim2.new(
				0,
				card.Position.X.Offset + (if card.AnchorPoint.X == 0.5 then 0 else card.Size.X.Offset / 2),
				0,
				fig(CARD_Y + 30)
			)
		end
	end

	local function isDone()
		for _, step in STEPS do
			if not done[step.name] then
				return false, step.name
			end
		end
		return true
	end

	local function shut()
		if spinning then
			spinning:Disconnect()
			spinning = nil
		end
		UiFx.popOut(gui)
	end

	local function open()
		if player:GetAttribute("FreeGift") or UiFx.isOpen(gui) then
			return
		end
		-- (already favorited, or in the group: ticked straight away)
		task.spawn(function()
			local ok, fav = pcall(AvatarEditorService.GetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset)
			if ok and fav then
				done.Favorite = true
				refresh()
			end
		end)
		if s.GroupId then
			task.spawn(function()
				local ok, member = pcall(player.IsInGroup, player, s.GroupId)
				if ok and member then
					done.Group = true
					refresh()
				end
			end)
		end
		refresh()
		UiFx.popIn(gui)
		if not spinning then
			local t = 0
			spinning = RunService.RenderStepped:Connect(function(dt)
				t += dt
				burst.Rotation = (burst.Rotation + SPIN * dt) % 360
				arrow.Position = arrowAt + UDim2.fromOffset(0, math.round(math.sin(t * 6) * fig(ARROW_BOB) / 2))
			end)
		end
	end
	FreeReward.open = open

	UiFx.menu(gui, shut)
	close.Activated:Connect(shut)

	cards.Like.Activated:Connect(function()
		done.Like = true -- (Roblox can't tell us: on your word)
		refresh()
	end)
	cards.Favorite.Activated:Connect(function()
		local ok = pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
		if not ok or RunService:IsStudio() then
			done.Favorite = true -- (no prompt here: Studio, or a place that isn't published)
			refresh()
		end
	end)
	AvatarEditorService.PromptSetFavoriteCompleted:Connect(function(result)
		if result == Enum.AvatarPromptResult.Success then
			done.Favorite = true
			refresh()
		end
	end)
	cards.Group.Activated:Connect(function()
		if not s.GroupId then
			done.Group = true -- (no group set yet: on your word)
			refresh()
			return
		end
		task.spawn(function()
			local ok, status = pcall(GroupService.PromptJoinAsync, GroupService, s.GroupId)
			local name = ok and typeof(status) == "EnumItem" and status.Name or ""
			if name == "Joined" or name == "AlreadyMember" then
				done.Group = true
				refresh()
			end
		end)
	end)

	local claiming = false
	claim.Activated:Connect(function()
		local all, missing = isDone()
		if not all then
			UiFx.shake(claim)
			UiFx.shake(cards[missing])
			return
		end
		if claiming or not remote then
			return
		end
		claiming = true
		local ok, got, why = pcall(remote.InvokeServer, remote)
		claiming = false
		if ok and got then
			UiFx.play("Claim")
			shut()
			hideGift()
			return
		end
		if why == "claimed" then
			shut()
			hideGift()
		elseif why == "group" then
			done.Group = false
			refresh()
			UiFx.shake(cards.Group)
		else
			UiFx.shake(claim)
		end
	end)
	player:GetAttributeChangedSignal("FreeGift"):Connect(function()
		if player:GetAttribute("FreeGift") then
			hideGift()
		end
	end)

	-- walking into the ring opens it (once each time you step in); walking off closes it
	local inside = false
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if not (gift and gift.Parent) then
			return
		end
		local pivot = gift:GetPivot()
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local away = if hrp then ((hrp.Position - pivot.Position) * Vector3.new(1, 0, 1)).Magnitude else math.huge
		-- (the present bobs and sways while you're near enough to see it)
		local present = gift:FindFirstChild("Present")
		if present and base and away < 250 then
			present:PivotTo(base * CFrame.new(0, s.Bob * (math.sin(t * 2) + 1) / 2, 0) * CFrame.Angles(0, math.sin(t * 0.9) * 0.12, 0))
		end
		if player:GetAttribute("FreeGift") or not player:GetAttribute("Loaded") then
			return
		end
		if away <= s.OpenRadius then
			if not inside then
				inside = true
				open()
			end
		elseif away > s.OpenRadius + 2 then
			inside = false
			if away > s.OpenRadius + AWAY and UiFx.isOpen(gui) then
				shut()
			end
		end
	end)
end

function FreeReward.init(root)
	local gui, close, claim, cards, arrow, burst = build(root)
	if not Ui.live then
		return
	end
	gui.Visible = false
	task.spawn(wire, gui, close, claim, cards, arrow, burst)
	task.spawn(function()
		local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 60)
		if map then
			findGift(map)
		end
	end)
end

return FreeReward
