; ===========================================================================
; link_stubs.asm — link-time stand-ins for the engine/link tier
; (docs/current_plan_link_cable.md). Stub conventions per project-conventions:
; exact pret labels, ret-minimal bodies, retirement documented per stub.
;
; The home/serial.asm tier is REAL as of Stage 1, and cable_club_npc.asm is
; REAL as of Stage 2 (its CloseLinkConnection retired this file's stub).
; What remains stubbed here are engine/link labels whose pret sources land
; in later stages.
; ===========================================================================

bits 32

%include "gb_memmap.inc"

section .text

; STUB{class=stub; label=PrintWaitingText; pret=engine/link/print_waiting_text.asm:PrintWaitingText; behavior=returns immediately instead of drawing the Waiting...! box (TextBoxBorder or CableClub_TextBoxBorder by wIsInBattle) and delaying 50 frames; evidence=its only linked caller is Serial_PrintWaitingTextAndSyncAndExchangeNybble whose own callers all land in Stage 3, and the WaitingText string is already generated into assets/link_text.inc for the real mirror; lifetime=until Stage 3 ports print_waiting_text.asm with the trade-screen projection decided}
global PrintWaitingText
PrintWaitingText:
    ret
