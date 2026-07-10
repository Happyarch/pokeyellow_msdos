; play_time.asm — TrackPlayTime + CountDownIgnoreInputBitReset
;
; Intended repo path: dos_port/src/util/play_time.asm
;
; Faithful port of pret home/play_time.asm. Both routines are per-frame VBlank
; responsibilities in the original (VBlank:: calls TrackPlayTime, which in turn
; calls CountDownIgnoreInputBitReset). In the DOS port they are driven once per
; frame from DelayFrame (src/video/frame.asm), matching the GB VBlank cadence.
;
;   TrackPlayTime — advance the in-game play clock frames→sec→min→hours, gated on
;   BIT_GAME_TIMER_COUNTING of wStatusFlags6, with the $ff:59:59 max-out cap and
;   the wd479 bit-0 "force maxed" debug path.
;
;   CountDownIgnoreInputBitReset — decrement wIgnoreInputCounter each frame; when
;   it hits 0 (wrapping to $ff), clear the input-suppression bits of wStatusFlags5
;   and, if BIT_DISABLE_JOYPAD had been set, wipe hJoyPressed/hJoyHeld.
;
; Build check:
;   nasm -f coff -I dos_port/include -I dos_port -o /dev/null dos_port/src/util/play_time.asm
;
; Register contract: both routines preserve all registers except flags. They are
; called by DelayFrame inside its pushad/popad envelope, and are also safe to
; call directly (e.g. from the overworld loop) as globals.

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; Symbols not yet in gb_memmap.inc / gb_constants.inc. Defined here %ifndef-safe
; with sym-verified addresses (see SUMMARY.md) so this file assembles standalone;
; root should promote these to the canonical memmap/constants and they will win.
; ---------------------------------------------------------------------------
%ifndef BIT_GAME_TIMER_COUNTING
BIT_GAME_TIMER_COUNTING      equ 0          ; wStatusFlags6 bit 0 (constants/ram_constants.asm)
%endif
%ifndef BIT_UNKNOWN_5_1
BIT_UNKNOWN_5_1              equ 1          ; wStatusFlags5 bit 1
%endif
%ifndef BIT_UNKNOWN_5_2
BIT_UNKNOWN_5_2              equ 2          ; wStatusFlags5 bit 2
%endif
%ifndef W_D479
W_D479                       equ 0xD479     ; wd479 (bit 0 = force-max in-game timer)
%endif
%ifndef W_PLAY_TIME_HOURS
W_PLAY_TIME_HOURS            equ 0xDA40     ; wPlayTimeHours
%endif
%ifndef W_PLAY_TIME_MAXED
W_PLAY_TIME_MAXED            equ 0xDA41     ; wPlayTimeMaxed
%endif
%ifndef W_PLAY_TIME_MINUTES
W_PLAY_TIME_MINUTES          equ 0xDA42     ; wPlayTimeMinutes
%endif
%ifndef W_PLAY_TIME_SECONDS
W_PLAY_TIME_SECONDS          equ 0xDA43     ; wPlayTimeSeconds
%endif
%ifndef W_PLAY_TIME_FRAMES
W_PLAY_TIME_FRAMES           equ 0xDA44     ; wPlayTimeFrames
%endif

global TrackPlayTime
global CountDownIgnoreInputBitReset

section .text

; ---------------------------------------------------------------------------
; TrackPlayTime — pret home/play_time.asm:TrackPlayTime
;
; Called once per frame. Increments the play-time counters with 60-frame /
; 60-second / 60-minute rollovers and a hard cap of 255h 59m 59s.
;
; In:  EBP = GB memory base. Out: all registers preserved (flags clobbered).
; ---------------------------------------------------------------------------
TrackPlayTime:
    push eax
    call CountDownIgnoreInputBitReset       ; pret: first thing TrackPlayTime does

    test byte [ebp + W_D479], 1 << 0        ; bit 0 → force in-game timer to max
    jnz .maxIGT

    mov al, [ebp + W_STATUS_FLAGS_6]
    test al, 1 << BIT_GAME_TIMER_COUNTING
    jz .done                                ; timer not running

    cmp byte [ebp + W_PLAY_TIME_MAXED], 0
    jne .done                               ; already maxed out

    ; frames
    mov al, [ebp + W_PLAY_TIME_FRAMES]
    inc al
    mov [ebp + W_PLAY_TIME_FRAMES], al
    cmp al, 60
    jne .done
    mov byte [ebp + W_PLAY_TIME_FRAMES], 0

    ; seconds
    mov al, [ebp + W_PLAY_TIME_SECONDS]
    inc al
    mov [ebp + W_PLAY_TIME_SECONDS], al
    cmp al, 60
    jne .done
    mov byte [ebp + W_PLAY_TIME_SECONDS], 0

    ; minutes
    mov al, [ebp + W_PLAY_TIME_MINUTES]
    inc al
    mov [ebp + W_PLAY_TIME_MINUTES], al
    cmp al, 60
    jne .done
    mov byte [ebp + W_PLAY_TIME_MINUTES], 0

    ; hours
    mov al, [ebp + W_PLAY_TIME_HOURS]
    inc al
    mov [ebp + W_PLAY_TIME_HOURS], al
    cmp al, 0xFF
    jne .done                               ; not yet at the hour cap

    or byte [ebp + W_D479], 1 << 0          ; latch the force-max flag (pret: set 0,[wd479])
    ; fall through to .maxIGT

.maxIGT:
    mov byte [ebp + W_PLAY_TIME_SECONDS], 59
    mov byte [ebp + W_PLAY_TIME_MINUTES], 59
    mov byte [ebp + W_PLAY_TIME_HOURS], 0xFF
    mov byte [ebp + W_PLAY_TIME_MAXED], 0xFF
.done:
    pop eax
    ret

; ---------------------------------------------------------------------------
; CountDownIgnoreInputBitReset — pret home/play_time.asm:CountDownIgnoreInputBitReset
;
; Decrement wIgnoreInputCounter; when it reaches 0 (loading $ff on the frame it
; underflows) clear BIT_UNKNOWN_5_1 / BIT_UNKNOWN_5_2 / BIT_DISABLE_JOYPAD of
; wStatusFlags5. If BIT_DISABLE_JOYPAD had been set, also wipe hJoyPressed and
; hJoyHeld so no stale input leaks through when control is handed back.
;
; NOTE (task wording vs pret): the M2.1 brief said "re-arm wJoyIgnore to $ff and
; clear hJoyPressed". Pret actually re-arms wIgnoreInputCounter (not wJoyIgnore)
; and clears BOTH hJoyPressed and hJoyHeld. This follows pret exactly.
;
; In:  EBP = GB memory base. Out: all registers preserved (flags clobbered).
; ---------------------------------------------------------------------------
CountDownIgnoreInputBitReset:
    push eax
    mov al, [ebp + W_IGNORE_INPUT_COUNTER]
    test al, al
    jnz .decrement
    mov al, 0xFF                            ; was 0 → re-arm to $ff
    jmp .continue
.decrement:
    dec al
.continue:
    mov [ebp + W_IGNORE_INPUT_COUNTER], al
    test al, al
    jnz .done                              ; still counting down

    ; counter hit 0: clear the input-suppression bits
    mov al, [ebp + W_STATUS_FLAGS_5]
    and al, ~((1 << BIT_UNKNOWN_5_1) | (1 << BIT_UNKNOWN_5_2))
    mov ah, al                             ; ah = value with DISABLE_JOYPAD bit still intact
    and al, ~(1 << BIT_DISABLE_JOYPAD)     ; clear it in the stored value
    mov [ebp + W_STATUS_FLAGS_5], al
    test ah, 1 << BIT_DISABLE_JOYPAD       ; pret: `bit` tested it BEFORE the res
    jz .done                               ; bit was not set → nothing to wipe

    mov byte [ebp + H_JOY_PRESSED], 0
    mov byte [ebp + H_JOY_HELD], 0
.done:
    pop eax
    ret
