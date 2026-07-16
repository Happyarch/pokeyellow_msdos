; home_stubs.asm — ret-only stubs for pret home/ routines that must resolve at
; link time but whose real bodies are deferred. Per the stub convention
; (project-conventions skill), the stand-in lives HERE under its exact pret
; label — never as a ret-only body in the file that will eventually hold the
; real routine (src/home/text_script.asm already holds the faithful body; it is
; simply not linkable yet).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; ---------------------------------------------------------------------------
; PlayCry — pret ref: home/pokemon.asm:PlayCry (AL = species).
;
; The mon cry. pret ref: home/pokemon.asm:140 — FOURTEEN instructions, a direct
; translation. Do not read this stub as "cries are a big audio project": they are
; not. Everything under PlayCry already exists in the port:
;   CryData              assets/cry_data.inc — GENERATED and exported (`global
;                        CryData`, src/data/audio_data.asm); 3 bytes per species
;                        index: base cry id, pitch mod, tempo mod.
;   the engine           src/audio/engine_1.asm already understands cries —
;                        Audio1_IsCry, CRY_SFX_START/CRY_SFX_END, and it consumes
;                        wFrequencyModifier (:881) and wTempoModifier (:857).
;   PlaySound            src/home/audio.asm — real (gated on g_audio_engine_online,
;                        which audio_init sets; music plays, so it is on).
;   WaitForSoundToFinish src/home/audio.asm — real; spins on wChannelSoundIDs
;                        CHAN5/6/8.
; TWO routines are missing, and only two:
;   GetCryData  — pret home/pokemon.asm:157. Currently a ret-stub, and one living
;                 in the WRONG FILE (src/engine/menus/pokedex.asm, not a *_stubs.asm
;                 — convention violation, fix it on the way past). Indexes CryData by
;                 species-1 (3 bytes/entry) → B = cry id, wFrequencyModifier,
;                 wTempoModifier; returns A = cry_id*3 + CRY_SFX_START (cry headers
;                 are 3 channels each). Its BankswitchHome/Back pair is a flat no-op.
;   PlayCry     — this stub. Zero wLowHealthAlarm around GetCryData → PlaySound →
;                 WaitForSoundToFinish, then restore it.
; Open question, honestly unknown: whether the OPL/MT-32 shims render a cry
; acceptably once the virtual APU is handed one. That is tuning, not a blocker.
;
; CONTRACT — THE PART A ret-ONLY STUB SILENTLY BREAKS. pret's PlayCry ends in
; WaitForSoundToFinish: it BLOCKS for the duration of the cry. Callers depend on that
; duration, not on any register or flag. The port's one live caller is the text_asm
; hook inside UsedStrengthText (field_move_messages.asm) — `call PlayCry / call
; Delay3 / jmp TextScriptEnd` — where the block is the ONLY thing holding "<MON> used
; STRENGTH." on screen. With a bare ret, Delay3's 3 frames are all message 1 gets
; before "<MON> can move boulders." paints over it: observed live, 2026-07-13, the
; message reads as SKIPPED. So this stub is not free, and the earlier comment here
; claiming it "costs the cry and nothing else" was wrong.
;
; A ret-only stub satisfies the stub convention and can still be wrong, when the
; contract callers rely on is HOW LONG IT TAKES. Ledger: M-32.
;
; TODO(audio): retire together with GetCryData. This stub is what lets
; field_move_messages.asm LINK — it was the file's only unresolved symbol, and it
; gated STRENGTH + SURF (menu-fidelity row 9 part 3).
; ---------------------------------------------------------------------------
global PlayCry
PlayCry:
    ret

; ---------------------------------------------------------------------------
; GetCryData — STUB. pret ref: home/pokemon.asm:157 (NOT home/audio.asm).
;
; MOVED HERE 2026-07-14 (menu-fidelity row 16 / M-66). It had been sitting as a
; ret-stub inside engine/menus/pokedex.asm — a SOURCE-MIRROR file — which is exactly
; where stubs may not live (CLAUDE.md / project-conventions). Its own comment there
; admitted the violation; nobody had acted on it. It belongs beside PlayCry, its only
; caller, because the two must be destubbed together.
;
; An older comment claimed "No audio HAL in this port (Phase 3)". That is FALSE, and
; has been since the audio phases merged (2026-07-07): the engine is live, music plays,
; PlaySound and WaitForSoundToFinish are real bodies, and src/audio/engine_1.asm already
; understands cries (Audio1_IsCry, CRY_SFX_START/END, and it reads the two modifier vars
; this routine is supposed to set). The cry data is generated and exported too
; (assets/cry_data.inc → `global CryData`). Nothing about the HAL blocks this. What
; blocks it is that nobody has written these ~15 instructions.
;
; The real body (pret home/pokemon.asm:157): index CryData by species-1, 3 bytes per
; entry → B = base cry id, [wFrequencyModifier] = pitch mod, [wTempoModifier] = tempo
; mod; return A = cry_id*3 + CRY_SFX_START (cry headers are 3 channels each). The
; BankswitchHome/BankswitchBack pair around the table read is a no-op in the flat port.
;
; Live callers of this stub: PlayCry (above) and the POKéDEX side menu's CRY option
; (engine/menus/pokedex.asm .choseCry → GetCryData → PlaySound). Both are silent, and
; both go loud the moment this returns real data. Ledger: M-32.
; ---------------------------------------------------------------------------
global GetCryData
GetCryData:
    ret
