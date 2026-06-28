# Art Assets Needed — Full Survey

Complete list of every visual asset the game needs.

## ART DIRECTION DECISION (locked 2026-06-28)

**Primary art source: Kenney "Tiny Town" + "Tiny Dungeon" (16×16, CC0).**
- All **CC0** → no attribution required, can recolor/modify/ship freely.
- **16×16 native, scaled 3× to fill the 48px block cells** (16 × 3 = 48, clean integer = crisp pixels). No change to the block grid.
- Tiny Town covers houses / buildings / furniture; Tiny Dungeon covers tiles / characters / items. One consistent style across the whole game.
- Recolor toward the game's mood as desired, but Kenney's own palette is fine to start. (The Apollo palette / hand-drawn-from-scratch plan is now secondary — kept for any custom pieces the user still wants to draw, e.g. the protagonist or story-specific props.)

Downloads (CC0):
- Tiny Town: https://kenney.nl/assets/tiny-town
- Tiny Dungeon: https://kenney.nl/assets/tiny-dungeon
- (ore detail, if Tiny packs lack ores) CC0 Mineral Icons (32×32): https://opengameart.org/content/cc0-mineral-icons — would need downscaling to 16px to match.

**Old target (superseded):** 32×32 blocks / Apollo palette / jlango CC-BY tileset. Kept below for reference only; the user's hand-drawn dirt-000N experiments live in `resources/blocks/` and can still be swapped in later.

### CC0 source shortlist (searched 2026-06-28)

All CC0 = free, no attribution, recolor/modify/ship freely.

| Source | Res | Covers | Page |
|---|---|---|---|
| **Kenney Tiny Town** | 16 | houses, furniture, town | kenney.nl/assets/tiny-town |
| **Kenney Tiny Dungeon** | 16 | tiles, characters, items | kenney.nl/assets/tiny-dungeon |
| **Dungeon Crawl 32×32 (DCSS)** | 32 | huge: ores, gems, walls, items, monsters | opengameart.org/content/dungeon-crawl-32x32-tiles |
| **CC0 Mineral Icons (AntumDeluge)** | 32 | coal, gold, silver, mithril, ore/rock | opengameart.org/content/cc0-mineral-icons |
| **Generic Platformer Tiles (surt)** | ? | platformer ground/terrain | opengameart.org/content/generic-platformer-tiles |
| **Simple Broad-Purpose Tileset (surt/Sharm)** | 16 | platformer scenery, chars (Arne palette) | opengameart.org/content/simple-broad-purpose-tileset |

Skip: "A Blocky Dungeon" (top-down, wrong perspective). CC-BY (needs credit, avoid for now): 700+ RPG Icons (Lorc), jlango dirt-grass-rock.

**Plan:** Kenney Tiny packs = dirt/stone/house/characters (the bulk, all 16px). For the 3 ore blocks (coal/iron/gem) which Kenney lacks: take a Kenney stone tile and dab ore specks on it (stays 16px, consistent), OR downscale AntumDeluge Mineral Icons / DCSS ore art to 16px. **Avoid mixing 16px and 32px in the dig grid** — keep one resolution.

---

## 1. Dig-world blocks (the underground)

These exist in `resources/blocks/` and each has a `texture` slot ready.

| Asset | Current | Needs sprite |
|---|---|---|
| Topsoil | brown rect, grass-ish top | grass-topped dirt tile |
| Dirt | brown rect | grainy dirt tile (see art_plan §6b) |
| Stone | gray rect | rocky/cracked stone tile |
| Coal | dark rect | dirt/stone with black coal chunks |
| Iron | rust rect | stone with orange-brown iron veins |
| Gem | cyan rect | stone with bright crystal facets |
| Bedrock | dark gray rect | hard, near-black impassable rock |

**Future region ores** (City→World, not built yet): copper, silver, platinum, uranium, exotic/"weird" ores. Each region introduces 1-2 new ore looks.

**Block states also needed later:** a "cracked" overlay for the hit-progress (block taking damage), and a break/shatter effect (deferred — polish).

---

## 2. Characters

Each needs idle + walk + jump + dig frames eventually. Start with idle only.

| Character | Where | Notes |
|---|---|---|
| **Protagonist** | dig world + house | 32×48. Silent. Needs idle/walk/jump/dig animation set. Most important sprite. |
| **Dad** | workshop, helper | engineer; appears as helper digging |
| **Mom** | kitchen, helper | warm; appears as helper sieving |
| **Sister** | office | finance; mostly seated |
| **Arya** | kitchen (Day 1), visits | savant; the most-drawn NPC over the game |

Family members appear as **helpers** (digging in the world) and as **NPCs** (standing in rooms). Helper sprites can be simpler.

---

## 3. House interior (7 rooms)

Rooms are in `scenes/rooms/`. Each currently uses flat ColorRects.

| Element | Used in | Notes |
|---|---|---|
| Floor tile (wood) | all rooms | tileable |
| Wall / wallpaper | all rooms | upper-middle-class feel |
| Door / doorframe | every room transition | the RoomDoor visual |
| Bed | bedroom | interactable (sleep) |
| Tool rack / wall hooks | bedroom | spade/pickaxe/hammer/drill hang here |
| Window + ladder | bedroom | the debug/Dad-upgrade shortcut |
| Stairs | corridor → downstairs | |
| Kitchen: stove, counter, table, sink | kitchen | Mom's domain |
| Workshop: workbench, anvil, tools, shelves | workshop | Dad's domain |
| Living room: couch, TV, rug, **family photo wall** | living room | photos are story props |
| Sister's office: desk, computer, papers, chair | sisters_room | |
| Parents' room: bed, dresser, **hidden Dad+Grandpa photo** | parents_room | |

**Story props:** the two family photographs (public 3-generation, hidden Dad+Grandpa) are specific art pieces, not generic furniture. See [[project-dig-character-grandpa]] in memory.

---

## 4. Surface / backyard

| Element | Notes |
|---|---|
| House exterior facade | windows, door, roof — player exits from here |
| Sky / clouds | background |
| Grass / surface ground | the strip the house sits on |
| Deposit pile | grows as you deposit (currently a ColorRect that scales) |
| Deposit station marker | where you press E |
| The spade (prop) | leaning against the porch on Day 1 |

---

## 5. Tools (held by character + on the wall)

Each tool has 4 tiers (Spade chain built; others planned). Ideally each tier has a distinct look.

- **Spade:** Rusty → Sharpened → Steel → Heirloom
- **Pickaxe, Hammer, Drill:** base + future tiers
- Tool icons for the shop UI + the held-in-hand version during digging

---

## 6. UI

| Element | Notes |
|---|---|
| Top bar background | money/dirt/pile/day/timer |
| Buttons | upgrade/sell/hire — could stay simple |
| Toast background | milestone/event popups |
| End-of-day modal frame | the shop |
| Cutscene modal frame | story beats |
| Icons | dirt, each ore, money, day, backpack |

UI can lag behind world art — flat colored panels read fine for a long time.

---

## Free asset sources (study or placeholder use)

### Best, most permissive (CC0 — no attribution required)
- **Kenney — Pixel Platformer** (18×18) — clean platformer tiles incl. ground/dirt/stone. [zip](https://kenney.nl/media/pages/assets/pixel-platformer/33bb4921eb-1696667883/kenney_pixel-platformer.zip)
- **Kenney — Tiny Town** (16×16, CC0) — houses, buildings, town elements. [zip](https://kenney.nl/media/pages/assets/tiny-town/a415fbeb49-1735736916/kenney_tiny-town.zip)
- **Kenney — Tiny Dungeon** (16×16, CC0) — dungeon tiles, characters, items. [zip](https://kenney.nl/media/pages/assets/tiny-dungeon/f8422efb44-1674742415/kenney_tiny-dungeon.zip)
- **OpenGameArt — CC0 Mineral Icons** by AntumDeluge (32×32, CC0) — gold, silver, coal, mithril, adamantite, ore/rock icons. https://opengameart.org/content/cc0-mineral-icons
- General: **kenney.nl** (everything CC0), **Lospec** (palettes + tiny tile examples)

### Free but needs a credit line (CC-BY)
- **OpenGameArt — "Dirt - Grass - Rock: Platformer terrain 32x32"** by jlango (32×32, CC-BY 3.0) — exact resolution match. https://opengameart.org/content/dirt-grass-rock-platformer-terrain-32x32
- **OpenGameArt — [LPC] Mine** — mining/cave tileset (check license on page) https://opengameart.org/content/lpc-mine
- OpenGameArt has many more: search "dirt tileset", "cave tileset", "ore", "mining" — verify license per page (they offer CC0 / CC-BY / GPL).

### Study references (don't copy — match the *density of detail*)
- Terraria dirt/stone/ore blocks (image search)
- Stardew Valley mining/cave tiles
- SteamWorld Dig

---

## Priority order to make (or source)

1. **Dirt block** — most-shown, learn the technique on it (art_plan §6b)
2. **Stone, coal** — next-most-shown underground
3. **Protagonist idle** — the character you stare at
4. **Topsoil, iron, gem, bedrock** — rest of the blocks
5. **Protagonist walk/jump/dig** — animation
6. **House: floor, wall, door, bed, tool rack** — bedroom first (it's where the day starts)
7. **Family NPCs** (Mom/Dad/Arya idle) — for the Day 1 scene
8. **Rest of house furnishings** — kitchen, workshop, living room, etc.
9. **Surface facade, deposit pile, UI polish** — last

---

## Wiring (when you have a PNG)

- Blocks: set the `texture` field in the block's `.tres`.
- Player/NPCs: assign to the `Sprite2D` slot (already on the node), or for animation swap to `AnimatedSprite2D` (Claude will wire this).
- Rooms: currently ColorRects — Claude will convert to `Sprite2D`/`TextureRect` when art lands.
- **Set Project Settings → Rendering → Textures → Default Texture Filter = Nearest** (once, globally) so pixel art stays crisp.

---

## Attribution tracking (required for CC-BY assets — fill in as used)

If any of these end up in the shipped game, the credits screen must list them:

- **jlango — "Dirt - Grass - Rock: Platformer terrain 32x32"** (CC-BY 3.0). Required: a credit line, e.g. "Terrain tiles by jlango (OpenGameArt, CC-BY 3.0)". Status: [ ] used / [ ] not used.
- CC0 assets (Kenney packs, AntumDeluge CC0 Mineral Icons) need **no** attribution, but crediting is polite.

**Workflow note (decided 2026-06-28):** Block art approach is **CC0/CC-BY base tilesets recolored to the Apollo palette + lightly modified**, not fully hand-drawn from scratch. The user keeps practicing their own pixel art on the side (the dirt-000N series) and can swap hand-made tiles in later. Characters (protagonist, family) more likely to be hand-drawn since personal style matters most there.
