<!-- Written by AI on 2026.11.18 by model claude fable 5.2, at Josh's request. -->

# The website (a prototype)

One page for RainWatch (BuienWatch in Dutch), meant for `rain.jjpcodes.com`, where the forecast files already are. It is not live, and its words are a draft: Josh edits them on the "Website" page of the Paper file (https://app.paper.design/file/01M7NBWW1V3TM4BBDNRMXEMP2F), and they are copied from there into `index.html`.

The page shows the rain for a town the visitor picks, as the watch would show it now. It reads KNMI's newest forecast with the two requests the watch makes (`latest`, then one byte range of the pack) and lists them underneath, so a visitor can see what the server is asked.

## Run it

```sh
uv run --with pillow python frame.py    # the pictures, once; see the top of frame.py
python3 serve.py 8791                   # then open http://<this machine>:8791/
```

`serve.py` serves the page and passes `latest` and `runs/*` through from the live server, Range header included, so the page and the files share one address as they would at `rain.jjpcodes.com`. `?lang=nl` and `?lang=en` choose the language; `#groningen` chooses the town.

## What is proven

- The same values as `server/watch_client.py`: all 31 steps for six towns on one run (18 November 2026).
- It works in Chrome 152 and in WebKit 27.2 (Safari's engine) at phone and desktop size: `latest` answers 200, the pack 206 with exactly the bytes asked for, and the browser's own `DecompressionStream('deflate-raw')` unpacks them.
- From another address it fails (`?direct`): the live server sends no CORS headers. At `rain.jjpcodes.com` the page and the files share an address, so none are needed.

## How it is made

- `rain.js` is the watch's reader and the app's rules in JavaScript: `Forecast.swift`, `RainCopy.swift`, `RainCurve.swift` and the graph of `RainViews.swift`. The app's words in it are copied from `Sources/RainGraph/Localizable.xcstrings`; before this goes live they should be read from the catalogue when the site is built, so the page and the watch can't disagree.
- `index.html` is the page, its own words in English and Dutch, and the drawing.
- `assets/` is made by `frame.py` and not committed.

## To go live

Nothing here changes AWS. The page needs, in `~/code/opentofu-infra/services/rainwatch`: `default_root_object = "index.html"` on the distribution, and a way to upload the page's files to the bucket (the publisher's key may only write `runs/*` and `latest`). The pack's one-day expiry covers `runs/` only, so the page's files stay.
