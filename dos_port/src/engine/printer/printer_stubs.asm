; printer_stubs.asm — Game Boy Printer routines, deferred.
;
; The GB Printer is a SERIAL-LINK peripheral (it hangs off the link port and is driven
; by the same serial transfer the trade/battle link uses). The port has no serial HAL,
; so the printer is TODO-HW, not merely unported: there is nothing for a faithful
; translation to talk to. These stubs keep pret's labels and let the routines that
; DISPATCH to the printer be ported in full, so the printer's callers are faithful
; today and only these bodies have to be filled in later.
;
; Created 2026-07-14 (menu-fidelity row 16). Before this, engine/menus/pokedex.asm's
; .chosePrint path was itself a no-op "STUB" comment that silently dropped 2 calls and
; 3 stores of pret's body. That is the wrong shape twice over: a stub is a LABEL with a
; ret, in a *_stubs.asm — never a deleted code path in a source-mirror file. The
; dispatch body now lives in pokedex.asm exactly as pret writes it, and the one thing
; that genuinely cannot work yet — the printer routine — is this ret.
;
; CONTRACT a bare ret is honest about: pret's PrintPokedexEntry draws its own screen and
; blocks while the transfer runs. Returning immediately means the caller (.chosePrint)
; falls straight through to its `ldh [hAutoBGTransferEnabled], 0 / call ClearScreen`,
; which clears and redraws the dex — i.e. pressing PRNT with no printer attached is a
; no-visible-op. That is also what real hardware does with no printer plugged in, so no
; caller is misled by this stub today.
;
; pret ref: engine/printer/print_pokedex.asm (PrintPokedexEntry).
; ---------------------------------------------------------------------------
bits 32

section .text

; PrintPokedexEntry — STUB (TODO-HW: serial). pret: engine/printer/print_pokedex.asm.
; In: [wCurPartySpecies] = the mon whose dex entry to print.
global PrintPokedexEntry
PrintPokedexEntry:
    ret
