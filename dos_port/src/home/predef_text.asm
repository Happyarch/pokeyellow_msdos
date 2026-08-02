; predef_text.asm — PrintPredefTextID / SetMapTextPointer / RestoreMapTextPointer.
;
; Faithful translation of pret `home/predef_text.asm` (Pokémon Yellow). Prints a
; text stream from the shared `TextPredefs` table (a predef-style text dispatch):
; temporarily repoints wCurMapTextPtr at TextPredefs, sets the TEXT_PREDEF flag
; (so DisplayTextID skips the map-bank switch), and runs DisplayTextID.
;
; DEVIATION{class=projection; pret=home/predef_text.asm:PrintPredefTextID; behavior=the predef text table is reached through a port-only FLAT published pointer w_predef_text_table_ptr instead of the 16-bit wCurMapTextPtr the GB dereferences, and DisplayTextID reads flat rows rather than walking GB address space; evidence=the port's TextPredefs rows and text streams are flat program-image data in section .data while wCurMapTextPtr is a 2-byte GB variable, so pret's truncate-to-16-bits-and-dereference walk reads unrelated bytes inside the GB allocation; lifetime=permanent flat-memory projection, retired only if the port ever hosts text streams inside GB address space}
;
; That is the maintainer's Option A (2026-08-02), and it is the same shape the
; ordinary map-text path already uses: pret's 16-bit wCurMapTextPtr stays, byte
; faithful, alongside a port-only flat table pointer (w_map_text_table_ptr there,
; w_predef_text_table_ptr here). SetMapTextPointer / RestoreMapTextPointer are
; UNTOUCHED and still save/restore wCurMapTextPtr exactly as pret does, which is
; what keeps the SAVE flow's ChangeBox working. The value they store on this path
; is the low 16 bits of a flat address and is deliberately never dereferenced;
; publishing the flat pointer beside it is what makes the lookup correct.
; Option B (copying the streams into GB space) is REJECTED AND CLOSED.
;
; Register map: A=AL, HL=ESI, EBP=GB base; GB memory as [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o predef_text.o predef_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
; Every symbol this file needs (hTextID, wTextPredefFlag, BIT_TEXT_PREDEF) is
; canonical in gb_memmap.inc / gb_constants.inc, included above. The
; m1_3_pending_symbols.inc scaffold it used to include was dissolved 2026-07-27.

section .data
align 4
; w_predef_text_table_ptr — PORT-ONLY. The flat address of TextPredefs, published by
; PrintPredefTextID and consumed by DisplayTextID's TEXT_PREDEF branch. Mirrors
; w_map_text_table_ptr (map_sprites.asm), which does the same job for the ordinary
; per-map text table. Not a pret variable; see the projection annotation at the top
; of this file.
global w_predef_text_table_ptr
w_predef_text_table_ptr: dd 0

section .text

global PrintPredefTextID
; SetMapTextPointer / RestoreMapTextPointer came BACK here 2026-08-02, from
; src/home/map_text_pointer.asm (which is deleted). They were extracted in menus S7
; only because the SAVE flow's ChangeBox needed them live while predef_text.asm
; could not link; that reason is gone. The move is not cosmetic — pret's
; PrintPredefTextID has no `ret`, it FALLS THROUGH into RestoreMapTextPointer, so
; with those two in another object this file's .text ended in a routine that ran off
; its own end. Harmless while the file was check-only, a live cross-file
; fall-through the moment it linked; update_label_db's boundary scan refuses to
; model that and said so.
global SetMapTextPointer
global RestoreMapTextPointer

extern DisplayTextID                    ; home/text_script.asm (this member)

; TextPredefs — the 68-row predef text table, pret data/text_predef_pointers.asm.
; It is hand-written (17 of its rows name PORT routines, so no generator can derive
; it) but lives in the DATA layer at src/data/predef_text_data.asm, exactly as
; MoveEffectPointerTable does — see that file's header for why both are true at once.
extern TextPredefs

; ─────────────────────────────────────────────────────────────────────────────
; PrintPredefTextID — pret home/predef_text.asm:1
; In: A = text-predef ID. Repoints the map text pointer at TextPredefs, flags
;     TEXT_PREDEF, and dispatches through DisplayTextID.
; ─────────────────────────────────────────────────────────────────────────────
PrintPredefTextID:
    ; ldh [hTextID], a
    mov [ebp + hTextID], al
    ; ld hl, TextPredefs ; call SetMapTextPointer
    mov esi, TextPredefs
    ; Port-only: publish the table as a FLAT pointer for DisplayTextID's predef
    ; branch. The SetMapTextPointer call below still runs unmodified — it saves the
    ; old wCurMapTextPtr and stores this address truncated to 16 bits, which is what
    ; RestoreMapTextPointer puts back and what ChangeBox's save/restore depends on.
    ; Nothing dereferences that truncated value any more — that is exactly the
    ; projection the annotation at the top of this file records.
    mov [w_predef_text_table_ptr], esi
    call SetMapTextPointer
    ; ld hl, wTextPredefFlag ; set BIT_TEXT_PREDEF,[hl]
    or byte [ebp + wTextPredefFlag], (1 << BIT_TEXT_PREDEF)
    ; call DisplayTextID
    call DisplayTextID
    ; falls through to RestoreMapTextPointer, exactly as pret does — there is no
    ; `ret` here in pret either.

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

; ── pret: INCLUDE "data/text_predef_pointers.asm" (the TextPredefs table) ──
;   The port's TextPredefs lives in the DATA layer instead — see the extern above
;   and src/data/predef_text_data.asm for why that is both hand-written and correct.
