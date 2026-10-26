# Backpack close "X" button (Figma)

Source: Figma file SXX3jajS0geX05QENW2Ofe, Page 2, group `52:152`: body `52:153` and glyph text `52:154`.
Render: `close_button_render.png`. Mockup: `backpack_with_close.png`.
Units are Figma px against the 2710x1621 backpack panel (`50:59`).

## Placement
- Size: 192 x 192 (square).
- Panel-local top-left at (2566, -54), so it overhangs the panel's top-right corner. It sticks out 48 px past the right edge and 54 px above the top edge.
- Roblox: AnchorPoint (0, 0). Position is X scale 2566/2710 and Y offset -54 px (scaled). Size is 192/2710 of the panel width, with a 1:1 UIAspectRatioConstraint.

## Body
- Corner radius 20.
- Stroke 10 px `#720006`, inside.
- Drop shadow: solid 0, 16 offset in `#720006`, no blur. In Roblox, use a same-size frame behind it, +16 px Y, radius 20.
- Fill: a radial gradient from the centre, with no texture or image:
  - `#FF5656` up to 31.7%
  - `#F93B3B` at 65.9%
  - `#F32020` at 100% (the corners)
- Roblox has no radial UIGradient. Either use a `#F93B3B` base with a white RadialGlow image (assets/ui/RadialGlow.png) tinted `#FF5656` at the centre, or just a flat `#F93B3B`.

## Glyph
- A text "x", not an image: lowercase x in Fredoka One (Roblox `Enum.Font.FredokaOne`), 130 px, white.
- The text box is 74 x 157 at button-local (59, 0), so it's horizontally centred and sits flush to the top of the button. It reads as visually centred because of the x-height.
- Text shadow: 0, 8 at rgba(0,0,0,0.25), done as a duplicate label +8 px Y in black at TextTransparency 0.75.
- The render shows a thick black outline, about 8 to 10 px. Figma's export doesn't report the width. Use a black UIStroke, Thickness about 8 at this scale.
