; IndigoPlateauLobby.asm — translated from pret scripts/IndigoPlateauLobby.asm by dos_port/tools/sm83xlat.
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


global IndigoPlateauLobbyChanseyText

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobbyClerkText   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobbyCooltrainerFText   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobbyGymGuideText   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobbyLinkReceptionistText   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobbyNurseText   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobby_Script   ; NOT YET DEFINED IN THE PORT
extern IndigoPlateauLobby_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PokecenterChanseyText   ; NOT YET DEFINED IN THE PORT
extern Serial_TryEstablishingExternallyClockedConnection   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_INDIGOPLATEAULOBBY_NURSE                  equ 1
TEXT_INDIGOPLATEAULOBBY_GYM_GUIDE              equ 2
TEXT_INDIGOPLATEAULOBBY_COOLTRAINER_F          equ 3
TEXT_INDIGOPLATEAULOBBY_CLERK                  equ 4
TEXT_INDIGOPLATEAULOBBY_LINK_RECEPTIONIST      equ 5
TEXT_INDIGOPLATEAULOBBY_CHANSEY                equ 6

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

; ---------------------------------------------------------------------------
; BAIL[event-range-macro] IndigoPlateauLobby_Script (scripts/IndigoPlateauLobby.asm:2-15) — at scripts/IndigoPlateauLobby.asm:14: ResetEventRange INDIGO_PLATEAU_EVENTS_START, EVENT_LANCES_ROOM_LOCK_DOOR
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call Serial_TryEstablishingExternallyClockedConnection
; PRET| 	call EnableAutoTextBoxDrawing
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_2, [hl]
; PRET| 	ret z
; PRET| 	ResetEvent EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH
; PRET| 	; Reset Elite Four events if the player started challenging them before
; PRET| 	ld hl, wElite4Flags
; PRET| 	bit BIT_STARTED_ELITE_4, [hl]
; PRET| 	res BIT_STARTED_ELITE_4, [hl]
; PRET| 	ret z
; PRET| 	ResetEventRange INDIGO_PLATEAU_EVENTS_START, EVENT_LANCES_ROOM_LOCK_DOOR
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[text-script-command-unported] IndigoPlateauLobby_TextPointers (scripts/IndigoPlateauLobby.asm:18-38) — at scripts/IndigoPlateauLobby.asm:27: script_pokecenter_nurse
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const IndigoPlateauLobbyNurseText,            TEXT_INDIGOPLATEAULOBBY_NURSE
; PRET| 	dw_const IndigoPlateauLobbyGymGuideText,         TEXT_INDIGOPLATEAULOBBY_GYM_GUIDE
; PRET| 	dw_const IndigoPlateauLobbyCooltrainerFText,     TEXT_INDIGOPLATEAULOBBY_COOLTRAINER_F
; PRET| 	dw_const IndigoPlateauLobbyClerkText,            TEXT_INDIGOPLATEAULOBBY_CLERK
; PRET| 	dw_const IndigoPlateauLobbyLinkReceptionistText, TEXT_INDIGOPLATEAULOBBY_LINK_RECEPTIONIST
; PRET| 	dw_const IndigoPlateauLobbyChanseyText,          TEXT_INDIGOPLATEAULOBBY_CHANSEY
; PRET| 
; PRET| IndigoPlateauLobbyNurseText:
; PRET| 	script_pokecenter_nurse
; PRET| 
; PRET| IndigoPlateauLobbyGymGuideText:
; PRET| 	text_far _IndigoPlateauLobbyGymGuideText
; PRET| 	text_end
; PRET| 
; PRET| IndigoPlateauLobbyCooltrainerFText:
; PRET| 	text_far _IndigoPlateauLobbyCooltrainerFText
; PRET| 	text_end
; PRET| 
; PRET| IndigoPlateauLobbyLinkReceptionistText:
; PRET| 	script_cable_club_receptionist

IndigoPlateauLobbyChanseyText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call PokecenterChanseyText
    jmp TextScriptEnd
