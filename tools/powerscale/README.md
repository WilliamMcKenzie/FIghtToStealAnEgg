# Powerscaling Control

A dashboard for balancing (QM, Oct 31): every weapon, pet, Strength, training, boss and
economy curve in `src/shared/Config.luau` as a graph you can edit.

**Open it:** double-click `Powerscaling.command` in the project folder (or run
`python3 tools/powerscale/serve.py`, then go to http://localhost:3001).

- **Lists** (weapon DPS and prices, pet cash, health, speed, boss health and damage, region
  prices...): pick a preset (Linear, Exponential, Logarithmic, Polynomial) and it fits a curve
  through the current values; then change the baseline (first value) and the growth. Or drag
  dots, type numbers in the table, or multiply everything. Grey dashed = the game now.
- **Formulas** (Strength -> damage / attack speed, pet ride speed, bounty, rebirth): edit the
  parameters, including the curve shape (`Config.Power.Curve`, `Config.PetStats.SpeedCurve`).
- **Pacing**: seconds to kill each region's boss and a training mob, and minutes of pen
  income to afford the next region, from your unsaved edits.
- **Save to game** writes only the changed values into Config.luau (comments and layout stay)
  and loads `src/` into the open Studio place like the map editor does.

`luaconfig.py` reads and writes Config.luau; `serve.py` is the server; `dashboard.html` the page.
