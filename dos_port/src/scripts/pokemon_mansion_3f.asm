; PokemonMansion3F.asm — translated from pret scripts/PokemonMansion3F.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_dims.inc"

global Mansion3CheckReplaceSwitchDoorBlocks
global PokemonMansion3FScientistText
global PokemonMansion3FSuperNerdText
global PokemonMansion3F_Script
global PokemonMansion3F_ScriptPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Mansion2ReplaceBlock   ; NOT YET DEFINED IN THE PORT
extern Mansion3Script_Switches   ; NOT YET DEFINED IN THE PORT
extern Mansion3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Mansion3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSwitchText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FDefaultScript   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FDiaryText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FSuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3FSuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion3F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
TEXT_POKEMONMANSION3F_SUPER_NERD               equ 1
TEXT_POKEMONMANSION3F_SCIENTIST                equ 2
TEXT_POKEMONMANSION3F_MAX_POTION               equ 3
TEXT_POKEMONMANSION3F_IRON                     equ 4
TEXT_POKEMONMANSION3F_DIARY                    equ 5
TEXT_POKEMONMANSION3F_SWITCH                   equ 6

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCoordIndex                                    equ 0xCD3D
wDungeonWarpDestinationMap                     equ 0xD71C
wPokemonMansion3FCurScript                     equ 0xD63C
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonMansion3F_Script:
    call Mansion3CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion3TrainerHeaders
    mov edi, PokemonMansion3F_ScriptPointers   ; pret: ld de, PokemonMansion3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion3FCurScript], al
    ret

Mansion3CheckReplaceSwitchDoorBlocks:
    mov esi, W_CURRENT_MAP_SCRIPT_FLAGS
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    CheckEvent EVENT_MANSION_SWITCH_ON
    jnz .switchTurnedOn
    mov al, 0xe
    mov bx, ((2) << 8) | (7)
    call Mansion2ReplaceBlock
    mov al, 0x5f
    mov bx, ((5) << 8) | (7)
    call Mansion2ReplaceBlock
    ret

.switchTurnedOn:
    mov al, 0x5f
    mov bx, ((2) << 8) | (7)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((5) << 8) | (7)
    call Mansion2ReplaceBlock
    ret

PokemonMansion3F_ScriptPointers:
    dd PokemonMansion3FDefaultScript
    dd DisplayEnemyTrainerTextAndStartBattle
    dd EndTrainerBattle

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] PokemonMansion3FDefaultScript (scripts/PokemonMansion3F.asm:41-52) — at scripts/PokemonMansion3F.asm:42: .isPlayerFallingDownHole is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .holeCoords
; PRET| 	call .isPlayerFallingDownHole
; PRET| 	ld a, [wWhichDungeonWarp]
; PRET| 	and a
; PRET| 	jp z, CheckFightingMapTrainers
; PRET| 	cp $3
; PRET| 	ld a, POKEMON_MANSION_1F
; PRET| 	jr nz, .fellDownHoleTo1F
; PRET| 	ld a, POKEMON_MANSION_2F
; PRET| .fellDownHoleTo1F
; PRET| 	ld [wDungeonWarpDestinationMap], a
; PRET| 	ret

.holeCoords:
    db 14, 16
    db 14, 17
    db 14, 19
    db -1

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] PokemonMansion3FDefaultScript.isPlayerFallingDownHole (scripts/PokemonMansion3F.asm:61-74) — at scripts/PokemonMansion3F.asm:64: bit BIT_ON_DUNGEON_WARP, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	xor a
; PRET| 	ld [wWhichDungeonWarp], a
; PRET| 	ld a, [wStatusFlags3]
; PRET| 	bit BIT_ON_DUNGEON_WARP, a
; PRET| 	ret nz
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, [wCoordIndex]
; PRET| 	ld [wWhichDungeonWarp], a
; PRET| 	ld hl, wStatusFlags3
; PRET| 	set BIT_ON_DUNGEON_WARP, [hl]
; PRET| 	ld hl, wStatusFlags6
; PRET| 	set BIT_DUNGEON_WARP, [hl]
; PRET| 	ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Mansion3Script_Switches (scripts/PokemonMansion3F.asm:77-84) — a generated asset already defines Mansion3Script_Switches
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	cp SPRITE_FACING_UP
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, TEXT_POKEMONMANSION3F_SWITCH
; PRET| 	ldh [hTextID], a
; PRET| 	jp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansion3F_TextPointers (scripts/PokemonMansion3F.asm:87-101) — a generated asset already defines Mansion3TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonMansion3FSuperNerdText, TEXT_POKEMONMANSION3F_SUPER_NERD
; PRET| 	dw_const PokemonMansion3FScientistText, TEXT_POKEMONMANSION3F_SCIENTIST
; PRET| 	dw_const PickUpItemText,                TEXT_POKEMONMANSION3F_MAX_POTION
; PRET| 	dw_const PickUpItemText,                TEXT_POKEMONMANSION3F_IRON
; PRET| 	dw_const PokemonMansion3FDiaryText,     TEXT_POKEMONMANSION3F_DIARY
; PRET| 	dw_const PokemonMansion2FSwitchText,    TEXT_POKEMONMANSION3F_SWITCH ; This switch uses the text script from the 2F.
; PRET| 
; PRET| Mansion3TrainerHeaders:
; PRET| 	def_trainers
; PRET| Mansion3TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_MANSION_3_TRAINER_0, 0, PokemonMansion3FSuperNerdBattleText, PokemonMansion3FSuperNerdEndBattleText, PokemonMansion3FSuperNerdAfterBattleText
; PRET| Mansion3TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_MANSION_3_TRAINER_1, 2, PokemonMansion3FScientistBattleText, PokemonMansion3FScientistEndBattleText, PokemonMansion3FScientistAfterBattleText
; PRET| 	db -1 ; end

PokemonMansion3FSuperNerdText:
    mov esi, Mansion3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

PokemonMansion3FScientistText:
    mov esi, Mansion3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansion3FSuperNerdBattleText (scripts/PokemonMansion3F.asm:116-141) — a generated asset already defines PokemonMansion3FSuperNerdBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonMansion3FSuperNerdBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FSuperNerdEndBattleText:
; PRET| 	text_far _PokemonMansion3FSuperNerdEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FSuperNerdAfterBattleText:
; PRET| 	text_far _PokemonMansion3FSuperNerdAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FScientistBattleText:
; PRET| 	text_far _PokemonMansion3FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FScientistEndBattleText:
; PRET| 	text_far _PokemonMansion3FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FScientistAfterBattleText:
; PRET| 	text_far _PokemonMansion3FScientistAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion3FDiaryText:
; PRET| 	text_far _PokemonMansion3FDiaryText
; PRET| 	text_end
