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

; This file used to carry its own %ifndef copies of wSpriteIndex, hSpriteIndex,
; POKEMON_TOWER_7F and OPP_RIVAL1/2/3 under a "TODO(root): promote to gb_memmap.inc"
; banner. That promotion happened 2026-07-27, so the copies are gone and the
; canonical headers below are the only definition of each:
;   wSpriteIndex / hSpriteIndex  -> gb_memmap.inc (hSpriteIndex is the hTextID slot)
;   OPP_RIVAL1/2/3               -> gb_constants.inc, as OPP_ID_OFFSET + $19/$2A/$2B
;   POKEMON_TOWER_7F             -> assets/map_dims.inc (generated; the two-tier source)

%include "gb_memmap.inc"
%include "gb_constants.inc"           ; OPP_RIVAL1/2/3
%include "assets/map_dims.inc"        ; POKEMON_TOWER_7F

global SetEnemyTrainerToStayAndFaceAnyDirection
extern SetSpriteMovementBytesToFF ; src/home/map_objects.asm

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
