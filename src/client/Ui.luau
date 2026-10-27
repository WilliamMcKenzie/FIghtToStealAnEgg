-- The HUD and popups as real objects in StarterGui, so QM can edit them in Studio (QM, Oct 26:
-- "how can I edit the native button myself? ... GUI based"). Every piece of UI the scripts
-- make goes through Ui.make, which only creates a child when its parent has none of that
-- name yet; when there is one, it hands that back untouched. So:
--   - tools/studio/uibake.luau runs the same building code in Edit mode, into StarterGui:
--     StarterGui.Hud then holds everything, and QM edits it in Explorer / Properties.
--     Running it again only adds pieces the code has gained since, never resets edits.
--   - In Play the game finds that copy in PlayerGui and only wires it up (clicks, values,
--     tweens); its look is whatever QM left it as. Anything missing is still made, so the
--     game works before a bake, and new pieces show up before the next one.
-- StarterGui isn't in default.project.json, so syncing src/ never touches it. Pieces that
-- repeat are cloned from hidden "...Template" objects (Ui.template), edit those.
--
--   Ui.live                                  -- true in Play, false while baking in Edit
--   Ui.make(parent, name, class, props) -> instance, fresh   -- fresh: just made, so add
--                                            -- its decorations (strokes, corners...) too
--   Ui.screen(name, props) -> ScreenGui      -- PlayerGui's copy in Play, StarterGui's in Edit
--   Ui.template(parent, name, build) -> t    -- parent's hidden template (build() makes it)
--   Ui.copy(t, name, parent) -> clone        -- a shown copy of it

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Ui = {}

Ui.live = RunService:IsRunning()

function Ui.make(parent, name, class, props)
	local found = parent:FindFirstChild(name)
	if found then
		return found, false
	end
	local inst = Instance.new(class)
	inst.Name = name
	if props then
		for k, v in props do
			if k ~= "Name" then
				inst[k] = v
			end
		end
	end
	inst.Parent = parent
	return inst, true
end

function Ui.screen(name, props)
	if not Ui.live then
		return (Ui.make(StarterGui, name, "ScreenGui", props))
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	if StarterGui:FindFirstChild(name) then
		-- (Roblox copies StarterGui into PlayerGui when the character first spawns)
		local copy = playerGui:WaitForChild(name, 30)
		if copy then
			return copy
		end
	end
	return (Ui.make(playerGui, name, "ScreenGui", props))
end

-- a piece that repeats: its hidden template in `parent` (made by `build` the first time)
function Ui.template(parent, name, build)
	local template = parent:FindFirstChild(name)
	if not template then
		template = build()
		template.Name = name
		template.Parent = parent
	end
	template.Visible = false
	return template
end

-- a shown copy of a template, for `parent`
function Ui.copy(template, name, parent)
	local clone = template:Clone()
	clone.Name = name
	clone.Visible = true
	clone.Parent = parent
	return clone
end

function Ui.isTemplate(inst)
	return string.sub(inst.Name, -8) == "Template"
end

return Ui
