; joypad2.asm — mirror of pret home/joypad2.asm.
;
; Holds ALL THREE of that pret file's labels, in pret's order:
;   JoypadLowSensitivity          — was src/home/joypad_lowsens.asm, a file whose
;                                   only content this was, so it was deleted.
;   WaitForTextScrollButtonPress  — was src/engine/battle/battle_menu.asm, which
;                                   keeps its own battle draw-layer labels.
;   ManualTextScroll              — arrived 2026-08-22. It was a FORKED PRET NAME:
;                                   the port called it `dialog_window_scroll` in
;                                   src/home/text.asm, which broke the
;                                   Preserve-pret-Labels rule and left this label
;                                   reading `missing`. Surfaced by the text-engine
;                                   realignment (docs/current_plan_text_engine_-
;                                   realign.md, Stage 3 finding 1).
;
; The fork was NOT a rename: the port's routine was a COMPOSITE of two things
; pret keeps apart — pret's ManualTextScroll (wait for A/B, then the press SFX)
; and a port-only overworld-dialog window hijack with no pret counterpart. Only
; the first half is a pret label, so only the first half moved here; the window
; hijack stays in the text engine as `dialog_window_scroll`, a descriptive
; port-only name, and calls this.
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
%include "assets/audio_constants.inc"    ; SFX_PRESS_AB (generated)
%include "gb_constants.inc"              ; LINK_STATE_BATTLING

; ---------------------------------------------------------------------------
; HRAM low-sensitivity joypad slots (pret hram.asm order, anchored at hSCX):
;   hJoyLast FFB1, hJoyReleased FFB2, hJoyPressed FFB3, hJoyHeld FFB4,
;   hJoy5 FFB5, hJoy6 FFB6, hJoy7 FFB7.
; hJoyPressed/hJoyHeld already live in gb_memmap.inc; hJoy5/6/7 do not yet.
; %ifndef-guarded so this file self-assembles AND coexists once root promotes
; them into gb_memmap.inc (see SUMMARY.md "missing memmap symbols").
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global JoypadLowSensitivity
global WaitForAPress
global WaitForTextScrollButtonPress
global ManualTextScroll
global wtsbp_arrow_pos                ; port-only: the blink cell projection knob

extern HandleDownArrowBlinkTiming     ; src/home/window.asm — faithful ▼ blink (COUNT1==0 guard)
extern DelayFrame                     ; src/home/vblank.asm
extern DelayFrames                    ; src/home/delay.asm — BL = frame count
extern WaitForSoundToFinish           ; src/home/delay.asm
extern PlaySound                      ; src/home/audio.asm — AL = sound id
extern CableClub_Run                  ; src/engine/link/cable_club.asm — pret predef (Stage 3)

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
    ; caller's DelayFrames. hJoyHeld is refreshed every frame by joypad_update and
    ; is authoritative for the current held state.
    push ebx
    mov al, [ebp + hJoyHeld]      ; current held buttons (fresh each DelayFrame)
    mov bl, [jls_prev]              ; JLS's own previous snapshot
    mov [jls_prev], al              ; snapshot updated only here (pret: hJoyLast)
    xor bl, al
    and bl, al                      ; pressed = (prev ^ held) & held
    mov [ebp + hJoyPressed], bl   ; edge that survives the caller's DelayFrames
    pop ebx

    mov al, [ebp + hJoy7]          ; ldh a, [hJoy7]   ; flag
    and al, al                      ; and a  — newly-pressed only, or held?
    mov al, [ebp + hJoyPressed]   ; ldh a, [hJoyPressed]  (mov keeps flags)
    jz  .storeButtonState           ; jr z (ZF set by hJoy7 test above)
    mov al, [ebp + hJoyHeld]      ; ldh a, [hJoyHeld]     ; all held buttons
.storeButtonState:
    mov [ebp + hJoy5], al          ; ldh [hJoy5], a
    mov al, [ebp + hJoyPressed]   ; ldh a, [hJoyPressed]
    and al, al                      ; and a  — any buttons newly pressed?
    jz  .noNewlyPressedButtons      ; jr z

    ; newly pressed buttons: arm the ~1/2 second initial delay
    mov byte [ebp + hFrameCounter], 30    ; ld a, 30 / ldh [hFrameCounter], a
    ret

.noNewlyPressedButtons:
    mov al, [ebp + hFrameCounter] ; ldh a, [hFrameCounter]
    and al, al                      ; and a  — is the delay over?
    jz  .delayOver                  ; jr z

    ; delay not over: report no buttons as pressed
    xor al, al
    mov [ebp + hJoy5], al          ; ldh [hJoy5], a
    ret

.delayOver:
    ; if [hJoy6] == 0 and A or B is held, report no buttons as pressed
    mov al, [ebp + hJoyHeld]      ; ldh a, [hJoyHeld]
    and al, PAD_A | PAD_B           ; and PAD_A | PAD_B
    jz  .setShortDelay              ; jr z (neither A nor B held)
    mov al, [ebp + hJoy6]          ; ldh a, [hJoy6]   ; flag
    and al, al                      ; and a
    jnz .setShortDelay              ; jr nz (hJoy6 != 0 → keep buttons)
    xor al, al
    mov [ebp + hJoy5], al          ; ldh [hJoy5], a   ; A/B held → suppress
.setShortDelay:
    ; arm the ~1/12 second auto-repeat cadence
    mov byte [ebp + hFrameCounter], 5     ; ld a, 5 / ldh [hFrameCounter], a
    ret

; ---------------------------------------------------------------------------
; WaitForAPress / WaitForTextScrollButtonPress — wait for A/B, faithfully mirroring
; pret home/joypad2.asm:WaitForTextScrollButtonPress. pret does NOT draw an arrow; it
; only *blinks a pre-existing* ▼ via HandleDownArrowBlinkTiming, gated by initializing
; hDownArrowBlinkCount1 = 0 (the canonical HandleDownArrowBlinkTiming leaves the tile
; alone when it isn't already ▼ and COUNT1 == 0). None of this routine's callers (status
; screen, league PC, EXP, town map) place a ▼, so none show one — matching the real game.
; The text-box advance ▼ is a *separate* mechanism (text.asm dialog_window_scroll).
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
; "wait for A" rather than as text scrolling. The ALIAS is declared first so the
; body attributes to the pret label (the scanners assign a body to the label
; immediately preceding it; the old order read WaitForTextScrollButtonPress as
; empty and reported its whole call set DROPPED).
WaitForAPress:
WaitForTextScrollButtonPress:
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    mov [wtsbp_saved_c1], al
    mov al, [ebp + H_DOWN_ARROW_COUNT2]
    mov [wtsbp_saved_c2], al
    mov byte [ebp + H_DOWN_ARROW_COUNT1], 0
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 1
    mov esi, [wtsbp_arrow_pos]                  ; pret: hlcoord 18,16 (projected)
    cmp byte [ebp + esi], CHAR_DOWN_ARROW
    jne .wait
    mov byte [ebp + H_DOWN_ARROW_COUNT1], ARROW_ON_FRAMES
.wait:
    mov esi, [wtsbp_arrow_pos]                  ; pret: hlcoord 18,16 (projected)
    call HandleDownArrowBlinkTiming              ; blinks only a pre-existing ▼ (COUNT1==0 guard)
    call DelayFrame
    ; pret: predef CableClub_Run — THE entry hook into the whole cable-club
    ; engine: CableClubLeftGameboy/RightGameboy set wLinkState = START_TRADE/
    ; START_BATTLE during JustAMomentText, and this poll (running while that
    ; text waits for A/B) is what dispatches into CableClub_DoBattleOrTrade.
    ; Single-player cost: one wLinkState compare per scroll-wait frame.
    ; DEVIATION{class=banking; pret=home/joypad2.asm:WaitForTextScrollButtonPress; behavior=call the linked CableClub_Run directly instead of through the predef dispatch table; evidence=pret predef CableClub_Run at data/predef_pointers.asm:58 and the flat single-address-space port which has no predef jump table for code predefs; lifetime=permanent flat-code boundary}
    call CableClub_Run
    test byte [ebp + hJoyPressed], PAD_A | PAD_B
    jz .wait
    mov al, [wtsbp_saved_c1]                      ; pret: pop af / ldh [hDownArrowBlinkCount1]
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov al, [wtsbp_saved_c2]
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    ret

; ---------------------------------------------------------------------------
; ManualTextScroll — pret home/joypad2.asm:ManualTextScroll.
; "(unless in link battle) waits for A or B being pressed and outputs the
; scrolling sound effect."
;
; THIS LABEL WAS FORKED until 2026-08-22. The port called the routine
; `dialog_window_scroll` and kept it in src/home/text.asm bundled together with
; the overworld dialog-window hijack. That bundling is why the fork happened:
; the composite genuinely had no single pret counterpart. Split apart, this half
; is pret's routine verbatim and the other half is `dialog_window_scroll`, a
; port-only presentation helper that calls this one.
;
; pret clobbers C in the link-battle branch (`ld c, 65`) and does not save it,
; so neither does the port with BL — that is pret's own contract, not an
; oversight to fix.
; ---------------------------------------------------------------------------
ManualTextScroll:
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING  ; ld a,[wLinkState] / cp
    je  .inLinkBattle                                 ; jr z, .inLinkBattle
    call WaitForTextScrollButtonPress
    call WaitForSoundToFinish
    mov al, SFX_PRESS_AB                              ; ld a, SFX_PRESS_AB
    jmp PlaySound                                     ; jp PlaySound (tail call)
.inLinkBattle:
    mov bl, 65                                        ; ld c, 65
    jmp DelayFrames                                   ; jp DelayFrames (tail call)

; ---------------------------------------------------------------------------
; JoypadLowSensitivity-private newly-pressed snapshot (pret: hJoyLast, but read
; only by this routine so the caller's per-frame joypad_update can't consume the
; edge between reads). Zeroed by the loader's BSS clear.
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; wtsbp_arrow_pos — the cell WaitForTextScrollButtonPress blinks. PORT-ONLY, no
; pret counterpart: pret writes `hlcoord 18, 16` inline because it has ONE
; 20x18 screen, whereas the port must blink either the battle/status canvas cell
; or — when the overworld dialog window is up — the arrow in the window copy at
; GB_TILEMAP1, which lives in a different tilemap entirely. Defaults to the
; battle/status projection so every existing caller is unchanged;
; dialog_window_scroll (src/home/text.asm) points it at the window copy for the
; duration of its wait and restores it afterwards. This knob is covered by the
; class=projection deviation annotated on WaitForTextScrollButtonPress above --
; spelled out in prose here on purpose, because writing the annotation's own
; syntax inside a comment makes lint_pret_labels parse it as a second, malformed
; annotation.
; ---------------------------------------------------------------------------
section .data
align 4
wtsbp_arrow_pos: dd (wTileMap + ARROW_OFF)

section .bss
align 1
jls_prev:   resb 1
; WaitForTextScrollButtonPress: saved down-arrow blink counters (pret push af x2)
wtsbp_saved_c1: resb 1
wtsbp_saved_c2: resb 1
