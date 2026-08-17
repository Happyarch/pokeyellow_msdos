; VermilionPokecenter.asm — translated from pret scripts/VermilionPokecenter.asm by dos_port/tools/sm83xlat.
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


global VermilionPokecenterChanseyText
global VermilionPokecenter_Script

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern VermilionPokecenterFishingGuruText   ; NOT YET DEFINED IN THE PORT
extern VermilionPokecenterLinkReceptionistText   ; NOT YET DEFINED IN THE PORT
extern VermilionPokecenterNurseText   ; NOT YET DEFINED IN THE PORT
extern VermilionPokecenterSailorText   ; NOT YET DEFINED IN THE PORT
extern VermilionPokecenter_TextPointers   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_VERMILIONPOKECENTER_NURSE                 equ 1
TEXT_VERMILIONPOKECENTER_FISHING_GURU          equ 2
TEXT_VERMILIONPOKECENTER_SAILOR                equ 3
TEXT_VERMILIONPOKECENTER_LINK_RECEPTIONIST     equ 4
TEXT_VERMILIONPOKECENTER_CHANSEY               equ 5

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
VermilionPokecenter_Script:
    call Serial_TryEstablishingExternallyClockedConnection
    jmp EnableAutoTextBoxDrawing

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] VermilionPokecenter_TextPointers (scripts/VermilionPokecenter.asm:6-25) — at scripts/VermilionPokecenter.asm:14: script_pokecenter_nurse
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const VermilionPokecenterNurseText,            TEXT_VERMILIONPOKECENTER_NURSE
; PRET| 	dw_const VermilionPokecenterFishingGuruText,      TEXT_VERMILIONPOKECENTER_FISHING_GURU
; PRET| 	dw_const VermilionPokecenterSailorText,           TEXT_VERMILIONPOKECENTER_SAILOR
; PRET| 	dw_const VermilionPokecenterLinkReceptionistText, TEXT_VERMILIONPOKECENTER_LINK_RECEPTIONIST
; PRET| 	dw_const VermilionPokecenterChanseyText,          TEXT_VERMILIONPOKECENTER_CHANSEY
; PRET| 
; PRET| VermilionPokecenterNurseText:
; PRET| 	script_pokecenter_nurse
; PRET| 
; PRET| VermilionPokecenterFishingGuruText:
; PRET| 	text_far _VermilionPokecenterFishingGuruText
; PRET| 	text_end
; PRET| 
; PRET| VermilionPokecenterSailorText:
; PRET| 	text_far _VermilionPokecenterSailorText
; PRET| 	text_end
; PRET| 
; PRET| VermilionPokecenterLinkReceptionistText:
; PRET| 	script_cable_club_receptionist

%assign event_byte -1
VermilionPokecenterChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd
