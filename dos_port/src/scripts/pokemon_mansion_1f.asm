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
%include "assets/script_constants.inc"

%include "assets/audio_constants.inc"
%include "assets/trainer_headers.inc"

global Mansion1CheckReplaceSwitchDoorBlocks
global Mansion1LoadEmptyFloorTileBlock
global Mansion1LoadHorizontalGateBlock
global Mansion1ReplaceBlock
global PokemonMansion1FScientistText
global PokemonMansion1FSwitchText
global PokemonMansion1F_Script

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern Mansion1Script_Switches
extern Mansion1TrainerHeader0
extern Mansion1TrainerHeaders
extern PlaySound
extern PokemonMansion1FScientistBattleText
extern PokemonMansion1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern PrintText
extern ReplaceTileBlock
extern TalkToTrainer
extern TextScriptEnd
extern YesNoChoice
extern _PokemonMansion1FSwitchNotPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion1FSwitchPressedText   ; NOT YET DEFINED IN THE PORT
extern _PokemonMansion1FSwitchText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wPokemonMansion1FCurScript                     equ 0xD639

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion1F_Script:
    call Mansion1CheckReplaceSwitchDoorBlocks
    call EnableAutoTextBoxDrawing
    mov esi, Mansion1TrainerHeaders
    mov edi, PokemonMansion1F_ScriptPointers   ; pret: ld de, PokemonMansion1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wPokemonMansion1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wPokemonMansion1FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Mansion1CheckReplaceSwitchDoorBlocks:
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
    mov bx, ((6) << 8) | (12)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((3) << 8) | (8)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((8) << 8) | (10)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((13) << 8) | (13)
    jmp Mansion1LoadHorizontalGateBlock

%assign event_byte -1
%assign event_byte_a -1
.switchTurnedOn:
    mov bx, ((6) << 8) | (12)
    call Mansion1LoadHorizontalGateBlock
    mov bx, ((3) << 8) | (8)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((8) << 8) | (10)
    call Mansion1LoadEmptyFloorTileBlock
    mov bx, ((13) << 8) | (13)
    jmp Mansion1LoadEmptyFloorTileBlock

%assign event_byte -1
%assign event_byte_a -1
Mansion1LoadHorizontalGateBlock:
    mov al, 0x2d
    mov [ebp + wNewTileBlockID], al
    jmp Mansion1ReplaceBlock

%assign event_byte -1
%assign event_byte_a -1
Mansion1LoadEmptyFloorTileBlock:
    mov al, 0xe
    mov [ebp + wNewTileBlockID], al
Mansion1ReplaceBlock:
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    ret

; Mansion1Script_Switches (scripts/PokemonMansion1F.asm:49-56) — not re-emitted: Mansion1Script_Switches is already defined elsewhere in the port.

; PokemonMansion1F_ScriptPointers (scripts/PokemonMansion1F.asm:59-75) — not re-emitted: Mansion1TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion1FScientistText:
    mov esi, Mansion1TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; PokemonMansion1FScientistBattleText (scripts/PokemonMansion1F.asm:84-93) — not re-emitted: PokemonMansion1FScientistBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
PokemonMansion1FSwitchText:
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
    mov esi, .NotPressedText
    call PrintText
.done:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.Text:
    text_far _PokemonMansion1FSwitchText
    text_end
.PressedText:
    text_far _PokemonMansion1FSwitchPressedText
    text_end
.NotPressedText:
    text_far _PokemonMansion1FSwitchNotPressedText
    text_end
