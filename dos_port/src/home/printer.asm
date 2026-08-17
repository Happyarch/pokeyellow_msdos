; ===========================================================================
; printer.asm — pret mirror of home/printer.asm.
;
; pret's home/printer.asm holds three labels:
;   PrinterSerial, SerialFunction            — the home-bank serial entry the GB
;                                              Printer drives. TODO-HW: the port has
;                                              no serial hardware and no transport,
;                                              so these are NOT ported here; the
;                                              printer's other entry points are
;                                              already stubbed under their pret names
;                                              in src/engine/printer/printer_stubs.asm
;                                              and src/home/serial_stubs.asm.
;   DisableWaitingAfterTextDisplay           — ported below.
;
; This file exists so the third one lives in its MIRROR (CLAUDE.md: a pret-labeled
; routine goes in dos_port/src/<pret path>), rather than being folded into a caller
; or into a *_stubs.asm — it is not a stub. Despite the filename it has nothing to do
; with the printer hardware: it only sets the "do not wait for a button press after
; the next text box" flag, which works exactly as on the GB. Twelve map scripts call
; it (it is what makes a sign or NPC line run straight into the next one).
;
; Register map (CLAUDE.md): A->AL; GB memory = [ebp + SYM] (gb_memmap.inc).
; ===========================================================================

bits 32

%include "gb_memmap.inc"

global DisableWaitingAfterTextDisplay

section .text

; ---------------------------------------------------------------------------
; DisableWaitingAfterTextDisplay — pret home/printer.asm:30-33.
;   ld a, $01 / ld [wDoNotWaitForButtonPressAfterDisplayingText], a / ret
; ---------------------------------------------------------------------------
DisableWaitingAfterTextDisplay:
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    ret
