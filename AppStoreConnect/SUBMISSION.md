# PartyRelay — App Store Connect Submission Doc

Everything needed to fill out App Store Connect for PartyRelay, in one place. Sections
follow the order you'll hit them in App Store Connect's UI. Anything you need to type
in yourself (not derivable from the code) is marked **⬜ FILL IN**.

---

## 0. Before you start: build toolchain blocker

Your Mac is on macOS 27 beta with only Xcode 27 beta installed. Apple's upload
validation currently rejects beta-toolchain builds ("Unsupported SDK or Xcode
version") until Xcode 27 reaches a Release Candidate. Either wait for that RC, or
build/archive from a Mac on a stable macOS + stable Xcode. This blocks the *upload*
step only — everything else below can be prepared right now.

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
stores team names/settings and a language preference locally via `UserDefaults` —
nothing leaves the device.

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
| Version number | `1.0` (already set as `MARKETING_VERSION` in the Xcode project) |
| Build number | `1` (already set as `CURRENT_PROJECT_VERSION`) |
| Copyright | `© 2026 [YOUR NAME OR COMPANY]` ⬜ **FILL IN** the legal name |
| Routing App Coverage File | Not applicable |
| Export compliance (encryption) | **No** — app uses no non-exempt encryption (no networking at all) |

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
Two teams, one phone, zero setup. Spin for Say & Guess, Draw & Guess, Lip Reading, or Charades — plus an Open Buzz twist that lets the other team steal points.
```

**Description** *(4000 char max)*
```
🎉 PartyRelay turns any get-together into a game night — no extra equipment, no account, no ads, no internet required. Split into two teams, pass one phone back and forth, and race the clock.

HOW IT WORKS
Spin the wheel to pick a game. Both teams play the exact same round, one after the other — whoever guesses more words wins the round and takes the point. Simple to explain in ten seconds, chaotic and hilarious in practice.

FOUR WAYS TO PLAY
🗣️ Say & Guess — describe the word out loud (without saying the word itself) while your team shouts out guesses.
🎨 Draw & Guess — sketch it on the in-app canvas, no letters or numbers allowed, teammates guess from your doodle.
🤐 Lip Reading — mouth the word with zero sound and see if your team can read your lips.
🕺 Charades — act it out with gestures alone.

⚡️ OPEN BUZZ
Land on this wheel sector and things get spicy: it picks one of the four games above, but now the OTHER team can jump in and steal a point for anything your team misses. Nobody gets to zone out on their turn.

BUILT FOR CLOSE, FUN MATCHES
PartyRelay quietly keeps blowouts from ruining the night — a team that falls behind gets a friendly boost (more time, extra skips) so the game stays fun for everyone until the last round, without ever feeling unfair or obvious about it.

THOUGHTFUL EXTRAS
• A recap after every round shows exactly which words came up, so arguments about "wait, was that really the word?" settle themselves.
• Optional privacy guard: hold the phone up to see the word, lay it flat to hide it automatically — perfect for passing hand to hand mid-round.
• Fully bilingual: switch between English and Simplified Chinese instantly, with word lists written natively for each language (not machine-translated).
• Thousands of hand-picked words across three difficulty tiers per game, so matches stay fresh for group after group.
• Customize team names and emoji, round count, turn length, haptics, and sound — all from one settings screen.

NO CATCH
PartyRelay is completely offline. No sign-up, no ads, no in-app purchases, no data collection, no network access of any kind. Just open it and start playing.

Perfect for family game night, parties, icebreakers, road trips, and any time two teams and a timer sound more fun than a phone in everyone's own hands.
```

**Keywords** *(100 char max, comma-separated, no spaces)*
```
party,charades,pictionary,drawing,guess,team,family,friends,offline,group,words,icebreaker,board
```

**What's New in This Version**
```
🎉 Welcome to PartyRelay!

• Four party games in one wheel: Say & Guess, Draw & Guess, Lip Reading, and Charades
• Open Buzz wheel modifier lets the opposing team steal points
• Smart catch-up system keeps close matches close, without ever calling it out
• Round-by-round word recap on the scoreboard
• Optional privacy guard using motion sensing
• Full English and Simplified Chinese localization
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
两队对战，一部手机轮流玩，无需任何准备。转动转盘挑战你说我猜、你画我猜、唇语猜词和肢体模仿，还有能让对方偷分的"开放抢答"玩法。
```

**Description**
```
🎉 派对接力能让任何聚会秒变游戏之夜——不用额外道具，不用注册账号，没有广告，全程不联网。分成两队，一部手机轮流传递，比拼谁能在限时内猜对更多词。

玩法很简单
转动转盘随机决定本轮玩法，两队依次挑战同一个玩法——猜对更多词的一方赢下本轮得分。十秒就能讲明白规则，玩起来却笑到停不下来。

四种玩法任你转
🗣️ 你说我猜——用语言描述词语（不能说出词语本身），队友抢答。
🎨 你画我猜——在画板上画出词语（不能写字、数字），队友根据画面猜。
🤐 唇语猜词——完全不出声，只靠口型让队友读出词语。
🕺 肢体模仿——只用动作和表情表演，不能发出声音。

⚡️ 开放抢答
转到这个特殊扇区会更刺激：系统会再转一次选出一个真实玩法，但这一轮对方队伍也能随时抢答偷分——谁都别想在自己回合里划水。

始终势均力敌，比赛更好玩
派对接力会悄悄帮落后的一方"追分"——多给一点时间、多几次跳过机会，让比赛在最后一轮前都保持悬念，而且完全不会让人察觉是系统在刻意调整。

贴心小细节
• 每轮结束后的记分板会回顾双方本轮出现过的所有词语，"这个真的是这个词吗"的争论从此终结。
• 可选防偷看模式：手机立起来才显示词语，放平自动隐藏，非常适合手机在人群中传递时使用。
• 中英文双语完整支持，随时一键切换，词库均为各语言原创手写，而非机器翻译。
• 每种玩法都有上千条精选词语，分为三档内部难度，场次再多也不会腻。
• 队伍名称、表情、总轮数、每轮时长、震动和音效都可以在设置里自由调整。

没有套路
派对接力完全离线运行，无需注册、没有广告、没有内购、不收集任何数据，也没有任何形式的联网行为。打开就能玩。

无论是家庭聚会、朋友派对、破冰活动还是自驾游途中，两队对战加一个计时器，可能比每个人各自刷手机有趣多了。
```

**Keywords**
```
派对,聚会,你画我猜,你说我猜,猜词,团队,家庭,朋友,离线,破冰,桌游,组队,聚会游戏
```

**What's New in This Version**
```
🎉 欢迎来到派对接力！

• 一个转盘四种玩法：你说我猜、你画我猜、唇语猜词、肢体模仿
• "开放抢答"转盘修饰符，让对方也能偷分
• 智能追分机制悄悄让比赛保持悬念，绝不明说
• 记分板新增每轮词语回顾
• 可选的运动感应防偷看模式
• 完整支持中文和英文双语
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
PartyRelay is an offline, pass-the-phone party game for two teams — there is no
account/sign-in, no network access, and no server component to test. To see the core
loop: tap "Start Game" on the home screen, spin the wheel, then tap through the
handoff screen to play a round (Say & Guess / Draw & Guess / Lip Reading / Charades).
All word content is bundled locally in the app; nothing is fetched remotely.
```

## 8. Version Release

| Field | Value |
|---|---|
| Release | Choose "Manually release this version" if you want to control the exact go-live moment, or "Automatically release" to go live right after approval ⬜ *(your call)* |
| Phased release | Optional — spreads the rollout over 7 days; recommended for a first release but not required |

---

## Quick pre-submit checklist

- [ ] Xcode 27 reaches RC (or switch to a stable Mac/Xcode) so the archive actually uploads
- [ ] Fill in Copyright holder name (`other_metadata.txt` placeholder, both languages)
- [ ] Fill in App Review contact name/phone/email
- [ ] Decide on Support URL (GitHub Issues is fine, or swap for something else)
- [ ] Pick your screenshot set from `PromoImages/` (tilt/ recommended) — 3–10 per language
- [ ] Confirm SKU doesn't collide with a prior app in your account
- [ ] Double check age rating questionnaire answers match "no objectionable content" above
- [ ] `PrivacyInfo.xcprivacy` — already added to the project, no action needed
- [ ] App icon — already present at 1024×1024, no action needed
