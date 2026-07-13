; link_cups.asm — CUP-VALIDATION half of pret engine/menus/link_menu.asm
; (lines ~197-511): PokeCup / PikaCup / PetitCup + every result routine.
; Menus swarm Session 8, package I2. Pure logic — no serial, no rendering,
; fully real GB behaviour (the party-shape/level/dex gates a Cable Club
; Colosseum battle checks before it will let you register a team).
;
; SEAM (I1 <-> I2): engine/menus/link_menu.asm (dispatch, PointerTable_f5488,
; the rest of the link menu UI) is a separate worker/worktree (I1). This file
; assembles + `make check`s standalone:
;   - global PokeCup / PikaCup / PetitCup — I1's PointerTable_f5488 points at
;     these three.
;   - extern the Colosseum*Text message labels — I1 owns those (defined in
;     engine/menus/link_menu.asm as text_far wrappers in pret; the port will
;     give each a flat, TX_END($50)-terminated byte stream, mirroring the
;     DoYouWantToNicknameText convention in naming_screen.asm). This file only
;     needs the *start* address of each stream (see PrintCupText below) — no
;     `_end` label dependency.
;   - Func_3b10f (engine/pokemon/evos_moves.asm — "is this species someone's
;     evolved form?") is not yet ported (pokemon_behavior plan). Stubbed to
;     the "basic" path (see PetitCup) — see the DEVIATION comment there.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX, HL=ESI, EBP=GB
; base. GB memory (party struct, wCurPartySpecies, wNamedObjectIndex,
; wNameBuffer) via [ebp+addr]; PokedexEntryPointers/dex-entry data live in
; flat program-image .data (dos_port/assets/dex_entries.inc) — read directly
; via [addr]/[esi], no EBP bias.
;
; FLAGS ARE NOT THE GB'S: every `cp NN / jr nc / jr c / jr z` below is ported
; onto the x86 flag set by the *same* logical op pret used (cmp -> jc/jnc/jz
; map 1:1 onto GB cp's C/Z since both are unsigned-subtract flag semantics).
; The two-byte weight compare (sub $b9 / sbc $1) is a real 16-bit borrow chain
; — ported as sub/mov/sbb with the `mov` (no EFLAGS side effect, same as GB
; LD) sitting between them so CF survives untouched, exactly as on hardware.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/link_cups.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- I1 (engine/menus/link_menu.asm) ---
extern Colosseum3MonsText
extern ColosseumMewText
extern ColosseumDifferentMonsText
extern ColosseumMaxL55Text
extern ColosseumMinL50Text
extern ColosseumTotalL155Text
extern ColosseumMaxL30Text
extern ColosseumMinL25Text
extern ColosseumTotalL80Text
extern ColosseumMaxL20Text
extern ColosseumMinL15Text
extern ColosseumTotalL50Text
extern ColosseumHeightText
extern ColosseumWeightText
extern ColosseumEvolvedText

; --- already-linked port routines ---
extern GetMonName                      ; home/names.asm — in: wNamedObjectIndex -> wNameBuffer
extern PrintTextStaged              ; text/text.asm — in: ESI = GB-space TX stream ptr

; PokedexEntryPointers — assets/dex_entries.inc (DO NOT %include the data file
; here: it is the shared contract with the G2 worker's pokedex_entry.asm,
; which owns the %include/embed; duplicate-including it would double-define
; every DexEntry label at link time). `dd` flat 32-bit .data pointers, index
; = internal_species_index - 1 (dex_entries.inc header).
extern PokedexEntryPointers

; --- local constants (not yet centralized in gb_constants.inc; harmless to
; redefine locally, no linker symbol involved) ---
MEW     equ 0x15                        ; constants/pokemon_constants.asm (=21)
TX_END  equ 0x50                        ; text/text.asm TX_END ('@' string terminator)

; wPartyMon2Level/3Level: gb_memmap.inc only pins wPartyMon1Level (lead-mon
; sym anchor); the other two party slots are +N*PARTYMON_STRUCT_LENGTH from
; it, same as wPartyMon{d:n} in pret's ram/wram.asm. Local equ, not touching
; gb_memmap.inc — root may want to promote these if another package needs them.
wPartyMon2Level equ wPartyMon1Level + PARTYMON_STRUCT_LENGTH
wPartyMon3Level equ wPartyMon2Level + PARTYMON_STRUCT_LENGTH

section .text

; SEAM (I1↔I2): each Colosseum*Text is an I1-owned drawn-whole PRINT ROUTINE
; (`call X` prints its message + rets), matching pret's `ld hl,X / call PrintText`
; → port `call X`. The result routines below `call` them directly then set AL,
; exactly as pret does. (An earlier I2 build assumed they were flat data streams
; printed via a local PrintCupText helper; that was reconciled onto I1's routine
; contract at integration.)

; ===========================================================================
; PokeCup — pret ref: engine/menus/link_menu.asm:PokeCup.
; Team-shape (3 mons, no MEW, no duplicate species) + level gate 50-55 each,
; combined <=155. a=0 on a valid team; else the fail routine's error code.
; ===========================================================================
global PokeCup
PokeCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi                             ; esi -> wPartySpecies (mon1)
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi                             ; esi -> mon2 address
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi                             ; esi -> mon1 address (wPartySpecies)
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies

    mov al, [ebp + wPartyMon1Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 56
    jnc LevelAbove55
    cmp al, 50
    jc LevelUnder50
    add al, bh
    add al, bl
    cmp al, 156
    jnc CombinedLevelsGreaterThan155
    xor al, al
    ret

; ===========================================================================
; PikaCup — pret ref: engine/menus/link_menu.asm:PikaCup.
; Same team-shape gate; level gate 15-20 each, combined <=50.
; ===========================================================================
global PikaCup
PikaCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies

    mov al, [ebp + wPartyMon1Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 21
    jnc LevelAbove20
    cmp al, 15
    jc LevelUnder15
    add al, bh
    add al, bl
    cmp al, 51
    jnc CombinedLevelsAbove50
    xor al, al
    ret

; ===========================================================================
; PetitCup — pret ref: engine/menus/link_menu.asm:PetitCup.
; Same team-shape gate; per-mon evolution-stage check (Func_3b10f — stubbed,
; see below); per-mon dex-entry height (<6'8") + weight (<=44lb) check;
; level gate 25-30 each, combined <=80.
; ===========================================================================
global PetitCup
PetitCup:
    mov esi, wPartyCount
    mov al, [ebp + esi]
    inc esi
    cmp al, 3
    jnz NotThreeMonsInParty
    mov bh, 3
.loop:
    mov al, [ebp + esi]                 ; wPartySpecies
    inc esi
    cmp al, MEW
    jz MewInParty
    dec bh
    jnz .loop
    dec esi
    dec esi
    cmp al, [ebp + esi]                 ; is third mon second mon?
    jz DuplicateSpecies
    dec esi
    cmp al, [ebp + esi]                 ; is third mon first mon?
    jz DuplicateSpecies
    mov al, [ebp + esi]
    inc esi
    cmp al, [ebp + esi]                 ; is first mon second mon?
    jz DuplicateSpecies                 ; esi -> mon2 address here

    ; --- per-mon evolution-stage check (x3) ---
    ; pret: `ld a,[hl] / ld [wCurPartySpecies],a / push hl / callfar Func_3b10f
    ; / pop hl / jp c, asm_f56ad` for mon1, mon2, mon3 in turn.
    ; DEVIATION: Func_3b10f (engine/pokemon/evos_moves.asm — "does some species
    ; evolve into wCurPartySpecies") is not yet ported (pokemon_behavior plan).
    ; Stubbed to the "basic form" result (CF clear -> jc NOT taken) for every
    ; mon. TODO once ported: extern Func_3b10f, preserve esi across the call
    ; (pret wraps it in push/pop hl since callfar clobbers registers), replace
    ; each `clc` stub below with `mov [ebp+wCurPartySpecies], al` / real call.
    dec esi                             ; esi -> mon1 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; DEVIATION: Func_3b10f stub (basic path)
    jc asm_f56ad
    inc esi                             ; esi -> mon2 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; DEVIATION: Func_3b10f stub (basic path)
    jc asm_f56ad
    inc esi                             ; esi -> mon3 address
    mov al, [ebp + esi]
    mov [ebp + wCurPartySpecies], al
    clc                                 ; DEVIATION: Func_3b10f stub (basic path)
    jc asm_f56ad
    dec esi
    dec esi                             ; esi -> mon1 address (wPartySpecies)

    ; --- per-mon dex-entry height/weight check (x3) ---
    mov bh, 3
.bigloop:
    mov al, [ebp + esi]                 ; wPartySpecies[i]
    inc esi
    push esi
    push ebx
    push eax
    ; DEVIATION: FarCopyData bank read -> flat read. pret does two FarCopyData
    ; calls (fetch the far pointer, then 20 bytes of the entry) because
    ; PokedexEntryPointers is bank-switched `dw` data on hardware; the port's
    ; PokedexEntryPointers is already a flat `dd` pointer (dex_entries.inc
    ; contract), so one direct load replaces both banked copies.
    movzx ecx, al
    dec ecx                             ; pret: dec a; ld c,a (species-1 index)
    mov esi, [PokedexEntryPointers + ecx*4]   ; flat dex-entry ptr (pret: hl = table+bc*2, FarCopyData)
.scanAt:
    mov al, [esi]
    inc esi
    cmp al, TX_END                      ; '@' name terminator
    jne .scanAt
    mov al, [esi]                       ; feet
    inc esi
    cmp al, 7
    jnc asm_f5689
    add al, al                          ; a = 2*feet
    add al, al                          ; a = 4*feet
    mov bh, al                          ; b = 4*feet
    add al, al                          ; a = 8*feet
    add al, bh                          ; a = 8*feet + 4*feet = 12*feet
    mov bh, al                          ; b = 12*feet
    mov al, [esi]                       ; inches
    inc esi
    add al, bh                          ; a = inches + 12*feet (total inches)
    cmp al, 0x51                        ; 81 = 6'8" + 1"
    jnc asm_f5689
    mov al, [esi]                       ; weight low byte
    inc esi
    sub al, 0xb9
    mov al, [esi]                       ; weight high byte (esi NOT advanced — mirrors pret `ld a,[hl]`)
    sbb al, 1                           ; 16-bit borrow chain: weight - 0x1b9 (441 tenths = 44.1 lb)
    jnc asm_f569b
    pop eax
    pop ebx
    pop esi
    dec bh
    jnz .bigloop

    mov al, [ebp + wPartyMon1Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    mov bh, al
    mov al, [ebp + wPartyMon2Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    mov bl, al
    mov al, [ebp + wPartyMon3Level]
    cmp al, 31
    jnc LevelAbove30
    cmp al, 25
    jc LevelUnder25
    add al, bh
    add al, bl
    cmp al, 81
    jnc CombinedLevelsAbove80
    xor al, al
    ret

; ===========================================================================
; Result routines — pret ref: engine/menus/link_menu.asm:410-511. Shared
; `jp z`/`jp nc`/`jp c` targets reached from all three cups (and, for
; asm_f5689/asm_f569b/asm_f56ad, only from PetitCup). Each prints its
; Colosseum*Text and returns its fixed error code in AL; not `global` — only
; reached via internal jumps within this file (PointerTable_f5488 in I1's
; link_menu.asm only needs PokeCup/PikaCup/PetitCup).
; ===========================================================================
NotThreeMonsInParty:
    call Colosseum3MonsText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x1
    ret

MewInParty:
    call ColosseumMewText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x2
    ret

DuplicateSpecies:
    call ColosseumDifferentMonsText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x3
    ret

LevelAbove55:
    call ColosseumMaxL55Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x4
    ret

LevelUnder50:
    call ColosseumMinL50Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x5
    ret

CombinedLevelsGreaterThan155:
    call ColosseumTotalL155Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x6
    ret

LevelAbove30:
    call ColosseumMaxL30Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x7
    ret

LevelUnder25:
    call ColosseumMinL25Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x8
    ret

CombinedLevelsAbove80:
    call ColosseumTotalL80Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0x9
    ret

LevelAbove20:
    call ColosseumMaxL20Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xa
    ret

LevelUnder15:
    call ColosseumMinL15Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xb
    ret

CombinedLevelsAbove50:
    call ColosseumTotalL50Text                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xc
    ret

; asm_f5689 — pret ref: engine/menus/link_menu.asm:asm_f5689. Height-over-limit
; fail. Reached via `jnc asm_f5689` from PetitCup's .bigloop with (esi, ebx,
; eax) still pushed (pret: `pop af / pop bc / pop hl` happen HERE, not before
; the jump — mirrored exactly: PetitCup does not pop before jumping in).
asm_f5689:
    pop eax
    pop ebx
    pop esi
    mov [ebp + wNamedObjectIndex], al   ; al = species internal index (pret: a from popped af)
    call GetMonName
    call ColosseumHeightText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xd
    ret

; asm_f569b — pret ref: engine/menus/link_menu.asm:asm_f569b. Weight-over-limit
; fail. Same stack-popping contract as asm_f5689.
asm_f569b:
    pop eax
    pop ebx
    pop esi
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    call ColosseumWeightText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xe
    ret

; asm_f56ad — pret ref: engine/menus/link_menu.asm:asm_f56ad. Evolved-mon fail
; (Func_3b10f's `jp c`). Currently unreachable while Func_3b10f is stubbed to
; the basic-form path (see PetitCup) — kept live so the seam is a one-line
; flip (`clc` -> real call) once Func_3b10f lands. pret: `ld a,[hl]` — esi
; still points at the current mon's species byte at the jc site.
asm_f56ad:
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    call ColosseumEvolvedText                 ; I1 drawn-whole print routine (sets AL after)
    mov al, 0xf
    ret

; ===========================================================================
; RunLinkCupsTest — DEBUG_I2 harness. Seeds a 3-mon party and exercises:
;   1. PokeCup on a passing team (levels 53/52/50, sum 155 -- both boundary
;      values) -> expect al=0.
;   2. PokeCup on the same team with mon1's level pushed to 60 -> expect
;      al=4 (LevelAbove55), the "cp 56 / jnc" gate.
;   3. PetitCup on a passing team of small real Pokemon (Diglett 0'8"/2lb,
;      Nidoran-F 1'4"/15lb, Pikachu 1'4"/13lb) at levels 28/27/25 (sum 80,
;      boundary) -> expect al=0. This is the one that actually walks the
;      real PokedexEntryPointers data end-to-end.
;   4. PetitCup with the third slot replaced by Rhydon (6'3", 265 lb, real
;      dex data) at the same valid levels -> expect al=14 (asm_f569b, the
;      two-byte weight-compare fail: 2650 tenths >> 441-tenth/44.1lb cutoff).
; Results land in `link_cups_test_results` (this file's own flat .bss, NOT
; GB WRAM -- avoids claiming any WRAM scratch address). No rendering; this
; package has no UI. `make DEBUG_I2=1` (root wires the flag + call site).
; ===========================================================================
%ifdef DEBUG_I2
global RunLinkCupsTest

SPECIES_RHYDON      equ 0x01
SPECIES_KANGASKHAN  equ 0x02
SPECIES_NIDORAN_M   equ 0x03
SPECIES_NIDORAN_F   equ 0x0f
SPECIES_DIGLETT     equ 0x3b
SPECIES_PIKACHU     equ 0x54

section .bss
align 4
link_cups_test_results: resb 4         ; [0]=PokeCup pass [1]=PokeCup fail
                                        ; [2]=PetitCup pass [3]=PetitCup fail

section .text
RunLinkCupsTest:
    ; --- scenario 1: PokeCup, valid team ---
    mov byte [ebp + wPartyCount], 3
    mov byte [ebp + wPartySpecies + 0], SPECIES_RHYDON
    mov byte [ebp + wPartySpecies + 1], SPECIES_KANGASKHAN
    mov byte [ebp + wPartySpecies + 2], SPECIES_NIDORAN_M
    mov byte [ebp + wPartyMon1Level], 53
    mov byte [ebp + wPartyMon2Level], 52
    mov byte [ebp + wPartyMon3Level], 50
    call PokeCup
    mov [link_cups_test_results + 0], al

    ; --- scenario 2: PokeCup, mon1 level pushed above the L55 ceiling ---
    mov byte [ebp + wPartyMon1Level], 60
    call PokeCup
    mov [link_cups_test_results + 1], al

    ; --- scenario 3: PetitCup, valid team of small real Pokemon ---
    mov byte [ebp + wPartySpecies + 0], SPECIES_DIGLETT
    mov byte [ebp + wPartySpecies + 1], SPECIES_NIDORAN_F
    mov byte [ebp + wPartySpecies + 2], SPECIES_PIKACHU
    mov byte [ebp + wPartyMon1Level], 28
    mov byte [ebp + wPartyMon2Level], 27
    mov byte [ebp + wPartyMon3Level], 25
    call PetitCup
    mov [link_cups_test_results + 2], al

    ; --- scenario 4: PetitCup, mon3 = Rhydon (real dex weight 265lb >> 44lb) ---
    mov byte [ebp + wPartySpecies + 2], SPECIES_RHYDON
    call PetitCup
    mov [link_cups_test_results + 3], al

.hang:
    jmp .hang
%endif
