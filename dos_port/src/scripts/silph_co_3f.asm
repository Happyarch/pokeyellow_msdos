; SilphCo3F.asm — translated from pret scripts/SilphCo3F.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global SilphCo3FGateCallbackScript
global SilphCo3FRocketText
global SilphCo3FScientistText
global SilphCo3FSilphWorkerMText
global SilphCo3F_Script
global SilphCo3F_UnlockedDoorEventScript

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern PrintText
extern ReplaceTileBlock
extern SilphCo2F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FRocketBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo3F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo3TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd
extern _SilphCo3FSilphWorkerMWhatShouldIDoText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo3FSilphWorkerMYouSavedUsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo3FCurScript                            equ 0xD643

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SilphCo3F_Script:
    call SilphCo3FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo3TrainerHeaders
    mov edi, SilphCo3F_ScriptPointers   ; pret: ld de, SilphCo3F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo3FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo3FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo3FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo2F_SetCardKeyDoorYScript
    call SilphCo3F_UnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_3_UNLOCKED_DOOR1
    jnz .unlock_door1
    pushfd
    push eax
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((4) << 8) | (4)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door1:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_3_UNLOCKED_DOOR2, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
    jz .nr_29
        ret
.nr_29:
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((4) << 8) | (8)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
.GateCoordinates:
    db 4, 4
    db 4, 8
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo3F_UnlockedDoorEventScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SILPH_CO_3_UNLOCKED_DOOR1)
    %assign event_byte EVENT_BYTE(EVENT_SILPH_CO_3_UNLOCKED_DOOR1)
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_44
        ret
.nr_44:
    cmp al, 0x1
    jnz .unlock_door1
    SetEventReuseHL EVENT_SILPH_CO_3_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door1:
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_3_UNLOCKED_DOOR2, EVENT_SILPH_CO_3_UNLOCKED_DOOR1
    ret

; SilphCo3F_ScriptPointers (scripts/SilphCo3F.asm:54-72) — not re-emitted: SilphCo3TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo3FSilphWorkerMText:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    mov esi, .YouSavedUsText
    jnz .beat_giovanni
    mov esi, .WhatShouldIDoText
.beat_giovanni:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.WhatShouldIDoText:
    text_far _SilphCo3FSilphWorkerMWhatShouldIDoText
    text_end
.YouSavedUsText:
    text_far _SilphCo3FSilphWorkerMYouSavedUsText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo3FRocketText:
    mov esi, SilphCo3TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo3FRocketBattleText (scripts/SilphCo3F.asm:99-108) — not re-emitted: SilphCo3FRocketBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo3FScientistText:
    mov esi, SilphCo3TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo3FScientistBattleText (scripts/SilphCo3F.asm:117-126) — not re-emitted: SilphCo3FScientistBattleText is already defined in assets/trainer_headers.inc.
