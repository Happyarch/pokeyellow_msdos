; special_warps.asm — fly / dungeon / cable-club / new-game special warp prep
; (OW-5.2).
;
; Intended repo path: dos_port/src/engine/overworld/special_warps.asm
; pret source: engine/overworld/special_warps.asm
;
; PrepareForSpecialWarp selects the destination map for a fly/dungeon/escape or
; new-game(-debug) warp and records it in wLastMap. It is pure flag/map-selection
; logic with no pointer-walk, so it ports cleanly here.
;
; LoadSpecialWarpData (UNBLOCKED 2026-07-10) copies a precomputed
; (view-pointer, Y, X, sub-block) struct out of the warp tables (NewGameWarp /
; TradeCenter*/Colosseum* / DungeonWarpData / FlyWarpData) into
; wCurrentTileBlockMapViewPointer&co. The former blocker — `event_displacement`
; carried pret's border-3 stride and a `dd` emission — is resolved: the macro
; (include/coords.inc) is re-derived against the port's own runtime
; view-pointer formula (overworld.asm:LoadWarpDestination) as a pure function
; of MAP_BORDER / SCREEN_BLOCK_*, emitting the 2-byte GB-space pointer the
; field actually holds. So the fly_warp payload keeps pret's exact 6-byte
; entry layout, and wDungeonWarpDataEntrySize=6 plus both copy loops port
; verbatim. The one structural divergence is pointer width: the FlyWarpDataPtr
; table stores flat 32-bit .data addresses (`dd`, pret: 2-byte ROM `dw`), so
; the walk skips 4 pointer bytes (pret: 2) and the match loads the pointer
; with one 32-bit read in place of pret's `ld a,[hli] / ld h,[hl] / ld l,a`
; (see the PROJ note in src/data/maps/special_warps.asm).
;
; In this routine HL→ESI holds FLAT .data table addresses (the tables live in
; the EXE image, not GB space); destination writes go through [ebp + wXxx] as
; usual. Map ids / <MAP>_WIDTH / tileset ids come from the generated
; assets/map_dims.inc (Tier-1 — pret constants, never hand-encoded).
;
; Retires the PrepareForSpecialWarp ret-stub in main_menu_stubs.asm (dup_def
; suppressed: stub stays LINKED for its caller until OW-7.2 promotion, same
; pattern as SpawnPikachu/EnterMapAnim).
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, HL->ESI. GB memory is
; [ebp+offset]. bit/res-then-branch preserves the tested ZF via a saved copy
; (x86 `and [mem]` sets flags) or a direct `test [mem],imm`.
;
; Check-only (HOME_CHECK_SRCS).
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/special_warps.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "coords.inc"              ; event_displacement (re-derived) for the data tables
%include "assets/map_dims.inc"     ; map ids, <MAP>_WIDTH, tileset ids (generated)

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef wStatusFlags6
wStatusFlags6      equ 0xD731 ; golden 00:d731
%endif
%ifndef wStatusFlags3
wStatusFlags3      equ 0xD72C ; golden 00:d72c (unions wCableClubDestinationMap)
%endif
%ifndef wDestinationMap
wDestinationMap    equ 0xD719 ; golden 00:d719
%endif
%ifndef wLastMap
wLastMap           equ 0xD364 ; golden 00:d364
%endif
%ifndef wLastBlackoutMap
wLastBlackoutMap   equ 0xD718 ; golden 00:d718
%endif
%ifndef wDungeonWarpDestinationMap
wDungeonWarpDestinationMap equ 0xD71C ; golden 00:d71c
%endif
%ifndef wDungeonWarpDataEntrySize
wDungeonWarpDataEntrySize  equ 0xD12E ; golden 00:d12e (unions wWhichPewterGuy)
%endif

; --- constants ---
; (PALLET_TOWN and the other map ids come from assets/map_dims.inc)
%ifndef BIT_FLY_OR_DUNGEON_WARP
BIT_FLY_OR_DUNGEON_WARP   equ 2   ; wStatusFlags6 bit 2
%endif
%ifndef BIT_DEBUG_MODE
BIT_DEBUG_MODE            equ 1   ; wStatusFlags6 bit 1
%endif
%ifndef BIT_DUNGEON_WARP
BIT_DUNGEON_WARP          equ 4   ; wStatusFlags6 bit 4
%endif
%ifndef BIT_ESCAPE_WARP
BIT_ESCAPE_WARP           equ 6   ; wStatusFlags6 bit 6
%endif
%ifndef BIT_ON_DUNGEON_WARP
BIT_ON_DUNGEON_WARP       equ 4   ; wStatusFlags3 bit 4
%endif
%ifndef USING_INTERNAL_CLOCK
USING_INTERNAL_CLOCK      equ 0x02 ; constants/serial_constants.asm
%endif

global PrepareForSpecialWarp
global LoadSpecialWarpData

extern LoadTilesetHeader           ; engine/overworld/overworld.asm (pret: predef)
extern PrepareNewGameDebug         ; engine/debug/debug_party.asm

section .text

; ---------------------------------------------------------------------------
; PrepareForSpecialWarp — pret engine/overworld/special_warps.asm:PrepareForSpecialWarp
; ---------------------------------------------------------------------------
PrepareForSpecialWarp:
    call LoadSpecialWarpData
    call LoadTilesetHeader                     ; pret: predef (banking/predef-regs elided)
    ; bit BIT_FLY_OR_DUNGEON_WARP,[wStatusFlags6] / res it / jr z — preserve the
    ; bit's ZF across the res via a saved copy (x86 `and [mem]` sets flags).
    mov al, [ebp + wStatusFlags6]
    mov ah, al                                 ; saved copy for the test
    and byte [ebp + wStatusFlags6], ~(1 << BIT_FLY_OR_DUNGEON_WARP) & 0xFF ; res
    test ah, 1 << BIT_FLY_OR_DUNGEON_WARP
    jz .debugNewGameWarp
    mov al, [ebp + wDestinationMap]
    jmp .next
.debugNewGameWarp:
    test byte [ebp + wStatusFlags6], 1 << BIT_DEBUG_MODE ; bit BIT_DEBUG_MODE,[hl]
    jz .setNewGameMatWarp                      ; apply to StartNewGameDebug only
    call PrepareNewGameDebug
.setNewGameMatWarp:
    ; called by OakSpeech during StartNewGame — first warp of the map index.
    mov al, PALLET_TOWN
.next:
    mov bh, al                                 ; ld b, a
    mov al, [ebp + wStatusFlags3]
    and al, al                                 ; and a ; ???
    jnz .next2
    mov al, bh                                 ; ld a, b
.next2:
    test byte [ebp + wStatusFlags6], 1 << BIT_DUNGEON_WARP ; bit BIT_DUNGEON_WARP,[hl]
    jnz .ret                                    ; ret nz
    mov [ebp + wLastMap], al
.ret:
    ret

; ---------------------------------------------------------------------------
; LoadSpecialWarpData — pret engine/overworld/special_warps.asm:LoadSpecialWarpData
; Selects the warp-data entry for the pending special warp (cable club /
; new game / dungeon warp / escape rope / fly) and copies it into
; wCurMap / wCurrentTileBlockMapViewPointer / wYCoord..wXBlockCoord — the
; port memmap keeps pret's WRAM layout (0xD35D..0xD363 contiguous), so both
; copy loops are verbatim. ESI (HL) walks flat .data tables; the only
; structural divergence is the FlyWarpDataPtr 32-bit pointer width (header).
; No register outputs (all effects in memory); preserves all registers.
; ---------------------------------------------------------------------------
LoadSpecialWarpData:
    push eax
    push ebx
    push edx
    push esi
    push edi

    mov al, [ebp + wCableClubDestinationMap]   ; ld a,[wCableClubDestinationMap]
    cmp al, TRADE_CENTER                       ; cp TRADE_CENTER
    jnz .notTradeCenter
    mov esi, TradeCenterPlayerWarp             ; ld hl,TradeCenterPlayerWarp
    mov al, [ebp + H_SERIAL_CONN_STATUS]       ; ldh a,[hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK               ; cp USING_INTERNAL_CLOCK
    jz .copyWarpData
    mov esi, TradeCenterFriendWarp             ; ld hl,TradeCenterFriendWarp
    jmp .copyWarpData
.notTradeCenter:
    cmp al, COLOSSEUM                          ; cp COLOSSEUM
    jnz .notColosseum
    mov esi, ColosseumPlayerWarp               ; ld hl,ColosseumPlayerWarp
    mov al, [ebp + H_SERIAL_CONN_STATUS]       ; ldh a,[hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK               ; cp USING_INTERNAL_CLOCK
    jz .copyWarpData
    mov esi, ColosseumFriendWarp               ; ld hl,ColosseumFriendWarp
    jmp .copyWarpData
.notColosseum:
    mov al, [ebp + wStatusFlags6]              ; ld a,[wStatusFlags6]
    ; warp to wLastMap (PALLET_TOWN) for StartNewGameDebug
    test al, 1 << BIT_DEBUG_MODE               ; bit BIT_DEBUG_MODE,a
    jnz .notNewGameWarp
    test al, 1 << BIT_FLY_OR_DUNGEON_WARP      ; bit BIT_FLY_OR_DUNGEON_WARP,a
    jnz .notNewGameWarp
    mov esi, NewGameWarp                       ; ld hl,NewGameWarp
.copyWarpData:
    lea edi, [ebp + wCurMap]                   ; ld de,wCurMap
    mov bl, 7                                  ; ld c,$7
.copyWarpDataLoop:
    mov al, [esi]                              ; ld a,[hli]
    inc esi
    mov [edi], al                              ; ld [de],a
    inc edi                                    ; inc de
    dec bl                                     ; dec c
    jnz .copyWarpDataLoop
    mov al, [esi]                              ; ld a,[hli] (8th byte: tileset)
    inc esi
    mov [ebp + wCurMapTileset], al             ; ld [wCurMapTileset],a
    xor al, al                                 ; xor a
    jmp .done                                  ; jr .done
.notNewGameWarp:
    mov al, [ebp + wLastMap]                   ; ld a,[wLastMap] ; overwritten before it's ever read
    ; ld hl,wStatusFlags6 / bit BIT_DUNGEON_WARP,[hl]
    test byte [ebp + wStatusFlags6], 1 << BIT_DUNGEON_WARP
    jnz .usedDungeonWarp
    ; bit BIT_ESCAPE_WARP,[hl] / res BIT_ESCAPE_WARP,[hl] / jr z — preserve the
    ; tested ZF across the res via a saved copy (x86 `and [mem]` sets flags).
    mov ah, [ebp + wStatusFlags6]
    and byte [ebp + wStatusFlags6], ~(1 << BIT_ESCAPE_WARP) & 0xFF ; res
    test ah, 1 << BIT_ESCAPE_WARP
    jz .otherDestination
    mov al, [ebp + wLastBlackoutMap]           ; ld a,[wLastBlackoutMap]
    jmp .usedFlyWarp
.usedDungeonWarp:
    ; ld hl,wStatusFlags3 / res BIT_ON_DUNGEON_WARP,[hl]
    and byte [ebp + wStatusFlags3], ~(1 << BIT_ON_DUNGEON_WARP) & 0xFF
    mov al, [ebp + wDungeonWarpDestinationMap] ; ld a,[wDungeonWarpDestinationMap]
    mov bh, al                                 ; ld b,a
    mov [ebp + wCurMap], al                    ; ld [wCurMap],a
    mov al, [ebp + wWhichDungeonWarp]          ; ld a,[wWhichDungeonWarp]
    mov bl, al                                 ; ld c,a
    mov esi, DungeonWarpList                   ; ld hl,DungeonWarpList
    xor edx, edx                               ; ld de,0
    mov al, 6                                  ; ld a,6
    mov [ebp + wDungeonWarpDataEntrySize], al  ; ld [wDungeonWarpDataEntrySize],a
.dungeonWarpListLoop:
    mov al, [esi]                              ; ld a,[hli]
    inc esi
    cmp al, bh                                 ; cp b
    jz .matchedDungeonWarpDestinationMap
    inc esi                                    ; inc hl
    jmp .nextDungeonWarp
.matchedDungeonWarpDestinationMap:
    mov al, [esi]                              ; ld a,[hli]
    inc esi
    cmp al, bl                                 ; cp c
    jz .matchedDungeonWarpID
.nextDungeonWarp:
    mov al, [ebp + wDungeonWarpDataEntrySize]  ; ld a,[wDungeonWarpDataEntrySize]
    add al, dl                                 ; add e
    mov dl, al                                 ; ld e,a
    jmp .dungeonWarpListLoop
.matchedDungeonWarpID:
    mov esi, DungeonWarpData                   ; ld hl,DungeonWarpData
    add esi, edx                               ; add hl,de
    jmp .copyWarpData2
.otherDestination:
    mov al, [ebp + wDestinationMap]            ; ld a,[wDestinationMap]
.usedFlyWarp:
    mov bh, al                                 ; ld b,a
    mov [ebp + wCurMap], al                    ; ld [wCurMap],a
    mov esi, FlyWarpDataPtr                    ; ld hl,FlyWarpDataPtr
.flyWarpDataPtrLoop:
    mov al, [esi]                              ; ld a,[hli]
    add esi, 2                                 ; (+ pret's `inc hl` pad-byte skip)
    cmp al, bh                                 ; cp b
    jz .foundFlyWarpMatch
    add esi, 4                                 ; pret: inc hl / inc hl (2-byte dw ptr) — flat dd is 4
    jmp .flyWarpDataPtrLoop
.foundFlyWarpMatch:
    mov esi, [esi]                             ; pret: ld a,[hli] / ld h,[hl] / ld l,a (flat dd read)
.copyWarpData2:
    ; ld de,wCurrentTileBlockMapViewPointer / ld c,$6
    lea edi, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov bl, 6
.copyWarpDataLoop2:
    mov al, [esi]                              ; ld a,[hli]
    inc esi
    mov [edi], al                              ; ld [de],a
    inc edi                                    ; inc de
    dec bl                                     ; dec c
    jnz .copyWarpDataLoop2
    xor al, al                                 ; xor a ; OVERWORLD
    mov [ebp + wCurMapTileset], al             ; ld [wCurMapTileset],a
.done:
    mov [ebp + W_Y_OFFSET_SINCE_LAST_SPECIAL_WARP], al ; ld [wYOffsetSinceLastSpecialWarp],a
    mov [ebp + W_X_OFFSET_SINCE_LAST_SPECIAL_WARP], al ; ld [wXOffsetSinceLastSpecialWarp],a
    mov al, 0xFF                               ; ld a,-1 ; exclude normal warps
    mov [ebp + wDestinationWarpID], al         ; ld [wDestinationWarpID],a

    pop edi
    pop esi
    pop edx
    pop ebx
    pop eax
    ret

section .data

; pret: INCLUDE "data/maps/special_warps.asm"
%include "src/data/maps/special_warps.asm"
