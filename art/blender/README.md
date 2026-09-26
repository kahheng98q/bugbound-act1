# BUGBOUND Blender environment prototype

`Act1_BattleRoom_01 - Corrupted Bug Shrine` is an original procedural 2.5D battle
stage: split-carapace compiler bug, six circuit legs, asymmetric memory towers,
suspended data leads, fractured terminals and acid-green data leaks. Navy alloy,
cyan valid-data light and magenta error light define the palette. All geometry and
materials are authored in the generator; no external game assets, reference-game
motifs, downloaded models, textures, add-ons or paid services are used.

## Installed Blender and exact commands

Verified locally: **Blender 5.2.2 LTS**, executable:
`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
The desktop shortcut targets `blender-launcher.exe`; use `blender.exe` for scripting.
Blender is not on PATH on this machine.

Run in **PowerShell**:

```powershell
Set-Location 'C:\Users\kahhe\Desktop\Project\bugbound-act1'
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python '.\art\blender\scripts\generate_room.py' -- --overwrite
```

This builds the scene and renders a 1440x900 PNG using Cycles CPU, 48 samples and
denoising. CPU rendering is intentional so the command works without configuring
a particular graphics card. A standalone Python installation is not needed.
The command was verified with the installed version; other Blender versions have
not been tested.

Open the generated scene:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' '.\art\blender\scenes\Act1_BattleRoom_01_Corrupted_Bug_Shrine.blend'
```

Press Numpad 0 for the production camera and F12 to render. Use material preview
or rendered shading to inspect lights and materials. The saved scene has the
production camera and render configuration already assigned.

Quick draft (864x540, 16 samples):

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python-exit-code 1 --python '.\art\blender\scripts\generate_room.py' -- --output '.\work\blender-draft' --samples 16 --resolution 60 --overwrite
```

Use `--no-render` to save just the scene. `--output` selects another output root.
Without `--overwrite`, the script refuses existing generated outputs. With it,
the scene, preview and generation report are replaced. Save hand-edited scenes
under another name before regenerating. Run in a separate Blender process:
the generator resets the current scene. It does not modify the Godot project.

## Files

```text
art/blender/
  scripts/generate_room.py   # deterministic seed 1701, procedural geometry
  scenes/                   # generated editable .blend
  renders/                  # preview PNG and generation-report.json
  exports/                  # reserved for future Godot-ready output
  review/                   # brief, scope, review status and limitations
```

Large generated outputs are ignored by this folder's `.gitignore`; the generator,
documentation and placeholder files are versionable. Preserve or share binary
art separately, or adopt Git LFS intentionally later.

## Composition and editing

- `BACKGROUND`: wall substrate, rear towers, suspended cables and central shrine.
- `MIDGROUND`: low-contrast battle floor, edge terminals and side rails.
- `FOREGROUND`: dark corner rubble, disconnected lead and near terminal.
- `LIGHTING`, `CAMERAS`, `GUIDES`: shared setup, independent of depth layers.

Coordinates are metres, Z up; negative Y faces the camera. The camera is
orthographic at `(0,-23,13)`, aimed at `(0,1,1.4)`, with scale 25. Its 16:10 render
matches the existing Godot 1440x900 viewport. Central clear space is
X `[-5.5,5.5]`, Y `[-2.5,1.5]`, Z `[0,3]`; the hidden-render wire guide shows it.
The bottom 24% is kept visually quiet for cards. An evaluated geometry check
rejects decorative intrusions above 8 cm into that reserve and a scene over
100,000 triangles. This is a spatial check, not proof of live enemy/UI readability.

Adjust `tower()` placements for the skyline, the shrine section for the core,
`terminal()` for side props, and the materials/lights in `generate()` for palette.
The exposed top/front are deliberate stage boundaries for a fixed camera; this
is not a sealed, navigable 3D room and promises no entrance or playable passage.

## Godot integration

The battle UI now uses three baked PNG plates from this scene, stored in
`godot/assets/environments/corrupted-shrine/`. `godot/ui/shrine_backdrop.gd`
draws them beneath combat controls with 4% overscan, aspect-preserving cover,
and smoothed pointer motion of 1/3/5 pixels. It does not consume input or gameplay
randomness. Set `motion_enabled = false` on the backdrop to disable movement.
The backdrop persists through ordinary UI rebuilds and remains behind the battle
during its finishing effects, then hides when leaving combat.

The opaque background plate includes the floor and rear architecture. The middle
plate carries side terminals/rails; the foreground carries near rubble and a
terminal. Transparent plates include floor contact shadows using Cycles shadow
catchers. Rear-wall shadows are included only in the background plate to avoid
doubling them during compositing. All three plates use the same export camera
target `(0,1,3.6)` to place the shrine between the arena HUD and the hand; the
source scene's original camera is preserved. The hidden surroundings still
contribute indirect lighting. The source
`.blend` is opened read-only by the exporter and never saved over.

Rebuild plates after editing/regenerating the Blender scene:

```powershell
Set-Location 'C:\Users\kahhe\Desktop\Project\bugbound-act1'
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background '.\art\blender\scenes\Act1_BattleRoom_01_Corrupted_Bug_Shrine.blend' --python-exit-code 1 --python '.\art\blender\scripts\export_godot_layers.py' -- --output '.\art\blender\exports\corrupted-shrine' --overwrite
Copy-Item '.\art\blender\exports\corrupted-shrine\*.png' '.\godot\assets\environments\corrupted-shrine\' -Force
Copy-Item '.\art\blender\exports\corrupted-shrine\manifest.json' '.\godot\assets\environments\corrupted-shrine\manifest.json' -Force
.\run-godot.ps1 --headless --editor --path godot --import
.\run-godot.ps1 --path godot --script res://tests/ui_smoke.gd -- --capture --combat-only --states
```

The small parallax range preserves the composition; larger motion needs more
occlusion/shadow review. Lighting is baked into the plates, not dynamic 3D lights.
The existing card art, characters, mechanics and combat layout are preserved.

## Validation and known limits

`renders/generation-report.json` records the installed Blender version, evaluated
triangle count, collection membership, resolution and combat clearance. Generation
fails with a nonzero process exit code if the scene violates those checks.
The original prototype preview was reviewed and the user's continuation authorized
Godot integration. Full production-art approval is not implied. This remains a
fixed-camera 2D environment; it does not provide 3D collision or navigation.

On the sandboxed draft run Blender logged a thumbnail-cache write warning;
the `.blend` and PNG still saved correctly and the process returned success.
Blender 5.2 also warns that `use_nodes` is deprecated for Blender 6.0; these
warnings do not prevent generation in the verified installed version.
