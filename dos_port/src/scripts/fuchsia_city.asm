; FuchsiaCity.asm — translated from pret scripts/FuchsiaCity.asm by dos_port/tools/sm83xlat.
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


global FuchsiaCityChanseySignText
global FuchsiaCityErikText
global FuchsiaCityFossilSignText
global FuchsiaCityGamblerText
global FuchsiaCityGymSignText
global FuchsiaCityKangaskhanSignText
global FuchsiaCityLaprasSignText
global FuchsiaCityPokemonText
global FuchsiaCitySafariGameSignText
global FuchsiaCitySafariZoneSignText
global FuchsiaCitySignText
global FuchsiaCitySlowpokeSignText
global FuchsiaCityVoltorbSignText
global FuchsiaCityWardensHomeSignText
global FuchsiaCityYoungster1Text
global FuchsiaCityYoungster2Text
global FuchsiaCity_Script
global FuchsiaCity_TextPointers

extern DisplayPokedex   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing
extern MartSignText   ; NOT YET DEFINED IN THE PORT
extern PokeCenterSignText   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern TextScriptEnd
extern _FuchsiaCityChanseySignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityErikText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityFossilSignKabutoText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityFossilSignOmanyteText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityFossilSignUndeterminedText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityGamblerText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityGymSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityKangaskhanSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityLaprasSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityPokemonText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCitySafariGameSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCitySafariZoneSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCitySignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCitySlowpokeSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityVoltorbSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityWardensHomeSignText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityYoungster1Text   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaCityYoungster2Text   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCity_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCity_TextPointers:
    dd FuchsiaCityYoungster1Text
    dd FuchsiaCityGamblerText
    dd FuchsiaCityErikText
    dd FuchsiaCityYoungster2Text
    dd FuchsiaCityPokemonText
    dd FuchsiaCityPokemonText
    dd FuchsiaCityPokemonText
    dd FuchsiaCityPokemonText
    dd FuchsiaCityPokemonText
    dd FuchsiaCityPokemonText
    dd FuchsiaCitySignText
    dd FuchsiaCitySignText
    dd FuchsiaCitySafariGameSignText
    dd MartSignText
    dd PokeCenterSignText
    dd FuchsiaCityWardensHomeSignText
    dd FuchsiaCitySafariZoneSignText
    dd FuchsiaCityGymSignText
    dd FuchsiaCityChanseySignText
    dd FuchsiaCityVoltorbSignText
    dd FuchsiaCityKangaskhanSignText
    dd FuchsiaCitySlowpokeSignText
    dd FuchsiaCityLaprasSignText
    dd FuchsiaCityFossilSignText
FuchsiaCityYoungster1Text:
    text_far _FuchsiaCityYoungster1Text
    text_end
FuchsiaCityGamblerText:
    text_far _FuchsiaCityGamblerText
    text_end
FuchsiaCityErikText:
    text_far _FuchsiaCityErikText
    text_end
FuchsiaCityYoungster2Text:
    text_far _FuchsiaCityYoungster2Text
    text_end
FuchsiaCityPokemonText:
    text_far _FuchsiaCityPokemonText
    text_end
FuchsiaCitySignText:
    text_far _FuchsiaCitySignText
    text_end
FuchsiaCitySafariGameSignText:
    text_far _FuchsiaCitySafariGameSignText
    text_end
FuchsiaCityWardensHomeSignText:
    text_far _FuchsiaCityWardensHomeSignText
    text_end
FuchsiaCitySafariZoneSignText:
    text_far _FuchsiaCitySafariZoneSignText
    text_end
FuchsiaCityGymSignText:
    text_far _FuchsiaCityGymSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCityChanseySignText:
    mov esi, .Text
    call PrintText
    mov al, 40
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaCityChanseySignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCityVoltorbSignText:
    mov esi, .Text
    call PrintText
    mov al, 6
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaCityVoltorbSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCityKangaskhanSignText:
    mov esi, .Text
    call PrintText
    mov al, 2
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaCityKangaskhanSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCitySlowpokeSignText:
    mov esi, .Text
    call PrintText
    mov al, 37
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaCitySlowpokeSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCityLaprasSignText:
    mov esi, .Text
    call PrintText
    mov al, 19
    call DisplayPokedex
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _FuchsiaCityLaprasSignText
    text_end

%assign event_byte -1
%assign event_byte_a -1
FuchsiaCityFossilSignText:
    CheckEvent EVENT_GOT_DOME_FOSSIL
    jnz .got_dome_fossil
    CheckEventReuseA EVENT_GOT_HELIX_FOSSIL
    jnz .got_helix_fossil
    mov esi, .UndeterminedText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_dome_fossil:
    mov esi, .OmanyteText
    call PrintText
    mov al, 98
    jmp .display

%assign event_byte -1
%assign event_byte_a -1
.got_helix_fossil:
    mov esi, .KabutoText
    call PrintText
    mov al, 90
.display:
    call DisplayPokedex
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.OmanyteText:
    text_far _FuchsiaCityFossilSignOmanyteText
    text_end
.KabutoText:
    text_far _FuchsiaCityFossilSignKabutoText
    text_end
.UndeterminedText:
    text_far _FuchsiaCityFossilSignUndeterminedText
    text_end
