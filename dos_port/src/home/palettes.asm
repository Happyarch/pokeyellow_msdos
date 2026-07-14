; palettes.asm — CGB/SGB palette command boundary for the native VGA renderer.
; Pret refs: home/palettes.asm, home/cgb_palettes.asm.
bits 32
%include "gb_memmap.inc"
global RunPaletteCommand
global g_pal_dirty, bg_slot_pal, obj_slot_pal
global pal_rgb_table, mon_pal_table, battle_slot_pal, battle_tile_pal, command_pal_table, repaint_front_table
extern _RunPaletteCommand
section .data
align 4
%include "assets/colors/palettes.inc"
; Preserve today's look until a palette command chooses otherwise.
bg_slot_pal: times 8 db PAL_DMG_GREEN
obj_slot_pal: times 8 db PAL_DMG_GREEN
g_pal_dirty: db 1
section .text
; RunPaletteCommand — pret ref: home/palettes.asm. In: GB `b` = the SET_PAL_* command,
; which is BH in the port's register map (CLAUDE.md: BC = BX, B = BH, C = BL).
;
; This used to be a normalizing shim: `mov al,bl / test al,al / jnz .have / mov al,bh`,
; i.e. it read BL FIRST and fell back to BH only when BL was zero, to tolerate call
; sites that had translated pret's `ld b` into the wrong half. That was a trap, not a
; kindness — it made the WRONG half authoritative. A site that correctly wrote BH
; (town_map, pokedex_entry) got the wrong palette whenever BL happened to be nonzero,
; and it meant nobody could fix a single call site without breaking it, because the
; "faithful" edit (BL -> BH) is exactly what the shim punished. Ledger M-62.
;
; Resolved 2026-07-14: every call site now passes BH, so this reads BH only, as pret's
; `b`. Two battle sites (faint_switch, faint_sendout) were passing NOTHING at all and
; dispatching on junk — they now set SET_PAL_BATTLE (M-72). pret's `c` is not read by
; _RunPaletteCommand, so BL carries nothing here.
RunPaletteCommand:
    mov al, bh                      ; GB b
    jmp _RunPaletteCommand
