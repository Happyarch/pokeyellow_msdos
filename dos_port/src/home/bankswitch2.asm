; bankswitch2.asm — BankswitchCommon / JumpToAddress, faithful no-ops under the
; flat model.
;
; Source: home/bankswitch2.asm (pret/pokeyellow). Split out of the port's
; home/bankswitch.asm (menu-intro review 2026-07-23) so both pret files map to
; their exact mirrors: home/bankswitch.asm keeps BankswitchHome/BankswitchBack,
; this file holds pret bankswitch2.asm's own labels, in pret's order:
; BankswitchCommon, Bankswitch, JumpToAddress, OpenSRAM, CloseSRAM. Bankswitch
; arrived in chunk 17 of the relocated-label grind, from
; src/engine/battle/move_effect_helpers.asm (a convenience grouping holding no
; pret file's labels, now deleted); its body is unchanged.
;
; OpenSRAM/CloseSRAM now have real bodies (maintainer directive 2026-08-23:
; "we usually don't emulate bankswitching, but I'd like to do it for SRAM ...
; this is important for our save simulation and not corrupting shit"). They no
; longer read `missing`, and this is NOT a HAL boundary — see below.
;
; Faithful-by-design adaptation (see CLAUDE.md): under this port's unified
; EBP-relative address space there are no MBC banks — every "ROM bank" already
; lives in one flat allocation, so the physical bank register write is a no-op.
; We still faithfully record the *requested* bank in hLoadedROMBank so any code
; that reads it back (audio, FarCopyData, etc.) sees the value pret would see.
;
; SRAM stays flat too (maintainer, 2026-08-23: "I still kinda want it flat
; though" — SRAM is "one giant reserved space in virtual memory", same as
; HRAM). Bank 0 is resident at GB_SRAM_BANK0 ($A000) and banks 1-3 at
; GB_SRAM_BANK1/2/3 ($22000/$24000/$26000, gb_memmap.inc) regardless of what
; OpenSRAM last latched — there is no $A000-$BFFF window swap. What IS real is
; the enable/disable WRITE-PROTECT LATCH: OpenSRAM/CloseSRAM record the MBC5
; rBMODE/rRAMG/rRAMB register writes pret makes, in port-local .bss below —
; rRAMG ($0000), rROMB ($2000), rRAMB ($4000) and rBMODE ($6000) are cartridge
; ADDRESS-SPACE decode windows (constants/hardware.inc lines 739/759/763/788),
; not emulated GB RAM, and the port has repurposed that low linear range for
; generated map blobs (audit_memmap.py caught rROMB=$2000 landing inside
; OW_ROUTE_17_BLK_GBADDR when this was first tried as a gb_memmap.inc [ebp+...]
; define — 2026-08-23), so they must never be `%include`d as memmap offsets.
; SramAssertOpen lets a debug build catch an SRAM write made while the latch
; says SRAM is disabled ("not corrupting shit").
;
; Register map: A -> AL (requested bank), HL -> ESI (handler flat pointer).
; hLoadedROMBank is the port's memmap alias for pret hLoadedROMBank.
;
; Build: nasm -f coff -I include/ -o bankswitch2.o bankswitch2.asm

bits 32

%include "gb_memmap.inc"

; MBC5 register VALUES pret loads before writing rBMODE/rRAMG (constants/
; hardware.inc lines 790-791 and 741-743). These are plain immediates, not
; addresses, so — unlike rRAMG/rROMB/rRAMB/rBMODE themselves — they carry no
; risk of aliasing emulated GB memory; they live here next to their only
; consumers rather than in gb_memmap.inc.
%define BMODE_ADVANCED   0x01
%define RAMG_SRAM_ENABLE 0x0A

global BankswitchCommon
global Bankswitch
global JumpToAddress
global OpenSRAM
global CloseSRAM
global SramAssertOpen

section .text

; ---------------------------------------------------------------------------
; BankswitchCommon — switch to ROM bank in AL.
;   Faithful: record AL in hLoadedROMBank. The MBC register write (rROMB) is a
;   no-op in the flat model. ; TODO-HW: ld [rROMB], a — MBC ROM bank register.
;   In:  AL = requested ROM bank.  Out: hLoadedROMBank = AL. Regs preserved.
; ---------------------------------------------------------------------------
BankswitchCommon:
    mov [ebp + hLoadedROMBank], al   ; ldh [hLoadedROMBank], a
    ret

; ===========================================================================
; Bankswitch — allowlist stub (divergence §2 item 4). No banks in the flat DPMI
; model: jump straight to the target in ESI (HL). B (bank) is ignored.
; ===========================================================================
Bankswitch:
    jmp esi

; ---------------------------------------------------------------------------
; JumpToAddress — pret home/bankswitch2.asm:JumpToAddress. Trivial trampoline
; used after BankswitchCommon-ing into a routine's bank so a `call JumpToAddress`
; tail-jumps to it (pret `jp hl`; the target's own `ret` returns to the caller of
; JumpToAddress). BankswitchCommon preserves ESI, so ESI still holds the handler.
; ---------------------------------------------------------------------------
JumpToAddress:
    jmp esi

; ---------------------------------------------------------------------------
; OpenSRAM — pret home/bankswitch2.asm:OpenSRAM.
;   push af / ld a,BMODE_ADVANCED / ld [rBMODE],a / ld a,RAMG_SRAM_ENABLE /
;   ld [rRAMG],a / pop af / ld [rRAMB],a / ret
;
; In:  AL = requested SRAM bank number.
; Out: g_sram_bmode = BMODE_ADVANCED, g_sram_ramg = RAMG_SRAM_ENABLE,
;      g_sram_ramb = AL (the latched bank). AL/flags preserved (pret's
;      push af .. pop af carries the bank across the two register writes;
;      here it carries it across the two `mov`s below, which don't touch
;      flags anyway, so ZF/CF entering the call reach `ret` unchanged).
;
; rBMODE/rRAMG/rRAMB are cartridge address-space registers (gb_memmap.inc),
; NOT [ebp+...] emulated-RAM offsets, so this stores the requested state in
; port-local .bss instead of writing "through" those addresses.
;
; DEVIATION{class=banking; pret=home/bankswitch2.asm:OpenSRAM; behavior=record the BMODE/RAMG/RAMB writes in port-local latch bytes instead of a real MBC5 register decode, and the addressing of GB_SRAM_BANK0-3 stays flat and does not consult the RAMB latch; evidence=CLAUDE.md resident-SRAM model plus maintainer directive 2026-08-23 to keep SRAM flat while still modelling the enable/disable write-protect bit; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
OpenSRAM:
    push eax                              ; push af
    mov byte [g_sram_bmode], BMODE_ADVANCED   ; ld a,BMODE_ADVANCED / ld [rBMODE],a
    mov byte [g_sram_ramg], RAMG_SRAM_ENABLE  ; ld a,RAMG_SRAM_ENABLE / ld [rRAMG],a
    pop eax                               ; pop af
    mov [g_sram_ramb], al                 ; ld [rRAMB], a — latch only; flat addressing ignores it
    ret

; ---------------------------------------------------------------------------
; CloseSRAM — pret home/bankswitch2.asm:CloseSRAM.
;   push af / ld a,0 / ld [rBMODE],a / ld [rRAMG],a / pop af / ret
;
; Out: g_sram_bmode = 0, g_sram_ramg = RAMG_SRAM_DISABLE (0). g_sram_ramb is
;      untouched, exactly as pret leaves rRAMB alone here. AL/flags preserved.
; ---------------------------------------------------------------------------
CloseSRAM:
    push eax                              ; push af
    xor al, al
    mov [g_sram_bmode], al                ; ld a,0 / ld [rBMODE],a
    mov [g_sram_ramg], al                 ; ld [rRAMG],a  (RAMG_SRAM_DISABLE == 0)
    pop eax                               ; pop af
    ret

; ---------------------------------------------------------------------------
; SramAssertOpen — port-only debug helper (not a pret label). Under
; DEBUG_ASSERT_SCRATCH, traps (int3) if SRAM is written while the latch says
; it is disabled ("not corrupting shit" — maintainer directive 2026-08-23).
; Compiles to a bare `ret` (zero cost) when DEBUG_ASSERT_SCRATCH is undefined.
; Port-only: no pret counterpart, so no DEVIATION/BUG/GLITCH/STUB annotation
; applies here (it does not stand in for a pret routine and does not change
; any translated routine's behavior).
; ---------------------------------------------------------------------------
SramAssertOpen:
%ifdef DEBUG_ASSERT_SCRATCH
    cmp byte [g_sram_ramg], RAMG_SRAM_ENABLE
    je .sram_open
    int3
.sram_open:
%endif
    ret

section .bss

; Port-local latch storage for the cartridge-space MBC5 registers OpenSRAM/
; CloseSRAM write (rBMODE/rRAMG/rRAMB — see the file header). NOT emulated GB
; RAM, and deliberately not defined in gb_memmap.inc/[ebp+...] form.
g_sram_bmode: resb 1                      ; last value written to rBMODE
g_sram_ramg:  resb 1                      ; last value written to rRAMG
g_sram_ramb:  resb 1                      ; last value written to rRAMB (latched bank)
