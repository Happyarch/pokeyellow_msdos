; bankswitch2.asm — BankswitchCommon / JumpToAddress, faithful no-ops under the
; flat model.
;
; Source: home/bankswitch2.asm (pret/pokeyellow). Split out of the port's
; home/bankswitch.asm (menu-intro review 2026-07-23) so both pret files map to
; their exact mirrors: home/bankswitch.asm keeps BankswitchHome/BankswitchBack,
; this file holds pret bankswitch2.asm's own labels, in pret's order:
; BankswitchCommon, Bankswitch, JumpToAddress. Bankswitch arrived in chunk 17 of
; the relocated-label grind, from src/engine/battle/move_effect_helpers.asm (a
; convenience grouping holding no pret file's labels, now deleted); its body is
; unchanged. pret bankswitch2.asm's other two labels, OpenSRAM and CloseSRAM,
; are `missing` — no port body anywhere (SRAM enable/disable is a HAL boundary).
;
; Faithful-by-design adaptation (see CLAUDE.md): under this port's unified
; EBP-relative address space there are no MBC banks — every "ROM bank" already
; lives in one flat allocation, so the physical bank register write is a no-op.
; We still faithfully record the *requested* bank in hLoadedROMBank so any code
; that reads it back (audio, FarCopyData, etc.) sees the value pret would see.
;
; Register map: A -> AL (requested bank), HL -> ESI (handler flat pointer).
; H_LOADED_ROM_BANK is the port's memmap alias for pret hLoadedROMBank.
;
; Build: nasm -f coff -I include/ -o bankswitch2.o bankswitch2.asm

bits 32

%include "gb_memmap.inc"

global BankswitchCommon
global Bankswitch
global JumpToAddress

section .text

; ---------------------------------------------------------------------------
; BankswitchCommon — switch to ROM bank in AL.
;   Faithful: record AL in hLoadedROMBank. The MBC register write (rROMB) is a
;   no-op in the flat model. ; TODO-HW: ld [rROMB], a — MBC ROM bank register.
;   In:  AL = requested ROM bank.  Out: hLoadedROMBank = AL. Regs preserved.
; ---------------------------------------------------------------------------
BankswitchCommon:
    mov [ebp + H_LOADED_ROM_BANK], al   ; ldh [hLoadedROMBank], a
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
