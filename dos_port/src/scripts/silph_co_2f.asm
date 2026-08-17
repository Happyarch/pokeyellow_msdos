; SilphCo2F.asm — translated from pret scripts/SilphCo2F.asm by dos_port/tools/sm83xlat.
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

global SilphCo2FGateCallbackScript
global SilphCo2FRocket1Text
global SilphCo2FRocket2Text
global SilphCo2FScientist1Text
global SilphCo2FScientist2Text
global SilphCo2FSilphWorkerFText
global SilphCo2F_Script
global SilphCo2F_UnlockedDoorEventScript

extern EnableAutoTextBoxDrawing
extern ExecuteCurMapScriptInTable
extern GiveItem
extern PrintText
extern ReplaceTileBlock
extern SilphCo2FScientist1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo2FSilphWorkerFPleaseTakeThisText   ; NOT YET DEFINED IN THE PORT
extern SilphCo2F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo2F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo2TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo2TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo2TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo2TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern SilphCo2TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer
extern TextScriptEnd
extern _SilphCo2FSilphWorkerFReceivedTM36Text   ; NOT YET DEFINED IN THE PORT
extern _SilphCo2FSilphWorkerFTM36ExplanationText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo2FSilphWorkerFTM36NoRoomText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo2FCurScript                            equ 0xD642

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
SilphCo2F_Script:
    call SilphCo2FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo2TrainerHeaders
    mov edi, SilphCo2F_ScriptPointers   ; pret: ld de, SilphCo2F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo2FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo2FCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FGateCallbackScript:
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
    call SilphCo2F_UnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_2_UNLOCKED_DOOR1
    jnz .unlock_door1
    pushfd
    push eax
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((2) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    call ReplaceTileBlock
    pop eax
    popfd
.unlock_door1:
    CheckEventAfterBranchReuseA EVENT_SILPH_CO_2_UNLOCKED_DOOR2, EVENT_SILPH_CO_2_UNLOCKED_DOOR1
    jz .nr_29
        ret
.nr_29:
    mov al, 0x54
    mov [ebp + wNewTileBlockID], al
    mov bx, ((5) << 8) | (2)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and A is left holding whatever the callee left rather than pret's parent ROM bank; evidence=pret Predef saves hLoadedROMBank with push af and restores it with pop af before returning so A holds a BANK NUMBER on return - not the predef id - and the flat DPMI model has no banks for that value to mean anything, plus dataflow shows no direct read of A after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
%assign event_byte_a -1
.GateCoordinates:
    db 2, 2
    db 5, 2
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo2F_SetCardKeyDoorYScript (scripts/SilphCo2F.asm:41-61) — at scripts/SilphCo2F.asm:51: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	push hl
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	ld a, [hli]
; PRET| 	ld b, a
; PRET| 	ld a, [hl]
; PRET| 	ld c, a
; PRET| 	xor a
; PRET| 	ldh [hUnlockedSilphCoDoors], a
; PRET| 	pop hl
; PRET| .loop_check_doors
; PRET| 	ld a, [hli]
; PRET| 	cp $ff
; PRET| 	jr z, .exit_loop
; PRET| 	push hl
; PRET| 	ld hl, hUnlockedSilphCoDoors
; PRET| 	inc [hl]
; PRET| 	pop hl
; PRET| 	cp b
; PRET| 	jr z, .check_y_coord
; PRET| 	inc hl
; PRET| 	jr .loop_check_doors

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo2F_SetCardKeyDoorYScript.check_y_coord (scripts/SilphCo2F.asm:63-70) — at scripts/SilphCo2F.asm:63: HL domain is top at a dereference
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [hli]
; PRET| 	cp c
; PRET| 	jr nz, .loop_check_doors
; PRET| 	ld hl, wCardKeyDoorY
; PRET| 	xor a
; PRET| 	ld [hli], a
; PRET| 	ld [hl], a
; PRET| 	ret

%assign event_byte -1
%assign event_byte_a -1
.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

%assign event_byte -1
%assign event_byte_a -1
SilphCo2F_UnlockedDoorEventScript:
    mov esi, wEventFlags + EVENT_BYTE(EVENT_SILPH_CO_2_UNLOCKED_DOOR1)
    %assign event_byte EVENT_BYTE(EVENT_SILPH_CO_2_UNLOCKED_DOOR1)
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_80
        ret
.nr_80:
    cmp al, 0x1
    jnz .unlock_door1
    SetEventReuseHL EVENT_SILPH_CO_2_UNLOCKED_DOOR1
    ret

%assign event_byte -1
%assign event_byte_a -1
.unlock_door1:
    SetEventAfterBranchReuseHL EVENT_SILPH_CO_2_UNLOCKED_DOOR2, EVENT_SILPH_CO_2_UNLOCKED_DOOR1
    ret

; SilphCo2F_ScriptPointers (scripts/SilphCo2F.asm:90-113) — not re-emitted: SilphCo2TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FSilphWorkerFText:
    CheckEvent EVENT_GOT_TM36
    jnz .already_have_tm
    mov esi, .PleaseTakeThisText
    call PrintText
    mov bx, ((238) << 8) | (1)
    call GiveItem
    mov esi, .TM36NoRoomText
    jae .print_text
    SetEvent EVENT_GOT_TM36
    mov esi, .ReceivedTM36Text
    jmp .print_text

%assign event_byte -1
%assign event_byte_a -1
.already_have_tm:
    mov esi, .TM36ExplanationText
.print_text:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
.PleaseTakeThisText:
    text_far SilphCo2FSilphWorkerFPleaseTakeThisText
    text_end
.ReceivedTM36Text:
    text_far _SilphCo2FSilphWorkerFReceivedTM36Text
    sound_get_item_1
    text_end
.TM36ExplanationText:
    text_far _SilphCo2FSilphWorkerFTM36ExplanationText
    text_end
.TM36NoRoomText:
    text_far _SilphCo2FSilphWorkerFTM36NoRoomText
    text_end

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FScientist1Text:
    mov esi, SilphCo2TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FScientist2Text:
    mov esi, SilphCo2TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FRocket1Text:
    mov esi, SilphCo2TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
%assign event_byte_a -1
SilphCo2FRocket2Text:
    mov esi, SilphCo2TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo2FScientist1BattleText (scripts/SilphCo2F.asm:176-221) — not re-emitted: SilphCo2FScientist1BattleText is already defined in assets/trainer_headers.inc.
