-- Where a player spawns (QM, Oct 31: "when player spawns in they should spawn in front of
-- their pen turned to face pen, with camera facing pen also"): out from their own pen's
-- gate (where its owner's name floats: Server/Map's OwnerSign), turned back to face the
-- pen. Shared so the server (Server/Pens puts the character there) and the client
-- (client/SpawnCam turns the camera to match) agree.
--
--   PenSpawn.pen(index) -> the pen Model or nil (workspace.Map.Base.Pens)
--   PenSpawn.spot(pen) -> CFrame or nil  -- on the floor (y 0) in front of the gate, its
--                                        -- LookVector toward the pen's middle

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local PenSpawn = {}

function PenSpawn.pen(index)
	local map = workspace:FindFirstChild("Map")
	local base = map and map:FindFirstChild("Base")
	local pens = base and base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen
		end
	end
	return nil
end

function PenSpawn.spot(pen)
	local area = pen and pen:FindFirstChild("Area")
	local sign = pen and pen:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if not (area and board) then
		return nil
	end
	local out = (board.Position - area.Position) * Vector3.new(1, 0, 1)
	if out.Magnitude < 0.01 then
		return nil
	end
	out = out.Unit
	local middle = Vector3.new(area.Position.X, 0, area.Position.Z)
	local at = middle + out * (area.Size.X / 2 + Config.PenSpawn.Distance)
	return CFrame.lookAt(at, middle)
end

return PenSpawn
