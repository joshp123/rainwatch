"""Render a still of one of the film's watches in dark, wet-night light, to judge how it looks.

Written by AI on 2026.11.18 by model claude fable 5.2.

    blender -b -P still.py -- <ultra|series|se> <three-quarter|glass|side|front> out.png
        [--screen face.png] [--samples 300] [--scale 100] [--brightness 3] [--arm]

The lights here are only for looking at the watch; the film's scenes bring their own.
"""

import argparse
import random
import sys
from math import cos, radians, sin
from pathlib import Path

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arm  # noqa: E402
import watch  # noqa: E402

# view: (camera azimuth towards the crown, elevation, distance m, lens mm, f-stop, target m)
VIEWS = {
    "three-quarter": (22, 48, 0.30, 85, 8.0, (0.0, 0.0, -0.006)),
    "glass": (36, 32, 0.17, 85, 16.0, (0.007, 0.0, 0.0)),
    "left": (-62, 24, 0.30, 85, 8.0, (0.0, 0.0, -0.01)),
    "side": (78, 14, 0.34, 85, 8.0, (0.0, 0.0, -0.022)),
    "front": (0, 89.9, 0.50, 135, 0, (0.0, 0.0, 0.0)),
    "wrist": (6.8, 56, 0.212, 70, 8.0, (0.0, 0.0, 0.0)),      # the film's glance: the wearer's own view
    "arm": (10, 50, 0.52, 70, 11.0, (0.0, 0.0, -0.01)),
}
SODIUM, COOL, BLUE, RED = (1.0, 0.45, 0.12), (0.75, 0.86, 1.0), (0.12, 0.33, 0.65), (1.0, 0.05, 0.03)


def emitter(name, location, radius, colour, strength):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=location, segments=24, ring_count=12)
    obj = bpy.context.object
    obj.name = name
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    emission = tree.nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*colour, 1)
    emission.inputs["Strength"].default_value = strength
    tree.links.new(emission.outputs["Emission"], output.inputs["Surface"])
    obj.data.materials.append(material)
    return obj


def area(name, location, target, size, colour, power):
    light = bpy.data.lights.new(name, "AREA")
    light.shape = "RECTANGLE"
    light.size, light.size_y = size
    light.color = colour
    light.energy = power
    obj = bpy.data.objects.new(name, light)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(obj)
    return obj


def night(camera, target):
    """A dark street: lamps out of focus behind the watch, a few mirrored so the glass shows them."""
    scene = bpy.context.scene
    world = bpy.data.worlds.new("night")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.003, 0.005, 0.011, 1)
    scene.world = world

    forward = (target - camera.location).normalized()
    right = forward.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(forward)
    reach = (camera.location - target).length

    def behind(u, v, depth):
        """A point `depth` from the lens, on the line of sight that passes (u, v) metres from the watch."""
        return camera.location + forward * depth + (right * u + up * v) * depth / reach

    rng = random.Random(7)
    for i in range(60):
        depth = rng.uniform(1.2, 3.0)
        at = behind(rng.uniform(-0.09, 0.09), rng.uniform(-0.16, 0.16), depth)
        colour = rng.choice((SODIUM, SODIUM, SODIUM, COOL, COOL, BLUE, RED))
        emitter(f"lamp {i}", at, rng.uniform(0.002, 0.005) * depth, colour, rng.uniform(1.5, 7))
    # Lamps the flat of the glass reflects: points behind the watch, mirrored through the glass.
    for i, (u, v, colour, strength) in enumerate(((-0.011, 0.016, SODIUM, 14), (0.013, 0.004, COOL, 9), (-0.004, -0.017, BLUE, 14))):
        at = behind(u, v, 1.6)
        emitter(f"street lamp {i}", (at.x, at.y, -at.z), 0.012, colour, strength)
    # A lit window, mirrored the same way, so the glass has a soft sheen across one corner.
    at = behind(0.08, 0.05, 1.3)
    window = area("window", (at.x, at.y, -at.z), (0, 0, 0), (0.55, 0.9), COOL, 2.5)
    window.data.spread = radians(120)
    area("sky", (-0.2, -0.5, 0.9), (0, 0, 0), (1.2, 0.8), COOL, 2.5)
    area("rim blue", (-0.42, 0.3, 0.06), (0, 0, -0.005), (0.08, 0.5), (0.45, 0.65, 1.0), 9)
    area("rim warm", (0.42, 0.3, 0.12), (0, 0, -0.005), (0.08, 0.5), (1.0, 0.72, 0.5), 5)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=("ultra", "series", "se"))
    parser.add_argument("view", choices=tuple(VIEWS))
    parser.add_argument("out")
    parser.add_argument("--screen")
    parser.add_argument("--samples", type=int, default=300)
    parser.add_argument("--scale", type=int, default=100, help="per cent of 1080 x 1920")
    parser.add_argument("--brightness", type=float, default=3.0)
    parser.add_argument("--arm", action="store_true", help="put the watch on a sleeved arm")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    root = watch.build(args.kind)
    if args.screen:
        watch.set_screen(root, args.screen, args.brightness)
    if args.arm or args.view in ("wrist", "arm"):
        arm.build(root)

    azimuth, elevation, distance, lens, fstop, target = VIEWS[args.view]
    target = Vector(target)
    az, el = radians(azimuth), radians(elevation)
    data = bpy.data.cameras.new("camera")
    data.lens = lens
    camera = bpy.data.objects.new("camera", data)
    camera.location = target + distance * Vector((sin(az) * cos(el), -cos(az) * cos(el), sin(el)))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(camera)
    scene.camera = camera
    if fstop:
        data.dof.use_dof = True
        data.dof.focus_distance = distance
        data.dof.aperture_fstop = fstop
    night(camera, target)

    scene.render.engine = "CYCLES"
    preferences = bpy.context.preferences.addons["cycles"].preferences
    preferences.compute_device_type = "METAL"
    preferences.get_devices()
    for device in preferences.devices:
        device.use = device.type == "METAL"
    scene.cycles.device = "GPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.01
    scene.cycles.use_denoising = True
    scene.cycles.sample_clamp_indirect = 10
    scene.cycles.max_bounces = 16
    scene.cycles.transmission_bounces = 12
    scene.cycles.glossy_bounces = 8
    scene.render.resolution_x, scene.render.resolution_y = 1080, 1920
    scene.render.resolution_percentage = args.scale
    scene.view_settings.view_transform = "AgX"
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = args.out
    bpy.ops.render.render(write_still=True)


main()
