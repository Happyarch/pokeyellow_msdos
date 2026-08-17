; GameCorner.asm — translated from pret scripts/GameCorner.asm, scripts/GameCorner_2.asm by dos_port/tools/sm83xlat.
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

%include "assets/audio_constants.inc"

global GameCornerBeauty1Text
global GameCornerBeauty2Text
global GameCornerDefaultScript
global GameCornerGamblerText
global GameCornerGymGuideChampInMakingText
global GameCornerGymGuideText
global GameCornerGymGuideTheyOfferRarePokemonText
global GameCornerMiddleAgedMan1Text
global GameCornerMovement_Rocket_WalkAroundPlayer
global GameCornerMovement_Rocket_WalkDirect
global GameCornerOopsForgotCoinCaseText
global GameCornerPikachuMovementData
global GameCornerPikachuMovementScript
global GameCornerPosterText
global GameCornerReenterMapAfterPlayerLoss
global GameCornerRocketAfterBattleText
global GameCornerRocketExitScript
global GameCornerRocketText
global GameCornerSelectLuckySlotMachine
global GameCornerSetRocketHideoutDoorTile
global GameCorner_Script
global GameCorner_ScriptPointers
global GameCorner_TextPointers
global Has9990Coins

extern AddBCDPredef   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern ClearScreenArea   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern GameCornerBlankText1   ; NOT YET DEFINED IN THE PORT
extern GameCornerBlankText2   ; NOT YET DEFINED IN THE PORT
extern GameCornerClerkText   ; NOT YET DEFINED IN THE PORT
extern GameCornerCoinText   ; NOT YET DEFINED IN THE PORT
extern GameCornerDrawCoinBox   ; NOT YET DEFINED IN THE PORT
extern GameCornerFishingGuru1Text   ; NOT YET DEFINED IN THE PORT
extern GameCornerFishingGuru2Text   ; NOT YET DEFINED IN THE PORT
extern GameCornerMiddleAgedMan2Text   ; NOT YET DEFINED IN THE PORT
extern GameCornerMiddleAgedWomanText   ; NOT YET DEFINED IN THE PORT
extern GameCornerMoneyText   ; NOT YET DEFINED IN THE PORT
extern GameCornerRocketBattleScript   ; NOT YET DEFINED IN THE PORT
extern HasEnoughCoins   ; NOT YET DEFINED IN THE PORT
extern HasEnoughMoney   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern IsItemInBag   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlaceString   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PrintBCDNumber   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern Random   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern SubBCDPredef   ; NOT YET DEFINED IN THE PORT
extern TextBoxBorder   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _GameCornerBeauty1Text   ; NOT YET DEFINED IN THE PORT
extern _GameCornerBeauty2Text   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkCantAffordTheCoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkCoinCaseIsFullText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkDoYouNeedSomeGameCoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkDontHaveCoinCaseText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkPleaseComePlaySometimeText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerClerkThanksHereAre50CoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerFishingGuru1Received10CoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerFishingGuru1WantToPlayText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerFishingGuru2Received20CoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerFishingGuru2ThrowingMeOffText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerGamblerText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerGymGuideChampInMakingText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerGymGuideTheyOfferRarePokemonText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerMiddleAgedMan1Text   ; NOT YET DEFINED IN THE PORT
extern _GameCornerMiddleAgedMan2Received20CoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerMiddleAgedMan2WantSomeCoinsText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerOopsForgotCoinCaseText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerPosterSwitchBehindPosterText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerRocketBattleEndText   ; NOT YET DEFINED IN THE PORT
extern _GameCornerRocketImGuardingThisPosterText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_GAMECORNER_DEFAULT                      equ 0
SCRIPT_GAMECORNER_ROCKET_BATTLE                equ 1
SCRIPT_GAMECORNER_ROCKET_EXIT                  equ 2
TEXT_GAMECORNER_ROCKET_AFTER_BATTLE            equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnusedCoinsByte                               equ 0xFF9F
wGameCornerCurScript                           equ 0xD65E

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
GameCorner_Script:
    call GameCornerSelectLuckySlotMachine
    call GameCornerSetRocketHideoutDoorTile
    call EnableAutoTextBoxDrawing
    mov esi, GameCorner_ScriptPointers
    mov al, [ebp + wGameCornerCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
GameCornerSelectLuckySlotMachine:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_2)) & 0xFF
    popfd
    jnz .nr_13
        ret
.nr_13:
    call Random
    mov al, [ebp + hRandomAdd]
    cmp al, 0x7
    jae .not_max
    mov al, 0x8
.not_max:
    shr al, 1
    shr al, 1
    shr al, 1
    mov [ebp + wLuckySlotHiddenEventIndex], al
    ret

%assign event_byte -1
GameCornerSetRocketHideoutDoorTile:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_30
        ret
.nr_30:
    CheckEvent EVENT_FOUND_ROCKET_HIDEOUT
    jz .nr_32
        ret
.nr_32:
    mov al, 0x2a
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (8)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
GameCornerReenterMapAfterPlayerLoss:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wGameCornerCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
GameCorner_ScriptPointers:
    dd GameCornerDefaultScript
    dd GameCornerRocketBattleScript
    dd GameCornerRocketExitScript

%assign event_byte -1
GameCornerDefaultScript:
    ret

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] GameCornerRocketBattleScript (scripts/GameCorner.asm:55-71) — at scripts/GameCorner.asm:66: de cannot hold the 32-bit address of GameCornerMovement_Rocket_WalkAroundPlayer; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, GameCornerReenterMapAfterPlayerLoss
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TEXT_GAMECORNER_ROCKET_AFTER_BATTLE
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld a, GAMECORNER_ROCKET
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call SetSpriteMovementBytesToFF
; PRET| 	ld de, GameCornerMovement_Rocket_WalkAroundPlayer
; PRET| 	ld a, [wYCoord]
; PRET| 	cp 6
; PRET| 	jr nz, .not_direct_movement
; PRET| 	ld de, GameCornerMovement_Rocket_WalkDirect
; PRET| 	jr .got_rocket_movement

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] GameCornerRocketBattleScript.not_direct_movement (scripts/GameCorner.asm:73-77) — at scripts/GameCorner.asm:76: de cannot hold the 32-bit address of GameCornerMovement_Rocket_WalkDirect; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wXCoord]
; PRET| 	cp 8
; PRET| 	jr nz, .pikachu
; PRET| 	ld de, GameCornerMovement_Rocket_WalkDirect
; PRET| 	jr .got_rocket_movement

%assign event_byte -1
.pikachu:
; DEVIATION{class=banking; pret=macros/farcall.asm:callfar; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call GameCornerPikachuMovementScript
    mov edi, GameCornerMovement_Rocket_WalkAroundPlayer   ; pret: ld de, GameCornerMovement_Rocket_WalkAroundPlayer — MoveSprite takes it in EDI
.got_rocket_movement:
    mov al, 11
    mov [ebp + hSpriteIndex], al
    call MoveSprite
    mov al, SCRIPT_GAMECORNER_ROCKET_EXIT
    mov [ebp + wGameCornerCurScript], al
    ret

%assign event_byte -1
GameCornerMovement_Rocket_WalkAroundPlayer:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_UP
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1
GameCornerMovement_Rocket_WalkDirect:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1

%assign event_byte -1
GameCornerRocketExitScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_111
        ret
.nr_111:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov al, 70
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_2))
    mov al, SCRIPT_GAMECORNER_DEFAULT
    mov [ebp + wGameCornerCurScript], al
    ret

%assign event_byte -1
GameCorner_TextPointers:
    dd GameCornerBeauty1Text
    dd GameCornerClerkText
    dd GameCornerMiddleAgedMan1Text
    dd GameCornerBeauty2Text
    dd GameCornerFishingGuru1Text
    dd GameCornerMiddleAgedWomanText
    dd GameCornerGymGuideText
    dd GameCornerGamblerText
    dd GameCornerMiddleAgedMan2Text
    dd GameCornerFishingGuru2Text
    dd GameCornerRocketText
    dd GameCornerPosterText
    dd GameCornerRocketAfterBattleText
GameCornerBeauty1Text:
    text_far _GameCornerBeauty1Text
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerClerkText (scripts/GameCorner.asm:147-171) — at scripts/GameCorner.asm:153: .declined is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call GameCornerDrawCoinBox
; PRET| 	ld hl, .DoYouNeedSomeGameCoins
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .declined
; PRET| 	; Can only get more coins if you
; PRET| 	; - have the Coin Case
; PRET| 	ld b, COIN_CASE
; PRET| 	call IsItemInBag
; PRET| 	jr z, .no_coin_case
; PRET| 	; - have room in the Coin Case for at least 9 coins
; PRET| 	call Has9990Coins
; PRET| 	jr nc, .coin_case_full
; PRET| 	; - have at least 1000 yen
; PRET| 	xor a
; PRET| 	ldh [hMoney], a
; PRET| 	ldh [hMoney + 2], a
; PRET| 	ld a, $10
; PRET| 	ldh [hMoney + 1], a
; PRET| 	call HasEnoughMoney
; PRET| 	jr nc, .buy_coins
; PRET| 	ld hl, .CantAffordTheCoins
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[unresolved-symbol] GameCornerClerkText.buy_coins (scripts/GameCorner.asm:174-196) — at scripts/GameCorner.asm:189: wPlayerCoins
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ldh [hMoney], a
; PRET| 	ldh [hMoney + 2], a
; PRET| 	ld a, $10
; PRET| 	ldh [hMoney + 1], a
; PRET| 	ld hl, hMoney + 2
; PRET| 	ld de, wPlayerMoney + 2
; PRET| 	ld c, $3
; PRET| 	predef SubBCDPredef
; PRET| 	; Receive 50 coins
; PRET| 	xor a
; PRET| 	ldh [hUnusedCoinsByte], a
; PRET| 	ldh [hCoins], a
; PRET| 	ld a, $50
; PRET| 	ldh [hCoins + 1], a
; PRET| 	ld de, wPlayerCoins + 1
; PRET| 	ld hl, hCoins + 1
; PRET| 	ld c, $2
; PRET| 	predef AddBCDPredef
; PRET| 	; Update display
; PRET| 	call GameCornerDrawCoinBox
; PRET| 	ld hl, .ThanksHereAre50Coins
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerClerkText.declined (scripts/GameCorner.asm:198-199) — at scripts/GameCorner.asm:199: .print_ret is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .PleaseComePlaySometime
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerClerkText.coin_case_full (scripts/GameCorner.asm:201-202) — at scripts/GameCorner.asm:202: .print_ret is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CoinCaseIsFull
; PRET| 	jr .print_ret

%assign event_byte -1
.no_coin_case:
    mov esi, .DontHaveCoinCase
.print_ret:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.DoYouNeedSomeGameCoins:
    text_far _GameCornerClerkDoYouNeedSomeGameCoinsText
    text_end
.ThanksHereAre50Coins:
    text_far _GameCornerClerkThanksHereAre50CoinsText
    text_end
.PleaseComePlaySometime:
    text_far _GameCornerClerkPleaseComePlaySometimeText
    text_end
.CantAffordTheCoins:
    text_far _GameCornerClerkCantAffordTheCoinsText
    text_end
.CoinCaseIsFull:
    text_far _GameCornerClerkCoinCaseIsFullText
    text_end
.DontHaveCoinCase:
    text_far _GameCornerClerkDontHaveCoinCaseText
    text_end
GameCornerMiddleAgedMan1Text:
    text_far _GameCornerMiddleAgedMan1Text
    text_end
GameCornerBeauty2Text:
    text_far _GameCornerBeauty2Text
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru1Text (scripts/GameCorner.asm:243-265) — at scripts/GameCorner.asm:244: .alreadyGotNpcCoins is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_10_COINS
; PRET| 	jr nz, .alreadyGotNpcCoins
; PRET| 	ld hl, .WantToPlayText
; PRET| 	call PrintText
; PRET| 	ld b, COIN_CASE
; PRET| 	call IsItemInBag
; PRET| 	jr z, .dontHaveCoinCase
; PRET| 	call Has9990Coins
; PRET| 	jr nc, .coinCaseFull
; PRET| 	xor a
; PRET| 	ldh [hUnusedCoinsByte], a
; PRET| 	ldh [hCoins], a
; PRET| 	ld a, $10
; PRET| 	ldh [hCoins + 1], a
; PRET| 	ld de, wPlayerCoins + 1
; PRET| 	ld hl, hCoins + 1
; PRET| 	ld c, $2
; PRET| 	predef AddBCDPredef
; PRET| 	SetEvent EVENT_GOT_10_COINS
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, .Received10CoinsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru1Text.alreadyGotNpcCoins (scripts/GameCorner.asm:267-268) — at scripts/GameCorner.asm:267: .WinsComeAndGoText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .WinsComeAndGoText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru1Text.coinCaseFull (scripts/GameCorner.asm:270-271) — at scripts/GameCorner.asm:270: .DontNeedMyCoinsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .DontNeedMyCoinsText
; PRET| 	jr .print_ret

%assign event_byte -1
.dontHaveCoinCase:
    mov esi, GameCornerOopsForgotCoinCaseText
.print_ret:
    call PrintText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] GameCornerFishingGuru1Text.WantToPlayText (scripts/GameCorner.asm:279-297) — at scripts/GameCorner.asm:284: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _GameCornerFishingGuru1WantToPlayText
; PRET| 	text_end
; PRET| 
; PRET| .Received10CoinsText:
; PRET| 	text_far _GameCornerFishingGuru1Received10CoinsText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .DontNeedMyCoinsText:
; PRET| 	text_far _GameCornerFishingGuru1DontNeedMyCoinsText
; PRET| 	text_end
; PRET| 
; PRET| .WinsComeAndGoText:
; PRET| 	text_far _GameCornerFishingGuru1WinsComeAndGoText
; PRET| 	text_end
; PRET| 
; PRET| GameCornerMiddleAgedWomanText:
; PRET| 	text_far _GameCornerMiddleAgedWomanText
; PRET| 	text_end

%assign event_byte -1
GameCornerGymGuideText:
    CheckEvent EVENT_BEAT_ERIKA
    mov esi, GameCornerGymGuideChampInMakingText
    jz .not_defeated
    mov esi, GameCornerGymGuideTheyOfferRarePokemonText
.not_defeated:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
GameCornerGymGuideChampInMakingText:
    text_far _GameCornerGymGuideChampInMakingText
    text_end
GameCornerGymGuideTheyOfferRarePokemonText:
    text_far _GameCornerGymGuideTheyOfferRarePokemonText
    text_end
GameCornerGamblerText:
    text_far _GameCornerGamblerText
    text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerMiddleAgedMan2Text (scripts/GameCorner.asm:323-343) — at scripts/GameCorner.asm:324: .alreadyGotNpcCoins is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_20_COINS_2
; PRET| 	jr nz, .alreadyGotNpcCoins
; PRET| 	ld hl, .WantSomeCoinsText
; PRET| 	call PrintText
; PRET| 	ld b, COIN_CASE
; PRET| 	call IsItemInBag
; PRET| 	jr z, .dontHaveCoinCase
; PRET| 	call Has9990Coins
; PRET| 	jr nc, .coinCaseFull
; PRET| 	xor a
; PRET| 	ldh [hUnusedCoinsByte], a
; PRET| 	ldh [hCoins], a
; PRET| 	ld a, $20
; PRET| 	ldh [hCoins + 1], a
; PRET| 	ld de, wPlayerCoins + 1
; PRET| 	ld hl, hCoins + 1
; PRET| 	ld c, $2
; PRET| 	predef AddBCDPredef
; PRET| 	SetEvent EVENT_GOT_20_COINS_2
; PRET| 	ld hl, .Received20CoinsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerMiddleAgedMan2Text.alreadyGotNpcCoins (scripts/GameCorner.asm:345-346) — at scripts/GameCorner.asm:345: .INeedMoreCoinsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .INeedMoreCoinsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerMiddleAgedMan2Text.coinCaseFull (scripts/GameCorner.asm:348-349) — at scripts/GameCorner.asm:348: .YouHaveLotsOfCoinsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .YouHaveLotsOfCoinsText
; PRET| 	jr .print_ret

%assign event_byte -1
.dontHaveCoinCase:
    mov esi, GameCornerOopsForgotCoinCaseText
.print_ret:
    call PrintText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] GameCornerMiddleAgedMan2Text.WantSomeCoinsText (scripts/GameCorner.asm:357-371) — at scripts/GameCorner.asm:362: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _GameCornerMiddleAgedMan2WantSomeCoinsText
; PRET| 	text_end
; PRET| 
; PRET| .Received20CoinsText:
; PRET| 	text_far _GameCornerMiddleAgedMan2Received20CoinsText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .YouHaveLotsOfCoinsText:
; PRET| 	text_far _GameCornerMiddleAgedMan2YouHaveLotsOfCoinsText
; PRET| 	text_end
; PRET| 
; PRET| .INeedMoreCoinsText:
; PRET| 	text_far _GameCornerMiddleAgedMan2INeedMoreCoinsText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru2Text (scripts/GameCorner.asm:375-395) — at scripts/GameCorner.asm:376: .alreadyGotNpcCoins is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_20_COINS
; PRET| 	jr nz, .alreadyGotNpcCoins
; PRET| 	ld hl, .ThrowingMeOffText
; PRET| 	call PrintText
; PRET| 	ld b, COIN_CASE
; PRET| 	call IsItemInBag
; PRET| 	jr z, .dontHaveCoinCase
; PRET| 	call Has9990Coins
; PRET| 	jr z, .coinCaseFull
; PRET| 	xor a
; PRET| 	ldh [hUnusedCoinsByte], a
; PRET| 	ldh [hCoins], a
; PRET| 	ld a, $20
; PRET| 	ldh [hCoins + 1], a
; PRET| 	ld de, wPlayerCoins + 1
; PRET| 	ld hl, hCoins + 1
; PRET| 	ld c, $2
; PRET| 	predef AddBCDPredef
; PRET| 	SetEvent EVENT_GOT_20_COINS
; PRET| 	ld hl, .Received20CoinsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru2Text.alreadyGotNpcCoins (scripts/GameCorner.asm:397-398) — at scripts/GameCorner.asm:397: .CloselyWatchTheReelsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .CloselyWatchTheReelsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] GameCornerFishingGuru2Text.coinCaseFull (scripts/GameCorner.asm:400-401) — at scripts/GameCorner.asm:400: .YouGotYourOwnCoinsText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .YouGotYourOwnCoinsText
; PRET| 	jr .print_ret

; ---------------------------------------------------------------------------
; BAIL[local-label-scope-collision] GameCornerFishingGuru2Text.dontHaveCoinCase (scripts/GameCorner.asm:403-406)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, GameCornerOopsForgotCoinCaseText
; PRET| .print_ret
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] GameCornerFishingGuru2Text.ThrowingMeOffText (scripts/GameCorner.asm:409-423) — at scripts/GameCorner.asm:414: sound_get_item_1
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _GameCornerFishingGuru2ThrowingMeOffText
; PRET| 	text_end
; PRET| 
; PRET| .Received20CoinsText:
; PRET| 	text_far _GameCornerFishingGuru2Received20CoinsText
; PRET| 	sound_get_item_1
; PRET| 	text_end
; PRET| 
; PRET| .YouGotYourOwnCoinsText:
; PRET| 	text_far _GameCornerFishingGuru2YouGotYourOwnCoinsText
; PRET| 	text_end
; PRET| 
; PRET| .CloselyWatchTheReelsText:
; PRET| 	text_far _GameCornerFishingGuru2CloselyWatchTheReelsText
; PRET| 	text_end

%assign event_byte -1
GameCornerRocketText:
    mov esi, .ImGuardingThisPosterText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .BattleEndText
    mov edx, .BattleEndText   ; pret: ld de, .BattleEndText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + hJoyPressed], al
    mov [ebp + hJoyReleased], al
    mov al, SCRIPT_GAMECORNER_ROCKET_BATTLE
    mov [ebp + wGameCornerCurScript], al
    jmp TextScriptEnd

%assign event_byte -1
.ImGuardingThisPosterText:
    text_far _GameCornerRocketImGuardingThisPosterText
    text_end
.BattleEndText:
    text_far _GameCornerRocketBattleEndText
    text_end
GameCornerRocketAfterBattleText:
    text_far _GameCornerRocketAfterBattleText
    text_end

%assign event_byte -1
GameCornerPosterText:
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, .SwitchBehindPosterText
    call PrintText
    call WaitForSoundToFinish
    mov al, SFX_GO_INSIDE
    call PlaySound
    call WaitForSoundToFinish
    SetEvent EVENT_FOUND_ROCKET_HIDEOUT
    mov al, 0x43
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (8)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    jmp TextScriptEnd

%assign event_byte -1
.SwitchBehindPosterText:
    text_far _GameCornerPosterSwitchBehindPosterText

%assign event_byte -1
    mov al, SFX_SWITCH
    call PlaySound
    call WaitForSoundToFinish
    jmp TextScriptEnd

%assign event_byte -1
GameCornerOopsForgotCoinCaseText:
    text_far _GameCornerOopsForgotCoinCaseText
    text_end

; ---------------------------------------------------------------------------
; BAIL[screen-coord-projection] GameCornerDrawCoinBox (scripts/GameCorner.asm:489-520) — at scripts/GameCorner.asm:491: hlcoord 11, 0
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wStatusFlags5
; PRET| 	set BIT_NO_TEXT_DELAY, [hl]
; PRET| 	hlcoord 11, 0
; PRET| 	lb bc, 5, 7
; PRET| 	call TextBoxBorder
; PRET| 	call UpdateSprites
; PRET| 	hlcoord 12, 1
; PRET| 	lb bc, 4, 7
; PRET| 	call ClearScreenArea
; PRET| 	hlcoord 12, 2
; PRET| 	ld de, GameCornerMoneyText
; PRET| 	call PlaceString
; PRET| 	hlcoord 12, 3
; PRET| 	ld de, GameCornerBlankText1
; PRET| 	call PlaceString
; PRET| 	hlcoord 12, 3
; PRET| 	ld de, wPlayerMoney
; PRET| 	ld c, 3 | MONEY_SIGN | LEADING_ZEROES
; PRET| 	call PrintBCDNumber
; PRET| 	hlcoord 12, 4
; PRET| 	ld de, GameCornerCoinText
; PRET| 	call PlaceString
; PRET| 	hlcoord 12, 5
; PRET| 	ld de, GameCornerBlankText2
; PRET| 	call PlaceString
; PRET| 	hlcoord 15, 5
; PRET| 	ld de, wPlayerCoins
; PRET| 	ld c, 2 | LEADING_ZEROES
; PRET| 	call PrintBCDNumber
; PRET| 	ld hl, wStatusFlags5
; PRET| 	res BIT_NO_TEXT_DELAY, [hl]
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[inline-text-db] GameCornerMoneyText (scripts/GameCorner.asm:523-532) — at scripts/GameCorner.asm:523: db "MONEY@"
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	db "MONEY@"
; PRET| 
; PRET| GameCornerCoinText:
; PRET| 	db "COIN@"
; PRET| 
; PRET| GameCornerBlankText1:
; PRET| 	db "       @"
; PRET| 
; PRET| GameCornerBlankText2:
; PRET| 	db "       @"

%assign event_byte -1
Has9990Coins:
    mov al, 0x99
    mov [ebp + hCoins], al
    mov al, 0x90
    mov [ebp + hCoins + 1], al
    jmp HasEnoughCoins

%assign event_byte -1
GameCornerPikachuMovementScript:
    mov esi, GameCornerPikachuMovementData
    mov bh, SPRITE_FACING_DOWN
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
GameCornerPikachuMovementData:
    db 0x00
    db 0x20
    db 0x1e
    db 0x35
    db 0x3f
