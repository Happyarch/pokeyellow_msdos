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


global SaffronCity_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityFightingDojoSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityGentlemanText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityMrPsychicsHouseSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityPidgeotText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRockerText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket1Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket2Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket3Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket4Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket5Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket6Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket7Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket8Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityRocket9Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityScientistText   ; NOT YET DEFINED IN THE PORT
extern SaffronCitySignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCitySilphCoLatestProductSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCitySilphCoSignText   ; NOT YET DEFINED IN THE PORT
extern SaffronCitySilphWorkerFText   ; NOT YET DEFINED IN THE PORT
extern SaffronCitySilphWorkerMText   ; NOT YET DEFINED IN THE PORT
extern SaffronCityTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCityTrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern SaffronCity_TextPointers   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityGentlemanText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityPidgeotText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket1Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket2Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket3Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket4Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket5Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket6Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityRocket7Text   ; NOT YET DEFINED IN THE PORT
extern _SaffronCityScientistText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphWorkerFText   ; NOT YET DEFINED IN THE PORT
extern _SaffronCitySilphWorkerMText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_SAFFRONCITY_ROCKET1                       equ 1
TEXT_SAFFRONCITY_ROCKET2                       equ 2
TEXT_SAFFRONCITY_ROCKET3                       equ 3
TEXT_SAFFRONCITY_ROCKET4                       equ 4
TEXT_SAFFRONCITY_ROCKET5                       equ 5
TEXT_SAFFRONCITY_ROCKET6                       equ 6
TEXT_SAFFRONCITY_ROCKET7                       equ 7
TEXT_SAFFRONCITY_SCIENTIST                     equ 8
TEXT_SAFFRONCITY_SILPH_WORKER_M                equ 9
TEXT_SAFFRONCITY_SILPH_WORKER_F                equ 10
TEXT_SAFFRONCITY_GENTLEMAN                     equ 11
TEXT_SAFFRONCITY_PIDGEOT                       equ 12
TEXT_SAFFRONCITY_ROCKER                        equ 13
TEXT_SAFFRONCITY_ROCKET8                       equ 14
TEXT_SAFFRONCITY_ROCKET9                       equ 15
TEXT_SAFFRONCITY_SIGN                          equ 16
TEXT_SAFFRONCITY_FIGHTING_DOJO_SIGN            equ 17
TEXT_SAFFRONCITY_GYM_SIGN                      equ 18
TEXT_SAFFRONCITY_MART_SIGN                     equ 19
TEXT_SAFFRONCITY_TRAINER_TIPS1                 equ 20
TEXT_SAFFRONCITY_TRAINER_TIPS2                 equ 21
TEXT_SAFFRONCITY_SILPH_CO_SIGN                 equ 22
TEXT_SAFFRONCITY_POKECENTER_SIGN               equ 23
TEXT_SAFFRONCITY_MR_PSYCHICS_HOUSE_SIGN        equ 24
TEXT_SAFFRONCITY_SILPH_CO_LATEST_PRODUCT_SIGN  equ 25

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SaffronCity_Script:
    jmp EnableAutoTextBoxDrawing

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] SaffronCity_TextPointers (scripts/SaffronCity.asm:5-123) — at scripts/SaffronCity.asm:78: sound_cry_pidgeot
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const SaffronCityRocket1Text,                  TEXT_SAFFRONCITY_ROCKET1
; PRET| 	dw_const SaffronCityRocket2Text,                  TEXT_SAFFRONCITY_ROCKET2
; PRET| 	dw_const SaffronCityRocket3Text,                  TEXT_SAFFRONCITY_ROCKET3
; PRET| 	dw_const SaffronCityRocket4Text,                  TEXT_SAFFRONCITY_ROCKET4
; PRET| 	dw_const SaffronCityRocket5Text,                  TEXT_SAFFRONCITY_ROCKET5
; PRET| 	dw_const SaffronCityRocket6Text,                  TEXT_SAFFRONCITY_ROCKET6
; PRET| 	dw_const SaffronCityRocket7Text,                  TEXT_SAFFRONCITY_ROCKET7
; PRET| 	dw_const SaffronCityScientistText,                TEXT_SAFFRONCITY_SCIENTIST
; PRET| 	dw_const SaffronCitySilphWorkerMText,             TEXT_SAFFRONCITY_SILPH_WORKER_M
; PRET| 	dw_const SaffronCitySilphWorkerFText,             TEXT_SAFFRONCITY_SILPH_WORKER_F
; PRET| 	dw_const SaffronCityGentlemanText,                TEXT_SAFFRONCITY_GENTLEMAN
; PRET| 	dw_const SaffronCityPidgeotText,                  TEXT_SAFFRONCITY_PIDGEOT
; PRET| 	dw_const SaffronCityRockerText,                   TEXT_SAFFRONCITY_ROCKER
; PRET| 	dw_const SaffronCityRocket8Text,                  TEXT_SAFFRONCITY_ROCKET8
; PRET| 	dw_const SaffronCityRocket9Text,                  TEXT_SAFFRONCITY_ROCKET9
; PRET| 	dw_const SaffronCitySignText,                     TEXT_SAFFRONCITY_SIGN
; PRET| 	dw_const SaffronCityFightingDojoSignText,         TEXT_SAFFRONCITY_FIGHTING_DOJO_SIGN
; PRET| 	dw_const SaffronCityGymSignText,                  TEXT_SAFFRONCITY_GYM_SIGN
; PRET| 	dw_const MartSignText,                            TEXT_SAFFRONCITY_MART_SIGN
; PRET| 	dw_const SaffronCityTrainerTips1Text,             TEXT_SAFFRONCITY_TRAINER_TIPS1
; PRET| 	dw_const SaffronCityTrainerTips2Text,             TEXT_SAFFRONCITY_TRAINER_TIPS2
; PRET| 	dw_const SaffronCitySilphCoSignText,              TEXT_SAFFRONCITY_SILPH_CO_SIGN
; PRET| 	dw_const PokeCenterSignText,                      TEXT_SAFFRONCITY_POKECENTER_SIGN
; PRET| 	dw_const SaffronCityMrPsychicsHouseSignText,      TEXT_SAFFRONCITY_MR_PSYCHICS_HOUSE_SIGN
; PRET| 	dw_const SaffronCitySilphCoLatestProductSignText, TEXT_SAFFRONCITY_SILPH_CO_LATEST_PRODUCT_SIGN
; PRET| 
; PRET| SaffronCityRocket1Text:
; PRET| 	text_far _SaffronCityRocket1Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket2Text:
; PRET| 	text_far _SaffronCityRocket2Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket3Text:
; PRET| 	text_far _SaffronCityRocket3Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket4Text:
; PRET| 	text_far _SaffronCityRocket4Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket5Text:
; PRET| 	text_far _SaffronCityRocket5Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket6Text:
; PRET| 	text_far _SaffronCityRocket6Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket7Text:
; PRET| 	text_far _SaffronCityRocket7Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityScientistText:
; PRET| 	text_far _SaffronCityScientistText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCitySilphWorkerMText:
; PRET| 	text_far _SaffronCitySilphWorkerMText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCitySilphWorkerFText:
; PRET| 	text_far _SaffronCitySilphWorkerFText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityGentlemanText:
; PRET| 	text_far _SaffronCityGentlemanText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityPidgeotText:
; PRET| 	text_far _SaffronCityPidgeotText
; PRET| 	sound_cry_pidgeot
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRockerText:
; PRET| 	text_far _SaffronCityRockerText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket8Text:
; PRET| 	text_far _SaffronCityRocket8Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityRocket9Text:
; PRET| 	text_far _SaffronCityRocket9Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCitySignText:
; PRET| 	text_far _SaffronCitySignText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityFightingDojoSignText:
; PRET| 	text_far _SaffronCityFightingDojoSignText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityGymSignText:
; PRET| 	text_far _SaffronCityGymSignText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityTrainerTips1Text:
; PRET| 	text_far _SaffronCityTrainerTips1Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityTrainerTips2Text:
; PRET| 	text_far _SaffronCityTrainerTips2Text
; PRET| 	text_end
; PRET| 
; PRET| SaffronCitySilphCoSignText:
; PRET| 	text_far _SaffronCitySilphCoSignText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCityMrPsychicsHouseSignText:
; PRET| 	text_far _SaffronCityMrPsychicsHouseSignText
; PRET| 	text_end
; PRET| 
; PRET| SaffronCitySilphCoLatestProductSignText:
; PRET| 	text_far _SaffronCitySilphCoLatestProductSignText
; PRET| 	text_end
