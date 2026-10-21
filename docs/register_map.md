# SM83 → x86 Register Map

Living document. Update this when edge cases are discovered during translation.

---

## Primary Register Mapping

| SM83 | x86 | Width | Notes |
|------|-----|-------|-------|
| `A` | `AL` | 8-bit | Accumulator. `AH` is scratch; do not rely on it across calls. |
| `F` (Z flag) | `EFLAGS ZF` | 1-bit | Direct mapping. `sub`/`cmp`/`or`/`and` set it correctly. |
| `F` (C flag) | `EFLAGS CF` | 1-bit | Direct mapping. Note: SM83 `RL`/`RR` use C; x86 `rcl`/`rcr` do too. |
| `F` (H flag) | `[hf_shadow]` | 8-bit BSS | Lazy — only written when DAA, CPL, or other H-consuming instructions follow. Use `dos_port/include/gb_memmap.inc` offset. |
| `F` (N flag) | (implicit) | — | Tracked by instruction choice. After subtraction x86 is already "in subtract state" for DAA via `das`. |
| `B` | `BH` | 8-bit | High byte of `BX`. |
| `C` | `BL` | 8-bit | Low byte of `BX`. |
| `BC` | `BX` | 16-bit | Zero-extend to 32-bit when used as address/count: `movzx ecx, bx`. |
| `D` | `DH` | 8-bit | High byte of `DX`. |
| `E` | `DL` | 8-bit | Low byte of `DX`. |
| `DE` | `DX` | 16-bit | Same zero-extension note as BC. |
| `H` | `[ESI bits 8:15]` | — | Rarely needed independently; ESI holds full HL. |
| `L` | `[ESI bits 0:7]` | — | Rarely needed independently. |
| `HL` | `ESI` | 32-bit | Full 32-bit for flat GB-space addressing. `[EBP + ESI]` = dereferenced HL. |
| `SP` | `ESP` | 32-bit | Direct. Mind x86 calling convention — pushes/pops affect it. |
| `PC` | `EIP` | — | Implicit. |

## Fixed Registers (Do Not Repurpose)

| x86 | Role |
|-----|------|
| `EBP` | Base pointer to emulated GB address space. `[EBP + offset]` for all GB memory. Never push/pop EBP without restoring. |
| `EDI` | Secondary pointer / blit destination. Available as scratch within routines; callers should save/restore if needed across calls. |
| `ECX` | Loop counter and scratch. |

---

## EBP Memory Model

`EBP` = base address of a **160 KiB (`0x28000`)** flat DPMI allocation: the 64 KB GB
address space (`$0000-$FFFF`), plus the 64,000-byte native 320×200 back buffer, plus
the four resident emulated SRAM banks. Banks 1–3 live ABOVE the GB window (the port
keeps them resident rather than bank-switching them through `$A000`); bank 0 stays in
the hardware SRAM window.

```
[EBP + 0x8000]  VRAM bank 0         (8 KB)   → GB_VRAM0
[EBP + 0x9800]  BG tilemap 0        (1 KB)   → GB_TILEMAP0
[EBP + 0x9C00]  BG tilemap 1        (1 KB)   → GB_TILEMAP1
[EBP + 0xA000]  SRAM bank 0         (8 KB)   → GB_SRAM_BANK0
[EBP + 0xC000]  WRAM bank 0         (4 KB)   → GB_WRAM0
[EBP + 0xD000]  WRAM bank 1         (4 KB)   → GB_WRAM1
[EBP + 0xFE00]  OAM                 (160 B)  → GB_OAM
[EBP + 0xFF00]  I/O register shadow (128 B)  → GB_IO
[EBP + 0xFF7E]  H-flag shadow       (1 B)    → hf_shadow
[EBP + 0xFF80]  HRAM                (127 B)  → GB_HRAM
[EBP + 0xFFFF]  IE register shadow  (1 B)    → GB_IE
[EBP + 0x10000] VRAM bank 1 (CGB)   (8 KB)  → GB_VRAM1
[EBP + 0x12000] native back buffer  (64000 B) → GB_BACKBUF
[EBP + 0x22000] SRAM bank 1         (8 KB)   → GB_SRAM_BANK1
[EBP + 0x24000] SRAM bank 2         (8 KB)   → GB_SRAM_BANK2
[EBP + 0x26000] SRAM bank 3         (8 KB)   → GB_SRAM_BANK3
[EBP + 0x28000] end of allocation
```

Dereference GB pointer in HL:  `mov al, [ebp + esi]`  
Store to GB pointer in HL:     `mov [ebp + esi], al`  
Increment HL (hli):            `inc esi`  
Decrement HL (hld):            `dec esi`

> Resident SRAM banks 1–3 are reached by flat 32-bit offset (`GB_SRAM_BANK1..3`,
> `$22000-$27FFF`), not through the `$A000` window — see the `DEVIATION{class=banking}`
> at `include/gb_memmap.inc:1592`.

---

## Common SM83 → x86 Idiom Table

| SM83 idiom | x86 translation | Notes |
|-----------|-----------------|-------|
| `ld a, [hl]` | `mov al, [ebp + esi]` | |
| `ld [hl], a` | `mov [ebp + esi], al` | |
| `ld a, [hl+]` (hli) | `mov al, [ebp + esi]` / `inc esi` | Two instructions |
| `ld a, [hl-]` (hld) | `mov al, [ebp + esi]` / `dec esi` | Two instructions |
| `ld hl, nn` | `mov esi, nn` | |
| `ld a, b` | `mov al, bh` | |
| `ld b, a` | `mov bh, al` | |
| `add hl, bc` | `movzx ecx, bx` / `add esi, ecx` | Zero-extend to avoid partial-reg issues |
| `and a` | `test al, al` | Sets Z, clears C, H undefined |
| `or a` | `test al, al` | Same |
| `cp n` | `cmp al, n` | |
| `jr z, .label` | `jz .label` | |
| `jr nz, .label` | `jnz .label` | |
| `jr c, .label` | `jc .label` | |
| `jr nc, .label` | `jnc .label` | |
| `dec bc` | `sub bx, 1` or `dec bx` | Note: SM83 `dec bc` does NOT set flags; use accordingly |
| `inc bc` | `inc bx` | Same — SM83 does not set flags for 16-bit inc/dec |
| `push bc` | `push bx` | |
| `pop bc` | `pop bx` | |
| `rst $xx` | `call <label>` | RST vectors become normal labeled calls |
| `call nn` | `call nn` | Direct |
| `ret` | `ret` | |
| `reti` | `iret` or `ret` + `sti` | Depends on context; rarely encountered |
| `ldh a, [$FFxx]` | `mov al, [ebp + 0xFF00 + xx]` | Use IO_* constants |
| `ldh [$FFxx], a` | `mov [ebp + 0xFF00 + xx], al` | Use IO_* constants |
| `lda a, [$FF00+c]` | `movzx ecx, bl` / `mov al, [ebp + 0xFF00 + ecx]` | |

---

## H-Flag (hf_shadow) Protocol

The H flag is only needed for `daa`, `cpl`, and a few specific comparisons.
**Default behavior: do not update `hf_shadow` unless the very next instruction
that runs (no branches in between) actually reads H.**

When H must be set:
- After an add that may produce a half-carry: set `[hf_shadow]` to the result
  of `((op1 & 0xF) + (op2 & 0xF)) & 0x10`
- After a sub: set `[hf_shadow]` to `((op1 & 0xF) - (op2 & 0xF)) & 0x10`

Lazy approach: annotate with `; H-flag: lazy (not computed)` if you skip it,
and come back to fix it if `daa`/`cpl` is ever reached via this path.

---

## Calling Convention Notes

**Translated SM83 code does NOT follow the standard C callee-saved convention.**
The register map (BC→BX, DE→DX, HL→ESI) IS the argument/return convention: a
translated routine's arguments and results travel in `EBX`/`EDX`/`ESI` exactly as
pret's `b`/`c`, `d`/`e`, `h`/`l` do, and a callee may legitimately clobber any of
them according to its own pret contract — e.g. `AddBCD` takes `ESI`/`EDX` and `CL`
and walks both pointers downward. Callers must read the callee's header/pret source
rather than assume a blanket "EBX/ESI are preserved" rule.

- Hard-preserved across calls: `EBP` (the GB base pointer; never repurpose)
- Preserved only when the pret contract says so: `EBX`, `EDX`, `ESI` (they are
  argument registers — see above)
- Caller-saved (may be clobbered): `EAX`, `ECX`, `EDX`, `EDI`
- Stack: 4-byte aligned; `ESP` must be valid at all times
- The GB's `push af` / `pop af` idiom needs `push ax` / `pop ax` at minimum;
  use `pushfd`/`popfd` only if FLAGS matter across the call

---

## Known Translation Pitfalls

1. **`dec bc` / `inc bc` don't set flags** in SM83; x86 `dec bx` DOES set flags.
   If the surrounding code relies on the fact that flags are unchanged after 16-bit
   inc/dec on the GB, use `lea bx, [bx - 1]` (flags-preserving) instead.

2. **`sub b` etc. are 8-bit** — SM83 arithmetic is always 8-bit unless explicitly
   paired. Watch for implicit 16-bit widening in x86.

3. **Bankswitching** — the GB code uses ROM bank numbers and `FAR_CALL` idioms.
   In the DOS port there is only one flat address space. All bankswitching calls
   become direct calls; `BankswitchCommon` and `callfar` macros need to be stubbed
   out as no-ops initially and revisited once all ROM content is in one binary.

4. **Interrupt enable/disable** — `di`/`ei` on the GB maps to nothing in the main
   game logic translation (the PIT ISR is a separate concern). Don't translate them
   as `cli`/`sti` unless you're working on the interrupt infrastructure.
