; core.asm — faithful translation of pret engine/battle/core.asm (battle loop).
;
; This replaces the bespoke Wave-2 orchestration (battle_menu.asm) with a
; structure-for-structure translation of pret's battle loop. Per the governing
; principle (docs/current_plan_battle_pret_alignment.md): the BACKEND is byte-
; faithful, and the FRONT END diverges from pret ONLY at the screen-draw primitive
; (the tile write into our centered 40-wide W_TILEMAP). Move animation is a marked
; placeholder (HP-bar drain); audio is a no-op stub.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, SP=ESP,
; EBP = base of emulated GB memory; GB address X = [ebp+X]. hWhoseTurn: 0=player.
;
; Build: nasm -f coff -I include/ -I . -o core.o core.asm
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

; --- move ids referenced by the turn-order logic (constants/move_constants.asm) ---
%ifndef QUICK_ATTACK
%define QUICK_ATTACK 0x62
%endif
%ifndef COUNTER
%define COUNTER      0x44
%endif
%ifndef CANNOT_MOVE
%define CANNOT_MOVE  0xFF
%endif
%ifndef LINK_STATE_BATTLING
%define LINK_STATE_BATTLING 4
%endif

; battle menu geometry — the generated battle UI layout (Tier 1,
; assets/ui_layout_battle.inc ← ui_layout_battle_sidecar.json; edit with
; tools/ui_layout/battle.py — never hand-edit offsets here).
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"
%define FW          40
; PROJ battle: action-menu cursor cells = UI_ACTION_CUR_L / UI_ACTION_CUR_R
%define MENU_ROW    UI_ACTION_CUR_L_ROW ; pret wTopMenuItemY $e; rows +0/+2
%define CUR_COL_L   UI_ACTION_CUR_L_COL ; left column  — FIGHT / PKMN
%define CUR_COL_R   UI_ACTION_CUR_R_COL ; right column — ITEM / RUN
%define T_SPACE     0x7F
%define T_H         0x7A        ; box ─
%define T_BR        0x7E        ; box ┘
; PROJ battle: move menu = UI_MOVE_BOX / UI_MOVE_TEXT / UI_MOVE_CURSOR
%define MOVEBOX_OFF   UI_MOVE_BOX_OFS          ; box top-left
%define MOVEBOX_W     (UI_MOVE_BOX_GBW - 2)    ; TextBoxBorder interior w
%define MOVEBOX_H     (UI_MOVE_BOX_GBH - 2)    ; TextBoxBorder interior h
%define MOVES_TEXT    UI_MOVE_TEXT_OFS         ; move list (single-spaced)
%define MOVES_CUR_COL UI_MOVE_CURSOR_COL
%define MOVES_ROW0    UI_MOVE_CURSOR_ROW
; PROJ battle: dialog box = UI_DIALOG_BOX, message lines = UI_DIALOG_LINE1/2,
; blink arrow = UI_DIALOG_ARROW
%define OUTER_OFF     UI_DIALOG_BOX_OFS        ; dialog box top-left
%define OUTER_W       (UI_DIALOG_BOX_GBW - 2)
%define OUTER_H       (UI_DIALOG_BOX_GBH - 2)
%define BTXT_LINE1    UI_DIALOG_LINE1_OFS      ; 1st text line
%define BTXT_LINE2    UI_DIALOG_LINE2_OFS      ; 2nd text line (<LINE>)
%define BTXT_ARROW    UI_DIALOG_ARROW_OFS      ; ▼ box bottom-right interior
%define T_DOWNARROW   0xEE              ; ▼ glyph
%define ARROW_BLINK   20                ; frames per ▼ blink phase

; generated battle message streams (Tier-1 data; %included so labels are local)
%include "assets/battle_text.inc"

section .text

global MainInBattleLoop
global DisplayBattleMenu
global MoveSelectionMenu
global AnyMoveToSelect
global PrintBattleText
global ExecutePlayerMove
global ExecutePlayerMoveDone
global DisplayUsedMoveText
global MonsStatsRose
global MonsStatsFell
global ApplyAttackToEnemyPokemon
global CheckPlayerStatusConditions
global CheckForDisobedience
global ExecuteEnemyMove
global ExecuteEnemyMoveDone
global ApplyAttackToPlayerPokemon
global CheckEnemyStatusConditions
global HandleEnemyMonFainted
global HandlePlayerMonFainted
global ReadPlayerMonCurHPAndStatus
global CheckNumAttacksLeft
global BattleMenu_RunWasSelected

; --- backend (already-faithful translations in other files) ---
extern SelectEnemyMove                 ; select_enemy_move.asm
extern TrainerAI                       ; trainer_ai.asm (CF if AI used item/switch)
extern HandlePoisonBurnLeechSeed       ; residual_damage.asm (ZF if target fainted)
extern BattleRandom                    ; home/random.asm

; --- draw primitives (category-D divergence point; battle_menu.asm draw helpers) ---
extern DrawHUDsAndHPBars               ; (DrawBattleHUDs) HUDs + HP bars
extern AnimateEnemyHPBar               ; battle_hud.asm — gradual enemy HP-bar drain (ECX=old HP)
extern AnimatePlayerHPBar              ; battle_hud.asm — gradual player HP-bar drain (ECX=old HP)
extern DrawEnemyHUDAndHPBar            ; battle_hud.asm — faithful enemy-only HUD+bar redraw
extern SaveScreenTilesToBuffer1        ; (SaveBattleScreen) snapshot clean screen
extern LoadScreenTilesFromBuffer1      ; (RestoreBattleScreen) restore it
extern DrawEmptyDialogBox              ; pret PrintEmptyString equiv (blank dialog box)
extern DrawBattleMenuBox               ; DisplayTextBoxID(BATTLE_MENU_TEMPLATE) equiv
extern HandleMenuInput                 ; home/window.asm
extern PlaceMenuCursor                 ; home/window.asm
extern menu_item_step                  ; home/window.asm — cursor vertical spacing
extern menu_redraw_cb                  ; home/window.asm — per-item redraw callback

; --- text engine + move-list helpers ---
extern TextBoxBorder                   ; text.asm (stride-aware)
extern PlaceString                     ; text.asm (src=EAX flat-linear, end in EBX)
extern TextCommandProcessor            ; text.asm (ESI=stream GB offset, EBX=cursor)
extern text_line2                      ; text.asm — <LINE> target (battle-set)
extern text_prompt_hook                ; text.asm — <PROMPT> display hook
extern text_arrow_pos                  ; text.asm — ▼ tile-buffer offset
extern FormatMovesString               ; misc.asm — wMoves → wMovesString (+ '-' slots)
extern PrintMoveInfoBox                ; battle_menu.asm draw helper (TYPE/PP box)
extern DelayFrame                      ; frame.asm
extern text_row_stride                 ; text.asm — W_TILEMAP row stride

; --- deferred in-battle sub-UIs (bag / party-switch) — call faithfully, body deferred ---
extern BattleItemMenu                  ; ITEM → bag (deferred; re-shows the menu)
extern BattlePartyMenu                 ; PKMN → party/switch (deferred; re-shows the menu)

; --- move-execution backend (already-faithful, in other files) ---
extern GetCurrentMove                  ; get_current_move.asm
extern AddNTimes                       ; home/array.asm — ESI += BX * AL (party index)
extern CriticalHitTest                 ; core_damage.asm
extern GetDamageVarsForPlayerAttack    ; core_damage.asm
extern GetDamageVarsForEnemyAttack     ; core_damage.asm
extern CalculateDamage                 ; core_damage.asm (ZF if 0 BP)
extern AdjustDamageForMoveType         ; core_damage.asm
extern RandomizeDamage                 ; core_damage.asm
extern MoveHitTest                     ; core_damage.asm (sets wMoveMissed)
extern PlayMoveAnimation               ; animations.asm (placeholder ; TODO-HW)
extern DecrementPP                     ; decrement_pp.asm
extern JumpMoveEffect                  ; effects.asm — MoveEffectPointerTable dispatch
extern IsInArray                       ; home/array.asm — AL in [ESI] ($FF-term, stride EDX) → CF
extern ResidualEffects1                ; battle_data.asm — effect-category arrays
extern SpecialEffectsCont
extern SetDamageEffects
extern ResidualEffects2
extern AlwaysHappenSideEffects
extern SpecialEffects
extern FindMoveName                    ; battle_menu.asm — move id → flat name ptr
extern GainExperience                  ; experience.asm — EXP award + level-up display
extern TryRunningFromBattle            ; battle_menu.asm — flee odds (CF = escaped)
; --- faint / switch lifecycle (battle-swarm-C) ---
extern FaintEnemyPokemon               ; faint_enemy.asm — enemy-faint state + EXP(-ALL)
extern RemoveFaintedPlayerMon          ; faint_switch.asm — player-faint state
extern AnyPartyAlive                   ; wild_encounter_check.asm — DH=0 if no party alive
extern AnyEnemyPokemonAliveCheck       ; faint_leaves.asm — ZF=1 if all enemy mons fainted
extern HandlePlayerBlackOut            ; faint_switch.asm — no usable mons → CF=1
extern DoUseNextMonDialogue            ; faint_switch.asm — "use next mon?" (CF=ran)
extern ChooseNextMon                   ; faint_switch.asm — forced switch-in (ZF=enemy HP0)
extern ReplaceFaintedEnemyMon          ; faint_sendout.asm — trainer sends next mon
extern TrainerBattleVictory            ; faint_sendout.asm — prize money + victory text
extern EnemyRan                        ; faint_switch.asm — enemy fled (link) tail

; ---------------------------------------------------------------------------
; MainInBattleLoop — pret engine/battle/core.asm:MainInBattleLoop (line 289).
; One battle turn: faint checks, player action (menu / forced move), enemy move
; selection, speed/priority turn order, execute both moves with residual-damage +
; faint handling between them. Loops until a mon faints or the battle ends.
; ---------------------------------------------------------------------------
MainInBattleLoop:
    call ReadPlayerMonCurHPAndStatus
    mov al, [ebp + wBattleMonHP]
    or  al, [ebp + wBattleMonHP + 1]        ; battle mon HP 0?
    jz  HandlePlayerMonFainted
    mov al, [ebp + wEnemyMonHP]
    or  al, [ebp + wEnemyMonHP + 1]         ; enemy mon HP 0?
    jz  HandleEnemyMonFainted
    call SaveScreenTilesToBuffer1
    mov byte [ebp + wFirstMonsNotOutYet], 0
    mov al, [ebp + wPlayerBattleStatus2]
    test al, (1 << NEEDS_TO_RECHARGE) | (1 << USING_RAGE)
    jnz .selectEnemyMove                    ; Rage / recharge → no menu
    ; not raging/recharging: clear both flinch bits
    and byte [ebp + wEnemyBattleStatus1], (~(1 << FLINCHED)) & 0xFF
    mov al, [ebp + wPlayerBattleStatus1]
    and al, (~(1 << FLINCHED)) & 0xFF
    mov [ebp + wPlayerBattleStatus1], al
    test al, (1 << THRASHING_ABOUT) | (1 << CHARGING_UP)
    jnz .selectEnemyMove                    ; thrashing / charging → no menu
    call DisplayBattleMenu
    jc  .ret                                ; player ran from battle (CF)
    mov al, [ebp + wEscapedFromBattle]
    test al, al
    jnz .ret                                ; POKé DOLL escape
    mov al, [ebp + wBattleMonStatus]
    test al, (1 << FRZ) | SLP_MASK
    jnz .selectEnemyMove                    ; frozen/asleep → can't pick a move
    mov al, [ebp + wPlayerBattleStatus1]
    test al, (1 << STORING_ENERGY) | (1 << USING_TRAPPING_MOVE)
    jnz .selectEnemyMove                    ; Bide / multi-turn wrap in progress
    test byte [ebp + wEnemyBattleStatus1], 1 << USING_TRAPPING_MOVE
    jz  .selectPlayerMove
    ; enemy is trapping us (Wrap, …) → player cannot move this turn
    mov byte [ebp + wPlayerSelectedMove], CANNOT_MOVE
    jmp .selectEnemyMove
.selectPlayerMove:
    mov al, [ebp + wActionResultOrTookBattleTurn]
    test al, al                             ; already acted (item/run/switch)?
    jnz .selectEnemyMove
    mov [ebp + wMoveMenuType], al           ; al = 0 (regular move menu)
    inc al
    mov [ebp + wAnimationID], al
    mov byte [ebp + wMenuItemToSwap], 0
    call MoveSelectionMenu                  ; ZF set if a move was chosen
    pushfd
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    popfd
    jnz MainInBattleLoop                    ; no move selected (B) → redraw menu
.selectEnemyMove:
    call SelectEnemyMove
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .noLinkBattle
    ; TODO-HW: link-battle move/run/switch exchange (Phase 4 network HAL). Single-
    ; player falls straight through to the local turn-order resolution.
.noLinkBattle:
    ; ---- turn order: Quick Attack > Counter(last) > speed > 50/50 random ----
    mov al, [ebp + wPlayerSelectedMove]
    cmp al, QUICK_ATTACK
    jne .pNotQuickAttack
    mov al, [ebp + wEnemySelectedMove]
    cmp al, QUICK_ATTACK
    je  .compareSpeed                       ; both Quick Attack → speed
    jmp .playerMovesFirst                   ; only player → player first
.pNotQuickAttack:
    mov al, [ebp + wEnemySelectedMove]
    cmp al, QUICK_ATTACK
    je  .enemyMovesFirst                    ; only enemy → enemy first
    mov al, [ebp + wPlayerSelectedMove]
    cmp al, COUNTER
    jne .pNotCounter
    mov al, [ebp + wEnemySelectedMove]
    cmp al, COUNTER
    je  .compareSpeed                       ; both Counter → speed
    jmp .enemyMovesFirst                    ; only player used Counter → goes last
.pNotCounter:
    mov al, [ebp + wEnemySelectedMove]
    cmp al, COUNTER
    je  .playerMovesFirst                   ; only enemy used Counter → player first
.compareSpeed:
    movzx eax, byte [ebp + wBattleMonSpeed]     ; player speed (big-endian)
    shl eax, 8
    mov al, [ebp + wBattleMonSpeed + 1]
    movzx ecx, byte [ebp + wEnemyMonSpeed]      ; enemy speed
    shl ecx, 8
    mov cl, [ebp + wEnemyMonSpeed + 1]
    cmp eax, ecx
    ja  .playerMovesFirst                   ; player faster
    jb  .enemyMovesFirst                    ; enemy faster
    ; speed tie → 50/50 (the internal-clock invert is link-only: TODO-HW Phase 4).
    call BattleRandom
    cmp al, (50 * 0xFF / 100) + 1           ; pret `50 percent + 1` = 128
    jb  .playerMovesFirst
    jmp .enemyMovesFirst

.enemyMovesFirst:
    mov byte [ebp + hWhoseTurn], 1
    call TrainerAI
    jc  .AIActionUsedEnemyFirst             ; AI used an item/switch instead of a move
    call ExecuteEnemyMove
    mov al, [ebp + wEscapedFromBattle]
    test al, al
    jnz .ret                                ; Teleport/Roar/Whirlwind escape
    test bh, bh                             ; b == 0 → player mon fainted
    jz  HandlePlayerMonFainted
.AIActionUsedEnemyFirst:
    call HandlePoisonBurnLeechSeed
    jz  HandleEnemyMonFainted               ; residual damage KO'd the enemy
    call DrawHUDsAndHPBars
    call ExecutePlayerMove
    mov al, [ebp + wEscapedFromBattle]
    test al, al
    jnz .ret
    test bh, bh                             ; b == 0 → enemy fainted
    jz  HandleEnemyMonFainted
    call HandlePoisonBurnLeechSeed
    jz  HandlePlayerMonFainted
    call DrawHUDsAndHPBars
    call CheckNumAttacksLeft
    jmp MainInBattleLoop

.playerMovesFirst:
    call ExecutePlayerMove
    mov al, [ebp + wEscapedFromBattle]
    test al, al
    jnz .ret
    test bh, bh                             ; b == 0 → enemy fainted
    jz  HandleEnemyMonFainted
    call HandlePoisonBurnLeechSeed
    jz  HandlePlayerMonFainted
    call DrawHUDsAndHPBars
    mov byte [ebp + hWhoseTurn], 1
    call TrainerAI
    jc  .AIActionUsedPlayerFirst
    call ExecuteEnemyMove
    mov al, [ebp + wEscapedFromBattle]
    test al, al
    jnz .ret
    test bh, bh                             ; b == 0 → player mon fainted
    jz  HandlePlayerMonFainted
.AIActionUsedPlayerFirst:
    call HandlePoisonBurnLeechSeed
    jz  HandleEnemyMonFainted
    call DrawHUDsAndHPBars
    call CheckNumAttacksLeft
    jmp MainInBattleLoop

.ret:
    ret

; ---------------------------------------------------------------------------
; DisplayBattleMenu — pret engine/battle/core.asm:DisplayBattleMenu (line 2076).
; Restore the clean screen, (re)draw HUDs + an empty dialog box, snapshot it, draw
; the FIGHT/PKMN/ITEM/RUN box, then run the faithful two-column cursor input and
; dispatch. Returns CF=1 if the player escaped (ran). Coord VALUES are projected to
; our centered canvas (the sanctioned draw-layer divergence); structure is pret's.
; Safari / old-man / Pikachu-tutorial / link branches are deferred (TODO: those
; battle types aren't reachable yet — only normal wild/trainer battles).
; ---------------------------------------------------------------------------
DisplayBattleMenu:
    call LoadScreenTilesFromBuffer1     ; restore saved screen
    ; (normal battle: wBattleType == 0)
    call DrawHUDsAndHPBars
    call DrawEmptyDialogBox             ; pret PrintEmptyString — blank dialog box
    call SaveScreenTilesToBuffer1
    call DrawBattleMenuBox              ; DisplayTextBoxID(BATTLE_MENU_TEMPLATE)
.handleBattleMenuInput:
    mov al, [ebp + wBattleAndStartSavedMenuItem]
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    sub al, 2                           ; left column if id < 2
    jc  .leftColumn
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    jmp .rightColumn
.leftColumn:
    ; clear the right-column cursor cells, watch RIGHT|A
    mov byte [ebp + W_TILEMAP + MENU_ROW * FW + CUR_COL_R], T_SPACE
    mov byte [ebp + W_TILEMAP + (MENU_ROW + 2) * FW + CUR_COL_R], T_SPACE
    mov byte [ebp + wTopMenuItemY], MENU_ROW
    mov byte [ebp + wTopMenuItemX], CUR_COL_L
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_RIGHT | PAD_A
    call HandleMenuInput
    test al, PAD_RIGHT
    jnz .rightColumn
    jmp .AButtonPressed
.rightColumn:
    ; clear the left-column cursor cells, watch LEFT|A
    mov byte [ebp + W_TILEMAP + MENU_ROW * FW + CUR_COL_L], T_SPACE
    mov byte [ebp + W_TILEMAP + (MENU_ROW + 2) * FW + CUR_COL_L], T_SPACE
    mov byte [ebp + wTopMenuItemY], MENU_ROW
    mov byte [ebp + wTopMenuItemX], CUR_COL_R
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_LEFT | PAD_A
    call HandleMenuInput
    test al, PAD_LEFT
    jnz .leftColumn
    mov al, [ebp + wCurrentMenuItem]    ; A in right column → id += 2
    add al, 2
    mov [ebp + wCurrentMenuItem], al
.AButtonPressed:
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBattleAndStartSavedMenuItem], al
    ; swap ITEM(1)/PKMN(2) ids (Gen-1 English versions swapped their on-screen order)
    cmp al, 1
    jne .notItemMenu
    inc al                              ; ITEM 1 → 2
    jmp .handleMenuSelection
.notItemMenu:
    cmp al, 2
    jne .handleMenuSelection
    dec al                              ; PKMN 2 → 1
.handleMenuSelection:
    and al, al
    jnz .upperLeftMenuItemWasNotSelected
    ; --- FIGHT selected ---
    mov byte [ebp + wNumRunAttempts], 0
    call LoadScreenTilesFromBuffer1     ; restore clean screen and return (CF=0)
    clc
    ret
.upperLeftMenuItemWasNotSelected:
    cmp al, 2
    jne .partyMenuOrRun
    ; --- ITEM (bag) selected --- (deferred sub-UI; re-show the menu after)
    call BattleItemMenu
    jmp DisplayBattleMenu
.partyMenuOrRun:
    dec al                              ; pret PartyMenuOrRockOrRun: dec a; nz → Run
    jnz BattleMenu_RunWasSelected       ; id 3 (RUN) → tail-jump (returns CF)
    ; --- PKMN (party) selected --- (deferred sub-UI; re-show the menu after)
    call BattlePartyMenu
    jmp DisplayBattleMenu

; ---------------------------------------------------------------------------
; MoveSelectionMenu — pret core.asm:MoveSelectionMenu (regular-battle path) with
; SelectMenuItem (2682) folded into the input loop. Lists the 4 moves via
; FormatMovesString ('-' for empty slots), runs the cursor with the live TYPE/PP
; box, and on A commits the move (0-PP / disabled re-show the menu). Returns ZF=1
; if a move was chosen, ZF=0 if the player backed out (B). Mimic/relearn menus, the
; SELECT move-swap, and TestBattle/debug paths are deferred (not reachable here).
; ---------------------------------------------------------------------------
MoveSelectionMenu:
    call AnyMoveToSelect                ; ZF=1 → no usable move (Struggle forced)
    jnz .regularmenu
    xor al, al                          ; ZF=1: selected move = Struggle
    ret
.regularmenu:
    ; .loadmoves — copy the 4 battle-mon move ids to wMoves, then FormatMovesString.
    mov al, [ebp + wBattleMonMoves + 0]
    mov [ebp + wMoves + 0], al
    mov al, [ebp + wBattleMonMoves + 1]
    mov [ebp + wMoves + 1], al
    mov al, [ebp + wBattleMonMoves + 2]
    mov [ebp + wMoves + 2], al
    mov al, [ebp + wBattleMonMoves + 3]
    mov [ebp + wMoves + 3], al
    call FormatMovesString              ; → wMovesString (+ '-' empties), sets wNumMovesMinusOne
    ; draw the move box (+ connect it to the FIGHT box: pret hlcoord 4,12 '─' / 10,12 '┘')
    mov esi, W_TILEMAP + MOVEBOX_OFF
    mov bh, MOVEBOX_H
    mov bl, MOVEBOX_W
    call TextBoxBorder
    mov byte [ebp + W_TILEMAP + MOVEBOX_OFF], T_H
    mov byte [ebp + W_TILEMAP + MOVEBOX_OFF + 6], T_BR
    ; .writemoves — single-spaced move list
    or  byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_SINGLE_SPACED_LINES
    mov esi, W_TILEMAP + MOVES_TEXT
    lea eax, [ebp + wMovesString]
    call PlaceString
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_SINGLE_SPACED_LINES)) & 0xFF
    ; .menuset — cursor over the listed moves (0-based, our window.asm convention).
    mov byte [ebp + wTopMenuItemY], MOVES_ROW0
    mov byte [ebp + wTopMenuItemX], MOVES_CUR_COL
    mov dword [menu_item_step], FW
    mov al, [ebp + wNumMovesMinusOne]
    mov [ebp + wMaxMenuItem], al
    mov al, [ebp + wPlayerMoveListIndex] ; restore remembered cursor (clamp to move count)
    cmp al, [ebp + wNumMovesMinusOne]
    jbe .idxOk
    xor al, al
.idxOk:
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    ; SelectMenuItem loop — refresh the TYPE/PP box on each cursor move.
    mov dword [menu_redraw_cb], PrintMoveInfoBox
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    mov dl, [ebp + wCurrentMenuItem]    ; pret writes the index on BOTH select and back
    mov [ebp + wPlayerMoveListIndex], dl
    test al, PAD_B
    jnz .back
    ; A pressed — SelectMenuItem: 0-PP / disabled checks
    movzx eax, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + eax + wBattleMonPP]
    and al, PP_MASK
    jz  .noPP
    mov al, [ebp + wPlayerDisabledMove] ; high nibble - 1 == disabled slot
    shr al, 4
    dec al
    movzx ecx, byte [ebp + wCurrentMenuItem]
    cmp al, cl
    je  .disabled
    ; commit the chosen move
    movzx eax, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + eax + wBattleMonMoves]
    mov [ebp + wPlayerSelectedMove], al
    xor al, al                          ; ZF=1 → move chosen
    ret
.back:
    mov byte [ebp + wMenuItemToSwap], 0
    or  al, PAD_B                       ; ZF=0 → backed out (B)
    ret
.noPP:
    mov eax, MoveNoPPText
    jmp .printReshow
.disabled:
    mov eax, MoveDisabledText
.printReshow:
    call PrintBattleText
    call LoadScreenTilesFromBuffer1
    jmp MoveSelectionMenu

; ---------------------------------------------------------------------------
; AnyMoveToSelect — pret core.asm:AnyMoveToSelect (2876). If every usable move is
; out of PP (honoring a disabled move), force Struggle and return ZF=1; else ZF=0.
; ---------------------------------------------------------------------------
AnyMoveToSelect:
    mov byte [ebp + wPlayerSelectedMove], STRUGGLE
    mov al, [ebp + wPlayerDisabledMove]
    and al, al
    jnz .handleDisabledMove
    mov al, [ebp + wBattleMonPP + 0]
    or  al, [ebp + wBattleMonPP + 1]
    or  al, [ebp + wBattleMonPP + 2]
    or  al, [ebp + wBattleMonPP + 3]
    and al, PP_MASK
    jz  .noMovesLeft
    ret                                 ; ZF=0 → a move has PP
.handleDisabledMove:
    shr al, 4                           ; disabled-move index (1-based) → b counter
    mov bh, al
    mov edx, NUM_MOVES + 1              ; d = loop count
    xor al, al                          ; accumulate PP (excluding the disabled move)
    mov esi, wBattleMonPP
.ppLoop:
    dec edx
    jz  .allChecked
    mov cl, [ebp + esi]
    inc esi
    dec bh                              ; this slot the disabled one?
    jz  .ppLoop                         ; if so, skip its PP
    or  al, cl
    jmp .ppLoop
.allChecked:
    and al, PP_MASK                     ; any PP left (excl. PP-up bits)?
    jz  .noMovesLeft
    ret                                 ; ZF=0
.noMovesLeft:
    mov eax, NoMovesLeftText
    call PrintBattleText
    mov ecx, 60
.delay:
    call DelayFrame
    dec ecx
    jnz .delay
    xor al, al                          ; ZF=1 → Struggle forced
    ret

; ---------------------------------------------------------------------------
; PrintBattleText — pret PrintText, battle variant. In: EAX = flat-linear ptr to a
; battle_text.inc command stream. Copies it into the GB dialog buffer, configures
; the battle box geometry (so <LINE>/<PROMPT> land in the battle dialog box, ▼ in
; W_TILEMAP), draws the box, and runs the shared TextCommandProcessor (which reveals
; the message char-by-char and self-terminates on prompt/done/text_end).
; ---------------------------------------------------------------------------
PrintBattleText:
    mov esi, eax                        ; flat source stream
    lea edi, [ebp + NPC_DIALOG_BUF]     ; → GB WRAM dialog buffer
    mov ecx, 80                         ; generous fixed span (stream self-terminates)
    rep movsb
    ; fall through — run the stream now sitting in NPC_DIALOG_BUF
; RunBattleTextStream — print the command stream already in NPC_DIALOG_BUF in the
; battle dialog box (entry for code-composed streams, e.g. DisplayUsedMoveText).
RunBattleTextStream:
    mov dword [text_row_stride], FW
    mov dword [text_line2], W_TILEMAP + BTXT_LINE2
    mov dword [text_arrow_pos], W_TILEMAP + BTXT_ARROW
    mov dword [text_prompt_hook], BattlePromptWait
    ; draw the battle dialog box (pret PrintText → DisplayTextBoxID MESSAGE_BOX)
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov ebx, W_TILEMAP + BTXT_LINE1     ; cursor = 1st text line
    mov esi, NPC_DIALOG_BUF             ; stream = the WRAM copy (GB offset)
    call TextCommandProcessor
    ret

; BattlePromptWait — the battle <PROMPT> hook (pret PromptText, W_TILEMAP variant):
; blink the ▼ at [text_arrow_pos], wait for A/B, erase. Installed in text_prompt_hook
; by PrintBattleText. Clobbers EAX/ECX.
BattlePromptWait:
    push esi
    mov esi, [text_arrow_pos]
    mov byte [ebp + esi], T_DOWNARROW
    mov ecx, ARROW_BLINK
.wait:
    call DelayFrame
    test byte [ebp + H_JOY_PRESSED], PAD_A | PAD_B
    jnz .done
    dec ecx
    jnz .wait
    mov ecx, ARROW_BLINK                ; blink toggle
    cmp byte [ebp + esi], T_DOWNARROW
    jne .turnOn
    mov byte [ebp + esi], T_SPACE
    jmp .wait
.turnOn:
    mov byte [ebp + esi], T_DOWNARROW
    jmp .wait
.done:
    mov byte [ebp + esi], T_SPACE       ; erase the ▼
    pop esi
    ret

section .data
; " used " — code-composed move-use grammar (pret used_move_text.asm is text_asm,
; i.e. code, so composing the fixed grammar in code is faithful). Charmap bytes.
str_used_grammar: db 0x4F,0xB4,0xB2,0xA4,0xA3,0x7F, 0x50   ; <LINE>"used " — pret _ActorNameText\n_UsedMove1Text (name on line 1, "used MOVE!" on line 2)
str_miss_text:    db 0x00,0x80,0xB3,0xB3,0xA0,0xA2,0xA8,0x7F,0xA6,0xAE,0xB3,0x7F,0xAD,0xAE,0x7F,0xB6,0xA0,0xB8,0xE7,0x50,0x50 ; "Attack got no way!" placeholder — TODO use AttackMissedText
section .text

; ---------------------------------------------------------------------------
; ExecutePlayerMove — pret engine/battle/core.asm:ExecutePlayerMove (3244), faithful
; CORE path: status check → GetCurrentMove → "X used MOVE!" → DecrementPP → crit /
; damage / type / randomize → MoveHitTest → animation (placeholder) → apply damage →
; HUD → move-effect dispatch → enemy-faint return (b=0 fainted, else ExecutePlayerMove-
; Done sets b=1). Returns b in BH for MainInBattleLoop.
;
; Implements pret's FAITHFUL array-gated move-effect ordering (core.asm:3294-3436):
; the six IsInArray checkpoints (ResidualEffects1 / SpecialEffectsCont / SetDamage-
; Effects / ResidualEffects2 / AlwaysHappenSideEffects / SpecialEffects) decide where
; JumpMoveEffect runs relative to damage, preserving the Gen-1 ordering exactly.
;
; TODO(faithful, deepen — each currently simplified/skipped, clearly marked):
;   - PrintGhostText (Pokémon Tower ghosts)         - charging moves (Fly/Dig/SolarBeam)
;   - HandleCounterMove, multi-hit loop, Mirror Move / Metronome, Explosion handling
;   - PrintCriticalOHKOText, DisplayEffectiveness, HandleBuildingRage, move-failure text
; ---------------------------------------------------------------------------
; --- externs for the faithful ExecutePlayerMove flow (Stage 2.5) ---
extern PrintGhostText                  ; core_stubs.asm (stub: not ghost)
extern HandleCounterMove               ; core_stubs.asm (stub: not counter)
extern MirrorMoveCopyMove              ; core_stubs.asm (stub: fail)
extern MetronomePickMove               ; core_stubs.asm (stub)
extern PrintCriticalOHKOText           ; core_stubs.asm (stub)
extern DisplayEffectiveness            ; core_stubs.asm (stub)
extern HandleExplodingAnimation        ; core_stubs.asm (stub)
extern HandleBuildingRage              ; building_rage.asm (real)
extern HideSubstituteShowMonAnim       ; move_effect_helpers.asm (stub)
extern ReshowSubstituteAnim            ; move_effect_helpers.asm (stub)
extern DelayFrames                     ; frame.asm
extern MultiHitText                    ; battle_text.inc
extern PrintMoveFailureText            ; print_move_failure.asm (real: DoesntAffect/miss/unaffected)

; Faithful port of pret engine/battle/core.asm:ExecutePlayerMove (3244). Re-entry
; labels (PlayerCanExecuteMove/PlayerCalcMoveDamage/HandleIfPlayerMoveMissed/
; GetPlayerAnimationType/PlayerCheckIfFlyOrChargeEffect/MirrorMoveCheck) are exposed so
; CheckPlayerStatusConditions' multi-turn continuations (Stage 3) land where pret's do.
; Deferred leaves (Counter/MirrorMove/Metronome/crit+effectiveness text/EXPLODE anim/
; ghost) are explicit stub CALLs (core_stubs.asm), flag-contract-faithful.
ExecutePlayerMove:
    mov byte [ebp + hWhoseTurn], 0
    mov al, [ebp + wPlayerSelectedMove]
    inc al                              ; CANNOT_MOVE ($FF) → 0
    jz  ExecutePlayerMoveDone
    mov byte [ebp + wMoveMissed], 0
    mov byte [ebp + wMonIsDisobedient], 0
    mov byte [ebp + wMoveDidntMiss], 0
    mov byte [ebp + wDamageMultipliers], EFFECTIVE
    mov al, [ebp + wActionResultOrTookBattleTurn]
    and al, al
    jnz ExecutePlayerMoveDone           ; already acted (item/run/switch)
    call PrintGhostText                 ; pret 3260 (stub: not ghost → ZF=0)
    jz  ExecutePlayerMoveDone           ; jp z — ghost can't attack
    call CheckPlayerStatusConditions    ; pret 3262
    jnz .playerHasNoSpecialCondition
    jmp esi                             ; jp hl — handled; ESI = continuation
.playerHasNoSpecialCondition:
    call GetCurrentMove
    test byte [ebp + wPlayerBattleStatus1], 1 << CHARGING_UP
    jnz PlayerCanExecuteChargingMove
    call CheckForDisobedience           ; ZF=0 uses move / ZF=1 disobeyed (turn spent)
    jz  ExecutePlayerMoveDone           ; jp z — disobeyed
CheckIfPlayerNeedsToChargeUp:           ; pret 3273
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, CHARGE_EFFECT
    je  JumpMoveEffect
    cmp al, FLY_EFFECT
    je  JumpMoveEffect
    jmp PlayerCanExecuteMove
PlayerCanExecuteChargingMove:           ; pret 3282
    and byte [ebp + wPlayerBattleStatus1], ~(1 << CHARGING_UP) & 0xFF
    and byte [ebp + wPlayerBattleStatus1], ~(1 << INVULNERABLE) & 0xFF
PlayerCanExecuteMove:                   ; pret 3288 — Rage continuation
    call DisplayUsedMoveText
    mov edx, wPlayerSelectedMove
    call DecrementPP
    mov al, [ebp + wPlayerMoveEffect]   ; ResidualEffects1 → effect does all, skip dmg+acc
    mov esi, ResidualEffects1
    mov edx, 1
    call IsInArray
    jc  JumpMoveEffect
    mov al, [ebp + wPlayerMoveEffect]   ; SpecialEffectsCont → run effect, don't skip
    mov esi, SpecialEffectsCont
    mov edx, 1
    call IsInArray
    jnc PlayerCalcMoveDamage
    call JumpMoveEffect
PlayerCalcMoveDamage:                   ; pret 3305 — Thrash continuation
    mov al, [ebp + wPlayerMoveEffect]   ; SetDamageEffects → skip calc, go to MoveHitTest
    mov esi, SetDamageEffects
    mov edx, 1
    call IsInArray
    jc  .moveHitTest
    call CriticalHitTest
    call HandleCounterMove              ; pret 3312 (stub: not counter → ZF=0)
    jz  HandleIfPlayerMoveMissed        ; jr z
    call GetDamageVarsForPlayerAttack
    call CalculateDamage
    jz  PlayerCheckIfFlyOrChargeEffect  ; jp z — 0 BP status move
    call AdjustDamageForMoveType
    call RandomizeDamage
.moveHitTest:
    call MoveHitTest
HandleIfPlayerMoveMissed:               ; pret 3322 — Bide continuation
    mov al, [ebp + wMoveMissed]
    and al, al
    jz  GetPlayerAnimationType
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, EXPLODE_EFFECT
    je  PlayPlayerMoveAnimation         ; EXPLODE still animates on a miss
    jmp PlayerCheckIfFlyOrChargeEffect
GetPlayerAnimationType:                 ; pret 3330 — Trapping continuation / multi-hit loop
    mov al, [ebp + wPlayerMoveEffect]
    and al, al
    mov al, ANIMATIONTYPE_BLINK_ENEMY_MON_SPRITE          ; no-effect damage move
    jz  PlayPlayerMoveAnimation
    mov al, ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT  ; move has an effect
PlayPlayerMoveAnimation:
    push eax                            ; push af — save anim type
    test byte [ebp + wPlayerBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jz  .noSub
    call HideSubstituteShowMonAnim
.noSub:
    pop eax                             ; pop af
    mov [ebp + wAnimationType], al
    mov al, [ebp + wPlayerMoveNum]
    call PlayMoveAnimation
    call HandleExplodingAnimation
    call DrawPlayerHUDAndHPBar
    test byte [ebp + wPlayerBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jz  MirrorMoveCheck
    call ReshowSubstituteAnim
    jmp MirrorMoveCheck
PlayerCheckIfFlyOrChargeEffect:         ; pret 3355
    mov bl, 30
    call DelayFrames
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, FLY_EFFECT
    je  .flyChargeAnim
    cmp al, CHARGE_EFFECT
    je  .flyChargeAnim
    jmp MirrorMoveCheck
.flyChargeAnim:
    mov byte [ebp + wAnimationType], 0
    mov al, STATUS_AFFECTED_ANIM
    call PlayMoveAnimation
MirrorMoveCheck:                        ; pret 3369
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, MIRROR_MOVE_EFFECT
    jne .metronomeCheck
    call MirrorMoveCopyMove             ; (stub: fail → ZF=1)
    jz  ExecutePlayerMoveDone
    mov byte [ebp + wMonIsDisobedient], 0
    jmp CheckIfPlayerNeedsToChargeUp
.metronomeCheck:
    cmp al, METRONOME_EFFECT
    jne .mirrorNext
    call MetronomePickMove              ; (stub: clears effect to break the re-entry loop)
    jmp CheckIfPlayerNeedsToChargeUp
.mirrorNext:
    mov al, [ebp + wPlayerMoveEffect]   ; ResidualEffects2 → run effect after damage, done
    mov esi, ResidualEffects2
    mov edx, 1
    call IsInArray
    jc  JumpMoveEffect
    mov al, [ebp + wMoveMissed]
    and al, al
    jz  .moveDidNotMiss
    call PrintMoveFailureText           ; pret 3390 — DoesntAffect/miss/unaffected + JumpKick recoil
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, EXPLODE_EFFECT
    je  .notDone                        ; Explosion effect still runs on a miss
    jmp ExecutePlayerMoveDone
.moveDidNotMiss:
    call ApplyAttackToEnemyPokemon
    call PrintCriticalOHKOText          ; (stub)
    call DisplayEffectiveness           ; (stub; pret callfar)
    mov byte [ebp + wMoveDidntMiss], 1
.notDone:
    mov al, [ebp + wPlayerMoveEffect]   ; AlwaysHappenSideEffects → run after damage, not done
    mov esi, AlwaysHappenSideEffects
    mov edx, 1
    call IsInArray
    jnc .skipAlwaysHappen
    call JumpMoveEffect
.skipAlwaysHappen:
    mov al, [ebp + wEnemyMonHP]
    or  al, [ebp + wEnemyMonHP + 1]
    jz  .pTargetFainted                 ; pret: ret z — enemy fainted, nothing else
    call HandleBuildingRage
    test byte [ebp + wPlayerBattleStatus1], 1 << ATTACKING_MULTIPLE_TIMES
    jz  .executeOtherEffects
    mov al, [ebp + wPlayerNumAttacksLeft]
    dec al
    mov [ebp + wPlayerNumAttacksLeft], al
    jnz GetPlayerAnimationType          ; multi-hit: re-apply until 0 or faint (only 1st hit calcs)
    and byte [ebp + wPlayerBattleStatus1], ~(1 << ATTACKING_MULTIPLE_TIMES) & 0xFF
    mov esi, MultiHitText
    call PrintText
    mov byte [ebp + wPlayerNumHits], 0
.executeOtherEffects:                   ; pret 3429 — SpecialEffects catch-all
    mov al, [ebp + wPlayerMoveEffect]
    and al, al
    jz  ExecutePlayerMoveDone           ; NO_ADDITIONAL_EFFECT
    mov esi, SpecialEffects
    mov edx, 1
    call IsInArray
    jc  ExecutePlayerMoveDone           ; in SpecialEffects → already handled (pret call nc)
    call JumpMoveEffect
    jmp ExecutePlayerMoveDone
.pTargetFainted:
    xor bh, bh                          ; b = 0 → enemy fainted
    ret

ExecutePlayerMoveDone:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    mov bh, 1                           ; b = 1 → target did not faint
    ret

; ---------------------------------------------------------------------------
; DisplayUsedMoveText — pret engine/battle/used_move_text.asm (text_asm-composed).
; Builds "<USER> used <MOVE>!" into the dialog buffer and prints it (no wait —
; pret's text ends in text_end). <USER> ($5A) is resolved by the text engine
; (player nick, or "Enemy "+enemy nick on the enemy's turn).
; ---------------------------------------------------------------------------
DisplayUsedMoveText:
    lea edi, [ebp + NPC_DIALOG_BUF]
    mov byte [edi], 0x00                ; TX_START
    inc edi
    mov byte [edi], 0x5A                ; <USER>
    inc edi
    mov esi, str_used_grammar           ; " used "
    call .copyFlat
    movzx eax, byte [ebp + hWhoseTurn]
    test al, al
    jz  .playerName
    mov al, [ebp + wEnemySelectedMove]
    jmp .gotId
.playerName:
    mov al, [ebp + wPlayerSelectedMove]
.gotId:
    call FindMoveName                   ; EAX = flat ptr to the move name
    mov esi, eax
    call .copyFlat
    mov byte [edi], 0xE7                ; '!'
    inc edi
    mov byte [edi], 0x50                ; '@' (PlaceString terminator)
    inc edi
    mov byte [edi], 0x50                ; TX_END
    jmp RunBattleTextStream
.copyFlat:                              ; copy a $50-terminated flat string [ESI] → [EDI]
    mov al, [esi]
    cmp al, 0x50
    je  .copyDone
    mov [edi], al
    inc edi
    inc esi
    jmp .copyFlat
.copyDone:
    ret

; ---------------------------------------------------------------------------
; MonsStatsRose / MonsStatsFell — pret MonsStatsRoseText (effects.asm:552) /
; MonsStatsFellText (:754): a text_far intro + a text_asm suffix branch, so the
; generator can't emit them (it skips them). Composed in code, like DisplayUsedMoveText.
; Prints "<USER/TARGET>'s<LINE><stat> rose!/fell!" — "greatly" for a ±2 stage — with a
; <PROMPT> wait. wStringBuffer holds the stat name (set by the caller, PrintStatText).
; TODO(B): live pacing/scroll of the "greatly" line is Master B's text-engine domain.
; ---------------------------------------------------------------------------
MonsStatsRose:
    mov bh, 0x5A                         ; <USER>
    call ComposeStatIntro               ; → EDI past intro, AL = attacker move effect
    cmp al, ATTACK_DOWN1_EFFECT         ; pret :564 — effect >= ATTACK_DOWN1 → "greatly"
    mov esi, str_greatly_rose
    jae AppendStatSuffix
    mov esi, str_rose
    jmp AppendStatSuffix
MonsStatsFell:
    mov bh, 0x59                         ; <TARGET>
    call ComposeStatIntro
    mov esi, str_greatly_fell           ; pret :765-769 — BIDE_EFFECT <= effect
    cmp al, BIDE_EFFECT                  ;                   < ATTACK_DOWN_SIDE_EFFECT
    jb  .fellPlain                       ;                   → "greatly"
    cmp al, ATTACK_DOWN_SIDE_EFFECT
    jb  AppendStatSuffix
.fellPlain:
    mov esi, str_fell
    ; fall through to AppendStatSuffix
AppendStatSuffix:                        ; copy suffix [ESI] (flat, <PROMPT>-terminated) → [EDI]
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    cmp al, 0x58                         ; <PROMPT> terminates + drives the ▼ wait
    jne AppendStatSuffix
    jmp RunBattleTextStream

; ComposeStatIntro — BH = <USER>/<TARGET> byte. Writes "<TX_START><name>'s<LINE>
; <TX_RAM wStringBuffer>" into NPC_DIALOG_BUF, leaves EDI past it, returns AL = the
; attacker's move effect (hWhoseTurn-selected, pret effects.asm:557-562). Clobbers EAX/EDI.
ComposeStatIntro:
    lea edi, [ebp + NPC_DIALOG_BUF]
    mov byte [edi], 0x00                 ; TX_START
    mov [edi + 1], bh                    ; <USER> / <TARGET>
    mov byte [edi + 2], 0xBD             ; "'s"
    mov byte [edi + 3], 0x4F             ; <LINE>
    mov byte [edi + 4], 0x01             ; TX_RAM
    mov word [edi + 5], wStringBuffer    ; stat-name source ($CF4A, little-endian)
    add edi, 7
    mov al, [ebp + wPlayerMoveEffect]
    cmp byte [ebp + hWhoseTurn], 0
    je  .introDone
    mov al, [ebp + wEnemyMoveEffect]
.introDone:
    ret

section .data
; Stat-change verb suffixes (charmap bytes), each <PROMPT>($58)-terminated. Compose
; onto the "<mon>'s<LINE><stat>" intro. "greatly" variants lead with <SCROLL>($4C).
str_rose:         db 0x7F,0xB1,0xAE,0xB2,0xA4,0xE7,0x58                                  ; " rose!"
str_greatly_rose: db 0x4C,0xA6,0xB1,0xA4,0xA0,0xB3,0xAB,0xB8,0x7F,0xB1,0xAE,0xB2,0xA4,0xE7,0x58 ; <SCROLL>"greatly rose!"
str_fell:         db 0x7F,0xA5,0xA4,0xAB,0xAB,0xE7,0x58                                  ; " fell!"
str_greatly_fell: db 0x4C,0xA6,0xB1,0xA4,0xA0,0xB3,0xAB,0xB8,0x7F,0xA5,0xA4,0xAB,0xAB,0xE7,0x58 ; <SCROLL>"greatly fell!"
section .text

; ---------------------------------------------------------------------------
; ApplyAttackToEnemyPokemon — faithful port of pret core.asm:4783. Dispatches the
; fixed/special-damage effects (Super Fang, Seismic Toss/Night Shade/Sonic Boom/
; Dragon Rage/Psywave) that skip CalculateDamage, then applies wDamage to the enemy
; mon (substitute-redirected). ApplyDamageToEnemyPokemon (pret :4849) is the plain
; HP-subtract entry the confusion self-hit jumps to (skips the effect dispatch).
; ---------------------------------------------------------------------------
ApplyAttackToEnemyPokemon:
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, OHKO_EFFECT
    je  ApplyDamageToEnemyPokemon        ; OHKO damage already set by CalculateDamage
    cmp al, SUPER_FANG_EFFECT
    je  .superFang
    cmp al, SPECIAL_DAMAGE_EFFECT
    je  .specialDamage
    mov al, [ebp + wPlayerMovePower]
    and al, al
    jz  ApplyAttackToEnemyPokemonDone    ; 0 base power → no attack to apply
    jmp ApplyDamageToEnemyPokemon
.superFang:                              ; wDamage = enemy current HP / 2 (min 1)
    mov al, [ebp + wEnemyMonHP]
    shr al, 1
    mov [ebp + wDamage], al
    mov bh, al
    mov al, [ebp + wEnemyMonHP + 1]
    rcr al, 1
    mov [ebp + wDamage + 1], al
    or  al, bh
    jnz ApplyDamageToEnemyPokemon
    mov byte [ebp + wDamage + 1], 1
    jmp ApplyDamageToEnemyPokemon
.specialDamage:
    mov bh, [ebp + wBattleMonLevel]      ; Seismic Toss / Night Shade = user level
    mov al, [ebp + wPlayerMoveNum]
    cmp al, SEISMIC_TOSS
    je  .storeSpecial
    cmp al, NIGHT_SHADE
    je  .storeSpecial
    mov bh, SONICBOOM_DAMAGE
    cmp al, SONICBOOM
    je  .storeSpecial
    mov bh, DRAGON_RAGE_DAMAGE
    cmp al, DRAGON_RAGE
    je  .storeSpecial
    ; Psywave: bh = user level * 1.5; random in [1, bh). Player Psywave always
    ; deals >= 1 (the enemy's range is [0, bh) — a Gen-1 asymmetry preserved below).
    mov al, [ebp + wBattleMonLevel]
    mov bh, al
    shr al, 1
    add al, bh
    mov bh, al
.psywaveLoop:
    call BattleRandom
    and al, al
    jz  .psywaveLoop
    cmp al, bh
    jae .psywaveLoop
    mov bh, al
.storeSpecial:
    mov byte [ebp + wDamage], 0
    mov [ebp + wDamage + 1], bh
    ; fall through

global ApplyDamageToEnemyPokemon        ; consumed by print_move_failure.asm (JumpKick recoil)
ApplyDamageToEnemyPokemon:
    mov al, [ebp + wDamage]
    or  al, [ebp + wDamage + 1]
    jz  ApplyAttackToEnemyPokemonDone    ; done if wDamage == 0
    test byte [ebp + wEnemyBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jnz AttackSubstitute                 ; substitute absorbs the hit (shared, tail)
    ; HP -= wDamage (big-endian); save pre-attack HP → wHPBarOldHP (pret little-endian)
    mov bl, [ebp + wDamage + 1]
    mov al, [ebp + wEnemyMonHP + 1]
    mov [ebp + wHPBarOldHP], al
    sub al, bl
    mov [ebp + wEnemyMonHP + 1], al
    mov bl, [ebp + wDamage]
    mov al, [ebp + wEnemyMonHP]
    mov [ebp + wHPBarOldHP + 1], al
    sbb al, bl                           ; CF preserved from the sub above (movs don't touch flags)
    mov [ebp + wEnemyMonHP], al
    jnc .animateHpBar
    ; overkill: set wDamage = pre-attack HP, zero the HP
    mov al, [ebp + wHPBarOldHP + 1]
    mov [ebp + wDamage], al
    mov al, [ebp + wHPBarOldHP]
    mov [ebp + wDamage + 1], al
    mov byte [ebp + wEnemyMonHP], 0
    mov byte [ebp + wEnemyMonHP + 1], 0
.animateHpBar:
    mov al, [ebp + wEnemyMonMaxHP]
    mov [ebp + wHPBarMaxHP + 1], al
    mov al, [ebp + wEnemyMonMaxHP + 1]
    mov [ebp + wHPBarMaxHP], al
    mov al, [ebp + wEnemyMonHP]
    mov [ebp + wHPBarNewHP + 1], al
    mov al, [ebp + wEnemyMonHP + 1]
    mov [ebp + wHPBarNewHP], al
    ; pret: hlcoord 2,2 / xor a / ld [wHPBarType],a / predef UpdateHPBar2 — gradual drain
    ; of the ENEMY bar (no HP number), from wHPBarOldHP down to the new struct HP.
    movzx ecx, word [ebp + wHPBarOldHP]     ; old HP (pret little-endian) → drain start
    call AnimateEnemyHPBar
ApplyAttackToEnemyPokemonDone:
    jmp DrawHUDsAndHPBars                    ; pret `jp DrawHUDsAndHPBars` (tail; its ret returns)

; --- externs for the status-condition checks (pret core.asm:3499) ---
extern PrintText                       ; move_effect_helpers.asm (ESI = flat text stream)
extern GetMoveName                     ; home/names.asm
extern DrawPlayerHUDAndHPBar           ; self-confusion damage redraw
extern FastAsleepText
extern WokeUpText
extern IsFrozenText
extern CantMoveText
extern FlinchedText
extern MustRechargeText
extern DisabledNoMoreText
extern ConfusedNoMoreText
extern IsConfusedText
extern HurtItselfText
extern MoveIsDisabledText
extern ThrashingAboutText
extern AttackContinuesText
extern UnleashedEnergyText

; ---------------------------------------------------------------------------
; CheckPlayerStatusConditions — faithful port of pret core.asm:3499.
; Returns: ZF=1 ("handled this turn") with ESI = the continuation label the caller
; must `jmp esi` to (pret's `ld hl, X` / `.returnToHL: xor a; ret` / `jp hl`); or
; ZF=0 with AL=1 ("mon may move normally", pret `.checkConditionsDone`).
; HL→ESI for the working pointers; register map A=AL, [ebp+addr] for GB memory.
; Stage-2 scope: the can't-move chain + confusion self-hit. The multi-turn lock-ins
; (Bide/Thrash/Trapping/Rage) fall through to .checkConditionsDone for now — TODO(Stage 3).
; ---------------------------------------------------------------------------
CheckPlayerStatusConditions:
    mov esi, wBattleMonStatus            ; ld hl, wBattleMonStatus
    mov al, [ebp + esi]
    and al, SLP_MASK
    jz .frozenCheck
    ; sleeping (pret 3504) — decrement turns left (sleep is exclusive of other status)
    dec al
    mov [ebp + wBattleMonStatus], al
    and al, al
    jz .wakeUp                           ; turns hit 0 → wake
    mov byte [ebp + wAnimationType], 0   ; fast asleep
    mov al, SLP_PLAYER_ANIM
    call PlayMoveAnimation
    mov esi, FastAsleepText
    call PrintText
    jmp .sleepDone
.wakeUp:
    mov esi, WokeUpText
    call PrintText
.sleepDone:
    mov byte [ebp + wPlayerUsedMove], 0
    mov esi, ExecutePlayerMoveDone       ; can't move this turn
    jmp .returnToHL

.frozenCheck:                            ; pret 3526
    test byte [ebp + esi], 1 << FRZ
    jz .heldInPlaceCheck
    mov esi, IsFrozenText
    call PrintText
    mov byte [ebp + wPlayerUsedMove], 0
    mov esi, ExecutePlayerMoveDone
    jmp .returnToHL

.heldInPlaceCheck:                       ; pret 3536 — enemy using a trapping move on us
    test byte [ebp + wEnemyBattleStatus1], 1 << USING_TRAPPING_MOVE
    jz .flinchedCheck
    mov esi, CantMoveText
    call PrintText
    mov esi, ExecutePlayerMoveDone
    jmp .returnToHL

.flinchedCheck:                          ; pret 3545
    test byte [ebp + wPlayerBattleStatus1], 1 << FLINCHED
    jz .hyperBeamCheck
    and byte [ebp + wPlayerBattleStatus1], ~(1 << FLINCHED) & 0xFF   ; res FLINCHED
    mov esi, FlinchedText
    call PrintText
    mov esi, ExecutePlayerMoveDone
    jmp .returnToHL

.hyperBeamCheck:                         ; pret 3555
    test byte [ebp + wPlayerBattleStatus2], 1 << NEEDS_TO_RECHARGE
    jz .anyMoveDisabledCheck
    and byte [ebp + wPlayerBattleStatus2], ~(1 << NEEDS_TO_RECHARGE) & 0xFF
    mov esi, MustRechargeText
    call PrintText
    mov esi, ExecutePlayerMoveDone
    jmp .returnToHL

.anyMoveDisabledCheck:                   ; pret 3565 — packed (move<<4 | turns)
    mov al, [ebp + wPlayerDisabledMove]
    and al, al
    jz .confusedCheck
    dec al
    mov [ebp + wPlayerDisabledMove], al
    and al, 0x0F                         ; Disable turns hit 0?
    jnz .confusedCheck
    mov byte [ebp + wPlayerDisabledMove], 0
    mov byte [ebp + wPlayerDisabledMoveNumber], 0
    mov esi, DisabledNoMoreText
    call PrintText

.confusedCheck:                          ; pret 3579
    test byte [ebp + wPlayerBattleStatus1], 1 << CONFUSED
    jz .triedToUseDisabledMoveCheck
    mov esi, wPlayerConfusedCounter
    mov al, [ebp + esi]
    dec al
    mov [ebp + esi], al
    jnz .isConfused
    and byte [ebp + wPlayerBattleStatus1], ~(1 << CONFUSED) & 0xFF   ; counter 0 → clear
    mov esi, ConfusedNoMoreText
    call PrintText
    jmp .triedToUseDisabledMoveCheck
.isConfused:
    mov esi, IsConfusedText
    call PrintText
    mov byte [ebp + wAnimationType], 0
    mov al, CONF_PLAYER_ANIM
    call PlayMoveAnimation
    call BattleRandom
    cmp al, (50 * 0xFF / 100) + 1        ; 50 percent + 1 chance to hurt itself
    jc .triedToUseDisabledMoveCheck
    mov al, [ebp + wPlayerBattleStatus1] ; hurts itself: keep only CONFUSED, clear the rest
    and al, 1 << CONFUSED
    mov [ebp + wPlayerBattleStatus1], al
    call HandleSelfConfusionDamage
    jmp .monHurtItselfOrFullyParalysed

.triedToUseDisabledMoveCheck:            ; pret 3608
    mov al, [ebp + wPlayerDisabledMoveNumber]
    and al, al
    jz .paralysisCheck
    cmp al, [ebp + wPlayerSelectedMove]
    jne .paralysisCheck
    call PrintMoveIsDisabledText
    mov esi, ExecutePlayerMoveDone
    jmp .returnToHL

.paralysisCheck:                         ; pret 3620
    test byte [ebp + wBattleMonStatus], 1 << PAR
    jz .bideCheck
    call BattleRandom
    cmp al, (25 * 0xFF / 100)            ; 25 percent chance fully paralyzed
    jae .bideCheck
    mov esi, FullyParalyzedText
    call PrintText

.monHurtItselfOrFullyParalysed:          ; pret 3630
    ; clear bide/thrashing/charging-up/trapping (already cleared for confusion damage)
    ; BUG(cosmetic): "invulnerable for the whole battle" glitch — clearing CHARGING_UP
    ; but NOT INVULNERABLE strands a mon that is fully-paralyzed or self-confused
    ; mid-Fly/Dig invulnerable for the rest of the battle. pret documents this at
    ; engine/battle/core.asm:3284-3286 (and does it here at :3634). Preserved faithfully.
    mov al, [ebp + wPlayerBattleStatus1]
    and al, ~((1 << STORING_ENERGY) | (1 << THRASHING_ABOUT) | (1 << CHARGING_UP) | (1 << USING_TRAPPING_MOVE)) & 0xFF
%if BUG_FIX_LEVEL >= 2
    and al, ~(1 << INVULNERABLE) & 0xFF  ; fixed: also drop invulnerability when it can't act
%endif
    mov [ebp + wPlayerBattleStatus1], al
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, FLY_EFFECT
    je .flyOrChargeEffect
    cmp al, CHARGE_EFFECT
    jne .notFlyOrChargeEffect
.flyOrChargeEffect:
    mov byte [ebp + wAnimationType], 0
    mov al, STATUS_AFFECTED_ANIM
    call PlayMoveAnimation
.notFlyOrChargeEffect:
    mov esi, ExecutePlayerMoveDone       ; two-turn move: recharge/can't move this turn
    jmp .returnToHL

.bideCheck:                              ; pret 3652 — Bide
    test byte [ebp + wPlayerBattleStatus1], 1 << STORING_ENERGY
    jz .thrashingAboutCheck
    mov byte [ebp + wPlayerMoveNum], 0
    ; accumulate wDamage (big-endian) into wPlayerBideAccumulatedDamage (big-endian)
    mov al, [ebp + wDamage]              ; damage hi
    mov bh, al
    mov al, [ebp + wDamage + 1]          ; damage lo
    mov bl, al
    mov al, [ebp + wPlayerBideAccumulatedDamage + 1]
    add al, bl                           ; lo += damage lo
    mov [ebp + wPlayerBideAccumulatedDamage + 1], al
    mov al, [ebp + wPlayerBideAccumulatedDamage]
    adc al, bh                           ; hi += damage hi + carry
    mov [ebp + wPlayerBideAccumulatedDamage], al
    mov al, [ebp + wPlayerNumAttacksLeft]
    dec al
    mov [ebp + wPlayerNumAttacksLeft], al
    jz .unleashEnergy
    mov esi, ExecutePlayerMoveDone       ; still storing → can't move this turn
    jmp .returnToHL
.unleashEnergy:
    and byte [ebp + wPlayerBattleStatus1], ~(1 << STORING_ENERGY) & 0xFF
    mov esi, UnleashedEnergyText
    call PrintText
    mov byte [ebp + wPlayerMovePower], 1
    mov al, [ebp + wPlayerBideAccumulatedDamage + 1]   ; lo
    add al, al                           ; *2 (sets CF)
    mov bh, al
    mov [ebp + wDamage + 1], al
    mov al, [ebp + wPlayerBideAccumulatedDamage]       ; hi
    rcl al, 1                            ; rl a — double hi through carry
    mov [ebp + wDamage], al
    or al, bh                            ; released damage == 0?
    jnz .bideNext
    mov byte [ebp + wMoveMissed], 1
.bideNext:
    mov byte [ebp + wPlayerBideAccumulatedDamage], 0
    mov byte [ebp + wPlayerBideAccumulatedDamage + 1], 0
    mov byte [ebp + wPlayerMoveNum], BIDE
    ; pret .UnleashEnergy (core.asm:3674-3700) does NOT swap levels here; the
    ; port's speed/damage routines branch on hWhoseTurn instead of the swap
    ; trick, so a swap here is never undone → permanent level corruption.
    mov esi, HandleIfPlayerMoveMissed    ; skip calc/DecrementPP/MoveHitTest
    jmp .returnToHL

.thrashingAboutCheck:                    ; pret 3702 — Thrash / Petal Dance
    test byte [ebp + wPlayerBattleStatus1], 1 << THRASHING_ABOUT
    jz .multiturnMoveCheck
    mov byte [ebp + wPlayerMoveNum], THRASH
    mov esi, ThrashingAboutText
    call PrintText
    mov al, [ebp + wPlayerNumAttacksLeft]
    dec al
    mov [ebp + wPlayerNumAttacksLeft], al
    jnz .thrashContinue                  ; counter != 0 → keep thrashing
    and byte [ebp + wPlayerBattleStatus1], ~(1 << THRASHING_ABOUT) & 0xFF
    or  byte [ebp + wPlayerBattleStatus1], 1 << CONFUSED   ; confused when it ends
    call BattleRandom
    and al, 3
    add al, 2                            ; confused for 2-5 turns
    mov [ebp + wPlayerConfusedCounter], al
.thrashContinue:
    mov esi, PlayerCalcMoveDamage        ; skip DecrementPP
    jmp .returnToHL

.multiturnMoveCheck:                     ; pret 3725 — Wrap / Bind / Fire Spin / Clamp
    test byte [ebp + wPlayerBattleStatus1], 1 << USING_TRAPPING_MOVE
    jz .rageCheck
    mov esi, AttackContinuesText
    call PrintText
    mov al, [ebp + wPlayerNumAttacksLeft]
    dec al
    mov [ebp + wPlayerNumAttacksLeft], al
    mov esi, GetPlayerAnimationType      ; deal last-hit damage; skip calc/DecrementPP/MoveHitTest
    jmp .returnToHL

.rageCheck:                              ; pret 3739 — Rage
    test byte [ebp + wPlayerBattleStatus2], 1 << USING_RAGE
    jz .checkConditionsDone
    mov byte [ebp + wNamedObjectIndex], RAGE
    call GetMoveName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov byte [ebp + wPlayerMoveEffect], 0
    mov esi, PlayerCanExecuteMove
    jmp .returnToHL

.returnToHL:
    xor al, al                           ; ZF=1, ESI = continuation → caller jmp esi
    ret
.checkConditionsDone:                    ; pret 3756
    mov al, 1
    and al, al                           ; ZF=0 → mon may move normally
    ret

; ---------------------------------------------------------------------------
; HandleSelfConfusionDamage — faithful port of pret core.asm:3843. Typeless 40-power
; physical hit the confused mon deals to itself: temporarily swaps the attacker's own
; Defense into the "enemy" defense slot, runs the player-attack damage pipeline (no
; type adjust / no randomize / always hits, no crit), restores, and applies to self.
; ---------------------------------------------------------------------------
HandleSelfConfusionDamage:
    mov esi, HurtItselfText
    call PrintText
    ; save wEnemyMonDefense (word) and overwrite with wBattleMonDefense (the self-defender)
    mov al, [ebp + wEnemyMonDefense]
    mov dh, al                           ; save hi
    mov al, [ebp + wEnemyMonDefense + 1]
    mov dl, al                           ; save lo
    mov al, [ebp + wBattleMonDefense]
    mov [ebp + wEnemyMonDefense], al
    mov al, [ebp + wBattleMonDefense + 1]
    mov [ebp + wEnemyMonDefense + 1], al
    push edx                             ; stash saved enemy defense (DH:DL)
    ; save wPlayerMoveEffect, set a 40-BP typeless non-crit move
    mov al, [ebp + wPlayerMoveEffect]
    push eax                             ; save effect byte (AL)
    mov byte [ebp + wPlayerMoveEffect], 0
    mov byte [ebp + wCriticalHitOrOHKO], 0   ; self-hit can't crit
    mov byte [ebp + wPlayerMovePower], 40    ; 40 base power
    mov byte [ebp + wPlayerMoveType], 0      ; typeless (the byte after power; pret xor a / ld [hl])
    call GetDamageVarsForPlayerAttack
    call CalculateDamage                 ; no AdjustDamageForMoveType / Randomize / MoveHitTest
    pop eax                              ; restore effect byte
    mov [ebp + wPlayerMoveEffect], al
    pop edx                              ; restore enemy defense (DH:DL)
    mov al, dh
    mov [ebp + wEnemyMonDefense], al
    mov al, dl
    mov [ebp + wEnemyMonDefense + 1], al
    mov byte [ebp + wAnimationType], 0
    mov byte [ebp + hWhoseTurn], 1       ; play self-hit anim as the "enemy" side
    call PlayMoveAnimation
    call DrawPlayerHUDAndHPBar
    mov byte [ebp + hWhoseTurn], 0
    jmp ApplyDamageToPlayerPokemon       ; pret jp ApplyDamageToPlayerPokemon — skip the
                                         ; effect dispatch (self-hit is a fixed 40-BP hit)

; ---------------------------------------------------------------------------
; PrintMoveIsDisabledText — faithful port of pret core.asm:3821. Clears the user's
; CHARGING_UP bit and prints "<MOVE> is disabled!" for the disabled move. Handles both
; sides via hWhoseTurn (reused by the enemy status check).
; ---------------------------------------------------------------------------
PrintMoveIsDisabledText:
    mov esi, wPlayerSelectedMove         ; ld hl, wPlayerSelectedMove
    mov edx, wPlayerBattleStatus1        ; ld de, wPlayerBattleStatus1
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .removeChargingUp
    inc esi                              ; enemy: wEnemySelectedMove (= wPlayerSelectedMove+1)
    mov edx, wEnemyBattleStatus1
.removeChargingUp:
    and byte [ebp + edx], ~(1 << CHARGING_UP) & 0xFF   ; res CHARGING_UP
    mov al, [ebp + esi]
    mov [ebp + wNamedObjectIndex], al
    call GetMoveName
    mov esi, MoveIsDisabledText
    jmp PrintText

; ---------------------------------------------------------------------------
; SwapPlayerAndEnemyLevels — pret core.asm:6370. Bide computes its damage from the
; user's level, but the damage routine reads the "attacker" level; swapping puts the
; Bide user's level where the calc expects it (and swaps back after).
; ---------------------------------------------------------------------------
SwapPlayerAndEnemyLevels:
    push ebx
    mov al, [ebp + wBattleMonLevel]
    mov bl, al
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wBattleMonLevel], al
    mov [ebp + wEnemyMonLevel], bl
    pop ebx
    ret

; ---------------------------------------------------------------------------
; CopyToStringBuffer — pret home/copy_string.asm. Copies the '@'-terminated string
; at EDX (GB addr) into wStringBuffer. Used by the Rage continuation (move name).
; ---------------------------------------------------------------------------
global CopyToStringBuffer            ; Wave 5/M5.3: give.asm consumes it once linked
CopyToStringBuffer:
    mov edi, wStringBuffer
.copy:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + edi], al
    inc edi
    cmp al, 0x50                        ; '@'
    jne .copy
    ret

; ---------------------------------------------------------------------------
; CheckForDisobedience — faithful port of pret engine/battle/core.asm:4001-4178
; (Yellow traded-mon obedience). Traded mons (OTID != player ID) may disobey when
; the player lacks the badge for their level: the level ceiling steps 10→30→50→70→
; 101 with Cascade/Rainbow/Marsh/Earth badges. On disobedience the mon naps, loafs,
; hurts itself in confusion, or uses a random other move. Returns ZF=0 = "uses a
; move" (caller `jz ExecutePlayerMoveDone`); ZF=1 = turn is spent disobeying. Sets
; wMonIsDisobedient. RNG-consumption order preserved exactly (behaviorally load-bearing).
; ---------------------------------------------------------------------------
; Symbols pret has but the port's includes don't yet carry (traded-mon obedience).
; Verified vs pret ram/wram.asm + constants/ram_constants.asm (badge_boosts.asm also
; defines wObtainedBadges=0xD355 locally, so keep these file-local to avoid an include
; double-definition). MON_OTID (0x0C) and wPartyMon1 (0xD16A) come from the includes.
%ifndef wObtainedBadges
wObtainedBadges     equ 0xD355
%endif
wPartyMon1OTID      equ (wPartyMon1 + MON_OTID)
BIT_CASCADEBADGE    equ 1
BIT_RAINBOWBADGE    equ 3
BIT_MARSHBADGE      equ 5
BIT_EARTHBADGE      equ 7

CheckForDisobedience:
    xor al, al
    mov [ebp + wMonIsDisobedient], al
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jnz .checkIfMonIsTraded
    mov al, 1
    and al, al                          ; clear Z (always obeys in a link battle)
    ret
; compare the mon's original trainer ID with the player's ID to see if it was traded
.checkIfMonIsTraded:
    mov esi, wPartyMon1OTID
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wPlayerMonNumber]
    call AddNTimes                      ; esi -> active mon's OTID
    mov al, [ebp + wPlayerID]
    cmp al, [ebp + esi]
    jnz .monIsTraded
    inc esi
    mov al, [ebp + wPlayerID + 1]
    cmp al, [ebp + esi]
    jz .canUseMove                      ; OTID == player ID → not traded → obeys
.monIsTraded:
; what level might disobey?
    mov esi, wObtainedBadges
    test byte [ebp + esi], (1 << BIT_EARTHBADGE)
    mov al, 101
    jnz .next
    test byte [ebp + esi], (1 << BIT_MARSHBADGE)
    mov al, 70
    jnz .next
    test byte [ebp + esi], (1 << BIT_RAINBOWBADGE)
    mov al, 50
    jnz .next
    test byte [ebp + esi], (1 << BIT_CASCADEBADGE)
    mov al, 30
    jnz .next
    mov al, 10
.next:
    mov bl, al
    mov cl, al
    mov al, [ebp + wBattleMonLevel]
    mov dl, al
    add al, bl
    mov bl, al
    jnc .noCarry
    mov bl, 0xFF                        ; cap b at $ff
.noCarry:
    mov al, cl
    cmp al, dl
    jnc .canUseMove
.loop1:
    call BattleRandom
    rol al, 4                           ; swap a
    cmp al, bl
    jnc .loop1
    cmp al, cl
    jc .canUseMove
.loop2:
    call BattleRandom
    cmp al, bl
    jnc .loop2
    cmp al, cl
    jc .useRandomMove
    mov al, dl
    sub al, cl
    mov bl, al
    call BattleRandom
    rol al, 4                           ; swap a
    sub al, bl
    jc .monNaps
    cmp al, bl
    jnc .monDoesNothing
    mov eax, WontObeyText
    call PrintBattleText
    call HandleSelfConfusionDamage
    jmp .cannotUseMove
.monNaps:
    call BattleRandom
    add al, al
    rol al, 4                           ; swap a
    and al, SLP_MASK
    jz .monNaps                         ; keep trying until at least 1 turn of sleep
    mov [ebp + wBattleMonStatus], al
    mov eax, BeganToNapText
    jmp .printText
.monDoesNothing:
    call BattleRandom
    and al, 3
    ; pret keeps the roll in A while loading each text ptr into HL (`ld hl,imm16`
    ; doesn't touch A). On x86 `mov eax,<label>` WOULD clobber the roll, so park it
    ; in DL and test DL — the text selection stays RNG-driven (pret core.asm:4088-4101).
    mov dl, al
    mov eax, LoafingAroundText
    test dl, dl
    jz .printText
    mov eax, WontObeyText
    dec dl
    jz .printText
    mov eax, TurnedAwayText
    dec dl
    jz .printText
    mov eax, IgnoredOrdersText
.printText:
    call PrintBattleText
    jmp .cannotUseMove
.useRandomMove:
    mov al, [ebp + wBattleMonMoves + 1]
    and al, al                          ; second move slot empty?
    jz .monDoesNothing                  ; only one move → won't use a move
    mov al, [ebp + wPlayerDisabledMoveNumber]
    and al, al
    jnz .monDoesNothing
    mov al, [ebp + wPlayerSelectedMove]
    cmp al, STRUGGLE
    jz .monDoesNothing                  ; struggling → won't use a move
; check if only one move has remaining PP
    mov esi, wBattleMonPP
    push esi
    mov al, [ebp + esi]
    inc esi
    and al, PP_MASK
    mov bl, al
    mov al, [ebp + esi]
    inc esi
    and al, PP_MASK
    add al, bl
    mov bl, al
    mov al, [ebp + esi]
    inc esi
    and al, PP_MASK
    add al, bl
    mov bl, al
    mov al, [ebp + esi]
    and al, PP_MASK
    add al, bl
    pop esi
    push eax
    movzx eax, byte [ebp + wCurrentMenuItem]
    mov ecx, eax
    add esi, ecx
    mov al, [ebp + esi]
    and al, PP_MASK
    mov bl, al
    pop eax
    cmp al, bl
    jz .monDoesNothing                  ; only the selected move has PP → won't use a move
    mov al, 1
    mov [ebp + wMonIsDisobedient], al
    mov al, [ebp + wMaxMenuItem]
    mov bl, al
    mov al, [ebp + wCurrentMenuItem]
    mov cl, al
.chooseMove:
    call BattleRandom
    and al, 3
    cmp al, bl
    jnc .chooseMove                     ; random# > move count → re-roll
    cmp al, cl
    jz .chooseMove                      ; matches player's selection → re-roll
    mov [ebp + wCurrentMenuItem], al
    mov esi, wBattleMonPP
    movzx edx, al
    add esi, edx
    mov al, [ebp + esi]
    and al, al                          ; chosen move has PP?
    jz .chooseMove                      ; no PP → re-roll
    movzx ecx, byte [ebp + wCurrentMenuItem]
    mov esi, wBattleMonMoves
    add esi, ecx
    mov al, [ebp + esi]
    mov [ebp + wPlayerSelectedMove], al
    call GetCurrentMove
.canUseMove:
    mov al, 1
    and al, al                          ; clear Z flag → obeys / uses a move
    ret
.cannotUseMove:
    xor al, al                          ; set Z flag → does not use its chosen move
    ret

; ---------------------------------------------------------------------------
; ExecuteEnemyMove — pret engine/battle/core.asm:ExecuteEnemyMove (5639), faithful
; mirror of ExecutePlayerMove with the enemy's move fields, applying damage to the
; player mon. Enemy PP is not decremented (player-only PP, per project scope). Same
; TODO(faithful) deepening list as ExecutePlayerMove (status/effects/multi-hit/…).
; Returns b in BH (0 = player mon fainted, else ExecuteEnemyMoveDone sets b=1).
; ---------------------------------------------------------------------------
; Faithful port of pret engine/battle/core.asm:ExecuteEnemyMove (5639) — mirror of
; ExecutePlayerMove with the enemy's WRAM. Re-entry labels (EnemyCanExecuteMove/
; EnemyCalcMoveDamage/HandleIfEnemyMoveMissed/GetEnemyAnimationType/
; EnemyCheckIfFlyOrChargeEffect/EnemyCheckIfMirrorMoveEffect) for Stage 3.
; Enemy PP is not decremented (player-only PP, per project scope). Enemy obedience
; is player-only, so there is no CheckForDisobedience on this side.
ExecuteEnemyMove:
    mov byte [ebp + hWhoseTurn], 1
    mov al, [ebp + wEnemySelectedMove]
    inc al                              ; CANNOT_MOVE → 0
    jz  ExecuteEnemyMoveDone
    mov byte [ebp + wMoveMissed], 0
    mov byte [ebp + wMonIsDisobedient], 0
    mov byte [ebp + wMoveDidntMiss], 0
    mov byte [ebp + wDamageMultipliers], EFFECTIVE
    call PrintGhostText                 ; (stub: not ghost → ZF=0)
    jz  ExecuteEnemyMoveDone
    inc byte [ebp + wAILayer2Encouragement]  ; pret core.asm:5656-5657 — read by AIMoveChoiceModification2
    call CheckEnemyStatusConditions
    jnz .enemyHasNoSpecialCondition
    jmp esi                             ; jp hl — handled; ESI = continuation
.enemyHasNoSpecialCondition:
    call GetCurrentMove                 ; hWhoseTurn=1 → loads wEnemyMove*
    test byte [ebp + wEnemyBattleStatus1], 1 << CHARGING_UP
    jnz EnemyCanExecuteChargingMove
CheckIfEnemyNeedsToChargeUp:            ; pret 5672
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, CHARGE_EFFECT
    je  JumpMoveEffect
    cmp al, FLY_EFFECT
    je  JumpMoveEffect
    jmp EnemyCanExecuteMove
EnemyCanExecuteChargingMove:            ; pret 5679
    and byte [ebp + wEnemyBattleStatus1], ~(1 << CHARGING_UP) & 0xFF
    and byte [ebp + wEnemyBattleStatus1], ~(1 << INVULNERABLE) & 0xFF
EnemyCanExecuteMove:                    ; pret 5692 — Rage continuation
    call DisplayUsedMoveText            ; "Enemy X used MOVE!" (enemy PP not decremented)
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, ResidualEffects1
    mov edx, 1
    call IsInArray
    jc  JumpMoveEffect
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, SpecialEffectsCont
    mov edx, 1
    call IsInArray
    jnc EnemyCalcMoveDamage
    call JumpMoveEffect
EnemyCalcMoveDamage:                    ; pret 5706 — Thrash continuation
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, SetDamageEffects
    mov edx, 1
    call IsInArray
    jc  .eMoveHitTest
    call CriticalHitTest
    call HandleCounterMove              ; (stub: not counter → ZF=0)
    jz  HandleIfEnemyMoveMissed
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    jz  EnemyCheckIfFlyOrChargeEffect   ; jp z — 0 BP status move
    call AdjustDamageForMoveType
    call RandomizeDamage
.eMoveHitTest:
    call MoveHitTest
HandleIfEnemyMoveMissed:                ; pret 5726 — Bide continuation
    mov al, [ebp + wMoveMissed]
    and al, al
    jz  GetEnemyAnimationType
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, EXPLODE_EFFECT
    je  PlayEnemyMoveAnimation
    jmp EnemyCheckIfFlyOrChargeEffect
GetEnemyAnimationType:                  ; pret 5737 — Trapping continuation / multi-hit loop
    mov al, [ebp + wEnemyMoveEffect]
    and al, al
    mov al, ANIMATIONTYPE_BLINK_ENEMY_MON_SPRITE
    jz  PlayEnemyMoveAnimation
    mov al, ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT
PlayEnemyMoveAnimation:
    push eax
    test byte [ebp + wEnemyBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jz  .noSub
    call HideSubstituteShowMonAnim
.noSub:
    pop eax
    mov [ebp + wAnimationType], al
    mov al, [ebp + wEnemyMoveNum]
    call PlayMoveAnimation
    call HandleExplodingAnimation
    call DrawEnemyHUDAndHPBar           ; pret DrawEnemyHUDAndHPBar (enemy-only redraw)
    test byte [ebp + wEnemyBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jz  EnemyCheckIfMirrorMoveEffect
    call ReshowSubstituteAnim
    jmp EnemyCheckIfMirrorMoveEffect
EnemyCheckIfFlyOrChargeEffect:          ; pret 5767
    mov bl, 30
    call DelayFrames
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, FLY_EFFECT
    je  .flyChargeAnim
    cmp al, CHARGE_EFFECT
    je  .flyChargeAnim
    jmp EnemyCheckIfMirrorMoveEffect
.flyChargeAnim:
    mov byte [ebp + wAnimationType], 0
    mov al, STATUS_AFFECTED_ANIM
    call PlayMoveAnimation
EnemyCheckIfMirrorMoveEffect:           ; pret 5782
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, MIRROR_MOVE_EFFECT
    jne .metronomeCheck
    call MirrorMoveCopyMove
    jz  ExecuteEnemyMoveDone
    mov byte [ebp + wMonIsDisobedient], 0
    jmp CheckIfEnemyNeedsToChargeUp
.metronomeCheck:
    cmp al, METRONOME_EFFECT
    jne .mirrorNext
    call MetronomePickMove
    jmp CheckIfEnemyNeedsToChargeUp
.mirrorNext:
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, ResidualEffects2
    mov edx, 1
    call IsInArray
    jc  JumpMoveEffect
    mov al, [ebp + wMoveMissed]
    and al, al
    jz  .eMoveDidNotMiss
    call PrintMoveFailureText           ; pret 5779 — DoesntAffect/miss/unaffected + JumpKick recoil
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, EXPLODE_EFFECT
    je  .eNotDone
    jmp ExecuteEnemyMoveDone
.eMoveDidNotMiss:
    call ApplyAttackToPlayerPokemon     ; player HP -= wDamage (floored)
    call PrintCriticalOHKOText          ; (stub)
    call DisplayEffectiveness           ; (stub)
    mov byte [ebp + wMoveDidntMiss], 1
.eNotDone:
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, AlwaysHappenSideEffects
    mov edx, 1
    call IsInArray
    jnc .eSkipAlwaysHappen
    call JumpMoveEffect
.eSkipAlwaysHappen:
    mov al, [ebp + wBattleMonHP]
    or  al, [ebp + wBattleMonHP + 1]
    jz  .eTargetFainted
    call HandleBuildingRage
    test byte [ebp + wEnemyBattleStatus1], 1 << ATTACKING_MULTIPLE_TIMES
    jz  .eExecuteOtherEffects
    mov al, [ebp + wEnemyNumAttacksLeft]
    dec al
    mov [ebp + wEnemyNumAttacksLeft], al
    jnz GetEnemyAnimationType           ; multi-hit loop
    and byte [ebp + wEnemyBattleStatus1], ~(1 << ATTACKING_MULTIPLE_TIMES) & 0xFF
    mov esi, MultiHitText
    call PrintText
    mov byte [ebp + wEnemyNumHits], 0
.eExecuteOtherEffects:
    mov al, [ebp + wEnemyMoveEffect]
    and al, al
    jz  ExecuteEnemyMoveDone
    mov esi, SpecialEffects
    mov edx, 1
    call IsInArray
    jc  ExecuteEnemyMoveDone
    call JumpMoveEffect
    jmp ExecuteEnemyMoveDone
.eTargetFainted:
    xor bh, bh                          ; b = 0 → player mon fainted
    ret

ExecuteEnemyMoveDone:
    mov bh, 1
    ret

; ApplyAttackToPlayerPokemon — faithful port of pret core.asm:4902. Mirror of the
; enemy version with the player mon's WRAM and the enemy's move fields.
; ApplyDamageToPlayerPokemon (pret :4968) is the plain HP-subtract entry the player
; confusion self-hit jumps to (skips the effect dispatch).
ApplyAttackToPlayerPokemon:
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, OHKO_EFFECT
    je  ApplyDamageToPlayerPokemon
    cmp al, SUPER_FANG_EFFECT
    je  .superFang
    cmp al, SPECIAL_DAMAGE_EFFECT
    je  .specialDamage
    mov al, [ebp + wEnemyMovePower]
    and al, al
    jz  ApplyAttackToPlayerPokemonDone   ; 0 base power → no attack to apply
    jmp ApplyDamageToPlayerPokemon
.superFang:                              ; wDamage = player current HP / 2 (min 1)
    mov al, [ebp + wBattleMonHP]
    shr al, 1
    mov [ebp + wDamage], al
    mov bh, al
    mov al, [ebp + wBattleMonHP + 1]
    rcr al, 1
    mov [ebp + wDamage + 1], al
    or  al, bh
    jnz ApplyDamageToPlayerPokemon
    mov byte [ebp + wDamage + 1], 1
    jmp ApplyDamageToPlayerPokemon
.specialDamage:
    mov bh, [ebp + wEnemyMonLevel]       ; Seismic Toss / Night Shade = user level
    mov al, [ebp + wEnemyMoveNum]
    cmp al, SEISMIC_TOSS
    je  .storeSpecial
    cmp al, NIGHT_SHADE
    je  .storeSpecial
    mov bh, SONICBOOM_DAMAGE
    cmp al, SONICBOOM
    je  .storeSpecial
    mov bh, DRAGON_RAGE_DAMAGE
    cmp al, DRAGON_RAGE
    je  .storeSpecial
    ; Psywave: bh = user level * 1.5; random in [0, bh). GLITCH(faithful): the enemy
    ; can deal 0 damage with Psywave (no reject-0), unlike the player's [1, bh) — see
    ; pret core.asm:4953-4955.
    mov al, [ebp + wEnemyMonLevel]
    mov bh, al
    shr al, 1
    add al, bh
    mov bh, al
.psywaveLoop:
    call BattleRandom
    cmp al, bh
    jae .psywaveLoop
    mov bh, al
.storeSpecial:
    mov byte [ebp + wDamage], 0
    mov [ebp + wDamage + 1], bh
    ; fall through

global ApplyDamageToPlayerPokemon       ; consumed by print_move_failure.asm (JumpKick recoil)
ApplyDamageToPlayerPokemon:
    mov al, [ebp + wDamage]
    or  al, [ebp + wDamage + 1]
    jz  ApplyAttackToPlayerPokemonDone
    test byte [ebp + wPlayerBattleStatus2], 1 << HAS_SUBSTITUTE_UP
    jnz AttackSubstitute
    mov bl, [ebp + wDamage + 1]
    mov al, [ebp + wBattleMonHP + 1]
    mov [ebp + wHPBarOldHP], al
    sub al, bl
    mov [ebp + wBattleMonHP + 1], al
    mov bl, [ebp + wDamage]
    mov al, [ebp + wBattleMonHP]
    mov [ebp + wHPBarOldHP + 1], al
    sbb al, bl
    mov [ebp + wBattleMonHP], al
    jnc .animateHpBar
    mov al, [ebp + wHPBarOldHP + 1]
    mov [ebp + wDamage], al
    mov al, [ebp + wHPBarOldHP]
    mov [ebp + wDamage + 1], al
    mov byte [ebp + wBattleMonHP], 0
    mov byte [ebp + wBattleMonHP + 1], 0
.animateHpBar:
    mov al, [ebp + wBattleMonMaxHP]
    mov [ebp + wHPBarMaxHP + 1], al
    mov al, [ebp + wBattleMonMaxHP + 1]
    mov [ebp + wHPBarMaxHP], al
    mov al, [ebp + wBattleMonHP]
    mov [ebp + wHPBarNewHP + 1], al
    mov al, [ebp + wBattleMonHP + 1]
    mov [ebp + wHPBarNewHP], al
    ; pret: hlcoord 10,9 / ld a,1 / ld [wHPBarType],a / predef UpdateHPBar2 — gradual drain
    ; of the PLAYER bar (ticks the HP number too), from wHPBarOldHP down to new struct HP.
    movzx ecx, word [ebp + wHPBarOldHP]     ; old HP (pret little-endian) → drain start
    call AnimatePlayerHPBar
ApplyAttackToPlayerPokemonDone:
    jmp DrawHUDsAndHPBars                    ; pret `jp DrawHUDsAndHPBars` (tail; its ret returns)

; ---------------------------------------------------------------------------
; AttackSubstitute — faithful port of pret core.asm:5020. Shared by both sides:
; the target's Substitute absorbs the hit instead of the mon. Redirected here from
; ApplyDamageTo{Enemy,Player}Pokemon when the target has HAS_SUBSTITUTE_UP set.
; ---------------------------------------------------------------------------
AttackSubstitute:
    mov esi, SubstituteTookDamageText
    call PrintText
    mov edx, wEnemySubstituteHP          ; player turn: target = enemy
    mov ebx, wEnemyBattleStatus2
    cmp byte [ebp + hWhoseTurn], 0
    je  .subApply
    mov edx, wPlayerSubstituteHP         ; enemy turn: target = player
    mov ebx, wPlayerBattleStatus2
.subApply:
    mov al, [ebp + wDamage]              ; wDamage high byte
    and al, al
    jnz .subBroke                        ; damage > 0xFF always breaks the substitute
    mov al, [ebp + edx]                  ; substitute HP
    sub al, [ebp + wDamage + 1]
    mov [ebp + edx], al
    jnc .subDone                         ; substitute survived (no borrow)
.subBroke:
    and byte [ebp + ebx], ~(1 << HAS_SUBSTITUTE_UP) & 0xFF   ; clear the substitute bit
    mov esi, SubstituteBrokeText
    call PrintText
    ; TODO(anim): pret flips hWhoseTurn around callfar Func_79929 (substitute-break
    ; anim) then flips back — a no-op here (anim deferred, Master B), so skipped.
    ; nullify the attacker's move effect (pret core.asm:5066-5072)
    mov esi, wPlayerMoveEffect           ; player turn
    cmp byte [ebp + hWhoseTurn], 0
    je  .subNullify
    mov esi, wEnemyMoveEffect            ; enemy turn
.subNullify:
    mov byte [ebp + esi], 0
    ; BUG(faithful): wDamage is NOT updated with the substitute's pre-hit HP on a
    ; break (pret core.asm:5050-5051) — preserved verbatim.
.subDone:
    ret

; ---------------------------------------------------------------------------
; CheckEnemyStatusConditions — faithful port of pret core.asm:5859 (mirror of
; CheckPlayerStatusConditions with the enemy's WRAM). Same ZF/ESI contract:
; ZF=1 + ESI=continuation → handled; ZF=0 + AL=1 → enemy may move.
; The enemy confusion self-hit is inlined (pret 5957-5996). Multi-turn lock-ins
; fall through to .done for now — TODO(Stage 3).
; ---------------------------------------------------------------------------
CheckEnemyStatusConditions:
    mov esi, wEnemyMonStatus
    mov al, [ebp + esi]
    and al, SLP_MASK
    jz .eFrozenCheck
    dec al                               ; sleeping — decrement turns left
    mov [ebp + wEnemyMonStatus], al
    and al, al
    jz .eWakeUp
    mov esi, FastAsleepText
    call PrintText
    mov byte [ebp + wAnimationType], 0
    mov al, SLP_ANIM
    call PlayMoveAnimation
    jmp .eSleepDone
.eWakeUp:
    mov esi, WokeUpText
    call PrintText
.eSleepDone:
    mov byte [ebp + wEnemyUsedMove], 0
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eFrozenCheck:                           ; pret 5883
    test byte [ebp + esi], 1 << FRZ
    jz .eTrappedCheck
    mov esi, IsFrozenText
    call PrintText
    mov byte [ebp + wEnemyUsedMove], 0
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eTrappedCheck:                          ; pret 5892 — player using a trapping move on us
    test byte [ebp + wPlayerBattleStatus1], 1 << USING_TRAPPING_MOVE
    jz .eFlinchedCheck
    mov esi, CantMoveText
    call PrintText
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eFlinchedCheck:                         ; pret 5900
    test byte [ebp + wEnemyBattleStatus1], 1 << FLINCHED
    jz .eRechargeCheck
    and byte [ebp + wEnemyBattleStatus1], ~(1 << FLINCHED) & 0xFF
    mov esi, FlinchedText
    call PrintText
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eRechargeCheck:                         ; pret 5909
    test byte [ebp + wEnemyBattleStatus2], 1 << NEEDS_TO_RECHARGE
    jz .eDisabledCheck
    and byte [ebp + wEnemyBattleStatus2], ~(1 << NEEDS_TO_RECHARGE) & 0xFF
    mov esi, MustRechargeText
    call PrintText
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eDisabledCheck:                         ; pret 5918
    mov al, [ebp + wEnemyDisabledMove]
    and al, al
    jz .eConfusedCheck
    dec al
    mov [ebp + wEnemyDisabledMove], al
    and al, 0x0F
    jnz .eConfusedCheck
    mov byte [ebp + wEnemyDisabledMove], 0
    mov byte [ebp + wEnemyDisabledMoveNumber], 0
    mov esi, DisabledNoMoreText
    call PrintText

.eConfusedCheck:                         ; pret 5931
    test byte [ebp + wEnemyBattleStatus1], 1 << CONFUSED
    jz .eTriedDisabledCheck
    mov esi, wEnemyConfusedCounter
    mov al, [ebp + esi]
    dec al
    mov [ebp + esi], al
    jnz .eIsConfused
    and byte [ebp + wEnemyBattleStatus1], ~(1 << CONFUSED) & 0xFF
    mov esi, ConfusedNoMoreText
    call PrintText
    jmp .eTriedDisabledCheck
.eIsConfused:
    mov esi, IsConfusedText
    call PrintText
    mov byte [ebp + wAnimationType], 0
    mov al, CONF_ANIM
    call PlayMoveAnimation
    call BattleRandom
    cmp al, 0x80                         ; pret cp $80 (= 50% + 1)
    jc .eTriedDisabledCheck
    ; hurts itself — keep only CONFUSED, clear the rest
    mov al, [ebp + wEnemyBattleStatus1]
    and al, 1 << CONFUSED
    mov [ebp + wEnemyBattleStatus1], al
    mov esi, HurtItselfText
    call PrintText
    ; swap wBattleMonDefense (save) ← wEnemyMonDefense (self-defender); 40-BP typeless self-hit
    mov al, [ebp + wBattleMonDefense]
    mov dh, al
    mov al, [ebp + wBattleMonDefense + 1]
    mov dl, al
    mov al, [ebp + wEnemyMonDefense]
    mov [ebp + wBattleMonDefense], al
    mov al, [ebp + wEnemyMonDefense + 1]
    mov [ebp + wBattleMonDefense + 1], al
    push edx
    mov al, [ebp + wEnemyMoveEffect]
    push eax
    mov byte [ebp + wEnemyMoveEffect], 0
    mov byte [ebp + wCriticalHitOrOHKO], 0
    mov byte [ebp + wEnemyMovePower], 40
    mov byte [ebp + wEnemyMoveType], 0
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    pop eax
    mov [ebp + wEnemyMoveEffect], al
    pop edx
    mov al, dh
    mov [ebp + wBattleMonDefense], al
    mov al, dl
    mov [ebp + wBattleMonDefense + 1], al
    mov byte [ebp + wAnimationType], 0
    mov byte [ebp + hWhoseTurn], 0
    mov al, POUND
    call PlayMoveAnimation
    mov byte [ebp + hWhoseTurn], 1
    call ApplyDamageToEnemyPokemon       ; skip effect dispatch (confusion self-hit)
    jmp .eMonHurtItselfOrFullyParalysed

.eTriedDisabledCheck:                    ; pret 5998
    mov al, [ebp + wEnemyDisabledMoveNumber]
    and al, al
    jz .eParalysisCheck
    cmp al, [ebp + wEnemySelectedMove]
    jne .eParalysisCheck
    call PrintMoveIsDisabledText
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eParalysisCheck:                        ; pret 6009
    test byte [ebp + wEnemyMonStatus], 1 << PAR
    jz .eBideCheck
    call BattleRandom
    cmp al, (25 * 0xFF / 100)
    jae .eBideCheck
    mov esi, FullyParalyzedText
    call PrintText

.eMonHurtItselfOrFullyParalysed:         ; pret 6018
    ; BUG(cosmetic): "invulnerable for the whole battle" glitch (enemy side) — see the
    ; player MonHurtItselfOrFullyParalysed note. pret ref core.asm:3284-3286 / :6022.
    mov al, [ebp + wEnemyBattleStatus1]
    and al, ~((1 << STORING_ENERGY) | (1 << THRASHING_ABOUT) | (1 << CHARGING_UP) | (1 << USING_TRAPPING_MOVE)) & 0xFF
%if BUG_FIX_LEVEL >= 2
    and al, ~(1 << INVULNERABLE) & 0xFF  ; fixed: also drop invulnerability when it can't act
%endif
    mov [ebp + wEnemyBattleStatus1], al
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, FLY_EFFECT
    je .eFlyOrChargeEffect
    cmp al, CHARGE_EFFECT
    jne .eNotFlyOrChargeEffect
.eFlyOrChargeEffect:
    mov byte [ebp + wAnimationType], 0
    mov al, STATUS_AFFECTED_ANIM
    call PlayMoveAnimation
.eNotFlyOrChargeEffect:
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL

.eBideCheck:                             ; pret 6038 — Bide
    test byte [ebp + wEnemyBattleStatus1], 1 << STORING_ENERGY
    jz .eThrashingAboutCheck
    mov byte [ebp + wEnemyMoveNum], 0
    mov al, [ebp + wDamage]
    mov bh, al
    mov al, [ebp + wDamage + 1]
    mov bl, al
    mov al, [ebp + wEnemyBideAccumulatedDamage + 1]
    add al, bl
    mov [ebp + wEnemyBideAccumulatedDamage + 1], al
    mov al, [ebp + wEnemyBideAccumulatedDamage]
    adc al, bh
    mov [ebp + wEnemyBideAccumulatedDamage], al
    mov al, [ebp + wEnemyNumAttacksLeft]
    dec al
    mov [ebp + wEnemyNumAttacksLeft], al
    jz .eUnleashEnergy
    mov esi, ExecuteEnemyMoveDone
    jmp .eReturnToHL
.eUnleashEnergy:
    and byte [ebp + wEnemyBattleStatus1], ~(1 << STORING_ENERGY) & 0xFF
    mov esi, UnleashedEnergyText
    call PrintText
    mov byte [ebp + wEnemyMovePower], 1
    mov al, [ebp + wEnemyBideAccumulatedDamage + 1]
    add al, al
    mov bh, al
    mov [ebp + wDamage + 1], al
    mov al, [ebp + wEnemyBideAccumulatedDamage]
    rcl al, 1
    mov [ebp + wDamage], al
    or al, bh
    jnz .eBideNext
    mov byte [ebp + wMoveMissed], 1
.eBideNext:
    mov byte [ebp + wEnemyBideAccumulatedDamage], 0
    mov byte [ebp + wEnemyBideAccumulatedDamage + 1], 0
    mov byte [ebp + wEnemyMoveNum], BIDE
    ; pret's enemy Bide unleash (core.asm:6085 region) pairs its swap with the
    ; un-swaps in HandleIfEnemyMoveMissed continuations, which the port stripped
    ; (hWhoseTurn-based routines). A swap here would never be undone.
    mov esi, HandleIfEnemyMoveMissed
    jmp .eReturnToHL

.eThrashingAboutCheck:                   ; pret 6088 — Thrash / Petal Dance
    test byte [ebp + wEnemyBattleStatus1], 1 << THRASHING_ABOUT
    jz .eMultiturnMoveCheck
    mov byte [ebp + wEnemyMoveNum], THRASH
    mov esi, ThrashingAboutText
    call PrintText
    mov al, [ebp + wEnemyNumAttacksLeft]
    dec al
    mov [ebp + wEnemyNumAttacksLeft], al
    jnz .eThrashContinue
    and byte [ebp + wEnemyBattleStatus1], ~(1 << THRASHING_ABOUT) & 0xFF
    or  byte [ebp + wEnemyBattleStatus1], 1 << CONFUSED
    call BattleRandom
    and al, 3
    add al, 2
    mov [ebp + wEnemyConfusedCounter], al
.eThrashContinue:
    mov esi, EnemyCalcMoveDamage
    jmp .eReturnToHL

.eMultiturnMoveCheck:                    ; pret 6110 — Wrap / Bind / Fire Spin / Clamp
    test byte [ebp + wEnemyBattleStatus1], 1 << USING_TRAPPING_MOVE
    jz .eRageCheck
    mov esi, AttackContinuesText
    call PrintText
    mov al, [ebp + wEnemyNumAttacksLeft]
    dec al
    mov [ebp + wEnemyNumAttacksLeft], al
    mov esi, GetEnemyAnimationType
    jmp .eReturnToHL

.eRageCheck:                             ; pret 6122 — Rage
    test byte [ebp + wEnemyBattleStatus2], 1 << USING_RAGE
    jz .eDone
    mov byte [ebp + wNamedObjectIndex], RAGE
    call GetMoveName
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov byte [ebp + wEnemyMoveEffect], 0
    mov esi, EnemyCanExecuteMove
    jmp .eReturnToHL

.eReturnToHL:
    xor al, al                           ; ZF=1, ESI = continuation
    ret
.eDone:                                  ; pret 6137
    mov al, 1
    and al, al                           ; ZF=0 → enemy may move
    ret

; ---------------------------------------------------------------------------
; HandleEnemyMonFainted — faithful port of pret core.asm:708-739. FaintEnemyPokemon
; (announce + EXP/EXP-ALL + party-slot zero) → AnyPartyAlive→blackout guard → wild:
; battle ends (ret) → trainer: AnyEnemyPokemonAliveCheck → TrainerBattleVictory (all
; down) or send out the next enemy mon and loop MainInBattleLoop.
; ---------------------------------------------------------------------------
HandleEnemyMonFainted:
    mov byte [ebp + wInHandlePlayerMonFainted], 0
    call FaintEnemyPokemon              ; "Enemy <nick> fainted!" + EXP(-ALL) + slot zero
    call AnyPartyAlive
    test dh, dh
    jz  HandlePlayerBlackOut            ; no live player mon → blackout
    mov al, [ebp + wBattleMonHP]
    or  al, [ebp + wBattleMonHP + 1]
    jz  .skipDrawPlayerHUD
    call DrawPlayerHUDAndHPBar          ; pret: call nz (battle mon still alive)
.skipDrawPlayerHUD:
    mov al, [ebp + wIsInBattle]
    dec al
    jz  .ret                            ; wild encounter → battle over
    call AnyEnemyPokemonAliveCheck
    jz  TrainerBattleVictory            ; all enemy mons fainted → win (prize money)
    ; pret 725-731: if the player's battle mon ALSO fainted (double KO, e.g. recoil),
    ; switch in a new player mon before replacing the enemy mon. (pret flags this call
    ; "useless in a trainer battle" but ports it — kept faithful, not dropped.)
    mov al, [ebp + wBattleMonHP]
    or  al, [ebp + wBattleMonHP + 1]
    jnz .skipReplacingBattleMon
    call DoUseNextMonDialogue
    jc  .ret                            ; player ran
    call ChooseNextMon
.skipReplacingBattleMon:
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    call ReplaceFaintedEnemyMon
    jz  EnemyRan                        ; link-only: enemy chose to run
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    jmp MainInBattleLoop
.ret:
    ret

; ---------------------------------------------------------------------------
; HandlePlayerMonFainted — faithful port of pret core.asm:981-1012. Remove the
; fainted mon → AnyPartyAlive→blackout → if the enemy is also KO'd, faint it (wild:
; end; trainer: victory or continue) → else DoUseNextMonDialogue + ChooseNextMon
; (forced switch-in) → loop MainInBattleLoop.
; ---------------------------------------------------------------------------
HandlePlayerMonFainted:
    mov byte [ebp + wInHandlePlayerMonFainted], 1
    call RemoveFaintedPlayerMon         ; clear exp flag, "<nick> fainted!", state
    call AnyPartyAlive
    test dh, dh
    jz  HandlePlayerBlackOut            ; no live mon → blackout
    mov al, [ebp + wEnemyMonHP]
    or  al, [ebp + wEnemyMonHP + 1]
    jnz .doUseNextMonDialogue           ; enemy still alive → just switch our mon
    ; both mons fainted (e.g. recoil KO): resolve the enemy faint first
    call FaintEnemyPokemon
    mov al, [ebp + wIsInBattle]
    dec al
    jz  .ret                            ; wild → battle over
    call AnyEnemyPokemonAliveCheck
    jz  TrainerBattleVictory
.doUseNextMonDialogue:
    call DoUseNextMonDialogue
    jc  .ret                            ; player ran (wild "use next mon?" → No → ran)
    call ChooseNextMon                  ; forced switch-in; ZF=1 if enemy HP 0
    jnz MainInBattleLoop                ; enemy still alive → resume the battle
    ; enemy also has 0 HP → send out the next enemy mon (trainer) / end
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    call ReplaceFaintedEnemyMon
    jz  EnemyRan
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    jmp MainInBattleLoop
.ret:
    ret

; ---------------------------------------------------------------------------
; ReadPlayerMonCurHPAndStatus — pret: copy the active party mon's HP/status into the
; battle-mon struct. In our scope the battle-mon struct IS the live source (seeded /
; updated in place), so this is a no-op for now.
; TODO(faithful): sync from wPartyMon[wPlayerMonNumber] once party↔battle-mon load
; (LoadBattleMonFromParty) is wired.
; ---------------------------------------------------------------------------
ReadPlayerMonCurHPAndStatus:
    ret

; ---------------------------------------------------------------------------
; CheckNumAttacksLeft — pret core.asm: manage multi-turn move counters (Bide/Thrash/
; Wrap → clear the multi-turn flags when the counter runs out).
; TODO(faithful): translate. No-op until the multi-turn move effects are wired.
; ---------------------------------------------------------------------------
CheckNumAttacksLeft:
    ret

; ---------------------------------------------------------------------------
; BattleMenu_RunWasSelected — pret core.asm:BattleMenu_RunWasSelected (2552). Restore
; the clean screen, try to flee; CF=escaped (battle ends), else if the turn was used
; the enemy gets a free move (MainInBattleLoop continues), else re-show the menu.
; ---------------------------------------------------------------------------
BattleMenu_RunWasSelected:
    call LoadScreenTilesFromBuffer1
    mov byte [ebp + wCurrentMenuItem], 3
    call TryRunningFromBattle           ; CF = escaped; sets wActionResultOrTookBattleTurn
    jc  .escaped
    mov al, [ebp + wActionResultOrTookBattleTurn]
    and al, al
    jnz .turnTaken                      ; couldn't escape, turn used → enemy attacks
    jmp DisplayBattleMenu               ; no turn taken (trainer no-run) → re-menu
.turnTaken:
    clc                                 ; not escaped; MainInBattleLoop runs the enemy move
    ret
.escaped:
    stc                                 ; MainInBattleLoop: jc .ret → battle ends (ran)
    ret
