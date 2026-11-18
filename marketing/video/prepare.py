"""Turns the captures of capture.sh into what the film reads: the face once per change, the radar
once per frame, and src/captures.json with their times.
Run: python3 prepare.py <capture folder>
Written by AI on 2026.11.18 by model claude fable 5.2."""
import json, os, shutil, sys

CAP = sys.argv[1]
HERE = os.path.dirname(os.path.abspath(__file__))
PUBLIC = f"{HERE}/public"
MINUTE = 60
out = {}

for lang, face_dir, radar_dir in (("en", "en", "ren"), ("nl", "nl", "rnl")):
    # The face: screenshots named by the second they were taken. Keep one per change.
    shots = sorted(f for f in os.listdir(f"{CAP}/{face_dir}/lapse") if f.endswith(".png"))
    launched = os.path.getmtime(f"{CAP}/{face_dir}/app-rainComing.png") - 7
    # As RainApp does for `-scenario`: the run on a five-minute mark at least ten minutes before
    # launch, its forecast from ten minutes after it; rainComing is dry for its first 25 minutes.
    rain_at = (launched - 10 * MINUTE) // (5 * MINUTE) * (5 * MINUTE) + 10 * MINUTE + 25 * MINUTE
    dest = f"{PUBLIC}/lapse/{lang}"
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    # The face changes on the minute, and a screenshot can catch it mid-change: keep the last one
    # taken in each minute, dated at that minute.
    minutes = {}
    for name in shots:
        taken = int(name[:-4])
        if rain_at - 21 * MINUTE <= taken <= rain_at + 7 * MINUTE and taken % MINUTE >= 15:
            minutes[taken // MINUTE * MINUTE] = name
    face = []
    for minute, name in sorted(minutes.items()):
        file = f"lapse/{lang}/{len(face):03d}.png"
        shutil.copy(f"{CAP}/{face_dir}/lapse/{name}", f"{PUBLIC}/{file}")
        face.append({"t": minute, "file": file})

    # The radar: a burst of screenshots while it plays. Its frames repeat, so keep each picture
    # once, in the order first seen from the earliest moment ("30 min ago") on.
    dest = f"{PUBLIC}/radar/{lang}"
    shutil.rmtree(dest, ignore_errors=True)
    os.makedirs(dest)
    burst = sorted(os.listdir(f"{CAP}/{radar_dir}/radar"))
    order = json.load(open(f"{CAP}/{radar_dir}/order.json"))    # written after looking at the burst
    for index, name in enumerate(order["frames"]):
        shutil.copy(f"{CAP}/{radar_dir}/radar/{name}", f"{dest}/{index:02d}.png")
    os.makedirs(f"{PUBLIC}/page", exist_ok=True)
    shutil.copy(f"{CAP}/{radar_dir}/page.png", f"{PUBLIC}/page/{lang}.png")
    out[lang] = {
        "face": face,
        "rainAt": rain_at,
        "lapseFrom": rain_at - 20 * MINUTE,
        "lapseTo": rain_at + 5 * MINUTE,
        "page": f"page/{lang}.png",
        "radarFolder": f"radar/{lang}",
        "radar": len(order["frames"]),
        "radarNow": order["now"],
    }
    print(lang, len(face), "face states,", len(order["frames"]), "radar frames, of", len(burst), "screenshots")

json.dump(out, open(f"{HERE}/src/captures.json", "w"), indent=1)
