; ===========================================================================
; serial.asm — mirror of pret home/serial.asm (all 13 of its labels).
; docs/current_plan_link_cable.md Stage 1: serial core + no-transport parity.
;
; This file is the link plan's HAL LINE. Everything above these routines
; (link_menu.asm today; cable_club*.asm, trade and link battle in later
; stages) is translated verbatim from pret and calls these primitives by
; their pret contracts. Below them sits the port-owned transport layer
; (src/net/net_hal.asm): rSB/rSC are virtual bytes (IO_SB/IO_SC), every
; `rSC = SC_START|*` write is followed by NetHAL_StartTransfer, and the
; serial INTERRUPT is replaced by delivery — a transport pump that completes
; an exchange calls `Serial` (below), the pret handler, with the received
; byte staged in IO_SB.
;
; NO-PARTNER CONTRACT (the retired serial_stubs.asm contract, kept verbatim).
; pret only ever runs these primitives with an established connection — the
; GB's no-partner terminations all live in the CALLERS (CableClubNPC's
; 90-frame race, LinkMenu's b=$78 loop). With no partner the primitives'
; own wait loops have no exit (hSerialReceivedNewData is interrupt-set;
; wUnknownSerialCounter is zeroed = disabled by LinkMenu's sites), so each
; exchange primitive takes an annotated no-link escape hatch at entry
; (NetHAL_LinkAlive, ZF=1 = dead) that reproduces the documented stub
; contract and keeps the menus on pret TERMINAL paths:
;
;   Serial_ExchangeByte              -> AL := $c0   (Func_f531b: two equal
;       reads, hi nybble $c0, low nybble 0 = "partner pressed nothing")
;   Serial_ExchangeLinkMenuSelection -> receive buffer[0..1] := $d0 (same
;       shape one nybble up, for LinkMenu's $d0 gate)
;   Serial_ExchangeNybble            -> wSerialExchangeNybbleReceiveData := $ff
;       ("no response" — LinkMenu's COLOSSEUM2 b=$78 counter expires)
;   Serial_SyncAndExchangeNybble     -> wSerialSyncAndExchangeNybbleReceiveData
;       := $ff (Func_f531b reads it as wLinkMenuSelectionReceiveBuffer ->
;       remote-ineligible -> redraw/retry path)
;   Serial_ExchangeBytes             -> immediate return, buffers untouched
;       (no pret caller is linked before Stage 3; the hatch is a hang guard)
;
; hSerialConnectionStatus stays pinned to CONNECTION_NOT_ESTABLISHED ($ff) by
; LinkMenu at entry until Stage 2's HELLO role election writes pret's own
; $01/$02 constants into it.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base.
; Preservation matches pret per routine; DelayFrame and the NetHAL_* entries
; preserve all GP registers (NetHAL_* clobber flags — call sites are placed
; where no SM83 flag is live).
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/home/serial.asm   (from dos_port/)
; ===========================================================================

bits 32

%include "gb_memmap.inc"

global Serial
global Serial_ExchangeBytes
global Serial_ExchangeByte
global WaitLoop_15Iterations
global IsUnknownCounterZero
global SetUnknownCounterToFFFF
global Serial_ExchangeLinkMenuSelection
global Serial_PrintWaitingTextAndSyncAndExchangeNybble
global Serial_SyncAndExchangeNybble
global Serial_ExchangeNybble
global Serial_SendZeroByte
global Serial_TryEstablishingExternallyClockedConnection
global PrinterSerial__

extern NetHAL_Pump              ; src/net/net_hal.asm — poll the bound transport
extern NetHAL_LinkAlive         ; src/net/net_hal.asm — ZF=1: no link session
extern NetHAL_StartTransfer     ; src/net/net_hal.asm — the rSC-write HAL site
extern NetHAL_ExchangeBlock     ; src/net/net_hal.asm — whole-block exchange
                                ; (Serial_ExchangeBytes' HAL cut, Stage 3)
extern DelayFrame               ; src/home/vblank.asm
extern PrinterSerial            ; src/home/printer.asm — dead
                                ; branch, see PrinterSerial__ below
extern PrintWaitingText         ; src/engine/link/print_waiting_text.asm
                                ; (pret mirror, real as of Stage 3 — the
                                ; link_stubs.asm stub is retired)
extern SaveScreenTilesToBuffer1     ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1   ; src/home/tilemap.asm

; constants/serial_constants.asm + hardware.inc (same values link_menu.asm uses)
USING_EXTERNAL_CLOCK        equ 0x01
USING_INTERNAL_CLOCK        equ 0x02
ESTABLISH_CONNECTION_WITH_EXTERNAL_CLOCK equ 0x02
SERIAL_PREAMBLE_BYTE        equ 0xFD
SERIAL_NO_DATA_BYTE         equ 0xFE
SC_START                    equ 0x80    ; hardware.inc B_SC_START
SC_INTERNAL                 equ 0x01    ; hardware.inc B_SC_SOURCE
SC_EXTERNAL                 equ 0x00
IE_VBLANK                   equ 0x01    ; hardware.inc interrupt-enable bits
IE_STAT                     equ 0x02
IE_TIMER                    equ 0x04
IE_SERIAL                   equ 0x08

section .text

; ---------------------------------------------------------------------------
; Serial — pret home/serial.asm:1 (the serial interrupt handler).
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial; behavior=runs as a plain call from a transport pump on exchange completion with ret instead of a hardware serial interrupt with reti, rSB/rSC are virtual GB-memory bytes and the slave re-arm rSC write is consumed by the transport driver via NetHAL_StartTransfer; evidence=the port has no SM83 interrupt controller and net_hal.asm transports deliver completed exchanges from NetHAL_Pump (docs/current_plan_link_cable.md message-level seam); lifetime=permanent HAL boundary}
;
; Stage 1: nothing calls this yet (the null transport never delivers). It is
; translated now so the Stage-2 UART pump has the real handler to call.
; ---------------------------------------------------------------------------
Serial:
    push eax                        ; push af/bc/de/hl
    push ebx
    push edx
    push esi
    ; ld a,[wPrinterConnectionOpen] / bit 0,a / jp nz, PrinterSerial__
    mov al, [ebp + wPrinterConnectionOpen]
    test al, 1                      ; retained DEAD branch: no port code sets
    jnz PrinterSerial__             ; bit 0 (printer plan cuts inside the
                                    ; printer engine, not here)
    ; ldh a,[hSerialConnectionStatus] / inc a / jr z (status == $ff -> not yet
    ; established)
    mov al, [ebp + hSerialConnectionStatus]
    inc al
    jz .connectionNotYetEstablished
    ; established: latch the received byte, stage the next send byte
    mov al, [ebp + IO_SB]
    mov [ebp + hSerialReceiveData], al
    mov al, [ebp + hSerialSendData]
    mov [ebp + IO_SB], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    je .done
    ; using external clock: re-arm the slave-side transfer
    mov byte [ebp + IO_SC], SC_START | SC_EXTERNAL
    call NetHAL_StartTransfer
    jmp .done
.connectionNotYetEstablished:
    ; first byte decides who clocks the connection: latch it as both the
    ; received data and the connection status
    mov al, [ebp + IO_SB]
    mov [ebp + hSerialReceiveData], al
    mov [ebp + hSerialConnectionStatus], al
    cmp al, USING_INTERNAL_CLOCK
    je .usingInternalClock
    ; using external clock
    xor al, al
    mov [ebp + IO_SB], al
    ; DEVIATION{class=timing; pret=home/serial.asm:Serial; behavior=the rDIV wait (write 3 then spin until bit 7 sets, roughly 32k cycles of hardware clock settling) is skipped; evidence=rDIV is inert in the port so a literal spin never exits, and the transports carry no bit clock to settle; lifetime=permanent HAL boundary}
    mov byte [ebp + IO_SC], SC_START | SC_EXTERNAL
    call NetHAL_StartTransfer
    jmp .done
.usingInternalClock:
    xor al, al
    mov [ebp + IO_SB], al
.done:
    mov byte [ebp + hSerialReceivedNewData], 1
    mov byte [ebp + hSerialSendData], SERIAL_NO_DATA_BYTE
    pop esi                         ; pop hl/de/bc/af
    pop edx
    pop ebx
    pop eax
    ret                             ; pret reti — see the HAL deviation above

; ---------------------------------------------------------------------------
; Serial_ExchangeBytes — pret home/serial.asm:58.
; In:  ESI = send data (HL), EDX = receive data (DE), BX = length (BC);
;      all GB offsets.
; Out: ESI/EDX advanced past the block, BX = 0 (as pret leaves bc).
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial_ExchangeBytes; behavior=the whole block crosses the wire as one reliable message each way via NetHAL_ExchangeBlock instead of pret's per-byte Serial_ExchangeByte loop with the ignore-until-preamble alignment, and the receive buffer holds the peer's send block verbatim from byte 0 where hardware stored it shifted 1-3 bytes by the preamble hunt, and it returns with the receive buffer untouched when no link session is up at entry or when it dies mid-exchange; evidence=maintainer architecture decision that byte-level lockstep must not be replayed over the network (one message per semantic exchange - docs/current_plan_link_cable.md exchange table) and every pret consumer of the received blocks scans past leading preamble slash zero bytes (cable_club.asm RNG-list and enemy-name scans skip 00 FD FE, the patch-list walker keys on FF terminators) so the verbatim alignment lands on identical downstream state, with both peers DOS ports seeing the same alignment by construction; lifetime=permanent HAL boundary}
;
; pret's register/WRAM exit contract is reproduced exactly: HL and DE advanced
; past the block, BC = 0 with ZF set, hSerialIgnoringInitialData written at
; entry as pret does (nothing else reads it between here and the next
; exchange). The 48-iteration inter-byte spin and the wUnknownSerialCounter2
; block-mode watchdog are per-byte pacing with no block-level counterpart;
; codec death (net_frame NF_DEATH_TICKS) bounds the wait instead.
; ---------------------------------------------------------------------------
Serial_ExchangeBytes:
    call NetHAL_LinkAlive
    jz .noLink
    mov byte [ebp + hSerialIgnoringInitialData], 1
    call NetHAL_ExchangeBlock       ; one reliable message each way (deviation)
    call NetHAL_LinkAlive           ; died mid-exchange: receive buffer is
    jz .noLink                      ; untouched (ExchangeBlock copies only on
                                    ; a validated peer block)
    ; pret exit state: hl/de past the block, bc = 0 (ZF set by the loop's
    ; final `or`)
    movzx eax, bx
    add esi, eax
    add edx, eax
    xor bx, bx                      ; ZF=1, as pret's ld a,b / or c leaves it
    mov al, 0                       ; pret exits with a = b|c = 0 (flag-safe)
    ret
.noLink:
    ret

; ---------------------------------------------------------------------------
; Serial_ExchangeByte — pret home/serial.asm:92.
; In:  hSerialSendData staged by the caller; ESI (HL) = caller's send pointer
;      (only read on the frame-paced no-data resend tail, as in pret).
; Out: AL = the exchanged byte (or the no-partner contract byte).
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial_ExchangeByte; behavior=returns AL=$c0 immediately when no link session is up at entry or when it dies mid-wait instead of continuing the wait loop, and the wait loop polls NetHAL_Pump because delivery is pump-driven rather than interrupt-driven; evidence=hSerialReceivedNewData is only ever set by the Serial delivery handler so with no partner the loop has no exit, and the $c0 contract is the measured serial_stubs value that keeps Func_f531b's two-read gate on its pret terminal path; lifetime=permanent no-partner boundary alongside live transports from Stage 2}
; ---------------------------------------------------------------------------
Serial_ExchangeByte:
    call NetHAL_LinkAlive
    jz .noLink
    xor al, al
    mov [ebp + hSerialReceivedNewData], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    jne .loop
    ; master: clock the transfer
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL
    call NetHAL_StartTransfer
.loop:
    call NetHAL_Pump                ; port: interrupt -> polled delivery (see
                                    ; the HAL deviation above); no flags live
    call NetHAL_LinkAlive           ; session died mid-wait: escape through
    jz .noLink                      ; the no-partner hatch
    mov al, [ebp + hSerialReceivedNewData]
    test al, al                     ; and a
    jnz .ok
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_EXTERNAL_CLOCK
    jne .doNotIncrementUnknownCounter
    call IsUnknownCounterZero
    jz .doNotIncrementUnknownCounter
    call WaitLoop_15Iterations
    push esi                        ; push hl
    ; ld hl,wUnknownSerialCounter+1 / inc [hl] / jr nz / dec hl / inc [hl]
    inc byte [ebp + wUnknownSerialCounter + 1]
    jnz .noCarry
    inc byte [ebp + wUnknownSerialCounter]
.noCarry:
    pop esi                         ; pop hl
    call IsUnknownCounterZero
    jnz .loop
    jmp SetUnknownCounterToFFFF     ; watchdog expiry: return through it (A=$ff)
.doNotIncrementUnknownCounter:
    mov al, [ebp + GB_IE]           ; ldh a,[rIE] — virtual, Init writes $0d,
                                    ; cable_club.asm narrows it to IE_SERIAL
                                    ; around block exchanges (Stage 3)
    and al, IE_SERIAL | IE_TIMER | IE_STAT | IE_VBLANK
    cmp al, IE_SERIAL
    jne .loop
    ; free-running block-exchange mode: run the wUnknownSerialCounter2 watchdog
    mov al, [ebp + wUnknownSerialCounter2]
    dec al
    mov [ebp + wUnknownSerialCounter2], al
    jnz .loop
    mov al, [ebp + wUnknownSerialCounter2 + 1]
    dec al
    mov [ebp + wUnknownSerialCounter2 + 1], al
    jnz .loop
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_EXTERNAL_CLOCK
    je .ok
    mov al, 255
.waitLoop:
    ; 8-BIT spin kept verbatim (see Serial_ExchangeBytes.waitLoop)
    dec al
    jnz .waitLoop
.ok:
    xor al, al
    mov [ebp + hSerialReceivedNewData], al
    ; reload the block-mode watchdog iff rIE is exactly IE_SERIAL
    mov al, [ebp + GB_IE]
    and al, IE_SERIAL | IE_TIMER | IE_STAT | IE_VBLANK
    sub al, IE_SERIAL
    jnz .skipReloadingUnknownCounter2
    mov [ebp + wUnknownSerialCounter2], al          ; a = 0 here
    mov al, 0x50
    mov [ebp + wUnknownSerialCounter2 + 1], al
.skipReloadingUnknownCounter2:
    mov al, [ebp + hSerialReceiveData]
    cmp al, SERIAL_NO_DATA_BYTE
    je .gotNoData
    ret                             ; ret nz — AL = the received byte
.gotNoData:
    call IsUnknownCounterZero
    jz .done
    push esi                        ; push hl
    ; 16-bit borrow-chain decrement of wUnknownSerialCounter, byte order as pret
    mov al, [ebp + wUnknownSerialCounter + 1]
    dec al
    mov [ebp + wUnknownSerialCounter + 1], al
    inc al                          ; original value; Z = it was 0 -> borrow
    jnz .noBorrow
    dec byte [ebp + wUnknownSerialCounter]
.noBorrow:
    pop esi                         ; pop hl
    call IsUnknownCounterZero
    jz SetUnknownCounterToFFFF      ; jr z — returns through it (A=$ff)
.done:
    mov al, [ebp + GB_IE]
    and al, IE_SERIAL | IE_TIMER | IE_STAT | IE_VBLANK
    cmp al, IE_SERIAL
    mov al, SERIAL_NO_DATA_BYTE     ; flag-preserving (ld a,n)
    jne .framePacedResend
    ret                             ; ret z — block mode: report "no data"
.framePacedResend:
    ; frame-paced mode: re-stage the caller's send byte and retry next frame.
    ; HL is 16-bit on the GB; ESI can hold a flat pointer at this incidental
    ; read (Func_f531b's context), so clamp the read to the GB 64K domain —
    ; the 16-bit wrap IS pret's bound (see "Preserve Counter WIDTH").
    push esi
    and esi, 0xFFFF
    mov al, [ebp + esi]             ; ld a,[hl]
    pop esi
    mov [ebp + hSerialSendData], al
    call DelayFrame
    jmp Serial_ExchangeByte
.noLink:
    mov al, 0xC0                    ; no-partner contract (header + deviation)
    ret

; ---------------------------------------------------------------------------
; WaitLoop_15Iterations — pret home/serial.asm:180. 8-bit spin, verbatim.
; ---------------------------------------------------------------------------
WaitLoop_15Iterations:
    mov al, 15
.waitLoop:
    dec al
    jnz .waitLoop
    ret

; ---------------------------------------------------------------------------
; IsUnknownCounterZero — pret home/serial.asm:187.
; Out: ZF=1 (and AL=0) iff both bytes of wUnknownSerialCounter are zero.
; ---------------------------------------------------------------------------
IsUnknownCounterZero:
    push esi                        ; push hl (mirrors pret; esi untouched here)
    mov al, [ebp + wUnknownSerialCounter]
    or al, [ebp + wUnknownSerialCounter + 1]
    pop esi
    ret

; ---------------------------------------------------------------------------
; SetUnknownCounterToFFFF — pret home/serial.asm:196. A is always 0 on entry;
; returns A=$ff with both counter bytes $ff.
; ---------------------------------------------------------------------------
SetUnknownCounterToFFFF:
    dec al
    mov [ebp + wUnknownSerialCounter], al
    mov [ebp + wUnknownSerialCounter + 1], al
    ret

; ---------------------------------------------------------------------------
; Serial_ExchangeLinkMenuSelection — pret home/serial.asm:204.
; Exchanges wLinkMenuSelectionSendBuffer <-> wLinkMenuSelectionReceiveBuffer
; (2 bytes; sent thrice, read twice, as pret's comment says).
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial_ExchangeLinkMenuSelection; behavior=writes $d0 into both receive-buffer bytes and returns when no link session is up instead of entering the exchange loop; evidence=with no partner Serial_ExchangeByte never completes so pret's loop has no exit, and $d0 is the measured serial_stubs value LinkMenu's hi-nybble gate accepts with low nybble 0 meaning the partner pressed nothing; lifetime=permanent no-partner boundary alongside live transports from Stage 2}
; ---------------------------------------------------------------------------
Serial_ExchangeLinkMenuSelection:
    call NetHAL_LinkAlive
    jz .noLink
    mov esi, wLinkMenuSelectionSendBuffer       ; ld hl,...
    mov edx, wLinkMenuSelectionReceiveBuffer    ; ld de,...
    mov bl, 2                                   ; ld c,2 — bytes to save
    mov byte [ebp + hSerialIgnoringInitialData], 1
.loop:
    call DelayFrame
    mov al, [ebp + esi]             ; ld a,[hl]
    mov [ebp + hSerialSendData], al
    call Serial_ExchangeByte
    mov bh, al                      ; ld b,a
    inc esi                         ; inc hl
    mov al, [ebp + hSerialIgnoringInitialData]
    test al, al                     ; and a
    mov al, 0                       ; ld a,0 (flag-preserving, NOT xor)
    mov [ebp + hSerialIgnoringInitialData], al
    jnz .loop                       ; first pass: discard, go again
    mov al, bh                      ; ld a,b
    mov [ebp + edx], al             ; ld [de],a
    inc edx                         ; inc de
    dec bl                          ; dec c — 8-bit, as pret
    jnz .loop
    ret
.noLink:
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer], 0xD0
    mov byte [ebp + wLinkMenuSelectionReceiveBuffer + 1], 0xD0
    ret

; ---------------------------------------------------------------------------
; Serial_PrintWaitingTextAndSyncAndExchangeNybble — pret home/serial.asm:229.
; DEVIATION{class=banking; pret=home/serial.asm:Serial_PrintWaitingTextAndSyncAndExchangeNybble; behavior=call the linked PrintWaitingText directly across the former bank seam; evidence=pret callfar PrintWaitingText and the flat single-address-space port; lifetime=permanent flat-code boundary}
; ---------------------------------------------------------------------------
Serial_PrintWaitingTextAndSyncAndExchangeNybble:
    call SaveScreenTilesToBuffer1
    call PrintWaitingText           ; pret callfar (see deviation above)
    call Serial_SyncAndExchangeNybble
    jmp LoadScreenTilesFromBuffer1

; ---------------------------------------------------------------------------
; Serial_SyncAndExchangeNybble — pret home/serial.asm:235.
; Rendezvous: repeat Serial_ExchangeNybble until the partner's nybble arrives
; (wUnknownSerialCounter, when armed, bounds the wait), then drain 10 + 10
; frames and publish the result to wSerialSyncAndExchangeNybbleReceiveData.
; The drain loops stay as LOCAL frame delays (game feel); they generate no
; wire traffic beyond the nybble re-sends, exactly as pret paces them.
; (Non-VC branch: b=10; the _YELLOW_VC vc_patch 26-frame variants are VC-only.)
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial_SyncAndExchangeNybble; behavior=writes $ff to wSerialSyncAndExchangeNybbleReceiveData and returns when no link session is up at entry or when it dies mid-rendezvous instead of continuing the rendezvous loop; evidence=with no partner the nybble never arrives and LinkMenu's call sites zero wUnknownSerialCounter which disables the bounding watchdog so loop1 has no exit, and $ff is the measured serial_stubs value that routes Func_f531b to its remote-ineligible retry path; lifetime=permanent no-partner boundary alongside live transports from Stage 2}
; ---------------------------------------------------------------------------
Serial_SyncAndExchangeNybble:
    call NetHAL_LinkAlive
    jz .noLink
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
.loop1:
    call NetHAL_LinkAlive           ; session died mid-rendezvous: escape
    jz .noLink                      ; through the no-partner hatch
    call Serial_ExchangeNybble
    call DelayFrame
    call IsUnknownCounterZero
    jz .next1
    push esi                        ; push hl
    ; ld hl,wUnknownSerialCounter+1 / dec [hl] / jr nz / dec hl / dec [hl]
    dec byte [ebp + wUnknownSerialCounter + 1]
    jnz .next2
    dec byte [ebp + wUnknownSerialCounter]
    jnz .next2
    pop esi                         ; pop hl
    xor al, al
    jmp SetUnknownCounterToFFFF     ; watchdog expiry: return through it
.next2:
    pop esi                         ; pop hl
.next1:
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    inc al                          ; $ff -> 0: nothing received yet
    jz .loop1
    mov bh, 10                      ; ld b,10
.loop2:
    call DelayFrame
    call Serial_ExchangeNybble
    dec bh
    jnz .loop2
    mov bh, 10                      ; ld b,10
.loop3:
    call DelayFrame
    call Serial_SendZeroByte
    dec bh
    jnz .loop3
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData], al
    ret
.noLink:
    mov byte [ebp + wSerialSyncAndExchangeNybbleReceiveData], 0xFF
    ret

; ---------------------------------------------------------------------------
; Serial_ExchangeNybble — pret home/serial.asm:289.
; Sends wSerialExchangeNybbleSendData + $60; if a $6x byte has arrived,
; publishes its low nybble to wSerialExchangeNybbleReceiveData.
;
; DEVIATION{class=HAL; pret=home/serial.asm:Serial_ExchangeNybble; behavior=writes $ff to wSerialExchangeNybbleReceiveData and returns when no link session is up instead of staging the send nybble; evidence=with no partner no $6x byte ever arrives so the receive publish never fires, and $ff is the measured serial_stubs no-response value LinkMenu's COLOSSEUM2 timeout counts against; lifetime=permanent no-partner boundary alongside live transports from Stage 2}
; ---------------------------------------------------------------------------
Serial_ExchangeNybble:
    call NetHAL_LinkAlive
    jz .noLink
    call .doExchange
    mov al, [ebp + wSerialExchangeNybbleSendData]
    add al, 0x60
    mov [ebp + hSerialSendData], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    jne .doExchange                 ; jr nz — tail-runs .doExchange, whose ret
                                    ; returns to the caller
    ; master: clock the transfer
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL
    call NetHAL_StartTransfer
.doExchange:
    mov al, [ebp + hSerialReceiveData]
    mov [ebp + wSerialExchangeNybbleTempReceiveData], al
    and al, 0xF0
    cmp al, 0x60
    je .gotNybble
    ret                             ; ret nz
.gotNybble:
    xor al, al
    mov [ebp + hSerialReceiveData], al
    mov al, [ebp + wSerialExchangeNybbleTempReceiveData]
    and al, 0x0F
    mov [ebp + wSerialExchangeNybbleReceiveData], al
    ret
.noLink:
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
    ret

; ---------------------------------------------------------------------------
; Serial_SendZeroByte — pret home/serial.asm:312. Terminates without a link
; (status $ff != internal -> ret), so no hatch is needed.
; ---------------------------------------------------------------------------
Serial_SendZeroByte:
    xor al, al
    mov [ebp + hSerialSendData], al
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    je .master
    ret                             ; ret nz
.master:
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL
    call NetHAL_StartTransfer       ; rSC HAL site (Serial header deviation)
    ret

; ---------------------------------------------------------------------------
; Serial_TryEstablishingExternallyClockedConnection — pret home/serial.asm:322.
; Stages the "I'll take the external clock" offer byte and arms a slave-side
; transfer. Called every frame by the 13 Pokecenter map scripts, so the HAL
; site must stay a fast no-op with no transport bound (it is: one compare).
; ---------------------------------------------------------------------------
Serial_TryEstablishingExternallyClockedConnection:
    mov byte [ebp + IO_SB], ESTABLISH_CONNECTION_WITH_EXTERNAL_CLOCK
    xor al, al
    mov [ebp + hSerialReceiveData], al
    mov byte [ebp + IO_SC], SC_START | SC_EXTERNAL
    call NetHAL_StartTransfer       ; rSC HAL site (Serial header deviation)
    ret

; ---------------------------------------------------------------------------
; PrinterSerial__ — pret home/serial.asm:331. The Serial handler's printer
; branch: retained as a documented DEAD branch (no port code sets
; wPrinterConnectionOpen bit 0; the printer plan's seam is inside the printer
; engine, docs/current_plan_printer.md "The seam"). Pops the registers Serial
; pushed, exactly as pret does.
; ---------------------------------------------------------------------------
PrinterSerial__:
    call PrinterSerial
    pop esi                         ; pop hl/de/bc/af (pushed by Serial)
    pop edx
    pop ebx
    pop eax
    ret                             ; pret reti — see Serial's HAL deviation
