; starter_dex.asm — Oak's Lab starter-Pokédex fake-ownership helper.
;
; Faithful translation of pret `engine/events/starter_dex.asm`. Temporarily marks
; Bulbasaur/Ivysaur/Charmander/Squirtle "owned" so Oak's Lab shows full Pokédex
; info for them, then restores wPokedexOwned's first byte.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/starter_dex.asm

bits 32

%include "gb_memmap.inc"

section .text

global StarterDex

extern ShowPokedexData          ; src/engine/menus/pokedex.asm (predef; real routine)

; DEX_BULBASAUR / DEX_IVYSAUR / DEX_CHARMANDER / DEX_SQUIRTLE — pret
; constants/pokedex_constants.asm dex numbers (1, 2, 4, 7). Not generated
; anywhere in the port; defined locally since only this file needs them.
DEX_BULBASAUR  equ 1
DEX_IVYSAUR    equ 2
DEX_CHARMANDER equ 4
DEX_SQUIRTLE   equ 7

; ─────────────────────────────────────────────────────────────────────────────
; StarterDex — pret engine/events/starter_dex.asm:StarterDex.
; ─────────────────────────────────────────────────────────────────────────────
StarterDex:
    mov byte [ebp + wPokedexOwned], (1 << (DEX_BULBASAUR - 1)) | (1 << (DEX_IVYSAUR - 1)) | (1 << (DEX_CHARMANDER - 1)) | (1 << (DEX_SQUIRTLE - 1))
    ; pret: `predef ShowPokedexData`. Established port pattern
    ; (src/engine/events/display_pokedex.asm, src/engine/items/item_effects.asm):
    ; call the real routine directly — it takes no predef-passed register
    ; argument, so GetPredefRegisters would only clobber, never help.
    ; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by direct call to ShowPokedexData; evidence=ShowPokedexData is a real routine in this port (engine/menus/pokedex.asm) taking no predef-passed register argument, the same convention engine/events/display_pokedex.asm and engine/items/item_effects.asm already use for this exact predef call; lifetime=permanent flat-code calling boundary}
    call ShowPokedexData
    mov byte [ebp + wPokedexOwned], 0
    ret
