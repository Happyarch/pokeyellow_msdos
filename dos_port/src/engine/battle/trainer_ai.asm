; trainer_ai.asm — Trainer AI move-scoring engine
;
; Faithful x86 NASM translation of engine/battle/trainer_ai.asm (pret/pokeyellow).
; Covers the entire AI move-selection system:
;   AIEnemyTrainerChooseMoves — builds a filtered move-weight buffer
;   AIMoveChoiceModificationFunctionPointers — flat dd dispatch table
;   AIMoveChoiceModification1/2/3/4 — per-class move-scoring modifiers
;   TrainerClassMoveChoiceModifications — per-trainer-class modifier list
;   StatusAilmentMoveEffects — data table for Mod1
;   ReadMove — loads a move record from the flat Moves table into enemy move WRAM
;   TrainerAI — top-level AI dispatcher (per-trainer-class random AI; mostly UI-coupled)
;   TrainerAIPointers — per-class AI function + count table
;   Per-trainer AI stubs (BrockAI, GenericAI, …) — deferred UI paths
;   AICheckIfHPBelowFraction, AICureStatus, DecrementAICount — pure math/WRAM helpers
;   AIUseX*, AIRecoverHP, AISwitchIfEnoughMons … — item/switch actions (UI stubbed)
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI, DE=EDX, BC=EBX.
; GB memory at [EBP+addr]; flat program-image tables accessed as [label] directly.
; `ld a,[hli]` → `mov al,[ebp+esi]; inc esi` (read THEN increment).
; SM83 conditional returns (`ret z`, `ret nz`) have no x86 equivalent:
;   `ret z`  → `jnz .continue; ret; .continue:` (return if ZF set)
;   `ret nz` → `jz  .continue; ret; .continue:` (return if ZF clear)
; `sbc` → `sbb`; AddNTimes stride in BX (not CX).
;
; Deferred externs (UI / audio — Wave 2 front-end):
;   AIPrintItemUse_, UpdateHPBar2, EnemySendOut, PlaySoundWaitForCurrent
;   (all stubbed as local no-ops so this file assembles clean)
;
; Trainer-data global dependency:
;   TrainerAIPointers is hand-written here (data-vs-code: pointers in .asm).
;   TrainerDataPointers and SpecialTrainerMoves are NOT yet generated.
;   They live in read_trainer_party.asm (q.v.) as extern stubs, reported to
;   the orchestrator for gen_trainer_parties.py + battle_data.asm integration.
;
; Shared WRAM aliases (wAILayer2Encouragement/wAICount/wBuffer/wAIItem/wEnemyMon1*)
; are in gb_memmap.inc; shared constants (EFFECT_01, XSTATITEM_DUPLICATE_ANIM,
; NUM_TRAINERS, the item ids) in gb_constants.inc — both added in the wave-1
; task-3 integration. The draft's item-id values were WRONG; the includes carry
; the correct constants/item_constants.asm values.
;
; Build:
;   nasm -f coff -I dos_port/include/ -I dos_port/ -o trainer_ai.o \
;        dos_port/src/engine/battle/trainer_ai.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; File-local derived constants. All shared WRAM aliases (wAICount, wAIItem,
; wBuffer, wEnemyMon1*, …), item IDs, NUM_TRAINERS, EFFECT_01 and
; XSTATITEM_DUPLICATE_ANIM live in gb_memmap.inc / gb_constants.inc (added in the
; wave-1 PREP / task-3 integration). NOTE: the draft's item-ID values were wrong;
; the include values are the correct constants/item_constants.asm ones.
; ---------------------------------------------------------------------------
XSTATITEM_ANIM          equ 0xAE
; percent macro: N * $FF / 100  (macros/data.asm)
PERCENT_25              equ (25 * 255 / 100 + 1)   ; 64
PERCENT_50              equ (50 * 255 / 100 + 1)   ; 128
PERCENT_13              equ (13 * 255 / 100 - 1)   ; 32
PERCENT_8               equ  (8 * 255 / 100)        ; 20
; Byte-safe mask for BADLY_POISONED bit clear (0xFF ^ 0x01 since BADLY_POISONED=0)
MASK_CLEAR_BADLY_POISONED equ (0xFF ^ (1 << BADLY_POISONED))

; ---------------------------------------------------------------------------
; Externs — already translated
; ---------------------------------------------------------------------------
extern AddNTimes
extern CopyData
extern Random
extern Divide
extern Moves
extern AIGetTypeEffectiveness
extern StatModifierUpEffect

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global AIEnemyTrainerChooseMoves
global AIMoveChoiceModification1
global AIMoveChoiceModification2
global AIMoveChoiceModification3
global AIMoveChoiceModification4
global ReadMove
global TrainerAI
global GenericAI
global DecrementAICount
global AICheckIfHPBelowFraction
global AICureStatus
global TrainerClassMoveChoiceModifications
global AIMoveChoiceModificationFunctionPointers

section .text

; ===========================================================================
; AIEnemyTrainerChooseMoves
; ---------------------------------------------------------------------------
; Builds a move-weight buffer (wBuffer[0..3], each starting at $0A = 10).
; Applies trainer-class modifier functions, then filters to the minimum-weight
; moves. Returns ESI = wBuffer (filtered) or ESI = wEnemyMonMoves (no mods).
;
; BUG-faithful: the undo loop at .loopUndoPartialIteration writes one byte
; past the start of wBuffer (= wBuffer-1 = $CEE8) when the first slot is the
; minimum. This is faithful to pret; the byte is harmless scratch WRAM.
;
; Pret ref: engine/battle/trainer_ai.asm:AIEnemyTrainerChooseMoves
; ===========================================================================
AIEnemyTrainerChooseMoves:
    ; init wBuffer[0..3] = 0x0A
    mov byte [ebp + wBuffer + 0], 0x0A
    mov byte [ebp + wBuffer + 1], 0x0A
    mov byte [ebp + wBuffer + 2], 0x0A
    mov byte [ebp + wBuffer + 3], 0x0A

    ; forbid disabled move (wEnemyDisabledMove upper nibble = 1-based slot)
    movzx eax, byte [ebp + wEnemyDisabledMove]
    shr al, 4           ; upper nibble → slot (0 = none)
    and al, 0x0F
    jz .noMoveDisabled
    dec al              ; 0-based index
    movzx ecx, al
    mov byte [ebp + wBuffer + ecx], 0x50
.noMoveDisabled:

    ; scan TrainerClassMoveChoiceModifications to find this trainer's entry
    mov esi, TrainerClassMoveChoiceModifications
    movzx ebx, byte [ebp + wTrainerClass]   ; b = wTrainerClass
.loopTrainerClasses:
    dec ebx
    jz .readTrainerClassData
.loopTrainerClassData:
    mov al, [esi]       ; scan (flat table)
    inc esi
    test al, al
    jnz .loopTrainerClassData
    jmp .loopTrainerClasses

.readTrainerClassData:
    mov al, [esi]       ; peek first byte of entry
    test al, al
    jz .useOriginalMoveSet
    push esi            ; start modifier loop

    ; --- apply each modifier in the list ---
.nextMoveChoiceModification:
    pop esi             ; current position in modifier list
    mov al, [esi]
    inc esi
    test al, al
    jz .loopFindMinimumEntries
    push esi            ; save for next iteration
    dec al
    movzx eax, al
    mov edi, [AIMoveChoiceModificationFunctionPointers + eax*4]
    call edi            ; modifier returns here
    jmp .nextMoveChoiceModification

    ; --- find the minimum-weight slot ---
.loopFindMinimumEntries:
    mov esi, wBuffer
    mov edx, wEnemyMonMoves
    mov bl, NUM_MOVES
.loopDecrementEntries:
    mov al, [ebp + edx]
    inc edx
    test al, al
    jz .loopFindMinimumEntries  ; no move: restart
    dec byte [ebp + esi]
    jz .minimumEntriesFound
    inc esi
    dec bl
    jz .loopFindMinimumEntries  ; all slots: restart
    jmp .loopDecrementEntries

.minimumEntriesFound:
    movzx eax, bl           ; a = c (remaining count)
.loopUndoPartialIteration:
    ; BUG-faithful: writes to [esi] then dec esi, potentially esi=wBuffer-1
    inc byte [ebp + esi]
    dec esi
    inc al
    cmp al, NUM_MOVES + 1
    jnz .loopUndoPartialIteration

    ; filter: keep only minimum-weight slots
    mov esi, wBuffer
    mov edx, wEnemyMonMoves
    mov bl, NUM_MOVES
.filterMinimalEntries:
    mov al, [ebp + edx]     ; move id
    test al, al
    jnz .moveExisting
    mov [ebp + esi], al     ; no move: clear slot
.moveExisting:
    mov al, [ebp + esi]
    dec al
    jz .slotWithMinimalValue
    xor al, al
    mov [ebp + esi], al     ; weight > 1: disable
    inc esi
    jmp .filterNext
.slotWithMinimalValue:
    mov al, [ebp + edx]
    mov [ebp + esi], al     ; store move id
    inc esi
.filterNext:
    inc edx
    dec bl
    jnz .filterMinimalEntries

    mov esi, wBuffer
    ret

.useOriginalMoveSet:
    mov esi, wEnemyMonMoves
    ret

; ===========================================================================
; AIMoveChoiceModificationFunctionPointers — flat dd pointer table
; Pret: dw (2-byte GB pointers). Port: dd (4-byte flat pointers), 0-indexed.
; ===========================================================================
AIMoveChoiceModificationFunctionPointers:
    dd AIMoveChoiceModification1
    dd AIMoveChoiceModification2
    dd AIMoveChoiceModification3
    dd AIMoveChoiceModification4

; ===========================================================================
; AIMoveChoiceModification1
; ---------------------------------------------------------------------------
; Discourages status-ailment moves (power=0, effect in StatusAilmentMoveEffects)
; when the player's mon already has a status (+$05 to buffer slot).
;
; BUG-faithful: the function returns early (on the first `ret z`) if the
; player has no status, rather than only skipping the discourage step.
; Pret ref: engine/battle/trainer_ai.asm:AIMoveChoiceModification1
; ===========================================================================
AIMoveChoiceModification1:
    mov al, [ebp + wBattleMonStatus]
    test al, al
    jnz .mod1_hasStatus
    ret                 ; faithful: `ret z` — early exit if no status
.mod1_hasStatus:
    mov esi, wBuffer - 1    ; hl = wBuffer-1 (pre-increment loop)
    mov edx, wEnemyMonMoves
    mov bh, NUM_MOVES + 1
.mod1_nextMove:
    dec bh
    jnz .mod1_notDone1
    ret                     ; faithful: `ret z` — processed all 4 moves
.mod1_notDone1:
    inc esi
    mov al, [ebp + edx]
    test al, al
    jnz .mod1_hasMove
    ret                     ; faithful: `ret z` — no more moves in set
.mod1_hasMove:
    inc edx
    call ReadMove
    mov al, [ebp + wEnemyMovePower]
    test al, al
    jnz .mod1_nextMove      ; has power → not a pure status move
    ; check StatusAilmentMoveEffects
    mov al, [ebp + wEnemyMoveEffect]
    push esi
    push edx
    push ebx
    mov esi, StatusAilmentMoveEffects
    call IsInArray_local    ; CF set if found
    pop ebx
    pop edx
    pop esi
    jnc .mod1_nextMove
    add byte [ebp + esi], 0x05   ; heavily discourage
    jmp .mod1_nextMove

; ===========================================================================
; AIMoveChoiceModification2
; ---------------------------------------------------------------------------
; If wAILayer2Encouragement == 1, slightly encourages stat-boosting / other
; special moves (dec weight by 1).
; Pret ref: engine/battle/trainer_ai.asm:AIMoveChoiceModification2
; ===========================================================================
AIMoveChoiceModification2:
    mov al, [ebp + wAILayer2Encouragement]
    cmp al, 1
    jz .mod2_active
    ret
.mod2_active:
    mov esi, wBuffer - 1
    mov edx, wEnemyMonMoves
    mov bh, NUM_MOVES + 1
.mod2_nextMove:
    dec bh
    jnz .mod2_notDone1
    ret
.mod2_notDone1:
    inc esi
    mov al, [ebp + edx]
    test al, al
    jnz .mod2_hasMove
    ret
.mod2_hasMove:
    inc edx
    call ReadMove
    mov al, [ebp + wEnemyMoveEffect]
    ; encourage if ATTACK_UP1_EFFECT <= effect < BIDE_EFFECT
    cmp al, ATTACK_UP1_EFFECT
    jb .mod2_nextMove
    cmp al, BIDE_EFFECT
    jb .mod2_preferMove
    ; encourage if ATTACK_UP2_EFFECT <= effect < POISON_EFFECT
    cmp al, ATTACK_UP2_EFFECT
    jb .mod2_nextMove
    cmp al, POISON_EFFECT
    jb .mod2_preferMove
    jmp .mod2_nextMove
.mod2_preferMove:
    dec byte [ebp + esi]
    jmp .mod2_nextMove

; ===========================================================================
; AIMoveChoiceModification3
; ---------------------------------------------------------------------------
; Encourages super-effective moves (dec weight -1) and discourages
; not-effective/immune moves (inc +1) when a better move of a different type
; exists (special-damage, Super Fang, Fly, or damaging move of different type).
; Pret ref: engine/battle/trainer_ai.asm:AIMoveChoiceModification3
; ===========================================================================
AIMoveChoiceModification3:
    mov esi, wBuffer - 1
    mov edx, wEnemyMonMoves
    mov bh, NUM_MOVES + 1
.mod3_nextMove:
    dec bh
    jnz .mod3_notDone1
    ret
.mod3_notDone1:
    inc esi
    mov al, [ebp + edx]
    test al, al
    jnz .mod3_hasMove
    ret
.mod3_hasMove:
    inc edx
    call ReadMove
    push esi
    push ebx
    push edx
    call AIGetTypeEffectiveness
    pop edx
    pop ebx
    pop esi
    mov al, [ebp + wTypeEffectiveness]
    cmp al, 0x10
    jz .mod3_nextMove           ; neutral → no change
    jb .mod3_notEffective       ; < 0x10 → not effective or immune
    dec byte [ebp + esi]        ; > 0x10 → super effective: encourage
    jmp .mod3_nextMove

.mod3_notEffective:
    ; inner loop: check if any "better" move exists
    push esi
    push edx
    push ebx
    ; save original move type on native stack before pushing registers
    movzx ecx, byte [ebp + wEnemyMoveType]
    push ecx                        ; original type
    mov esi, wEnemyMonMoves
    mov bh, NUM_MOVES + 1
    xor bl, bl                      ; c = 0 (no better move)
.mod3_loopMoves:
    dec bh
    jz .mod3_inner_done
    mov al, [ebp + esi]
    inc esi
    test al, al
    jz .mod3_inner_done
    call ReadMove                   ; preserves esi, edx, ebx
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, SUPER_FANG_EFFECT
    je .mod3_betterMoveFound
    cmp al, SPECIAL_DAMAGE_EFFECT
    je .mod3_betterMoveFound
    cmp al, FLY_EFFECT
    je .mod3_betterMoveFound
    mov al, [ebp + wEnemyMoveType]
    cmp al, byte [esp]              ; compare with saved original type
    je .mod3_loopMoves
    mov al, [ebp + wEnemyMovePower]
    test al, al
    jnz .mod3_betterMoveFound
    jmp .mod3_loopMoves
.mod3_betterMoveFound:
    mov bl, al                      ; c = non-zero
.mod3_inner_done:
    movzx eax, bl
    pop ecx                         ; discard saved type
    pop ebx
    pop edx
    pop esi
    test al, al
    jz .mod3_nextMove               ; no better move: don't discourage
    inc byte [ebp + esi]            ; discourage non-effective move
    jmp .mod3_nextMove

; ===========================================================================
; AIMoveChoiceModification4 — unused no-op
; Pret ref: engine/battle/trainer_ai.asm:AIMoveChoiceModification4
; ===========================================================================
AIMoveChoiceModification4:
    ret

; ===========================================================================
; StatusAilmentMoveEffects — effects treated as status-only by Mod1
; ===========================================================================
StatusAilmentMoveEffects:
    db EFFECT_01        ; $01 unused sleep effect
    db SLEEP_EFFECT
    db POISON_EFFECT
    db PARALYZE_EFFECT
    db 0xFF             ; -1 sentinel

; ===========================================================================
; IsInArray_local — local flat-table byte scan (not exported)
; Input:  AL = search value, ESI = flat table base ($FF = sentinel).
; Output: CF set if found; ESI/EDX/EBX preserved.
; Report: a global IsInArray should be added to dos_port/src/home/array.asm.
; ===========================================================================
IsInArray_local:
    push esi
    push ecx
    movzx ecx, al
.isInArray_loop:
    mov al, [esi]
    cmp al, 0xFF
    je .isInArray_notfound
    cmp al, cl
    je .isInArray_found
    inc esi
    jmp .isInArray_loop
.isInArray_found:
    pop ecx
    pop esi
    stc
    ret
.isInArray_notfound:
    pop ecx
    pop esi
    clc
    ret

; ===========================================================================
; ReadMove
; ---------------------------------------------------------------------------
; Load move record for move-id AL from flat Moves table into WRAM
; wEnemyMoveNum..wEnemyMoveMaxPP (MOVE_LENGTH bytes).
; Preserves ESI, EDX, EBX.
; Pret ref: engine/battle/trainer_ai.asm:ReadMove
; ===========================================================================
ReadMove:
    push esi
    push edx
    push ebx
    dec al
    movzx ecx, al
    imul ecx, ecx, MOVE_LENGTH
    mov esi, Moves
    add esi, ecx
    mov edx, wEnemyMoveNum
    mov ecx, MOVE_LENGTH
.readMove_copy:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .readMove_copy
    pop ebx
    pop edx
    pop esi
    ret

; ===========================================================================
; TrainerClassMoveChoiceModifications — flat data table
; ---------------------------------------------------------------------------
; Null-terminated modifier-id sequences, one per trainer class (order 1..47).
; AIEnemyTrainerChooseMoves skips (class-1) entries then reads the current one.
; Pret ref: data/trainers/move_choices.asm via `move_choices` macro.
; ===========================================================================
TrainerClassMoveChoiceModifications:
    db 0             ; YOUNGSTER      ($01)
    db 1, 0          ; BUG_CATCHER    ($02)
    db 1, 0          ; LASS           ($03)
    db 1, 3, 0       ; SAILOR         ($04)
    db 1, 0          ; JR_TRAINER_M   ($05)
    db 1, 0          ; JR_TRAINER_F   ($06)
    db 1, 2, 3, 0    ; POKEMANIAC     ($07)
    db 1, 2, 0       ; SUPER_NERD     ($08)
    db 1, 0          ; HIKER          ($09)
    db 1, 0          ; BIKER          ($0A)
    db 1, 3, 0       ; BURGLAR        ($0B)
    db 1, 0          ; ENGINEER       ($0C)
    db 1, 2, 0       ; UNUSED_JUGGLER ($0D)
    db 1, 3, 0       ; FISHER         ($0E)
    db 1, 3, 0       ; SWIMMER        ($0F)
    db 0             ; CUE_BALL       ($10)
    db 1, 0          ; GAMBLER        ($11)
    db 1, 3, 0       ; BEAUTY         ($12)
    db 1, 2, 0       ; PSYCHIC_TR     ($13)
    db 1, 0          ; ROCKER         ($14)
    db 1, 0          ; JUGGLER        ($15)
    db 1, 0          ; TAMER          ($16)
    db 1, 0          ; BIRD_KEEPER    ($17)
    db 1, 0          ; BLACKBELT      ($18)
    db 1, 0          ; RIVAL1         ($19)
    db 1, 3, 0       ; PROF_OAK       ($1A)
    db 1, 2, 0       ; CHIEF          ($1B)
    db 1, 2, 0       ; SCIENTIST      ($1C)
    db 1, 3, 0       ; GIOVANNI       ($1D)
    db 1, 0          ; ROCKET         ($1E)
    db 1, 3, 0       ; COOLTRAINER_M  ($1F)
    db 1, 3, 0       ; COOLTRAINER_F  ($20)
    db 1, 0          ; BRUNO          ($21)
    db 1, 0          ; BROCK          ($22)
    db 1, 3, 0       ; MISTY          ($23)
    db 1, 0          ; LT_SURGE       ($24)
    db 1, 3, 0       ; ERIKA          ($25)
    db 1, 3, 0       ; KOGA           ($26)
    db 1, 0          ; BLAINE         ($27)
    db 1, 0          ; SABRINA        ($28)
    db 1, 2, 0       ; GENTLEMAN      ($29)
    db 1, 3, 0       ; RIVAL2         ($2A)
    db 1, 3, 0       ; RIVAL3         ($2B)
    db 1, 2, 3, 0    ; LORELEI        ($2C)
    db 1, 0          ; CHANNELER      ($2D)
    db 1, 0          ; AGATHA         ($2E)
    db 1, 3, 0       ; LANCE          ($2F)

; ===========================================================================
; TrainerAI — top-level AI dispatcher
; ---------------------------------------------------------------------------
; Called once per trainer turn. Rolls Random, calls the class-specific AI.
; Returns CF set if an action was taken.
; Pret ref: engine/battle/trainer_ai.asm:TrainerAI
; ===========================================================================
TrainerAI:
    mov al, [ebp + wIsInBattle]
    dec al
    jz .done            ; not a trainer battle
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jz .done
    mov al, [ebp + wEnemyBattleStatus1]
    test al, (1 << CHARGING_UP) | (1 << THRASHING_ABOUT) | (1 << STORING_ENERGY)
    jnz .done
    mov al, [ebp + wEnemyBattleStatus2]
    test al, (1 << USING_RAGE)
    jnz .done
    ; look up trainer-class entry: 5 bytes each (db count + dd ptr)
    movzx eax, byte [ebp + wTrainerClass]
    dec eax
    mov ecx, 5
    imul ecx, eax           ; offset = (class-1) * 5
    mov esi, TrainerAIPointers
    add esi, ecx            ; esi → {db count, dd ptr}
    ; check AI count
    mov al, [ebp + wAICount]
    test al, al
    jz .done
    inc al
    jnz .getpointer
    ; al was 0: reload count from table, then proceed
    mov al, [esi]
    mov [ebp + wAICount], al
.getpointer:
    inc esi                 ; skip count byte
    mov edi, [esi]          ; load function pointer (dd)
    call Random             ; random byte in AL
    call edi                ; class-specific AI; CF=1 if action taken
    ret
.done:
    clc
    ret

; ===========================================================================
; TrainerAIPointers — per-class entry: db count_byte + dd function_pointer
; Each entry is 5 bytes. Pret: dbw (1+2 bytes, GB pointer).
; Port: db + dd (1+4 bytes, flat pointer).
; Pret ref: data/trainers/ai_pointers.asm:TrainerAIPointers
; ===========================================================================
TrainerAIPointers:
%macro taip 2           ; count, FunctionLabel
    db %1
    dd %2
%endmacro
    taip 3, GenericAI          ; YOUNGSTER
    taip 3, GenericAI          ; BUG_CATCHER
    taip 3, GenericAI          ; LASS
    taip 3, GenericAI          ; SAILOR
    taip 3, GenericAI          ; JR_TRAINER_M
    taip 3, GenericAI          ; JR_TRAINER_F
    taip 3, GenericAI          ; POKEMANIAC
    taip 3, GenericAI          ; SUPER_NERD
    taip 3, GenericAI          ; HIKER
    taip 3, GenericAI          ; BIKER
    taip 3, GenericAI          ; BURGLAR
    taip 3, GenericAI          ; ENGINEER
    taip 3, JugglerAI          ; UNUSED_JUGGLER
    taip 3, GenericAI          ; FISHER
    taip 3, GenericAI          ; SWIMMER
    taip 3, GenericAI          ; CUE_BALL
    taip 3, GenericAI          ; GAMBLER
    taip 3, GenericAI          ; BEAUTY
    taip 3, GenericAI          ; PSYCHIC_TR
    taip 3, GenericAI          ; ROCKER
    taip 3, JugglerAI          ; JUGGLER
    taip 3, GenericAI          ; TAMER
    taip 3, GenericAI          ; BIRD_KEEPER
    taip 2, BlackbeltAI        ; BLACKBELT
    taip 3, GenericAI          ; RIVAL1
    taip 3, GenericAI          ; PROF_OAK
    taip 1, GenericAI          ; CHIEF
    taip 3, GenericAI          ; SCIENTIST
    taip 1, GiovanniAI         ; GIOVANNI
    taip 3, GenericAI          ; ROCKET
    taip 2, CooltrainerMAI     ; COOLTRAINER_M
    taip 1, CooltrainerFAI     ; COOLTRAINER_F
    taip 2, BrunoAI            ; BRUNO
    taip 5, BrockAI            ; BROCK
    taip 1, MistyAI            ; MISTY
    taip 1, LtSurgeAI          ; LT_SURGE
    taip 1, ErikaAI            ; ERIKA
    taip 2, KogaAI             ; KOGA
    taip 2, BlaineAI           ; BLAINE
    taip 1, SabrinaAI          ; SABRINA
    taip 3, GenericAI          ; GENTLEMAN
    taip 1, Rival2AI           ; RIVAL2
    taip 1, Rival3AI           ; RIVAL3
    taip 2, LoreleiAI          ; LORELEI
    taip 3, GenericAI          ; CHANNELER
    taip 2, AgathaAI           ; AGATHA
    taip 1, LanceAI            ; LANCE

; ===========================================================================
; Per-trainer AI functions
; Input: AL = Random() output.  Return: CF=1 if action taken, CF=0 otherwise.
; Pret ref: engine/battle/trainer_ai.asm (each FooAI label).
; ===========================================================================

JugglerAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AISwitchIfEnoughMons
.done:  clc
    ret

BlackbeltAI:
    cmp al, PERCENT_13
    jnc .done
    jmp AIUseXAttack
.done:  clc
    ret

GiovanniAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseGuardSpec
.done:  clc
    ret

CooltrainerMAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseXAttack
.done:  clc
    ret

CooltrainerFAI:
    ; BUG: the intended `ret nc` after `cp 25 percent + 1` is commented out
    ; in pret, so the 25% bail never fires. Faithful translation: we do NOT
    ; add `jnc .done` after the cmp.
    cmp al, PERCENT_25
    ; jnc .done  <-- intentionally omitted (pret BUG, no ret nc)
    mov al, 10
    call AICheckIfHPBelowFraction
    jnc .coolf2
    jmp AIUseHyperPotion
.coolf2:
    mov al, 5
    call AICheckIfHPBelowFraction
    jnc .coofdone
    jmp AISwitchIfEnoughMons
.coofdone: clc
    ret

BrockAI:
    mov al, [ebp + wEnemyMonStatus]
    test al, al
    jz .done
    jmp AIUseFullHeal
.done:  clc
    ret

MistyAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseXDefend
.done:  clc
    ret

LtSurgeAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseXSpeed
.done:  clc
    ret

ErikaAI:
    cmp al, PERCENT_50
    jnc .done
    mov al, 10
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseSuperPotion
.done:  clc
    ret

KogaAI:
    cmp al, PERCENT_13
    jnc .done
    jmp AIUseXAttack
.done:  clc
    ret

BlaineAI:
    cmp al, PERCENT_25
    jnc .done
    mov al, 10
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseSuperPotion
.done:  clc
    ret

SabrinaAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseXDefend
.done:  clc
    ret

Rival2AI:
    cmp al, PERCENT_13
    jnc .done
    mov al, 5
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUsePotion
.done:  clc
    ret

Rival3AI:
    cmp al, PERCENT_13
    jnc .done
    mov al, 5
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseFullRestore
.done:  clc
    ret

LoreleiAI:
    cmp al, PERCENT_50
    jnc .done
    mov al, 5
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseSuperPotion
.done:  clc
    ret

BrunoAI:
    cmp al, PERCENT_25
    jnc .done
    jmp AIUseXDefend
.done:  clc
    ret

AgathaAI:
    cmp al, PERCENT_8
    jb .aswitch
    cmp al, PERCENT_50
    jnc .done
    mov al, 4
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseSuperPotion
.aswitch:
    jmp AISwitchIfEnoughMons
.done:  clc
    ret

LanceAI:
    cmp al, PERCENT_50
    jnc .done
    mov al, 5
    call AICheckIfHPBelowFraction
    jnc .done
    jmp AIUseHyperPotion
.done:  clc
    ret

GenericAI:
    clc
    ret

; ===========================================================================
; DecrementAICount — decrement [wAICount], return CF=1 (action taken).
; ===========================================================================
DecrementAICount:
    dec byte [ebp + wAICount]
    stc
    ret

; ===========================================================================
; AICheckIfHPBelowFraction
; ---------------------------------------------------------------------------
; Return CF set if wEnemyMonHP < wEnemyMonMaxHP / AL.
; Pure math via Divide; no UI.
; Pret ref: engine/battle/trainer_ai.asm:AICheckIfHPBelowFraction
; ===========================================================================
AICheckIfHPBelowFraction:
    mov [ebp + hDivisor], al
    mov al, [ebp + wEnemyMonMaxHP]
    mov [ebp + hDividend], al
    mov al, [ebp + wEnemyMonMaxHP + 1]
    mov [ebp + hDividend + 1], al
    mov bh, 2
    call Divide
    ; compare wEnemyMonHP (big-endian) with quotient
    ; quotient is in hQuotient[2..3]: byte[2]=high, byte[3]=low
    movzx ebx, byte [ebp + hQuotient + 2]   ; threshold high → b
    movzx ecx, byte [ebp + hQuotient + 3]   ; threshold low  → c
    movzx edx, byte [ebp + wEnemyMonHP + 1] ; HP low → e
    movzx eax, byte [ebp + wEnemyMonHP]     ; HP high → d
    ; pret: `ld a, d; sub b; ret nz`
    mov dl, al
    sub dl, bl                  ; d - b
    jnz .hpfrac_ret
    ; `ld a, e; sub c; ret`
    movzx edx, byte [ebp + wEnemyMonHP + 1]
    sub dl, cl
.hpfrac_ret:
    ret

; ===========================================================================
; AICureStatus
; ---------------------------------------------------------------------------
; Clears status in both wEnemyMonStatus (battle) and the party roster entry.
; Clears BADLY_POISONED in wEnemyBattleStatus3. Pure WRAM writes; no UI.
; Pret ref: engine/battle/trainer_ai.asm:AICureStatus
; ===========================================================================
AICureStatus:
    movzx eax, byte [ebp + wEnemyMonPartyPos]  ; AL = count for AddNTimes
    mov esi, wEnemyMon1Status
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    xor al, al
    mov [ebp + esi], al                     ; clear party roster status
    mov [ebp + wEnemyMonStatus], al         ; clear active battle status
    and byte [ebp + wEnemyBattleStatus3], MASK_CLEAR_BADLY_POISONED
    ret

; ===========================================================================
; AI item-use helpers (UI parts stubbed)
; ===========================================================================

; --- AIPlayRestoringSFX ---
; TODO-HW: audio HAL Phase 3. Stub no-op.
AIPlayRestoringSFX:
    ret

; --- AIPrintItemUse_ ---
; Deferred UI: "X used [wAIItem] on Z!" (GetItemName + PrintText).
AIPrintItemUse_:
    ; TODO-UI: deferred Wave 2 front-end
    ret

; --- AIPrintItemUseAndUpdateHPBar ---
; Deferred UI: item text + UpdateHPBar2.
AIPrintItemUseAndUpdateHPBar:
    ; TODO-UI: deferred Wave 2 front-end
    jmp DecrementAICount

; --- AIUsePotion, AIUseSuperPotion, AIUseHyperPotion ---
; Pret ref: engine/battle/trainer_ai.asm:AIUsePotion etc.
AIUsePotion:
    mov al, POTION
    mov bh, 20
    jmp AIRecoverHP

AIUseSuperPotion:
    mov al, SUPER_POTION
    mov bh, 50
    jmp AIRecoverHP

AIUseHyperPotion:
    mov al, HYPER_POTION
    mov bh, 200
    ; fallthrough

; --- AIRecoverHP ---
; Heal BH HP from enemy mon (cap at maxHP), write HPBar scratch. UI stubbed.
; Pret ref: engine/battle/trainer_ai.asm:AIRecoverHP
AIRecoverHP:
    mov [ebp + wAIItem], al
    ; read current HP (big-endian: high at wEnemyMonHP, low at +1)
    movzx ecx, byte [ebp + wEnemyMonHP]      ; HP high
    movzx edx, byte [ebp + wEnemyMonHP + 1]  ; HP low
    ; save old HP to HPBar scratch
    mov [ebp + wHPBarOldHP], dl
    mov [ebp + wHPBarOldHP + 1], cl
    ; add heal (bh = B register = heal amount)
    movzx eax, bh
    add edx, eax
    mov [ebp + wEnemyMonHP + 1], dl
    mov [ebp + wHPBarNewHP], dl
    mov [ebp + wHPBarNewHP + 1], cl
    jnc .recoverHP_noCarry
    inc ecx                         ; propagate carry to high byte
    mov [ebp + wEnemyMonHP], cl
    mov [ebp + wHPBarNewHP + 1], cl
.recoverHP_noCarry:
    ; cap at maxHP
    movzx eax, byte [ebp + wEnemyMonMaxHP]      ; maxHP high
    movzx ebx, byte [ebp + wEnemyMonMaxHP + 1]  ; maxHP low
    mov [ebp + wHPBarMaxHP], bl
    mov [ebp + wHPBarMaxHP + 1], al
    cmp ecx, eax
    ja .recoverHP_cap
    jb .recoverHP_ok
    cmp edx, ebx
    jbe .recoverHP_ok
.recoverHP_cap:
    mov [ebp + wEnemyMonHP], al
    mov [ebp + wEnemyMonHP + 1], bl
    mov [ebp + wHPBarNewHP], bl
    mov [ebp + wHPBarNewHP + 1], al
.recoverHP_ok:
    jmp AIPrintItemUseAndUpdateHPBar

; --- AIUseFullRestore ---
; Cure status + set HP = maxHP. UI stubbed.
; Pret ref: engine/battle/trainer_ai.asm:AIUseFullRestore
AIUseFullRestore:
    call AICureStatus
    mov al, FULL_RESTORE
    mov [ebp + wAIItem], al
    movzx ecx, byte [ebp + wEnemyMonHP + 1]
    mov [ebp + wHPBarOldHP], cl
    movzx ecx, byte [ebp + wEnemyMonHP]
    mov [ebp + wHPBarOldHP + 1], cl
    movzx eax, byte [ebp + wEnemyMonMaxHP + 1]  ; maxHP low
    movzx ecx, byte [ebp + wEnemyMonMaxHP]       ; maxHP high
    mov [ebp + wHPBarMaxHP], al
    mov [ebp + wHPBarMaxHP + 1], cl
    mov [ebp + wEnemyMonHP + 1], al
    mov [ebp + wHPBarNewHP], al
    mov [ebp + wEnemyMonHP], cl
    mov [ebp + wHPBarNewHP + 1], cl
    jmp AIPrintItemUseAndUpdateHPBar

; --- AIUseFullHeal ---
; Pret ref: engine/battle/trainer_ai.asm:AIUseFullHeal
AIUseFullHeal:
    call AIPlayRestoringSFX
    call AICureStatus
    mov al, FULL_HEAL
    jmp AIPrintItemUse

; --- AISwitchIfEnoughMons / SwitchEnemyMon ---
; Pret ref: engine/battle/trainer_ai.asm:AISwitchIfEnoughMons / SwitchEnemyMon
AISwitchIfEnoughMons:
    movzx ecx, byte [ebp + wEnemyPartyCount]
    mov esi, wEnemyMon1HP
    xor edx, edx                            ; d = unfainted count
.aswitch_loop:
    movzx eax, byte [ebp + esi]             ; HP high
    movzx ebx, byte [ebp + esi + 1]         ; HP low
    or al, bl
    jz .aswitch_fainted
    inc edx
.aswitch_fainted:
    push ecx
    mov ecx, PARTYMON_STRUCT_LENGTH
    add esi, ecx
    pop ecx
    dec ecx
    jnz .aswitch_loop
    cmp edx, 2
    jnc SwitchEnemyMon
    clc
    ret

SwitchEnemyMon:
    ; copy HP and status back to party roster
    movzx eax, byte [ebp + wEnemyMonPartyPos]  ; AL = count for AddNTimes
    mov esi, wEnemyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    ; esi = wEnemyMon1HP + partyPos * PARTYMON_STRUCT_LENGTH
    mov edx, wEnemyMonHP
    mov ecx, (MON_STATUS + 1 - MON_HP)     ; = 4 bytes
.switchMon_copy:
    mov al, [ebp + edx]
    mov [ebp + esi], al
    inc edx
    inc esi
    dec ecx
    jnz .switchMon_copy
    ; TODO-UI: PrintText AIBattleWithdrawText (deferred Wave 2)
    ; TODO-UI: EnemySendOut (deferred Wave 2)
    stc
    ret

; --- AIUseXAttack / Defend / Speed / Special ---
; Pret ref: engine/battle/trainer_ai.asm:AIUseXAttack etc.
AIUseXAttack:
    mov bh, ATTACK_UP1_EFFECT
    mov al, X_ATTACK
    jmp AIIncreaseStat

AIUseXDefend:
    mov bh, DEFENSE_UP1_EFFECT
    mov al, X_DEFEND
    jmp AIIncreaseStat

AIUseXSpeed:
    mov bh, SPEED_UP1_EFFECT
    mov al, X_SPEED
    jmp AIIncreaseStat

AIUseXSpecial:
    mov bh, SPECIAL_UP1_EFFECT
    mov al, X_SPECIAL
    ; fallthrough

; --- AIIncreaseStat ---
; Save wEnemyMoveNum/Effect, inject XSTATITEM_DUPLICATE_ANIM + stat effect,
; call StatModifierUpEffect, restore. UI call stubbed.
; Pret ref: engine/battle/trainer_ai.asm:AIIncreaseStat
AIIncreaseStat:
    mov [ebp + wAIItem], al
    push ebx                        ; save bh (stat effect id)
    call AIPrintItemUse_            ; deferred UI stub
    pop ebx
    ; save current wEnemyMoveNum and wEnemyMoveEffect
    movzx eax, byte [ebp + wEnemyMoveEffect]
    push eax
    movzx eax, byte [ebp + wEnemyMoveNum]
    push eax
    ; inject temporary values
    mov byte [ebp + wEnemyMoveNum], XSTATITEM_DUPLICATE_ANIM
    mov [ebp + wEnemyMoveEffect], bh   ; bh = stat effect id (B register)
    call StatModifierUpEffect
    ; restore
    pop eax
    mov [ebp + wEnemyMoveNum], al
    pop eax
    mov [ebp + wEnemyMoveEffect], al
    jmp DecrementAICount

; --- AIUseGuardSpec ---
; Pret ref: engine/battle/trainer_ai.asm:AIUseGuardSpec
AIUseGuardSpec:
    call AIPlayRestoringSFX
    or byte [ebp + wEnemyBattleStatus2], (1 << PROTECTED_BY_MIST)
    mov al, GUARD_SPEC
    jmp AIPrintItemUse

; --- AIPrintItemUse ---
; Store item, call UI stub, decrement count.
; Pret ref: engine/battle/trainer_ai.asm:AIPrintItemUse
AIPrintItemUse:
    mov [ebp + wAIItem], al
    call AIPrintItemUse_
    jmp DecrementAICount

; --- AIUseXAccuracy (unreferenced in pret) ---
AIUseXAccuracy:
    call AIPlayRestoringSFX
    or byte [ebp + wEnemyBattleStatus2], (1 << USING_X_ACCURACY)
    mov al, X_ACCURACY
    jmp AIPrintItemUse

; --- AIUseDireHit (unreferenced in pret) ---
AIUseDireHit:
    call AIPlayRestoringSFX
    or byte [ebp + wEnemyBattleStatus2], (1 << GETTING_PUMPED)
    mov al, DIRE_HIT
    jmp AIPrintItemUse
