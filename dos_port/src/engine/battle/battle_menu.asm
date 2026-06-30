; battle_menu.asm — the FIGHT / PKMN / ITEM / RUN battle menu (Wave 2, Stage 2a).
;
; Faithful port of pret's DisplayBattleMenu (engine/battle/core.asm) +
; BATTLE_MENU_TEMPLATE (data/text_boxes.asm), built on the stride-40 primitives in
; src/text/wide_text.asm (WideTextBoxBorder / WidePlaceString / WideHandleMenuInput,
; the wide-canvas mirrors of TextBoxBorder / PlaceString / HandleMenuInput).
;
; Flow (mirrors DisplayBattleMenu): clear the announcement text from the dialog box
; (pret PrintEmptyString) → draw the smaller menu box over it (pret DisplayTextBoxID
; with BATTLE_MENU_TEMPLATE = TextBoxBorder(8,12,19,17) + PlaceString(BattleMenuText,
; 10,14)) → two-column input: HandleMenuInput per column (UP/DOWN + A), LEFT/RIGHT
; switch columns. Right-column A adds 2 to the item id; then the gen-1 ITEM/PKMN id
; swap. Centered (+10 col, +3 row) onto the 40x25 canvas.
;
; Menu item ids after the swap: 0=FIGHT 1=PKMN 2=ITEM 3=RUN.  FIGHT/PKMN/ITEM/RUN
; dispatch is Stage 2b; for now A returns the id and the caller re-enters.
;
; Register map: A=AL, BC=BX, EBP=GB base; GB memory = [EBP+addr].
;
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

%define FW   SCREEN_TILES_W            ; 40 — W_TILEMAP stride
%define T_SP 0x7F

; Box: pret BATTLE_MENU_TEMPLATE 8,12,19,17 → canvas top-left (18,15), interior
; 10×4 (x2-x1-1 by y2-y1-1). Text at GB(10,14) → canvas (20,17).
%define BOX_OFF      (15 * FW + 18)
%define BOX_W        10
%define BOX_H        4
%define TEXT_OFF     (17 * FW + 20)
; Outer dialog box (InitBattle box): canvas (10,15), interior 18×4. Redrawn here
; each time so any leftover move-box borders/corners are wiped (the port-side
; equivalent of pret's LoadScreenTilesFromBuffer1 screen-restore on menu redraw).
%define OUTER_OFF    (15 * FW + 10)
%define OUTER_W      18
%define OUTER_H      4
; Cursor columns: GB left x=9 / right x=15 → canvas 19 / 25. Top item row = 17.
%define CUR_COL_L    19
%define CUR_COL_R    25
%define MENU_ROW_TOP 17

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
str_used:  db 0xB4,0xB2,0xA4,0xA3,0x7F, 0x50   ; "used "
str_excl:  db 0xE7, 0x50                        ; "!"
str_type:  db 0x93,0x98,0x8F,0x84, 0x50         ; "TYPE"
str_enemy: db 0x84,0xAD,0xA4,0xAC,0xB8,0x7F, 0x50          ; "Enemy "
str_fainted: db 0xA5,0xA0,0xA8,0xAD,0xB3,0xA4,0xA3,0xE7, 0x50  ; "fainted!"

section .bss
menu_saved: resb 1                        ; remembered item across opens (pret wBattleAndStartSavedMenuItem)
move_count: resb 1                        ; number of real moves listed
; Battle terminal state (Stage 2c): 0 = ongoing, 1 = player won (enemy fainted),
; 2 = player lost (active mon fainted). The harness resets it at battle start, the
; round handler sets it on a faint, and DisplayBattleMenu breaks its loop on it.
global wBattleOver
wBattleOver: resb 1
; blinking-▼ text-advance arrow state (WaitForAPress)
arrow_timer: resb 1
arrow_on:    resb 1
; Saved "clean" battle screen (HUDs + sprites + dialog box, no menus) — the port's
; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1. Restored when (re)entering
; the main menu so transient overlays (move box, TYPE/PP box) are wiped.
screen_save: resb SCREEN_AREA

section .text

global DisplayBattleMenu
global DrawBattleMenu
global DrawMoveList
global PrintMoveInfoBox
global SaveBattleScreen
global RestoreBattleScreen
global EndBattleScreen
global WaitForAPress
global DoPlayerAttackDamage
global DoEnemyAttackDamage
global RenderPlayerTurn
extern WideTextBoxBorder
extern WidePlaceString
extern WideHandleMenuInput
extern wide_line_step
extern wide_menu_redraw_cb
extern MoveNames
extern Moves
extern WideTypeNames
extern DelayFrame
extern DrawBattleHUDs
extern AnimateEnemyHPBar
extern AnimatePlayerHPBar
extern GetCurrentMove
extern GetDamageVarsForPlayerAttack
extern GetDamageVarsForEnemyAttack
extern SelectEnemyMove
extern CalculateDamage
extern AdjustDamageForMoveType
extern RandomizeDamage
extern BattleRandom

; TYPE/PP info box: pret PrintMenuItem TextBoxBorder(0,8) 9×3. GB-centered would be
; (10,11), but its right wall (col 20) clips the player HUD name there, so it is
; nudged 1 col left to IB_COL=9 (right wall col 19, clearing the HUD). Layout offsets
; are pret-relative to the box origin: "TYPE/" (+1,+1)/(+5,+1), type name (+2,+2),
; "cur/max" PP (+5,+3)/(+7,+3)/(+8,+3).
%define IB_COL        9
%define IB_ROW        11
%define INFOBOX_OFF   (IB_ROW * FW + IB_COL)
%define CHAR_SLASH    0xF3
%define CHAR_DIG0     0xF6

; Move-list box: pret regular menu TextBoxBorder(4,12) 14×4 → canvas (14,15);
; moves at GB(6,13) → canvas (16,16), single-spaced; cursor col 15.
%define MOVEBOX_OFF   (15 * FW + 14)
%define MOVEBOX_W     14
%define MOVEBOX_H     4
%define MOVES_TEXT    (16 * FW + 16)
%define MOVES_ROW0    16
%define MOVES_CUR_COL 15

; ---------------------------------------------------------------------------
; DrawBattleMenu — clear the announcement text and draw the menu box + labels
; (no input). In: EBP = GB base. Preserves nothing of note.
; ---------------------------------------------------------------------------
DrawBattleMenu:
    mov dword [wide_line_step], 2 * FW
    ; Redraw the full outer dialog box: clears the announcement text (PrintEmptyString)
    ; AND overwrites any leftover move-box borders/corners from a closed FIGHT submenu.
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call WideTextBoxBorder
    ; DisplayTextBoxID(BATTLE_MENU_TEMPLATE): the smaller menu box (divider) + text
    mov esi, W_TILEMAP + BOX_OFF
    mov bh, BOX_H
    mov bl, BOX_W
    call WideTextBoxBorder
    mov esi, W_TILEMAP + TEXT_OFF
    mov eax, BattleMenuText
    call WidePlaceString
    ret

; ---------------------------------------------------------------------------
; DisplayBattleMenu — draw the menu and run the two-column input loop. Returns
; AL = selected menu id (0=FIGHT 1=PKMN 2=ITEM 3=RUN). In: EBP = GB base.
; ---------------------------------------------------------------------------
; SaveBattleScreen — snapshot the clean battle screen (W_TILEMAP) for later restore.
; RestoreBattleScreen — put it back, wiping any transient menu/info overlays.
SaveBattleScreen:
    lea esi, [ebp + W_TILEMAP]
    mov edi, screen_save
    mov ecx, SCREEN_AREA
    rep movsb
    ret
RestoreBattleScreen:
    mov esi, screen_save
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    rep movsb
    ret

; EndBattleScreen — clean battle terminal (Stage 2c): blank the whole canvas and
; present it, so when the loop ends the HUD/menu/sprites clear instead of the menu
; re-appearing. Placeholder for the real exit — Stage 3 returns to the overworld
; (and runs the victory EXP screen via the Wave-1 GainExperience). In: EBP = GB base.
EndBattleScreen:
    lea edi, [ebp + W_TILEMAP]
    mov ecx, SCREEN_AREA
    mov al, T_SP                          ; blank tile
    rep stosb
    call DelayFrame                       ; present the cleared screen
    ret

DisplayBattleMenu:
    ; pret DisplayBattleMenu: LoadScreenTilesFromBuffer1 → DrawHUDsAndHPBars →
    ; SaveScreenTilesToBuffer1. Redrawing the HUDs with the CURRENT HP and re-saving
    ; is what keeps a drained HP bar drained (the snapshot would otherwise hold the
    ; battle-start full bar and "refill" it each time the menu reappears).
    call RestoreBattleScreen              ; restore clean screen (sprites + dialog box)
    call DrawBattleHUDs                   ; redraw HUDs with current HP
    call SaveBattleScreen                 ; re-snapshot so the drained HP persists
    call DrawBattleMenu
    ; restore the saved selection; sub 2 → negative = left column, else right
    mov al, [menu_saved]
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    sub al, 2
    jc .leftColumn
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    jmp .rightColumn

.leftColumn:
    ; clear the right-column cursor cells, then watch RIGHT|A
    mov byte [ebp + W_TILEMAP + MENU_ROW_TOP * FW + CUR_COL_R], T_SP
    mov byte [ebp + W_TILEMAP + (MENU_ROW_TOP + 2) * FW + CUR_COL_R], T_SP
    mov byte [ebp + wTopMenuItemX], CUR_COL_L
    mov byte [ebp + wTopMenuItemY], MENU_ROW_TOP
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_RIGHT | PAD_A
    call WideHandleMenuInput
    test al, PAD_RIGHT
    jnz .rightColumn
    jmp .selected                        ; A pressed (left column id 0/1)

.rightColumn:
    ; clear the left-column cursor cells, then watch LEFT|A
    mov byte [ebp + W_TILEMAP + MENU_ROW_TOP * FW + CUR_COL_L], T_SP
    mov byte [ebp + W_TILEMAP + (MENU_ROW_TOP + 2) * FW + CUR_COL_L], T_SP
    mov byte [ebp + wTopMenuItemX], CUR_COL_R
    mov byte [ebp + wTopMenuItemY], MENU_ROW_TOP
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_LEFT | PAD_A
    call WideHandleMenuInput
    test al, PAD_LEFT
    jnz .leftColumn
    mov al, [ebp + wCurrentMenuItem]     ; A pressed in right column → id += 2
    add al, 2
    mov [ebp + wCurrentMenuItem], al

.selected:
    mov al, [ebp + wCurrentMenuItem]
    mov [menu_saved], al
    ; gen-1 ITEM/PKMN id swap (English versions swapped their on-screen positions)
    cmp al, 1
    jne .notItem
    inc al                               ; ITEM 1 → 2
    jmp .dispatch
.notItem:
    cmp al, 2
    jne .dispatch
    dec al                               ; PKMN 2 → 1
.dispatch:
    ; AL = 0 FIGHT / 1 PKMN / 2 ITEM / 3 RUN. Only FIGHT is wired (Stage 2a); the
    ; rest are Stage 2b/3 stubs (return the id, caller re-enters).
    test al, al
    jnz .ret
    call MoveSelectionMenu               ; FIGHT → move list (B returns here)
    cmp byte [wBattleOver], 0            ; a faint this round ends the battle
    jne .ret
    jmp DisplayBattleMenu                ; redraw the main menu and continue
.ret:
    ret

; ---------------------------------------------------------------------------
; MoveSelectionMenu — the player's move list (faithful to the regular-battle path
; of pret MoveSelectionMenu). Copies wBattleMonMoves → wMoves, FormatMovesString,
; draws the move box, lists the moves (single-spaced) and runs the cursor.
; A selects a move (Stage 2b stub), B returns. In: EBP = GB base.
; ---------------------------------------------------------------------------
MoveSelectionMenu:
    call DrawMoveList
    mov al, [move_count]
    test al, al
    jz .back                              ; no moves (defensive)
    mov dword [wide_menu_redraw_cb], PrintMoveInfoBox   ; refresh TYPE/PP on cursor move
    call WideHandleMenuInput
    mov dword [wide_menu_redraw_cb], 0
    ; remember the cursor position (pret writes wPlayerMoveListIndex on BOTH select and
    ; back, core.asm:2745 — so leaving the menu either way preserves it for next time).
    mov dl, [ebp + wCurrentMenuItem]
    mov [ebp + wPlayerMoveListIndex], dl
    test al, PAD_B
    jnz .back
    ; A: store the selected move and run the (Stage-2b-start) attack text
    movzx eax, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + eax + wBattleMonMoves]
    mov [ebp + wPlayerSelectedMove], al
    call ExecutePlayerTurn
.back:
    ret

; ---------------------------------------------------------------------------
; ExecutePlayerTurn — Stage 2b: run one full battle round (both battlers act once),
; ordered by speed (pret MainInBattle / ExecutePlayerMove + ExecuteEnemyMove). The
; player's move is already in wPlayerSelectedMove; the enemy's move is chosen here
; (slot 0 for now — trainer AI / random selection deferred). Faster battler attacks
; first; if its target faints the round ends (the fainted mon does not retaliate).
;
; Turn-order quirks deferred: Quick Attack / Counter priority and the random
; speed-tie break (pret compares speeds and rolls BattleRandom on a tie). Here a
; tie goes to the player. In: [wPlayerSelectedMove] set; EBP = GB base.
; ---------------------------------------------------------------------------
ExecutePlayerTurn:
    ; choose the enemy's move (wild random-move AI; also the default for trainers
    ; for now — see select_enemy_move.asm).
    call SelectEnemyMove
    ; turn order (faithful pret ExecutePlayerMove ordering, core.asm:.noLinkBattle):
    ; Quick Attack takes priority; Counter always moves last; otherwise compare speed,
    ; with a 50/50 random break on a tie.
    mov al, [ebp + wPlayerSelectedMove]
    cmp al, QUICK_ATTACK
    jne .pNotQuickAttack
    mov al, [ebp + wEnemySelectedMove]
    cmp al, QUICK_ATTACK
    je .compareSpeed                      ; both Quick Attack → speed
    jmp .playerFirst                      ; only player → player first
.pNotQuickAttack:
    mov al, [ebp + wEnemySelectedMove]
    cmp al, QUICK_ATTACK
    je .enemyFirst                        ; only enemy → enemy first
    mov al, [ebp + wPlayerSelectedMove]
    cmp al, COUNTER
    jne .pNotCounter
    mov al, [ebp + wEnemySelectedMove]
    cmp al, COUNTER
    je .compareSpeed                      ; both Counter → speed
    jmp .enemyFirst                       ; only player used Counter → Counter goes last
.pNotCounter:
    mov al, [ebp + wEnemySelectedMove]
    cmp al, COUNTER
    je .playerFirst                       ; only enemy used Counter → player first
.compareSpeed:
    movzx eax, byte [ebp + wBattleMonSpeed]
    shl eax, 8
    mov al, [ebp + wBattleMonSpeed + 1]
    movzx ecx, byte [ebp + wEnemyMonSpeed]
    shl ecx, 8
    mov cl, [ebp + wEnemyMonSpeed + 1]
    cmp eax, ecx
    ja .playerFirst                       ; player faster
    jb .enemyFirst                        ; enemy faster
    ; speed tie → 50/50. (pret's internal-clock invert is link-only: TODO-HW Phase 4.)
    call BattleRandom
    cmp al, (50 * 0xFF / 100) + 1         ; pret `50 percent + 1` = 128
    jb .playerFirst
    jmp .enemyFirst
.playerFirst:
    call PlayerAttackStep
    jc .enemyFainted                      ; enemy fainted → player wins, round ends
    call EnemyAttackStep
    jc .playerFainted                     ; player mon fainted → round ends
    ret
.enemyFirst:
    call EnemyAttackStep
    jc .playerFainted
    call PlayerAttackStep
    jc .enemyFainted
    ret
.enemyFainted:
    mov byte [wBattleOver], 1             ; victory
    ret
.playerFainted:
    ; active mon fainted. Multi-mon switch-in (pret: pick another party mon) is
    ; deferred — for now any active-mon faint ends the battle as a loss.
    mov byte [wBattleOver], 2             ; defeat
    ret

; PlayerAttackStep — the player's move resolves: render the attack (damage + HUD +
; text), wait for A, then faint-check the enemy. Returns CF=1 if the enemy fainted
; (the battle-ending case), CF=0 otherwise.
PlayerAttackStep:
    call RenderPlayerTurn
    call WaitForAPress
    mov al, [ebp + wEnemyMonHP]
    or al, [ebp + wEnemyMonHP + 1]
    jnz .alive
    call ShowEnemyFainted                 ; pret FaintEnemyPokemon (victory flow TBD)
    stc
    ret
.alive:
    clc
    ret

; EnemyAttackStep — the enemy's move resolves (mirror of PlayerAttackStep). Returns
; CF=1 if the player mon fainted, CF=0 otherwise.
EnemyAttackStep:
    call RenderEnemyTurn
    call WaitForAPress
    mov al, [ebp + wBattleMonHP]
    or al, [ebp + wBattleMonHP + 1]
    jnz .alive
    call ShowPlayerFainted
    stc
    ret
.alive:
    clc
    ret

; ShowEnemyFainted — "Enemy <nick> / fainted!" in the dialog box, then wait for A.
ShowEnemyFainted:
    mov dword [wide_line_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call WideTextBoxBorder
    mov esi, W_TILEMAP + (17 * FW + 11)   ; "Enemy " + nick
    mov eax, str_enemy
    call WidePlaceString
    lea eax, [ebp + wEnemyMonNick]
    call WidePlaceString
    mov esi, W_TILEMAP + (19 * FW + 11)   ; "fainted!"
    mov eax, str_fainted
    call WidePlaceString
    call WaitForAPress
    ret

; ShowPlayerFainted — "<nick> / fainted!" (no "Enemy " prefix), then wait for A.
ShowPlayerFainted:
    mov dword [wide_line_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call WideTextBoxBorder
    mov esi, W_TILEMAP + (17 * FW + 11)   ; player nick
    lea eax, [ebp + wBattleMonNick]
    call WidePlaceString
    mov esi, W_TILEMAP + (19 * FW + 11)   ; "fainted!"
    mov eax, str_fainted
    call WidePlaceString
    call WaitForAPress
    ret

RenderPlayerTurn:
    call RestoreBattleScreen              ; wipe the move box + TYPE/PP box first
    call DrawBattleHUDs                   ; HUDs at PRE-attack HP (damage applied below)
    mov dword [wide_line_step], 2 * FW
    ; redraw the dialog box (clears the move menu)
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call WideTextBoxBorder
    ; line 1: the attacking mon's name
    mov esi, W_TILEMAP + (17 * FW + 11)
    lea eax, [ebp + wBattleMonNick]
    call WidePlaceString
    ; line 2: "used " + move name + "!"
    mov esi, W_TILEMAP + (19 * FW + 11)
    mov eax, str_used
    call WidePlaceString
    mov al, [ebp + wPlayerSelectedMove]
    call FindMoveName                     ; EAX = move-name ptr (ESI preserved)
    call WidePlaceString
    mov eax, str_excl
    call WidePlaceString
    ; capture the enemy's pre-hit HP, apply damage, then animate the bar draining
    movzx ecx, byte [ebp + wEnemyMonHP]
    shl ecx, 8
    mov cl, [ebp + wEnemyMonHP + 1]
    push ecx
    call DoPlayerAttackDamage             ; faithful damage calc → enemy HP
    pop ecx                               ; ECX = old enemy HP
    call AnimateEnemyHPBar
    ret

; RenderEnemyTurn — mirror of RenderPlayerTurn for the enemy's move: restore the
; clean screen, apply the enemy's damage to the player mon, redraw the HUDs (player
; HP bar now reflects it), and print "Enemy <nick> / used <move>!" (pret <USER> =
; "Enemy " + nick on the enemy's turn — see home/text.asm:PlaceMoveUsersName).
RenderEnemyTurn:
    call RestoreBattleScreen              ; wipe any transient overlay first
    call DrawBattleHUDs                   ; HUDs at PRE-attack HP (damage applied below)
    mov dword [wide_line_step], 2 * FW
    ; redraw the dialog box
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call WideTextBoxBorder
    ; line 1: "Enemy " + enemy nick (chained on one line; WidePlaceString returns end ESI)
    mov esi, W_TILEMAP + (17 * FW + 11)
    mov eax, str_enemy
    call WidePlaceString
    lea eax, [ebp + wEnemyMonNick]
    call WidePlaceString
    ; line 2: "used " + move name + "!"
    mov esi, W_TILEMAP + (19 * FW + 11)
    mov eax, str_used
    call WidePlaceString
    mov al, [ebp + wEnemySelectedMove]
    call FindMoveName
    call WidePlaceString
    mov eax, str_excl
    call WidePlaceString
    ; capture the player's pre-hit HP, apply damage, then animate the bar draining
    movzx ecx, byte [ebp + wBattleMonHP]
    shl ecx, 8
    mov cl, [ebp + wBattleMonHP + 1]
    push ecx
    call DoEnemyAttackDamage              ; faithful damage calc → player HP
    pop ecx                               ; ECX = old player HP
    call AnimatePlayerHPBar
    ret

; ---------------------------------------------------------------------------
; DoEnemyAttackDamage — the faithful Gen-1 damage pipeline for the enemy's selected
; move (mirror of DoPlayerAttackDamage; pret ExecuteEnemyMove core): GetCurrentMove
; → GetDamageVarsForEnemyAttack → CalculateDamage → (if BP>0) AdjustDamageForMoveType
; → RandomizeDamage. Subtracts wDamage from the player mon's HP (floored at 0).
; Accuracy/MoveHitTest deferred (always hits); crit forced off. In: [wEnemySelectedMove]
; set; EBP = GB base.
; ---------------------------------------------------------------------------
DoEnemyAttackDamage:
    mov byte [ebp + hWhoseTurn], 1
    call GetCurrentMove                   ; enemy move → wEnemyMove*
    mov byte [ebp + wCriticalHitOrOHKO], 0
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    jz .apply                             ; 0-BP move → wDamage stays 0
    call AdjustDamageForMoveType
    call RandomizeDamage
.apply:
    ; wBattleMonHP (big-endian) -= wDamage (big-endian), floor at 0
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
    mov [ebp + wBattleMonHP + 1], al      ; low byte
    shr eax, 8
    mov [ebp + wBattleMonHP], al          ; high byte
    ret

; WaitForAPress — wait for A/B to advance text, blinking the ▼ "more text" arrow at
; the dialog box's bottom-right interior cell, faithful to WaitForTextScrollButtonPress
; / HandleDownArrowBlinkTiming (pret toggles the '▼' tile vs a space while waiting).
; The exact GB blink counters produce a moderate cadence; the port toggles every
; ARROW_BLINK_FRAMES frames. Erases the arrow on exit. In: EBP = GB base.
%define ARROW_OFF          (19 * FW + 28)   ; dialog-box bottom-right interior (canvas 28,19)
%define T_DOWNARROW        0xEE             ; charmap "▼"
%define ARROW_BLINK_FRAMES 20
WaitForAPress:
    mov byte [arrow_on], 1
    mov byte [arrow_timer], ARROW_BLINK_FRAMES
    mov byte [ebp + W_TILEMAP + ARROW_OFF], T_DOWNARROW
.wait:
    dec byte [arrow_timer]
    jnz .present
    mov byte [arrow_timer], ARROW_BLINK_FRAMES
    xor byte [arrow_on], 1
    jz .arrowOff
    mov byte [ebp + W_TILEMAP + ARROW_OFF], T_DOWNARROW
    jmp .present
.arrowOff:
    mov byte [ebp + W_TILEMAP + ARROW_OFF], T_SP
.present:
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jz .wait
    mov byte [ebp + W_TILEMAP + ARROW_OFF], T_SP   ; erase the arrow on advance
    ret

; ---------------------------------------------------------------------------
; DoPlayerAttackDamage — the faithful Gen-1 damage pipeline for the player's
; selected move (pret ExecutePlayerMove core): GetCurrentMove → GetDamageVarsFor-
; PlayerAttack → CalculateDamage → (if BP>0) AdjustDamageForMoveType (STAB +
; type) → RandomizeDamage. Subtracts wDamage from the enemy's HP (floored at 0).
; Status moves (0 BP, e.g. GROWL) leave wDamage=0. Accuracy/MoveHitTest deferred
; (always hits); crit forced off. In: [wPlayerSelectedMove] set; EBP = GB base.
; ---------------------------------------------------------------------------
DoPlayerAttackDamage:
    mov byte [ebp + hWhoseTurn], 0
    call GetCurrentMove                   ; selected move → wPlayerMove*
    mov byte [ebp + wCriticalHitOrOHKO], 0
    call GetDamageVarsForPlayerAttack
    call CalculateDamage
    jz .apply                             ; 0-BP move → wDamage stays 0
    call AdjustDamageForMoveType
    call RandomizeDamage
.apply:
    ; wEnemyMonHP (big-endian) -= wDamage (big-endian), floor at 0
    movzx eax, byte [ebp + wEnemyMonHP]
    shl eax, 8
    mov al, [ebp + wEnemyMonHP + 1]
    movzx ecx, byte [ebp + wDamage]
    shl ecx, 8
    mov cl, [ebp + wDamage + 1]
    sub eax, ecx
    jns .store
    xor eax, eax
.store:
    mov [ebp + wEnemyMonHP + 1], al       ; low byte
    shr eax, 8
    mov [ebp + wEnemyMonHP], al           ; high byte
    ret

; ---------------------------------------------------------------------------
; DrawMoveList — draw the move box, list the player's moves (one per row, "-" for
; empty), and set up the menu vars (no input). In: EBP = GB base.
; ---------------------------------------------------------------------------
DrawMoveList:
    mov dword [wide_line_step], FW        ; single-spaced list
    mov esi, W_TILEMAP + MOVEBOX_OFF
    mov bh, MOVEBOX_H
    mov bl, MOVEBOX_W
    call WideTextBoxBorder
    ; list the 4 move slots: a name per real move, "-" for empty
    mov byte [move_count], 0
    xor ebx, ebx                          ; bl = slot 0..3
.movloop:
    movzx eax, bl
    mov cl, [ebp + eax + wBattleMonMoves] ; move id (cl; FindMoveName preserves CL? no — keep in stack-safe reg)
    movzx esi, bl
    imul esi, esi, FW
    add esi, W_TILEMAP + MOVES_TEXT       ; dest row = MOVES_TEXT + slot*FW
    test cl, cl
    jz .dash
    inc byte [move_count]
    mov al, cl
    call FindMoveName                     ; AL=id → EAX=flat name ptr
    call WidePlaceString                  ; EAX=src, ESI=dest
    jmp .movnext
.dash:
    mov byte [ebp + esi], 0xE3            ; '-'
.movnext:
    inc bl
    cmp bl, NUM_MOVES
    jb .movloop
    ; cursor over the real moves only
    mov al, [move_count]
    test al, al
    jz .dml_ret
    dec al
    mov [ebp + wMaxMenuItem], al
    mov byte [ebp + wTopMenuItemY], MOVES_ROW0
    mov byte [ebp + wTopMenuItemX], MOVES_CUR_COL
    ; restore the remembered cursor (pret inits wCurrentMenuItem from wPlayerMoveListIndex,
    ; so the FIGHT menu reopens on the last move used/highlighted). Clamp to the real
    ; move count in case the index is stale (fewer moves on this mon).
    mov al, [ebp + wPlayerMoveListIndex]
    cmp al, [move_count]
    jb .idxInRange
    xor al, al                            ; out of range → first move
.idxInRange:
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    ; UP/DOWN are handled inside WideHandleMenuInput (it moves the cursor and loops),
    ; so only A/B end the menu — watching UP/DOWN would exit on every cursor move.
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
.dml_ret:
    ret

; ---------------------------------------------------------------------------
; FindMoveName — in AL = move id (1-based). Out: EAX = flat ptr to that move's
; name in MoveNames (variable-length, '@'=0x50-terminated, move-id order).
; Clobbers ECX, EDX. (Self-contained walk; the faithful GetName/FormatMovesString
; path is deferred until the battle-backend name closure links.)
; ---------------------------------------------------------------------------
FindMoveName:
    movzx ecx, al
    mov eax, MoveNames
    dec ecx                               ; skip (id-1) names
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

; ---------------------------------------------------------------------------
; PrintMoveInfoBox — the TYPE/PP box for the highlighted move (pret PrintMenuItem).
; Drawn each cursor move via the wide_menu_redraw_cb hook. Reads wCurrentMenuItem,
; wBattleMonMoves/PP, and the flat Moves table (type @ +3, base PP @ +5).
; Max PP is the base value (PP-up GetMaxPP scaling is deferred). In: EBP = GB base.
; ---------------------------------------------------------------------------
PrintMoveInfoBox:
    mov dword [wide_line_step], FW
    mov esi, W_TILEMAP + INFOBOX_OFF      ; box interior 9×3
    mov bh, 3
    mov bl, 9
    call WideTextBoxBorder
    mov esi, W_TILEMAP + ((IB_ROW + 1) * FW + IB_COL + 1)   ; "TYPE/"
    mov eax, str_type
    call WidePlaceString
    mov byte [ebp + W_TILEMAP + ((IB_ROW + 1) * FW + IB_COL + 5)], CHAR_SLASH
    ; move data offset = (id-1) * MOVE_LENGTH  (flat Moves table)
    movzx eax, byte [ebp + wCurrentMenuItem]
    movzx eax, byte [ebp + eax + wBattleMonMoves]
    dec eax
    imul eax, eax, MOVE_LENGTH
    ; type name at canvas (12,13)
    movzx ecx, byte [Moves + eax + 3]
    push eax
    mov esi, W_TILEMAP + ((IB_ROW + 2) * FW + IB_COL + 2)   ; type name
    mov eax, [WideTypeNames + ecx * 4]
    call WidePlaceString
    pop eax
    ; PP "cur/max" on row IB_ROW+3
    movzx ecx, byte [Moves + eax + 5]     ; max PP (base)
    push ecx
    movzx ecx, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + ecx + wBattleMonPP]
    and al, 0x3F                          ; PP_MASK
    mov edi, W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 5)   ; curPP
    call print_2d
    mov byte [ebp + W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 7)], CHAR_SLASH
    pop eax                               ; max PP
    mov edi, W_TILEMAP + ((IB_ROW + 3) * FW + IB_COL + 8)   ; maxPP
    call print_2d
    ret

; print_2d — AL = value (<100) as 2 digits at [ebp+EDI] (leading space if tens=0).
; Clobbers EAX, ECX, EDX.
print_2d:
    movzx eax, al
    xor edx, edx
    mov ecx, 10
    div ecx                               ; EAX = tens, EDX = ones
    test al, al
    jnz .tens
    mov byte [ebp + edi], 0x7F            ; leading space
    jmp .ones
.tens:
    add al, CHAR_DIG0
    mov [ebp + edi], al
.ones:
    add dl, CHAR_DIG0
    mov [ebp + edi + 1], dl
    ret
