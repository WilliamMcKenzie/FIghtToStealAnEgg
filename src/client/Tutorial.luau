-- The new player tutorial (QM, Oct 31; paced like LassoAPet's, with our own steps and
-- words). One thing at a time: a banner sweeping across the top says what to do
-- (client/Banner), arrows on the ground lead the way (client/ArrowTrail, LassoAPet's) and a
-- pulsing tap hand points at what to press. While it runs the HUD is hidden (every
-- button, counter and the hotbar; the boss bar still shows in the fight), and it comes
-- back piece by piece as it's needed.
--
--   1. place  you start holding a Horse egg (Server/Tutorial) and your pen glows
--             (client/PenGlow): "Place your egg!", the hand and arrows on your pen
--   2. hatch  it's ready at once (Config.Tutorial.HatchTime): "Hatch your egg!", arrows to
--             it; PenEggs' big arrow is over it and its prompt hatches it
--   3. steal  "Steal an egg!", arrows to the nearest egg in the Meadow's nests (filled at
--             once if they're empty: TutorialEggs)
--   4. fight  its boss (always Config.Tutorial.Boss, all but harmless): "Fight boss!".
--             Dying sends you back to 3
--   5. bow    the bounty flies into your Cash (now shown: client/BossBounty): "Buy a bow!",
--             arrows to Carl and the hand on him, then on the bow's Buy in his shop
--             (buying equips it)
--   6. train  "Train with weapons to become stronger!": arrows to the Meadow training
--             ground's blocker, its price reading FREE, the hand on its Buy; then arrows
--             to the nearest mob in there. Your first hit on one ends it (Server/Tutorial
--             clears the Tutorial attribute), and the whole HUD comes back.
--
-- Runs whenever your Tutorial attribute is on (a new account, or "/tutorial").

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Abbrev = require(Shared.Abbrev)
local Banner = require(script.Parent.Banner)
local WeaponShop = require(script.Parent.WeaponShop)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local T = Config.Tutorial

local TAP = "rbxassetid://134865745295413" -- LassoAPet's assets/ui/TapHand.png (QM's)
local TAP_SIZE = 96 -- px tall (it's 488 x 610)
local TAP_TIP = Vector2.new(0.365, 0.03) -- the fingertip, in the picture
-- (the HUD's pieces it hides, in StarterGui > Hud > Root: client/Hud)
local HIDE = { "ShopButton", "IndexButton", "EggsButton", "PetsButton", "Power", "Cash", "Hotbar", "OfflineEarn" }
local WORDS = {
	place = "Place your egg!",
	hatch = "Hatch your egg!",
	steal = "Steal an egg!",
	fight = "Fight boss!",
	bow = "Buy a bow!",
	train = "Train with weapons to become stronger!",
}
local AFTER_BOSS = 2.2 -- seconds after the bounty lands till "Buy a bow!" (the Boss Defeated banner's sweep)

local gen = 0 -- bumped by every (re)start ("/tutorial" mid-way starts over)
local myGen = 0 -- the run going now's
local function on()
	return player:GetAttribute("Tutorial") == true and gen == myGen
end

-- ---- the HUD, hidden -----------------------------------------------------------------------

local hidden = {} -- [GuiObject] = { wanted (its Visible as the HUD would have it), conn }

local function hide(object)
	if hidden[object] then
		return
	end
	local h = { wanted = object.Visible }
	h.conn = object:GetPropertyChangedSignal("Visible"):Connect(function()
		if object.Visible then
			h.wanted = true
			object.Visible = false
		end
	end)
	hidden[object] = h
	object.Visible = false
end

local function reveal(object)
	local h = hidden[object]
	if h then
		hidden[object] = nil
		h.conn:Disconnect()
		object.Visible = h.wanted
	end
end

local function hudRoot()
	local hud = player.PlayerGui:FindFirstChild("Hud")
	return hud and hud:FindFirstChild("Root")
end

local function hideHud()
	local root = hudRoot()
	if not root then
		return
	end
	for _, name in HIDE do
		local object = root:FindFirstChild(name)
		if object and object:IsA("GuiObject") then
			hide(object)
		end
	end
end

local function revealHud(name)
	local root = hudRoot()
	local object = root and root:FindFirstChild(name)
	if object then
		reveal(object)
	end
end

local function revealAll()
	for object in hidden do
		reveal(object)
	end
end

-- ---- the tap hand, the arrows and the banner -----------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 40
local tap = Instance.new("ImageLabel")
tap.Name = "TapHand"
tap.BackgroundTransparency = 1
tap.Image = TAP
tap.AnchorPoint = TAP_TIP
tap.Size = UDim2.fromOffset(math.round(TAP_SIZE * 488 / 610), TAP_SIZE)
tap.Visible = false
local tapScale = Instance.new("UIScale")
tapScale.Parent = tap
tap.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local tapAt -- a GuiObject, a Vector3 in the world, or nil
local guideAt -- a Vector3 or an Instance (followed) to lead you to, or nil
local trail = require(script.Parent.ArrowTrail).new()
local said = {} -- [step] = true once its banner's been up this run

local function say(step)
	if not said[step] then
		said[step] = true
		Banner.show(WORDS[step], "Prompt")
	end
end

local function where(target)
	if typeof(target) == "Vector3" then
		return target
	elseif typeof(target) == "Instance" and target.Parent then
		return if target:IsA("Model")
			then target:GetPivot().Position
			elseif target:IsA("BasePart") then target.Position
			else nil
	end
	return nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

RunService.RenderStepped:Connect(function()
	-- the tap hand
	local show = false
	if typeof(tapAt) == "Instance" and tapAt:IsA("GuiObject") and tapAt.Visible and tapAt.AbsoluteSize.X > 0 then
		local c = tapAt.AbsolutePosition + tapAt.AbsoluteSize / 2
		tap.Position = UDim2.fromOffset(c.X, c.Y)
		show = true
	elseif typeof(tapAt) == "Vector3" then
		local p, onScreen = camera:WorldToViewportPoint(tapAt)
		if onScreen then
			tap.Position = UDim2.fromOffset(p.X, p.Y)
			show = true
		end
	end
	tap.Visible = show
	tapScale.Scale = 1 + 0.12 * math.sin(os.clock() * 6)
	-- the arrows, from just in front of you along the ground
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = where(guideAt)
	if root and target then
		local from = Vector3.new(root.Position.X, 0, root.Position.Z)
		local to = Vector3.new(target.X, 0, target.Z)
		local along = to - from
		if along.Magnitude > 8 then
			rayParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("ArrowTrail") }
			local hit = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rayParams)
			local y = (if hit then hit.Position.Y else root.Position.Y - 5) + 0.3
			from += along.Unit * 4
			trail.draw(Vector3.new(from.X, y, from.Z), Vector3.new(to.X, y, to.Z))
		else
			trail.draw()
		end
	else
		trail.draw()
	end
end)

local function point(hand, arrows)
	tapAt, guideAt = hand, arrows
end

-- ---- what's where ----------------------------------------------------------------------

local function myArea()
	local index = player:GetAttribute("Pen")
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen:FindFirstChild("Area")
		end
	end
	return nil
end

-- your placed eggs (PenEggs), and the spot of the last one put down (x, z from the
-- middle of your pen's Area), or nil
local function penEggs()
	local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("PenEggs") or "[]")
	return if ok and type(list) == "table" then list else {}
end
local function lastEgg()
	local area = myArea()
	local list = penEggs()
	local e = list[#list]
	if not (area and type(e) == "table" and type(e.x) == "number" and type(e.z) == "number") then
		return nil
	end
	return area.CFrame:PointToWorldSpace(Vector3.new(e.x, -area.Size.Y / 2, e.z))
end

local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- the nearest of `list` (Instances) to you, or nil
local function nearest(list)
	local root = myRoot()
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, item in list do
		local at = where(item)
		if at then
			local d = (at - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = item, d
			end
		end
	end
	return best
end

-- the Meadow's eggs waiting in their nests
local function meadowEggs()
	local now = workspace:GetServerTimeNow()
	local list = {}
	for _, egg in CollectionService:GetTagged("Egg") do
		if
			egg:GetAttribute("Biome") == "Meadow"
			and egg.Parent
			and CollectionService:HasTag(egg.Parent, "Nest")
			and not egg:GetAttribute("Vanish")
			and (egg:GetAttribute("PopAt") or 0) <= now
		then
			table.insert(list, egg)
		end
	end
	return list
end

local function meadowBoss()
	local folder = workspace:FindFirstChild("Bosses")
	for _, body in if folder then folder:GetChildren() else {} do
		if body:GetAttribute("Biome") == "Meadow" then
			return body
		end
	end
	return nil
end

local function carl()
	local map = workspace:FindFirstChild("Map")
	local vendors = map and map:FindFirstChild("Vendors")
	for _, stall in if vendors then vendors:GetChildren() else {} do
		local spot = stall:FindFirstChild("CarlSpot", true)
		if spot then
			return spot
		end
	end
	return nil
end

local function ownsWeapon(id)
	for owned in string.gmatch(player:GetAttribute("Weapons") or "", "[^,]+") do
		if owned:match("^[^:]+") == id then
			return true
		end
	end
	return false
end

-- the Meadow training ground's blocker (Map.Blockers; client/Regions takes it out of the
-- world once you own it)
local function groundBlocker()
	local map = workspace:FindFirstChild("Map")
	local blockers = map and map:FindFirstChild("Blockers")
	for _, model in if blockers then blockers:GetChildren() else {} do
		if model:GetAttribute("Training") and model:GetAttribute("Region") == T.Ground then
			return model
		end
	end
	return nil
end

-- the world spot of the blocker's Buy button on the face toward you (its SurfaceGui's
-- layout: centred across, its height from the top read off the button)
local function buyButtonSpot(model)
	local wall = model:FindFirstChild("Wall")
	local root = myRoot()
	if not (wall and root) then
		return nil
	end
	local toward = (root.Position - wall.Position):Dot(wall.CFrame.LookVector) >= 0
	local face = wall:FindFirstChild(if toward then "FaceFront" else "FaceBack")
	local button = face and face:FindFirstChild("Buy", true)
	local down = wall.Size.Y * 0.2 -- (a guess till the button's laid out)
	if button and button.AbsoluteSize.Y > 0 and face.PixelsPerStud > 0 then
		local fromTop = (button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2) / face.PixelsPerStud
		down = fromTop - wall.Size.Y / 2
	end
	local out = wall.CFrame.LookVector * (if toward then 1 else -1) * (wall.Size.Z / 2 + 0.2)
	return wall.Position - wall.CFrame.UpVector * down + out
end

-- the blocker's price reads FREE in the tutorial (Server/Regions doesn't charge for it);
-- put back after
local freed = {} -- { { label, text } } or { { coin } }
local function setFree(model, free)
	if free then
		local cost = Config.Training.Grounds[T.Ground] and Config.Training.Grounds[T.Ground].Cost
		local price = cost and Abbrev(cost)
		for _, d in model:GetDescendants() do
			if d:IsA("TextLabel") and d.Text == price then
				table.insert(freed, { d, d.Text })
				d.Text = "FREE"
				d.Size = UDim2.fromOffset(4 * 52, d.Size.Y.Offset)
				local coin = d.Parent and d.Parent:FindFirstChildWhichIsA("ImageLabel")
				if coin and coin.Visible then
					table.insert(freed, { coin })
					coin.Visible = false
				end
			end
		end
	else
		for _, f in freed do
			if f[2] then
				f[1].Text = f[2]
				f[1].Size = UDim2.fromOffset(#f[2] * 52, f[1].Size.Y.Offset)
			else
				f[1].Visible = true
			end
		end
		table.clear(freed)
	end
end

local function trainingMobs()
	local folder = workspace:FindFirstChild("Mobs")
	local list = {}
	for _, body in if folder then folder:GetChildren() else {} do
		if body:GetAttribute("Ground") == T.Ground and (body:GetAttribute("Health") or 0) > 0 then
			table.insert(list, body)
		end
	end
	return list
end

-- ---- the steps ------------------------------------------------------------------------------

-- runs `each` every frame-ish till done() or the tutorial's off; true if done()
local function till(done, each)
	while on() do
		if done() then
			return true
		end
		if each then
			each()
		end
		task.wait(0.1)
	end
	return false
end

local landed = false
require(script.Parent.BossBounty).landed:Connect(function()
	landed = true
end)
ReplicatedStorage:WaitForChild("BossBounty").OnClientEvent:Connect(function()
	if on() then
		revealHud("Cash") -- (before the bounty flies into it)
	end
end)

local running = false
local function run(thisGen)
	while running do -- (the last run winds down first)
		task.wait(0.1)
	end
	if thisGen ~= gen then
		return
	end
	running = true
	myGen = thisGen
	said = {}
	local since = os.clock()
	till(function() -- (once the HUD's built: every piece it hides, or 10 seconds)
		local root = hudRoot()
		if not root then
			return false
		end
		for _, name in HIDE do
			if not root:FindFirstChild(name) and os.clock() - since < 10 then
				return false
			end
		end
		return true
	end)
	hideHud()

	-- 1. place your egg
	till(function()
		return player:GetAttribute("TutorialPlaced") == true
	end, function()
		local area = myArea()
		if area and player:GetAttribute("Holding") then
			say("place")
			local floor = area.Position - Vector3.new(0, area.Size.Y / 2, 0)
			point(floor + Vector3.new(0, 1, 0), floor)
		else
			point(nil, nil)
		end
	end)

	-- 2. hatch it
	local waiting = #penEggs()
	till(function()
		return #penEggs() < waiting
	end, function()
		say("hatch")
		point(nil, lastEgg())
	end)
	point(nil, nil)
	task.wait(2) -- (the pet jumps out)

	-- 3. steal an egg, 4. fight its boss (back to 3 if you die)
	local asked = 0
	while on() do
		landed = false
		till(function()
			return player:GetAttribute("LockedIn") == "Meadow"
		end, function()
			say("steal")
			local list = meadowEggs()
			if #list == 0 and os.clock() - asked > 3 then
				asked = os.clock()
				ReplicatedStorage:WaitForChild("TutorialEggs"):FireServer()
			end
			point(nil, nearest(list))
		end)
		point(nil, nil)
		till(function()
			local boss = meadowBoss()
			return landed
				or player:GetAttribute("LockedIn") ~= "Meadow"
				or (boss ~= nil and not boss:GetAttribute("Intro"))
		end)
		said.fight = nil
		till(function()
			return landed or player:GetAttribute("LockedIn") ~= "Meadow"
		end, function()
			say("fight")
		end)
		-- (the fight's over: if it died, its bounty's on the way; wait for it to land)
		local over = os.clock()
		till(function()
			return landed or os.clock() - over > 3
		end)
		if landed then
			break
		end
		said.steal = nil -- (you died: steal another)
	end
	revealHud("Cash")
	task.wait(AFTER_BOSS)

	-- 5. buy a bow from Carl
	till(function()
		return ownsWeapon(T.Weapon)
	end, function()
		say("bow")
		local spot = carl()
		if WeaponShop.isOpen() then
			point(WeaponShop.buyButton(T.Weapon), nil)
		elseif spot then
			point(spot.Position + Vector3.new(0, 4, 0), spot)
		end
	end)
	point(nil, nil)

	-- 6. buy the Meadow training ground (FREE), then hit something in it
	local blocker = groundBlocker()
	if blocker then
		setFree(blocker, true)
	end
	till(function()
		return player:GetAttribute("Train" .. T.Ground) == true
	end, function()
		say("train")
		if blocker and blocker.Parent then
			local spot = buyButtonSpot(blocker)
			point(spot, blocker:FindFirstChild("Wall"))
		else
			point(nil, nil)
		end
	end)
	till(function()
		return false
	end, function()
		say("train")
		point(nil, nearest(trainingMobs()))
	end)

	-- done (Server/Tutorial turned it off)
	point(nil, nil)
	if blocker then
		setFree(blocker, false)
	end
	if not player:GetAttribute("Tutorial") then
		revealAll()
	end
	running = false
end

local function check()
	if player:GetAttribute("Tutorial") == true then
		gen += 1
		task.spawn(run, gen)
	elseif not running then
		point(nil, nil)
		revealAll()
	end
end
player:GetAttributeChangedSignal("Tutorial"):Connect(check)
check()

return nil
