"""Original BUGBOUND idle prototypes. Run in a separate Blender background process.

No room geometry is loaded or modified. Camera inclination matches the Godot plates.
Re-running replaces the two generated character sources and their PNGs.
"""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT.parents[1] / 'godot/assets/characters'
COL = None
RIG = None


def mat(name, rgb, glow=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = .62
    p.inputs['Emission Color'].default_value = (*rgb, 1)
    p.inputs['Emission Strength'].default_value = glow
    return m


def use(name):
    global COL
    COL = bpy.data.collections[name]


def finish(o, name, material):
    o.name = name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    COL.objects.link(o)
    o.parent = RIG
    if material:
        o.data.materials.append(material)
    return o


def box(name, loc, scale, material, bevel=.035, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = finish(bpy.context.object, name, material)
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = rot
    if bevel:
        m = o.modifiers.new('Single facet bevel', 'BEVEL')
        m.width, m.segments = bevel, 1
        o.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
    return o


def orb(name, loc, scale, material, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    o = finish(bpy.context.object, name, material)
    o.scale = scale
    return o


def line(name, points, radius, material):
    c = bpy.data.curves.new(name, 'CURVE')
    c.dimensions = '3D'
    c.bevel_depth, c.bevel_resolution = radius, 0
    s = c.splines.new('POLY')
    s.points.add(len(points)-1)
    for p, v in zip(s.points, points):
        p.co = (*v, 1)
    o = bpy.data.objects.new(name, c)
    COL.objects.link(o)
    o.parent = RIG
    c.materials.append(material)
    return o


def prism(name, points, y, depth, material):
    n = len(points)
    verts = [(x, y+d, z) for d in (-depth/2, depth/2) for x, z in points]
    faces = [tuple(reversed(range(n))), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(name, mesh)
    COL.objects.link(o)
    o.parent = RIG
    mesh.materials.append(material)
    bevel = o.modifiers.new('Broken bevel', 'BEVEL')
    bevel.width, bevel.segments = .025, 1
    o.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
    return o


def setup(yaw):
    global RIG
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name in ('BODY', 'ACCESSORIES', 'EMISSIVE', 'ANIMATION', 'LIGHTING', 'CAMERAS'):
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
    RIG = bpy.data.objects.new('Idle pose / character root', None)
    bpy.data.collections['ANIMATION'].objects.link(RIG)
    RIG.rotation_euler.z = math.radians(yaw)
    RIG['pose'] = 'Authored idle; separate parts available for future rigging'
    return {
        'gold': mat('Honey shell', (.96, .53, .035)),
        'lightgold': mat('Warm face', (1, .71, .13)),
        'dark': mat('Ink navy', (.017, .029, .055)),
        'steel': mat('Blue graphite harness', (.055, .105, .15)),
        'wing': mat('Frosted cyan wing', (.34, .82, .92)),
        'cyan': mat('Valid data / cyan', (.025, .8, 1), 1.4),
        'lime': mat('Debug success / lime', (.52, 1, .025), 1.3),
        'pink': mat('Corruption / magenta', (1, .018, .24), 2),
        'folder': mat('Ochre folder shell', (.66, .33, .095)),
        'paper': mat('Cached file ivory', (.78, .87, .74)),
        'purple': mat('Corrupted plum', (.16, .025, .13)),
    }


def bee(m):
    use('BODY')
    abdomen = orb('Striped bee abdomen', (0, .04, 1.25), (.65, .53, .78), m['gold'])
    abdomen.data.materials.append(m['dark'])
    for p in abdomen.data.polygons:
        if -.65 < p.center.z < -.28 or .12 < p.center.z < .48:
            p.material_index = 1
    orb('Oversized expressive bee head', (0, -.12, 2.21), (.72, .60, .66), m['lightgold'])
    for x in (-.29, .29):
        orb('Ink eye', (x, -.665, 2.28), (.17, .09, .235), m['dark'])
        orb('Eye glint', (x+.045, -.745, 2.36), (.048, .025, .065), m['paper'])
    line('Confident smile', [(-.17,-.711,2.02),(-.08,-.745,1.96),(.045,-.753,1.95),(.15,-.716,2.01)], .027, m['dark'])
    for side in (-1, 1):
        line('Articulated antenna', [(side*.30,-.02,2.72),(side*.43,-.02,3.04),(side*.64,-.07,3.16)], .043, m['dark'])
        line('Idle bent leg', [(side*.32,.02,.73),(side*.42,-.02,.46),(side*.37,-.22,.29)], .09, m['dark'])
        box('Debugger boot', (side*.39,-.27,.23), (.39,.50,.25), m['steel'], .08)
    line('Left arm', [(-.51,-.02,1.66),(-.79,-.19,1.43),(-.70,-.44,1.24)], .105, m['dark'])
    orb('Resting glove', (-.70,-.45,1.24), (.17,.16,.18), m['gold'])
    line('Tool arm', [(.51,-.02,1.68),(.79,-.18,1.42),(.98,-.47,1.56)], .11, m['dark'])
    orb('Tool glove', (.97,-.45,1.56), (.19,.18,.17), m['gold'])
    use('ACCESSORIES')
    for side in (-1, 1):
        wing = orb('Upper faceted wing', (side*.79,.39,2.16), (.34,.10,.70), m['wing'], 8, 6)
        wing.rotation_euler.y = side*.64
        wing = orb('Lower faceted wing', (side*.68,.42,1.69), (.27,.09,.46), m['wing'], 8, 6)
        wing.rotation_euler.y = side*1.0
    box('Compiler backpack', (-.12,.49,1.62), (.93,.43,.94), m['steel'], .11)
    for x in (-.37,.37):
        line('Harness strap', [(x,.35,1.99),(x,-.43,1.83),(x,-.49,1.35)], .065, m['steel'])
    box('Harness buckle', (0,-.54,1.54), (.34,.10,.21), m['steel'])
    box('Handheld debugger casing', (1.0,-.57,1.86), (.48,.23,.66), m['steel'], .07, (0,-.12,0))
    box('Debugger display', (1.0,-.697,1.94), (.35,.028,.35), m['dark'], .015)
    line('Probe antenna', [(1.11,-.54,2.17),(1.20,-.54,2.42)], .032, m['steel'])
    use('EMISSIVE')
    for side in (-1,1):
        orb('Antenna status node', (side*.64,-.07,3.16), (.10,.10,.10), m['lime'], 8, 4)
        box('Boot cyan seam', (side*.39,-.53,.25), (.23,.025,.065), m['cyan'], .01)
    box('Harness live status', (0,-.602,1.54), (.18,.024,.075), m['lime'], .01)
    line('Terminal prompt chevron', [(.88,-.72,2.04),(.99,-.72,1.95),(.88,-.72,1.86)], .021, m['lime'])
    box('Terminal cursor', (1.08,-.724,1.85), (.10,.025,.035), m['cyan'], .005)
    orb('Probe tip', (1.20,-.54,2.42), (.066,.066,.066), m['cyan'], 8, 4)


def folder(m):
    use('BODY')
    prism('Folder back with recognizable raised tab', [(-.91,.87),(.94,.87),(1.05,2.43),(-.24,2.43),(-.39,2.72),(-.90,2.72),(-1.04,2.56)], .19, .20, m['folder'])
    # Separate jagged covers reveal a deep error cavity, not a painted crack.
    prism('Left torn folder cover', [(-.91,.85),(-.05,.85),(-.27,1.25),(-.03,1.51),(-.32,1.72),(-.14,2.24),(-1.02,2.28)], -.29, .24, m['gold'])
    prism('Right torn folder cover', [(.19,.84),(.91,.84),(1.07,2.26),(.19,2.25),(.04,1.99),(.29,1.77),(.08,1.51),(.34,1.29)], -.29, .24, m['folder'])
    for side in (-1,1):
        line('Bent cable leg', [(side*.56,.0,.99),(side*.68,-.05,.55),(side*.48,-.31,.27)], .125, m['purple'])
        box('Asymmetric folded foot', (side*.51,-.34,.23), (.43 if side<0 else .58,.55,.25), m['steel'], .045)
    line('Long corrupted arm', [(-.91,.05,1.75),(-1.32,-.01,1.32),(-1.45,-.23,.99)], .13, m['purple'])
    line('Short corrupted arm', [(.92,.02,1.61),(1.25,-.1,1.73),(1.38,-.26,1.47)], .16, m['purple'])
    for x,z,side in [(-1.46,1.01,-1),(1.40,1.46,1)]:
        for i in range(3):
            offset = (i-1)*.18
            line('Broken binder claw', [(x+offset,-.23,z),(x+offset+side*.10,-.38,z-.24),(x+offset-side*.05,-.54,z-.34)], .065, m['folder'])
    use('ACCESSORIES')
    for i in range(3):
        box('Exposed cached document', (-.10+i*.11,.08-i*.08,2.39+i*.07), (1.21,.055,.43), m['paper'], .015, (0,(i-1)*.12,0))
    # Slanted eyes are separate recessed pieces on the front cover.
    prism('Left angry eye socket', [(-.83,1.99),(-.41,1.82),(-.47,2.03)], -.442, .055, m['dark'])
    prism('Right angry eye socket', [(.41,1.85),(.84,2.07),(.81,1.83)], -.442, .055, m['dark'])
    for i,(x,z) in enumerate([(-1.16,2.49),(1.19,2.47),(1.53,2.07),(-1.60,1.87),(.94,2.96)]):
        box('Floating lost file fragment %02d'%i, (x,.04,z), (.21,.10,.26), m['folder'] if i%2 else m['paper'], .018, (.1,.25*i,.12*i))
    use('EMISSIVE')
    orb('Exposed magenta error core', (.05,-.12,1.61), (.29,.25,.52), m['pink'], 8, 5)
    prism('Left error pupil', [(-.62,1.96),(-.49,1.90),(-.51,1.98)], -.485, .02, m['pink'])
    prism('Right error pupil', [(.53,1.89),(.69,1.99),(.68,1.88)], -.485, .02, m['pink'])
    for i,(x,z) in enumerate([(-1.20,2.2),(1.34,2.61),(-1.46,1.63),(.68,2.85),(.22,.74)]):
        box('Detached error voxel %02d'%i, (x,-.10,z), (.11,.10,.11), m['pink'], .008)
    line('Broken data trace', [(.55,-.44,1.1),(.65,-.44,1.28),(.84,-.44,1.28)], .018, m['pink'])


def render(name, directory):
    global RIG
    scene = bpy.context.scene
    # Exactly the plate direction: camera (0,-23,13) -> target (0,1,3.6).
    target = Vector((0,0,1.68))
    cam_data = bpy.data.cameras.new('Combat orthographic / matched inclination')
    cam = bpy.data.objects.new('CAM_CombatSprite', cam_data)
    bpy.data.collections['CAMERAS'].objects.link(cam)
    cam.location = target + Vector((0,-24,9.4))
    cam.rotation_euler = (target-cam.location).to_track_quat('-Z','Y').to_euler()
    cam_data.type, cam_data.ortho_scale = 'ORTHO', 3.85
    scene.camera = cam
    for label, pos, color, energy, size in [
        ('Soft cool key', (0,-5,7), (.72,.86,1), 500, 5),
        ('Server cyan left', (-4,1,4), (.025,.8,1), 420, 3),
        ('Error magenta rim', (4,2,3.7), (1,.025,.24), 500, 3),
        ('Acid lime top', (0,2,6), (.5,1,.025), 200, 2),
    ]:
        d = bpy.data.lights.new(label, 'AREA')
        d.energy, d.color, d.size = energy, color, size
        o = bpy.data.objects.new(label,d)
        bpy.data.collections['LIGHTING'].objects.link(o)
        o.location = pos
        o.rotation_euler = (target-o.location).to_track_quat('-Z','Y').to_euler()
    scene.world = bpy.data.worlds.new('Navy server ambience')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.025,.045,.09,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .35
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'AgX'
    scene['original_design'] = 'BUGBOUND / procedural authored geometry / no external assets'
    scene['environment_camera_direction'] = [0,24,-9.4]
    scene['idle_pose'] = 'Frame 1; unrigged editable prototype'
    scene.frame_set(1)
    out = ROOT / directory
    out.mkdir(parents=True, exist_ok=True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(out / (name+'.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(out / (name+'.blend')))
    bpy.ops.render.render(write_still=True)
    import shutil
    shutil.copyfile(out/(name+'.png'), ASSETS/(name+'.png'))
    report = {'name':name, 'camera_direction':[0,24,-9.4], 'resolution':[768,768],
              'alpha':'transparent RGBA', 'pose':'idle / frame 1',
              'collections':{c.name:len(c.objects) for c in bpy.data.collections},
              'mesh_faces':sum(len(o.data.polygons) for o in scene.objects if o.type=='MESH')}
    (out/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n')


bee(setup(17))
render('bee-programmer', 'characters')
folder(setup(-13))
render('corrupted-folder', 'enemies')
