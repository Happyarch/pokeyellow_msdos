; mpu401.asm — MPU-401 UART driver + flat-stream MIDI sequencer (Phase B).
; Port-only module (no pret counterpart; descriptive names per convention).
;
; Plays the precompiled music streams in assets/music_streams.inc (generated
; by tools/audio/gb_to_midi.py + midi_to_stream.py) on an MPU-401 in UART
; mode — MT-32 or General MIDI module on the other end of the cable.
;
; Division of labor in MIDI mode (g_midi_music = 1):
;   - The translated engine keeps running EVERYTHING exactly as on GB —
;     music bookkeeping (wChannelSoundIDs, wLastMusicSoundID, fades, tempo)
;     stays authentic, and SFX/cries still voice through the OPL shim.
;   - opl_shim's voice_volume force-mutes a voice whose GB channel is NOT
;     SFX-owned, so the engine's music never sounds on FM — the stream
;     sequencer here is the audible music (classic MT-32 + SB combo).
;   - AudioCommon_PlaySound mirrors music starts into midi_seq_start and
;     stop-alls into midi_seq_stop; everything else needs no game changes.
;
; Stream format (see midi_to_stream.py):
;   dw loop_off (0xFFFF = play once), then ops:
;     00-7F wait N frames | 80-EF MIDI msg (status + 1-2 data)
;     F0 end: stop        | F1 end: jump to loop_off
;
; Fades: FadeOutAudio ramps rAUDVOL (NR50) down and then starts the next
; song via PlaySound. midi_seq_tick mirrors NR50's terminal volume (0-7)
; into scaled CC7 for every MIDI channel the stream has touched, tracking
; each channel's most recent in-stream CC7 as the 100% base. The stream's
; own messages are rescaled on the way out, so a fade in progress applies
; to them too.
;
; Timing note: a message burst (song-start program changes + first chord)
; blocks in mpu_write_data's DRR handshake at ~320 µs/byte on real UART
; hardware; a start-of-song burst of a few dozen bytes costs ~1 frame once.
; All polls are bounded — absent/wedged hardware degrades to silence, never
; a hang; a write timeout mid-song stops the sequencer.

bits 32

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global mpu_detect
global mt32_upload
global midi_seq_start
global midi_seq_stop
global midi_seq_tick

extern tick_count                 ; boot/timing.asm — 60 Hz PIT tick counter
global g_midi_music
global g_cfg_midi
global g_mpu_present
global g_mpu_base

MPU_POLL_BOUND  equ 4000          ; status reads before declaring timeout
MPU_DRR         equ 0x40          ; status bit 6: 0 = ready for output
MPU_DSR         equ 0x80          ; status bit 7: 0 = data available
MPU_CMD_RESET   equ 0xFF
MPU_CMD_UART    equ 0x3F
MPU_ACK         equ 0xFE

section .text

; ---------------------------------------------------------------------------
; mpu_detect — probe g_mpu_base for an MPU-401 and put it in UART mode.
; Called from audio_init when /MT32 or /GM was given. Requires an ACK to at
; least one of RESET/UART (DOSBox-X and real MPUs ACK both; an interface
; already in UART mode may swallow the reset ACK). On failure clears
; g_cfg_midi so the OPL path keeps the music. Preserves all registers.
; ---------------------------------------------------------------------------
mpu_detect:
    pushad
    xor edi, edi                  ; ACK-seen accumulator
    call mpu_wait_drr
    jc .absent
    movzx edx, word [g_mpu_base]
    inc edx
    mov al, MPU_CMD_RESET
    out dx, al
    call mpu_read_ack
    or edi, eax
    call mpu_wait_drr
    jc .absent
    movzx edx, word [g_mpu_base]
    inc edx
    mov al, MPU_CMD_UART
    out dx, al
    call mpu_read_ack
    or edi, eax
    test edi, edi
    jz .absent
    mov byte [g_mpu_present], 1
    mov byte [g_midi_music], 1
    popad
    ret
.absent:
    mov byte [g_cfg_midi], 0      ; fall back to OPL music
    popad
    ret

; mpu_wait_drr — poll until the interface accepts output. CF = timeout.
; Clobbers EAX ECX EDX.
mpu_wait_drr:
    movzx edx, word [g_mpu_base]
    inc edx                       ; status port
    mov ecx, MPU_POLL_BOUND
.poll:
    in al, dx
    test al, MPU_DRR
    jz .ready
    loop .poll
    stc
    ret
.ready:
    clc
    ret

; mpu_read_ack — drain incoming bytes briefly; EAX = 1 if an ACK ($FE) was
; among them, else 0. Clobbers ECX EDX.
mpu_read_ack:
    xor eax, eax
    movzx edx, word [g_mpu_base]
    inc edx
    mov ecx, MPU_POLL_BOUND
.poll:
    push eax
    in al, dx
    test al, MPU_DSR
    pop eax
    jnz .next                     ; no data pending
    push edx
    dec edx                       ; data port
    push eax
    in al, dx
    cmp al, MPU_ACK
    pop eax
    pop edx
    jne .next
    mov eax, 1
    ret
.next:
    loop .poll
    ret

; mpu_write_data — send AL to the MIDI OUT data port after the DRR
; handshake. CF = timeout (hardware wedged). Clobbers ECX EDX; preserves AL.
mpu_write_data:
    push eax
    call mpu_wait_drr
    pop eax
    jc .fail
    movzx edx, word [g_mpu_base]
    out dx, al
    clc
.fail:
    ret

; ---------------------------------------------------------------------------
; mt32_upload — send the generated MT-32 setup SysEx (assets/mt32_sysex.inc:
; LCD greeting, reverb + partial reserves + channel table, custom timbres,
; patch/rhythm rewrites) after a successful probe. /MT32 only — a GM module
; gets no Roland DT1s. Messages are paced 3 PIT ticks (~50 ms) apart, the
; classic MT-32 buffer-safety interval (pit_init runs before audio_init, so
; tick_count is live). A write timeout aborts the upload but leaves MIDI
; mode on. Preserves all registers.
; ---------------------------------------------------------------------------
mt32_upload:
    cmp byte [g_cfg_midi], 1      ; MT-32 mode only
    jne .off
    cmp byte [g_mpu_present], 0
    jz .off
    pushad
    mov esi, Mt32SysexBlob
.msg:
    movzx edi, word [esi]         ; message length (EDI survives
    test edi, edi                 ;  mpu_write_data's ECX/EDX clobber)
    jz .done
    add esi, 2
.byte:
    mov al, [esi]
    call mpu_write_data
    jc .done                      ; interface wedged: give up quietly
    inc esi
    dec edi
    jnz .byte
    mov ebx, [tick_count]
    add ebx, 3                    ; let the MT-32 chew on the message
.pace:
    cmp [tick_count], ebx
    jb .pace
    jmp .msg
.done:
    popad
.off:
    ret

; ---------------------------------------------------------------------------
; midi_seq_start — start the stream for music sound id AL (bank from
; wAudioROMBank, exactly the (id, bank) addressing the engine dispatch
; uses). Called from AudioCommon_PlaySound's music path on every music
; start; no-op when MIDI mode is inactive or the id has no stream (the
; engine keeps the song on OPL then). Preserves all registers.
; ---------------------------------------------------------------------------
midi_seq_start:
    cmp byte [g_midi_music], 0
    jz .off
    pushad
    movzx eax, al
    mov cl, [ebp + wAudioROMBank]
    mov esi, MidiStreamTable_Bank1
    cmp cl, AUDIO_BANK_1
    je .table
    mov esi, MidiStreamTable_Bank2
    cmp cl, AUDIO_BANK_2
    je .table
    mov esi, MidiStreamTable_Bank3
    cmp cl, AUDIO_BANK_3
    je .table
    mov esi, MidiStreamTable_Bank4
.table:
    mov esi, [esi + eax*4]
    test esi, esi
    jz .done                      ; no stream for this id
    call midi_all_notes_off       ; clean handover from the previous song
    movzx eax, word [esi]         ; loop_off
    lea ecx, [esi + 2]            ; first op byte
    mov [midi_base], ecx
    mov [midi_ptr], ecx
    cmp ax, 0xFFFF
    jne .haveLoop
    xor eax, eax
    mov [midi_loop], eax
    jmp .noLoop
.haveLoop:
    add eax, ecx
    mov [midi_loop], eax
.noLoop:
    mov word [midi_wait], 0
    mov byte [midi_on], 1
    ; forget CC7 bases from the previous song ($FF = channel untouched)
    mov edi, midi_cc7_base
    mov ecx, 16 / 4
    mov eax, 0xFFFFFFFF
    rep stosd
    mov byte [midi_scale], 7
.done:
    popad
.off:
    ret

; ---------------------------------------------------------------------------
; midi_seq_stop — silence and stop the sequencer (stop-all-audio path,
; audio_shutdown). Preserves all registers.
; ---------------------------------------------------------------------------
midi_seq_stop:
    cmp byte [midi_on], 0
    jz .off
    pushad
    mov byte [midi_on], 0
    call midi_all_notes_off
    popad
.off:
    ret

; midi_all_notes_off — CC123 (all notes off) + CC120 (all sound off) on the
; melodic channels and the rhythm channel. Clobbers EAX EBX ECX EDX.
midi_all_notes_off:
    cmp byte [g_mpu_present], 0
    jz .done
    mov ebx, midi_used_channels
.chan:
    mov ah, [ebx]
    test ah, ah
    js .done                      ; $FF terminator
    mov al, ah
    or al, 0xB0
    call mpu_write_data
    mov al, 123
    call mpu_write_data
    xor al, al
    call mpu_write_data
    mov al, [ebx]
    or al, 0xB0
    call mpu_write_data
    mov al, 120
    call mpu_write_data
    xor al, al
    call mpu_write_data
    inc ebx
    jmp .chan
.done:
    ret

; ---------------------------------------------------------------------------
; midi_seq_tick — one 60 Hz sequencer step. Called from audio_tick after the
; engine update + opl_pass (DelayFrame is pushad-wrapped; clobbers freely).
; ---------------------------------------------------------------------------
midi_seq_tick:
    cmp byte [midi_on], 0
    jz .idle
    ; NR50 mirror: engine fades ramp both terminals together; scale CC7
    mov al, [ebp + rAUDVOL]
    and al, 7
    cmp al, [midi_scale]
    je .noRescale
    mov [midi_scale], al
    call midi_rescale_cc7
.noRescale:
    mov ax, [midi_wait]
    test ax, ax
    jz .pump
    dec ax
    mov [midi_wait], ax
    jnz .idle                     ; still waiting
.pump:
    mov esi, [midi_ptr]
.op:
    movzx eax, byte [esi]
    cmp al, 0x7F
    jbe .wait
    cmp al, 0xF0
    je .end
    cmp al, 0xF1
    je .loop
    ; MIDI message: status + 1 or 2 data bytes.
    ; (kind lives in BL — mpu_write_data clobbers ECX/EDX in its DRR poll)
    mov bl, al
    and bl, 0xF0
    call mpu_write_data
    jc .dead
    mov al, [esi + 1]
    call mpu_write_data
    jc .dead
    cmp bl, 0xC0
    je .len1
    cmp bl, 0xD0
    je .len1
    ; two data bytes; snoop CC7 to track fade bases and rescale on the fly
    mov al, [esi + 2]
    cmp bl, 0xB0
    jne .send2
    cmp byte [esi + 1], 7
    jne .send2
    movzx edx, byte [esi]
    and edx, 0x0F
    mov [midi_cc7_base + edx], al
    call midi_scale_vol
.send2:
    call mpu_write_data
    jc .dead
    add esi, 3
    jmp .op
.len1:
    add esi, 2
    jmp .op
.wait:
    mov [midi_wait], ax
    inc esi
    mov [midi_ptr], esi
    ret
.loop:
    mov esi, [midi_loop]
    jmp .op
.end:                             ; clean end-of-stream (op $F0)
.dead:                            ; or a write timeout mid-song
    mov byte [midi_on], 0
.idle:
    ret

; midi_scale_vol — AL = CC7 base value → AL scaled by midi_scale (0-7)/7.
; Clobbers AH.
midi_scale_vol:
    push edx
    movzx edx, al
    movzx eax, byte [midi_scale]
    imul edx, eax
    mov eax, edx
    xor edx, edx
    mov dl, 7
    div dl                        ; AL = base*scale/7
    pop edx
    ret

; midi_rescale_cc7 — resend scaled CC7 on every channel with a known base
; (fade step). Clobbers EAX EBX ECX EDX.
midi_rescale_cc7:
    xor ebx, ebx
.chan:
    mov al, [midi_cc7_base + ebx]
    cmp al, 0xFF
    je .next
    push eax
    mov al, bl
    or al, 0xB0
    call mpu_write_data
    mov al, 7
    call mpu_write_data
    pop eax
    call midi_scale_vol
    call mpu_write_data
.next:
    inc ebx
    cmp ebx, 16
    jb .chan
    ret

; ---------------------------------------------------------------------------
; midi_dbg_snapshot — MIDI driver state into GB scratch (DEBUG_AUDIO dump),
; continuing the $D220 window after the SB fields:
;   $D227 g_cfg_midi, +1 g_mpu_present, +2 g_midi_music, +3 midi_on,
;   +4 dw stream progress (midi_ptr - midi_base), +6 midi_scale,
;   +7.. midi_cc7_base[0..15]
; ---------------------------------------------------------------------------
global midi_dbg_snapshot
midi_dbg_snapshot:
    push ecx
    mov al, [g_cfg_midi]
    mov [ebp + 0xD227], al
    mov al, [g_mpu_present]
    mov [ebp + 0xD228], al
    mov al, [g_midi_music]
    mov [ebp + 0xD229], al
    mov al, [midi_on]
    mov [ebp + 0xD22A], al
    mov eax, [midi_ptr]
    sub eax, [midi_base]
    mov [ebp + 0xD22B], al
    mov [ebp + 0xD22C], ah
    mov al, [midi_scale]
    mov [ebp + 0xD22D], al
    xor ecx, ecx
.cc7:
    mov al, [midi_cc7_base + ecx]
    mov [ebp + 0xD22E + ecx], al
    inc ecx
    cmp ecx, 16
    jb .cc7
    pop ecx
    ret

; ---------------------------------------------------------------------------
section .data

g_cfg_midi:     db 0              ; /MT32 = 1, /GM = 2 (0 = OPL music)
g_midi_music:   db 0              ; MIDI mode active (probe succeeded)
g_mpu_present:  db 0
g_mpu_base:     dw 0x330          ; data port; status/command = +1

; channels gb_to_midi.py emits on: GB ch1/2/3 → 1/2/3, noise → 9 (rhythm)
midi_used_channels: db 1, 2, 3, 9, 0xFF

; generated music streams + per-bank id → stream tables
%include "assets/music_streams.inc"

; generated MT-32 setup SysEx (length-prefixed DT1s, dw 0 terminated)
%include "assets/mt32_sysex.inc"

section .bss

midi_base:      resd 1            ; first op byte of the current stream
midi_ptr:       resd 1            ; current op position
midi_loop:      resd 1            ; resolved loop target (0 = play once)
midi_wait:      resw 1            ; frames until the next op group
midi_on:        resb 1
midi_scale:     resb 1            ; NR50 terminal volume 0-7 (7 = full)
midi_cc7_base:  resb 16           ; last in-stream CC7 per channel ($FF unset)
