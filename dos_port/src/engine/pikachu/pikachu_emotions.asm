; pikachu_emotions.asm — pret mirror of engine/pikachu/pikachu_emotions.asm.
;
; Phase 3 Overworld Follower Pikachu Subsystem:
; - IsPlayerTalkingToPikachu, InitializePikachuTextID
; - DoStarterPikachuEmotions (bytecode interpreter)
; - StarterPikachuEmotionsJumptable, StarterPikachuEmotionCommand_* handlers
; - TalkToPikachu, PlaySpecificPikachuEmotion
; - MapSpecificPikachuExpression, IsPlayerPikachuAsleepInParty
; - PikachuWalksToNurseJoy counter hop animation
; - PikachuEmotionTable and PikachuEmotion33
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX (D=DH,E=DL);
; GB memory = [ebp + SYM] (gb_memmap.inc).

bits 32

%include "gb_macros.inc"
%include "assets/map_dims.inc"   ; map-id / tileset-id constants (Tier-1 generated)
%include "gb_memmap.inc"
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------

section .text

global IsPlayerTalkingToPikachu
global InitializePikachuTextID
global DoStarterPikachuEmotions
global StarterPikachuEmotionsJumptable
global StarterPikachuEmotionCommand_nop
global StarterPikachuEmotionCommand_nop3
global StarterPikachuEmotionCommand_text
global StarterPikachuEmotionCommand_pcm
global PlayPikachuSoundClip_
global StarterPikachuEmotionCommand_emote
global ShowPikachuEmoteBubble
global StarterPikachuEmotionCommand_movement
global StarterPikachuEmotionCommand_delay
global StarterPikachuEmotionCommand_subcmd
global StarterPikachuEmotionCommand_nop2
global StarterPikachuEmotionCommand_9
global StarterPikachuEmotionCommand_turnawayfromplayer
global DeletedFunction_fcffb
global PlaySpecificPikachuEmotion
global TalkToPikachu
global PikachuEmotionTable
global PikachuEmotion33
global MapSpecificPikachuExpression
global IsPlayerPikachuAsleepInParty
global PikachuWalksToNurseJoy

extern DisplayTextID                                    ; src/home/text_script.asm
extern PrintText                                        ; src/home/window.asm
extern PlayPikachuSoundClip                             ; src/audio/pikachu_pcm.asm
extern EmotionBubble                                    ; src/engine/overworld/emotion_bubbles.asm
extern ApplyPikachuMovementData_                        ; src/engine/pikachu/pikachu_movement.asm
extern DelayFrames                                      ; src/home/delay.asm
extern LoadPikachuSpriteIntoVRAM                        ; src/engine/pikachu/pikachu_movement.asm
extern LoadFontTilePatterns                             ; src/home/load_font.asm
extern Pikachu_LoadCurrentMapViewUpdateSpritesAndDelay3 ; src/engine/pikachu/pikachu_movement.asm
extern WaitForTextScrollButtonPress                     ; src/home/joypad2.asm
extern PikachuPewterPokecenterCheck                     ; src/engine/pikachu/pikachu_movement.asm
extern PikachuFanClubCheck                              ; src/engine/pikachu/pikachu_movement.asm
extern PikachuBillsHouseCheck                           ; src/engine/pikachu/pikachu_movement.asm
extern UpdateSprites                                    ; src/home/update_sprites.asm
extern CheckPikachuFollowingPlayer                      ; src/home/pikachu.asm
extern CheckPikachuStatusCondition                      ; src/engine/pikachu/pikachu_status.asm
extern IsThisPartyMonStarterPikachu                     ; src/engine/pikachu/pikachu_status.asm
extern AddNTimes                                        ; src/home/array.asm
extern ApplyPikachuMovementData                         ; src/home/pikachu.asm
extern BillsHouse_CheckPikachuEmotion                   ; src/engine/pikachu/pikachu_stubs.asm
extern GetPikaPicAnimationScriptIndex                   ; src/engine/pikachu/pikachu_pic_animation.asm
extern StarterPikachuEmotionCommand_pikapic              ; src/engine/pikachu/pikachu_pic_animation.asm

; Pikachu emotion scripts & movement scripts from src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion0                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion1                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion2                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion3                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion4                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion5                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion6                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion7                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion8                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion9                                  ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion10                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion11                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion12                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion13                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion14                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion15                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion16                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion17                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion18                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion19                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion20                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion21                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion22                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion23                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion24                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion25                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion26                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion27                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion28                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion29                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion30                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion31                                 ; src/data/pikachu/pikachu_emotions.asm
extern PikachuEmotion32                                 ; src/data/pikachu/pikachu_emotions.asm

; ---------------------------------------------------------------------------
; IsPlayerTalkingToPikachu — pret engine/pikachu/pikachu_emotions.asm:1
; ---------------------------------------------------------------------------
IsPlayerTalkingToPikachu:
    mov al, [ebp + wd435]
    test al, al
    jz .done
    mov al, [ebp + hSpriteIndex]
    cmp al, PIKACHU_SPRITE_INDEX
    jne .done
    call InitializePikachuTextID
    xor al, al
    mov [ebp + hSpriteIndex], al
    mov [ebp + wd435], al
.done:
    ret

; ---------------------------------------------------------------------------
; InitializePikachuTextID — pret engine/pikachu/pikachu_emotions.asm:14
; ---------------------------------------------------------------------------
InitializePikachuTextID:
    mov al, TEXT_PIKACHU_ANIM
    mov [ebp + hTextID], al
    xor al, al
    mov [ebp + wPlayerMovingDirection], al
    mov al, 1
    mov [ebp + wAutoTextBoxDrawingControl], al
    call DisplayTextID
    xor al, al
    mov [ebp + wAutoTextBoxDrawingControl], al
    ret

; ---------------------------------------------------------------------------
; DoStarterPikachuEmotions — pret engine/pikachu/pikachu_emotions.asm:26
; Bytecode interpreter for Pikachu emotion scripts.
; In: AL = emotion index, ESI = PikachuEmotionTable
; ---------------------------------------------------------------------------
DoStarterPikachuEmotions:
    movzx eax, al
    mov edx, [esi + eax * 4]            ; EDX = flat pointer to emotion bytecode script
.loop:
    mov al, [edx]
    inc edx
    cmp al, 0xFF
    je .done
    movzx ecx, al
    mov esi, [StarterPikachuEmotionsJumptable + ecx * 4]
    call esi
    jmp .loop
.done:
    ret

StarterPikachuEmotionsJumptable:
    dd StarterPikachuEmotionCommand_nop      ; 0
    dd StarterPikachuEmotionCommand_text     ; 1
    dd StarterPikachuEmotionCommand_pcm      ; 2
    dd StarterPikachuEmotionCommand_emote    ; 3
    dd StarterPikachuEmotionCommand_movement ; 4
    dd StarterPikachuEmotionCommand_pikapic  ; 5
    dd StarterPikachuEmotionCommand_subcmd   ; 6
    dd StarterPikachuEmotionCommand_delay    ; 7
    dd StarterPikachuEmotionCommand_nop2     ; 8
    dd StarterPikachuEmotionCommand_9        ; 9
    dd StarterPikachuEmotionCommand_nop3     ; a

StarterPikachuEmotionCommand_nop:
StarterPikachuEmotionCommand_nop3:
    ret

StarterPikachuEmotionCommand_text:
    mov esi, [edx]
    add edx, 4
    push edx
    call PrintText
    pop edx
    ret

StarterPikachuEmotionCommand_pcm:
    mov al, [edx]
    inc edx
    push edx
    mov dl, al
    call PlayPikachuSoundClip_
    pop edx
    ret

PlayPikachuSoundClip_:
    cmp al, 0xFF
    je .done
    call PlayPikachuSoundClip
.done:
    ret

StarterPikachuEmotionCommand_emote:
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    mov al, [edx]
    inc edx
    push edx
    call ShowPikachuEmoteBubble
    pop edx
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    ret

ShowPikachuEmoteBubble:
    mov [ebp + wWhichEmotionBubble], al
    mov byte [ebp + wEmotionBubbleSpriteIndex], PIKACHU_SPRITE_INDEX
    call EmotionBubble
    ret

StarterPikachuEmotionCommand_movement:
    mov esi, [edx]
    add edx, 4
    push edx
    mov bh, 0x3F                         ; BANK(DoStarterPikachuEmotions)
    call ApplyPikachuMovementData_
    pop edx
    ret

StarterPikachuEmotionCommand_delay:
    mov al, [edx]
    inc edx
    push edx
    mov bl, al
    call DelayFrames
    pop edx
    ret

StarterPikachuEmotionCommand_subcmd:
    mov al, [edx]
    inc edx
    push edx
    movzx eax, al
    mov esi, [.Subcommands + eax * 4]
    call esi
    pop edx
    ret

.Subcommands:
    dd LoadPikachuSpriteIntoVRAM
    dd LoadFontTilePatterns
    dd Pikachu_LoadCurrentMapViewUpdateSpritesAndDelay3
    dd WaitForTextScrollButtonPress
    dd PikachuPewterPokecenterCheck
    dd PikachuFanClubCheck
    dd PikachuBillsHouseCheck

StarterPikachuEmotionCommand_nop2:
    ret

StarterPikachuEmotionCommand_9:
    push edx
    call StarterPikachuEmotionCommand_turnawayfromplayer
    call UpdateSprites
    pop edx
    ret

StarterPikachuEmotionCommand_turnawayfromplayer:
    mov al, [ebp + wSpriteStateData1 + SPRITESTATEDATA1_FACINGDIRECTION]
    xor al, 4
    mov [ebp + wSpriteStateData1 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE + SPRITESTATEDATA1_FACINGDIRECTION], al
    ret

DeletedFunction_fcffb:
    ret

PlaySpecificPikachuEmotion:
    mov al, dl
    jmp load_expression

; ---------------------------------------------------------------------------
; TalkToPikachu — pret engine/pikachu/pikachu_emotions.asm:248
; ---------------------------------------------------------------------------
TalkToPikachu:
    call MapSpecificPikachuExpression
    jc load_expression
    call GetPikaPicAnimationScriptIndex
    call DeletedFunction_fcffb
load_expression:
    mov [ebp + wExpressionNumber], al
    mov esi, PikachuEmotionTable
    call DoStarterPikachuEmotions
    ret

; ---------------------------------------------------------------------------
; MapSpecificPikachuExpression — pret engine/pikachu/pikachu_emotions.asm:303
; ---------------------------------------------------------------------------
MapSpecificPikachuExpression:
    mov al, [ebp + wCurMap]
    cmp al, POKEMON_FAN_CLUB
    jne .notFanClub
    test byte [ebp + wPikachuMapScriptFlags], (1 << BIT_PIKACHU_MAP_SCRIPT_ACTIVE)
    jnz .fanClubScriptActive
    mov al, 29                          ; PikachuEmotion29
    jmp .play_emotion
.fanClubScriptActive:
    call CheckPikachuFollowingPlayer
    jz .check_pikachu_status
    mov al, 30                          ; PikachuEmotion30
    jmp .play_emotion

.notFanClub:
    mov al, [ebp + wCurMap]
    cmp al, PEWTER_POKECENTER
    jne .notPewterPokecenter
    call CheckPikachuFollowingPlayer
    jz .check_pikachu_status
    mov al, 26                          ; PikachuEmotion26
    jmp .play_emotion

.notPewterPokecenter:
    call BillsHouse_CheckPikachuEmotion
    mov al, dl
    cmp al, 0xFF
    jne .play_emotion
    jmp .check_pikachu_status

.check_pikachu_status:
    call IsPlayerPikachuAsleepInParty
    jnc .notAsleep
    mov al, 11                          ; PikachuEmotion11
    jmp .play_emotion
.notAsleep:
    call CheckPikachuStatusCondition
    jnc .notStatus
    mov al, 28                          ; PikachuEmotion28
    jmp .play_emotion
.notStatus:
    mov al, [ebp + wCurMap]
    cmp al, POKEMON_TOWER_1F
    jb .notInLavenderTower
    cmp al, POKEMON_TOWER_7F + 1
    jae .notInLavenderTower
    mov al, 22                          ; PikachuEmotion22
    jmp .play_emotion

.notInLavenderTower:
    mov al, [ebp + wPikachuEmotionModifier]
    test al, al
    jz .mood_based_emotion
    dec al
    movzx ebx, al
    mov al, [.Emotions + ebx]
    jmp .play_emotion

.mood_based_emotion:
    clc
    ret

.play_emotion:
    stc
    ret

.Emotions:
    db 18                               ; PikachuEmotion18
    db 21                               ; PikachuEmotion21
    db 23                               ; PikachuEmotion23
    db 24                               ; PikachuEmotion24
    db 25                               ; PikachuEmotion25

; ---------------------------------------------------------------------------
; IsPlayerPikachuAsleepInParty — pret engine/pikachu/pikachu_emotions.asm:372
; ---------------------------------------------------------------------------
IsPlayerPikachuAsleepInParty:
    mov byte [ebp + wWhichPokemon], 0
.loop:
    movzx ebx, byte [ebp + wWhichPokemon]
    mov al, [ebp + wPartySpecies + ebx]
    cmp al, 0xFF
    je .done
    cmp al, STARTER_PIKACHU
    jne .curMonNotStarterPikachu
    call IsThisPartyMonStarterPikachu
    jnc .curMonNotStarterPikachu
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1Status
    mov ebx, wPartyMon2 - wPartyMon1
    call AddNTimes
    mov al, [ebp + esi]
    and al, SLP_MASK
    jz .done
    jmp .curMonSleepingPikachu
.curMonNotStarterPikachu:
    mov al, [ebp + wWhichPokemon]
    cmp al, PARTY_LENGTH - 1
    je .done
    inc al
    mov [ebp + wWhichPokemon], al
    jmp .loop
.curMonSleepingPikachu:
    stc
    ret
.done:
    clc
    ret

; ---------------------------------------------------------------------------
; PikachuWalksToNurseJoy — pret engine/pikachu/pikachu_emotions.asm:415
; ---------------------------------------------------------------------------
PikachuWalksToNurseJoy:
    mov byte [ebp + hPikachuSpriteVRAMOffset], 0x40
    call LoadPikachuSpriteIntoVRAM
    call .GetMovementData
    test al, al
    jz .skip
    call ApplyPikachuMovementData
.skip:
    mov byte [ebp + hPikachuSpriteVRAMOffset], 0
    ret

.GetMovementData:
    mov dl, [ebp + wSpriteStateData2 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE + SPRITESTATEDATA2_MAPY]
    mov dh, [ebp + wSpriteStateData2 + PIKACHU_SPRITE_INDEX * SPRITESTATEDATA_STRUCT_SIZE + SPRITESTATEDATA2_MAPX]
    mov al, [ebp + wYCoord]
    add al, 4
    cmp al, dl
    je .pikachu_at_same_y_as_player
    jae .pikachu_above_player
    mov esi, .PikaMovementData1
    mov al, 1
    ret

.pikachu_above_player:
    xor al, al
    ret

.pikachu_at_same_y_as_player:
    mov al, [ebp + wXCoord]
    add al, 4
    cmp al, dh
    jb .pikachu_to_right_of_player
    mov esi, .PikaMovementData2
    mov al, 2
    ret

.pikachu_to_right_of_player:
    mov esi, .PikaMovementData3
    mov al, 3
    ret

.PikaMovementData1:
    db 0x00 ; init
    db 0x36 ; look up
    db 0x2B ; walk up left
    db 0x34 ; hop up right
    db 0x3F ; ret

.PikaMovementData2:
    db 0x00 ; init
    db 0x36 ; look up
    db 0x34 ; hop up right
    db 0x3F ; ret

.PikaMovementData3:
    db 0x00 ; init
    db 0x36 ; look up
    db 0x33 ; hop up left
    db 0x3F ; ret

; ---------------------------------------------------------------------------
; PikachuEmotionTable — pret engine/pikachu/pikachu_emotions.asm:264
; ---------------------------------------------------------------------------
PikachuEmotionTable:
    dd PikachuEmotion0
    dd PikachuEmotion1
    dd PikachuEmotion2
    dd PikachuEmotion3
    dd PikachuEmotion4
    dd PikachuEmotion5
    dd PikachuEmotion6
    dd PikachuEmotion7
    dd PikachuEmotion8
    dd PikachuEmotion9
    dd PikachuEmotion10
    dd PikachuEmotion11
    dd PikachuEmotion12
    dd PikachuEmotion13
    dd PikachuEmotion14
    dd PikachuEmotion15
    dd PikachuEmotion16
    dd PikachuEmotion17
    dd PikachuEmotion18
    dd PikachuEmotion19
    dd PikachuEmotion20
    dd PikachuEmotion21
    dd PikachuEmotion22
    dd PikachuEmotion23
    dd PikachuEmotion24
    dd PikachuEmotion25
    dd PikachuEmotion26
    dd PikachuEmotion27
    dd PikachuEmotion28
    dd PikachuEmotion29
    dd PikachuEmotion30
    dd PikachuEmotion31
    dd PikachuEmotion32
    dd PikachuEmotion33

; ---------------------------------------------------------------------------
; PikachuEmotion33 — pret engine/pikachu/pikachu_emotions.asm:300
; ---------------------------------------------------------------------------
PikachuEmotion33:
    db 0xFF
