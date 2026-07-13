; ===========================================================================
; textbox.asm — DisplayTextBoxID home wrapper.
; Faithful port of pret home/textbox.asm (menus-port Session 2):
;
;   DisplayTextBoxID::
;       homecall_sf DisplayTextBoxID_
;       ret
;
; The homecall_sf bank shuffle collapses to a plain call under the port's flat
; memory model; DisplayTextBoxID_ (src/engine/menus/text_box.asm) is the
; box-drawing worker.
;
; What homecall_sf actually does (macros/farcall.asm:52), since the "_sf" is
; load-bearing and easy to misread:
;
;       ldh a, [hLoadedROMBank] / push af       ; save the caller's bank
;       ld a, BANK(\1) / call BankswitchCommon
;       call \1
;       pop bc / ld a, b / call BankswitchCommon ; restore it
;
; It pops into BC rather than AF precisely so the *callee's* flags survive the
; bank restore (BankswitchCommon is two stores + ret — flag-neutral). So the
; function-table handlers' return contracts (DoBuySellQuitMenu's CF etc.) reach
; the caller intact on both sides — that part the port matches exactly.
;
; But the shuffle also DESTROYS A and BC on the way out (A = the caller's old
; bank, B = same, C = the caller's entry flags). The port's plain call preserves
; AL and BX instead. That is a deliberate, strictly-more-permissive divergence,
; not fidelity: no caller can depend on a register being clobbered, and there is
; no bank byte to restore here. See the TODO-HW tag below.
;
; This definition supersedes the interim copy that lived in
; src/home/text_script.asm (now an extern there) — ONE definition, canonical
; pret file placement.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/home/textbox.asm
; ===========================================================================

bits 32

global DisplayTextBoxID

extern DisplayTextBoxID_                ; engine/menus/text_box.asm

section .text

; ---------------------------------------------------------------------------
; DisplayTextBoxID — draw the text box selected by [wTextBoxID] (b,c = the
; two-option text coords in pret; the port's two-option path takes its box
; parameters from yes_no.asm state — see DisplayTextBoxID_).
; pret ref: home/textbox.asm:DisplayTextBoxID
; ---------------------------------------------------------------------------
DisplayTextBoxID:
    ; TODO-HW(banking): homecall_sf saves/switches/restores the ROM bank around
    ; the far call; flat memory ⇒ plain near call. Consequence: pret exits with
    ; A and BC clobbered by the bank-restore shuffle, the port with AL and BX
    ; intact. Flags — the contract callers actually read — pass through on both.
    call DisplayTextBoxID_
    ret
