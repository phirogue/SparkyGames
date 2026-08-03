# Owner Actions — things only you can do

**Date:** 2026-08-02. Companion to
`docs/research/2026-08-02-critical-project-review.md`. Everything the review
flagged that I can execute is in flight (code fixes, doc reconciliation,
balance passes, tooling). This doc is the remainder: accounts, money, legal,
hardware, taste, and decisions — the things that need a human with a credit
card and authority.

Ordered by lead time: the top items start clocks that keep ticking while you
do everything else.

---

## 1. Start the launch clocks (longest lead time — this week)

### Google Play (Android)
- [ ] **Create the Google Play developer account** ($25 one-time).
      `docs/publishing/google-play-account.md` has the walkthrough — it said
      "Start this NOW" on 2026-07-29 and nothing has happened since.
      Personal vs organization account decision included there (organization
      needs a D-U-N-S number; personal shows your legal name on the listing).
- [ ] **Recruit 12 testers.** New personal developer accounts must run a
      closed test with **at least 12 testers opted in for 14 consecutive
      days** before you can even *apply* for production access. Friends and
      family count. This is the hard gate — every week it isn't started is a
      week added to the earliest possible launch date.
- [ ] Create the app entry + internal testing track as soon as a signed
      build exists (I can prepare the build config; you own the console).

### Apple / iPhone (you said iPhone matters — read this one carefully)
- [ ] **Enroll in the Apple Developer Program** ($99/year). Needs an Apple
      ID with two-factor auth. Enrolling as an individual is fastest;
      "SparkyGames" as a company name requires a D-U-N-S number and legal
      entity — decide which (this interacts with the trademark item below).
- [ ] **You need access to a Mac.** Godot exports iOS projects, but signing
      and uploading to App Store Connect require Xcode on macOS. Options,
      pick one:
      1. A physical Mac (any Apple-silicon Mac mini is enough, ~$500-600).
      2. A cloud Mac (MacStadium, Scaleway) rented month-to-month around
         launch windows.
      3. GitHub Actions macOS runners for CI signing/upload (free tier
         minutes exist; this is the cheapest but fiddliest — I can build
         the workflow once you have the Apple account and certificates).
      Nothing on the iOS side can happen until this is decided.
- [ ] **TestFlight** is Apple's beta channel (no 12-tester gate, much
      friendlier than Google's) — but it still needs the account + a Mac.
- [ ] **App Store featuring nominations** — your own research calls this
      the single biggest install lever, requested 6–8 weeks pre-launch via
      App Store Connect. It cannot be requested until the account exists.

## 2. AI content rights — verify before more assets are made (existential)

- [ ] **Kling: confirm your plan tier includes commercial rights.**
      `asset-pipeline.md` flags this as unverified and notes the free tier
      does NOT include them. If the tier is wrong, every video asset made so
      far is unusable. Screenshot the terms page and drop it in
      `docs/publishing/` so we have a record.
- [ ] **ChatGPT images: save the current OpenAI terms** (content ownership
      section) the same way. You own outputs per current terms, but we want
      a dated copy on file for store review disputes.
- [ ] **AI music: check the tool's commercial tier before generating.**
      You mentioned you'll be making AI music — Suno/Udio/etc. all gate
      commercial use behind paid plans, and *songs made while on the free
      tier generally stay non-commercial even if you upgrade later*.
      Subscribe first, generate second. Same drill: dated copy of terms in
      `docs/publishing/`.
- [ ] Note: AI-generated art/music is **not copyrightable** in the US, so
      the game's only registrable IP is the trademark and the (human-written)
      text. Which leads to…

## 3. Trademark + brand (cheap now, painful later)

- [ ] Decide the public developer name (SparkyGames vs something else) and
      check **"The Nine Lives of Ashcat"** for conflicts (quick USPTO TESS
      search + app-store search). A US trademark filing is ~$250–350/class
      DIY. Since the art itself can't be copyrighted, the *name* is the moat.
- [ ] Register a domain for the game (needed anyway for the privacy policy
      and press kit).

## 4. Store compliance (fast, but only you can own them)

- [ ] **Privacy policy URL** — required by both stores even for an
      offline game with zero data collection. I can draft the text (it's
      three paragraphs for a no-SDK offline game); you need to host it at a
      URL you control (the domain above, or GitHub Pages under your account).
- [ ] **Content rating questionnaire (IARC)** — filled in the Play Console
      by you. The game is a murder investigation with a body scene
      (tasteful, off-page, but present); answer honestly, expect ~9+/Teen.
      Nothing to prepare, just be aware it's your click.
- [ ] **App icon** — your own marketing research says the icon is "the
      single highest-leverage image we'll ship" and should be **human-made,
      not AI**. Commissioning a single icon from an illustrator is
      $100–400. This is the one art asset worth real money.

## 5. Art & music generation queue (your credits, your taste)

- [ ] **Regenerate the title art.** The current title screen reads
      "The Nine Lives **of of** Ashcat" — the typo is baked into the image
      (`assets` title art, see `screenshots/02_title.png`). Same
      composition, one "of". (Alternative if regen keeps fumbling: generate
      the art without lettering and I'll set the title in type — decide
      which you prefer.)
- [ ] **The art manifest is 2 of 24 approved** (`docs/design/art-manifest.md`).
      The backdrops and enemy portraits are the current blockers for
      Chapter 1 wiring. Batch-generate per the manifest order; the new
      consistency tool (below) will help you spot the ones that drift.
- [ ] **Music list** — no music manifest exists yet. When you're ready I'll
      write one (per-screen loops: title, hub, story, battle, defeat) with
      prompt suggestions; you generate on a commercial-tier account (see §2).

## 6. Decisions I need from you (each blocks work I can't start)

1. **Who killed Elspeth?** The docs currently plan to choose the Unraveler
   "after playtesting which ally players trust most" — but the fair-play
   mystery rules require clues planted from Chapter 1 to read honestly in
   hindsight. These are incompatible. **Pick the culprit now** (or
   explicitly bless "bluffable early clues" and I'll update the story
   contract). Everything Ch1-prose-shaped waits on this.
2. **Chapter 1 mission-module cut list.** Ch1's design uses five non-combat
   modules (diplomacy, ritual, survival, escort, heist). My recommendation:
   ship Ch1 with combat + TWO cheap modules (heist/Alarm reuses the
   existing stealth system almost entirely; ritual pattern-matching is a
   small self-contained minigame), convert the other leads to combat or
   choice-scenes, and defer diplomacy/survival/escort to Ch2+. Approve,
   amend, or veto.
3. **Fate deck: cut or keep?** Spec'd in core-gameplay.md as the long-term
   crit/variance system, absent from the build, mentioned nowhere else.
   My recommendation: cut it from the docs; the charge system already
   fills the "spend to improve odds" niche. Say the word and I'll excise it.
4. **Supporter pack ($2.99): spec or cut for launch?** Currently 4 lines of
   design and zero art entries. My recommendation: cut from launch copy,
   revisit post-launch.
5. **Prose trim pass** — the prologue exceeds its own joke-per-scene budget
   in places ("fish, buttons, gossip, gossip about fish"). I can do a
   surgical trim pass and show you a before/after diff, but the voice is
   the product — do you want me to draft it, or do you want to do the pass
   yourself with my line notes?

## 7. Community runway (zero-cost, starts whenever you're ready)

Per your organic-only marketing plan, audience runway is the entire budget:
- [ ] Reserve the game's name on TikTok/Instagram/YouTube (even if unused).
- [ ] **Create the free Steam page** when the trailer exists — your own
      research says the card-roguelite audience actually lives there and
      wishlists are free top-of-funnel. (I can write the store copy.)
- [ ] The "hand-drawn" marketing angle is being purged from the docs per
      your AI-honesty decision. I'm drafting replacement store/press copy
      that leads with the writing and storybook design and states plainly
      that art and music are AI-generated with human curation — **you
      approve the final wording** before anything ships publicly.

---

## What's already in flight (no action needed)

Code: payment-engine fix, HP clamp, loadout clamp, release-build error
handling, save-migration fix + tests, aspect-ratio strategy, UI overflow
fixes, journal margins. Content: Moonlight naming restored (your call),
empty_coat made completable, Swat + value-3 cards wired in, anti-turtle
balance pass, JSON normalization. Docs: PvP removed everywhere, daily
prowls replaced with the generated-cases concept (hunts, practice bouts
against Ash's friends), Midjourney references corrected, AI-transparency
stance recorded, README refreshed. Tooling: prowl-mode simulation, art
consistency checker v1 (flags palette/tone outliers so you can spot-correct
drifting images).
