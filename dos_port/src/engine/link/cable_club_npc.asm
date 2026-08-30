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
%ifdef DEBUG_CABLECLUB
extern DumpBackbuffer               ; src/debug/debug_dump.asm — FRAME.BIN + GBSTATE.BIN, then exit
%endif
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
extern LinkTransportSelect          ; src/net/link_ui.asm — Out: AL=1 proceed / 0 cancel

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
    ; DEVIATION{class=HAL; pret=engine/link/cable_club_npc.asm:CableClubNPC; behavior=insert a transport-select UI call before the establishment race, cancelling to the no-partner path when the player backs out; evidence=the GB has one fixed physical cable so pret never has to choose a transport, while the port must pick between the CLI-preselected transport and SERIAL/IPX/TCP-IP the player chooses live, and net_hal.asm:109's own comment says the UI selects by storing g_net_transport before this race would otherwise begin; lifetime=permanent HAL boundary for a transport this stage cannot know in advance}
    ; LinkTransportSelect (src/net/link_ui.asm) returns immediately (AL=1) when
    ; g_net_transport is already bound (CLI /COMx flags) -- the common case is a
    ; single extra branch, not an extra screen. AL=0 means the player cancelled
    ; out of the transport-select/book UI entirely; route that to the same
    ; .didNotConnect pret already uses for "couldn't establish".
    call LinkTransportSelect
    test al, al
    jz .didNotConnect
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
; wired (the overworld half of that flow — the hold-open check itself and the
; warp's end-to-end scenario — is owned by docs/current_plan_overworld_realign.md
; Stage J.5, adopted 2026-08-28; this plan's Stage 3 keeps the in-club session).
; DEVIATION{class=projection; pret=home/text_script.asm:DisplayTextID; behavior=the receptionist text id dispatches through CheckNPCInteraction's generated SCRIPT table into this shim instead of DisplayTextID's TX_SCRIPT byte case; evidence=the port's overworld NPC-talk path is the generated dialog table (map_sprites.asm CheckNPCInteraction) and pret's DisplayTextID case body is call CableClubNPC then AfterDisplayingTextID which this shim and .dialog_done reproduce; lifetime=permanent overworld dialog-dispatch projection}
; ---------------------------------------------------------------------------
CableClubReceptionistScript:
    call CableClubNPC
%ifdef DEBUG_CABLECLUB
    ; cable_club_nolink golden photograph: CableClubNPC has just returned from
    ; the no-peer path — the failure text's last page is still on screen and
    ; .didNotConnect's WRAM aftermath is latched (hSerialConnectionStatus $FF,
    ; wUnknownSerialCounter zeroed, wMenuJoypadPollCount zeroed). One DelayFrame
    ; lets the compositor draw the final reveal, then dump-and-exit.
    call DelayFrame
    call DumpBackbuffer                     ; FRAME.BIN + GBSTATE.BIN, then exits
%endif
    ret

; ===========================================================================
; # RunLinkCheck — %ifdef DEBUG_LINKCHECK two-instance harness driver.
; #
; # tools/linkcheck.sh runs two DOSBox-X instances joined by a nullmodem
; # cable, each booted with `PKMN.EXE /COM1 /LINKLOG` on this gate. The
; # harness seeds the pokédex event (the receptionist's gate) and then loops
; # the REAL CableClubNPC: with no peer yet, each attempt runs the faithful
; # 90-frame race into the "reserved for 2 friends" text and returns; once
; # both instances' races overlap, the net session synthesizes establishment
; # and CableClubNPC proceeds — save prompt (AUTOKEY_LINKCHECK's A train
; # answers YES), rendezvous, then LinkMenu, which parks awaiting input.
; # LinkMenu's entry sets linkcheck_in_menu (debug hook in link_menu.asm),
; # which STOPS the A train — an A in LinkMenu would select TRADE CENTER,
; # a Stage-3 flow. AutoKeyDrive photographs the parked menu at
; # AUTOKEY_DUMP_FRAME (GBSTATE + FRAME + LINKLOG.BIN), and linkcheck.sh
; # asserts the $02/$01 role split and the crossed exchange logs.
; #
; # The attempt bound only marks diagnostics (lcMarks in GBSTATE): after it,
; # the harness parks so the photograph still fires and shows the failure.
; ===========================================================================
%ifdef DEBUG_LINKCHECK
global RunLinkCheck
global linkcheck_marks
global linkcheck_in_menu

LINKCHECK_MAX_ATTEMPTS equ 40

section .bss
linkcheck_marks:                        ; GBSTATE flat region "lcMarks", 2 bytes
linkcheck_attempts: resb 1              ; CableClubNPC attempts used
linkcheck_in_menu:  resb 1              ; 1 = LinkMenu entered (set by its hook)

section .text
RunLinkCheck:
    SetEvent EVENT_GOT_POKEDEX          ; open the receptionist's gate
    mov byte [linkcheck_attempts], 0
.try:
    inc byte [linkcheck_attempts]
    mov byte [linkcheck_in_menu], 0     ; re-arm the A train per attempt
    call CableClubNPC                   ; parks in LinkMenu on success
    cmp byte [linkcheck_attempts], LINKCHECK_MAX_ATTEMPTS
    jb .try
.park:                                  ; gave up: hold still for the photograph
    call DelayFrame
    jmp .park
%endif

; ===========================================================================
; # RunTradeCheck — %ifdef DEBUG_TRADECHECK two-instance harness driver.
; #
; # tools/tradecheck.sh runs two DOSBox-X instances joined by a nullmodem
; # cable exactly like linkcheck.sh (a different default TCP port, 23457, so
; # the two harnesses can coexist), one plain and one with /PARTYB
; # (boot/entry.asm), both booted on this DEBUG_TRADECHECK build. The retry
; # loop below is RunLinkCheck's verbatim, same cross-instance boot-skew
; # rationale: the REAL CableClubNPC races up to TRADECHECK_MAX_ATTEMPTS times
; # until both instances' 90-frame establishment windows overlap.
; #
; # UNLIKE RunLinkCheck, a successful race is not parked here: selecting TRADE
; # CENTER in LinkMenu tail-jumps to SpecialEnterMap (link_menu.asm:1244,
; # `jmp SpecialEnterMap`) and never returns up this call chain, so once
; # AUTOKEY_TRADECHECK's A train lands its press on the parked LinkMenu — there
; # is no linkcheck-style A-suppression gate here, because the default cursor
; # item 0 already IS "TRADE CENTER" (link_menu.asm:1208-1218, wCurrentMenuItem
; # test == 0) — control leaves RunTradeCheck for good and the normal
; # OverworldLoop machinery drives the rest (the walk to the table, both trade
; # rounds) under its own per-frame DelayFrame pump like any other overworld
; # screen. `.park` below is reached only on total failure (no peer within
; # TRADECHECK_MAX_ATTEMPTS), matching RunLinkCheck's own give-up shape.
; ===========================================================================
%ifdef DEBUG_TRADECHECK
global RunTradeCheck
global tradecheck_marks

TRADECHECK_MAX_ATTEMPTS equ 40          ; same bound as LINKCHECK_MAX_ATTEMPTS

section .bss
tradecheck_attempts: resb 1             ; CableClubNPC attempts used (this harness only)
; GBSTATE flat region "tcMarks" (debug_dump.asm): round1_traded/round2_cancelled
; are the two DEBUG_TRADECHECK-gated mark stores in cable_club.asm
; (TradeCenter_Trade's .tradeCompleted and ReturnToCableClubRoom's entry);
; steps_taken is diagnostic-only bookkeeping written by AUTOKEY_TRADECHECK's
; own walk state machine (debug_dump.asm) and is not read by any
; tools/tradecheck.sh assertion.
tradecheck_marks:
tradecheck_round1_traded:    resb 1
tradecheck_round2_cancelled: resb 1
tradecheck_steps_taken:      resd 1
; +6: set by cable_club_link_down's DEBUG_TRADECHECK hook (cable_club.asm) the
; moment the link-death escape hatch fires. STICKY where wTradeCenterPointerTableIndex
; is not: after the hatch's title reset, tradecheck --kill's A keeps auto-pressing
; A and can start a NEW GAME whose WRAM init rewrites CC38-area variables before
; the dump frame — this flat .bss byte survives that, so the --kill assertion
; reads the hatch's firing, not whatever the post-reset game state left behind.
tradecheck_link_down_hatch:  resb 1

section .text
RunTradeCheck:
    SetEvent EVENT_GOT_POKEDEX          ; open the receptionist's gate
    mov byte [tradecheck_attempts], 0
.try:
    inc byte [tradecheck_attempts]
    call CableClubNPC                   ; success tail-jumps away for good; see header
    cmp byte [tradecheck_attempts], TRADECHECK_MAX_ATTEMPTS
    jb .try
.park:                                  ; gave up: hold still for the AUTOKEY_DUMP_FRAME photograph
    call DelayFrame
    jmp .park
%endif

; ===========================================================================
; # RunBattleCheck — %ifdef DEBUG_BATTLECHECK two-instance harness driver.
; #
; # tools/battlecheck.sh runs two DOSBox-X instances joined by a nullmodem
; # cable exactly like tradecheck.sh (a different default TCP port, 23458, so
; # all three harnesses can coexist), one plain and one with /PARTYB
; # (boot/entry.asm), both booted on this DEBUG_BATTLECHECK build. The retry
; # loop below is RunTradeCheck's / RunLinkCheck's verbatim, same cross-instance
; # boot-skew rationale: the REAL CableClubNPC races up to
; # BATTLECHECK_MAX_ATTEMPTS times until both instances' 90-frame establishment
; # windows overlap.
; #
; # UNLIKE RunLinkCheck, a successful race is not parked here. LinkMenu's
; # default cursor is item 0 = TRADE CENTER (link_menu.asm:1097); COLOSSEUM is
; # item 1, so AUTOKEY_BATTLECHECK's .apply block (debug_dump.asm) carries a
; # state-gated LinkMenu step: suppress A and strobe ONE DOWN while
; # wCurrentMenuItem != 1 — the same idiom as AUTOKEY_TRADECHECK's ROUND2
; # DOWN-to-CANCEL climb; see that block for the full walk/battle citation
; # trace. Selecting COLOSSEUM tail-jumps to SpecialEnterMap
; # (link_menu.asm:1244, `jmp SpecialEnterMap`) and never returns up this call
; # chain: control leaves RunBattleCheck for good and the normal OverworldLoop
; # machinery drives the rest (the walk to the table, the entire link battle —
; # which, per CableClub_DoBattleOrTradeAgain's battle branch
; # (engine/link/cable_club.asm), runs synchronously inside
; # `predef InitOpponent` before CableClub_Run's caller ever resumes) under its
; # own per-frame DelayFrame pump like any other overworld screen. `.park`
; # below is reached only on total failure (no peer within
; # BATTLECHECK_MAX_ATTEMPTS), matching RunTradeCheck's own give-up shape.
; ===========================================================================
%ifdef DEBUG_BATTLECHECK
global RunBattleCheck
global battlecheck_marks

BATTLECHECK_MAX_ATTEMPTS equ 40         ; same bound as LINKCHECK/TRADECHECK_MAX_ATTEMPTS

section .bss
battlecheck_attempts: resb 1            ; CableClubNPC attempts used (this harness only)
; GBSTATE flat region "bcMarks" (debug_dump.asm). battle_started is NOT stored
; here by any game-code site (spec Stage 4 step 3, deliverable 3d): it is set
; live from AUTOKEY_BATTLECHECK's .apply block (debug_dump.asm reads
; wIsInBattle/wLinkState every frame already), so no game-code store is
; needed for it. The other three fields ARE game-code-gated stores, capped at
; exactly the three sites the spec lists:
;   turn_count   — LinkBattleExchangeData's entry (core.asm)
;   battle_over/battle_result — EndOfBattle's LINK_STATE_BATTLING branch
;                  (end_of_battle.asm)
;   link_down_hatch — step 2's .linkDown hatch (core.asm)
battlecheck_marks:
battlecheck_battle_started:  resb 1     ; +0 — set ONLY by AUTOKEY_BATTLECHECK's .apply (debug_dump.asm)
battlecheck_battle_over:     resb 1     ; +1 — end_of_battle.asm's link-battle branch
battlecheck_turn_count:      resw 1     ; +2..3 — core.asm LinkBattleExchangeData entry (dw, incremented)
battlecheck_link_down_hatch: resb 1     ; +4 — core.asm's .linkDown hatch
battlecheck_battle_result:   resb 1     ; +5 — copy of wBattleResult at battle_over time

section .text
RunBattleCheck:
    SetEvent EVENT_GOT_POKEDEX          ; open the receptionist's gate
    mov byte [battlecheck_attempts], 0
.try:
    inc byte [battlecheck_attempts]
    call CableClubNPC                   ; success tail-jumps away for good; see header
    cmp byte [battlecheck_attempts], BATTLECHECK_MAX_ATTEMPTS
    jb .try
.park:                                  ; gave up: hold still for the AUTOKEY_DUMP_FRAME photograph
    call DelayFrame
    jmp .park
%endif

; ===========================================================================
; # RunLinkBookCheck — %ifdef DEBUG_LINKBOOKCHECK SINGLE-instance harness
; # driver (link cable plan Stage 5 step 5, Deliverable 2 — the linkbook
; # persistence scenario, `link_book_roundtrip` in tools/scenario_manifest.json).
; #
; # UNLIKE RunLinkCheck/RunTradeCheck/RunBattleCheck above, this is genuinely
; # single-instance: NO nullmodem cable, no peer, no CLI transport flag
; # (`/COM1` etc.) is ever passed. With g_net_transport left at its default
; # NET_TRANSPORT_NONE, CableClubNPC's LinkTransportSelect call (the
; # DEVIATION seam documented at CableClubNPC's .receivedPokedex above) does
; # NOT race an establishment window at all -- it opens the port-only
; # transport-select + connection-book UI (src/net/link_ui.asm) and blocks
; # there, which is exactly the surface this scenario exists to exercise. A
; # single CableClubNPC call is therefore enough: there is no partner to wait
; # for, so none of RunLinkCheck/RunTradeCheck/RunBattleCheck's retry-loop-
; # until-the-race-lands shape applies here.
; #
; # tools/linkbookcheck.sh drives the whole flow with TWO layers, both in
; # src/debug/debug_dump.asm's AutoKeyDrive:
; #   - pad-level menu navigation (%ifdef AUTOKEY_LINKBOOKCHECK /
; #     AUTOKEY_LINKBOOKCHECK_PHASE2): a phase-gated state machine reading
; #     wMaxMenuItem/wCurrentMenuItem/wMenuWatchedKeys to walk the transport
; #     menu -> book list -> (record menu, run2 only) -> YesNoChoice, the
; #     same "DOWN-strobe while not at target, else assert A" idiom
; #     RunTradeCheck/RunBattleCheck's own AUTOKEY blocks already use.
; #   - keyboard-level field typing (%ifdef AUTOKEY_KBDSCRIPT, shared with
; #     kbd_naming_entry's driver): a scripted (scancode,shift) table pushed
; #     one pair per frame into the SAME kbd_ring kbd_isr feeds, via the new
; #     port-only kbd_ring_push (src/input/joypad.asm) -- see that routine's
; #     header for why AUTOKEY (pad bits only) cannot reach the NAME?/
; #     ADDRESS? fields on its own.
; #
; # Two builds of this SAME gate exist (both DEBUG_LINKBOOKCHECK; the
; # PHASE2 sub-define picks which AUTOKEY navigation + kbdscript table is
; # compiled in -- see debug_dump.asm): run1 (fresh LINKBOOK.DAT) creates a
; # TCP and an IPX entry and cancels out; run2 (same image, LINKBOOK.DAT NOT
; # purged) EDITs the TCP entry's name and DELETEs the IPX entry. Marks land
; # in linkbookcheck_marks (below) for tools/linkbookcheck.sh to assert
; # against, per-phase, exactly like battlecheck_marks above.
; ===========================================================================
%ifdef DEBUG_LINKBOOKCHECK
global RunLinkBookCheck
global linkbookcheck_marks

; GBSTATE flat region "lbcMarks" (debug_dump.asm). Every byte here is a
; game-code-gated store from src/net/link_ui.asm's DEBUG_LINKBOOKCHECK hooks
; (LBC_* offsets defined there) -- none is written from the AUTOKEY driver
; itself, so a mark set is proof the real commit code path ran, not just
; that the harness's own navigation reached the right screen.
section .bss
align 4
linkbookcheck_marks:
lbc_tcp_new:      resb 1     ; +0 — run1: TCP NEW committed (LBC_TCP_NEW)
lbc_ipx_new:      resb 1     ; +1 — run1: IPX NEW committed (LBC_IPX_NEW)
lbc_tcp_edited:   resb 1     ; +2 — run2: TCP EDIT committed (LBC_TCP_EDITED)
lbc_ipx_deleted:  resb 1     ; +3 — run2: IPX DELETE committed (LBC_IPX_DELETED)
lbc_menu_opened:  resb 1     ; +4 — diagnostic: transport UI actually opened
lbc_cancelled:    resb 1     ; +5 — diagnostic: cancelled all the way out

section .text
RunLinkBookCheck:
    SetEvent EVENT_GOT_POKEDEX          ; open the receptionist's gate
    call CableClubNPC                   ; blocks in LinkTransportSelect's UI;
                                         ; returns once the player cancels all
                                         ; the way out, without binding a
                                         ; transport (the check builds the UI,
                                         ; not a session)
.park:                                  ; hold still for the AUTOKEY_DUMP_FRAME photograph
    call DelayFrame
    jmp .park
%endif
