; Museum1F.asm — translated from pret scripts/Museum1F.asm, scripts/Museum1F_2.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"

global Museum1FDefaultScript
global Museum1FGamblerText
global Museum1FNoopScript
global Museum1FOldAmberText
global Museum1FPrintGamblerText
global Museum1FPrintOldAmberText
global Museum1FPrintScientist1Text
global Museum1FPrintScientist2Text
global Museum1FPrintScientist3Text
global Museum1FScientist1Text
global Museum1FScientist2Text
global Museum1FScientist3Text
global Museum1F_Script
global Museum1F_ScriptPointers
global Museum1F_TextPointers

extern Bankswitch
extern CallFunctionInTable
extern DisplayTextBoxID
extern DisplayTextID
extern GiveItem
extern HasEnoughMoney
extern HideObject
extern PlaySoundWaitForCurrent
extern PrintText
extern StartSimulatingJoypadStates
extern SubBCDPredef
extern TextScriptEnd
extern UpdateSprites
extern WaitForSoundToFinish
extern YesNoChoice
extern _Museum1FGamblerText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FOldAmberText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1AmberIsFossilizedTreeSapText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1ComeAgainText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1DoYouKnowWhatAmberIsText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1DontHaveEnoughMoneyText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1GoToOtherSideText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1TakePlentyOfTimeText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1ThankYouText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1TheresALabSomewhereText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist1WouldYouLikeToComeInText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2GetTheOldAmberCheckText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2ReceivedOldAmberText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2TakeThisToAPokemonLabText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist2YouDontHaveSpaceText   ; NOT YET DEFINED IN THE PORT
extern _Museum1FScientist3Text   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_MUSEUM1F_NOOP                           equ 1
TEXT_MUSEUM1F_SCIENTIST1                       equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wMuseum1FCurScript                             equ 0xD618
wPriceTemp                                     equ 0xCD3D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Museum1F_Script:
    mov al, 1 << BIT_NO_AUTO_TEXT_BOX
    mov [ebp + wAutoTextBoxDrawingControl], al
    xor al, al
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, Museum1F_ScriptPointers
    mov al, [ebp + wMuseum1FCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
%assign event_byte_a -1
Museum1F_ScriptPointers:
    dd Museum1FDefaultScript
    dd Museum1FNoopScript

%assign event_byte -1
%assign event_byte_a -1
Museum1FDefaultScript:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jz .nr_19
        ret
.nr_19:
    mov al, [ebp + wXCoord]
    cmp al, 9
    jz .continue
    mov al, [ebp + wXCoord]
    cmp al, 10
    jz .nr_25
        ret
.nr_25:
.continue:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, TEXT_MUSEUM1F_SCIENTIST1
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
Museum1FNoopScript:
    ret

%assign event_byte -1
%assign event_byte_a -1
Museum1F_TextPointers:
    dd Museum1FScientist1Text
    dd Museum1FGamblerText
    dd Museum1FScientist2Text
    dd Museum1FScientist3Text
    dd Museum1FOldAmberText

%assign event_byte -1
%assign event_byte_a -1
Museum1FScientist1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist1Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Museum1FGamblerText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintGamblerText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Museum1FScientist2Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist2Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Museum1FScientist3Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintScientist3Text
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Museum1FOldAmberText:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call Museum1FPrintOldAmberText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
Museum1FPrintScientist1Text:
    mov al, [ebp + wYCoord]
    cmp al, 4
    jnz .not_right_of_scientist
    mov al, [ebp + wXCoord]
    cmp al, 13
    jz .behind_counter
    jmp .check_ticket

%assign event_byte -1
%assign event_byte_a -1
.not_right_of_scientist:
    cmp al, 3
    jnz .not_behind_counter
    mov al, [ebp + wXCoord]
    cmp al, 12
    jz .behind_counter
.not_behind_counter:
    CheckEvent EVENT_BOUGHT_MUSEUM_TICKET
    jnz .already_bought_ticket
    mov esi, .GoToOtherSideText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.check_ticket:
    CheckEvent EVENT_BOUGHT_MUSEUM_TICKET
    jz .no_ticket
.already_bought_ticket:
    mov esi, .TakePlentyOfTimeText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.no_ticket:
    mov al, MONEY_BOX
    mov [ebp + wTextBoxID], al
    call DisplayTextBoxID
    xor al, al
    mov [ebp + hJoyHeld], al
    mov esi, .WouldYouLikeToComeInText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .deny_entry
    xor al, al
    mov [ebp + hMoney], al
    mov [ebp + hMoney + 1], al
    mov al, 0x50
    mov [ebp + hMoney + 2], al
    call HasEnoughMoney
    jae .buy_ticket
    mov esi, .DontHaveEnoughMoneyText
    call PrintText
    jmp .deny_entry

%assign event_byte -1
%assign event_byte_a -1
.buy_ticket:
    mov esi, .ThankYouText
    call PrintText
    SetEvent EVENT_BOUGHT_MUSEUM_TICKET
    xor al, al
    mov [ebp + wPriceTemp], al
    mov [ebp + wPriceTemp + 1], al
    mov al, 0x50
    mov [ebp + wPriceTemp + 2], al
    mov esi, wPriceTemp + 2
    mov dx, wPlayerMoney + 2
    mov bl, 0x3
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call SubBCDPredef
    mov al, MONEY_BOX
    mov [ebp + wTextBoxID], al
    call DisplayTextBoxID
    mov al, SFX_PURCHASE
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    jmp .allow_entry

%assign event_byte -1
%assign event_byte_a -1
.deny_entry:
    mov esi, .ComeAgainText
    call PrintText
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    call StartSimulatingJoypadStates
    call UpdateSprites
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.allow_entry:
    mov al, SCRIPT_MUSEUM1F_NOOP
    mov [ebp + wMuseum1FCurScript], al
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.behind_counter:
    mov esi, .DoYouKnowWhatAmberIsText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 0x0
    jnz .explain_amber
    mov esi, .TheresALabSomewhereText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.explain_amber:
    mov esi, .AmberIsFossilizedTreeSapText
    call PrintText
.done:
    ret

%assign event_byte -1
%assign event_byte_a -1
.ComeAgainText:
    text_far _Museum1FScientist1ComeAgainText
    text_end
.WouldYouLikeToComeInText:
    text_far _Museum1FScientist1WouldYouLikeToComeInText
    text_end
.ThankYouText:
    text_far _Museum1FScientist1ThankYouText
    text_end
.DontHaveEnoughMoneyText:
    text_far _Museum1FScientist1DontHaveEnoughMoneyText
    text_end
.DoYouKnowWhatAmberIsText:
    text_far _Museum1FScientist1DoYouKnowWhatAmberIsText
    text_end
.TheresALabSomewhereText:
    text_far _Museum1FScientist1TheresALabSomewhereText
    text_end
.AmberIsFossilizedTreeSapText:
    text_far _Museum1FScientist1AmberIsFossilizedTreeSapText
    text_end
.GoToOtherSideText:
    text_far _Museum1FScientist1GoToOtherSideText
    text_end
.TakePlentyOfTimeText:
    text_far _Museum1FScientist1TakePlentyOfTimeText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Museum1FPrintGamblerText:
    mov esi, .Text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Museum1FGamblerText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Museum1FPrintScientist2Text:
    CheckEvent EVENT_GOT_OLD_AMBER
    jnz .got_item
    mov esi, .TakeThisToAPokemonLabText
    call PrintText
    mov bx, (OLD_AMBER << 8) | (1)   ; pret: lb bc, OLD_AMBER, 1 (Museum1F_2.asm:151)
    call GiveItem
    jae .bag_full
    SetEvent EVENT_GOT_OLD_AMBER
    mov al, TOGGLE_OLD_AMBER
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov esi, .ReceivedOldAmberText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .YouDontHaveSpaceText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .GetTheOldAmberCheckText
.done:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.TakeThisToAPokemonLabText:
    text_far _Museum1FScientist2TakeThisToAPokemonLabText
    text_end
.ReceivedOldAmberText:
    text_far _Museum1FScientist2ReceivedOldAmberText
    sound_get_item_1
    text_end
.GetTheOldAmberCheckText:
    text_far _Museum1FScientist2GetTheOldAmberCheckText
    text_end
.YouDontHaveSpaceText:
    text_far _Museum1FScientist2YouDontHaveSpaceText
    text_end

%assign event_byte -1
%assign event_byte_a -1
Museum1FPrintScientist3Text:
    mov esi, .Text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Museum1FScientist3Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
Museum1FPrintOldAmberText:
    mov esi, .Text
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _Museum1FOldAmberText
    text_end
