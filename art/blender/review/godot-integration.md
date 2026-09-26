# Godot shrine integration — 2026-09-26

The first room now appears behind battles in the local Godot game. The existing
characters, card hand, bug monitor, rules and layout remain intact. The room uses
three PNG plates and a presentation-only Control with smoothed 1/3/5 px pointer
movement, 4% overscan, aspect-preserving cover, and dark readability overlays.
The control ignores mouse/focus, persists across battle UI rebuilds, and hides
after the retained combat presentation finishes. It consumes no gameplay RNG.

## Export and visual corrections

- Export target `(0,1,3.6)` places the shrine in the gap between arena and hand.
  The source `.blend` and its original preview camera are not overwritten.
- The base includes architecture and floor. Transparent middle/foreground plates
  include their contact shadows. Rear architecture shadows are baked only once,
  in the base plate; including them again caused dark duplicate bands and was fixed.
- All layers share the same camera. Layer images and export metadata are under
  `godot/assets/environments/corrupted-shrine/`.
- Blender 5.2.2 LTS completed the three-plate render; Godot 4.5 imported all assets.

## Verification

Run from the repository root:

```powershell
.\run-godot.ps1 --headless --path godot --script res://tests/test_combat_clarity.gd
.\run-godot.ps1 --headless --path godot --script res://tests/test_game_feel.gd
.\run-godot.ps1 --path godot --script res://tests/ui_smoke.gd -- --capture --combat-only --states
```

- Combat clarity: **396 checks, 0 failures**.
- Game feel / animation and transition behavior: **84 checks, 0 failures**.
- Rendered combat matrix and interaction states: **0 failures**, process exit 0.
- Visually reviewed native **1280x720 and 1440x900**, **English and Chinese**;
  cards and combat text fit, and the shrine remains visible between the controls.
- The capture suite also exercises focus, hover, pressed, unaffordable and long cards.
- `git diff --check` passed. Existing unrelated untracked card import files remain.

Before changing the stale assertions, the original UI was reproduced in an
isolated local project. Its Git blob matched the original exactly:
`97091f7b9e2c021e2f95f0b5746be8a36b84dc72`.
It produced the same 8 clarity and 21 combat-matrix failures as the integration.
Those assertions expected the old End Turn arrow and old idle preview message.
They now check the existing `[E]` shortcut and current keyboard-help text; no
assertion was removed or weakened and no gameplay text was changed.

Evidence: repository `work/ui-combat-{1280,1440}-{en,zh}.png`,
`work/shrine-capture.log`, `work/shrine-clarity.log`, `work/shrine-game-feel.log`.
The initial graphical launch used a relative log path and crashed at startup;
the normal executable with an absolute log path completed successfully.

## Remaining limits

This is a baked 2D environment, not a traversable 3D level. Three textures replace
live scene rendering; lights are baked. Larger camera motion and a redesigned
combat layout would need a new framing/shadow review. Human art approval remains
open; local checks do not imply a production-art or deployment sign-off.
