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
; ── LoadSpecialWarpData + the warp DATA tables are DEFERRED (blocked) ──
; LoadSpecialWarpData copies a precomputed (view-pointer, Y, X, sub-block) struct
; out of ROM tables (NewGameWarp / TradeCenter*/Colosseum* / DungeonWarpData /
; FlyWarpData) into wCurrentTileBlockMapViewPointer&co. Those tables are built by
; the `fly_warp`/`special_warp_spec`/`fly_warp_spec` macros on top of
; `event_displacement`, which:
;   (1) is explicitly marked "do not use this macro until [re-derived]" in
;       dos_port/include/coords.inc — it carries an unresolved border-stride bug
;       (assumes MAP_BORDER=3; the port's wOverworldMap uses a wider border), and
;   (2) precomputes a wCurrentTileBlockMapViewPointer value the port's
;       native-width renderer does NOT consume the same way — the port
;       DELIBERATELY diverges here (see overworld.asm:LoadDestinationWarpPosition,
;       which recomputes the view-pointer at runtime instead of copying pret's
;       ROM table).
; Worse, LoadSpecialWarpData's pointer-walk arithmetic (`ld a,[hli]; ld h,[hl];
; ld l,a` building a 2-byte GB pointer; wDungeonWarpDataEntrySize=6; the fly/
; dungeon entry strides) is INSEPARABLE from the flat/GB pointer-model decision —
; a verbatim transliteration yields broken flat-pointer semantics, and the flat
; adaptation can't be finalized until the event_displacement re-derivation +
; view-pointer model are resolved. So LoadSpecialWarpData is externed here and
; ported together with its data once that model lands (tracked: memory
; coord-macros-logic-audit; TODO(OW map-data extension / event_displacement
; re-derivation)).
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

; --- constants ---
%ifndef PALLET_TOWN
PALLET_TOWN               equ 0x00
%endif
%ifndef BIT_FLY_OR_DUNGEON_WARP
BIT_FLY_OR_DUNGEON_WARP   equ 2   ; wStatusFlags6 bit 2
%endif
%ifndef BIT_DEBUG_MODE
BIT_DEBUG_MODE            equ 1   ; wStatusFlags6 bit 1
%endif
%ifndef BIT_DUNGEON_WARP
BIT_DUNGEON_WARP          equ 4   ; wStatusFlags6 bit 4
%endif

global PrepareForSpecialWarp

extern LoadSpecialWarpData         ; UNPORTED/BLOCKED (this file, deferred tail — see header)
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
