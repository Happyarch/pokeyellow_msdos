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
%include "assets/event_constants.inc"        ; EVENT_* (DEBUG_OAK_EVENT harness)
%include "events.inc"                        ; SetEvent

%ifndef FIRST_ROUTE_MAP
FIRST_ROUTE_MAP     equ 0x0C  ; constants/map_constants.asm (after UNUSED_MAP_0B)
%endif

global MarkTownVisitedAndLoadToggleableObjects
global InitializeToggleableObjectsFlags
global InitToggleableObjectFlags
global IsToggleableHidden
global g_toggleable_flags
global ShowObject
global ShowObject2
global HideObject
global ToggleableObjectFlagAction
global IsObjectHidden

extern FlagAction              ; src/engine/flag_action.asm (ebp-relative flag bit-manip)
extern UpdateSprites           ; src/home/update_sprites.asm

section .text

; ---------------------------------------------------------------------------
; MarkTownVisitedAndLoadToggleableObjects
; pret engine/overworld/toggleable_objects.asm:MarkTownVisitedAndLoadToggleableObjects
; ---------------------------------------------------------------------------
MarkTownVisitedAndLoadToggleableObjects:
    mov al, [ebp + wCurMap]
    cmp al, FIRST_ROUTE_MAP
    jae .notInTown                          ; jr nc (map id >= first route → not a town)
    movzx ecx, al                           ; c = curMap (flag index)
    mov bh, FLAG_SET                         ; b = FLAG_SET
    mov esi, wTownVisitedFlag                ; hl = wTownVisitedFlag (FlagAction adds ebp)
    ; pret: `predef FlagActionPredef`. Established port pattern (engine/menus/pokedex.asm,
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

; ---------------------------------------------------------------------------
; IsObjectHidden — pret engine/overworld/toggleable_objects.asm:IsObjectHidden
;
; pret is a predef, reached as `predef IsObjectHidden` from
; engine/overworld/movement.asm:CheckSpriteAvailability, and its whole contract is
; the HRAM pair: it reads the slot from hCurrentSpriteOffset and publishes
; "hidden?" to hIsToggleableObjectOff, which the caller then tests. That contract
; is reproduced here exactly; only the LOOKUP inside diverges.
;
; STRUCTURAL SPLIT (CLAUDE.md "Preserve pret Labels"): the flat-model scan already
; existed as the port-only helper IsToggleableHidden (map_sprites.asm), which takes
; the object id in AL and answers in CF. It is kept, because InitMapSprites calls it
; at MAP LOAD time where hCurrentSpriteOffset is not live and there is no HRAM
; result to publish. IsObjectHidden is pret's per-frame entry point and delegates to
; it, so the pret label names the pret contract and neither half is a fork of the
; other. Before this routine existed the pret label was absent entirely and
; CheckSpriteAvailability called the bespoke helper directly — a name fork of
; exactly the kind that rule exists to prevent.
;
; DEVIATION{class=data-model; pret=engine/overworld/toggleable_objects.asm:IsObjectHidden; behavior=the hidden bit is looked up in the flat g_toggleable_flags array through the precomputed per-map toggle list instead of scanning pret's wToggleableObjectList and testing wToggleableObjectFlags via ToggleableObjectFlagAction; evidence=the port flattened this subsystem ahead of OW-3.2 (tools/generators/gen_toggleable_objects.py plus map_sprites.asm) so wToggleableObjectList is never built and has no readers, and behaviour through the HRAM contract is identical; lifetime=retires if the toggleable subsystem is re-derived to pret's ebp-relative wToggleableObjectFlags model}
;
; In:  [EBP + hCurrentSpriteOffset] = slot byte offset (a multiple of $10).
; Out: [EBP + hIsToggleableObjectOff] = nonzero if this object is hidden.
; ---------------------------------------------------------------------------
IsObjectHidden:
    mov al, [ebp + hCurrentSpriteOffset]    ; ldh a, [hCurrentSpriteOffset]
    ; pret: `swap a` — the offset is always a multiple of $10 and below $100, so the
    ; nibble swap is exactly a >> 4, yielding the 1-based sprite slot number.
    shr al, 4
    ; The port's per-map toggle lists are keyed by the 0-based LOCAL OBJECT ID
    ; (= slot - 1), which is what gen_toggleable_objects.py emits and what
    ; IsToggleableHidden compares against. pret compares the swapped offset directly
    ; because its own list stores that form.
    dec al
    call IsToggleableHidden                 ; CF = 1 -> hidden. Clobbers AL only.
    ; `mov` does not touch flags, so CF still holds IsToggleableHidden's answer at
    ; the jnc below (the flag-preservation rule).
    mov al, 0
    jnc .store
    mov al, 1
.store:
    mov [ebp + hIsToggleableObjectOff], al  ; ldh [hIsToggleableObjectOff], a
    ret

; ---------------------------------------------------------------------------
; InitializeToggleableObjectsFlags — pret engine/overworld/toggleable_objects.asm.
;
; NAME FORK CLOSED 2026-08-22. This routine was `InitToggleableObjectFlags` in
; map_sprites.asm, so the pret label read `missing` and its only pret caller,
; InitPlayerData2, tail-jumped to a ret-stub in overworld_stubs.asm instead of to
; this body. It now carries pret's name (the port-local alias is kept alongside
; per CLAUDE.md's "Preserve pret Labels" rule) and lives at its pret mirror.
;
; It is the FLATTENED-MODEL equivalent of pret's routine, not a line-for-line
; translation of it — see this file's header. pret clears an ebp-relative
; wToggleableObjectFlags bit array and then walks ToggleableObjectStates calling
; ToggleableObjectFlagAction for every entry marked OFF; the port's default-hidden
; bitmap is precomputed by tools/generators/gen_toggleable_objects.py, so the whole
; walk collapses into one copy of toggleable_default_flags into g_toggleable_flags.
;
; DEVIATION{class=data-model; pret=engine/overworld/toggleable_objects.asm:InitializeToggleableObjectsFlags; behavior=the per-entry ToggleableObjectStates walk that sets a flag for every object marked OFF is replaced by a single copy of a precomputed default-hidden bitmap into the flat g_toggleable_flags array, and the routine additionally zeroes the wEventFlags region which pret does not touch here; evidence=the port precomputes each object global index at generation time in tools/generators/gen_toggleable_objects.py so there is no runtime pointer-difference divide to perform and no wToggleableObjectList to rebuild - see this file header - and the explicit wEventFlags clear exists because a DPMI allocation is not guaranteed zero-filled where a fresh cartridge WRAM effectively is; lifetime=permanent while the toggleable subsystem stays flat-model rather than pret ebp-relative}
;
; Called once at game start (EnterMap, before the first LoadMapData) so default-
; hidden objects (e.g. Oak in Pallet Town) do not spawn.  Also clears the general
; wEventFlags region — its new-game default is all-zero; explicit so a non-zeroed
; DPMI allocation can't leak stale event bits.
;
; TODO-GLOBAL-EVENTS: when the save / script engine lands, move this to the real
; new-game init and let scripts toggle g_toggleable_flags / wEventFlags at runtime.
; All registers preserved.
; ---------------------------------------------------------------------------
InitializeToggleableObjectsFlags:
InitToggleableObjectFlags:               ; port-local alias (pre-2026-08-22 name)
    push eax
    push ecx
    push esi
    push edi

    ; Copy default-hidden bitmap into the persistent flag array.
    mov esi, toggleable_default_flags   ; flat .data source
    mov edi, g_toggleable_flags         ; flat .bss dest
    mov ecx, TOGGLEABLE_FLAG_BYTES
    rep movsb

    ; Clear the general event-flag region (wEventFlags, NUM_EVENTS bits ≈ 0x140 B).
    lea edi, [ebp + wEventFlags]
    xor al, al
    mov ecx, 0x140
    rep stosb

%ifdef DEBUG_OAK_EVENT
    ; Test harness: force the event that PalletTownOakText gates on so the "set"
    ; branch ("OAK: That was close!") shows instead of the default "Hey! Wait!".
    SetEvent EVENT_GOT_POKEBALLS_FROM_OAK
%endif

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; IsToggleableHidden — is the given object on the current map hidden by default?
; Pret ref: engine/overworld/toggleable_objects.asm:IsObjectHidden.
;
; In:  AL = local object id (0-based slot index, = text_id).
;      [EBP + wCurMap] = current map id.
; Out: CF = 1 if the object is a toggleable that is currently flagged hidden.
; Clobbers: AL only (EBX/ECX/EDX/ESI preserved for the InitMapSprites caller).
; ---------------------------------------------------------------------------
IsToggleableHidden:
    push ebx
    push ecx
    push edx
    push esi

    movzx ebx, al                       ; BL = local object id to find
    movzx eax, byte [ebp + wCurMap]
    mov esi, [ToggleableMapPointers + eax*4]  ; flat ptr to this map's list (0 = none)
    test esi, esi
    jz .not_hidden

.scan:
    movzx eax, byte [esi]               ; runtime_slot (0xFF = end of list)
    cmp al, 0xFF
    je .not_hidden
    cmp al, bl
    je .match
    add esi, 2                          ; next (slot, global_index) pair
    jmp .scan

.match:
    movzx ecx, byte [esi + 1]           ; global toggleable index
    bt [g_toggleable_flags], ecx        ; CF = hidden bit
    jc .hidden

.not_hidden:
    pop esi
    pop edx
    pop ecx
    pop ebx
    clc
    ret

.hidden:
    pop esi
    pop edx
    pop ecx
    pop ebx
    stc
    ret

; ---------------------------------------------------------------------------
; Toggleable-object flag storage + generated tables. Moved here 2026-08-22 from
; map_sprites.asm, which is where the flat-model rewrite originally landed them;
; this file is the pret mirror for the whole toggleable subsystem.
; ---------------------------------------------------------------------------
section .bss
; Global toggleable-object (event) flags — pret's wToggleableObjectFlags. Bit g set
; (LSB-first) => toggleable object g is hidden. Persistent across map loads; seeded
; once from toggleable_default_flags by InitializeToggleableObjectsFlags at game start.
; Sized 64 B (TOGGLEABLE_FLAG_BYTES is ~30) so a dword-width `bt` near the end never
; reads past the array.
g_toggleable_flags:   resb 64

; Toggleable-object (event) flag defaults + per-map gating lists.
; Defines toggleable_default_flags, TOGGLEABLE_FLAG_BYTES, toggle_list_*,
; and ToggleableMapPointers.  Generated by tools/generators/gen_toggleable_objects.py.
%include "assets/toggleable_objects.inc"
