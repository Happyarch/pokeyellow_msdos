; bankswitch.asm — MBC ROM-bank switch, faithful no-op under the flat model.
;
; Source: home/bankswitch2.asm:BankswitchCommon, home/bankswitch.asm:
;         BankswitchHome / BankswitchBack (pret/pokeyellow).
;
; Faithful-by-design adaptation (see CLAUDE.md): under this port's unified
; EBP-relative address space there are no MBC banks — every "ROM bank" already
; lives in one flat allocation, so the physical bank register write is a no-op.
; We still faithfully record the *requested* bank in hLoadedROMBank so any code
; that reads it back (audio, FarCopyData, etc.) sees the value pret would see.
;
; pret BankswitchCommon (home/bankswitch2.asm):
;     BankswitchCommon::
;         ldh [hLoadedROMBank], a   ; <- we keep this (faithful bookkeeping)
;         ld  [rROMB], a            ; <- MBC ROM bank register: flat-model no-op
;         ret
;
; Register map: A -> AL (requested bank). H_LOADED_ROM_BANK is the port's
; memmap alias for pret hLoadedROMBank (gb_memmap.inc: equ 0xFFB8).
;
; Build: nasm -f coff -I include/ -o bankswitch.o bankswitch.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global BankswitchCommon
global BankswitchHome
global BankswitchBack

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

; ---------------------------------------------------------------------------
; BankswitchHome — switch to bank AL, saving the current bank so BankswitchBack
;   can restore it. Only valid when called from the home bank (as in pret).
;   pret shuffles A through wBankswitchHomeTemp because SM83 can't hold two
;   values; on x86 we keep the requested bank in a register, so only the saved
;   slot is needed. The saved slot is host-side scratch (not emulated GB RAM),
;   so it lives in this file's .bss rather than the EBP GB space.
;   In: AL = requested bank.
; ---------------------------------------------------------------------------
BankswitchHome:
    push eax
    mov al, [ebp + H_LOADED_ROM_BANK]           ; ldh a, [hLoadedROMBank]
    mov [bankswitchHomeSavedROMBank], al        ; ld [wBankswitchHomeSavedROMBank], a
    pop eax
    call BankswitchCommon                        ; switch to requested bank (AL)
    ret

; ---------------------------------------------------------------------------
; BankswitchBack — return from BankswitchHome: restore the saved bank.
; ---------------------------------------------------------------------------
BankswitchBack:
    mov al, [bankswitchHomeSavedROMBank]        ; ld a, [wBankswitchHomeSavedROMBank]
    call BankswitchCommon
    ret

; ---------------------------------------------------------------------------
; SwitchToMapRomBank — set the ROM bank for the current map's data/scripts.
; pret home/overworld.asm:SwitchToMapRomBank: reads the map's bank from
; MapHeaderBanks and BankswitchCommon-s to it. Flat-model: record the requested
; bank (bookkeeping); the physical MBC write is a no-op. Consumers (reload_tiles,
; text_script, run_map_script) keep the pret call structure.
; In: AL = map bank id. All other registers preserved.
; ---------------------------------------------------------------------------
global SwitchToMapRomBank
SwitchToMapRomBank:
    call BankswitchCommon                        ; record AL in hLoadedROMBank (flat no-op MBC)
    ret

section .bss

; pret wBankswitchHomeSavedROMBank (ram/wram.asm). Host-side scratch under the
; flat model — a private .bss byte, zeroed by the coff-go32 loader. pret's
; wBankswitchHomeTemp is not needed (it only existed to shuffle A on SM83).
bankswitchHomeSavedROMBank: resb 1
