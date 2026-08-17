; SSAnneKitchen.asm — translated from pret scripts/SSAnneKitchen.asm by dos_port/tools/sm83xlat.
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


global SSAnneKitchenCook1Text
global SSAnneKitchenCook2Text
global SSAnneKitchenCook3Text
global SSAnneKitchenCook4Text
global SSAnneKitchenCook5Text
global SSAnneKitchenCook6Text
global SSAnneKitchenCook7Text
global SSAnneKitchen_Script
global SSAnneKitchen_TextPointers

extern EnableAutoTextBoxDrawing
extern PrintText
extern SSAnneKitchenCook7EelsAuBarbecueText   ; NOT YET DEFINED IN THE PORT
extern SSAnneKitchenCook7PrimeBeefSteakText   ; NOT YET DEFINED IN THE PORT
extern SSAnneKitchenCook7SalmonDuSaladText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd
extern _SSAnneKitchenCook1Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook2Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook3Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook4Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook5Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook6Text   ; NOT YET DEFINED IN THE PORT
extern _SSAnneKitchenCook7MainCourseIsText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SSAnneKitchen_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
SSAnneKitchen_TextPointers:
    dd SSAnneKitchenCook1Text
    dd SSAnneKitchenCook2Text
    dd SSAnneKitchenCook3Text
    dd SSAnneKitchenCook4Text
    dd SSAnneKitchenCook5Text
    dd SSAnneKitchenCook6Text
    dd SSAnneKitchenCook7Text
SSAnneKitchenCook1Text:
    text_far _SSAnneKitchenCook1Text
    text_end
SSAnneKitchenCook2Text:
    text_far _SSAnneKitchenCook2Text
    text_end
SSAnneKitchenCook3Text:
    text_far _SSAnneKitchenCook3Text
    text_end
SSAnneKitchenCook4Text:
    text_far _SSAnneKitchenCook4Text
    text_end
SSAnneKitchenCook5Text:
    text_far _SSAnneKitchenCook5Text
    text_end
SSAnneKitchenCook6Text:
    text_far _SSAnneKitchenCook6Text
    text_end

%assign event_byte -1
%assign event_byte_a -1
SSAnneKitchenCook7Text:
    mov esi, .MainCourseIsText
    call PrintText
    mov al, [ebp + hRandomAdd]
    test al, (1 << (7))
    jz .not_dialog_1
    mov esi, .SalmonDuSaladText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_dialog_1:
    test al, (1 << (4))
    jz .not_dialog_2
    mov esi, .EelsAuBarbecueText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_dialog_2:
    mov esi, .PrimeBeefSteakText
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.MainCourseIsText:
    text_far _SSAnneKitchenCook7MainCourseIsText
    text_end
.SalmonDuSaladText:
    text_far SSAnneKitchenCook7SalmonDuSaladText
    text_end
.EelsAuBarbecueText:
    text_far SSAnneKitchenCook7EelsAuBarbecueText
    text_end
.PrimeBeefSteakText:
    text_far SSAnneKitchenCook7PrimeBeefSteakText
    text_end
