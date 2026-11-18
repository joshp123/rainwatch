# Written by AI on 2026.11.18 by model claude fable 5.2. See ../README.md.
# gen_paper.py <name> <page> <query> <selector> [index] [at] [wait_ms]: one screen as HTML for Paper, in paper/<name>.html
import sys, pathlib
from playwright.sync_api import sync_playwright
name, pagefile, query, selector = sys.argv[1:5]
index = int(sys.argv[5]) if len(sys.argv) > 5 and sys.argv[5] else 0
at = float(sys.argv[6]) if len(sys.argv) > 6 and sys.argv[6] else None
wait = int(sys.argv[7]) if len(sys.argv) > 7 else 700
out = pathlib.Path("/tmp/rainwatch-iphone-paper"); out.mkdir(exist_ok=True); js = (pathlib.Path(__file__).parent / "topaper.js").read_text()
with sync_playwright() as p:
    b = p.webkit.launch()
    page = b.new_page(viewport={"width": 3200 if pagefile != "index.html" else 700, "height": 1400 if pagefile != "index.html" else 900}, device_scale_factor=2)
    page.on("pageerror", lambda e: print("ERR", e))
    page.goto(f"http://127.0.0.1:8793/{pagefile}?{query}")
    page.wait_for_function("document.body.dataset.ready", timeout=30000)
    if at is not None:
        box = page.locator("#graph svg").bounding_box()
        page.mouse.move(box["x"] + box["width"] * at, box["y"] + 40); page.mouse.down(); page.mouse.up()
    page.wait_for_timeout(wait)
    result = page.evaluate(f"({js})({selector!r}, {name!r}, {str(out)!r}, {index})")
    for asset in result["assets"]:
        (out / asset["file"]).write_text(asset["svg"])
    if page.locator("#map").count() and page.locator("#map").is_visible():
        page.add_style_tag(content="#map .moment { visibility: hidden !important }")
        page.locator("#map").screenshot(path=str(out / f"{name}-map.png"))
    (out / f"{name}.html").write_text(result["html"])
    print(name, len(result["html"]), "chars,", len(result["assets"]), "drawings")
    b.close()
