# Art Assets Needed — Full Survey

Complete list of every visual asset the game needs, mapped to free CC0/CC-BY sources you can study or use as placeholders while you make your own. Pulled from the actual game contents (blocks, helpers, rooms, characters).

**Target resolution:** 32×32 for blocks, 32×48 for characters (per `art_plan.md`). Many free packs are 16×16 or 18×18 — fine for study; scale or redraw at our size.

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
