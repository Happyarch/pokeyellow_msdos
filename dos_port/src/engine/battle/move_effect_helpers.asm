; move_effect_helpers.asm — residual shared scaffold for the move-effect handlers.
;
; The pret engine/battle/effects.asm labels that used to live here (PrintStatText,
; ConditionalPrintButItFailed, PrintButItFailedText_, PrintDidntAffectText,
; PrintMayNotAttackText, CheckTargetSubstitute, ClearHyperBeam) now sit in their
; pret mirror, src/engine/battle/effects.asm. What is left is the handful of
; labels whose pret home is some OTHER file, plus the stat-name data blob:
;
;   PrintDoesntAffectText   pret engine/battle/core.asm
;   UpdateCurMonHPBar       pret engine/battle/core.asm
;   EffectCallBattleCore    pret engine/battle/move_effects/reflect_light_screen.asm
;   Bankswitch              pret home/bankswitch2.asm
;   StatModTextStrings      pret data/battle/stat_mod_names.asm (generated asset)
;
; Each of those is still a relocated_labels row in tools/pret_label_allowlist.json;
; they retire with their own pret file's consolidation pass, not with this one.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; flat program-image data read via [label]/[esi].
;
; Build: nasm -f coff -I include/ -I . -o move_effect_helpers.o move_effect_helpers.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- real backend already live + linked ---
extern AnimateEnemyHPBar        ; battle_hud.asm — gradual enemy HP-bar drain (ECX = old HP)
extern AnimatePlayerHPBar       ; battle_hud.asm — gradual player HP-bar drain (ECX = old HP)
extern PrintText                ; src/home/window.asm — pret's PrintText

; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern DoesntAffectMonText

section .text

; ===========================================================================
; PrintDoesntAffectText — pret engine/battle/core.asm: ld hl, DoesntAffectMonText
; / jp PrintText.
; ===========================================================================
global PrintDoesntAffectText
PrintDoesntAffectText:
    mov esi, DoesntAffectMonText
    jmp PrintText

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

; ===========================================================================
; UpdateCurMonHPBar — pret engine/battle/core.asm:677 (UpdateCurMonHPBar → predef
; UpdateHPBar2). Faithful gradual, tick-by-tick HP-bar drain. Selects the bar by
; hWhoseTurn exactly as pret: hWhoseTurn==0 (player's turn) → the PLAYER mon's bar
; (pret hlcoord 10,9 / wHPBarType=1, i.e. the side that also ticks the HP number);
; else → the ENEMY mon's bar (pret hlcoord 2,2 / wHPBarType=0, no number). The old HP
; to start the drain from is wHPBarOldHP (pret stores it little-endian; each caller —
; residual_damage / drain_hp / heal / recoil — populates wHPBar{Old,New,Max}HP and the
; mon-struct HP before calling, matching pret). Animate{Player,Enemy}HPBar tick from
; ECX(old HP) to the final struct HP (== wHPBarNewHP here), redrawing on each pixel
; change with 2 DelayFrames per pixel — pret's UpdateHPBar cadence. pret preserves bc.
; ===========================================================================
global UpdateCurMonHPBar
UpdateCurMonHPBar:
    push ebx                            ; pret UpdateCurMonHPBar: push bc / pop bc
    movzx ecx, word [ebp + wHPBarOldHP] ; old HP (pret little-endian word) → drain start
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .playerBar                       ; hWhoseTurn==0 → player's mon bar (wHPBarType=1)
    call AnimateEnemyHPBar
    jmp .done
.playerBar:
    call AnimatePlayerHPBar
.done:
    pop ebx
    ret

; ---------------------------------------------------------------------------
; StatModTextStrings — pret data/battle/stat_mod_names.asm. '@'-terminated stat
; names in GB charmap bytes, concatenated (li "X" → db "X","@"). Scanned by
; PrintStatText (now in effects.asm), which reaches it as an extern.
; ---------------------------------------------------------------------------
global StatModTextStrings
section .data
%include "assets/stat_mod_runtime_strings.inc"
