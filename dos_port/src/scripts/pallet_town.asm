; pallet_town.asm — hand-translated text_asm scripts for Pallet Town.
;
; Reference port of the event/var-gated dialog in scripts/PalletTown.asm. This is
; the first faithful text_asm translation and the template for the rest: a script
; is a native routine reached from the map's TextTable via a SCRIPT entry
; (`dd <label>, 0xFFFFFFFF`, emitted by gen_npc_dialogs' SCRIPT_OVERRIDES). The
; dialog dispatcher (map_sprites.asm:CheckNPCInteraction) CALLs the routine after
; loading the font; the routine picks a text stream and prints it via ShowTextStream
; (PrintText on the flat stream, then wait for A/B), then returns.
;
; In: EBP = GB memory base; font already loaded; player frozen in a standing pose.
; The routine may use AL/flags freely (caller preserves via pushad).

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/audio_constants.inc"
%include "assets/event_constants.inc"
%include "events.inc"
%include "m8_2_pending_symbols.inc"   ; wSpriteIndex / wToggleableObjectIndex / emotion bubble scratch

global PalletTownOakText
global PalletTown_Script
global PalletTownDefaultScript
global PalletTownOakHeyWaitScript
global PalletTownOakWalksToPlayerScript
global PalletTownOakGreetsPlayerScript
global PalletTownPikachuBattleScript
global PalletTownAfterPikachuBattleScript
global PalletTownOakNotSafeComeWithMeScript
global PalletTownPlayerFollowsOakScript
global PalletTownDaisyScript
global PalletTownNoopScript
extern ShowTextStream            ; (ESI = flat TX stream — walked in place)
extern CallFunctionInTable       ; (AL = index, ESI = flat dd jumptable)
extern EnableAutoTextBoxDrawing
extern StopAllMusic              ; src/home/audio.asm
extern PlayMusic                 ; src/home/audio.asm (AL=id, BL=bank)
extern ShowObject                ; src/engine/overworld/toggleable_objects.asm
extern HideObject                ; src/engine/overworld/toggleable_objects.asm
extern Delay3                    ; src/video/frame.asm
extern DelayFrames               ; src/video/frame.asm (BL=count)
extern CalcPositionOfPlayerRelativeToNPC ; src/home/pathfinding.asm
extern FindPathToPlayer          ; src/home/pathfinding.asm
extern MoveSprite                ; src/home/pathfinding.asm (EDI=flat movement stream)
extern EmotionBubble             ; src/engine/overworld/trainer_engine.asm

; PalletTown_ScriptPointers state indices (pret: def_script_pointers in
; scripts/PalletTown.asm — SCRIPT_PALLETTOWN_*).
SCRIPT_PALLETTOWN_DEFAULT              equ 0
SCRIPT_PALLETTOWN_OAK_HEY_WAIT         equ 1
SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER  equ 2
SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER    equ 3
SCRIPT_PALLETTOWN_PIKACHU_BATTLE       equ 4
SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE equ 5
SCRIPT_PALLETTOWN_OAK_NOT_SAFE         equ 6
SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK   equ 7
SCRIPT_PALLETTOWN_DAISY                equ 8
SCRIPT_PALLETTOWN_NOOP                 equ 9

TEXT_PALLETTOWN_OAK                    equ 1
TEXT_PALLETTOWN_OAK_COME_WITH_ME       equ 8
PALLETTOWN_OAK                         equ 1
TOGGLE_DAISY_SITTING                   equ 0x28
TOGGLE_DAISY_WALKING                   equ 0x29
EXCLAMATION_BUBBLE                     equ 0

wSavedCoordIndex                       equ 0xCF0D
wOakWalkedToPlayer                     equ 0xCF0E
wSprite01StateData1MovementStatus      equ W_SPRITE_STATE_DATA_1 + 0x10 + SPRITESTATEDATA1_MOVEMENTSTATUS
wSprite01StateData1FacingDirection     equ W_SPRITE_STATE_DATA_1 + 0x10 + SPRITESTATEDATA1_FACINGDIRECTION
wSprite01StateData2MapY                equ W_SPRITE_STATE_DATA_2 + 0x10 + SPRITESTATEDATA2_MAPY
wSprite01StateData2MapX                equ W_SPRITE_STATE_DATA_2 + 0x10 + SPRITESTATEDATA2_MAPX

; ---------------------------------------------------------------------------
section .data

%include "assets/pallet_runtime_strings.inc"

; ---------------------------------------------------------------------------
section .text

PalletTownOakText:
    mov al, [ebp + wOakWalkedToPlayer]
    test al, al
    jnz .next
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    mov esi, oak_default_text
    call ShowTextStream
    mov bl, 10
    call DelayFrames
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], PLAYER_DIR_DOWN
    mov byte [ebp + wEmotionBubbleSpriteIndex], 0
    mov byte [ebp + wWhichEmotionBubble], EXCLAMATION_BUBBLE
    call EmotionBubble
    ret
.next:
    dec al
    jnz .whew
    mov esi, oak_got_text
    jmp .show
.whew:
    mov esi, oak_whew_text
.show:
    call ShowTextStream
    ret

PalletTownOakComeWithMe:
    mov esi, oak_come_with_me_text
    jmp ShowTextStream

; Temporary Pallet-local text dispatcher. Stage 2 owns the real DisplayTextID
; service closure; until then the Oak cutscene must not call the linked ret-stub.
DisplayPalletTownTextID:
    mov al, [ebp + hTextID]
    cmp al, TEXT_PALLETTOWN_OAK
    je PalletTownOakText
    cmp al, TEXT_PALLETTOWN_OAK_COME_WITH_ME
    je PalletTownOakComeWithMe
    ret

; ---------------------------------------------------------------------------
; PalletTown_Script — the map's per-frame _Script (RunMapScript dispatches here
; via MapScriptPointers[PALLET_TOWN]). Faithful skeleton of scripts/PalletTown.asm:
; PalletTown_Script: the event-gate, then CallFunctionInTable on the current-script
; index. The cutscene state routines themselves are deferred (they need scripted
; NPC movement + the Pikachu battle) and recorded as stubs below.
; ---------------------------------------------------------------------------
PalletTown_Script:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK   ; ZF=1 ⇒ flag clear
    jz .next
    SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS
.next:
    call EnableAutoTextBoxDrawing              ; faithful: pret calls this before dispatch
    mov al, [ebp + wPalletTownCurScript]
    mov esi, PalletTown_ScriptPointers
    jmp CallFunctionInTable                    ; tail-call: run the current state

PalletTownDefaultScript:
    CheckEvent EVENT_FOLLOWED_OAK_INTO_LAB
    jnz .ret
    cmp byte [ebp + W_Y_COORD], 0
    jne .ret
    ResetEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
    cmp byte [ebp + W_X_COORD], 10
    je .playerOnLeftExit
    SetEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
.playerOnLeftExit:
    mov byte [ebp + H_JOY_HELD], 0
    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
    mov byte [ebp + W_PLAYER_MOVING_DIRECTION], PLAYER_DIR_UP
    call StopAllMusic
    mov bl, MUSIC_MEET_PROF_OAK_BANK
    mov al, MUSIC_MEET_PROF_OAK
    call PlayMusic
    SetEvent EVENT_OAK_APPEARED_IN_PALLET
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_OAK_HEY_WAIT
.ret:
    ret

PalletTownOakHeyWaitScript:
    mov byte [ebp + W_JOY_IGNORE], PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov byte [ebp + wOakWalkedToPlayer], 0
    mov byte [ebp + hTextID], TEXT_PALLETTOWN_OAK
    call DisplayPalletTownTextID
    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
    mov byte [ebp + wSprite01StateData2MapY], 8
    mov byte [ebp + wSprite01StateData2MapX], 14
    mov byte [ebp + wToggleableObjectIndex], TOGGLE_PALLET_TOWN_OAK
    call ShowObject
    mov byte [ebp + wSprite01StateData1MovementStatus], 2
    mov byte [ebp + wSprite01StateData1FacingDirection], SPRITE_FACING_UP
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_OAK_WALKS_TO_PLAYER
    ret

PalletTownOakWalksToPlayerScript:
    call Delay3
    mov byte [ebp + W_Y_COORD], 0
    mov byte [ebp + H_NPC_PLAYER_RELATIVE_POS_PERSPECTIVE], 1
    mov byte [ebp + H_NPC_SPRITE_OFFSET], 0x10 ; PALLETTOWN_OAK slot offset
    call CalcPositionOfPlayerRelativeToNPC
    dec byte [ebp + H_NPC_PLAYER_Y_DISTANCE]
    call FindPathToPlayer
    mov byte [ebp + H_CURRENT_SPRITE_OFFSET], 0x10
    lea edi, [ebp + wNPCMovementDirections2]
    call MoveSprite
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_OAK_GREETS_PLAYER
    ret

PalletTownOakGreetsPlayerScript:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    jnz .ret
    mov byte [ebp + W_JOY_IGNORE], PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov byte [ebp + wOakWalkedToPlayer], 1
    mov byte [ebp + wSprite01StateData1MovementStatus], 2
    mov byte [ebp + wSprite01StateData1FacingDirection], SPRITE_FACING_UP
    mov byte [ebp + hTextID], TEXT_PALLETTOWN_OAK
    call DisplayPalletTownTextID
    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
    mov byte [ebp + wSprite01StateData1MovementStatus], 2
    CheckEvent EVENT_PLAYER_AT_RIGHT_EXIT_TO_PALLET_TOWN
    mov al, SPRITE_FACING_RIGHT
    jz .storeFacing
    mov al, SPRITE_FACING_LEFT
.storeFacing:
    mov [ebp + wSprite01StateData1FacingDirection], al
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_PIKACHU_BATTLE
.ret:
    ret

PalletTownPikachuBattleScript:
    mov byte [ebp + W_JOY_IGNORE], PAD_SELECT | PAD_START | PAD_CTRL_PAD
    mov byte [ebp + wListScrollOffset], 0
    mov byte [ebp + wBattleType], BATTLE_TYPE_PIKACHU
    mov byte [ebp + wCurOpponent], STARTER_PIKACHU
    mov byte [ebp + wCurEnemyLevel], 5
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_AFTER_PIKACHU_BATTLE
    ret

PalletTownAfterPikachuBattleScript:
    mov byte [ebp + wOakWalkedToPlayer], 2
    mov byte [ebp + hTextID], TEXT_PALLETTOWN_OAK
    call DisplayPalletTownTextID
    mov byte [ebp + wSprite01StateData1MovementStatus], 2
    mov byte [ebp + wSprite01StateData1FacingDirection], SPRITE_FACING_UP
    mov byte [ebp + hTextID], TEXT_PALLETTOWN_OAK_COME_WITH_ME
    call DisplayPalletTownTextID
    mov byte [ebp + W_JOY_IGNORE], PAD_BUTTONS | PAD_CTRL_PAD
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_OAK_NOT_SAFE
    ret

PalletTownOakNotSafeComeWithMeScript:
    mov byte [ebp + W_SPRITE_PLAYER_FACING_DIR], 0
    mov byte [ebp + wSpriteIndex], PALLETTOWN_OAK
    mov byte [ebp + W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM], 0
    mov byte [ebp + wNPCMovementScriptPointerTableNum], 1
    mov byte [ebp + W_NPC_MOVEMENT_SCRIPT_BANK], 0
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_PLAYER_FOLLOWS_OAK
    ret

PalletTownPlayerFollowsOakScript:
    cmp byte [ebp + wNPCMovementScriptPointerTableNum], 0
    jne .ret
    mov byte [ebp + wPalletTownCurScript], SCRIPT_PALLETTOWN_DAISY
.ret:
    ret

PalletTownDaisyScript:
    CheckEvent EVENT_DAISY_WALKING
    jnz .next
    CheckBothEventsSet EVENT_GOT_TOWN_MAP, EVENT_ENTERED_BLUES_HOUSE
    jnz .next
    SetEvent EVENT_DAISY_WALKING
    mov byte [ebp + wToggleableObjectIndex], TOGGLE_DAISY_SITTING
    call HideObject
    mov byte [ebp + wToggleableObjectIndex], TOGGLE_DAISY_WALKING
    call ShowObject
.next:
    CheckEvent EVENT_GOT_POKEBALLS_FROM_OAK
    jz PalletTownNoopScript
    SetEvent EVENT_PALLET_AFTER_GETTING_POKEBALLS_2
PalletTownNoopScript:
    ret

; ---------------------------------------------------------------------------
section .data
align 4

; Flat dd state table (pret: PalletTown_ScriptPointers, def_script_pointers).
PalletTown_ScriptPointers:
    dd PalletTownDefaultScript      ; SCRIPT_PALLETTOWN_DEFAULT
    dd PalletTownOakHeyWaitScript
    dd PalletTownOakWalksToPlayerScript
    dd PalletTownOakGreetsPlayerScript
    dd PalletTownPikachuBattleScript
    dd PalletTownAfterPikachuBattleScript
    dd PalletTownOakNotSafeComeWithMeScript
    dd PalletTownPlayerFollowsOakScript
    dd PalletTownDaisyScript
    dd PalletTownNoopScript         ; SCRIPT_PALLETTOWN_NOOP
