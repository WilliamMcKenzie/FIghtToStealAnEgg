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
  It also keeps `workspace.StudStyle` live in Edit mode: its `GroundTransparency`/`Transparency`
  and `GroundTileScale`/`TileScale` attributes hold for every stud Texture (Shared/StudStyle).

## The UI in StarterGui (QM edits it in Studio)

The game's UI (since the Oct 27 wipe, just the boss bar) is real objects in
`StarterGui > Hud` (see `src/client/Ui.luau`). StarterGui isn't in the Rojo tree, so syncing
`src/` never touches it: QM's edits there are kept in the place.
- `python3 lu.py uibake.luau` (Edit, after syncing `src/`): adds whatever UI is missing to
  StarterGui. It never changes what's there, so run it whenever the UI code gains new pieces.
  Save the place after.
- `python3 uisave.py`: saves StarterGui's UI into the repo as `ui/<ScreenGui>.json`; commit
  `ui/` so QM's edits are in git too. `python3 uiload.py [Hud]` puts them back into a place
  (replacing those ScreenGuis), e.g. a fresh one.
In Play the scripts find the objects by name and only wire them up, so renaming or deleting
one makes the game build a default one in its place.
- `python3 lu.py ui_strip.luau` (Edit, one-off, Oct 27): deletes everything in StarterGui.Hud but
  the boss bar. Save the place, then `uisave.py`.
