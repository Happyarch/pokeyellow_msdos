; pokecenter.asm — pret mirror of engine/events/pokecenter.asm (Pokemon Yellow)
;
; Implements DisplayPokemonCenterDialogue_ — the Pokemon Center healing flow:
; Pewter sleeping-Pokemon check, welcome message, YES/NO prompt, blackout-map
; update, Pikachu walk-to-nurse coordination, Nurse Joy bowing, healing-machine
; animation, party heal (HealParty), audio restart, sprite restoration, and farewell text.
;
; Register map (SM83 -> x86): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI, EBP = GB base.
; GB memory is [ebp + addr].
;
; UI PROJECTION (docs/ui_projection.md):
;   overworld-ui (dialog)      GB(0,17) 20x6  center, X+10, Y+0           -> text.asm (PrintText)
;   overworld-ui (HEAL/CANCEL) GB(11,6) 9x6   anchor=top-right, X+20, Y+0 -> yes_no.asm (YesNoChoicePokeCenter)
;   (pokecenter.asm contains 0 direct hlcoord / TextBoxBorder calls; inherits existing shared projections)
;
; Build: nasm -f coff -I include/ -I . -o pokecenter.o src/engine/events/pokecenter.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "assets/audio_constants.inc"
%include "assets/map_dims.inc"

%ifndef BIT_USED_POKECENTER
BIT_USED_POKECENTER equ 2
%endif

section .text

global DisplayPokemonCenterDialogue_
global Func_6eaa
global Func_6ebb
global PokemonCenterWelcomeText
global ShallWeHealYourPokemonText
global NeedYourPokemonText
global PokemonFightingFitText
global PokemonCenterFarewellText
global LooksContentText

; --- External routines ---
extern CheckPikachuFollowingPlayer             ; src/home/pikachu.asm
extern PrintText                               ; src/home/window.asm
extern SaveScreenTilesToBuffer1                ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1              ; src/home/tilemap.asm
extern YesNoChoicePokeCenter                   ; src/home/yes_no.asm
extern UpdateSprites                           ; src/home/update_sprites.asm
extern SetLastBlackoutMap                      ; src/engine/events/set_blackout_map.asm
extern IsStarterPikachuAliveInOurParty         ; src/engine/pikachu/pikachu_status.asm
extern LoadCurrentMapView                      ; src/home/overworld.asm
extern Delay3                                  ; src/home/palettes.asm
extern PikachuWalksToNurseJoy                  ; NOT YET DEFINED IN THE PORT
extern DelayFrames                             ; src/home/delay.asm
extern DisablePikachuOverworldSpriteDrawing    ; src/home/pikachu.asm
extern EnablePikachuOverworldSpriteDrawing     ; src/home/pikachu.asm
extern AnimateHealingMachine                   ; src/engine/overworld/healing_machine.asm
extern HealParty                               ; src/engine/events/heal_party.asm
extern PlaySound                               ; src/home/audio.asm
extern ReloadWalkingTilePatterns               ; src/engine/overworld/map_sprites.asm
extern SpriteFunc_34a1                         ; src/home/map_objects.asm
extern LoadFontTilePatterns                    ; src/home/load_font.asm
extern SetSpriteFacingDirectionAndDelay        ; src/home/map_objects.asm

; ---------------------------------------------------------------------------
; DisplayPokemonCenterDialogue_ — pret engine/events/pokecenter.asm:DisplayPokemonCenterDialogue_
; ---------------------------------------------------------------------------
DisplayPokemonCenterDialogue_:
    mov al, [ebp + wCurMap]                    ; ld a, [wCurMap]
    cmp al, PEWTER_POKECENTER                  ; cp PEWTER_POKECENTER
    jne .regularCenter                         ; jr nz, .regularCenter
    call CheckPikachuFollowingPlayer           ; call CheckPikachuFollowingPlayer
    jz .regularCenter                          ; jr z, .regularCenter
    mov esi, LooksContentText                  ; ld hl, LooksContentText
    call PrintText                             ; call PrintText
    ret

.regularCenter:
    call SaveScreenTilesToBuffer1              ; call SaveScreenTilesToBuffer1
    mov esi, PokemonCenterWelcomeText          ; ld hl, PokemonCenterWelcomeText
    call PrintText                             ; call PrintText
    mov al, [ebp + wStatusFlags4]              ; ld hl, wStatusFlags4 / bit BIT_USED_POKECENTER, [hl]
    or byte [ebp + wStatusFlags4], (1 << BIT_UNKNOWN_4_1) | (1 << BIT_USED_POKECENTER) ; set BIT_UNKNOWN_4_1 / set BIT_USED_POKECENTER
    test al, (1 << BIT_USED_POKECENTER)
    jnz .skipShallWeHealYourPokemon            ; jr nz, .skipShallWeHealYourPokemon
    mov esi, ShallWeHealYourPokemonText        ; ld hl, ShallWeHealYourPokemonText
    call PrintText                             ; call PrintText

.skipShallWeHealYourPokemon:
    call YesNoChoicePokeCenter                 ; call YesNoChoicePokeCenter
    call UpdateSprites                         ; call UpdateSprites
    mov al, [ebp + wCurrentMenuItem]           ; ld a, [wCurrentMenuItem]
    test al, al                                ; and a
    jnz .declinedHealing                       ; jp nz, .declinedHealing
    call SetLastBlackoutMap                    ; call SetLastBlackoutMap
    call IsStarterPikachuAliveInOurParty        ; callfar IsStarterPikachuAliveInOurParty
    jnc .notHealingPlayerPikachu               ; jr nc, .notHealingPlayerPikachu
    call CheckPikachuFollowingPlayer           ; call CheckPikachuFollowingPlayer
    jnz .notHealingPlayerPikachu               ; jr nz, .notHealingPlayerPikachu
    call LoadCurrentMapView                    ; call LoadCurrentMapView
    call Delay3                                ; call Delay3
    call UpdateSprites                         ; call UpdateSprites
    call PikachuWalksToNurseJoy                ; callfar PikachuWalksToNurseJoy

.notHealingPlayerPikachu:
    mov esi, NeedYourPokemonText               ; ld hl, NeedYourPokemonText
    call PrintText                             ; call PrintText
    mov bl, 64                                 ; ld c, 64
    call DelayFrames                           ; call DelayFrames
    call CheckPikachuFollowingPlayer           ; call CheckPikachuFollowingPlayer
    jnz .playerPikachuNotOnScreen              ; jr nz, .playerPikachuNotOnScreen
    call DisablePikachuOverworldSpriteDrawing   ; call DisablePikachuOverworldSpriteDrawing
    call IsStarterPikachuAliveInOurParty        ; callfar IsStarterPikachuAliveInOurParty
    jnc .playerPikachuNotOnScreen              ; call c, Func_6eaa
    call Func_6eaa

.playerPikachuNotOnScreen:
    mov bh, 1                                  ; lb bc, 1, 8
    mov bl, 8
    call Func_6ebb                             ; call Func_6ebb
    mov bl, 30                                 ; ld c, 30
    call DelayFrames                           ; call DelayFrames
    call AnimateHealingMachine                 ; farcall AnimateHealingMachine
    call HealParty                             ; predef HealParty
    xor al, al                                 ; xor a
    mov [ebp + wAudioFadeOutControl], al        ; ld [wAudioFadeOutControl], a
    mov al, [ebp + wAudioSavedROMBank]         ; ld a, [wAudioSavedROMBank]
    mov [ebp + wAudioROMBank], al              ; ld [wAudioROMBank], a
    mov al, [ebp + wMapMusicSoundID]           ; ld a, [wMapMusicSoundID]
    mov [ebp + wLastMusicSoundID], al          ; ld [wLastMusicSoundID], a
    mov [ebp + wNewSoundID], al                ; ld [wNewSoundID], a
    call PlaySound                             ; call PlaySound
    call CheckPikachuFollowingPlayer           ; call CheckPikachuFollowingPlayer
    jnz .doNotReturnPikachu                    ; jr nz, .doNotReturnPikachu
    call IsStarterPikachuAliveInOurParty        ; callfar IsStarterPikachuAliveInOurParty
    jnc .skipFunc_6eaa2                        ; call c, Func_6eaa
    call Func_6eaa
.skipFunc_6eaa2:
    mov byte [ebp + wPikachuSpawnState], 5     ; ld a, $5 / ld [wPikachuSpawnState], a
    call EnablePikachuOverworldSpriteDrawing    ; call EnablePikachuOverworldSpriteDrawing

.doNotReturnPikachu:
    mov bh, 1                                  ; lb bc, 1, 0
    mov bl, 0
    call Func_6ebb                             ; call Func_6ebb
    mov esi, PokemonFightingFitText            ; ld hl, PokemonFightingFitText
    call PrintText                             ; call PrintText
    call IsStarterPikachuAliveInOurParty        ; callfar IsStarterPikachuAliveInOurParty
    jnc .notInParty                            ; jr nc, .notInParty
    mov bh, 15                                 ; lb bc, 15, 0
    mov bl, 0
    call Func_6ebb                             ; call Func_6ebb

.notInParty:
    call LoadCurrentMapView                    ; call LoadCurrentMapView
    call Delay3                                ; call Delay3
    call UpdateSprites                         ; call UpdateSprites
    call ReloadWalkingTilePatterns             ; callfar ReloadWalkingTilePatterns
    mov byte [ebp + hSpriteIndex], 1           ; ld a, $1 / ldh [hSpriteIndex], a
    mov byte [ebp + hSpriteImageIndex], 1      ; ld a, $1 / ldh [hSpriteImageIndex], a
    call SpriteFunc_34a1                       ; call SpriteFunc_34a1
    mov bl, 40                                 ; ld c, 40
    call DelayFrames                           ; call DelayFrames
    call UpdateSprites                         ; call UpdateSprites
    call LoadFontTilePatterns                  ; call LoadFontTilePatterns
    jmp .done                                  ; jr .done

.declinedHealing:
    call LoadScreenTilesFromBuffer1            ; call LoadScreenTilesFromBuffer1

.done:
    mov esi, PokemonCenterFarewellText         ; ld hl, PokemonCenterFarewellText
    call PrintText                             ; call PrintText
    call UpdateSprites                         ; call UpdateSprites
    ret

; ---------------------------------------------------------------------------
; Func_6eaa — pret engine/events/pokecenter.asm:Func_6eaa
; ---------------------------------------------------------------------------
Func_6eaa:
    mov byte [ebp + hSpriteIndex], 1           ; ld a, $1 / ldh [hSpriteIndex], a
    mov byte [ebp + hSpriteImageIndex], 4      ; ld a, $4 / ldh [hSpriteImageIndex], a
    call SpriteFunc_34a1                       ; call SpriteFunc_34a1
    mov bl, 64                                 ; ld c, 64
    jmp DelayFrames                            ; call DelayFrames / ret (tail call)

; ---------------------------------------------------------------------------
; Func_6ebb — pret engine/events/pokecenter.asm:Func_6ebb
; ---------------------------------------------------------------------------
Func_6ebb:
    mov [ebp + hSpriteIndex], bh               ; ld a, b / ldh [hSpriteIndex], a
    mov [ebp + hSpriteImageIndex], bl          ; ld a, c / ldh [hSpriteImageIndex], a
    push ebx                                   ; push bc
    call SetSpriteFacingDirectionAndDelay      ; call SetSpriteFacingDirectionAndDelay
    pop ebx                                    ; pop bc
    mov [ebp + hSpriteIndex], bh               ; ld a, b / ldh [hSpriteIndex], a
    mov [ebp + hSpriteImageIndex], bl          ; ld a, c / ldh [hSpriteImageIndex], a
    call SpriteFunc_34a1                       ; call SpriteFunc_34a1
    ret

; ---------------------------------------------------------------------------
; Text streams — text_far definitions with %include "assets/pokecenter_text.inc"
; ---------------------------------------------------------------------------
PokemonCenterWelcomeText:
    text_far _PokemonCenterWelcomeText
    text_end

ShallWeHealYourPokemonText:
    text_pause
    text_far _ShallWeHealYourPokemonText
    text_end

NeedYourPokemonText:
    text_far _NeedYourPokemonText
    text_end

PokemonFightingFitText:
    text_far _PokemonFightingFitText
    text_end

PokemonCenterFarewellText:
    text_pause
    text_far _PokemonCenterFarewellText
    text_end

LooksContentText:
    text_far _LooksContentText
    text_end

%include "assets/pokecenter_text.inc"
