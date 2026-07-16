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
;   (the Repel family + ItemUseEscapeRope landed in item_effects.asm — stubs retired.
;    Escape Rope needed HandleFlyWarpOrDungeonWarp, ported 2026-07-13 — blocker B1 cleared.)
; TODO(items-plan Stage 11): ItemUseSurfboard / ItemUsePPUp /
;                            ItemUsePPRestore
;   (Bicycle / CoinCase / OaksParcel / Pokedex / PokeFlute / CardKey landed in
;    item_effects.asm — stubs retired)
;   (ItemUseItemfinder landed in item_effects.asm 2026-07-16 — overworld-events
;    Stage 3 bullet 2 published HiddenItemCoords and linked itemfinder.asm.)
; BLOCKED (docs/items_blockers.md):
;   ItemUseOldRod / ItemUseGoodRod / ItemUseSuperRod (B7: FishingAnim needs the
;   trainer_engine link closure)
; TODO(safari, battle plan): ItemUseBait / ItemUseRock (Safari Zone throws)
;
; Build: nasm -f coff -I include/ -I . -o item_use_stubs.o src/engine/items/item_use_stubs.asm

bits 32

section .text

global ItemUseSurfboard
global ItemUseOldRod
global ItemUseGoodRod
global ItemUseSuperRod
global ItemUsePPUp
global ItemUsePPRestore

ItemUseSurfboard:
ItemUseOldRod:
ItemUseGoodRod:
ItemUseSuperRod:
ItemUsePPUp:
ItemUsePPRestore:
    ret
