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

; battle menu geometry — pret GB coords projected to our 40-wide canvas (+10col,+3row).
; (The coord VALUES are the sanctioned draw-layer divergence; the structure is pret's.)
%define FW          40
%define MENU_ROW    17          ; pret wTopMenuItemY $e (GB 14) + 3
%define CUR_COL_L   19          ; left column  (GB 9 + 10)  — FIGHT / PKMN
%define CUR_COL_R   25          ; right column (GB 15 + 10) — ITEM / RUN
%define T_SPACE     0x7F
%define T_H         0x7A        ; box ─
%define T_BR        0x7E        ; box ┘
; move menu (pret hlcoord 4,12 box / 6,13 text projected; audit-verified positions)
%define MOVEBOX_OFF   (15 * FW + 14)   ; box top-left, GB(4,12) → canvas (14,15)
%define MOVEBOX_W     14
%define MOVEBOX_H     4
%define MOVES_TEXT    (16 * FW + 16)   ; move list, GB(6,13) → canvas (16,16)
%define MOVES_CUR_COL 15                ; GB 5 + 10
%define MOVES_ROW0    16                ; GB 13 + 3
; battle dialog box (pret MESSAGE_BOX GB(0,12) projected) + message geometry
%define OUTER_OFF     (15 * FW + 10)    ; dialog box top-left, GB(0,12) → canvas (10,15)
%define OUTER_W       18
%define OUTER_H       4
%define BTXT_LINE1    (17 * FW + 11)    ; 1st text line (1,14) → canvas (11,17)
%define BTXT_LINE2    (19 * FW + 11)    ; 2nd text line (<LINE>) → canvas (11,19)
%define BTXT_ARROW    (19 * FW + 28)    ; ▼ at the box bottom-right interior
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
extern FindMoveName                    ; battle_menu.asm — move id → flat name ptr
extern GainExperience                  ; experience.asm — EXP award + level-up display
extern TryRunningFromBattle            ; battle_menu.asm — flee odds (CF = escaped)

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
; TODO(faithful, deepen — each currently simplified/skipped, clearly marked):
;   - PrintGhostText (Pokémon Tower ghosts)         - charging moves (Fly/Dig/SolarBeam)
;   - the IsInArray effect-array gating (SpecialEffectsCont / SetDamageEffects /
;     ResidualEffects2 / AlwaysHappenSideEffects / SpecialEffects) — here JumpMoveEffect
;     runs once after damage (covers the common post-damage side effect)
;   - HandleCounterMove, multi-hit loop, Mirror Move / Metronome, Explosion handling
;   - PrintCriticalOHKOText, DisplayEffectiveness, HandleBuildingRage, move-failure text
; ---------------------------------------------------------------------------
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
    call CheckPlayerStatusConditions    ; ZF=0 → no condition (proceed); ZF=1 → can't move
    jnz .noCondition
    mov bh, 1                           ; (TODO: faithful handlers set b) — treat as no faint
    ret
.noCondition:
    call GetCurrentMove                 ; selected move → wPlayerMove* (+ name buffer)
    call CheckForDisobedience           ; (stub: obedient)
    call DisplayUsedMoveText            ; "X used MOVE!" (no wait — pret text_end)
    mov edx, wPlayerSelectedMove        ; DE = ptr to the move id just used
    call DecrementPP
    call CriticalHitTest
    call GetDamageVarsForPlayerAttack
    call CalculateDamage                ; ZF=1 → 0 BP (status move)
    jz  .statusMove
    call AdjustDamageForMoveType
    call RandomizeDamage
    call MoveHitTest                    ; sets wMoveMissed
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .missed
    mov al, [ebp + wPlayerMoveNum]
    call PlayMoveAnimation              ; TODO-HW: placeholder (HP-bar update below)
    call ApplyAttackToEnemyPokemon      ; enemy HP -= wDamage (floored)
    call DrawHUDsAndHPBars
    mov byte [ebp + wMoveDidntMiss], 1
    call JumpMoveEffect                 ; run the move's effect (TODO: array-gated order)
    mov al, [ebp + wEnemyMonHP]
    mov bh, [ebp + wEnemyMonHP + 1]
    or  al, bh                          ; enemy fainted?
    jz  .targetFainted
    jmp ExecutePlayerMoveDone
.statusMove:
    mov al, [ebp + wPlayerMoveNum]
    call PlayMoveAnimation
    call DrawHUDsAndHPBars
    call JumpMoveEffect                 ; 0-BP move: run its effect (e.g. GROWL)
    jmp ExecutePlayerMoveDone
.missed:
    mov eax, AttackMissedText           ; generated battle text (TODO: PrintMoveFailureText variants)
    call PrintBattleText
    jmp ExecutePlayerMoveDone
.targetFainted:
    xor bh, bh                          ; b = 0 → MainInBattleLoop: enemy fainted
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
; ApplyAttackToEnemyPokemon — subtract wDamage (big-endian) from the enemy mon's HP,
; floored at 0. (pret ApplyAttackToEnemyPokemon core; substitute handling deferred.)
; ---------------------------------------------------------------------------
ApplyAttackToEnemyPokemon:
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
    mov [ebp + wEnemyMonHP + 1], al
    shr eax, 8
    mov [ebp + wEnemyMonHP], al
    ret

; ---------------------------------------------------------------------------
; CheckPlayerStatusConditions — pret core.asm:CheckPlayerStatusConditions (3499).
; TODO(faithful): translate sleep/freeze/paralysis/confusion/flinch/Bide/Thrash/Rage/
; Disable. Stubbed to "no condition" (ZF=0) so the move always executes for now.
; ---------------------------------------------------------------------------
CheckPlayerStatusConditions:
    mov al, 1
    and al, al                          ; ZF=0 → no special condition
    ret

; ---------------------------------------------------------------------------
; CheckForDisobedience — pret core.asm (Yellow obedience for traded mons).
; TODO(faithful): translate. Stubbed to "obeys" (no effect).
; ---------------------------------------------------------------------------
CheckForDisobedience:
    ret

; ---------------------------------------------------------------------------
; ExecuteEnemyMove — pret engine/battle/core.asm:ExecuteEnemyMove (5639), faithful
; mirror of ExecutePlayerMove with the enemy's move fields, applying damage to the
; player mon. Enemy PP is not decremented (player-only PP, per project scope). Same
; TODO(faithful) deepening list as ExecutePlayerMove (status/effects/multi-hit/…).
; Returns b in BH (0 = player mon fainted, else ExecuteEnemyMoveDone sets b=1).
; ---------------------------------------------------------------------------
ExecuteEnemyMove:
    mov byte [ebp + hWhoseTurn], 1
    mov al, [ebp + wEnemySelectedMove]
    inc al                              ; CANNOT_MOVE → 0
    jz  ExecuteEnemyMoveDone
    mov byte [ebp + wMoveMissed], 0
    mov byte [ebp + wMonIsDisobedient], 0
    mov byte [ebp + wMoveDidntMiss], 0
    mov byte [ebp + wDamageMultipliers], EFFECTIVE
    call CheckEnemyStatusConditions     ; ZF=0 → no condition
    jnz .noCondition
    mov bh, 1
    ret
.noCondition:
    call GetCurrentMove                 ; hWhoseTurn=1 → loads wEnemyMove*
    call DisplayUsedMoveText            ; "Enemy X used MOVE!"
    call CriticalHitTest
    call GetDamageVarsForEnemyAttack
    call CalculateDamage
    jz  .statusMove
    call AdjustDamageForMoveType
    call RandomizeDamage
    call MoveHitTest
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .missed
    mov al, [ebp + wEnemyMoveNum]
    call PlayMoveAnimation
    call ApplyAttackToPlayerPokemon     ; player HP -= wDamage (floored)
    call DrawHUDsAndHPBars
    mov byte [ebp + wMoveDidntMiss], 1
    call JumpMoveEffect
    mov al, [ebp + wBattleMonHP]
    mov bh, [ebp + wBattleMonHP + 1]
    or  al, bh
    jz  .targetFainted
    jmp ExecuteEnemyMoveDone
.statusMove:
    mov al, [ebp + wEnemyMoveNum]
    call PlayMoveAnimation
    call DrawHUDsAndHPBars
    call JumpMoveEffect
    jmp ExecuteEnemyMoveDone
.missed:
    mov eax, AttackMissedText
    call PrintBattleText
    jmp ExecuteEnemyMoveDone
.targetFainted:
    xor bh, bh                          ; b = 0 → player mon fainted
    ret

ExecuteEnemyMoveDone:
    mov bh, 1
    ret

; ApplyAttackToPlayerPokemon — subtract wDamage from the player mon's HP, floored.
ApplyAttackToPlayerPokemon:
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

; CheckEnemyStatusConditions — pret core.asm. TODO(faithful): translate (sleep/freeze/
; etc.). Stubbed to "no condition" (ZF=0).
CheckEnemyStatusConditions:
    mov al, 1
    and al, al
    ret

; ---------------------------------------------------------------------------
; HandleEnemyMonFainted — pret core.asm:HandleEnemyMonFainted (708). Faithful CORE:
; announce "Enemy <nick> fainted!" and award EXP (with the level-up display), then
; return to MainInBattleLoop's caller (battle ends — wild victory). Returns to the
; battle's outer caller (reached via `jp` from MainInBattleLoop).
;
; TODO(faithful): SlideDownFaintedMonPic + faint SFX (FaintEnemyPokemon), AnyPartyAlive
; → HandlePlayerBlackOut, RemoveFaintedPlayerMon (double-faint), trainer multi-mon
; (ReplaceFaintedEnemyMon / ChooseNextMon / DoUseNextMonDialogue), prize money,
; TrainerBattleVictory, EnemyRan.
; ---------------------------------------------------------------------------
HandleEnemyMonFainted:
    mov byte [ebp + wInHandlePlayerMonFainted], 0
    mov eax, EnemyMonFaintedText
    call PrintBattleText                ; "Enemy <nick> fainted!" (prompt → ▼ + wait)
    call GainExperience                 ; EXP + level-up display (experience.asm, wired)
    mov byte [ebp + wBattleResult], 0   ; 0 = player won
    ret

; ---------------------------------------------------------------------------
; HandlePlayerMonFainted — pret core.asm:HandlePlayerMonFainted (981). Faithful CORE:
; announce "<nick> fainted!" and end the battle as a loss.
; TODO(faithful): RemoveFaintedPlayerMon, AnyPartyAlive→blackout, the switch-in
; (DoUseNextMonDialogue / ChooseNextMon) for a multi-mon party.
; ---------------------------------------------------------------------------
HandlePlayerMonFainted:
    mov byte [ebp + wInHandlePlayerMonFainted], 1
    mov eax, PlayerMonFaintedText
    call PrintBattleText                ; "<nick> fainted!" (prompt → ▼ + wait)
    mov byte [ebp + wBattleResult], 1   ; 1 = player lost (multi-mon switch deferred)
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
