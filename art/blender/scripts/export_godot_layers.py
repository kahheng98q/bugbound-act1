"""Render Godot plates from the generated .blend without modifying the source scene.

blender --background scene.blend --python export_godot_layers.py -- --output DIR
"""
import argparse
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--samples", type=int, default=48)
parser.add_argument("--overwrite", action="store_true")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
args.output = args.output.resolve()
if args.samples < 1:
    parser.error("samples must be positive")
if not args.overwrite and any((args.output / name).exists() for name in ["background.png", "midground.png", "foreground.png", "manifest.json"]):
    parser.error("Export exists. Use --overwrite or choose a different output directory.")
args.output.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = args.samples
scene.cycles.use_denoising = True
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
background = list(bpy.data.collections["BACKGROUND"].objects)
middle = list(bpy.data.collections["MIDGROUND"].objects)
front = list(bpy.data.collections["FOREGROUND"].objects)
floor = [obj for obj in middle if obj.name.startswith(("Stage /", "Floor /"))]
middle = [obj for obj in middle if obj not in floor]
geometry = background + floor + middle + front
original = {obj: (obj.hide_render, obj.visible_camera, obj.is_shadow_catcher, obj.visible_shadow) for obj in geometry}
original_path = scene.render.filepath
original_rotation = scene.camera.rotation_euler.copy()
# Lower the shrine into the clear area between arena HUD and hand.
scene.camera.rotation_euler = (Vector((0, 1, 3.6)) - scene.camera.location).to_track_quat("-Z", "Y").to_euler()
plates = {}
try:
    for name, selected in [("background", background + floor), ("midground", middle), ("foreground", front)]:
        for obj in geometry:
            obj.hide_render = False
            obj.is_shadow_catcher = False
            obj.visible_shadow = True
            # Invisible surroundings still contribute to lighting and reflections.
            obj.visible_camera = obj in selected
        if name == "background":
            # Remove movable layers AND their shadows from the background plate.
            for obj in middle + front:
                obj.hide_render = True
        else:
            # Catch only this layer's contact shadows onto the common floor.
            for obj in (front if name == "midground" else middle):
                obj.hide_render = True
            # Rear architecture shadows are already baked into the base plate.
            for obj in background:
                obj.visible_shadow = False
            for obj in floor:
                if obj.name.startswith("Stage /"):
                    obj.visible_camera = True
                    obj.is_shadow_catcher = True
                else:
                    obj.hide_render = True
        scene.render.film_transparent = name != "background"
        scene.render.filepath = str(args.output / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        plates[name] = name + ".png"
    manifest = {
        "room": "Act1_BattleRoom_01", "blender": bpy.app.version_string,
        "source": "art/blender/scenes/Act1_BattleRoom_01_Corrupted_Bug_Shrine.blend",
        "resolution": [scene.render.resolution_x, scene.render.resolution_y],
        "camera": "CAM_Battle with Godot HUD framing target (0, 1, 3.6)", "plates": plates,
        "notes": "Floor belongs to background. Middle/foreground have transparent film and floor shadow catchers. All plates share one camera. Runtime overscans by 4%; motion capped at 5 px."
    }
    (args.output / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
finally:
    for obj, values in original.items():
        obj.hide_render, obj.visible_camera, obj.is_shadow_catcher, obj.visible_shadow = values
    scene.render.filepath = original_path
    scene.camera.rotation_euler = original_rotation
