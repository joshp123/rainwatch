# Written by AI on 2026.11.18 by model claude fable 5.2.
"""Renders the launch film's shots.
  blender -b --python film.py -- --gen <folder> --out <folder> --language en --shot street [--frames 224 300] [--still 250 ...] [--draft] [--unnamed]
A shot's frames go to <out>/<shot>/<frame>.png. The cut is in SHOTS; ../README.md has the rest.
"""
import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common  # noqa: E402
from common import BEAT, BLUE, ease, lerp, light_only, look, ramp, spline, text  # noqa: E402
from world import MINUTE, World  # noqa: E402
from wrist import STREET, Rain, Tile, Wrist  # noqa: E402

BAR = 4 * BEAT
# The cut, in frames at 30 a second, on the music's bars (15 bars of 56 frames). Every join is a cut.
SHOTS = {
    "glance": (0, 196),             # a wrist turns, the screen wakes; the circle lifts off the face and the line runs out along the street to the rain
    "street": (196, 7 * BAR),       # down on the street: now on the left, the rain coming in from the right, the circle counting
    "rain": (7 * BAR, 11 * BAR),    # back at the wrist: it arrives; the circle goes home; the three widgets lift off and turn
    "se": (616, 644),               # the app on an SE 3
    "series": (644, 12 * BAR),      # and on a Series 12
    "end": (12 * BAR, 15 * BAR),    # what each rain app puts in the slot; the name
}
END = 12 * BAR
SAME_FROM = 800  # from here to the end, the cut that names no other app is the named cut's frames
COUNT_FROM = 3 * BAR
WIDGETS = 532    # the three widgets lift off the face
ARRIVES = 8 * BAR
FRAMES_A_MINUTE = 2 * BEAT


def minute_of(frame):
    """The film's clock, in minutes from its first minute (07:40). Ten minutes pass between the line
    running out and the rain arriving, and three more at that pace. It waits at 07:53 while the widgets
    are in the air; the other two watches show their own screenshots' minutes (07:53 to 07:55); and it
    runs again from 07:55 at the end."""
    if frame >= END:
        return 15 + (frame - END) / FRAMES_A_MINUTE
    return min(max(0, frame - COUNT_FROM), WIDGETS - COUNT_FROM) / FRAMES_A_MINUTE


def face_index(frame):
    """Which of the minute-by-minute pictures of the app shows at this frame (the film opens on the second)."""
    return int(math.floor(minute_of(frame) + 1e-6)) + 1


# ---- the wrist ----

CIRCLE = (105.5, 216.5)     # the circle's centre on the Ultra's face, in the screenshot's points (export/)
WIDE = (106.5, 148.5)       # the wide slot's centre, and its size as the face shrinks it
WIDE_SIZE = (190 * 0.884, 73.5 * 0.884)
STACK_SIZE = (198, 81.5)    # the Smart Stack card
LOWERED = (-58, 0.035)      # the wrist turned away: degrees, and how far it hangs lower
RAISED = 9                  # the wrist turned to the wearer, in degrees
STREET_SCALE = 4.0          # metres to one of the street's units, seen from the wrist: the rain walks two metres a minute
STREET_ORIGIN = (0, 0.5, STREET)
TILE_DEPTH = 0.11           # how far before the camera the tiles turn: one plane, so one focus holds them all

GLANCE = (Vector((0.014, -0.118, 0.176)), Vector((0, 0.004, 0)))
HERO = (Vector((0.012, -0.100, 0.146)), Vector((0, 0.002, 0)))
# The wearer's view over the wrist and down the street.
OVER = (Vector((0.010, -0.120, 0.085)), Vector((0.0, 0.88, -0.165)))
OVER_LENS = 46


def wrist_matrix(degrees, drop=0.0):
    """Where the watch is when the wrist is rolled about the forearm's own axis."""
    axis = Vector((0, 0, -0.028))
    turn = Matrix.Rotation(math.radians(degrees), 4, "X")
    return Matrix.Translation(axis - turn @ axis + Vector((0, 0, -drop))) @ turn


def turn_wrist(wrist, keys):
    """Key the wrist's roll: (frame, degrees towards the wearer, drop in metres)."""
    for frame, degrees, drop in keys:
        matrix = wrist_matrix(degrees, drop)
        wrist.arm.rotation_euler = matrix.to_euler()
        wrist.arm.location = matrix.to_translation()
        wrist.arm.keyframe_insert("rotation_euler", frame=frame)
        wrist.arm.keyframe_insert("location", frame=frame)


def screens(wrist, args, folder_of=lambda frame: "face", brightness=lambda frame: 2.6):
    """Put the app's picture for each frame's minute on the watch: folder_of says which set."""
    def update(scene, *_):
        frame = scene.frame_current
        path = f"{args.gen}/{args.language}/{folder_of(frame)}/{face_index(frame):02d}.png"
        if os.path.exists(path):
            wrist.show(path, brightness(frame))
    bpy.app.handlers.frame_change_pre.append(update)


def pose(location, target):
    """A camera pose as (location, rotation, forward, right, up)."""
    turn = look(location, target)
    return location, turn, turn @ Vector((0, 0, -1)), turn @ Vector((1, 0, 0)), turn @ Vector((0, 1, 0))


def in_view(view, depth, across, up):
    """A place in front of a camera pose: metres ahead, to the right and up."""
    location, _, forward, right, above = view
    return location + forward * depth + right * across + above * up


def tiles(wrist, args, index, rest=Matrix.Identity(4)):
    """The three complications as tiles, resting where the face has them."""
    point = wrist.width / 211
    gen = f"{args.gen}/{args.language}"

    def tile(name, size, corner, slot, margin=0.0):
        made = Tile(wrist.scene, name, f"{gen}/{name}/{index:02d}.png", (size[0] * point, size[1] * point), corner and corner * point,
                    (0, 0, 0), margin=margin * point)
        made.slot = rest @ Vector((slot.x, slot.y, made.slot.z))
        made.flat = rest.to_quaternion()
        return made
    return (tile("circle", (45, 45), None, wrist.point(*CIRCLE)), tile("wide", WIDE_SIZE, 12, wrist.point(*WIDE), margin=8),
            tile("stack", STACK_SIZE, 20, wrist.point(105.5, 232)))


def counting(tile, args, name="circle"):
    """Keep a tile's picture on the film's minute."""
    def update(scene, *_):
        tile.show(f"{args.gen}/{args.language}/{name}/{face_index(scene.frame_current):02d}.png")
    bpy.app.handlers.frame_change_pre.append(update)


class Keys:
    """Keys a tile's flight, keeping each turn on the short way round from the last."""

    def __init__(self, tile):
        self.tile, self.previous = tile, tile.flat.copy()

    def key(self, frame, location, turn, scale=1.0):
        turn = turn.copy()
        if turn.dot(self.previous) < 0:
            turn.negate()
        self.previous = turn
        self.tile.key(frame, location, turn, scale)


def fly(tile, start, lifted, facing, grown, lift=18, spin=30, hold=2, drop=16, scale_from=1.0):
    """Key a tile out of its slot towards the camera, growing as it comes, round once, and back."""
    tile.shown = (start, start + lift + spin + hold + drop)
    keys = Keys(tile)
    keys.key(start - 1, tile.slot, tile.flat, scale_from)
    keys.key(start, tile.slot, tile.flat, scale_from)
    keys.key(start + lift, lifted, facing, grown)
    for quarter in range(1, 5):
        keys.key(start + lift + spin * quarter / 4, lifted, facing @ Quaternion((0, 1, 0), quarter * math.pi / 2), grown)
    keys.key(start + lift + spin + hold, lifted, facing @ Quaternion((0, 1, 0), 2 * math.pi), grown)
    keys.key(start + lift + spin + hold + drop, tile.slot, tile.flat, scale_from)


def over_wrist():
    """Where the circle hangs, enlarged, before the wearer's eyes while the rain comes: (place, turn, scale)."""
    view = pose(*OVER)
    return in_view(view, 0.08, 0.0, -0.002), view[1], 4.4


def street_from_wrist(scene, args, extent_of=lambda frame: 1.0):
    """The street as the wearer sees it: the line runs from their feet, and its rain is real size far
    off; near the wrist the rain is the wrist's own."""
    return World(scene, args.gen, args.language, minute_of, ARRIVES, extent_of=extent_of, scale=STREET_SCALE,
                 origin=STREET_ORIGIN, ground=False, near=3.0, from_now=True)


def build_glance(scene, args):
    """A wrist turns the watch to the wearer and the screen wakes. The circle lifts off the face and
    hangs before the eyes; beyond it the rain line runs out along the street to the rain, which is
    already walking in."""
    wrist = Wrist(scene, "ultra")
    wrist.street()
    street_from_wrist(scene, args, extent_of=lambda frame: ramp(frame, 96, 140) ** 1.6)
    turn_wrist(wrist, [(-2, *LOWERED), (4, -55, 0.033), (28, 7, 0.0), (86, RAISED, 0.0), (200, RAISED, 0.0)])
    lift = 86
    screens(wrist, args, folder_of=lambda frame: "face" if frame < lift else "face-no-circle",
            brightness=lambda frame: lerp(0.12, 2.6, ramp(frame, 14, 24)))
    circle = tiles(wrist, args, 1, wrist_matrix(RAISED))[0]
    place, facing, grown = over_wrist()
    circle.shown = (lift, 10 ** 6)
    keys = Keys(circle)
    keys.key(lift - 1, circle.slot, circle.flat)
    keys.key(lift, circle.slot, circle.flat)
    keys.key(lift + 28, place, facing, grown)
    counting(circle, args)

    def lamps(scene_, *_):
        # The lamps round the wearer's feet go out of view as the eyes come up to the street.
        wrist.dim(1 - ramp(scene_.frame_current, 88, 118))
    bpy.app.handlers.frame_change_pre.append(lamps)

    def path(frame):
        location = spline([(0, GLANCE[0]), (84, Vector((0.008, -0.088, 0.128))), (136, OVER[0]), (196, OVER[0] + Vector((-0.004, 0.008, -0.003)))], frame)
        up = ramp(frame, 84, 136)
        target = Vector((0, 0.002, 0)).lerp(OVER[1], up)
        # The watch is sharp from the first frame, lowered and asleep, which is also where the film's loop ends.
        watch = (wrist_matrix(*LOWERED).to_translation().lerp(Vector((0, 0, 0)), ramp(frame, 0, 28)) - location).length
        focus = lerp(watch, (place - location).length, ramp(frame, 90, 118))
        return location, target, lerp(70, OVER_LENS, up), focus, lerp(5.6, 36, ramp(frame, 90, 128))
    return common.camera(scene), path


def build_street(scene, args):
    """Down on the street beside now: the line runs from the left foreground away to the right, and
    the rain comes in along it, towering as it nears. The camera stays where it is, so the rain is
    seen to come. The circle hangs before the lens as it hung before the eyes, counting."""
    World(scene, args.gen, args.language, minute_of, ARRIVES, label_turn=math.radians(32))
    first, last = SHOTS["street"]
    sign = Tile(scene, "sign", f"{args.gen}/{args.language}/circle/{face_index(first):02d}.png", (2, 2), None, (0, 0, 0), thickness=0.05)
    sign.shown = (-1, 10 ** 6)
    counting(sign, args)

    def path(frame):
        t = ease((frame - first) / (last - first))
        location = Vector((3.6, -1.3, 0.7)).lerp(Vector((3.1, -1.0, 0.6)), t)
        target = Vector((-0.6, 3.8, 3.3)).lerp(Vector((-0.6, 3.4, 3.6)), t)
        return location, target, 21, 4.2, 2.0

    def hang(scene_, *_):
        location, target = path(scene_.frame_current)[:2]
        view = pose(location, target)
        sign.holder.location = in_view(view, 3.0, -0.85, 1.35)
        # Turned a little from the lens, so its edge and its face take the light as a thing in the street does.
        sign.holder.rotation_quaternion = view[1] @ Quaternion((0, 1, 0), 0.22)
        sign.holder.scale = (0.92, 0.92, 0.92)
    bpy.app.handlers.frame_change_pre.append(hang)
    return common.camera(scene), path


def build_rain(scene, args):
    """Back at the wrist as the rain comes in over the street and arrives: the first drops land on the
    glass and the circle turns to how long it lasts. It drops home; then the three widgets lift off
    the face as glass, turn once before the camera and drop back."""
    wrist = Wrist(scene, "ultra")
    wrist.street()
    home, level = 496, 530
    # Once the eyes are back down on the watch the street is out of the picture.
    street_from_wrist(scene, args).hidden_from = level
    Rain(scene, wrist, ARRIVES)
    turn_wrist(wrist, [(380, RAISED, 0.0), (home, RAISED, 0.0), (level, 0, 0.0)])
    circle = tiles(wrist, args, face_index(392), wrist_matrix(RAISED))[0]
    place, facing, grown = over_wrist()
    circle.shown = (0, home)
    keys = Keys(circle)
    keys.key(380, place, facing, grown)
    keys.key(home - 20, place, facing, grown)
    keys.key(home, circle.slot, circle.flat)
    counting(circle, args)

    # The three widgets, with the wrist level again.
    three = tiles(wrist, args, face_index(540))
    drift = Vector((0.004, -0.106, 0.151))
    view = pose(HERO[0].lerp(drift, 0.5), HERO[1])
    lifts, lands = WIDGETS, WIDGETS + 72
    timing = dict(lift=16, spin=28, hold=2, drop=14)
    fly(three[0], lifts, in_view(view, TILE_DEPTH, 0.0, 0.0), view[1], 3.4, **timing)
    fly(three[1], lifts + 5, in_view(view, TILE_DEPTH, 0.0, 0.030), view[1], 1.6, **timing)
    # The Smart Stack's card is not on the face: it comes up from under the face's lower edge.
    fly(three[2], lifts + 10, in_view(view, TILE_DEPTH, 0.0, -0.030), view[1], 1.6, scale_from=0.001, **timing)
    for tile, name in zip(three, ("circle", "wide", "stack")):
        # From the first lift to the last landing the face's slots are empty and the tiles are the widgets.
        tile.shown = (lifts, lands)
        counting(tile, args, name)
    screens(wrist, args, folder_of=lambda frame: "face-no-circle" if frame < home else "face-empty" if lifts <= frame <= lands else "face")

    def lamps(scene_, *_):
        wrist.dim(ramp(scene_.frame_current, home, level))
    bpy.app.handlers.frame_change_pre.append(lamps)
    over = OVER[0] + Vector((-0.016, -0.002, -0.004))

    def path(frame):
        location = spline([(392, over), (448, over + Vector((0.004, 0.008, -0.002))), (home - 20, over + Vector((0.006, 0.010, -0.002))),
                           (level + 4, HERO[0]), (616, drift)], frame)
        down = ramp(frame, home - 20, level)
        target = OVER[1].lerp(HERO[1], down)
        near = ramp(frame, lifts + 2, lifts + 16) * (1 - ramp(frame, lands - 20, lands - 2))
        watch = (target - location).length if frame > home else (Vector((0, 0, 0)) - location).length
        focus = lerp((place - location).length, watch, ramp(frame, home - 24, home))
        return location, target, lerp(OVER_LENS, 70, down), lerp(focus, TILE_DEPTH, near), lerp(36, 5.6, ramp(frame, home - 16, level - 8))
    return common.camera(scene), path


def build_other(kind):
    def build(scene, args):
        """The same complications on another Apple Watch, in the rain."""
        wrist = Wrist(scene, kind)
        wrist.street(seed=3 if kind == "series" else 5)
        Rain(scene, wrist, ARRIVES, seed=8 if kind == "series" else 9)
        wrist.show(f"{args.gen}/{args.language}/face-{kind}/shown.png", 2.6)
        first = SHOTS[kind][0]
        if kind == "series":
            start, end = Vector((0.07, -0.085, 0.085)), Vector((0.045, -0.085, 0.105))
        else:
            start, end = Vector((-0.06, -0.07, 0.125)), Vector((-0.035, -0.08, 0.125))

        def path(frame):
            t = (frame - first) / 28
            location = start.lerp(end, t)
            target = Vector((0, 0.002, 0))
            return location, target, 70, (target - location).length, 4.5
        return common.camera(scene), path
    return build


def build_end(scene, args):
    """What each rain app puts in the circle's slot, the name, and the wrist lowering to where the film began."""
    wrist = Wrist(scene, "ultra")
    wrist.street()
    Rain(scene, wrist, ARRIVES)
    turn_wrist(wrist, [(660, 0, 0), (822, 0, 0), (841, *LOWERED)])
    words = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "words.json")))[args.language]
    fonts = f"{args.gen}/fonts/SFCompactRounded-"
    bold, semibold = bpy.data.fonts.load(fonts + "Bold.ttf"), bpy.data.fonts.load(fonts + "Semibold.ttf")
    white, grey, blue = light_only("name", (1, 1, 1), 3.0), light_only("other names", (0.8, 0.8, 0.8), 2.6), light_only("promise", BLUE, 2.6)
    point = wrist.width / 211
    last = (Vector((0.010, -0.102, 0.150)), Vector((0, 0.014, 0)))
    close = (Vector((0.016, -0.106, 0.152)), Vector((0, 0.006, 0)))
    asleep = lambda frame: ramp(frame, 830, 839)  # noqa: E731
    leave = 764  # the rows have been readable for nearly three seconds

    def words_at(name, body, font, size, mat, where, turn, align="LEFT"):
        o = text(name, body, font, size, mat, extrude=size * 0.02, align=align)
        o.rotation_mode = "QUATERNION"
        o.location, o.rotation_quaternion = where, turn
        return o

    def appear(o, start, end=None, fall=None):
        """Key an object in over 12 frames, and out again by falling away."""
        for frame, scale in ((start - 1, 0.001), (start + 8, 1.06), (start + 13, 1.0)):
            o.scale = (scale, scale, scale)
            o.keyframe_insert("scale", frame=frame)
        if end:
            o.keyframe_insert("location", frame=end)
            o.keyframe_insert("scale", frame=end)
            o.location = Vector(o.location) + fall
            o.scale = (0.001, 0.001, 0.001)
            o.keyframe_insert("location", frame=end + 20)
            o.keyframe_insert("scale", frame=end + 20)

    named = not args.unnamed
    if named:
        # Three rows in one plane before the camera: the slot's disc, enlarged, and the app's name.
        view = pose(close[0].lerp(last[0], 0.35), close[1])
        rows = (0.027, 0.0, -0.027)
        ours = tiles(wrist, args, face_index(END))[0]
        ours.shown = (END, leave + 22)
        fly_to = in_view(view, TILE_DEPTH, -0.0155, rows[0])
        keys = Keys(ours)
        keys.key(END - 1, ours.slot, ours.flat)
        keys.key(END, ours.slot, ours.flat)
        keys.key(END + 12, fly_to, view[1], 2.8)
        keys.key(leave, fly_to, view[1], 2.8)
        keys.key(leave + 22, ours.slot, ours.flat)
        counting(ours, args)
        appear(words_at("our name", words["name"], semibold, 0.0056, white, in_view(view, TILE_DEPTH, -0.003, rows[0] - 0.002), view[1]),
               END + 5, leave, view[4] * -0.02)
        fall = view[4] * -0.09
        others = []
        for row, (name, picture) in enumerate(zip(words["others"], ("other-button.png", "other-empty.png"))):
            other = Tile(scene, f"other {row}", f"{args.gen}/{picture}", (45 * point, 45 * point), None, (0, 0, 0))
            other.shown = (END, SAME_FROM - 2)
            others.append(other)
            where = in_view(view, TILE_DEPTH, -0.0155, rows[row + 1])
            other.key(END - 1, where + view[3] * 0.05, view[1], 2.6)
            other.key(END + 2 + 4 * row, where + view[3] * 0.05, view[1], 2.6)
            other.key(END + 14 + 4 * row, where, view[1], 2.6)
            other.key(leave + 3 * row, where, view[1], 2.6)
            other.key(leave + 22 + 3 * row, where + fall, view[1] @ Quaternion((1, 0, 0), 1.2), 2.0)
            appear(words_at(f"other name {row}", name, semibold, 0.0056, grey, in_view(view, TILE_DEPTH, -0.003, rows[row + 1] - 0.002), view[1]),
                   END + 9 + 4 * row, leave + 3 * row, fall)
        # The lamp that lights the case's edge is turned down while the rows are up: out of focus, that
        # edge is a bright patch behind the middle name.
        lamp = bpy.data.objects["lamp right"].data
        for frame, power in ((END - 1, 1.0), (leave, 1.0), (leave + 22, 9.0)):
            lamp.energy = power
            lamp.keyframe_insert("energy", frame=frame)
        # The watch behind the rows is dim while they are up, and wakes as ours flies home.
        screens(wrist, args, folder_of=lambda frame: "face-no-circle" if frame < leave + 22 else "face",
                brightness=lambda frame: lerp(lerp(0.5, 2.6, ramp(frame, leave, leave + 22)), 0.12, asleep(frame)))
    else:
        screens(wrist, args, brightness=lambda frame: lerp(2.6, 0.12, asleep(frame)))

    # The name stands in the watch's own plane, so one focus holds both.
    end_view = pose(*last)
    depth = (last[1] - last[0]).length
    appear(words_at("title", words["name"], bold, 0.0128, white, in_view(end_view, depth, 0, 0.052), end_view[1], align="CENTER"), 770)
    appear(words_at("promise", words["promise"], semibold, 0.0085, blue, in_view(end_view, depth, 0, 0.0355), end_view[1], align="CENTER"), 778)
    centre = wrist.point(*CIRCLE)

    def with_names(frame):
        location = spline([(END, close[0]), (leave, close[0].lerp(last[0], 0.6)), (leave + 34, last[0]), (840, last[0].lerp(GLANCE[0], 0.5))], frame)
        target = spline([(END, close[1]), (leave, close[1]), (leave + 34, last[1]), (840, last[1])], frame)
        return location, target

    def path(frame):
        location, target = with_names(frame)
        if named:
            near = 1 - ramp(frame, leave, leave + 26)
            return location, target, 70, lerp((target - location).length, TILE_DEPTH, near), 5.6
        # With no other app named: from close on the circle, counting, out to the whole watch. From
        # SAME_FROM on it is the same picture as the named cut, which is rendered once for both.
        join = ramp(frame, 776, SAME_FROM)
        location = spline([(END, Vector((0.004, -0.03, 0.06))), (750, Vector((0.008, -0.07, 0.11))), (leave + 34, last[0])], frame).lerp(location, join)
        target = spline([(END, centre), (750, centre * 0.5), (leave + 34, last[1])], frame).lerp(target, join)
        return location, target, 70, (target - location).length, lerp(11, 5.6, ramp(frame, END, 776))
    return common.camera(scene), path


BUILD = {"glance": build_glance, "street": build_street, "rain": build_rain, "series": build_other("series"),
         "se": build_other("se"), "end": build_end}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gen", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--language", default="en")
    parser.add_argument("--shot", required=True, choices=list(SHOTS))
    parser.add_argument("--frames", type=int, nargs=2)
    parser.add_argument("--still", type=int, nargs="*")
    parser.add_argument("--draft", action="store_true")
    parser.add_argument("--unnamed", action="store_true", help="the end names no other app")
    parser.add_argument("--size", type=int, nargs=2, default=(1080, 1920))
    parser.add_argument("--step", type=int, default=1, help="render every nth frame")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])

    scene = common.setup(*args.size, args.draft)
    cam, path = BUILD[args.shot](scene, args)
    bpy.app.handlers.frame_change_pre.append(Tile.show_in_flight)
    start, stop = SHOTS[args.shot]
    common.bake_camera(cam, range(start - 1, stop + 2), path)
    first, last = args.frames or (start, SAME_FROM if args.unnamed and args.shot == "end" else stop)
    frames = args.still if args.still else range(first, last, args.step)
    folder = f"{args.out}/{args.shot}" + ("-unnamed" if args.unnamed and args.shot == "end" else "")
    os.makedirs(folder, exist_ok=True)
    for frame in frames:
        target = f"{folder}/{frame:04d}.png"
        if os.path.exists(target) and not args.still:
            continue
        scene.frame_set(frame)
        scene.render.filepath = target
        bpy.ops.render.render(write_still=True)
        print("FRAME", frame, flush=True)


main()
