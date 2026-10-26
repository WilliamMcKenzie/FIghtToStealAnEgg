# Backpack "MERGE" button (Figma)

Source: Figma file SXX3jajS0geX05QENW2Ofe, Page 2, nodes `51:148` (button "Rectangle 5") and `51:149` (text "MERGE").
Mockup: `backpack_items_with_merge.png` (QM's screenshot). Figma render of the button body: `merge_button_render.png`.
Units are Figma px. The backpack panel ("roddy 1", `50:59`) is 2710x1621, so scale by `panelWidth / 2710`.

## Behaviour (QM, 2026-10-26)
- Items tab only. It appears only when a merge is possible.
- Merging takes two of one item and gives the next item up its evolution ladder (e.g. Axe -> Waraxe, Shortbow -> Longbow -> NatureBow). Only obvious chains for now.

## Placement
- Size: 690 x 228.
- Horizontally centred on the panel (left edge at panel x 1010).
- Top edge at panel y 1507, so it hangs 114 px below the panel's bottom edge, plus the 16 px drop shadow.
- In Roblox: AnchorPoint (0.5, 0), Position X = 0.5 of the panel, Size = (690/2710, 228/1621) of the panel.

## Body
- Corner radius 20.
- Stroke 10 px, `#00A529`, inside, with clipped content.
- Drop shadow: a solid, unblurred offset of 0, 16 in `#00A529`. In Roblox, use a frame of the same size and colour behind the button, offset +16 px in Y with a 20 radius.
- Fill: `assets/ui/merge_button_texture.png`, tiled with TileSize 180x180 in Figma px from the top-left, over a `#D9D9D9` base (fully covered).
  - The texture is a 2-colour checker with 90 px cells: `#88F421` (136,244,33) at the top-left cell and `#84F01C` (132,240,28).
  - The Figma image itself is 1800 px; the tile here is a pixel-exact 2x2-cell repeat of it.

## Label "MERGE"
- Montserrat ExtraBold (`Font.fromName("Montserrat", Enum.FontWeight.ExtraBold)`), 100 px, white `#FFFFFF`.
- Centred in the button. The text box is 381 x 122 at button-local (154, 53).
- Text shadow: 0, 8 at rgba(0,0,0,0.25). In Roblox, use a duplicate label behind it, offset +8 px Y, black at TextTransparency 0.75.
- Outline: a black outline about 6 to 8 px wide, read off QM's screenshot. Figma's export didn't report the stroke width, so this is an estimate. Use a UIStroke, Color black, ApplyStrokeMode Contextual.

## Separator (pets tab, also new on Page 2)
- `51:150` ("Rectangle 6"): 2311 x 24, at panel-local (154, 464), between the pen row and the collection.
- Horizontal gradient:
  - 0 -> 1%: transparent
  - 15.4%: rgba(193,162,131,0.5)
  - 88.5%: rgba(193,162,131,0.5)
  - 100%: transparent
- So it's `#C1A283` at 50% alpha, fading out at both ends.

## Panel texture
`assets/ui/backpack_panel_texture.png` is the backpack panel checker: a 180x180 tile with 90 px cells, `#E5CBB1` top-left and `#E9D1B9`. The panel has a 12 px `#C1A283` stroke and a radius of 20.
