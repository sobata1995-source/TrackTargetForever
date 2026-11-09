# TrackTarget Forever working notes

## Scope and layout

This private repository contains the experimental WoW Forever minimap-targeting addon. The installable folder is `TrackTargetForever/`; keep that name and the matching `.toc` filename intact. The root README is repository-facing; the addon folder contains the complete English/Bulgarian user documentation.

- `Logic.lua`: pure name/tooltip parsing, exact-name matching and safe macro construction.
- `Core.lua`: game API integration, protected-click handling, minimap input and target feedback.
- `tests/`: existing deterministic and mocked integration suites.

## Development constraints

- Keep runtime syntax compatible with Lua 5.1 and preserve the `.toc` load order.
- Targeting must remain tied to an actual user click and prepared outside combat. Do not modify protected frames or attributes during combat lockdown.
- Faction feedback must come from a confirmed matching target. Do not infer faction from marker color or a partially matching first name.
- Forever's second `UnitName` return is a surname in this implementation's target client. Preserve full-name and overlapping-marker handling.
- Preserve the minimap's unrelated mouse behavior. Do not add automatic attacks, spell casts or movement.
- Keep privacy and publication as requested: do not make the repository public, create releases/tags, or add publishing workflows unless the user later explicitly authorizes that action.

## Verification

Run commands from the repository root. Python 3 and a shared Lua 5.4 library are required by the bundled runner:

```text
python3 tests/run_lua.py tests/test_logic.lua tests/test_core.lua
python3 tests/run_lua.py --syntax TrackTargetForever/Logic.lua TrackTargetForever/Core.lua
```

The baseline is 78 logic checks plus 90 mocked integration checks. Run relevant tests after functional changes. No live WoW client is provided here: never describe mocked results as successful in-game targeting. Use `TrackTargetForever/TESTING_BG.md` for live-client checks and record the actual client build and observed results.

## Packaging

Keep generated ZIPs out of Git. From the repository root:

```text
python3 -m zipfile -c TrackTargetForever-0.1.0-beta.zip TrackTargetForever
```

Update version/changelog only when changing the deliverable. Preserve the MIT notices. Repository preparation alone is not a gameplay change.
