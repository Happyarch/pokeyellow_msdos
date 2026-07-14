; ===========================================================================
; serial_stubs.asm — link-time stand-ins for pret home/serial.asm.
;
; ; TODO-HW: network HAL (Phase 4).  The port has no serial hardware and no
; network transport, so the six serial entry points the link menus call are
; stubbed.  Per the stub convention (project-conventions skill) they live HERE,
; under their exact pret labels — never as bodies in the file that will one day
; hold the real routines (a future src/home/serial.asm), and never in a caller's
; mirror file.  Until row 20 part 2 they sat inside engine/menus/link_menu.asm,
; which is a caller — the mirror-file shadow class the convention exists to stop
; (menu-fidelity M-112).
;
; NOT SHADOWING A REAL BODY: no src/home/serial.asm exists in the tree (checked
; against the Makefile source lists and nm) — there is no unlinked faithful body
; for these labels anywhere, so these stubs are the only definitions.  When the
; network HAL lands, delete this file: two linked globals of one name is a link
; error, so the collision will be loud rather than a silent shadow.
;
; ---------------------------------------------------------------------------
; NO-PARTNER (single-player) RETURN CONTRACT
;
; These are not bare rets: each of pret's routines communicates its result
; through A or a WRAM byte, and the callers (LinkMenu / Func_f531b in
; engine/menus/link_menu.asm) branch on that result.  A bare ret would leave the
; byte at whatever the last screen wrote and send those menus down an undefined
; path — the contract below is chosen so the no-partner collapse drives each menu
; to a pret TERMINAL path, never past one:
;
;   hSerialConnectionStatus is pinned to CONNECTION_NOT_ESTABLISHED ($ff) by
;     LinkMenu at entry (not here).  $ff != USING_INTERNAL_CLOCK, so every
;     "who clocks the connection wins" / "start the transfer" test takes the
;     not-internal branch deterministically.
;
;   Serial_ExchangeByte  -> A := $c0.  Func_f531b reads it twice and requires the
;     two reads to be equal (`cp b`) with high nybble $c0 (`and $f0 / cp $c0`); a
;     fixed value satisfies both.  Low nybble 0 = "partner pressed neither A nor
;     B", so the menu uses the PLAYER's selection.
;
;   Serial_ExchangeLinkMenuSelection -> receive buffer[0..1] := $d0.  Same shape
;     one nybble up: LinkMenu's `and $f0 / cp $d0` accepts it (the exchange loop
;     exits) and the 0 low nybble means the partner pressed nothing.
;
;   Serial_ExchangeNybble -> wSerialExchangeNybbleReceiveData := $ff ("no
;     response").  LinkMenu's COLOSSEUM2 wait (`inc a / jr z`) therefore keeps
;     looping until its own b=$78 frame counter expires -> the timeout branch
;     -> .choseCancel (which still runs CloseLinkConnection and the cancel
;     dialog).
;
;   Serial_SyncAndExchangeNybble -> wSerialSyncAndExchangeNybbleReceiveData :=
;     $ff.  $cc3d is BOTH that symbol and (pret's own wram union)
;     wLinkMenuSelectionReceiveBuffer, which Func_f531b reads on the next line:
;     non-zero = "the remote player's team is ineligible" -> Func_f5476
;     (ColosseumIneligibleText) -> asm_f547c (jp Func_f531b, redraw and retry).
;
;   Serial_SendZeroByte / CloseLinkConnection -> genuinely nothing to do without
;     a link: pret sends a $00 byte / tears the connection down.  Bare rets, and
;     flag-safe: every caller either ignores flags or re-derives them (Func_f531b's
;     drain loop tests its own `dec b`).
;
; Register map: A→AL, BC→BX, DE→DX, HL→ESI; GB memory = [ebp + SYM].
; ===========================================================================
bits 32

%include "gb_memmap.inc"

section .text

global Serial_ExchangeByte
global Serial_ExchangeLinkMenuSelection
global Serial_ExchangeNybble
global Serial_SyncAndExchangeNybble
global Serial_SendZeroByte
global CloseLinkConnection

; pret ref: home/serial.asm:Serial_ExchangeByte
Serial_ExchangeByte:
    mov al, 0xC0                    ; fixed "idle partner" byte (see CONTRACT)
    ret

; pret ref: home/serial.asm:Serial_ExchangeLinkMenuSelection
Serial_ExchangeLinkMenuSelection:
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer], 0xD0
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer + 1], 0xD0
    ret

; pret ref: home/serial.asm:Serial_ExchangeNybble
Serial_ExchangeNybble:
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
    ret

; pret ref: home/serial.asm:Serial_SyncAndExchangeNybble
Serial_SyncAndExchangeNybble:
    mov byte [ebp + wSerialSyncAndExchangeNybbleReceiveData], 0xFF
    ret

; pret ref: home/serial.asm:Serial_SendZeroByte
Serial_SendZeroByte:
    ret

; pret ref: home/serial.asm:CloseLinkConnection
CloseLinkConnection:
    ret
