; dungeon_warps.asm — IsPlayerOnDungeonWarp (OW-1.4, pure-logic leaf).
;
; Faithful translation of pret engine/overworld/dungeon_warps.asm.
; Checks whether the player's current map coords match an entry in a
; caller-supplied ($ff-terminated) (Y,X) coordinate array -- the array that
; identifies the dungeon-warp trigger tiles for the CURRENT map (e.g.
; Seafoam4HolesCoords, VictoryRoad3F's .SwitchOrHoleCoords, ...). Each pret
; map script sets HL to its own array immediately before `call
; IsPlayerOnDungeonWarp` (see scripts/SeafoamIslandsB3F.asm,
; scripts/VictoryRoad3F.asm); that array is per-map data owned by those
; (not-yet-ported) map scripts, so it is NOT inlined here.
;
; NOTE: pret's IsPlayerOnDungeonWarp does not reference DungeonWarpList — that
; table (data/maps/special_warps.asm) is consumed by PrepareForSpecialWarp and
; belongs to the special_warps port (ticket OW-5.2), not here; it is inlined
; there to avoid a duplicate-symbol clash.
;
; Register map (SM83->x86): A->AL, HL->ESI, BC->BX (B=BH,C=BL).
; GB memory = [ebp + SYM], SYM from gb_memmap.inc.
;
; Reuses (does not duplicate) the port's existing coord-array scan:
;   extern ArePlayerCoordsInArray  ; src/engine/overworld/hidden_events.asm
; Contract (per that file's own header comment):
;   In:  ESI = flat ptr to a $ff-terminated array of (Y,X) pairs.
;        Reads [W_Y_COORD]/[W_X_COORD] (player coords) internally -- caller
;        does NOT need to load BH/BL itself.
;   Out: CF=1 and [W_COORD_INDEX] = matching 1-based index if found;
;        CF=0 (and [W_COORD_INDEX] = examined-entry count) otherwise.
;   Clobbers EAX, ESI. Preserves EBX/EDX.
;
; Build (default, LINK): nasm -f coff -I include/ -I . \
;                             -o dungeon_warps.o dungeon_warps.asm
; Build (standalone verify): nasm -f coff -I dos_port/include -I dos_port \
;                             -o /dev/null dungeon_warps.asm

bits 32

%include "gb_memmap.inc"

; ---------------------------------------------------------------------------
; Scaffold WRAM symbols not yet in gb_memmap.inc.
; TODO(root): promote these to gb_memmap.inc with sym-verified pret addresses,
; then delete the local defs here (do not keep both -- NASM %ifndef cannot
; detect another file's `equ`, so no cross-file collision risk today, but a
; combined future include of both definitions in ONE file would redefine-
; error, which is exactly the case root's promotion step needs to resolve).
; ---------------------------------------------------------------------------
; W_WHICH_DUNGEON_WARP (0xD71D) is defined in gb_memmap.inc (root-verified vs
; ram/wram.asm: wStatusFlags3 0xD72C − 15 bytes = 0xD71D).
%ifndef W_COORD_INDEX
; wCoordIndex -- ram/wram.asm:1015, inside a UNION/NEXTU scratch-byte group
; (ram/wram.asm:1000-1023) where wCoordIndex aliases wSavedY/wTempSCX/
; wWhichTrade/wDexMaxSeenMon/.../wSwappedMenuItem/wRodResponse/
; wOptionsCursorLocation (all zero-width labels stacked at the SAME address;
; only the trailing `db` at ram/wram.asm:1022 allocates the byte). The
; union's base address was not independently re-derived in this session
; (deeply nested UNION/ENDU blocks with NUM_BADGES-sized gaps upstream, at
; ram/wram.asm:906-1027); reusing the value already declared in this port's
; src/engine/overworld/hidden_events.asm (its own PLACEHOLDER for the same
; symbol) so both files agree rather than introducing a second guess.
W_COORD_INDEX         equ 0xD152   ; ram/wram.asm:1015 wCoordIndex
%endif

; wStatusFlags3 bit -- constants/ram_constants.asm (wStatusFlags3 const_def block)
%ifndef BIT_ON_DUNGEON_WARP
BIT_ON_DUNGEON_WARP   equ 4
%endif
; wStatusFlags6 bit -- constants/ram_constants.asm (wStatusFlags6 const_def block)
%ifndef BIT_DUNGEON_WARP
BIT_DUNGEON_WARP      equ 4
%endif

section .text

global IsPlayerOnDungeonWarp
extern ArePlayerCoordsInArray            ; src/engine/overworld/hidden_events.asm

; ---------------------------------------------------------------------------
; IsPlayerOnDungeonWarp -- test whether the player is on (or already flagged
; as being on) a dungeon warp tile from the caller-supplied coords array.
; Pret ref: engine/overworld/dungeon_warps.asm:IsPlayerOnDungeonWarp
;
; In:  ESI = flat ptr to caller's $ff-terminated (Y,X) dungeon-warp coords
;      array (caller loads this, exactly as pret loads HL before `call`).
; Out: CF=1  if THIS call newly detected a warp-array match (mirrors pret:
;            ArePlayerCoordsInArray's `stc` survives untouched all the way to
;            this ret on SM83, because every instruction pret places after it
;            -- ld/set -- is flag-neutral there); [W_WHICH_DUNGEON_WARP]
;            holds the matched 1-based index and W_STATUS_FLAGS_3/6 have the
;            ON_DUNGEON_WARP/DUNGEON_WARP bits freshly set.
;      CF=0  otherwise -- either the player was ALREADY flagged on a dungeon
;            warp (pret's `bit BIT_ON_DUNGEON_WARP,a` / `ret nz` early exit;
;            CF=0 because pret's opening `xor a` cleared C and `bit` never
;            touches C), or the coords array had no match (propagates
;            ArePlayerCoordsInArray's own `clc`). [W_WHICH_DUNGEON_WARP] is
;            always zeroed first regardless of path (pret's unconditional
;            `xor a` / `ld [wWhichDungeonWarp],a`).
; Clobbers EAX, ESI (via the ArePlayerCoordsInArray call). Preserves EBX/EDX.
; ---------------------------------------------------------------------------
IsPlayerOnDungeonWarp:
    mov byte [ebp + W_WHICH_DUNGEON_WARP], 0     ; xor a / ld [wWhichDungeonWarp],a
    mov al, [ebp + W_STATUS_FLAGS_3]             ; ld a,[wStatusFlags3]
    test al, (1 << BIT_ON_DUNGEON_WARP)          ; bit BIT_ON_DUNGEON_WARP,a (ZF set <-> bit==0, like GB)
    jnz .alreadyOnWarp                           ; ret nz (Z clear == bit WAS set == already on warp)

    call ArePlayerCoordsInArray                  ; ESI already = caller's array ptr
    jnc .notFound                                ; ret nc

    ; Match found: ArePlayerCoordsInArray left CF=1 and [W_COORD_INDEX] set.
    mov al, [ebp + W_COORD_INDEX]                ; ld a,[wCoordIndex]
    mov [ebp + W_WHICH_DUNGEON_WARP], al         ; ld [wWhichDungeonWarp],a
    or byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_ON_DUNGEON_WARP) ; set BIT_ON_DUNGEON_WARP,[hl]
    or byte [ebp + W_STATUS_FLAGS_6], (1 << BIT_DUNGEON_WARP)    ; set BIT_DUNGEON_WARP,[hl]
    ; PROJ: x86 `or` clobbers CF (clears it to 0) as a side effect GB's `set`
    ; does not have -- pret: engine/overworld/dungeon_warps.asm:12-14. Rather
    ; than rely on CF surviving the two `or`s above, re-establish CF=1
    ; explicitly: program logic proves CF was 1 on entry to this block (we
    ; only fall through here past `jnc .notFound`), so `stc` reconstructs the
    ; exact value pret's flag-neutral tail would have preserved.
    stc
    ret

.alreadyOnWarp:
    clc                                          ; CF=0: matches pret (xor a cleared C; bit leaves C alone)
    ret

.notFound:
    ; CF already 0 here -- propagated from ArePlayerCoordsInArray's own `clc`.
    ret
