"""Apple Watches for the RainWatch launch film, modelled in code for Blender 5.2 and Cycles.

Written by AI on 2026.11.18 by model claude fable 5.2.

    import watch
    root = watch.build("ultra")            # or "series" (Series 12, 46 mm), "se" (SE 3, 44 mm)
    watch.set_screen(root, "/path/000.png", brightness=1.5)

build() returns an empty with every part parented to it, and adds no lights, cameras or world.
Sizes are real, in metres. The root is at the centre of the outer surface of the cover glass; the
display faces +Z, the top of the watch is towards +Y and the crown is on +X. The band closes into a
loop under the watch, sized for a wrist.

Parts, as children of the root, named "<root name>.<part>":
    root["loop"]  the band's loop, where a wrist goes: (half-width in Y, half-depth in Z, centre z)
    root["case"]  (half-width, half-height, depth, how far out the crown reaches)

    display   the lit screen: UVs run 0 to 1 over exactly the area the watch's screenshot covers.
              Its material has an image node named "screen" and a value node named "brightness".
    glass     the cover glass, real glass. It is open underneath: the display and the black border
              sit inside it, as on a laminated screen, so there is no second reflection.
    mask      the black border under the glass
    body      the case
    details   crown, buttons, speaker slots
    band      the strap

The shapes are traced from Apple's own front-on bezel pictures (Apple Design Resources) and its
published sizes. Nothing here is a downloaded model.
"""

from math import asin, cos, pi, sin, tan

import bmesh
import bpy
from mathutils import Vector

MM = 0.001
CORNER_POINTS = 32   # points round each corner of an outline
SMOOTH = 1.2         # how far a corner's curve runs past a circle's, as Apple's corners do
POWER = 2.48         # superellipse power that makes such a corner cut the diagonal where a circle would

ORANGE = (1.0, 0.16, 0.0)

SCREEN_PIXELS = {"ultra": (422, 514), "series": (416, 496), "se": (368, 448)}


# ---------------------------------------------------------------------------------------------
# Outlines and profiles (all in millimetres)

def _extent(a, b, r):
    return max(min(r * SMOOTH, 0.98 * a, 0.98 * b), 1e-3)


def _outline(a, b, r, z, n=CORNER_POINTS):
    """Points round a rounded rectangle of half-size (a, b), anticlockwise seen from +Z."""
    e = _extent(a, b, r)
    k = 2 / POWER
    corner = []
    for i in range(n + 1):
        t = (pi / 2) * (0.5 - 0.5 * cos(pi * i / n))
        corner.append((e * max(cos(t), 0.0) ** k, e * max(sin(t), 0.0) ** k))
    ax, by = a - e, b - e
    pts = [(ax + x, by + y, z) for x, y in corner]
    pts += [(-ax - x, by + y, z) for x, y in reversed(corner)]
    pts += [(-ax - x, -by - y, z) for x, y in corner]
    pts += [(ax + x, -by - y, z) for x, y in reversed(corner)]
    return pts


def _edge_x(a, b, r, y):
    """The x of the right-hand edge of that outline at height y."""
    e = _extent(a, b, r)
    u = (abs(y) - (b - e)) / e
    if u <= 0:
        return a
    return a - e + e * (1 - min(u, 1.0) ** POWER) ** (1 / POWER)


def _round(corners, n=8):
    """A polyline of (d, z, radius) with its corners rounded, as a list of (d, z)."""
    pts = [Vector(c[:2]) for c in corners]
    count = len(pts)
    half = [0.0] * count
    reach = [0.0] * count
    for i in range(1, count - 1):
        radius = corners[i][2] if len(corners[i]) > 2 else 0
        angle = (pts[i - 1] - pts[i]).angle(pts[i + 1] - pts[i])
        half[i] = angle / 2
        if radius > 0 and angle < pi - 1e-3:
            reach[i] = radius / tan(angle / 2)
    for i in range(count - 1):
        length = (pts[i + 1] - pts[i]).length
        want = reach[i] + reach[i + 1]
        if want > 0.999 * length:
            reach[i] *= 0.999 * length / want
            reach[i + 1] *= 0.999 * length / want
    out = [pts[0]]
    for i in range(1, count - 1):
        if reach[i] < 1e-6:
            out.append(pts[i])
            continue
        u = (pts[i - 1] - pts[i]).normalized()
        v = (pts[i + 1] - pts[i]).normalized()
        radius = reach[i] * tan(half[i])
        centre = pts[i] + (u + v).normalized() * (radius / sin(half[i]))
        start = pts[i] + u * reach[i] - centre
        end = pts[i] + v * reach[i] - centre
        sweep = start.angle(end)
        steps = max(2, round(n * sweep / (pi / 2)))
        for s in range(steps + 1):
            f = s / steps
            out.append(centre + (start * sin((1 - f) * sweep) + end * sin(f * sweep)) / sin(sweep))
    out.append(pts[-1])
    clean = [out[0]]
    for p in out[1:]:
        if (p - clean[-1]).length > 1e-5:
            clean.append(p)
    return [(p.x, p.y) for p in clean]


def _inset_at(profile, z):
    """How far in from the case's outline a profile's outer wall is at height z."""
    top = max(range(len(profile)), key=lambda i: profile[i][1])
    wall = profile[:top + 1]
    if z <= wall[0][1]:
        return wall[0][0]
    for (d0, z0), (d1, z1) in zip(wall, wall[1:]):
        if z0 <= z <= z1 and z1 > z0:
            return d0 + (d1 - d0) * (z - z0) / (z1 - z0)
    return wall[-1][0]


def _step(lo, hi, x):
    t = min(max((x - lo) / (hi - lo), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------
# Meshes

class _Mesh:
    """Rings of points joined into quads. Lengths go in as millimetres and come out as metres."""

    def __init__(self):
        self.verts, self.faces, self.mats = [], [], []

    def ring(self, pts):
        start = len(self.verts)
        self.verts += pts
        return range(start, start + len(pts))

    def join(self, r0, r1, mat=0):
        n = len(r0)
        for j in range(n):
            k = (j + 1) % n
            self.faces.append((r0[j], r0[k], r1[k], r1[j]))
            self.mats.append(mat)

    def cap(self, r, mat=0, flip=False):
        self.faces.append(tuple(reversed(r)) if flip else tuple(r))
        self.mats.append(mat)

    def loft(self, rings, mat=0, cap_first=False, cap_last=False):
        """Join rings in order. Anticlockwise rings that climb give faces that look outwards."""
        ids = [self.ring(r) for r in rings]
        for i in range(len(ids) - 1):
            self.join(ids[i], ids[i + 1], mat(i) if callable(mat) else mat)
        if cap_first:
            self.cap(ids[0], mat(0) if callable(mat) else mat, flip=True)
        if cap_last:
            self.cap(ids[-1], mat(len(ids) - 2) if callable(mat) else mat)
        return ids

    def grid(self, rows, mat=0):
        """Join rows of points into an open sheet."""
        ids = [self.ring(row) for row in rows]
        for a, b in zip(ids, ids[1:]):
            for j in range(len(a) - 1):
                self.faces.append((a[j], b[j], b[j + 1], a[j + 1]))
                self.mats.append(mat)

    def object(self, name, materials, root, closed=False):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([(x * MM, y * MM, z * MM) for x, y, z in self.verts], [], self.faces)
        mesh.polygons.foreach_set("material_index", self.mats)
        mesh.polygons.foreach_set("use_smooth", [True] * len(self.faces))
        mesh.update()
        if closed:
            bm = bmesh.new()
            bm.from_mesh(mesh)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(mesh)
            bm.free()
        for material in materials:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = root
        return obj


def _shell(mesh, a, b, r, profile, mat=0, cap_first=False, cap_last=False):
    """Loft a (d, z) profile round an outline: d is how far in from the outline."""
    rings = [_outline(a - d, b - d, max(r - d, 0.3), z) for d, z in profile]
    return mesh.loft(rings, mat, cap_first, cap_last)


def _pill(half_length, radius, n=10):
    """Points round a pill long in Y, as (y, z), anticlockwise seen from +X."""
    radius = max(radius, 0.02)
    c = max(half_length - radius, 0.0)
    pts = [(c + radius * cos(-pi / 2 + pi * i / n), radius * sin(-pi / 2 + pi * i / n)) for i in range(n + 1)]
    pts += [(-c + radius * cos(pi / 2 + pi * i / n), radius * sin(pi / 2 + pi * i / n)) for i in range(n + 1)]
    return pts


def _pad(mesh, surface, side, y, z, length, width, proud, bevel, mat, upright=False):
    """A pill-shaped pad that follows the side of the case and stands `proud` of it."""
    rings = []
    for inset, height in ((0, -0.3), (0, proud - bevel), (0.3 * bevel, proud - 0.3 * bevel),
                          (bevel, proud), (bevel + min(0.3, width / 4), proud)):
        ring = []
        for u, v in _pill(length / 2 - inset, width / 2 - inset):
            py, pz = (y + v, z + u) if upright else (y + u, z + v)
            ring.append((side * (surface(py, pz) + height), py, pz))
        rings.append(ring)
    mesh.loft(rings, mat, cap_first=True, cap_last=True)


def _tooth(u):
    """0 on the ridge of a crown's tooth, 1 in the groove; u runs 0 to 1 across one tooth."""
    return _step(0.3, 0.8, abs(2 * u - 1))


def _crown(mesh, x, y, z, stations, teeth):
    """A crown on the +X side. stations: (distance out, radius, groove depth, material)."""
    per_tooth = 10
    count = teeth * per_tooth
    rings = []
    for out, radius, groove, _ in stations:
        ring = []
        for j in range(count):
            angle = 2 * pi * j / count
            rad = radius - groove * _tooth((j % per_tooth) / per_tooth)
            ring.append((x + out, y + rad * cos(angle), z + rad * sin(angle)))
        rings.append(ring)
    mesh.loft(rings, lambda i: stations[i + 1][3], cap_first=True, cap_last=True)


# ---------------------------------------------------------------------------------------------
# Materials

def _material(name, bevel=None, grain=None, **inputs):
    """A Principled material, shared between watches by name. bevel rounds sharp edges, in mm;
    grain is (size in mm, strength) of a blasted surface."""
    material = bpy.data.materials.get(name)
    if material:
        return material
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    shader.name = "shader"
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for key, value in inputs.items():
        if isinstance(value, tuple) and len(value) == 3:
            value = (*value, 1.0)
        shader.inputs[key].default_value = value
    normal = None
    if bevel:
        node = tree.nodes.new("ShaderNodeBevel")
        node.samples = 6
        node.inputs["Radius"].default_value = bevel * MM
        normal = node.outputs["Normal"]
    if grain:
        size, strength = grain
        coordinates = tree.nodes.new("ShaderNodeTexCoord")
        noise = tree.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 1 / (size * MM)
        noise.inputs["Detail"].default_value = 1.0
        bump = tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        bump.inputs["Distance"].default_value = size * MM * 0.25
        tree.links.new(coordinates.outputs["Object"], noise.inputs["Vector"])
        tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        if normal:
            tree.links.new(normal, bump.inputs["Normal"])
        normal = bump.outputs["Normal"]
    if normal:
        tree.links.new(normal, shader.inputs["Normal"])
    return material


def _metal(name, colour, roughness, bevel=0.12, grain=None, **more):
    return _material(name, bevel=bevel, grain=grain, **{"Base Color": colour, "Metallic": 1.0, "Roughness": roughness, **more})


def _rubber(name, colour, roughness=0.5):
    return _material(name, **{"Base Color": colour, "Roughness": roughness, "Specular IOR Level": 0.4})


def _black(name="watch black", roughness=0.35):
    return _material(name, **{"Base Color": (0.004, 0.004, 0.005), "Roughness": roughness})


def _glass(name, ior):
    return _material(name, **{"Base Color": (1, 1, 1), "Roughness": 0.0, "IOR": ior, "Transmission Weight": 1.0})


def _screen_material(name):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    tree = material.node_tree
    tree.nodes.clear()
    output = tree.nodes.new("ShaderNodeOutputMaterial")
    shader = tree.nodes.new("ShaderNodeBsdfPrincipled")
    image = tree.nodes.new("ShaderNodeTexImage")
    image.name = image.label = "screen"
    image.interpolation = "Cubic"
    image.extension = "CLIP"
    brightness = tree.nodes.new("ShaderNodeValue")
    brightness.name = brightness.label = "brightness"
    brightness.outputs[0].default_value = 1.5
    shader.inputs["Base Color"].default_value = (0.002, 0.002, 0.002, 1)
    shader.inputs["Roughness"].default_value = 0.25
    tree.links.new(image.outputs["Color"], shader.inputs["Emission Color"])
    tree.links.new(brightness.outputs[0], shader.inputs["Emission Strength"])
    tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


# ---------------------------------------------------------------------------------------------
# Parts shared by the three watches

def _display(root, size, radius, z):
    width, height = size
    pts = _outline(width / 2, height / 2, radius, z, n=48)
    mesh = bpy.data.meshes.new(f"{root.name}.display")
    mesh.from_pydata([(x * MM, y * MM, z * MM) for x, y, z in pts], [], [tuple(range(len(pts)))])
    uv = mesh.uv_layers.new(name="screen")
    for loop in mesh.loops:
        x, y, _ = pts[loop.vertex_index]
        uv.data[loop.index].uv = (x / width + 0.5, y / height + 0.5)
    mesh.materials.append(_screen_material(f"{root.name}.screen"))
    obj = bpy.data.objects.new(mesh.name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    return obj


def _band(root, material, lug_y, lug_z, wrist, width, thickness, edge, rib=None, taper=None):
    """A strap that leaves the case at both ends and closes into a loop round a wrist.

    wrist is the loop's half-width and the height of its lowest point; lug_z is the strap's inner
    face at the case.
    rib is (pitch, height, start): ridges across the strap. taper is (width, distance).
    """
    half_w, bottom = wrist
    start = asin(lug_y / half_w)
    half_d = (lug_z - bottom) / (1 + cos(start))
    centre_z = bottom + half_d
    root["loop"] = (half_w * MM, half_d * MM, centre_z * MM)
    dense = []
    samples = 3000
    for i in range(samples + 1):
        angle = start + (2 * pi - 2 * start) * i / samples
        dense.append(Vector((half_w * sin(angle), centre_z + half_d * cos(angle))))
    into_case = 3.0
    lead_in = (dense[0] - dense[1]).normalized()
    lead_out = (dense[-1] - dense[-2]).normalized()
    dense = [dense[0] + lead_in * into_case] + dense + [dense[-1] + lead_out * into_case]

    lengths = [0.0]
    for p, q in zip(dense, dense[1:]):
        lengths.append(lengths[-1] + (q - p).length)
    total = lengths[-1]
    spacing = 0.35
    stations = round(total / spacing)
    path, index = [], 0
    for s in range(stations + 1):
        at = total * s / stations
        while index < len(lengths) - 2 and lengths[index + 1] < at:
            index += 1
        f = (at - lengths[index]) / max(lengths[index + 1] - lengths[index], 1e-9)
        path.append((at, dense[index].lerp(dense[index + 1], f)))

    rings = []
    corner = 5
    for s, (at, p) in enumerate(path):
        before, after = path[max(s - 1, 0)][1], path[min(s + 1, stations)][1]
        tangent = (after - before).normalized()
        normal = Vector((-tangent.y, tangent.x))        # away from the wrist
        from_end = min(at, total - at) - into_case
        thick, half = thickness, width / 2
        if taper:
            half = (width + (taper[0] - width) * _step(0, taper[1], from_end)) / 2
        if rib:
            pitch, height, begin = rib
            if from_end > begin:
                u = ((from_end - begin) % pitch) / pitch - 0.5
                thick += height * _step(0, 1.5, from_end - begin) * max(1 - (u / 0.44) ** 2, 0.0) ** 0.5
        c = min(edge, thick / 2 - 0.01)
        section = [(-half + c + (2 * half - 2 * c) * i / 6, 0.0) for i in range(7)]
        section += [(half - c + c * sin(pi / 2 * i / corner), c - c * cos(pi / 2 * i / corner)) for i in range(1, corner + 1)]
        section += [(half - c + c * cos(pi / 2 * i / corner), thick - c + c * sin(pi / 2 * i / corner)) for i in range(corner + 1)]
        section += [(half - c - (2 * half - 2 * c) * i / 6, thick) for i in range(1, 7)]
        section += [(-half + c - c * sin(pi / 2 * i / corner), thick - c + c * cos(pi / 2 * i / corner)) for i in range(1, corner + 1)]
        section += [(-half + c - c * cos(pi / 2 * i / corner), c - c * sin(pi / 2 * i / corner)) for i in range(corner)]
        rings.append([(x, p.x + normal.x * h, p.y + normal.y * h) for x, h in section])
    mesh = _Mesh()
    mesh.loft(rings, cap_first=True, cap_last=True)
    return mesh.object(f"{root.name}.band", [material], root, closed=True)


# ---------------------------------------------------------------------------------------------
# Apple Watch Ultra

def _ultra(root, band_colour):
    a, b, r = 20.85, 24.5, 13.0           # the case is 41.7 x 49 mm, 44 mm across the crown guard
    rim = 2.79                            # metal seen from the front, between the case's edge and the glass
    glass_depth = 1.2
    profile = _round([
        (15.0, -12.0), (8.0, -12.0, 3.0), (1.6, -10.7, 0.6), (0.0, -9.7, 1.2),
        (0.0, -1.1, 1.3),                 # the side wall, rounding over into the shoulder
        (1.3, -1.0, 0.15), (1.4, -0.14, 0.04),   # the step up to the raised rim
        (1.58, 0.05, 0.05), (rim - 0.05, 0.05, 0.04),
        (rim - 0.01, 0.0, 0.0), (rim - 0.01, -glass_depth - 0.1), (rim + 1.5, -glass_depth - 0.1),
    ])
    titanium = _metal("ultra titanium", (0.56, 0.52, 0.47), 0.4, grain=(0.13, 0.45))
    polished = _metal("ultra titanium polished", (0.62, 0.58, 0.53), 0.12)
    rim_metal = _metal("ultra titanium rim", (0.6, 0.56, 0.51), 0.3)
    ceramic = _black("watch back", 0.1)

    def body_material(i):
        d, z = profile[i + 1]
        d0, z0 = profile[i]
        if z < -10.6 and d > 1.5:
            return 3
        if d0 >= 1.39 and d <= 1.6 and z > -0.2:
            return 1
        if d > 1.55 and z > 0.0:
            return 2
        return 0

    body = _Mesh()
    _shell(body, a, b, r, profile, body_material, cap_first=True, cap_last=True)

    def wall(y, z):
        d = _inset_at(profile, z)
        return _edge_x(a - d, b - d, r - d, y)

    crown_y, crown_z = 6.25, -5.45
    guard_height = 2.0

    def guard(y, z):
        along = 1 - _step(10.6, 14.2, abs(y))
        across = _step(-10.5, -9.4, z) * (1 - _step(-2.7, -1.15, z))
        slot = _step(3.95, 4.75, abs(y - crown_y))
        return guard_height * along * across * slot

    rows = []
    for i in range(125):
        y = -15.0 + 30.0 * i / 124
        rows.append([(wall(y, z) + guard(y, z) - 0.03, y, z) for z in (-10.8 + 9.75 * j / 60 for j in range(61))])
    body.grid(rows, 0)
    body.object(f"{root.name}.body", [titanium, polished, rim_metal, ceramic], root)

    details = _Mesh()
    orange = _material("ultra orange", **{"Base Color": ORANGE, "Roughness": 0.5, "Specular IOR Level": 0.25})
    gap = _black()
    _crown(details, a - 0.6, crown_y, crown_z, [
        (0.0, 2.7, 0, 0), (0.95, 2.7, 0, 0), (1.0, 3.35, 0, 0), (1.15, 3.7, 0.2, 0),
        (1.3, 3.8, 0.5, 0), (2.55, 3.8, 0.5, 0), (2.75, 3.68, 0.25, 0), (2.88, 3.4, 0.0, 0),
        (2.9, 3.15, 0, 0), (2.86, 3.1, 0, 1), (2.86, 2.55, 0, 1), (2.9, 2.5, 0, 0),
        (2.98, 2.3, 0, 0), (3.0, 0.4, 0, 0),
    ], teeth=22)

    def guard_face(y, z):
        return wall(y, z) + guard(y, z)

    _pad(details, guard_face, 1, -7.1, crown_z, 10.1, 3.7, 0.03, 0.02, 2)      # the gap round the side button
    _pad(details, guard_face, 1, -7.1, crown_z, 9.5, 3.1, 0.2, 0.07, 0)
    _pad(details, wall, -1, -4.0, crown_z, 13.5, 3.8, 0.03, 0.02, 2)
    _pad(details, wall, -1, -4.0, crown_z, 13.0, 3.3, 0.55, 0.3, 1)           # the Action button
    for i in (-1, 0, 1):
        _pad(details, wall, -1, 8.5 + 1.6 * i, crown_z, 4.4, 0.95, 0.02, 0.01, 2, upright=True)   # speaker
    details.object(f"{root.name}.details", [titanium, orange, gap], root, closed=True)

    glass = _Mesh()
    _shell(glass, a, b, r, _round([
        (rim + 0.01, -glass_depth), (rim + 0.01, -0.12, 0.03), (rim + 0.2, 0.0, 0.05), (rim + 1.2, 0.0),
    ]), cap_last=True)
    glass.object(f"{root.name}.glass", [_glass("watch sapphire", 1.77)], root)

    mask = _Mesh()
    mask.cap(mask.ring(_outline(a - rim, b - rim, r - rim, -glass_depth)))
    mask.object(f"{root.name}.mask", [_black("watch mask", 0.3)], root)
    _display(root, (33.2, 40.45), 9.1, -glass_depth + 0.004)

    root["case"] = (a * MM, b * MM, 12.0 * MM, (a + 2.4) * MM)
    band = _rubber("ultra band", band_colour or (0.012, 0.013, 0.016))
    _band(root, band, lug_y=b - 2.0, lug_z=-6.6, wrist=(30.0, -53.2), width=23.4, thickness=1.9,
          edge=0.9, rib=(4.7, 1.25, 5.0))


# ---------------------------------------------------------------------------------------------
# Apple Watch Series 12 and SE 3: a rounded case with glass that curves down into it

ROUND = {
    "series": dict(
        a=19.9, b=23.0, r=11.9, depth=9.7, joint=(1.07, -1.9), dome=(2.3, 4.05),
        side=[(0.0, -7.4, 3.2), (0.0, -3.55, 4.0)], back=[(12.0, -9.7), (7.0, -9.7, 4.0), (2.2, -8.6, 1.0)],
        mask=(2.0, -1.15, 1.0), screen=(33.3, 39.7), screen_r=8.6,
        crown=dict(y=8.4, z=-5.5, teeth=44, stations=[
            (0.0, 3.25, 0, 0), (0.75, 3.25, 0, 0), (0.85, 3.05, 0, 0), (0.9, 3.0, 0.1, 0), (2.0, 3.0, 0.1, 0),
            (2.15, 2.9, 0.04, 0), (2.25, 2.7, 0, 0), (2.3, 2.3, 0, 0), (2.27, 2.25, 0, 2), (2.27, 2.0, 0, 2),
            (2.32, 1.95, 0, 0), (2.36, 0.3, 0, 0)]),
        button=dict(y=-7.3, z=-5.5, length=9.0, width=2.3, proud=0.1),
        band=dict(lug_z=-7.9, wrist=(29.0, -49.0), width=24.0, thickness=2.4, edge=1.1, taper=(21.5, 14.0)),
    ),
    "se": dict(
        a=19.0, b=22.0, r=10.2, depth=10.7, joint=(1.45, -1.75), dome=(2.6, 3.0),
        side=[(0.0, -8.0, 3.2), (0.0, -4.0, 3.2)], back=[(11.0, -10.7), (6.5, -10.7, 4.0), (2.0, -9.4, 1.0)],
        mask=(2.4, -1.1, 0.9), screen=(28.67, 34.9), screen_r=5.6,
        crown=dict(y=8.0, z=-5.9, teeth=40, stations=[
            (0.0, 3.4, 0, 0), (0.7, 3.4, 0, 0), (0.8, 3.25, 0, 0), (0.85, 3.2, 0.1, 0), (2.1, 3.2, 0.1, 0),
            (2.25, 3.1, 0.04, 0), (2.35, 2.9, 0, 0), (2.4, 2.6, 0, 0), (2.37, 2.55, 0, 2), (2.37, 2.3, 0, 2),
            (2.42, 2.25, 0, 0), (2.46, 0.3, 0, 0)]),
        button=dict(y=-7.0, z=-5.9, length=9.5, width=2.5, proud=0.1),
        band=dict(lug_z=-8.6, wrist=(28.0, -48.9), width=22.5, thickness=2.4, edge=1.1, taper=(20.0, 14.0)),
    ),
}


def _rounded(root, kind, band_colour):
    spec = ROUND[kind]
    a, b, r = spec["a"], spec["b"], spec["r"]
    joint_d, joint_z = spec["joint"]
    profile = _round(spec["back"] + spec["side"] + [
        (joint_d, joint_z), (joint_d + 0.03, joint_z - 0.06), (joint_d + 0.03, joint_z - 0.9),
        (joint_d + 2.0, joint_z - 0.9),
    ], n=12)
    if kind == "series":
        metal = _material("series jet black", bevel=0.08, **{
            "Base Color": (0.006, 0.006, 0.007), "Metallic": 0.85, "Roughness": 0.05,
            "Coat Weight": 1.0, "Coat Roughness": 0.02})
        strap = _rubber("series band", band_colour or (0.008, 0.008, 0.009), 0.45)
    else:
        metal = _metal("se starlight", (0.78, 0.71, 0.61), 0.33, bevel=0.08, grain=(0.07, 0.25))
        strap = _rubber("se band", band_colour or (0.66, 0.58, 0.46), 0.5)
    ceramic = _black("watch back", 0.1)
    back_top = spec["back"][-1][1]

    body = _Mesh()
    _shell(body, a, b, r, profile, lambda i: 1 if profile[i + 1][1] <= back_top and profile[i + 1][0] > 1.5 else 0,
           cap_first=True, cap_last=True)
    body.object(f"{root.name}.body", [metal, ceramic], root)

    def wall(y, z):
        d = _inset_at(profile, z)
        return _edge_x(a - d, b - d, r - d, y)

    details = _Mesh()
    crown, button = spec["crown"], spec["button"]
    _crown(details, wall(crown["y"], crown["z"]) - 0.75, crown["y"], crown["z"], crown["stations"], crown["teeth"])
    _pad(details, wall, 1, button["y"], button["z"], button["length"] + 0.3, button["width"] + 0.3, 0.02, 0.01, 1)
    _pad(details, wall, 1, button["y"], button["z"], button["length"], button["width"], button["proud"], 0.06, 0)
    _pad(details, wall, 1, 0.6, crown["z"], 0.7, 0.7, 0.015, 0.01, 1)                     # microphone
    for y in (-5.5, 5.5):
        _pad(details, wall, -1, y, crown["z"], 7.5, 0.7, 0.015, 0.01, 1)                  # speaker
    details.object(f"{root.name}.details", [metal, _black(), _black("watch crown ring", 0.2)], root, closed=True)

    dome_d, dome_r = spec["dome"]
    glass = _Mesh()
    _shell(glass, a, b, r, _round([(joint_d + 0.02, joint_z), (dome_d, 0.0, dome_r), (dome_d + 4.5, 0.0)], n=24),
           cap_last=True)
    glass.object(f"{root.name}.glass", [_glass("watch glass", 1.52)], root)

    mask_d, mask_z, mask_r = spec["mask"]
    mask = _Mesh()
    _shell(mask, a, b, r, _round([(joint_d + 0.04, joint_z - 0.07), (mask_d, mask_z, mask_r), (mask_d + 4.0, mask_z)], n=10),
           cap_last=True)
    mask.object(f"{root.name}.mask", [_black("watch mask", 0.3)], root)
    _display(root, spec["screen"], spec["screen_r"], mask_z + 0.004)
    root["case"] = (a * MM, b * MM, spec["depth"] * MM, (wall(crown["y"], crown["z"]) + 1.65) * MM)
    _band(root, strap, lug_y=b - 2.0, **spec["band"])


# ---------------------------------------------------------------------------------------------

def build(kind, name=None, band_colour=None):
    """Build an "ultra", "series" or "se" watch and return its root."""
    root = bpy.data.objects.new(name or kind, None)
    root.empty_display_size = 0.01
    bpy.context.collection.objects.link(root)
    root["kind"] = kind
    if kind == "ultra":
        _ultra(root, band_colour)
    else:
        _rounded(root, kind, band_colour)
    return root


def part(root, which):
    """A part of a built watch: "display", "glass", "mask", "body", "details" or "band"."""
    return bpy.data.objects[f"{root.name}.{which}"]


def set_screen(root, image=None, brightness=None):
    """Put a picture (a path or a bpy image) on the watch's screen, and set how bright it is."""
    nodes = part(root, "display").active_material.node_tree.nodes
    if image is not None:
        nodes["screen"].image = bpy.data.images.load(image, check_existing=True) if isinstance(image, str) else image
    if brightness is not None:
        nodes["brightness"].outputs[0].default_value = brightness
