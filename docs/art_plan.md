# Art Plan — Dig

A self-paced roadmap for making the game's art yourself, starting from zero.

The game code is already sprite-ready. Every visual node has a `Sprite2D` slot or a colored rect that's easy to swap. You are not blocked on code — you can start drawing today and drop assets in as you go.

**Honest framing:** art is a longer skill arc than learning Godot. Your first sprites will look rough. That's expected. Make a lot of bad ones to find your style.

---

## 1. Pick a tool

The split is pixel art vs hand-drawn. Pixel art is easier to start, faster to iterate, and fits the platformer/dig genre. Strongly recommended.

**Pixel art tools (in order of recommendation):**

- **Aseprite** — $20, industry standard. Best workflow. ([aseprite.org](https://aseprite.org))
- **LibreSprite** — free fork of older Aseprite. Less polished.
- **Piskel** — browser-based, free. Easiest to try first. ([piskelapp.com](https://www.piskelapp.com))
- **Pixilart** — browser-based, free.

**Recommendation:** install Aseprite. The $20 pays itself back in the first afternoon. It is GPL-licensed; the purchase price supports the devs.

**Non-pixel alternatives (do NOT recommend for first run):**
- Krita (painting, free)
- Inkscape (vector, free)
- Affinity Designer ($30 one-time)

---

## 2. Pick a base resolution

Decide this **before** you draw anything. Everything else is built around it.

Common sizes:

| Resolution | Example game | Notes |
|---|---|---|
| 16×16 | Stardew Valley, Terraria | Tiny. Forces stylization. Easiest to draw. |
| 32×32 | Hyper Light Drifter | Sweet spot. Readable, expressive, manageable. |
| 48×48 | (Dig's current block size) | Bigger = more detail = more work per sprite. |
| 64×64 | Owlboy | Detailed but slow. |

**Recommendation: 32×32 for blocks, 32×48 for the character.** Render at 2× scale in Godot. World coords stay at 48 (block grid size unchanged). The code change to make this work is small.

Or stay at 48×48 native blocks and just draw bigger. More detail per block, slower per sprite.

---

## 3. Pick a palette

This is the single most important tip. **Pick a palette before drawing.** Use only those colors. This is the difference between "kid's drawing" and "looks like a game."

**Free palettes:** [lospec.com](https://lospec.com/palette-list)

**Top pick: Apollo (46 colors)** by AdamCYounis — [lospec.com/palette-list/apollo](https://lospec.com/palette-list/apollo)

Why Apollo over a general palette (decided 2026-06-28, after checking how dirt-heavy games handle palettes):
- This is an **all-underground game** — dirt, stone, and ore fill the screen. We need **value depth in browns and greys**, not hue variety across the whole rainbow.
- Apollo is built as **8 deep dark→light ramps**: a 6-step brown ramp, adjacent maroon + orange-brown ramps (great for dirt shadow hue-shifting), and a **9-step grey ramp** for stone/bedrock. Plus saturated blues/greens/reds/purples left over for ore/gem accents (coal, iron, gem, copper, silver).
- Bonus: it's by AdamCYounis, the same teacher whose tutorials are recommended below — consistent mental model.
- You'll use ~25-30 of its 46 colors. (A general 64-color palette like Resurrect 64 wastes most of its colors on hues an underground game never shows — only ~10-15 usable.)

**Caveat:** even Apollo has only ~6 true browns. Since dirt is on screen constantly, it's a justified exception to add **1-2 custom dark-brown swatches** to the palette panel (and reuse those exact swatches everywhere). Add them *to* the palette, don't free-pick.

Other earth-toned options if Apollo doesn't click: **Oil 6** (tiny, very brown/muddy), **AAP-64** (broad but warm). But start with Apollo.

### One palette for the WHOLE game — do NOT split (decided 2026-06-28)

Use Apollo for everything — underground, house, characters, UI. Do **not** use a separate palette for the house/buildings.

- **Cohesion** is what makes it look like one game. The player crosses house↔dig constantly; two unrelated palettes would clash every time. Stardew / Terraria / SteamWorld Dig all use one unified palette across interior, exterior, and underground.
- Apollo is a full 46-color palette (8 hue ramps) — its browns/greys cover dirt and stone, and its blues/greens/purples/reds cover sky, plants, fabric, windows, furniture, clothes, UI. It's general enough for the house AND deep enough for the dirt.
- **Get tonal variety by emphasis, not by splitting:** lean on the brown + dark-grey ramps underground (enclosed, earthy); pull in warmer browns + soft accents (a blue window, a warm lamp, a green plant) in the house. Same palette, different selection. That gives the cozy-house-vs-lonely-hole mood without breaking cohesion.
- A deliberate warm/cold house-vs-hole contrast is a valid *late-stage artistic* choice, but it'd still be sub-ranges of one master palette, not two unrelated sets. Not a beginner starting point.

---

## 4. What to draw, in order

Drawing things in order of impact on the game's feel:

1. **Dirt block** (just one). If you can make a good dirt tile, you can make everything.
2. **Topsoil block** (dirt with grass on top).
3. **Stone block.**
4. **Coal block.**
5. **Player character — idle pose only.** Just a standing frame, no animation.
6. **Player walk cycle** (2-4 frames).
7. **Player jump + fall poses** (2 more frames).
8. **Player dig pose** (1-2 swing frames).
9. **Iron, gem, bedrock** blocks.
10. **House facade / room tiles** (much later — lots of work).

Each is an evening's work for a beginner, getting faster. **Don't try to make any of these final on the first pass.** Make a v1 of every block, then a v2 of everything once your skill is sharper.

---

## 5. Learning resources (concrete)

**Worth your time:**

- **AdamCYounis on YouTube** — "Pixel Art Class" series. Best free curriculum online. Watch the first 3-5 lessons before drawing anything important.
- **MortMort on YouTube** — punchy, specific lessons on color and lighting.
- **Pixel Logic by Michael Azzi** — $9 PDF. Foundational reference. ([gumroad](https://saint11.gumroad.com/l/pixel-logic))
- **Lospec Pixel Art Academy** — free lessons + palettes.

**Skip:**
- "Make a sprite in 5 minutes" videos. They teach shortcuts, not foundations.

---

## 6. Workflow for each sprite

1. **Reference.** Look at real dirt, real coal, real tools. Don't draw from imagination at the start.
2. **Block out the silhouette.** Just a flat shape. Does it read?
3. **Add 2-3 shades** of the main color (light, medium, dark).
4. **Define edges.** Darker outline OR selective colored outline (search "selout").
5. **Highlight.** One or two bright pixels for shine.
6. **Step back.** Zoom out to game scale. If it doesn't read at game size, fix it.

---

## 6b. Dirt is grainy noise, NOT a lit cube (important correction)

The single most common beginner mistake on a dirt tile: shading it like a crate — strong top-left highlight, big bottom-right shadow wedge, hard outline. That reads as a chocolate block, not soil.

**Dirt is soft, grainy texture.** The recipe that actually works:

1. Flat-fill the whole tile in the **mid-brown**.
2. With the **darkest brown**, 1px pencil, scatter **~40-60 single pixels** randomly across the whole tile. No pattern — like gentle TV static. Some touching, mostly not.
3. With the **lighter tan**, scatter **~20-30 single pixels**, weighted slightly toward the top.
4. With **maroon / near-black**, make **2-3 tiny 3-pixel clusters** = pebble-holes. That's the only place the darkest color goes.
5. Only *now* add a **very subtle** gradient: darken the bottom ~3-4 rows by one shade, lighten the top ~2 rows by one shade. Gentle. No hard edge.
6. View → Tiled Mode. Make sure no obvious repeating clump and the seams don't line up. Move speckle away from the very edges if they do.

The mental shift: **textured noise, not a shaded 3D cube.** The lit-cube approach (strong corner highlight + shadow wedge) is correct for *crates, stone bricks, metal* — hard-edged objects. Soft materials (dirt, sand, grass) are mostly grain with only a whisper of directional light.

**References to study side-by-side:** Terraria dirt block, Stardew Valley dirt, SteamWorld Dig. Match the *density of speckle*, not the lighting.

## 7. Dropping a sprite into the game

Once you have a `.png`:

1. Drop it in `res://assets/blocks/dirt.png` (or wherever).
2. Open `resources/blocks/dirt.tres` in Godot.
3. Find the `texture` field — drag your PNG in.
4. Run. The block now uses your art.

**One important setting:** In Project Settings → Rendering → Textures → Default Texture Filter, set this to **Nearest** (not Linear). Otherwise pixel art looks blurry. Set once project-wide.

---

## 8. Suggested weekly plan

| Week | Goal |
|---|---|
| 1 | Install tool, watch AdamCYounis lessons 1-5, draw 5 throwaway sprites of nothing. |
| 2 | Pick a palette, draw the dirt block 5 times. Pick best. Drop into game. |
| 3 | Draw all other blocks at the dirt-block quality. |
| 4 | Start the character — idle pose only. |
| Month 2 | Walk cycle + jump + dig animations. |
| Month 3 | House facade, rooms, furniture. |

---

## 9. What I (Claude) can do for you

- Tell you which file to drop a texture into so it shows up in-game
- Adjust block scaling / Godot import settings
- Write the code to wire up new sprite slots (character animation states, etc.)
- Review your sprites by looking at PNG files you commit to the repo
- Suggest tweaks based on what the game needs visually

I **cannot**:
- Draw the sprites for you
- Watch YouTube tutorials with you
- Generate AI-style art (you've also explicitly rejected this direction)

---

## 10. Anti-perfectionism reminder

Your first dirt block will look bad. Make it anyway and put it in the game. Iterate. The fastest way to improve is by making the next one, not by polishing the current one.

Done is better than perfect. Especially for a game you haven't shipped yet.
