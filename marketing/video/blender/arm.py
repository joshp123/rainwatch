"""A left forearm for the film's watches, dressed for a wet November morning.

Written by AI on 2026.11.18 by model claude fable 5.2.

    import arm, watch
    root = watch.build("ultra")
    parts = arm.build(root)       # a dict of objects, all parented to the watch's root

The forearm runs along X through the band's loop: a rain jacket's sleeve towards -X, its cuff a
few millimetres from the watch, and a gloved hand towards +X. Both cuffs close round the case's
own outline and run on beside the band, so only a margin of wrist shows round the watch. The
sleeve and the hand run on far enough to leave any frame that holds the watch. Sizes are real, in
metres; the shapes are made here, in code, in millimetres.

Parts: "sleeve", "tab" (the cuff's adjuster), "stitches", "beads" (rain standing on the sleeve),
"skin", "cuff" (the glove's knitted cuff) and "glove" (the back of the hand).
"""

import random
from math import cos, exp, hypot, pi, sin, sqrt

import bmesh
import bpy
from mathutils import Vector, noise

MM = 0.001

# How the arm's width and depth change along it (x in mm from the watch's centre), as multiples of
# the wrist's; how far the hand sits towards the thumb; and how the back of the hand rises.
WIDTH = [(-320, 1.42), (-90, 1.1), (-30, 1.0), (22, 1.0), (55, 1.24), (88, 1.42), (175, 1.45)]
DEPTH = [(-320, 1.75), (-90, 1.22), (-30, 1.0), (22, 1.0), (55, 0.93), (88, 0.78), (175, 0.6)]
THUMB = [(30, 0.0), (90, 5.0), (175, 6.0)]
LIFT = [(22, 0.0), (60, 1.5), (175, 1.0)]
ROUND = 2.4      # the top of a wrist is flatter than an ellipse and rounds over at its sides


def _step(lo, hi, x):
    t = min(max((x - lo) / (hi - lo), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _curve(x, knots):
    if x <= knots[0][0]:
        return knots[0][1]
    for (x0, v0), (x1, v1) in zip(knots, knots[1:]):
        if x <= x1:
            return v0 + (v1 - v0) * _step(x0, x1, x)
    return knots[-1][1]


def _wrap(angle):
    return (angle + pi) % (2 * pi) - pi


# ---------------------------------------------------------------------------------------------
# Meshes

class _Mesh:
    def __init__(self):
        self.verts, self.faces, self.uvs = [], [], []

    def strip(self, rows, closed=True, uvs=None):
        """Join rows of points. Rows that advance towards +X, with points running from the top of
        the arm towards +Y, give faces that look outwards."""
        n = len(rows[0])
        start = len(self.verts)
        for i, row in enumerate(rows):
            self.verts += row
            self.uvs += uvs[i] if uvs else [(0.0, 0.0)] * n
        for i in range(len(rows) - 1):
            a, b = start + i * n, start + (i + 1) * n
            for j in range(n if closed else n - 1):
                k = (j + 1) % n
                self.faces.append((a + j, b + j, b + k, a + k))

    def tube(self, points, radii, sides=6):
        """A thread: a thin tube through points, closed at both ends."""
        start = len(self.verts)
        for i, (p, radius) in enumerate(zip(points, radii)):
            before, after = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
            t = [after[k] - before[k] for k in range(3)]
            length = sqrt(sum(c * c for c in t)) or 1.0
            t = [c / length for c in t]
            u = (0.0, -t[2], t[1]) if abs(t[0]) > 0.6 else (-t[1], t[0], 0.0) if abs(t[2]) > 0.6 else (-t[2], 0.0, t[0])
            ul = sqrt(sum(c * c for c in u)) or 1.0
            u = [c / ul for c in u]
            v = (t[1] * u[2] - t[2] * u[1], t[2] * u[0] - t[0] * u[2], t[0] * u[1] - t[1] * u[0])
            for s in range(sides):
                angle = 2 * pi * s / sides
                self.verts.append(tuple(p[k] + radius * (cos(angle) * u[k] + sin(angle) * v[k]) for k in range(3)))
                self.uvs.append((0.0, 0.0))
        for i in range(len(points) - 1):
            a, b = start + i * sides, start + (i + 1) * sides
            for s in range(sides):
                k = (s + 1) % sides
                self.faces.append((a + s, a + k, b + k, b + s))
        self.faces.append(tuple(start + s for s in range(sides)))
        self.faces.append(tuple(start + (len(points) - 1) * sides + s for s in range(sides)))

    def bead(self, centre, normal, radius, squash=0.7, rings=5, sides=10):
        """A drop of water standing on a surface."""
        nx, ny, nz = normal
        u = (0.0, -nz, ny) if abs(nx) < 0.9 else (-ny, nx, 0.0)
        ul = sqrt(sum(c * c for c in u))
        u = [c / ul for c in u]
        v = (ny * u[2] - nz * u[1], nz * u[0] - nx * u[2], nx * u[1] - ny * u[0])
        start = len(self.verts)
        for r in range(1, rings):
            polar = pi * r / rings
            for s in range(sides):
                angle = 2 * pi * s / sides
                a, b, c = radius * sin(polar) * cos(angle), radius * sin(polar) * sin(angle), radius * squash * cos(polar)
                self.verts.append(tuple(centre[k] + a * u[k] + b * v[k] + c * normal[k] for k in range(3)))
        top = len(self.verts)
        self.verts.append(tuple(centre[k] + radius * squash * normal[k] for k in range(3)))
        self.verts.append(tuple(centre[k] - radius * squash * normal[k] for k in range(3)))
        self.uvs += [(0.0, 0.0)] * (len(self.verts) - start)
        for r in range(rings - 2):
            a, b = start + r * sides, start + (r + 1) * sides
            for s in range(sides):
                k = (s + 1) % sides
                self.faces.append((a + s, b + s, b + k, a + k))
        for s in range(sides):
            k = (s + 1) % sides
            self.faces.append((top, start + s, start + k))
            self.faces.append((top + 1, start + (rings - 2) * sides + k, start + (rings - 2) * sides + s))

    def object(self, name, material, root, closed=False):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([(x * MM, y * MM, z * MM) for x, y, z in self.verts], [], self.faces)
        mesh.polygons.foreach_set("use_smooth", [True] * len(self.faces))
        layer = mesh.uv_layers.new(name="cloth")
        for loop in mesh.loops:
            layer.data[loop.index].uv = self.uvs[loop.vertex_index]
        mesh.update()
        if closed:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = root
        return obj


# ---------------------------------------------------------------------------------------------
# Materials

def _principled(name, **inputs):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for key, value in inputs.items():
        socket = shader.inputs[key]
        socket.default_value = (*value, 1.0) if socket.type == "RGBA" and len(value) == 3 else value
    return material, tree, shader


def _bump(tree, shader, heights, distance):
    """Add height textures (output socket, weight) together and use them as the surface's relief."""
    total = None
    for socket, weight in heights:
        scaled = tree.nodes.new("ShaderNodeMath")
        scaled.operation = "MULTIPLY"
        scaled.inputs[1].default_value = weight
        tree.links.new(socket, scaled.inputs[0])
        if total is None:
            total = scaled.outputs[0]
        else:
            add = tree.nodes.new("ShaderNodeMath")
            tree.links.new(total, add.inputs[0])
            tree.links.new(scaled.outputs[0], add.inputs[1])
            total = add.outputs[0]
    bump = tree.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = distance * MM
    tree.links.new(total, bump.inputs["Height"])
    tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])


def _noise(tree, vector, size, detail=2.0, stretch=None):
    """Noise whose features are `size` mm across; stretch scales it along (x, y, z)."""
    noise = tree.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 1 / (size * MM)
    noise.inputs["Detail"].default_value = detail
    if stretch:
        mapping = tree.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = stretch
        tree.links.new(vector, mapping.inputs["Vector"])
        vector = mapping.outputs["Vector"]
    tree.links.new(vector, noise.inputs["Vector"])
    return noise.outputs["Fac"]


def _ripstop(name, colour):
    """Wet ripstop nylon: a fine weave, a grid of heavier threads, and rain lying on it in patches."""
    material, tree, shader = _principled(name, **{
        "Base Color": colour, "Roughness": 0.5, "Specular IOR Level": 0.35, "Sheen Weight": 0.05, "Sheen Roughness": 0.4,
        "Sheen Tint": colour, "Coat Roughness": 0.18})
    uv = tree.nodes.new("ShaderNodeUVMap").outputs["UV"]             # in metres along the cloth
    position = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    weave = tree.nodes.new("ShaderNodeTexChecker")
    weave.inputs["Scale"].default_value = 1 / (0.45 * MM)
    tree.links.new(uv, weave.inputs["Vector"])
    grid = tree.nodes.new("ShaderNodeTexBrick")
    grid.offset = 0.0
    grid.inputs["Scale"].default_value = 1 / (4.0 * MM)
    grid.inputs["Mortar Size"].default_value = 0.035
    grid.inputs["Brick Width"].default_value = 1.0
    grid.inputs["Row Height"].default_value = 1.0
    tree.links.new(uv, grid.inputs["Vector"])
    _bump(tree, shader, [(weave.outputs["Fac"], 0.6), (grid.outputs["Fac"], 1.0), (_noise(tree, position, 2.5), 1.5)], 0.1)
    wet = tree.nodes.new("ShaderNodeMapRange")
    wet.inputs["From Min"].default_value = 0.35
    wet.inputs["From Max"].default_value = 0.65
    wet.inputs["To Min"].default_value = 0.03
    wet.inputs["To Max"].default_value = 0.28
    tree.links.new(_noise(tree, position, 18.0, 3.0), wet.inputs["Value"])
    tree.links.new(wet.outputs["Result"], shader.inputs["Coat Weight"])
    return material


def _knit(name, colour):
    material, tree, shader = _principled(name, **{
        "Base Color": colour, "Roughness": 0.9, "Sheen Weight": 0.05, "Sheen Roughness": 0.5, "Sheen Tint": colour, "Specular IOR Level": 0.2})
    position = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    _bump(tree, shader, [(_noise(tree, position, 0.5, 2.0, (4.0, 1.0, 1.0)), 1.0), (_noise(tree, position, 0.15), 0.5)], 0.25)
    return material


def _softshell(name, colour):
    material, tree, shader = _principled(name, **{
        "Base Color": colour, "Roughness": 0.55, "Specular IOR Level": 0.35, "Sheen Weight": 0.05, "Sheen Roughness": 0.45,
        "Sheen Tint": colour, "Coat Weight": 0.3, "Coat Roughness": 0.18})
    position = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    _bump(tree, shader, [(_noise(tree, position, 0.3), 1.0), (_noise(tree, position, 3.0), 1.5)], 0.06)
    return material


# ---------------------------------------------------------------------------------------------

class _Arm:
    def __init__(self, root, seed):
        self.root = root
        self.half_w, self.half_d, self.centre_z = (v / MM for v in root["loop"])
        case = [v / MM for v in root["case"]]
        self.top = -case[2] - 0.25                 # the skin under the back of the watch
        self.glove_x = case[3] + 1.5               # where the glove begins, at its nearest
        band = bpy.data.objects[f"{root.name}.band"]
        self.beside_band = max(corner[0] for corner in band.bound_box) / MM + 1.8
        # How far the case, with its crown and buttons, reaches to each side at each millimetre of y,
        # so that the cuffs can close round it.
        reach = {-1: [0.0] * 81, 1: [0.0] * 81}
        for part in ("body", "details"):
            for vertex in bpy.data.objects[f"{root.name}.{part}"].data.vertices:
                x, y, z = (c / MM for c in vertex.co)
                if abs(y) <= 40 and z > -case[2]:
                    side = 1 if x > 0 else -1
                    reach[side][round(y) + 40] = max(reach[side][round(y) + 40], abs(x))
        self.reach = {}
        for side, raw in reach.items():
            wide = [max(raw[max(i - 2, 0):i + 3]) for i in range(81)]
            self.reach[side] = [sum(wide[max(i - 2, 0):i + 3]) / len(wide[max(i - 2, 0):i + 3]) for i in range(81)]
        rng = random.Random(seed)
        # The sleeve is pushed back from the watch, so it bunches into folds that run part of the way round.
        self.folds = []
        for _ in range(18):
            self.folds.append((14 + 290 * rng.random() ** 1.5, rng.uniform(-pi, pi), rng.uniform(1.0, 2.6),
                               rng.uniform(3.0, 6.0), rng.uniform(-9.0, 9.0), rng.uniform(0.7, 2.4)))
        self.rng = rng
        self.tab_from, self.tab_to = -0.8, 0.4     # the cuff's tab, in angle round the arm
        self.tab_near, self.tab_far = 4.5, 26.5    # and in mm back from the cuff's edge
        self.tab_hem = max(self.edge(-1, self.tab_from + (self.tab_to - self.tab_from) * i / 40) for i in range(41))

    # ---- the arm itself ----

    def section(self, x, angle, gap=0.0):
        """A point on the arm's surface, or `gap` mm outside it: angle 0 is the top, towards +Y."""
        y = (self.half_w - 0.4 + gap) * sin(angle)
        if cos(angle) > 0:                         # the top, up to the back of the watch
            z = self.centre_z + (self.top - self.centre_z + gap) * (1 - abs(sin(angle)) ** ROUND) ** (1 / ROUND)
        else:                                      # underneath, the band's own loop
            z = self.centre_z + (self.half_d - 0.4 + gap) * cos(angle)
        y = y * _curve(x, WIDTH) - _curve(x, THUMB)
        if z < self.top:
            z = self.top + (z - self.top) * _curve(x, DEPTH)
        return y, z + _curve(x, LIFT)

    def offset(self, x, angle, gap, lift):
        """That point, moved `lift` mm along the surface's normal; and the normal."""
        y, z = self.section(x, angle, gap)
        y0, z0 = self.section(x, angle - 0.01, gap)
        y1, z1 = self.section(x, angle + 0.01, gap)
        length = hypot(y1 - y0, z1 - z0)
        ny, nz = -(z1 - z0) / length, (y1 - y0) / length
        return (x, y + ny * lift, z + nz * lift), (0.0, ny, nz)

    def edge(self, side, angle, margin=1.6):
        """Where a cuff ends on this side of the watch (x, unsigned): close round the case on top of
        the wrist, and beside the band past the case's ends and underneath."""
        if cos(angle) <= 0:
            return self.beside_band
        y = min(max((self.half_w - 0.4) * sin(angle) + 40, 0.0), 79.999)
        reach = self.reach[side]
        at = reach[int(y)] + (reach[int(y) + 1] - reach[int(y)]) * (y - int(y))
        return max(self.beside_band, at + margin)

    # ---- the sleeve ----

    def cloth(self, back, angle):
        """How far the sleeve's cloth stands off its smooth shape, `back` mm from the cuff's edge."""
        hem = 0.45 * (1 - _step(8.5, 10.5, back)) - 0.3 * exp(-((back - 7.0) / 0.4) ** 2)
        elastic = 0.25 + 0.75 * (0.5 - 0.5 * cos(angle - 0.3))
        pleats = exp(-back / 26) * elastic * (1.1 * abs(sin(15.5 * angle + 0.3)) - 0.6 + 0.4 * sin(19 * angle + 2.1))
        # Pushed-back cloth buckles into sharp ridges that run round the arm, and crumples finely.
        c, s = 38 * cos(angle), 38 * sin(angle)
        ridges = 1.7 * (1 - abs(noise.noise(Vector((c / 30, s / 30, back / 9.5))))) ** 1.6
        ridges += 0.4 * (1 - abs(noise.noise(Vector((c / 13, s / 13, back / 5 + 7.3))))) ** 1.6 - 1.1
        for at, round_, height, width, lean, span in self.folds:
            turn = _wrap(angle - round_)
            ridges += height * exp(-((back - at - lean * turn) / width) ** 2) * exp(-(turn / span) ** 4)
        # The tab is stiff and holds the cloth under it flat.
        loose = 1 - _step(-6.0, 1.0, self.tab(back - self.tab_hem + self.edge(-1, angle), angle))
        pleats *= 0.4 + 0.6 * loose
        ridges *= _step(6, 26, back) * (0.55 + 0.45 * exp(-back / 110)) * loose
        crumple = 0.06 * _step(9, 14, back) * noise.noise(Vector((c / 3.2, s / 3.2, back / 3.2)))
        return hem + pleats + ridges + crumple

    def tab(self, back, angle):
        """How high the cuff's tab stands off the sleeve here; below zero outside it."""
        radius = 34.0
        half_long = (self.tab_to - self.tab_from) / 2 * radius
        along = (angle - (self.tab_from + self.tab_to) / 2) * radius
        across = back - (self.tab_near + self.tab_far) / 2
        corner = 6.0 if along < 0 else 2.0
        qx, qy = abs(along) - half_long + corner, abs(across) - (self.tab_far - self.tab_near) / 2 + corner
        inside = corner - hypot(max(qx, 0.0), max(qy, 0.0)) - min(max(qx, qy), 0.0)
        return inside

    def on_tab(self, back, angle, lift=0.0):
        """A point on the cuff's tab. The tab is stiff, so it lies straight across the sleeve however
        the hem under it runs: `back` is measured from the hem at its furthest from the watch."""
        lift += 1.6 * _step(0.0, 1.0, self.tab(back, angle)) - 0.1
        return self.sleeve(back + self.tab_hem - self.edge(-1, angle), angle, lift)

    def sleeve(self, back, angle, lift=0.0):
        gap = 4.0 + 11 * (1 - exp(-back / 40)) + 0.035 * back
        return self.offset(-self.edge(-1, angle) - back, angle, gap, self.cloth(back, angle) + lift)

    def build_sleeve(self, material):
        columns = 400
        angles = [2 * pi * j / columns for j in range(columns)]
        backs = [320 - 3 * i for i in range(60)] + [140 - 1.6 * i for i in range(50)] + [60 - i for i in range(48)] + [12 - 0.4 * i for i in range(31)]
        rows, uvs = [], []
        for back in backs:
            rows.append([self.sleeve(back, a)[0] for a in angles])
            uvs.append([(a * 40 * MM, back * MM) for a in angles])
        roll = 1.3                                  # the cuff's edge, rolled under into the lining
        for i in range(1, 7):
            turn = pi * i / 6
            row = []
            for a in angles:
                (x, y, z), _ = self.sleeve(0.0, a, -roll * (1 - cos(turn)))
                row.append((x + roll * sin(turn), y, z))
            rows.append(row)
            uvs.append([(a * 40 * MM, -roll * turn * MM) for a in angles])
        for back in range(2, 32, 2):
            rows.append([self.sleeve(back, a, -2 * roll)[0] for a in angles])
            uvs.append([(a * 40 * MM, -(roll * pi + back) * MM) for a in angles])
        mesh = _Mesh()
        mesh.strip(rows, uvs=uvs)
        return mesh.object(f"{self.root.name}.arm.sleeve", material, self.root)

    def build_tab(self, material):
        rows, uvs = [], []
        for i in range(60):
            back = self.tab_far + 0.8 - (self.tab_far - self.tab_near + 1.6) * i / 59
            row, uv = [], []
            for j in range(120):
                angle = self.tab_from - 0.03 + (self.tab_to - self.tab_from + 0.06) * j / 119
                row.append(self.on_tab(back, angle)[0])
                uv.append((back * MM, angle * 34 * MM))
            rows.append(row)
            uvs.append(uv)
        mesh = _Mesh()
        mesh.strip(rows, closed=False, uvs=uvs)
        return mesh.object(f"{self.root.name}.arm.tab", material, self.root)

    def stitch(self, mesh, path, place, length=2.4, space=0.8):
        """Sew along a path of surface coordinates; place(coords, lift) gives the point in space."""
        points = [place(c, 0.0) for c in path]
        travelled = [0.0]
        for p, q in zip(points, points[1:]):
            travelled.append(travelled[-1] + sqrt(sum((q[k] - p[k]) ** 2 for k in range(3))))

        def at(distance):
            for i in range(len(travelled) - 1):
                if travelled[i + 1] >= distance:
                    f = (distance - travelled[i]) / max(travelled[i + 1] - travelled[i], 1e-9)
                    return tuple(path[i][k] + (path[i + 1][k] - path[i][k]) * f for k in range(2))
            return path[-1]

        start = 0.0
        while start + length <= travelled[-1]:
            thread = [place(at(start + length * f), lift) for f, lift in ((0, -0.12), (0.2, 0.1), (0.5, 0.16), (0.8, 0.1), (1, -0.12))]
            mesh.tube(thread, (0.16, 0.2, 0.2, 0.2, 0.16))
            start += length + space

    def build_stitches(self, material):
        mesh = _Mesh()
        ring = [(7.0, 2 * pi * j / 720) for j in range(721)]
        self.stitch(mesh, ring, lambda c, lift: self.sleeve(c[0], c[1], lift)[0])
        # Round the tab, 2 mm in from its edge.
        radius = 34.0
        middle = (self.tab_from + self.tab_to) / 2
        half_long = (self.tab_to - self.tab_from) / 2 * radius - 2.0
        half_wide = (self.tab_far - self.tab_near) / 2 - 2.0
        outline = [(half_long - 2 * half_long * i / 60 + 4 * i / 60, -half_wide) for i in range(61)]
        outline += [(-half_long + 4 - 4 * sin(pi / 2 * i / 12), -half_wide + 4 - 4 * cos(pi / 2 * i / 12)) for i in range(1, 13)]
        outline += [(-half_long, -half_wide + 4 + (2 * half_wide - 8) * i / 16) for i in range(1, 17)]
        outline += [(-half_long + 4 - 4 * cos(pi / 2 * i / 12), half_wide - 4 + 4 * sin(pi / 2 * i / 12)) for i in range(1, 13)]
        outline += [(-half_long + 4 + (2 * half_long - 4) * i / 60, half_wide) for i in range(1, 61)]
        outline += [(half_long, half_wide - 2 * half_wide * i / 20) for i in range(1, 21)]
        centre = (self.tab_near + self.tab_far) / 2
        path = [(centre + across, middle + along / radius) for along, across in outline]
        self.stitch(mesh, path, lambda c, lift: self.on_tab(c[0], c[1], lift)[0])
        # The glove's hem.
        ring = [(self.glove_x + 19.5, 2 * pi * j / 720) for j in range(721)]
        self.stitch(mesh, ring, lambda c, lift: self.shell(c[0], c[1], lift)[0])
        return mesh.object(f"{self.root.name}.arm.stitches", material, self.root, closed=True)

    def build_beads(self, material):
        mesh = _Mesh()
        for _ in range(800):
            back, angle = 1.5 + 150 * self.rng.random() ** 1.4, self.rng.uniform(-1.9, 1.9)
            radius = 0.18 + 1.0 * self.rng.random() ** 3
            on_tab = self.tab(back - self.tab_hem + self.edge(-1, angle), angle)
            if -1.5 < on_tab <= 1.2:
                continue
            place = self.on_tab if on_tab > 1.2 else self.sleeve
            centre, normal = place(back - (self.tab_hem - self.edge(-1, angle) if on_tab > 1.2 else 0), angle, radius * 0.3)
            mesh.bead(centre, normal, radius)
        return mesh.object(f"{self.root.name}.arm.beads", material, self.root, closed=True)

    # ---- the hand ----

    def knit(self, along, angle, lift=0.0, ribs=88):
        """The glove's knitted cuff, `along` mm from its edge."""
        rib = 0.55 * abs(cos(ribs * angle / 2)) ** 0.5
        return self.offset(self.edge(1, angle) + along, angle, 2.2, rib + 0.2 * sin(3 * angle + along / 9) + lift)

    def build_cuff(self, material):
        ribs = 88
        columns = ribs * 8
        angles = [2 * pi * j / columns for j in range(columns)]
        roll = 1.1
        rows = []
        for i in range(7):                          # the edge, rolled over
            turn = pi * (1 - i / 6)
            row = []
            for a in angles:
                (x, y, z), _ = self.knit(roll, a, -roll + roll * cos(turn))
                row.append((x - roll * sin(turn), y, z))
            rows.append(row)
        for i in range(1, 62):
            rows.append([self.knit(roll + 0.6 * i, a)[0] for a in angles])
        mesh = _Mesh()
        mesh.strip(rows)
        return mesh.object(f"{self.root.name}.arm.cuff", material, self.root)

    def shell(self, x, angle, lift=0.0):
        creases = sum(h * exp(-((x - at) / 2.6) ** 2) for at, h in ((self.glove_x + 30, 0.9), (self.glove_x + 37, 0.7), (self.glove_x + 46, 0.5)))
        point, normal = self.offset(x, angle, 4.3, creases * (0.5 + 0.5 * cos(angle)) + 0.35 * sin(2 * angle + x / 14) + lift)
        end = 150.0
        if x > end:                                 # the hand closes, far out of frame
            shrink = sqrt(max(1 - ((x - end) / 24) ** 2, 0.0004))
            cy, cz = -_curve(x, THUMB), self.top - 14 * _curve(x, DEPTH)
            point = (x, cy + (point[1] - cy) * shrink, cz + (point[2] - cz) * shrink)
        return point, normal

    def build_glove(self, material):
        columns = 240
        angles = [2 * pi * j / columns for j in range(columns)]
        start = self.glove_x + 15
        roll = 0.8
        rows = []
        for i in range(7):
            turn = pi * (1 - i / 6)
            row = []
            for a in angles:
                (x, y, z), _ = self.shell(start + roll, a, -roll + roll * cos(turn))
                row.append((x - roll * sin(turn), y, z))
            rows.append(row)
        x = start + roll
        while x < 173.5:
            x += 0.5 if x < start + 12 else 1.5
            rows.append([self.shell(min(x, 173.9), a)[0] for a in angles])
        mesh = _Mesh()
        mesh.strip(rows)
        return mesh.object(f"{self.root.name}.arm.glove", material, self.root)

    def build_skin(self, material):
        angles = [2 * pi * j / 120 for j in range(120)]
        rows = [[self.offset(x, a, 0.0, 0.0)[0] for a in angles] for x in (-70 + 2.5 * i for i in range(int((self.glove_x + 95) / 2.5)))]
        mesh = _Mesh()
        mesh.strip(rows)
        return mesh.object(f"{self.root.name}.arm.skin", material, self.root)


def build(root, jacket=(0.016, 0.026, 0.05), glove=(0.011, 0.014, 0.022), seed=4, beads=True):
    """Dress the watch's wrist. root is what watch.build() returned; returns a dict of the parts.

    The colours are set for the film's street (wrist.py), whose light is strong: there the cloth
    reads as dark navy and the little skin that shows as skin in shadow. Sheen is left almost off
    because that light falls on it as on a matt surface, and turned the dark cloth pale grey."""
    arm = _Arm(root, seed)
    name = root.name
    skin, tree, shader = _principled(f"{name} skin", **{
        "Base Color": (0.1, 0.052, 0.036), "Roughness": 0.5, "Coat Weight": 0.12, "Coat Roughness": 0.2})
    position = tree.nodes.new("ShaderNodeTexCoord").outputs["Object"]
    _bump(tree, shader, [(_noise(tree, position, 0.35), 1.0), (_noise(tree, position, 1.6, 3.0, (1.0, 5.0, 5.0)), 1.2)], 0.04)
    thread = _principled(f"{name} thread", **{"Base Color": tuple(c * 2.2 + 0.006 for c in jacket), "Roughness": 0.75})[0]
    water = _principled(f"{name} rain", **{"Base Color": (1.0, 1.0, 1.0), "Roughness": 0.0, "IOR": 1.33, "Transmission Weight": 1.0})[0]
    tab = _principled(f"{name} tab", **{"Base Color": tuple(c * 0.6 for c in jacket), "Roughness": 0.5, "Coat Weight": 0.3, "Coat Roughness": 0.2})
    _bump(tab[1], tab[2], [(_noise(tab[1], tab[1].nodes.new("ShaderNodeTexCoord").outputs["Object"], 0.25), 1.0)], 0.04)
    parts = {
        "sleeve": arm.build_sleeve(_ripstop(f"{name} jacket", jacket)),
        "tab": arm.build_tab(tab[0]),
        "stitches": arm.build_stitches(thread),
        "skin": arm.build_skin(skin),
        "cuff": arm.build_cuff(_knit(f"{name} glove cuff", glove)),
        "glove": arm.build_glove(_softshell(f"{name} glove", glove)),
    }
    if beads:
        parts["beads"] = arm.build_beads(water)
    return parts
