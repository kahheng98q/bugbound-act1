"""BUGBOUND's original, deterministic 2.5D battle-stage prototype. Run with Blender."""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOM = "Act1_BattleRoom_01"
ROOT = Path(__file__).resolve().parents[1]
RNG = random.Random(1701)
COLLECTION = None


def material(name, color, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = 0.6
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat


def assign(obj, name, mat):
    obj.name = name
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    COLLECTION.objects.link(obj)
    if mat:
        obj.data.materials.append(mat)
    obj["bugbound_original"] = True
    return obj


def box(name, xyz, size, mat, bevel=0.04, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = assign(bpy.context.object, name, mat)
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = rotation
    if bevel:
        mod = obj.modifiers.new("Machined chipped edges", "BEVEL")
        mod.width, mod.segments = bevel, 1
        obj.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
    return obj


def cable(name, points, mat, radius=0.045, smooth=True):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 16
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new("BEZIER" if smooth else "POLY")
    if smooth:
        spline.bezier_points.add(len(points) - 1)
        for p, co in zip(spline.bezier_points, points):
            p.co = co
            p.handle_left_type = p.handle_right_type = "AUTO"
    else:
        spline.points.add(len(points) - 1)
        for p, co in zip(spline.points, points):
            p.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    COLLECTION.objects.link(obj)
    curve.materials.append(mat)
    return obj


def crystal(name, xyz, size, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=xyz)
    obj = assign(bpy.context.object, name, mat)
    obj.scale = size
    return obj


def light(name, xyz, color, power, size, target):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = power, color, "DISK", size
    obj = bpy.data.objects.new(name, data)
    COLLECTION.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def tower(x, y, height, width, phase, mats):
    navy, steel, cyan, pink, lime, dark = mats
    box("Server / foundation", (x, y, .18), (width + .4, 1.4, .36), steel)
    box("Server / monolithic spine", (x, y + .35, height / 2), (width, .65, height), navy)
    for i in range(int(height / .53)):
        z = .55 + i * .53
        shift = .12 if i % 4 == phase else 0
        box("Server / memory cartridge", (x + shift, y -.1, z), (width, .65, .43), steel)
        box("Server / dark slot", (x + shift, y -.438, z), (width * .78, .025, .18), dark, .01)
        box("Server / status strip", (x - width * .32 + shift, y -.46, z), (.07, .025, .19), cyan if i % 3 else pink, .005)
        for j in range(2):
            box("Server / bit indicator", (x + width * .18 + j * .12 + shift, y -.465, z), (.045, .025, .06), lime if i % 5 == 0 else cyan, 0)
    box("Server / fractured cap", (x -.13, y, height + .12), (width*.75, 1, .24), navy, rotation=(0,.15,.07))


def terminal(x, y, scale, mats, broken=False):
    navy, steel, cyan, pink, lime, dark = mats
    box("Terminal / grounded pedestal", (x, y, .4*scale), (.65*scale,.65*scale,.8*scale), steel)
    box("Terminal / monitor casing", (x, y, 1.07*scale), (1.2*scale,.42*scale,.77*scale), navy)
    box("Terminal / display", (x,y-.222*scale,1.07*scale), (1.02*scale,.02,.59*scale), dark, .01)
    for row in range(4):
        length = (.32 + .14*(row % 3))*scale
        box("Terminal / fragmented code", (x-.15*scale,y-.24*scale,(1.25-row*.12)*scale), (length,.014,.026*scale), pink if broken else cyan, 0)
    box("Terminal / keyboard tray", (x,y-.35*scale,.68*scale), (1.1*scale,.6*scale,.09), steel)
    if broken:
        cable("Terminal / screen fracture", [(x-.4*scale,y-.255*scale,1.35*scale),(x+.07*scale,y-.255*scale,1.08*scale),(x-.1*scale,y-.255*scale,.8*scale)], navy, .026, False)


def generate(args):
    global COLLECTION
    RNG.seed(1701)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in list(bpy.data.collections):
        bpy.data.collections.remove(coll)
    scene = bpy.context.scene
    scene.name = ROOM + " - Corrupted Bug Shrine"
    scene.unit_settings.system = "METRIC"
    groups = {}
    for name in ["BACKGROUND", "MIDGROUND", "FOREGROUND", "LIGHTING", "CAMERAS", "GUIDES"]:
        groups[name] = bpy.data.collections.new(name)
        scene.collection.children.link(groups[name])
    navy = material("Obsidian polymer / midnight navy", (.023,.043,.078), .25)
    steel = material("Oxidised blue memory alloy", (.075,.14,.19), .5)
    floor = material("Quiet combat floor", (.038,.065,.09), .25)
    dark = material("Unpowered glass", (.005,.012,.022), .1)
    cyan = material("Cyan / valid data", (.035,.65,.8), .2, 2.3)
    pink = material("Magenta / invalid instruction", (.65,.018,.22), .1, 2.5)
    lime = material("Acid green / corruption", (.28,.75,.015), .1, 2.1)
    mats = navy, steel, cyan, pink, lime, dark
    COLLECTION = groups["BACKGROUND"]
    # A stage set for a fixed 2D camera, deliberately open at front/top.
    box("Backdrop / solid substrate", (0,6.5,3.5), (30,.6,8), navy)
    for x, h, w in [(-10,6,1.4),(-7.8,4.7,1.3),(-5.7,6.4,1.55),(5.8,4.5,1.8),(8,6.8,1.35),(10,5.2,1.5)]:
        tower(x, 4.6 + RNG.uniform(-.2,.5), h, w, RNG.randrange(4), mats)
    for x in [-10.8,-3.4,3.6,10.6]:
        box("Wall / bus pilaster", (x,6.05,3.5), (.18,.3,7), steel)
    # Broken rectangular instruction traces replace borrowed fantasy ornament.
    for side in [-1,1]:
        for i in range(4):
            x=side*(4.1+i*.32)
            cable("Wall / severed instruction trace", [(x,6.13,1),(x,6.13,2+i*.5),(x+side*.2,6.13,2+i*.5)],steel,.025,False)
    for x,y,z in [(-6.7,4.15,5.5),(-5.1,4.1,6.6),(8.6,4.4,6.7)]:
        box("Ruin / peeled memory plate", (x,y,z), (.6,.15,.8), steel,.025,(.18,.3,-.24))
    # Overhead cable tray is grounded by side uprights; cables end at sockets.
    box("Data bus / top beam", (0,4.8,7.15), (22,.65,.3), steel)
    for x in [-10.8,10.8]:
        box("Data bus / support", (x,4.8,3.55), (.35,.65,7.1), steel)
    for i, (a,b,sag) in enumerate([(-10,-5,4.6),(-7,4,5.7),(-4,9,6.0),(3,10,5.2)]):
        points = [(a,4.45,7),(a+.7,4.1,6.5),((a+b)/2,4.0,sag),(b-.5,4.25,6.6),(b,4.45,7)]
        cable("Suspended data cable", points, dark, .072)
        cable("Cable / thin active filament", [(x,y-.065,z) for x,y,z in points], cyan if i%2 else pink, .013)
        for x in [a,b]:
            box("Cable / beam socket", (x,4.45,7), (.23,.35,.22), steel)
    # Original bug emblem: split carapace, six circuit limbs, detached error blocks.
    box("Shrine / lower plinth", (0,3.65,.24), (4.5,2.1,.48), navy, .12)
    box("Shrine / upper plinth", (0,3.65,.6), (3.55,1.6,.28), steel, .08)
    box("Shrine / compiler spine", (0,4.15,2.4), (.52,.7,3.4), steel)
    for side in [-1,1]:
        crystal("Bug shrine / split carapace", (side*.48,3.75,2.75), (.57,.45,1.1), steel)
        cable("Bug shrine / wing circuit", [(side*.17,3.3,3.5),(side*.75,3.3,2.8),(side*.2,3.3,1.95)], cyan, .042, False)
        for i in range(3):
            z=2.15+i*.47
            cable("Bug shrine / circuit leg", [(side*.65,3.7,z),(side*(1.05+i*.13),3.65,z+.2),(side*(1.5+i*.13),3.65,z+.2)], steel, .09, False)
            box("Bug shrine / leg contact", (side*(1.5+i*.13),3.64,z+.2), (.16,.19,.16), pink, .01)
        cable("Bug shrine / antenna", [(side*.25,3.7,3.62),(side*.45,3.7,4.03),(side*.83,3.7,4.16)], steel,.05,False)
    crystal("Bug shrine / head", (0,3.65,3.64), (.4,.36,.35), navy)
    crystal("Bug shrine / corrupted core", (0,3.19,2.72), (.18,.22,.62), lime)
    for side in [-1,1]:
        box("Bug shrine / eye", (side*.17,3.31,3.68), (.11,.07,.06), lime,.005)
    for i in range(9):
        box("Corruption / displaced memory", (RNG.uniform(-1.2,1.2),3.4,RNG.uniform(.9,1.65)), (RNG.uniform(.08,.18),.12,.12), lime,.01)
    # Thin broken traces remain confined to rear and edges of the battle floor.
    for side in [-1,1]:
        cable("Corruption / rear floor trace", [(side*.2,3.1,.035),(side*1.4,2.7,.035),(side*1.4,2.3,.035),(side*2.5,2.3,.035),(side*2.5,2.65,.035),(side*4,2.65,.035)], lime,.022,False)
    COLLECTION = groups["MIDGROUND"]
    box("Stage / thick floor substrate", (0,-3,-.28), (30,22,.55), floor,.04)
    for x in range(-15,16,3):
        box("Floor / quiet expansion seam", (x,-3,.001), (.025,22,.006), navy,0)
    for y in [-12,-9,-6,-3,0,3,6]:
        box("Floor / quiet transverse seam", (0,y,.001), (30,.024,.006), navy,0)
    for x,y,s in [(-7,1,1.2),(7.6,1.7,1.05),(-9,-1,.8)]:
        terminal(x,y,s,mats,True)
    box("Ruin / toppled server cartridge", (9,1,.28),(1.9,.85,.55),steel,.05,(0,0,-.35))
    for i in range(5):
        crystal("Corruption / edge shard", (8.8+i*.25,1.1,.55),(.08,.09,.2+i*.035),lime)
    for side in [-1,1]:
        box("Battle deck / side rail", (side*7,-1,.08), (.15,6,.16), steel)
        for y in [-3,-1,1]:
            box("Battle deck / cyan edge tick", (side*6.9,y,.022), (.15,.4,.022), cyan,0)
    COLLECTION = groups["FOREGROUND"]
    for side in [-1,1]:
        for i in range(9):
            x,y=side*RNG.uniform(8.0,11.5),RNG.uniform(-6.2,-3.5)
            w,h=RNG.uniform(.3,.9),RNG.uniform(.15,.65)
            box("Foreground / discarded memory block", (x,y,h/2), (w,.55,h), navy,.04, (0,0,RNG.uniform(-.7,.7)))
        cable("Foreground / disconnected data lead", [(side*11,-4,.12),(side*9,-4.5,.12),(side*8.1,-5.6,.12)],dark,.09)
    terminal(-9.1,-4.0,1.15,mats,True)
    COLLECTION = groups["LIGHTING"]
    light("Soft blue overhead", (0,-1,9), (.48,.67,1),2200,10,(0,1,0))
    light("Cyan left wash", (-7,-1,5),(.04,.8,1),1600,6,(-3,3,2))
    light("Magenta right wash", (7,2,5),(1,.045,.28),1900,5,(3,3,2))
    light("Shrine / green leak", (0,2.7,2.5),(.45,1,.025),120,2,(0,1,0))
    light("Shrine / rim", (0,5,5),(.1,.6,1),900,3,(0,3.5,2.7))
    scene.world = bpy.data.worlds.new("Deep navy void")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.025,.045,.09,1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .35
    COLLECTION = groups["CAMERAS"]
    data = bpy.data.cameras.new("Battle / orthographic 16:10")
    cam = bpy.data.objects.new("CAM_Battle",data)
    COLLECTION.objects.link(cam)
    cam.location = (0,-23,13)
    target = Vector((0,1,1.4))
    cam.rotation_euler = (target-cam.location).to_track_quat("-Z","Y").to_euler()
    data.type, data.ortho_scale = "ORTHO", 25
    scene.camera = cam
    COLLECTION = groups["GUIDES"]
    reserve = box("GUIDE / clear combat volume", (0,-.5,1.5),(11,4,3),None,0)
    reserve.display_type = "WIRE"
    reserve.hide_render = True
    reserve["purpose"] = "No dressing inside: x [-5.5,5.5], y [-2.5,1.5], z [0,3]."
    scene["room_id"] = ROOM
    scene["art_direction"] = "Original BUGBOUND: software ruins, six-legged compiler bug, split memory carapace"
    scene["parallax_note"] = "BACKGROUND, MIDGROUND, FOREGROUND share CAM_Battle; transparent layer render needs overlap/infill review."
    scene["ui_safe_area"] = "Bottom 24 percent reserved for cards; prototype only, validate in Godot."
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x,scene.render.resolution_y = 1440,900
    scene.render.resolution_percentage = args.resolution
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.render.film_transparent = False
    # Keep compositing minimal; emission is readable without washing out silhouettes.
    for area in bpy.context.screen.areas if bpy.context.screen else []:
        if area.type == "VIEW_3D":
            area.spaces.active.region_3d.view_perspective = "CAMERA"
    bpy.context.view_layer.update()
    check(scene, groups, args.output)
    scene.render.filepath = str(args.output / "renders" / (ROOM + "_preview.png"))
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output / "scenes" / (ROOM + "_Corrupted_Bug_Shrine.blend")))
    if not args.no_render:
        bpy.ops.render.render(write_still=True)


def check(scene, groups, output):
    """Conservative evaluated AABB check for the reserved combat envelope."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    collisions, triangles = [], 0
    for name in ("BACKGROUND","MIDGROUND","FOREGROUND"):
        for obj in groups[name].objects:
            if obj.type not in {"MESH","CURVE"}:
                continue
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            try:
                mesh.calc_loop_triangles()
                triangles += len(mesh.loop_triangles)
                verts = [evaluated.matrix_world @ v.co for v in mesh.vertices]
                low = [min(v[i] for v in verts) for i in range(3)]
                high = [max(v[i] for v in verts) for i in range(3)]
                if low[0]<5.5 and high[0]>-5.5 and low[1]<1.5 and high[1]>-2.5 and low[2]<3 and high[2]>.08:
                    collisions.append(obj.name)
            finally:
                evaluated.to_mesh_clear()
    report = {"room":ROOM,"blender":bpy.app.version_string,"seed":1701,"triangles":triangles,
              "triangle_budget":100000,"combat_envelope_clear":not collisions,"intrusions":collisions,
              "collections":{k:len(v.objects) for k,v in groups.items()},
              "camera":list(scene.camera.location),"resolution":[1440*scene.render.resolution_percentage//100,900*scene.render.resolution_percentage//100],
              "runtime_verified":False,"note":"Fixed-camera art prototype; no Godot import or runtime approval implied."}
    (output/"renders"/"generation-report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    if collisions or triangles>100000:
        raise RuntimeError("Scene violates prototype budget/clearance: " + json.dumps(report))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT)
    parser.add_argument("--samples",type=int,default=48)
    parser.add_argument("--resolution",type=int,default=100,help="Percentage of 1440x900")
    parser.add_argument("--no-render",action="store_true")
    parser.add_argument("--overwrite",action="store_true",help="Replace generated scene/preview only")
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
    if args.samples<1 or not 1<=args.resolution<=100:
        parser.error("samples must be positive; resolution must be 1..100")
    args.output=args.output.resolve()
    targets=[args.output/"scenes"/(ROOM+"_Corrupted_Bug_Shrine.blend"),args.output/"renders"/(ROOM+"_preview.png"),args.output/"renders"/"generation-report.json"]
    if not args.overwrite and any(p.exists() for p in targets):
        parser.error("Generated output already exists. Use --overwrite or a different --output directory.")
    for name in ["scenes","renders","exports"]:
        (args.output/name).mkdir(parents=True,exist_ok=True)
    generate(args)


if __name__ == "__main__":
    main()
