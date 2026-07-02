; metronome.asm — MetronomePickMove (battle-engine move-effect translation swarm).
;
; Faithful translation of engine/battle/core.asm:MetronomePickMove (pret/pokeyellow).
; Metronome picks a uniformly random move id in [1, STRUGGLE) excluding METRONOME
; itself, writes it into the acting side's wPlayerSelectedMove/wEnemySelectedMove,
; and tail-jumps into ReloadMoveData (shared with Mirror Move) to copy the picked
; move's stats/PP/name and return control to the caller.
;
; Fidelity boundary: docs/plans/move_translation_divergence.md. The only allowed
; divergence here is §2 item 1 (literal subanim / PlayMoveAnimation is the real
; ANIMATION=OFF path, kept as a faithful call — see below).
;
; Register map (CLAUDE.md): A=AL, DE=EDX, HL=ESI, EBP=GB base. GB memory at
; [EBP+addr]. hWhoseTurn is HRAM (0xFFF3), accessed the same way per the
; established pattern (building_rage.asm, residual_damage.asm).
;
; Build: nasm -f coff -I include/ -I . -o metronome.o metronome.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global MetronomePickMove

; --- shared scaffold externs (call, never define) ---
extern BattleRandom          ; core_damage.asm — battle PRNG, result in AL
extern PlayMoveAnimation     ; animations.asm — allowlist anim (ANIMATION=OFF path, §2 item 1)
extern ReloadMoveData        ; mirror_move.asm (sibling file) — reloads move data+name;
                              ; resolves at final link. In: AL = picked move id,
                              ; EDX = dest struct offset (wPlayerMoveNum/wEnemyMoveNum).

; move ids (pret constants.asm move_constants.asm)
METRONOME_MOVE  equ 0x4C     ; METRONOME
STRUGGLE_MOVE   equ 0xA5     ; STRUGGLE — pret ASSERT NUM_ATTACKS == STRUGGLE;
                              ; ids >= STRUGGLE are not real moves and are rejected.

; ===========================================================================
; MetronomePickMove — pret core.asm:5184. Picks a random move (not METRONOME,
; not >= STRUGGLE) for the acting side and reloads its move data.
; ===========================================================================
MetronomePickMove:
    xor al, al
    mov [ebp + wAnimationType], al      ; xor a / ld [wAnimationType], a
    mov al, METRONOME_MOVE              ; ld a, METRONOME
    ; ALLOWLIST (§2 item 1): pret plays Metronome's own subanim here
    ; (xor a / ld [wAnimationType],a / ld a, METRONOME / call PlayMoveAnimation).
    ; PlayMoveAnimation in this port already implements the faithful
    ; ANIMATION=OFF realization (fixed delay + PlayApplyingAttackAnimation), so
    ; this call is kept exactly as pret has it — subanim -> ANIMATION=OFF
    ; (kept faithful call), not a skip.
    call PlayMoveAnimation
    mov edx, wPlayerMoveNum             ; ld de, wPlayerMoveNum
    mov esi, wPlayerSelectedMove        ; ld hl, wPlayerSelectedMove
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .pickMoveLoop                    ; jr z, .pickMoveLoop
    mov edx, wEnemyMoveNum              ; ld de, wEnemyMoveNum
    mov esi, wEnemySelectedMove         ; ld hl, wEnemySelectedMove
.pickMoveLoop:
    call BattleRandom                   ; call BattleRandom -> AL
    and al, al
    jz .pickMoveLoop                    ; and a / jr z, .pickMoveLoop (reject 0)
    cmp al, STRUGGLE_MOVE               ; cp STRUGGLE
    jae .pickMoveLoop                   ; jr nc, .pickMoveLoop (reject id >= STRUGGLE)
    cmp al, METRONOME_MOVE              ; cp METRONOME
    je .pickMoveLoop                    ; jr z, .pickMoveLoop (reject Metronome itself)
    mov [ebp + esi], al                 ; ld [hl], a
    jmp ReloadMoveData                  ; jr ReloadMoveData (tail jump; DE/AL set as pret leaves them)
