<!-- deliberated: REVIEW LOOP HALTED AT ROUND CAP — an experimental multi-model
     adversarial review (three models cycling roles) hit its round limit (3
     rounds) with 4 finding(s) still outstanding and unreviewed. The maintainer
     stopped the loop there. This is a round-cap exit, NOT a rejection: the
     content is believed sound, but the 4 findings have not been checked off
     and this spec has not been through a completed adversarial pass. Treat the
     4 outstanding findings as open items to verify before treating the spec as
     final. -->

# Cities1 Remaster Specification

> **Gate — the linter is MANDATORY. Rewritten 2026-08-02 against the tooling
> that actually exists; the version this replaces predated `static_gate` and
> told you "nothing runs it for you", which stopped being true on 2026-07-26.**
>
> **What runs automatically.** `dos_port/tools/static_gate` runs BOTH linter
> modes plus `test_label_db.py` and `validate_scenarios.py`, and it is invoked
> by `.githooks/pre-commit` (installed here: `core.hooksPath=.githooks`). It
> fires whenever anything under `dos_port/` is staged. It is a per-class
> RATCHET against a checked-in baseline: it fails a class that GREW.
>
> **What that does NOT mean.** A class sitting at baseline is not sanctioned —
> it is unfixed debt that merely has not gotten worse. `dos_port/tools/lint_pret_labels`
> **must exit 0**; it does not today — a small number of known, unsanctioned
> findings remain (`aux_misplaced` under plain `lint_pret_labels`;
> `--strict-claims` can add `hand_encoded_text` / `local_shadow` on top). None
> of those was ever approved by the maintainer, and the counts move as agents
> clear debt — **run `dos_port/tools/lint_pret_labels --no-scan` and
> `--no-scan --strict-claims` yourself** rather than trusting a number written
> here. Do not cite "at baseline" as permission to leave a class non-zero, and
> do not rewrite the rule to match the breakage.
>
> **For every commit made under this plan:**
> 1. Record the per-class counts from BOTH `lint_pret_labels` and
>    `lint_pret_labels --strict-claims` **before** you start.
> 2. Run both again before committing and compare per class. A class that grew
>    is your regression to fix now, not the next agent's to discover. Moving a
>    routine between files silently invalidates `extern` provider comments
>    elsewhere in the tree — collateral visible **only** under `--strict-claims`.
> 3. A green static gate proves **no structural or bookkeeping drift and nothing
>    about behaviour.** If the change can move a pixel or a WRAM byte, run
>    `make -C dos_port fidelity` (core) or `fidelity-full`, and add a must-hit
>    scenario when no existing one can witness the change.
>
> **The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json`
> is hash-locked legacy debt, not precedent. New relocations are FORBIDDEN. An
> agent may not add, expand or reinterpret it — including `structural_findings`
> and `suppress` — to make its own work pass. **Any ADDITION requires explicit
> maintainer sign-off and cannot be committed without it**; the pre-commit hook
> refuses added keys outright and names them. If the linter says `mirror`, move
> the complete routine to `dos_port/src/<pret path>` instead.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

## Purpose

Remaster `Cities1` for the MS-DOS port by revising both shipped MIDI renderings:

- `dos_port/assets/midi/gm/Music_Cities1.mid`
- `dos_port/assets/midi/mt32/Music_Cities1.mid`

The remaster must preserve the Game Boy composition in `audio/music/cities1.asm` as the source of truth while improving the arrangement quality on the target synths.

### Why this is a pipeline change, not a file edit

Both `.mid` files under `dos_port/assets/midi/` are build products of `gb_to_midi.py`, generated from the GB source plus per-song enhancement configuration (`dos_port/tools/audio/enhancements/`, `dos_port/tools/audio/overrides/`). They are not committed as hand-authored masters — the Makefile regenerates them from that pipeline, so editing the `.mid` bytes directly is not a remaster, it is a change that the next `make assets` silently discards. 

The spec is framed strictly around the override/enhancement source files rather than the shipped `.mid` files themselves because the build toolchain is the authoritative source of truth. Any change directly to the `.mid` binary payload bypasses the compiler, breaking reproducibility and ensuring the next asset compile clobbers the edit. The source-side configuration is the only place where timing and patch assignments can be maintained under version control and verified programmatically (via `yaml_lint.py`).

The actual deliverable of this remaster is therefore:

- a `Music_Cities1` enhancement/override definition (YAML, in the same location and format as existing per-song overrides under `dos_port/tools/audio/overrides/` and/or `dos_port/tools/audio/enhancements/`) encoding the tier-1 (OPL3/GM) and tier-2/3 (MT-32) changes described below, following `audio-enhance-opl3` and `audio-enhance-mt32` conventions
- the regenerated `.mid` files produced by running the standard asset build (`make assets` / the `gb_to_midi.py` target for this song) from that definition

Any reviewer step that inspects the `.mid` files must first confirm they are current build output of the checked-in override, not a hand-edited artifact — regenerate-and-diff, not edit-in-place.

## Source of Truth

The authoritative composition is `audio/music/cities1.asm`. The existing GM and MT-32 MIDIs are reference renderings, not the specification. Any remaster must keep the same song identity, loop logic, and melodic/harmonic content implied by the GB source.

The arrangement should be treated as a city theme with its own character:

- brighter and busier than a calm town theme
- more rhythmic and motoric than a purely lyrical city cue
- strongly loop-dependent, so the ending must re-enter cleanly
- harmonically stable, so enhancement should come from voicing, texture, and timbral clarity, not reharmonization

### Why "brighter and busier" is the target, not "warmer and more relaxed"

This is a source-driven conclusion, not a stylistic preference imposed from outside. `Cities1` plays continuously during ordinary overworld movement in every city that uses it — it is functional wayfinding music the player hears while walking, shopping, and talking to NPCs, not a stationary mood cue like a Pokémon Center theme. Its GB channel data matches that job: constant short-value motion in the lead, a second line that keeps moving rather than sustaining, and a noise channel that is rhythmically active throughout rather than used sparingly for accent. A "warmer, more relaxed" remaster would be pleasant in isolation but would misrepresent what the source actually does — it would be a different track wearing this one's melody. The busy, bright framing is therefore the faithful reading of the source's own texture, not a taste call. Player-facing effect: the remaster should keep the sense of a lively, populated place passing by, matching the pace at which the player is actually moving through it, rather than settling into ambience.

### Why the stylistic comparison is limited to Celadon City and Vermilion City

`Cerulean City` and `Pewter City` were considered and excluded, not overlooked. Cerulean's theme leans on a distinct harmonic color (extended/altered harmony over its water-town identity) that makes it a poor texture analog — matching its density would import a harmonic flavor `Cities1` does not have. Pewter's theme is comparatively sparse and stately, closer to the "calm town theme" this spec explicitly frames `Cities1` against. Celadon and Vermilion were chosen because they bracket `Cities1` on the one axis that matters for this remaster — continuous multi-channel activity versus internal relief — without either of them contradicting `Cities1`'s harmonic stability. Adding more comparison points would not sharpen the target; it would dilute two genuinely load-bearing reference points into a vaguer "city-theme-in-general" average. The comparison group is deliberately narrow because its job is to bound one specific texture decision (how continuously all voices are active), not to catalog every city theme's style.

It should differ from those themes in execution, not in function:

- compared with `Celadon City`, it should be less playful and less pattern-flashy, with less need for voice-crossing tricks or decorative imitation
- compared with `Vermilion City`, it should allow more internal relief and more phrase contour, because it is not built around the same relentless "everything plays all the time" effect
- compared with both, it should sit in the middle: active enough to feel urban, but not so dense that the loop loses clarity

## Scope: base track and the Hall-of-Fame alternate tempo

`audio/music/cities1.asm` is played under two different tempo/timing configurations in the original game: the normal overworld tempo, and a distinct **alternate tempo** used in the Hall of Fame sequence (mirrored in the port by `dos_port/src/audio/alternate_tempo.asm` and the corresponding `..._AlternateTempo` channel data referenced from `gen_audio_data.py`/`mpu401.asm`'s channel-command-pointer table). 

This remaster covers **only** the two shipped MIDI rendering files of `Music_Cities1` (GM and MT-32). Separate alternate-tempo MIDI files are **out of scope** because the build system does not define or produce distinct `Music_Cities1AlternateTempo` MIDI assets (the game engine plays `Music_Cities1` at both tempos, overriding channel pointers at runtime).

### Why the alternate-tempo Hall of Fame playback is in scope for verification

Although the user's deliverable only names the two normal `Music_Cities1` files, the Hall of Fame alternate-tempo execution is a critical verification target. At runtime, the game engine uses pointer overrides to play the same underlying `Music_Cities1` data at the faster 232 BPM tempo. Because the base game engine and the enhancement engine run concurrently, if the timing of the enhancement events is not written robustly, the two playback rates will diverge. Verification at the alternate tempo is required to ensure the single authored YAML functions correctly under both tempo modes, preventing a scenario where the overworld version sounds correct while the Hall of Fame version suffers from rhythmic or harmonic drift.

### Why one override definition drives both tempo builds and how timing is preserved

Because separate alternate-tempo MIDI assets are out of scope, a pair of independently hand-tuned files is not permitted. One unified `Music_Cities1` override/enhancement YAML file drives the entire arrangement. Treating the two tempos as separate targets would require maintaining duplicate YAML sources, which increases the likelihood of sync errors, configuration drift, and reviewer overhead.

To ensure the arrangement is robust across both tempos and stays sample-locked to the base channels without timing drift (a key risk when the game engine plays the theme at the faster tempo in the Hall of Fame), the following rule is enforced:
- **Tempo-relative timing:** All authored override events (fills, tapers, sustain changes) must be expressed relative to musical position (measures, beats, and fractions of beats) and the song's active tempo parameter, rather than absolute frames or milliseconds.
- This ensures the build system correctly compiles timing offsets that scale proportionally when the driver processes the track at different playback speeds, preserving the lockstep relationship between the base channels and the enhancement stream under both overworld (144 BPM) and Hall-of-Fame (232 BPM) tempos.

## Musical Diagnosis

### What the GB source is doing

The GB track is built from:

- a repeating melodic cell in the lead
- a supportive second line that fills in harmony and motion
- a sustained or patterned third voice that acts like an internal glue line
- a busy noise part that supplies momentum and city bustle

The result is a compact loop that feels energetic without becoming aggressive. The source relies on repeated figures, short harmonic spans, and texture rather than large formal contrast.

### What the current remasters should improve

The current GM and MT-32 versions should be remastered to fix three classes of weaknesses:

- thinness in the inner texture
- blurred phrasing or loop transitions
- underused target-specific timbre potential

The goal is not to rewrite the song. The goal is to make the existing musical idea read more clearly on desktop synths.

### Why "thinness in the inner texture" is a real risk here

That diagnosis follows from the GB writing itself, not from a style preference. The source spends much of its loop on repeated support patterns and short-note motion in the middle voices, while the top line carries the recognizability. On desktop synths, if those middle parts are simplified into block chords or softened into generic pad sustain, the track loses the internal forward motion that makes it feel like a city theme. The spec therefore treats "inner texture" as a concrete failure mode to check for, not as vague polish language.

## Arrangement Goals

### Shared goals for both renderings

- keep the original melody unmistakable at all times
- preserve the loop feel and phrase lengths from the GB source
- strengthen the bass and inner harmony without changing the tune
- keep rhythmic motion present, but avoid overcomplicating the accompaniment
- maintain a city-theme brightness rather than turning the track into a lounge, battle, or cinematic cue
- keep the harmonic progression, structural form, and phrase-level melodic/bass relationship identical between the GM and MT-32 renderings (see "Why the musical backbone must be identical" below)

### GM-specific goals

The GM rendering should prioritize:

- clear register separation
- clean, playable orchestration on standard General MIDI synths
- slightly stronger bass and pad support than the current version
- restrained color changes that survive on weaker GM playback devices

The GM version should sound complete and polished even on basic software MIDI.

### MT-32-specific goals

The MT-32 rendering should go further than GM in character and depth:

- more expressive sustained timbres
- richer inner voices
- more pronounced spatial or atmospheric support where the song can afford it
- better use of MT-32 attack and resonance character without changing the tune

The MT-32 version may be fuller than the GM version, but it must still be recognizably the same arrangement, not a separate recomposition.

### Why GM is held to a compatibility floor instead of scaling in richness with MT-32

Letting GM scale up alongside MT-32 was considered and rejected, for a reason specific to what "General MIDI" means as a deployment target here: GM covers a wide range of real playback quality, from full wavetable hardware down to thin default software synths, and the port has no way to detect which one a given player has. MT-32 is a single, known device profile with a fixed, predictable timbre and behavior — richness authored for it lands the same way for every MT-32 listener. Richness authored for "GM" does not: an arrangement voiced to sound full on a strong GM synth can turn cluttered or muddy on a weak one, because the player has no volume/velocity headroom or clean patch separation to fall back on. Holding GM to restrained, register-separated writing is therefore not a ceiling on ambition, it's the only choice that sounds correct across the actual range of GM devices the port ships to. MT-32's richer ceiling is available precisely because that risk doesn't exist for a single fixed device profile.

### Why the musical backbone must be identical between GM and MT-32, even though MT-32 has a larger voice budget

Letting MT-32 use its extra voice budget for structurally different arrangement content (different chord extensions, a different formal treatment, device-specific countermelodic material) was considered and rejected. The player can switch between the two renderings via port configuration, and both renderings exist to be the same music playing on different hardware — not two different arrangements. If the MT-32 version's harmonic function or structure diverged from GM's, "which is the real Cities1 arrangement" would no longer have an answer, and the port's stated Faithfulness Rules (same core harmonic progression, same loop logic) would have to be checked separately per device, doubling the review surface for no player-facing benefit. MT-32's extra voice budget is deliberately spent on this spec's non-structural axes instead — inner-voice richness, sustain/attack character, spatial depth — all things that add color to the same backbone rather than building a different one. This is also why "musical backbone" is explicitly scoped: it means harmonic progression and phrase/structural form, not voicing, doubling, or timbre — the axes where GM and MT-32 are expected to diverge are named in the GM- and MT-32-specific goals above.

### Why it belongs with Celadon City and Vermilion City, but not the same way

`Cities1` belongs to the same family because it shares the city-theme job: a looping, welcoming urban cue built from clean melodic identity and supporting texture. That is why the spec keeps the family resemblance (see Source of Truth above for which themes and why) but does not ask for the same arrangement style.

## What to Change

All changes below are authored as override/enhancement configuration for `gb_to_midi.py` (per Purpose), applied identically in intent to the normal-tempo and alternate-tempo builds (per Scope), and regenerated into the shipped `.mid` files rather than edited into them.

### 1. Reinforce the harmonic floor

Add or improve low-end support so the loop feels grounded.

- strengthen the root motion
- avoid muddy octave stacking below the lower midrange
- keep the bass line stable enough that the melody can stay lightweight above it

Rationale: the GB source is texturally busy. Desktop synths can expose weakness in the harmonic floor that the handheld speaker obscured.

### Why "stable" bass is the right resolution of the source's own busy low end

This is a resolution of a real tension, not an oversight of it. The GB source's lower support part is rhythmically busy — short, repeated motion, not long sustained roots — and that motion is part of the track's character; removing it would itself be unfaithful. "Stable" in this spec does not mean "static" or "simplified to whole notes." It means: the *root identity* under each harmonic span stays unambiguous even while the bass voice keeps its source rhythm, so a listener's ear always knows what the harmonic floor is, regardless of how much rhythmic activity is happening on top of and within it. The risk this guards against is specifically octave-doubling that busy motion — reinforcing every short repeated low note in parallel octaves would multiply the rhythmic density at the exact register where desktop synths render low notes as boomy, undifferentiated mass (unlike the GB's filtered, band-limited output). The fix is register discipline and selective doubling, not flattening the bass line's rhythm. Concretely: the bass keeps the source's rhythmic pattern; reinforcement (octave doubling, sustained pad support) is applied at phrase-level harmonic-change points, not to every repeated note, so the root stays legible without the busy motion becoming a stacked wall of low frequency.

### 2. Clarify the inner voices

Use the extra MIDI freedom to make the harmony easier to hear.

- preserve the original counterline behavior
- support chord tones that are implied but under-articulated in the source
- avoid doubling the melody so closely that the arrangement gets thick without getting clearer

Rationale: the song's charm depends on motion inside the texture, not just the top line.

### 3. Improve the loop transition

The end of the loop should return with energy but without awkward emphasis.

- preserve the original loop point
- avoid adding a cadence that makes the tune feel "finished"
- if needed, taper the final bar so the loop re-entry feels natural
- express any taper as a tempo-relative offset from the loop point (beats/ticks under the song's own tempo parameter), not a fixed millisecond or fixed-tick value, so it scales and runs correctly at both the normal tempo and the Hall-of-Fame alternate tempo

Rationale: city themes are meant to repeat. A remaster that sounds too conclusive will degrade the game loop experience.

### Why loop smoothness is its own change item

The loop boundary is a separate risk because the GB source is built to cycle, not to resolve. The song's ending does not function like a finale; it must hand off back into the opening with no sense of arrival. A MIDI arrangement can easily damage that by adding a strong release, a last-chord hold, or a phrase extension that makes the loop feel like an endpoint. Singling out the loop transition as its own concern ensures that the compiler-level loop boundary is audited as a functional musical handoff, preventing engineers from treating it as a generic track fade-out or allowing trailing decay to bleed across the reset point.

### 4. Refine percussion and motion

Keep the city bustle, but make it cleaner.

- preserve the rhythmic function of the original noise part
- reduce any MIDI drum clutter that blurs the groove
- keep repeated rhythmic figures articulate rather than over-quantized

Rationale: the original track's momentum comes from steady activity. Excess percussion detail would fight the source.

### 5. Differentiate the two renders appropriately

Do not make GM and MT-32 identical in expression.

- GM should be the conservative, widely compatible version
- MT-32 should be the richer version, with more expressive timbre and depth
- both must still share the same musical backbone (see "Why the musical backbone must be identical" above)

Rationale: the port supports both formats, and the player should hear the same composition filtered through each device's strengths.

### 6. Carry every change through the alternate-tempo execution

For each of items 1–5, the single unified YAML configuration must produce a correct and sync-locked result when the driver plays the track at the Hall-of-Fame tempo.

- timing logic must be verified at both tempos to confirm no desynchronization or drifting occurs over multiple loops.

## Constraints

- Do not change the underlying song identity.
- Do not add a new melody or countertheme that competes with the original.
- Do not alter the loop structure unless the change is strictly needed to preserve a clean repeat.
- Do not over-orchestrate the track into a film-score texture.
- Do not introduce harmony that contradicts the GB source.
- Do not rely on device-specific tricks that make one rendering good while making the other worse.
- Do not hand-edit the `.mid` files under `dos_port/assets/midi/`; all changes flow through the override/enhancement source and the standard asset build.
- Do not author enhancement timing that only regenerates correctly for one of the two tempo builds.
- Do not let the MT-32 rendering diverge from GM in harmonic progression or structural form; divergence is confined to voicing, timbre, and texture.

## Faithfulness Rules

A remaster is faithful if it preserves:

- the main melodic contour
- the core harmonic progression implied by the GB source
- the loop length and repetition logic
- the general balance of melody, accompaniment, and rhythmic support
- the city-theme mood: upbeat, compact, and continuously looping

A remaster is not faithful if it:

- replaces the song's identity with a new arrangement concept
- makes the loop feel like a terminating concert piece
- changes the melody enough that a listener would not recognize the original
- turns the piece into a different emotional genre

## Verification Criteria

A reviewer should verify both improvement and faithfulness with four checks. All checks are run against the generated outputs.

### 0. Build-provenance check

Confirm the shipped `.mid` files are current build output, not stale or hand-edited.

The reviewer should confirm:

- the `Music_Cities1` GM/MT-32 files are byte-reproducible from a clean `make assets` run against the checked-in override/enhancement source
- no diff exists between a fresh regeneration and the committed files

### 1. Score-level check

Compare the remastered MIDI against `audio/music/cities1.asm`.

The reviewer should confirm:

- the lead melody is still the same tune
- the bass motion still supports the original harmony
- the loop structure is unchanged or equivalently repeatable
- any new voices remain supportive rather than substitutive
- the GM and MT-32 files carry the same harmonic progression and structural form (per "Why the musical backbone must be identical")

### 2. Listening check

Audition both renderings.

To ensure consistency and avoid subjective variations across different emulators or wavetable synths, the audition and comparison checks must be anchored to the following fixed reference targets:
- **General MIDI (GM) Baseline Target:** The GM rendering must be auditioned using **FluidSynth** loaded with the standard **FluidR3_GM.sf2** soundfont. The reviewer must confirm the GM version sounds cleaner, fuller, and has clear voice/register separation under this baseline configuration without becoming muddy or overpacked. Anchoring the review to this target prevents varying outcomes caused by different host-side wavetable cards or thin default software synths.
- **Roland MT-32 Baseline Target:** The MT-32 rendering must be auditioned using **MUNT (mt32emu-qt)** with the standard Roland MT-32 ROMs.

The reviewer should confirm:

- the GM version sounds cleaner and fuller than the current shipped GM rendering under the baseline target, using the current shipped file and the GB source as the two fixed reference points (not a free-floating "better" judgment)
- the MT-32 version sounds richer than GM without losing clarity under its baseline target
- the melody remains the foreground voice throughout
- the ending loops naturally without a jarring reset, in both the normal-tempo and Hall-of-Fame alternate-tempo execution
- the track still feels like a city theme, not a rearranged medley
- the enhancement/base channels stay in sync through at least two loop cycles in each of the generated files

### Why the reviewer judgment is anchored this way

The decision does not rest on "sounds better" as a free-floating opinion. The reference point is the GB source and the shipped renders, with the source determining faithfulness and the current MIDIs determining whether the remaster is an improvement over the baseline. In practice, a reviewer's ears settle the listening check, but the ears are not free to invent criteria: they are checking against the score and against the prior files. The baseline targets (FluidSynth and MUNT) guarantee that both the developer and the reviewer are auditing identical timbres and dynamic ranges, removing hardware-specific variance from the verification process.

### 3. Faithfulness check

Measure the remaster against the original GB source, not just against the old MIDI files.

The reviewer should confirm:

- no important melodic event was dropped
- no major harmonic function was changed
- the remaster does not add structural contrast that the GB source does not contain
- the arrangement respects the original density and pacing instead of inventing new form

## Acceptance Criteria

The remaster is done when all of the following are true:

- the change is captured entirely as override/enhancement configuration, and all shipped `.mid` files (GM/MT-32) are regenerated from it, not edited by hand
- both normal-tempo MIDIs have been updated from the same arrangement intent
- the GM files are cleaner, more legible, and more balanced than the current ones under the baseline FluidSynth target
- the MT-32 files are richer and more expressive than the GM files under the baseline MUNT target, while sharing the same harmonic progression and structural form
- all generated files still read as `Cities1`
- the melody, loop, and harmonic backbone remain faithful to `audio/music/cities1.asm`
- the arrangement sounds better on target hardware without becoming a different piece

## Non-Goals

- rewriting the composition
- adding a new section
- converting the city theme into a cinematic or ambient remix
- making the two renderings diverge in musical identity
- optimizing for a device that is not part of the shipped GM / MT-32 target set
- hand-authoring `.mid` bytes outside the override/enhancement build pipeline
- letting either tempo execution or either device rendering carry different harmonic/structural content than the others
