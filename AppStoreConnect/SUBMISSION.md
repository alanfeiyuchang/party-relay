# PartyRelay — App Store Connect Submission Doc

Everything needed to fill out App Store Connect for PartyRelay, in one place. Sections
follow the order you'll hit them in App Store Connect's UI. Anything you need to type
in yourself (not derivable from the code) is marked **⬜ FILL IN**.

---

## 0. Before you start: which Xcode to archive with

`xcode-select` on this Mac points at **Xcode-beta**, and Apple's upload validation
rejects beta-toolchain builds ("Unsupported SDK or Xcode version"). `/Applications/Xcode.app`
is the release Xcode (27.1), so archive with that instead — no need to change `xcode-select`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PartyRelay.xcodeproj -scheme PartyRelay \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/PartyRelay 1.3 (9).xcarchive" \
  archive
```

Archiving to that path makes it show up in Xcode → Window → Organizer, where
**Distribute App** re-signs it with the distribution certificate (the command line
signs with the development one, which is expected).

---

## 1. App Information (one-time, not localized)

| Field | Value |
|---|---|
| Bundle ID | `com.partyrelay.app` |
| SKU (internal, never shown publicly) | `partyrelay-ios-2026` ⬜ *(any unique string works — change if you already used this)* |
| Primary category | Games |
| Secondary category | Games → Family (or Games → Board) |
| Content rights | **No**, this app does not contain, show, or access third-party copyrighted content |
| Age rating questionnaire | Answer **None / No** to every category — no violence, no mature/suggestive themes, no gambling, no horror, no unrestricted web access, no user-generated content shared with others, no ads that could serve mature content. Result: **4+** |

## 2. Pricing and Availability

| Field | Value |
|---|---|
| Price | Free |
| Availability | All countries/regions (or narrow it down yourself) ⬜ |

## 3. App Privacy (the "nutrition label")

The app makes **zero network requests** and has **no analytics/ad SDKs**. It only
stores team names, Take Turns player names/avatars, settings and a language preference
locally via `UserDefaults` — nothing leaves the device.

| Question | Answer |
|---|---|
| Does this app collect data? | **No, this app does not collect any data.** |
| Data types | N/A — none collected |
| Tracking (per App Tracking Transparency) | No tracking |

A `PrivacyInfo.xcprivacy` manifest has been added to the project (declaring the
`UserDefaults` "required reason" API with reason code `CA92.1`, since Apple now
requires this be declared even for on-device-only storage). This is already done in
code — nothing to fill in here.

## 4. Version Information

| Field | Value |
|---|---|
| Version number | `1.3` (set as `MARKETING_VERSION` in the Xcode project) |
| Build number | `9` (set as `CURRENT_PROJECT_VERSION`) — builds up to 8 went to 1.0–1.2 |
| Copyright | `© 2026 [YOUR NAME OR COMPANY]` ⬜ **FILL IN** the legal name |
| Routing App Coverage File | Not applicable |
| Export compliance (encryption) | **No** — app uses no non-exempt encryption (no networking at all). Already declared in the build (`ITSAppUsesNonExemptEncryption = NO`), so App Store Connect won't ask |

### Screenshots (per device size required)

Use `AppStoreConnect/PromoImages/`:
- `tilt/en/` and `tilt/zh-Hans/` — 3 dark-background hero slides (recommended as your
  primary screenshot set; real app UI shown inside a tilted phone mockup)
- `hero/en/` and `hero/zh-Hans/` — 4 flat-illustration alternative hero slides
- `feature/en/` and `feature/zh-Hans/` — 5 feature-highlight slides (games/wheel, Open
  Buzz, catch-up, privacy guard, recap)
- `hero-photo/` — 1 photoreal composite (real screenshot inside an AI-generated photo
  of someone holding a phone at a party)

All are 1290×2796 (iPhone 6.7"-class), which App Store Connect accepts directly. Pick
whichever 3–10 you like best per language and upload in your preferred order (put the
strongest one first — it's what shows in search results).

**New in 1.3:** none of the slides above show the mode picker or Take Turns yet. Raw
captures of those screens are in `Screenshots/modes-*-{en,zh}.png` (mode picker, player
setup, the name ring, handoff recap, results). They are 1206×2622 (iPhone 17 Pro), which
the required 6.9"/6.5" slot doesn't take — re-capture them on a Pro Max simulator with the
same `SCREENSHOT_MODE` values (`menu`, `rotationhome`, `rotation`, `rotationhandoff`,
`rotationresult`), or run them through the promo pipeline, if you want them in the listing.

### App Icon

Already present: `PartyRelay/Assets.xcassets/AppIcon.appiconset/AppIcon.png` at the
required 1024×1024, single-size universal icon format. Nothing to do here.

---

## 5. Localized Store Listing — English

**App Name** *(30 char max)*
```
PartyRelay: Team Party Game
```

**Subtitle** *(30 char max)*
```
Charades, Draw & Guess & more
```

**Promotional Text** *(170 char max, editable anytime without a new build)*
```
Two teams, one quick round, or take turns where everyone scores for themselves. Spin for Say & Guess, Draw & Guess, Lip Reading, Charades or Hall of Fame.
```

**Description** *(4000 char max)*
```
PartyRelay turns any get-together into a game night — no extra equipment, no account, no ads, no internet required. Pass one phone around and race the clock: as two teams, as one group, or taking turns with everyone scoring for themselves.

THREE WAYS TO PLAY
Team Battle — split into two teams and spin the wheel to pick a game. Both teams play the exact same round, one after the other — whoever guesses more words wins the round and takes the point. Simple to explain in ten seconds, chaotic and hilarious in practice.
Quick Mode — not enough people for two teams? No teams, no scores: one spin, one round, then a tally of how many you got.
Take Turns — everyone plays for themselves. Add the players and the phone goes round the circle: each person spins for a game and gives the clues while everyone else guesses. There's no "got it" button — the other players' names sit around the word, and tapping whoever guessed gives a point to them and to the clue-giver. When everyone has had a turn, the leaderboard shows who's on top.

FIVE GAMES ON THE WHEEL
Say & Guess — describe the word out loud (without saying the word itself) while everyone shouts out guesses.
Draw & Guess — sketch it on the in-app canvas, no letters or numbers allowed, and let the others guess from your doodle.
Lip Reading — mouth the word with zero sound and see if anyone can read your lips.
Charades — act it out with gestures alone.
Hall of Fame (Team Battle) — both teams play at once with no timer: each team is secretly given a famous name, then you take turns asking yes/no questions until someone cracks the other team's name.

OPEN BUZZ
In Team Battle, land on this wheel sector and things get spicy: it picks one of the timed games above, but now the OTHER team can jump in and steal a point for anything your team misses. Nobody gets to zone out on their turn.

BUILT FOR CLOSE, FUN MATCHES
PartyRelay quietly keeps blowouts from ruining the night — a team that falls behind gets a friendly boost (more time, extra skips) so the game stays fun for everyone until the last round, without ever feeling unfair or obvious about it.

THOUGHTFUL EXTRAS
• A recap after every turn shows exactly which words came up (and in Take Turns, who guessed each one), so arguments about "wait, was that really the word?" settle themselves.
• Pause any turn: restart it with fresh words if something went wrong, or end the game.
• Optional privacy guard: hold the phone up to see the word, lay it flat to hide it automatically — perfect for passing hand to hand mid-round.
• Fully bilingual: switch between English and Simplified Chinese instantly, with word lists written natively for each language (not machine-translated).
• Thousands of hand-picked words per game — every entry is a real word, idiom, saying or title, so nobody gets stuck on something that isn't actually a thing.
• Customize team names, player names and avatars, round count, turn length, haptics, and sound.

NO CATCH
PartyRelay is completely offline. No sign-up, no ads, no in-app purchases, no data collection, no network access of any kind. Just open it and start playing.

Perfect for family game night, parties, icebreakers, road trips, and any time a timer and a few friends sound more fun than a phone in everyone's own hands.
```

**Keywords** *(100 char max, comma-separated, no spaces)*
```
party,charades,pictionary,drawing,guess,team,family,friends,offline,group,words,icebreaker,board
```

**What's New in This Version** *(1.3)*
```
NEW: TAKE TURNS
A third way to play, where everyone scores for themselves. Add your players — give each a name and an avatar, drag them into seating order — and the phone goes round the circle, starting from someone picked at random. On your turn you spin for a game and give the clues. The other players' names sit around the word: tap whoever guessed, and you both get a point. Once everyone has had a go, a leaderboard shows who's on top, split into acting and guessing points.

PICK A MODE ON THE HOME SCREEN
Team Battle, Quick Mode and Take Turns are now three cards on the home screen. Quick Mode no longer hides in Settings.

PAUSE
The in-game Home button is now Pause. It stops the clock, and lets you restart the current turn with fresh words (handy after a mis-tap) or end the game.

POLISH
• Tidier layouts on larger screens.
• The handoff button now just says Start.
```

**Support URL**
```
https://github.com/alanfeiyuchang/party-relay/issues
```
⬜ Replace with a dedicated support page or `mailto:` link if you'd rather not use GitHub Issues directly.

**Marketing URL** *(optional)*
```
https://github.com/alanfeiyuchang/party-relay
```

---

## 6. Localized Store Listing — Simplified Chinese (简体中文)

**App Name** *(30 字符以内)*
```
派对接力 PartyRelay
```

**Subtitle**
```
你画我猜·你说我猜·动作模仿
```

**Promotional Text**
```
两队对战、一局快玩，或者轮流表演、各记各分。转盘挑战你说我猜、你画我猜、唇语猜词、肢体模仿和名人堂，一部手机就能玩。
```

**Description**
```
🎉 派对接力能让任何聚会秒变游戏之夜——不用额外道具，不用注册账号，没有广告，全程不联网。一部手机轮流传递，比拼谁能在限时内猜对更多词：可以两队对战，可以大家一起快玩一局，也可以轮流表演、各记各分。

三种模式
⚔️ 对战模式——分成两队，转动转盘随机决定本轮玩法，两队依次挑战同一个玩法，猜对更多词的一方赢下本轮得分。十秒就能讲明白规则，玩起来却笑到停不下来。
⚡️ 快速模式——人不够分成两队？不分队、不记分，转一次盘只打一局，打完直接看猜对了几个。
🔄 轮流模式——每个人各自为战。填好玩家，手机按顺序轮着传：轮到谁，谁就转盘选玩法、负责表演，其他人一起猜。屏幕上没有「猜对」按钮，其他人的名字围在词的周围，谁猜对了就点谁，表演者和猜对的人各得 1 分。所有人都表演过一次后，排行榜揭晓谁最厉害。

五种玩法任你转
🗣️ 你说我猜——用语言描述词语（不能说出词语本身），其他人抢答。
🎨 你画我猜——在画板上画出词语（不能写字、数字），其他人根据画面猜。
🤐 唇语猜词——完全不出声，只靠口型让大家读出词语。
🕺 肢体模仿——只用动作和表情表演，不能发出声音。
🌟 名人堂（对战模式）——两队同时进行、不计时：各自拿到一个名人的名字，轮流互相提问，先猜中对方名字的一队获胜。

⚡️ 开放抢答
对战模式下转到这个特殊扇区会更刺激：系统会再转一次选出一个计时玩法，但这一轮对方队伍也能随时抢答偷分——谁都别想在自己回合里划水。

贴心小细节
• 每一轮结束都会回顾刚才出现过的所有词语（轮流模式还会标出每个词是谁猜中的），"这个真的是这个词吗"的争论从此终结。
• 随时暂停：出了岔子可以重开这一小局、换一批新词，也可以直接结束游戏。
• 可选防偷看模式：手机立起来才显示词语，放平自动隐藏，非常适合手机在人群中传递时使用。
• 中英文双语完整支持，随时一键切换，词库均为各语言原创手写，而非机器翻译。
• 每种玩法都有上千条精选词语，全部是真实存在的词、成语、俗语或作品名，不会冒出让人一脸问号的怪东西。
• 队伍名称、玩家名字和头像、总轮数、每轮时长、震动和音效都可以自由调整。

没有套路
派对接力完全离线运行，无需注册、没有广告、没有内购、不收集任何数据，也没有任何形式的联网行为。打开就能玩。

无论是家庭聚会、朋友派对、破冰活动还是自驾游途中，几个人加一个计时器，可能比每个人各自刷手机有趣多了。
```

**Keywords**
```
派对,聚会,你画我猜,你说我猜,猜词,团队,家庭,朋友,离线,破冰,桌游,组队,聚会游戏
```

**What's New in This Version** *(1.3)*
```
新增：轮流模式
第三种玩法，每个人各自为战、各记各分。填好玩家——每人可以起名字、选头像，拖动调整顺序——开局随机抽一个人先来，之后手机按顺序轮着传。轮到你时，你转盘选玩法、负责表演；其他人的名字围在词的周围，谁猜对了就点谁，你们俩各加 1 分。所有人都表演过一次后，排行榜揭晓名次，还会分开显示表演分和猜词分。

主页直接选模式
对战模式、快速模式、轮流模式现在是主页上的三张卡片，快速模式不用再去设置里找了。

暂停
游戏中的「主页」按钮改成了「暂停」：点一下计时就停，可以重开这一小局、换一批新词（点错了正好用得上），也可以直接结束游戏。

细节打磨
• 大屏幕上的排版更整齐。
• 交接页的按钮现在就叫「开始」。
```

**Support URL**
```
https://github.com/alanfeiyuchang/party-relay/issues
```

**Marketing URL** *(optional)*
```
https://github.com/alanfeiyuchang/party-relay
```

---

## 7. App Review Information

| Field | Value |
|---|---|
| Sign-in required? | **No** — app has no accounts/login |
| Demo account | Not applicable |
| Contact — First/Last name | ⬜ **FILL IN** |
| Contact — Phone number | ⬜ **FILL IN** |
| Contact — Email | ⬜ **FILL IN** (defaults to your Apple ID email if left blank, but Apple recommends filling it in) |
| Notes for reviewer | See suggested text below — paste as-is or edit |

**Suggested reviewer notes:**
```
PartyRelay is an offline, pass-the-phone party game — there is no account/sign-in, no
network access, and no server component to test. The home screen offers three modes:

- Team Battle: tap it, then "Start Game", spin the wheel, and tap through the handoff
  screen to play a round (Say & Guess / Draw & Guess / Lip Reading / Charades /
  Hall of Fame).
- Quick Mode: one round with no teams.
- Take Turns (new in 1.3): set the player count, tap "Start Game", and the phone is
  passed from player to player. During a turn, the other players' names surround the
  word; tapping a name scores a point for that player and the performer.

The "Pause" button in the top-left corner of any game screen offers Restart this turn /
End game / Resume. All word content is bundled locally in the app; nothing is fetched
remotely.
```

## 8. Version Release

| Field | Value |
|---|---|
| Release | Choose "Manually release this version" if you want to control the exact go-live moment, or "Automatically release" to go live right after approval ⬜ *(your call)* |
| Phased release | Optional — spreads the rollout over 7 days; recommended for a first release but not required |

---

## Pre-submit checklist — 1.3 update

Sections 1–3 (app info, pricing, privacy) carry over untouched. For an update you only
need:

- [ ] Archive with the release **Xcode.app**, not Xcode-beta (see section 0) — build `1.3 (9)`
- [ ] Paste the new **What's New** text, both languages (section 5 / 6)
- [ ] Update the **Description** in both languages — it now describes the three modes,
      Take Turns and the Pause menu, and no longer says Quick Mode lives in Settings
- [ ] Update the **Promotional Text** in both languages (editable without a new build)
- [ ] Screenshots: the current set still shows real screens, but none of the new mode
      picker or Take Turns — see "New in 1.3" under Screenshots (section 4) if you want
      to add them
- [ ] Paste the updated reviewer notes (section 7) — they walk through the three modes

Unchanged, nothing to do: age rating, `PrivacyInfo.xcprivacy`, app icon, SKU, bundle ID,
pricing, privacy answers, export compliance (declared in the build).

### Shelved since 1.1: Emoji Manager

😜 Emoji Manager is hidden in this release — one line in `Models.swift`:

```swift
static let hidden: Set<GameKind> = [.emojiCode]   // empty this set to bring it back
```

Its view, both word banks and all its strings are still in the app, so it can come back
in a later version without any rework. The support page at `docs/index.html` no longer
lists it either. If you re-enable it, put it back on both.
