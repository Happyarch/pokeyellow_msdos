; toggleable_objects.asm — toggleable-object (item/legendary/NPC) show/hide (OW-3.2).
;
; Intended repo path: dos_port/src/engine/overworld/toggleable_objects.asm
; pret source: engine/overworld/toggleable_objects.asm
;
; *** PORT DIVERGENCE — read before touching ***
; The port's toggleable-object subsystem was flattened ahead of this ticket
; (tools/generators/gen_toggleable_objects.py + map_sprites.asm). Instead of pret's runtime
; model — a 3-byte-per-entry `ToggleableObjectStates` table, a `wToggleableObjectList`
; rebuilt per map by dividing a pointer difference by 3, and an ebp-relative
; `wToggleableObjectFlags` bit array — the port:
;   * precomputes the GLOBAL index into each `toggle_list_<map>` entry
;     (db runtime_slot, global_index),
;   * indexes maps through `ToggleableMapPointers` (dd) directly, and
;   * stores the hidden bits in the FLAT .bss array `g_toggleable_flags`
;     (map_sprites.asm: IsToggleableHidden does `bt [g_toggleable_flags], ecx`).
; So pret's `MarkTownVisitedAndLoadToggleableObjects` list-build tail is obsolete
; here (nothing consults wToggleableObjectList), and the flag helper can't route
; through the port's ebp-relative `FlagAction` — it must bts/btr/bt the flat array.
; The port's `InitToggleableObjectFlags` / `IsToggleableHidden` (map_sprites.asm)
; are the flattened-model equivalents of pret `InitializeToggleableObjectsFlags` /
; `IsObjectHidden`.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL/CL, HL->ESI. GB memory is
; [ebp+offset]; g_toggleable_flags is a flat host symbol.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/toggleable_objects.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"                  ; FLAG_SET / FLAG_RESET / FLAG_TEST
%include "gb_macros.inc"
%include "m8_2_pending_symbols.inc"          ; wToggleableObjectIndex

%ifndef FIRST_ROUTE_MAP
FIRST_ROUTE_MAP     equ 0x0C  ; constants/map_constants.asm (after UNUSED_MAP_0B)
%endif
%ifndef wTownVisitedFlag
; golden 00:d70a. NOTE: town_map.asm's reader currently uses a placeholder
; (TOWNMAP_WRAM_PLACEHOLDER 0xDE00 + 0xA6 = 0xDEA6) — a documented "not a real
; allocation" TODO there. Until that reader is reconciled to this golden address,
; the town-visited-for-flying flag written here and read by town_map won't agree.
wTownVisitedFlag    equ 0xD70A
%endif

global MarkTownVisitedAndLoadToggleableObjects
global ShowObject
global ShowObject2
global HideObject
global ToggleableObjectFlagAction

extern FlagAction              ; src/engine/flag_action.asm (ebp-relative flag bit-manip)
extern UpdateSprites           ; src/engine/overworld/movement.asm
extern g_toggleable_flags      ; src/engine/overworld/map_sprites.asm (flat .bss bit array)

section .text

; ---------------------------------------------------------------------------
; MarkTownVisitedAndLoadToggleableObjects
; pret engine/overworld/toggleable_objects.asm:MarkTownVisitedAndLoadToggleableObjects
; ---------------------------------------------------------------------------
MarkTownVisitedAndLoadToggleableObjects:
    mov al, [ebp + W_CUR_MAP]
    cmp al, FIRST_ROUTE_MAP
    jae .notInTown                          ; jr nc (map id >= first route → not a town)
    movzx ecx, al                           ; c = curMap (flag index)
    mov bh, FLAG_SET                         ; b = FLAG_SET
    mov esi, wTownVisitedFlag                ; hl = wTownVisitedFlag (FlagAction adds ebp)
    ; pret: `predef FlagActionPredef`. Established port pattern (item_predicates.asm,
    ; experience.asm): call the FlagAction leaf directly when registers are hand-set —
    ; FlagActionPredef begins with GetPredefRegisters, which would clobber ESI/BH/CL.
    call FlagAction
.notInTown:
    ; DIVERGENCE (see file header): pret rebuilds wToggleableObjectList here from
    ; ToggleableObjectMapPointers via Divide (pointer-difference / 3 → global index).
    ; The port precomputes those global indices into the toggle_list_<map> data and
    ; reads them directly (IsToggleableHidden), so wToggleableObjectList is never
    ; consulted and the list-build tail — plus its Divide dependency — is dead here.
    ret

; ---------------------------------------------------------------------------
; ShowObject / ShowObject2 — clear the hidden flag for wToggleableObjectIndex,
; then refresh sprites. pret: engine/overworld/toggleable_objects.asm.
; ---------------------------------------------------------------------------
ShowObject:
ShowObject2:
    movzx ecx, byte [ebp + wToggleableObjectIndex]  ; c = global index
    mov bh, FLAG_RESET                               ; b = action
    call ToggleableObjectFlagAction                  ; reset "removed" flag
    jmp UpdateSprites                                ; jp UpdateSprites (tail)

; ---------------------------------------------------------------------------
; HideObject — set the hidden flag for wToggleableObjectIndex, then refresh.
; pret: engine/overworld/toggleable_objects.asm:HideObject.
; ---------------------------------------------------------------------------
HideObject:
    movzx ecx, byte [ebp + wToggleableObjectIndex]  ; c = global index
    mov bh, FLAG_SET                                 ; b = action
    call ToggleableObjectFlagAction                  ; set "removed" flag
    jmp UpdateSprites                                ; jp UpdateSprites (tail)

; ---------------------------------------------------------------------------
; ToggleableObjectFlagAction — FLAG_SET/RESET/TEST on the FLAT g_toggleable_flags
; bit array. pret's version is "identical to FlagAction" on ebp-relative
; wToggleableObjectFlags; the port stores these bits in flat .bss instead (see
; header), so it uses bts/btr/bt rather than routing through FlagAction.
; In: CL = c = global index, BH = b = action. FLAG_TEST result: CF = bit state
;     (ShowObject/HideObject — the only callers — ignore it).
; ---------------------------------------------------------------------------
ToggleableObjectFlagAction:
    movzx ecx, cl                            ; ecx = bit index
    mov al, bh
    test al, al
    jz .reset                                ; FLAG_RESET (0)
    cmp al, FLAG_TEST
    je .read
.set:
    bts [g_toggleable_flags], ecx            ; set "removed" (hidden) bit
    ret
.reset:
    btr [g_toggleable_flags], ecx            ; clear "removed" bit
    ret
.read:
    bt [g_toggleable_flags], ecx             ; CF = current bit
    ret
