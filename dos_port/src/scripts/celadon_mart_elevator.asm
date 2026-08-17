; CeladonMartElevator.asm — translated from pret scripts/CeladonMartElevator.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

%include "assets/map_dims.inc"

global CeladonMartElevatorCopyWarpMapsScript
global CeladonMartElevatorFloors
global CeladonMartElevatorShakeScript
global CeladonMartElevatorStoreWarpEntriesScript
global CeladonMartElevatorText
global CeladonMartElevatorWarpMaps
global CeladonMartElevator_Script
global CeladonMartElevator_TextPointers

extern Bankswitch
extern CopyData
extern DisplayElevatorFloorMenu   ; NOT YET DEFINED IN THE PORT
extern LoadItemList
extern ShakeElevator
extern TextScriptEnd

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
CeladonMartElevator_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    push esi
    jz .sk_6
        call CeladonMartElevatorStoreWarpEntriesScript
.sk_6:
    pop esi
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_USED_ELEVATOR))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_USED_ELEVATOR)) & 0xFF
    popfd
    jz .sk_10
        call CeladonMartElevatorShakeScript
.sk_10:
    xor al, al
    mov [ebp + wAutoTextBoxDrawingControl], al
    inc al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMartElevatorStoreWarpEntriesScript:
    mov esi, wWarpEntries
    mov al, [ebp + wWarpedFromWhichWarp]
    mov bh, al
    mov al, [ebp + wWarpedFromWhichMap]
    mov bl, al
    call .StoreWarpEntry
    ; fallthrough
.StoreWarpEntry:
    inc esi
    inc esi
    mov al, bh
    mov [ebp + esi], al
    inc esi
    mov al, bl
    mov [ebp + esi], al
    inc esi
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonMartElevatorCopyWarpMapsScript:
    mov esi, CeladonMartElevatorFloors
    call LoadItemList
    mov esi, CeladonMartElevatorWarpMaps
    mov dx, wElevatorWarpMaps
    mov bx, CeladonMartElevatorWarpMaps.End - CeladonMartElevatorWarpMaps
    jmp CopyData

%assign event_byte -1
%assign event_byte_a -1
CeladonMartElevatorFloors:
    db 5
    db FLOOR_1F
    db FLOOR_2F
    db FLOOR_3F
    db FLOOR_4F
    db FLOOR_5F
    db -1
CeladonMartElevatorWarpMaps:
    db 5, CELADON_MART_1F
    db 2, CELADON_MART_2F
    db 2, CELADON_MART_3F
    db 2, CELADON_MART_4F
    db 2, CELADON_MART_5F

%assign event_byte -1
%assign event_byte_a -1
.End:
CeladonMartElevatorShakeScript:
; DEVIATION{class=banking; pret=macros/farcall.asm:farjp; behavior=bank switch dropped, jmp goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    jmp ShakeElevator

%assign event_byte -1
%assign event_byte_a -1
CeladonMartElevator_TextPointers:
    dd CeladonMartElevatorText

%assign event_byte -1
%assign event_byte_a -1
CeladonMartElevatorText:
    call CeladonMartElevatorCopyWarpMapsScript
    mov esi, CeladonMartElevatorWarpMaps
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DisplayElevatorFloorMenu
    jmp TextScriptEnd
