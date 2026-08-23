; link_battle_versus_text.asm — mirror of pret
; engine/battle/link_battle_versus_text.asm (one label: DisplayLinkBattleVersusTextBox).
;
; Link cable plan Stage 4 step 2 (added after the step-1 audit measured this
; routine genuinely missing — no port body, no stub, both call sites carrying
; a DEVIATION{class=HAL} noting the drop). Draws the "[player] VS [enemy]"
; box with pokeball party rosters, called from DoBattleTransitionAndInitBattleVariables
; and EndOfBattle (both src/engine/battle/core.asm / end_of_battle.asm) during
; the battle-transition/post-battle phase — the battle screen already owns the
; canvas at that point (cable_club's MovieEndSurface is long done), so this
; uses the BATTLE UI layout convention (BCOORD projection over wTileMap), the
; same one PrintWaitingText (src/engine/link/print_waiting_text.asm) and every
; other in-battle text box in core.asm use — not the movie/cinematic surface
; convention.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=EDX, HL=ESI,
; EBP = GB base.
;
; Build check: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 \
;              -o /dev/null src/engine/battle/link_battle_versus_text.asm
;              (from dos_port/)

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"          ; BCOORD — battle-screen projection

global DisplayLinkBattleVersusTextBox

extern LoadTextBoxTilePatterns         ; src/home/load_font.asm
extern TextBoxBorder                   ; src/home/text.asm — ESI=top-left, BL=w, BH=h
extern PlaceString                     ; src/home/text.asm — EAX=flat src, ESI=dest
extern SetupPlayerAndEnemyPokeballs    ; src/engine/battle/battle_stubs.asm (STUB) —
                                        ; see its header for why
extern DelayFrames                     ; src/home/delay.asm — BL = frame count

; constants/charmap.asm — two raw bold-glyph tiles, not a generated string
; (project convention: a single/short run of raw control/glyph tiles written
; directly by code is not Tier-1 data; only human-rendered *strings* are).
CHAR_BOLD_V equ 0x69
CHAR_BOLD_S equ 0x6A

section .text

; ---------------------------------------------------------------------------
; DisplayLinkBattleVersusTextBox — pret
; engine/battle/link_battle_versus_text.asm:DisplayLinkBattleVersusTextBox.
; "display '[player] VS [enemy]' text box with pokeballs representing their
; parties next to the names" (pret's own header comment).
; ---------------------------------------------------------------------------
DisplayLinkBattleVersusTextBox:
    call LoadTextBoxTilePatterns
    mov esi, BCOORD(3, 4)                ; hlcoord 3, 4
    mov bh, 7                            ; lb bc, 7, 12
    mov bl, 12
    call TextBoxBorder
    lea eax, [ebp + wPlayerName]         ; ld de, wPlayerName (GB string -> flat)
    mov esi, BCOORD(4, 5)                ; hlcoord 4, 5
    call PlaceString
    lea eax, [ebp + wLinkEnemyTrainerName] ; ld de, wLinkEnemyTrainerName
    mov esi, BCOORD(4, 10)               ; hlcoord 4, 10
    call PlaceString
; place bold "VS" tiles between the names — two raw tile writes (ld_hli_a_string
; expands to exactly this: [hli]=first char, [hl]=last char, no terminator)
    mov esi, BCOORD(9, 8)                ; hlcoord 9, 8
    mov byte [ebp + esi], CHAR_BOLD_V
    mov byte [ebp + esi + 1], CHAR_BOLD_S
    mov byte [ebp + wUpdateSpritesEnabled], 0   ; xor a / ld [wUpdateSpritesEnabled], a
    call SetupPlayerAndEnemyPokeballs    ; pret: callfar (banking DEVIATION, flat code)
    mov bl, 150                          ; ld c, 150
    jmp DelayFrames                      ; jp DelayFrames
