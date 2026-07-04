; npc_movement_2.asm — OW-1.6 (pure-logic leaf, CHECK-ONLY).
;
; Intended repo path: dos_port/src/engine/overworld/npc_movement_2.asm
;
; Translated from pret/pokeyellow:
;   engine/overworld/npc_movement_2.asm : SetEnemyTrainerToStayAndFaceAnyDirection,
;                                          RivalIDs
;
; After a trainer battle the engine normally freezes the loser's sprite facing
; the player forever (STAY + FF movement bytes). This routine is the exception
; list: on POKEMON_TOWER_7F the Rocket the player just fought walks away
; (leaves the map), so its sprite must NOT be frozen — bail out with no change.
; Likewise the rival (trainer class RIVAL1/2/3, checked via wEngagedTrainerClass
; against the inlined RivalIDs table) leaves after his battles, so he is also
; excluded. Every other defeated trainer falls through to .notRival and gets
; frozen via the (currently check-only) SetSpriteMovementBytesToFF.
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH (BC->BX per project convention),
; RAM is EBP-relative (see CLAUDE.md / asm-translation skill). RivalIDs is a small
; FLAT host data table (not GB memory), so ESI walks it directly without the EBP
; bias — same convention pathfinding.asm uses for its flat movement-byte pointer.
;
; Build (check-only): nasm -f coff -I include/ -I . -o npc_movement_2.o \
;                           src/engine/overworld/npc_movement_2.asm
; ---------------------------------------------------------------------------

; ---- TODO(root): promote to gb_memmap.inc ----------------------------------
; wCurMap and wEngagedTrainerClass already exist in gb_memmap.inc — reused as-is.
;
; wSpriteIndex / hSpriteIndex: not yet in gb_memmap.inc. Values below match the
; existing %ifndef-guarded copies already carried in m1_3_pending_symbols.inc /
; m8_2_pending_symbols.inc (both agree), so this file's copy is consistent with
; those pending root-integrations rather than introducing a third address.
%ifndef wSpriteIndex
wSpriteIndex            equ 0xCF13   ; pret ram/wram.asm:1198 (db)
%endif
%ifndef hSpriteIndex
hSpriteIndex            equ 0xFF8C   ; pret ram/hram.asm:65 (db) — ASSERT == hTextID slot
%endif

; POKEMON_TOWER_7F: map id constant (constants/map_constants.asm:234, "; $94"
; comment in the pret source — confirmed sequential against the surrounding
; POKEMON_TOWER_2F..6F entries, $8F..$93).
%ifndef POKEMON_TOWER_7F
POKEMON_TOWER_7F         equ 0x94
%endif

; OPP_RIVAL1/2/3: trainer_const RIVAL1/2/3 (constants/trainer_constants.asm:42,
; 59, 60 -> class ids $19/$2A/$2B) run through `trainer_const`'s
; `OPP_\1 EQU OPP_ID_OFFSET + \1` (OPP_ID_OFFSET = 200, line 1):
;   OPP_RIVAL1 = 200 + 0x19 (25) = 225 = 0xE1
;   OPP_RIVAL2 = 200 + 0x2A (42) = 242 = 0xF2
;   OPP_RIVAL3 = 200 + 0x2B (43) = 243 = 0xF3
%ifndef OPP_RIVAL1
OPP_RIVAL1               equ 0xE1
%endif
%ifndef OPP_RIVAL2
OPP_RIVAL2               equ 0xF2
%endif
%ifndef OPP_RIVAL3
OPP_RIVAL3               equ 0xF3
%endif
; ---------------------------------------------------------------------------

%include "gb_memmap.inc"

global SetEnemyTrainerToStayAndFaceAnyDirection
extern SetSpriteMovementBytesToFF ; src/engine/overworld/pathfinding.asm (check-only)

section .data

; RivalIDs — pret: engine/overworld/npc_movement_2.asm:RivalIDs
; $ff-terminated list of OPP_RIVAL* class ids checked against wEngagedTrainerClass.
RivalIDs:
    db OPP_RIVAL1
    db OPP_RIVAL2
    db OPP_RIVAL3
    db 0xFF ; end

section .text

; ---------------------------------------------------------------------------
; SetEnemyTrainerToStayAndFaceAnyDirection — freeze the just-defeated trainer's
; sprite (STAY facing the player), UNLESS it's the Pokemon Tower 7F Rocket or
; the rival (both walk away after their battle, so must not be frozen).
;
; pret: engine/overworld/npc_movement_2.asm:SetEnemyTrainerToStayAndFaceAnyDirection
; In:   wCurMap, wEngagedTrainerClass, wSpriteIndex (GB memory, EBP-relative)
; Out:  hSpriteIndex set + tail-jumps into SetSpriteMovementBytesToFF, UNLESS
;       the map/rival exception fires (plain return, no change).
; Clobbers: AL, BH, ESI, flags
; ---------------------------------------------------------------------------
SetEnemyTrainerToStayAndFaceAnyDirection:
    mov al, [ebp + wCurMap]
    cmp al, POKEMON_TOWER_7F                  ; cp POKEMON_TOWER_7F
    jz .ret                                   ; ret z (Rockets on 7F leave after battling)

    mov esi, RivalIDs                         ; ld hl, RivalIDs (flat host pointer)
    mov al, [ebp + wEngagedTrainerClass]
    mov bh, al                                ; ld b, a  (B -> BH per register map)
.loop:
    mov al, [esi]                             ; ld a, [hli]  (load ...
    inc esi                                   ;               ... + advance ptr)
    cmp al, 0xFF                              ; cp -1
    jz .notRival                              ; jr z, .notRival
    cmp al, bh                                ; cp b
    jz .ret                                   ; ret z (the rival leaves after battling)
    jmp .loop                                 ; jr .loop

.notRival:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al              ; ldh [hSpriteIndex], a
    jmp SetSpriteMovementBytesToFF            ; jp SetSpriteMovementBytesToFF (tail jump)

.ret:
    ret
