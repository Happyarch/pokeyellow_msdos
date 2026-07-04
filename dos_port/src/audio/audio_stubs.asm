; audio_stubs.asm — ret-only stubs for the sound/music engine entry points that
; overworld/battle routines call but which have no audio backend yet. The port has
; no APU emulation (Phase 3 audio HAL); these keep the faithful call structure
; resolvable at link time. Each just returns — callers that only sequence sound are
; inert; callers that busy-wait on sound state MUST bound their wait against these
; (a ret-stub never advances a sound-done flag), per the overworld-port plan.
;
; TODO-HW: audio HAL (Phase 3) — replace each stub with the real driver call.
; Retire a stub when its real routine lands (move out of this file, repoint externs).
;
; Register map: A→AL, HL→ESI, BC→BX, DE→DX; GB mem = [ebp+SYM] (gb_memmap.inc).

bits 32

section .text

; StopAllMusic — pret home/audio.asm:StopAllMusic (silence all channels + reset
; the music state). TODO-HW: audio HAL (Phase 3). Never produces sound; safe no-op.
global StopAllMusic
StopAllMusic:
    ret

; WaitForSoundToFinish — pret home/audio.asm:WaitForSoundToFinish (spin until the
; low-priority sound flag clears). TODO-HW: audio HAL (Phase 3). Returns immediately;
; callers that looped on the sound-done flag are already satisfied (nothing playing).
global WaitForSoundToFinish
WaitForSoundToFinish:
    ret

; PlayMusic — pret home/audio.asm:PlayMusic (start the track in A). TODO-HW: audio
; HAL (Phase 3). No-op; the track id in AL is ignored.
global PlayMusic
PlayMusic:
    ret

; PlayDefaultMusic — pret home/audio.asm:PlayDefaultMusic (resume the current map's
; music). TODO-HW: audio HAL (Phase 3). No-op.
global PlayDefaultMusic
PlayDefaultMusic:
    ret
