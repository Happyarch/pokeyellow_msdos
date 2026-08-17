; CinnabarLabFossilRoom.asm — translated from pret scripts/CinnabarLabFossilRoom.asm by dos_port/tools/sm83xlat.
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


global CinnabarLabFossilRoomScientist1Text
global CinnabarLabFossilRoomScientist2Text
global CinnabarLabFossilRoom_Script
global CinnabarLabFossilRoom_TextPointers
global FossilsList
global Lab4Script_GetFossilsInBag
global LoadFossilItemAndMonNameBank1D

extern Bankswitch
extern DoInGameTradeDialogue   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing
extern GetQuantityOfItemInBag
extern GiveFossilToCinnabarLab   ; NOT YET DEFINED IN THE PORT
extern GivePokemon
extern LoadFossilItemAndMonName   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern TextScriptEnd
extern _CinnabarLabFossilRoomScientist1FossilIsBackToLifeText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1GoForAWalkText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1NoFossilsText   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabFossilRoomScientist1Text   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wFilteredBagItems                              equ 0xCC5B
wFilteredBagItemsCount                         equ 0xCD37
wFossilMon                                     equ 0xD70F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CinnabarLabFossilRoom_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
CinnabarLabFossilRoom_TextPointers:
    dd CinnabarLabFossilRoomScientist1Text
    dd CinnabarLabFossilRoomScientist2Text

%assign event_byte -1
%assign event_byte_a -1
Lab4Script_GetFossilsInBag:
    xor al, al
    mov [ebp + wFilteredBagItemsCount], al
    mov edx, wFilteredBagItems
    mov esi, FossilsList
.loop:
    mov al, [esi]
    lea esi, [esi+1]
    test al, al
    jz .done
    push esi
    push edx
    mov [ebp + wTempByteValue], al
    mov bh, al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call GetQuantityOfItemInBag
    pop edx
    pop esi
    mov al, bh
    test al, al
    jz .loop
    mov al, [ebp + wTempByteValue]
    and edx, 0xFFFF   ; pret: ld [de], a — enforce 16-bit GB pointer before accessing ebp + edx
    mov [ebp + edx], al
    inc edx
    inc byte [ebp + wFilteredBagItemsCount]
    jmp .loop
.done:
    mov al, 0xff
    and edx, 0xFFFF   ; pret: ld [de], a — enforce 16-bit GB pointer before accessing ebp + edx
    mov [ebp + edx], al
    ret

%assign event_byte -1
%assign event_byte_a -1
FossilsList:
    db DOME_FOSSIL
    db HELIX_FOSSIL
    db OLD_AMBER
    db 0

%assign event_byte -1
%assign event_byte_a -1
CinnabarLabFossilRoomScientist1Text:
    CheckEvent EVENT_GAVE_FOSSIL_TO_LAB
    jnz .check_done_reviving
    mov esi, .Text
    call PrintText
    call Lab4Script_GetFossilsInBag
    mov al, [ebp + wFilteredBagItemsCount]
    test al, al
    jz .no_fossils
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call GiveFossilToCinnabarLab
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.no_fossils:
    mov esi, .NoFossilsText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.check_done_reviving:
    CheckEventAfterBranchReuseA EVENT_LAB_STILL_REVIVING_FOSSIL, EVENT_GAVE_FOSSIL_TO_LAB
    jz .done_reviving
    mov esi, .GoForAWalkText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.done_reviving:
    call LoadFossilItemAndMonNameBank1D
    mov esi, .FossilIsBackToLifeText
    call PrintText
    pushfd    ; SM83 form writes no flags
        SetEvent EVENT_LAB_HANDING_OVER_FOSSIL_MON
    popfd
    mov al, [ebp + wFossilMon]
    mov bh, al
    mov bl, 30
    call GivePokemon
    jae .done
    ResetEvents EVENT_GAVE_FOSSIL_TO_LAB, EVENT_LAB_STILL_REVIVING_FOSSIL, EVENT_LAB_HANDING_OVER_FOSSIL_MON
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _CinnabarLabFossilRoomScientist1Text
    text_end
.NoFossilsText:
    text_far _CinnabarLabFossilRoomScientist1NoFossilsText
    text_end
.GoForAWalkText:
    text_far _CinnabarLabFossilRoomScientist1GoForAWalkText
    text_end
.FossilIsBackToLifeText:
    text_far _CinnabarLabFossilRoomScientist1FossilIsBackToLifeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CinnabarLabFossilRoomScientist2Text:
    mov al, TRADE_FOR_STICKY
    mov [ebp + wWhichTrade], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call DoInGameTradeDialogue
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
LoadFossilItemAndMonNameBank1D:
; DEVIATION{class=banking; pret=macros/farcall.asm:farjp; behavior=bank switch dropped, jmp goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    jmp LoadFossilItemAndMonName
