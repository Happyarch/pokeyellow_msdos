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
%include "assets/script_constants.inc"

%include "assets/map_dims.inc"

global RocketHideoutElevatorFloors
global RocketHideoutElevatorScript
global RocketHideoutElevatorShakeScript
global RocketHideoutElevatorStoreWarpEntriesScript
global RocketHideoutElevatorText
global RocketHideoutElevatorWarpMaps
global RocketHideoutElevator_Script
global RocketHideoutElevator_TextPointers

extern Bankswitch
extern CopyData
extern Delay3
extern DisplayElevatorFloorMenu   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag
extern LoadItemList
extern PrintText
extern ShakeElevator
extern TextScriptEnd
extern _RocketHideoutElevatorAppearsToNeedKeyText   ; NOT YET DEFINED IN THE PORT

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
RocketHideoutElevator_Script:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    push esi
    jz .sk_6
        call RocketHideoutElevatorStoreWarpEntriesScript
.sk_6:
    pop esi
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_USED_ELEVATOR))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_USED_ELEVATOR)) & 0xFF
    popfd
    jz .sk_10
        call RocketHideoutElevatorShakeScript
.sk_10:
    xor al, al
    mov [ebp + wAutoTextBoxDrawingControl], al
    inc al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutElevatorStoreWarpEntriesScript:
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
RocketHideoutElevatorScript:
    mov esi, RocketHideoutElevatorFloors
    call LoadItemList
    mov esi, RocketHideoutElevatorWarpMaps
    mov dx, wElevatorWarpMaps
    mov bx, RocketHideoutElevatorWarpMaps.End - RocketHideoutElevatorWarpMaps
    call CopyData
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutElevatorFloors:
    db 3
    db FLOOR_B1F
    db FLOOR_B2F
    db FLOOR_B4F
    db -1
RocketHideoutElevatorWarpMaps:
    db 4, ROCKET_HIDEOUT_B1F
    db 4, ROCKET_HIDEOUT_B2F
    db 2, ROCKET_HIDEOUT_B4F

%assign event_byte -1
%assign event_byte_a -1
.End:
RocketHideoutElevatorShakeScript:
    call Delay3
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call ShakeElevator
    ret

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutElevator_TextPointers:
    dd RocketHideoutElevatorText

%assign event_byte -1
%assign event_byte_a -1
RocketHideoutElevatorText:
    mov bh, 74
    call IsItemInBag
    jz .no_key
    call RocketHideoutElevatorScript
    mov esi, RocketHideoutElevatorWarpMaps
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DisplayElevatorFloorMenu
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.no_key:
    mov esi, .AppearsToNeedKeyText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.AppearsToNeedKeyText:
    text_far _RocketHideoutElevatorAppearsToNeedKeyText
    text_waitbutton
    text_end
