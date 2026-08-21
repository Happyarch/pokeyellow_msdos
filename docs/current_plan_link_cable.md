# Current Plan: Link Cable (Phase 4 Network Multiplayer)

Created 2026-08-21 (planning session, branch `claude/link-cable-protocol-planning-s5d09u`).
This plan REOPENS the link layer: the 2026-08-17 "stays unwired" maintainer
directive is superseded by the maintainer's 2026-08-21 request to begin this
work. The two doc sites that recorded the directive are updated in the same
commit as this file; the stigmergy memory `link-layer-planned-transports` must
be rewritten from a host session (Stage 0 — remote sessions have no stigmergy).

Skills route: `asm-translation` + `faithfulness-review` for every pret mirror;
`project-conventions` for stubs/annotations/plan bookkeeping; `build-and-debug`
for harness work.

## Decisions (maintainer, 2026-08-21)

- **Peer scope: DOS port ↔ DOS port only.** No real-ROM/emulator peer, no real
  GB hardware peer. The wire framing below the HAL line is port-owned.
- **Transports, in build order: (1) null-modem COM UART — mandatory; (2) IPX;
  (3) native in-game TCP.** No separate UDP mode (IPX covers the
  datagram+reliability niche; DOSBox-X nullmodem/IPXNET already tunnel over
  host TCP/UDP for emulated setups).
- **Feature scope: both Trade Center and Colosseum link battles.**
- **Latency posture: the byte-level lockstep of the GB wire must NOT be
  replayed over the network** ("don't just replace link cable calls with
  network calls — janky online battles"). See "Message-level seam" below.
- **Init handshake carries a `game_gen` byte** — Gen I = $01. Boolean
  semantics today (Gen I vs the planned Gen II port), a full byte reserved
  for future maintainer use.
- **Packet-loss handling is required** — reliability layer + desync detection,
  not best-effort.
- **Printer and link keep separate forks of the pret serial functions.**
  Verified compatible: the printer plan cuts inside the printer engine
  (`Printer_PrepareToSend` → in-memory device; `docs/current_plan_printer.md`
  "The seam") and does no `home/serial.asm`/rSB/rSC work, so
  `dos_port/src/home/serial.asm` belongs to the link layer alone. Pret
  `Serial`'s `wPrinterConnectionOpen` branch is retained as a documented dead
  branch; the net pump asserts printer and link are never simultaneously
  active.

## Transport rationale (recorded so it is not re-litigated)

| Transport | Why | Where it runs |
|---|---|---|
| COM UART null modem (8250/16550, `/COM1-4`, 115200 8N1, `/BAUD=` fallback for plain 8250) | Most authentic; mandatory. DOSBox-X `serial1=nullmodem` carries the emulated UART over host TCP → internet play between two DOSBox-X instances with zero in-game net code. | Real hardware + DOSBox-X |
| IPX (INT 7Ah / far entry via DPMI real-mode translation, ECBs in DOS conventional memory, polled — no ESR callbacks) | Classic DOS LAN layer; DOSBox-X emulates it natively (`ipx=true`, IPXNET) with no packet driver; real DOS via the Novell stack. Broadcast peer discovery for free. Needs the shared ARQ layer (datagrams drop). | DOSBox-X natively + real LAN |
| Native TCP — minimal NASM stack: packet driver (INT 60h-80h scan) + ARP + IPv4 + single-connection stop-and-wait TCP | Maintainer wants native in-game TCP. **WATT-32 rejected**: it assumes DJGPP crt0/libc and the port links neither (`i386-pc-msdosdjgpp-ld -T link.ld`, pure NASM, custom entry in `boot/entry.asm`) — a 100+-symbol libc shim for the least-critical transport is the wrong trade. Our traffic is one-outstanding-message, so a stop-and-wait TCP subset is small and RFC-793-conservative. Fallback if it fails soak (maintainer ruling required to invoke): UDP + the shared ARQ layer. | Real DOS w/ packet driver; DOSBox-X via NE2000+slirp |

## Architecture — message-level seam

**Rejected:** a byte-level virtual cable (one network round trip per GB byte
exchange). The party-block exchange is 641 bytes ⇒ 641 RTTs (~32 s at 50 ms
internet latency), and every battle turn would stall per byte.

**Adopted:** the HAL cut line is the *bodies of the serial exchange
primitives* in `home/serial.asm`. Each keeps pret's register/WRAM/HRAM
contract, role semantics and timeout behavior, but the wire carries **one
reliable message per semantic exchange**:

| pret primitive | wire cost |
|---|---|
| `Serial_ExchangeBytes` (17 / 424 / 200-byte blocks) | 1 message each way per block |
| `Serial_SyncAndExchangeNybble` / `Serial_ExchangeNybble` | 1 message each way per rendezvous |
| `Serial_ExchangeLinkMenuSelection` | 1 message each way |
| `Serial_ExchangeByte` (direct caller: Yellow cup-select `$C0` handshake in `Func_f531b`) | 1 message each way |

A link battle turn = one RTT. All pacing runs locally — pret already
guarantees frame-count symmetry in link mode (`ManualTextScroll` → fixed
65-frame delay; the trade animation is serial-silent), and the 10+10-frame
drain loops in the nybble rendezvous are kept as *local* delays so game feel
matches the GB without generating wire traffic.

Everything **above** the primitives is translated verbatim: all of
`engine/link/cable_club.asm` ($FD preambles, $FE patch lists, RNG-list
selection with the master authoritative, trade state machines),
`cable_club_npc.asm` structure and timeouts, `LinkBattleExchangeData`, and
every `wLinkState == LINK_STATE_BATTLING` divergence site in battle core. The
patch-list machinery is semantically redundant over framed transport but
costs nothing and keeps `cable_club.asm` fully faithful — blocks cross the
wire patched and unpatch runs as in pret. Each diverging primitive carries
`DEVIATION{class=HAL}`; time-calibrated waits carry `class=timing`.

### Layout (audio-HAL template; `mpu401.asm` is the driver precedent)

```
dos_port/src/net/            new subsystem — Makefile var NET_SRCS
  net_hal.asm      session state, role election, exchange mailboxes,
                   NetHAL_Pump (hooked in DelayFrame beside audio_tick AND
                   polled inside the primitives' wait loops), transport
                   vtable, /COMx //IPX //TCP flags, disconnect escape hatch
  net_frame.asm    frame codec (magic, type, session-id, seq16, exch-id,
                   len, CRC) + stop-and-wait ARQ (retransmit, dedupe,
                   keepalive) — engaged on UART+IPX, bypassed on TCP
  com_uart.asm     8250/16550: IRQ4/IRQ3 RX-ring ISR (DPMI 0204h/0205h
                   install, [cs:isr_ds], manual EOI — joypad.asm pattern),
                   polled THRE TX with bounded waits (mpu401 pattern)
  ipx_dos.asm      IPX detect/socket/ECB poll via DPMI 0100h + 0300h/0301h
  pktdrv.asm       packet-driver binding; RX via DPMI 0303h real-mode
                   callback (new pattern for this repo — document it)
  net_ip.asm       ARP + IPv4 + minimal TCP (Stage 6)
dos_port/src/home/serial.asm                  pret mirror; primitives = HAL line
dos_port/src/engine/link/cable_club_npc.asm   faithful
dos_port/src/engine/link/cable_club.asm       completed to all 23 pret labels
dos_port/src/engine/movie/trade.asm           trade animation (local-only)
```

The Makefile var must NOT be named `LINK_SRCS` — that already means "linker
sources" (Makefile:2949). Standard `.text/.data/.bss` only ⇒ no `link.ld`
change (say so in the commit message so nobody "fixes" it). CLI flags parse in
`boot/entry.asm:parse_cmdline` beside `/NOSOUND`.

### Session protocol (port-owned, below the line)

1. **HELLO / HELLO_ACK** at transport connect:
   `{proto_ver, rom_build_id, game_gen, token32}`.
   `game_gen` = $01 (Gen I) — full byte, stored in `g_peer_game_gen`; v1
   requires $01 and routes mismatch to pret's no-partner timeout path.
   Version/build mismatch → refuse; peer sees pret's no-partner behavior.
2. **Role election**: higher token32 (re-rolled on tie) becomes the GB
   master; the result is written into `hSerialConnectionStatus` as pret's own
   constants ($02 internal / $01 external), so every downstream tie-break —
   menu conflict, RNG-list ownership, warp side, trade-anim variant, speed
   ties — falls out of untouched pret code. `CableClubNPC`'s 90-frame race
   loop keeps its structure and timeout; its rSB/rSC sites become HAL calls
   reporting election state.
3. **EXCH messages** carry `{exch_id (monotonic), payload}`; both sides must
   present matching exch_ids — a mismatch is a *detected* protocol desync and
   forces the link-error path instead of silent divergence.
4. **Packet-loss / desync prevention**: CRC + seq16 ARQ with retransmit and
   dedupe on UART/IPX (TCP natively reliable); KEEPALIVEs; the exch-id
   lockstep check; `/LINKLOG` dumps each side's exchange stream
   (`LINKLOG.BIN`) and the harness asserts A.sent == B.recv both ways.
5. **Disconnect escape hatch** (pret spins forever post-club — a new
   `DEVIATION{class=HAL}`): transport death (keepalive misses / ARQ
   exhaustion / TCP reset) forces `wUnknownSerialCounter*` to expiry so
   pret's own timeout text fires where it exists; where none exists, a
   hold-B abort routes into `CloseLinkConnection` + link-error text.

## Stages

### Stage 0 — governance + groundwork
- [ ] Directive doc sites updated (done in this plan's landing commit):
      `docs/current_plan_overworld_events.md`, `docs/current_plan_printer.md`
- [ ] HOST SESSION: rewrite stigmergy `link-layer-planned-transports` to the
      reopened state + these transport decisions; run
      `memory_search regression link` / `regression serial` and fold findings
      back into this plan
- [ ] Verify + close backlog #17 (cable-club warp seam — appears already
      root-wired: `SpecialEnterMap` honors `wEnteringCableClub`,
      `PrepareForSpecialWarp` stub retired); cite `label_status --callers`
- [ ] `gb_memmap.inc`: add missing serial defines (`hSerialReceivedNewData`,
      `hSerialIgnoringInitialData`, `wUnknownSerialCounter2`, nybble temp —
      audit the block for gaps); `check_ram_collisions.py` + `audit_memmap.py`
      clean (NEVER assert an address free — derive it)
- [ ] Makefile `NET_SRCS` bucket wired into the link aggregate; note "no
      link.ld change — standard sections"
- [ ] Generated-strings audit for cable-club/link texts (two-tier rule;
      needs the `unicode_converter` submodule)

### Stage 1 — serial core + no-transport parity
- [ ] `net_hal.asm` skeleton: session state, mailboxes, pump + reentrancy
      guard, transport vtable with a null transport; pump hook in `DelayFrame`
      beside `audio_tick`
- [ ] Translate `src/home/serial.asm` (all labels; exchange primitives as the
      HAL line with `DEVIATION{class=HAL}` each; watchdog counters verbatim;
      spins time-calibrated with `class=timing`); **delete
      `src/home/serial_stubs.asm`** (loud-collision rule) and sweep the 15
      `TODO-HW: network HAL` sites in `link_menu.asm`; repoint extern comments
      per stub-retirement rule 5; `update_label_db`
- [ ] Gates: faithdiff per label, lint 0, `make fidelity` core+full (zero
      single-player drift); new `cable_club_nolink` golden vs mGBA (no-peer
      receptionist timeout is mGBA-comparable); re-verify LinkMenu /
      `Func_f531b` no-partner termination against real watchdog wall time

### Stage 2 — UART transport + handshake
- [ ] `net_frame.asm` codec + ARQ, with a DEBUG-only RAM-pipe transport unit
      test (injected drops/corruption); game-level loopback rejected (breaks
      role asymmetry)
- [ ] `com_uart.asm` (`/COM1-4`, `/BAUD=`, FIFO detect, IRQ RX ring, polled TX)
- [ ] Translate `cable_club_npc.asm` (retire the `CableClubNPC` stub in
      `main_menu_stubs.asm`); HELLO election incl. `game_gen`; drop the
      `DEBUG_I1_LINK` build gate
- [ ] `tools/linkcheck.sh` two-instance harness: per-instance `PKMN.IMG`
      clones (`run_headless.sh` pattern — sidesteps `dos_port/run`'s fuser
      lock), confs derived from the tracked transport-less `dosbox-x.conf`,
      nullmodem server/client pair; scenario: both instances reach the link
      menu with consistent master/slave roles; `/LINKLOG` cross-check green

### Stage 3 — Trade Center
- [ ] Complete `src/engine/link/cable_club.asm` to all 23 labels
      (`CableClub_DoBattleOrTrade[Again]` block build/patch/exchange/unpatch,
      RNG list, `TradeCenter_SelectMon`/`TradeCenter_Trade`, `CableClub_Run`
      + its `WaitForTextScrollButtonPress` poll hook)
- [ ] Translate `engine/movie/trade.asm` (retire the core_stubs trade-anim
      stubs)
- [ ] Two-instance scripted trade: `.dsv` postconditions (byte-identical
      44-byte structs incl. offset 7 per the Gen-2 rule, OT/ID swap, party
      counts), cancel ($F) and re-trade paths
- [ ] Disconnect escape hatch + mid-trade kill test

### Stage 4 — Colosseum link battle
- [ ] Divergence-site audit: enumerate every pret
      `wLinkState == LINK_STATE_BATTLING` site (~25) vs the ported battle
      core; classify translated / missing / stubbed; fix gaps (items ban, no
      EXP, no badge boosts, 65-frame `ManualTextScroll`, enemy data from the
      received block, forced link transition + versus text box)
- [ ] Real `LinkBattleExchangeData` (retire the battle_stubs entry): action
      nybbles, local drain pacing, shared 10-byte RNG list (master
      authoritative, x=5x+1 reseed), speed-tie inversion
- [ ] Two-instance battle to a consistent result on both sides;
      run/struggle/no-action paths; mid-battle disconnect

### Stage 5 — IPX
- [ ] `ipx_dos.asm` (detect, socket `/IPXSOCK=`, DOS-memory ECBs, poll loop,
      broadcast discovery); linkcheck IPXNET variant; rerun the Stage 3/4
      scenario battery

### Stage 6 — native TCP
- [ ] Slirp reachability spike FIRST (two NE2000+slirp guests are NATed
      apart — host port-forward topology; pcap fallback documented); gates
      the rest of the stage
- [ ] `pktdrv.asm` (DPMI 0303h real-mode RX callback — new pattern,
      document it) + `net_ip.asm` (ARP, IPv4, minimal stop-and-wait TCP);
      flags `/TCPWAIT[=port]`, `/TCP=ip[:port]`, `/IP= /MASK= /GW=`
      (no DHCP in v1 — recorded as deferred); linkcheck NE2000 variant;
      rerun battery

### Stage 7 — hardening + bookkeeping
- [ ] Soak: repeated trades/battles per transport, injected drops,
      pause/resume one instance; keepalive tuning
- [ ] Docs sweep (`dos_port/run` header flags, ROADMAP Phase 4,
      evidence-discipline wording: "verified under two-instance DOSBox-X",
      never "works on real hardware"); `update_label_db`
- [ ] HOST SESSION: stigmergy final state + `episode_record`
- [ ] Archive: `git mv docs/current_plan_link_cable.md docs/plans/link_cable.md`

## Acceptance (ROADMAP Phase 4)

One trade and one battle completed over each of the three transports under
the two-instance harness; all fidelity gates green; no single-player
regression in `make fidelity` core+full; real-hardware paths (UART on a
physical null modem cable, Novell IPX, packet-driver TCP) ship
spec-conformant with runtime escape hatches — the printer-backend precedent
for unverifiable hardware.

## Risks / open questions

1. TCP fallback ruling (UDP + shared ARQ) — only if the minimal TCP subset
   fails soak; maintainer decision.
2. `game_gen` mismatch behavior once a Gen II peer exists (refuse vs
   Time-Capsule-style limited mode) — deferred; byte reserved now.
3. Watchdog wall-time calibration retires the stub-era timing that any
   DEBUG_I1_LINK-tuned expectations relied on — those move to true pret
   no-partner behavior.
4. Two-slirp TCP reachability under DOSBox-X (Stage 6 spike; pcap fallback
   needs privileges).

## Environment notes for implementation sessions

- Submodules must be initialized (`git submodule update --init`) at least for
  `dos_port/tools/dosbox-x` (serial/IPX/NE2000 testing), `unicode_converter`
  (text generators) and `mgba` (goldens). The Happyarch fork submodule URLs
  are SSH (`git@github.com:…`) — remote/CI sessions may need an https URL
  rewrite.
- Stigmergy is unavailable in remote sessions; all memory/episode items above
  are marked HOST SESSION.
