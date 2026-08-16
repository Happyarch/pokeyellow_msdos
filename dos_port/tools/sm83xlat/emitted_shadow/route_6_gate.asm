; Route6Gate.asm — translated from pret scripts/Route6Gate.asm by dos_port/tools/sm83xlat.
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


global Route6GateMovePlayerDownScript
global Route6GatePlayerMovingScript
global Route6Gate_Script
global Route6Gate_ScriptPointers
global Route6Gate_TextPointers

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern Route6GateDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGeeImThirstyText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGiveDrinkText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE6GATE_PLAYER_MOVING                equ 1
TEXT_ROUTE6GATE_GUARD_GEE_IM_THIRSTY           equ 2
TEXT_ROUTE6GATE_GUARD_GIVE_DRINK               equ 3

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wOverrideSimulatedJoypadStatesMask
wOverrideSimulatedJoypadStatesMask             equ W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK
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
wRoute6GateCurScript                           equ 0xD635
wSpritePlayerStateData2MovementByte1           equ 0xC206

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route6Gate_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route6Gate_ScriptPointers
    mov al, [ebp + wRoute6GateCurScript]
    call CallFunctionInTable
    ret

Route6Gate_ScriptPointers:
    dd Route6GateDefaultScript
    dd Route6GatePlayerMovingScript

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] Route6GateDefaultScript (scripts/Route6Gate.asm:14-34) — at scripts/Route6Gate.asm:15: bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; PRET| 	ret nz
; PRET| 	ld hl, .PlayerInCoordsArray
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, PLAYER_DIR_RIGHT
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	farcall RemoveGuardDrink
; PRET| 	ldh a, [hItemToRemoveID]
; PRET| 	and a
; PRET| 	jr nz, .have_drink
; PRET| 	ld a, TEXT_ROUTE6GATE_GUARD_GEE_IM_THIRSTY
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call Route6GateMovePlayerDownScript
; PRET| 	ld a, SCRIPT_ROUTE6GATE_PLAYER_MOVING
; PRET| 	ld [wRoute6GateCurScript], a
; PRET| 	ret

.have_drink:
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    mov al, TEXT_ROUTE6GATE_GUARD_GIVE_DRINK
    mov [ebp + hTextID], al
    jmp DisplayTextID

.PlayerInCoordsArray:
    db 2, 3
    db 2, 4
    db -1

Route6GatePlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_50
        ret
.nr_50:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute6GateCurScript], al
    ret

Route6GateMovePlayerDownScript:
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov al, PAD_DOWN
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov [ebp + wOverrideSimulatedJoypadStatesMask], al
    ret

Route6Gate_TextPointers:
    dd SaffronGateGuardText
    dd SaffronGateGuardGeeImThirstyText
    dd SaffronGateGuardGiveDrinkText
