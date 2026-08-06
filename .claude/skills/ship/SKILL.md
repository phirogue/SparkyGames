---
name: ship
description: Full pre-commit gate for SparkyGames - verify, propagate, then commit and push. Usage: /ship <commit subject>
---

# Ship — the only road to a commit

Nothing lands on main red. One command runs the gates in the right order and
stops at the first failure that makes later steps meaningless:

```powershell
python tools/verify.py standard
```

That covers: import pass · unit tests · propagation checks · minigame bots ·
chaos fuzzer. It prints why each step exists and what failed.

## Then, depending on what changed

| Changed | Also run |
|---|---|
| anything visual or any content | `python tools/verify.py full` — adds the every-quest sweep and art repetition |
| enemies / skills / costs / deck data | `godot --headless --path game -s tests/simulate.gd`, then update `docs/design/balance-notes.md` if numbers moved |
| enemy stats or intents | `godot --headless --path game -s tests/bestiary.gd` — the bestiary doc is GENERATED |

**Read the screenshots.** The sweep proves they were produced, not that they
look right. Law 1 is a human (or Claude) looking at the images the change
touched — see `/uitour`.

## Before a commit the owner will look at

Run **`/ownerpass`** (law 3). It adds the story-critic and first-timer passes
on top of these gates. Cheap to skip mid-change; **never** skip it before
saying "ready to review", and never report ready with a known unfixed defect
unmentioned.

## Committing

Short imperative subject; body explains *why* when it isn't obvious. End with:

```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

Then `git push`. Remote is `origin` → github.com/phirogue/SparkyGames.

**Never** commit red and never bypass hooks with `--no-verify`. If a gate
fails, fix the cause.

## Things that are easy to forget at commit time

- **New `class_name` script or new image?** `godot --headless --path game
  --import` first — otherwise a class "is not declared in the current scope"
  and new art renders black.
- **New profile key?** It needs a `SaveService.DEFAULT_PROFILE` entry *and* a
  migration that answers "what does an old save imply?" (law 14).
- **New story scene with a battle?** It needs `when_outcome` variants —
  victory text after a retreat is a canon bug (law 17).
- **New tuning number?** `game/data/rules.json` **and** `Rules.DEFAULTS`, or
  `tests/unit/test_rules.gd` will say so.
- **Screenshots are not tracked** (owner decision 2026-08-06) — except the
  curated `screenshots/reference/` set. A tour run produces no commit noise.
- Never commit secrets, keystores, certificates or store credentials.

If you are unsure what else your change has to touch, that is `/propagate`.
