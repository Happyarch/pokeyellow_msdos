; ===========================================================================
; yes_no.asm — the YES/NO (two-option) entry points, at their pret mirror.
;
; Faithful port of pret home/yes_no.asm: YesNoChoice, TwoOptionMenu,
; InitYesNoTextBoxParameters, YesNoChoicePokeCenter, WideYesNoChoice,
; DisplayYesNoChoice. The two-option implementation itself —
; DisplayTwoOptionMenu — lives in ITS pret mirror,
; src/engine/menus/text_box.asm (R-001 retirement 2026-07-23), exactly as
; pret splits these two files.
;
; CARRY CONTRACT (preserved from pret DisplayTwoOptionMenu):
;   YesNoChoice / DisplayYesNoChoice / all two-option entry points return:
;     CF = 0 (and wCurrentMenuItem = 0)  -> the FIRST  option was chosen
;     CF = 1 (and wCurrentMenuItem = 1)  -> the SECOND option was chosen
;   For the default YES_NO_MENU the first option is "YES", so:
;     YES -> carry clear (AL/wCurrentMenuItem = 0)
;     NO  -> carry set   (AL/wCurrentMenuItem = 1)   (also when B is pressed)
;   wChosenMenuItem and wMenuExitMethod are also set as pret does
;   (CHOSE_FIRST_ITEM / CHOSE_SECOND_ITEM).
;
; BOX PLACEMENT CONTRACT: pret's entry points fix the box with `hlcoord X, Y`
; and `lb bc` before dispatching through DisplayTextBoxID. The port's
; window-projected DisplayTwoOptionMenu takes the top-left from the
; yn_box_col/row (+ yn_proj_mode anchor) state owned HERE — the port stand-in
; for pret's register triple. A caller that supplies its own coords (e.g.
; engine/menus/save.asm SaveTheGame_YesOrNo: hlcoord 0, 7) writes these
; directly; they stay global for that reason.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
; Build (standalone check):
;   nasm -f coff -I dos_port/include -I dos_port -o /dev/null yes_no.asm
; ===========================================================================

%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

extern DisplayTwoOptionMenu     ; engine/menus/text_box.asm — the ONE two-option
                                ; impl (pret mirror); reads yn_box_col/row/proj_mode

global YesNoChoice
global TwoOptionMenu
global DisplayYesNoChoice
global WideYesNoChoice
global YesNoChoicePokeCenter
global InitYesNoTextBoxParameters
global yn_box_col
global yn_box_row
global yn_proj_mode

; ===========================================================================
section .bss
; ---------------------------------------------------------------------------
; Box placement for the current invocation — the port's stand-in for pret's
; hlcoord/lb bc at the entry points. Written by the entry points below and by
; coord-supplying callers (save.asm); read by DisplayTwoOptionMenu
; (engine/menus/text_box.asm).
;
; DEVIATION{class=projection; pret=home/yes_no.asm:InitYesNoTextBoxParameters; behavior=the two-option box top-left and its anchor mode are carried in three port-owned globals that DisplayTwoOptionMenu reads, instead of pret's hlcoord X Y plus lb bc register triple handed to DisplayTextBoxID; evidence=the port publishes the box as a projected window on a 40x25 canvas rather than drawing it into the live 20x18 tilemap, so the coordinates must survive past the register-passing call boundary and be re-anchored per mode, and callers that supply their own coords, engine/menus/save.asm SaveTheGame_YesOrNo, write these directly which is why they are global; lifetime=permanent window-compositor boundary}
; ---------------------------------------------------------------------------
yn_box_col:     resd 1          ; box top-left GB column  (pret hlcoord X)
yn_box_row:     resd 1          ; box top-left GB row     (pret hlcoord Y)
yn_proj_mode:   resd 1          ; 0 = overworld (X+20/Y+0), 1 = battle (X+10/Y+3)

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; YesNoChoice — the standard YES/NO box. pret ref: home/yes_no.asm:YesNoChoice.
; In:  EBP = GB base. Out: CF=0 -> YES, CF=1 -> NO. (see carry contract above)
; ---------------------------------------------------------------------------
YesNoChoice:
    ; pret: call SaveScreenTilesToBuffer1 — in the port's window-descriptor
    ; model the box is a non-destructive overlay, so "restore" = drop our
    ; window descriptor on exit (done by DisplayTwoOptionMenu's teardown).
    ; No BG tile save needed.
    call InitYesNoTextBoxParameters
    jmp DisplayYesNoChoice

; ---------------------------------------------------------------------------
; TwoOptionMenu — pret ref: home/yes_no.asm:TwoOptionMenu (unreferenced).
; Sets wTextBoxID = TWO_OPTION_MENU then runs the same YES_NO box.
; ---------------------------------------------------------------------------
TwoOptionMenu:
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call InitYesNoTextBoxParameters
    jmp DisplayYesNoChoice          ; pret: jp DisplayTextBoxID -> TWO_OPTION path

; ---------------------------------------------------------------------------
; InitYesNoTextBoxParameters — pret ref: home/yes_no.asm.
;   xor a ; YES_NO_MENU        -> wTwoOptionMenuID = 0
;   hlcoord 14, 7              -> box top-left GB(14,7)
;   lb bc, 8, 15              -> cursor (Y=8, X=15); implied by box+geometry here
; ---------------------------------------------------------------------------
InitYesNoTextBoxParameters:
    mov byte [ebp + wTwoOptionMenuID], YES_NO_MENU
    mov dword [yn_box_col], 14
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0         ; overworld anchor (battle caller sets 1)
    ret

; ---------------------------------------------------------------------------
; YesNoChoicePokeCenter — pret ref: home/yes_no.asm:YesNoChoicePokeCenter.
;   HEAL_CANCEL_MENU, hlcoord 11,6, box 9x6 (blank line before first item).
; ---------------------------------------------------------------------------
YesNoChoicePokeCenter:
    mov byte [ebp + wTwoOptionMenuID], HEAL_CANCEL_MENU
    mov dword [yn_box_col], 11
    mov dword [yn_box_row], 6
    mov dword [yn_proj_mode], 0         ; overworld anchor
    jmp DisplayYesNoChoice

; ---------------------------------------------------------------------------
; WideYesNoChoice — pret ref: home/yes_no.asm:WideYesNoChoice (unreferenced).
;   WIDE_YES_NO_MENU, hlcoord 12,7, box 8x5.
; ---------------------------------------------------------------------------
WideYesNoChoice:
    mov byte [ebp + wTwoOptionMenuID], WIDE_YES_NO_MENU
    mov dword [yn_box_col], 12
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0         ; overworld anchor
    ; fall through

; ---------------------------------------------------------------------------
; DisplayYesNoChoice — pret ref: home/yes_no.asm:DisplayYesNoChoice, which sets
; wTextBoxID=TWO_OPTION_MENU and calls DisplayTextBoxID (dispatching to
; DisplayTwoOptionMenu). We inline the TWO_OPTION_MENU path directly.
; In: wTwoOptionMenuID + yn_box_col/row set. Out: carry = chosen option.
; ---------------------------------------------------------------------------
DisplayYesNoChoice:
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    jmp DisplayTwoOptionMenu
