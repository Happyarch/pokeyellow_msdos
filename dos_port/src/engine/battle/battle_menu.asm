; battle_menu.asm — battle DRAW HELPERS + EXP/level-up display + run-odds.
;
; This file is the sanctioned DRAW-LAYER divergence point for the battle front end.
; The bespoke battle ORCHESTRATION it used to hold (DisplayBattleMenu, MoveSelectionMenu,
; the turn loop, Render*/Do*AttackDamage, the fainted/no-PP/run message draws) has been
; replaced by the faithful translation in core.asm (engine/battle/core.asm). What remains
; here are: (1) the centered-canvas draw primitives core.asm calls, exposed under pret
; names (SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 / DrawHUDsAndHPBars /
; DrawEmptyDialogBox / DrawBattleMenuBox); (2) the EXP/level-up display routines that
; GainExperience (experience.asm) calls inside its per-mon loop; (3) the move TYPE/PP box
; and FindMoveName helper; (4) the faithful run-odds (TryRunningFromBattle).
;
; All draw coords come from the generated battle UI layout (Tier 1,
; assets/ui_layout_battle.inc ← ui_layout_battle_sidecar.json; edit with
; tools/ui_layout/battle.py — never hand-edit offsets here). The layout is the
; only place the front end diverges from pret.
;
; Register map: A=AL, BC=BX, EBP = GB base; GB memory = [EBP+addr].
%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

bits 32

%define FW   SCREEN_TILES_W            ; 40 — W_TILEMAP stride
%define T_SP 0x7F

; PROJ battle: action menu box/labels = UI_ACTION_MENU_BOX / UI_ACTION_TEXT
; (pret BATTLE_MENU_TEMPLATE 8,12,19,17; TextBoxBorder takes interior w/h).
%define BOX_OFF      UI_ACTION_MENU_BOX_OFS
%define BOX_W        (UI_ACTION_MENU_BOX_GBW - 2)
%define BOX_H        (UI_ACTION_MENU_BOX_GBH - 2)
%define TEXT_OFF     UI_ACTION_TEXT_OFS
; PROJ battle: outer dialog box = UI_DIALOG_BOX (same box InitBattle draws).
%define OUTER_OFF    UI_DIALOG_BOX_OFS
%define OUTER_W      (UI_DIALOG_BOX_GBW - 2)
%define OUTER_H      (UI_DIALOG_BOX_GBH - 2)
; Dialog text rows, box-relative so text follows the box wherever the layout
; puts it: DLG_INT(n) = single-spaced interior row n; the standard two
; double-spaced message lines are the layout's own elements.
%define DLG_INT(n)   (UI_DIALOG_BOX_OFS + (n) * FW + 1)
; PROJ battle: message lines = UI_DIALOG_LINE1 / UI_DIALOG_LINE2
%define MSG_LINE1    UI_DIALOG_LINE1_OFS
%define MSG_LINE2    UI_DIALOG_LINE2_OFS

; PROJ battle: TYPE/PP info box = UI_INFO_BOX (pret PrintMenuItem
; TextBoxBorder(0,8) 9×3). Interior offsets stay box-origin-relative.
%define IB_COL        UI_INFO_BOX_COL
%define IB_ROW        UI_INFO_BOX_ROW
%define INFOBOX_OFF   UI_INFO_BOX_OFS
%define CHAR_SLASH    0xF3
%define CHAR_DIG0     0xF6

; PROJ battle: level-up stats box = UI_LVLUP_BOX / UI_LVLUP_LBL / UI_LVLUP_VAL
; (pret PrintStatsBox.LevelUpStatsBox; labels/values step 2 rows ×4).
%define LVLBOX_OFF   UI_LVLUP_BOX_OFS
%define LVLBOX_W     (UI_LVLUP_BOX_GBW - 2)
%define LVLBOX_H     (UI_LVLUP_BOX_GBH - 2)
%define LVL_LBL_OFF  UI_LVLUP_LBL_OFS
%define LVL_VAL_OFF  UI_LVLUP_VAL_OFS

; PROJ battle: ▼ "more text" advance arrow = UI_DIALOG_ARROW
%define ARROW_OFF          UI_DIALOG_ARROW_OFS
%define T_DOWNARROW        0xEE
%define ARROW_BLINK_FRAMES 20

section .data
; "FIGHT <PK><MN><NEXT>ITEM  RUN@"  (raw charmap tiles)
BattleMenuText:
    db 0x85,0x88,0x86,0x87,0x93,0x7F      ; "FIGHT "
    db 0xE1,0xE2                          ; <PK><MN>
    db 0x4E                               ; <NEXT>
    db 0x88,0x93,0x84,0x8C                ; "ITEM"
    db 0x7F,0x7F                          ; "  "
    db 0x91,0x94,0x8D                      ; "RUN"
    db 0x50                               ; @
str_excl:  db 0xE7, 0x50                        ; "!"
str_type:  db 0x93,0x98,0x8F,0x84, 0x50         ; "TYPE"
; run-from-battle text (pret GotAwayText / CantEscapeText / NoRunningText)
str_gotaway: db 0x86,0xAE,0xB3,0x7F,0xA0,0xB6,0xA0,0xB8,0x7F,0xB2,0xA0,0xA5,0xA4,0xAB,0xB8,0xE7, 0x50 ; "Got away safely!"
str_cantesc: db 0x82,0xA0,0xAD,0xE0,0xB3,0x7F,0xA4,0xB2,0xA2,0xA0,0xAF,0xA4,0xE7, 0x50              ; "Can't escape!"
str_norun1:  db 0x8D,0xAE,0xE7,0x7F,0x93,0xA7,0xA4,0xB1,0xA4,0xE0,0xB2,0x7F,0xAD,0xAE, 0x50          ; "No! There's no"
str_norun2:  db 0xB1,0xB4,0xAD,0xAD,0xA8,0xAD,0xA6,0x7F,0xA5,0xB1,0xAE,0xAC,0x7F,0xA0, 0x50          ; "running from a"
str_norun3:  db 0xB3,0xB1,0xA0,0xA8,0xAD,0xA4,0xB1,0x7F,0xA1,0xA0,0xB3,0xB3,0xAB,0xA4,0xE7, 0x50     ; "trainer battle!"
; victory EXP text (pret " gained" + _ExpPointsText " EXP. Points!")
str_gained:  db 0x7F,0xA6,0xA0,0xA8,0xAD,0xA4,0xA3, 0x50                                          ; " gained"
str_exppts:  db 0x7F,0x84,0x97,0x8F,0xE8,0x7F,0x8F,0xAE,0xA8,0xAD,0xB3,0xB2,0xE7, 0x50            ; " EXP. Points!"
; level-up text (pret _GrewLevelText "<nick> grew / to level N!")
str_grew:    db 0x7F,0xA6,0xB1,0xA4,0xB6, 0x50                                                    ; " grew"
str_tolevel: db 0xB3,0xAE,0x7F,0xAB,0xA4,0xB5,0xA4,0xAB,0x7F, 0x50                                 ; "to level "
; level-up stats-box labels (pret PrintStatsBox.StatsText)
str_attack:  db 0x80,0x93,0x93,0x80,0x82,0x8A, 0x50                                               ; "ATTACK"
str_defense: db 0x83,0x84,0x85,0x84,0x8D,0x92,0x84, 0x50                                          ; "DEFENSE"
str_speed:   db 0x92,0x8F,0x84,0x84,0x83, 0x50                                                    ; "SPEED"
str_special: db 0x92,0x8F,0x84,0x82,0x88,0x80,0x8B, 0x50                                          ; "SPECIAL"

section .bss
; Battle terminal state (legacy harness hook): 0 = ongoing. core.asm uses wBattleResult;
; the DEBUG_BATTLE harness still seeds this for compatibility.
global wBattleOver
wBattleOver: resb 1
; WaitForTextScrollButtonPress: saved down-arrow blink counters (pret push af x2)
wtsbp_saved_c1: resb 1
wtsbp_saved_c2: resb 1
; Saved "clean" battle screen — SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1.
screen_save: resb SCREEN_AREA
lvl_mon_ptr: resd 1                       ; GB offset of the leveling party mon (PrintStatsBox)

section .text

global DrawBattleMenu
global DrawBattleMenuBox
global DrawEmptyDialogBox
global PrintMoveInfoBox
global SaveBattleScreen
global RestoreBattleScreen
global SaveScreenTilesToBuffer1
global LoadScreenTilesFromBuffer1
global DrawHUDsAndHPBars
global EndBattleScreen
global WaitForAPress
global WaitForTextScrollButtonPress
global ShowGainedExpText
global ShowGrewLevelText
global PrintStatsBox
global LearnMoveFromLevelUp
global FindMoveName
global TryRunningFromBattle
global BattleItemMenu
global BattlePartyMenu
global DoEnemyAttackDamage

extern TextBoxBorder                 ; unified text engine (text.asm), stride-aware
extern PlaceString                   ; unified text engine; src=EAX, returns end in EBX
extern PrintLetterDelay              ; shared per-letter delay; gates on BIT_TEXT_DELAY
extern menu_item_step                ; src/home/window.asm — menu cursor item spacing
extern text_row_stride               ; text.asm — W_TILEMAP row stride (battle sets 40)
extern MoveNames
extern Moves
extern WideTypeNames
extern DelayFrame
extern HandleDownArrowBlinkTiming     ; src/home/window.asm — faithful ▼ blink (COUNT1==0 guard)
extern DrawBattleHUDs
extern BattleRandom
extern Multiply
extern Divide
extern GetMonLearnset                ; write_moves.asm — flat learnset ptr for wCurPartySpecies
; --- DEBUG_BATTLE_ENEMYHIT ground-truth scaffold only ---
extern GetCurrentMove
extern GetDamageVarsForEnemyAttack
extern CalculateDamage
extern AdjustDamageForMoveType
extern RandomizeDamage
extern IsThisPartyMonStarterPikachu  ; src/engine/pikachu/pikachu_status.asm (mood bump)
extern GetMoveName                   ; src/home/names.asm — move name -> wNameBuffer
extern CopyToStringBuffer            ; src/engine/battle/core.asm — wNameBuffer -> wStringBuffer
extern LearnMove                     ; src/engine/pokemon/learn_move.asm — faithful teach flow

; ===========================================================================
; Draw primitives (the sanctioned divergence point) under pret names.
; ===========================================================================

; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 (pret names) — snapshot the
; clean battle screen (W_TILEMAP) and restore it (wiping transient menu/info overlays).
SaveScreenTilesToBuffer1:
SaveBattleScreen:
    lea esi, [ebp + W_TILEMAP]
    mov edi, screen_save
    mov ecx, SCREEN_AREA
    rep movsb
    ret
LoadScreenTilesFromBuffer1:
RestoreBattleScreen:
    mov esi, screen_save
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    rep movsb
    ret

; DrawHUDsAndHPBars (pret name) — alias to the centered-canvas HUD draw helper.
DrawHUDsAndHPBars:
    jmp DrawBattleHUDs

; DrawEmptyDialogBox — pret PrintEmptyString: redraw the outer dialog box with a BLANK
; interior (clears any prior message). Labels/box are instant (pret PlaceString).
DrawEmptyDialogBox:
    and byte [ebp + W_LETTER_PRINTING_DELAY], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    ret

; DrawBattleMenuBox — pret DisplayTextBoxID(BATTLE_MENU_TEMPLATE): the smaller menu box
; (divider) + the FIGHT/PKMN/ITEM/RUN labels. In: EBP = GB base.
DrawBattleMenuBox:
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + BOX_OFF
    mov bh, BOX_H
    mov bl, BOX_W
    call TextBoxBorder
    mov esi, W_TILEMAP + TEXT_OFF
    mov eax, BattleMenuText
    call PlaceString
    mov esi, ebx
    ret

; DrawBattleMenu — outer dialog box + menu box + labels (static; used by the DEBUG_BATTLE
; non-interactive dump harness). Equivalent to DrawEmptyDialogBox + DrawBattleMenuBox.
DrawBattleMenu:
    call DrawEmptyDialogBox
    jmp DrawBattleMenuBox

; EndBattleScreen — clean battle terminal: blank the canvas, present it, restore the
; overworld text stride. (Placeholder exit; real exit returns to the overworld.)
EndBattleScreen:
    mov dword [text_row_stride], 20       ; restore the overworld/GB text stride
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    mov al, T_SP
    rep stosb
    call DelayFrame
    ret

; BattleItemMenu / BattlePartyMenu — deferred in-battle sub-UIs (bag / party-switch).
; pret runs the bag / party menu here; until those are wired, they are no-ops (core.asm
; re-shows DisplayBattleMenu after). TODO(faithful): ITEM → bag use, PKMN → switch.
BattleItemMenu:
BattlePartyMenu:
    ret

; WaitForAPress / WaitForTextScrollButtonPress — wait for A/B, faithfully mirroring
; pret home/joypad2.asm:WaitForTextScrollButtonPress. pret does NOT draw an arrow; it
; only *blinks a pre-existing* ▼ via HandleDownArrowBlinkTiming, gated by initializing
; hDownArrowBlinkCount1 = 0 (the canonical HandleDownArrowBlinkTiming leaves the tile
; alone when it isn't already ▼ and COUNT1 == 0). None of this routine's callers (status
; screen, league PC, EXP, town map) place a ▼, so none show one — matching the real game.
; The text-box advance ▼ is a *separate* mechanism (text.asm manual_text_scroll).
;
; The prior port version force-drew ▼ at ARROW_OFF and blanked it to a SPACE on exit,
; which on the status screen (ARROW_OFF = scoord(18,16)) punched a hole in the types/ID/OT
; box's bottom border and showed a spurious blinking arrow — a bespoke divergence.
; Save/restore the blink counters like pret's push af / push af.
WaitForTextScrollButtonPress:
WaitForAPress:
    mov al, [ebp + H_DOWN_ARROW_COUNT1]
    mov [wtsbp_saved_c1], al
    mov al, [ebp + H_DOWN_ARROW_COUNT2]
    mov [wtsbp_saved_c2], al
    mov byte [ebp + H_DOWN_ARROW_COUNT1], 0      ; pret: xor a  / ldh [hDownArrowBlinkCount1]
    mov byte [ebp + H_DOWN_ARROW_COUNT2], 6      ; pret: ld a,6 / ldh [hDownArrowBlinkCount2]
.wait:
    mov esi, W_TILEMAP + ARROW_OFF               ; pret: hlcoord 18,16
    call HandleDownArrowBlinkTiming              ; blinks only a pre-existing ▼ (COUNT1==0 guard)
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jz .wait
    mov al, [wtsbp_saved_c1]                      ; pret: pop af / ldh [hDownArrowBlinkCount1]
    mov [ebp + H_DOWN_ARROW_COUNT1], al
    mov al, [wtsbp_saved_c2]
    mov [ebp + H_DOWN_ARROW_COUNT2], al
    ret

; ===========================================================================
; TryRunningFromBattle — faithful pret escape-odds (engine/battle/core.asm).
; Guaranteed-escape special cases first (Safari / "hurry get away" / link), then the
; wild-mon speed odds; trainer battles can't be fled. Returns CF=1 on escape ("Got
; away safely!"), CF=0 otherwise; on a failed escape sets wActionResultOrTookBattleTurn
; (wild) and wForcePlayerToChooseMon (both paths).
; ===========================================================================
TryRunningFromBattle:
    ; pret core.asm:1536-1545 — guaranteed-escape special cases before the odds math.
    ; TODO(faithful): IsGhostBattle → .canEscape (Master A's IsGhostBattle; ghost
    ; battles are not reachable yet).
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    je .canEscape                        ; Safari battle always escapes (reachable)
    cmp byte [ebp + wBattleType], BATTLE_TYPE_RUN
    je .canEscape                        ; "hurry, get away?" forced-run
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    je .canEscape                        ; link battle always escapes
    cmp byte [ebp + wIsInBattle], 2
    je .trainerBattle
    inc byte [ebp + wNumRunAttempts]
    mov al, [ebp + wBattleMonSpeed]
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + wBattleMonSpeed + 1]
    mov [ebp + hMultiplicand + 2], al
    mov al, [ebp + wEnemyMonSpeed]
    mov [ebp + hEnemySpeed], al
    mov al, [ebp + wEnemyMonSpeed + 1]
    mov [ebp + hEnemySpeed + 1], al
    ; player speed >= enemy speed → guaranteed escape (pret StringCmp + jr nc)
    movzx eax, byte [ebp + wBattleMonSpeed]
    shl eax, 8
    mov al, [ebp + wBattleMonSpeed + 1]
    movzx ecx, byte [ebp + wEnemyMonSpeed]
    shl ecx, 8
    mov cl, [ebp + wEnemyMonSpeed + 1]
    cmp eax, ecx
    jae .canEscape
    ; quotient = (player speed * 32) / ((enemy speed / 4) % 256)
    mov byte [ebp + hMultiplicand], 0
    mov byte [ebp + hMultiplier], 32
    call Multiply
    mov al, [ebp + hProduct + 2]
    mov [ebp + hDividend], al
    mov al, [ebp + hProduct + 3]
    mov [ebp + hDividend + 1], al
    mov bh, [ebp + hEnemySpeed]
    mov al, [ebp + hEnemySpeed + 1]
    shr bh, 1
    rcr al, 1
    shr bh, 1
    rcr al, 1
    and al, al
    jz .canEscape
    mov [ebp + hDivisor], al
    mov bh, 2
    call Divide
    mov al, [ebp + hQuotient + 2]
    and al, al
    jnz .canEscape
    movzx ecx, byte [ebp + wNumRunAttempts]
.addLoop:
    dec ecx
    jz .compareRandom
    mov al, [ebp + hQuotient + 3]
    add al, 30
    mov [ebp + hQuotient + 3], al
    jc .canEscape
    jmp .addLoop
.compareRandom:
    call BattleRandom
    mov bl, al
    mov al, [ebp + hQuotient + 3]
    cmp al, bl
    jae .canEscape
    ; can't escape: forfeit the turn, print "Can't escape!"
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    mov eax, str_cantesc
    call PrintRunLine
    mov byte [ebp + wForcePlayerToChooseMon], 1  ; pret core.asm:1620-1622
    call SaveScreenTilesToBuffer1
    clc
    ret
.trainerBattle:
    ; "No! There's no / running from a / trainer battle!" (3 lines, single-spaced).
    or  byte [ebp + W_LETTER_PRINTING_DELAY], (1 << BIT_TEXT_DELAY)
    mov dword [menu_item_step], FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov esi, W_TILEMAP + DLG_INT(1)
    mov eax, str_norun1
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + DLG_INT(2)
    mov eax, str_norun2
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + DLG_INT(3)
    mov eax, str_norun3
    call PlaceString
    mov esi, ebx
    call WaitForAPress
    mov byte [ebp + wForcePlayerToChooseMon], 1  ; pret core.asm:1620-1622
    call SaveScreenTilesToBuffer1
    clc
    ret
.canEscape:
    mov eax, str_gotaway
    call PrintRunLine
    stc
    ret

; PrintRunLine — redraw the dialog box and place a single-line run message (line 1),
; then wait for A. In: EAX = string ptr; EBP = GB base.
PrintRunLine:
    push eax
    or  byte [ebp + W_LETTER_PRINTING_DELAY], (1 << BIT_TEXT_DELAY)
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    pop eax
    mov esi, W_TILEMAP + MSG_LINE1
    call PlaceString
    mov esi, ebx
    call WaitForAPress
    ret

; ===========================================================================
; EXP / level-up display — called by GainExperience (experience.asm) per mon.
; ===========================================================================

; ShowGainedExpText — pret GainedText→ExpPointsText: "<nick> gained / N EXP. Points!"
; for wWhichPokemon; waits for A. N = wExpAmountGained (16-bit big-endian).
ShowGainedExpText:
    or  byte [ebp + W_LETTER_PRINTING_DELAY], (1 << BIT_TEXT_DELAY)
    call RestoreBattleScreen
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov esi, W_TILEMAP + MSG_LINE1
    call get_party_nick
    call PlaceString
    mov esi, ebx
    mov eax, str_gained
    call PlaceString
    mov esi, ebx
    mov edi, W_TILEMAP + MSG_LINE2
    movzx eax, byte [ebp + wExpAmountGained]
    shl eax, 8
    mov al, [ebp + wExpAmountGained + 1]
    call print_dec
    mov esi, edi
    mov eax, str_exppts
    call PlaceString
    mov esi, ebx
    call WaitForAPress
    ret

; ShowGrewLevelText — pret GrewLevelText: "<nick> grew / to level N!" (no wait; the
; stats box + a single WaitForTextScrollButtonPress follow). N = wCurEnemyLevel.
ShowGrewLevelText:
    or  byte [ebp + W_LETTER_PRINTING_DELAY], (1 << BIT_TEXT_DELAY)
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov esi, W_TILEMAP + MSG_LINE1
    call get_party_nick
    call PlaceString
    mov esi, ebx
    mov eax, str_grew
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + MSG_LINE2
    mov eax, str_tolevel
    call PlaceString
    mov esi, ebx
    mov edi, esi
    movzx eax, byte [ebp + wCurEnemyLevel]
    call print_dec
    mov esi, edi
    mov eax, str_excl
    call PlaceString
    mov esi, ebx
    ret

; LearnMoveFromLevelUp — faithful pret evos_moves.asm:LearnMoveFromLevelUp. Scans the
; leveled mon's learnset for a move taught at wCurEnemyLevel; if unknown and a free slot
; exists, writes it + base PP and shows "<nick> learned <move>!". All-slots-full "forget
; a move?" menu DEFERRED. Called by GainExperience after the stats box.
LearnMoveFromLevelUp:
    mov al, [ebp + wPokedexNum]
    mov [ebp + wCurPartySpecies], al
    call GetMonLearnset
.scan:
    mov al, [esi]
    inc esi
    test al, al
    jz .restore
    mov dh, al
    mov al, [esi]
    inc esi
    mov dl, al
    cmp dh, [ebp + wCurEnemyLevel]
    jne .scan
    movzx eax, byte [ebp + wWhichPokemon]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    add eax, wPartyMon1
    mov [lvl_mon_ptr], eax
    lea edi, [eax + MON_MOVES]
    mov cl, NUM_MOVES
.known:
    mov al, [ebp + edi]
    cmp al, dl
    je .restore
    inc edi
    dec cl
    jnz .known
    ; pret LearnMoveFromLevelUp (evos_moves.asm) delegates slot-find/write/PP/
    ; battle-sync/display to `predef LearnMove` — the faithful teach-flow module
    ; (src/engine/pokemon/learn_move.asm). This replaces the old inline free-slot
    ; scan that silently dropped the move (no message at all) when all 4 slots
    ; were already full; LearnMove's DontAbandonLearning now handles that case
    ; too (see its header for the current deferred-UI scope).
    mov [ebp + wMoveNum], dl
    mov [ebp + wNamedObjectIndex], dl
    call GetMoveName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    call LearnMove                      ; -> BH: 0 = not learned, 1 = learned
    test bh, bh
    jz .restore
    ; Yellow: if the leveling mon is the player's starter Pikachu and the move it
    ; just learned is THUNDER/THUNDERBOLT, bump its mood/emotion. Faithful to pret
    ; evos_moves.asm LearnMoveFromLevelUp (.foundThunderOrThunderbolt). Only the
    ; learned path reaches here — the "already known" / "slots full" paths jump
    ; straight to .restore and skip this.
    movzx eax, byte [ebp + wMoveNum]
    cmp al, THUNDERBOLT
    je .pikachuThunderMove
    cmp al, THUNDER
    jne .restore
.pikachuThunderMove:
    call IsThisPartyMonStarterPikachu   ; uses [wWhichPokemon]; CF set if starter
    jnc .restore
    mov al, 5
    mov [ebp + wPikachuEmotionModifier], al
    mov al, 0x85
    mov [ebp + wPikachuMood], al
.restore:
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wPokedexNum], al
    ret

; PrintStatsBox — pret PrintStatsBox.LevelUpStatsBox: box + ATTACK/DEFENSE/SPEED/SPECIAL
; with right-aligned values from the leveled party mon (CalcStats wrote the new stats).
PrintStatsBox:
    and byte [ebp + W_LETTER_PRINTING_DELAY], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov dword [menu_item_step], FW
    mov esi, W_TILEMAP + LVLBOX_OFF
    mov bh, LVLBOX_H
    mov bl, LVLBOX_W
    call TextBoxBorder
    movzx eax, byte [ebp + wWhichPokemon]
    imul eax, eax, PARTYMON_STRUCT_LENGTH
    add eax, wPartyMon1
    mov [lvl_mon_ptr], eax
    mov esi, W_TILEMAP + LVL_LBL_OFF
    mov eax, str_attack
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + LVL_LBL_OFF + 2 * FW
    mov eax, str_defense
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + LVL_LBL_OFF + 4 * FW
    mov eax, str_speed
    call PlaceString
    mov esi, ebx
    mov esi, W_TILEMAP + LVL_LBL_OFF + 6 * FW
    mov eax, str_special
    call PlaceString
    mov esi, ebx
    mov ebx, [lvl_mon_ptr]
    mov edi, W_TILEMAP + LVL_VAL_OFF
    movzx eax, byte [ebp + ebx + MON_ATK]
    shl eax, 8
    mov al, [ebp + ebx + MON_ATK + 1]
    call print_num3
    mov ebx, [lvl_mon_ptr]
    mov edi, W_TILEMAP + LVL_VAL_OFF + 2 * FW
    movzx eax, byte [ebp + ebx + MON_DEF]
    shl eax, 8
    mov al, [ebp + ebx + MON_DEF + 1]
    call print_num3
    mov ebx, [lvl_mon_ptr]
    mov edi, W_TILEMAP + LVL_VAL_OFF + 4 * FW
    movzx eax, byte [ebp + ebx + MON_SPD]
    shl eax, 8
    mov al, [ebp + ebx + MON_SPD + 1]
    call print_num3
    mov ebx, [lvl_mon_ptr]
    mov edi, W_TILEMAP + LVL_VAL_OFF + 6 * FW
    movzx eax, byte [ebp + ebx + MON_SPC]
    shl eax, 8
    mov al, [ebp + ebx + MON_SPC + 1]
    call print_num3
    ret

; get_party_nick — EAX = flat ptr to the wWhichPokemon party nick.
get_party_nick:
    movzx eax, byte [ebp + wWhichPokemon]
    imul eax, eax, NAME_LENGTH
    lea eax, [ebp + eax + wPartyMonNicks]
    ret

; print_num3 — EAX (0..999) → 3-digit right-aligned, space-padded, at [ebp+EDI..EDI+2].
print_num3:
    push ebx
    mov ebx, 10
    xor edx, edx
    div ebx
    add dl, CHAR_DIG0
    mov [ebp + edi + 2], dl
    xor edx, edx
    div ebx
    test eax, eax
    jnz .tens
    test edx, edx
    jnz .tens
    mov byte [ebp + edi + 1], 0x7F
    jmp .hund
.tens:
    add dl, CHAR_DIG0
    mov [ebp + edi + 1], dl
.hund:
    test eax, eax
    jnz .hundDigit
    mov byte [ebp + edi], 0x7F
    jmp .num3done
.hundDigit:
    add al, CHAR_DIG0
    mov [ebp + edi], al
.num3done:
    pop ebx
    ret

; print_dec — EAX = value → decimal at [ebp+EDI], no leading zeros, EDI advanced.
print_dec:
    mov ebx, 10
    xor ecx, ecx
.div:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .div
.emit:
    pop edx
    add dl, CHAR_DIG0
    mov [ebp + edi], dl
    inc edi
    push ecx
    push edi
    call PrintLetterDelay
    pop edi
    pop ecx
    dec ecx
    jnz .emit
    ret

; ===========================================================================
; Move list helpers (called by core.asm's MoveSelectionMenu).
; ===========================================================================

; FindMoveName — AL = move id (1-based). Out: EAX = flat ptr to that move's name in
; MoveNames ('@'=0x50-terminated, move-id order). Clobbers ECX, EDX.
FindMoveName:
    movzx ecx, al
    mov eax, MoveNames
    dec ecx
.skip:
    jecxz .done
.scan:
    mov dl, [eax]
    inc eax
    cmp dl, 0x50
    jne .scan
    dec ecx
    jmp .skip
.done:
    ret

; PrintMoveInfoBox — the TYPE/PP box for the highlighted move (pret PrintMenuItem). Drawn
; each cursor move via the menu_redraw_cb hook. Reads wCurrentMenuItem, wBattleMonMoves/PP,
; and the flat Moves table (type @ +3, base PP @ +5). In: EBP = GB base.
PrintMoveInfoBox:
    and byte [ebp + W_LETTER_PRINTING_DELAY], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov dword [menu_item_step], FW
    mov esi, W_TILEMAP + INFOBOX_OFF
    mov bh, 3
    mov bl, 9
    call TextBoxBorder
    mov esi, W_TILEMAP + ((IB_ROW + 1) * FW + IB_COL + 1)
    mov eax, str_type
    call PlaceString
    mov esi, ebx
    mov byte [ebp + W_TILEMAP + ((IB_ROW + 1) * FW + IB_COL + 5)], CHAR_SLASH
    movzx eax, byte [ebp + wCurrentMenuItem]
    movzx eax, byte [ebp + eax + wBattleMonMoves]
    dec eax
    imul eax, eax, MOVE_LENGTH
    movzx ecx, byte [Moves + eax + 3]
    push eax
    mov esi, W_TILEMAP + ((IB_ROW + 2) * FW + IB_COL + 2)
    mov eax, [WideTypeNames + ecx * 4]
    call PlaceString
    mov esi, ebx
    pop eax
    movzx ecx, byte [Moves + eax + 5]
    push ecx
    movzx ecx, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + ecx + wBattleMonPP]
    and al, 0x3F
    mov edi, W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 5)
    call print_2d
    mov byte [ebp + W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 7)], CHAR_SLASH
    pop eax
    mov edi, W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 8)
    call print_2d
    ret

; print_2d — AL = value (<100) as 2 digits at [ebp+EDI] (leading space if tens=0).
print_2d:
    movzx eax, al
    xor edx, edx
    mov ecx, 10
    div ecx
    test al, al
    jnz .tens
    mov byte [ebp + edi], 0x7F
    jmp .ones
.tens:
    add al, CHAR_DIG0
    mov [ebp + edi], al
.ones:
    add dl, CHAR_DIG0
    mov [ebp + edi + 1], dl
    ret

; ===========================================================================
; DEBUG_BATTLE_ENEMYHIT ground-truth scaffold (NOT the live battle path).
; ===========================================================================
; DoEnemyAttackDamage — run the faithful Gen-1 damage pipeline for the enemy's selected
; move and subtract wDamage from the player mon's HP (floored). Used only by the static
; DEBUG_BATTLE_ENEMYHIT WRAM-dump harness; the live battle resolves moves via core.asm.
DoEnemyAttackDamage:
    mov byte [ebp + hWhoseTurn], 1
    call GetCurrentMove
    mov byte [ebp + wCriticalHitOrOHKO], 0
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    jz .apply
    call AdjustDamageForMoveType
    call RandomizeDamage
.apply:
    movzx eax, byte [ebp + wBattleMonHP]
    shl eax, 8
    mov al, [ebp + wBattleMonHP + 1]
    movzx ecx, byte [ebp + wDamage]
    shl ecx, 8
    mov cl, [ebp + wDamage + 1]
    sub eax, ecx
    jns .store
    xor eax, eax
.store:
    mov [ebp + wBattleMonHP + 1], al
    shr eax, 8
    mov [ebp + wBattleMonHP], al
    ret
