; CeladonPokecenter.asm — translated from pret scripts/CeladonPokecenter.asm by dos_port/tools/sm83xlat.
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


global CeladonPokecenterBeautyText
global CeladonPokecenterChanseyText
global CeladonPokecenterGentlemanText
global CeladonPokecenterLinkReceptionistText
global CeladonPokecenterNurseText
global CeladonPokecenter_Script
global CeladonPokecenter_TextPointers

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CeladonPokecenterBeautyText   ; NOT YET DEFINED IN THE PORT
extern _CeladonPokecenterGentlemanText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeladonPokecenter_Script:
    call Serial_TryEstablishingExternallyClockedConnection
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
CeladonPokecenter_TextPointers:
    dd CeladonPokecenterNurseText
    dd CeladonPokecenterGentlemanText
    dd CeladonPokecenterBeautyText
    dd CeladonPokecenterLinkReceptionistText
    dd CeladonPokecenterChanseyText
CeladonPokecenterLinkReceptionistText:
    script_cable_club_receptionist
CeladonPokecenterNurseText:
    script_pokecenter_nurse
CeladonPokecenterGentlemanText:
    text_far _CeladonPokecenterGentlemanText
    text_end
CeladonPokecenterBeautyText:
    text_far _CeladonPokecenterBeautyText
    text_end

%assign event_byte -1
%assign event_byte_a -1
CeladonPokecenterChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd
