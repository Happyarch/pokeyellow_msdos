; ===========================================================================
; item_predicates.asm — HM / key-item / bag predicates.
;
; Intended path: dos_port/src/home/item_predicates.asm
;
; Faithful translation of the pret HM/key-item helpers, gathered here because
; they share the HM-id range test and the KeyItemFlags bit array:
;
;   IsItemHM     — pret home/names.asm:IsItemHM        (item id → CF = is HM)
;   IsMoveHM     — pret home/names.asm:IsMoveHM        (move id → CF = is HM)
;   HMMoves      — pret data/moves/hm_moves.asm        (Tier-2 db list; see below)
;   (IsItemInBag — pret home/map_objects.asm:IsItemInBag — MOVED to its mirror,
;                  src/home/map_objects.asm)
;   IsKeyItem    — pret home/item.asm:IsKeyItem        (thin save-regs wrapper)
;   IsKeyItem_   — pret engine/items/item_effects.asm:IsKeyItem_ — MOVED to that
;                  mirror, src/engine/items/item_effects.asm. IsKeyItem still calls it.
;                                                      ([wCurItem] → [wIsKeyItem])
;
; TWO-TIER NOTE (per CLAUDE.md): HMMoves is *code*, not generated data — a
; small hand-authored `db` list of HM move ids. pret INCLUDEs
; data/moves/hm_moves.asm here (and again for HMMoveArray in bills_pc.asm); we
; inline the five ids directly as a Tier-2 table. It is NOT emitted by any
; tools/generators/gen_*.py and `make assets` must never touch it.
;
; Register map: A=AL, HL=ESI, BC=EBX (B=BH,C=BL), DE=EDX. GB memory = [ebp+SYM].
;
; Build: nasm -f coff -I dos_port/include -I dos_port -o /dev/null \
;            dos_port/src/home/item_predicates.asm
; ===========================================================================

bits 32

%include "gb_constants.inc"     ; HM01, TM01, FLAG_TEST, CUT/FLY/SURF/STRENGTH/FLASH
%include "gb_memmap.inc"        ; wCurItem, wIsKeyItem, wBuffer, wPredefBC

global IsItemHM
global IsMoveHM
global HMMoves
global IsKeyItem

extern IsInArray                ; src/home/array2.asm — flat $FF-terminated search
extern IsKeyItem_               ; src/engine/items/item_effects.asm — its pret mirror

section .text

; ---------------------------------------------------------------------------
; IsItemHM — pret home/names.asm:IsItemHM.
; Sets CF if the item id is an HM (HM01..TM01-1, i.e. $C4..$C8), else clears CF.
; Faithful: pret `cp HM01 / jr c,.notHM / cp TM01 / ret` — after the second
; compare CF = (A < TM01), and since A >= HM01 here that is exactly "is HM".
; In:  AL = item id.   Out: CF = 1 if HM.   Clobbers nothing but flags.
; ---------------------------------------------------------------------------
IsItemHM:
    cmp al, HM01                ; cp HM01
    jb .notHM                   ; jr c  (unsigned A < HM01 → below HMs)
    cmp al, TM01                ; cp TM01 → CF = (A < TM01)  [A >= HM01 here]
    ret
.notHM:
    clc                         ; and a  (clears carry)
    ret

; ---------------------------------------------------------------------------
; IsMoveHM — pret home/names.asm:IsMoveHM.
; Sets CF if the move id is one of the five HM moves.
; Faithful: `ld hl, HMMoves / ld de, 1 / jp IsInArray`. HMMoves is a flat
; .data table; IsInArray reads it with flat [ESI] addressing (matches the
; other HM/effect-category arrays), so pass the flat label directly.
; In:  AL = move id.   Out: CF = 1 if HM move, BH = index.  (tail call)
; ---------------------------------------------------------------------------
IsMoveHM:
    mov esi, HMMoves            ; ld hl, HMMoves (flat label)
    mov edx, 1                  ; ld de, 1  (entry stride)
    jmp IsInArray              ; jp IsInArray → returns CF

; ---------------------------------------------------------------------------
; IsItemInBag — MOVED to its mirror, src/home/map_objects.asm (mirror rule). It is
; a pret home/map_objects.asm label; nothing left in this file calls it, so the
; GetQuantityOfItemInBag extern went with it.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; IsKeyItem — pret home/item.asm:IsKeyItem.
; Thin wrapper: preserve HL/DE/BC and run IsKeyItem_ (a farcall in pret; a plain
; call under the flat model). Result left in [wIsKeyItem].
; In:  [wCurItem] = item id.   Out: [wIsKeyItem] = 0/1.
; ---------------------------------------------------------------------------
IsKeyItem:
    push esi                    ; push hl
    push edx                    ; push de
    push ebx                    ; push bc
    call IsKeyItem_             ; farcall IsKeyItem_
    pop ebx                     ; pop bc
    pop edx                     ; pop de
    pop esi                     ; pop hl
    ret

; ===========================================================================
; Tier-2 data (hand-authored code table, NOT generated — see header note).
; pret: data/moves/hm_moves.asm. Flat .data so IsInArray's [ESI] reads reach it.
; ===========================================================================
section .data

HMMoves:
    db CUT                       ; $0F
    db FLY                       ; $13
    db SURF                      ; $39
    db STRENGTH                  ; $46
    db FLASH                     ; $94
    db 0xFF                      ; db -1 ; end (IsInArray terminator)
