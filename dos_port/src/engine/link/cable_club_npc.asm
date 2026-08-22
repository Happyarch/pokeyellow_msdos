; ===========================================================================
; cable_club_npc.asm — mirror of pret engine/link/cable_club_npc.asm.
; docs/current_plan_link_cable.md Stage 2.
;
; Holds all of that file's pret labels: CableClubNPC (the link receptionist),
; Serial_SyncAndExchangeNybbleDouble, CloseLinkConnection, and the seven
; receptionist text streams (far bodies generated into
; assets/link_npc_text.inc — two-tier rule, carrier = this file). Plus ONE
; port-only glue label, CableClubReceptionistScript (bottom), which is how
; the overworld NPC-talk path reaches CableClubNPC (pret routes it through
; DisplayTextID's TX_SCRIPT_CABLE_CLUB_RECEPTIONIST case; the port's
; CheckNPCInteraction dispatches generated SCRIPT table entries instead —
; see the note at that label).
;
; The 90-frame establishment race keeps pret's exact shape: each frame it
; arms as slave (rSB=$02 offer, rSC=START|EXTERNAL) then kicks as master
; (rSB=$01, rSC=START|INTERNAL), and whoever's transfer completes decides
; both roles through the Serial handler's not-yet-established path. The
; port's rSC writes are the virtual IO_SC byte + NetHAL_StartTransfer; the
; net session below the line runs the HELLO/token election and, once BOTH
; sides' races have armed, synthesizes exactly the byte each side's ISR
; would have latched ($02 -> master, $01 -> slave). See net_hal.asm's
; header. With no partner (or a refused HELLO) nothing is ever delivered
; and wLinkTimeoutCounter expires into pret's own no-partner text.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/link/cable_club_npc.asm  (from dos_port/)
; ===========================================================================

bits 32

%include "gb_memmap.inc"
%include "assets/event_constants.inc"   ; EVENT_GOT_POKEDEX
%include "events.inc"                   ; CheckEvent (clobbers AL, sets ZF)
%include "gb_constants.inc"
%include "gb_text.inc"                  ; text_far / text_pause / text_end
%include "assets/audio_constants.inc"   ; SFX_SAVE

global CableClubNPC
global Serial_SyncAndExchangeNybbleDouble
global CloseLinkConnection
global CableClubReceptionistScript
global CableClubNPCWelcomeText          ; stream wrappers (pret labels)
global CableClubNPCAreaReservedFor2FriendsLinkedByCableText
global CableClubNPCPleaseApplyHereHaveToSaveText
global CableClubNPCPleaseWaitText
global CableClubNPCLinkClosedBecauseOfInactivityText
global CableClubNPCPleaseComeAgainText
global CableClubNPCMakingPreparationsText

extern PrintText                    ; src/home/window.asm
extern DelayFrame                   ; src/home/vblank.asm
extern DelayFrames                  ; src/home/delay.asm — In: BL = frames
extern Delay3                       ; src/home/palettes.asm
extern CheckPikachuFollowingPlayer  ; src/home/pikachu.asm — ZF=0: following
extern YesNoChoice                  ; src/home/yes_no.asm
extern SaveGameData                 ; src/engine/menus/save.asm (callfar target)
extern WaitForSoundToFinish         ; src/home/delay.asm
extern PlaySoundWaitForCurrent      ; src/home/delay.asm — In: AL = sound id
extern Serial_SendZeroByte          ; src/home/serial.asm
extern Serial_SyncAndExchangeNybble ; src/home/serial.asm
extern Serial_ExchangeNybble        ; src/home/serial.asm
extern LinkMenu                     ; src/engine/menus/link_menu.asm (callfar target)
extern NetHAL_StartTransfer         ; src/net/net_hal.asm — the rSC-write HAL site
extern NetHAL_LinkAlive             ; src/net/net_hal.asm — ZF=1: no session

; constants/serial_constants.asm (the values link_menu.asm/serial.asm also use)
USING_EXTERNAL_CLOCK        equ 0x01
USING_INTERNAL_CLOCK        equ 0x02
CONNECTION_NOT_ESTABLISHED  equ 0xFF
ESTABLISH_CONNECTION_WITH_INTERNAL_CLOCK equ 0x01
ESTABLISH_CONNECTION_WITH_EXTERNAL_CLOCK equ 0x02
SC_START                    equ 0x80
SC_INTERNAL                 equ 0x01
SC_EXTERNAL                 equ 0x00

; The generated far streams (Tier-1 data; DO-NOT-EDIT header inside).
%include "assets/link_npc_text.inc"

section .text

; ---------------------------------------------------------------------------
; CableClubNPC — pret engine/link/cable_club_npc.asm:1.
; The link receptionist: pokédex gate, the 90-frame establishment race, the
; save prompt, the SyncAndExchangeNybble rendezvous, then LinkMenu.
; ---------------------------------------------------------------------------
CableClubNPC:
    mov esi, CableClubNPCWelcomeText    ; ld hl,... / call PrintText
    call PrintText
    call CheckPikachuFollowingPlayer
    jnz .asm_7048                       ; jr nz — Pikachu out: not ready
    CheckEvent EVENT_GOT_POKEDEX
    jnz .receivedPokedex                ; jp nz
.asm_7048:
    ; no pokédex yet (or Pikachu following): "making preparations"
    mov bl, 60                          ; ld c,60 / call DelayFrames
    call DelayFrames
    mov esi, CableClubNPCMakingPreparationsText
    call PrintText
    jmp .didNotConnect
.receivedPokedex:
    mov byte [ebp + wMenuJoypadPollCount], 1
    mov byte [ebp + wLinkTimeoutCounter], 90
.establishConnectionLoop:
    mov al, [ebp + hSerialConnectionStatus]
    cmp al, USING_INTERNAL_CLOCK
    je .establishedConnection
    cmp al, USING_EXTERNAL_CLOCK
    je .establishedConnection
    ; arm as slave: offer $02 in rSB, clear the receive latch, external clock
    mov byte [ebp + hSerialConnectionStatus], CONNECTION_NOT_ESTABLISHED
    mov byte [ebp + IO_SB], ESTABLISH_CONNECTION_WITH_EXTERNAL_CLOCK
    xor al, al
    mov [ebp + hSerialReceiveData], al
    ; (pret's vc_hook/vc_assert Link_fake_connection_status block is VC-only
    ; scaffolding and is not carried)
    mov byte [ebp + IO_SC], SC_START | SC_EXTERNAL
    call NetHAL_StartTransfer           ; rSC HAL site (serial.asm pattern)
    mov al, [ebp + wLinkTimeoutCounter]
    dec al
    mov [ebp + wLinkTimeoutCounter], al
    jz .failedToEstablishConnection
    ; kick as master: send $01, internal clock
    mov byte [ebp + IO_SB], ESTABLISH_CONNECTION_WITH_INTERNAL_CLOCK
    mov byte [ebp + IO_SC], SC_START | SC_INTERNAL
    call NetHAL_StartTransfer           ; rSC HAL site
    call DelayFrame
    jmp .establishConnectionLoop
.establishedConnection:
    call Serial_SendZeroByte
    call DelayFrame
    call Serial_SendZeroByte
    mov bl, 50                          ; ld c,50 / call DelayFrames
    call DelayFrames
    mov esi, CableClubNPCPleaseApplyHereHaveToSaveText
    call PrintText
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    call YesNoChoice
    mov byte [ebp + wMenuJoypadPollCount], 1
    mov al, [ebp + wCurrentMenuItem]
    test al, al                         ; and a
    jnz .choseNo
    ; DEVIATION{class=banking; pret=engine/link/cable_club_npc.asm:CableClubNPC; behavior=call the linked SaveGameData and LinkMenu directly across the former bank seams; evidence=pret callfar SaveGameData and callfar LinkMenu and the flat single-address-space port; lifetime=permanent flat-code boundary}
    call SaveGameData                   ; pret callfar (see deviation above)
    call WaitForSoundToFinish
    mov al, SFX_SAVE
    call PlaySoundWaitForCurrent
    mov esi, CableClubNPCPleaseWaitText
    call PrintText
    ; wUnknownSerialCounter := $0003 (lo=3, hi=0) — the rendezvous watchdog
    mov byte [ebp + wUnknownSerialCounter], 3
    xor al, al
    mov [ebp + wUnknownSerialCounter + 1], al
    mov [ebp + hSerialReceivedNewData], al
    mov [ebp + wSerialExchangeNybbleSendData], al
    call Serial_SyncAndExchangeNybble
    ; watchdog expired ($ffff) = the partner went silent
    mov al, [ebp + wUnknownSerialCounter]
    inc al
    jnz .connected
    mov al, [ebp + wUnknownSerialCounter + 1]
    inc al
    jnz .connected
    mov bh, 10                          ; ld b,10
.syncLoop:
    call DelayFrame
    call Serial_SendZeroByte
    dec bh
    jnz .syncLoop
    call CloseLinkConnection
    mov esi, CableClubNPCLinkClosedBecauseOfInactivityText
    call PrintText
    jmp .didNotConnect
.failedToEstablishConnection:
    mov esi, CableClubNPCAreaReservedFor2FriendsLinkedByCableText
    call PrintText
    jmp .didNotConnect
.choseNo:
    call CloseLinkConnection
    mov esi, CableClubNPCPleaseComeAgainText
    call PrintText
.didNotConnect:
    xor al, al
    mov [ebp + wUnknownSerialCounter], al
    mov [ebp + wUnknownSerialCounter + 1], al
    and byte [ebp + wStatusFlags4], ~(1 << BIT_LINK_CONNECTED) & 0xFF
    xor al, al
    mov [ebp + wMenuJoypadPollCount], al
    ret
.connected:
    xor al, al                          ; xor a / ld [hld],a / ld [hl],a
    mov [ebp + wUnknownSerialCounter + 1], al
    mov [ebp + wUnknownSerialCounter], al
    mov al, [ebp + wLetterPrintingDelayFlags]
    push eax                            ; push af
    call LinkMenu                       ; pret callfar (deviation above)
    pop eax                             ; pop af
    mov [ebp + wLetterPrintingDelayFlags], al
    ret

; ---------------------------------------------------------------------------
; Serial_SyncAndExchangeNybbleDouble — pret engine/link/cable_club_npc.asm:133
; ("seems to be similar of Serial_SyncAndExchangeNybble" — no linked caller
; in pret Yellow either; translated for completeness). Unlike its home/
; sibling this one decrements wUnknownSerialCounter UNCONDITIONALLY each
; iteration, so it self-terminates; the entry hatch below still short-cuts
; the no-session case rather than counting down for up to ~18 minutes.
;
; DEVIATION{class=HAL; pret=engine/link/cable_club_npc.asm:Serial_SyncAndExchangeNybbleDouble; behavior=writes $ff to wSerialSyncAndExchangeNybbleReceiveData and returns when no link session is up instead of counting the watchdog down through the rendezvous loop; evidence=with no partner the nybble never arrives so the loop only exits through up to 65536 frame-paced watchdog decrements, and the $ff result is the same no-response value the home-bank sibling's hatch publishes; lifetime=permanent no-partner boundary alongside live transports}
; ---------------------------------------------------------------------------
Serial_SyncAndExchangeNybbleDouble:
    call NetHAL_LinkAlive
    jz .noLink
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
.loop:
    call Serial_ExchangeNybble
    call DelayFrame
    push esi                            ; push hl (mirrors pret)
    ; ld hl, wUnknownSerialCounter+1 / dec [hl] / jr nz / dec hl / dec [hl]
    dec byte [ebp + wUnknownSerialCounter + 1]
    jnz .next
    dec byte [ebp + wUnknownSerialCounter]
    jnz .next
    pop esi
    jmp .setUnknownSerialCounterToFFFF
.next:
    pop esi                             ; pop hl
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    inc al
    jz .loop
    call DelayFrame
    mov byte [ebp + wSerialExchangeNybbleReceiveData], 0xFF
    call Serial_ExchangeNybble
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    inc al
    jz .loop
    mov bh, 10                          ; ld b,10
.syncLoop1:
    call DelayFrame
    call Serial_ExchangeNybble
    dec bh
    jnz .syncLoop1
    mov bh, 10
.syncLoop2:
    call DelayFrame
    call Serial_SendZeroByte
    dec bh
    jnz .syncLoop2
    mov al, [ebp + wSerialExchangeNybbleReceiveData]
    mov [ebp + wSerialSyncAndExchangeNybbleReceiveData], al
    ret
.setUnknownSerialCounterToFFFF:
    mov al, 0xFF
    mov [ebp + wUnknownSerialCounter], al
    mov [ebp + wUnknownSerialCounter + 1], al
    ret
.noLink:
    mov byte [ebp + wSerialSyncAndExchangeNybbleReceiveData], 0xFF
    ret

; ---------------------------------------------------------------------------
; CloseLinkConnection — pret engine/link/cable_club_npc.asm:210.
; Tear the GB-level connection state down and re-arm an externally clocked
; establish offer (the idle cartridge posture). Retires the link_stubs.asm
; ret-stub.
; ---------------------------------------------------------------------------
CloseLinkConnection:
    call Delay3
    mov byte [ebp + hSerialConnectionStatus], CONNECTION_NOT_ESTABLISHED
    mov byte [ebp + IO_SB], ESTABLISH_CONNECTION_WITH_EXTERNAL_CLOCK
    xor al, al
    mov [ebp + hSerialReceiveData], al
    mov byte [ebp + IO_SC], SC_START | SC_EXTERNAL
    call NetHAL_StartTransfer           ; rSC HAL site (serial.asm pattern)
    ret

; ---------------------------------------------------------------------------
; Text-stream wrappers — pret engine/link/cable_club_npc.asm:181-208, same
; order. Far bodies live in the generated include above.
; ---------------------------------------------------------------------------
section .data

CableClubNPCAreaReservedFor2FriendsLinkedByCableText:
    text_far _CableClubNPCAreaReservedFor2FriendsLinkedByCableText
    text_end

CableClubNPCWelcomeText:
    text_far _CableClubNPCWelcomeText
    text_end

CableClubNPCPleaseApplyHereHaveToSaveText:
    text_far _CableClubNPCPleaseApplyHereHaveToSaveText
    text_end

CableClubNPCPleaseWaitText:
    text_far _CableClubNPCPleaseWaitText
    text_pause
    text_end

CableClubNPCLinkClosedBecauseOfInactivityText:
    text_far _CableClubNPCLinkClosedBecauseOfInactivityText
    text_end

CableClubNPCPleaseComeAgainText:
    text_far _CableClubNPCPleaseComeAgainText
    text_end

CableClubNPCMakingPreparationsText:
    text_far _CableClubNPCMakingPreparationsText
    text_end

section .text

; ---------------------------------------------------------------------------
; CableClubReceptionistScript — PORT-ONLY glue (descriptive name, no pret
; counterpart). pret reaches CableClubNPC through DisplayTextID's
; TX_SCRIPT_CABLE_CLUB_RECEPTIONIST ($f6) case (home/text_script.asm — the
; port's mirror of that case exists at src/home/text_script.asm:277 and
; stays); the port's live NPC-talk path is CheckNPCInteraction's generated
; dialog table, which dispatches SCRIPT entries by `call`. Every
; <Map>LinkReceptionistText is routed here by gen_npc_dialogs.py's
; SCRIPT_OVERRIDES, and this shim runs the same body the DisplayTextID case
; runs. The dialog window teardown the DisplayTextID path gets from
; AfterDisplayingTextID is CheckNPCInteraction's .dialog_done here; the
; wEnteringCableClub hold-open nuance matters only once the club-map warp is
; wired (Stage 3 validates that flow end to end).
; DEVIATION{class=projection; pret=home/text_script.asm:DisplayTextID; behavior=the receptionist text id dispatches through CheckNPCInteraction's generated SCRIPT table into this shim instead of DisplayTextID's TX_SCRIPT byte case; evidence=the port's overworld NPC-talk path is the generated dialog table (map_sprites.asm CheckNPCInteraction) and pret's DisplayTextID case body is call CableClubNPC then AfterDisplayingTextID which this shim and .dialog_done reproduce; lifetime=permanent overworld dialog-dispatch projection}
; ---------------------------------------------------------------------------
CableClubReceptionistScript:
    call CableClubNPC
    ret
