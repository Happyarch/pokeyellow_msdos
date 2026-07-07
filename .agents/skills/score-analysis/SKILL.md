---
name: score-analysis
description: >
  Per-track musicological analysis of every Pokémon Red/Blue/Yellow song,
  transcribed from the Pokémon Score Transcriptions project. Covers key,
  harmonic language, compositional techniques, channel usage, structural
  quirks, and register choices. Read the description for a specific track
  BEFORE attempting any arrangement work on it — it tells you what makes
  the track tick so you don't accidentally work against the composer's
  intent. Triggers: "what key is [track]", "analyze [track]",
  "how does [track] work", "before arranging [track]", "score analysis",
  "Masuda", "channel usage in [track]", "what's special about [track]".
---

# Score Analysis — Per-Track Reference

**Read the analysis for a track BEFORE you arrange it.** These
descriptions tell you what Masuda was doing compositionally — the key
center, the harmonic tricks, the structural oddities, the channel
assignments that matter. Working without this context risks writing
parts that contradict the composer's intent.

---

## When to Use This Skill

```
START: You're about to arrange (or review an arrangement for) a track
  │
  ├─ Do you know the track's key, harmonic language, and structure?
  │     NO ──► Read descriptions/<track>.md from the index below.
  │     YES ─► Proceed with arrangement (music-theory + enhance skills).
  │
  └─ Is the track doing something unusual? (chromatic, atonal, nested
     loops, unconventional form, ambiguous key)
        YES ──► Read the description — it likely explains the technique.
        NO ───► You may not need this, but a quick skim never hurts.
```

**This skill is read-only context.** It doesn't tell you *how* to
arrange — that's the `music-theory` and `audio-enhance-*` skills. This
tells you *what you're working with* so those skills can be applied
correctly.

**Authority note — descriptions are theory guidance, not note data.**
The authoritative source for the actual notes, timing, loop points, and
channel contents is the **pret disassembly**, reached through the
deterministic pipeline (`pret_audio.py` → `music_analysis.py` →
`analysis/<Song>.yaml`, which is frame-exact against the engine). These
prose descriptions exist to convey the *right theory ideas* to apply in
an enhancement — key feel, harmonic tricks, structural intent. If a
description disagrees with the analysis output about a concrete fact
(a pitch, a measure count, a loop point), trust the analysis and treat
the description's claim as commentary. Never transcribe notes from a
description into an arrangement — read them from the analysis.

---

## What Each Description Covers

Each per-track file provides some or all of:

- **Key and mode** — major, minor, ambiguous, modal mixture
- **Harmonic language** — diatonic, chromatic, borrowed chords (e.g.,
  Neapolitan ♭II in Wild Battle), applied dominants
- **Channel assignments** — which voice carries melody, bass, harmony;
  any unusual register choices (e.g., Pallet Town's unusually high
  registers due to GB speaker frequency response)
- **Structural form** — phrase lengths, loop points, modified repeats
  (e.g., Wild Battle's offset loop), nested independent loops (Lavender
  Town's 80-measure meta-cycle)
- **Compositional techniques** — vibrato abuse (Lavender Town), chromatic
  ambiguity (Wild Battle's major/minor struggle), dynamic contrast
- **Cross-references** — "see also" pointers to related tracks that
  use similar techniques

---

## Key Takeaways for Arrangers

A few patterns from the descriptions that directly affect arrangement:

### Register awareness
Pallet Town, Cinnabar Island, Pokémon Tower, and Victory! Trainer all
use unusually high registers — the bass doesn't go below C4. This is
deliberate (GB speaker frequency response). **Bass reinforcement in
lower octaves is a natural tier-1 addition** for these tracks, since
OPL3/MT-32 aren't limited by a tiny speaker.

### Chromatic / ambiguous tracks
Wild Battle oscillates between major and minor with Neapolitan chords.
Lavender Town uses an atonal-sounding ostinato (C–G–B–F♯ tritone).
**Don't "fix" the ambiguity** — it's the point. Added parts should
match the chromatic language, not impose clean diatonic harmony.

### Nested loops
Lavender Town and Pokémon Mansion use independent per-channel loops of
different lengths, creating evolving textures. **Arrangement must
account for the full meta-cycle**, not just the shortest loop.

### Modified loop points
Wild Battle, Ocean, Encounter! Rival, and Silph Company have loop
returns that differ slightly from the first statement (e.g., octave
transposition for smooth re-entry). **Your added voices need to handle
both the first-time and loop-return variants.**

---

## Track Index

All descriptions live in:
```
docs/references/pokemon_score_transcriptions/descriptions/
```

Sorted alphabetically by filename (matches `ls`); regenerate this table
from the directory listing + each file's `#` heading if files change.

| Track | File | Key highlights |
|-------|------|---------------|
| Battle! Gym Leader | battle_gym_leader.md | |
| Battle! Trainer | battle_trainer.md | |
| Battle! Wild Pokémon | battle_wild_pokemon.md | C major/minor ambiguity, ♭II Neapolitan, offset loop |
| Celadon City | celadon_city.md | |
| Cerulean City | cerulean_city.md | |
| Cinnabar Island | cinnabar_island.md | High register |
| Conclusion | conclusion.md | |
| Cycling | cycling.md | |
| Encounter! Bad Guy Trainer | encounter_bad_guy_trainer.md | |
| Encounter! Boy Trainer | encounter_boy_trainer.md | |
| Encounter! Girl Trainer | encounter_girl_trainer.md | |
| Encounter! Rival | encounter_rival.md | Modified loop point |
| End Credits | end_credits.md | |
| Evolution | evolution.md | |
| Evolution Fanfare | evolution_fanfare.md | |
| Final Battle! Rival | final_battle_rival.md | |
| Foreword | foreword.md | Context on the transcription project |
| Game Corner Casino | game_corner_casino.md | |
| Guidepost | guidepost.md | |
| Hall of Fame | hall_of_fame.md | |
| Introduction | introduction.md | Methodology and notation conventions |
| Item Fanfare | item_fanfare.md | |
| Jigglypuff's Song | jigglypuffs_song.md | |
| Lavender Town | lavender_town.md | Atonal ostinato, tritone, nested loops, vibrato abuse |
| Level Up Fanfare | level_up_fanfare.md | |
| Mt. Moon Cave | mt_moon_cave.md | |
| Ocean | ocean.md | Modified loop point |
| Opening Battle! | opening_battle.md | |
| Pallet Town | pallet_town.md | High register, nostalgia, C6 melody |
| Pewter City | pewter_city.md | |
| Poké Flute | poke_flute.md | |
| Pokédex Fanfare 1 | pokedex_fanfare_1.md | |
| Pokédex Fanfare 2 | pokedex_fanfare_2.md | |
| Pokémon Captured Fanfare | pokemon_captured_fanfare.md | |
| Pokémon Center | pokemon_center.md | |
| Pokémon Center Recovery | pokemon_center_recovery.md | |
| Pokémon Gym | pokemon_gym.md | |
| Pokémon Mansion | pokemon_mansion.md | Complex nested loops |
| Pokémon Tower | pokemon_tower.md | High register |
| Professor Oak | professor_oak.md | |
| Professor Oak's Lab | professor_oaks_lab.md | |
| Road to Cerulean City (from Mt. Moon) | road_to_cerulean_city.md | |
| Road to Lavender Town (from Vermilion City) | road_to_lavender_town.md | |
| Road to Viridian City (from Pallet Town) | road_to_viridian_city.md | |
| S.S. Anne | ss_anne.md | |
| Sylph Company | sylph_company.md | Modified loop point (book spells it "Sylph") |
| Team Rocket Hideout | team_rocket_hideout.md | |
| The Final Road | the_final_road.md | |
| Title Screen | title_screen.md | |
| To Bill's Origin (from Cerulean City) | to_bills_origin.md | |
| Vermilion City | vermilion_city.md | |
| Victory! Gym Leader | victory_gym_leader.md | |
| Victory! Trainer | victory_trainer.md | High register |
| Victory! Wild Pokémon | victory_wild_pokemon.md | |
| Viridian Forest | viridian_forest.md | |
| Conclusion | conclusion.md | |
