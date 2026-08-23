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
- **In-game link setup UI (maintainer requirement, 2026-08-21):** the player
  must be able to select serial vs IPX vs TCP in-game and type addresses for
  IPX and TCP, with **up to five saved TCP and five saved IPX connections —
  each user-nameable, editable and deletable — plus a DIRECT connect option**
  for one-off connections to no saved profile (maintainer, 2026-08-21).
  CLI flags remain as the non-interactive path (harness/scripting) and skip
  the UI. See "Link setup UI + connection book" below.
- **Keyboard naming screen as a BUILD option (maintainer requirement,
  2026-08-21):** `make KBD_NAMING=1` converts the game's name-entry UI
  (player/rival/nickname, `DisplayNamingScreen`) to direct keyboard typing;
  a dedicated key opens a small on-screen picker showing ONLY the
  game-specific characters a US keyboard cannot type. Default build (flag
  off/0) keeps the faithful on-screen grid. See "Keyboard naming screen"
  under the UI section.
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

### Remote-play trade audio — investigated, NO provision needed (2026-08-22)

Raised as a possible edge case (a cross-GB "duet" during the trade sequence
that remote IPX/TCP players would each half-hear), investigated same day,
and RESOLVED AS A NON-ISSUE (maintainer, 2026-08-22) — recorded so it is not
re-litigated:

- The trade sequence's music is one complete track played in full on EACH
  machine: `engine/link/cable_club.asm:836-840` starts `MUSIC_SAFARI_ZONE`
  (the track unused in the Safari Zone itself — the same music the evolution
  scene uses) locally on both sides. No channel partitioning.
- The Cable Club map music is likewise identical both sides
  (`data/maps/songs.asm`: TRADE_CENTER and COLOSSEUM both `MUSIC_CELADON`),
  and nothing under pret `audio/` reads `hSerialConnectionStatus`.
- The only per-side asymmetry is the role-MIRRORED trade animations
  (`InternalClockTradeAnim` / `ExternalClockTradeAnim`) playing their own
  SFX/cries at their own animation points — which is a complete, coherent
  soundscape for each player standalone, so remote play loses nothing a
  player would miss. Battles have no per-side audio asymmetry at all.

No extended APU, second channel bank, or peer-cue scheduling is required.
If a genuinely channel-partitioned piece is ever identified, the fallback
sketch lives in this section's git history (c86733f).

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

### Link setup UI + connection book (port-only)

No pret counterpart — descriptive names, no pret labels absorbed. Lives in
the net subsystem (`src/net/link_ui.asm`, `src/net/link_book.asm`) so the
whole feature stays greppable in one place.

- **Entry point — the receptionist flow.** `CableClubNPC` gains one
  port-only seam after the receptionist dialog and before the connection
  attempt: if no transport was preselected on the command line, show
  "HOW WILL YOU LINK?" — SERIAL / IPX / TCP / CANCEL (SERIAL offers a
  COM1-4 pick, default COM1). Only after the transport is up does pret's
  90-frame establish loop run, reading HELLO-election state as before.
  CANCEL falls into pret's no-partner path. One `DEVIATION{class=HAL}` at
  the seam. CLI flags (`/COM1-4`, `/IPX[...]`, `/TCP=`, `/TCPWAIT`)
  preselect and skip the UI entirely — required by the headless
  two-instance harness, which cannot drive interactive setup.
- **Connection book — 5 TCP + 5 IPX slots, nameable (maintainer,
  2026-08-21).** Choosing IPX or TCP opens the book for that transport:
  - **DIRECT** — type an address and connect without touching the book
    (for one-off connections to no saved profile);
  - **AUTO** (IPX only) — broadcast discovery, the IPX default;
  - the saved entries, **shown by their user-typed name** (label entered
    through the same keyboard widget; address shown alongside/on select);
    selecting one opens **CONNECT / EDIT / DELETE / CANCEL** — EDIT reopens
    name+address for retyping, DELETE frees the slot (confirm prompt);
  - **NEW** — enter name + address into a free slot (grayed/absent at 5/5).
- **Address entry is keyboard text input, not a GB character grid.** This
  is DOS: every machine has the keyboard the port already owns (IRQ1). A
  port-only line-edit widget reads raw scancodes through a text-entry mode
  added beside the existing joypad scancode path (`src/input/joypad.asm`),
  rendered with `TextBoxBorder`/`PlaceString`. Charset is restricted per
  field: TCP = dotted quad + `:port`; IPX = 8 hex net digits + 12 hex node
  digits (AUTO covers the common case so hand-typed IPX addresses are the
  exception). Input validated on accept; invalid → error text, re-edit.
- **Persistence: `LINKBOOK.DAT`, a separate port-only DOS file — NOT the
  `.dsv`.** The save file is byte-for-byte the raw 32 KiB SRAM image (v2),
  and the Gen-1/Gen-2 byte-identity rule forbids smuggling port config into
  GB SRAM. Same int 21h file-I/O pattern as `src/save/dsv_io.asm`: magic
  `LNKB`, version byte, additive checksum, then 10 fixed-size records —
  in-use flag, **16-byte charmap-encoded name** (typed via the keyboard
  widget, game charset incl. picker chars), and the address payload
  (TCP: ip4+port2; IPX: net4+node6), padded to one fixed record size for
  both types. Corrupt/absent file = empty book, never an error.
  `saveconv.py` untouched — this file is not save data.
- **Strings are Tier-1 data**: every label ("HOW WILL YOU LINK?", "SERIAL",
  "IPX", "TCP", "AUTO", "NEW", …) comes from a new
  `tools/generators/gen_link_ui_strings.py` → `assets/link_ui_strings.inc`,
  wired into `make assets`. No hand-encoded charmap bytes.
- **Harness note**: scenarios drive the UI via AutoKeyDrive where the UI
  itself is under test; everything else uses the CLI-flag bypass.

### Keyboard naming screen (build option `KBD_NAMING=1`)

Rides on the same Stage-5 text-entry infrastructure (scancode text mode +
line-edit widget). Build plumbing mirrors `BUG_FIX_LEVEL`: `KBD_NAMING ?= 0`
in the Makefile, `-D KBD_NAMING=$(KBD_NAMING)` in `NASMFLAGS`, `%if`-guarded
blocks in `src/engine/menus/naming_screen.asm`.

- **Flag on**: `DisplayNamingScreen` accepts typed input directly — any
  Gen-1 name-charset character a US keyboard produces (letters with Shift
  for case, digits/punctuation where the charset has them), Backspace
  deletes, Enter confirms (pret END semantics), pret length limits
  unchanged. The letter grid is not drawn.
- **Special-char picker**: one dedicated key (F2 unless implementation
  finds a conflict) opens a compact on-screen picker listing ONLY the
  game-specific characters not typable on a US keyboard (♂ ♀ é × PK MN …),
  arrows + Enter to insert, Esc to close. The picker's character list and
  the scancode→charmap table are both **generated** — derived from pret's
  naming-screen charset minus the typable mapping by a
  `gen_kbd_naming.py` generator into `assets/` (two-tier rule: these are
  data, and deriving the "special" set at generation time means it cannot
  drift from the charset).
- **Fidelity**: flag off is the faithful default — goldens and
  `make fidelity` run it. Flag on is a sanctioned divergence: one
  `DEVIATION{class=projection}` on the naming screen with the `%if` blocks,
  covered by a port-only AutoKeyDrive scenario on a `KBD_NAMING=1` build
  (type a name including one picker character; assert the resulting name
  bytes in a dump).

## Stages

### Stage 0 — governance + groundwork
- [x] Directive doc sites updated (done in this plan's landing commit):
      `docs/current_plan_overworld_events.md`, `docs/current_plan_printer.md`
- [ ] HOST SESSION: apply the stigmergy edits queued in
      `docs/stigmergy_outbox.jsonl` (the `link-layer-planned-transports`
      rewrite, the regression memory_search fold-back, and the Stage 2
      episode_record — full args are in the file, replay them verbatim and
      delete each line in the applying commit). This item closes when the
      outbox holds only its README line (2026-08-21/22 remote sessions could
      not do this — stigmergy is host-only)
- [x] Verify + close backlog #17 (2026-08-21): root-wired — `SpecialEnterMap`
      honors `wEnteringCableClub` (`main_menu.asm:426-431`),
      `PrepareForSpecialWarp` translated (`special_warps.asm:73`, stub retired
      per `main_menu_stubs.asm:27`; `label_status --callers` = 5 callers incl.
      LinkMenu). Closure written into `docs/current_plan_backlog.md` #17
- [x] `gb_memmap.inc` serial defines added 2026-08-21: `hSerialReceivedNewData`
      $FFA9, `hSerialIgnoringInitialData` $FFAB (contiguous pret HRAM block),
      `wSerialExchangeNybbleTempReceiveData` $D78B (pret union),
      `wLinkTimeoutCounter` $D795 (pret same-byte declaration),
      `wUnknownSerialCounter2` $DE41 (pret union w/ Bide),
      `wPrinterConnectionOpen` $E267 (contiguous run E265-E269);
      `check_ram_collisions` + `check_ram_addresses` + `audit_memmap` +
      `check_ram_straddle` all clean
- [x] Makefile `NET_SRCS` bucket (empty, beside HAL_SRCS) wired into the
      `LINK_SRCS` aggregate 2026-08-21; no link.ld change — standard sections
- [x] Generated-strings audit 2026-08-21: `assets/link_text.inc` already
      carries all link_menu + Colosseum/TradeCenter streams; one gap found —
      pret `WaitingText` (`engine/link/print_waiting_text.asm`) had no
      generator. Added to `gen_menu_strings.py` LINK_STRINGS → link_text.inc
      (global, for the Stage-1 `PrintWaitingText` mirror)

### Stage 1 — serial core + no-transport parity
- [x] `net_hal.asm` skeleton 2026-08-21 (`src/net/net_hal.asm`): session state
      (`g_net_transport`/`g_net_link_up`/`g_peer_game_gen`), pump + reentrancy
      guard, `NetHAL_LinkAlive`, `NetHAL_StartTransfer`, transport vtable with
      the null transport row; pump hooked in `DelayFrame` beside `audio_tick`
      (inside `PERF_AUDIO`'s slot — one compare per frame while unbound).
      Exchange mailboxes deferred to Stage 2 with the frame codec that defines
      their shape
- [x] `src/home/serial.asm` translated 2026-08-21 — all 13 pret labels;
      primitives cut at the HAL line, each no-partner escape hatch carries a
      `DEVIATION{class=HAL}` reproducing the retired stub contract verbatim
      (the faithful bodies' own loops have no exit with no partner — measured
      against the pret flow, see the file header); watchdogs verbatim; the
      `Serial` handler's rDIV wait is a `class=timing` deviation (rDIV inert);
      `serial_stubs.asm` DELETED; the 15 `TODO-HW: network HAL` sites in
      `link_menu.asm` swept (incl. restoring the `.doneChoosingMenuSelection`
      rSC write as IO_SC + `NetHAL_StartTransfer`); extern comments repointed
      (link_menu, printer.asm header, 13 Pokecenter scripts); NEW stubs per
      convention: `CloseLinkConnection` + `PrintWaitingText` →
      `src/engine/link/link_stubs.asm` (their pret sources are Stage 2/3
      files; PrintWaitingText's real mirror needs the trade-screen projection
      decided in Stage 3), `PrinterSerial` → `printer_stubs.asm` (retained
      dead branch); `update_label_db` rescanned
- [x] Gates: faithdiff per label run 2026-08-21 (all findings are the
      annotated HAL boundary: NetHAL_* calls, virtual IO_SB/IO_SC stores, and
      faithdiff's documented pointer-indirect-store blind spot on
      wUnknownSerialCounter / the receive buffers); lint 0 in both modes;
      full build links; `fidelity-serial` core tier 16/16 PASS 2026-08-21
      AND `fidelity-full-serial` 87/87 PASS 2026-08-22 (zero single-player
      drift with the DelayFrame pump call in place; both run AFTER fixing
      the VM's silent sfdisk/MBR image-mount failure — see Environment
      notes); DEBUG_I1 + DEBUG_I1_LINK harness photos verified
      2026-08-21 (both menus draw correctly and FRAME.BIN lands at frame 90,
      so DelayFrame + pump kept 90 frames advancing with the real serial
      layer linked — the AUTOKEY_QUIET harness parks in HandleMenuInput
      before any exchange call, so the hatch VALUES are covered by the
      construction argument in serial.asm's header plus the fidelity tiers,
      not by these photos). Checked off 2026-08-22 with the full tier green;
      the one deferred item: the `cable_club_nolink` golden — it
      compares the RECEPTIONIST's 90-frame no-peer timeout, which is
      `CableClubNPC`'s loop, still a ret-stub until Stage 2 translates
      cable_club_npc.asm; the golden therefore LANDS WITH STAGE 2, not here
      (recorded 2026-08-21 — Stage 1 sequenced it optimistically; landed
      2026-08-22, see the Stage 2 `cable_club_nolink` entry)

### Stage 2 — UART transport + handshake
- [x] `net_frame.asm` codec + ARQ landed 2026-08-22 (`7847346`), proven by the
      DEBUG_NETTEST RAM-pipe test: 5 phases (clean / drop-every-17th /
      corrupt-every-19th / idle-keepalive / dead-pipe), 60/60 both ways,
      PASS=1 — and it caught a real bug (nf_crc_init clobbered ECX/EDX on
      first use, poisoning the stored retransmit frame's CRC); game-level
      loopback rejected (breaks role asymmetry)
- [x] `com_uart.asm` + CLI flags + session core landed 2026-08-22 (`2a29f82`);
      two REAL bugs found and fixed by the linkcheck harness (step 5 below):
      (1) IRQ edge-loss at init — the staggered second instance boots into
      the first one's HELLO retransmissions, so a byte already in the RBR
      when IER goes live holds INTR high and the edge-triggered 8259 never
      fires; fixed with a post-IER drain (RBR+LSR+IIR) plus a CLI-guarded
      direct-port polling fallback in ComUart_RxByte; (2) the master's
      first kick OVERTOOK its own pump-queued ESTABLISH_REQ (kicks send
      synchronously from StartTransfer), reaching the peer while still
      NS_UP where the EXCH was codec-acked but semantically dropped, never
      resent, wedging net_kick_open for the whole session — fixed by
      holding kicks while net_estab_pend is set
- [x] `cable_club_npc.asm` translated 2026-08-22 (all pret labels + the
      seven receptionist texts via the new `LINK_NPC_FAR` generator list ->
      `assets/link_npc_text.inc`; `collect_far` learned to strip VC
      scaffolding); `CableClubNPC` + `CloseLinkConnection` stubs retired;
      HELLO election incl. `game_gen` landed in step 2's session core.
      RECEPTIONIST WIRING (found in planning: stub retirement alone was not
      enough — the NPC-talk path never dispatched TX_SCRIPT ids): all 13
      `<Map>LinkReceptionistText` ids route via `gen_npc_dialogs.py`
      `SCRIPT_OVERRIDES` to the port-only `CableClubReceptionistScript`
      shim running pret's DisplayTextID $f6 body. The `DEBUG_I1_LINK` gate
      is KEPT as a photography harness (no longer the only reachability —
      that is what this line originally meant to drop); LinkMenu's Stage-1
      status pin moved into that harness. Two smoke notes for the golden
      (step 4): a debug indoor spawn renders with a WHITE DAC (deferred
      fade/palette path — tilemap content is fine, so compare tilemap/WRAM,
      not pixels), and PrintText dialog lands in the WINDOW scratch, not
      wTileMap — pick the compared surface accordingly
- [x] `tools/linkcheck.sh` two-instance harness — GREEN 2026-08-22 (lc5-lc7):
      establishment, $02/$01 role split, LINKLOG cross-check both ways, zero
      desyncs, session alive at both dumps, through a 15 s and a 30 s parked
      LinkMenu (the park is exchange-heavy — pret's selection loop exchanges
      continuously, ~40 msg/s). THE 2026-08-22 STALL WAS NEVER THE EMULATOR:
      byte counters on both sides of the fork's nullmodem (NMDBG heartbeat)
      showed flushed==delivered in lockstep every second of every failing run,
      and the DOSBox `rx_interrupt_threshold` suspect below is exonerated (the
      guest read LSR DR=0 — bytes never reached the fifo because they were
      never sent). Root cause was GUEST-side: NetFrame_Tick counted its ARQ
      timers per PUMP CALL, and the pump runs 100-1000x frame rate inside
      wait loops, so NF_DEATH_TICKS=600 collapsed from ~10 s wall to ~1 s —
      inside the peer's 1/s keepalive gap; one side died between keepalives
      and its silence killed the other (the "UART stall" was the post-death
      ring backlog, a symptom). Fixed in `3222bbd`: timers now advance by
      elapsed frames of the 60 Hz PIT `tick_count` read through the
      `nf_clock` pointer (DEBUG_NETTEST repoints it at its iteration counter;
      battery still 60/60 PASS). Second, separate failure after that fix:
      the boot-relative AUTOKEY_DUMP_FRAME photograph — the instances boot
      seconds apart, the first dumper exits, and the survivor's park sits
      peer-less >10 s so its CORRECT no-peer death latches before its own
      dump (nfDiag forensics: latch−reset = exactly 600 frames). Fixed by
      photographing LINKCHECK_MENU_HOLD (default 900) frames after
      linkcheck_in_menu — LinkMenu entry is a wire-synchronized rendezvous,
      so both dumps land within an exchange RTT; AUTOKEY_DUMP_FRAME stays
      the ceiling for runs that never reach the menu. The fork's NMDBG
      1 Hz nullmodem heartbeat (rx_state/gather-buffer/byte counters) is
      kept for future transport debugging — Stage 3 blocks and the IPX/TCP
      transports will want it. The instrumentation is committed on the
      fork's `mcp-debug` branch (`0eff618fd`, pushed to Happyarch/dosbox-x
      2026-08-22 with maintainer authorization — it began as a local-only
      diff) and the submodule pointer here tracks it, so a fresh clone can
      rebuild the C_MODEM fork with `tools/build_dosbox_mcp.sh` and run
      linkcheck anywhere. Independently re-verified 2026-08-22 (second
      session):
      3/3 consecutive linkcheck.sh runs green (662/663/662 LINKLOG records,
      both directions matching, zero desyncs, both sides in LinkMenu and
      NS_ESTABLISHED at dump)
      Harness inventory: the `DEBUG_LINKCHECK` gate (`RunLinkCheck` loops the
      real `CableClubNPC`; `AUTOKEY_LINKCHECK`'s A train answers the prompts
      and stops at LinkMenu entry via the `linkcheck_in_menu` hook), the
      `/LINKLOG` ring (`net_hal.asm`, records real EXCH bytes only) +
      `LINKLOG.BIN` dump (`DumpLinkLog`, debug_dump.asm, photograph path),
      and the GBSTATE probe regions (linkStatus/netRole/netState/desyncs/
      lcMarks + diagnostic ncbState/netEstab/netExchCtr/netPumps/uartDiag/
      nfDiag). Env knobs: LINKCHECK_PORT/LINKCHECK_DUMP_FRAME/RUN_TIMEOUT/
      LINKCHECK_STAGGER; needs the C_MODEM fork binary at
      `tools/dosbox-x-mcp/dosbox-x-mcp` (build_dosbox_mcp.sh — the system
      dosbox-x lacks nullmodem). An earlier draft of this entry blamed a
      DOSBox `rx_interrupt_threshold` edge; that suspicion is DISPROVEN
      (see the GREEN paragraph above) — do not re-investigate it
- [x] `cable_club_nolink` golden landed 2026-08-22 (id 91, tier full) — the
      Stage-1 deferred item. Talks to the PEWTER_POKECENTER link
      receptionist (player seeded at (3,11) facing UP, EVENT_GOT_POKEDEX
      set) with no peer, on both sides through the real A-press dispatch:
      port `DEBUG_CABLECLUB` gate falls through into OverworldLoop and
      AUTOKEY_APRESS drives IsSpriteOrSignInFrontOfPlayer ->
      CheckNPCInteraction -> generated SCRIPT entry ->
      CableClubReceptionistScript -> CableClubNPC; the mGBA side
      (cable_club_nolink.lua) script-warps in and presses the same A.
      CableClubNPC's 90-frame race expires into the two-page failure text
      (both `cont` waits answered by A on both sides) and the shim's
      DEBUG_CABLECLUB hook photographs the moment CableClubNPC returns.
      Golden verified by decomposition (linkStatus $FF, linkTimeout 0,
      serialCounter 0, menuPollCount 0, map $3A at (3,11), last page
      "friends who are / linked by cable." on screen), regen byte-identical
      (determinism), goldencheck end-to-end PASS with window (16,6)
      brute-force-measured and every mask justified per class (dialog-
      scratch overlap rows 0-2, wider-OAM-window packing with the
      receptionist verified present by value, walked-through OBJ residue
      $60-$7F, MAP_BORDER view-pointer). SCOPE: the timeout path only —
      the connected path needs a peer and is covered by linkcheck.sh
- [x] Stage 2 close-out battery 2026-08-22: `fidelity-serial` core 16/16
      PASS (after `3222bbd` + the synchronized-photograph commit) and
      `fidelity-full-serial` 90/90 PASS, 0 FAIL, exit 0 — the whole
      registry including the new cable_club_nolink (this VM uses the
      serial tiers per the maintainer's standing instruction). Zero
      single-player drift from the whole Stage 2 net layer. The fork's
      NMDBG instrumentation is pushed on Happyarch/dosbox-x `mcp-debug`
      (`0eff618fd`) and the submodule pointer tracks it (maintainer
      authorization, this session)

### Stage 3 — Trade Center
- [x] HAL block seam 2026-08-22 (`b50e1e0`): `NF_BLK` reliable frame type +
      `NetHAL_ExchangeBlock` (one message each way per block, block-id
      lockstep, one-deep RX stage), `Serial_ExchangeBytes` re-cut at that
      seam (receive buffer verbatim-from-byte-0 — both peers DOS ports, the
      preamble-hunt shift is a GB-hardware artifact). Verified: NETTEST
      layout-v2 PASS decomposed (EXCH 60/60 both ways, blocks 3/3 each way
      content-checked incl. a one-shot-drop ARQ recovery at 424 B,
      blk_content_fail 0), linkcheck.sh regression 664/664 records both
      directions zero desyncs
- [x] Complete `src/engine/link/cable_club.asm` to all 23 labels
      (`CableClub_DoBattleOrTrade[Again]` block build/patch/exchange/unpatch,
      RNG list, `TradeCenter_SelectMon`/`TradeCenter_Trade`, `CableClub_Run`
      + its `WaitForTextScrollButtonPress` poll hook) — 2026-08-23
      (`99cb00b`): whole session runs inside the movie-projection surface
      (header projection DEVIATION), hidden events
      `CableClubLeftGameboy`/`RightGameboy` real in bills_pc.asm,
      `PrintWaitingText` real (link_stubs.asm deleted), faithdiff triage in
      the commit message, lint 0 both modes, `fidelity-serial` core 16/16
      PASS with the poll live. Runtime trade proof deferred to the
      two-instance item below (needs trade.asm)
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

### Stage 5 — link setup UI + connection book
- [ ] Keyboard text-entry mode beside the joypad scancode path
      (`src/input/joypad.asm`): port-only line-edit widget, per-field
      charset, no effect on normal joypad mapping
- [ ] `src/net/link_ui.asm`: transport-select menu in the `CableClubNPC`
      seam (CLI flags bypass), COM1-4 pick, per-transport book screens —
      DIRECT (connect without saving), AUTO (IPX), named entries with
      CONNECT/EDIT/DELETE/CANCEL, NEW (name + address); validation +
      error text; DELETE confirms
- [ ] `src/net/link_book.asm`: `LINKBOOK.DAT` load/save (magic `LNKB`,
      version, additive checksum, 5 TCP + 5 IPX fixed records with in-use
      flag + 16-byte charmap name + address payload; corrupt or absent →
      empty book)
- [ ] `tools/generators/gen_link_ui_strings.py` → `assets/link_ui_strings.inc`
      wired into `make assets`; zero hand-encoded charmap bytes
      (`lint_pret_labels --no-scan --strict-claims` stays 0)
- [ ] AutoKeyDrive scenario: create a named TCP and a named IPX entry,
      reboot the instance, assert names + addresses persist; EDIT an entry
      and re-verify; DIRECT connect path; full-book (5/5, NEW unavailable)
      and DELETE-with-confirm paths
- [ ] `KBD_NAMING=1` build option: Makefile flag (BUG_FIX_LEVEL plumbing
      pattern), `%if`-guarded keyboard path in
      `src/engine/menus/naming_screen.asm` with `DEVIATION{class=projection}`,
      special-char picker, `gen_kbd_naming.py` generated scancode map +
      picker charset; default build byte-identical behavior
- [ ] Port-only scenario on a `KBD_NAMING=1` build: type a name including
      one picker character, assert name bytes in a dump; default-build
      goldens untouched

### Stage 6 — IPX
- [ ] `ipx_dos.asm` (detect, socket `/IPXSOCK=`, DOS-memory ECBs, poll loop,
      broadcast discovery + direct net:node address from the book);
      linkcheck IPXNET variant; rerun the Stage 3/4 scenario battery

### Stage 7 — native TCP
- [ ] Slirp reachability spike FIRST (two NE2000+slirp guests are NATed
      apart — host port-forward topology; pcap fallback documented); gates
      the rest of the stage
- [ ] `pktdrv.asm` (DPMI 0303h real-mode RX callback — new pattern,
      document it) + `net_ip.asm` (ARP, IPv4, minimal stop-and-wait TCP);
      flags `/TCPWAIT[=port]`, `/TCP=ip[:port]`, `/IP= /MASK= /GW=`
      (no DHCP in v1 — recorded as deferred); book entries feed the
      connect path; linkcheck NE2000 variant; rerun battery

### Stage 8 — hardening + bookkeeping
- [ ] Soak: repeated trades/battles per transport, injected drops,
      pause/resume one instance; keepalive tuning
- [ ] Docs sweep (`dos_port/run` header flags, ROADMAP Phase 4,
      evidence-discipline wording: "verified under two-instance DOSBox-X",
      never "works on real hardware"); `update_label_db`
- [ ] HOST SESSION: stigmergy final state + `episode_record` — queue the
      concrete edits in `docs/stigmergy_outbox.jsonl` as the stages land
      (Stage 2's are already there), then apply-and-delete host-side
- [ ] Archive: `git mv docs/current_plan_link_cable.md docs/plans/link_cable.md`

## Acceptance (ROADMAP Phase 4)

One trade and one battle completed over each of the three transports under
the two-instance harness; all fidelity gates green; no single-player
regression in `make fidelity` core+full; real-hardware paths (UART on a
physical null modem cable, Novell IPX, packet-driver TCP) ship
spec-conformant with runtime escape hatches — the printer-backend precedent
for unverifiable hardware. UI acceptance: transport selectable in-game at
the receptionist; TCP and IPX addresses enterable by keyboard; five saved,
user-named connections per transport surviving a reboot via `LINKBOOK.DAT`,
each editable and deletable; and a DIRECT connect path that never touches
the book.

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

- **Fidelity runs from Claude's VM/remote sessions use the SERIAL tiers:**
  `make -C dos_port fidelity-serial` / `fidelity-full-serial` (maintainer
  directive 2026-08-21 — this satisfies CLAUDE.md's "unless the maintainer
  explicitly asks" requirement, scoped to resource-limited VM/remote
  sessions). The parallel `pgate.sh` default is sized for the maintainer's
  96-thread / 512 GB workstation; a 4-thread / 15 GB VM sits at pgate's
  concurrency floor (4 jobs, each with a tmpfs shadow copy), and
  oversubscription is the documented way parallelism can corrupt a result
  (goldencheck timeout kills). Every `make fidelity` reference in this plan
  reads per-environment: serial tiers on VM/remote, parallel on the
  workstation. Budget the serial full tier's wall time (historically
  ~1750 s at 86 scenarios — re-measure, the scenario count drifts upward)
  and keep the standing shell rules: no source edits while a suite runs,
  gate on a status FILE (never a pipeline tail), never poll with pgrep.
- **A fresh VM may lack `sfdisk` (util-linux's fdisk tools), and the failure
  is SILENT and misleading** (measured 2026-08-21): the `image` recipe pipes
  `sfdisk` to /dev/null, so a missing binary yields an MBR-less `PKMN.IMG`
  that mtools reads fine but DOSBox-X `imgmount` refuses ("Could not extract
  drive geometry") — and every goldencheck then reports "no GBSTATE.BIN in
  image — run crashed before the dump?", which reads as a game crash and is a
  MOUNT failure. Check `which sfdisk` before the first image build (Ubuntu:
  `apt-get install fdisk`), and after installing, `rm dos_port/PKMN.IMG` so
  the recipe recreates it with a real MBR. The same VM also lacked `pytest`
  (`pip install pytest`), without which `static_gate` — and therefore the
  pre-commit hook — fails on its label-DB test step.
- Submodules must be initialized (`git submodule update --init`) at least for
  `dos_port/tools/dosbox-x` (serial/IPX/NE2000 testing), `unicode_converter`
  (text generators) and `mgba` (goldens). The Happyarch fork submodule URLs
  are SSH (`git@github.com:…`) — remote/CI sessions may need an https URL
  rewrite.
- Stigmergy is unavailable in remote sessions; all memory/episode items above
  are marked HOST SESSION, and their concrete edits are queued in
  `docs/stigmergy_outbox.jsonl` (schema + apply-and-delete protocol in that
  file's README line) rather than described in prose.
