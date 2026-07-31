# Marketing & Trailer Research — Solo-Dev Playbook

*Compiled 2026-07-31 for The Nine Lives of Ashcat (free Chapter 1 + single
unlock, iOS/Android, Godot).*

## The core reality

Premium-ish mobile does NOT grow through paid ads — it grows through three
levers a solo dev controls: **platform editorial featuring** (the biggest
install driver), **organic short-form video** (a hand-illustrated cat
detective is unusually well-armed here), and **store page conversion**. The
free-Chapter-1 model is an asset: free charts, free-game featuring slots,
every install a potential conversion.

## 1. Store pages (ASO)

- Apple indexes Title (30ch) + Subtitle (30ch) + hidden 100-char keyword
  field — never repeat a word across them. Suggested subtitle:
  **"Cat detective card roguelite"** (detective/card/roguelite are the
  searched genre terms). Keyword field: `deckbuilder,roguelike,mystery,noir,
  offline,single player,cozy,story`.
- Win long-tail ("cat card game", "detective deckbuilder"), not head terms.
- **Screenshots decide conversion**; Apple OCR-indexes their text. First
  frame = the fantasy (Ashcat mid-case, full-bleed art + one wry line), then
  combat, story, world, depth, "Chapter 1 free." Captions in Ash's voice.
- Icon: Ashcat's face, readable at 60px; A/B test via Play store-listing
  experiments (free) / Apple PPO.
- Ratings gate featuring (90% of featured apps are 4.0+): fire the native
  review prompt at a high point — after the first case closes, never on a
  timer.

## 2. Featuring — the actual install driver

- **Apple Featuring Nominations form** (App Store Connect → Featured →
  Nominations): submit **6–8 weeks pre-launch**; pitch the STORY ("solo dev
  hand-illustrated a storybook noir where a cat spends nine lives solving
  murders"), not the version. Adopt cheap platform features first (iPad
  layout, haptics, iCloud save). Re-nominate under **New Content** for every
  chapter forever. *Highest expected-value single marketing task we have.*
- Google: no form; strong vitals + pre-registration + Indie Games
  Festival/Accelerator entries are the路. (Play Pass inclusion offers are
  worth taking if offered.)

## 3. Press & creators (2026 landscape)

- **TouchArcade is dead** (Sept 2024) — mobile press is thin. Target:
  **Pocket Gamer**, **Pocket Tactics**, **MiniReview** (app+Discord), TA
  forums' surviving community, ex-TA writers on newsletters.
- Creators: no premium-mobile reviewer class exists; target (a) deckbuilder/
  roguelite YouTubers (the Balatro-mobile audience), (b) cozy/aesthetic
  TikTokers, (c) cat-content accounts. ~30 personalized pitches, press-kit
  link, TestFlight code; small creators (5–50k) respond and convert best.
- Press kit: one Notion/GitHub page — facts, 3–5 GIFs, trailer, art, the
  solo-dev story, contact.

## 4. Communities

r/roguelites (NOT r/roguelikes), r/deckbuildinggames, r/AndroidGaming +
r/iosgaming (both upvote premium/no-ads dev posts), r/godot ("shipped Godot
game" is itself a story), TouchArcade forums Upcoming Games, MiniReview
Discord. One launch post per sub, different angle each, drafted in advance.

## 5. Timing

- **Google Play pre-registration** (≤90 days out) and **App Store pre-order**
  (free apps eligible): both concentrate day-one installs for chart velocity
  and give a store URL months early — the mobile "wishlist." Open ~4–8 weeks
  before launch with the trailer.

## 6. Trailer craft (Derek Lieu principles)

- **No logos up front; hook in ≤5s; genre unmistakable by 10s;** gameplay
  structured as an argument: hook → core loop → depth → escalation → title +
  CTA. Cut to music beats; never tutorial footage.
- 45s structure for us: (0–4s) one charming beat + wry line ("Nine lives.
  Somebody's about to lose one.") → (4–15s) card loop → (15–30s) death→next
  life, story, humor → (30–40s) bosses/chapters → (40–45s) title, "Chapter 1
  free," date.
- Tools: OBS capture of a staged "demo mode" build; DaVinci Resolve (free);
  Kling image-to-video for 1–2 mood shots from key art (social cuts ONLY).
- **Apple app preview rules:** 15–30s, up to 3, **captured in-app footage
  only** (no AI/motion graphics), portrait 886×1920, H.264 30fps; first 5s
  must work MUTED. One "screenshots-in-motion" 30s portrait loop.
- Vertical cuts: 1080×1920, ~21–34s, captions always, keep bottom 20% and
  right 10% clear. Capture natively vertical (our game is portrait!).

## 7. Cheap tactics ranked (effort→impact)

1. **Cat-first short-form video** 2–3/wk (TikTok/Shorts/Reels): Ashcat being
   a cat mid-case, art-process reveals, "I hand-drew every card in my cat
   detective game." #catsoftiktok × #indiegame. Account voiced AS Ash.
2. **Apple featuring nomination** — one afternoon, biggest upside.
3. **GIFs/art posts** — #screenshotsaturday, r/godot, r/IndieDev.
4. **Beta as funnel** — TestFlight public link (10k testers, shareable
   anywhere); Play closed testing doubles as the mandatory 12-tester/14-day
   gate. Recruit via Discord — testers become launch reviewers.
5. **Small Discord** (announcements/beta/cat-pics).
6. **Devlogs** — as story-building (~10% of content time), not growth.
7. **Reddit launch posts** — save for launch week, one per sub.
8. **Creator mailing** (~30 emails).
9. Cat-café/charity partnerships (stretch, on-brand).

## 8. Skip

- **Paid UA**: single-unlock LTV ≈ price × conversion (~$0.35 at 5% of $6.99)
  vs $1–4+ CPI — you lose ~85¢/dollar forever. Exception: tiny post-launch
  Apple Search Ads on brand/long-tail as ASO data only.
- **PR wire services / paid reviews / "guaranteed featuring" / ASO agencies.**
- **Publishers**: 30–50% rev share for what the Nominations form now gives
  everyone; only for real upfront money. DO plan a later **Steam release** —
  card-roguelite audiences (and wishlists) actually live there; Godot makes
  it nearly free; it's a second launch.

## 9. 8-week pre-launch checklist (3–5 hrs/week)

- **W8:** lock date; one-sentence pitch; **submit Apple nomination**; press
  kit page; create Ash-voiced social accounts.
- **W7:** Godot demo-mode capture pipeline; first 2 TikToks (cadence starts,
  never stops); **start Play closed testing** (12×14-day launch blocker).
- **W6:** cut the 45s trailer; 15s vertical teaser; community feedback.
- **W5:** finalize store pages; **open pre-reg + pre-order**; record the
  on-device App Store preview; announce date everywhere.
- **W4:** pitch ~30 creators + Pocket Gamer/Pocket Tactics/MiniReview with
  TestFlight public link.
- **W3:** beta triage; polish the Chapter-1-ending → unlock moment (that IS
  marketing); verify Play testing clock; apply for production.
- **W2:** follow-ups; draft Reddit posts; wire review prompt; **submit builds
  for review** (rejection buffer); schedule launch-week clips.
- **W1:** release from pre-order (chart velocity); Reddit + launch TikTok +
  Discord; happy testers rate day one; watch crashes hourly — a fast 1.0.1
  beats everything.
- **Post-launch:** re-nominate every update; keep short-form cadence; Play
  listing experiments; put the Steam page up.

*(Full source links in the research transcript: Apple featuring docs, Derek
Lieu essays + trailer checklist, Apple app-preview specs, ASO guides, TikTok
indie case studies, CPI/LTV benchmarks, TouchArcade shutdown coverage.)*
