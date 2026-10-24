# Studio helpers

Drive the open Roblox Studio through its MCP server (`StudioMCP --stdio`), from this Mac.

- `python3 lu.py file.luau [Edit|Client|Server]` runs Luau in Studio (`STUDIO=<id>` picks an instance).
  `python3 lu.py --tool <name> '<json>'` calls any StudioMCP tool (`OUT=x.png` saves a screen capture).
- `python3 mkload.py load.luau` then `python3 lu.py load.luau`: syncs `src/` into the open place
  (the Rojo layout of default.project.json). Studio must be in Edit mode (stop Play first).
- `OUT=assets/meshes/ids.json python3 meshup.py assets/meshes/ids.json *.obj`: uploads OBJ meshes.
- `OUT=assets/ui/ids.json python3 imgup.py File.png`: uploads PNGs as images.

The open place is the source of truth for `Workspace.World` (built by `tools/lineup.luau`), so
don't rebuild the place from Rojo over it.
- `MapBaker.lua` is a Studio plugin (copy it into the Plugins folder): **Map > Rebuild** bakes
  Shared/MapData into `workspace.Map` in Edit mode, **Map > Import .map** bakes a file from the map
  editor (tools/mapeditor) straight from disk. Save the place after.
