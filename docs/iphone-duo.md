# iPhone Duo

The 2026 foldable. Two displays: outer 5.4" 1398×2034, inner 7.6" 1878×2670, both
120Hz. Ships 2026-10-23.

## The one fact that shapes everything

**Only one display is lit at a time.** Showing content on both at once is limited to
camera apps holding an active capture session — `CameraCaptureAccessory` (iOS 27.1+).
`ExternalNonInteractiveAccessory` is for external monitors and AirPlay, not the Duo's
outer screen, and the outer screen cannot host a new window.

So "each team looks at their own screen" is off the table for this app. What is left,
and what is worth building, is **folding as a gesture**: closing the phone is already
the handoff, and the inner screen is a bigger canvas and a wider scoreboard.

Source: developer Lab Q&A (Q24), not official documentation. Apple has not stated this
publicly. Re-check against the official docs before relying on it.

## What the app has to survive

Folding or unfolding **migrates and resizes the running app** — it is not destroyed and
recreated. The inner screen is regular/regular size class and **does not honour the
app's declared orientations**, so this portrait-locked app runs landscape on it:
951×669pt. The outer screen is compact width / regular height.

Two things broke on first contact, both from assuming portrait:

- The home screen's content came to about 684pt against 669pt of height, so the VStack
  overflowed and pushed the language button off the top. Fixed by `FittingScroll`
  (SharedUI.swift) — behaves like a plain VStack when the height fits and scrolls when
  it does not — plus a two-column layout at regular width.
- The scoreboard's "words this round" chips were clipped in half.

The drawing canvas stores **normalised** coordinates (`CanvasSpace`) rather than points,
because a drawing has to survive the screen changing size underneath it mid-round.

## Working with the simulator

Xcode 27.1 or newer. This machine still has Xcode-beta 27.0 alongside, and
`xcode-select` points at the beta, so commands need the override:

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, iOS 27.1 runtime. The two
displays are two integrated screens: screenID 3 "LCD-1" is the inner one, screenID 1
"LCD" the outer. Screenshotting the dark one gives a black frame.

```bash
xcrun simctl io <udid> screenshot --display internal out.png   # or --display 1 | 3
```

**simctl has no fold/posture command.** Changing posture is a click in DeviceHub's GUI
and cannot be scripted.

### Sweeping every page

The app jumps straight to any page via `SCREENSHOT_MODE` (see ScreenshotMode.swift for
the full list — home, wheel, handoff, drawcanvas, scoreboard, hofresult, smallboard,
settings, privacy, pick, …):

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
UDID=$(xcrun simctl list devices | awk '/iPhone Duo/{print $NF}' | tr -d '()')
for m in home wheel handoff drawcanvas scoreboard hofresult smallboard settings; do
  xcrun simctl terminate $UDID com.partyrelay.app 2>/dev/null
  SIMCTL_CHILD_SCREENSHOT_MODE=$m xcrun simctl launch $UDID com.partyrelay.app
  sleep 2
  xcrun simctl io $UDID screenshot --display internal Screenshots/duo-check/$m.png
done
```

`Screenshots/duo-check/` is gitignored — it is 20MB+ of verification frames and this
loop regenerates it in a couple of minutes.
