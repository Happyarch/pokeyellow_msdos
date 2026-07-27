; joypad2.asm — mirror of pret home/joypad2.asm.
;
; Holds two of that pret file's three labels, in pret's order:
;   JoypadLowSensitivity          — was src/home/joypad_lowsens.asm, a file whose
;                                   only content this was, so it was deleted.
;   WaitForTextScrollButtonPress  — was src/engine/battle/battle_menu.asm, which
;                                   keeps its own battle draw-layer labels.
;
; The third, ManualTextScroll, is `missing` in the port. The text engine's
; port-only manual_text_scroll / text_pause helpers (src/home/text.asm) cover
; part of what it does for the dialog ▼, but no routine carries the pret name.
;
; Register map: A=AL, HL=ESI; GB memory / HRAM is [ebp+SYM] from gb_memmap.inc.
;
; Build: nasm -f coff -I include/ -I . -o joypad2.o joypad2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; WaitForTextScrollButtonPress's blink coordinate is a UI-layout projection, so
; the generated battle layout comes in equates-only — the same include
; battle_menu.asm uses. See the DEVIATION on the routine itself.
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"
%define ARROW_OFF          UI_DIALOG_ARROW_OFS

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
global WaitForAPress
global WaitForTextScrollButtonPress

extern HandleDownArrowBlinkTiming     ; src/home/window.asm — faithful ▼ blink (COUNT1==0 guard)
extern DelayFrame                     ; src/home/vblank.asm


section .text

; ---------------------------------------------------------------------------
; JoypadLowSensitivity — pret home/joypad2.asm:16
; In:  EBP = GB memory base. [hJoy6]/[hJoy7] select the mode.
; Out: [hJoy5] = pressed buttons; [hFrameCounter] armed with the next delay.
; Clobbers: AL, flags (mirrors pret, which only touches A/flags here).
; ---------------------------------------------------------------------------
JoypadLowSensitivity:
    ; pret opens with `call Joypad`, which computes the newly-pressed EDGE at read
    ; time against hJoyLast. The port instead computes that edge inside
    ; joypad_update, which runs once per DelayFrame — but every JoypadLowSensitivity
    ; caller (options, town map, pokedex, title) does read-then-N×DelayFrame, so a
    ; press that lands on any but the last of those frames has its edge overwritten
    ; to 0 before the loop's next top-of-iteration read. Symptom: "holding won't
    ; even advance one", laggy / inconsistent taps. Fix (port equivalent of pret's
    ; `call Joypad`): recompute the edge HERE against a JoypadLowSensitivity-private
    ; snapshot updated ONLY on JoypadLowSensitivity calls — so it survives the
    ; caller's DelayFrames. H_JOY_HELD is refreshed every frame by joypad_update and
    ; is authoritative for the current held state.
    push ebx
    mov al, [ebp + H_JOY_HELD]      ; current held buttons (fresh each DelayFrame)
    mov bl, [jls_prev]              ; JLS's own previous snapshot
    mov [jls_prev], al              ; snapshot updated only here (pret: hJoyLast)
    xor bl, al
    and bl, al                      ; pressed = (prev ^ held) & held
    mov [ebp + H_JOY_PRESSED], bl   ; edge that survives the caller's DelayFrames
    pop ebx

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

; ---------------------------------------------------------------------------
; WaitForAPress / WaitForTextScrollButtonPress — wait for A/B, faithfully mirroring
; pret home/joypad2.asm:WaitForTextScrollButtonPress. pret does NOT draw an arrow; it
; only *blinks a pre-existing* ▼ via HandleDownArrowBlinkTiming, gated by initializing
; hDownArrowBlinkCount1 = 0 (the canonical HandleDownArrowBlinkTiming leaves the tile
; alone when it isn't already ▼ and COUNT1 == 0). None of this routine's callers (status
; screen, league PC, EXP, town map) place a ▼, so none show one — matching the real game.
; The text-box advance ▼ is a *separate* mechanism (text.asm manual_text_scroll).
;
; The prior port version force-drew ▼ at ARROW_OFF and blanked it to a SPACE on exit,
; which on the status screen (ARROW_OFF = scoord(18,16)) punched a hole in the types/ID/OT
; box's bottom border and showed a spurious blinking arrow — a bespoke divergence.
; Save/restore the blink counters like pret's push af / push af.
;
; DEVIATION{class=projection; pret=home/joypad2.asm:WaitForTextScrollButtonPress; behavior=the blink cell is UI_DIALOG_ARROW_OFS from the generated battle UI layout instead of pret's fixed hlcoord 18 16, and the port's saved-counter pair is a private .bss pair instead of the SM83 stack; evidence=the port's canvas is 40x25 not the GB's 20x18 so a literal coord(18,16) lands elsewhere, and every battle-screen coordinate comes from assets/ui_layout_battle.inc per the Tier-1 layout pipeline; lifetime=permanent, the widescreen canvas projection is by design}
;
; The port's WaitForAPress is a port-only alias on the same body, kept alongside
; the pret name (never in place of it) because most of its call sites read as
; "wait for A" rather than as text scrolling.
WaitForTextScrollButtonPress:
WaitForAPress:
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    mov [wtsbp_saved_c1], al
    mov al, [ebp + H_DOWN_ARROW_COUNT2]
    mov [wtsbp_saved_c2], al
    mov byte [ebp + H_DOWN_ARROW_COUNT1], 0      ; pret: xor a  / ldh [hDownArrowBlinkCount1]
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 6      ; pret: ld a,6 / ldh [hDownArrowBlinkCount2]
.wait:
    mov esi, W_TILEMAP + ARROW_OFF               ; pret: hlcoord 18,16
    call HandleDownArrowBlinkTiming              ; blinks only a pre-existing ▼ (COUNT1==0 guard)
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jz .wait
    mov al, [wtsbp_saved_c1]                      ; pret: pop af / ldh [hDownArrowBlinkCount1]
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov al, [wtsbp_saved_c2]
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    ret

; ---------------------------------------------------------------------------
; JoypadLowSensitivity-private newly-pressed snapshot (pret: hJoyLast, but read
; only by this routine so the caller's per-frame joypad_update can't consume the
; edge between reads). Zeroed by the loader's BSS clear.
; ---------------------------------------------------------------------------
section .bss
align 1
jls_prev:   resb 1
; WaitForTextScrollButtonPress: saved down-arrow blink counters (pret push af x2)
wtsbp_saved_c1: resb 1
wtsbp_saved_c2: resb 1
