; spk_shim.asm — virtual APU → PC-speaker device shim, SFX only (port-only
; HAL layer, the last-resort device).
;
; The speaker is one square-wave voice with no volume control, so playing
; 4-channel music on it would be noise. This shim voices only sound effects:
; when an SFX owns a GB pulse channel (wChannelSoundIDs CHAN5/CHAN6 nonzero —
; the engine writes the SFX's registers over that channel while it plays),
; the highest-priority audible one drives PIT channel 2 in mode 3 (square
; wave), gated through port 61h bits 0-1. Menu blips, collision bonks, and
; cry pulse voices come through; music and the noise channel stay silent.
;
; Like the other shims, the engine's NRx4 restart bit is CONSUMED here (ch0
; and ch1 only — ch2/ch3 bits are left set; the engine never reads them
; back), and envelope / sweep / length run in software per tick so notes
; end, pokeball arcs bend, and a decayed-to-zero voice releases the gate.
; The GB envelope's only audible mapping on a 1-bit speaker is on/off:
; volume 0 = gate closed, anything else = gate open.
;
; PIT ch2 is shared with spk_pcm.asm (the Pikachu clip player, which
; reprograms it to mode 0). spk_silence closes the gate and invalidates the
; cached divisor so the first note after a clip reprograms mode 3 cleanly.
;
; Always present, nothing to probe: audio_init selects the shim via /SPK or
; as the fallback when no OPL answered. g_spk_on = 0 -> every entry no-ops.

%include "gb_memmap.inc"

global spk_shim_init
global spk_pass
global spk_silence
global spk_shim_shutdown
global spk_dbg_snapshot
global g_spk_on

section .text

PIT_CMD_PORT  equ 0x43
PIT_CH2_PORT  equ 0x42
SPK_GATE_PORT equ 0x61            ; bit 0 = ch2 gate, bit 1 = speaker data

; --- per-voice software state (pulse channels 0-1 only) --------------------
SS_FREQ       equ 0    ; word: GB 11-bit freq incl. sweep
SS_KEY        equ 2    ; byte: key-on flag
SS_ENVVOL     equ 3    ; byte: current GB volume 0-15
SS_ENVDIR     equ 4    ; byte: envelope direction (1 = up)
SS_ENVPER     equ 5    ; byte: envelope period (0 = off)
SS_ENVACC     equ 6    ; word: envelope accumulator (64/tick vs 60*period)
SS_LEN        equ 8    ; word: length counter (1/256 s units)
SS_LENACC     equ 10   ; word: length accumulator (256/tick vs 60)
SS_LENEN      equ 12   ; byte: length enable (NRx4 bit 6)
SS_SWEEP      equ 13   ; byte: NR10 latched at key-on (ch0 only)
SS_SWACC      equ 14   ; word: sweep accumulator (128/tick vs 60*period)
SS_SIZE       equ 16

; ===========================================================================
; spk_shim_init — reset state, mark the shim active. Preserves all registers.
; ===========================================================================
spk_shim_init:
    pushad
    mov byte [g_spk_on], 1
    mov ecx, 2 * SS_SIZE
    mov edi, spk_state
.clr:
    mov byte [edi], 0
    inc edi
    loop .clr
    call spk_silence
    popad
    ret

; spk_silence — close the speaker gate and forget the programmed divisor
; (forces a mode-3 reprogram on the next note). Safe with the shim inactive.
; Exported for PlayPikachuSoundClip, which hands PIT ch2 to spk_pcm.
spk_silence:
    push eax
    in al, SPK_GATE_PORT
    and al, 0xFC                  ; gate + data off
    out SPK_GATE_PORT, al
    mov word [spk_last_div], 0
    mov byte [spk_active_ch], 0xFF
    pop eax
    ret

; spk_shim_shutdown — leave the speaker quiet on exit. Preserves registers.
spk_shim_shutdown:
    jmp spk_silence

; ===========================================================================
; spk_pass — the per-tick pass. Called from audio_tick (DelayFrame is
; pushad-wrapped, registers may be clobbered freely).
;   EBX = GB pulse channel (0-1), ESI = its register file, EDI = its state
; ===========================================================================
spk_pass:
    cmp byte [g_spk_on], 0
    jz .off
    mov al, [ebp + rAUDTERM]
    mov [s_nr51_snap], al

    xor ebx, ebx
.chLoop:
    lea esi, [ebx*4 + ebx]
    add esi, 0xFF10               ; channel register base
    mov eax, ebx
    shl eax, 4                    ; ch * 16
    lea edi, [spk_state + eax]

    mov al, [ebp + esi + 4]       ; NRx4
    test al, 0x80
    jz .noRestart
    and al, 0x7F                  ; consume the restart bit
    mov [ebp + esi + 4], al
    call spk_keyon
    jmp .running
.noRestart:
    cmp byte [edi + SS_KEY], 0
    jz .next
    ; frequency follow (engine vibrato / pitch slides)
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + SS_FREQ], cx       ; output happens in the select step below
.running:
    cmp byte [edi + SS_KEY], 0
    jz .next
    call spk_sweep
    call spk_envelope
    call spk_length
.next:
    inc ebx
    cmp ebx, 2
    jb .chLoop

    ; --- select the output voice: SFX-owned ch0 first, then ch1 ------------
    xor ebx, ebx
    mov edi, spk_state
    call spk_audible
    jnc .drive
    inc ebx
    add edi, SS_SIZE
    call spk_audible
    jnc .drive
    ; nothing to voice: gate off (idempotent port toggle avoided via cache)
    cmp byte [spk_active_ch], 0xFF
    je .off
    call spk_silence
.off:
    ret
.drive:
    mov [spk_active_ch], bl
    ; GB freq -> Hz -> PIT divisor, program on change
    movzx eax, word [edi + SS_FREQ]
    mov ecx, 2048
    sub ecx, eax
    mov eax, 131072
    xor edx, edx
    div ecx                       ; EAX = Hz (>= 64, so the divisor fits)
    mov ecx, eax
    mov eax, 1193182
    xor edx, edx
    div ecx
    cmp eax, 65535
    jbe .fit
    mov eax, 65535
.fit:
    cmp ax, [spk_last_div]
    je .gate
    mov [spk_last_div], ax
    inc word [spk_div_writes]     ; cumulative, for the debug snapshot
    mov ecx, eax
    mov al, 0xB6                  ; ch2, lobyte/hibyte, mode 3 (square wave)
    out PIT_CMD_PORT, al
    mov al, cl
    out PIT_CH2_PORT, al
    mov al, ch
    out PIT_CH2_PORT, al
.gate:
    in al, SPK_GATE_PORT
    mov ah, al
    and ah, 3
    cmp ah, 3
    je .done                      ; both bits already set
    or al, 3
    out SPK_GATE_PORT, al
.done:
    ret

; ---------------------------------------------------------------------------
; spk_audible — CF clear if channel EBX should drive the speaker: an SFX owns
; it (wChannelSoundIDs CHAN5+ch nonzero), it is keyed, its envelope is above
; zero, and NR51 doesn't mute it. Clobbers EAX ECX.
; ---------------------------------------------------------------------------
spk_audible:
    cmp byte [ebp + wChannelSoundIDs + CHAN5 + ebx], 0
    jz .no
    cmp byte [edi + SS_KEY], 0
    jz .no
    cmp byte [edi + SS_ENVVOL], 0
    jz .no
    mov cl, bl
    mov al, 0x11
    shl al, cl
    test [s_nr51_snap], al        ; both terminal bits clear -> rest/duck
    jz .no
    clc
    ret
.no:
    stc
    ret

; ---------------------------------------------------------------------------
; spk_keyon — latch envelope/length/sweep/frequency for channel EBX (same
; sequence as the other shims; no device write — output is selected per tick).
; ---------------------------------------------------------------------------
spk_keyon:
    mov al, [ebp + esi + 2]       ; NRx2
    mov ah, al
    shr ah, 4
    mov [edi + SS_ENVVOL], ah
    mov ah, al
    shr ah, 3
    and ah, 1
    mov [edi + SS_ENVDIR], ah
    and al, 7
    mov [edi + SS_ENVPER], al
    mov word [edi + SS_ENVACC], 0
    movzx eax, byte [ebp + esi + 1]
    and eax, 0x3F
    neg eax
    add eax, 64
    mov [edi + SS_LEN], ax
    mov word [edi + SS_LENACC], 0
    mov al, [ebp + esi + 4]
    and al, 0x40
    mov [edi + SS_LENEN], al
    test ebx, ebx
    jnz .noSweep
    mov al, [ebp + rAUD1SWEEP]
    mov [edi + SS_SWEEP], al
    mov word [edi + SS_SWACC], 0
.noSweep:
    mov cl, [ebp + esi + 3]
    mov ch, [ebp + esi + 4]
    and ch, 7
    mov [edi + SS_FREQ], cx
    mov byte [edi + SS_KEY], 1
    ret

spk_keyoff:
    mov byte [edi + SS_KEY], 0
    ret

; ---------------------------------------------------------------------------
; spk_sweep / spk_envelope / spk_length — the same GB-unit software emulation
; as the other shims (see opl_shim.asm for the timing derivations).
; ---------------------------------------------------------------------------
spk_sweep:
    test ebx, ebx
    jnz .done
    mov al, [edi + SS_SWEEP]
    mov cl, al
    shr cl, 4
    and cl, 7                     ; period
    jz .done
    movzx eax, cl
    imul eax, 60
    movzx ecx, word [edi + SS_SWACC]
    add ecx, 128
    cmp ecx, eax
    jb .store
    sub ecx, eax
    mov [edi + SS_SWACC], cx
    movzx eax, word [edi + SS_FREQ]
    mov edx, eax
    mov cl, [edi + SS_SWEEP]
    and cl, 7
    shr eax, cl
    test byte [edi + SS_SWEEP], 8
    jnz .down
    add edx, eax
    cmp edx, 2048
    jb .apply
    jmp spk_keyoff                ; overflow silences the channel (GB rule)
.down:
    sub edx, eax
    jns .apply
    xor edx, edx
.apply:
    mov [edi + SS_FREQ], dx
    ret
.store:
    mov [edi + SS_SWACC], cx
.done:
    ret

spk_envelope:
    mov al, [edi + SS_ENVPER]
    test al, al
    jz .done
    movzx ecx, al
    imul ecx, 60
    movzx eax, word [edi + SS_ENVACC]
    add eax, 64
    cmp eax, ecx
    jb .store
    sub eax, ecx
    mov cl, [edi + SS_ENVVOL]
    cmp byte [edi + SS_ENVDIR], 0
    jz .down
    cmp cl, 15
    jae .store
    inc cl
    jmp .set
.down:
    test cl, cl
    jz .store
    dec cl
.set:
    mov [edi + SS_ENVVOL], cl
.store:
    mov [edi + SS_ENVACC], ax
.done:
    ret

spk_length:
    cmp byte [edi + SS_LENEN], 0
    jz .done
    movzx eax, word [edi + SS_LENACC]
    add eax, 256
    movzx ecx, word [edi + SS_LEN]
.step:
    cmp eax, 60
    jb .save
    sub eax, 60
    dec ecx
    jnz .step
    mov word [edi + SS_LEN], 0
    mov byte [edi + SS_LENEN], 0
    mov [edi + SS_LENACC], ax
    jmp spk_keyoff
.save:
    mov [edi + SS_LEN], cx
    mov [edi + SS_LENACC], ax
.done:
    ret

; ---------------------------------------------------------------------------
; spk_dbg_snapshot — copy shim state into the $D250+ debug scratch window
; (DEBUG_AUDIO window 9 spans $D220-$D25F; tandy uses $D248-4F):
;   $D250    g_spk_on             $D251     active channel (0xFF = none)
;   $D252-53 last PIT divisor     $D254/55  ch0/ch1 SS_KEY
;   $D256-57 divisor writes since boot (proves SFX drove the speaker)
; In: EBP = GB memory base. Clobbers EAX.
; ---------------------------------------------------------------------------
spk_dbg_snapshot:
    mov al, [g_spk_on]
    mov [ebp + 0xD250], al
    mov al, [spk_active_ch]
    mov [ebp + 0xD251], al
    mov ax, [spk_last_div]
    mov [ebp + 0xD252], al
    mov [ebp + 0xD253], ah
    mov al, [spk_state + 0*SS_SIZE + SS_KEY]
    mov [ebp + 0xD254], al
    mov al, [spk_state + 1*SS_SIZE + SS_KEY]
    mov [ebp + 0xD255], al
    mov ax, [spk_div_writes]
    mov [ebp + 0xD256], al
    mov [ebp + 0xD257], ah
    ret

section .data

g_spk_on:       db 0              ; /SPK or no-OPL fallback selected the shim
spk_active_ch:  db 0xFF           ; channel currently driving the speaker

section .bss

spk_state:      resb 2 * SS_SIZE
spk_last_div:   resw 1
spk_div_writes: resw 1
s_nr51_snap:    resb 1
