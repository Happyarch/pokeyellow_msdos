; NameRatersHouse.asm — translated from pret scripts/NameRatersHouse.asm by dos_port/tools/sm83xlat.
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


global NameRatersHouseNameRaterText
global NameRatersHouseYesNoScript
global NameRatersHouse_Script
global NameRatersHouse_TextPointers

extern AddNTimes   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern DisplayNameRaterScreen   ; NOT YET DEFINED IN THE PORT
extern DisplayPartyMenu   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GBPalWhiteOutWithDelay3   ; NOT YET DEFINED IN THE PORT
extern GetPartyMonName2   ; NOT YET DEFINED IN THE PORT
extern LoadGBPal   ; NOT YET DEFINED IN THE PORT
extern NameRatersHouseCheckMonOTScript   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RestoreScreenTilesAndReloadTilePatterns   ; NOT YET DEFINED IN THE PORT
extern SaveScreenTilesToBuffer2   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterATrulyImpeccableNameText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterComeAnyTimeYouLikeText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterGiveItANiceNameText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterPokemonHasBeenRenamedText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterWantMeToRateText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterWhatShouldWeNameItText   ; NOT YET DEFINED IN THE PORT
extern _NameRatersHouseNameRaterWhichPokemonText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
NameRatersHouse_Script:
    jmp EnableAutoTextBoxDrawing

%assign event_byte -1
%assign event_byte_a -1
NameRatersHouseYesNoScript:
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] NameRatersHouseCheckMonOTScript (scripts/NameRatersHouse.asm:13-36) — at scripts/NameRatersHouse.asm:19: .check_match_loop is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wPartyMonOT
; PRET| 	ld bc, NAME_LENGTH
; PRET| 	ld a, [wWhichPokemon]
; PRET| 	call AddNTimes
; PRET| 	ld de, wPlayerName
; PRET| 	ld c, NAME_LENGTH
; PRET| 	call .check_match_loop
; PRET| 	jr c, .no_match
; PRET| 	ld hl, wPartyMon1OTID
; PRET| 	ld bc, PARTYMON_STRUCT_LENGTH
; PRET| 	ld a, [wWhichPokemon]
; PRET| 	call AddNTimes
; PRET| 	ld de, wPlayerID
; PRET| 	ld c, $2
; PRET| .check_match_loop
; PRET| 	ld a, [de]
; PRET| 	cp [hl]
; PRET| 	jr nz, .no_match
; PRET| 	inc hl
; PRET| 	inc de
; PRET| 	dec c
; PRET| 	jr nz, .check_match_loop
; PRET| 	and a
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
.no_match:
    stc
    ret

%assign event_byte -1
%assign event_byte_a -1
NameRatersHouse_TextPointers:
    dd NameRatersHouseNameRaterText

%assign event_byte -1
%assign event_byte_a -1
NameRatersHouseNameRaterText:
    call SaveScreenTilesToBuffer2
    mov esi, .WantMeToRateText
    call NameRatersHouseYesNoScript
    jnz .did_not_rename
    mov esi, .WhichPokemonText
    call PrintText
    xor al, al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    mov [ebp + wUpdateSpritesEnabled], al
    mov [ebp + wMenuItemToSwap], al
    call DisplayPartyMenu
    pushfd
    push eax
    call GBPalWhiteOutWithDelay3
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadGBPal
    pop eax
    popfd
    jb .did_not_rename
    call GetPartyMonName2
    call NameRatersHouseCheckMonOTScript
    mov esi, .ATrulyImpeccableNameText
    jb .done
    mov esi, .GiveItANiceNameText
    call NameRatersHouseYesNoScript
    jnz .did_not_rename
    mov esi, .WhatShouldWeNameItText
    call PrintText
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call DisplayNameRaterScreen
    jb .did_not_rename
    mov esi, .PokemonHasBeenRenamedText
.done:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.did_not_rename:
    mov esi, .ComeAnyTimeYouLikeText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.WantMeToRateText:
    text_far _NameRatersHouseNameRaterWantMeToRateText
    text_end
.WhichPokemonText:
    text_far _NameRatersHouseNameRaterWhichPokemonText
    text_end
.GiveItANiceNameText:
    text_far _NameRatersHouseNameRaterGiveItANiceNameText
    text_end
.WhatShouldWeNameItText:
    text_far _NameRatersHouseNameRaterWhatShouldWeNameItText
    text_end
.PokemonHasBeenRenamedText:
    text_far _NameRatersHouseNameRaterPokemonHasBeenRenamedText
    text_end
.ComeAnyTimeYouLikeText:
    text_far _NameRatersHouseNameRaterComeAnyTimeYouLikeText
    text_end
.ATrulyImpeccableNameText:
    text_far _NameRatersHouseNameRaterATrulyImpeccableNameText
    text_end
