; Route5Gate.asm — translated from pret scripts/Route5Gate.asm by dos_port/tools/sm83xlat.
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


global Route5GateMovePlayerUpScript
global Route5GatePlayerMovingScript
global Route5Gate_Script
global Route5Gate_ScriptPointers
global Route5Gate_TextPointers
global SaffronGateGuardText

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern PrintText   ; NOT YET DEFINED IN THE PORT
extern RemoveGuardDrink   ; NOT YET DEFINED IN THE PORT
extern Route5GateDefaultScript   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGeeImThirstyText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGiveDrinkText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardThanksForTheDrinkText   ; NOT YET DEFINED IN THE PORT
extern StartSimulatingJoypadStates   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _SaffronGateGuardGeeImThirstyText   ; NOT YET DEFINED IN THE PORT
extern _SaffronGateGuardImParchedText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE5GATE_PLAYER_MOVING                equ 1
TEXT_ROUTE5GATE_GUARD_GEE_IM_THIRSTY           equ 2
TEXT_ROUTE5GATE_GUARD_GIVE_DRINK               equ 3

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
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
wRoute5GateCurScript                           equ 0xD661

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route5Gate_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wRoute5GateCurScript]
    mov esi, Route5Gate_ScriptPointers
    jmp CallFunctionInTable

Route5Gate_ScriptPointers:
    dd Route5GateDefaultScript
    dd Route5GatePlayerMovingScript

Route5GateMovePlayerUpScript:
    mov al, PAD_UP
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    jmp StartSimulatingJoypadStates

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] Route5GateDefaultScript (scripts/Route5Gate.asm:20-40) — at scripts/Route5Gate.asm:21: bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; PRET| 	ret nz
; PRET| 	ld hl, .PlayerInCoordsArray
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, PLAYER_DIR_LEFT
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	farcall RemoveGuardDrink
; PRET| 	ldh a, [hItemToRemoveID]
; PRET| 	and a
; PRET| 	jr nz, .have_drink
; PRET| 	ld a, TEXT_ROUTE5GATE_GUARD_GEE_IM_THIRSTY
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call Route5GateMovePlayerUpScript
; PRET| 	ld a, SCRIPT_ROUTE5GATE_PLAYER_MOVING
; PRET| 	ld [wRoute5GateCurScript], a
; PRET| 	ret

.have_drink:
    mov al, TEXT_ROUTE5GATE_GUARD_GIVE_DRINK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    ret

.PlayerInCoordsArray:
    db 3, 3
    db 3, 4
    db -1

Route5GatePlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_57
        ret
.nr_57:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute5GateCurScript], al
    ret

Route5Gate_TextPointers:
    dd SaffronGateGuardText
    dd SaffronGateGuardGeeImThirstyText
    dd SaffronGateGuardGiveDrinkText

SaffronGateGuardText:
    mov al, [ebp + wStatusFlags1]
    test al, (1 << (6))
    jnz .thanks_for_drink
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveGuardDrink
    mov al, [ebp + hItemToRemoveID]
    test al, al
    jnz .have_drink
    mov esi, SaffronGateGuardGeeImThirstyText
    call PrintText
    call Route5GateMovePlayerUpScript
    mov al, SCRIPT_ROUTE5GATE_PLAYER_MOVING
    mov [ebp + wRoute5GateCurScript], al
    jmp TextScriptEnd

.have_drink:
    mov esi, SaffronGateGuardGiveDrinkText
    call PrintText
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    jmp TextScriptEnd

.thanks_for_drink:
    mov esi, SaffronGateGuardThanksForTheDrinkText
    call PrintText
    jmp TextScriptEnd

; ---------------------------------------------------------------------------
; BAIL[text-sound-command-unported] SaffronGateGuardGeeImThirstyText (scripts/Route5Gate.asm:99-110) — at scripts/Route5Gate.asm:104: sound_get_key_item
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	text_far _SaffronGateGuardGeeImThirstyText
; PRET| 	text_end
; PRET| 
; PRET| SaffronGateGuardGiveDrinkText:
; PRET| 	text_far _SaffronGateGuardImParchedText
; PRET| 	sound_get_key_item
; PRET| 	text_far _SaffronGateGuardYouCanGoOnThroughText
; PRET| 	text_end
; PRET| 
; PRET| SaffronGateGuardThanksForTheDrinkText:
; PRET| 	text_far _SaffronGateGuardThanksForTheDrinkText
; PRET| 	text_end
