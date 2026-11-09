# TrackTarget Forever

Local validation for this package: Lua syntax checks, 78 name/tooltip logic checks, and 90 mocked integration checks across 16 scenarios passed. Actual WoW Forever mouse routing, secure execution, and server targeting still require the in-game checklist; no live-client test was performed here.

**Click the existing red Track Humanoids dot on the actual minimap → select the character as your normal target in the standard WoW target frame.** Inspect the target normally, including class and level when the game displays them. The small **Ally / Horde** label beneath the minimap is supplemental.

**0.1.0-beta · Blizzard World of Warcraft: Forever · Interface 16001**

For Hunters and Druids with active **Track Humanoids**, outside combat. This beta has **not been tested in a live WoW Forever game session by the development environment**. Local code checks cannot validate the game's secure execution, minimap hit testing, or third-party UI compatibility.

## Installation

1. Completely close WoW Forever.
2. Extract the ZIP and copy its `TrackTargetForever` folder into the Forever installation's `Interface/AddOns` folder.
3. Check the exact path, without an extra nested addon folder:

   ```text
   World of Warcraft/_forever_/Interface/AddOns/TrackTargetForever/TrackTargetForever.toc
   ```

4. Restart the game and enable **TrackTarget Forever** in **AddOns**.
5. For the first test, disable other minimap click-targeting addons.

No external application or additional library is required. Bulgarian instructions are in `README_BG.md`; the short in-game checklist is in `TESTING_BG.md`.

## Use

Enable **Track Humanoids**. A Druid must use the form in which the ability is available. Out of combat, hover the red tracking dot on the minimap until the game displays its name, then left-click the dot itself.

The click directly attempts to set that character as your normal WoW target. Use the standard target frame to inspect the character as usual. A confirmed player target also produces a small **Ally** or **Horde** label beneath the minimap. There is no intermediate selection menu or custom class/level panel. Repeated left-clicks on overlapping names cycle through the candidates, one target per click.

A humanoid dot can refer to an NPC, which can also become your normal target; the supplemental label then shows **NPC**. There is no hostile-only filter. Failed or unknown results show **?** with a tooltip explanation. Faction is determined from the confirmed target, not inferred from dot color. Normal minimap right-click behavior remains available.

## Commands

| Command | Purpose |
| --- | --- |
| `/ttf` or `/ttf help` | Show help. |
| `/ttf on` / `/ttf off` | Enable or disable the addon. |
| `/ttf mode direct` | Direct left-click targeting; the default. |
| `/ttf mode shift` | Require Shift + left-click. |
| `/ttf panel on` / `/ttf panel off` | Show or hide the small faction label. |
| `/ttf reset` | Restore this addon's defaults. |
| `/ttf debug` | Print client, tracking, and hovered-tooltip diagnostics. |
| `/ttf test` | Preview a clearly marked sample label without targeting a real character. |

Change settings outside combat.

## Limitations

- Dynamic minimap targeting works only outside combat. Hover the dot again afterward.
- Requires active Track Humanoids: Hunter spell 19883 or Druid spell 5225. The addon does not enable tracking or change forms.
- A visible dot may refer to a unit that cannot currently be targeted.
- Name-based targeting can select a nearer NPC with the same name.
- Alliance/Horde and current attackability are separate properties.
- Custom minimaps and UI replacement addons require live-client compatibility testing.

## Troubleshooting

Use `/console scriptErrors 1`, then `/reload`, and reproduce the issue. Capture the full error. Hover the affected dot and run `/ttf debug`.

Report the addon version, Forever build, class/form, active tracking, combat state, reproduction steps, expected and actual results, and UI/minimap addons. Diagnostics may include names visible under the cursor; review them before sharing. Use `/console scriptErrors 0` to restore hidden Lua errors if desired.

## Disable or remove

Use `/ttf off` outside combat, or disable the addon in AddOns. To remove it, close the game and delete its folder. Settings use `TrackTargetForeverDB`; `/ttf reset` resets only the addon's settings. It does not modify saved player macros or nameplate distance settings and does not attack or cast spells.

## Development references

The implementation reads the real minimap mouseover tooltip and prepares a secure action outside combat. A player click executes the action. The resulting target must match before faction is reported.

- [Blizzard UI source mirror: Forever SecureTemplates](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua)
- [Blizzard UI source mirror: Forever Minimap](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Minimap/Mainline/Minimap.lua)
- [ForeverPlusPlus developer API notes](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md)

These references document client APIs; they do not certify this beta in game. TrackTarget Forever is original addon code.

Copyright (c) 2026 Denis Aleksandrov. MIT License; see `LICENSE.txt`.
