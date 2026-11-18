# Written by AI on 2026.11.18 by model claude fable 5.2. A picture of the prototype's screen.
# shot.py <out.png> <query> [wait_ms] [at=position 0..1 to scrub to]
import sys
from playwright.sync_api import sync_playwright
out, query = sys.argv[1], sys.argv[2]
wait = int(sys.argv[3]) if len(sys.argv) > 3 else 600
at = float(sys.argv[4]) if len(sys.argv) > 4 else None
with sync_playwright() as p:
    b = p.webkit.launch()
    page = b.new_page(viewport={"width": 700, "height": 900}, device_scale_factor=2)
    msgs = []
    page.on("console", lambda m: msgs.append(m.text))
    page.on("pageerror", lambda e: msgs.append("ERR " + str(e)))
    page.goto("http://127.0.0.1:8793/?" + query)
    try:
        page.wait_for_function("document.body.dataset.ready", timeout=30000)
    except Exception as e:
        msgs.append("not ready: " + str(e)[:100])
    if at is not None:
        box = page.locator("#graph svg").bounding_box()
        page.mouse.move(box["x"] + box["width"] * at, box["y"] + 40)
        page.mouse.down(); page.mouse.up()
    page.wait_for_timeout(wait)
    page.locator("#phone").screenshot(path=out, omit_background=True)
    for m in msgs: print(m)
    b.close()
