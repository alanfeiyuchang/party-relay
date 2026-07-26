# 🎉 派对接力 · PartyRelay

A local, offline, pass-the-phone party game for two teams. SwiftUI · iOS 17+ · zero dependencies, zero network calls.

Split into Red Team vs Blue Team, spin the wheel for a game, race to guess words before the timer runs out, and let the built-in catch-up system quietly keep a blowout from turning into a boring rest of the night.

<p align="center">
  <img src="Screenshots/3-en-home.png" width="220" alt="Home screen">
  <img src="Screenshots/4-en-wheel.png" width="220" alt="Spin the wheel">
  <img src="Screenshots/7-en-scoreboard.png" width="220" alt="Scoreboard with recap">
  <img src="Screenshots/9-en-pickmode.png" width="220" alt="Catch-up game picker">
</p>

More screenshots (Chinese UI, settings, Open Buzz, privacy guard, drawing canvas) are in [`Screenshots/`](Screenshots).

---

## Gameplay

### The four games

| | Game | How it works |
|---|---|---|
| 🗣️ | **Say & Guess** | One player describes the word out loud — without saying any character/word that's literally in it — while the rest of the team guesses. |
| 🎨 | **Draw & Guess** | One player sketches the word on an in-app canvas (no letters or numbers), teammates guess from the same screen. |
| 🤐 | **Lip Reading** | One player mouths the word silently — no sound at all — and the team reads their lips. |
| 🕺 | **Charades** | One player acts the word out with gestures only, no sound. |

Every game pulls from its own hand-written word list (not machine translated), split into 3 internal difficulty tiers that quietly get harder as the match progresses. Words never repeat within the same team's turn.

### ⚡️ Open Buzz — not a 5th game, a wheel modifier

The wheel has a 5th sector, **Open Buzz**. Landing on it doesn't start a game by itself — it spins again to pick one of the four real games, but for that round **both teams can steal points**: while the other team is having their turn, your team can jump in and steal a point for a word they missed. There's no separate trivia/quiz mode — it's a rule modifier layered onto whichever game gets picked.

### Scoring: small points → 1 big point

Each round, **both teams play the same game**, one after the other — the **Red team always goes first**. Whoever gets more correct guesses (small points) in their turn wins the round and earns **+1 big point**. Tie on small points → both teams get the big point. First to the most big points after all rounds wins; a tied match goes to a sudden-death overtime round.

### Small-score mode (optional)

Flip **"Decide the winner by small score"** in Settings and big points disappear entirely: every correct guess adds to that team's running total, the scoreboard just shows those two totals, and after the configured number of rounds the highest total wins (a tie still goes to overtime). The host's +/− buttons adjust the running totals directly, and the catch-up system works off the point gap the same way.

### Handoff countdown

When one team's turn ends and the phone passes to the other team, the handoff screen's start button stays disabled for 5 seconds — enough of a beat that nobody starts their turn while the phone is still in the air.

### Catch-up system (invisible to players)

If a team falls behind, their turn quietly gets a boost — more time, a couple of extra skips, and internally easier words. **None of this is shown in the UI** (no difficulty labels, no "-1 tier" badges) — only a friendly "🔥 Comeback boost" banner with the concrete perks (+15s, +2 skips), never anything about word difficulty. Deep into a lopsided match, the trailing team can also skip the wheel entirely and pick their game directly from a list — see the picker screenshot above.

### After every round: word recap + reset

The scoreboard page shows a recap of every word that came up during each team's turn that round (so you can settle "wait, was that really the word?" disputes), plus a **Reset Game** button (with a confirmation prompt) to abandon the current match and start over without force-quitting the app.

### Privacy guard (optional, off by default)

When enabled in Settings, the word card only shows while the phone is held upright; laying it flat automatically hides it behind a "🙈 don't peek" card — handy when passing the phone hand-to-hand mid-round. A triple-tap escape hatch force-reveals the word if motion sensing isn't cooperating (also the default fallback on the Simulator, which has no real accelerometer).

### Settings

- Toggle any of the 4 games off (Open Buzz always stays available as long as ≥1 game is on) — the wheel rebuilds its sectors immediately. The same toggles are reachable from the home screen: tap any game tag to read its rules and add/remove it from the wheel; excluded games show greyed out.
- Total rounds: 3–10 (default 6).
- Turn length: 30–180s in 15s steps.
- Skips per turn: 0–10 (default 3).
- Small-score win mode on/off (see above).
- Privacy guard on/off.
- Haptics + sound effects on/off (global switch).

When exactly one regular game is enabled, spinning would be pointless — the wheel is skipped entirely and the match drops straight into that game (Open Buzz doesn't count here, since landing on it only re-spins for a real game).

### Getting out mid-match

Every in-game screen has a **Home** button in the top-left corner. It asks for confirmation first ("Return to home? The current game's progress will be lost."), so a stray tap can't wipe a match in progress.

### Localization

Fully bilingual (English / Simplified Chinese) via a native `.xcstrings` String Catalog — no hardcoded UI text. Word banks are independently authored per language (not machine-translated) and switch automatically with the app language. Toggle language from the 🌐 button on the home screen; it takes effect instantly across the whole app.

---

## Word banks

| Game | Chinese entries | English entries |
|---|---:|---:|
| Say & Guess | 1778 | 120 |
| Draw & Guess | 1770 | 120 |
| Lip Reading | 1770 | 120 |
| Charades | 1769 | 120 |

Each is split across 3 internal difficulty tiers and hand-curated per game's constraints (describable nouns/idioms, concretely drawable things, short high-visibility-mouth-shape phrases, physically actable verbs/scenes).

---

## Project structure

```
PartyRelay/
├── PartyRelayApp.swift        # App entry point
├── Models.swift                # Team / GameKind / GameSettings / CatchUp / RoundOutcome / Phase
├── GameStore.swift              # Central state machine: rounds, scoring, catch-up, word dispatch
├── Localization.swift           # AppLanguage + LanguageManager (loads the right .lproj bundle)
├── Localizable.xcstrings        # All user-facing strings, en + zh-Hans
├── MotionManager.swift          # CoreMotion posture detection (upright/flat) for the privacy guard
├── FeedbackManager.swift        # Centralized haptics + sound effects, gated by the settings switch
├── ScreenshotMode.swift         # SCREENSHOT_MODE env var → jump straight to any screen (for automation)
├── Words/                       # Per-game word banks, zh + en, 3 tiers each
└── Views/
    ├── HomeView, SettingsView    # Landing page (+ team setup) and settings sheet
    ├── WheelView                 # Spinning wheel, Open Buzz respin, catch-up game picker
    ├── HandoffView                # "pass the phone" hand-off screen between turns
    ├── PlayView                   # Say & Guess / Lip Reading / Charades turn screen
    ├── DrawView                   # Draw & Guess: word screen ⇄ drawing canvas
    ├── RoundResultView             # Small-score comparison + big-point award reveal
    ├── ScoreboardView               # Big scores, last round's words recap, Reset Game
    ├── VictoryView + ConfettiView    # Match end screen with confetti
    └── SharedUI                      # Buttons, timer ring, catch-up banner, score badge
```

---

## Build & run

Requires Xcode with an iOS 17+ SDK.

```bash
xcodebuild -project PartyRelay.xcodeproj -target PartyRelay \
  -sdk iphonesimulator -configuration Debug -arch arm64 build \
  CODE_SIGNING_ALLOWED=NO SYMROOT=build
```

If you only have an Xcode beta installed and no stable Xcode selected via `xcode-select`, prefix the command with:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

Then install and launch on a booted simulator:

```bash
xcrun simctl install booted build/Debug-iphonesimulator/PartyRelay.app
xcrun simctl launch booted com.partyrelay.app
```

To run on a real device, open `PartyRelay.xcodeproj` in Xcode, pick your team under Signing & Capabilities, and run normally.

## Screenshot / QA automation

Two environment variables let you jump straight to any screen with realistic sample data, useful for scripted screenshots:

```bash
SIMCTL_CHILD_SCREENSHOT_MODE=<mode> SIMCTL_CHILD_SCREENSHOT_LANG=<zh|en> \
  xcrun simctl launch booted com.partyrelay.app
```

`SCREENSHOT_MODE` values (see `ScreenshotMode.swift`): `home`, `wheel`, `pick`, `openbuzz`, `privacy`, `draw`, `drawcanvas`, `scoreboard`, `result`, `settings`, `victory`.
`SCREENSHOT_LANG` forces `zh` or `en` regardless of the simulator's system language.
