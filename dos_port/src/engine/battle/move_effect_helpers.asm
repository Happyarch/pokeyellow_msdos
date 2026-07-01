; move_effect_helpers.asm — shared scaffold for the move-effect translation swarm.
;
; Provides the real shared text/logic helpers and the faithful-animation hooks that
; every move-effect handler (move_effects/*.asm, stat_mod_effects.asm, effects.asm
; bodies) calls but must NOT define itself. The fidelity boundary is
; docs/move_translation_divergence.md §4: these globals exist before the swarm
; starts; a worker `extern`s and calls them, the auditor expects them.
;
; Three tiers (per the divergence spec):
;   - real text/logic helpers (§3): PrintText, PrintStatText, ConditionalPrintBut-
;     ItFailed / PrintButItFailedText_, PrintDidntAffectText, PrintMayNotAttackText,
;     EffectCallBattleCore, CheckTargetSubstitute, DelayFrames.
;   - faithful-animation (ANIMATION=OFF behaviour, §3): UpdateCurMonHPBar,
;     PlayApplyingAttackAnimation, HideSubstituteShowMonAnim / ReshowSubstituteAnim.
;   - allowlist HW stubs (§2): Bankswitch (flat passthrough), the literal move
;     subanimation (PlayCurrentMoveAnimation / *2 / PlayBattleAnimation2 → no-op,
;     the ANIMATION=OFF path), audio (TODO-HW).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; flat program-image data (text labels, StatModTextStrings)
; read via [label]/[esi].
;
; Build: nasm -f coff -I include/ -I . -o move_effect_helpers.o move_effect_helpers.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- real backend already live + linked ---
extern PrintBattleText          ; core.asm — EAX = flat battle_text stream → print + prompt
extern DrawHUDsAndHPBars        ; battle_menu.asm / battle_hud.asm — redraw HUDs + HP bars
extern AnimateEnemyHPBar        ; battle_hud.asm — gradual enemy HP-bar drain (ECX = old HP)
extern AnimatePlayerHPBar       ; battle_hud.asm — gradual player HP-bar drain (ECX = old HP)
; DelayFrames (frame.asm) and PlayApplyingAttackAnimation (animations.asm) are already
; live + linked — handlers extern them directly; not redefined here.

; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern ButItFailedText
extern DidntAffectText
extern DoesntAffectMonText
extern ParalyzedMayNotAttackText

section .text

; ===========================================================================
; PrintText — pret PrintText, battle scope. In: ESI (HL) = flat ptr to a
; battle_text.inc command stream. Wraps PrintBattleText (which takes EAX). The
; handlers pass `mov esi, XxxText` then call/jp here, matching pret `ld hl, XxxText
; / jp PrintText`. Returns after the message (and any <PROMPT> wait) completes.
; ===========================================================================
global PrintText
PrintText:
    mov eax, esi
    jmp PrintBattleText                 ; tail: its ret returns to PrintText's caller

; ===========================================================================
; PrintStatText — pret engine/battle/effects.asm:PrintStatText.
; In: BH (B) = 1-based stat index. Copies the matching '@'-terminated stat name
; from StatModTextStrings into wStringBuffer (STAT_NAME_LENGTH bytes), for the
; "<MON>'s <STAT> rose/fell!" message. Clobbers AL, BH, ECX, ESI, EDI.
; ===========================================================================
global PrintStatText
PrintStatText:
    mov esi, StatModTextStrings
.outer:
    dec bh                              ; pret: dec b; jr z, .foundStatName
    jz .found
.inner:
    mov al, [esi]                       ; ld a, [hli] (flat)
    inc esi
    cmp al, 0x50                        ; '@'
    jne .inner
    jmp .outer
.found:
    mov edi, wStringBuffer              ; ld de, wStringBuffer
    mov ecx, STAT_NAME_LENGTH           ; ld bc, STAT_NAME_LENGTH
.copy:
    mov al, [esi]                       ; flat source (StatModTextStrings)
    inc esi
    mov [ebp + edi], al                 ; GB WRAM dest
    inc edi
    dec ecx
    jnz .copy
    ret

; ===========================================================================
; ConditionalPrintButItFailed / PrintButItFailedText_ — pret effects.asm.
; ConditionalPrintButItFailed: if the side effect failed yet the attack landed
; (wMoveDidntMiss != 0) return silently; otherwise print "But it failed!".
; ===========================================================================
global ConditionalPrintButItFailed
ConditionalPrintButItFailed:
    mov al, [ebp + wMoveDidntMiss]
    and al, al
    jz PrintButItFailedText_            ; side effect failed → "But it failed!"
    ret                                ; ret nz — attack succeeded, stay quiet
global PrintButItFailedText_
PrintButItFailedText_:
    mov esi, ButItFailedText
    jmp PrintText

; ===========================================================================
; PrintDidntAffectText / PrintMayNotAttackText — pret effects.asm.
; ===========================================================================
global PrintDidntAffectText
PrintDidntAffectText:
    mov esi, DidntAffectText
    jmp PrintText

; PrintDoesntAffectText — pret core.asm: ld hl, DoesntAffectMonText / jp PrintText.
global PrintDoesntAffectText
PrintDoesntAffectText:
    mov esi, DoesntAffectMonText
    jmp PrintText

global PrintMayNotAttackText
PrintMayNotAttackText:
    mov esi, ParalyzedMayNotAttackText
    jmp PrintText

; ===========================================================================
; CheckTargetSubstitute — pret effects.asm. ZF=1 if the target has NO substitute
; up (move can affect it), ZF=0 if a substitute is up. Preserves ESI/EDX; clobbers AL.
; ===========================================================================
global CheckTargetSubstitute
CheckTargetSubstitute:
    push esi
    mov esi, wEnemyBattleStatus2        ; target = enemy on the player's turn
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .next
    mov esi, wPlayerBattleStatus2
.next:
    test byte [ebp + esi], 1 << HAS_SUBSTITUTE_UP   ; ZF=1 → no substitute
    pop esi
    ret

; ===========================================================================
; ClearHyperBeam — pret engine/battle/effects.asm:ClearHyperBeam. Clears the
; NEEDS_TO_RECHARGE bit on the TARGET side's wXxxBattleStatus2 (enemy on the
; player's turn, player on the enemy's turn — the literal pret hl selection).
; Shared by FreezeBurnParalyzeEffect, FlinchSideEffect, TrappingEffect. Preserves
; ESI; clobbers AL (pret clobbers AF; callers don't rely on AL surviving).
; ===========================================================================
global ClearHyperBeam
ClearHyperBeam:
    push esi
    mov esi, wEnemyBattleStatus2        ; player's turn → target = enemy
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .playerTurn
    mov esi, wPlayerBattleStatus2
.playerTurn:
    and byte [ebp + esi], ~(1 << NEEDS_TO_RECHARGE) & 0xFF   ; res NEEDS_TO_RECHARGE
    pop esi
    ret

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
; Literal move-subanimation — allowlist stub (divergence §2 item 1). With
; ANIMATION=OFF the literal VFX stream is skipped; the faithful damage shake / HP
; drain are driven separately (PlayApplyingAttackAnimation / UpdateCurMonHPBar).
; The handlers still CALL these (correct + required) — here they are no-ops.
; ; TODO-HW: move-subanimation tile/OAM-stream engine (deferred).
; ===========================================================================
global PlayCurrentMoveAnimation
global PlayCurrentMoveAnimation2
global PlayBattleAnimation
global PlayBattleAnimation2
global AnimationSubstitute
global AnimationTransformMon
PlayCurrentMoveAnimation:
PlayCurrentMoveAnimation2:
PlayBattleAnimation:
PlayBattleAnimation2:
AnimationSubstitute:
AnimationTransformMon:
    ret

; ===========================================================================
; Audio — allowlist stub (divergence §2 item 2). ; TODO-HW: audio HAL (Phase 3).
; ===========================================================================
global PlaySound
PlaySound:
    ret

; ===========================================================================
; Faithful-animation hooks (ANIMATION=OFF behaviour, divergence §3). These are
; the visuals the game shows with animations off; the handlers drive them and the
; auditor expects them. Landed incrementally per the swarm plan — they provide the
; faithful effect where cheap and a clearly-marked linking symbol otherwise.
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

; PlayApplyingAttackAnimation (the damage shake / mon flash) is already live in
; animations.asm — handlers extern it directly. (It is the renderer blit-offset/flash
; hook's home; the software-PPU shake itself lands incrementally there.)

; HideSubstituteShowMonAnim / ReshowSubstituteAnim — pret animations.asm: swap the
; Substitute doll pic with the mon pic in VRAM (and back). No substitute support in
; the port yet, so the pics are unchanged — linking symbol now.
; TODO(faithful): Substitute↔mon pic VRAM swap once Substitute is wired.
global HideSubstituteShowMonAnim
global ReshowSubstituteAnim
HideSubstituteShowMonAnim:
ReshowSubstituteAnim:
    ret

; ---------------------------------------------------------------------------
; StatModTextStrings — pret data/battle/stat_mod_names.asm. '@'-terminated stat
; names in GB charmap bytes, concatenated (li "X" → db "X","@"). Scanned by
; PrintStatText. Charmap: 'A'..'Z' = $80..$99, '@' = $50.
; ---------------------------------------------------------------------------
section .data
StatModTextStrings:
    db 0x80,0x93,0x93,0x80,0x82,0x8A,0x50                         ; "ATTACK@"
    db 0x83,0x84,0x85,0x84,0x8D,0x92,0x84,0x50                    ; "DEFENSE@"
    db 0x92,0x8F,0x84,0x84,0x83,0x50                              ; "SPEED@"
    db 0x92,0x8F,0x84,0x82,0x88,0x80,0x8B,0x50                    ; "SPECIAL@"
    db 0x80,0x82,0x82,0x94,0x91,0x80,0x82,0x98,0x50               ; "ACCURACY@"
    db 0x84,0x95,0x80,0x83,0x84,0x50                              ; "EVADE@"
