; ===========================================================================
; link_stubs.asm — link-time stand-ins for the engine/link tier
; (docs/current_plan_link_cable.md). Stub conventions per project-conventions:
; exact pret labels, ret-minimal bodies, retirement documented per stub.
;
; The home/serial.asm tier is REAL as of Stage 1 (src/home/serial.asm — the
; old src/home/serial_stubs.asm is deleted). What remains stubbed here are
; engine/link labels whose pret sources land in later stages.
; ===========================================================================

bits 32

%include "gb_memmap.inc"

section .text

; STUB{class=stub; label=CloseLinkConnection; pret=engine/link/cable_club_npc.asm:CloseLinkConnection; behavior=returns immediately instead of pret's Delay3 then resetting hSerialConnectionStatus to $ff and re-arming an externally clocked establish transfer; evidence=the only linked caller is LinkMenu .choseCancel which reads nothing back, and with no transport bound there is no connection state to tear down beyond the status byte LinkMenu itself pins at entry; lifetime=until Stage 2 translates cable_club_npc.asm (which owns this label)}
global CloseLinkConnection
CloseLinkConnection:
    ret

; STUB{class=stub; label=PrintWaitingText; pret=engine/link/print_waiting_text.asm:PrintWaitingText; behavior=returns immediately instead of drawing the Waiting...! box (TextBoxBorder or CableClub_TextBoxBorder by wIsInBattle) and delaying 50 frames; evidence=its only linked caller is Serial_PrintWaitingTextAndSyncAndExchangeNybble whose own callers all land in Stage 3, and the WaitingText string is already generated into assets/link_text.inc for the real mirror; lifetime=until Stage 3 ports print_waiting_text.asm with the trade-screen projection decided}
global PrintWaitingText
PrintWaitingText:
    ret
