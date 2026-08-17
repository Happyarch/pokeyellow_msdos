; LavenderTown.asm — translated from pret scripts/LavenderTown.asm by dos_port/tools/sm83xlat.
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


global LavenderTownCooltrainerMText
global LavenderTownLittleGirlText
global LavenderTownPokemonHouseSignText
global LavenderTownPokemonTowerSignText
global LavenderTownSignText
global LavenderTownSilphScopeSignText
global LavenderTownSuperNerdText
global LavenderTown_Script
global LavenderTown_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownCooltrainerMText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownLittleGirlDoYouBelieveInGhostsText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownLittleGirlHaHaGuessNotText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownLittleGirlSoThereAreBelieversText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownPokemonHouseSignText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownPokemonTowerSignText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownSignText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownSilphScopeSignText   ; NOT YET DEFINED IN THE PORT
extern _LavenderTownSuperNerdText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
LavenderTown_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
LavenderTown_TextPointers:
    dd LavenderTownLittleGirlText
    dd LavenderTownCooltrainerMText
    dd LavenderTownSuperNerdText
    dd LavenderTownSignText
    dd LavenderTownSilphScopeSignText
    dd MartSignText
    dd PokeCenterSignText
    dd LavenderTownPokemonHouseSignText
    dd LavenderTownPokemonTowerSignText

%assign event_byte -1
%assign event_byte_a -1
LavenderTownLittleGirlText:
    mov esi, .DoYouBelieveInGhostsText
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    mov esi, .HaHaGuessNotText
    jnz .got_text
    mov esi, .SoThereAreBelieversText
.got_text:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.DoYouBelieveInGhostsText:
    text_far _LavenderTownLittleGirlDoYouBelieveInGhostsText
    text_end
.SoThereAreBelieversText:
    text_far _LavenderTownLittleGirlSoThereAreBelieversText
    text_end
.HaHaGuessNotText:
    text_far _LavenderTownLittleGirlHaHaGuessNotText
    text_end
LavenderTownCooltrainerMText:
    text_far _LavenderTownCooltrainerMText
    text_end
LavenderTownSuperNerdText:
    text_far _LavenderTownSuperNerdText
    text_end
LavenderTownSignText:
    text_far _LavenderTownSignText
    text_end
LavenderTownSilphScopeSignText:
    text_far _LavenderTownSilphScopeSignText
    text_end
LavenderTownPokemonHouseSignText:
    text_far _LavenderTownPokemonHouseSignText
    text_end
LavenderTownPokemonTowerSignText:
    text_far _LavenderTownPokemonTowerSignText
    text_end
