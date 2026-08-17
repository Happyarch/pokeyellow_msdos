; ViridianForest.asm — translated from pret scripts/ViridianForest.asm, scripts/ViridianForest_2.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_script_tables.inc"
%include "assets/trainer_headers.inc"

global ViridianForestCooltrainerFText
global ViridianForestLeavingSignText
global ViridianForestPrintLeavingSignText
global ViridianForestPrintTrainerTips1Text
global ViridianForestPrintTrainerTips2Text
global ViridianForestPrintTrainerTips3Text
global ViridianForestPrintTrainerTips4Text
global ViridianForestPrintUseAntidoteSignText
global ViridianForestSign_Common
global ViridianForestTalkToTrainer
global ViridianForestTrainerTips1Text
global ViridianForestTrainerTips2Text
global ViridianForestTrainerTips3Text
global ViridianForestTrainerTips4Text
global ViridianForestUseAntidoteSignText
global ViridianForestYoungster2Text
global ViridianForestYoungster3Text
global ViridianForestYoungster4Text
global ViridianForestYoungster5Text
global ViridianForest_Script

extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern ViridianForestTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern ViridianForestYoungster2BattleText   ; NOT YET DEFINED IN THE PORT
extern ViridianForest_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestLeavingSignText   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips1Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips2Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips3Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestTrainerTips4Text   ; NOT YET DEFINED IN THE PORT
extern _ViridianForestUseAntidoteSignText   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wViridianForestCurScript                       equ 0xD617

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
ViridianForest_Script:
    call EnableAutoTextBoxDrawing
    mov esi, ViridianForestTrainerHeaders
    mov edi, ViridianForest_ScriptPointers   ; pret: ld de, ViridianForest_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wViridianForestCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wViridianForestCurScript], al
    ret

; ViridianForest_ScriptPointers (scripts/ViridianForest.asm:11-51) — not re-emitted: ViridianForest_ScriptPointers is already defined in assets/map_script_tables.inc.

%assign event_byte -1
ViridianForestYoungster2Text:
    mov esi, ViridianForestTrainerHeader0
    jmp ViridianForestTalkToTrainer

%assign event_byte -1
ViridianForestYoungster3Text:
    mov esi, ViridianForestTrainerHeader1
    jmp ViridianForestTalkToTrainer

%assign event_byte -1
ViridianForestYoungster4Text:
    mov esi, ViridianForestTrainerHeader2
    jmp ViridianForestTalkToTrainer

%assign event_byte -1
ViridianForestCooltrainerFText:
    mov esi, ViridianForestTrainerHeader3
    jmp ViridianForestTalkToTrainer

%assign event_byte -1
ViridianForestYoungster5Text:
    mov esi, ViridianForestTrainerHeader4
ViridianForestTalkToTrainer:
    call TalkToTrainer
    jmp TextScriptEnd

; ViridianForestYoungster2BattleText (scripts/ViridianForest.asm:81-142) — not re-emitted: ViridianForestYoungster2BattleText is already defined in assets/trainer_headers.inc.

%assign event_byte -1
ViridianForestTrainerTips1Text:
    mov esi, ViridianForestPrintTrainerTips1Text
    jmp ViridianForestSign_Common

%assign event_byte -1
ViridianForestUseAntidoteSignText:
    mov esi, ViridianForestPrintUseAntidoteSignText
    jmp ViridianForestSign_Common

%assign event_byte -1
ViridianForestTrainerTips2Text:
    mov esi, ViridianForestPrintTrainerTips2Text
    jmp ViridianForestSign_Common

%assign event_byte -1
ViridianForestTrainerTips3Text:
    mov esi, ViridianForestPrintTrainerTips3Text
    jmp ViridianForestSign_Common

%assign event_byte -1
ViridianForestTrainerTips4Text:
    mov esi, ViridianForestPrintTrainerTips4Text
    jmp ViridianForestSign_Common

%assign event_byte -1
ViridianForestLeavingSignText:
    mov esi, ViridianForestPrintTrainerTips1Text
ViridianForestSign_Common:
    mov bh, 60
    call Bankswitch
    jmp TextScriptEnd

%assign event_byte -1
ViridianForestPrintTrainerTips1Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestTrainerTips1Text
    text_end

%assign event_byte -1
ViridianForestPrintUseAntidoteSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestUseAntidoteSignText
    text_end

%assign event_byte -1
ViridianForestPrintTrainerTips2Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestTrainerTips2Text
    text_end

%assign event_byte -1
ViridianForestPrintTrainerTips3Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestTrainerTips3Text
    text_end

%assign event_byte -1
ViridianForestPrintTrainerTips4Text:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestTrainerTips4Text
    text_end

%assign event_byte -1
ViridianForestPrintLeavingSignText:
    mov esi, .text
    call PrintText
    ret

%assign event_byte -1
.text:
    text_far _ViridianForestLeavingSignText
    text_end
