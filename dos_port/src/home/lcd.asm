; lcd.asm — mirror of pret home/lcd.asm.
;
; Holds both of that file's pret labels, in pret order:
;   DisableLCD, EnableLCD
;
; Was src/video/lcd_control.asm until the mirror repair; ClearBgMap and FillBgMap,
; which that file also used to carry, are home/vcopy.asm labels and live in
; src/home/vcopy.asm.
;
; The LCD on/off dance on real hardware races the PPU scanline counter and
; toggles rLCDC bit 7. In this port the renderer is driven by the main loop,
; so we only keep/clear the shadow bit — there is no scanline hazard.
; ; TODO-HW: honour LCD-off timing if a scanline-accurate renderer is added.
;
; Build: nasm -f coff -I include/ -o lcd.o lcd.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

LCDC_ON_BIT equ 7

global DisableLCD
global EnableLCD

section .text

; ---------------------------------------------------------------------------
; DisableLCD — clear LCD-enable bit in the LCDC shadow. All registers preserved.
; ---------------------------------------------------------------------------
DisableLCD:
    and byte [ebp + IO_LCDC], ~(1 << LCDC_ON_BIT) & 0xFF
    ret

; ---------------------------------------------------------------------------
; EnableLCD — set LCD-enable bit in the LCDC shadow. All registers preserved.
; ---------------------------------------------------------------------------
EnableLCD:
    or byte [ebp + IO_LCDC], (1 << LCDC_ON_BIT)
    ret
