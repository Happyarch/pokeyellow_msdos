; opl_enh.asm — tier-1 OPL enhancement stream player (Phase E).
;
; Plays the pre-compiled enhancement streams (assets/enh_streams.inc, from
; tools/audio/gen_enh_streams.py) on the FM voices the APU shim doesn't use,
; ALONGSIDE — never instead of — the faithful opl_shim pass. The stream is
; dumb by design: voice numbers, fnum/block, patch indices and carrier
; levels are all precomputed by deterministic Python; this player only
; writes registers on cue at 60 Hz (the same frame clock as the engine, so
; the layer stays aligned with the base channels it was authored against).
;
; Voice pool: pool 0-4 = OPL voices 4-8 (first register array; the shim owns
; 0-3, and /SFXOVERLAP — still deferred — will contend here when it lands).
; Pool 5-9 = the second array's voices 0-4, OPL3 only: on an OPL2 their
; events are dropped whole (the generator warns when a song needs them).
;
; Start/stop mirrors mpu401's midi_seq: AudioCommon_PlaySound's music path
; calls enh_seq_start with the sound id, table picked by wAudioROMBank.
; Active only when the OPL shim is the device (g_shim_device == 1) and MIDI
; mode is off (in MIDI mode the MT-32/GM stream already carries the full
; arrangement, tiers included).
;
; NR50 master volume (fades!) is mirrored every tick: the engine's
; FadeOutAudio ramps NR50, and the enhancement layer must fade with the
; base channels or it would keep playing at full level over a fade-out.

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global enh_init
global enh_seq_start
global enh_seq_stop
global enh_seq_tick
global enh_dbg_snapshot

extern opl_write                  ; src/audio/opl_shim.asm
extern opl_write_hi
extern OplPatches
extern OplSlotMod
extern OplRegGroups
extern OplMasterAttTable
extern g_opl3
extern g_opl_present
extern g_shim_device              ; src/audio/audio_hal.asm
extern g_cfg_noenh                ; src/audio/audio_hal.asm — /NOENH
extern g_midi_music               ; src/audio/mpu401.asm

OPL_PATCH_SIZE_E equ 11           ; keep in sync with assets/opl_patches.inc

; per-pool-voice state
EV_KEY   equ 0                    ; byte: key-on flag
EV_PATCH equ 1                    ; byte: loaded patch id (0xFF = none)
EV_B0    equ 2                    ; byte: last B0 written (incl. key bit)
EV_KSL   equ 3                    ; byte: patch carrier KSL bits ($C0 mask)
EV_LVL   equ 4                    ; byte: stream carrier level 0-63
EV_SIZE  equ 8

POOL_SIZE      equ 10
POOL_OPL2_SAFE equ 5

section .text

; ---------------------------------------------------------------------------
; enh_init — reset caches (no port I/O; call once from audio_init).
; ---------------------------------------------------------------------------
enh_init:
    push edi
    push ecx
    mov edi, enh_state
    mov ecx, POOL_SIZE
.v:
    mov byte [edi + EV_KEY], 0
    mov byte [edi + EV_PATCH], 0xFF
    add edi, EV_SIZE
    loop .v
    mov byte [enh_on], 0
    mov byte [enh_master], 0xFF   ; force a level pass on first tick
    pop ecx
    pop edi
    ret

; ---------------------------------------------------------------------------
; enh_voice_of — pool index EBX -> physical voice AL + write fn selection.
; Returns CF set if the voice is unusable (second array on an OPL2).
; ---------------------------------------------------------------------------
; (inlined logic via enh_chan_write/enh_slot_of below)

; enh_chan_write — write AL to per-channel register base AH (A0/B0/C0) of
; pool voice EBX. Preserves EBX ESI EDI; clobbers EAX ECX EDX.
enh_chan_write:
    cmp ebx, POOL_OPL2_SAFE
    jae .hi
    add ah, bl
    add ah, 4                     ; pool 0-4 -> voices 4-8, array 0
    jmp opl_write
.hi:
    cmp byte [g_opl3], 0
    jz .skip                      ; OPL2: no second array — drop whole
    add ah, bl
    sub ah, POOL_OPL2_SAFE        ; pool 5-9 -> voices 0-4, array 1
    jmp opl_write_hi
.skip:
    ret

; enh_slot_of — CL = modulator slot offset for pool voice EBX (array-local).
enh_slot_of:
    cmp ebx, POOL_OPL2_SAFE
    jae .hi
    mov cl, [OplSlotMod + ebx + 4]
    ret
.hi:
    mov cl, [OplSlotMod + ebx - POOL_OPL2_SAFE]
    ret

; ---------------------------------------------------------------------------
; enh_loadpatch — load patch AL onto pool voice EBX (EDI = voice state)
; unless cached. Clobbers EAX ECX EDX; preserves EBX ESI EDI.
; ---------------------------------------------------------------------------
enh_loadpatch:
    cmp al, [edi + EV_PATCH]
    je .done
    cmp ebx, POOL_OPL2_SAFE       ; OPL2: don't burn port writes on a voice
    jb .usable                    ; that can never sound
    cmp byte [g_opl3], 0
    jz .done
.usable:
    mov [edi + EV_PATCH], al
    push esi
    push ebx
    movzx esi, al
    imul esi, OPL_PATCH_SIZE_E
    add esi, OplPatches
    call enh_slot_of
    mov bh, cl                    ; modulator slot offset
    push edi
    xor edi, edi                  ; reg-group index 0-4
.ops:
    mov ah, [OplRegGroups + edi]
    add ah, bh                    ; modulator register
    mov al, [esi + edi]
    call .write
    add ah, 3                     ; carrier register (slot + 3)
    mov al, [esi + edi + 5]
    call .write
    inc edi
    cmp edi, 5
    jb .ops
    pop edi
    ; cache the carrier KSL bits for level writes
    mov al, [esi + 6]
    and al, 0xC0
    mov [edi + EV_KSL], al
    pop ebx
    pop esi
.done:
    ret
.write:                           ; AH reg / AL val -> the voice's array
    cmp byte [esp + 8], POOL_OPL2_SAFE   ; saved EBX (pool index)
    jae .whi
    jmp opl_write
.whi:
    jmp opl_write_hi

; ---------------------------------------------------------------------------
; enh_level — write pool voice EBX's carrier $40 from EV_KSL/EV_LVL +
; the cached master attenuation. Clobbers EAX ECX EDX.
; ---------------------------------------------------------------------------
enh_level:
    mov al, [edi + EV_LVL]
    add al, [enh_master_att]
    cmp al, 63
    jbe .clamped
    mov al, 63
.clamped:
    or al, [edi + EV_KSL]
    call enh_slot_of
    mov ah, 0x40 + 3              ; carrier level register
    add ah, cl
    cmp ebx, POOL_OPL2_SAFE
    jae .hi
    jmp opl_write
.hi:
    cmp byte [g_opl3], 0
    jz .skip
    jmp opl_write_hi
.skip:
    ret

; ---------------------------------------------------------------------------
; enh_all_off — key off every pool voice (port I/O only if an OPL answered).
; ---------------------------------------------------------------------------
enh_all_off:
    cmp byte [g_opl_present], 0
    jz .done
    push ebx
    push edi
    xor ebx, ebx
    mov edi, enh_state
.v:
    cmp byte [edi + EV_KEY], 0
    jz .next
    mov byte [edi + EV_KEY], 0
    mov al, [edi + EV_B0]
    and al, 0x1F                  ; clear the key bit
    mov [edi + EV_B0], al
    mov ah, 0xB0
    call enh_chan_write
.next:
    add edi, EV_SIZE
    inc ebx
    cmp ebx, POOL_SIZE
    jb .v
    pop edi
    pop ebx
.done:
    ret

; ---------------------------------------------------------------------------
; enh_seq_start — start the enhancement stream for music sound id AL
; (bank from wAudioROMBank, same addressing as midi_seq_start). Called from
; AudioCommon_PlaySound's music path. Preserves all registers.
; ---------------------------------------------------------------------------
enh_seq_start:
    pushad
    ; whatever was playing stops now — a song with no enhancement layer
    ; must not inherit the previous song's
    call enh_all_off
    mov byte [enh_on], 0
    cmp byte [g_cfg_noenh], 0
    jne .done                     ; /NOENH: enhancement layer disabled (A/B)
    cmp byte [g_shim_device], 1
    jne .done                     ; OPL shim not the active device
    cmp byte [g_midi_music], 0
    jnz .done                     ; MIDI stream carries the full arrangement
    movzx eax, byte [esp + 28]    ; original AL (pushad: EAX at ESP+28)
    mov cl, [ebp + wAudioROMBank]
    mov esi, EnhStreamTable_Bank1
    cmp cl, AUDIO_BANK_1
    je .table
    mov esi, EnhStreamTable_Bank2
    cmp cl, AUDIO_BANK_2
    je .table
    mov esi, EnhStreamTable_Bank3
    cmp cl, AUDIO_BANK_3
    je .table
    mov esi, EnhStreamTable_Bank4
.table:
    mov esi, [esi + eax*4]
    test esi, esi
    jz .done                      ; no enhancement layer for this song
    movzx eax, word [esi]         ; loop_off
    lea ecx, [esi + 2]            ; first op byte
    mov [enh_base], ecx
    mov [enh_ptr], ecx
    cmp ax, 0xFFFF
    jne .haveLoop
    xor eax, eax
    mov [enh_loop], eax
    jmp .noLoop
.haveLoop:
    add eax, ecx
    mov [enh_loop], eax
.noLoop:
    mov word [enh_wait], 0
    mov byte [enh_on], 1
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; enh_seq_stop — silence and stop the layer. Preserves all registers.
; ---------------------------------------------------------------------------
enh_seq_stop:
    pushad
    call enh_all_off
    mov byte [enh_on], 0
    popad
    ret

; ---------------------------------------------------------------------------
; enh_seq_tick — one 60 Hz step. Called from audio_tick right after
; opl_pass (so it only ever runs when the OPL shim is the device).
; ---------------------------------------------------------------------------
enh_seq_tick:
    cmp byte [enh_on], 0
    jz .off

    ; mirror NR50's louder terminal into the layer's master attenuation
    mov al, [ebp + rAUDVOL]
    mov ah, al
    and al, 7                     ; right volume
    shr ah, 4
    and ah, 7                     ; left volume
    cmp al, ah
    jae .haveVol
    mov al, ah
.haveVol:
    cmp al, [enh_master]
    je .waitCheck
    mov [enh_master], al
    movzx eax, al
    mov al, [OplMasterAttTable + eax]
    mov [enh_master_att], al
    ; re-level every keyed voice at the new master
    xor ebx, ebx
    mov edi, enh_state
.relevel:
    cmp byte [edi + EV_KEY], 0
    jz .rnext
    call enh_level
.rnext:
    add edi, EV_SIZE
    inc ebx
    cmp ebx, POOL_SIZE
    jb .relevel

.waitCheck:
    movzx eax, word [enh_wait]
    test eax, eax
    jz .ops
    dec eax
    mov [enh_wait], ax
    test eax, eax
    jnz .off                      ; still waiting
.ops:
    mov esi, [enh_ptr]
.op:
    movzx eax, byte [esi]
    inc esi
    cmp al, 0x80
    jb .wait                      ; 01-7F: wait
    cmp al, 0xA0
    jb .keyoff                    ; 80-8F
    cmp al, 0xF0
    jb .keyon                     ; A0-AF
    je .stop                      ; F0
    mov esi, [enh_loop]           ; F1: jump to loop
    test esi, esi
    jnz .op
.stop:
    call enh_all_off
    mov byte [enh_on], 0
    jmp .off

.wait:
    mov [enh_wait], ax
    mov [enh_ptr], esi
.off:
    ret

.keyoff:
    and eax, 0x0F
    mov ebx, eax
    imul edi, ebx, EV_SIZE
    add edi, enh_state
    cmp byte [edi + EV_KEY], 0
    jz .op
    mov byte [edi + EV_KEY], 0
    mov al, [edi + EV_B0]
    and al, 0x1F
    mov [edi + EV_B0], al
    mov ah, 0xB0
    call enh_chan_write
    jmp .op

.keyon:
    and eax, 0x0F
    mov ebx, eax
    imul edi, ebx, EV_SIZE
    add edi, enh_state
    mov al, [esi]                 ; patch
    call enh_loadpatch
    mov al, [esi + 4]             ; lvl
    mov [edi + EV_LVL], al
    call enh_level
    mov al, [esi + 3]             ; c0 (patch C0 | pan)
    mov ah, 0xC0
    call enh_chan_write
    mov al, [esi + 1]             ; a0: fnum low
    mov ah, 0xA0
    call enh_chan_write
    mov al, [esi + 2]             ; b0: block | fnum hi
    or al, 0x20                   ; key on
    mov [edi + EV_B0], al
    mov byte [edi + EV_KEY], 1
    mov ah, 0xB0
    call enh_chan_write
    add esi, 5
    jmp .op

; ---------------------------------------------------------------------------
; enh_dbg_snapshot — debug window 9, $D258-$D25C:
;   +0 enh_on, +1/+2 key mask (pool voices 0-9), +3/+4 stream offset.
; ---------------------------------------------------------------------------
enh_dbg_snapshot:
    push eax
    push ecx
    push edx
    mov al, [enh_on]
    mov [ebp + 0xD258], al
    xor eax, eax
    xor ecx, ecx
    mov edx, enh_state
.mask:
    cmp byte [edx + EV_KEY], 0
    jz .m0
    bts eax, ecx
.m0:
    add edx, EV_SIZE
    inc ecx
    cmp ecx, POOL_SIZE
    jb .mask
    mov [ebp + 0xD259], ax
    mov eax, [enh_ptr]
    sub eax, [enh_base]
    mov [ebp + 0xD25B], ax
    pop edx
    pop ecx
    pop eax
    ret

section .data

%include "assets/enh_streams.inc"

section .bss

enh_state:      resb POOL_SIZE * EV_SIZE
enh_base:       resd 1
enh_ptr:        resd 1
enh_loop:       resd 1
enh_wait:       resw 1
enh_on:         resb 1
enh_master:     resb 1            ; cached NR50 louder terminal (0xFF = none)
enh_master_att: resb 1
