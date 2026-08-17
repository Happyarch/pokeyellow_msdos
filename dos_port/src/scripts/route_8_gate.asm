; Route8Gate.asm — translated from pret scripts/Route8Gate.asm by dos_port/tools/sm83xlat.
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


global Route8GateDefaultScript
global Route8GateMovePlayerRightScript
global Route8GatePlayerMovingScript
global Route8Gate_Script
global Route8Gate_ScriptPointers
global Route8Gate_TextPointers

extern ArePlayerCoordsInArray
extern Bankswitch
extern CallFunctionInTable
extern Delay3
extern DisplayTextID
extern EnableAutoTextBoxDrawing
extern RemoveGuardDrink   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGeeImThirstyText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardGiveDrinkText   ; NOT YET DEFINED IN THE PORT
extern SaffronGateGuardText   ; NOT YET DEFINED IN THE PORT

; Script constants — pret defines these via dw_const in this file.
SCRIPT_ROUTE8GATE_PLAYER_MOVING                equ 1
TEXT_ROUTE8GATE_GUARD_GEE_IM_THIRSTY           equ 2
TEXT_ROUTE8GATE_GUARD_GIVE_DRINK               equ 3

; pret RAM symbols gb_memmap.inc does not carry. Addresses are rgblink's,
; read from pokeyellow.sym — not inferred.
wRoute8GateCurScript                           equ 0xD636
wSpritePlayerStateData2MovementByte1           equ 0xC206

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
Route8Gate_Script:
    call EnableAutoTextBoxDrawing
    mov esi, Route8Gate_ScriptPointers
    mov al, [ebp + wRoute8GateCurScript]
    jmp CallFunctionInTable

%assign event_byte -1
%assign event_byte_a -1
Route8Gate_ScriptPointers:
    dd Route8GateDefaultScript
    dd Route8GatePlayerMovingScript

%assign event_byte -1
%assign event_byte_a -1
Route8GateMovePlayerRightScript:
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov al, PAD_RIGHT
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov [ebp + wOverrideSimulatedJoypadStatesMask], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route8GateDefaultScript:
    mov al, [ebp + wStatusFlags1]
    setc ah                     ; SM83 `bit` preserves C — stash it
    test al, (1 << (6))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    jz .nr_27
        ret
.nr_27:
    mov esi, .PlayerInCoordsArray
    call ArePlayerCoordsInArray
    jb .nr_30
        ret
.nr_30:
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    xor al, al
    mov [ebp + hJoyHeld], al
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveGuardDrink
    mov al, [ebp + hItemToRemoveID]
    test al, al
    jnz .have_drink
    mov al, TEXT_ROUTE8GATE_GUARD_GEE_IM_THIRSTY
    mov [ebp + hTextID], al
    call DisplayTextID
    call Route8GateMovePlayerRightScript
    mov al, SCRIPT_ROUTE8GATE_PLAYER_MOVING
    mov [ebp + wRoute8GateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
.have_drink:
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    mov al, TEXT_ROUTE8GATE_GUARD_GIVE_DRINK
    mov [ebp + hTextID], al
    jmp DisplayTextID

%assign event_byte -1
%assign event_byte_a -1
.PlayerInCoordsArray:
    db 3, 2
    db 4, 2
    db -1

%assign event_byte -1
%assign event_byte_a -1
Route8GatePlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
    test al, al
    jz .nr_61
        ret
.nr_61:
    call Delay3
    xor al, al
    mov [ebp + wJoyIgnore], al
    mov [ebp + wRoute8GateCurScript], al
    ret

%assign event_byte -1
%assign event_byte_a -1
Route8Gate_TextPointers:
    dd SaffronGateGuardText
    dd SaffronGateGuardGeeImThirstyText
    dd SaffronGateGuardGiveDrinkText
