; SeafoamIslands1F.asm — translated from pret scripts/SeafoamIslands1F.asm by dos_port/tools/sm83xlat.
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

global Seafoam1HolesCoords
global SeafoamIslands1F_TextPointers

extern BoulderText   ; NOT YET DEFINED IN THE PORT
extern CheckBoulderCoords   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern IsPlayerOnDungeonWarp   ; NOT YET DEFINED IN THE PORT
extern SeafoamIslands1F_Script   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT

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

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] SeafoamIslands1F_Script (scripts/SeafoamIslands1F.asm:2-20) — at scripts/SeafoamIslands1F.asm:5: bit BIT_PUSHED_BOULDER, [hl]
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	SetEvent EVENT_IN_SEAFOAM_ISLANDS
; PRET| 	ld hl, wMiscFlags
; PRET| 	bit BIT_PUSHED_BOULDER, [hl]
; PRET| 	res BIT_PUSHED_BOULDER, [hl]
; PRET| 	jr z, .noBoulderWasPushed
; PRET| 	ld hl, Seafoam1HolesCoords
; PRET| 	call CheckBoulderCoords
; PRET| 	ret nc
; PRET| 	EventFlagAddress hl, EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	jr nz, .boulder2FellDownHole
; PRET| 	SetEventReuseHL EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_1F_BOULDER_1
; PRET| 	ld [wObjectToHide], a
; PRET| 	ld a, TOGGLE_SEAFOAM_ISLANDS_B1F_BOULDER_1
; PRET| 	ld [wObjectToShow], a
; PRET| 	jr .hideAndShowBoulderObjects

%assign event_byte -1
.boulder2FellDownHole:
    SetEventAfterBranchReuseHL EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE, EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE
    mov al, 224
    mov [ebp + wObjectToHide], al
    mov al, 226
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
.noBoulderWasPushed:
    mov al, SEAFOAM_ISLANDS_B1F
    mov [ebp + wDungeonWarpDestinationMap], al
    mov esi, Seafoam1HolesCoords
    jmp IsPlayerOnDungeonWarp

%assign event_byte -1
Seafoam1HolesCoords:
    db 6, 17
    db 6, 24
    db -1
SeafoamIslands1F_TextPointers:
    dd BoulderText
    dd BoulderText
