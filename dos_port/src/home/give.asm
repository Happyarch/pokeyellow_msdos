; give.asm — faithful port of home/give.asm (pret/pokeyellow).
;
; Two home helpers that hand the player an item or a Pokémon:
;   GiveItem     — add quantity c of item b to the bag, copy its name to the
;                  string buffer, and return carry on success.
;   GivePokemon  — stage species b / level c and jump into _GivePokemon, which
;                  adds the mon to the party (or a box if the party is full).
;
; Register map (SM83 -> x86): a=AL, b=BH, c=BL, hl=ESI, de=EDX. GB memory is
; accessed EBP-relative as [ebp+SYM] with SYM from gb_memmap.inc.
;
; LINK STATUS: CHECK-only for now. Two externs are unresolved in the current tree:
;   * _GivePokemon      — engine/events/give_pokemon.asm is NOT yet ported
;                         (lands with the pokemon events layer). GivePokemon is a
;                         faithful farjp into it.
;   * CopyToStringBuffer — defined in src/engine/battle/core.asm:1362 but NOT
;                         exported `global`. Root must add `global CopyToStringBuffer`
;                         to core.asm to link GiveItem.
; GetItemName (home/names.asm) and AddItemToInventory (engine/items/inventory.asm)
; are already `global`.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/give.asm

bits 32

%include "gb_memmap.inc"

section .text

global GiveItem
global GivePokemon

extern AddItemToInventory      ; ESI=inv count addr; [wCurItem],[wItemQuantity]; CF=success
extern GetItemName             ; name of item [wNamedObjectIndex] -> name buffer
extern CopyToStringBuffer      ; core.asm — copy '@'-terminated name -> wStringBuffer
extern _GivePokemon            ; engine/events/give_pokemon.asm (NOT YET PORTED)

; ---------------------------------------------------------------------------
; GiveItem — give the player quantity c (BL) of item b (BH), and copy the
; item's name to wStringBuffer. Returns carry set on success, clear on failure
; (bag full). pret home/give.asm:GiveItem.
; ---------------------------------------------------------------------------
GiveItem:
    mov al, bh                       ; ld a, b
    mov [ebp + wNamedObjectIndex], al ; ld [wNamedObjectIndex], a
    mov [ebp + wCurItem], al         ; ld [wCurItem], a
    mov al, bl                       ; ld a, c
    mov [ebp + wItemQuantity], al    ; ld [wItemQuantity], a
    mov esi, wNumBagItems            ; ld hl, wNumBagItems
    call AddItemToInventory          ; CF set on success
    jnc .done                        ; ret nc  (failure: carry clear, return as-is)
    call GetItemName
    call CopyToStringBuffer
    stc                              ; scf — report success
.done:
    ret

; ---------------------------------------------------------------------------
; GivePokemon — give the player monster b (BH) at level c (BL). Stages the
; "current" species/level and PLAYER_PARTY_DATA location, then tail-jumps into
; _GivePokemon (which adds to party, or a box if the party is full).
; pret home/give.asm:GivePokemon.
; ---------------------------------------------------------------------------
GivePokemon:
    mov al, bh                       ; ld a, b
    mov [ebp + wCurPartySpecies], al ; ld [wCurPartySpecies], a
    mov al, bl                       ; ld a, c
    mov [ebp + wCurEnemyLevel], al   ; ld [wCurEnemyLevel], a
    xor al, al                       ; xor a ; PLAYER_PARTY_DATA (0)
    mov [ebp + wMonDataLocation], al ; ld [wMonDataLocation], a
    jmp _GivePokemon                 ; farjp _GivePokemon (flat: plain tail jump)
