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


global MrFujisHouseLittleGirlText
global MrFujisHouseMrFujiPokedexText
global MrFujisHouseMrFujiText
global MrFujisHouseNidorinoText
global MrFujisHousePsyduckText
global MrFujisHouseSuperNerdText
global MrFujisHouse_Script
global MrFujisHouse_TextPointers

extern EnableAutoTextBoxDrawing
extern GiveItem
extern PlayCry
extern PrintText
extern TextScriptEnd
extern _MrFujisHouseLittleGirlPokemonAreNiceToHugText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseLittleGirlThisIsMrFujisHouseText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiHasMyFluteHelpedYouText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiPokeFluteExplanationText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiPokeFluteNoRoomText   ; NOT YET DEFINED IN THE PORT
extern _MrFujisHouseMrFujiPokedexText   ; NOT YET DEFINED IN THE PORT
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

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouse_TextPointers:
    dd MrFujisHouseSuperNerdText
    dd MrFujisHouseLittleGirlText
    dd MrFujisHousePsyduckText
    dd MrFujisHouseNidorinoText
    dd MrFujisHouseMrFujiText
    dd MrFujisHouseMrFujiPokedexText

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouseSuperNerdText:
    CheckEvent EVENT_RESCUED_MR_FUJI
    jnz .rescued_mr_fuji
    mov esi, .MrFujiIsntHereText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.rescued_mr_fuji:
    mov esi, .MrFujiHadBeenPrayingText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.MrFujiIsntHereText:
    text_far _MrFujisHouseSuperNerdMrFujiIsntHereText
    text_end
.MrFujiHadBeenPrayingText:
    text_far _MrFujisHouseSuperNerdMrFujiHadBeenPrayingText
    text_end

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouseLittleGirlText:
    CheckEvent EVENT_RESCUED_MR_FUJI
    jnz .rescued_mr_fuji
    mov esi, .ThisIsMrFujisHouseText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.rescued_mr_fuji:
    mov esi, .PokemonAreNiceToHugText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ThisIsMrFujisHouseText:
    text_far _MrFujisHouseLittleGirlThisIsMrFujisHouseText
    text_end
.PokemonAreNiceToHugText:
    text_far _MrFujisHouseLittleGirlPokemonAreNiceToHugText
    text_end
MrFujisHousePsyduckText:
    text_far _MrFujisHousePsyduckText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 47
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouseNidorinoText:
    text_far _MrFujisHouseNidorinoText

%assign event_byte -1
%assign event_byte_a -1
    mov al, 167
    call PlayCry
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
MrFujisHouseMrFujiText:
    CheckEvent EVENT_GOT_POKE_FLUTE
    jnz .got_item
    mov esi, .IThinkThisMayHelpYourQuestText
    call PrintText
    mov bx, ((73) << 8) | (1)
    call GiveItem
    jae .bag_full
    mov esi, .ReceivedPokeFluteText
    call PrintText
    SetEvent EVENT_GOT_POKE_FLUTE
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.bag_full:
    mov esi, .PokeFluteNoRoomText
    call PrintText
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.got_item:
    mov esi, .HasMyFluteHelpedYouText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.IThinkThisMayHelpYourQuestText:
    text_far _MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText
    text_end
.ReceivedPokeFluteText:
    text_far _MrFujisHouseMrFujiReceivedPokeFluteText
    sound_get_key_item
    text_far _MrFujisHouseMrFujiPokeFluteExplanationText
    text_end
.PokeFluteNoRoomText:
    text_far _MrFujisHouseMrFujiPokeFluteNoRoomText
    text_end
.HasMyFluteHelpedYouText:
    text_far _MrFujisHouseMrFujiHasMyFluteHelpedYouText
    text_end
MrFujisHouseMrFujiPokedexText:
    text_far _MrFujisHouseMrFujiPokedexText
    text_end
