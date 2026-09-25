; sb_pcm.asm — Sound Blaster DSP PCM player (direct-mode and single-cycle DMA).
; Port-only module (no pret counterpart; descriptive names per convention).
;
; Supports two playback paths for 8-bit unsigned mono PCM:
; 1. Single-Cycle 8-bit DMA (primary path):
;    Streams audio via 8237 DMA Channel 1 and DSP command $14 from conventional
;    DOS memory (< 1 MB, allocated via DPMI 0100h) without crossing 64 KB DMA
;    boundaries. Completion is signaled via DSP IRQ (acknowledged at port 2xEh)
;    and monitored via DMA count wrap. This frees the CPU to continue running
;    DelayFrame at 60 FPS while cries sound, keeping Pokéball grow/shrink and
;    sprite animations completely fluid.
; 2. Direct Mode (guarded fallback):
;    Hand-feeds the DAC one sample at a time via DSP command $10 and PIT pacing
;    with interrupts disabled. Activated if /NODMA is passed or DMA setup fails.
;
; DEVIATION{class=HAL; pret=home/pikachu_cries.asm:PlayPikachuPCM; behavior=a digitized clip is fed to a Sound Blaster DSP via DMA or direct mode, instead of being streamed as 1-bit samples through the Game Boy wave channel's DAC via rAUD3LEVEL; evidence=the DOS target has no wave channel and its DSP takes 8-bit PCM bytes rather than a DAC level, so both the output path and the timebase must be re-derived, and no pret routine has a DSP or PIT counterpart; lifetime=permanent, the PCM device shim is a hardware boundary}

bits 32

%include "gb_memmap.inc"

global sb_pcm_play
global pcm_pace_init
global pcm_pace
global sb_cry_play
global sb_dma_init
global sb_dma_shutdown
global sb_dma_play
global sb_sfx_dma_play
global sb_dma_poll_completion
global g_sb_nodma
global g_sb_dma_active

%ifndef ENABLE_PIKA_PCM
%define ENABLE_PIKA_PCM 1
%endif

%if ENABLE_PIKA_PCM != 0

extern g_sb_base                  ; src/audio/audio_hal.asm (BLASTER A field)
extern g_sb_irq                   ; src/audio/audio_hal.asm (BLASTER I field)
extern g_sb_dma                   ; src/audio/audio_hal.asm (BLASTER D field)
extern g_sb_present               ; src/audio/audio_hal.asm
extern current_pit_divisor        ; boot/timing.asm
extern ds_base                    ; boot/entry.asm
extern DelayFrame                 ; src/home/vblank.asm

; --- Pokemon cry audio engine externs (Stage 2/3) ---
extern opl_silence                ; src/audio/opl_shim.asm
extern enh_seq_stop               ; src/audio/opl_enh.asm
extern midi_all_notes_off         ; src/audio/mpu401.asm
extern tandy_silence              ; src/audio/tandy_shim.asm
extern spk_silence                ; src/audio/spk_shim.asm
extern covox_silence              ; src/audio/covox_shim.asm
extern cms_silence                ; src/audio/cms_shim.asm
extern innova_silence             ; src/audio/innova_shim.asm
extern g_cry_rate                 ; src/input/input_cfg.asm
extern cry_synth_set_rate         ; src/audio/cry_synth.asm
extern cry_pcm_buffer             ; src/audio/cry_synth.asm
extern cry_render_species         ; src/audio/cry_synth.asm
extern g_cry_frames_rendered      ; src/audio/cry_synth.asm
extern sfx_render_clip            ; src/audio/cry_synth.asm
extern SfxSoftApuMask             ; assets/sfx_data.inc
extern tick_count                 ; boot/timing.asm

PIT_CMD_PORT    equ 0x43
PIT_CH0_PORT    equ 0x40
%ifndef PIT_DIVISOR
%define PIT_DIVISOR 19506         ; SGB default, matches boot/timing.asm
%endif
DSP_TIMEOUT     equ 4000          ; bounded write-ready polls

section .data
align 4
g_sb_nodma:      db 0             ; 1 = disable DMA via /NODMA
g_sb_dma_active: db 0             ; 1 = DMA playback currently in progress
dma_ready:       db 0             ; 1 = DMA buffer & IRQ successfully initialized
sb_irq_vec:      db 0             ; mapped interrupt vector (e.g. 0x0D or 0x0F)
orig_pic_mask:   db 0             ; original PIC mask bit for g_sb_irq

section .text

align 4
sb_isr_ds:       dw 0             ; DS selector for ISR (CS-readable)

; ---------------------------------------------------------------------------
; dsp_write — write AL to the DSP command/data port with a bounded
; write-ready poll. In: EBX = DSP base. Out: CF set on timeout. Preserves AL.
; ---------------------------------------------------------------------------
dsp_write:
    push ecx
    mov ah, al
    lea edx, [ebx + 0xC]
    mov ecx, DSP_TIMEOUT
.rdy:
    in al, dx
    test al, 0x80                 ; bit 7 clear = ready for write
    jz .send
    loop .rdy
    mov al, ah
    pop ecx
    stc
    ret
.send:
    mov al, ah
    out dx, al
    pop ecx
    clc
    ret

; ---------------------------------------------------------------------------
; sb_dma_isr — Sound Blaster DMA completion interrupt handler.
; Acknowledges DSP interrupt by reading port 2xEh and sends EOI to 8259 PIC.
; ---------------------------------------------------------------------------
sb_dma_isr:
    push eax
    push edx
    push ds
    mov ax, [cs:sb_isr_ds]
    mov ds, ax

    ; Acknowledge DSP interrupt by reading DSP Read Buffer Status (port 2xEh)
    movzx edx, word [g_sb_base]
    add edx, 0x0E
    in al, dx

    ; Send EOI (0x20) to 8259 PIC
    mov al, 0x20
    cmp byte [g_sb_irq], 8
    jb .masterOnly
    out 0xA0, al                  ; Slave PIC EOI
.masterOnly:
    out 0x20, al                  ; Master PIC EOI

    mov byte [g_sb_dma_active], 0

    pop ds
    pop edx
    pop eax
    iretd

; ---------------------------------------------------------------------------
; sb_dma_init — allocate conventional DMA buffer and hook Sound Blaster IRQ.
; Called from audio_init.
; ---------------------------------------------------------------------------
sb_dma_init:
    pushad
    cmp byte [g_sb_present], 0
    jz .done
    cmp byte [g_sb_nodma], 0
    jnz .done
    cmp byte [g_sb_dma], 1        ; support standard 8-bit Channel 1
    jne .done
    mov al, [g_sb_irq]
    test al, al
    jz .done
    cmp al, 15
    ja .done

    ; Save DS selector for the ISR
    mov ax, ds
    mov [sb_isr_ds], ax

    ; Allocate 32 KB conventional memory block (2048 paragraphs) via DPMI 0100h
    mov ax, 0x0100
    mov bx, 0x0800                ; 2048 paras = 32768 bytes
    int 0x31
    jc .done
    mov [dma_dos_seg], ax
    mov [dma_dos_sel], dx

    ; Physical address: linear = seg << 4
    movzx eax, ax
    shl eax, 4

    ; Check 64 KB boundary crossing for 16 KB transfer:
    ; if (linear & 0xFFFF) + 16384 > 0x10000 -> align to next 64 KB boundary
    mov ecx, eax
    and ecx, 0xFFFF
    add ecx, 16384
    cmp ecx, 0x10000
    jbe .aligned
    add eax, 0xFFFF
    and eax, ~0xFFFF
.aligned:
    mov [dma_phys_off], ax
    shr eax, 16
    mov [dma_phys_page], al

    ; Flat pointer: flat = physical - [ds_base]
    movzx eax, word [dma_phys_off]
    movzx edx, byte [dma_phys_page]
    shl edx, 16
    or eax, edx
    sub eax, [ds_base]
    mov [dma_flat], eax

    ; Determine interrupt vector: IRQ 0..7 -> INT 08h..0Fh, IRQ 8..15 -> INT 70h..77h
    movzx ecx, byte [g_sb_irq]
    cmp cl, 8
    jae .highIrq
    add cl, 0x08
    jmp .haveVec
.highIrq:
    add cl, 0x70 - 8
.haveVec:
    mov [sb_irq_vec], cl

    ; Get current PM vector (DPMI 0204h)
    mov ax, 0x0204
    mov bl, [sb_irq_vec]
    int 0x31
    mov [orig_irq_off], edx
    mov [orig_irq_sel], cx

    ; Install our PM vector (DPMI 0205h)
    mov ax, 0x0205
    mov bl, [sb_irq_vec]
    mov cx, cs
    mov edx, sb_dma_isr
    int 0x31

    ; Unmask IRQ at PIC
    movzx ecx, byte [g_sb_irq]
    cmp cl, 8
    jae .unmaskSlave
    in al, 0x21
    mov ah, 1
    shl ah, cl
    mov dl, al
    and dl, ah
    mov [orig_pic_mask], dl       ; remember prior mask
    not ah
    and al, ah
    out 0x21, al
    jmp .picDone
.unmaskSlave:
    sub cl, 8
    in al, 0xA1
    mov ah, 1
    shl ah, cl
    mov dl, al
    and dl, ah
    mov [orig_pic_mask], dl
    not ah
    and al, ah
    out 0xA1, al
    ; Also ensure cascade IRQ 2 is unmasked on Master PIC
    in al, 0x21
    and al, ~(1 << 2)
    out 0x21, al
.picDone:

    mov byte [dma_ready], 1

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; sb_dma_shutdown — restore PIC mask, DPMI vector, and free DOS buffer.
; Called from audio_shutdown.
; ---------------------------------------------------------------------------
sb_dma_shutdown:
    pushad
    cmp byte [dma_ready], 0
    je .done
    mov byte [dma_ready], 0

    ; Mask DMA Channel 1
    mov al, 0x05
    out 0x0A, al

    ; Restore PIC mask
    movzx ecx, byte [g_sb_irq]
    cmp cl, 8
    jae .restSlave
    in al, 0x21
    mov ah, [orig_pic_mask]
    or al, ah
    out 0x21, al
    jmp .restVec
.restSlave:
    sub cl, 8
    in al, 0xA1
    mov ah, [orig_pic_mask]
    or al, ah
    out 0xA1, al
.restVec:

    ; Restore PM interrupt vector (DPMI 0205h)
    mov ax, 0x0205
    mov bl, [sb_irq_vec]
    mov cx, [orig_irq_sel]
    mov edx, [orig_irq_off]
    int 0x31

    ; Free DOS memory block (DPMI 0101h)
    mov ax, 0x0101
    mov dx, [dma_dos_sel]
    int 0x31

.done:
    popad
    ret

; ---------------------------------------------------------------------------
; sb_dma_play — initiate single-cycle 8-bit DMA playback on Sound Blaster DSP.
; In:  ECX = sample count (1..16384)
;      EDX = sample rate in Hz
; Out: CF clear on start, CF set on error.
; ---------------------------------------------------------------------------
sb_dma_play:
    push ebx
    push ecx
    push edx

    movzx ebx, word [g_sb_base]
    test ebx, ebx
    jz .fail

    ; 1. Mask DMA Channel 1 (port 0x0A, val 0x05)
    mov al, 0x05
    out 0x0A, al

    ; 2. Clear flip-flop
    xor al, al
    out 0x0C, al

    ; 3. DMA mode: single-cycle (0x40), address increment (0x00), read/playback (0x08), Ch 1 (0x01) = 0x49
    mov al, 0x49
    out 0x0B, al

    ; 4. Clear flip-flop
    xor al, al
    out 0x0C, al

    ; 5. Write base physical address to port 0x02 (lo, then hi)
    mov ax, [dma_phys_off]
    out 0x02, al
    mov al, ah
    out 0x02, al

    ; 6. Write page register to port 0x83
    mov al, [dma_phys_page]
    out 0x83, al

    ; 7. Clear flip-flop
    xor al, al
    out 0x0C, al

    ; 8. Write count (length - 1) to port 0x03 (lo, then hi)
    mov eax, ecx
    dec eax
    out 0x03, al
    mov al, ah
    out 0x03, al

    ; 9. Unmask DMA Channel 1 (port 0x0A, val 0x01)
    mov al, 0x01
    out 0x0A, al

    ; 10. DSP speaker on (command 0xD1)
    mov al, 0xD1
    call dsp_write

    ; 11. Set time constant (command 0x40)
    mov al, 0x40
    call dsp_write

    ; Time constant argument: TC = 256 - (1000000 / rate)
    test edx, edx
    jnz .haveRate
    mov edx, 22050
.haveRate:
    mov eax, 1000000
    push ecx
    mov ecx, edx
    xor edx, edx
    div ecx                       ; EAX = 1000000 / rate
    pop ecx
    neg al                        ; AL = 256 - (1000000 / rate)
    call dsp_write

    ; Set active flag
    mov byte [g_sb_dma_active], 1

    ; 12. DSP command 0x14: 8-bit single-cycle DMA DAC output
    mov al, 0x14
    call dsp_write

    ; 13. Transfer length - 1 (lo byte, then hi byte)
    mov eax, ecx
    dec eax
    call dsp_write                ; lo byte
    mov al, ah
    call dsp_write                ; hi byte

    clc
    pop edx
    pop ecx
    pop ebx
    ret

.fail:
    stc
    pop edx
    pop ecx
    pop ebx
    ret

; ===========================================================================
; sb_sfx_dma_play — render and start single-cycle DMA playback for soft APU SFX.
; In:  AL  = sound ID (e.g. SFX_GO_INSIDE, SFX_GO_OUTSIDE)
;      EBP = GB memory base
; Out: CF clear on success (DMA started), CF set if fallback needed.
; Preserves EBP, AL, EBX.
; Clobbers: ECX, EDX, ESI, EDI.
; ===========================================================================
sb_sfx_dma_play:
    ; 1. Check if this sound ID is configured for soft APU playback
    push edx
    movzx edx, al
    bt [SfxSoftApuMask], edx
    pop edx
    jnc .notSoftApu

    ; 2. Check if Sound Blaster and DMA are available
    cmp byte [g_sb_present], 0
    jz .fallback
    cmp byte [dma_ready], 0
    jz .fallback
    cmp byte [g_sb_nodma], 0
    jnz .fallback
    cmp byte [g_sb_dma_active], 0
    jnz .fallback               ; DMA busy (e.g. cry or previous SFX still playing)

    ; 3. Render SFX into DMA buffer using soft APU synth
    push eax
    mov edi, [dma_flat]
    mov ecx, 16384
    call sfx_render_clip        ; renders bytecode to completion into [dma_flat]
    test eax, eax
    jz .renderFailed

    ; 4. Start background single-cycle DMA at 22,050 Hz
    mov ecx, eax                ; sample count
    mov edx, 22050              ; 22,050 Hz
    call sb_dma_play
    jc .renderFailed

    pop eax
    clc
    ret

.renderFailed:
    pop eax
.fallback:
.notSoftApu:
    stc
    ret

; ===========================================================================
; sb_dma_poll_completion — check if 8237 DMA count has wrapped to 0xFFFF.
; Clears g_sb_dma_active and acknowledges DSP interrupt.
; Called every audio tick from audio_tick.
; ===========================================================================
sb_dma_poll_completion:
    cmp byte [g_sb_dma_active], 0
    jz .done
    movzx edx, byte [g_sb_dma]
    lea edx, [edx * 2 + 1]        ; port 0x03 for Channel 1
    xor al, al
    out 0x0C, al                  ; clear flip-flop
    in al, dx
    mov ah, al
    in al, dx
    xchg al, ah                   ; AX = count
    cmp ax, 0xFFFF
    jne .done

    ; Hardware DMA reached end of buffer: acknowledge DSP
    movzx edx, word [g_sb_base]
    test edx, edx
    jz .clearFlag
    add edx, 0x0E
    in al, dx
.clearFlag:
    mov byte [g_sb_dma_active], 0
.done:
    ret

; ---------------------------------------------------------------------------
; sb_pcm_play — play a clip on the DSP, blocking, interrupts off (Direct Mode).
; In:  ESI = flat ptr to 8-bit unsigned samples
;      ECX = sample count (>0)
;      EAX = pacing step: PIT input clocks per sample in 24.8 fixed point
; Out: EAX = samples actually played (== count unless the DSP wedged)
; Clobbers: EBX/ECX/EDX/EDI; advances ESI. Preserves EBP.
; ---------------------------------------------------------------------------
sb_pcm_play:
    mov edi, ecx                  ; samples remaining
    movzx ebx, word [g_sb_base]
    test ebx, ebx
    jz .nodsp
    pushfd
    cli
    call pcm_pace_init
    mov al, 0xD1                  ; DSP speaker on (needed on pre-4.xx DSPs)
    call dsp_write
    jc .abort
.sample:
    call pcm_pace
    mov al, 0x10                  ; DSP direct-mode output
    call dsp_write
    jc .abort
    mov al, [esi]
    call dsp_write
    jc .abort
    inc esi
    dec edi
    jnz .sample
.abort:
    mov al, 0xD3                  ; DSP speaker off
    call dsp_write
    popfd
    mov eax, ecx
    sub eax, edi                  ; samples played
    ret
.nodsp:
    xor eax, eax
    ret

; ---------------------------------------------------------------------------
; pcm_pace_init — arm the pacer. In: EAX = step (PIT clocks per tick, 24.8
; fixed point). Clobbers AX/DX flags only. Call with interrupts off.
; ---------------------------------------------------------------------------
pcm_pace_init:
    mov [pace_step], eax
    xor eax, eax
    mov [pace_acc], eax
    call pit_latch_ch0
    mov [pace_prev], ax
    ret

; ---------------------------------------------------------------------------
; pcm_pace — busy-wait until one pacing step has elapsed since the last
; return (steps never drift: the fractional remainder carries over, and an
; overrun is repaid on the next call). Clobbers EAX/EDX.
; ---------------------------------------------------------------------------
pcm_pace:
.wait:
    call pit_latch_ch0
    mov dx, [pace_prev]
    mov [pace_prev], ax
    sub dx, ax                    ; elapsed mode-3 counts = prev - cur
    jnc .noWrap
    add dx, [current_pit_divisor] ; latched counter reloaded mid-gap
.noWrap:
    movzx edx, dx
    shl edx, 7                    ; counts dec by 2 per clock; <<8 fp, /2
    add edx, [pace_acc]
    mov [pace_acc], edx
    cmp edx, [pace_step]
    jb .wait
    sub edx, [pace_step]
    mov [pace_acc], edx
    ret

; pit_latch_ch0 — latch and read PIT channel 0. Out: AX = count. Clobbers AL.
pit_latch_ch0:
    xor al, al                    ; latch command, channel 0
    out PIT_CMD_PORT, al
    in al, PIT_CH0_PORT
    mov ah, al
    in al, PIT_CH0_PORT
    xchg al, ah                   ; AX = lo | hi<<8
    ret

; ---------------------------------------------------------------------------
; sb_cry_play — play monster AL's cry on Sound Blaster DSP.
; Prefers asynchronous DMA playback, keeping DelayFrame running at 60 FPS
; so visual animations (Pokéball growth, retreating, blinking) never stall.
; Falls back to Direct Mode if /NODMA is set or DMA buffer is unavailable.
;
; In:  AL  = species ID (1..151)
;      EBP = GB memory base
; Out: AL, EBX, EBP preserved.
; Clobbers: ECX, EDX, ESI, EDI.
; ---------------------------------------------------------------------------
sb_cry_play:
    push ebx
    push esi
    push edi
    push eax                      ; preserve AL (species ID) on stack

    ; a) Silence/mute all active sound sources:
    call opl_silence
    call enh_seq_stop
    call midi_all_notes_off
    call tandy_silence
    call spk_silence
    call covox_silence
    call cms_silence
    call innova_silence

    ; b) Check if DMA playback is ready:
    cmp byte [dma_ready], 0
    je .fallbackDirect
    cmp byte [g_sb_nodma], 0
    jne .fallbackDirect

    ; --- DMA Playback Path (60 FPS Non-Blocking) ---
    movzx eax, word [g_cry_rate]
    call cry_synth_set_rate

    ; Render species cry directly into DMA buffer (max 16 KB):
    mov al, [esp]                 ; restore AL = species ID
    mov edi, [dma_flat]
    mov ecx, 16384
    call cry_render_species
    test eax, eax
    jz .dmaFinished

    mov ecx, eax                  ; samples count
    movzx edx, word [g_cry_rate]
    call sb_dma_play
    jc .fallbackDirect            ; if DSP reject, try direct fallback

    ; Mark SFX channels active
    mov byte [ebp + wChannelSoundIDs + CHAN5], 0xFF
    mov byte [ebp + wChannelSoundIDs + CHAN6], 0xFF
    mov byte [ebp + wChannelSoundIDs + CHAN8], 0xFF

.waitDmaLoop:
    cmp byte [g_sb_dma_active], 0
    je .dmaFinished

    ; Poll 8237 DMA count register for wrap (0xFFFF means DMA completed)
    movzx edx, byte [g_sb_dma]
    lea edx, [edx * 2 + 1]        ; port 0x03 for Channel 1
    xor al, al
    out 0x0C, al                  ; clear flip-flop
    in al, dx
    mov ah, al
    in al, dx
    xchg al, ah                   ; AX = count
    cmp ax, 0xFFFF
    jne .pumpFrame

    ; Hardware DMA reached end of buffer: acknowledge DSP
    movzx edx, word [g_sb_base]
    add edx, 0x0E
    in al, dx
    mov byte [g_sb_dma_active], 0
    jmp .dmaFinished

.pumpFrame:
    call DelayFrame               ; render screen at 60 FPS while cry sounds
    jmp .waitDmaLoop

.dmaFinished:
    ; Clear SFX channels
    xor eax, eax
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al
    pop eax
    pop edi
    pop esi
    pop ebx
    ret

.fallbackDirect:
    ; --- Fallback Direct Mode Path (/NODMA or DMA allocation failure) ---
    ; Render a single frame first so the 7x7 mon is visible before freezing
    call DelayFrame

    movzx eax, word [g_cry_rate]
    call cry_synth_set_rate

    mov al, [esp]                 ; restore AL = species ID
    mov edi, cry_pcm_buffer
    mov ecx, 65536
    call cry_render_species

    test eax, eax
    jz .directReconcile
    push eax

    ; Calculate pacing step: step = (1193182 * 256 + rate / 2) / rate
    movzx ecx, word [g_cry_rate]
    test ecx, ecx
    jnz .haveDirectRate
    mov ecx, 22050
.haveDirectRate:
    mov eax, ecx
    shr eax, 1
    add eax, 305454592            ; 1193182 * 256 + rate / 2
    xor edx, edx
    div ecx                       ; EAX = step in 24.8 fixed point

    pop ecx                       ; ECX = samples count
    mov esi, cry_pcm_buffer
    call sb_pcm_play

.directReconcile:
    mov ecx, [g_cry_frames_rendered]
    add [tick_count], ecx
    cmp byte [ebp + hFrameCounter], cl
    jb .clearHFrame
    sub byte [ebp + hFrameCounter], cl
    jmp .directDone
.clearHFrame:
    mov byte [ebp + hFrameCounter], 0
.directDone:
    xor eax, eax
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al

    pop eax
    pop edi
    pop esi
    pop ebx
    ret

section .bss
align 4
pace_step:      resd 1            ; PIT clocks per pacing tick, 24.8 fp
pace_acc:       resd 1            ; accumulated elapsed clocks, 24.8 fp
pace_prev:      resw 1            ; last latched ch0 count

dma_dos_seg:    resw 1            ; real-mode segment of allocated DOS block
dma_dos_sel:    resw 1            ; PM selector of allocated DOS block
dma_flat:       resd 1            ; flat pointer to 64KB-safe DMA buffer
dma_phys_off:   resw 1            ; physical offset (bits 0..15)
dma_phys_page:  resb 1            ; physical page (bits 16..23)

orig_irq_off:   resd 1            ; original protected-mode ISR offset
orig_irq_sel:   resw 1            ; original protected-mode ISR selector

%else

section .data
g_sb_nodma:      db 0
g_sb_dma_active: db 0

section .text
sb_pcm_play:
pcm_pace_init:
pcm_pace:
sb_cry_play:
sb_dma_init:
sb_dma_shutdown:
sb_dma_play:
    xor eax, eax
    ret

sb_sfx_dma_play:
    stc
    ret

sb_dma_poll_completion:
    ret

%endif
