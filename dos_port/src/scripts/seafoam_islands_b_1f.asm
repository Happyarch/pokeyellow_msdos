; SeafoamIslandsB1F.asm — translated from pret scripts/SeafoamIslandsB1F.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"

%include "assets/map_dims.inc"

global Seafoam2HolesCoords
global SeafoamIslandsB1F_Script
global SeafoamIslandsB1F_TextPointers

extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CheckBoulderCoords
extern EnableAutoTextBoxDrawing
extern HideObject
extern IsPlayerOnDungeonWarp
extern ShowObject

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wObjectToHide                                  equ 0xD078
wObjectToShow                                  equ 0xD079

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SeafoamIslandsB1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, wMiscFlags
    setc ah                     ; SM83 `bit` preserves C — stash it
    test byte [ebp + esi], (1 << (BIT_PUSHED_BOULDER))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_PUSHED_BOULDER)) & 0xFF
    popfd
    jz .noBoulderWasPushed
    mov esi, Seafoam2HolesCoords
    call CheckBoulderCoords
    jb .nr_9
        ret
.nr_9:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE)
    %assign event_byte EVENT_BYTE(EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE)
    mov al, [ebp + wCoordIndex]
    cmp al, 0x1
    jnz .boulder2FellDownHole
    SetEventReuseHL EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE
    mov al, 225
    mov [ebp + wObjectToHide], al
    mov al, 227
    mov [ebp + wObjectToShow], al
    jmp .hideAndShowBoulderObjects

%assign event_byte -1
%assign event_byte_a -1
.boulder2FellDownHole:
    SetEventAfterBranchReuseHL EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE, EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE
    mov al, 226
    mov [ebp + wObjectToHide], al
    mov al, 228
    mov [ebp + wObjectToShow], al
.hideAndShowBoulderObjects:
    mov al, [ebp + wObjectToHide]
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, [ebp + wObjectToShow]
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ShowObject

%assign event_byte -1
%assign event_byte_a -1
.noBoulderWasPushed:
    mov al, SEAFOAM_ISLANDS_B2F
    mov [ebp + wDungeonWarpDestinationMap], al
    mov esi, Seafoam2HolesCoords
    jmp IsPlayerOnDungeonWarp

%assign event_byte -1
%assign event_byte_a -1
Seafoam2HolesCoords:
    db 6, 18
    db 6, 23
    db -1
SeafoamIslandsB1F_TextPointers:
    dd BoulderText
    dd BoulderText
