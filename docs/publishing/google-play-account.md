# Google Play Developer Account — What to Create and How

*Written 2026-07-29. Start this NOW — the tester requirement adds weeks of
lead time before a public launch is even possible.*

## 1. Which account type

Two options: **Personal** or **Organization**.

| | Personal | Organization |
|---|---|---|
| Cost | $25 one-time | $25 one-time |
| Requirements | Government ID verification | D-U-N-S number (free but takes days–weeks), org docs, org website/email |
| 12-tester rule | **Yes** (accounts created after Nov 13, 2023): closed test with ≥12 testers continuously opted in for 14 days before you can apply for production access | Exempt |
| Public listing shows | Your legal name (developer name can differ but legal name appears for paid apps) | Company name |

**Recommendation: Personal account, created immediately.** You don't have an
LLC, a D-U-N-S number takes time, and the 12-tester requirement is actually
useful — it forces the beta we'd want anyway. If you later form a company,
accounts can't simply convert (you'd create an org account and transfer the
app — supported and routine).

One caveat worth 10 minutes of thought: **for paid apps/IAP, a personal
account's legal name is visible to users.** If you're uncomfortable with
that, the alternative is forming an LLC first (cost/time trade-off — not
recommended yet; the game is months from launch).

## 2. Step-by-step

1. **Create a dedicated Google account** — e.g. `sparkygames.dev@gmail.com`.
   Do not use your personal Gmail: the account will accumulate keystores,
   payment data, and tester chatter, and you may someday hand it to a
   company. Turn on **2-step verification** immediately and set recovery
   options (Play Console requires 2SV).
2. **Register at** play.google.com/console → pay **$25** (one-time,
   card).
3. **Identity verification:** government photo ID + confirmation of legal
   name/address. Usually clears in 1–3 days; occasionally longer. The
   developer profile also requires a contact email and phone that Google
   verifies.
4. **Public developer profile:** pick the developer name **"SparkyGames"**
   (shown on the store), support email, and later a privacy-policy URL
   (required for the store listing — a simple hosted page is fine; we can
   generate one).
5. **Payments profile (to sell the unlock IAP):** Play Console → Setup →
   Payments profile → create a **merchant account**. Needs: legal name,
   address, and tax info (**W-9 for US persons**; Google withholds nothing
   for US-source but collects the form). Do this early — it gates IAP
   testing, not just launch.
6. **Enroll in the 15% program:** Play Console → Setup → *Reduced service
   fee* — enroll the account group so the first $1M/yr is charged 15%
   instead of 30%. Takes minutes; people forget it and donate 15% to Google.
7. **API access for CI (later):** Setup → API access → create a service
   account so GitHub Actions can upload builds to the internal track
   automatically.

## 3. The 12-tester / 14-day requirement — plan of attack

Applies to us (new personal account). Before we can even *apply* for
production (public) access:

- Run a **closed test** with **≥12 testers opted in continuously for 14
  days**. Testers must actually install and keep opted-in; drop below 12 and
  the clock is at risk.
- After 14 days, fill out Google's production-access application (questions
  about testing feedback and readiness — genuine answers, easy if we really
  ran the beta).
- **Recruiting 12+ testers:** friends/family (a Gmail address is all a
  tester needs), plus communities that exist for exactly this:
  r/AndroidClosedTesting, "20-tester" Discord exchanges, TestTribe-style
  groups. Aim for ~20 sign-ups so churn never drops us under 12.
- **Timeline implication:** the moment the Prequel + a slice of Chapter 1 is
  playable on a phone, we ship it to closed testing — the 14-day clock can
  run while we keep building. Internal testing (up to 100 testers, no
  waiting period) is available immediately for our own devices.

## 4. Housekeeping rules (repo policy)

- The **upload keystore** lives outside the repo, backed up in two places
  (password manager + offline). Losing it is survivable with Play App
  Signing, but don't test that.
- Enroll in **Play App Signing** (default for new apps) so Google holds the
  final signing key.
- Never share the Play Console account password; add collaborators via
  user permissions instead.
- Apple later: Apple Developer Program ($99/yr) has no tester-count
  requirement; TestFlight replaces the closed-test dance. Register when iOS
  builds begin, not before.
