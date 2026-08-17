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


global Route7DefaultScript
global Route7GateMovePlayerLeftScript
global Route7Gate_Script
global Route7Gate_ScriptPointers
global Route7Gate_TextPointers
global Route7PlayerMovingScript

extern ArePlayerCoordsInArray   ; NOT YET DEFINED IN THE PORT
extern Bankswitch   ; NOT YET DEFINED IN THE PORT
extern CallFunctionInTable   ; NOT YET DEFINED IN THE PORT
extern Delay3   ; NOT YET DEFINED IN THE PORT
extern DisplayTextID   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern RemoveGuardDrink   ; NOT YET DEFINED IN THE PORT
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

%assign event_byte -1
Route7Gate_Script:
    call EnableAutoTextBoxDrawing
    mov al, [ebp + wRoute7GateCurScript]
    mov esi, Route7Gate_ScriptPointers
    call CallFunctionInTable
    ret

%assign event_byte -1
Route7Gate_ScriptPointers:
    dd Route7DefaultScript
    dd Route7PlayerMovingScript

%assign event_byte -1
Route7GateMovePlayerLeftScript:
    mov esi, wStatusFlags5
    or byte [ebp + esi], (1 << (BIT_SCRIPTED_MOVEMENT_STATE))
    mov al, PAD_LEFT
    mov [ebp + wSimulatedJoypadStatesEnd], al
    mov al, 0x1
    mov [ebp + wSimulatedJoypadStatesIndex], al
    xor al, al
    mov [ebp + wSpritePlayerStateData2MovementByte1], al
    mov [ebp + wOverrideSimulatedJoypadStatesMask], al
    ret

%assign event_byte -1
Route7DefaultScript:
    mov al, [ebp + wStatusFlags1]
    setc ah                     ; SM83 `bit` preserves C — stash it
    test al, (1 << (6))
    bt   eax, 8                 ; CF = AH bit 0 = saved C; ZF untouched
    jz .nr_28
        ret
.nr_28:
    mov esi, .PlayerInCoordsArray
    call ArePlayerCoordsInArray
    jb .nr_31
        ret
.nr_31:
    mov al, PLAYER_DIR_UP
    mov [ebp + wPlayerMovingDirection], al
    xor al, al
    mov [ebp + hJoyHeld], al
; DEVIATION{class=banking; pret=macros/farcall.asm:farcall; behavior=bank switch dropped, call goes straight to the target; evidence=the DPMI model is flat so every routine is always addressable, and Bankswitch has no port counterpart; lifetime=permanent}
    call RemoveGuardDrink
    mov al, [ebp + hItemToRemoveID]
    test al, al
    jnz .have_drink
    mov al, TEXT_ROUTE7GATE_GUARD_GEE_IM_THIRSTY
    mov [ebp + hTextID], al
    call DisplayTextID
    call Route7GateMovePlayerLeftScript
    mov al, SCRIPT_ROUTE7GATE_PLAYER_MOVING
    mov [ebp + wRoute7GateCurScript], al
    ret

%assign event_byte -1
.have_drink:
    mov al, TEXT_ROUTE7GATE_GUARD_GIVE_DRINK
    mov [ebp + hTextID], al
    call DisplayTextID
    mov esi, wStatusFlags1
    or byte [ebp + esi], (1 << (6))
    ret

%assign event_byte -1
.PlayerInCoordsArray:
    db 3, 3
    db 4, 3
    db -1

%assign event_byte -1
Route7PlayerMovingScript:
    mov al, [ebp + wSimulatedJoypadStatesIndex]
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

%assign event_byte -1
Route7Gate_TextPointers:
    dd SaffronGateGuardText
    dd SaffronGateGuardGeeImThirstyText
    dd SaffronGateGuardGiveDrinkText
