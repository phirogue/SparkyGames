# Owner Actions — things only you can do

**Date:** 2026-08-02; updated 2026-08-31 (release pass). Companion to
`docs/research/2026-08-02-critical-project-review.md` and
`docs/research/2026-08-31-ship-readiness-review.md`. Everything the reviews
flagged that I can execute is done or in flight (code fixes, doc
reconciliation, balance passes, tooling, export presets, drafts). This doc
is the remainder: accounts, money, legal, hardware, taste, and decisions —
the things that need a human with a credit card and authority.

**2026-08-31 status:** the four items still blocking a store build, in
order: (1) Google Play account + the 12-tester clock, (2) Apple enrollment
+ the Mac decision, (3) Kling/AI-music commercial-terms verification, (4)
the commissioned app icon. Drafts now exist for the privacy policy
(`docs/publishing/privacy-policy.md` — needs a hosted URL and contact) and
the store listing (`docs/publishing/store-listing.md` — needs your
approval, especially the AI-disclosure wording). `game/export_presets.cfg`
is scaffolded for both platforms with icon and signing slots empty.
Monetization simplified 2026-08-31: free + tip jar at launch, Chapter 2
paid later — so no paywall or restore flow blocks v1.

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
- [x] **ChatGPT images: commercial use VERIFIED 2026-08-03.** Owner
      confirmed the plan's terms permit commercial use of generated
      stills; the Chapter 1 image batch is unblocked (Phase 0 sign-off,
      `docs/design/chapter1-build-plan.md`). Still worth doing when
      convenient: save a dated copy of the OpenAI content-ownership terms
      into `docs/publishing/` as evidence for store-review disputes.
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
      check **"The Nine Lives of Ash"** for conflicts (quick USPTO TESS
      search + app-store search). A US trademark filing is ~$250–350/class
      DIY. Since the art itself can't be copyrighted, the *name* is the moat.
- [ ] Register a domain for the game (needed anyway for the privacy policy
      and press kit).

## 4. Store compliance (fast, but only you can own them)

- [ ] **Privacy policy URL** — required by both stores even for an
      offline game with zero data collection. **Draft written 2026-08-31:
      `docs/publishing/privacy-policy.md`** — set the contact + effective
      date, then host it at a URL you control (the domain above, or GitHub
      Pages under your account).
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

1. ~~**Who killed Elspeth?**~~ **ANSWERED 2026-08-03: Bodkin.** See
   `docs/design/the-unraveler.md` (confirmed, veto window closed). Ch1
   prose is unblocked.
2. ~~**Chapter 1 mission-module cut list.**~~ **APPROVED 2026-08-03** as
   recommended: keep heist/Alarm and ritual, convert diplomacy to
   choice-scenes, defer survival and escort to Ch2+. Recorded in
   `docs/design/chapter1-build-plan.md` Phase 0.
3. **Fate deck: cut or keep?** Spec'd in core-gameplay.md as the long-term
   crit/variance system, absent from the build, mentioned nowhere else.
   My recommendation: cut it from the docs; the charge system already
   fills the "spend to improve odds" niche. Say the word and I'll excise it.
4. ~~**Supporter pack ($2.99): spec or cut for launch?**~~ **RESOLVED
   2026-08-31 by the monetization revision:** the game launches free with a
   donation tip jar; Chapter 2 is sold when ready. The Supporter Pack is cut
   — the tip jar replaces it with no cosmetic art needed. See
   `docs/design/monetization.md`.
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
