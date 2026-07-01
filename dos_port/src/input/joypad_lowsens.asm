; joypad_lowsens.asm — JoypadLowSensitivity (low button sensitivity input).
;
; Intended path: dos_port/src/input/joypad_lowsens.asm
;
; Faithful translation of pret home/joypad2.asm:16-53 (JoypadLowSensitivity).
; This is the low-sensitivity ("debounced") joypad read used by menus, maps,
; the title screen and the town map. It exposes an auto-repeat model:
;
;   OUTPUT: [hJoy5] = pressed buttons in the usual (active-HIGH) format.
;   Two flag inputs, [hJoy6] and [hJoy7], select one of three modes:
;     1. Newly-pressed only ([hJoy7]==0, [hJoy6]==any):
;        just copies [hJoyPressed] → [hJoy5].
;     2. Currently-pressed at low sample rate with delay
;        ([hJoy7]==1, [hJoy6]!=0):
;        held >~1/2 s → report ~12x/second thereafter; held <1/2 s → one press.
;     3. Same as 2, but report nothing while A or B is held
;        ([hJoy7]==1, [hJoy6]==0).
;
;   Cadence (verbatim from pret):
;     - INITIAL delay after a newly-pressed frame: 30 frames (~1/2 second).
;     - AUTO-REPEAT cadence once the delay expires: 5 frames (~1/12 second).
;   The frame delay lives in hFrameCounter (H_FRAME_COUNTER 0xFFD5), which is
;   decremented once per V-blank by DelayFrame.
;
; Register map: A→AL; GB HRAM = [ebp + SYM].  ZF from `and al,al` mirrors SM83
; `and a`; `mov` does not disturb flags (so the `ldh a,[..]` between an `and`
; and its `jr z` is reproduced by `mov` between `and al,al` and `jz`).
;
; DEPENDENCIES (see SUMMARY.md):
;   * Inputs hJoyPressed / hJoyHeld are produced by the joypad frontend
;     (sibling M3.1, dos_port/src/input/joypad.asm → H_JOY_PRESSED / H_JOY_HELD).
;     Referenced here only via memmap symbols, so this file assembles now and is
;     CHECK-clean; it becomes runtime-correct once M3.1's writers land.
;   * hFrameCounter must be decremented per frame in DelayFrame (sibling M2.1).
;   * pret's JoypadLowSensitivity opens with `call Joypad` to refresh
;     hJoyPressed/hJoyHeld from hardware. In the DOS port that refresh is done
;     by joypad_update inside the DelayFrame pipeline, and every caller of
;     JoypadLowSensitivity issues a DelayFrame per loop iteration, so the read
;     state is already fresh — the explicit `call Joypad` is intentionally
;     omitted (matches the port's existing model). If M3.1 later exports a
;     cheap `Joypad` global, root may add `call Joypad` at the top for full
;     faithfulness.
;
; Build: nasm -f coff -I include/ -o joypad_lowsens.o joypad_lowsens.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; ---------------------------------------------------------------------------
; HRAM low-sensitivity joypad slots (pret hram.asm order, anchored at H_SCX):
;   hJoyLast FFB1, hJoyReleased FFB2, hJoyPressed FFB3, hJoyHeld FFB4,
;   hJoy5 FFB5, hJoy6 FFB6, hJoy7 FFB7.
; H_JOY_PRESSED/H_JOY_HELD already live in gb_memmap.inc; H_JOY5/6/7 do not yet.
; %ifndef-guarded so this file self-assembles AND coexists once root promotes
; them into gb_memmap.inc (see SUMMARY.md "missing memmap symbols").
; ---------------------------------------------------------------------------
%ifndef H_JOY5
H_JOY5  equ 0xFFB5      ; hJoy5 — OUTPUT: pressed buttons (usual format)
%endif
%ifndef H_JOY6
H_JOY6  equ 0xFFB6      ; hJoy6 — flag: 0 = suppress repeat while A/B held
%endif
%ifndef H_JOY7
H_JOY7  equ 0xFFB7      ; hJoy7 — flag: 0 = newly-pressed only, 1 = held+delay
%endif

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global JoypadLowSensitivity

section .text

; ---------------------------------------------------------------------------
; JoypadLowSensitivity — pret home/joypad2.asm:16
; In:  EBP = GB memory base. [hJoy6]/[hJoy7] select the mode.
; Out: [hJoy5] = pressed buttons; [hFrameCounter] armed with the next delay.
; Clobbers: AL, flags (mirrors pret, which only touches A/flags here).
; ---------------------------------------------------------------------------
JoypadLowSensitivity:
    ; call Joypad  — omitted; joypad state is refreshed by joypad_update in the
    ;                DelayFrame pipeline (see header dependency note).
    mov al, [ebp + H_JOY7]          ; ldh a, [hJoy7]   ; flag
    and al, al                      ; and a  — newly-pressed only, or held?
    mov al, [ebp + H_JOY_PRESSED]   ; ldh a, [hJoyPressed]  (mov keeps flags)
    jz  .storeButtonState           ; jr z (ZF set by hJoy7 test above)
    mov al, [ebp + H_JOY_HELD]      ; ldh a, [hJoyHeld]     ; all held buttons
.storeButtonState:
    mov [ebp + H_JOY5], al          ; ldh [hJoy5], a
    mov al, [ebp + H_JOY_PRESSED]   ; ldh a, [hJoyPressed]
    and al, al                      ; and a  — any buttons newly pressed?
    jz  .noNewlyPressedButtons      ; jr z

    ; newly pressed buttons: arm the ~1/2 second initial delay
    mov byte [ebp + H_FRAME_COUNTER], 30    ; ld a, 30 / ldh [hFrameCounter], a
    ret

.noNewlyPressedButtons:
    mov al, [ebp + H_FRAME_COUNTER] ; ldh a, [hFrameCounter]
    and al, al                      ; and a  — is the delay over?
    jz  .delayOver                  ; jr z

    ; delay not over: report no buttons as pressed
    xor al, al
    mov [ebp + H_JOY5], al          ; ldh [hJoy5], a
    ret

.delayOver:
    ; if [hJoy6] == 0 and A or B is held, report no buttons as pressed
    mov al, [ebp + H_JOY_HELD]      ; ldh a, [hJoyHeld]
    and al, PAD_A | PAD_B           ; and PAD_A | PAD_B
    jz  .setShortDelay              ; jr z (neither A nor B held)
    mov al, [ebp + H_JOY6]          ; ldh a, [hJoy6]   ; flag
    and al, al                      ; and a
    jnz .setShortDelay              ; jr nz (hJoy6 != 0 → keep buttons)
    xor al, al
    mov [ebp + H_JOY5], al          ; ldh [hJoy5], a   ; A/B held → suppress
.setShortDelay:
    ; arm the ~1/12 second auto-repeat cadence
    mov byte [ebp + H_FRAME_COUNTER], 5     ; ld a, 5 / ldh [hFrameCounter], a
    ret
