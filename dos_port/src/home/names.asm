; names.asm — mirror of pret home/names.asm.
;
; The pret file's labels, in pret order, and where each one is:
;
;   GetMonName      (:1)    here
;   GetItemName     (:27)   here
;   GetMachineName  (:51)   here
;   TechnicalPrefix (:103)  assets/home_names_runtime_strings.inc (Tier-1 text)
;   HiddenPrefix    (:105)  assets/home_names_runtime_strings.inc (Tier-1 text)
;   IsItemHM        (:110)  here
;   IsMoveHM        (:121)  here
;   HMMoves         (:126)  here (Tier-2 db list — see the banner below)
;   GetMoveName     (:129)  here
;
; NOT here, and not lost: GetName and NamePointers are pret home/names2.asm
; labels and live in src/home/names2.asm. The two pret files are one subsystem
; but two mirrors; the split follows pret. The BUG/GLITCH annotations for
; GetName's HM01 threshold and its out-of-range name walk travel with it and are
; in names2.asm — they are NOT duplicated here.
;
; The four wrappers here set [wNameListType]/[wNameListIndex] and tail-call
; GetName, except GetMonName, which is the fixed-width species path (AddNTimes,
; NAME_LENGTH-1 stride) that GetName itself dispatches to for MONSTER_NAME.
;
; Addressing note: MonsterNames and the other name tables are FLAT program
; labels read as [esi]; wNameBuffer is WRAM, so the copies here are inline
; flat→WRAM loops (CopyData would EBP-bias the source — see get_current_move.asm).
;
; ORDER: this file is not fully pret-ordered — GetMoveName sits before
; GetItemName, a pre-existing inversion this chunk did not introduce and did not
; rewrite. The arrivals are appended in pret order among themselves under the
; banner at the foot of the file.
;

; Build: nasm -f coff -I include/ -I . -o names.o src/home/names.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global GetMonName
global GetMoveName
global GetItemName
global GetMachineName
global IsItemHM
global IsMoveHM
global HMMoves

extern AddNTimes
extern MonsterNames
extern GetName                  ; src/home/names2.asm — the shared list walker
extern IsInArray                ; src/home/array2.asm — flat $FF-terminated search

section .data

%include "assets/home_names_runtime_strings.inc"

section .text

; ---------------------------------------------------------------------------
; GetMonName — fixed-width species name (faithful; no walk). Index in
; [wNamedObjectIndex] (1-based) → MonsterNames[(idx-1)*(NAME_LENGTH-1)] →
; wNameBuffer, then a '@' terminator at offset NAME_LENGTH-1.
; ---------------------------------------------------------------------------
GetMonName:
    mov al, [ebp + wNamedObjectIndex]
    dec al
    mov esi, MonsterNames
    mov bx, NAME_LENGTH - 1                  ; stride
    call AddNTimes                           ; esi += (NAME_LENGTH-1)*al (flat)
    mov edi, wNameBuffer
    mov ecx, NAME_LENGTH - 1
.cp:
    mov al, [esi]
    inc esi
    mov [ebp + edi], al
    inc edi
    dec ecx
    jnz .cp
    mov byte [ebp + edi], 0x50               ; '@' at offset NAME_LENGTH-1
    ret

; ---------------------------------------------------------------------------
; GetMoveName — name of move [wNamedObjectIndex] → wNameBuffer.
; ---------------------------------------------------------------------------
GetMoveName:
    mov al, MOVE_NAME
    mov [ebp + wNameListType], al
    mov al, [ebp + wNamedObjectIndex]
    mov [ebp + wNameListIndex], al
    jmp GetName                              ; tail call

; ---------------------------------------------------------------------------
; GetItemName — name of item [wNamedObjectIndex] → wNameBuffer (TM/HM → machine).
; ---------------------------------------------------------------------------
GetItemName:
    mov al, [ebp + wNamedObjectIndex]
    cmp al, HM01
    jae GetMachineName
    mov [ebp + wNameListIndex], al
    mov al, ITEM_NAME
    mov [ebp + wNameListType], al
    jmp GetName                              ; tail call

; ---------------------------------------------------------------------------
; GetMachineName — build "TMnn"/"HMnn" for TM/HM id [wNamedObjectIndex] →
; wNameBuffer (faithful: HM reuses the TM number path via +NUM_HMS).
; ---------------------------------------------------------------------------
GetMachineName:
    mov al, [ebp + wNamedObjectIndex]
    ; FIX(faithful): save the original index on entry (pret `push af`, home/names.asm:57)
    ; and restore it before the single ret (pret `pop af` + write-back, ~:96-97).
    ; Without this the HM path leaves `id + NUM_HMS` in wNamedObjectIndex, corrupting
    ; the index for any caller that re-reads it.
    push eax                                 ; = pret push af
    cmp al, TM01
    jae .writeTM
    add al, NUM_HMS                          ; HM → reuse TM numbering
    mov [ebp + wNamedObjectIndex], al
    mov esi, HiddenPrefix
    jmp .prefix
.writeTM:
    mov esi, TechnicalPrefix
.prefix:
    mov edi, wNameBuffer
    mov al, [esi]
    mov [ebp + edi], al
    mov al, [esi + 1]
    mov [ebp + edi + 1], al
    add edi, 2
    ; machine number = id - (TM01 - 1)
    mov al, [ebp + wNamedObjectIndex]
    sub al, TM01 - 1
    mov bl, 0xF6                             ; '0' (tens digit accumulator)
.tens:
    sub al, 10
    jc .ones
    inc bl
    jmp .tens
.ones:
    add al, 10                               ; al = ones digit (0-9)
    mov [ebp + edi], bl                      ; tens
    inc edi
    add al, 0xF6                             ; ones → '0'+n
    mov [ebp + edi], al
    inc edi
    mov byte [ebp + edi], 0x50               ; '@'
    ; FIX(faithful): restore original wNamedObjectIndex (pret `pop af` + write-back,
    ; home/names.asm:96-97). Reached by both TM and HM paths (single exit), so the
    ; entry push is always balanced.
    pop eax                                  ; = pret pop af
    mov [ebp + wNamedObjectIndex], al
    ret

; ===========================================================================
; --- was src/home/item_predicates.asm ---
; Arrivals from the deleted `home util bucket` src/home/item_predicates.asm.
; They are pret home/names.asm labels and belong here by the mirror rule.
; This file is NOT fully pret-ordered (GetMoveName precedes GetItemName, a
; pre-existing inversion), so the arrivals are appended under this banner in
; pret order among themselves: IsItemHM (pret :110), IsMoveHM (:121),
; HMMoves (:126). pret puts GetMoveName (:129) after HMMoves.
; ===========================================================================

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

; ===========================================================================
; Tier-2 data (hand-authored code table, NOT generated — see header note).
; pret: home/names.asm:HMMoves INCLUDEs data/moves/hm_moves.asm. We inline the
; five ids directly as a Tier-2 table; it is NOT emitted by any
; tools/generators/gen_*.py and `make assets` must never touch it.
; Flat .data so IsInArray's [ESI] reads reach it.
; ===========================================================================
section .data

HMMoves:
    db CUT                       ; $0F
    db FLY                       ; $13
    db SURF                      ; $39
    db STRENGTH                  ; $46
    db FLASH                     ; $94
    db 0xFF                      ; db -1 ; end (IsInArray terminator)
