; predef_text.asm — PrintPredefTextID / SetMapTextPointer / RestoreMapTextPointer.
;
; Faithful translation of pret `home/predef_text.asm` (Pokémon Yellow). Prints a
; text stream from the shared `TextPredefs` table (a predef-style text dispatch):
; temporarily repoints wCurMapTextPtr at TextPredefs, sets the TEXT_PREDEF flag
; (so DisplayTextID skips the map-bank switch), and runs DisplayTextID.
;
; Intended repo path: dos_port/src/home/predef_text.asm. Assembled CHECK-ONLY
; (its TextPredefs data table + DisplayTextID's non-home deps resolve in later
; waves). See docs/current_plan_home_rectification.md (M1.3).
;
; Register map: A=AL, HL=ESI, EBP=GB base; GB memory as [EBP + addr].
;
; Build (check-only): nasm -f coff -I include/ -I . -o /dev/null predef_text.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
; TEMPORARY: symbols the root must migrate into the canonical includes, then drop
; this line (see m1_3_pending_symbols.inc header).
%include "m1_3_pending_symbols.inc"

section .text

global PrintPredefTextID
global SetMapTextPointer
global RestoreMapTextPointer

extern DisplayTextID                    ; home/text_script.asm (this member)

; TODO(home-rectify M1.3 follow-up): TextPredefs is the predef text-pointer table
;   (pret data/text_predef_pointers.asm). It is a small hand-authored `dw`/pointer
;   table (Tier-2 code-owned per the two-tier rule). Not ported here — externed as
;   a flat data label; port it as a `dd`/`dw` table when the predef-text callers land.
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
    call SetMapTextPointer
    ; ld hl, wTextPredefFlag ; set BIT_TEXT_PREDEF,[hl]
    or byte [ebp + wTextPredefFlag], (1 << BIT_TEXT_PREDEF)
    ; call DisplayTextID   (pret falls through into RestoreMapTextPointer afterward)
    call DisplayTextID
    ; fall through to RestoreMapTextPointer

; ─────────────────────────────────────────────────────────────────────────────
; RestoreMapTextPointer — pret home/predef_text.asm:9
; Restore wCurMapTextPtr from the saved copy in hSavedMapTextPtr.
; ─────────────────────────────────────────────────────────────────────────────
RestoreMapTextPointer:
    ; ld hl, wCurMapTextPtr
    ; ldh a,[hSavedMapTextPtr];   ld [hli],a
    ; ldh a,[hSavedMapTextPtr+1]; ld [hl],a
    mov al, [ebp + hSavedMapTextPtr]
    mov [ebp + wCurMapTextPtr], al
    mov al, [ebp + hSavedMapTextPtr + 1]
    mov [ebp + wCurMapTextPtr + 1], al
    ret

; ─────────────────────────────────────────────────────────────────────────────
; SetMapTextPointer — pret home/predef_text.asm:17
; Save the current wCurMapTextPtr into hSavedMapTextPtr, then point it at HL.
; ─────────────────────────────────────────────────────────────────────────────
SetMapTextPointer:
    ; ld a,[wCurMapTextPtr];   ldh [hSavedMapTextPtr],a
    ; ld a,[wCurMapTextPtr+1]; ldh [hSavedMapTextPtr+1],a
    mov al, [ebp + wCurMapTextPtr]
    mov [ebp + hSavedMapTextPtr], al
    mov al, [ebp + wCurMapTextPtr + 1]
    mov [ebp + hSavedMapTextPtr + 1], al
    ; ld a,l; ld [wCurMapTextPtr],a ; ld a,h; ld [wCurMapTextPtr+1],a
    ; HL (ESI) holds a GB 16-bit address; store it little-endian.
    mov eax, esi
    mov [ebp + wCurMapTextPtr], al       ; low byte  (l)
    mov [ebp + wCurMapTextPtr + 1], ah   ; high byte (h)
    ret

; ── pret: INCLUDE "data/text_predef_pointers.asm" (the TextPredefs table) ──
;   Not embedded here (Tier-2 data, externed above). See follow-up note.
