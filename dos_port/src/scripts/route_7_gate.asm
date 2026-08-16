; Route7Gate.asm — translated from pret scripts/Route7Gate.asm by dos_port/tools/sm83xlat.
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


global Route7GateMovePlayerLeftScript
global Route7Gate_Script
global Route7Gate_ScriptPointers
global Route7Gate_TextPointers
global Route7PlayerMovingScript

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern Route7DefaultScript   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGeeImThirstyText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGiveDrinkText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE7GATE_PLAYER_MOVING                equ 1
TEXT_ROUTE7GATE_GUARD_GEE_IM_THIRSTY           equ 2
TEXT_ROUTE7GATE_GUARD_GIVE_DRINK               equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute7GateCurScript                           equ 0xD662
wSpritePlayerStateData2MovementByte1           equ 0xC206

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

Route7Gate_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wRoute7GateCurScript]
    mov esi, Route7Gate_ScriptPointers
    call CallFunctionInTable
    ret

Route7Gate_ScriptPointers:
    dd Route7DefaultScript
    dd Route7PlayerMovingScript

Route7GateMovePlayerLeftScript:
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov al, PAD_LEFT
    mov [ebp + W_SIMULATED_JOYPAD_STATES_END], al
    mov al, 0x1
    mov [ebp + W_SIMULATED_JOYPAD_STATES_INDEX], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov [ebp + W_OVERRIDE_SIMULATED_JOYPAD_STATES_MASK], al
    ret

; ---------------------------------------------------------------------------
; BAIL[bit-clobbers-live-carry] Route7DefaultScript (scripts/Route7Gate.asm:26-46) — at scripts/Route7Gate.asm:27: bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; NO SYMBOL IS DEFINED for this region. pret source follows, verbatim.
; ---------------------------------------------------------------------------
; PRET| 	ld a, [wStatusFlags1]
; PRET| 	bit BIT_GAVE_SAFFRON_GUARDS_DRINK, a
; PRET| 	ret nz
; PRET| 	ld hl, .PlayerInCoordsArray
; PRET| 	call ArePlayerCoordsInArray
; PRET| 	ret nc
; PRET| 	ld a, PLAYER_DIR_UP
; PRET| 	ld [wPlayerMovingDirection], a
; PRET| 	xor a
; PRET| 	ldh [hJoyHeld], a
; PRET| 	farcall RemoveGuardDrink
; PRET| 	ldh a, [hItemToRemoveID]
; PRET| 	and a
; PRET| 	jr nz, .have_drink
; PRET| 	ld a, TEXT_ROUTE7GATE_GUARD_GEE_IM_THIRSTY
; PRET| 	ldh [hTextID], a
; PRET| 	call DisplayTextID
; PRET| 	call Route7GateMovePlayerLeftScript
; PRET| 	ld a, SCRIPT_ROUTE7GATE_PLAYER_MOVING
; PRET| 	ld [wRoute7GateCurScript], a
; PRET| 	ret

.have_drink:
    mov al, TEXT_ROUTE7GATE_GUARD_GIVE_DRINK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    ret

.PlayerInCoordsArray:
    db 3, 3
    db 4, 3
    db -1

Route7PlayerMovingScript:
    mov al, [ebp + W_SIMULATED_JOYPAD_STATES_INDEX]
    test al, al
    jz .nr_63
        ret
.nr_63:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute7GateCurScript], al
    mov [ebp + wCurMapScript], al
    ret

Route7Gate_TextPointers:
    dd SaffronGateGuardText
    dd SaffronGateGuardGeeImThirstyText
    dd SaffronGateGuardGiveDrinkText
