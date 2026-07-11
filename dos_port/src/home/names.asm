; names.asm — shared name lookup (faithful: home/names.asm + home/names2.asm).
;
; The gen-1 name dispatcher. GetName resolves [wNameListIndex] within the list
; chosen by [wNameListType] (a NamePointers index) into wNameBuffer. Wrappers
; GetMonName / GetMoveName / GetItemName / GetMachineName set the type and call it.
;
;   type 1 MONSTER_NAME  → GetMonName: FIXED-WIDTH (AddNTimes, NAME_LENGTH-1 stride).
;   types 2-7            → walk the '@'(0x50)-terminated list, counting terminators.
;
; Addressing note (the flat-vs-WRAM hazard): NamePointers mixes FLAT program
; labels (Monster/Move/Unused/Item/Trainer names — read [esi]) with WRAM lists
; (wPartyMonOT/wEnemyMonOT — read [ebp+esi]). GetName biases the two OT entries by
; EBP up front so the walk/copy is uniform afterwards. The flat name tables (incl.
; MoveNames) are read flat; wNameBuffer is WRAM, so the copy is an inline
; flat→WRAM loop (CopyData would EBP-bias the source — see get_current_move.asm).
;
; BUG (faithful, range-guarded): pret's `cp HM01` test applies to ALL name types,
; not just items — any id >= HM01 fetches a TM/HM name. Harmless in normal play
; (NUM_ATTACKS and the mon indexes are all < HM01). Preserved.
;
; GLITCH (name-overflow): an out-of-range index walks the SOURCE past the table
; through adjacent program/WRAM bytes until a 0x50 → garbage names (the glitch-
; name mechanism). The destination copy is bounded (NAME_BUFFER_LENGTH), so
; wNameBuffer never overflows — this is cosmetic, not memory corruption.
; Safety: bounded under DPMI flat alloc. Optional FIXALL guard below.
; This is the .walk mechanism behind two docs/references/yellow_glitches.md
; #battle-system entries reached via a glitch move index in a mon's moveset:
; "Super Glitch" (indices A6-C3, no name entry — search overruns MoveNames) and
; "Move 0x00" (index 0x00, the CoolTrainer♀/"--" glitch — same overrun, index 0
; walks from before the table start). Both are cataloged BUG(critical) with
; "Potential" ACE on real hardware (ROM-bank-dependent overrun target); in this
; port the overrun target is adjacent linked .data/.text, not attacker-chosen
; ROM content, and the destination write stays within NAME_BUFFER_LENGTH — no
; ACE path exists here (downgraded to a bounded cosmetic glitch, per the Safety
; line above). Neither glitch move entry nor index-0 "--" is reachable through
; normal ported gameplay yet (no glitch-Pokémon catch path — see
; docs/bug_categorization.md, Save/SRAM "Index #000 Post-Capture" — pending
; port), so this is latent/dormant rather than live, but the shared mechanism
; is already faithfully preserved for whenever that path lands.
;
; This file lives in the not-yet-linked battle/name tier (assembled by `make
; check`, validated by native harness). MoveNames/ItemNames are flat data labels;
; TrainerNames/wPartyMonOT/wEnemyMonOT resolve when the battle UI is linked.
;
; Build: nasm -f coff -I include/ -I . -o names.o src/home/names.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"        ; BUG_FIX_LEVEL

global GetName
global GetMonName
global GetMoveName
global GetItemName
global GetMachineName
global NamePointers

extern AddNTimes
extern MonsterNames
extern MoveNames
extern ItemNames
extern TrainerNames
; wPartyMonOT / wEnemyMonOT are WRAM equs from gb_memmap.inc.

%if BUG_FIX_LEVEL >= 2
NAME_WALK_MAX   equ 0x2000      ; FIXALL: cap the source walk to bound runaways
%endif

section .data
align 4

; NamePointers — indexed by (wNameListType - 1). See list_constants.asm.
NamePointers:
    dd MonsterNames         ; 1 MONSTER_NAME  (flat; routed via GetMonName)
    dd MoveNames            ; 2 MOVE_NAME     (flat)
    dd UnusedBadgeNames     ; 3 UNUSED_NAME   (flat)
    dd ItemNames            ; 4 ITEM_NAME     (flat)
    dd wPartyMonOT          ; 5 PLAYEROT_NAME (WRAM; +EBP)
    dd wEnemyMonOT          ; 6 ENEMYOT_NAME  (WRAM; +EBP)
    dd TrainerNames         ; 7 TRAINER_NAME  (flat)

; type 3 is genuinely unused in gen 1; a lone terminator stands in for the table.
UnusedBadgeNames:
    db 0x50

TechnicalPrefix:  db 0x93, 0x8C    ; "TM"
HiddenPrefix:     db 0x87, 0x8C    ; "HM"

section .text

; ---------------------------------------------------------------------------
; GetName — resolve [wNameListIndex] in list [wNameListType] → wNameBuffer.
; (wPredefBank is ignored: ROM banking is a no-op in the flat model.)
; ---------------------------------------------------------------------------
GetName:
    mov al, [ebp + wNameListIndex]
    mov [ebp + wNamedObjectIndex], al

    ; BUG(faithful): the HM01 test applies to all name types.
    cmp al, HM01
    jae GetMachineName

    mov al, [ebp + wNameListType]
    cmp al, MONSTER_NAME
    je GetMonName                       ; fixed-width path (tail)

    ; types 2-7: esi = NamePointers[type-1]  (flat read of our own .data table)
    movzx eax, al
    dec eax
    mov esi, [NamePointers + eax*4]

    ; OT lists are WRAM offsets → bias by EBP so the walk reads linear memory.
    mov al, [ebp + wNameListType]
    cmp al, PLAYEROT_NAME
    je .wram
    cmp al, ENEMYOT_NAME
    jne .walk
.wram:
    add esi, ebp
.walk:
    movzx ebx, byte [ebp + wNameListIndex]   ; bl = wanted entry (1-based)
    xor ecx, ecx                             ; cl = entry counter
%if BUG_FIX_LEVEL >= 2
    xor edi, edi                             ; FIXALL: bytes-walked budget
%endif
.nextName:
    mov edx, esi                             ; remember this entry's start
.nextChar:
    mov al, [esi]
    inc esi
%if BUG_FIX_LEVEL >= 2
    inc edi
    cmp edi, NAME_WALK_MAX
    jae .placeholder                         ; runaway: bail to a safe empty name
%endif
    cmp al, 0x50                             ; '@'
    jne .nextChar
    inc cl
    cmp cl, bl
    jne .nextName
    ; edx = start of the wanted entry. Faithful: stash it in wUnusedNamePointer.
    mov [ebp + wUnusedNamePointer], dx
    ; copy bounded NAME_BUFFER_LENGTH bytes (flat src → WRAM dst).
    mov esi, edx
    mov edi, wNameBuffer
    mov ecx, NAME_BUFFER_LENGTH
.copy:
    mov al, [esi]
    inc esi
    mov [ebp + edi], al
    inc edi
    dec ecx
    jnz .copy
    ret

%if BUG_FIX_LEVEL >= 2
.placeholder:
    mov byte [ebp + wNameBuffer], 0x50       ; empty, terminated name
    ret
%endif

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
