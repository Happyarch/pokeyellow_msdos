; auto_textbox.asm — EnableAutoTextBoxDrawing / DisableAutoTextBoxDrawing.
;
; Faithful translation of home/text.asm:EnableAutoTextBoxDrawing et al. Map
; _Scripts (and the wild-encounter repel message) call these to control whether
; DisplayTextID auto-draws the text box, and to reset the
; wDoNotWaitForButtonPressAfterDisplayingText flag so the next text waits for a
; button press. The flags are consumed by the text dispatcher (DisplayTextID),
; parts of which are still deferred — but the control routines are stable and
; shared, so they live here now.
;
; Register map: a=AL.
;
; Build: nasm -f coff -I include/ -I . -o auto_textbox.o auto_textbox.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global EnableAutoTextBoxDrawing
global DisableAutoTextBoxDrawing

EnableAutoTextBoxDrawing:
    xor al, al
    jmp AutoTextBoxDrawingCommon

DisableAutoTextBoxDrawing:
    mov al, 1 << BIT_NO_AUTO_TEXT_BOX
    ; fallthrough

AutoTextBoxDrawingCommon:
    mov [ebp + wAutoTextBoxDrawingControl], al
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al  ; wait for button press
    ret
