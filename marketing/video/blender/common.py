# Written by AI on 2026.11.18 by model claude fable 5.2.
"""What every shot of the launch film shares: the render settings, materials, night lights and text."""
import math
import os
import random

import bpy
from mathutils import Matrix, Vector

FPS = 30
BEAT = 14  # frames: the music is 900/7 beats a minute, so a beat is 14 frames and a bar 56
RAIN_BLUE = (0x5A / 255, 0x9B / 255, 0xD3 / 255)  # RainPalette.buienradarBlue
ORANGE = (1.0, 0.36, 0.04)  # the Ultra's Action button


def linear(c):
    """sRGB to the linear values Blender's shaders take."""
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


BLUE = linear(RAIN_BLUE)


def ease(x):
    """Smooth start and stop, 0 to 1."""
    x = min(1.0, max(0.0, x))
    return x * x * x * (x * (6 * x - 15) + 10)


def ramp(f, a, b):
    """0 before frame a, 1 after frame b, eased between."""
    return ease((f - a) / (b - a)) if b > a else float(f >= b)


def lerp(a, b, t):
    return a + (b - a) * t


def setup(width, height, draft):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type == "METAL"
    cycles = scene.cycles
    cycles.device = "CPU" if os.environ.get("RW_CPU") else "GPU"
    cycles.samples = 40 if draft else 64
    cycles.use_adaptive_sampling = True
    cycles.adaptive_threshold = 0.06 if draft else 0.05
    cycles.use_denoising = True
    cycles.max_bounces = 10
    cycles.transmission_bounces = 10
    cycles.glossy_bounces = 5
    cycles.caustics_reflective = False
    cycles.caustics_refractive = False
    cycles.sample_clamp_indirect = 8
    scene.render.use_persistent_data = os.environ.get("RW_PERSIST", "1") == "1"
    if os.environ.get("RW_DENOISE_CPU"):
        cycles.denoising_use_gpu = False
    if os.environ.get("RW_TILE"):
        cycles.use_auto_tile, cycles.tile_size = True, int(os.environ["RW_TILE"])
    scene.render.use_motion_blur = not os.environ.get("RW_NO_BLUR")
    scene.render.motion_blur_shutter = 0.4
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 50 if draft else 100
    scene.render.fps = FPS
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_depth = "8"
    scene.render.dither_intensity = 1.0
    scene.view_settings.view_transform = "AgX"
    for look in ("AgX - Medium High Contrast", "Medium High Contrast"):
        try:
            scene.view_settings.look = look
            break
        except TypeError:
            pass
    return scene


def material(name, emission=None, strength=1.0, **inputs):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    for key, value in inputs.items():
        bsdf.inputs[key].default_value = value
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = strength
    return m


def glass(name, colour, roughness=0.03, glow=0.0):
    return material(name, emission=colour if glow else None, strength=glow,
                    **{"Base Color": (*colour, 1), "Transmission Weight": 1.0, "Roughness": roughness, "IOR": 1.45})


def light_only(name, colour, strength):
    """A surface that glows and takes no light: the widget's own flat colours."""
    return material(name, emission=colour, strength=strength, **{"Base Color": (0, 0, 0, 1), "Roughness": 1.0, "Specular IOR Level": 0.0})


def wet_ground(name="wet ground"):
    """Dark tarmac after rain: puddles that mirror, damp patches that do not, fine grain."""
    m = material(name, **{"Base Color": (0.012, 0.013, 0.016, 1), "Roughness": 0.2})
    tree = m.node_tree
    bsdf = tree.nodes["Principled BSDF"]
    coords = tree.nodes.new("ShaderNodeTexCoord")
    puddles = tree.nodes.new("ShaderNodeTexNoise")
    puddles.inputs["Scale"].default_value = 0.35
    puddles.inputs["Detail"].default_value = 3
    to_rough = tree.nodes.new("ShaderNodeMapRange")
    to_rough.inputs["From Min"].default_value = 0.42
    to_rough.inputs["From Max"].default_value = 0.62
    to_rough.inputs["To Min"].default_value = 0.015
    to_rough.inputs["To Max"].default_value = 0.34
    grain = tree.nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 60
    grain.inputs["Detail"].default_value = 6
    damp = tree.nodes.new("ShaderNodeMath")
    damp.operation = "MULTIPLY"
    bump = tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.02
    tree.links.new(coords.outputs["Object"], puddles.inputs["Vector"])
    tree.links.new(coords.outputs["Object"], grain.inputs["Vector"])
    tree.links.new(puddles.outputs["Fac"], to_rough.inputs["Value"])
    tree.links.new(to_rough.outputs["Result"], bsdf.inputs["Roughness"])
    # Grain only where the ground is not under water.
    tree.links.new(grain.outputs["Fac"], damp.inputs[0])
    tree.links.new(to_rough.outputs["Result"], damp.inputs[1])
    tree.links.new(damp.outputs["Value"], bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def obj(name, mesh_or_data, mat=None, parent=None):
    o = bpy.data.objects.new(name, mesh_or_data)
    bpy.context.scene.collection.objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    if parent is not None:
        o.parent = parent
    return o


def mesh(name, verts, faces, mat=None, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    if smooth:
        for polygon in data.polygons:
            polygon.use_smooth = True
    return obj(name, data, mat)


def remesh(o, verts, faces, smooth=False):
    """Give an object's mesh new geometry. The mesh itself stays, so the renderer updates it in
    place: a new mesh every frame is one more kept in its memory every frame."""
    data = o.data
    data.clear_geometry()
    data.from_pydata(verts, [], faces)
    if smooth:
        for polygon in data.polygons:
            polygon.use_smooth = True
    data.update()


def night(scene, seed=7, lamps=110, strength=1.0, street=True):
    """A night sky, the lights of a town far off, and two rows of street lamps along the line,
    which the lens turns into discs."""
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.006, 0.012, 1)
    scene.world = world
    rng = random.Random(seed)
    colours = [((1.0, 0.45, 0.12), 5), ((1.0, 0.8, 0.55), 3), ((0.75, 0.85, 1.0), 2), ((1.0, 0.08, 0.04), 1), (RAIN_BLUE, 1)]
    bag = [c for c, weight in colours for _ in range(weight)]
    root = bpy.data.objects.new("street lights", None)
    scene.collection.objects.link(root)
    for index in range(lamps):
        colour = rng.choice(bag)
        angle = rng.uniform(0, 2 * math.pi)
        distance = rng.uniform(60, 150)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rng.uniform(0.7, 1.9), segments=16, ring_count=8,
                                             location=(distance * math.cos(angle), distance * math.sin(angle), rng.uniform(1.5, 22)))
        lamp = bpy.context.object
        lamp.name = f"street light {index}"
        lamp.data.materials.append(light_only(f"street light {index}", linear(colour), rng.uniform(3, 14) * strength))
        lamp.parent = root
        lamp.visible_shadow = False
    if street:
        sodium = light_only("street lamp", linear((1.0, 0.5, 0.16)), 30 * strength)
        for side in (-1, 1):
            for index in range(-3, 16):
                bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=16, ring_count=8,
                                                     location=(side * 11 + rng.uniform(-0.4, 0.4), index * 13 + (6 if side > 0 else 0), 7.5))
                lamp = bpy.context.object
                lamp.data.materials.append(sodium)
                lamp.parent = root
                lamp.visible_shadow = False
    return root


def area_light(name, location, target, colour, power, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.size = power, colour, size
    data.shape = "DISK"
    o = bpy.data.objects.new(name, data)
    o.visible_glossy = False
    bpy.context.scene.collection.objects.link(o)
    o.location = location
    o.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    return o


def text(name, body, font, size, mat, extrude=0.0, align="CENTER", parent=None):
    """Words as a shape. It takes no part in motion blur: a word that changes would smear."""
    data = bpy.data.curves.new(name, "FONT")
    data.body = body
    data.font = font
    data.size = size
    data.align_x = align
    data.extrude = extrude
    data.resolution_u = 6
    o = obj(name, data, mat, parent)
    o.cycles.use_motion_blur = False
    return o


def camera(scene, name="camera", lens=50, sensor=36):
    data = bpy.data.cameras.new(name)
    data.lens, data.sensor_width = lens, sensor
    data.sensor_fit = "HORIZONTAL"
    data.dof.use_dof = True
    data.clip_start, data.clip_end = 0.001, 2000
    o = bpy.data.objects.new(name, data)
    scene.collection.objects.link(o)
    scene.camera = o
    return o


def spline(keys, frame):
    """A smooth path through keys [(frame, value), ...] (Catmull-Rom); values are numbers or Vectors."""
    if frame <= keys[0][0]:
        return keys[0][1]
    if frame >= keys[-1][0]:
        return keys[-1][1]
    i = max(k for k in range(len(keys) - 1) if keys[k][0] <= frame)
    (f1, p1), (f2, p2) = keys[i], keys[i + 1]
    p0 = keys[i - 1][1] if i > 0 else p1
    p3 = keys[i + 2][1] if i + 2 < len(keys) else p2
    t = (frame - f1) / (f2 - f1)
    return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t)


def look(location, target):
    """The camera's rotation looking from location at target. Looking straight down, the top of the
    frame is +Y, as on the watch's screen; looking along the ground, it is up."""
    forward = (Vector(target) - Vector(location)).normalized()
    down = abs(forward.z) ** 4
    hint = Vector((0, down, 1 - down))
    right = forward.cross(hint).normalized()
    up = right.cross(forward)
    return Matrix((right, up, -forward)).transposed().to_quaternion()


def bake_camera(cam, frames, path):
    """Key the camera on every frame from path(frame) -> (location, target, lens, focus distance, f-stop),
    so the renderer blurs its motion."""
    cam.rotation_mode = "QUATERNION"
    previous = None
    for f in frames:
        location, target, lens, focus, fstop = path(f)
        cam.location = location
        q = look(location, target)
        if previous is not None and q.dot(previous) < 0:
            q.negate()
        previous = q.copy()
        cam.rotation_quaternion = q
        cam.data.lens = lens
        cam.data.dof.focus_distance = focus
        cam.data.dof.aperture_fstop = fstop
        cam.keyframe_insert("location", frame=f)
        cam.keyframe_insert("rotation_quaternion", frame=f)
        cam.data.keyframe_insert("lens", frame=f)
        cam.data.dof.keyframe_insert("focus_distance", frame=f)
        cam.data.dof.keyframe_insert("aperture_fstop", frame=f)
