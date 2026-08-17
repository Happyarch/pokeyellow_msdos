; SilphCoElevator.asm — translated from pret scripts/SilphCoElevator.asm by dos_port/tools/sm83xlat.
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

global SilphCoElevatorCopyWarpMapsScript
global SilphCoElevatorElevatorText
global SilphCoElevatorFloors
global SilphCoElevatorShakeScript
global SilphCoElevatorWarpMaps
global SilphCoElevator_Script
global SilphCoElevator_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CopyData   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayElevatorFloorMenu   ; NOT YET DEFINED IN THE PORT
extern LoadItemList   ; NOT YET DEFINED IN THE PORT
extern ShakeElevator   ; NOT YET DEFINED IN THE PORT
extern SilphCoElevatorStoreWarpEntriesScript   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

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

%assign event_byte -1
%assign event_byte_a -1
SilphCoElevator_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    push esi
    jz .sk_6
        call SilphCoElevatorStoreWarpEntriesScript
.sk_6:
    pop esi
    test byte [ebp + esi], (1 << (7))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (7)) & 0xFF
    popfd
    jz .sk_10
        call SilphCoElevatorShakeScript
.sk_10:
    xor al, al
    mov [ebp + wAutoTextBoxDrawingControl], al
    inc al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCoElevatorStoreWarpEntriesScript (scripts/SilphCoElevator.asm:18-32) — at scripts/SilphCoElevator.asm:23: .StoreWarpEntry is defined in a region that bailed
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

%assign event_byte -1
%assign event_byte_a -1
SilphCoElevatorCopyWarpMapsScript:
    mov esi, SilphCoElevatorFloors
    call LoadItemList
    mov esi, SilphCoElevatorWarpMaps
    mov dx, wElevatorWarpMaps
    mov bx, SilphCoElevatorWarpMaps.End - SilphCoElevatorWarpMaps
    call CopyData
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCoElevatorFloors:
    db 11
    db 86
    db 87
    db 88
    db 89
    db 90
    db 91
    db 92
    db 93
    db 94
    db 95
    db 96
    db -1
SilphCoElevatorWarpMaps:
    db 3, SILPH_CO_1F
    db 2, SILPH_CO_2F
    db 2, SILPH_CO_3F
    db 2, SILPH_CO_4F
    db 2, SILPH_CO_5F
    db 2, SILPH_CO_6F
    db 2, SILPH_CO_7F
    db 2, SILPH_CO_8F
    db 2, SILPH_CO_9F
    db 2, SILPH_CO_10F
    db 1, SILPH_CO_11F

%assign event_byte -1
%assign event_byte_a -1
.End:
SilphCoElevatorShakeScript:
    call Delay3
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ShakeElevator
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCoElevator_TextPointers:
    dd SilphCoElevatorElevatorText

%assign event_byte -1
%assign event_byte_a -1
SilphCoElevatorElevatorText:
    call SilphCoElevatorCopyWarpMapsScript
    mov esi, SilphCoElevatorWarpMaps
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DisplayElevatorFloorMenu
    jmp TextScriptEnd
