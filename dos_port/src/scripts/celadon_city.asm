; CeladonCity.asm — translated from pret scripts/CeladonCity.asm, scripts/CeladonCity_2.asm by dos_port/tools/sm83xlat.
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


global CeladonCityDeptStoreSignText
global CeladonCityGameCornerSignText
global CeladonCityGirlText
global CeladonCityGramps1Text
global CeladonCityGramps2Text
global CeladonCityGymSignText
global CeladonCityLittleGirlText
global CeladonCityMansionSignText
global CeladonCityPrintTrainerTips1Text
global CeladonCityPrizeExchangeSignText
global CeladonCityRocket1Text
global CeladonCityRocket2Text
global CeladonCityScript1
global CeladonCitySignText
global CeladonCityTrainerTips1Text
global CeladonCityTrainerTips2Text
global CeladonCity_Script
global CeladonCity_ScriptPointers
global CeladonCity_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CeladonCityFisherText   ; NOT YET DEFINED IN THE PORT
extern CeladonCityGramps3Text   ; NOT YET DEFINED IN THE PORT
extern CeladonCityPoliwrathText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityDeptStoreSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGameCornerSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGirlText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGramps1Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGramps2Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGramps3ReceivedTM41Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGramps3Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityLittleGirlText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityMansionSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityPrizeExchangeSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityRocket1Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityRocket2Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCitySignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern _CeladonCityTrainerTips2Text   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCeladonCityCurScript                          equ 0xD640

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeladonCity_Script:
    call EnableAutoTextBoxDrawing
    mov esi, CeladonCity_ScriptPointers
    mov al, [ebp + wCeladonCityCurScript]
    call CallFunctionInTable
    ret

%assign event_byte -1
CeladonCity_ScriptPointers:
    dd CeladonCityScript1

%assign event_byte -1
CeladonCityScript1:
    ResetEvents EVENT_1B8, EVENT_1BF
    ResetEvent EVENT_67F
    ret

%assign event_byte -1
CeladonCity_TextPointers:
    dd CeladonCityLittleGirlText
    dd CeladonCityGramps1Text
    dd CeladonCityGirlText
    dd CeladonCityGramps2Text
    dd CeladonCityGramps3Text
    dd CeladonCityFisherText
    dd CeladonCityPoliwrathText
    dd CeladonCityRocket1Text
    dd CeladonCityRocket2Text
    dd CeladonCityTrainerTips1Text
    dd CeladonCitySignText
    dd PokeCenterSignText
    dd CeladonCityGymSignText
    dd CeladonCityMansionSignText
    dd CeladonCityDeptStoreSignText
    dd CeladonCityTrainerTips2Text
    dd CeladonCityPrizeExchangeSignText
    dd CeladonCityGameCornerSignText
CeladonCityLittleGirlText:
    text_far _CeladonCityLittleGirlText
    text_end
CeladonCityGramps1Text:
    text_far _CeladonCityGramps1Text
    text_end
CeladonCityGirlText:
    text_far _CeladonCityGirlText
    text_end
CeladonCityGramps2Text:
    text_far _CeladonCityGramps2Text
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonCityGramps3Text (scripts/CeladonCity.asm:55-64) — at scripts/CeladonCity.asm:56: .gotTM41 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_TM41
; PRET| 	jr nz, .gotTM41
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	lb bc, TM_SOFTBOILED, 1
; PRET| 	call GiveItem
; PRET| 	jr c, .Success
; PRET| 	ld hl, .TM41NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .Done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonCityGramps3Text.Success (scripts/CeladonCity.asm:66-69) — at scripts/CeladonCity.asm:66: .ReceivedTM41Text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ReceivedTM41Text
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_TM41
; PRET| 	jr .Done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] CeladonCityGramps3Text.gotTM41 (scripts/CeladonCity.asm:71-74) — at scripts/CeladonCity.asm:71: .TM41ExplanationText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .TM41ExplanationText
; PRET| 	call PrintText
; PRET| .Done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] CeladonCityGramps3Text.Text (scripts/CeladonCity.asm:77-98) — at scripts/CeladonCity.asm:82: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _CeladonCityGramps3Text
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedTM41Text:
; PRET| 	text_far _CeladonCityGramps3ReceivedTM41Text
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .TM41ExplanationText:
; PRET| 	text_far _CeladonCityGramps3TM41ExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .TM41NoRoomText:
; PRET| 	text_far _CeladonCityGramps3TM41NoRoomText
; PRET| 	text_end
; PRET| 
; PRET| CeladonCityFisherText:
; PRET| 	text_far _CeladonCityFisherText
; PRET| 	text_end
; PRET| 
; PRET| CeladonCityPoliwrathText:
; PRET| 	text_far _CeladonCityPoliwrathText

%assign event_byte -1
    mov al, 111
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
CeladonCityRocket1Text:
    text_far _CeladonCityRocket1Text
    text_end
CeladonCityRocket2Text:
    text_far _CeladonCityRocket2Text
    text_end

%assign event_byte -1
CeladonCityTrainerTips1Text:
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call CeladonCityPrintTrainerTips1Text
    jmp TextScriptEnd

%assign event_byte -1
CeladonCitySignText:
    text_far _CeladonCitySignText
    text_end
CeladonCityGymSignText:
    text_far _CeladonCityGymSignText
    text_end
CeladonCityMansionSignText:
    text_far _CeladonCityMansionSignText
    text_end
CeladonCityDeptStoreSignText:
    text_far _CeladonCityDeptStoreSignText
    text_end
CeladonCityTrainerTips2Text:
    text_far _CeladonCityTrainerTips2Text
    text_end
CeladonCityPrizeExchangeSignText:
    text_far _CeladonCityPrizeExchangeSignText
    text_end
CeladonCityGameCornerSignText:
    text_far _CeladonCityGameCornerSignText
    text_end

%assign event_byte -1
CeladonCityPrintTrainerTips1Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _CeladonCityTrainerTips1Text
    text_end
