# Economy & Pacing Target (10-15h playthrough)

Working doc for the full economy recurve. **Spreadsheet the target curve here FIRST, then set `.tres` numbers to match it.** Do not tune blindly.

## The playtime math

- Target: **10-15 hours** to "beat" (reach/finish the World region).
- A "day" = one dig session + house + end-of-day shop. Early game ≈ **1-2 min/day** of real play; later days are longer (deeper digs, more management).
- So 10-15h ≈ **roughly 300-700 days** across the whole game, spread across 5 regions (House → City → State → Country → World).
- **House region target: ~1-2 hours ≈ 60-120 days.** That's the slice we're fixing first — it's currently far too fast.

## What's wrong now (diagnosis 2026-06-28)

Current values:
- Dirt $0.10/unit, full 30-pack = $3.
- Coal (depth 8) = **$8/block** = 80× a dirt unit. Iron (20) = $50. Gem (40) = $500.
- Reward tiers jump ~6-10× each → a **cliff, not a ramp.** You scrape pennies on dirt, then suddenly get rich the instant you hit coal.
- Upgrade costs don't scale with income → income outruns costs almost immediately.
- Net: the House region is over in minutes, not the intended 1-2 hours.

## The principle (from the idle-game research)

Income and costs must both grow **exponentially but offset** — the player is always ~10-20% short of the next purchase, so every stretch takes real time. The reward curve must be a **smooth ramp**, not a cliff. (See [[project-dig-gameplay-expansion]] research notes: exponential cost vs roughly-linear production is the pacing engine.)

## Target curve — HOUSE region (to fill in / iterate)

Goal: ~60-120 in-game days in the backyard before City unlock. Each upgrade should feel earned (several days of saving), not trivial.

| Phase (House) | ~Days | What the player is doing | Money/day (rough) | Next purchase costs |
|---|---|---|---|---|
| Opening (dirt only) | 1-10 | Scraping dirt, depth 1-5. Saving for first Spade upgrade + Coffee. | low (dirt only) | first upgrades cheap but day income is tiny |
| First upgrades | 10-30 | Sharpened spade, first Coffee, first Backpack. Reaching stone. | rising slowly | costs climb ~1.5-1.6× per level |
| Reaching coal | 30-60 | Coal seam (depth 8) becomes the income driver — but a *gentle* step, not 80×. | meaningful jump, not explosion | mid-tier upgrades, Hammer/Pickaxe/Drill |
| Toward City | 60-120 | Iron starting, saving the lump sum to unlock City. | steady | City unlock = a big deliberate goal |

**Open numbers to decide (this is the spreadsheet work):**
- What should a *good* dirt-only day earn? (sets the floor)
- Coal value relative to dirt — needs to come DOWN from 80× to maybe ~10-15× so it's a step not a cliff. OR dirt value comes up.
- Upgrade cost curve: base + multiplier per level so they pace at "a few days each."
- City unlock cost: the lump sum that ends the House region (~the player's total earnings over ~80-100 days).

## Method
1. Pick the **dirt-day floor** (e.g. a full pack should be worth roughly one... what?).
2. Re-space the ore tiers as a smooth ~2-3× ramp instead of 6-10× jumps.
3. Set upgrade costs to exponential curves that lag income by ~10-20%.
4. Project day-by-day money vs cumulative cost; confirm House ≈ 60-120 days.
5. THEN write the numbers into `.tres` + `game_state.gd`.

## LOCKED v3 numbers (2026-06-28) — House region recurve

**Principle:** dirt is the early floor (~first 30 days), ore takes over after. Ore tiers form a smooth ~3× ramp, NOT the old 6-10× cliff. Income and cost both grow exponentially, offset so you're always ~10-20% short of the next thing.

### Friction (all four knobs ON)
- `BASE_BACKPACK_CAPACITY`: 30 → **20**
- Spade base cooldown: 0.15 → **0.20s**
- Day length: stays **30s** base (upgrades extend it)

### Block values (depths TRIPLED 2026-06-30 — "we should not hit stone so soon")
| Block | HP | yield | depth | weight |
|---|---|---|---|---|
| topsoil | 4 | 1 dirt | 1 (surface only) | 10 |
| **loose dirt** (was "dirt") | 8 | **0** (worthless overburden) | 2+ | 10 |
| **clay** | 9 | **2 dirt** (the sellable earth) | 2+ | 2.5 |
| stone | 14 | 2 dirt | **15+** | 4 |
| **hard rock** | 28 | 2 dirt | **15+** | 2.0 |
| **unstable rock** (hazard) | 10 | 1 dirt | **15+** | 2.5 |
| coal | 18 | **$1.5** | **24+** | 2.0 |
| **ore pocket** (reward) | 16 | **$4** | **54+** | 0.3 |
| iron | 30 | **$5** | **75+** | 0.4 |
| **gold** | 40 | **$12** | **84+** | 0.18 |
| gem | 50 | **$18** | **96+** | 0.15 |
| dirt price | — | **$0.10/unit** (unchanged) | — | — |

Ore ramp: coal $1.5 → ore pocket $4 → iron $5 → gold $12 → gem $18.

### Village strata (depths tripled 2026-06-30)
Early bands were too cramped (stone at depth 5 = hit in seconds). Tripled from stone down; dirt/clay still start at depth 2 (you dig into dirt immediately).
- **d2-14:** pure dirt-digging — loose dirt + clay only. The long lean opening.
- **d15+:** stone, hard rock, **unstable rock** — cave-ins start here.
- **d24+:** **coal** — the reliable money ore.
- **d54+:** ore pockets ($4, ~1%).
- **d75+:** iron. **d84+:** gold. **d96+:** gem — the deepest jackpots, very rare.

**Soft floor (no wall):** depth stays infinite; past ~100 there's nothing richer than gem + climb-risk grows → natural stop. Real depth opens with later regions.

⚠️ **Deep-tier reachability:** at the tripled depths, iron/gold/gem sit 75-96 rows down — many days of digging. They may be effectively aspirational/late-House (or even City-era) goals now. Watch in playtest: if coal@24 already feels too deep to reach in early days, the whole table may need to come back up ~1.5× instead of ×3.

### Dirt-tier split (2026-06-30)
Not every block pays anymore. **Loose dirt is worthless ($0)** — pure overburden you dig through. The sellable "dirt" resource now comes from **clay** pockets (2 dirt/block, weight 2.5 ≈ ~18% of shallow blocks). This makes even the dirt-only early game a *search*, not a guaranteed payout, and roughly halves early income (sim: shallow day ~$0.73 vs old ~$1.50). Topsoil (surface row only) still gives 1 dirt as a small day-1 bonus. The deposit-pile / $0.10-per-unit plumbing is unchanged — the pile just fills slower (clay + topsoil feed it; everything else gives 0).

### Projected House pace (REVISED 2026-06-30 after ore re-gating)
The dirt split + pushing ore deep made the village ~3-4× leaner than the original v3 projection. Re-simulated cumulative income (crude straight-down model w/ tool+depth+backpack progression):
- day 10 ≈ $2, day 30 ≈ $25, day 60 ≈ $122, day 100 ≈ $488, day 150 ≈ $1024
- **City unlock target revised $2000 → ~$1100** so House finishes ~110-130 days ≈ **~2-2.5h**. Keeps the lean "every dollar counts" feel the user wants.
- ⚠️ Sim is crude (assumes straight-down digging). Treat as directional; **real tuning waits on in-engine playtest.**
- ⚠️ **No region-unlock flow exists yet** — `city_unlocked` is a debug flag. The $1100 is a locked *design target* for when that gate is built, not a wired cost.

(Original v3 projection, now superseded: dirt-only day ≈ $1.50, City ≈ $2000 at ~100 days.)

### Upgrade cost curves (base, mult per level)
- Coffee (day length): base **$8**, ×**1.5**
- Backpack: base **$15**, ×**1.4**
- Spade tiers: keep named-tier costs but rebase first tier ~$20, ×1.6 feel
- (Other upgrades to re-cost in the same spirit — lag income by ~15%.)

## Status
- Diagnosis done. ✅
- Target curve locked (above). ✅
- **Numbers applied (2026-06-30).** ✅
  - `game_state.gd`: backpack 30→20. dirt price 0.10 and day 30s confirmed unchanged.
  - blocks: topsoil 4, dirt 8, stone 14, coal HP18/$1.5, iron HP30/$5, gem HP50/$18.
  - spade: base cooldown 0.20, tier_cooldown [0.20,0.15,0.12,0.09], base_cost 50→20.
  - Coffee (day_length): base 75→**8**, ×1.5. Backpack upgrade: base 120→**15**, ×1.40.
- **Tool gating decision (2026-06-30):** Pickaxe/Hammer/Drill and the family/Arya upgrades are **region-progression rewards**, NOT House-era purchases. Their costs ($300–$4M) and `unlock_money` gates are left as-is — House is spade-only; better tools unlock as City→World open. The region-unlock flow will enforce this.
- City unlock cost ≈ **$2000** still TBD — to be set when the region-unlock flow is built (no flow exists yet, so nothing to wire).
- Later regions (City→World) reuse the same shape, scaled up. Each region's unlock cost ≈ cumulative earnings over its intended day-span.
