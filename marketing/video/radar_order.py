# Orders the radar burst by the white time marker on the strip, and makes a contact sheet.
import hashlib, json, os, sys
from PIL import Image
cap = sys.argv[1]
for lang in ("ren", "rnl"):
    d = f"{cap}/{lang}/radar"; seen = {}
    for name in sorted(os.listdir(d)):
        if not name.endswith(".png"): continue
        h = hashlib.md5(open(f"{d}/{name}", "rb").read()).hexdigest()
        if h in seen: continue
        im = Image.open(f"{d}/{name}").convert("RGB")
        # marker: the column in the strip (y 428..470) with the most near-white pixels
        best, bx = 0, -1
        for x in range(8, 414):
            n = sum(1 for y in range(428, 470) if min(im.getpixel((x, y))) > 235)
            if n > best: best, bx = n, x
        clock = hashlib.md5(im.crop((150, 8, 272, 52)).tobytes()).hexdigest()
        seen[h] = (bx, best, name, clock)
    # The clock's minute changes during the burst: keep the pictures of the commonest minute.
    clocks = [c for *_, c in seen.values()]
    common = max(set(clocks), key=clocks.count)
    by_x = {}
    for bx, best, name, clock in sorted(seen.values()):
        if bx not in by_x or clock == common: by_x[bx] = (bx, best, name)
    frames = sorted(by_x.values())
    print(lang, len(frames), [(x, n) for x, n, _ in frames])
    names = [n for _, _, n in frames]
    json.dump({"frames": names, "now": 0}, open(f"{cap}/{lang}/order.json", "w"))
    sheet = Image.new("RGB", (8 * 215, ((len(names) + 7) // 8) * 262), "#222")
    for i, n in enumerate(names):
        sheet.paste(Image.open(f"{d}/{n}").convert("RGB").resize((211, 257)), ((i % 8) * 215 + 2, (i // 8) * 262 + 2))
    sheet.save(f"{cap}/{lang}-radar-sheet.png")
