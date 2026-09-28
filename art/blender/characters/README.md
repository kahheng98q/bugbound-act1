# Phase 5 character prototypes

Original BUGBOUND geometry, authored directly in Blender; no downloaded models,
external character references, paid generation, or environment edits.

- `bee-programmer.blend` / `bee-programmer.png`: honey shell, ink stripes,
  expressive face, four faceted wings, antenna status nodes, compiler backpack,
  harness and handheld terminal debugger. Relaxed standing idle with tool raised.
- `../enemies/corrupted-folder.blend` / `../enemies/corrupted-folder.png`: tabbed
  folder, exposed cached pages, split cover around a magenta error core, unequal
  cable arms and binder claws, detached file fragments. Crouched hostile idle.

Each editable source separates `BODY`, `ACCESSORIES`, `EMISSIVE`, `ANIMATION`,
`LIGHTING`, and `CAMERAS`. The animation collection contains a pose root; these
are unrigged single-pose prototypes, not complete animation sets. Frame 1 is the
authored idle. Godot retains its attack presentation hook with a brief scale pulse.

The orthographic camera uses direction `(0,24,-9.4)`, exactly matching the
environment's Godot export camera. Individual yaw turns the bee toward the right
and folder toward the left. Cyan left light, magenta right rim, lime overhead
light and navy ambience match the room palette. Renders are 768×768 RGBA with
transparent film; no background or ground is baked into the character images.
The room's geometry and background plates remain separate and unchanged.

Rebuild both sources and PNGs from the repository root in PowerShell:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python '.\art\blender\scripts\generate_characters.py'
```

This overwrites generated character outputs and copies the PNGs to
`godot/assets/characters/`. Save hand edits under another name before regenerating.
No additional Python, add-ons, or service credentials are required. Verified with
Blender 5.2.2 LTS, Cycles CPU, 32 samples and AgX. The small `.blend` sources and
previews are retained alongside this document. Per-character JSON records report
collection membership, camera, image size, and source mesh face counts (before
bevel evaluation; curves are excluded).

Godot uses the existing portrait slots, native PNG alpha, and existing combat
positions. Only Bee Programmer and Corrupted Folder artwork is replaced; cards,
other enemies and the environment remain as before. The selection thumbnail uses
the existing bee-rewards atlas. No hitbox, HP, enemy, or player rules change.

## Verified integration

The rendered Chinese combat was inspected at 1280×720 and 1440×900. Both new
characters appear together over the existing shrine environment; silhouettes,
faces, wings, debugger, folder split and core remain visible without overlap or
clipping. Existing slot dimensions and combat centers are retained. Captures:
`work/phase5-combat-1280.png` and `work/phase5-combat-1440.png`.

`test_game_feel.gd`, `test_combat_clarity.gd`, full `ui_smoke.gd`, and the combat
capture matrix with interaction states each passed with zero failures. The
graphical capture logged sandbox shader-cache/certificate-store warnings but
completed and saved both requested viewport sizes. Blender saved both scenes and
renders successfully despite a sandbox thumbnail/extension-cache warning.

Capture command (direct executable preserves the script argument separator):

```powershell
& '.\work\godot\Godot_v4.5-stable_win64.exe' --path godot --script res://tests/ui_smoke.gd -- --capture --combat-only --states
```
