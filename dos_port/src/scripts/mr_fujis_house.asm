; MrFujisHouse.asm — translated from pret scripts/MrFujisHouse.asm by dos_port/tools/sm83xlat.
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


global MrFujisHouseNidorinoText
global MrFujisHousePsyduckText
global MrFujisHouse_Script
global MrFujisHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern MrFujisHouseLittleGirlText   ; NOT YET DEFINED IN THE PORT
extern MrFujisHouseMrFujiPokedexText   ; NOT YET DEFINED IN THE PORT
extern MrFujisHouseMrFujiText   ; NOT YET DEFINED IN THE PORT
extern MrFujisHouseSuperNerdText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseLittleGirlPokemonAreNiceToHugText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseLittleGirlThisIsMrFujisHouseText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiReceivedPokeFluteText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseNidorinoText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHousePsyduckText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseSuperNerdMrFujiHadBeenPrayingText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseSuperNerdMrFujiIsntHereText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

MrFujisHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

MrFujisHouse_TextPointers:
    dd MrFujisHouseSuperNerdText
    dd MrFujisHouseLittleGirlText
    dd MrFujisHousePsyduckText
    dd MrFujisHouseNidorinoText
    dd MrFujisHouseMrFujiText
    dd MrFujisHouseMrFujiPokedexText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrFujisHouseSuperNerdText (scripts/MrFujisHouse.asm:16-20) — at scripts/MrFujisHouse.asm:17: .rescued_mr_fuji is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_RESCUED_MR_FUJI
; PRET| 	jr nz, .rescued_mr_fuji
; PRET| 	ld hl, .MrFujiIsntHereText
; PRET| 	call PrintText
; PRET| 	jr .done

.rescued_mr_fuji:
    mov esi, .MrFujiHadBeenPrayingText
    call PrintText
.done:
    jmp TextScriptEnd

.MrFujiIsntHereText:
    text_far _MrFujisHouseSuperNerdMrFujiIsntHereText
    text_end
.MrFujiHadBeenPrayingText:
    text_far _MrFujisHouseSuperNerdMrFujiHadBeenPrayingText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrFujisHouseLittleGirlText (scripts/MrFujisHouse.asm:37-41) — at scripts/MrFujisHouse.asm:38: .rescued_mr_fuji is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_RESCUED_MR_FUJI
; PRET| 	jr nz, .rescued_mr_fuji
; PRET| 	ld hl, .ThisIsMrFujisHouseText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] MrFujisHouseLittleGirlText.rescued_mr_fuji (scripts/MrFujisHouse.asm:43-46)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PokemonAreNiceToHugText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

.ThisIsMrFujisHouseText:
    text_far _MrFujisHouseLittleGirlThisIsMrFujisHouseText
    text_end
.PokemonAreNiceToHugText:
    text_far _MrFujisHouseLittleGirlPokemonAreNiceToHugText
    text_end
MrFujisHousePsyduckText:
    text_far _MrFujisHousePsyduckText

    mov al, 47
    call PlayCry
    jmp TextScriptEnd

MrFujisHouseNidorinoText:
    text_far _MrFujisHouseNidorinoText

    mov al, 167
    call PlayCry
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrFujisHouseMrFujiText (scripts/MrFujisHouse.asm:72-82) — at scripts/MrFujisHouse.asm:73: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_POKE_FLUTE
; PRET| 	jr nz, .got_item
; PRET| 	ld hl, .IThinkThisMayHelpYourQuestText
; PRET| 	call PrintText
; PRET| 	lb bc, POKE_FLUTE, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedPokeFluteText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_POKE_FLUTE
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrFujisHouseMrFujiText.bag_full (scripts/MrFujisHouse.asm:84-86) — at scripts/MrFujisHouse.asm:84: .PokeFluteNoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PokeFluteNoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] MrFujisHouseMrFujiText.got_item (scripts/MrFujisHouse.asm:88-91) — at scripts/MrFujisHouse.asm:88: .HasMyFluteHelpedYouText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HasMyFluteHelpedYouText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] MrFujisHouseMrFujiText.IThinkThisMayHelpYourQuestText (scripts/MrFujisHouse.asm:94-113) — at scripts/MrFujisHouse.asm:99: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedPokeFluteText:
; PRET| 	text_far _MrFujisHouseMrFujiReceivedPokeFluteText
; PRET| 	sound_get_key_item
; PRET| 	text_far _MrFujisHouseMrFujiPokeFluteExplanationText
; PRET| 	text_end
; PRET| 
; PRET| .PokeFluteNoRoomText:
; PRET| 	text_far _MrFujisHouseMrFujiPokeFluteNoRoomText
; PRET| 	text_end
; PRET| 
; PRET| .HasMyFluteHelpedYouText:
; PRET| 	text_far _MrFujisHouseMrFujiHasMyFluteHelpedYouText
; PRET| 	text_end
; PRET| 
; PRET| MrFujisHouseMrFujiPokedexText:
; PRET| 	text_far _MrFujisHouseMrFujiPokedexText
; PRET| 	text_end
