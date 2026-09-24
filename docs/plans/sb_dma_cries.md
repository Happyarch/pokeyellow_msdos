# Current Plan: Sound Blaster DMA Cry Playback

Plan to implement hardware DMA streaming for Sound Blaster Pokémon cry playback, replacing the blocking Direct Mode CPU polling loop with background single-cycle 8-bit DMA. This allows the graphics compositor and animation pipeline (`DelayFrame`) to continue running at 60 FPS while cries sound, preventing Pokéball grow/shrink and sprite animations from stalling.

## STATUS — MEASURED 2026-09-24: COMPLETE (15/15 complete)

## Background & Problem Statement
The APU software synthesizer (`cry_synth.asm`) generates cycle-accurate 8-bit unsigned PCM for Pokémon cries. However, Sound Blaster playback (`sb_pcm.asm:sb_pcm_play`) currently relies on DSP Direct Mode (`0x10`) with interrupts disabled (`cli`) and tight PIT polling for the entire cry duration (~400 ms). Because the port's VBlank/screen pipeline executes in `DelayFrame`, blocking the CPU freezes all frame rendering during the cry. In battle send-out (`AnimateSendingOutMon`), the mon freezes at the $5\times5$ downscaled frame rather than smoothly resolving to $7\times7$ while the cry sounds.

Sound Blaster hardware provides 8-bit DMA (Channel 1 standard) and IRQ completion signaling. Utilizing single-cycle DMA playback allows the DSP to stream audio from conventional RAM in the background while the main thread pumps `DelayFrame` at 60 FPS.

## Technical Architecture

### 1. Device Routing Separation
- If an explicit non-SB chiptune device is selected (`g_shim_device` == `DEV_INNOVA`, `DEV_COVOX`, `DEV_TANDY`, `DEV_CMS`), `PlayCry` routes directly to the native pret `.fallback` path. Innovation SSI-2001 (SID) never falls back to Sound Blaster DSP.
- Sound Blaster cry playback activates only when `g_sb_present != 0` and `g_shim_device` is default OPL/SB.

### 2. Conventional Memory DMA Buffer (DPMI 0100h)
- 8237 DMA requires a contiguous physical memory buffer below 1 MB that does not cross a 64 KB physical boundary.
- Allocate a 32 KB block in conventional DOS memory using DPMI function `0100h` at audio init.
- Physical address: `linear = seg * 16`.
- Offset buffer start to ensure the 16 KB active slice never crosses a 64 KB boundary:
  `if ((linear & 0xFFFF) + 16384 > 0x10000) offset = (linear + 0xFFFF) & ~0xFFFF`.
- Store base physical address (`addr_lo = physical & 0xFFFF`), page register (`page = physical >> 16`), and flat PM pointer (`linear - ds_base`).

### 3. DPMI Protected-Mode IRQ Handler
- Parse `g_sb_irq` (from `BLASTER` environment variable, e.g. IRQ 5 or 7).
- Map to interrupt vector:
  - IRQ 0–7 $\to$ INT `08h + IRQ` (IRQ 5 = `0Dh`, IRQ 7 = `0Fh`).
  - IRQ 8–15 $\to$ INT `70h + (IRQ - 8)`.
- Save old vector via DPMI `0204h`.
- Install `sb_dma_isr` via DPMI `0205h`.
- Unmask IRQ at 8259 PIC (port `0x21` / `0xA1`).
- Inside `sb_dma_isr`:
  - Read DSP status port `[g_sb_base] + 0x0E` to acknowledge the interrupt at the DSP.
  - Send EOI (`0x20`) to Master PIC (port `0x20`), and Slave PIC (port `0xA0`) if IRQ $\ge 8$.
  - Clear `byte [g_sb_dma_active] = 0`.
  - `iretd`.
- Restore PIC mask and original vector at shutdown (`sb_dma_shutdown`).

### 4. 8237 DMA Channel & DSP Transfer
- Program 8237 DMA Controller (Channel 1):
  - Mask Channel 1: `out 0x0A, 0x05`.
  - Clear flip-flop: `out 0x0C, 0x00`.
  - Set Mode: Single-cycle, read (memory to device), auto-increment: `out 0x0B, 0x49`.
  - Clear flip-flop: `out 0x0C, 0x00`.
  - Write physical address to port `0x02` (lo, hi) and page port `0x83`.
  - Clear flip-flop: `out 0x0C, 0x00`.
  - Write count (`len - 1`) to port `0x03` (lo, hi).
  - Unmask Channel 1: `out 0x0A, 0x01`.
- Program SB DSP:
  - Enable speaker: DSP command `0xD1`.
  - Set time constant: DSP command `0x40`, value `256 - (1000000 / rate)`.
  - Start 8-bit DMA transfer: DSP command `0x14`, length lo `(len - 1) & 0xFF`, length hi `((len - 1) >> 8) & 0xFF`.
  - Set `g_sb_dma_active = 1`.

### 5. Asynchronous Cry Loop & Fallback
- `sb_cry_play`:
  - If DMA buffer available and `g_sb_nodma == 0`:
    - Synthesize cry into DMA buffer.
    - Start DMA playback.
    - Set `wChannelSoundIDs + CHAN5/6/8` to non-zero.
    - Loop calling `DelayFrame` while `g_sb_dma_active != 0`.
    - Once DMA completes, clear `wChannelSoundIDs`.
  - Fallback (if `/NODMA` or allocation fails):
    - Call `DelayFrame` once to flush pending graphics ($7\times7$ mon).
    - Execute direct mode `sb_pcm_play` (freeze accepted as fallback).

---

## Action Items

### Stage 1: Device Routing & Policy Cleanup
- [x] In `src/home/pokemon.asm`, update `PlayCry`: only route to `sb_cry_play` when `g_sb_present != 0` AND `g_shim_device == DEV_OPL` (or default). If `g_shim_device` is `DEV_INNOVA`, `DEV_COVOX`, `DEV_TANDY`, or `DEV_CMS`, jump directly to `.fallback`.
- [x] Add `/NODMA` command line flag parsing in `boot/entry.asm` to force Direct Mode fallback if requested.

### Stage 2: Conventional DMA Buffer Allocation
- [x] In `src/audio/sb_pcm.asm`, implement `sb_dma_init` allocating 32 KB conventional memory via DPMI `AX=0100h`.
- [x] Calculate 64 KB boundary-safe physical address and flat pointer.
- [x] Implement `sb_dma_shutdown` for clean shutdown.

### Stage 3: DPMI IRQ Hooking & PIC Management
- [x] In `src/audio/sb_pcm.asm`, implement IRQ hooking: save original vector via DPMI `0204h`, install `sb_dma_isr` via DPMI `0205h`, and unmask IRQ at PIC.
- [x] Implement `sb_dma_isr`: read DSP port `2xEh` to acknowledge DSP, send PIC EOI, clear `g_sb_dma_active`.
- [x] Implement IRQ restore in `sb_dma_shutdown`: restore PIC mask and restore original protected-mode vector via DPMI `0205h`.

### Stage 4: 8237 DMA & DSP Playback Pipeline
- [x] Implement `sb_dma_play(len, rate)`: program 8237 DMA Channel 1, set DSP time constant, send DSP command `0x14`, set `g_sb_dma_active = 1`.
- [x] Update `sb_cry_play` to stream through `sb_dma_play`, setting `wChannelSoundIDs` and pumping `DelayFrame` while `g_sb_dma_active != 0`.
- [x] Retain Direct Mode (`0x10`) path as guarded fallback when DMA buffer is unallocated or `/NODMA` is set.

### Stage 5: Verification & Safety Gates
- [x] Verify build and run `dos_port/tools/static_gate`.
- [x] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims`.
- [x] Verify golden scenarios (`pokedex_entry`, `party_menu`, `battle_pikachu`).
- [x] Live test in DOSBox-X with early game save: verify Pokéball send-out grow animation runs at 60 FPS while cry sounds.
