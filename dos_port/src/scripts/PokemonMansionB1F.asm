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
%include "assets/script_constants.inc"

; Trainer headers and battle text are DEFINED once, by the single carrier
; src/data/trainer_headers.asm. Declare what this script uses; do NOT %include
; assets/trainer_headers.inc here — the asset DEFINES all 1302 symbols, so an
; include makes every one of them a duplicate global the moment a second script
; links. (That is what kept 202 link-ready scripts out of the build.)
extern Mansion4TrainerHeader0             ; assets/trainer_headers.inc
extern Mansion4TrainerHeader1             ; assets/trainer_headers.inc
extern Mansion4TrainerHeaders             ; assets/trainer_headers.inc
extern PokemonMansionB1FBurglarBattleText ; assets/trainer_headers.inc

global Mansion4Script_Switches
global MansionB1FCheckReplaceSwitchDoorBlocks
global PokemonMansionB1FBurglarText
global PokemonMansionB1FScientistText
global PokemonMansionB1F_Script

extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Mansion2ReplaceBlock
extern Mansion4TrainerHeader0
extern Mansion4TrainerHeader1
extern Mansion4TrainerHeaders
extern PokemonMansionB1FBurglarBattleText
extern PokemonMansionB1F_ScriptPointers
extern TalkToTrainer
extern TextScriptEnd

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonMansionB1F_Script:
    call MansionB1FCheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion4TrainerHeaders
    mov edi, PokemonMansionB1F_ScriptPointers   ; pret: ld de, PokemonMansionB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansionB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansionB1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
MansionB1FCheckReplaceSwitchDoorBlocks:
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

%assign event_byte -1
%assign event_byte_a -1
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
Mansion4Script_Switches:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jnz .ret
    mov byte [ebp + hJoyHeld], 0
    mov byte [ebp + hTextID], 9 ; TEXT_POKEMONMANSIONB1F_SWITCH
    jmp DisplayTextID
.ret:
    ret

; PokemonMansionB1F_ScriptPointers (scripts/PokemonMansionB1F.asm:57-80) — not re-emitted: PokemonMansionB1F_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansionB1FBurglarText:
    mov esi, Mansion4TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
PokemonMansionB1FScientistText:
    mov esi, Mansion4TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonMansionB1FBurglarBattleText (scripts/PokemonMansionB1F.asm:95-120) — not re-emitted: PokemonMansionB1FBurglarBattleText is already defined in assets/trainer_headers.inc.
