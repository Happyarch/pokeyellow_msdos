; move_effect_helpers.asm — residual shared scaffold for the move-effect handlers.
;
; The pret engine/battle/effects.asm labels that used to live here (PrintStatText,
; ConditionalPrintButItFailed, PrintButItFailedText_, PrintDidntAffectText,
; PrintMayNotAttackText, CheckTargetSubstitute, ClearHyperBeam) now sit in their
; pret mirror, src/engine/battle/effects.asm, and the two engine/battle/core.asm
; labels that used to live here (PrintDoesntAffectText, UpdateCurMonHPBar) now sit
; in that mirror too. What is left is the handful of labels whose pret home is some
; OTHER file, plus the stat-name data blob:
;
;   EffectCallBattleCore    pret engine/battle/move_effects/reflect_light_screen.asm
;   Bankswitch              pret home/bankswitch2.asm
;   StatModTextStrings      pret data/battle/stat_mod_names.asm (generated asset)
;
; The first two are still relocated_labels rows in tools/pret_label_allowlist.json;
; they retire with their own pret file's consolidation pass, not with this one.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; flat program-image data read via [label]/[esi].
;
; Build: nasm -f coff -I include/ -I . -o move_effect_helpers.o move_effect_helpers.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

; ===========================================================================
; EffectCallBattleCore — pret move_effects/reflect_light_screen.asm. In the ROM
; this banks into BattleCore and jp [hl]; in the flat DPMI model there are no
; banks, so it tail-jumps to ESI (HL). (Same as Bankswitch below.)
; ===========================================================================
global EffectCallBattleCore
EffectCallBattleCore:
    jmp esi

; ===========================================================================
; Bankswitch — allowlist stub (divergence §2 item 4). No banks in the flat DPMI
; model: jump straight to the target in ESI (HL). B (bank) is ignored.
; ===========================================================================
global Bankswitch
Bankswitch:
    jmp esi

; ---------------------------------------------------------------------------
; StatModTextStrings — pret data/battle/stat_mod_names.asm. '@'-terminated stat
; names in GB charmap bytes, concatenated (li "X" → db "X","@"). Scanned by
; PrintStatText (now in effects.asm), which reaches it as an extern.
; ---------------------------------------------------------------------------
global StatModTextStrings
section .data
%include "assets/stat_mod_runtime_strings.inc"
