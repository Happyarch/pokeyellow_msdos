; SaffronCity.asm — translated from pret scripts/SaffronCity.asm by dos_port/tools/sm83xlat.
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


global SaffronCityFightingDojoSignText
global SaffronCityGentlemanText
global SaffronCityGymSignText
global SaffronCityMrPsychicsHouseSignText
global SaffronCityPidgeotText
global SaffronCityRockerText
global SaffronCityRocket1Text
global SaffronCityRocket2Text
global SaffronCityRocket3Text
global SaffronCityRocket4Text
global SaffronCityRocket5Text
global SaffronCityRocket6Text
global SaffronCityRocket7Text
global SaffronCityRocket8Text
global SaffronCityRocket9Text
global SaffronCityScientistText
global SaffronCitySignText
global SaffronCitySilphCoLatestProductSignText
global SaffronCitySilphCoSignText
global SaffronCitySilphWorkerFText
global SaffronCitySilphWorkerMText
global SaffronCityTrainerTips1Text
global SaffronCityTrainerTips2Text
global SaffronCity_Script
global SaffronCity_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityFightingDojoSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityGentlemanText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityMrPsychicsHouseSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityPidgeotText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRockerText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket1Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket2Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket3Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket4Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket5Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket6Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket7Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket8Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket9Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityScientistText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphCoLatestProductSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphCoSignText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphWorkerFText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphWorkerMText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityTrainerTips2Text   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
SaffronCity_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
SaffronCity_TextPointers:
    dd SaffronCityRocket1Text
    dd SaffronCityRocket2Text
    dd SaffronCityRocket3Text
    dd SaffronCityRocket4Text
    dd SaffronCityRocket5Text
    dd SaffronCityRocket6Text
    dd SaffronCityRocket7Text
    dd SaffronCityScientistText
    dd SaffronCitySilphWorkerMText
    dd SaffronCitySilphWorkerFText
    dd SaffronCityGentlemanText
    dd SaffronCityPidgeotText
    dd SaffronCityRockerText
    dd SaffronCityRocket8Text
    dd SaffronCityRocket9Text
    dd SaffronCitySignText
    dd SaffronCityFightingDojoSignText
    dd SaffronCityGymSignText
    dd MartSignText
    dd SaffronCityTrainerTips1Text
    dd SaffronCityTrainerTips2Text
    dd SaffronCitySilphCoSignText
    dd PokeCenterSignText
    dd SaffronCityMrPsychicsHouseSignText
    dd SaffronCitySilphCoLatestProductSignText
SaffronCityRocket1Text:
    text_far _SaffronCityRocket1Text
    text_end
SaffronCityRocket2Text:
    text_far _SaffronCityRocket2Text
    text_end
SaffronCityRocket3Text:
    text_far _SaffronCityRocket3Text
    text_end
SaffronCityRocket4Text:
    text_far _SaffronCityRocket4Text
    text_end
SaffronCityRocket5Text:
    text_far _SaffronCityRocket5Text
    text_end
SaffronCityRocket6Text:
    text_far _SaffronCityRocket6Text
    text_end
SaffronCityRocket7Text:
    text_far _SaffronCityRocket7Text
    text_end
SaffronCityScientistText:
    text_far _SaffronCityScientistText
    text_end
SaffronCitySilphWorkerMText:
    text_far _SaffronCitySilphWorkerMText
    text_end
SaffronCitySilphWorkerFText:
    text_far _SaffronCitySilphWorkerFText
    text_end
SaffronCityGentlemanText:
    text_far _SaffronCityGentlemanText
    text_end
SaffronCityPidgeotText:
    text_far _SaffronCityPidgeotText
    sound_cry_pidgeot
    text_end
SaffronCityRockerText:
    text_far _SaffronCityRockerText
    text_end
SaffronCityRocket8Text:
    text_far _SaffronCityRocket8Text
    text_end
SaffronCityRocket9Text:
    text_far _SaffronCityRocket9Text
    text_end
SaffronCitySignText:
    text_far _SaffronCitySignText
    text_end
SaffronCityFightingDojoSignText:
    text_far _SaffronCityFightingDojoSignText
    text_end
SaffronCityGymSignText:
    text_far _SaffronCityGymSignText
    text_end
SaffronCityTrainerTips1Text:
    text_far _SaffronCityTrainerTips1Text
    text_end
SaffronCityTrainerTips2Text:
    text_far _SaffronCityTrainerTips2Text
    text_end
SaffronCitySilphCoSignText:
    text_far _SaffronCitySilphCoSignText
    text_end
SaffronCityMrPsychicsHouseSignText:
    text_far _SaffronCityMrPsychicsHouseSignText
    text_end
SaffronCitySilphCoLatestProductSignText:
    text_far _SaffronCitySilphCoLatestProductSignText
    text_end
