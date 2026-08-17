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
%include "assets/trainer_headers.inc"

global Mansion2CheckReplaceSwitchDoorBlocks
global Mansion2ReplaceBlock
global PokemonMansion2FSuperNerdText
global PokemonMansion2FSwitchText
global PokemonMansion2F_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Mansion2Script_Switches
extern Mansion2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern Mansion2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern PlaySound
extern PokemonMansion2FSuperNerdBattleText   ; NOT YET DEFINED IN THE PORT
extern PokemonMansion2F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern ReplaceTileBlock
extern TalkToTrainer
extern TextScriptEnd
extern YesNoChoice
extern _PokemonMansion2FSwitchNotPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion2FSwitchPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion2FSwitchText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonMansion2FCurScript                     equ 0xD63B

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion2F_Script:
    call Mansion2CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion2TrainerHeaders
    mov edi, PokemonMansion2F_ScriptPointers   ; pret: ld de, PokemonMansion2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion2FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
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

%assign event_byte -1
%assign event_byte_a -1
Mansion2ReplaceBlock:
    mov [ebp + wNewTileBlockID], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

; Mansion2Script_Switches (scripts/PokemonMansion2F.asm:45-52) — not re-emitted: Mansion2Script_Switches is already defined elsewhere in the port.

; PokemonMansion2F_ScriptPointers (scripts/PokemonMansion2F.asm:55-72) — not re-emitted: Mansion2TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion2FSuperNerdText:
    mov esi, Mansion2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonMansion2FSuperNerdBattleText (scripts/PokemonMansion2F.asm:81-98) — not re-emitted: PokemonMansion2FSuperNerdBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion2FSwitchText:
    mov esi, .Text
    call PrintText
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .not_pressed
    mov al, 0x1
    mov [ebp + wDoNotWaitForButtonPressAfterDisplayingText], al
    mov esi, wCurrentMapScriptFlags
    or byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    mov esi, .PressedText
    call PrintText
    mov al, SFX_GO_INSIDE
    call PlaySound
    CheckAndSetEvent EVENT_MANSION_SWITCH_ON
    jz .done
    ResetEventReuseHL EVENT_MANSION_SWITCH_ON
    jmp .done

%assign event_byte -1
%assign event_byte_a -1
.not_pressed:
    mov esi, .NotPressed
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _PokemonMansion2FSwitchText
    text_end
.PressedText:
    text_far _PokemonMansion2FSwitchPressedText
    text_end
.NotPressed:
    text_far _PokemonMansion2FSwitchNotPressedText
    text_end
