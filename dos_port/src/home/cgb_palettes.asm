; cgb_palettes.asm — native VGA realization of pret home/cgb_palettes.asm.
bits 32
global UpdateCGBPal_BGP, UpdateCGBPal_OBP0, UpdateCGBPal_OBP1
extern g_pal_dirty                   ; home/palettes.asm
section .text
; The port's BGP/OBP mirrors remain the fade source; marking the DAC dirty is
; the direct replacement for the original banked CGB transfer.
UpdateCGBPal_BGP:
UpdateCGBPal_OBP0:
UpdateCGBPal_OBP1:
    mov byte [g_pal_dirty], 1
    ret
