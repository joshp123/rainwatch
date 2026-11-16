<!-- Written by AI on 2026.11.13 by model claude opus 5.5, at Josh's request. -->

# Rain

Josh's Apple Watch app: Buienradar's rain for the next two hours where he is, on his Apple Watch Ultra 3, as complications, a Smart Stack widget and an app with a radar map. What it must do and why is in `REQUIREMENTS.md`; how it is built and run is in `README.md`; the evidence behind the design is in `research/`.

The goal is a glance he can trust: whether it is dry now and for how long, drawn as Buienradar's own rain line, never older than it says. He judges the work by looking at it, so the pictures are the product.

## Design

`DESIGN.md` has the rules every view follows and where they come from. Read it before changing a view.

`LAUNCH.md` is the plan for the App Store: Josh's open decisions first, then every task with its owner and status. Keep its status columns current when a task moves.

## The server

The forecast job is `server/job.py`. It runs every 5 minutes on the gohome VPS (`~/code/nix/nixos-config/hosts/nixos/gohome-hub/rainwatch.nix`), which uploads its two files to S3; CloudFront serves them at `rain.jjpcodes.com` (`~/code/opentofu-infra/services/rainwatch`). Why it is built this way: `server/FIRST-PRINCIPLES.md`. KNMI's fair-use rules bind every change: one fetch per run, never the same file twice (https://developer.dataplatform.knmi.nl/fair-use).

## App Store Connect and Apple's developer account: command line only

Josh, 14 November 2026: "No, I'm not gonna use touch ID. You're gonna figure out how to drive this via the CLI instead of computer use. This is a hard rule ... You need to be using command line tools and finding the appropriate first party command line tools instead of just doing random computer use shit."

So every App Store Connect and developer-account task (the app record, names and languages, the listing, privacy answers, trader status, builds, TestFlight, submission) is done from the shell, never by driving Xcode, a browser or the Developer app on screen, and never with a step that needs Josh's Touch ID. Use Apple's own tools first: `xcodebuild` to archive, export and upload, `xcrun altool` and `notarytool`, and the App Store Connect API. Where Apple's API stops (it cannot create an app, answer App Privacy or set trader status), use `asc` (github.com/rorkai/App-Store-Connect-CLI, installed from its GitHub release in `~/.local/bin`; Homebrew's copy is years old). Its `asc web` commands sign in to the App Store Connect website as Josh: `--two-factor-method sms` with `--two-factor-code-command "asc web auth messages-code"` reads Apple's text from Messages on this Mac, so the code needs no one. If a task seems to have no command-line route, read the tool's docs and source before concluding that, and ask Josh rather than reach for the screen.

## Look at every image before anyone else does

Josh, 13 November 2026: "look at those images? some look weird? lots is clipped? you need to set this up properly in a repo ... with a rule to always look at images and critique it". Mock-ups and screenshots from this project have gone to him clipped, overlapping and inconsistent because the agent showed them without looking.

So before you show, describe or commit any image (a render in `renders/` or a simulator or watch screenshot), open it yourself at full size and critique it as Josh would, against what a real watch shows. Fix what you find and look again; show it only when you would put your name to it. Check at least:

- Nothing is clipped by the frame, the screen corner or another view, and no text is truncated or wraps where it should not.
- Nothing overlaps: words, the rain line, dots, map labels and system controls each have their own space.
- Labels read as intended: "Now" and the first hour mark must not read as one phrase; every word is plain English, with no codes.
- Times agree: the forecast, the axis, the words and the clock on the face describe the same moment.
- Sizes are true: complications at their real size on Josh's face (`research/josh-face-2026-11-05.jpeg`), text readable at arm's length.
- It works in every state that will occur: dry, drizzle, on and off, heavy, stale, and Night Mode or a tinted face.

When the image changed a lot, also get a critique from a fresh agent that sees only the image and Josh's words, not your reasoning.

## Testing in the simulator

Drive the simulator with tools that read its accessibility tree, not by clicking Device Hub with computer use: the tree gives every word on screen, our complications included, and exact positions, so a test can check what Rain says instead of guessing from pixels.

What works here, checked on 13 November 2026 with Xcode 27.2 and the watchOS 27.2 simulator:

- serve-sim (Expo, Apache-2.0) streams a simulator to a browser and takes commands. Run it without installing anything: `nix shell nixpkgs#nodejs_22 -c npx -y serve-sim@latest --detach -q <udid>`. Then `curl http://127.0.0.1:3100/helper/<udid>/ax` returns the accessibility tree (the face showed "Rain stops in 3 min, Dry 15:50–16:25" and "IN, 3, MIN"), and `serve-sim tap <x> <y> -d <udid>` taps at coordinates from 0 to 1 (divide the tree's points by the 211 × 257 screen). Drags must go through its WebSocket in one connection; separate `gesture` calls arrive too slowly. Stop it with `serve-sim --kill`.
- Not yet tried here: AXe (`brew install cameroncooke/axe/axe`, taps by accessibility label), sim-use (LY Corp) and baguette (web device farm). baguette's docs say it presses the watch crown but cannot turn it.
- No third-party tool turns the Digital Crown. Apple's XCUITest can, and `App/RainUITests` uses it: `xcodebuild test -project Rain.xcodeproj -scheme Rain -destination 'id=<simulator udid>'` answers the location question, opens the forecast and the radar, checks that the radar plays, that the crown pauses it and that zoom works, and keeps a screenshot of each screen. Get them with `xcrun xcresulttool export attachments --path <result bundle> --output-path <folder>`; the test also records the screen as a video.
- Run the UI tests with `App/test.sh <simulator udid>`. The refused-location test needs location never asked, and only `xcrun simctl privacy ... reset location` clears a watch app's permission (XCUITest's reset stopped working after a simulator restart), so the script runs it on its own between resets. The system's buttons use a curly apostrophe: "Don’t Allow".
- Device Hub with computer use is the last resort; it needs the window in front for some gestures and gives only pixels.
- On Josh's real watch, `xcrun devicectl device capture screenshot --device <watch> --destination x.png` works and takes about a second; `process launch` opens any app, including other developers' (Buienradar is `nl.rtl.buienradar.watchkitapp`). `capture screen-record` is not supported on the watch, so take screenshots in a loop to see motion.
- Text sizes are only true on the real watch: the Mac renderer draws SF Compact Rounded about a fifth smaller than the watch, and Josh's face gives the circle 45 points, not the 50 in Apple's guidelines. To see any saved forecast on his real face, launch the debug build in the background and close it again: `xcrun devicectl device process launch --device <watch> --no-activate --terminate-existing nl.jjp.rain.watchkitapp -- -scenario showerComing`, then `devicectl device process terminate` on Rain's pid and take a screenshot. Launch once more without `-scenario` to put the live forecast back. The screen must be awake; system prompts can cover the face, so look at every screenshot. `renders/watch/circular-states.png` is the reference.
- Not yet tried: Xcode 27's release notes say its coding agents can rotate and press the Digital Crown (Xcode's MCP server, `xcrun mcpbridge`); it needs Josh to approve agent access in Xcode.

This field changes month to month, and most of these tools are under a year old. When this section is more than a month old, or a tool here fails, search for the current state of the art first (Parallel web search works well), try anything better, and rewrite this section with the date you checked.

## Working here

- Build the app from `App/` with the commands in `README.md`; the simulator is "Rain Ultra 3". Mock-ups come from `swift run render-mockups renders research/josh-face-2026-11-05.jpeg`. Mock-ups only show widget designs; for what the app really looks like, use simulator or watch screenshots.
- Pairing Josh's watch with this Mac (worked on 13 November 2026, Xcode 27.2, watchOS 27.0). From watchOS 27 the watch must start pairing itself; Xcode no longer pairs it through the iPhone (the pairing log says "supports user-driven network pairing flows. Skipping companion proxy bootstrap pairing"). If `devicectl` says the watch rejected the Bluetooth connection (error 1035), the old pairing is stale:
  1. `xcrun devicectl manage unpair --device <watch udid>`.
  2. In Device Hub, open File > Pair Nearby Device… with Device Hub in front (from the background the sheet does not open) and leave the "Waiting to pair" sheet open.
  3. Josh opens Settings > Privacy & Security > Developer Mode on the watch, taps Pair with this Mac, and types the six-digit code the sheet shows (not his passcode). If the Mac is not listed, the watch is not on Wi-Fi: turn off its Bluetooth for a moment.
  4. Build once for the watch with `-allowProvisioningUpdates -allowProvisioningDeviceRegistration` so its UDID is added to the signing profiles.
  The Mac reaches the watch over Wi-Fi, so installs fail with "Connection invalid" or error 1001 when the watch's screen turns off; keep it awake while installing.
