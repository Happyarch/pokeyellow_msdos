; PokemonMansion1F.asm — translated from pret scripts/PokemonMansion1F.asm by dos_port/tools/sm83xlat.
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

global Mansion1CheckReplaceSwitchDoorBlocks
global Mansion1LoadEmptyFloorTileBlock
global Mansion1LoadHorizontalGateBlock
global Mansion1ReplaceBlock
global PokemonMansion1FScientistText
global PokemonMansion1F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Mansion1Script_Switches   ; NOT YET DEFINED IN THE PORT
extern Mansion1TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion1TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1FSwitchText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion1FSwitchNotPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion1FSwitchPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion1FSwitchText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONMANSION1F_DEFAULT                equ 0
SCRIPT_POKEMONMANSION1F_START_BATTLE           equ 1
SCRIPT_POKEMONMANSION1F_END_BATTLE             equ 2
TEXT_POKEMONMANSION1F_SCIENTIST                equ 1
TEXT_POKEMONMANSION1F_ESCAPE_ROPE              equ 2
TEXT_POKEMONMANSION1F_CARBOS                   equ 3
TEXT_POKEMONMANSION1F_SWITCH                   equ 4

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonMansion1FCurScript                     equ 0xD639
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonMansion1F_Script:
    call Mansion1CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion1TrainerHeaders
    mov edi, PokemonMansion1F_ScriptPointers   ; pret: ld de, PokemonMansion1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion1FCurScript], al
    ret

Mansion1CheckReplaceSwitchDoorBlocks:
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
    mov bx, ((6) << 8) | (12)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((3) << 8) | (8)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((8) << 8) | (10)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((13) << 8) | (13)
    jmp Mansion1LoadHorizontalGateBlock

.switchTurnedOn:
    mov bx, ((6) << 8) | (12)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((3) << 8) | (8)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((8) << 8) | (10)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((13) << 8) | (13)
    jmp Mansion1LoadEmptyFloorTileBlock

Mansion1LoadHorizontalGateBlock:
    mov al, 0x2d
    mov [ebp + W_NEW_TILE_BLOCK_ID], al
    jmp Mansion1ReplaceBlock

Mansion1LoadEmptyFloorTileBlock:
    mov al, 0xe
    mov [ebp + W_NEW_TILE_BLOCK_ID], al
Mansion1ReplaceBlock:
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Mansion1Script_Switches (scripts/PokemonMansion1F.asm:49-56) — a generated asset already defines Mansion1Script_Switches
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	cp SPRITE_FACING_UP
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, TEXT_POKEMONMANSION1F_SWITCH
; PRET| 	ldh [hTextID], a
; PRET| 	jp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansion1F_ScriptPointers (scripts/PokemonMansion1F.asm:59-75) — a generated asset already defines Mansion1TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_POKEMONMANSION1F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_POKEMONMANSION1F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_POKEMONMANSION1F_END_BATTLE
; PRET| 
; PRET| PokemonMansion1F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonMansion1FScientistText, TEXT_POKEMONMANSION1F_SCIENTIST
; PRET| 	dw_const PickUpItemText,                TEXT_POKEMONMANSION1F_ESCAPE_ROPE
; PRET| 	dw_const PickUpItemText,                TEXT_POKEMONMANSION1F_CARBOS
; PRET| 	dw_const PokemonMansion1FSwitchText,    TEXT_POKEMONMANSION1F_SWITCH
; PRET| 
; PRET| Mansion1TrainerHeaders:
; PRET| 	def_trainers
; PRET| Mansion1TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_MANSION_1_TRAINER_0, 3, PokemonMansion1FScientistBattleText, PokemonMansion1FScientistEndBattleText, PokemonMansion1FScientistAfterBattleText
; PRET| 	db -1 ; end

PokemonMansion1FScientistText:
    mov esi, Mansion1TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansion1FScientistBattleText (scripts/PokemonMansion1F.asm:84-93) — a generated asset already defines PokemonMansion1FScientistBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonMansion1FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion1FScientistEndBattleText:
; PRET| 	text_far _PokemonMansion1FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansion1FScientistAfterBattleText:
; PRET| 	text_far _PokemonMansion1FScientistAfterBattleText
; PRET| 	text_end

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonMansion1FSwitchText (scripts/PokemonMansion1F.asm:97-114) — at scripts/PokemonMansion1F.asm:113: ResetEventReuseHL EVENT_MANSION_SWITCH_ON
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, .Text
; PRET| 	call PrintText
; PRET| 	call YesNoChoice
; PRET| 	ld a, [wCurrentMenuItem]
; PRET| 	and a
; PRET| 	jr nz, .not_pressed
; PRET| 	ld a, $1
; PRET| 	ld [wDoNotWaitForButtonPressAfterDisplayingText], a
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	set BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ld hl, .PressedText
; PRET| 	call PrintText
; PRET| 	ld a, SFX_GO_INSIDE
; PRET| 	call PlaySound
; PRET| 	CheckAndSetEvent EVENT_MANSION_SWITCH_ON
; PRET| 	jr z, .done
; PRET| 	ResetEventReuseHL EVENT_MANSION_SWITCH_ON
; PRET| 	jr .done

.not_pressed:
    mov esi, .NotPressedText
    call PrintText
.done:
    jmp TextScriptEnd

.Text:
    text_far _PokemonMansion1FSwitchText
    text_end
.PressedText:
    text_far _PokemonMansion1FSwitchPressedText
    text_end
.NotPressedText:
    text_far _PokemonMansion1FSwitchNotPressedText
    text_end
