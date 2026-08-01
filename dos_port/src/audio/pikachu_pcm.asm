; pikachu_pcm.asm — Pikachu's digitized voice (pret audio/pikachu_pcm.asm).
;
; Moved here from src/engine/pikachu/ to follow pret, which relocated the routine
; out of engine/pikachu/ into audio/ (upstream bd1b695b, "Identify and refactor
; Pikachu PCM cry code and data"); PikachuCriesPointerTable went with it, into
; pret audio/pikachu_cries_pointers.asm — the port's copy is generated Tier-1
; data in assets/pika_pcm.inc. src/audio/ deliberately mixes pret mirrors
; (engine_1..4.asm, poke_flute.asm) with the port's bespoke multi-device HAL
; (audio_hal, sb_pcm, opl_shim, mpu401, spk_*, tandy_shim); this file is a pret
; mirror whose body is a port-only device dispatch, and pika_dbg_snapshot below
; is port-only debug state that travels with it.
;
; On the GB, PlayPikachuSoundClip hijacked the wave channel's DAC with
; interrupts off and streamed a 1-bit clip through rAUD3LEVEL
; (PlayPikachuPCM, home/pikachu_cries.asm). The port plays the same clips as
; real PCM instead: gen_pika_pcm.py low-pass-filters the pret streams to
; 8-bit @ PIKA_PCM_RATE (assets/pika_pcm.inc), and this routine dispatches
; to the Sound Blaster DSP player (sb_pcm.asm) or the PC-speaker PWM player
; (spk_pcm.asm). Blocking with interrupts off is preserved — the GB froze
; the whole game for the clip too, so callers already expect it.
;
; Kept from pret: the 3-frame lead-in delay, and clearing the CHAN5-8 sound
; IDs afterwards (SFX state is stale after the freeze). The wave-RAM
; save/restore and APU register dance have no analog here — the APU shim
; never loses its state.
;
; All held notes are CUT before the clip (opl_silence + midi_all_notes_off):
; the shim's software envelopes freeze with interrupts off, so a held FM
; voice would drone through the whole clip — on the GB the *hardware*
; envelopes kept decaying through the freeze, so the cry stood alone there
; too. Music channels re-key on their next note events after the clip.

bits 32

%include "gb_memmap.inc"

global PlayPikachuSoundClip
global pika_dbg_snapshot

extern DelayFrame                 ; src/home/vblank.asm
extern g_audio_engine_online      ; src/home/audio.asm
extern g_sb_present               ; src/audio/audio_hal.asm
extern sb_pcm_play                ; src/audio/sb_pcm.asm
extern spk_pcm_play               ; src/audio/spk_pcm.asm
extern opl_silence                ; src/audio/opl_shim.asm (guarded, no-OPL safe)
extern midi_all_notes_off         ; src/audio/mpu401.asm (guarded, no-MPU safe)
extern tandy_silence              ; src/audio/tandy_shim.asm (guarded)
extern spk_silence                ; src/audio/spk_shim.asm (also frees PIT ch2
                                  ;  for spk_pcm's mode-0 use; safe always)

section .data
; Tier-1 generated data: table + blob (tools/audio/gen_pika_pcm.py). Included
; before .text so PIKA_PCM_RATE is defined when PIKA_STEP_FP is evaluated.
%include "assets/pika_pcm.inc"

; PIT input clocks per sample, 24.8 fixed point.
PIKA_STEP_FP equ (1193182 * 256 + PIKA_PCM_RATE / 2) / PIKA_PCM_RATE

section .text

; ---------------------------------------------------------------------------
; PlayPikachuSoundClip — play digitized Pikachu cry DL (pret: E), 0-based
; index into PikachuCriesPointerTable (ldpikacry). Blocks for the clip
; length. In: DL = clip index, EBP = GB memory base. Preserves EBP.
; ---------------------------------------------------------------------------
PlayPikachuSoundClip:
    push ebx
    mov bl, dl                    ; clip index survives the DelayFrames
    call DelayFrame               ; pret: 3 frames of lead-in
    call DelayFrame
    call DelayFrame
    cmp byte [g_audio_engine_online], 0
    je .done                      ; /NOSOUND or init failure: silent skip
    movzx ebx, bl
    cmp ebx, NUM_PIKA_CRIES
    jae .done
    push ebx
    call opl_silence              ; cut held FM voices (see header)
    call tandy_silence            ; cut held PSG voices
    call spk_silence              ; speaker gate off + hand PIT ch2 to spk_pcm
    call midi_all_notes_off       ; cut held MT-32/GM notes in MIDI mode
    pop ebx
    mov esi, [PikachuCriesPointerTable + ebx*8]
    mov ecx, [PikachuCriesPointerTable + ebx*8 + 4]
    mov [pika_dbg_clip], bl
    mov eax, PIKA_STEP_FP
    cmp byte [g_sb_present], 0
    je .speaker
    mov byte [pika_dbg_device], 1 ; 1 = SB DSP
    call sb_pcm_play
    jmp .played
.speaker:
    mov byte [pika_dbg_device], 2 ; 2 = PC speaker
    call spk_pcm_play
.played:
    mov [pika_dbg_played], eax
    ; pret: zero wChannelSoundIDs CHAN5-8 after the freeze (stale SFX state)
    xor eax, eax
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al
.done:
    pop ebx
    ret

; ---------------------------------------------------------------------------
; pika_dbg_snapshot — copy PCM-player state into the $D240+ debug scratch
; window (DEBUG_AUDIO harness; $D227-$D23D is midi_dbg_snapshot's):
;   $D240    last clip index      $D241 device (0 none, 1 SB, 2 speaker)
;   $D242-45 dd samples played
; In: EBP = GB memory base. Clobbers EAX.
;
; DEVIATION{class=HAL; pret=audio/pikachu_pcm.asm:PlayPikachuSoundClip; behavior=a port-only helper publishes which clip played, which device took it and how many samples it fed into a GB debug scratch window, state the Game Boy version has no equivalent of because it had no device choice; evidence=its only caller is RunAudioTest in src/debug/debug_dump.asm which is assembled into DEBUG_ harness builds only, and the device fields it reports exist solely because the port dispatches PCM across sb_pcm and spk_pcm; lifetime=retires with the DEBUG_AUDIO harness}
; ---------------------------------------------------------------------------
pika_dbg_snapshot:
    mov al, [pika_dbg_clip]
    mov [ebp + 0xD240], al
    mov al, [pika_dbg_device]
    mov [ebp + 0xD241], al
    mov eax, [pika_dbg_played]
    mov [ebp + 0xD242], eax
    ret

section .bss
align 4
pika_dbg_played: resd 1           ; samples the player reported back
pika_dbg_clip:   resb 1           ; last clip index requested
pika_dbg_device: resb 1           ; 0 = never played, 1 = SB, 2 = speaker
