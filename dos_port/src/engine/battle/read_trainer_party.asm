; read_trainer_party.asm — ReadTrainer: parse a trainer's party blob into WRAM.
;
; Faithful x86 NASM translation of engine/battle/read_trainer_party.asm
; (pret/pokeyellow).
;
; ReadTrainer parses a trainer's party blob from TrainerDataPointers into
; wEnemyPartyCount / wEnemyPartySpecies / wEnemyMons using AddPartyMon, and
; then optionally applies SpecialTrainerMoves (per-move overrides for Yellow).
; Finally it computes wAmountMoneyWon via AddBCDPredef.
;
; Two flat data tables required by ReadTrainer are NOT yet generated for the
; port.  They are declared extern here and REPORTED as deferred dependencies:
;
;   TrainerDataPointers — an array of NUM_TRAINERS flat pointers (dd), one per
;     trainer class, each pointing to that class's sequential trainer blobs.
;     Needs generator: tools/generators/gen_trainer_parties.py → assets/trainer_parties.inc
;     + a global in dos_port/src/data/battle_data.asm (or a new file
;     dos_port/src/data/trainer_data.asm).
;
;   SpecialTrainerMoves — flat byte sequence (trainer class, trainer no, then
;     {party-slot, move-slot, move-id} triples, 0-terminated per trainer,
;     0xFF-terminated globally).  Same generator.
;
;   AddBCDPredef — BCD 2-digit addition (predef system, home/predef.asm).
;     Not yet ported; stubbed as a no-op here.
;
; Synthetic validation harness: scratchpad/w1_ai/test_read_trainer.asm
;   — seeds inline trainer blobs (both flat-level and special-level formats),
;     calls ReadTrainer, asserts wEnemyPartyCount/species/level are correct.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI, DE=EDX, BC=EBX.
; GB memory at [EBP+addr]; flat tables via [label+offset].
; `ld a,[hli]` → `mov al,[esi]; inc esi` (read THEN increment).
;
; Build:
;   nasm -f coff -I dos_port/include/ -I dos_port/ -o read_trainer_party.o \
;        dos_port/src/engine/battle/read_trainer_party.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; WRAM aliases (wTrainerBaseMoney, wLoneAttackNo, wTrainerNo, wAmountMoneyWon,
; wFirstMonsNotOutYet, wEnemyMon1Moves) live in gb_memmap.inc (added in the
; wave-1 task-3 integration).

; ---------------------------------------------------------------------------
; Externs — already implemented in the port
; ---------------------------------------------------------------------------
extern AddNTimes
extern CopyData
extern AddPartyMon

; ---------------------------------------------------------------------------
; Deferred data externs — NOT YET GENERATED.
; Marked REPORT so the orchestrator knows to wire the generator.
; ---------------------------------------------------------------------------
; REPORT: gen_trainer_parties.py → assets/trainer_parties.inc
;         Must emit TrainerDataPointers (dd table, NUM_TRAINERS entries)
;         and SpecialTrainerMoves (byte stream, $FF-terminated globally).
;         Add to battle_data.asm (or a new trainer_data.asm) and BATTLE_SRCS.
extern TrainerDataPointers       ; flat dd pointer table, one ptr per class
extern SpecialTrainerMoves       ; Yellow per-trainer move override table

; ---------------------------------------------------------------------------
; BCD money adder (engine/math/bcd.asm). pret's `predef AddBCDPredef` is a bank-
; switch indirection around AddBCD; per the §2 item-4 allowlist (predef bank call
; dropped → flat call) we preload ESI/EDX/CL and call AddBCD directly, exactly as
; home/money.asm and move_effects/pay_day.asm do. AddBCD adds the source BCD number
; at [ESI..] into the accumulator at [EDX..], walking low→high for CL bytes.
; ---------------------------------------------------------------------------
extern AddBCD                    ; ESI=hl src LSB, EDX=de dst LSB, CL=byte count

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global ReadTrainer

section .text

; ===========================================================================
; ReadTrainer
; ---------------------------------------------------------------------------
; Reads the trainer's party blob for [wTrainerClass] / [wTrainerNo] from the
; flat TrainerDataPointers table, calls AddPartyMon for each mon, then applies
; any SpecialTrainerMoves overrides, and computes wAmountMoneyWon.
;
; Skips everything in a link battle (wLinkState != 0).
;
; Party blob format (pret data/trainers/parties.asm):
;
;   Flat-level format (first byte != $FF):
;     db level, species_1, species_2, ..., 0x00
;
;   Special-level format (first byte == $FF):
;     db $FF, level_1, species_1, level_2, species_2, ..., 0x00
;
; SpecialTrainerMoves format (data/trainers/special_moves.asm):
;   Repeated: db trainerClass, trainerNo, {db slot, moveSlot, moveId}*, db 0
;   Globally terminated by db $FF.
;
; Pret ref: engine/battle/read_trainer_party.asm:ReadTrainer
; ===========================================================================
ReadTrainer:
    ; skip in link battle
    mov al, [ebp + wLinkState]
    test al, al
    jz .notLinkBattle
    ret                         ; faithful: `ret nz` — skip if link state active
.notLinkBattle:

    ; init wEnemyPartyCount = 0, wEnemyPartySpecies = $FF
    mov byte [ebp + wEnemyPartyCount], 0
    mov byte [ebp + wEnemyPartySpecies], 0xFF

    ; look up trainer class pointer: TrainerDataPointers[(class-1) * 2 (GB) → * 4 (port dd)]
    ; Pret uses `dw` (2-byte GB pointer); port uses `dd` (4-byte flat pointer).
    movzx eax, byte [ebp + wTrainerClass]
    dec eax
    mov esi, [TrainerDataPointers + eax*4]  ; flat → ESI = start of this class's blobs

    ; advance to trainer number (wTrainerNo):
    ; skip (trainerNo - 1) null-terminated trainer entries
    movzx ebx, byte [ebp + wTrainerNo]   ; b = trainerNo

.CheckNextTrainer:
    dec ebx
    jz .IterateTrainer
.SkipTrainer:
    mov al, [esi]
    inc esi
    test al, al
    jnz .SkipTrainer
    jmp .CheckNextTrainer

; ---- parse trainer entry ----
.IterateTrainer:
    mov al, [esi]
    inc esi
    cmp al, 0xFF             ; special trainer (per-mon levels)?
    je .SpecialTrainer
    ; flat-level: store level, loop over species
    mov [ebp + wCurEnemyLevel], al
.LoopTrainerData:
    mov al, [esi]
    inc esi
    test al, al
    jz .AddAdditionalMoveData   ; 0x00 = end of party
    mov [ebp + wCurPartySpecies], al
    mov byte [ebp + wMonDataLocation], ENEMY_PARTY_DATA
    push esi
    call AddPartyMon
    pop esi
    jmp .LoopTrainerData

.SpecialTrainer:
    ; special: each mon has its own level
.SpecialTrainerLoop:
    mov al, [esi]
    inc esi
    test al, al
    jz .AddAdditionalMoveData   ; 0x00 = end of party
    mov [ebp + wCurEnemyLevel], al
    mov al, [esi]
    inc esi
    mov [ebp + wCurPartySpecies], al
    mov byte [ebp + wMonDataLocation], ENEMY_PARTY_DATA
    push esi
    call AddPartyMon
    pop esi
    jmp .SpecialTrainerLoop

; ---- apply Yellow per-trainer special move overrides ----
.AddAdditionalMoveData:
    movzx ebx, byte [ebp + wTrainerClass]  ; b = trainer class
    movzx ecx, byte [ebp + wTrainerNo]     ; c = trainer no
    mov esi, SpecialTrainerMoves

.loopAdditionalMoveData:
    mov al, [esi]            ; read class or $FF sentinel
    inc esi
    cmp al, 0xFF
    je .FinishUp             ; global end of SpecialTrainerMoves
    cmp al, bl               ; does class match?
    jnz .loopSkipSpecial
    mov al, [esi]            ; read trainer no
    inc esi
    cmp al, cl               ; does trainer no match?
    jnz .loopSkipSpecialNo

    ; match found: ESI now points at the move-override triples
    mov edx, esi             ; de = override data pointer (save as edx = flat)
.writeAdditionalMoveDataLoop:
    mov al, [edx]            ; party-mon slot (1-based) or 0 (end)
    inc edx
    test al, al
    jz .FinishUp

    ; destination: wEnemyMon1Moves + (slot-1) * PARTYMON_STRUCT_LENGTH + (moveSlot-1)
    dec al                                  ; 0-based party slot
    movzx ecx, al
    mov esi, wEnemyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH
    push edx
    call AddNTimes                          ; esi = wEnemyMon1Moves + slot*PARTYMON_STRUCT_LENGTH
    pop edx

    mov al, [edx]            ; move slot (1-based)
    inc edx
    dec al                   ; 0-based move slot
    movzx ecx, al
    add esi, ecx             ; esi = wEnemyMon1Moves + slot*PARTYMON + moveSlot

    mov al, [edx]            ; move id
    inc edx
    mov [ebp + esi], al      ; write move id into party roster
    jmp .writeAdditionalMoveDataLoop

.loopSkipSpecial:
    ; trainer no byte follows class byte → skip it
    inc esi
.loopSkipSpecialNo:
    ; skip the override triples for this non-matching trainer: find 0x00
.loopSkipSpecialTriples:
    mov al, [esi]
    inc esi
    test al, al
    jnz .loopSkipSpecialTriples
    jmp .loopAdditionalMoveData

; ---- compute prize money ----
.FinishUp:
    ; zero wAmountMoneyWon (3 bytes BCD)
    xor al, al
    mov [ebp + wAmountMoneyWon + 0], al
    mov [ebp + wAmountMoneyWon + 1], al
    mov [ebp + wAmountMoneyWon + 2], al

    ; wAmountMoneyWon += wTrainerBaseMoney, repeated wCurEnemyLevel times.
    ; pret read_trainer_party.asm .LastLoop: hl=wTrainerBaseMoney+1, c=2,
    ; predef AddBCDPredef, looped wCurEnemyLevel (b) times. AddBCD clobbers CL/CH,
    ; so preserve the loop count across the call (pret push bc / pop bc).
    movzx ecx, byte [ebp + wCurEnemyLevel]   ; loop count (enemy level)
    test cl, cl
    jz .FinishUp_done
.lastLoop:
    push ecx
    mov esi, wTrainerBaseMoney + 1           ; hl: source LSB (2-byte BCD base money)
    mov edx, wAmountMoneyWon + 2             ; de: dest LSB (3-byte BCD accumulator)
    mov cl, 2                                ; c: 2 source bytes into the 3-byte total
    call AddBCD
    pop ecx
    dec ecx
    jnz .lastLoop
.FinishUp_done:
    ret
