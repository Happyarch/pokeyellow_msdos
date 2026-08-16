; RocketHideoutB4F.asm — translated from pret scripts/RocketHideoutB4F.asm by dos_port/tools/sm83xlat.
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

global RocketHideoutB4FGiovanniHopeWeMeetAgainText
global RocketHideoutB4FGiovanniText
global RocketHideoutB4FJessieJamesEndBattleText
global RocketHideoutB4FJessieJamesMovementData_45605
global RocketHideoutB4FJessieJamesMovementData_45606
global RocketHideoutB4FResetScripts
global RocketHideoutB4FRocketText
global RocketHideoutB4FScript10
global RocketHideoutB4FScript12
global RocketHideoutB4FScript13
global RocketHideoutB4FScript8
global RocketHideoutB4FScript9
global RocketHideoutB4FScript_HideJessieJames
global RocketHideoutB4FScript_HideObject
global RocketHideoutB4FSetScript
global RocketHideoutB4FText12
global RocketHideoutB4FText13
global RocketHideoutB4F_Script
global RocketHideoutB4F_ScriptPointers

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EmotionBubble   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern EngageMapTrainer   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern GBFadeInFromBlack   ; NOT YET DEFINED IN THE PORT
extern GBFadeOutToBlack   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RocketHideout4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RocketHideout4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FBeatGiovanniScript   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FJessieJamesText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FRocketEndBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript11   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript4   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript5   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript6   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript7   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript_455a5   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FScript_ShowObject   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4FText11   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB4F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniHopeWeMeetAgainText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniImpressedYouGotHereText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FGiovanniWhatCannotBeText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutB4FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText2   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText3   ; NOT YET DEFINED IN THE PORT
extern _RocketHideoutJessieJamesText4   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROCKETHIDEOUTB4F_DEFAULT                equ 0
SCRIPT_ROCKETHIDEOUTB4F_BEAT_GIOVANNI          equ 3
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT4                equ 4
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT5                equ 5
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT8                equ 8
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT11               equ 11
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT12               equ 12
SCRIPT_ROCKETHIDEOUTB4F_SCRIPT13               equ 13
TEXT_ROCKETHIDEOUTB4F_GIOVANNI                 equ 1
TEXT_ROCKETHIDEOUTB4F_JAMES                    equ 2
TEXT_ROCKETHIDEOUTB4F_JESSIE                   equ 3
TEXT_ROCKETHIDEOUTB4F_ROCKET                   equ 4
TEXT_ROCKETHIDEOUTB4F_HP_UP                    equ 5
TEXT_ROCKETHIDEOUTB4F_TM_RAZOR_WIND            equ 6
TEXT_ROCKETHIDEOUTB4F_IRON                     equ 7
TEXT_ROCKETHIDEOUTB4F_SILPH_SCOPE              equ 8
TEXT_ROCKETHIDEOUTB4F_LIFT_KEY                 equ 9
TEXT_ROCKETHIDEOUTB4F_GIOVANNI_HOPE_WE_MEET_AGAIN equ 10
TEXT_ROCKETHIDEOUTB4F_TEXT11                   equ 11
TEXT_ROCKETHIDEOUTB4F_TEXT12                   equ 12
TEXT_ROCKETHIDEOUTB4F_TEXT13                   equ 13

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRocketHideoutB4FCurScript                     equ 0xD633
wSprite02StateData1FacingDirection             equ 0xC129
wSprite02StateData1MovementStatus              equ 0xC121
wSprite03StateData1FacingDirection             equ 0xC139
wSprite03StateData1MovementStatus              equ 0xC131

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RocketHideoutB4F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, RocketHideout4TrainerHeaders
    mov edi, RocketHideoutB4F_ScriptPointers   ; pret: ld de, RocketHideoutB4F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRocketHideoutB4FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRocketHideoutB4FCurScript], al
    ret

RocketHideoutB4FResetScripts:
    CheckAndResetEvent EVENT_6A0
    jz .sk_12
        call RocketHideoutB4FScript_HideJessieJames
.sk_12:
    xor al, al
    mov [ebp + wJoyIgnore], al
RocketHideoutB4FSetScript:
    mov [ebp + wRocketHideoutB4FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

RocketHideoutB4FScript_HideJessieJames:
    mov al, 134
    call RocketHideoutB4FScript_HideObject
    mov al, 135
    call RocketHideoutB4FScript_HideObject
    ret

RocketHideoutB4F_ScriptPointers:
    dd RocketHideoutB4FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd RocketHideoutB4FBeatGiovanniScript
    dd RocketHideoutB4FScript4
    dd RocketHideoutB4FScript5
    dd RocketHideoutB4FScript6
    dd RocketHideoutB4FScript7
    dd RocketHideoutB4FScript8
    dd RocketHideoutB4FScript9
    dd RocketHideoutB4FScript10
    dd RocketHideoutB4FScript11
    dd RocketHideoutB4FScript12
    dd RocketHideoutB4FScript13

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] RocketHideoutB4FBeatGiovanniScript (scripts/RocketHideoutB4F.asm:45-70) — at scripts/RocketHideoutB4F.asm:60: predef ShowObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, RocketHideoutB4FResetScripts
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI
; PRET| 	ld a, TEXT_ROCKETHIDEOUTB4F_GIOVANNI_HOPE_WE_MEET_AGAIN
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call GBFadeOutToBlack
; PRET| 	ld a, TOGGLE_ROCKET_HIDEOUT_B4F_GIOVANNI
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	ld a, TOGGLE_ROCKET_HIDEOUT_B4F_ITEM_4
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	call UpdateSprites
; PRET| 	call GBFadeInFromBlack
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_DEFAULT
; PRET| 	ld [wRocketHideoutB4FCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES
    jnz .sk_78
        call RocketHideoutB4FScript_455a5
.sk_78:
    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_4_TRAINER_2
    jnz .sk_80
        call CheckFightingMapTrainers
.sk_80:
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] RocketHideoutB4FScript_455a5 (scripts/RocketHideoutB4F.asm:84-123) — at scripts/RocketHideoutB4F.asm:90: .asm_455c2 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wYCoord]
; PRET| 	cp $e
; PRET| 	ret nz
; PRET| 	ResetEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	ld a, [wXCoord]
; PRET| 	cp $18
; PRET| 	jr z, .asm_455c2
; PRET| 	ld a, [wXCoord]
; PRET| 	cp $19
; PRET| 	ret nz
; PRET| 	SetEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| .asm_455c2
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetJessieJames)
; PRET| 	ld a, MUSIC_MEET_JESSIE_JAMES
; PRET| 	call PlayMusic
; PRET| 	call UpdateSprites
; PRET| 	call Delay3
; PRET| 	call UpdateSprites
; PRET| 	call Delay3
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, TEXT_ROCKETHIDEOUTB4F_TEXT11
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, TOGGLE_ROCKET_HIDEOUT_B4F_JAMES
; PRET| 	call RocketHideoutB4FScript_ShowObject
; PRET| 	ld a, TOGGLE_ROCKET_HIDEOUT_B4F_JESSIE
; PRET| 	call RocketHideoutB4FScript_ShowObject
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT4
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

RocketHideoutB4FJessieJamesMovementData_45605:
    db 0x4
RocketHideoutB4FJessieJamesMovementData_45606:
    db 0x4
    db 0x4
    db 0x4
    db 0xff

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] RocketHideoutB4FScript4 (scripts/RocketHideoutB4F.asm:134-146) — at scripts/RocketHideoutB4F.asm:134: de cannot hold the 32-bit address of RocketHideoutB4FJessieJamesMovementData_45605; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45605
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_45617
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45606
; PRET| .asm_45617
; PRET| 	ld a, ROCKETHIDEOUTB4F_JAMES
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT5
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] RocketHideoutB4FScript5 (scripts/RocketHideoutB4F.asm:149-180) — at scripts/RocketHideoutB4F.asm:160: .asm_4564a is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| RocketHideoutB4FScript6:
; PRET| 	ld a, $2
; PRET| 	ld [wSprite02StateData1MovementStatus], a
; PRET| 	ld a, SPRITE_FACING_LEFT
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_4564a
; PRET| 	ld a, SPRITE_FACING_DOWN
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| .asm_4564a
; PRET| 	call Delay3
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| RocketHideoutB4FScript7:
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45606
; PRET| 	CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
; PRET| 	jr z, .asm_4565f
; PRET| 	ld de, RocketHideoutB4FJessieJamesMovementData_45605
; PRET| .asm_4565f
; PRET| 	ld a, ROCKETHIDEOUTB4F_JESSIE
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT8
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

RocketHideoutB4FScript8:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_187
        ret
.nr_187:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
RocketHideoutB4FScript9:
    mov al, 0x2
    mov [ebp + wSprite03StateData1MovementStatus], al
    mov al, SPRITE_FACING_DOWN
    mov [ebp + wSprite03StateData1FacingDirection], al
    CheckEvent EVENT_ROCKET_HIDEOUT_4_JESSIE_JAMES_ON_LEFT
    jz .asm_45697
    mov al, SPRITE_FACING_RIGHT
    mov [ebp + wSprite03StateData1FacingDirection], al
.asm_45697:
    call Delay3
    mov al, TEXT_ROCKETHIDEOUTB4F_TEXT12
    mov [ebp + hTextID], al
    call DisplayTextID
RocketHideoutB4FScript10:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, RocketHideoutB4FJessieJamesEndBattleText
    mov edx, RocketHideoutB4FJessieJamesEndBattleText   ; pret: ld de, RocketHideoutB4FJessieJamesEndBattleText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_ROCKET
    mov [ebp + wCurOpponent], al
    mov al, 0x2b
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_6A0
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT11
    call RocketHideoutB4FSetScript
    ret

; ---------------------------------------------------------------------------
; BAIL[bank-expression] RocketHideoutB4FScript11 (scripts/RocketHideoutB4F.asm:224-252) — at scripts/RocketHideoutB4F.asm:245: BANK(Music_MeetJessieJames)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, RocketHideoutB4FResetScripts
; PRET| 	ld a, $2
; PRET| 	ld [wSprite02StateData1MovementStatus], a
; PRET| 	ld [wSprite03StateData1MovementStatus], a
; PRET| 	xor a
; PRET| 	ld [wSprite02StateData1FacingDirection], a
; PRET| 	ld [wSprite03StateData1FacingDirection], a
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, TEXT_ROCKETHIDEOUTB4F_TEXT13
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetJessieJames)
; PRET| 	ld a, MUSIC_MEET_JESSIE_JAMES
; PRET| 	call PlayMusic
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT12
; PRET| 	call RocketHideoutB4FSetScript
; PRET| 	ret

RocketHideoutB4FScript12:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call GBFadeOutToBlack
    mov al, 134
    call RocketHideoutB4FScript_HideObject
    mov al, 135
    call RocketHideoutB4FScript_HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    mov al, SCRIPT_ROCKETHIDEOUTB4F_SCRIPT13
    call RocketHideoutB4FSetScript
    ret

RocketHideoutB4FScript13:
    call PlayDefaultMusic
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    SetEvent EVENT_BEAT_ROCKET_HIDEOUT_4_JESSIE_JAMES
    mov al, SCRIPT_ROCKETHIDEOUTB4F_DEFAULT
    call RocketHideoutB4FSetScript
    ret

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] RocketHideoutB4FScript_ShowObject (scripts/RocketHideoutB4F.asm:280-284) — at scripts/RocketHideoutB4F.asm:281: predef ShowObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	call UpdateSprites
; PRET| 	call Delay3
; PRET| 	ret

RocketHideoutB4FScript_HideObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] RocketHideoutB4F_TextPointers (scripts/RocketHideoutB4F.asm:292-317) — a generated asset already defines RocketHideout4TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const RocketHideoutB4FGiovanniText,                TEXT_ROCKETHIDEOUTB4F_GIOVANNI
; PRET| 	dw_const RocketHideoutB4FJessieJamesText,             TEXT_ROCKETHIDEOUTB4F_JAMES
; PRET| 	dw_const RocketHideoutB4FJessieJamesText,             TEXT_ROCKETHIDEOUTB4F_JESSIE
; PRET| 	dw_const RocketHideoutB4FRocketText,                  TEXT_ROCKETHIDEOUTB4F_ROCKET
; PRET| 	dw_const PickUpItemText,                              TEXT_ROCKETHIDEOUTB4F_HP_UP
; PRET| 	dw_const PickUpItemText,                              TEXT_ROCKETHIDEOUTB4F_TM_RAZOR_WIND
; PRET| 	dw_const PickUpItemText,                              TEXT_ROCKETHIDEOUTB4F_IRON
; PRET| 	dw_const PickUpItemText,                              TEXT_ROCKETHIDEOUTB4F_SILPH_SCOPE
; PRET| 	dw_const PickUpItemText,                              TEXT_ROCKETHIDEOUTB4F_LIFT_KEY
; PRET| 	dw_const RocketHideoutB4FGiovanniHopeWeMeetAgainText, TEXT_ROCKETHIDEOUTB4F_GIOVANNI_HOPE_WE_MEET_AGAIN
; PRET| 	dw_const RocketHideoutB4FText11,                      TEXT_ROCKETHIDEOUTB4F_TEXT11
; PRET| 	dw_const RocketHideoutB4FText12,                      TEXT_ROCKETHIDEOUTB4F_TEXT12
; PRET| 	dw_const RocketHideoutB4FText13,                      TEXT_ROCKETHIDEOUTB4F_TEXT13
; PRET| 
; PRET| RocketHideout4TrainerHeaders:
; PRET| 	def_trainers 4
; PRET| RocketHideout4TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_ROCKET_HIDEOUT_4_TRAINER_2, 1, RocketHideoutB4FRocketBattleText, RocketHideoutB4FRocketEndBattleText, RocketHideoutB4FRocketAfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| RocketHideoutB4FJessieJamesText:
; PRET| 	text_end
; PRET| 
; PRET| RocketHideoutB4FText11:
; PRET| 	text_far _RocketHideoutJessieJamesText1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] scripts/RocketHideoutB4F.asm:anon (scripts/RocketHideoutB4F.asm:319-330) — at scripts/RocketHideoutB4F.asm:327: predef EmotionBubble
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld c, 10
; PRET| 	call DelayFrames
; PRET| 	ld a, $8
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, $0
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	ld a, EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	ld c, 20
; PRET| 	call DelayFrames
; PRET| 	jp TextScriptEnd

RocketHideoutB4FText12:
    text_far _RocketHideoutJessieJamesText2
    text_end
RocketHideoutB4FJessieJamesEndBattleText:
    text_far _RocketHideoutJessieJamesText3
    text_end
RocketHideoutB4FText13:
    text_far _RocketHideoutJessieJamesText4

    mov bl, 64
    call DelayFrames
    jmp TextScriptEnd

RocketHideoutB4FGiovanniText:
    CheckEvent EVENT_BEAT_ROCKET_HIDEOUT_GIOVANNI
    jnz .beat_giovanni
    mov esi, .ImpressedYouGotHereText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .WhatCannotBeText
    mov edx, .WhatCannotBeText   ; pret: ld de, .WhatCannotBeText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, SCRIPT_ROCKETHIDEOUTB4F_BEAT_GIOVANNI
    mov [ebp + wRocketHideoutB4FCurScript], al
    mov [ebp + wCurMapScript], al
    jmp .done

.beat_giovanni:
    mov esi, RocketHideoutB4FGiovanniHopeWeMeetAgainText
    call PrintText
.done:
    jmp TextScriptEnd

.ImpressedYouGotHereText:
    text_far _RocketHideoutB4FGiovanniImpressedYouGotHereText
    text_end
.WhatCannotBeText:
    text_far _RocketHideoutB4FGiovanniWhatCannotBeText
    text_end
RocketHideoutB4FGiovanniHopeWeMeetAgainText:
    text_far _RocketHideoutB4FGiovanniHopeWeMeetAgainText
    text_end

RocketHideoutB4FRocketText:
    mov esi, RocketHideout4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] RocketHideoutB4FRocketBattleText (scripts/RocketHideoutB4F.asm:394-399) — a generated asset already defines RocketHideoutB4FRocketBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _RocketHideoutB4FRocketBattleText
; PRET| 	text_end
; PRET| 
; PRET| RocketHideoutB4FRocketEndBattleText:
; PRET| 	text_far _RocketHideoutB4FRocketEndBattleText
; PRET| 	text_promptbutton

    SetEvent EVENT_ROCKET_DROPPED_LIFT_KEY
    mov al, 140
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ShowObject
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] RocketHideoutB4FRocketAfterBattleText (scripts/RocketHideoutB4F.asm:409-411) — a generated asset already defines RocketHideoutB4FRocketAfterBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	jp TextScriptEnd

.Text:
    text_far _RocketHideoutB4FRocketAfterBattleText
    text_end
