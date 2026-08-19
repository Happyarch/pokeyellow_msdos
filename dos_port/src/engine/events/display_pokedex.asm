; ===========================================================================
; display_pokedex.asm — faithful port of pret engine/events/display_pokedex.asm
; (Pokemon Yellow)
;
; Implements _DisplayPokedex — shows a dex entry from outside the pokédex UI
; (reached via home/map_objects.asm:DisplayPokedex, which stashes the dex
; number in wPokedexNum and jumps here), reloads the map behind it, marks the
; species seen, and suppresses the usual "wait for button" gate so the caller's
; own script can decide when to continue.
;
; Register map (SM83 -> x86): A=AL, HL=ESI, BC=BX (B=BH, C=BL); EBP = GB base.
; GB memory is [ebp + addr].
;
; Build: nasm -f coff -I include/ -I . -o display_pokedex.o src/engine/events/display_pokedex.asm
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global _DisplayPokedex

; --- External routines ---
extern ShowPokedexData          ; src/engine/menus/pokedex.asm (predef; real routine — see IndexToPokedex precedent for the predef-wrapper deviation)
extern ReloadMapData            ; src/home/reload_tiles.asm
extern DelayFrames              ; src/home/delay.asm (BL = frame count)
extern IndexToPokedex           ; src/engine/menus/pokedex.asm (predef; real routine)
extern FlagAction                ; src/engine/flag_action.asm — ESI=array, CL=bit, BH=action

; ---------------------------------------------------------------------------
; _DisplayPokedex — pret ref: engine/events/display_pokedex.asm:1-19.
; In: [wPokedexNum] = dex number, set by the caller (DisplayPokedex).
; ---------------------------------------------------------------------------
_DisplayPokedex:
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY) ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY, [hl]
; DEVIATION{class=banking; pret=engine/events/display_pokedex.asm:_DisplayPokedex; behavior=call ShowPokedexData directly instead of the pret predef; evidence=ShowPokedexData is a real routine in this port (engine/menus/pokedex.asm) and GetPredefRegisters would clobber the live registers rather than help, the same convention item_effects.asm:ItemUseBall already uses for this exact predef call; lifetime=permanent flat-code calling boundary}
    call ShowPokedexData                          ; predef ShowPokedexData
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF ; ld hl, wStatusFlags5 / res BIT_NO_TEXT_DELAY, [hl]
    call ReloadMapData                            ; call ReloadMapData
    mov bl, 10                                    ; ld c, 10
    call DelayFrames                              ; call DelayFrames
; DEVIATION{class=banking; pret=engine/events/display_pokedex.asm:_DisplayPokedex; behavior=call IndexToPokedex directly instead of the pret predef; evidence=IndexToPokedex is a real routine in this port (engine/menus/pokedex.asm) and GetPredefRegisters would clobber wPokedexNum-derived state rather than help, the same convention every other IndexToPokedex call site in this tree uses; lifetime=permanent flat-code calling boundary}
    call IndexToPokedex                           ; predef IndexToPokedex
    mov al, [ebp + wPokedexNum]                   ; ld a, [wPokedexNum]
    dec al                                        ; dec a
    mov cl, al                                    ; ld c, a
    mov bh, FLAG_SET                               ; ld b, FLAG_SET
    mov esi, wPokedexSeen                         ; ld hl, wPokedexSeen
; DEVIATION{class=banking; pret=engine/events/display_pokedex.asm:_DisplayPokedex; behavior=call FlagAction directly instead of the predef wrapper; evidence=pret predef FlagActionPredef plus port direct-register calling convention where GetPredefRegisters would clobber ESI/CL/BH, established port pattern engine/menus/pokedex.asm:IsPokemonBitSet and engine/pokemon/evos_moves.asm; lifetime=permanent flat-code calling boundary}
    call FlagAction                               ; predef FlagActionPredef
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1 ; ld a, $1 / ld [wDoNotWaitForButtonPressAfterDisplayingText], a
    ret
