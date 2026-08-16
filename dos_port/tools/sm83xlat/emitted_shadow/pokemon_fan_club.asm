; PokemonFanClub.asm — translated from pret scripts/PokemonFanClub.asm by dos_port/tools/sm83xlat.
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


global PokemonFanClubClefairyText
global PokemonFanClubPikachuMovementData
global PokemonFanClubScript0
global PokemonFanClubScript1
global PokemonFanClubScript_59a39
global PokemonFanClubSeelText
global PokemonFanClub_Script
global PokemonFanClub_ScriptPointers
global PokemonFanClub_TextPointers

extern ApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern CheckPikachuStatusCondition   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisablePikachuFollowingPlayer   ; NOT YET DEFINED IN THE PORT
extern DisplayPartyMenu   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern GBPalNormal   ; NOT YET DEFINED IN THE PORT
extern GBPalWhiteOutWithDelay3   ; NOT YET DEFINED IN THE PORT
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern LoadCurrentMapView   ; NOT YET DEFINED IN THE PORT
extern LoadGBPal   ; NOT YET DEFINED IN THE PORT
extern LoadScreenTilesFromBuffer2   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern PokemonFanClubChairmanText   ; NOT YET DEFINED IN THE PORT
extern PokemonFanClubClefairyFanText   ; NOT YET DEFINED IN THE PORT
extern PokemonFanClubReceptionistText   ; NOT YET DEFINED IN THE PORT
extern PokemonFanClubScript_59a44   ; NOT YET DEFINED IN THE PORT
extern PokemonFanClubSeelFanText   ; NOT YET DEFINED IN THE PORT
extern PrintFanClubPortrait   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Random   ; NOT YET DEFINED IN THE PORT
extern ReloadTilesetTilePatterns   ; NOT YET DEFINED IN THE PORT
extern RestoreScreenTilesAndReloadTilePatterns   ; NOT YET DEFINED IN THE PORT
extern SaveScreenTilesToBuffer2   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern Text_59c1f   ; NOT YET DEFINED IN THE PORT
extern Text_59c24   ; NOT YET DEFINED IN THE PORT
extern Text_59c29   ; NOT YET DEFINED IN THE PORT
extern Text_59c2e   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubChairmanIntroText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubChairmanStoryText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubClefairyFanBetterText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubClefairyFanNormalText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubClefairyFanText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubClefairyText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubReceivedBikeVoucherText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubSeelFanBetterText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubSeelFanNormalText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubSeelFanText   ; NOT YET DEFINED IN THE PORT
extern _PokemonFanClubSeelText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONFANCLUB_SCRIPT1                  equ 1

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wPlayerMovingDirection
wPlayerMovingDirection                         equ W_PLAYER_MOVING_DIRECTION
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hOaksAideResult                                equ 0xFFDB
wPikachuMapScriptFlags                         equ 0xD492
wPikachuSpawnStateFlags                        equ 0xD471
wPokemonFanClubCurScript                       equ 0xD5F9
wSprite03StateData1FacingDirection             equ 0xC139
wSprite03StateData1MovementStatus              equ 0xC131

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonFanClub_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonFanClub_ScriptPointers
    mov al, [ebp + wPokemonFanClubCurScript]
    call CallFunctionInTable
    ret

PokemonFanClub_ScriptPointers:
    dd PokemonFanClubScript0
    dd PokemonFanClubScript1

PokemonFanClubScript0:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (7))
    jnz .sk_16
        call PokemonFanClubScript_59a44
.sk_16:
    mov esi, wPikachuMapScriptFlags
    or byte [ebp + esi], (1 << (7))
    ret

PokemonFanClubScript1:
    mov esi, wPikachuMapScriptFlags
    test byte [ebp + esi], (1 << (7))
    jnz .sk_24
        call PokemonFanClubScript_59a39
.sk_24:
    mov esi, wPikachuMapScriptFlags
    or byte [ebp + esi], (1 << (7))
    ret

PokemonFanClubScript_59a39:
    call Random
    mov al, [ebp + hRandomAdd]
    cmp al, 25
    jae .sk_33
        call PokemonFanClubScript_59a44
.sk_33:
    ret

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] PokemonFanClubScript_59a44 (scripts/PokemonFanClub.asm:37-61) — at scripts/PokemonFanClub.asm:38: bit BIT_PIKACHU_SPAWN_STARTER, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wPikachuSpawnStateFlags]
; PRET| 	bit BIT_PIKACHU_SPAWN_STARTER, a
; PRET| 	ret z
; PRET| 	callfar CheckPikachuStatusCondition
; PRET| 	ret c
; PRET| 	ld a, SCRIPT_POKEMONFANCLUB_SCRIPT1
; PRET| 	ld [wPokemonFanClubCurScript], a
; PRET| 	xor a
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	call UpdateSprites
; PRET| 	call UpdateSprites
; PRET| 	ld a, EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	ld a, $f ; Pikachu
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	predef EmotionBubble
; PRET| 	ld hl, PokemonFanClubPikachuMovementData
; PRET| 	call ApplyPikachuMovementData
; PRET| 	ld a, $2 ; Seel
; PRET| 	ld [wSprite03StateData1MovementStatus], a
; PRET| 	xor a ; SPRITE_FACING_DOWN
; PRET| 	ld [wSprite03StateData1FacingDirection], a
; PRET| 	callfar InitializePikachuTextID
; PRET| 	call DisablePikachuFollowingPlayer
; PRET| 	ret

PokemonFanClubPikachuMovementData:
    db 0x00
    db 0x26
    db 0x20
    db 0x20
    db 0x20
    db 0x1e
    db 0x3f
PokemonFanClub_TextPointers:
    dd PokemonFanClubClefairyFanText
    dd PokemonFanClubSeelFanText
    dd PokemonFanClubClefairyText
    dd PokemonFanClubSeelText
    dd PokemonFanClubChairmanText
    dd PokemonFanClubReceptionistText

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubClefairyFanText (scripts/PokemonFanClub.asm:83-87) — at scripts/PokemonFanClub.asm:84: .asm_59aaf is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_LEFT_FANCLUB_AFTER_BIKE_VOUCHER
; PRET| 	jr z, .asm_59aaf
; PRET| 	ld hl, .yellowtext
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonFanClubClefairyFanText.asm_59aaf (scripts/PokemonFanClub.asm:90-95) — at scripts/PokemonFanClub.asm:90: CheckEventReuseHL EVENT_PIKACHU_FAN_BOAST
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventReuseHL EVENT_PIKACHU_FAN_BOAST
; PRET| 	jr nz, .mineisbetter
; PRET| 	SetEventReuseHL EVENT_SEEL_FAN_BOAST
; PRET| 	ld hl, .normaltext
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonFanClubClefairyFanText.mineisbetter (scripts/PokemonFanClub.asm:97-101) — at scripts/PokemonFanClub.asm:97: ResetEventReuseHL EVENT_PIKACHU_FAN_BOAST
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ResetEventReuseHL EVENT_PIKACHU_FAN_BOAST
; PRET| 	ld hl, .bettertext
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

.normaltext:
    text_far _PokemonFanClubClefairyFanNormalText
    text_end
.bettertext:
    text_far _PokemonFanClubClefairyFanBetterText
    text_end
.yellowtext:
    text_far _PokemonFanClubClefairyFanText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubSeelFanText (scripts/PokemonFanClub.asm:117-121) — at scripts/PokemonFanClub.asm:118: .asm_59ae7 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_LEFT_FANCLUB_AFTER_BIKE_VOUCHER
; PRET| 	jr z, .asm_59ae7
; PRET| 	ld hl, .yellowtext
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonFanClubSeelFanText.asm_59ae7 (scripts/PokemonFanClub.asm:124-129) — at scripts/PokemonFanClub.asm:124: CheckEventReuseHL EVENT_SEEL_FAN_BOAST
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventReuseHL EVENT_SEEL_FAN_BOAST
; PRET| 	jr nz, .mineisbetter
; PRET| 	SetEventReuseHL EVENT_PIKACHU_FAN_BOAST
; PRET| 	ld hl, .normaltext
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonFanClubSeelFanText.mineisbetter (scripts/PokemonFanClub.asm:131-135) — at scripts/PokemonFanClub.asm:131: ResetEventReuseHL EVENT_SEEL_FAN_BOAST
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ResetEventReuseHL EVENT_SEEL_FAN_BOAST
; PRET| 	ld hl, .bettertext
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] PokemonFanClubSeelFanText.normaltext (scripts/PokemonFanClub.asm:138-147)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonFanClubSeelFanNormalText
; PRET| 	text_end
; PRET| 
; PRET| .bettertext
; PRET| 	text_far _PokemonFanClubSeelFanBetterText
; PRET| 	text_end
; PRET| 
; PRET| .yellowtext
; PRET| 	text_far _PokemonFanClubSeelFanText
; PRET| 	text_end

PokemonFanClubClefairyText:
    mov esi, .Text
    call PrintText
    mov al, 4
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

.Text:
    text_far _PokemonFanClubClefairyText
    text_end

PokemonFanClubSeelText:
    mov esi, .Text
    call PrintText
    mov al, 58
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd

.Text:
    text_far _PokemonFanClubSeelText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText (scripts/PokemonFanClub.asm:177-186) — at scripts/PokemonFanClub.asm:178: .check_bike_voucher is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEventHL EVENT_LEFT_FANCLUB_AFTER_BIKE_VOUCHER
; PRET| 	jr z, .check_bike_voucher
; PRET| 	ld hl, Text_59c1f
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr z, .select_mon_to_print
; PRET| 	ld hl, Text_59c24
; PRET| 	jr .gbpals_print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.check_bike_voucher (scripts/PokemonFanClub.asm:189-207) — at scripts/PokemonFanClub.asm:190: .nothingleft is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_BIKE_VOUCHER
; PRET| 	jr nz, .nothingleft
; PRET| 	ld hl, .IntroText
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .nothanks
; PRET| 
; PRET| 	; tell the story
; PRET| 	ld hl, .StoryText
; PRET| 	call PrintText
; PRET| 	lb bc, BIKE_VOUCHER, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .BikeVoucherText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_BIKE_VOUCHER
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.bag_full (scripts/PokemonFanClub.asm:209-210) — at scripts/PokemonFanClub.asm:209: .BagFullText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .BagFullText
; PRET| 	jr .gbpals_print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.nothanks (scripts/PokemonFanClub.asm:212-213) — at scripts/PokemonFanClub.asm:212: .NoStoryText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoStoryText
; PRET| 	jr .gbpals_print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.nothingleft (scripts/PokemonFanClub.asm:215-221) — at scripts/PokemonFanClub.asm:215: .FinalText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .FinalText
; PRET| .gbpals_print_text
; PRET| 	push hl
; PRET| 	call LoadGBPal
; PRET| 	pop hl
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.select_mon_to_print (scripts/PokemonFanClub.asm:224-236) — at scripts/PokemonFanClub.asm:232: .print is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call GBPalWhiteOutWithDelay3
; PRET| 	call LoadCurrentMapView
; PRET| 	call SaveScreenTilesToBuffer2
; PRET| 	ld a, $ff
; PRET| 	ld [wUpdateSpritesEnabled], a
; PRET| 	ld a, $00
; PRET| 	ld [wTempTilesetNumTiles], a
; PRET| 	call DisplayPartyMenu
; PRET| 	jp nc, .print
; PRET| 	call GBPalWhiteOutWithDelay3
; PRET| 	call RestoreScreenTilesAndReloadTilePatterns
; PRET| 	ld hl, Text_59c24
; PRET| 	jr .gbpals_print_text

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonFanClubChairmanText.print (scripts/PokemonFanClub.asm:239-257) — at scripts/PokemonFanClub.asm:255: .gbpals_print_text is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wUpdateSpritesEnabled], a
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_NO_TEXT_DELAY, [hl]
; PRET| 	callfar PrintFanClubPortrait
; PRET| 	ld hl, wStatusFlags5
; PRET| 	res BIT_NO_TEXT_DELAY, [hl]
; PRET| 	call GBPalWhiteOutWithDelay3
; PRET| 	call ReloadTilesetTilePatterns
; PRET| 	call RestoreScreenTilesAndReloadTilePatterns
; PRET| 	call LoadScreenTilesFromBuffer2
; PRET| 	call Delay3
; PRET| 	call GBPalNormal
; PRET| 	ld hl, Text_59c2e
; PRET| 	ldh a, [hOaksAideResult]
; PRET| 	and a
; PRET| 	jr nz, .gbpals_print_text
; PRET| 	ld hl, Text_59c29
; PRET| 	jr .gbpals_print_text

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] PokemonFanClubChairmanText.IntroText (scripts/PokemonFanClub.asm:260-303) — at scripts/PokemonFanClub.asm:269: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonFanClubChairmanIntroText
; PRET| 	text_end
; PRET| 
; PRET| .StoryText:
; PRET| 	text_far _PokemonFanClubChairmanStoryText
; PRET| 	text_end
; PRET| 
; PRET| .BikeVoucherText:
; PRET| 	text_far _PokemonFanClubReceivedBikeVoucherText
; PRET| 	sound_get_key_item
; PRET| 	text_far _PokemonFanClubExplainBikeVoucherText
; PRET| 	text_end
; PRET| 
; PRET| .NoStoryText:
; PRET| 	text_far _PokemonFanClubNoStoryText
; PRET| 	text_end
; PRET| 
; PRET| .FinalText:
; PRET| 	text_far _PokemonFanClubChairFinalText
; PRET| 	text_end
; PRET| 
; PRET| .BagFullText:
; PRET| 	text_far _PokemonFanClubBagFullText
; PRET| 	text_end
; PRET| 
; PRET| Text_59c1f:
; PRET| 	text_far FanClubChairPrintText1
; PRET| 	text_end
; PRET| 
; PRET| Text_59c24:
; PRET| 	text_far FanClubChairPrintText2
; PRET| 	text_end
; PRET| 
; PRET| Text_59c29:
; PRET| 	text_far FanClubChairPrintText3
; PRET| 	text_end
; PRET| 
; PRET| Text_59c2e:
; PRET| 	text_far FanClubChairPrintText4
; PRET| 	text_end
; PRET| 
; PRET| PokemonFanClubReceptionistText:
; PRET| 	text_far _PokemonFanClubReceptionistText
; PRET| 	text_end
