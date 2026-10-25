# usage: mkstale.py out.luau : writes Luau that removes scripts (and folders) the open place
# has under Shared, Server and Client but src/ no longer does (mkload.py only adds and
# updates, so a file deleted or renamed in the repo stays in the place until this runs).
import json, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def expected(path):
    """{ name: subtree or True } for a src folder, as Rojo names things."""
    out = {}
    for f in sorted(os.listdir(path)):
        full = os.path.join(path, f)
        if os.path.isdir(full):
            out[f] = expected(full)
        elif f.endswith(".luau") or f.endswith(".lua"):
            name = f.rsplit(".", 1)[0]
            for suffix in (".server", ".client"):
                if name.endswith(suffix):
                    name = name[: -len(suffix)]
            if name != "init":
                out[name] = True
    return out


roots = {
    "game.ReplicatedStorage.Shared": expected(os.path.join(ROOT, "src", "shared")),
    "game.ServerScriptService.Server": expected(os.path.join(ROOT, "src", "server")),
    "game.StarterPlayer.StarterPlayerScripts.Client": expected(os.path.join(ROOT, "src", "client")),
}
code = """local HttpService = game:GetService("HttpService")
local trees = HttpService:JSONDecode(%s)
local gone = {}
local function prune(inst, want)
	for _, child in inst:GetChildren() do
		if child:IsA("LuaSourceContainer") or child:IsA("Folder") then
			local w = want[child.Name]
			if w == nil then
				table.insert(gone, child:GetFullName())
				child:Destroy()
			elseif type(w) == "table" then
				prune(child, w)
			end
		end
	end
end
for path, want in trees do
	local inst = game
	for part in string.gmatch(path, "[^.]+") do
		if part ~= "game" then
			inst = inst and inst:FindFirstChild(part)
		end
	end
	if inst then
		prune(inst, want)
	end
end
return "removed " .. #gone .. (if #gone > 0 then ": " .. table.concat(gone, ", ") else "")
""" % json.dumps(json.dumps(roots))
open(sys.argv[1], "w").write(code)
