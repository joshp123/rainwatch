# Written by AI on 2026.11.18 by model claude fable 5.2.
"""Outside the widget: the watch on a wrist over a wet street at night, in real sizes (metres).

The watch is watch.py's; its display faces up (+Z), its top is away from the wearer (+Y) and the
forearm runs along X, the hand towards +X. The camera is where the wearer's eyes are.
"""
import math
import random

import bpy
from mathutils import Quaternion, Vector

import arm as sleeve
import watch
from common import BLUE, area_light, glass, light_only, linear, material, mesh, obj, remesh, text, wet_ground

STREET = -1.15  # the ground under the wrist


def faces_for(gen, language, kind="ultra"):
    folder = "face" if kind == "ultra" else f"face-{kind}"
    return lambda index: f"{gen}/{language}/{folder}/{index:02d}.png"


class Wrist:
    def __init__(self, scene, kind="ultra", arm=True, name=None, band_colour=None):
        self.scene = scene
        self.root = watch.build(kind, name or kind, band_colour)
        self.display = watch.part(self.root, "display")
        corners = [Vector(c) for c in self.display.bound_box]
        self.width = max(c.x for c in corners) - min(c.x for c in corners)
        self.height = max(c.y for c in corners) - min(c.y for c in corners)
        self.screen_z = corners[0].z
        # Everything that turns with the wrist hangs from this.
        self.arm = bpy.data.objects.new(f"{self.root.name} arm", None)
        scene.collection.objects.link(self.arm)
        self.root.parent = self.arm
        self.images = {}
        if arm:
            # A rain jacket's sleeve on one side and a glove on the other (arm.py).
            sleeve.build(self.root)

    # ---- the screen ----

    def point(self, x, y, points=(211, 257)):
        """A place on the screen, given in the screenshot's points from its top left, in the watch's own space."""
        return Vector(((x / points[0] - 0.5) * self.width, (0.5 - y / points[1]) * self.height, self.screen_z))

    def show(self, path, brightness=None):
        if path not in self.images:
            self.images[path] = bpy.data.images.load(path)
        watch.set_screen(self.root, self.images[path], brightness)

    # ---- the street ----

    def street(self, seed=11, lamps=34):
        """The wet street under the wrist, with the lamps the lens turns to discs, and the light on the watch."""
        scene = self.scene
        world = bpy.data.worlds.new("night")
        world.use_nodes = True
        world.node_tree.nodes["Background"].inputs[0].default_value = (0.003, 0.005, 0.011, 1)
        scene.world = world
        mesh("street", [(-900, -900, STREET), (900, -900, STREET), (900, 900, STREET), (-900, 900, STREET)], [(0, 1, 2, 3)], wet_ground("street"))
        self.lamps = []
        rng = random.Random(seed)
        colours = [(1.0, 0.45, 0.12)] * 5 + [(1.0, 0.8, 0.55)] * 2 + [(0.7, 0.82, 1.0)] * 2 + [(1.0, 0.07, 0.03), (0.36, 0.61, 0.83)]
        for index in range(lamps):
            # Lamps and windows low over the street, and their reflections in it, fill the frame behind the wrist.
            x, y = rng.uniform(-1.6, 1.6), rng.uniform(-0.6, 3.2)
            bpy.ops.mesh.primitive_uv_sphere_add(radius=rng.uniform(0.012, 0.03), segments=12, ring_count=6,
                                                 location=(x, y, STREET + rng.uniform(0.02, 0.5)))
            lamp = bpy.context.object
            lamp.data.materials.append(light_only(f"lamp {index}", linear(rng.choice(colours)), rng.uniform(12, 60)))
            lamp.visible_shadow = False
            self.lamps.append(lamp)
        # The sky's light is kept out of reflections: the flat glass would mirror it over the screen.
        area_light("sky", (-0.25, -0.35, 0.8), (0, 0, 0), (0.6, 0.75, 1.0), 14, 1.0)
        area_light("lamp left", (-0.45, 0.25, 0.12), (0, 0, 0), (0.4, 0.62, 1.0), 9, 0.3).visible_glossy = True
        area_light("lamp right", (0.4, 0.3, 0.16), (0, 0, 0), (1.0, 0.55, 0.22), 9, 0.3).visible_glossy = True


    def dim(self, amount):
        """Shrink the lamps round the wearer's feet away (0) or bring them back (1)."""
        for lamp in self.lamps:
            lamp.scale = (amount, amount, amount)
            lamp.hide_render = amount <= 0


class Rain:
    """Rain round the wrist: streaks through the air, and drops that land and stay on the glass."""

    def __init__(self, scene, wrist, starts, seed=5, streaks=1400, drops=30):
        self.wrist, self.starts = wrist, starts
        colour = linear((0.72, 0.85, 1.0))
        self.air = mesh("rain", [], [], light_only("rain 0", colour, 0.5))
        self.air.data.materials.append(light_only("rain 1", colour, 2.2))
        self.air.cycles.use_motion_blur = False
        self.air.visible_shadow = False
        rng = random.Random(seed)
        self.streaks = [(rng.uniform(-0.45, 0.45), rng.uniform(-0.35, 0.9), rng.random(), rng.uniform(0.8, 1.3), rng.random()) for _ in range(streaks)]
        water = glass("water", (1, 1, 1), roughness=0.0)
        water.node_tree.nodes["Principled BSDF"].inputs["IOR"].default_value = 1.33
        self.drops = []
        for index in range(drops):
            bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=24, ring_count=12)
            drop = bpy.context.object
            drop.name = f"drop {index}"
            bpy.ops.object.shade_smooth()
            drop.data.materials.append(water)
            drop.parent = wrist.root
            size = rng.uniform(0.00035, 0.001) * (1.8 if rng.random() < 0.12 else 1)
            where = (rng.uniform(-0.56, 0.56) * wrist.width, rng.uniform(-0.56, 0.56) * wrist.height)
            # The circle stays clear enough to read.
            while (Vector((where[0], where[1], 0)) - Vector((0, -0.342 * wrist.height, 0))).length < 0.0042:
                where = (rng.uniform(-0.56, 0.56) * wrist.width, rng.uniform(-0.56, 0.56) * wrist.height)
            # The first lands as the rain arrives, a few more straight after, the rest over two seconds.
            lands = starts + (0 if index == 0 else rng.uniform(0, 70) * (0.25 if index < 6 else 1.0))
            self.drops.append((drop, where, size, lands, rng.uniform(0.8, 1.25)))
            drop.cycles.use_motion_blur = False
        bpy.app.handlers.frame_change_pre.append(lambda scene, *_: self.update(scene.frame_current))

    def update(self, frame):
        verts, faces, tiers = [], [], []
        if frame >= self.starts - 6:
            thick = min(1.0, (frame - self.starts + 6) / 30)
            for x, y, phase, speed, chance in self.streaks:
                if chance > thick:
                    continue
                top, floor = 0.55, -0.6
                period = (top - floor) / (0.085 * speed)
                fallen = (frame / period + phase) % 1.0
                z = top - (top - floor) * fallen
                length, width, lean = 0.05 * speed, 0.00028, 0.012 * speed
                n = len(verts)
                verts += [(x - width, y, z), (x + width, y, z), (x + width, y + lean, z + length), (x - width, y + lean, z + length),
                          (x, y - width, z), (x, y + width, z), (x, y + width + lean, z + length), (x, y - width + lean, z + length)]
                faces += [(n, n + 1, n + 2, n + 3), (n + 4, n + 5, n + 6, n + 7)]
                tiers += [1 if chance < 0.12 else 0] * 2
        remesh(self.air, verts, faces)
        for polygon, tier in zip(self.air.data.polygons, tiers):
            polygon.material_index = tier
        for drop, (x, y), size, lands, squash in self.drops:
            grown = min(1.0, max(0.0, (frame - lands) / 3))
            drop.location = (x, y, 0.00002)
            # A drop on glass is a flattened dome; it lands in three frames.
            drop.scale = (size * grown * squash, size * grown, size * 0.42 * grown)
            drop.hide_render = grown == 0


class Tile:
    """A complication as a slab of black glass with its picture alight on it. On the watch it rests
    in its slot on the face, and is keyed by the shot: `holder` is what moves."""

    def __init__(self, scene, name, picture, size, corner, slot, thickness=0.00055, margin=0.0):
        """size: the picture's, in metres; corner radius in metres, or None for a disc; slot: where it
        rests, in the watch's space; margin: how far the glass runs past the picture."""
        self.name = name
        self.slot = Vector((slot[0], slot[1], thickness / 2 + 0.00015))
        picture_width, picture_height = size
        width, height = picture_width + 2 * margin, picture_height + 2 * margin
        self.size = size
        self.holder = bpy.data.objects.new(name, None)
        scene.collection.objects.link(self.holder)
        self.holder.rotation_mode = "QUATERNION"
        self.holder.location = self.slot
        outline = []
        if corner is None:
            outline = [(width / 2 * math.cos(2 * math.pi * k / 96), height / 2 * math.sin(2 * math.pi * k / 96)) for k in range(96)]
        else:
            for cx, cy, start in ((width / 2 - corner, height / 2 - corner, 0), (-width / 2 + corner, height / 2 - corner, 90),
                                  (-width / 2 + corner, -height / 2 + corner, 180), (width / 2 - corner, -height / 2 + corner, 270)):
                for k in range(17):
                    a = math.radians(start + 90 * k / 16)
                    outline.append((cx + corner * math.cos(a), cy + corner * math.sin(a)))
        n = len(outline)
        verts = [(x, y, -thickness / 2) for x, y in outline] + [(x, y, thickness / 2) for x, y in outline]
        faces = [tuple(reversed(range(n))), tuple(range(n, 2 * n))] + [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
        # Black glass, as the face is: the picture reads on it as it does on the watch, and its
        # polished edge takes the street's lights.
        slab_glass = material(f"{name} glass", **{"Base Color": (0.003, 0.003, 0.004, 1), "Roughness": 0.04, "Coat Weight": 1.0,
                                                  "Coat Roughness": 0.02, "IOR": 1.5})
        self.slab = mesh(f"{name} slab", verts, faces, slab_glass)
        self.slab.parent = self.holder
        bevel = self.slab.modifiers.new("bevel", "BEVEL")
        bevel.width, bevel.segments = thickness * 0.3, 3
        # The picture: a sheet just proud of the slab's face, alight where the picture is, clear where it is not.
        sheet = bpy.data.materials.new(f"{name} picture")
        sheet.use_nodes = True
        tree = sheet.node_tree
        tree.nodes.clear()
        out = tree.nodes.new("ShaderNodeOutputMaterial")
        image = tree.nodes.new("ShaderNodeTexImage")
        image.name = "picture"
        image.extension = "CLIP"
        image.image = bpy.data.images.load(picture, check_existing=True)
        glow = tree.nodes.new("ShaderNodeEmission")
        glow.inputs["Strength"].default_value = 2.6
        clear = tree.nodes.new("ShaderNodeBsdfTransparent")
        mix = tree.nodes.new("ShaderNodeMixShader")
        tree.links.new(image.outputs["Color"], glow.inputs["Color"])
        tree.links.new(image.outputs["Alpha"], mix.inputs["Fac"])
        tree.links.new(clear.outputs["BSDF"], mix.inputs[1])
        tree.links.new(glow.outputs["Emission"], mix.inputs[2])
        tree.links.new(mix.outputs["Shader"], out.inputs["Surface"])
        self.image = image
        z = thickness / 2 + 0.00001
        data = bpy.data.meshes.new(f"{name} picture")
        # The same picture is on the back, the right way round, so a tile that turns is never blank.
        left, right, low, high = -picture_width / 2, picture_width / 2, -picture_height / 2, picture_height / 2
        data.from_pydata([(left, low, z), (right, low, z), (right, high, z), (left, high, z),
                          (left, low, -z), (right, low, -z), (right, high, -z), (left, high, -z)], [], [(0, 1, 2, 3), (5, 4, 7, 6)])
        uv = data.uv_layers.new(name="picture")
        for loop, corner_uv in zip(data.loops, ((0, 0), (1, 0), (1, 1), (0, 1), (0, 0), (1, 0), (1, 1), (0, 1))):
            uv.data[loop.index].uv = corner_uv
        self.sheet = obj(f"{name} picture", data, sheet, self.holder)
        self.sheet.visible_shadow = False
        # It is drawn only between these frames: at rest on the face the screen's own picture is there.
        self.shown = (1, 0)
        self.flat = Quaternion()
        Tile.made.append(self)

    made = []

    @staticmethod
    def show_in_flight(scene, *_):
        """Outside its frames a tile is put far out of the picture, not hidden: the renderer never
        loads the picture of something that was hidden when it started."""
        for tile in Tile.made:
            shown = tile.shown[0] <= scene.frame_current <= tile.shown[1]
            tile.holder.delta_location = (0, 0, 0) if shown else (0, -500, -500)

    def show(self, picture):
        self.image.image = bpy.data.images.load(picture, check_existing=True)

    def key(self, frame, location, turn, scale=1.0):
        self.holder.location = location
        self.holder.rotation_quaternion = turn
        self.holder.scale = (scale, scale, scale)
        for path in ("location", "rotation_quaternion", "scale"):
            self.holder.keyframe_insert(path, frame=frame)
