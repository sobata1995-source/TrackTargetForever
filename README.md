# TrackTarget Forever

**Click a Track Humanoids marker on the minimap to attempt normal WoW targeting, with a compact Ally / Horde indicator.**

A lightweight addon for Hunters and Druids in **World of Warcraft: Forever**. It works with the existing minimap tracking dots and the standard target frame, so you can inspect a selected character's faction, class and level using the game's own UI.

**Status:** `0.1.0-beta` · Interface `16001` · private development project · no published release.

## What it does

- Starts automatically at login when enabled in the AddOns list.
- Uses a direct left-click on an existing Track Humanoids dot; no selection menu or repeated chat command is needed.
- Confirms the resulting target before displaying **Ally**, **Horde**, **NPC** or an unknown result.
- Cycles overlapping names with repeated clicks and supports an optional Shift-click mode.
- Keeps the usual minimap right-click behavior available.

Targeting is **outside combat only** and requires active Track Humanoids. A visible marker does not guarantee that its unit can be targeted. This is a test build: secure execution, real minimap mouse routing and compatibility with other UI addons still require live-client testing.

## Install from this repository

Clone the repository or use **Code → Download ZIP**, then copy the inner `TrackTargetForever` folder into your Forever client's `Interface/AddOns` directory. The final path must end with:

```text
Interface/AddOns/TrackTargetForever/TrackTargetForever.toc
```

Restart the game, enable **TrackTarget Forever**, and activate Track Humanoids. The addon loads automatically; `/ttf` is optional help and configuration.

Read the [English user guide](TrackTargetForever/README.md), [Bulgarian user guide](TrackTargetForever/README_BG.md) or [Bulgarian in-game test checklist](TrackTargetForever/TESTING_BG.md) for detailed controls and limitations.

## Project layout

| Path | Purpose |
| --- | --- |
| `TrackTargetForever/Logic.lua` | Tooltip names, exact-name matching and safe macro text. |
| `TrackTargetForever/Core.lua` | WoW events, minimap input, secure action and faction feedback. |
| `TrackTargetForever/TrackTargetForever.toc` | Addon metadata and load order. |
| `tests/` | Local Lua logic and mocked WoW integration tests. |
| `AGENTS.md` | Working notes for Codex and other coding agents. |

## Local checks and packaging

The existing suite passed **78 logic checks** and **90 mocked integration checks** across 16 scenarios. These results do not replace a test inside WoW.

From the repository root, with Python 3 and the shared Lua 5.4 library available:

```text
python3 tests/run_lua.py tests/test_logic.lua tests/test_core.lua
python3 tests/run_lua.py --syntax TrackTargetForever/Logic.lua TrackTargetForever/Core.lua
```

Create an installable local ZIP without publishing a release:

```text
python3 -m zipfile -c TrackTargetForever-0.1.0-beta.zip TrackTargetForever
```

The runtime uses Lua 5.1-compatible syntax. Test execution through Lua 5.4 is separate from the game client's protected-action behavior. In-game reports should include the client build, class/form, tracking mode, combat state, hovered marker and any Lua error.

## License

Original addon code under the **MIT License**. See [LICENSE.txt](LICENSE.txt). World of Warcraft and Blizzard Entertainment are trademarks of their respective owners; this project is not an official Blizzard product.
