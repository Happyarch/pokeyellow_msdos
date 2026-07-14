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
; Older translated callers used either BL or BH for GB B; normalize both.
RunPaletteCommand:
    mov al, bl
    test al, al
    jnz .have_command
    mov al, bh
.have_command:
    jmp _RunPaletteCommand
