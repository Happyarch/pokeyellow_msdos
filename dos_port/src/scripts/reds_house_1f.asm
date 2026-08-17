; RedsHouse1F.asm — translated from pret scripts/RedsHouse1F.asm, scripts/RedsHouse1F_2.asm by dos_port/tools/sm83xlat.
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
%include "assets/script_constants.inc"

%include "assets/audio_constants.inc"

global RedsHouse1FMomHealScript
global RedsHouse1FMomLookingGreatText
global RedsHouse1FMomText
global RedsHouse1FMomYouShouldRestText
global RedsHouse1FPrintMomText
global RedsHouse1FPrintTVText
global RedsHouse1FTVText
global RedsHouse1F_Script
global RedsHouse1F_TextPointers

extern Bankswitch
extern EnableAutoTextBoxDrawing
extern GBFadeInFromWhite
extern GBFadeOutToWhite
extern HealParty
extern PlaySound
extern PrintText
extern ReloadMapData
extern TextScriptEnd
extern _RedsHouse1FMomLookingGreatText   ; NOT YET DEFINED IN THE PORT
extern _RedsHouse1FMomWakeUpText   ; NOT YET DEFINED IN THE PORT
extern _RedsHouse1FMomYouShouldRestText   ; NOT YET DEFINED IN THE PORT
extern _RedsHouse1FTVStandByMeMovieText   ; NOT YET DEFINED IN THE PORT
extern _RedsHouse1FTVWrongSideText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1F_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1F_TextPointers:
    dd RedsHouse1FMomText
    dd RedsHouse1FTVText

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FMomText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RedsHouse1FPrintMomText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FTVText:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RedsHouse1FPrintTVText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FPrintMomText:
    mov al, [ebp + wStatusFlags4]
    test al, (1 << (BIT_GOT_STARTER))
    jnz RedsHouse1FMomHealScript
    mov esi, .WakeUpText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.WakeUpText:
    text_far _RedsHouse1FMomWakeUpText
    text_end

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FMomHealScript:
    mov esi, RedsHouse1FMomYouShouldRestText
    call PrintText
    call GBFadeOutToWhite
    call ReloadMapData
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HealParty
    mov al, MUSIC_PKMN_HEALED
    mov [ebp + wNewSoundID], al
    call PlaySound
.next:
    mov al, [ebp + wChannelSoundIDs]
    cmp al, MUSIC_PKMN_HEALED
    jz .next
    mov al, [ebp + wMapMusicSoundID]
    mov [ebp + wNewSoundID], al
    call PlaySound
    call GBFadeInFromWhite
    mov esi, RedsHouse1FMomLookingGreatText
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FMomYouShouldRestText:
    text_far _RedsHouse1FMomYouShouldRestText
    text_end
RedsHouse1FMomLookingGreatText:
    text_far _RedsHouse1FMomLookingGreatText
    text_end

%assign event_byte -1
%assign event_byte_a -1
RedsHouse1FPrintTVText:
    mov esi, .WrongSideText
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jnz .got_text
    mov esi, .StandByMeMovieText
.got_text:
    call PrintText
    ret

%assign event_byte -1
%assign event_byte_a -1
.StandByMeMovieText:
    text_far _RedsHouse1FTVStandByMeMovieText
    text_end
.WrongSideText:
    text_far _RedsHouse1FTVWrongSideText
    text_end
