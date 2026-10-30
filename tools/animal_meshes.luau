-- The animals' low-poly meshes (QM, Oct 14; tools/bbmodel_to_luau.py --meshes): one MeshPart
-- per mesh in ReplicatedStorage.AnimalMeshes, named as its .obj, which Rig.luau copies (scripts
-- can't set MeshId, so the game can't make them itself). (From LassoForEggs: QM's uploads.) Rerunnable: run in the command bar after filling IDS.
--
-- To fill IDS: upload each assets/meshes/<Kind>/<Name>.obj (Asset Manager > Bulk Import, or
-- Import 3D: units studs, no rig, keep the name) and put its mesh asset id next to its name.
local AssetService = game:GetService("AssetService")
local IDS = {
	GiantRafflesia_Mosslight_Stem = 138897571228769, -- (the Giant Rafflesia, a Meadow boss: QM Oct 25)
	GiantRafflesia_Petal_Petal1 = 134402827558101,
	GiantRafflesia_Petal_Petal2 = 122501213903802,
	GiantRafflesia_Petal_Petal3 = 137440297596070,
	GiantRafflesia_Petal_Petal4 = 106403228068807,
	GiantRafflesia_Petal_Petal5 = 133284589944906,
	GiantRafflesia_Petaldark_Flower = 126991300195113,
	GiantRafflesia_Rim_Flower = 91295063947723,
	GiantRafflesia_Vine_Stem = 138332442612398,
	GiantRafflesia_Vine_root = 71053029294374,
	GiantRafflesia_Wart_Petal1 = 97902420267084,
	GiantRafflesia_Wart_Petal2 = 93712028390221,
	GiantRafflesia_Wart_Petal3 = 140704345987263,
	GiantRafflesia_Wart_Petal4 = 124018537708046,
	GiantRafflesia_Wart_Petal5 = 78180364957226,
	GiantRafflesia_Well_Flower = 88148812378304,
	Bat_Fur_neck = 81329754956163, -- (LassoAPet's Bat: the Blood Bat boss, QM Oct 30)
	Bat_Fur_root = 140436210691479,
	Bat_Wing_WingL = 96644882542231,
	Bat_Wing_WingL2 = 138337495224235,
	Bat_Wing_WingR = 101191126037721,
	Bat_Wing_WingR2 = 76684957771569,
	AncientTreant_Leaf_ArmL = 72520559240156, -- (LassoAPet's Ancient Treant: the Elder Treant boss, QM Oct 30)
	AncientTreant_Leaf_ArmR = 138556975636001,
	AncientTreant_Leaf_neck = 135473395019785,
	AncientTreant_Bark_ArmL = 100405580096422,
	AncientTreant_Bark_ArmR = 91526866992805,
	AncientTreant_Bark_root = 115478703668645,
	AncientTreant_Moss_root = 93576707636543,
}
local folder = game.ReplicatedStorage:FindFirstChild("AnimalMeshes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "AnimalMeshes"
	folder.Parent = game.ReplicatedStorage
end
for name, id in IDS do
	if id == 0 then
		continue
	end
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://" .. id), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise, -- (no level-of-detail blobbing: QM, Oct 15, the Treant's low-poly canopy came out lumpy)
		})
	end)
	if not ok then
		warn(name, part)
		continue
	end
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.DoubleSided = false
	part.Parent = folder
end
print(#folder:GetChildren(), "animal meshes")
