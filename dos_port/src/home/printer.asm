; ===========================================================================
; printer.asm — pret mirror of home/printer.asm.
;
; pret's home/printer.asm holds three labels:
;   PrinterSerial, SerialFunction            — the Serial handler's printer branch
;                                              in pret. They are ret-only here
;                                              because the port printer device
;                                              consumes GB Printer packets
;                                              synchronously through
;                                              PrintDev_ConsumePacket, so the
;                                              serial-interrupt byte pump pret used
;                                              to reach them never runs in this
;                                              model. See docs/plans/printer.md.
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
global PrinterSerial
global SerialFunction

section .text

; ---------------------------------------------------------------------------
; PrinterSerial — pret home/printer.asm:1-26. The per-byte printer serial
; branch of the Serial handler. The port printer device does not use the
; interrupt byte pump, so the body stays the pret-shape no-op below.
; ---------------------------------------------------------------------------
PrinterSerial:
    ret

; ---------------------------------------------------------------------------
; SerialFunction — pret home/printer.asm:27-29. Same pret-shape no-op: the
; printer engine's serial-function sentinel is only meaningful alongside the
; byte-interrupt pump that the port printer flow does not run.
; ---------------------------------------------------------------------------
SerialFunction:
    ret

; ---------------------------------------------------------------------------
; DisableWaitingAfterTextDisplay — pret home/printer.asm:30-33.
;   ld a, $01 / ld [wDoNotWaitForButtonPressAfterDisplayingText], a / ret
; ---------------------------------------------------------------------------
DisableWaitingAfterTextDisplay:
    mov byte [ebp + wDoNotWaitForButtonPressAfterDisplayingText], 1
    ret
