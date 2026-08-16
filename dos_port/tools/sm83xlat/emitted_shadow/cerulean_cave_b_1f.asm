; CeruleanCaveB1F.asm — translated from pret scripts/CeruleanCaveB1F.asm by dos_port/tools/sm83xlat.
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


global CeruleanCaveB1FMewtwoText
global CeruleanCaveB1F_Script

extern CeruleanCaveB1FTrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern CeruleanCaveB1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern CeruleanCaveB1F_TextPointers   ; NOT YET DEFINED IN THE PORT
extern CheckFightingMapTrainers   ; NOT YET DEFINED IN THE PORT
extern DisplayEnemyTrainerTextAndStartBattle   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern EndTrainerBattle   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern MewtwoBattleText   ; NOT YET DEFINED IN THE PORT
extern MewtwoTrainerHeader   ; NOT YET DEFINED IN THE PORT
extern PickUpItemText   ; NOT YET DEFINED IN THE PORT
extern PlayCry   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern WaitForSoundToFinish   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_CERULEANCAVEB1F_DEFAULT                 equ 0
SCRIPT_CERULEANCAVEB1F_START_BATTLE            equ 1
SCRIPT_CERULEANCAVEB1F_END_BATTLE              equ 2
TEXT_CERULEANCAVEB1F_MEWTWO                    equ 1
TEXT_CERULEANCAVEB1F_ULTRA_BALL1               equ 2
TEXT_CERULEANCAVEB1F_ULTRA_BALL2               equ 3
TEXT_CERULEANCAVEB1F_MAX_REVIVE                equ 4
TEXT_CERULEANCAVEB1F_MAX_ELIXER                equ 5

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wCeruleanCaveB1FCurScript                      equ 0xD64F

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CeruleanCaveB1F_Script:
    call EnableAutoTextBoxDrawing
    mov esi, CeruleanCaveB1FTrainerHeaders
    mov edi, CeruleanCaveB1F_ScriptPointers   ; pret: ld de, CeruleanCaveB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wCeruleanCaveB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wCeruleanCaveB1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] CeruleanCaveB1F_ScriptPointers (scripts/CeruleanCaveB1F.asm:11-28) — a generated asset already defines CeruleanCaveB1F_ScriptPointers
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	def_script_pointers
; PRET| 	dw_const CheckFightingMapTrainers,              SCRIPT_CERULEANCAVEB1F_DEFAULT
; PRET| 	dw_const DisplayEnemyTrainerTextAndStartBattle, SCRIPT_CERULEANCAVEB1F_START_BATTLE
; PRET| 	dw_const EndTrainerBattle,                      SCRIPT_CERULEANCAVEB1F_END_BATTLE
; PRET| 
; PRET| CeruleanCaveB1F_TextPointers:
; PRET| 	def_text_pointers
; PRET| 	dw_const CeruleanCaveB1FMewtwoText, TEXT_CERULEANCAVEB1F_MEWTWO
; PRET| 	dw_const PickUpItemText,            TEXT_CERULEANCAVEB1F_ULTRA_BALL1
; PRET| 	dw_const PickUpItemText,            TEXT_CERULEANCAVEB1F_ULTRA_BALL2
; PRET| 	dw_const PickUpItemText,            TEXT_CERULEANCAVEB1F_MAX_REVIVE
; PRET| 	dw_const PickUpItemText,            TEXT_CERULEANCAVEB1F_MAX_ELIXER
; PRET| 
; PRET| CeruleanCaveB1FTrainerHeaders:
; PRET| 	def_trainers
; PRET| MewtwoTrainerHeader:
; PRET| 	trainer EVENT_BEAT_MEWTWO, 0, MewtwoBattleText, MewtwoBattleText, MewtwoBattleText
; PRET| 	db -1 ; end

CeruleanCaveB1FMewtwoText:
    mov esi, MewtwoTrainerHeader
    call TalkToTrainer
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[owned-by-generated-assets] MewtwoBattleText (scripts/CeruleanCaveB1F.asm:37-37) — a generated asset already defines MewtwoBattleText
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _MewtwoBattleText

    mov al, 131
    call PlayCry
    call WaitForSoundToFinish
    jmp TextScriptEnd
