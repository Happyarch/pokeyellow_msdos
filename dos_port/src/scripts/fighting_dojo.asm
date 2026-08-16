; FightingDojo.asm — translated from pret scripts/FightingDojo.asm by dos_port/tools/sm83xlat.
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


global FightingDojoBetterNotGetGreedyText
global FightingDojoBlackbelt1Text
global FightingDojoBlackbelt2Text
global FightingDojoBlackbelt3Text
global FightingDojoBlackbelt4Text
global FightingDojoDefaultScript
global FightingDojoHitmonchanPokeBallText
global FightingDojoHitmonleePokeBallText
global FightingDojoResetScripts
global FightingDojo_Script
global FightingDojo_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayPokedex   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt1AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt1BattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt1EndBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt2AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt2BattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt2EndBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt3AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt3BattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt3EndBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt4AfterBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt4BattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoBlackbelt4EndBattleText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoKarateMasterPostBattleScript   ; NOT YET DEFINED IN THE PORT
extern FightingDojoKarateMasterText   ; NOT YET DEFINED IN THE PORT
extern FightingDojoTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern FightingDojoTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern FightingDojoTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern FightingDojoTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern FightingDojoTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern FightingDojo_TextPointers   ; NOT YET DEFINED IN THE PORT
extern GivePokemon   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoBetterNotGetGreedyText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoHitmonchanPokeBallText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoHitmonleePokeBallText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoKarateMasterDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoKarateMasterIWillGiveYouAPokemonText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoKarateMasterStayAndTrainWithUsText   ; NOT YET DEFINED IN THE PORT
extern _FightingDojoKarateMasterText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_FIGHTINGDOJO_DEFAULT                    equ 0
SCRIPT_FIGHTINGDOJO_KARATE_MASTER_POST_BATTLE  equ 3
TEXT_FIGHTINGDOJO_KARATE_MASTER                equ 1
TEXT_FIGHTINGDOJO_BLACKBELT1                   equ 2
TEXT_FIGHTINGDOJO_BLACKBELT2                   equ 3
TEXT_FIGHTINGDOJO_BLACKBELT3                   equ 4
TEXT_FIGHTINGDOJO_BLACKBELT4                   equ 5
TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL          equ 6
TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL         equ 7
TEXT_FIGHTINGDOJO_KARATE_MASTER_I_WILL_GIVE_YOU_A_POKEMON equ 8

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wFightingDojoCurScript                         equ 0xD641
wSavedCoordIndex                               equ 0xCF0D

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

FightingDojo_Script:
    call EnableAutoTextBoxDrawing
    mov esi, FightingDojoTrainerHeaders
    mov edi, FightingDojo_ScriptPointers   ; pret: ld de, FightingDojo_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wFightingDojoCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wFightingDojoCurScript], al
    ret

FightingDojoResetScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wFightingDojoCurScript], al
    mov [ebp + wCurMapScript], al
    ret

FightingDojo_ScriptPointers:
    dd FightingDojoDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd FightingDojoKarateMasterPostBattleScript

FightingDojoDefaultScript:
    CheckEvent EVENT_DEFEATED_FIGHTING_DOJO
    jz .nr_26
        ret
.nr_26:
    call CheckFightingMapTrainers
    mov al, [ebp + wTrainerHeaderFlagBit]
    test al, al
    jz .nr_30
        ret
.nr_30:
    CheckEvent EVENT_BEAT_KARATE_MASTER
    jz .nr_32
        ret
.nr_32:
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wSavedCoordIndex], al
    mov al, [ebp + wYCoord]
    cmp al, 3
    jz .nr_38
        ret
.nr_38:
    mov al, [ebp + wXCoord]
    cmp al, 4
    jz .nr_41
        ret
.nr_41:
    mov al, 1
    mov [ebp + wSavedCoordIndex], al
    mov al, PLAYER_DIR_RIGHT
    mov [ebp + wPlayerMovingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    mov al, SPRITE_FACING_LEFT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    mov al, TEXT_FIGHTINGDOJO_KARATE_MASTER
    mov [ebp + hTextID], al
    call DisplayTextID
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] FightingDojoKarateMasterPostBattleScript (scripts/FightingDojo.asm:57-81) — at scripts/FightingDojo.asm:62: .already_facing is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, FightingDojoResetScripts
; PRET| 	ld a, [wSavedCoordIndex]
; PRET| 	and a ; nz if the player was at (4, 3), left of the Karate Master
; PRET| 	jr z, .already_facing
; PRET| 	ld a, PLAYER_DIR_RIGHT
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, FIGHTINGDOJO_KARATE_MASTER
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, SPRITE_FACING_LEFT
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| .already_facing
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEventRange EVENT_BEAT_KARATE_MASTER, EVENT_BEAT_FIGHTING_DOJO_TRAINER_3
; PRET| 	ld a, TEXT_FIGHTINGDOJO_KARATE_MASTER_I_WILL_GIVE_YOU_A_POKEMON
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a ; SCRIPT_FIGHTINGDOJO_DEFAULT
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld [wFightingDojoCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] FightingDojo_TextPointers (scripts/FightingDojo.asm:84-104) — a generated asset already defines FightingDojoTrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const FightingDojoKarateMasterText,                          TEXT_FIGHTINGDOJO_KARATE_MASTER
; PRET| 	dw_const FightingDojoBlackbelt1Text,                            TEXT_FIGHTINGDOJO_BLACKBELT1
; PRET| 	dw_const FightingDojoBlackbelt2Text,                            TEXT_FIGHTINGDOJO_BLACKBELT2
; PRET| 	dw_const FightingDojoBlackbelt3Text,                            TEXT_FIGHTINGDOJO_BLACKBELT3
; PRET| 	dw_const FightingDojoBlackbelt4Text,                            TEXT_FIGHTINGDOJO_BLACKBELT4
; PRET| 	dw_const FightingDojoHitmonleePokeBallText,                     TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL
; PRET| 	dw_const FightingDojoHitmonchanPokeBallText,                    TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL
; PRET| 	dw_const FightingDojoKarateMasterText.IWillGiveYouAPokemonText, TEXT_FIGHTINGDOJO_KARATE_MASTER_I_WILL_GIVE_YOU_A_POKEMON
; PRET| 
; PRET| FightingDojoTrainerHeaders:
; PRET| 	def_trainers 2
; PRET| FightingDojoTrainerHeader0:
; PRET| 	trainer EVENT_BEAT_FIGHTING_DOJO_TRAINER_0, 4, FightingDojoBlackbelt1BattleText, FightingDojoBlackbelt1EndBattleText, FightingDojoBlackbelt1AfterBattleText
; PRET| FightingDojoTrainerHeader1:
; PRET| 	trainer EVENT_BEAT_FIGHTING_DOJO_TRAINER_1, 4, FightingDojoBlackbelt2BattleText, FightingDojoBlackbelt2EndBattleText, FightingDojoBlackbelt2AfterBattleText
; PRET| FightingDojoTrainerHeader2:
; PRET| 	trainer EVENT_BEAT_FIGHTING_DOJO_TRAINER_2, 3, FightingDojoBlackbelt3BattleText, FightingDojoBlackbelt3EndBattleText, FightingDojoBlackbelt3AfterBattleText
; PRET| FightingDojoTrainerHeader3:
; PRET| 	trainer EVENT_BEAT_FIGHTING_DOJO_TRAINER_3, 3, FightingDojoBlackbelt4BattleText, FightingDojoBlackbelt4EndBattleText, FightingDojoBlackbelt4AfterBattleText
; PRET| 	db -1 ; end

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] FightingDojoKarateMasterText (scripts/FightingDojo.asm:108-127) — at scripts/FightingDojo.asm:110: CheckEventReuseA EVENT_BEAT_KARATE_MASTER
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_DEFEATED_FIGHTING_DOJO
; PRET| 	jp nz, .defeated_dojo
; PRET| 	CheckEventReuseA EVENT_BEAT_KARATE_MASTER
; PRET| 	jp nz, .defeated_master
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_TALKED_TO_TRAINER, [hl]
; PRET| 	set BIT_PRINT_END_BATTLE_TEXT, [hl]
; PRET| 	ld hl, .DefeatedText
; PRET| 	ld de, .DefeatedText
; PRET| 	call SaveEndBattleTextPointers
; PRET| 	ldh a, [hSpriteIndex]
; PRET| 	ld [wSpriteIndex], a
; PRET| 	call EngageMapTrainer
; PRET| 	call InitBattleEnemyParameters
; PRET| 	ld a, SCRIPT_FIGHTINGDOJO_KARATE_MASTER_POST_BATTLE
; PRET| 	ld [wFightingDojoCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	jr .end

.defeated_dojo:
    mov esi, .StayAndTrainWithUsText
    call PrintText
    jmp .end

.defeated_master:
    mov esi, .IWillGiveYouAPokemonText
    call PrintText
.end:
    jmp TextScriptEnd

.Text:
    text_far _FightingDojoKarateMasterText
    text_end
.DefeatedText:
    text_far _FightingDojoKarateMasterDefeatedText
    text_end
.IWillGiveYouAPokemonText:
    text_far _FightingDojoKarateMasterIWillGiveYouAPokemonText
    text_end
.StayAndTrainWithUsText:
    text_far _FightingDojoKarateMasterStayAndTrainWithUsText
    text_end

FightingDojoBlackbelt1Text:
    mov esi, FightingDojoTrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] FightingDojoBlackbelt1BattleText (scripts/FightingDojo.asm:161-170) — a generated asset already defines FightingDojoBlackbelt1BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FightingDojoBlackbelt1BattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt1EndBattleText:
; PRET| 	text_far _FightingDojoBlackbelt1EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt1AfterBattleText:
; PRET| 	text_far _FightingDojoBlackbelt1AfterBattleText
; PRET| 	text_end

FightingDojoBlackbelt2Text:
    mov esi, FightingDojoTrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] FightingDojoBlackbelt2BattleText (scripts/FightingDojo.asm:179-188) — a generated asset already defines FightingDojoBlackbelt2BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FightingDojoBlackbelt2BattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt2EndBattleText:
; PRET| 	text_far _FightingDojoBlackbelt2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt2AfterBattleText:
; PRET| 	text_far _FightingDojoBlackbelt2AfterBattleText
; PRET| 	text_end

FightingDojoBlackbelt3Text:
    mov esi, FightingDojoTrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] FightingDojoBlackbelt3BattleText (scripts/FightingDojo.asm:197-206) — a generated asset already defines FightingDojoBlackbelt3BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FightingDojoBlackbelt3BattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt3EndBattleText:
; PRET| 	text_far _FightingDojoBlackbelt3EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt3AfterBattleText:
; PRET| 	text_far _FightingDojoBlackbelt3AfterBattleText
; PRET| 	text_end

FightingDojoBlackbelt4Text:
    mov esi, FightingDojoTrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] FightingDojoBlackbelt4BattleText (scripts/FightingDojo.asm:215-224) — a generated asset already defines FightingDojoBlackbelt4BattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _FightingDojoBlackbelt4BattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt4EndBattleText:
; PRET| 	text_far _FightingDojoBlackbelt4EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| FightingDojoBlackbelt4AfterBattleText:
; PRET| 	text_far _FightingDojoBlackbelt4AfterBattleText
; PRET| 	text_end

FightingDojoHitmonleePokeBallText:
    CheckEitherEventSet EVENT_GOT_HITMONLEE, EVENT_GOT_HITMONCHAN
    jz .GetMon
    mov esi, FightingDojoBetterNotGetGreedyText
    call PrintText
    jmp .done

.GetMon:
    mov al, 43
    call DisplayPokedex
    mov esi, .Text
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .done
    mov al, [ebp + wCurPartySpecies]
    mov bh, al
    mov bl, 30
    call GivePokemon
    jae .done
    mov al, 74
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    SetEvents EVENT_GOT_HITMONLEE, EVENT_DEFEATED_FIGHTING_DOJO
.done:
    jmp TextScriptEnd

.Text:
    text_far _FightingDojoHitmonleePokeBallText
    text_end

FightingDojoHitmonchanPokeBallText:
    CheckEitherEventSet EVENT_GOT_HITMONLEE, EVENT_GOT_HITMONCHAN
    jz .GetMon
    mov esi, FightingDojoBetterNotGetGreedyText
    call PrintText
    jmp .done

.GetMon:
    mov al, 44
    call DisplayPokedex
    mov esi, .Text
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .done
    mov al, [ebp + wCurPartySpecies]
    mov bh, al
    mov bl, 30
    call GivePokemon
    jae .done
    SetEvents EVENT_GOT_HITMONCHAN, EVENT_DEFEATED_FIGHTING_DOJO
    mov al, 75
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
.done:
    jmp TextScriptEnd

.Text:
    text_far _FightingDojoHitmonchanPokeBallText
    text_end
FightingDojoBetterNotGetGreedyText:
    text_far _FightingDojoBetterNotGetGreedyText
    text_end
