-- A beaten boss's bounty (QM, Oct 31; Server/Bosses fires BossBounty to everyone who beat
-- it, then pays them): the "Boss Defeated!" banner sweeps across (client/Banner), and a
-- "+$X" gain popup (a copy of the Cash counter's GainTemplate: client/GainPopups) pops up
-- over where the boss died, holds a moment, then flies down into the Cash counter, which
-- only counts it once it lands (Hud.holdBack) with a bump and a coin sound. The counter's
-- own popup skips it (GainPopups.expect).
--
--   BossBounty.landed   -- RBXScriptSignal: fires as a bounty lands (client/Tutorial)
--   BossBounty.fly(amount, from, size?)  -- just the "+$X" flying into the Cash counter, from a
--                                        -- screen point (the Offline Cash popup's Claim)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Abbrev = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Abbrev"))
local Banner = require(script.Parent.Banner)
local GainPopups = require(script.Parent.GainPopups)
local Hud = require(script.Parent.Hud)
local UiFx = require(script.Parent.UiFx)

local BossBounty = {}
local landedEvent = Instance.new("BindableEvent")
BossBounty.landed = landedEvent.Event

local UP = 0.7 -- the popup starts this far up the boss's height
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BIG = 1.4 -- its size over the boss, x the counter's popup
local HOLD = 0.6 -- seconds it stays over the boss
local FLY = TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local LANDED = 0.7 -- its size as it lands
local BUMP = 1.15 -- the counter's bump as it lands
local BUMP_IN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BUMP_OUT = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local camera = workspace.CurrentCamera

-- a screen point in the scaled HUD root's own (design) pixels
local function toRoot(root, screen)
	local scale = root:FindFirstChildOfClass("UIScale")
	local s = if scale then scale.Scale else 1
	local p = (screen - root.AbsolutePosition) / s
	return UDim2.fromOffset(p.X, p.Y)
end

local function bump(counter)
	local scale = counter:FindFirstChild("Bump") or Instance.new("UIScale")
	scale.Name = "Bump"
	scale.Parent = counter
	local up = TweenService:Create(scale, BUMP_IN, { Scale = BUMP })
	up.Completed:Once(function()
		TweenService:Create(scale, BUMP_OUT, { Scale = 1 }):Play()
	end)
	up:Play()
end

-- the popup pops up at `from` (a screen point), holds, and flies into the Cash counter
local function fly(amount, from, size, onLanded)
	GainPopups.expect("Cash", amount)
	local release = Hud.holdBack("Cash", amount)
	local parts = GainPopups.parts("Cash")
	if not parts then
		release()
		return
	end
	local root = parts.row.Parent
	local popup = parts.template:Clone()
	popup.Name = "BountyPop"
	popup.Visible = true
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.ZIndex = 30
	popup.Amount.Text = "+" .. Abbrev(amount)
	popup.Position = toRoot(root, from)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = popup
	popup.Parent = root
	TweenService:Create(scale, POP, { Scale = size or BIG }):Play()
	task.delay(HOLD + 0.25, function()
		local counter = parts.counter
		local to = counter.AbsolutePosition + counter.AbsoluteSize * Vector2.new(0.3, 0.5)
		TweenService:Create(scale, FLY, { Scale = LANDED }):Play()
		local fly = TweenService:Create(popup, FLY, { Position = toRoot(root, to) })
		fly.Completed:Once(function()
			popup:Destroy()
			release()
			bump(counter)
			UiFx.play("Claim")
			if onLanded then
				onLanded()
			end
		end)
		fly:Play()
	end)
end

function BossBounty.fly(amount, from, size)
	fly(amount, from, size)
end

local function bounty(amount, at, height)
	if typeof(amount) ~= "number" or typeof(at) ~= "Vector3" then
		return
	end
	Banner.show("Boss Defeated!", "Boss")
	local over = at + Vector3.new(0, (height or 10) * UP, 0)
	local p, onScreen = camera:WorldToViewportPoint(over)
	local from = if onScreen then Vector2.new(p.X, p.Y) else camera.ViewportSize * Vector2.new(0.5, 0.4)
	fly(amount, from, BIG, function()
		landedEvent:Fire(amount)
	end)
end

ReplicatedStorage:WaitForChild("BossBounty").OnClientEvent:Connect(bounty)

return BossBounty
