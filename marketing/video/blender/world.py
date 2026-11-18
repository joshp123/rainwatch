# Written by AI on 2026.11.18 by model claude fable 5.2.
"""The two-hour rain line laid along a wet street at night, as a ridge of glass as tall as its rain
is heavy, with the forecast's rain falling over it and walking towards now.

Everything is built from line.json, the numbers the app's own curve gives (export/). One unit is
the radius of the circle complication as it stands over the line; `scale` is metres to a unit when
the street is seen from the wrist.
"""
import json
import math
import random

import bpy

from common import BLUE, area_light, glass, lerp, light_only, linear, mesh, night, remesh, text, wet_ground
from wrist import Tile

# Units of length for a minute, the height of the heaviest rain the scale shows, and how high its rain falls from.
MINUTE = 0.5
RIDGE_HEIGHT = 3.0
RIDGE_WIDTH = 0.12
RAIN_HEIGHT = 10.0
RAIN_WIDTH = 3.4
STROKE = 0.06
AXIS = 120.0  # minutes on the widget's axis


class World:
    def __init__(self, scene, gen, language, minute_of, arrives, sign_at=None, extent_of=lambda frame: 1.0,
                 scale=1.0, origin=(0, 0, 0), ground=True, near=-4.0, from_now=False, label_turn=math.pi / 2):
        """minute_of(frame): minutes since the film's first minute. arrives: the frame the rain reaches now.
        sign_at(frame): where the circle stands by the dot, as (across, along, height, size), or None
        for no sign. extent_of(frame): how much of the line is drawn yet, 0 to 1, from now outwards.
        near: the rain is not drawn nearer to now than this (units along the line). from_now: the
        street is seen by someone standing at now, looking along the line: only the baseline and the
        dot are drawn, finer, with the rain over them; the wall of glass would stand in their face,
        and "Now" would be written under their feet."""
        self.from_now = from_now
        self.label_turn = label_turn  # which way the words on the ground face
        self.hidden_from = None
        self.scene, self.gen, self.language = scene, gen, language
        self.minute_of, self.arrives, self.sign_at, self.extent_of, self.near = minute_of, arrives, sign_at, extent_of, near
        self.lines = json.load(open(f"{gen}/{language}/line.json"))
        self.root = bpy.data.objects.new("street", None)
        scene.collection.objects.link(self.root)
        self.root.location, self.root.scale = origin, (scale, scale, scale)

        def own(o):
            o.parent = self.root
            return o
        # The whole curve in minutes since the film's first minute, from the forecast at that minute.
        first = self.lines[1]
        self.curve = [[(first["axisStart"] + t * AXIS, v) for t, v in run] for run in first["runs"]]
        self.known = first["axisStart"] + first["known"] * AXIS
        self.rain_start = first["axisStart"] + first["dot"] * AXIS

        if ground:
            own(mesh("ground", [(-300, -300, 0), (300, -300, 0), (300, 300, 0), (-300, 300, 0)], [(0, 1, 2, 3)], wet_ground()))
        self.ridge = own(mesh("ridge", [], [], glass("rain glass", BLUE, roughness=0.04, glow=0.12)))
        self.ridge.data.materials.append(light_only("rain edge", BLUE, 1.8))
        self.track = own(mesh("track", [], [], light_only("track", (0.38, 0.38, 0.38), 1.0)))
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.062, segments=32, ring_count=16)
        self.dot = own(bpy.context.object)
        self.dot.name = "dot"
        self.dot.data.materials.append(light_only("dot", (1, 1, 1), 4.0))
        bpy.ops.object.shade_smooth()

        medium = bpy.data.fonts.load(f"{gen}/fonts/SFCompactRounded-Medium.ttf")
        grey = light_only("axis words", (0.62, 0.62, 0.62), 1.6)
        self.now = own(text("now", first["now"], medium, 0.5, grey, align="LEFT"))
        self.hours = [own(text(f"hour {i}", clock, medium, 0.5, grey)) for i, clock in enumerate(first["hours"])]
        self.hour_minutes = [first["axisStart"] + t * AXIS for t in first["hourAt"]]
        self.ticks = own(mesh("ticks", [], [], light_only("ticks", (0.38, 0.38, 0.38), 1.0)))

        # The circle itself, large, standing over the dot: the widget and the rain it counts down to, together.
        self.sign = None
        if sign_at:
            self.sign = Tile(scene, "sign", self.circle(1), (2, 2), None, (0, 0, 0), thickness=0.05)
            own(self.sign.holder)
            self.sign.shown = (-1, 10 ** 6)

        drop = linear((0.72, 0.85, 1.0))
        self.rain = own(mesh("rain", [], [], light_only("rain 0", drop, 0.35)))
        self.rain.data.materials.append(light_only("rain 1", drop, 1.1))
        self.rain.data.materials.append(light_only("rain 2", drop, 3.0))
        self.rain.visible_shadow = False
        self.splash = own(mesh("splashes", [], [], light_only("splash", drop, 1.2)))
        for o in (self.ridge, self.track, self.rain, self.splash, self.ticks):
            o.cycles.use_motion_blur = False
        rng = random.Random(3)
        self.drops = [(rng.random(), rng.gauss(0, 0.33), rng.random(), rng.uniform(0.7, 1.4), rng.random(), rng.random())
                      for _ in range(26000)]

        own(night(scene))
        # A light keeps its power when the street is scaled up, so it is given more to reach as far.
        for light in (area_light("moon", (-10, 26, 18), (0, 8, 0), (0.55, 0.72, 1.0), 9000 * scale * scale, 10),
                      area_light("lamp", (9, -6, 8), (0, 3, 0), (1.0, 0.6, 0.28), 2500 * scale * scale, 5)):
            own(light)
        bpy.app.handlers.frame_change_pre.append(lambda scene, *_: self.update(scene.frame_current))

    def hide(self, hidden):
        """Take the whole street out of the picture, or put it back."""
        for o in self.root.children_recursive:
            o.hide_render = hidden

    def circle(self, index):
        return f"{self.gen}/{self.language}/circle/{index:02d}.png"

    def height_at(self, s):
        for run in self.curve:
            if run[0][0] <= s <= run[-1][0]:
                for (s0, v0), (s1, v1) in zip(run, run[1:]):
                    if s0 <= s <= s1:
                        return lerp(v0, v1, (s - s0) / (s1 - s0)) if s1 > s0 else v0
        return 0.0

    def update(self, frame):
        if self.hidden_from is not None and frame >= self.hidden_from:
            self.hide(True)
            return
        minute, extent = self.minute_of(frame), self.extent_of(frame)
        reach = minute + extent * (self.known - minute)  # how far along the line is drawn

        def along(s):
            return (s - minute) * MINUTE

        # The rain line: a wall of glass whose top edge is the line, from now on.
        verts, faces, edge_faces = [], [], []
        half = RIDGE_WIDTH / 2
        for run in self.curve:
            points = [(s, v) for s, v in run if minute - 1e-6 <= s <= reach]
            if len(points) < 2 or self.from_now:
                continue
            first = len(verts)
            for s, v in points:
                y, top = along(s), 0.004 + v * RIDGE_HEIGHT
                verts += [(-half, y, 0), (half, y, 0), (half, y, top), (-half, y, top)]
            for i in range(len(points) - 1):
                a, b = first + 4 * i, first + 4 * i + 4
                faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2), (a + 3, a + 2, b + 2, b + 3), (a, a + 3, b + 3, b)]
                edge_faces.append(len(faces) - 2)
            last = first + 4 * (len(points) - 1)
            faces += [(first, first + 1, first + 2, first + 3), (last + 3, last + 2, last + 1, last)]
        remesh(self.ridge, verts, faces, smooth=True)
        for index in edge_faces:
            self.ridge.data.polygons[index].material_index = 1
            self.ridge.data.polygons[index].use_smooth = False

        # The baseline, as far as the forecast reaches, with a gap round the dot as the widget has.
        line = self.lines[min(len(self.lines) - 1, max(0, int(math.floor(minute + 1e-6)) + 1))]
        dot_minute = None if line["dot"] is None else line["axisStart"] + line["dot"] * AXIS
        verts, faces, previous = [], [], False
        stroke = STROKE * (0.15 if self.from_now else 1.0)
        for i in range(241):
            s = minute + (reach - minute) * i / 240
            if dot_minute is not None and abs(along(s) - along(dot_minute)) < 0.13:
                previous = False
                continue
            verts += [(-stroke / 2, along(s), 0.003), (stroke / 2, along(s), 0.003)]
            if previous:
                n = len(verts)
                faces.append((n - 4, n - 3, n - 1, n - 2))
            previous = True
        remesh(self.track, verts, faces)
        self.dot.hide_render = dot_minute is None or dot_minute > reach
        if dot_minute is not None:
            self.dot.location = (0, along(dot_minute), 0.02)
            self.dot.scale = [0.4 if self.from_now else 1.0] * 3

        # The axis's own words on the ground beside it: "Now", and the hours as the line reaches them.
        self.now.location, self.now.rotation_euler = (0.3, -0.16, 0.004), (0, 0, self.label_turn)
        self.now.scale = [0.0 if self.from_now else min(1.0, extent * 12)] * 3
        ticks, tick_faces = [], []
        for o, s in zip(self.hours, self.hour_minutes):
            y = along(s)
            shown = float(s <= reach and y > 1.6)
            o.location, o.rotation_euler, o.scale = (0.46, y, 0.004), (0, 0, self.label_turn), [shown] * 3
            if s <= reach:
                n = len(ticks)
                ticks += [(0, y - 0.03, 0.003), (0.22, y - 0.03, 0.003), (0.22, y + 0.03, 0.003), (0, y + 0.03, 0.003)]
                tick_faces.append((n, n + 1, n + 2, n + 3))
        remesh(self.ticks, ticks, tick_faces)

        # The circle over the dot until the rain arrives, the moment it counts down to; then at now, where the rain is.
        if self.sign:
            across, ahead, height, size = self.sign_at(frame)
            anchor = along(dot_minute) if dot_minute is not None and not line["raining"] else 0.0
            holder = self.sign.holder
            holder.location = (across, anchor + ahead, height)
            holder.scale = (size, size, size)
            holder.rotation_quaternion = self.scene.camera.matrix_world.to_quaternion()
            self.sign.show(self.circle(min(len(self.lines) - 1, int(math.floor(minute + 1e-6)) + 1)))

        self.fall(frame, minute)

    def fall(self, frame, minute):
        """The forecast's rain over the line: it falls from as high as the line is tall there, and
        thicker where it is heavier. Streaks that lean the way the rain walks, and a ring where each lands."""
        verts, faces, tiers, rings, ring_faces = [], [], [], [], []
        span = (self.rain_start, min(max(run[-1][0] for run in self.curve), minute + 75))
        for where, across, phase, speed, chance, glint in self.drops:
            s = lerp(span[0], span[1], where)
            v = self.height_at(s)
            # Heavier rain has more drops; the lightest still has some.
            if v <= 0 or chance > 0.1 + 0.9 * v ** 0.7:
                continue
            y = (s - minute) * MINUTE
            if y < self.near:
                continue
            top = RAIN_HEIGHT * (0.2 + 0.8 * v ** 0.6)
            period = top / (0.42 * speed)  # frames to fall
            fallen = (frame / period + phase) % 1.0
            x = across * RAIN_WIDTH / 2
            z = top * (1 - fallen)
            length = 0.34 * speed
            lean = 0.22 * length
            # Seen from the wrist the street is four times the size, and its rain is drawn finer to match.
            width = 0.0055 * (0.3 if self.from_now else 1.0)
            y += lean * z / length
            n = len(verts)
            verts += [(x - width, y, z), (x + width, y, z), (x + width, y + lean, z + length), (x - width, y + lean, z + length),
                      (x, y - width, z), (x, y + width, z), (x, y + width + lean, z + length), (x, y - width + lean, z + length)]
            faces += [(n, n + 1, n + 2, n + 3), (n + 4, n + 5, n + 6, n + 7)]
            tiers += [0 if glint < 0.55 else 1 if glint < 0.93 else 2] * 2
            # Where the last fall of this drop landed: a ring that widens and fades.
            age = fallen * period
            if age < 9:
                self.ring(rings, ring_faces, x, y, 0.03 + 0.016 * age, 0.008 * (1 - age / 9) * (0.4 if self.from_now else 1.0), 20)
        # The first drops land at now: three rings run out over the wet ground.
        for delay in (0, 5, 11):
            age = frame - self.arrives - delay
            if 0 <= age < 34:
                self.ring(rings, ring_faces, 0, 0, 0.12 + 0.2 * age, 0.07 * (1 - age / 34) ** 1.5 * (0.3 if self.from_now else 1.0), 96, 0.004)
        remesh(self.rain, verts, faces)
        for polygon, tier in zip(self.rain.data.polygons, tiers):
            polygon.material_index = tier
        remesh(self.splash, rings, ring_faces)

    @staticmethod
    def ring(verts, faces, x, y, radius, thick, steps, z=0.002):
        m = len(verts)
        for k in range(steps):
            a = 2 * math.pi * k / steps
            verts += [(x + radius * math.cos(a), y + radius * math.sin(a), z),
                      (x + (radius + thick) * math.cos(a), y + (radius + thick) * math.sin(a), z)]
        for k in range(steps):
            a, b = m + 2 * k, m + 2 * ((k + 1) % steps)
            faces.append((a, a + 1, b + 1, b))
