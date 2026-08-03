# Rejection response — 1.0 (4), submission 3b708c85-48d5-4d18-91aa-f89b1b46ff75

Reviewed 2026-08-02 on iPad Air 11-inch (M3). Two issues: **1.1 Safety – Objectionable
Content** (in metadata, description field) and **1.5 Safety** (Support URL).

---

## Issue 2 first — Guideline 1.5, Support URL (unambiguous, fully fixable)

Apple rejects `github.com/<user>/<repo>/issues` as a Support URL: an issue tracker is a
developer tool, not an end-user support page. They want a plain webpage with a way to
ask questions and get help.

**Fix (done in this repo):** `docs/index.html` — a bilingual support page with a contact
email and a stated 2-business-day response time, a FAQ, and the privacy policy.

**To publish:**

1. Commit and push `docs/` to `main`.
2. GitHub → repo **Settings → Pages** → Source: *Deploy from a branch* → Branch: `main`,
   Folder: `/docs` → **Save**.
3. Wait ~1 minute, then open <https://alanfeiyuchang.github.io/party-relay/> and confirm
   it loads (not a 404 — Apple will click it).
4. App Store Connect → **App Information / Version** → set
   **Support URL** = `https://alanfeiyuchang.github.io/party-relay/`
   and **Privacy Policy URL** = `https://alanfeiyuchang.github.io/party-relay/#privacy`.

The repo must stay **public** for the Pages site to be reachable.

---

## Issue 1 — Guideline 1.1, objectionable content in the description

Apple's notice does not quote the offending words, and this rejection template is
usually triggered by a specific phrase in the description field. **Ask them which one**
(reply draft below) — resubmitting blind risks the same rejection plus escalation, which
their "Resubmitting this app without making the appropriate changes… will result in the
same or additional App Review Guideline violations" paragraph is explicitly warning about.

While waiting, the description in this repo has been scrubbed of the phrases most likely
to have tripped it. Changes made to `en/description.txt`:

| Before | After | Why |
|---|---|---|
| "Land on this wheel sector and **things get spicy**" | "…and **the stakes go up**" | "spicy" is common slang for sexual/adult content and is a frequent 1.1 metadata flag |
| "Simple to explain in ten seconds, **chaotic and hilarious** in practice" | "…and **fun for the whole group**" | removes edgy framing for a 4+ title |
| "**steal** a point" | "**take** a point" | neutral wording |
| "keeps **blowouts** from ruining the night" | "keeps **one-sided scores** from…" | neutral wording |
| "Thousands of hand-picked words" | "Thousands of hand-picked, **family-friendly** words" | states the 4+ positioning up front |
| four games listed | six games listed (adds Emoji Manager, Hall of Fame) | metadata was stale vs. build 4 |

`zh-Hans/description.txt` got the matching edits (`更刺激` → `更紧张`, `抢答偷分` →
`抢答得分`, added `老少皆宜` / `内容适合全家一起玩`, and the two new modes).

### Check these too before resubmitting

The App Store Connect copy for 1.0 (4) may differ from what is in this repo — the repo
copy predates the Emoji Manager / Hall of Fame builds. Read the **live** description,
subtitle, promotional text, keywords, and What's New in App Store Connect and look for:

- Any drinking / dare / punishment / forfeit framing (`酒`, `干杯`, `惩罚`, `大冒险`,
  "drinking game", "truth or dare") — the single most common 1.1 trigger for party games.
- Any suggestion that the drawing canvas or emoji field lets players create *whatever
  they want* — Apple reads unmoderated content creation as a 1.1 risk. Describe them as
  tools for drawing/spelling **the given word**, which is what they actually are.
- Named real people in the marketing copy (Hall of Fame). Keep it generic —
  "a widely known person or fictional character" — and never list real names in metadata.
- Screenshots are metadata too. `AppStoreConnect/PromoImages/hero-photo/` is an
  AI-generated party photo with blurred figures in the background who appear to be
  holding bottles. It reads as ambiguous, but for a 4+ title it is not worth defending —
  drop that screenshot and use the `tilt/` or `feature/` sets, which are pure UI.

---

## Resolution Center reply draft (send before resubmitting)

> Hello,
>
> Thank you for the review.
>
> **Guideline 1.5 — Support URL:** we have replaced the GitHub Issues link with a
> dedicated support page: https://alanfeiyuchang.github.io/party-relay/ — it provides a
> support email address with a stated response time, a FAQ covering gameplay and
> settings, and our privacy policy. The Support URL in App Store Connect has been
> updated accordingly.
>
> **Guideline 1.1 — Objectionable content in the description:** we want to correct this
> completely, but we are not sure which part of the description was flagged. PartyRelay
> is an offline, pass-the-phone word-guessing game for two teams (say it, draw it, mouth
> it, act it out, spell it in emoji, or guess a well-known name). It contains no
> references to alcohol, drugs, gambling, sexual content, violence, or dares/forfeits,
> and there is no user-generated content shared between users or over a network — the app
> makes no network requests at all. We have already revised the description to remove
> informal phrasing that could be read the wrong way (for example "things get spicy",
> which we meant as "the round gets more competitive", is now "the stakes go up").
>
> Could you please point us to the specific term or image in the description that raised
> the concern? We will remove it right away. If it would help, we are happy to send the
> full revised description text here for confirmation before we resubmit.
>
> Thank you,
> Feiyu Chang

---

## Order of operations

1. Push `docs/`, enable GitHub Pages, verify the URL loads.
2. Update Support URL + Privacy Policy URL in App Store Connect.
3. Paste the revised descriptions (both languages) into App Store Connect.
4. Remove the `hero-photo` screenshot from the screenshot sets.
5. Send the Resolution Center reply asking for the specific 1.1 term.
6. Resubmit once they answer — or after 2–3 days of no reply, resubmit with the revised
   metadata and a note in App Review Notes summarizing the changes.
