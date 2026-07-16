; give_pokemon_stubs.asm — link-time stand-in for the pokemon-events layer.
;
; _GivePokemon (pret engine/events/give_pokemon.asm) adds a mon to the party, or
; to a box if the party is full. It is NOT ported yet. The only reference to it in
; the port is home/give.asm:GivePokemon, which farjps here. GivePokemon itself has
; NO linked caller today (the starter/gift flows that use it land with the pokemon
; events layer), so this ret-stub is never reached at runtime — it exists purely
; to resolve the extern that promoting give.asm (Stage 3 bullet 3, for GiveItem)
; pulls in. Keep the exact pret label (CLAUDE.md "Preserve pret Labels").
;
; Retire: replace with the real engine/events/give_pokemon.asm port; then delete
; this stub and run label_status --callers _GivePokemon.
;
; Build: nasm -f coff -I include/ -o give_pokemon_stubs.o src/engine/events/give_pokemon_stubs.asm

bits 32

section .text

global _GivePokemon

_GivePokemon:
    ret
