# tools/batches/ — generation runs that already happened

These are **one-off scripts, kept as history, not tools.** Each one is a
specific batch of images that was generated on a specific day: the job list,
the prompt each asset was made from, and the reasoning in its docstring.

They live here rather than in `tools/` so the reusable tooling is obvious at a
glance. Nothing in the project calls them.

| script | what it generated |
|---|---|
| `genart_batch.py` | the first standing batch (2026-08-03) |
| `genart_fixes.py` | the seven images that failed the 2026-08-03 style audit — where `STRICT_STYLE` was born |
| `genart_fixes2.py` | the second corrective pass |
| `genart_round3.py` | round three, including the transparent-background UI attempts |
| `genart_ch1_arc.py` | Chapter 1's opening arc (2026-08-04) |

## Why keep them

The prompt that made an image is the only record of *why it looks like that*.
When a piece of art needs to change, the original prompt is the starting point
— editing with `--ref` beats re-rolling from scratch, and you cannot edit
toward something if you do not know what was asked for the first time.

## If you are generating art now

Use **`/genart`**, which drives `tools/genart.py`. The house style is
`STRICT_STYLE` in that file — these scripts import it from there rather than
carrying their own copy, so there is exactly one definition of the style and it
cannot drift between batches.

To re-run one of these (rare — normally you want a single `genart.py` call
instead):

```powershell
python tools/batches/genart_fixes.py --dry-run
```

Remember that every generation **spends real money** (~$0.19/image), and that
art library rules 1 and 2 apply: check `assets/library/` before generating
anything, and `assets/archive/` before regenerating a *change*.
