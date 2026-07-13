; item_use_stubs.asm — link-time stand-ins for the ItemUse* families that the
; item-USE dispatcher (item_use.asm:ItemUsePtrTable) can reach but that are not
; ported yet. Every stub keeps its exact pret label (CLAUDE.md "Preserve pret
; Labels") and is ret-only.
;
; pret ref for all of them: engine/items/item_effects.asm.
;
; Reachability: ALL of these are live targets — the bag's USE dispatches through
; the table, so picking one of these items today is a no-op that returns to the
; item list with wActionResultOrTookBattleTurn = 1 (the value UseItem_ seeds).
; That is a deliberately quiet failure, not a crash; the retirement stages below
; replace each with the real handler.
;
; TODO(items-plan Stage 9):  ItemUseEscapeRope
;   (the Repel family landed in item_effects.asm — stubs retired)
; TODO(items-plan Stage 11): ItemUseBicycle / ItemUsePokeFlute / ItemUseTownMap /
;                            ItemUseItemfinder / ItemUseOldRod / ItemUseGoodRod /
;                            ItemUseSuperRod / ItemUseCardKey / ItemUseCoinCase /
;                            ItemUseOaksParcel / ItemUseSurfboard / ItemUsePokedex /
;                            ItemUsePPUp / ItemUsePPRestore
; TODO(safari, battle plan): ItemUseBait / ItemUseRock (Safari Zone throws)
;
; Build: nasm -f coff -I include/ -I . -o item_use_stubs.o src/engine/items/item_use_stubs.asm

bits 32

section .text

global ItemUseTownMap
global ItemUseBicycle
global ItemUseSurfboard
global ItemUsePokedex
global ItemUseBait
global ItemUseRock
global ItemUseEscapeRope
global ItemUseCardKey
global ItemUseCoinCase
global ItemUseOaksParcel
global ItemUseItemfinder
global ItemUsePokeFlute
global ItemUseOldRod
global ItemUseGoodRod
global ItemUseSuperRod
global ItemUsePPUp
global ItemUsePPRestore

ItemUseTownMap:
ItemUseBicycle:
ItemUseSurfboard:
ItemUsePokedex:
ItemUseBait:
ItemUseRock:
ItemUseEscapeRope:
ItemUseCardKey:
ItemUseCoinCase:
ItemUseOaksParcel:
ItemUseItemfinder:
ItemUsePokeFlute:
ItemUseOldRod:
ItemUseGoodRod:
ItemUseSuperRod:
ItemUsePPUp:
ItemUsePPRestore:
    ret
