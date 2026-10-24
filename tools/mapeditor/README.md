# Map editor

`MapEditor.html` edits the game's map, `maps/world.map` (QM, Oct 24). Open it in a browser
(it's one self-contained file), paint the floor a 4-stud checker square at a time, place
and move every mesh (props, pillars, arches, ruins, nests, bosses), tweak any colour, then **Download .map** and send it
over. Walls and barriers are shown but fixed (tools/map_gen.py lays them out).

On this Mac: `python3 tools/mapeditor/serve.py` serves it at http://localhost:3000, opening the
game's current `maps/world.map`. Its **Save to game** button writes `maps/world.map`, bakes
`src/shared/MapData.luau` and syncs and rebuilds the map in the open Studio place (Edit mode),
so nothing needs sending.

Getting a .map into the game by hand:

1. `python3 tools/map_bake.py ~/Downloads/world.map` copies it to `maps/world.map` and bakes
   it into `src/shared/MapData.luau` (a `.map.json` from the Artifact page works the same).
2. Sync `src/` into Studio, then **Map > Rebuild** (the Map Baker plugin, `tools/studio/MapBaker.lua`)
   builds `workspace.Map` in Edit mode. Save the place. The game plays on that baked map.
   **Map > Import .map** bakes a file straight from disk, to look at before it goes in the repo.

Rebuilding the editor (after Config colour changes, new meshes, or a new world.map):

    python3 tools/mapeditor/sprites.py   # top-down mesh pictures (needs node, playwright, three)
    python3 tools/mapeditor/build.py     # -> MapEditor.html

## The .map format

JSON, one row of cells and one object per line so diffs read well:

- `cell` (4 studs), `origin` (the north-west corner, x and z), `size` (columns, rows)
- `rows`: north to south, one character a cell: a tile's `id`, or `.` for no floor (under walls)
- `tiles`: `{ id, area, key (a Config.WorldColors key; key .. "Checker" is its checker), top, liquid? }`
- `colours`: `{ key: [r, g, b] }`, the colours changed from Config.WorldColors (they win)
- `areas`: the base's pens, training grounds and spawn; each biome's bounds and boss-circle radius
- `objects`: `Prop` (item, x, z, yaw, scale, style, y only when pinned), `Pillar` (style, kind,
  size, height, yaw, scale, y), `Arch` (style, yaw, scale, y), `Ruin`, `Nest`, `Boss`
- `fixed`: walls, barriers, wall height, gateway half-width (older files also had pillars and
  arches here: `tools/map_migrate.py` moves them into `objects`, and the editor does it on open)
- `saved`: when the editor wrote it (the game warns if the baked map isn't MapData's)

`src/shared/MapFile.luau` is the parser.
