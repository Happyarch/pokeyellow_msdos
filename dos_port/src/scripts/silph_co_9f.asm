; SilphCo9F.asm — translated from pret scripts/SilphCo9F.asm by dos_port/tools/sm83xlat.
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

%include "assets/trainer_headers.inc"

global SilphCo9FGateCallbackScript
global SilphCo9FNurseText
global SilphCo9FRocket1Text
global SilphCo9FRocket2Text
global SilphCo9FScientistText
global SilphCo9F_Script
global SilphCo9F_SetCardKeyDoorYScript
global SilphCo9F_SetUnlockedSilphCoDoorsScript

extern Delay3
extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern GBFadeInFromWhite
extern GBFadeOutToWhite
extern HealParty
extern PrintText
extern ReplaceTileBlock
extern SilphCo9FNurseDontGiveUpText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseThankYouText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FNurseYouLookTiredText   ; NOT YET DEFINED IN THE PORT
extern SilphCo9FRocket1BattleText
extern SilphCo9F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo9TrainerHeader0
extern SilphCo9TrainerHeader1
extern SilphCo9TrainerHeader2
extern SilphCo9TrainerHeaders
extern TalkToTrainer
extern TextScriptEnd

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo9FCurScript                            equ 0xD649

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SilphCo9F_Script:
    call SilphCo9FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo9TrainerHeaders
    mov edi, SilphCo9F_ScriptPointers   ; pret: ld de, SilphCo9F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo9FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo9FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo9FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo9F_SetCardKeyDoorYScript
    call SilphCo9F_SetUnlockedSilphCoDoorsScript
    CheckEvent EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    jnz .unlock_door1
    pushfd
    push eax
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((4) << 8) | (1)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door1:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR2, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    jnz .unlock_door2
    pushfd
    push eax
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (9)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door2:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR3, EVENT_SILPH_CO_9_UNLOCKED_DOOR2
    jnz .unlock_door3
    pushfd
    push eax
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((5) << 8) | (9)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door3:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_9_UNLOCKED_DOOR4, EVENT_SILPH_CO_9_UNLOCKED_DOOR3
    jz .nr_47
        ret
.nr_47:
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((6) << 8) | (5)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
.GateCoordinates:
    db 4, 1
    db 2, 9
    db 5, 9
    db 6, 5
    db -1

%assign event_byte -1
%assign event_byte_a -1
SilphCo9F_SetCardKeyDoorYScript:
    push esi
    mov esi, wCardKeyDoorY
    mov al, [ebp + esi]
    lea esi, [esi+1]
    mov bh, al
    mov al, [ebp + esi]
    mov bl, al
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    pop esi
.loop_card_key_doors:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, 0xff
    jz .exit_loop
    push esi
    mov esi, hUnlockedSilphCoDoors
    inc byte [ebp + esi]
    pop esi
    cmp al, bh
    jz .check_door
    lea esi, [esi+1]
    jmp .loop_card_key_doors

%assign event_byte -1
%assign event_byte_a -1
.check_door:
    mov al, [esi]
    lea esi, [esi+1]
    cmp al, bl
    jnz .loop_card_key_doors
    mov esi, wCardKeyDoorY
    xor al, al
    mov [ebp + esi], al
    lea esi, [esi+1]
    mov [ebp + esi], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo9F_SetUnlockedSilphCoDoorsScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SILPH_CO_9_UNLOCKED_DOOR1)
    %assign event_byte EVENT_BYTE(EVENT_SILPH_CO_9_UNLOCKED_DOOR1)
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_100
        ret
.nr_100:
    cmp al, 0x1
    jnz .unlock_door1
    SetEventReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door1:
    cmp al, 0x2
    jnz .unlock_door2
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR2, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door2:
    cmp al, 0x3
    jnz .unlock_door3
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR3, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door3:
    cmp al, 0x4
    jz .nr_117
        ret
.nr_117:
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_9_UNLOCKED_DOOR4, EVENT_SILPH_CO_9_UNLOCKED_DOOR1
    ret

; SilphCo9F_ScriptPointers (scripts/SilphCo9F.asm:122-142) — not re-emitted: SilphCo9TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo9FNurseText:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    jnz .beat_giovanni
    mov esi, .YouLookTiredText
    call PrintText
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call HealParty
    call GBFadeOutToWhite
    call Delay3
    call GBFadeInFromWhite
    mov esi, .DontGiveUpText
    call PrintText
    jmp .text_script_end

%assign event_byte -1
%assign event_byte_a -1
.beat_giovanni:
    mov esi, .ThankYouText
    call PrintText
.text_script_end:
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.YouLookTiredText:
    text_far SilphCo9FNurseYouLookTiredText
    text_end
.DontGiveUpText:
    text_far SilphCo9FNurseDontGiveUpText
    text_end
.ThankYouText:
    text_far SilphCo9FNurseThankYouText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo9FRocket1Text:
    mov esi, SilphCo9TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SilphCo9FScientistText:
    mov esi, SilphCo9TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SilphCo9FRocket2Text:
    mov esi, SilphCo9TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo9FRocket1BattleText (scripts/SilphCo9F.asm:194-227) — not re-emitted: SilphCo9FRocket1BattleText is already defined in assets/trainer_headers.inc.
