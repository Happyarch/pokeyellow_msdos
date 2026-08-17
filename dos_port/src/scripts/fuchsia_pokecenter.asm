; FuchsiaPokecenter.asm — translated from pret scripts/FuchsiaPokecenter.asm by dos_port/tools/sm83xlat.
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


global FuchsiaPokecenterChanseyText
global FuchsiaPokecenterCooltrainerFText
global FuchsiaPokecenterLinkReceptionistText
global FuchsiaPokecenterNurseText
global FuchsiaPokecenterRockerText
global FuchsiaPokecenter_Script
global FuchsiaPokecenter_TextPointers

extern Bankswitch
extern EnableAutoTextBoxDrawing
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd
extern _FuchsiaPokecenterCooltrainerFText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaPokecenterRockerText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
FuchsiaPokecenter_Script:
    call Serial_TryEstablishingExternallyClockedConnection
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
FuchsiaPokecenter_TextPointers:
    dd FuchsiaPokecenterNurseText
    dd FuchsiaPokecenterRockerText
    dd FuchsiaPokecenterCooltrainerFText
    dd FuchsiaPokecenterLinkReceptionistText
    dd FuchsiaPokecenterChanseyText
FuchsiaPokecenterNurseText:
    script_pokecenter_nurse
FuchsiaPokecenterRockerText:
    text_far _FuchsiaPokecenterRockerText
    text_end
FuchsiaPokecenterCooltrainerFText:
    text_far _FuchsiaPokecenterCooltrainerFText
    text_end
FuchsiaPokecenterLinkReceptionistText:
    script_cable_club_receptionist

%assign event_byte -1
%assign event_byte_a -1
FuchsiaPokecenterChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd
