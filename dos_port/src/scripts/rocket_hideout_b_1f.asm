; RocketHideoutB1F.asm — translated from pret scripts/RocketHideoutB1F.asm by dos_port/tools/sm83xlat.
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

global RocketHideoutB1FRocket1Text
global RocketHideoutB1FRocket2Text
global RocketHideoutB1FRocket3Text
global RocketHideoutB1FRocket4Text
global RocketHideoutB1FRocket5Text
global RocketHideoutB1F_Script

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern ExecuteCurMapScriptInTable   ; NOT YET DEFINED IN THE PORT
extern PlaySound   ; NOT YET DEFINED IN THE PORT
extern ReplaceTileBlock   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeader0   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeader1   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeader2   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeader3   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeader4   ; NOT YET DEFINED IN THE PORT
extern RocketHideout1TrainerHeaders   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB1FDoorCallbackScript   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB1FRocket1BattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB1FRocket5EndBattleText   ; NOT YET DEFINED IN THE PORT
extern RocketHideoutB1F_ScriptPointers   ; NOT YET DEFINED IN THE PORT
extern TalkToTrainer   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRocketHideoutB1FCurScript                     equ 0xD630

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

RocketHideoutB1F_Script:
    call RocketHideoutB1FDoorCallbackScript
    call EnableAutoTextBoxDrawing
    mov esi, RocketHideout1TrainerHeaders
    mov edi, RocketHideoutB1F_ScriptPointers   ; pret: ld de, RocketHideoutB1F_ScriptPointers — ExecuteCurMapScriptInTable takes it in EDI
    mov al, [ebp + wRocketHideoutB1FCurScript]
    call ExecuteCurMapScriptInTable
    mov [ebp + wRocketHideoutB1FCurScript], al
    ret

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] RocketHideoutB1FDoorCallbackScript (scripts/RocketHideoutB1F.asm:12-21) — at scripts/RocketHideoutB1F.asm:17: .door_open is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld hl, wCurrentMapScriptFlags
; PRET| 	bit BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	res BIT_CUR_MAP_LOADED_1, [hl]
; PRET| 	ret z
; PRET| 	CheckEvent EVENT_ENTERED_ROCKET_HIDEOUT
; PRET| 	jr nz, .door_open
; PRET| 	CheckEventReuseA EVENT_BEAT_ROCKET_HIDEOUT_1_TRAINER_4
; PRET| 	jr nz, .play_sound_door_open
; PRET| 	ld a, $54 ; Door Block
; PRET| 	jr .set_door_block

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] RocketHideoutB1FDoorCallbackScript.play_sound_door_open (scripts/RocketHideoutB1F.asm:23-32) — at scripts/RocketHideoutB1F.asm:32: predef_jump ReplaceTileBlock
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, SFX_GO_INSIDE
; PRET| 	call PlaySound
; PRET| 	; [pret] BUG: should be SetEvent to avoid the SFX playing every time you enter the map
; PRET| 	CheckEventHL EVENT_ENTERED_ROCKET_HIDEOUT
; PRET| .door_open
; PRET| 	ld a, $e ; Floor Block
; PRET| .set_door_block
; PRET| 	ld [wNewTileBlockID], a
; PRET| 	lb bc, 8, 12
; PRET| 	predef_jump ReplaceTileBlock

; RocketHideoutB1F_ScriptPointers (scripts/RocketHideoutB1F.asm:35-62) — not re-emitted: RocketHideout1TrainerHeaders is already defined in assets/trainer_headers.inc.

RocketHideoutB1FRocket1Text:
    mov esi, RocketHideout1TrainerHeader0
    call TalkToTrainer
    jmp TextScriptEnd

RocketHideoutB1FRocket2Text:
    mov esi, RocketHideout1TrainerHeader1
    call TalkToTrainer
    jmp TextScriptEnd

RocketHideoutB1FRocket3Text:
    mov esi, RocketHideout1TrainerHeader2
    call TalkToTrainer
    jmp TextScriptEnd

RocketHideoutB1FRocket4Text:
    mov esi, RocketHideout1TrainerHeader3
    call TalkToTrainer
    jmp TextScriptEnd

RocketHideoutB1FRocket5Text:
    mov esi, RocketHideout1TrainerHeader4
    call TalkToTrainer
    jmp TextScriptEnd

; RocketHideoutB1FRocket5EndBattleText (scripts/RocketHideoutB1F.asm:95-95) — not re-emitted: RocketHideoutB1FRocket5EndBattleText is already defined in assets/trainer_headers.inc.

; ---------------------------------------------------------------------------
; BAIL[target-region-bailed] scripts/RocketHideoutB1F.asm:anon (scripts/RocketHideoutB1F.asm:97-99) — at scripts/RocketHideoutB1F.asm:98: .prompt_end is defined in a region that bailed
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	SetEvent EVENT_BEAT_ROCKET_HIDEOUT_1_TRAINER_4
; PRET| 	ld hl, .prompt_end
; PRET| 	ret

; RocketHideoutB1FRocket5EndBattleText.prompt_end (scripts/RocketHideoutB1F.asm:102-159) — not re-emitted: RocketHideoutB1FRocket1BattleText is already defined in assets/trainer_headers.inc.
