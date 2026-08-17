; SilphCo5F.asm — translated from pret scripts/SilphCo5F.asm by dos_port/tools/sm83xlat.
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

global SilphCo5FGateCallbackScript
global SilphCo5FRockerText
global SilphCo5FRocket1Text
global SilphCo5FRocket2Text
global SilphCo5FScientistText
global SilphCo5FSilphWorkerMText
global SilphCo5F_Script
global SilphCo5F_SetUnlockedSilphCoDoorsScript

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern ReplaceTileBlock
extern SilphCo4F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRockerBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FRocket2BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5FScientistBattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo5F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SilphCo5TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
extern TalkToTrainer
extern TextScriptEnd
extern _SilphCo5FSilphWorkerMThatsYouRightText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo5FSilphWorkerMYoureOurHeroText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo5FCurScript                            equ 0xD645

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SilphCo5F_Script:
    call SilphCo5FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo5TrainerHeaders
    mov edi, SilphCo5F_ScriptPointers   ; pret: ld de, SilphCo5F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo5FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo5FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo4F_SetCardKeyDoorYScript
    call SilphCo5F_SetUnlockedSilphCoDoorsScript
    CheckEvent EVENT_SILPH_CO_5_UNLOCKED_DOOR1
    jnz .unlock_door1
    pushfd
    push eax
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (3)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door1:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_5_UNLOCKED_DOOR2, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
    jnz .unlock_door2
    pushfd
    push eax
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (3)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door2:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_5_UNLOCKED_DOOR3, EVENT_SILPH_CO_5_UNLOCKED_DOOR2
    jz .nr_38
        ret
.nr_38:
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((5) << 8) | (7)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
.GateCoordinates:
    db 2, 3
    db 6, 3
    db 5, 7
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo5F_SetUnlockedSilphCoDoorsScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SILPH_CO_5_UNLOCKED_DOOR1)
    %assign event_byte EVENT_BYTE(EVENT_SILPH_CO_5_UNLOCKED_DOOR1)
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_54
        ret
.nr_54:
    cmp al, 0x1
    jnz .unlock_door1
    SetEventReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door1:
    cmp al, 0x2
    jnz .unlock_door2
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR2, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door2:
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_5_UNLOCKED_DOOR3, EVENT_SILPH_CO_5_UNLOCKED_DOOR1
    ret

; SilphCo5F_ScriptPointers (scripts/SilphCo5F.asm:69-98) — not re-emitted: SilphCo5TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FSilphWorkerMText:
    mov esi, .ThatsYouRightText
    mov edi, .YoureOurHeroText   ; pret: ld de — callee takes it in EDI (abi.json)
    call SilphCo6FBeatGiovanniPrintDEOrPrintHLScript
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.ThatsYouRightText:
    text_far _SilphCo5FSilphWorkerMThatsYouRightText
    text_end
.YoureOurHeroText:
    text_far _SilphCo5FSilphWorkerMYoureOurHeroText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FRocket1Text:
    mov esi, SilphCo5TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRocket1BattleText (scripts/SilphCo5F.asm:122-131) — not re-emitted: SilphCo5FRocket1BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FScientistText:
    mov esi, SilphCo5TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FScientistBattleText (scripts/SilphCo5F.asm:140-149) — not re-emitted: SilphCo5FScientistBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FRockerText:
    mov esi, SilphCo5TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRockerBattleText (scripts/SilphCo5F.asm:158-167) — not re-emitted: SilphCo5FRockerBattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo5FRocket2Text:
    mov esi, SilphCo5TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo5FRocket2BattleText (scripts/SilphCo5F.asm:176-197) — not re-emitted: SilphCo5FRocket2BattleText is already defined in assets/trainer_headers.inc.
