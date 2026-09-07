# PartyRelay — App Store Connect Submission Doc

Everything needed to fill out App Store Connect for PartyRelay, in one place. Sections
follow the order you'll hit them in App Store Connect's UI. Anything you need to type
in yourself (not derivable from the code) is marked **⬜ FILL IN**.

---

## 0. Before you start: which Xcode to archive with

`xcode-select` on this Mac points at **Xcode 27 beta**, and Apple's upload validation
rejects beta-toolchain builds ("Unsupported SDK or Xcode version"). Xcode 26.6 is also
installed, so archive with that instead — no need to change `xcode-select`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project PartyRelay.xcodeproj -scheme PartyRelay \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$HOME/Library/Developer/Xcode/Archives/$(date +%Y-%m-%d)/PartyRelay 1.1 (6).xcarchive" \
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
| Version number | `1.1` (set as `MARKETING_VERSION` in the Xcode project) |
| Build number | `6` (set as `CURRENT_PROJECT_VERSION`) — 1.0 shipped as build 4 |
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
Two teams, one phone, zero setup. Spin for Say & Guess, Draw & Guess, Lip Reading, Charades or Hall of Fame — or switch on Quick Mode for one round with no teams.
```

**Description** *(4000 char max)*
```
🎉 PartyRelay turns any get-together into a game night — no extra equipment, no account, no ads, no internet required. Split into two teams, pass one phone back and forth, and race the clock.

HOW IT WORKS
Spin the wheel to pick a game. Both teams play the exact same round, one after the other — whoever guesses more words wins the round and takes the point. Simple to explain in ten seconds, chaotic and hilarious in practice.

FIVE WAYS TO PLAY
🗣️ Say & Guess — describe the word out loud (without saying the word itself) while your team shouts out guesses.
🎨 Draw & Guess — sketch it on the in-app canvas, no letters or numbers allowed, teammates guess from your doodle.
🤐 Lip Reading — mouth the word with zero sound and see if your team can read your lips.
🕺 Charades — act it out with gestures alone.
🌟 Hall of Fame — both teams play at once with no timer: each team is secretly given a famous name, then you take turns asking yes/no questions until someone cracks the other team's name.

⚡️ OPEN BUZZ
Land on this wheel sector and things get spicy: it picks one of the timed games above, but now the OTHER team can jump in and steal a point for anything your team misses. Nobody gets to zone out on their turn.

⚡️ QUICK MODE
Not enough people to split into two teams? Turn on Quick Mode: no teams, no scores — one spin, one round, then a tally of how many you got. Turn it back off and everything returns to the full two-team match.

BUILT FOR CLOSE, FUN MATCHES
PartyRelay quietly keeps blowouts from ruining the night — a team that falls behind gets a friendly boost (more time, extra skips) so the game stays fun for everyone until the last round, without ever feeling unfair or obvious about it.

THOUGHTFUL EXTRAS
• A recap after every round shows exactly which words came up, so arguments about "wait, was that really the word?" settle themselves.
• Optional privacy guard: hold the phone up to see the word, lay it flat to hide it automatically — perfect for passing hand to hand mid-round.
• Fully bilingual: switch between English and Simplified Chinese instantly, with word lists written natively for each language (not machine-translated).
• Thousands of hand-picked words per game — every entry is a real word, idiom, saying or title, so nobody gets stuck on something that isn't actually a thing.
• Customize team names and emoji, round count, turn length, haptics, and sound — all from one settings screen.

NO CATCH
PartyRelay is completely offline. No sign-up, no ads, no in-app purchases, no data collection, no network access of any kind. Just open it and start playing.

Perfect for family game night, parties, icebreakers, road trips, and any time two teams and a timer sound more fun than a phone in everyone's own hands.
```

**Keywords** *(100 char max, comma-separated, no spaces)*
```
party,charades,pictionary,drawing,guess,team,family,friends,offline,group,words,icebreaker,board
```

**What's New in This Version** *(1.1)*
```
NEW: QUICK MODE
Not enough people for two teams? Turn on Quick Mode in Settings — no teams, no scores, just one spin and one round, then a tally of how many words you got.

REBUILT WORD BANKS
• Every word bank was rewritten and cleaned out. Obscure idioms, hard-to-place names and odd descriptive phrases that were never really "words" are gone — what's left is real words, common idioms, well-known sayings, and titles people actually recognise.
• The hidden difficulty ramp is gone too. Each game now draws from a single pool, sized to how fast that game plays, so easier games have far more words and matches stay fresh much longer.
• The English word banks grew from 120 entries per game to as many as 1,157.

POLISH
• Two games got new colours so the wheel never looks like it's naming a team.
• Buttons that call out a team now wear that team's colour.
• Tidier home screen.
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
两队对战，一部手机轮流玩，无需任何准备。转盘挑战你说我猜、你画我猜、唇语猜词、肢体模仿和名人堂；人不够分队？打开快速模式，一局定胜负。
```

**Description**
```
🎉 派对接力能让任何聚会秒变游戏之夜——不用额外道具，不用注册账号，没有广告，全程不联网。分成两队，一部手机轮流传递，比拼谁能在限时内猜对更多词。

玩法很简单
转动转盘随机决定本轮玩法，两队依次挑战同一个玩法——猜对更多词的一方赢下本轮得分。十秒就能讲明白规则，玩起来却笑到停不下来。

五种玩法任你转
🗣️ 你说我猜——用语言描述词语（不能说出词语本身），队友抢答。
🎨 你画我猜——在画板上画出词语（不能写字、数字），队友根据画面猜。
🤐 唇语猜词——完全不出声，只靠口型让队友读出词语。
🕺 肢体模仿——只用动作和表情表演，不能发出声音。
🌟 名人堂——两队同时进行、不计时：各自拿到一个名人的名字，轮流互相提问，先猜中对方名字的一队获胜。

⚡️ 开放抢答
转到这个特殊扇区会更刺激：系统会再转一次选出一个计时玩法，但这一轮对方队伍也能随时抢答偷分——谁都别想在自己回合里划水。

⚡️ 快速模式
人不够分成两队？在设置里打开快速模式：不分队、不记分，转一次盘只打一局，打完直接看猜对了几个。关掉就恢复成完整的两队赛制。

始终势均力敌，比赛更好玩
派对接力会悄悄帮落后的一方"追分"——多给一点时间、多几次跳过机会，让比赛在最后一轮前都保持悬念，而且完全不会让人察觉是系统在刻意调整。

贴心小细节
• 每轮结束后的记分板会回顾双方本轮出现过的所有词语，"这个真的是这个词吗"的争论从此终结。
• 可选防偷看模式：手机立起来才显示词语，放平自动隐藏，非常适合手机在人群中传递时使用。
• 中英文双语完整支持，随时一键切换，词库均为各语言原创手写，而非机器翻译。
• 每种玩法都有上千条精选词语，全部是真实存在的词、成语、俗语或作品名，不会冒出让人一脸问号的怪东西。
• 队伍名称、表情、总轮数、每轮时长、震动和音效都可以在设置里自由调整。

没有套路
派对接力完全离线运行，无需注册、没有广告、没有内购、不收集任何数据，也没有任何形式的联网行为。打开就能玩。

无论是家庭聚会、朋友派对、破冰活动还是自驾游途中，两队对战加一个计时器，可能比每个人各自刷手机有趣多了。
```

**Keywords**
```
派对,聚会,你画我猜,你说我猜,猜词,团队,家庭,朋友,离线,破冰,桌游,组队,聚会游戏
```

**What's New in This Version** *(1.1)*
```
新增：快速模式
人不够分成两队？在设置里打开快速模式——不分队、不记分，转一次盘只打一局，打完直接看这一局猜对了几个。

词库重做
• 所有词库整体重写清洗。生僻成语、不好联想的人名，还有那些其实算不上"词"的描述性短句，全部删掉；留下的都是固定词、常见成语、广为人知的俗语和作品名。
• 去掉了随轮次悄悄爬升的难度分档。每个玩法现在只有一个词池，按这个玩法过词的快慢来定大小——越好猜的玩法词越多，玩很多场也不容易重复。
• 英文词库从每个玩法 120 条扩到最多 1157 条。

细节打磨
• 两个玩法换了配色，转盘不会再看起来像在指定某一队。
• 点名了队伍的按钮会穿上那支队的队色。
• 主页排版更清爽。
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
handoff screen to play a round (Say & Guess / Draw & Guess / Lip Reading / Charades /
Hall of Fame). All word content is bundled locally in the app; nothing is fetched
remotely.

New in 1.1: a "Quick Mode" toggle in Settings turns the match into a single no-teams
round — flip it on and tap "Start Game" to see it.
```

## 8. Version Release

| Field | Value |
|---|---|
| Release | Choose "Manually release this version" if you want to control the exact go-live moment, or "Automatically release" to go live right after approval ⬜ *(your call)* |
| Phased release | Optional — spreads the rollout over 7 days; recommended for a first release but not required |

---

## Pre-submit checklist — 1.1 update

Sections 1–3 (app info, pricing, privacy) carry over from 1.0 untouched. For an
update you only need:

- [ ] Archive with **Xcode 26.6**, not the 27 beta (see section 0) — build `1.1 (6)`
- [ ] Paste the new **What's New** text, both languages (section 5 / 6)
- [ ] Update the **Description** in both languages — it now lists five games, adds Quick
      Mode, and no longer claims three difficulty tiers
- [ ] Update the **Promotional Text** in both languages (editable without a new build)
- [ ] Screenshots: the current set still matches the app. Emoji Manager is shelved in
      1.1, so **drop any screenshot showing it** if your uploaded set includes one
- [ ] Reviewer notes now mention Quick Mode — paste the updated text (section 7)

Unchanged from 1.0, nothing to do: age rating, `PrivacyInfo.xcprivacy`, app icon, SKU,
bundle ID, pricing, privacy answers.

### Shelved in 1.1: Emoji Manager

😜 Emoji Manager is hidden in this release — one line in `Models.swift`:

```swift
static let hidden: Set<GameKind> = [.emojiCode]   // empty this set to bring it back
```

Its view, both word banks and all its strings are still in the app, so it can come back
in a later version without any rework. The support page at `docs/index.html` no longer
lists it either. If you re-enable it, put it back on both.
