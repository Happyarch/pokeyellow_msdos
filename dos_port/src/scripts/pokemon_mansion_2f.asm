; PokemonMansion2F.asm — translated from pret scripts/PokemonMansion2F.asm by dos_port/tools/sm83xlat.
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

global Mansion2CheckReplaceSwitchDoorBlocks
global Mansion2ReplaceBlock
global PokemonMansion2FSuperNerdText
global PokemonMansion2F_Script

extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern Mansion2Script_Switches   ; NOT YET DEFINED IN THE PORT
extern Mansion2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FDiary1Text   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FDiary2Text   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSuperNerdAfterBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSuperNerdEndBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2FSwitchText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern YesNoChoice   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion2FSwitchNotPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion2FSwitchPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion2FSwitchText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_POKEMONMANSION2F_DEFAULT                equ 0
SCRIPT_POKEMONMANSION2F_START_BATTLE           equ 1
SCRIPT_POKEMONMANSION2F_END_BATTLE             equ 2
TEXT_POKEMONMANSION2F_SUPER_NERD               equ 1
TEXT_POKEMONMANSION2F_CALCIUM                  equ 2
TEXT_POKEMONMANSION2F_DIARY1                   equ 3
TEXT_POKEMONMANSION2F_DIARY2                   equ 4
TEXT_POKEMONMANSION2F_SWITCH                   equ 5

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonMansion2FCurScript                     equ 0xD63B
wSpritePlayerStateData1FacingDirection         equ 0xC109

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

PokemonMansion2F_Script:
    call Mansion2CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion2TrainerHeaders
    mov edi, PokemonMansion2F_ScriptPointers   ; pret: ld de, PokemonMansion2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion2FCurScript], al
    ret

Mansion2CheckReplaceSwitchDoorBlocks:
    mov esi, wCurrentMapScriptFlags
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
    mov bx, ((2) << 8) | (4)
    call Mansion2ReplaceBlock
    mov al, 0x54
    mov bx, ((4) << 8) | (9)
    call Mansion2ReplaceBlock
    mov al, 0x5f
    mov bx, ((11) << 8) | (3)
    call Mansion2ReplaceBlock
    ret

.switchTurnedOn:
    mov al, 0x5f
    mov bx, ((2) << 8) | (4)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((4) << 8) | (9)
    call Mansion2ReplaceBlock
    mov al, 0xe
    mov bx, ((11) << 8) | (3)
    call Mansion2ReplaceBlock
    ret

Mansion2ReplaceBlock:
    mov [ebp + wNewTileBlockID], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

; ---------------------------------------------------------------------------
; Mansion2Script_Switches (scripts/PokemonMansion2F.asm:45-52) — Tier-1 data: Mansion2Script_Switches is generated into assets/hidden_events.inc.

; ---------------------------------------------------------------------------
; PokemonMansion2F_ScriptPointers (scripts/PokemonMansion2F.asm:55-72) — Tier-1 data: Mansion2TrainerHeaders is generated into assets/trainer_headers.inc.

PokemonMansion2FSuperNerdText:
    mov esi, Mansion2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; PokemonMansion2FSuperNerdBattleText (scripts/PokemonMansion2F.asm:81-98) — Tier-1 data: PokemonMansion2FSuperNerdBattleText is generated into assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[event-byte-assembly-state] PokemonMansion2FSwitchText (scripts/PokemonMansion2F.asm:102-119) — at scripts/PokemonMansion2F.asm:118: ResetEventReuseHL EVENT_MANSION_SWITCH_ON
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
    mov esi, .NotPressed
    call PrintText
.done:
    jmp TextScriptEnd

.Text:
    text_far _PokemonMansion2FSwitchText
    text_end
.PressedText:
    text_far _PokemonMansion2FSwitchPressedText
    text_end
.NotPressed:
    text_far _PokemonMansion2FSwitchNotPressedText
    text_end
