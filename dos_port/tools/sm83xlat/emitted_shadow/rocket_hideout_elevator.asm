; RocketHideoutElevator.asm — translated from pret scripts/RocketHideoutElevator.asm by dos_port/tools/sm83xlat.
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

global RocketHideoutElevatorFloors
global RocketHideoutElevatorScript
global RocketHideoutElevatorShakeScript
global RocketHideoutElevatorText
global RocketHideoutElevatorWarpMaps
global RocketHideoutElevator_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CopyData   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayElevatorFloorMenu   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern LoadItemList   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutElevatorStoreWarpEntriesScript   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutElevator_Script   ; NOT YET DEFINED IN THE PORT
extern ShakeElevator   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutElevatorAppearsToNeedKeyText   ; NOT YET DEFINED IN THE PORT

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wCurrentMapScriptFlags
wCurrentMapScriptFlags                         equ W_CURRENT_MAP_SCRIPT_FLAGS
%endif
%ifndef wWarpEntries
wWarpEntries                                   equ W_WARP_ENTRIES
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wElevatorWarpMaps                              equ 0xCC5B
wWarpedFromWhichMap                            equ 0xD73B
wWarpedFromWhichWarp                           equ 0xD73A

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] RocketHideoutElevator_Script (scripts/RocketHideoutElevator.asm:2-15) — at scripts/RocketHideoutElevator.asm:8: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	push hl
; PRET| 	call nz, RocketHideoutElevatorStoreWarpEntriesScript
; PRET| 	pop hl
; PRET| 	bit BIT_CUR_MAP_USED_ELEVATOR, [hl]
; PRET| 	res BIT_CUR_MAP_USED_ELEVATOR, [hl]
; PRET| 	call nz, RocketHideoutElevatorShakeScript
; PRET| 	xor a
; PRET| 	ld [wAutoTextBoxDrawingControl], a
; PRET| 	inc a
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] RocketHideoutElevatorStoreWarpEntriesScript (scripts/RocketHideoutElevator.asm:18-32) — at scripts/RocketHideoutElevator.asm:23: .StoreWarpEntry is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wWarpEntries
; PRET| 	ld a, [wWarpedFromWhichWarp]
; PRET| 	ld b, a
; PRET| 	ld a, [wWarpedFromWhichMap]
; PRET| 	ld c, a
; PRET| 	call .StoreWarpEntry
; PRET| 	; fallthrough
; PRET| .StoreWarpEntry:
; PRET| 	inc hl
; PRET| 	inc hl
; PRET| 	ld a, b
; PRET| 	ld [hli], a
; PRET| 	ld a, c
; PRET| 	ld [hli], a
; PRET| 	ret

RocketHideoutElevatorScript:
    mov esi, RocketHideoutElevatorFloors
    call LoadItemList
    mov esi, RocketHideoutElevatorWarpMaps
    mov dx, wElevatorWarpMaps
    mov bx, RocketHideoutElevatorWarpMaps.End - RocketHideoutElevatorWarpMaps
    call CopyData
    ret

RocketHideoutElevatorFloors:
    db 3
    db 85
    db 84
    db 97
    db -1
RocketHideoutElevatorWarpMaps:
    db 4, ROCKET_HIDEOUT_B1F
    db 4, ROCKET_HIDEOUT_B2F
    db 2, ROCKET_HIDEOUT_B4F

.End:
RocketHideoutElevatorShakeScript:
    call Delay3
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ShakeElevator
    ret

RocketHideoutElevator_TextPointers:
    dd RocketHideoutElevatorText

RocketHideoutElevatorText:
    mov bh, 74
    call IsItemInBag
    jz .no_key
    call RocketHideoutElevatorScript
    mov esi, RocketHideoutElevatorWarpMaps
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call DisplayElevatorFloorMenu
    jmp .text_script_end

.no_key:
    mov esi, .AppearsToNeedKeyText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

.AppearsToNeedKeyText:
    text_far _RocketHideoutElevatorAppearsToNeedKeyText
    text_waitbutton
    text_end
