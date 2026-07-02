; ghost.asm — PrintGhostText / IsGhostBattle (pret engine/battle/core.asm:3452/:3480).
;
; Faithful, instruction-for-instruction translation. Pokémon Tower ($8E..$94)
; wild battles are disguised as "Ghost" unless the player has the Silph
; Scope ($48) in the bag; PrintGhostText prints the flavor text on each turn
; of such a battle (frozen/asleep players can't act, so no text that turn).
;
; Register map: A=AL, F.Z=ZF, BC=BX (B=BH), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null scratch/ghost.asm

bits 32

%include "gb_memmap.inc"        ; wIsInBattle, wCurMap, wBattleMonStatus, hWhoseTurn
%include "gb_constants.inc"     ; FRZ, SLP_MASK

section .text

global PrintGhostText
global IsGhostBattle

extern PrintText                ; move_effect_helpers.asm — ESI = flat text stream
extern ScaredText                ; assets/battle_text.inc
extern GetOutText                ; assets/battle_text.inc
extern IsItemInBag               ; home/item_predicates.asm — In: BH=item id.
                                  ; Out: ZF=1 if NOT in bag, ZF=0 if in bag; BH=qty.
                                  ; (Matches pret home/map_objects.asm:IsItemInBag
                                  ; exactly — no polarity adaptation needed.)

; ===========================================================================
; PrintGhostText — pret engine/battle/core.asm:PrintGhostText.
; Prints the "Sacred ash..."/scared flavor text on the player's turn (unless
; frozen/asleep) or the "You're not scaring me!"-style get-out text on the
; ghost's turn, but only during an actual disguised-ghost battle.
; Out: ZF=0 (via IsGhostBattle) if not a ghost battle (no-op, no text printed).
;      Otherwise prints text and returns with ZF=1 (xor a).
; ===========================================================================
PrintGhostText:
    call IsGhostBattle
    jnz .ret                            ; ret nz
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .Ghost                          ; jr nz, .Ghost
    mov al, [ebp + wBattleMonStatus]    ; ld a, [wBattleMonStatus]
    and al, (1 << FRZ) | SLP_MASK       ; = 0x27
    jnz .ret                            ; ret nz
    mov esi, ScaredText                 ; ld hl, ScaredText
    call PrintText
    xor al, al
    ret
.Ghost:
    mov esi, GetOutText                 ; ld hl, GetOutText
    call PrintText
    xor al, al
    ret
.ret:
    ret

; ===========================================================================
; IsGhostBattle — pret engine/battle/core.asm:IsGhostBattle.
; Out: ZF=1 if this IS a disguised-ghost battle; ZF=0 if it is not.
; (wIsInBattle != 1 [not a wild battle], or outside the Pokémon Tower ghost
; floors, or the player holds the Silph Scope → all ZF=0 "not ghost".)
; ===========================================================================
IsGhostBattle:
    mov al, [ebp + wIsInBattle]         ; ld a, [wIsInBattle]
    dec al                              ; dec a
    jnz .ret                            ; ret nz
    mov al, [ebp + wCurMap]             ; ld a, [wCurMap]
    cmp al, 0x8E                        ; cp POKEMON_TOWER_1F
    jb .next                            ; jr c, .next
    cmp al, 0x95                        ; cp POKEMON_TOWER_7F + 1
    jae .next                           ; jr nc, .next
    mov bh, 0x48                        ; ld b, SILPH_SCOPE
    call IsItemInBag
    jz .ret                             ; ret z
.next:
    mov al, 1                           ; ld a, 1
    and al, al                          ; and a
    ret
.ret:
    ret
