; PokemonTower2F.asm — translated from pret scripts/PokemonTower2F.asm, scripts/PokemonTower2F_2.asm by dos_port/tools/sm83xlat.
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

global PokemonTower2FChannelerText
global PokemonTower2FPikachuMovement
global PokemonTower2FPikachuMovementScript
global PokemonTower2FResetRivalEncounter
global PokemonTower2FRivalDownThenRightMovement
global PokemonTower2FRivalEncounterEventCoords
global PokemonTower2FRivalExitsScript
global PokemonTower2FRivalRightThenDownMovement
global PokemonTower2FRivalText
global PokemonTower2F_Script
global PokemonTower2F_ScriptPointers
global PokemonTower2F_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern MoveSprite   ; NOT YET DEFINED IN THE PORT
extern Music_RivalAlternateStart   ; NOT YET DEFINED IN THE PORT
extern PlayDefaultMusic   ; NOT YET DEFINED IN THE PORT
extern PlayMusic   ; NOT YET DEFINED IN THE PORT
extern PokemonTower2FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern PokemonTower2FDefeatedRivalScript   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern SaveEndBattleTextPointers   ; NOT YET DEFINED IN THE PORT
extern StopAllMusic   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern TryApplyPikachuMovementData   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower2FChannelerText   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower2FRivalDefeatedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower2FRivalHowsYourDexText   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower2FRivalVictoryText   ; NOT YET DEFINED IN THE PORT
extern _PokemonTower2FRivalWhatBringsYouHereText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONTOWER2F_DEFAULT                  equ 0
SCRIPT_POKEMONTOWER2F_DEFEATED_RIVAL           equ 1
SCRIPT_POKEMONTOWER2F_RIVAL_EXITS              equ 2
TEXT_POKEMONTOWER2F_RIVAL                      equ 1

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wCoordIndex                                    equ 0xCD3D
wPokemonTower2FCurScript                       equ 0xD62A

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
PokemonTower2F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, PokemonTower2F_ScriptPointers
    mov al, [ebp + wPokemonTower2FCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
PokemonTower2FResetRivalEncounter:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wPokemonTower2FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
PokemonTower2F_ScriptPointers:
    dd PokemonTower2FDefaultScript
    dd PokemonTower2FDefeatedRivalScript
    dd PokemonTower2FRivalExitsScript

; ---------------------------------------------------------------------------
; BAIL[bank-expression] scripts/PokemonTower2F.asm:anon (scripts/PokemonTower2F.asm:25-57) — at scripts/PokemonTower2F.asm:31: BANK(Music_MeetRival)
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	CheckEvent EVENT_BEAT_POKEMON_TOWER_RIVAL
; PRET| 	ret nz
; PRET| 	ld hl, PokemonTower2FRivalEncounterEventCoords
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	call StopAllMusic
; PRET| 	ld c, BANK(Music_MeetRival)
; PRET| 	ld a, MUSIC_MEET_RIVAL
; PRET| 	call PlayMusic
; PRET| 	ResetEvent EVENT_POKEMON_TOWER_RIVAL_ON_LEFT
; PRET| 	ld a, [wCoordIndex]
; PRET| 	cp $1
; PRET| 	ld a, PLAYER_DIR_UP
; PRET| 	ld b, SPRITE_FACING_DOWN
; PRET| 	jr nz, .player_below_rival
; PRET| ; the rival is on the left side and the player is on the right side
; PRET| 	SetEvent EVENT_POKEMON_TOWER_RIVAL_ON_LEFT
; PRET| 	ld a, PLAYER_DIR_LEFT
; PRET| 	ld b, SPRITE_FACING_RIGHT
; PRET| .player_below_rival
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	ld a, POKEMONTOWER2F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	ld a, b
; PRET| 	ldh [hSpriteFacingDirection], a
; PRET| 	call SetSpriteFacingDirectionAndDelay
; PRET| 	ld a, TEXT_POKEMONTOWER2F_RIVAL
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ldh [hJoyPressed], a
; PRET| 	ret

%assign event_byte -1
PokemonTower2FRivalEncounterEventCoords:
    db 5, 15
    db 6, 14
    db 0x0F

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] PokemonTower2FDefeatedRivalScript (scripts/PokemonTower2F.asm:65-88) — at scripts/PokemonTower2F.asm:74: de cannot hold the 32-bit address of PokemonTower2FRivalDownThenRightMovement; callee <none in range> has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wIsInBattle]
; PRET| 	cp $ff
; PRET| 	jp z, PokemonTower2FResetRivalEncounter
; PRET| 	ld a, PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	SetEvent EVENT_BEAT_POKEMON_TOWER_RIVAL
; PRET| 	ld a, TEXT_POKEMONTOWER2F_RIVAL
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	ld de, PokemonTower2FRivalDownThenRightMovement
; PRET| 	CheckEvent EVENT_POKEMON_TOWER_RIVAL_ON_LEFT
; PRET| 	jr nz, .got_movement
; PRET| 	callfar PokemonTower2FPikachuMovementScript
; PRET| 	ld de, PokemonTower2FRivalRightThenDownMovement
; PRET| .got_movement
; PRET| 	ld a, POKEMONTOWER2F_RIVAL
; PRET| 	ldh [hSpriteIndex], a
; PRET| 	call MoveSprite
; PRET| 	call StopAllMusic
; PRET| 	farcall Music_RivalAlternateStart
; PRET| 	ld a, SCRIPT_POKEMONTOWER2F_RIVAL_EXITS
; PRET| 	ld [wPokemonTower2FCurScript], a
; PRET| 	ld [wCurMapScript], a
; PRET| 	ret

%assign event_byte -1
PokemonTower2FRivalRightThenDownMovement:
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db -1
PokemonTower2FRivalDownThenRightMovement:
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_RIGHT
    db NPC_MOVEMENT_DOWN
    db NPC_MOVEMENT_DOWN
    db -1

%assign event_byte -1
PokemonTower2FRivalExitsScript:
    mov al, [ebp + wStatusFlags5]
    test al, (1 << (BIT_SCRIPTED_NPC_MOVEMENT))
    jz .nr_115
        ret
.nr_115:
    mov al, 57
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    xor al, al
    mov [ebp + wJoyIgnore], al
    call PlayDefaultMusic
    mov al, SCRIPT_POKEMONTOWER2F_DEFAULT
    mov [ebp + wPokemonTower2FCurScript], al
    mov [ebp + wCurMapScript], al
    ret

%assign event_byte -1
PokemonTower2F_TextPointers:
    dd PokemonTower2FRivalText
    dd PokemonTower2FChannelerText

%assign event_byte -1
PokemonTower2FRivalText:
    CheckEvent EVENT_BEAT_POKEMON_TOWER_RIVAL
    jz .do_battle
    mov esi, .HowsYourDexText
    call PrintText
    jmp .text_script_end

%assign event_byte -1
.do_battle:
    mov esi, .WhatBringsYouHereText
    call PrintText
    mov esi, wStatusFlags3
    or byte [ebp + esi], (1 << (BIT_TALKED_TO_TRAINER))
    or byte [ebp + esi], (1 << (BIT_PRINT_END_BATTLE_TEXT))
    mov esi, .DefeatedText
    mov edx, .VictoryText   ; pret: ld de, .VictoryText — SaveEndBattleTextPointers takes it in EDX
    call SaveEndBattleTextPointers
    mov al, OPP_RIVAL2
    mov [ebp + wCurOpponent], al
    mov al, [ebp + wRivalStarter]
    add al, 0x1
    mov [ebp + wTrainerNo], al
    mov al, SCRIPT_POKEMONTOWER2F_DEFEATED_RIVAL
    mov [ebp + wPokemonTower2FCurScript], al
    mov [ebp + wCurMapScript], al
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
.WhatBringsYouHereText:
    text_far _PokemonTower2FRivalWhatBringsYouHereText
    text_end
.DefeatedText:
    text_far _PokemonTower2FRivalDefeatedText
    text_end
.VictoryText:
    text_far _PokemonTower2FRivalVictoryText
    text_end
.HowsYourDexText:
    text_far _PokemonTower2FRivalHowsYourDexText
    text_end
PokemonTower2FChannelerText:
    text_far _PokemonTower2FChannelerText
    text_end

%assign event_byte -1
PokemonTower2FPikachuMovementScript:
    mov esi, PokemonTower2FPikachuMovement
    mov bh, SPRITE_FACING_RIGHT
    call TryApplyPikachuMovementData
    ret

%assign event_byte -1
PokemonTower2FPikachuMovement:
    db 0x00
    db 0x1d
    db 0x1f
    db 0x38
    db 0x3f
