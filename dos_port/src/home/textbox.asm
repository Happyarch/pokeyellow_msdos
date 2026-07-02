; ===========================================================================
; textbox.asm — DisplayTextBoxID home wrapper.
; Faithful port of pret home/textbox.asm (menus-port Session 2):
;
;   DisplayTextBoxID::
;       homecall_sf DisplayTextBoxID_
;       ret
;
; The homecall_sf bank/stack-frame shuffle collapses to a plain call under the
; port's flat memory model; DisplayTextBoxID_ (src/engine/menus/text_box.asm)
; is the box-drawing worker. Register/flag pass-through is total, so the
; function-table handlers' return contracts (DoBuySellQuitMenu's CF etc.)
; reach the caller intact.
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
    ; TODO-HW: homecall_sf saves/switches the ROM bank around the far call;
    ; flat memory ⇒ plain near call.
    call DisplayTextBoxID_
    ret
