-- Boss sounds (QM, Oct 31): each boss cries as it rises out of its dais (just as the intro's
-- camera gets to it: client/BossIntro) or wakes up, and cries again, pitched down, with a
-- thump, as it dies. A biter (Config.BossSounds.Cries[Kind].attack) bites as each attack
-- winds up. Enemy swipes whoosh as they strike (client/Swipes), red circles thump as they
-- go off (client/Bombs) and minions thud as they land from the sky. The cries are
-- LassoAPet's boss cries, reused or re-pitched: Config.BossSounds. All through client/Sfx,
-- so heard only while on screen.
--
--   BossSounds.play(entry, at, pitch?) -- entry: { id, volume, pitch? } from Config.BossSounds

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Sfx)

local S = Config.BossSounds
local INTRO = Config.BossIntro

local BossSounds = {}

local function resolve(id)
	return S.Sounds[id] or id
end

function BossSounds.play(entry, at, pitch)
	if not entry then
		return nil
	end
	local s = Sfx.play(resolve(entry.id), entry.volume or 0.5, at)
	if s then
		s.PlaybackSpeed = (entry.pitch or 1) * (pitch or 1)
	end
	return s
end

local function cryOf(body)
	return S.Cries[body:GetAttribute("Kind")] or S.Default
end

local function cry(body, pitch, loud)
	if not body.Parent then
		return
	end
	local c = cryOf(body)
	BossSounds.play({ id = c.id, volume = (c.volume or 0.5) * (loud or 1), pitch = c.pitch }, body, pitch)
end

-- a boss in workspace.Bosses: its cry on arriving or waking, and on dying
local watched = {}
local function watch(body)
	if not body:IsA("BasePart") or watched[body] then
		return
	end
	watched[body] = true
	if body:GetAttribute("Intro") then
		task.delay(INTRO.PanIn, cry, body) -- (as it starts to rise, the camera on it)
	end
	body:GetAttributeChangedSignal("Asleep"):Connect(function()
		if body:GetAttribute("Asleep") == false then
			cry(body)
		end
	end)
	local died = false
	body:GetAttributeChangedSignal("Health"):Connect(function()
		if not died and (body:GetAttribute("Health") or 1) <= 0 then
			died = true
			cry(body, S.DeathPitch, S.DeathVolume)
			BossSounds.play(S.Death, body)
		end
	end)
	body.AncestryChanged:Connect(function()
		if not body.Parent then
			watched[body] = nil
		end
	end)
end

task.spawn(function()
	local folder = workspace:WaitForChild("Bosses")
	for _, body in folder:GetChildren() do
		watch(body)
	end
	folder.ChildAdded:Connect(watch)
end)

-- a minion dropped from the sky (Server/Minions' DropAt / Drop, on server time): a thud
-- as it lands
task.spawn(function()
	local folder = workspace:WaitForChild("Mobs")
	folder.ChildAdded:Connect(function(body)
		local dropAt = body:GetAttribute("DropAt")
		if not (body:IsA("BasePart") and dropAt) then
			return
		end
		local wait = dropAt + (body:GetAttribute("Drop") or 0) - workspace:GetServerTimeNow()
		if wait > 0 then
			task.delay(wait, function()
				if body.Parent then
					BossSounds.play(S.Land, body)
				end
			end)
		end
	end)
end)

-- a biter's bite as each attack winds up (Server/BossAttacks' BossAnim)
task.spawn(function()
	ReplicatedStorage:WaitForChild("BossAnim").OnClientEvent:Connect(function(body, _, windup)
		local c = body and S.Cries[body:GetAttribute("Kind")]
		if not (c and c.attack) then
			return
		end
		task.delay(math.max((windup or 0) - 0.1, 0), function()
			if body.Parent and (body:GetAttribute("Health") or 1) > 0 then
				BossSounds.play({ id = c.attack, volume = S.AttackVolume }, body)
			end
		end)
	end)
end)

return BossSounds
