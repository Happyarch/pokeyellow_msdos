; SilphCo8F.asm — translated from pret scripts/SilphCo8F.asm by dos_port/tools/sm83xlat.
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

global SilphCo8FGateCallbackScript
global SilphCo8FRocket1Text
global SilphCo8FRocket2Text
global SilphCo8FScientistText
global SilphCo8FSilphWorkerMText
global SilphCo8F_Script
global SilphCo8F_UnlockedDoorEventScript

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern SilphCo8FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern SilphCo8F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern SilphCo8F_SetCardKeyDoorYScript   ; NOT YET DEFINED IN THE PORT
extern SilphCo8TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern SilphCo8TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern SilphCo8TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern SilphCo8TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SilphCo8FSilphWorkerMSilphIsFinishedText   ; NOT YET DEFINED IN THE PORT
extern _SilphCo8FSilphWorkerMThanksForSavingUsText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hUnlockedSilphCoDoors                          equ 0xFFE0
wSilphCo8FCurScript                            equ 0xD648

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
SilphCo8F_Script:
    call SilphCo8FGateCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, SilphCo8TrainerHeaders
    mov edi, SilphCo8F_ScriptPointers   ; pret: ld de, SilphCo8F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wSilphCo8FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wSilphCo8FCurScript], al
    ret

%assign event_byte -1
SilphCo8FGateCallbackScript:
    mov esi, wCurrentMapScriptFlags
    test byte [ebp + esi], (1 << (BIT_CUR_MAP_LOADED_1))
    pushfd    ; SM83 form writes no flags
        and byte [ebp + esi], ~(1 << (BIT_CUR_MAP_LOADED_1)) & 0xFF
    popfd
    jnz .nr_15
        ret
.nr_15:
    mov esi, .GateCoordinates
    call SilphCo8F_SetCardKeyDoorYScript
    call SilphCo8F_UnlockedDoorEventScript
    CheckEvent EVENT_SILPH_CO_8_UNLOCKED_DOOR
    jz .nr_20
        ret
.nr_20:
    mov al, 0x5f
    mov [ebp + wNewTileBlockID], al
    mov bx, ((4) << 8) | (3)
; DEVIATION{class=banking; pret=macros/predef.asm:predef_jump; behavior=Predef dispatch replaced by a direct jmp, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    jmp ReplaceTileBlock

%assign event_byte -1
.GateCoordinates:
    db 4, 3
    db -1

; ---------------------------------------------------------------------------
; BAIL[pointer-domain-unknown] SilphCo8F_SetCardKeyDoorYScript (scripts/SilphCo8F.asm:31-51) — at scripts/SilphCo8F.asm:41: HL domain is top at a dereference
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
; BAIL[pointer-domain-unknown] SilphCo8F_SetCardKeyDoorYScript.check_y_coord (scripts/SilphCo8F.asm:53-60) — at scripts/SilphCo8F.asm:53: HL domain is top at a dereference
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
.exit_loop:
    xor al, al
    mov [ebp + hUnlockedSilphCoDoors], al
    ret

%assign event_byte -1
SilphCo8F_UnlockedDoorEventScript:
    mov al, [ebp + hUnlockedSilphCoDoors]
    test al, al
    jnz .nr_69
        ret
.nr_69:
    SetEvent EVENT_SILPH_CO_8_UNLOCKED_DOOR
    ret

; SilphCo8F_ScriptPointers (scripts/SilphCo8F.asm:74-94) — not re-emitted: SilphCo8TrainerHeaders is already defined in assets/trainer_headers.inc.

%assign event_byte -1
SilphCo8FSilphWorkerMText:
    CheckEvent EVENT_BEAT_SILPH_CO_GIOVANNI
    mov esi, .ThanksForSavingUsText
    jnz .beat_giovanni
    mov esi, .SilphIsFinishedText
.beat_giovanni:
    call PrintText
    jmp TextScriptEnd

%assign event_byte -1
.SilphIsFinishedText:
    text_far _SilphCo8FSilphWorkerMSilphIsFinishedText
    text_end
.ThanksForSavingUsText:
    text_far _SilphCo8FSilphWorkerMThanksForSavingUsText
    text_end

%assign event_byte -1
SilphCo8FRocket1Text:
    mov esi, SilphCo8TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
SilphCo8FScientistText:
    mov esi, SilphCo8TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

%assign event_byte -1
SilphCo8FRocket2Text:
    mov esi, SilphCo8TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

; SilphCo8FRocket1BattleText (scripts/SilphCo8F.asm:133-166) — not re-emitted: SilphCo8FRocket1BattleText is already defined in assets/trainer_headers.inc.
