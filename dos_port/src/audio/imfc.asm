; imfc.asm — IBM Music Feature Card (IMFC) driver + flat-stream MIDI sequencer.
;
; DEVIATION{class=HAL; pret=home/audio.asm:UpdateSound; behavior=music synthesized on IBM Music Feature Card via flat 60 Hz bytecode streams; evidence=IMFC is a 4-op FM synthesizer with proprietary parallel PIU interface; lifetime=permanent, the IMFC device path is a hardware boundary}
; Port-only module (no pret counterpart; descriptive names per convention).
;
; Plays the precompiled music streams in assets/imfc_streams.inc (generated
; by tools/audio/gb_to_midi.py + midi_to_stream.py --target imfc) on an IBM
; Music Feature Card (Yamaha FB-01 OPP 4-op FM synth core + PD71055 PIU)
; via 8 assigned MIDI channels on I/O base 0x2A20.
;
; Division of labor in IMFC mode (g_imfc_music = 1):
;   - The translated engine keeps running everything exactly as on GB —
;     music bookkeeping (wChannelSoundIDs, wLastMusicSoundID, fades, tempo)
;     stays authentic, and SFX/cries still voice through the OPL shim.
;   - opl_shim's voice_volume force-mutes a voice whose GB channel is NOT
;     SFX-owned, so the engine's music never sounds on FM — the stream
;     sequencer here is the audible music.
;   - AudioCommon_PlaySound mirrors music starts into imfc_seq_start and
;     stop-alls into imfc_seq_stop; everything else needs no game changes.

bits 32

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

extern tick_count
extern StopAllSounds

global imfc_detect
global imfc_upload
global imfc_seq_start
global imfc_seq_stop
global imfc_seq_tick
global imfc_all_notes_off
global imfc_dbg_snapshot
global g_imfc_music
global g_cfg_imfc
global g_imfc_present
global g_imfc_base

IMFC_PORT_PIU0  equ 0x0   ; Data from card to PC
IMFC_PORT_PIU1  equ 0x1   ; Data from PC to card
IMFC_PORT_PIU2  equ 0x2   ; Status / Handshake (bit 2 = OBF)
IMFC_PORT_PCR   equ 0x3   ; 8255 / PD71055 control register
IMFC_PORT_TSR   equ 0xC   ; Total status register
IMFC_POLL_BOUND equ 4000  ; bounded poll loop iterations

section .text

; ---------------------------------------------------------------------------
; imfc_detect — probe the TSR and handshake ports for the IMFC.
; An absent ISA bus reads 0xFF; a valid IMFC TSR has bits 2..6 as 0.
; On success, configures the 8255 PIU mode and sets g_imfc_present = 1.
; Preserves EBX, ESI, EDI.
; ---------------------------------------------------------------------------
imfc_detect:
    push ebx
    push edx
    mov dx, [g_imfc_base]
    add dx, IMFC_PORT_TSR
    in al, dx
    cmp al, 0xFF
    je .absent
    test al, 0x7C                 ; bits 2..6 must be 0 on valid card
    jnz .absent

    ; Configure 8255 PIU mode:
    ; Mode 1 for Group 0 (Port 0 input), Mode 1 for Group 1 (Port 1 output)
    ; Control word = 0xB4
    mov dx, [g_imfc_base]
    add dx, IMFC_PORT_PCR
    mov al, 0xB4
    out dx, al

    mov byte [g_imfc_present], 1
    mov byte [g_imfc_music], 1
    pop edx
    pop ebx
    ret

.absent:
    mov byte [g_cfg_imfc], 0
    mov byte [g_imfc_present], 0
    mov byte [g_imfc_music], 0
    pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; imfc_write_data — send one byte in AL to PIU1 with bounded handshake poll.
; Returns CF=0 on success, CF=1 on timeout.
; Preserves EBX, ESI, EDI.
; ---------------------------------------------------------------------------
imfc_write_data:
    push ebx
    push ecx
    push edx
    mov bl, al
    mov dx, [g_imfc_base]
    add dx, IMFC_PORT_PIU2
    mov ecx, IMFC_POLL_BOUND
.poll_obf:
    in al, dx
    test al, 0x04                 ; Port C bit 2: OBF (Output Buffer Full)
    jz .ready                     ; 0 = ready for next byte
    dec ecx
    jnz .poll_obf
    pop edx
    pop ecx
    pop ebx
    stc
    ret

.ready:
    mov dx, [g_imfc_base]
    add dx, IMFC_PORT_PIU1
    mov al, bl
    out dx, al
    pop edx
    pop ecx
    pop ebx
    clc
    ret

; ---------------------------------------------------------------------------
; imfc_upload — transmit the boot SysEx setup blob (assets/imfc_sysex.inc)
; to initialize memory protection, master volume, and 8 instrument channels.
; Preserves all registers.
; ---------------------------------------------------------------------------
imfc_upload:
    cmp byte [g_cfg_imfc], 1
    jne .off
    cmp byte [g_imfc_present], 0
    jz .off
    pushad
    mov esi, ImfcSysexBlob
.msg:
    movzx edi, word [esi]         ; message length
    test edi, edi
    jz .done
    add esi, 2
.byte:
    mov al, [esi]
    call imfc_write_data
    jc .done                      ; hardware wedged: give up quietly
    inc esi
    dec edi
    jnz .byte
    ; Pacing delay: 3 PIT ticks (~50 ms)
    mov ebx, [tick_count]
    add ebx, 3
.pace:
    cmp [tick_count], ebx
    jb .pace
    jmp .msg
.done:
    popad
.off:
    ret

; ---------------------------------------------------------------------------
; imfc_send_sysex_list — send a list of length-prefixed SysEx messages to
; the IMFC without pacing delays. Length of 0 terminates the list.
; Input: ESI = pointer to list (if 0, returns immediately)
; Preserves all registers.
; ---------------------------------------------------------------------------
imfc_send_sysex_list:
    test esi, esi
    jz .off
    pushad
.msg:
    movzx edi, word [esi]
    test edi, edi
    jz .done
    add esi, 2
.byte:
    mov al, [esi]
    call imfc_write_data
    jc .done
    inc esi
    dec edi
    jnz .byte
    jmp .msg
.done:
    popad
.off:
    ret

; ---------------------------------------------------------------------------
; imfc_seq_start — start the stream for music sound id AL (bank from
; wAudioROMBank). Called from AudioCommon_PlaySound. Preserves all registers.
; ---------------------------------------------------------------------------
imfc_seq_start:
    cmp byte [g_imfc_music], 0
    jz .off
    pushad
    movzx eax, al                 ; sound id
    mov cl, [ebp + wAudioROMBank]
    xor ebx, ebx
    cmp cl, AUDIO_BANK_1
    je .bank_ok
    inc ebx
    cmp cl, AUDIO_BANK_2
    je .bank_ok
    inc ebx
    cmp cl, AUDIO_BANK_3
    je .bank_ok
    inc ebx
.bank_ok:
    mov edx, [bank_stream_tables + ebx*4]
    mov esi, [edx + eax*4]
    test esi, esi
    jz .no_stream

    push eax
    push ebx
    call imfc_all_notes_off
    pop ebx
    pop eax

    ; IMFC on-the-fly custom patch setup / cleanup
    push esi
    mov esi, [g_imfc_active_cleanup]
    test esi, esi
    jz .no_prev_cleanup
    call imfc_send_sysex_list
    mov dword [g_imfc_active_cleanup], 0
.no_prev_cleanup:
    mov edx, [bank_setup_tables + ebx*4]
    mov esi, [edx + eax*4]
    test esi, esi
    jz .no_new_setup
    call imfc_send_sysex_list
    mov edx, [bank_cleanup_tables + ebx*4]
    mov edx, [edx + eax*4]
    mov [g_imfc_active_cleanup], edx
.no_new_setup:
    pop esi

    movzx eax, word [esi]         ; loop_off
    lea ecx, [esi + 2]            ; first op byte
    mov [imfc_base], ecx
    mov [imfc_ptr], ecx
    cmp ax, 0xFFFF
    jne .haveLoop
    xor eax, eax
    mov [imfc_loop], eax
    jmp .noLoop
.haveLoop:
    add eax, ecx
    mov [imfc_loop], eax
.noLoop:
    mov word [imfc_wait], 0
    mov byte [imfc_on], 1
    ; Reset CC7 bases ($FF = untouched)
    mov edi, imfc_cc7_base
    mov ecx, 8 / 4
    mov eax, 0xFFFFFFFF
    rep stosd
    mov byte [imfc_scale], 7
.done:
    popad
.off:
    ret

.no_stream:
    call imfc_seq_stop
    jmp .done

; ---------------------------------------------------------------------------
; imfc_seq_stop — silence and stop the sequencer. Preserves all registers.
; ---------------------------------------------------------------------------
imfc_seq_stop:
    cmp byte [g_imfc_present], 0
    jz .off
    pushad
    cmp byte [imfc_on], 0
    jz .chk_cleanup
    mov byte [imfc_on], 0
    call imfc_all_notes_off
.chk_cleanup:
    mov esi, [g_imfc_active_cleanup]
    test esi, esi
    jz .done
    call imfc_send_sysex_list
    mov dword [g_imfc_active_cleanup], 0
.done:
    popad
.off:
    ret

; ---------------------------------------------------------------------------
; imfc_all_notes_off — CC123 (all notes off) + CC120 (all sound off) across
; active IMFC channels 0..7. Clobbers EAX, EBX, ECX, EDX.
; ---------------------------------------------------------------------------
imfc_all_notes_off:
    cmp byte [g_imfc_present], 0
    jz .done
    xor ebx, ebx
.chan:
    cmp ebx, 8
    jae .done
    mov al, bl
    or al, 0xB0
    call imfc_write_data
    mov al, 123
    call imfc_write_data
    xor al, al
    call imfc_write_data
    mov al, bl
    or al, 0xB0
    call imfc_write_data
    mov al, 120
    call imfc_write_data
    xor al, al
    call imfc_write_data
    inc ebx
    jmp .chan
.done:
    ret

; ---------------------------------------------------------------------------
; imfc_seq_tick — one 60 Hz sequencer step. Called from audio_tick.
; ---------------------------------------------------------------------------
imfc_seq_tick:
    cmp byte [imfc_on], 0
    jz .idle
    ; NR50 mirror: scale CC7 by lower 3 bits of rAUDVOL
    mov al, [ebp + rAUDVOL]
    and al, 7
    cmp al, [imfc_scale]
    je .noRescale
    mov [imfc_scale], al
    call imfc_rescale_cc7
.noRescale:
    mov ax, [imfc_wait]
    test ax, ax
    jz .pump
    dec ax
    mov [imfc_wait], ax
    jnz .idle
.pump:
    mov esi, [imfc_ptr]
.op:
    movzx eax, byte [esi]
    cmp al, 0x7F
    jbe .wait
    cmp al, 0xF0
    je .end
    cmp al, 0xF1
    je .loop

    ; MIDI message (0x80..0xEF)
    mov bl, al
    and bl, 0xF0

    ; Special handling for 0xBn (Control Change)
    cmp bl, 0xB0
    jne .standard_msg

    ; Intercept CC 0 (Bank Select) -> Translate to FB-01 SysEx:
    ; F0 43 1<ch> 15 04 <bank> F7
    cmp byte [esi + 1], 0
    jne .not_bank_select
    movzx edx, byte [esi]
    and edx, 0x0F                 ; channel
    mov al, 0xF0
    call imfc_write_data
    mov al, 0x43
    call imfc_write_data
    mov al, dl
    or al, 0x10                   ; 0x10 | ch
    call imfc_write_data
    mov al, 0x15
    call imfc_write_data
    mov al, 0x04                  ; param 4 = Voice Bank Number
    call imfc_write_data
    mov al, [esi + 2]             ; bank number
    call imfc_write_data
    mov al, 0xF7
    call imfc_write_data
    add esi, 3
    jmp .op

.not_bank_select:
    ; Snoop CC 7 to scale volume by NR50
    cmp byte [esi + 1], 7
    jne .standard_msg
    movzx edx, byte [esi]
    and edx, 0x0F
    mov al, [esi + 2]
    mov [imfc_cc7_base + edx], al
    call imfc_scale_vol
    mov bh, al                    ; scaled volume in BH
    mov al, [esi]
    call imfc_write_data
    mov al, 7
    call imfc_write_data
    mov al, bh
    call imfc_write_data
    add esi, 3
    jmp .op

.standard_msg:
    call imfc_write_data
    jc .dead
    mov al, [esi + 1]
    call imfc_write_data
    jc .dead
    cmp bl, 0xC0
    je .len1
    cmp bl, 0xD0
    je .len1
    mov al, [esi + 2]
    call imfc_write_data
    jc .dead
    add esi, 3
    jmp .op

.len1:
    add esi, 2
    jmp .op

.wait:
    mov [imfc_wait], ax
    inc esi
    mov [imfc_ptr], esi
    ret

.loop:
    mov esi, [imfc_loop]
    jmp .op

.end:
.dead:
    mov byte [imfc_on], 0
.idle:
    ret

; imfc_scale_vol — AL = CC7 base -> AL scaled by imfc_scale (0-7)/7
imfc_scale_vol:
    push edx
    movzx edx, al
    movzx eax, byte [imfc_scale]
    imul edx, eax
    mov eax, edx
    xor edx, edx
    mov dl, 7
    div dl                        ; AL = base*scale/7
    pop edx
    ret

; imfc_rescale_cc7 — retransmit scaled CC7 across all touched channels
imfc_rescale_cc7:
    pushad
    xor ebx, ebx
.scan:
    cmp ebx, 8
    jae .done
    mov al, [imfc_cc7_base + ebx]
    cmp al, 0xFF
    je .next
    call imfc_scale_vol
    mov bh, al
    mov al, bl
    or al, 0xB0
    call imfc_write_data
    mov al, 7
    call imfc_write_data
    mov al, bh
    call imfc_write_data
.next:
    inc ebx
    jmp .scan
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; imfc_dbg_snapshot — snapshot IMFC driver state for DEBUG_AUDIO
; ---------------------------------------------------------------------------
imfc_dbg_snapshot:
    mov al, [g_cfg_imfc]
    mov [ebp + (W_PORT_SCRATCH + 0x38)], al
    mov al, [g_imfc_present]
    mov [ebp + (W_PORT_SCRATCH + 0x39)], al
    mov al, [g_imfc_music]
    mov [ebp + (W_PORT_SCRATCH + 0x3A)], al
    mov al, [imfc_on]
    mov [ebp + (W_PORT_SCRATCH + 0x3B)], al
    ret

section .data

g_imfc_base:    dw 0x2A20
g_cfg_imfc:     db 0
g_imfc_present: db 0
g_imfc_music:   db 0

bank_stream_tables:
    dd ImfcStreamTable_Bank1
    dd ImfcStreamTable_Bank2
    dd ImfcStreamTable_Bank3
    dd ImfcStreamTable_Bank4

bank_setup_tables:
    dd ImfcSongSetupTable_Bank1
    dd ImfcSongSetupTable_Bank2
    dd ImfcSongSetupTable_Bank3
    dd ImfcSongSetupTable_Bank4

bank_cleanup_tables:
    dd ImfcSongCleanupTable_Bank1
    dd ImfcSongCleanupTable_Bank2
    dd ImfcSongCleanupTable_Bank3
    dd ImfcSongCleanupTable_Bank4

%include "assets/imfc_streams.inc"
%include "assets/imfc_sysex.inc"

section .bss
align 4

imfc_on:                resb 1
imfc_scale:             resb 1
imfc_wait:              resw 1
imfc_base:              resd 1
imfc_ptr:               resd 1
imfc_loop:              resd 1
g_imfc_active_cleanup:  resd 1
imfc_cc7_base:          resb 8
