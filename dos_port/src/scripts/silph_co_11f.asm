; SilphCo11F.asm — translated from pret scripts/SilphCo11F.asm, scripts/SilphCo11F_2.asm by dos_port/tools/sm83xlat.
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

global SilphCo11FGateCallbackScript
global SilphCo11FGiovanniAfterBattleScript
global SilphCo11FGiovanniStartBattleScript
global SilphCo11FMovementData_622f5
global SilphCo11FMovementData_622fb
global SilphCo11FMovementData_62300
global SilphCo11FMovementData_62305
global SilphCo11FMovementData_6230b
global SilphCo11FMovementData_62311
global SilphCo11FResetCurScript
global SilphCo11FRocketText
global SilphCo11FScript10
global SilphCo11FScript11
global SilphCo11FScript13
global SilphCo11FScript9
global SilphCo11FScript_621c5
global SilphCo11FScript_621ff
global SilphCo11FScript_HideObject
global SilphCo11FSetCurScript
global SilphCo11FSetUnlockedDoorEventScript
global SilphCo11FText10
global SilphCo11FText9
global SilphCo11FText_624c2
global SilphCo11F_Script
global SilphCo11F_ScriptPointers
global SilphCo11GateCoords

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
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
extern GiveItem   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern InitBattleEnemyParameters   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern ShowObject   ; NOT YET DEFINED IN THE PORT
extern SilphCo10FGiovanniILostAgainText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FBeautyText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FGiovanniText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FGiovanniYouRuinedOurPlansText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FJessieJamesText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FRocketAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FRocketEndBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript12   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript14   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript5   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript6   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript7   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript8   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript_6229c   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FScript_ShowObject   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FSilphPresidentText   ; NOT YET DEFINED IN THE PORT
extern SilphCo11FTeamRocketLeavesScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo11F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo11F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo11TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo11TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern UpdateSprites   ; NOT YET DEFINED IN THE PORT
extern _SilphCo11FSilphPresidentReceivedMasterBallText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo11FSilphPresidentText   ; NOT YET DEFINED IN THE PORT
extern _SilphCoJessieJamesText2   ; NOT YET DEFINED IN THE PORT
extern _SilphCoJessieJamesText3   ; NOT YET DEFINED IN THE PORT
extern _SilphCoJessieJamesText4   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_SILPHCO11F_DEFAULT                      equ 0
SCRIPT_SILPHCO11F_GIOVANNI_AFTER_BATTLE        equ 3
SCRIPT_SILPHCO11F_GIOVANNI_START_BATTLE        equ 4
SCRIPT_SILPHCO11F_SCRIPT5                      equ 5
SCRIPT_SILPHCO11F_SCRIPT6                      equ 6
SCRIPT_SILPHCO11F_SCRIPT9                      equ 9
SCRIPT_SILPHCO11F_SCRIPT12                     equ 12
SCRIPT_SILPHCO11F_SCRIPT13                     equ 13
SCRIPT_SILPHCO11F_SCRIPT14                     equ 14
TEXT_SILPHCO11F_SILPH_PRESIDENT                equ 1
TEXT_SILPHCO11F_BEAUTY                         equ 2
TEXT_SILPHCO11F_GIOVANNI                       equ 3
TEXT_SILPHCO11F_JAMES                          equ 4
TEXT_SILPHCO11F_ROCKET                         equ 5
TEXT_SILPHCO11F_JESSIE                         equ 6
TEXT_SILPHCO11F_GIOVANNI_YOU_RUINED_OUR_PLANS  equ 7
TEXT_SILPHCO11F_TEXT8                          equ 8
TEXT_SILPHCO11F_TEXT9                          equ 9
TEXT_SILPHCO11F_TEXT10                         equ 10

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wCoordIndex                                    equ 0xCD3D
wSavedCoordIndex                               equ 0xCF0D
wSilphCo11FCurScript                           equ 0xD658
wSprite03StateData1FacingDirection             equ 0xC139
wSprite03StateData1MovementStatus              equ 0xC131
wSprite04StateData1FacingDirection             equ 0xC149
wSprite04StateData1MovementStatus              equ 0xC141
wSprite06StateData1FacingDirection             equ 0xC169
wSprite06StateData1MovementStatus              equ 0xC161

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

SilphCo11F_Script:
    call SilphCo11FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo11TrainerHeaders
    mov edi, SilphCo11F_ScriptPointers   ; pret: ld de, SilphCo11F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo11FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo11FCurScript], al
    ret

SilphCo11FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, SilphCo11GateCoords
    call SilphCo11F_SetCardKeyDoorYScript
    call SilphCo11FSetUnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_11_UNLOCKED_DOOR
    jz .nr_20
        ret
.nr_20:
    mov al, 0x20
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (3)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    ret

SilphCo11GateCoords:
    db 6, 3
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo11F_SetCardKeyDoorYScript (scripts/SilphCo11F.asm:32-52) — at scripts/SilphCo11F.asm:42: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push hl
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	ld a, [hli]
; PRET| 	ld b, a
; PRET| 	ld a, [hl]
; PRET| 	ld c, a
; PRET| 	xor a
; PRET| 	ldh [hUnlockedSilphCoDoors], a
; PRET| 	pop hl
; PRET| .loop_check_doors
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .exit_loop
; PRET| 	push hl
; PRET| 	ld hl, hUnlockedSilphCoDoors
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	cp b
; PRET| 	jr z, .check_y_coord
; PRET| 	inc hl
; PRET| 	jr .loop_check_doors

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo11F_SetCardKeyDoorYScript.check_y_coord (scripts/SilphCo11F.asm:54-61) — at scripts/SilphCo11F.asm:54: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	cp c
; PRET| 	jr nz, .loop_check_doors
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	xor a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 	ret

.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

SilphCo11FSetUnlockedDoorEventScript:
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_70
        ret
.nr_70:
    SetEvent EVENT_SILPH_CO_11_UNLOCKED_DOOR
    ret

SilphCo11FResetCurScript:
    xor al, al
    mov [ebp + wJoyIgnore], al
SilphCo11FSetCurScript:
    mov [ebp + wSilphCo11FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

SilphCo11F_ScriptPointers:
    dd SilphCo11FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle
    dd SilphCo11FGiovanniAfterBattleScript
    dd SilphCo11FGiovanniStartBattleScript
    dd SilphCo11FScript5
    dd SilphCo11FScript6
    dd SilphCo11FScript7
    dd SilphCo11FScript8
    dd SilphCo11FScript9
    dd SilphCo11FScript10
    dd SilphCo11FScript11
    dd SilphCo11FScript12
    dd SilphCo11FScript13
    dd SilphCo11FScript14

    CheckEvent EVENT_BEAT_SILPH_CO_11F_JESSIE_JAMES
    jnz .sk_107
        call SilphCo11FScript_6229c
.sk_107:
    CheckEvent EVENT_782
    jz .nr_109
        ret
.nr_109:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .sk_111
        call SilphCo11FScript_621c5
.sk_111:
    ret

SilphCo11FScript_621c5:
    mov esi, .PlayerCoordsArray
    call ArePlayerCoordsInArray
    jae CheckFightingMapTrainers
    mov al, [ebp + wCoordIndex]
    mov [ebp + wSavedCoordIndex], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SILPHCO11F_GIOVANNI
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, 3
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov edi, .GiovanniMovement   ; pret: ld de, .GiovanniMovement — MoveSprite takes it in EDI
    call MoveSprite
    mov al, SCRIPT_SILPHCO11F_GIOVANNI_START_BATTLE
    call SilphCo11FSetCurScript
    ret

.PlayerCoordsArray:
    db 13, 6
    db 12, 7
    db -1
.GiovanniMovement:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

SilphCo11FScript_621ff:
    mov [ebp + wPlayerMovingDirection], al
    mov al, bh
    mov [ebp + wSprite03StateData1FacingDirection], al
    mov al, 0x2
    mov [ebp + wSprite03StateData1MovementStatus], al
    ret

SilphCo11FGiovanniAfterBattleScript:
    mov al, [ebp + wIsInBattle]
    cmp al, 0xff
    jz SilphCo11FResetCurScript
    mov al, [ebp + wSavedCoordIndex]
    cmp al, 1
    jz .face_player_up
    mov al, PLAYER_DIR_LEFT
    mov bh, SPRITE_FACING_RIGHT
    jmp .continue

.face_player_up:
    mov al, PLAYER_DIR_UP
    mov bh, SPRITE_FACING_DOWN
.continue:
    call SilphCo11FScript_621ff
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, TEXT_SILPHCO11F_GIOVANNI_YOU_RUINED_OUR_PLANS
    mov [ebp + hTextID], al
    call DisplayTextID
    call GBFadeOutToBlack
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call SilphCo11FTeamRocketLeavesScript
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    SetEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    xor al, al
    mov [ebp + wJoyIgnore], al
    jmp SilphCo11FSetCurScript

SilphCo11FGiovanniStartBattleScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_188
        ret
.nr_188:
    mov al, 3
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov al, [ebp + wSavedCoordIndex]
    cmp al, 1
    jz .face_player_up
    mov al, PLAYER_DIR_LEFT
    mov bh, SPRITE_FACING_RIGHT
    jmp .continue

.face_player_up:
    mov al, PLAYER_DIR_UP
    mov bh, SPRITE_FACING_DOWN
.continue:
    call SilphCo11FScript_621ff
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, SilphCo10FGiovanniILostAgainText
    mov edx, SilphCo10FGiovanniILostAgainText   ; pret: ld de, SilphCo10FGiovanniILostAgainText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, [ebp + hSpriteIndex]
    mov [ebp + wSpriteIndex], al
    call EngageMapTrainer
    call InitBattleEnemyParameters
    mov al, SCRIPT_SILPHCO11F_GIOVANNI_AFTER_BATTLE
    jmp SilphCo11FSetCurScript

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo11FScript_6229c (scripts/SilphCo11F.asm:220-257) — at scripts/SilphCo11F.asm:229: .asm_622c3 is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wYCoord]
; PRET| 	cp $3
; PRET| 	ret nz
; PRET| 	ld a, [wXCoord]
; PRET| 	cp $4
; PRET| 	ret nc
; PRET| 	ResetEvents EVENT_780, EVENT_781
; PRET| 	ld a, [wXCoord]
; PRET| 	cp $3
; PRET| 	jr z, .asm_622c3
; PRET| 	SetEventReuseHL EVENT_780
; PRET| 	ld a, [wXCoord]
; PRET| 	cp $2
; PRET| 	jr z, .asm_622c3
; PRET| 	ResetEventReuseHL EVENT_780
; PRET| 	SetEventReuseHL EVENT_781
; PRET| .asm_622c3
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetJessieJames)
; PRET| 	ld a, MUSIC_MEET_JESSIE_JAMES
; PRET| 	call PlayMusic
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, TEXT_SILPHCO11F_TEXT8
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_782
; PRET| 	ld a, SCRIPT_SILPHCO11F_SCRIPT5
; PRET| 	call SilphCo11FSetCurScript
; PRET| 	ret

SilphCo11FMovementData_622f5:
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0xff
SilphCo11FMovementData_622fb:
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0xff
SilphCo11FMovementData_62300:
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0xff
SilphCo11FMovementData_62305:
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0x5
    db 0xff
SilphCo11FMovementData_6230b:
    db 0x5
    db 0x5
    db 0x6
    db 0x5
    db 0x5
    db 0xff
SilphCo11FMovementData_62311:
    db 0x5
    db 0x5
    db 0x5
    db 0x6
    db 0x5
    db 0x5
    db 0xff

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] SilphCo11FScript5 (scripts/SilphCo11F.asm:307-323) — at scripts/SilphCo11F.asm:307: de cannot hold the 32-bit address of SilphCo11FMovementData_622f5; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld de, SilphCo11FMovementData_622f5
; PRET| 	CheckEitherEventSet EVENT_780, EVENT_781
; PRET| 	and a
; PRET| 	jr z, .asm_6232d
; PRET| 	ld de, SilphCo11FMovementData_62300
; PRET| 	cp $1
; PRET| 	jr z, .asm_6232d
; PRET| 	ld de, SilphCo11FMovementData_6230b
; PRET| .asm_6232d
; PRET| 	ld a, SILPHCO11F_JAMES
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_SILPHCO11F_SCRIPT6
; PRET| 	call SilphCo11FSetCurScript
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo11FScript6 (scripts/SilphCo11F.asm:326-361) — at scripts/SilphCo11F.asm:338: .asm_6235e is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wStatusFlags5]
; PRET| 	bit BIT_SCRIPTED_NPC_MOVEMENT, a
; PRET| 	ret nz
; PRET| SilphCo11FScript7:
; PRET| 	ld a, $2
; PRET| 	ld [wSprite04StateData1MovementStatus], a
; PRET| 	ld hl, wSprite04StateData1FacingDirection
; PRET| 	ld [hl], SPRITE_FACING_RIGHT
; PRET| 	CheckEitherEventSet EVENT_780, EVENT_781
; PRET| 	and a
; PRET| 	jr z, .asm_6235e
; PRET| 	ld [hl], SPRITE_FACING_UP
; PRET| .asm_6235e
; PRET| 	call Delay3
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| SilphCo11FScript8:
; PRET| 	ld de, SilphCo11FMovementData_622fb
; PRET| 	CheckEitherEventSet EVENT_780, EVENT_781
; PRET| 	and a
; PRET| 	jr z, .asm_6237b
; PRET| 	ld de, SilphCo11FMovementData_62305
; PRET| 	cp $1
; PRET| 	jr z, .asm_6237b
; PRET| 	ld de, SilphCo11FMovementData_62311
; PRET| .asm_6237b
; PRET| 	ld a, SILPHCO11F_JESSIE
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, SCRIPT_SILPHCO11F_SCRIPT9
; PRET| 	call SilphCo11FSetCurScript
; PRET| 	ret

SilphCo11FScript9:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_368
        ret
.nr_368:
    mov al, PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
SilphCo11FScript10:
    mov al, 0x2
    mov [ebp + wSprite06StateData1MovementStatus], al
    mov esi, wSprite06StateData1FacingDirection
    mov byte [ebp + esi], SPRITE_FACING_UP
    CheckEitherEventSet EVENT_780, EVENT_781
    test al, al
    jz .asm_623b1
    mov byte [ebp + esi], SPRITE_FACING_LEFT
.asm_623b1:
    call Delay3
    mov al, TEXT_SILPHCO11F_TEXT9
    mov [ebp + hTextID], al
    call DisplayTextID
SilphCo11FScript11:
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, SilphCo11FText_624c2
    mov edx, SilphCo11FText_624c2   ; pret: ld de, SilphCo11FText_624c2 — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_ROCKET
    mov [ebp + wCurOpponent], al
    mov al, 0x2d
    mov [ebp + wTrainerNo], al
    xor al, al
    mov [ebp + hJoyHeld], al
    mov [ebp + wJoyIgnore], al
    mov al, SCRIPT_SILPHCO11F_SCRIPT12
    call SilphCo11FSetCurScript
    ret

; ---------------------------------------------------------------------------
; BAIL[bank-expression] SilphCo11FScript12 (scripts/SilphCo11F.asm:404-432) — at scripts/SilphCo11F.asm:425: BANK(Music_MeetJessieJames)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, SilphCo11FResetCurScript
; PRET| 	ld a, $2
; PRET| 	ld [wSprite04StateData1MovementStatus], a
; PRET| 	ld [wSprite06StateData1MovementStatus], a
; PRET| 	xor a
; PRET| 	ld [wSprite04StateData1FacingDirection], a
; PRET| 	ld [wSprite06StateData1FacingDirection], a
; PRET| 	ld a, PAD_SELECT | PAD_START | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld a, TEXT_SILPHCO11F_TEXT10
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
; PRET| 	ld a, SCRIPT_SILPHCO11F_SCRIPT13
; PRET| 	call SilphCo11FSetCurScript
; PRET| 	ret

SilphCo11FScript13:
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    call GBFadeOutToBlack
    mov al, 188
    call SilphCo11FScript_HideObject
    mov al, 190
    call SilphCo11FScript_HideObject
    call UpdateSprites
    call Delay3
    call GBFadeInFromBlack
    mov al, SCRIPT_SILPHCO11F_SCRIPT14
    call SilphCo11FSetCurScript
    ret

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] SilphCo11FScript14 (scripts/SilphCo11F.asm:450-458) — at scripts/SilphCo11F.asm:455: SetEventReuseHL EVENT_BEAT_SILPH_CO_11F_JESSIE_JAMES
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call PlayDefaultMusic
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ResetEvent EVENT_782
; PRET| 	SetEventReuseHL EVENT_BEAT_SILPH_CO_11F_JESSIE_JAMES
; PRET| 	ld a, SCRIPT_SILPHCO11F_DEFAULT
; PRET| 	call SilphCo11FSetCurScript
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] SilphCo11FScript_ShowObject (scripts/SilphCo11F.asm:461-465) — at scripts/SilphCo11F.asm:462: predef ShowObject
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	call UpdateSprites
; PRET| 	call Delay3
; PRET| 	ret

SilphCo11FScript_HideObject:
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo11F_TextPointers (scripts/SilphCo11F.asm:473-492) — a generated asset already defines SilphCo11TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const SilphCo11FSilphPresidentText,            TEXT_SILPHCO11F_SILPH_PRESIDENT
; PRET| 	dw_const SilphCo11FBeautyText,                    TEXT_SILPHCO11F_BEAUTY
; PRET| 	dw_const SilphCo11FGiovanniText,                  TEXT_SILPHCO11F_GIOVANNI
; PRET| 	dw_const SilphCo11FJessieJamesText,               TEXT_SILPHCO11F_JAMES
; PRET| 	dw_const SilphCo11FRocketText,                    TEXT_SILPHCO11F_ROCKET
; PRET| 	dw_const SilphCo11FJessieJamesText,               TEXT_SILPHCO11F_JESSIE
; PRET| 	dw_const SilphCo11FGiovanniYouRuinedOurPlansText, TEXT_SILPHCO11F_GIOVANNI_YOU_RUINED_OUR_PLANS
; PRET| 	dw_const SilphCo11FJessieJamesText,               TEXT_SILPHCO11F_TEXT8
; PRET| 	dw_const SilphCo11FText9,                         TEXT_SILPHCO11F_TEXT9
; PRET| 	dw_const SilphCo11FText10,                        TEXT_SILPHCO11F_TEXT10
; PRET| 
; PRET| SilphCo11TrainerHeaders:
; PRET| 	def_trainers 5
; PRET| SilphCo11TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_SILPH_CO_11F_TRAINER_0, 3, SilphCo11FRocketBattleText, SilphCo11FRocketEndBattleText, SilphCo11FRocketAfterBattleText
; PRET| 	db -1 ; end
; PRET| 
; PRET| SilphCo11FJessieJamesText:
; PRET| 	text_far _SilphCoJessieJamesText1

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] scripts/SilphCo11F.asm:anon (scripts/SilphCo11F.asm:494-505) — at scripts/SilphCo11F.asm:502: predef EmotionBubble
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld c, 10
; PRET| 	call DelayFrames
; PRET| 	ld a, $4
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, $0
; PRET| 	ld [wEmotionBubbleSpriteIndex], a
; PRET| 	ld a, EXCLAMATION_BUBBLE
; PRET| 	ld [wWhichEmotionBubble], a
; PRET| 	predef EmotionBubble
; PRET| 	ld c, 20
; PRET| 	call DelayFrames
; PRET| 	jp TextScriptEnd

SilphCo11FText9:
    text_far _SilphCoJessieJamesText2
    text_end
SilphCo11FText_624c2:
    text_far _SilphCoJessieJamesText3
    text_end
SilphCo11FText10:
    text_far _SilphCoJessieJamesText4

    mov bl, 64
    call DelayFrames
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo11FSilphPresidentText (scripts/SilphCo11F.asm:524-534) — at scripts/SilphCo11F.asm:525: .got_item is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_GOT_MASTER_BALL
; PRET| 	jp nz, .got_item
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	lb bc, MASTER_BALL, 1
; PRET| 	call GiveItem
; PRET| 	jr nc, .bag_full
; PRET| 	ld hl, .ReceivedMasterBallText
; PRET| 	call PrintText
; PRET| 	SetEvent EVENT_GOT_MASTER_BALL
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo11FSilphPresidentText.bag_full (scripts/SilphCo11F.asm:536-538) — at scripts/SilphCo11F.asm:536: .NoRoomText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .NoRoomText
; PRET| 	call PrintText
; PRET| 	jr .done

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] SilphCo11FSilphPresidentText.got_item (scripts/SilphCo11F.asm:540-543) — at scripts/SilphCo11F.asm:540: .MasterBallDescriptionText is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .MasterBallDescriptionText
; PRET| 	call PrintText
; PRET| .done
; PRET| 	jp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] SilphCo11FSilphPresidentText.Text (scripts/SilphCo11F.asm:546-576) — at scripts/SilphCo11F.asm:551: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo11FSilphPresidentText
; PRET| 	text_end
; PRET| 
; PRET| .ReceivedMasterBallText:
; PRET| 	text_far _SilphCo11FSilphPresidentReceivedMasterBallText
; PRET| 	sound_get_key_item
; PRET| 	text_end
; PRET| 
; PRET| .MasterBallDescriptionText:
; PRET| 	text_far _SilphCo11FSilphPresidentMasterBallDescriptionText
; PRET| 	text_end
; PRET| 
; PRET| .NoRoomText:
; PRET| 	text_far _SilphCo11FSilphPresidentNoRoomText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo11FBeautyText:
; PRET| 	text_far _SilphCo11FBeautyText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo11FGiovanniText:
; PRET| 	text_far _SilphCo11FGiovanniText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo10FGiovanniILostAgainText:
; PRET| 	text_far _SilphCo10FGiovanniILostAgainText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo11FGiovanniYouRuinedOurPlansText:
; PRET| 	text_far _SilphCo11FGiovanniYouRuinedOurPlansText
; PRET| 	text_end

SilphCo11FRocketText:
    mov esi, SilphCo11TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] SilphCo11FRocketBattleText (scripts/SilphCo11F.asm:585-594) — a generated asset already defines SilphCo11FRocketBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SilphCo11FRocket2BattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo11FRocketEndBattleText:
; PRET| 	text_far _SilphCo11FRocket2EndBattleText
; PRET| 	text_end
; PRET| 
; PRET| SilphCo11FRocketAfterBattleText:
; PRET| 	text_far _SilphCo11FRocket2AfterBattleText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo11FTeamRocketLeavesScript (scripts/SilphCo11F_2.asm:2-11) — at scripts/SilphCo11F_2.asm:4: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .HideToggleableObjectIDs
; PRET| .hide_loop
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .done_hiding
; PRET| 	push hl
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef HideObject
; PRET| 	pop hl
; PRET| 	jr .hide_loop

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo11FTeamRocketLeavesScript.done_hiding (scripts/SilphCo11F_2.asm:13-22) — at scripts/SilphCo11F_2.asm:15: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .ShowToggleableObjectIDs
; PRET| .show_loop
; PRET| 	ld a, [hli]
; PRET| 	cp -1
; PRET| 	ret z
; PRET| 	push hl
; PRET| 	ld [wToggleableObjectIndex], a
; PRET| 	predef ShowObject
; PRET| 	pop hl
; PRET| 	jr .show_loop

.ShowToggleableObjectIDs:
    db 18
    db 19
    db 20
    db 21
    db 22
    db 23
    db -1
.HideToggleableObjectIDs:
    db 11
    db 12
    db 13
    db 14
    db 15
    db 16
    db 17
    db 24
    db 25
    db 142
    db 143
    db 144
    db 145
    db 146
    db 147
    db 149
    db 150
    db 151
    db 155
    db 156
    db 157
    db 158
    db 162
    db 163
    db 164
    db 167
    db 168
    db 169
    db 170
    db 175
    db 176
    db 177
    db 178
    db 179
    db 180
    db 181
    db 182
    db 187
    db 188
    db 189
    db 190
    db -1
