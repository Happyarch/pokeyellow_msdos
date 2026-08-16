; HallOfFame.asm — translated from pret scripts/HallOfFame.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_dims.inc"

global HallOfFameEntryMovement
global HallOfFameNoopScript
global HallOfFameOakCongratulationsScript
global HallOfFameOakText
global HallOfFame_Script
global HallOfFame_ScriptPointers
global HallOfFame_TextPointers
global HallofFameRoomClearScripts

extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern DecodeRLEList   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DelayFrames   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern HallOfFameDefaultScript   ; NOT YET DEFINED IN THE PORT
extern HallOfFamePC   ; NOT YET DEFINED IN THE PORT
extern HallOfFameResetEventsAndSaveScript   ; NOT YET DEFINED IN THE PORT
extern HideObject   ; NOT YET DEFINED IN THE PORT
extern Init   ; NOT YET DEFINED IN THE PORT
extern SaveGameData   ; NOT YET DEFINED IN THE PORT
extern SetSpriteFacingDirectionAndDelay   ; NOT YET DEFINED IN THE PORT
extern SetSpriteMovementBytesToFF   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern WaitForTextScrollButtonPress   ; NOT YET DEFINED IN THE PORT
extern _HallOfFameOakText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_HALLOFFAME_OAK_CONGRATULATIONS          equ 1
SCRIPT_HALLOFFAME_RESET_EVENTS_AND_SAVE        equ 2
TEXT_HALLOFFAME_OAK                            equ 1

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wElite4Flags
wElite4Flags                                   equ W_ELITE4_FLAGS
%endif
%ifndef wPlayerMovingDirection
wPlayerMovingDirection                         equ W_PLAYER_MOVING_DIRECTION
%endif
%ifndef wSimulatedJoypadStatesEnd
wSimulatedJoypadStatesEnd                      equ W_SIMULATED_JOYPAD_STATES_END
%endif
%ifndef wSimulatedJoypadStatesIndex
wSimulatedJoypadStatesIndex                    equ W_SIMULATED_JOYPAD_STATES_INDEX
%endif

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
hSpriteFacingDirection                         equ 0xFF8D
wAgathasRoomCurScript                          equ 0xD64E
wBrunosRoomCurScript                           equ 0xD64D
wHallOfFameCurScript                           equ 0xD64A
wLancesRoomCurScript                           equ 0xD652
wLastBlackoutMap                               equ 0xD718
wLoreleisRoomCurScript                         equ 0xD64C

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

HallOfFame_Script:
    call EnableAutoTextBoxDrawing
    mov esi, HallOfFame_ScriptPointers
    mov al, [ebp + wHallOfFameCurScript]
    jmp CallFunctionInTable

HallofFameRoomClearScripts:
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wHallOfFameCurScript], al
    ret

HallOfFame_ScriptPointers:
    dd HallOfFameDefaultScript
    dd HallOfFameOakCongratulationsScript
    dd HallOfFameResetEventsAndSaveScript
    dd HallOfFameNoopScript

HallOfFameNoopScript:
    ret

; ---------------------------------------------------------------------------
; BAIL[predef-leaves-id-in-a] HallOfFameResetEventsAndSaveScript (scripts/HallOfFame.asm:24-58) — at scripts/HallOfFame.asm:29: predef HallOfFamePC
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	call Delay3
; PRET| 	ld a, [wLetterPrintingDelayFlags]
; PRET| 	push af
; PRET| 	xor a
; PRET| 	ld [wJoyIgnore], a
; PRET| 	predef HallOfFamePC
; PRET| 	pop af
; PRET| 	ld [wLetterPrintingDelayFlags], a
; PRET| 	ld hl, wStatusFlags7
; PRET| 	res BIT_NO_MAP_MUSIC, [hl]
; PRET| 	ASSERT wStatusFlags7 + 1 == wElite4Flags
; PRET| 	inc hl
; PRET| 	set BIT_UNUSED_BEAT_ELITE_4, [hl] ; unused
; PRET| 	xor a ; SCRIPT_*_DEFAULT
; PRET| 	ld hl, wLoreleisRoomCurScript
; PRET| 	ld [hli], a ; wLoreleisRoomCurScript
; PRET| 	ld [hli], a ; wBrunosRoomCurScript
; PRET| 	ld [hl], a ; wAgathasRoomCurScript
; PRET| 	ld [wLancesRoomCurScript], a
; PRET| 	ld [wHallOfFameCurScript], a
; PRET| 	; Elite 4 events
; PRET| 	ResetEventRange INDIGO_PLATEAU_EVENTS_START, INDIGO_PLATEAU_EVENTS_END, 1
; PRET| 	xor a
; PRET| 	ld [wHallOfFameCurScript], a
; PRET| 	ld a, PALLET_TOWN
; PRET| 	ld [wLastBlackoutMap], a
; PRET| 	farcall SaveGameData
; PRET| 	ld b, 5
; PRET| .delayLoop
; PRET| 	ld c, 600 / 5
; PRET| 	call DelayFrames
; PRET| 	dec b
; PRET| 	jr nz, .delayLoop
; PRET| 	call WaitForTextScrollButtonPress
; PRET| 	jp Init

; ---------------------------------------------------------------------------
; BAIL[host-pointer-in-16bit-reg] HallOfFameDefaultScript (scripts/HallOfFame.asm:61-71) — at scripts/HallOfFame.asm:64: de cannot hold the 32-bit address of HallOfFameEntryMovement; callee DecodeRLEList has no abi.json entry
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, PAD_BUTTONS | PAD_CTRL_PAD
; PRET| 	ld [wJoyIgnore], a
; PRET| 	ld hl, wSimulatedJoypadStatesEnd
; PRET| 	ld de, HallOfFameEntryMovement
; PRET| 	call DecodeRLEList
; PRET| 	dec a
; PRET| 	ld [wSimulatedJoypadStatesIndex], a
; PRET| 	call StartSimulatingJoypadStates
; PRET| 	ld a, SCRIPT_HALLOFFAME_OAK_CONGRATULATIONS
; PRET| 	ld [wHallOfFameCurScript], a
; PRET| 	ret

HallOfFameEntryMovement:
    db PAD_UP, 5
    db -1

HallOfFameOakCongratulationsScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_80
        ret
.nr_80:
    mov al, PLAYER_DIR_RIGHT
    mov [ebp + wPlayerMovingDirection], al
    mov al, 1
    mov [ebp + hSpriteIndex], al
    call SetSpriteMovementBytesToFF
    mov al, SPRITE_FACING_LEFT
    mov [ebp + hSpriteFacingDirection], al
    call SetSpriteFacingDirectionAndDelay
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    inc al
    mov [ebp + wPlayerMovingDirection], al
    mov al, TEXT_HALLOFFAME_OAK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov al, PAD_BUTTONS | PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    mov al, 9
    mov [ebp + wToggleableObjectIndex], al
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call HideObject
    mov al, SCRIPT_HALLOFFAME_RESET_EVENTS_AND_SAVE
    mov [ebp + wHallOfFameCurScript], al
    ret

HallOfFame_TextPointers:
    dd HallOfFameOakText
HallOfFameOakText:
    text_far _HallOfFameOakText
    text_end
