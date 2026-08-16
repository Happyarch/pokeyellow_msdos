; PokemonMansionB1F.asm — translated from pret scripts/PokemonMansionB1F.asm by dos_port/tools/sm83xlat.
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


global MansionB1FCheckReplaceSwitchDoorBlocks
global PokemonMansionB1FBurglarText
global PokemonMansionB1FScientistText
global PokemonMansionB1F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Mansion2ReplaceBlock   ; NOT YET DEFINED IN THE PORT
extern Mansion4Script_Switches   ; NOT YET DEFINED IN THE PORT
extern Mansion4TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion4TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern Mansion4TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSwitchText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FBurglarAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FBurglarBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FBurglarEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FDiaryText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FScientistAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1FScientistEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonMansionB1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONMANSIONB1F_DEFAULT               equ 0
SCRIPT_POKEMONMANSIONB1F_START_BATTLE          equ 1
SCRIPT_POKEMONMANSIONB1F_END_BATTLE            equ 2
TEXT_POKEMONMANSIONB1F_BURGLAR                 equ 1
TEXT_POKEMONMANSIONB1F_SCIENTIST               equ 2
TEXT_POKEMONMANSIONB1F_RARE_CANDY              equ 3
TEXT_POKEMONMANSIONB1F_FULL_RESTORE            equ 4
TEXT_POKEMONMANSIONB1F_TM_BLIZZARD             equ 5
TEXT_POKEMONMANSIONB1F_TM_SOLARBEAM            equ 6
TEXT_POKEMONMANSIONB1F_DIARY                   equ 7
TEXT_POKEMONMANSIONB1F_SECRET_KEY              equ 8
TEXT_POKEMONMANSIONB1F_SWITCH                  equ 9

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonMansionB1FCurScript                    equ 0xD63D
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonMansionB1F_Script:
    call MansionB1FCheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion4TrainerHeaders
    mov edi, PokemonMansionB1F_ScriptPointers   ; pret: ld de, PokemonMansionB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansionB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansionB1FCurScript], al
    ret

MansionB1FCheckReplaceSwitchDoorBlocks:
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
    mov bx, ((8) << 8) | (13)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((11) << 8) | (6)
    call Mansion2ReplaceBlock
    mov al, 0x5f
    mov bx, ((3) << 8) | (4)
    call Mansion2ReplaceBlock
    mov al, 0x54
    mov bx, ((8) << 8) | (8)
    call Mansion2ReplaceBlock
    ret

.switchTurnedOn:
    mov al, 0x2d
    mov bx, ((8) << 8) | (13)
    call Mansion2ReplaceBlock
    mov al, 0x5f
    mov bx, ((11) << 8) | (6)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((3) << 8) | (4)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((8) << 8) | (8)
    call Mansion2ReplaceBlock
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] Mansion4Script_Switches (scripts/PokemonMansionB1F.asm:47-54) — a generated asset already defines Mansion4Script_Switches
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wSpritePlayerStateData1FacingDirection]
; PRET| 	cp SPRITE_FACING_UP
; PRET| 	ret nz
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	ld a, TEXT_POKEMONMANSIONB1F_SWITCH
; PRET| 	ldh [hTextID], a
; PRET| 	jp DisplayTextID

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansionB1F_ScriptPointers (scripts/PokemonMansionB1F.asm:57-80) — a generated asset already defines Mansion4TrainerHeaders
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_POKEMONMANSIONB1F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_POKEMONMANSIONB1F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_POKEMONMANSIONB1F_END_BATTLE
; PRET| 
; PRET| PokemonMansionB1F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const PokemonMansionB1FBurglarText,   TEXT_POKEMONMANSIONB1F_BURGLAR
; PRET| 	dw_const PokemonMansionB1FScientistText, TEXT_POKEMONMANSIONB1F_SCIENTIST
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONMANSIONB1F_RARE_CANDY
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONMANSIONB1F_FULL_RESTORE
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONMANSIONB1F_TM_BLIZZARD
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONMANSIONB1F_TM_SOLARBEAM
; PRET| 	dw_const PokemonMansionB1FDiaryText,     TEXT_POKEMONMANSIONB1F_DIARY
; PRET| 	dw_const PickUpItemText,                 TEXT_POKEMONMANSIONB1F_SECRET_KEY
; PRET| 	dw_const PokemonMansion2FSwitchText,     TEXT_POKEMONMANSIONB1F_SWITCH ; This switch uses the text script from the 2F.
; PRET| 
; PRET| Mansion4TrainerHeaders:
; PRET| 	def_trainers
; PRET| Mansion4TrainerHeader0:
; PRET| 	trainer EVENT_BEAT_MANSION_4_TRAINER_0, 0, PokemonMansionB1FBurglarBattleText, PokemonMansionB1FBurglarEndBattleText, PokemonMansionB1FBurglarAfterBattleText
; PRET| Mansion4TrainerHeader1:
; PRET| 	trainer EVENT_BEAT_MANSION_4_TRAINER_1, 3, PokemonMansionB1FScientistBattleText, PokemonMansionB1FScientistEndBattleText, PokemonMansionB1FScientistAfterBattleText
; PRET| 	db -1 ; end

PokemonMansionB1FBurglarText:
    mov esi, Mansion4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

PokemonMansionB1FScientistText:
    mov esi, Mansion4TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] PokemonMansionB1FBurglarBattleText (scripts/PokemonMansionB1F.asm:95-120) — a generated asset already defines PokemonMansionB1FBurglarBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _PokemonMansionB1FBurglarBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FBurglarEndBattleText:
; PRET| 	text_far _PokemonMansionB1FBurglarEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FBurglarAfterBattleText:
; PRET| 	text_far _PokemonMansionB1FBurglarAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FScientistBattleText:
; PRET| 	text_far _PokemonMansionB1FScientistBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FScientistEndBattleText:
; PRET| 	text_far _PokemonMansionB1FScientistEndBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FScientistAfterBattleText:
; PRET| 	text_far _PokemonMansionB1FScientistAfterBattleText
; PRET| 	text_end
; PRET| 
; PRET| PokemonMansionB1FDiaryText:
; PRET| 	text_far _PokemonMansionB1FDiaryText
; PRET| 	text_end
