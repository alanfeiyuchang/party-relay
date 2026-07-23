# App Store Connect submission kit

Everything needed to fill out the App Store Connect listing for PartyRelay / 派对接力, in both English and Simplified Chinese.

```
AppStoreConnect/
├── en/                     # Copy-paste-ready text fields for the English listing
├── zh-Hans/                # Same fields, localized for the Simplified Chinese listing
├── PromoImages/
│   ├── hero/{en,zh-Hans}/   # 4 "hero" marketing slides — pick your favorite as screenshot #1
│   └── feature/{en,zh-Hans}/# 5 feature-highlight slides — screenshots #2–6
└── scripts/                 # The generator that built PromoImages/ (HTML/CSS + headless Chrome)
```

## Text fields (`en/`, `zh-Hans/`)

One file per App Store Connect field, plain text, already checked against Apple's character limits:

| File | Field | Limit |
|---|---|---:|
| `app_name.txt` | App name | 30 |
| `subtitle.txt` | Subtitle | 30 |
| `promotional_text.txt` | Promotional text (editable without a new build) | 170 |
| `description.txt` | Description | 4000 |
| `keywords.txt` | Keywords (comma-separated) | 100 |
| `whats_new.txt` | "What's New in This Version" | 4000 |
| `support_marketing_urls.txt` | Support URL / Marketing URL | — |
| `other_metadata.txt` | Category, age rating, copyright, price, privacy notes | — |

**Before you submit:** `other_metadata.txt` has two placeholders you must fill in yourself —
the copyright holder name, and (if you'd rather not point directly at GitHub Issues) a real
support contact. Apple won't accept the listing without a working Support URL.

## Promo images (`PromoImages/`)

All 18 images are **1290×2796** (iPhone 6.7"-class screenshot size — accepted directly as
real App Store screenshots, not just social-media art). Each one frames an actual, current
screenshot of the app inside a phone mockup — nothing here shows mocked-up or outdated UI.

- **`hero/`** — 4 variants of a "people having fun with the app" title slide (flat-illustration
  characters + confetti around a phone showing the home screen / wheel / a game in progress).
  These are deliberately redundant with each other — **review them and pick the one (or two)
  you like best** for screenshot slot #1; you don't need to use all 4.
- **`feature/`** — 5 slides, one per major feature (the 4 games + wheel, Open Buzz, the
  catch-up/comeback system, the privacy guard, the round recap), meant to fill screenshot
  slots #2–6 in order.

If Apple's current upload portal asks for a different largest-device size (e.g. 6.9" /
1320×2868 for the newest Pro Max), bump `W, H` in `scripts/gen_promo.py` and re-run
`python3 scripts/build_all.py` followed by the render loop in this README — everything
regenerates from the same templates and the current screenshots.

### Regenerating or tweaking the images

The images are built, not hand-drawn: `scripts/people.py` defines a small reusable flat-illustration
"party person" (SVG), `scripts/gen_promo.py` lays out each slide (phone mockup + real screenshot +
headline), and `scripts/build_all.py` writes one `.html` file per slide into `_build/html/`. A
plain headless-Chrome screenshot turns each into a PNG:

```bash
# 1. Re-capture fresh device screenshots if the app UI changed
#    (see the modes in PartyRelay/ScreenshotMode.swift)
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay -sdk iphonesimulator \
  -configuration Debug -arch arm64 build CODE_SIGNING_ALLOWED=NO SYMROOT=build
xcrun simctl install booted build/Debug-iphonesimulator/PartyRelay.app
# ... loop SIMCTL_CHILD_SCREENSHOT_MODE / SIMCTL_CHILD_SCREENSHOT_LANG over
#     home/wheel/openbuzz/privacy/pick/draw/drawcanvas/scoreboard/result/settings/victory
#     into AppStoreConnect/_build/fresh_screens/{en,zh}-<mode>.png

# 2. Regenerate the HTML slides
cd AppStoreConnect/scripts && python3 build_all.py

# 3. Render every slide to PNG
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
cd ../_build
while IFS=$'\t' read -r htmlfile outrel; do
  mkdir -p "../PromoImages/$(dirname "$outrel")"
  "$CHROME" --headless --disable-gpu --screenshot="../PromoImages/$outrel" \
    --window-size=1290,2796 "file://$(pwd)/html/$htmlfile"
done < html/manifest.txt
```

`_build/` (raw HTML + the working copy of device screenshots) is gitignored — it's scratch
output, regenerate it any time from `scripts/` + a fresh simulator build.

## Why not literally use the old `Screenshots/` folder?

Those were taken mid-development and some predate the fix that hides the internal
difficulty/tier system from players (one shows a leftover "Difficulty Medium" label). All
images in `PromoImages/` were captured fresh from the current build instead — see
`_build/fresh_screens/` (or re-run step 1 above) if you want the raw, undecorated screenshots
for any other purpose.
