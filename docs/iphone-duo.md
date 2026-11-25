# iPhone Duo

The 2026 foldable. Two displays, both 120Hz. Ships 2026-10-23.

**Measured, not quoted** (`simctl io <udid> enumerate`, and `FOLD_PROBE=1` with
`simctl launch --console`):

| | points | app-usable | safe-area insets (t/l/b/r) |
| --- | --- | --- | --- |
| outer | 466×678 | **382×644** | 0 / 0 / 34 / **84** |
| inner | **951×669 (landscape)** | **867×635** | 0 / 0 / 34 / **84** |

Both rows are measured on the real device (`FOLD_PROBE=1` + `devicectl device process launch
--console`), not inferred from the simulator.

The outer screen has **no top status bar** — the clock and Wi-Fi sit in an 84pt vertical
strip down the trailing edge, which is why `RootView` puts the pause button there.

**The inner screen's orientation follows the device, and both orientations really happen.**
Two readings on the same phone, minutes apart:

| device held | `interfaceOrientation` | app-usable | insets (t/l/b/r) | full |
| --- | --- | --- | --- | --- |
| portrait | landscapeRight | 867×635 | 0 / 0 / 34 / **84** | 951×669 |
| landscapeLeft | portrait | 669×835 | **82** / 0 / 34 / 0 | 669×951 |

So the panel sits 90° rotated relative to the device's portrait: holding the phone upright gives
the app a *landscape* layout, and turning the phone sideways gives it *portrait*. The status bar
moves accordingly — a vertical 84pt strip on the trailing edge in landscape, a normal 82pt top bar
in portrait.

⚠️ A first reading showed only the landscape case and was briefly written up here as "the inner
screen is always landscape". That was one sample and it was wrong. Take two readings in different
device orientations before concluding anything about this panel.

What still needs deciding: `RootView.isSideways` is `isLaptopPosture && width > height`, so folding
while the phone is held upright puts the whole app behind `RotateToLaptopOverlay`, and the folded
layout is only reachable by physically turning the phone. `CreaseSplit` also assumes the crease is
horizontal, which only holds in the portrait case. Whether to build a landscape folded layout, or
keep steering people to portrait, is an open design call.

## The one fact that shapes everything

**Only one display is lit at a time.** Showing content on both at once is limited to
camera apps holding an active capture session — `CameraCaptureAccessory` (iOS 27.1+).
`ExternalNonInteractiveAccessory` is for external monitors and AirPlay, not the Duo's
outer screen, and the outer screen cannot host a new window.

Source: developer Lab Q&A (Q24), not official documentation. Apple has not stated this
publicly. Re-check against the official docs before relying on it.

**This page used to conclude from that "each team looks at their own screen is off the
table". That conclusion is wrong and the app no longer follows it.** The capture-session
requirement is a price, not a wall: `PartyRelay/CoverScreen.swift` holds the session, and the
outer screen now shows the guessers a timer, a big question mark, or a live mirror of the drawing.

The session stays a decoy, though. Putting it to real use was tried — a small live view from the
outward-facing camera on the inner screen — and abandoned: on the device both `position: .front`
cameras (`built-in_video:1` wide and `:8` ultra-wide) turn out to be the **inner** screen's, and the
cover screen's camera is not enumerable while the phone is open, so there is no reliable way to pick
it. With nothing displaying frames, the sink discards every one.

The cost is still real — camera permission, the green dot, a line in App Review Notes — so the
session is only opened on a device that actually has a hinge (`HingeMonitor.status != .unavailable`);
an ordinary iPhone is never asked for the camera.

Folding is still also a gesture: closing the phone mid-round now blanks the word and
pauses the timer (`FoldedShutOverlay`), because closing is how people hand the phone over
and the next person must not see the answer.

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
and cannot be scripted. Both Duo simulators here sit *closed*, so the inner screen is dark
and the app actually runs on the outer one — screenshotting the inner display gives a black
frame, and the real `UIHingeInteraction` reports `.closed`.

That is why `PartyRelay/FoldPreview.swift` exists: it lays the whole app out at any target
point size with injected safe-area insets, so the 90° layout can be reviewed at the inner
screen's real dimensions. It was calibrated against the real screen at the same size —
SSIM ≈ 0.996, the residual being the status bar it hides. Sweep every page with:

```bash
scripts/fold-shots.sh            # 90° laptop posture (inner screen)
scripts/fold-shots.sh --flat     # unfolded, for contrast
scripts/fold-shots.sh --outer    # the app on the outer screen (phone closed)
scripts/fold-shots.sh --cover    # what the guessers see on the outer screen
```

Debug overrides: `FORCE_LAPTOP=1` (90° posture, also fakes a hinge so the fold hints
render), `FORCE_SHUT=1` (phone closed), `FORCE_SIDEWAYS=1`, `PREVIEW_COVER=1`.

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
