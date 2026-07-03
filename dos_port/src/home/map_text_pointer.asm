; map_text_pointer.asm — SetMapTextPointer / RestoreMapTextPointer.
;
; Source: pret home/predef_text.asm (the two map-text-pointer helpers at the top
; of that file). Extracted into their own linkable home module (menus S7): the
; SAVE-flow's ChangeBox (engine/menus/save.asm) needs them live, but their pret
; host predef_text.asm cannot link yet — it also carries the predef-text dispatch
; (PrintPredefTextID → DisplayTextID / TextPredefs), which is deep script-engine
; work (docs/current_plan_script_engine.md). These two routines are self-contained
; (only wCurMapTextPtr + hSavedMapTextPtr), so they live here as the single
; definition; predef_text.asm externs them.
;
; Register map: A→AL, HL→ESI; GB mem = [ebp+SYM]. hSavedMapTextPtr is a 2-byte
; HRAM save slot; wCurMapTextPtr is the 2-byte (LE) current map text pointer.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "m1_3_pending_symbols.inc"      ; wCurMapTextPtr, hSavedMapTextPtr

global SetMapTextPointer
global RestoreMapTextPointer

section .text

; ─────────────────────────────────────────────────────────────────────────────
; RestoreMapTextPointer — pret home/predef_text.asm:RestoreMapTextPointer.
; Restore wCurMapTextPtr from the saved copy in hSavedMapTextPtr.
; ─────────────────────────────────────────────────────────────────────────────
RestoreMapTextPointer:
    mov al, [ebp + hSavedMapTextPtr]
    mov [ebp + wCurMapTextPtr], al
    mov al, [ebp + hSavedMapTextPtr + 1]
    mov [ebp + wCurMapTextPtr + 1], al
    ret

; ─────────────────────────────────────────────────────────────────────────────
; SetMapTextPointer — pret home/predef_text.asm:SetMapTextPointer.
; Save the current wCurMapTextPtr into hSavedMapTextPtr, then point it at HL (ESI).
; ─────────────────────────────────────────────────────────────────────────────
SetMapTextPointer:
    mov al, [ebp + wCurMapTextPtr]
    mov [ebp + hSavedMapTextPtr], al
    mov al, [ebp + wCurMapTextPtr + 1]
    mov [ebp + hSavedMapTextPtr + 1], al
    ; HL (ESI) holds a GB 16-bit address; store it little-endian.
    mov eax, esi
    mov [ebp + wCurMapTextPtr], al       ; low byte  (l)
    mov [ebp + wCurMapTextPtr + 1], ah   ; high byte (h)
    ret
