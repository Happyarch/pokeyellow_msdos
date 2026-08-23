; core.asm — faithful translation of pret engine/battle/core.asm (battle loop).
;
; This replaces the bespoke Wave-2 orchestration (battle_menu.asm) with a
; structure-for-structure translation of pret's battle loop. Per the governing
; principle (docs/current_plan_battle_pret_alignment.md): the BACKEND is byte-
; faithful, and the FRONT END diverges from pret ONLY at the screen-draw primitive
; (the tile write into our centered 40-wide wTileMap). Move animation is a marked
; placeholder (HP-bar drain); audio is a no-op stub.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, SP=ESP,
; EBP = base of emulated GB memory; GB address X = [ebp+X]. hWhoseTurn: 0=player.
;
; Build: nasm -f coff -I include/ -I . -o core.o core.asm
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "assets/script_constants.inc"; shared constants (%define: emits no COFF symbol)
%include "gb_constants.inc"
%include "coords.inc"          ; BCOORD (hoisted here from a local %define, battle_animations 2b)
%include "assets/audio_constants.inc"   ; AUDIO_BANK_2 (PlayBattleVictoryMusic)
%include "msgbox.inc"          ; the message-box projection record

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
; carried in with PlayMoveAnimation (was animations.asm)
%define ANIM_OFF_DELAY 30              ; pret .animationsDisabled: ld c,30 / call DelayFrames
; carried in with CalculateDamage (was core_damage.asm)
EFFECT_1E equ 0x1E                     ; unused move effect, special-cased in CalculateDamage
; carried in with the unit-C faint/send-out cluster
MIRROR_MOVE       equ 0x4D
HP_BAR_RED        equ 2       ; constants/gfx_constants.asm

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
; PROJ battle: the Safari menu replaces the action menu with full-width labels,
; so its two cursor columns sit at different GB x than FIGHT/PKMN's. pret uses
; raw `ld b, $1` / `ld b, $d`; these are the same values projected, from the
; generated layout records (never literals — regression-battle-second-battle-hud-tile-band).
%define SAF_ROW     UI_SAFARI_CUR_L_ROW ; == MENU_ROW: both are pret's row 14
%define SAF_COL_L   UI_SAFARI_CUR_L_COL ; pret ld b, $1  — SAFARI BALL / THROW ROCK
%define SAF_COL_R   UI_SAFARI_CUR_R_COL ; pret ld b, $d  — BAIT / RUN
%define SAF_BALLS   UI_SAFARI_BALLS_COL ; pret hlcoord 7, 14 — the ball counter
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

; Battle HUD frame/divider tiles (Tier-1 data, pret BattleHudTiles1/2/3 expanded
; 1bpp->2bpp by tools/generators/gen_battle_hud_inc.py). %included here rather than
; externed because LoadHudTilePatterns below sizes its copies with
; BATTLE_HUD_TILES*_SIZE — assembly-time arithmetic, which an extern cannot
; provide. src/home/load_font.asm externs both labels for the status screen's
; variant of the load, so they are global.
section .data
align 4
%include "assets/battle_hud_2bpp.inc"
global str_used_grammar               ; DisplayUsedMoveText, now engine/battle/used_move_text.asm
global RunBattleTextStream            ; DisplayUsedMoveText, now engine/battle/used_move_text.asm
global battle_hud_tiles1_2bpp
global battle_hud_tiles23_2bpp

; The party screen's scratch stride (party_menu.asm calls it GBSCR_W). NOT
; SCREEN_WIDTH, which is this port's 40-wide CANVAS stride.
PARTY_SCRATCH_STRIDE equ 20

section .text

global MainInBattleLoop
global DisplayBattleMenu
global MoveSelectionMenu
global SelectMenuItem
global SelectMenuItem_CursorUp
global SelectMenuItem_CursorDown
global SwapMovesInMenu
global PrintMenuItem
global AnyMoveToSelect
global PrintBattleText
global PrintEmptyString                 ; pret core.asm:6720 — retired its battle_exp_stubs.asm stub
extern DisplayUsedMoveText          ; src/engine/battle/used_move_text.asm
extern PrintTextStaged                 ; src/home/window.asm — PrintText, stream already staged
extern AnimationSlideEnemyMonOff       ; engine/battle/animations.asm — EnemyRan's tail
extern PlaySoundWaitForCurrent         ; src/home/delay.asm — In: AL = sound id (also declared at its other use below)
extern EnemyRanText                    ; dos_port/assets/battle_text.inc — EnemyRan, link arm
global ExecutePlayerMove
global ExecutePlayerMoveDone
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
global GetBattleHealthBarColor         ; pret core.asm — used by DrawPlayerHUDAndHPBar, below
global CenterMonName                   ; pret core.asm — used by both HUD draws below

; --- consolidated from other port files (grind session 8) ---
global GetCurrentMove
global LoadEnemyMonData
global ApplyBurnAndParalysisPenaltiesToPlayer
global ApplyBurnAndParalysisPenaltiesToEnemy
global ApplyBurnAndParalysisPenalties
global QuarterSpeedDueToParalysis
global HalveAttackDueToBurn
global ApplyBadgeStatBoosts
global PlayMoveAnimation
global BattleRandom
global GetDamageVarsForPlayerAttack
global GetDamageVarsForEnemyAttack
global GetEnemyMonStat
global CalculateDamage
global JumpToOHKOMoveEffect
global CriticalHitTest
global AdjustDamageForMoveType
global MoveHitTest
global CalcHitChance
global RandomizeDamage
global AIGetTypeEffectiveness
global AnyEnemyPokemonAliveCheck
global ChooseNextMon
global CriticalOHKOTextPointers
global DoUseNextMonDialogue
global EnemyRan
global EnemySendOut
global EnemySendOutFirstMon
global HandlePlayerBlackOut
global HandlePoisonBurnLeechSeed
global HandlePoisonBurnLeechSeed_DecreaseOwnHP
global HandlePoisonBurnLeechSeed_IncreaseEnemyHP
global HasMonFainted
global IncrementMovePP
global IsGhostBattle
global LoadBattleMonFromParty
global MirrorMoveCopyMove
global PrintCriticalOHKOText
global PrintGhostText
global ReloadMoveData
global RemoveFaintedPlayerMon
global ReplaceFaintedEnemyMon
global SendOutMon
global AnimateRetreatingPlayerMon       ; pret core.asm:1828 (plan 2a)
global SwitchPlayerMon                  ; pret core.asm:2525 (plan 2a)
global PartyMenuOrRockOrRun             ; pret core.asm:2404 (plan 2a)
global BagWasSelected                   ; pret core.asm:2292 (plan 2c)
global UseBagItem                       ; pret core.asm:2344 (plan 2c)
global TrainerBattleVictory
global CalculateModifiedStats            ; pret core.asm:6550 (plan 3d)
global CalculateModifiedStat            ; pret core.asm:6560 (plan 3d)
global DoubleOrHalveSelectedStats        ; pret core.asm:6449 (plan 3d)
global ScrollTrainerPicAfterBattle      ; pret core.asm:6453 jpfar thunk

; --- backend (already-faithful translations in other files) ---
extern TrainerAI                       ; trainer_ai.asm (CF if AI used item/switch)

; --- draw primitives (category-D divergence point; battle_menu.asm draw helpers) ---
extern UpdateHPBar2                    ; engine/gfx/hp_bar.asm — pret animated HP-bar engine (ESI = bar coord)
extern SaveScreenTilesToBuffer1        ; src/home/tilemap.asm
extern RetreatMon                      ; engine/battle/common_text.asm — switch-out line
extern SaveScreenTilesToBuffer2        ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer2      ; src/home/tilemap.asm
extern DisplayPartyMenu                ; src/home/pokemon.asm — CF=0 iff a mon was chosen
extern GoBackToPartyMenu               ; src/home/pokemon.asm
extern GBPalWhiteOut                   ; src/home/palettes.asm
extern GBPalNormal                     ; src/home/palettes.asm
extern RunDefaultPaletteCommand        ; src/home/palettes.asm
extern DisplayTextBoxID                ; src/home/textbox.asm
extern yn_box_col                      ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row                      ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode                    ; home/yes_no.asm — 0 = overworld anchor, 1 = battle
extern PlaceUnfilledArrowMenuCursor    ; src/home/window.asm
extern StatusScreen                    ; engine/menus/status_screen.asm — predef
extern StatusScreen2                   ; engine/menus/status_screen.asm — predef
extern AnimationSubstitute             ; engine/battle/animations.asm
extern AnimationMinimizeMon            ; engine/battle/animations.asm
extern LoadMonFrontSprite              ; src/home/pics.asm — EDX = VRAM dest
extern FillMemory                      ; src/home/copy2.asm — ESI dest, BX count, AL value
extern ShowSimulatedInputBagBox        ; battle_menu.asm — tutorial one-item box
extern DisplayListMenuID               ; src/home/list_menu.asm — CF=1 iff cancelled
extern UseItem                         ; src/home/item.asm
extern GetItemName                     ; src/home/names.asm
extern CopyToStringBuffer              ; src/home/copy_string.asm
extern ItemsCantBeUsedHereText         ; assets/battle_text.inc (generated Tier-1)
extern g_window_count                  ; src/ppu/ppu.asm — window descriptor count
extern g_bg_whiteout                   ; src/ppu/ppu.asm — 1 = blank BG, skip the tilemap
extern LinkBattleExchangeData          ; battle_stubs.asm (STUB) — link play is unported
extern UseNextMonText                  ; assets/battle_text.inc (generated Tier-1)
extern LoadScreenTilesFromBuffer1      ; src/home/tilemap.asm — restore clean screen
extern DrawEmptyDialogBox              ; pret PrintEmptyString equiv (blank dialog box)
extern DrawBattleMenuBox               ; DisplayTextBoxID(BATTLE_MENU_TEMPLATE) equiv
extern HandleMenuInput                 ; home/window.asm
extern PlaceMenuCursor                 ; home/window.asm
extern menu_item_step                  ; home/window.asm — cursor vertical spacing
extern menu_redraw_cb                  ; home/window.asm — per-frame cursor redraw hook
extern PartyMenuMirror                 ; engine/menus/party_menu.asm — scratch → window blit
extern DisplaySwitchStatsCancelPartyBox ; engine/menus/text_box.asm — port-only scratch draw
extern EraseMenuCursor                 ; home/window.asm

; --- text engine + move-list helpers ---
extern TextBoxBorder                   ; text.asm (stride-aware)
extern PlaceString                     ; text.asm (src=EAX flat-linear, end in EBX)
extern TextCommandProcessor            ; text.asm (ESI=stream, FLAT ptr; EBX=cursor)
extern text_msgbox                     ; text.asm — the active msgbox projection record
extern text_arrow_pos                  ; text.asm — ▼ tile (read by BattlePromptWait;
                                       ; published by PrintText from the record)
extern FormatMovesString               ; misc.asm — wMoves → wMovesString (+ '-' slots)
extern DelayFrame                      ; src/home/vblank.asm
extern text_row_stride                 ; text.asm — wTileMap row stride

; --- PrintMenuItem's helpers (pret core.asm:3010) ---
extern CopyData                        ; home/copy.asm — ESI→EDX, BX bytes
extern PrintNumber                     ; home/print_num.asm — ESI dest, EDX src, BH flags/bytes, BL digits
extern GetMaxPP                        ; engine/items/get_max_pp.asm — → wMaxPP (PP Ups incl.)
extern PrintMoveType                   ; engine/battle/print_type.asm — pret predef PrintMoveType
extern Delay3                          ; src/home/palettes.asm

; --- deferred in-battle sub-UIs (bag / party-switch) — call faithfully, body deferred ---

; --- move-execution backend (already-faithful, in other files) ---
extern AddNTimes                       ; home/array.asm — ESI += BX * AL (party index)
extern DecrementPP                     ; decrement_pp.asm
extern JumpMoveEffect                  ; effects.asm — MoveEffectPointerTable dispatch
extern CopyToStringBuffer              ; src/home/copy_string.asm — EDX=src → wStringBuffer
extern IsInArray                       ; home/array2.asm — AL in [ESI] ($FF-term, stride EDX) → CF
extern ResidualEffects1                ; battle_data.asm — effect-category arrays
extern SpecialEffectsCont
extern SetDamageEffects
extern ResidualEffects2
extern AlwaysHappenSideEffects
extern SpecialEffects
extern GainExperience                  ; experience.asm — EXP award + level-up display
; --- faint / switch lifecycle (battle-swarm-C) ---

; --- pulled in with the session-8 consolidated bodies ---
extern Moves                           ; src/data/moves/moves.asm — flat move-record table
extern GetMonHeader                    ; home/pokemon.asm — loads wMonHeader from wCurSpecies
extern LoadFrontSpriteByMonIndex       ; home/pokemon.asm — decode front pic + place 7x7 at ESI
extern TrainerSentOutText              ; assets/battle_text.inc (battle_menu.asm carries the blob)
extern CalcStats                       ; home/move_mon.asm — EDX=dest, ESI=EV base, BH=useEVs
extern GetMonName                      ; home/names.asm — wNamedObjectIndex -> wNameBuffer
extern WriteMonMoves                   ; evos_moves.asm — level-up moveset (predef: wPredefDE)
extern LoadMovePPs                     ; add_mon.asm — PPs (predef: wPredefHL/DE)
extern IndexToPokedex                  ; engine/menus/pokedex.asm — predef, wPokedexNum in place
extern FlagAction                      ; flag_action.asm — ESI=array, CL=bit, BH=action
extern ModifyPikachuHappiness          ; engine/events/pikachu_happiness.asm — DH = PIKAHAPPY_*
extern MoveAnimation                   ; animations.asm — pret predef, direct call (Stage 2b)
extern Func_78e98                      ; animations.asm — BG save/clear/restore around the anim

; --- pulled in with the damage pipeline (was core_damage.asm) ---
extern Multiply                        ; home/math.asm
extern Divide                          ; home/math.asm
extern Random                          ; home/random.asm
extern CalcStat                        ; home/move_mon.asm — single stat from base+DV+EV
extern TypeEffects                     ; battle_data.asm — type-matchup table
extern HighCriticalMoves               ; battle_data.asm — high-crit move list
extern StatModifierRatios              ; battle_data.asm — stat-stage numerator/denominator
extern CheckTargetSubstitute           ; substitute.asm

; --- pulled in with the unit-C faint/send-out cluster ---
extern AddBCD                          ; engine/math/bcd.asm
extern ClearScreen                     ; home/copy2.asm
extern ClearScreenArea                 ; src/home/copy2.asm — ESI=wTileMap dest, BH=rows, BL=width
                                       ; (hoisted here 2026-08-11: HandlePlayerBlackOut
                                       ; uses it ~1000 lines before the old declaration)
extern ClearSprites                    ; home/clear_sprites.asm
extern IsItemInBag                     ; src/home/map_objects.asm
extern PrintSendOutMonMessage          ; engine/battle/common_text.asm
extern AnimateSendingOutMon            ; engine/battle/init_battle.asm — send-out pic animation
extern LoadMonBackPic                  ; engine/battle/init_battle.asm — sent-out mon back pic
extern IsThisPartyMonStarterPikachu    ; engine/pikachu/pikachu_status.asm — CF=1 when starter
extern CopyDownscaledMonTiles          ; animations.asm — predef; ESI dest, BH rows, BL cols
extern AnimationSlideMonOff            ; animations.asm — starter-Pikachu retreat walk-off
extern StarterPikachuBattleEntranceAnimation ; battle_stubs.asm (STUB) — pret engine/battle/pikachu_entrance_anim.asm
extern IsPlayerPikachuAsleepInParty    ; engine/pikachu/pikachu_emotions.asm — real party scan
extern PlayPikachuSoundClip            ; src/audio/pikachu_pcm.asm
extern PlayCry                         ; src/home/pokemon.asm — pret home/pokemon.asm:140
extern RunPaletteCommand               ; home/palettes.asm
extern GetHealthBarColor               ; home/palettes.asm — DL = HP pixels, ESI = colour addr
extern SetPal_Battle                   ; engine/gfx/palettes.asm — publish both HP-bar slots
extern PlacePlayerHUDTiles             ; draw_hud_pokeball_gfx.asm (pret mirror)
extern PlaceEnemyHUDTiles              ; draw_hud_pokeball_gfx.asm (pret mirror)
extern UpdateCGBPal_OBP0               ; src/home/cgb_palettes.asm — arms g_pal_dirty
extern UpdateCGBPal_OBP1               ; src/home/cgb_palettes.asm — arms g_pal_dirty
extern PrintStatusConditionNotFainted  ; home/pokemon.asm -> PrintStatusAilment
extern ClearScreenArea                 ; home/copy2.asm — BH rows x BL cols of blanks at ESI
extern PrintLevel                      ; home/pokemon.asm — ':L' + wLoadedMonLevel at ESI
extern DrawHP                          ; engine/pokemon/status_screen.asm — predef DrawHP
extern DrawHPBar                       ; src/home/pokemon.asm — ESI coord, DH tiles, DL pixels, BL sliver
; --- HUD geometry for DrawHUDsAndHPBars and its two halves, moved here with
; --- them from battle_hud.asm. Values come from the generated battle UI layout
; --- (assets/ui_layout_battle.inc); never hand-edit an offset here.
; PROJ battle: enemy HUD = UI_ENEMY_{NAME,LV,HPBAR}_OFS
; PROJ battle: player HUD = UI_PLAYER_{NAME,LV,HPBAR,HPFRAC}_OFS
%define E_NAME    UI_ENEMY_NAME_OFS
%define E_LV      UI_ENEMY_LV_OFS
%define E_HPBAR   UI_ENEMY_HPBAR_OFS
%define P_NAME    UI_PLAYER_NAME_OFS
%define P_LV      UI_PLAYER_LV_OFS
%define P_HPBAR   UI_PLAYER_HPBAR_OFS
%define P_HPFRAC  UI_PLAYER_HPFRAC_OFS
; PROJ battle: the player connectors stack in the element's top-RIGHT column
%define P_FRAME_CONN (UI_PLAYER_HUD_FRAME_OFS + UI_PLAYER_HUD_FRAME_GBW - 1)
%define T_HUD_73  0x73                 ; HUD vertical connector
%define CHAR_SLSH 0xF3                 ; '/' in the HP fraction
extern SkipFixedLengthTextEntries      ; home/array.asm

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
    ; pret: ld a,[wBattleType] / and a / jr nz, .nonstandardbattle — a special
    ; battle (OLD_MAN / PIKACHU / SAFARI, wBattleType != 0) has NO player mon out,
    ; so it draws NEITHER HUD here (the enemy HUD it shows was drawn earlier and is
    ; restored by LoadScreenTilesFromBuffer1 above). Drawing DrawHUDsAndHPBars
    ; unconditionally was painting a phantom player HUD over zeroed data — the
    ; ":L 0 / 0/ 0" box in the Oak/Pikachu intro battle.
    cmp byte [ebp + wBattleType], 0
    jne .nonstandardbattle
    call DrawHUDsAndHPBars
    call DrawEmptyDialogBox             ; pret PrintEmptyString — blank dialog box
    call SaveScreenTilesToBuffer1
.nonstandardbattle:
    ; pret 2086-2092 — the menu box, and WHICH box depends on the battle type:
    ;     ld a, [wBattleType]
    ;     cp BATTLE_TYPE_SAFARI
    ;     ld a, BATTLE_MENU_TEMPLATE
    ;     jr nz, .menuselected
    ;     ld a, SAFARI_BATTLE_MENU_TEMPLATE
    ;   .menuselected
    ;     ld [wTextBoxID], a
    ;     call DisplayTextBoxID
    ; The compare's ZF crosses a flag-neutral `ld` again; the `mov` below is
    ; equally flag-neutral, so the branch still reads the compare.
    ;
    ; THIS REPLACES A PORT-ONLY WRAPPER, and doing so closes a faithdiff finding
    ; rather than adding one. `DrawBattleMenuBox` hardcoded the battle template's
    ; geometry, so DisplayTextBoxID and [wTextBoxID] both read DROPPED on this
    ; routine and there was no way to ask for the Safari box at all. Both
    ; templates resolve to the same generated layout records the wrapper used
    ; (BATTLE_MENU_TEMPLATE -> UI_ACTION_MENU_BOX_* + BattleMenuText at
    ; UI_ACTION_TEXT_*), so the normal-battle drawing is unchanged — verified by
    ; battle_menu / move_selection / battle_oldman / battle_pikachu.
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_SAFARI
    mov al, BATTLE_MENU_TEMPLATE
    jne .menuselected                   ; jr nz
    mov al, SAFARI_BATTLE_MENU_TEMPLATE
.menuselected:
    mov [ebp + wTextBoxID], al
    call DisplayTextBoxID
    ; pret 2093-2101: the old-man tutorial and the Prof. Oak Pikachu battle run
    ; this menu on SIMULATED input — the cursor walks itself to ITEM.
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    je .doSimulatedMenuInput
    cmp al, BATTLE_TYPE_PIKACHU
    je .doSimulatedMenuInput
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
    ; pret 2151-2166. The blank tile is loaded into A BEFORE the branch and used
    ; by both arms, and the compare's ZF crosses that flag-neutral load exactly
    ; as pret writes it (`cp BATTLE_TYPE_SAFARI / ld a, ' ' / jr z`).
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    mov al, T_SPACE                     ; ld a, ' ' — flag-neutral
    je .safariLeftColumn
    ; clear the right-column cursor cells, top item X = the left column
    mov [ebp + wTileMap + MENU_ROW * FW + CUR_COL_R], al
    mov [ebp + wTileMap + (MENU_ROW + 2) * FW + CUR_COL_R], al
    mov bh, CUR_COL_L                   ; ld b, $9
    jmp .leftColumn_WaitForInput
.safariLeftColumn:
    mov [ebp + wTileMap + SAF_ROW * FW + SAF_COL_R], al
    mov [ebp + wTileMap + (SAF_ROW + 2) * FW + SAF_COL_R], al
    ; The Safari menu shows how many balls are left. BH/BL are PrintNumber's
    ; arguments and it clobbers them, which is why pret sets `ld b, $1` AFTER
    ; the call and not before — keep that order.
    mov esi, wTileMap + SAF_ROW * FW + SAF_BALLS
    mov edx, wNumSafariBalls
    mov bh, 1                           ; lb bc, 1, 2 — 1 source byte
    mov bl, 2                           ;               2 digits
    call PrintNumber
    mov bh, SAF_COL_L                   ; ld b, $1
.leftColumn_WaitForInput:
    mov byte [ebp + wTopMenuItemY], MENU_ROW
    mov [ebp + wTopMenuItemX], bh
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_RIGHT | PAD_A
    call HandleMenuInput
    test al, PAD_RIGHT
    jnz .rightColumn
    jmp .AButtonPressed
.rightColumn:
    ; pret 2184-2199, the mirror of the above.
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    mov al, T_SPACE                     ; ld a, ' ' — flag-neutral
    je .safariRightColumn
    ; clear the left-column cursor cells, top item X = the right column
    mov [ebp + wTileMap + MENU_ROW * FW + CUR_COL_L], al
    mov [ebp + wTileMap + (MENU_ROW + 2) * FW + CUR_COL_L], al
    mov bh, CUR_COL_R                   ; ld b, $f
    jmp .rightColumn_WaitForInput
.safariRightColumn:
    mov [ebp + wTileMap + SAF_ROW * FW + SAF_COL_L], al
    mov [ebp + wTileMap + (SAF_ROW + 2) * FW + SAF_COL_L], al
    mov esi, wTileMap + SAF_ROW * FW + SAF_BALLS
    mov edx, wNumSafariBalls
    mov bh, 1
    mov bl, 2
    call PrintNumber
    mov bh, SAF_COL_R                   ; ld b, $d
.rightColumn_WaitForInput:
    mov byte [ebp + wTopMenuItemY], MENU_ROW
    mov [ebp + wTopMenuItemX], bh
    mov byte [ebp + wMaxMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], PAD_LEFT | PAD_A
    call HandleMenuInput
    test al, PAD_LEFT
    jnz .leftColumn
    mov al, [ebp + wCurrentMenuItem]    ; A in right column → id += 2
    add al, 2
    mov [ebp + wCurrentMenuItem], al
.AButtonPressed:
    ; pret 2225-2227: the unused BATTLE_TYPE_RUN arm is tested FIRST, before the
    ; Safari one. It is the "Hurry, get away!" forced-run battle -- unused in the
    ; shipped game, but it is a real branch of this routine and its absence was
    ; the DROPPED BattleMenu_RunWasSelected faithdiff has reported here.
    cmp byte [ebp + wBattleType], BATTLE_TYPE_RUN
    je .handleUnusedBattle
    ; pret 2224-2231. THE SAFARI TEST COMES FIRST AND ITS FLAGS CROSS TWO LOADS,
    ; exactly as pret writes it:
    ;     cp BATTLE_TYPE_SAFARI
    ;     ld a, [wCurrentMenuItem]
    ;     ld [wBattleAndStartSavedMenuItem], a
    ;     jr z, .handleMenuSelection
    ; The two `ld`s are flag-neutral on SM83 and the two `mov`s are flag-neutral
    ; in x86, so the branch still reads the COMPARE's ZF. Putting the compare
    ; after the loads, or using anything flag-writing between, silently makes
    ; the Safari menu take the ID swap below.
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBattleAndStartSavedMenuItem], al
    ; A Safari battle SKIPS the swap: its four items (SAFARI BALL / BAIT / ROCK
    ; / RUN) are already in menu order, so ids 0-3 mean what they say.
    je .handleMenuSelection
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
    ; pret 2249-2251: in a Safari battle the upper-left item is not FIGHT, it is
    ; SAFARI BALL — the only way to throw one, since the Safari bag has no ball.
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    je .throwSafariBallWasSelected
    ; --- FIGHT selected ---
    mov byte [ebp + wNumRunAttempts], 0
    call LoadScreenTilesFromBuffer1     ; restore clean screen and return (CF=0)
    clc
    ret
.handleUnusedBattle:
    ; pret 2256-2261. Only menu item 3 (RUN) does anything; everything else just
    ; prints "Hurry, get away!" and redraws the menu.
    cmp byte [ebp + wCurrentMenuItem], 3
    je BattleMenu_RunWasSelected        ; jp z
    mov esi, RunAwayText                ; ld hl, .RunAwayText
    call PrintText
    jmp DisplayBattleMenu               ; jp
.throwSafariBallWasSelected:
    ; pret 2256-2259. Note it is `jp UseBagItem`, NOT a call: UseBagItem owns the
    ; rest of the turn from here (it is the same tail the BAIT branch below uses).
    mov byte [ebp + wCurItem], SAFARI_BALL
    jmp UseBagItem
.upperLeftMenuItemWasNotSelected:
    cmp al, 2
    jne .partyMenuOrRun
    ; --- ITEM (bag), or BAIT in the Safari Zone ---
    ; pret falls straight through here into the link check and then
    ; BagWasSelected, and the flow's own `ret` (in UseBagItem) IS
    ; DisplayBattleMenu's return: CF=1 when a capture ended the battle, CF=0
    ; otherwise. The port used to `call BattleItemMenu` and re-dispatch on CF —
    ; a port-only shape that existed only because the bag was a stub. Restored
    ; to pret's fall-through by battle plan 2c.
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jne .notLinkBattle                  ; jr nz
    ; can't use items in link battles
    mov esi, ItemsCantBeUsedHereText
    call PrintText
    jmp DisplayBattleMenu               ; jp
.notLinkBattle:
    call SaveScreenTilesToBuffer2
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    jne BagWasSelected                  ; jr nz
    ; bait was selected
    mov byte [ebp + wCurItem], SAFARI_BAIT
    jmp UseBagItem                      ; jr
.partyMenuOrRun:
    ; pret: jp PartyMenuOrRockOrRun — the dec-a run check is the HEAD of that
    ; routine, not of this one. It used to be inlined here with a call to the
    ; port-only ret-stub BattlePartyMenu; battle plan 2a replaced both with
    ; pret's own routine, so this is a plain tail jump again.
    jmp PartyMenuOrRockOrRun

.doSimulatedMenuInput:
    ; pret 2107-2137: park the real player name in wLinkEnemyTrainerName (the
    ; wGrassRate union — ItemUseBall's .oldManBattle later writes the name over
    ; wGrassRate, the Missingno.-glitch write half), rename the player to the
    ; tutorial identity so battle text reads "PROF.OAK used POKé BALL!", then
    ; DRAW the cursor walking FIGHT -> ITEM (pret simulates the keystrokes
    ; visually — no joypad machinery) and take the ITEM branch directly.
    lea esi, [ebp + wPlayerName]
    lea edi, [ebp + wLinkEnemyTrainerName]
    mov ecx, NAME_LENGTH
    rep movsb                           ; pret: CopyData wPlayerName -> wLinkEnemyTrainerName
    mov esi, str_oldman_name            ; pret: ld hl, .oldManName
    cmp byte [ebp + wBattleType], BATTLE_TYPE_OLD_MAN   ; pret: dec a / jr z
    je .useOldManName
    mov esi, str_profoak_name           ; pret: ld hl, .profOakName
.useOldManName:
    lea edi, [ebp + wPlayerName]
    mov ecx, NAME_LENGTH
    rep movsb                           ; pret: CopyData -> wPlayerName
    ; the simulated keystrokes (pret hlcoord 9,14 / 9,16 = the left-column
    ; cursor cells this menu's .leftColumn manages: FIGHT above, ITEM below)
    mov byte [ebp + wTileMap + MENU_ROW * FW + CUR_COL_L], 0xED          ; '▶' on FIGHT
    mov bl, 20
    call DelayFrames
    mov byte [ebp + wTileMap + MENU_ROW * FW + CUR_COL_L], T_SPACE
    mov byte [ebp + wTileMap + (MENU_ROW + 2) * FW + CUR_COL_L], 0xED    ; '▶' on ITEM
    mov bl, 20
    call DelayFrames
    mov byte [ebp + wTileMap + (MENU_ROW + 2) * FW + CUR_COL_L], 0xEC    ; '▷' (pret leaves the hollow cursor)
    mov al, 2                           ; pret: ld a, $2 — select the ITEM entry
    jmp .upperLeftMenuItemWasNotSelected

; ===========================================================================
; The FIGHT sub-menu: MoveSelectionMenu / SelectMenuItem / SwapMovesInMenu /
; PrintMenuItem — pret core.asm:2567-3084, translated structure-for-structure
; (menu-fidelity row 22).
;
; Until row 22 the port had ONE routine here: a bespoke MoveSelectionMenu that
; folded a 0-based cursor loop into the draw, and three of pret's four labels did
; not exist at all (SelectMenuItem / SwapMovesInMenu / PrintMenuItem read `missing`
; in translation.db). That shape could not express the Mimic and move-relearn menus
; (wMoveMenuType 1/2 — the two callers that made this a blocker), the SELECT
; move-swap, or the disabled-move ▷ marker. It is replaced wholesale below.
;
; CURSOR INDEX BASE — the load-bearing detail. pret's menu item numbering here is
; ONE-based: wCurrentMenuItem is (move index + 1) and wMaxMenuItem is
; wNumMovesMinusOne + 2, i.e. item 0 and item max are deliberately OUT-OF-RANGE
; sentinel slots. That is how the wrap works: UP/DOWN are watched keys, so
; HandleMenuInput RETURNS on them, and SelectMenuItem_CursorUp/_CursorDown catch
; the moment the cursor lands on a sentinel and wrap it to the other end.
; SelectMenuItem then re-runs, which is also what redraws the TYPE/PP box each
; time the cursor moves — pret needs no redraw callback, and the port's
; menu_redraw_cb hook (its stand-in) is gone with the old loop.
;
; COORDS: pret hlcoords are projected onto the port's 40x25 battle canvas by the
; battle projection (X+10, Y+3) — the same transform the generated UI_* layout
; records use (assets/ui_layout_battle.inc; e.g. UI_MOVE_BOX = GB(4,12) -> ofs 614
; = BCOORD(4,12)). Only the coordinate VALUES move; every write is pret's.
; BCOORD itself is now defined once in include/coords.inc (hoisted, 2b).
; ===========================================================================
%define T_UPARROW_R   0xEC              ; '▷' unfilled cursor (charmap.asm)
%define T_SLASH       0xF3              ; '/'

; ---------------------------------------------------------------------------
; MoveSelectionMenu — pret core.asm:2567. Draws one of the three move menus
; (regular battle / Mimic / relearn, per wMoveMenuType), then falls through into
; SelectMenuItem. Out: ZF=1 if a move was selected, ZF=0 if the player backed out.
; ---------------------------------------------------------------------------
MoveSelectionMenu:
    mov al, [ebp + wMoveMenuType]
    dec al
    jz  .mimicmenu
    dec al
    jz  .relearnmenu
    jmp .regularmenu

; .loadmoves — In: ESI = move list (GB offset). Stages it into wMoves and formats.
.loadmoves:
    mov edx, wMoves                     ; ld de, wMoves
    mov bx, NUM_MOVES                   ; ld bc, NUM_MOVES
    call CopyData
    call FormatMovesString              ; callfar FormatMovesString
    ret

; .writemoves — In: ESI = dest tile offset. Prints wMovesString single-spaced.
.writemoves:
    or  byte [ebp + hUILayoutFlags], 1 << BIT_SINGLE_SPACED_LINES
    lea eax, [ebp + wMovesString]       ; ld de, wMovesString (PlaceString takes a flat src)
    call PlaceString
    and byte [ebp + hUILayoutFlags], (~(1 << BIT_SINGLE_SPACED_LINES)) & 0xFF
    ret

.regularmenu:
    call AnyMoveToSelect                ; ZF=1 → every move is out of PP: Struggle
    jnz .haveMoves
    ret                                 ; pret `ret z` — returns with ZF=1 (chosen)
.haveMoves:
    mov esi, wBattleMonMoves
    call .loadmoves
    ; DEVIATION{class=HAL; pret=engine/battle/core.asm:MoveSelectionMenu; behavior=DI and EI around the move-list box are omitted because the port composites an atomic software back buffer; evidence=pret source MoveSelectionMenu plus src/ppu software compositor; lifetime=permanent DOS video HAL}
    ; pret brackets the box draw in di/ei ("out of pure
    ; coincidence, it is possible for vblank to occur between the di and ei") to
    ; stop the LCD from latching a half-written tilemap. The port draws into a
    ; back buffer that render_bg only reads once per composited frame, so there is
    ; no tearing window to close and no interrupt to mask.
    mov esi, BCOORD(4, 12)
    mov bh, 4                           ; lb bc, 4, 14 — b = interior height
    mov bl, 14                          ;               c = interior width
    call TextBoxBorder
    mov byte [ebp + BCOORD(4, 12)], T_H  ; '─' — join the box to the FIGHT menu above
    mov byte [ebp + BCOORD(10, 12)], T_BR ; '┘'
    mov esi, BCOORD(6, 13)
    call .writemoves
    mov bh, 5                           ; ld b, $5  (cursor X)
    mov al, 0xC                         ; ld a, $c  (cursor Y)
    jmp .menuset

.mimicmenu:
    mov esi, wEnemyMonMoves
    call .loadmoves
    mov esi, BCOORD(0, 7)
    mov bh, 4
    mov bl, 14
    call TextBoxBorder
    mov esi, BCOORD(2, 8)
    call .writemoves
    mov bh, 1                           ; ld b, $1
    mov al, 7                           ; ld a, $7
    jmp .menuset

.relearnmenu:
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1Moves
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; ESI += wWhichPokemon * struct length
    call .loadmoves
    mov esi, BCOORD(4, 7)
    mov bh, 4
    mov bl, 14
    call TextBoxBorder
    mov esi, BCOORD(6, 8)
    call .writemoves
    mov bh, 5                           ; ld b, $5
    mov al, 7                           ; ld a, $7

.menuset:
; pret walks hl from wTopMenuItemY through the menu-state block with ld [hli],a;
; the port stores each byte by name (same bytes, same order).
; In: AL = pret cursor Y, BH = pret cursor X — both projected onto the canvas here.
    add al, 3                           ; canvas row = GB row + 3
    mov [ebp + wTopMenuItemY], al
    add bh, 10                          ; canvas col = GB col + 10
    mov [ebp + wTopMenuItemX], bh
    mov al, [ebp + wMoveMenuType]
    cmp al, 1
    je  .selectedmoveknown              ; Mimic: AL is already 1 = first item
    mov al, [ebp + wPlayerMoveListIndex]
    inc al                              ; 0-based move index → 1-based menu item
.selectedmoveknown:
    mov [ebp + wCurrentMenuItem], al
                                        ; (pret: inc hl — wTileBehindCursor untouched)
    mov al, [ebp + wNumMovesMinusOne]
    inc al
    inc al                              ; max item = move count + 1 (the wrap sentinel)
    mov [ebp + wMaxMenuItem], al
    mov al, [ebp + wMoveMenuType]
    dec al
    mov bh, PAD_UP | PAD_DOWN | PAD_A
    jz  .matchedkeyspicked              ; Mimic: no B (the move must be picked)
    dec al
    mov bh, PAD_UP | PAD_DOWN | PAD_A | PAD_B
    jz  .matchedkeyspicked              ; relearn
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je  .matchedkeyspicked              ; link battle: bh unchanged (UP/DOWN/A/B)
    ; Disable left, right, and START buttons in regular battles.
    mov al, [ebp + wStatusFlags7]
    test al, 1 << BIT_TEST_BATTLE
    mov bh, (~(PAD_LEFT | PAD_RIGHT | PAD_START)) & 0xFF
    jz  .matchedkeyspicked
    mov bh, PAD_CTRL_PAD | PAD_BUTTONS  ; TestBattle: every key (debug move stepping)
.matchedkeyspicked:
    mov [ebp + wMenuWatchedKeys], bh
    mov al, [ebp + wMoveMenuType]
    cmp al, 1
    je  .movelistindex1
    mov al, [ebp + wPlayerMoveListIndex]
    inc al
.movelistindex1:
    mov [ebp + wLastMenuItem], al       ; pret: ld [hl],a — the byte after wMenuWatchedKeys
    ; fallthrough

; ---------------------------------------------------------------------------
; SelectMenuItem — pret core.asm:2682. Draws the TYPE/PP box (and the swap
; marker), runs the cursor, and dispatches the key that ended it. Re-entered
; from _CursorUp/_CursorDown on every cursor move, which is what refreshes the box.
; ---------------------------------------------------------------------------
SelectMenuItem:
    mov al, [ebp + wMoveMenuType]
    and al, al
    jz  .battleselect
    dec al
    jnz .select                         ; relearn menu: no prompt, no info box
    mov esi, BCOORD(1, 14)              ; Mimic: "WHICH TECHNIQUE?"
    mov eax, WhichTechniqueString
    call PlaceString
    jmp .select
.battleselect:
    ; Hide move swap cursor in TestBattle. This causes PrintMenuItem to not run in
    ; TestBattle. MoveSelectionMenu still draws part of its window, an issue which
    ; did not seem to exist in the Japanese versions. (pret's comment, preserved.)
    mov al, [ebp + wStatusFlags7]
    test al, 1 << BIT_TEST_BATTLE
    jnz .select
    call PrintMenuItem
    mov al, [ebp + wMenuItemToSwap]
    and al, al
    jz  .select
    mov esi, BCOORD(5, 13)              ; mark the move already picked for swapping
    dec al
    mov bx, FW                          ; ld bc, SCREEN_WIDTH — one canvas row
    call AddNTimes
    mov byte [ebp + esi], T_UPARROW_R   ; '▷'
.select:
    ; DEVIATION{class=data-model; pret=engine/battle/core.asm:MoveSelectionMenu; behavior=pret's inverted double-spacing flag is represented by explicit menu_item_step scratch; evidence=pret MoveSelectionMenu and PlaceMenuCursor plus port window.asm; lifetime=permanent DOS menu data model}
    ; pret sets BIT_DOUBLE_SPACED_MENU in hUILayoutFlags
    ; around HandleMenuInput, which — see PlaceMenuCursor, where the bit SET means
    ; bc = SCREEN_WIDTH and CLEAR means bc = 40 = two GB rows — selects a ONE-row
    ; cursor step (the flag's name is backwards). The port's window.asm carries that
    ; as the explicit menu_item_step scratch, so the set/res pair becomes
    ; one-row-step / back-to-two-row-step.
    mov dword [menu_item_step], FW
    call HandleMenuInput
    mov dword [menu_item_step], 2 * FW
    test al, PAD_UP
    jnz SelectMenuItem_CursorUp
    test al, PAD_DOWN
    jnz SelectMenuItem_CursorDown
    test al, PAD_SELECT
    jnz SwapMovesInMenu
    ; (pret's _DEBUG block — START/RIGHT/LEFT into Func_3d4f5/Func_3d529/Func_3d523,
    ; the TestBattle move stepper — is compiled out in the retail build, so the port
    ; does not carry it; those three labels are pret _DEBUG-only. See ledger M-118.)
    test al, PAD_B                      ; bit B_PAD_B, a
    pushfd                              ; push af — the B verdict decides the return
    mov byte [ebp + wMenuItemToSwap], 0
    mov al, [ebp + wCurrentMenuItem]
    dec al                              ; 1-based menu item → 0-based move index
    mov [ebp + wCurrentMenuItem], al
    mov bh, al                          ; ld b, a
    mov al, [ebp + wMoveMenuType]
    dec al                              ; if not mimic
    jnz .notB
    popfd
    ret                                 ; Mimic: caller reads the index, not the flag
.notB:
    dec al                              ; ZF=1 → relearn menu
    mov al, bh                          ; (flag-neutral, as pret's `ld a,b`)
    mov [ebp + wPlayerMoveListIndex], al
    jnz .moveselected
    popfd
    ret                                 ; relearn: same, index only
.moveselected:
    popfd
    jnz .backedOut                      ; pret `ret nz` — B was pressed
    movzx ebx, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + ebx + wBattleMonPP]  ; ld hl,wBattleMonPP / add hl,bc / ld a,[hl]
    and al, PP_MASK
    jz  .noPP
    mov al, [ebp + wPlayerDisabledMove]
    shr al, 4                           ; swap a / and $f — the disabled slot, 1-based
    dec al
    cmp al, bl                          ; cp c
    je  .disabled
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz .transformedMoveSelected
.transformedMoveSelected:               ; pointless (pret's own comment: both paths
                                        ; land here) — Transform-copied moves are usable
    movzx ebx, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + ebx + wBattleMonMoves]
    mov [ebp + wPlayerSelectedMove], al
    xor al, al
    ret                                 ; ZF=1 → a move was selected
.backedOut:
    ret                                 ; ZF=0 → the player pressed B
.disabled:
    mov eax, MoveDisabledText
    jmp .print
.noPP:
    mov eax, MoveNoPPText
.print:
    call PrintBattleText                ; pret: call PrintText
    call LoadScreenTilesFromBuffer1
    jmp MoveSelectionMenu

; ---------------------------------------------------------------------------
; SelectMenuItem_CursorUp / _CursorDown — pret core.asm:2800 / 2810. The cursor
; landed on one of the two out-of-range sentinel items: wrap it to the other end.
; ---------------------------------------------------------------------------
SelectMenuItem_CursorUp:
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jnz SelectMenuItem                  ; not on the top sentinel → just redraw
    call EraseMenuCursor
    mov al, [ebp + wNumMovesMinusOne]
    inc al                              ; wrap to the last move
    mov [ebp + wCurrentMenuItem], al
    jmp SelectMenuItem

SelectMenuItem_CursorDown:
    mov al, [ebp + wCurrentMenuItem]
    mov bh, al                          ; ld b, a
    mov al, [ebp + wNumMovesMinusOne]
    inc al
    inc al
    cmp al, bh                          ; cp b
    jne SelectMenuItem                  ; not on the bottom sentinel → just redraw
    call EraseMenuCursor
    mov byte [ebp + wCurrentMenuItem], 1 ; wrap to the first move
    jmp SelectMenuItem

; ---------------------------------------------------------------------------
; SwapMovesInMenu — pret core.asm:2926. SELECT picks a move, SELECT again swaps
; the two — in wBattleMonMoves/PP, in the party struct, and in the disabled-move
; index. Re-enters MoveSelectionMenu either way.
; ---------------------------------------------------------------------------
SwapMovesInMenu:
    ; (pret's _DEBUG head — TestBattle jumps to Func_3d4f5 here — is retail-absent.)
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz MoveSelectionMenu               ; a Transformed mon's moves are not really its own
    mov al, [ebp + wMenuItemToSwap]
    and al, al
    jz  .noMenuItemSelected
    mov esi, wBattleMonMoves
    call .swapBytes                     ; swap moves
    mov esi, wBattleMonPP
    call .swapBytes                     ; swap move PP
; update the index of the disabled move if necessary
    mov esi, wPlayerDisabledMove        ; ld hl, wPlayerDisabledMove
    mov al, [ebp + esi]
    shr al, 4                           ; swap a / and $f — disabled slot (1-based)
    mov bh, al
    mov al, [ebp + wCurrentMenuItem]
    cmp al, bh
    jne .next
    mov al, [ebp + esi]
    and al, 0x0F                        ; keep the turn counter (low nybble)
    mov bh, al
    mov al, [ebp + wMenuItemToSwap]
    shl al, 4                           ; swap a — the swapped-to slot becomes disabled
    add al, bh
    mov [ebp + esi], al
    jmp .swapMovesInPartyMon
.next:
    mov al, [ebp + wMenuItemToSwap]
    cmp al, bh
    jne .swapMovesInPartyMon
    mov al, [ebp + esi]
    and al, 0x0F
    mov bh, al
    mov al, [ebp + wCurrentMenuItem]
    shl al, 4
    add al, bh
    mov [ebp + esi], al
.swapMovesInPartyMon:
    mov esi, wPartyMon1Moves
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    push esi
    call .swapBytes                     ; swap moves
    pop esi
    add esi, MON_PP - MON_MOVES
    call .swapBytes                     ; swap move PP
    mov byte [ebp + wMenuItemToSwap], 0 ; deselect the item
    jmp MoveSelectionMenu

; .swapBytes — In: ESI = list base. Swaps the [wMenuItemToSwap-1] and
; [wCurrentMenuItem-1] entries. (Both indices are 1-based here: SelectMenuItem's
; dec has not run yet on this path.)
.swapBytes:
    push esi
    mov al, [ebp + wMenuItemToSwap]
    dec al
    movzx edx, al
    add edx, esi                        ; ld d,h / ld e,l — the first entry
    pop esi
    mov al, [ebp + wCurrentMenuItem]
    dec al
    movzx ecx, al
    add esi, ecx                        ; the second entry
    mov al, [ebp + edx]
    mov bh, [ebp + esi]
    mov [ebp + esi], al
    mov al, bh
    mov [ebp + edx], al
    ret

.noMenuItemSelected:
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wMenuItemToSwap], al     ; select the current menu item for swapping
    jmp MoveSelectionMenu

; ---------------------------------------------------------------------------
; PrintMenuItem — pret core.asm:3010. The TYPE / PP box for the move the cursor
; is on: box at GB(0,8), "TYPE/" + the move's type, and curPP/maxPP. Prints
; "Disabled!" instead if this is the disabled move.
;
; This replaces the port-invented PrintMoveInfoBox (battle_menu.asm), which hand-
; rolled the type lookup, the PP digits and the box, and skipped GetMaxPP entirely
; — so a move with a PP Up applied showed its BASE max PP. Here the max PP comes
; from GetMaxPP, exactly as pret.
; ---------------------------------------------------------------------------
PrintMenuItem:
    ; DEVIATION{class=HAL; pret=engine/battle/core.asm:PrintMenuItem; behavior=auto-BG-transfer gating and Delay3 are omitted because no partial tilemap transfer or presentation occurs inside the routine; evidence=pret source PrintMenuItem plus src/ppu software compositor; lifetime=permanent DOS video HAL}
    ; pret disables hAutoBGTransferEnabled around the draw (and
    ; ends in Delay3) so the partially-drawn box is never DMA'd to VRAM mid-frame.
    ; The port composites a whole back buffer per frame — there is no incremental
    ; BG transfer to gate, and no frame is presented mid-routine.
    mov esi, BCOORD(0, 8)
    mov bh, 3                           ; lb bc, 3, 9
    mov bl, 9
    call TextBoxBorder
    mov al, [ebp + wPlayerDisabledMove]
    and al, al
    jz  .notDisabled
    shr al, 4                           ; swap a / and $f — the disabled slot (1-based)
    mov bh, al
    mov al, [ebp + wCurrentMenuItem]
    cmp al, bh
    jne .notDisabled
    mov esi, BCOORD(1, 10)
    mov eax, DisabledText
    call PlaceString
    jmp .moveDisabled
.notDisabled:
    dec byte [ebp + wCurrentMenuItem]   ; ld hl,wCurrentMenuItem / dec [hl] — 0-based
    mov byte [ebp + hWhoseTurn], 0
    movzx ebx, byte [ebp + wCurrentMenuItem]
    mov al, [ebp + ebx + wBattleMonMoves]
    ; update wPlayerSelectedMove even if the move isn't actually selected (just
    ; pointed to by the cursor) — GetCurrentMove below reads it.
    mov [ebp + wPlayerSelectedMove], al
    mov al, [ebp + wPlayerMonNumber]
    mov [ebp + wWhichPokemon], al
    mov byte [ebp + wMonDataLocation], BATTLE_MON_DATA
    call GetMaxPP                       ; callfar GetMaxPP → wMaxPP (PP Ups included)
    movzx ebx, byte [ebp + wCurrentMenuItem]
    inc byte [ebp + wCurrentMenuItem]   ; ld c,[hl] / inc [hl] — back to 1-based
    mov al, [ebp + ebx + wBattleMonPP]
    and al, PP_MASK
    mov [ebp + wBattleMenuCurrentPP], al
; print TYPE/<type> and <curPP>/<maxPP>
    mov esi, BCOORD(1, 9)
    mov eax, TypeText
    call PlaceString
    mov byte [ebp + BCOORD(7, 11)], T_SLASH
    mov byte [ebp + BCOORD(5, 9)], T_SLASH
    mov esi, BCOORD(5, 11)
    mov edx, wBattleMenuCurrentPP
    mov bh, 1                           ; lb bc, 1, 2 — 1 source byte, 2 digits
    mov bl, 2
    call PrintNumber
    mov esi, BCOORD(8, 11)
    mov edx, wMaxPP
    mov bh, 1
    mov bl, 2
    call PrintNumber
    call GetCurrentMove
    mov esi, BCOORD(2, 10)
    call PrintMoveType                  ; predef PrintMoveType (port: direct call)
.moveDisabled:
    jmp Delay3                          ; pret: ld a,1 / ldh [hAutoBGTransferEnabled] / jp Delay3

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
; battle_text.inc command stream. Selects the battle box geometry (so <LINE>/<PROMPT>
; land in the battle dialog box, ▼ in wTileMap) and runs the one printer, which
; draws the box and walks the stream in place, revealing it char-by-char and
; self-terminating on prompt/done/text_end.
; ---------------------------------------------------------------------------
PrintBattleText:
    mov esi, eax                        ; flat source stream
    mov dword [text_msgbox], msgbox_centered
    jmp PrintText                       ; the one printer, drawing per the record.
                                        ; Tail — its ret returns to us.

; ---------------------------------------------------------------------------
; PrintEmptyString — pret core.asm:6720:
;       PrintEmptyString: ld hl, .emptyString / jp PrintText
;       .emptyString      db "@"
; A zero-length stream printed for its SIDE EFFECT: PrintText draws the message
; box, so this blanks/redraws the battle dialog area. It is not cosmetic filler —
; five live callers depend on the box being (re)drawn: SendOutMon,
; EnemySendOutFirstMon, FaintEnemyPokemon, DoUseNextMonDialogue and the
; ModifyPikachuHappiness path.
;
; RETIRED the ret-only stub in battle_exp_stubs.asm (battle_completion 3d).
;
; pret writes `jp PrintText`; the port goes through PrintBattleText, which is
; PrintText plus the one thing pret does not need — selecting the battle msgbox
; projection. pret's box id is fixed at MESSAGE_BOX inside DisplayTextBoxID,
; whereas the port's PrintText republishes geometry from [text_msgbox] on every
; call, so a bare PrintText here would draw wherever the LAST printer left the
; record. SendOutMon's call can be the first text of a battle, so that record is
; not reliably the battle box yet. Same wrapper the rest of this file uses.
; ---------------------------------------------------------------------------
PrintEmptyString:
    mov eax, EmptyBattleString           ; ld hl, .emptyString
    jmp PrintBattleText                  ; jp PrintText (see the note above)

section .data
; pret's `.emptyString db "@"` — a lone $50 text terminator, i.e. a control byte,
; not a rendered glyph run, so it is code-side rather than generated Tier-1 data.
EmptyBattleString: db 0x50
section .text

; RunBattleTextStream — print a stream COMPOSED IN WRAM (NPC_DIALOG_BUF) in the
; battle dialog box. DisplayUsedMoveText and ComposeStatIntro build their streams
; byte-by-byte at run time (splicing a nickname / a TX_RAM operand), so their stream
; genuinely lives in GB space — this is what PrintTextStaged exists for. It is NOT
; the retired staging workaround; do not "convert" these to PrintText.
RunBattleTextStream:
    mov dword [text_msgbox], msgbox_centered
    jmp PrintTextStaged                 ; tail

; BattlePromptWait — the battle <PROMPT> hook (pret PromptText, wTileMap variant):
; blink the ▼ at [text_arrow_pos], wait for A/B, erase. Installed in text_prompt_hook
; by PrintBattleText. Clobbers EAX/ECX.
BattlePromptWait:
    push esi
    mov esi, [text_arrow_pos]
    mov byte [ebp + esi], T_DOWNARROW
    mov ecx, ARROW_BLINK
.wait:
    call DelayFrame
    test byte [ebp + hJoyPressed], PAD_A | PAD_B
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
align 4
; ---------------------------------------------------------------------------
; msgbox_centered — the CENTER-PROJECTED message box (msgbox.inc).
;
; The same pret message box as msgbox_dialog (text.asm); the only difference is
; the projection. Battle center-projects it onto the stride-40 canvas (the
; UI_DIALOG_* constants below are generated by the ui_layout_battle pipeline) and
; draws it straight in — MB_WIN_TILEMAP = 0, no window — so it never collapses the
; caller's window list. The full-screen menus (save / naming / learn_move /
; evolution / in-battle item use) select this record for exactly that reason: they
; are stride-20 screens that own a window list, not battle screens.
;
; If the battle UI is ever re-projected (e.g. made stride-40-native), it is THIS
; RECORD that changes. There must never be a second PrintText.
; ---------------------------------------------------------------------------
global msgbox_centered
msgbox_centered:
    dd FW                       ; MB_STRIDE       — the full canvas
    dd wTileMap + OUTER_OFF    ; MB_BOX_OFS      — UI_DIALOG_BOX_OFS
    dd OUTER_W                  ; MB_BOX_W
    dd OUTER_H                  ; MB_BOX_H
    dd wTileMap + BTXT_LINE1   ; MB_LINE1        — UI_DIALOG_LINE1_OFS
    dd wTileMap + BTXT_LINE2   ; MB_LINE2        — UI_DIALOG_LINE2_OFS
    dd wTileMap + BTXT_ARROW   ; MB_ARROW        — UI_DIALOG_ARROW_OFS
    dd BattlePromptWait         ; MB_PROMPT       — blinks the ▼, waits A/B
    dd 0                        ; MB_WIN_WX       ] no window: drawn directly into
    dd 0                        ; MB_WIN_WY       ] the canvas, so the caller's
    dd 0                        ; MB_WIN_CLIP     ] window list survives
    dd 0                        ; MB_WIN_MAXY     ]
    dd 0                        ; MB_WIN_TILEMAP  ] 0 = none
    dd 0                        ; MB_WIN_STARTROW ]

; " used " — code-composed move-use grammar (pret used_move_text.asm is text_asm,
; i.e. code, so composing the fixed grammar in code is faithful). Charmap bytes.
%include "assets/battle_core_runtime_strings.inc"
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
extern DisplayEffectiveness            ; display_effectiveness.asm (real)
extern HideSubstituteShowMonAnim       ; src/engine/battle/animations.asm
extern ReshowSubstituteAnim            ; src/engine/battle/animations.asm
extern DelayFrames                     ; src/home/delay.asm
extern str_oldman_name                 ; battle_menu.asm (assets/battle_menu_runtime_strings.inc)
extern str_profoak_name                ; battle_menu.asm (assets/battle_menu_runtime_strings.inc)
extern MultiHitText                    ; battle_text.inc
extern _ScrollTrainerPicAfterBattle    ; scroll_draw_trainer_pic.asm — pret jpfar target
extern StatModifierRatios               ; src/data/battle/stat_modifiers.asm (flat Tier-1 table)
extern DoubleSelectedStats              ; engine/battle/unused_stats_functions.asm
extern HalveSelectedStats               ; engine/battle/unused_stats_functions.asm
extern PrintEndBattleText              ; src/home/trainers.asm — class-specific end text

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
    call PrintGhostText                 ; pret 3260 (real; non-ghost returns ZF=0)
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
    call HandleCounterMove              ; pret 3312 (real; non-counter returns ZF=0)
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
    call MirrorMoveCopyMove             ; real; failure returns ZF=1
    jz  ExecutePlayerMoveDone
    mov byte [ebp + wMonIsDisobedient], 0
    jmp CheckIfPlayerNeedsToChargeUp
.metronomeCheck:
    cmp al, METRONOME_EFFECT
    jne .mirrorNext
    call MetronomePickMove              ; real random move selection
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
    call PrintCriticalOHKOText          ; real battle text path
    call DisplayEffectiveness           ; real display_effectiveness.asm path
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecutePlayerMove; behavior=Psywave reroll never terminates when the byte-truncated upper bound is zero; evidence=pret source ExecutePlayerMove plus docs/references/yellow_glitches.md battle-system Psywave Infinite Loop; lifetime=permanent Gen-1 behavior}
    ; "Psywave Infinite Loop" — bh = (level*3)/2 truncated to a
    ; byte; at level 0, 1, or 171 this truncates to 0 (171*1.5 = 256.5 -> 256 mod
    ; 256 = 0). With bh=0, BOTH exit conditions here are unreachable: `and al,al`
    ; keeps rerolling until al!=0, then `cmp al,bh(0)` / `jae` is always taken
    ; (any al>0 is >=0) — the loop never terminates, hanging the battle engine.
    ; Gen-1 behavior, preserved verbatim (this port's shared `_Divide` primitive
    ; already guards its OWN divide-by-zero case — see
    ; engine/math/multiply_divide.asm — but that guard does not reach this
    ; separate reroll loop, which has no divisor at all). pret ref:
    ; engine/battle/core.asm (Psywave damage calc, player side),
    ; docs/references/yellow_glitches.md#battle-system (Psywave Infinite Loop).
    ; Safety: hang only (busy-loop on BattleRandom), no ACE — matches the
    ; catalogue's "Potential" ACE flag being about separate RNG-manipulation
    ; setups, not this loop itself.
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
    ; Calls pret's real animated engine (engine/gfx/hp_bar.asm) directly since the
    ; AnimateEnemyHPBar fork retirement; the wHPBar{Old,New,Max}HP staging above is
    ; exactly the state UpdateHPBar2 consumes.
    mov esi, wTileMap + E_HPBAR             ; hlcoord 2,2 (BCOORD battle projection)
    xor al, al                               ; xor a
    mov [ebp + wHPBarType], al               ; ld [wHPBarType], a — enemy: no HP number
    call UpdateHPBar2                        ; predef UpdateHPBar2
ApplyAttackToEnemyPokemonDone:
    jmp DrawHUDsAndHPBars                    ; pret `jp DrawHUDsAndHPBars` (tail; its ret returns)

; --- externs for the status-condition checks (pret core.asm:3499) ---
extern PrintText                       ; src/home/window.asm — pret PrintText (ESI = flat text stream)
extern GetMoveName                     ; home/names.asm
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecutePlayerMove; behavior=freeze bypasses recharge-bit clearing and leaves an extra recharge turn after thaw; evidence=pret check order plus docs/references/yellow_glitches.md battle-system Hyper Beam and Freeze; lifetime=permanent Gen-1 behavior}
    ; "Hyper Beam + Freeze" — this frozen check is tested (and, on
    ; a hit, returns) BEFORE .hyperBeamCheck below ever runs, so a mon that gets
    ; frozen while it still owes a Hyper Beam recharge turn never reaches the
    ; `and ..., ~(1<<NEEDS_TO_RECHARGE)` clear at .hyperBeamCheck while frozen.
    ; Gen-1 freeze has no auto-thaw (only a Fire-type hit via CheckDefrost cures
    ; it — see effects.asm:FreezeBurnParalyzeEffect), so the stale
    ; NEEDS_TO_RECHARGE bit survives every frozen turn; once thawed, the mon must
    ; ALSO burn a full "must recharge" turn it would otherwise not owe, on top of
    ; however long the freeze itself lasted — effectively "permanently unable to
    ; act" for the freeze's duration plus one extra forced-idle turn. Gen-1
    ; behavior (pret's own check order), preserved verbatim. pret ref:
    ; engine/battle/core.asm (ExecutePlayerMove .frozenCheck vs .hyperBeamCheck
    ; ordering), docs/references/yellow_glitches.md#battle-system (Hyper Beam +
    ; Freeze).
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecutePlayerMove; behavior=full paralysis or confusion self-hit clears charging without clearing invulnerability; evidence=pret source ExecutePlayerMove status-bit mask; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; "invulnerable for the whole battle" glitch — clearing CHARGING_UP
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:HandleSelfConfusionDamage; behavior=confusion self-hit is redirected to the user's own Substitute; evidence=pret tail jump plus docs/references/yellow_glitches.md battle-system Substitute and Confusion Self-Hit; lifetime=permanent Gen-1 behavior}
    ; "Substitute + Confusion Self-Hit" — self-inflicted confusion
    ; damage tail-jumps into the shared ApplyDamageToPlayerPokemon, which (being
    ; also the normal opponent-damage applicator) checks wPlayerBattleStatus2's
    ; HAS_SUBSTITUTE_UP and redirects the hit onto the confused mon's OWN
    ; Substitute (via AttackSubstitute) instead of unconditionally hitting its
    ; real HP the way a true self-inflicted hit should. Gen-1 behavior,
    ; preserved verbatim. pret ref: engine/battle/core.asm:HandleSelfConfusionDamage
    ; (jp ApplyDamageToPlayerPokemon), docs/references/yellow_glitches.md
    ; #battle-system (Substitute + Confusion Self-Hit)
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
; DoBattleTransitionAndInitBattleVariables — pret core.asm:6333. Shows the
; battle-transition animation over the LIVE overworld view + frozen OAM, then
; runs pret's post-transition teardown. Called from the two pret sites in
; init_battle.asm (after ReadTrainer / after LoadEnemyMonData).
; ---------------------------------------------------------------------------
extern BattleTransition                ; src/engine/battle/battle_transitions.asm
extern saved_ow_view_ptr               ; init_battle.asm — overworld view-ptr save slot
extern SnapshotRenderedTileMap         ; src/ppu/ppu.asm — re-crop wTileMap to the blitted origin
global DoBattleTransitionAndInitBattleVariables
DoBattleTransitionAndInitBattleVariables:
    ; DEVIATION{class=HAL; pret=engine/battle/core.asm:DoBattleTransitionAndInitBattleVariables; behavior=performs the port's flat-canvas switch before the transition - re-crops wTileMap to the rendered camera origin, then saves and zeroes the overworld view pointer, zeroes the fine-scroll shadows and hardware mirrors, and disables tile animations; evidence=pret's BG is already a tilemap the wipe mutates in place, while the port's render_bg takes the overworld path whenever wCurrentTileBlockMapViewPointer is nonzero and would never show wTileMap writes; lifetime=permanent, render HAL}
    ; wTileMap is the player-anchored COLLISION crop, not a mirror of the screen,
    ; so the flat path would otherwise draw the same world from a different origin
    ; and the whole background would jump on the switch frame while the OBJ layer
    ; stayed put (measured +32,+32 px). Re-crop to what render_bg actually blitted.
    call SnapshotRenderedTileMap
    mov ax, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [saved_ow_view_ptr], ax
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + hSCX], 0
    mov byte [ebp + hSCY], 0
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    mov byte [ebp + hTileAnimations], 0
    ; link battle branch — never taken in the port (wLinkState is never
    ; LINK_STATE_BATTLING); kept faithful minus the unreachable link textbox.
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .next
    mov byte [ebp + wMenuJoypadPollCount], 0
    ; TODO-HW: network HAL — DisplayLinkBattleVersusTextBox unported (Phase 4;
    ; this branch is unreachable until link battles exist)
    mov byte [ebp + wUpdateSpritesEnabled], 1
    call ClearScreen
.next:
    call DelayFrame
    call BattleTransition                        ; pret: predef BattleTransition
    call LoadHudAndHpBarAndStatusTilePatterns
    mov byte [ebp + hAutoBGTransferEnabled], 1   ; vestigial (inert in the port)
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    call ClearSprites
    call ClearScreen
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    mov [ebp + hWY], al
    mov [ebp + IO_WY], al
    mov [ebp + hTileAnimations], al
    mov [ebp + wPlayerStatsToDouble + 0], al     ; pret: 5 x ld [hli], a
    mov [ebp + wPlayerStatsToDouble + 1], al
    mov [ebp + wPlayerStatsToDouble + 2], al
    mov [ebp + wPlayerStatsToDouble + 3], al
    mov [ebp + wPlayerStatsToDouble + 4], al
    mov [ebp + wPlayerDisabledMove], al
    ret

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
    call PrintGhostText                 ; real; non-ghost returns ZF=0
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
    call SwapPlayerAndEnemyLevels       ; pret :5707 — swap ON for the enemy turn
    mov al, [ebp + wEnemyMoveEffect]
    mov esi, SetDamageEffects
    mov edx, 1
    call IsInArray
    jc  EnemyMoveHitTest
    call CriticalHitTest
    call HandleCounterMove              ; real; non-counter returns ZF=0
    jz  HandleIfEnemyMoveMissed
    ; pret :5716-5718 swaps OFF across GetDamageVarsForEnemyAttack precisely so
    ; it reads the TRUE enemy level (`ld a,[wEnemyMonLevel] / ld e,a`), then
    ; back ON for CalculateDamage — which takes the level in E and reads no
    ; level byte itself.
    call SwapPlayerAndEnemyLevels
    call GetDamageVarsForEnemyAttack
    call SwapPlayerAndEnemyLevels
    call CalculateDamage
    jz  EnemyCheckIfFlyOrChargeEffect   ; jp z — 0 BP status move
    call AdjustDamageForMoveType
    call RandomizeDamage
; pret core.asm:5724. This was `.eMoveHitTest`, a routine-local label — the same
; code under a FORKED NAME, which is what made faithdiff report both a DROPPED
; EnemyMoveHitTest and an ADDED MoveHitTest on EnemyCalcMoveDamage: with the
; body local, its `call MoveHitTest` counted as EnemyCalcMoveDamage's own.
; Restoring pret's global name is behaviour-identical (same code, same
; fall-through into HandleIfEnemyMoveMissed) and closes both lines.
EnemyMoveHitTest:
    call MoveHitTest
HandleIfEnemyMoveMissed:                ; pret 5726 — Bide continuation
    mov al, [ebp + wMoveMissed]
    and al, al
    jz  .moveDidNotMiss
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, EXPLODE_EFFECT
    je  HandleExplosionMiss
    jmp EnemyCheckIfFlyOrChargeEffect
.moveDidNotMiss:                        ; pret :5734-5735
    call SwapPlayerAndEnemyLevels       ; swap OFF before damage application
GetEnemyAnimationType:                  ; pret 5737 — Trapping continuation / multi-hit loop
    mov al, [ebp + wEnemyMoveEffect]
    and al, al
    mov al, ANIMATIONTYPE_BLINK_ENEMY_MON_SPRITE
    jz  PlayEnemyMoveAnimation
    mov al, ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT
    jmp PlayEnemyMoveAnimation          ; pret `jr PlayEnemyMoveAnimation` — the
                                        ; explosion-miss arm now sits between
                                        ; these two, so this can no longer fall
                                        ; through as it used to
HandleExplosionMiss:                    ; pret core.asm:5744
    ; A IS THE ANIMATION TYPE, and pret zeroes it here. PlayEnemyMoveAnimation
    ; below does `push af ... pop af / ld [wAnimationType], a`, so whatever is
    ; in A at entry BECOMES wAnimationType. The port used to jump straight to
    ; PlayEnemyMoveAnimation from the EXPLODE_EFFECT test above, still carrying
    ; wEnemyMoveEffect in AL — so a missed enemy Explosion/Selfdestruct set
    ; wAnimationType = EXPLODE_EFFECT instead of 0.
    ;
    ; The DEVIATION that used to sit here — "the port omits pret's level swaps
    ; as a consistent whole" — is RETIRED 2026-08-13: all 7 swap sites are
    ; restored, so this one is paired again.
    call SwapPlayerAndEnemyLevels       ; pret :5745 — swap OFF on the miss arm
    xor al, al                          ; pret `xor a` — animation type 0
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
    call SwapPlayerAndEnemyLevels       ; pret :5768 — swap OFF on this arm too
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
    call MirrorMoveCopyMove             ; real; failure returns ZF=1
    jz  ExecuteEnemyMoveDone
    mov byte [ebp + wMonIsDisobedient], 0
    jmp CheckIfEnemyNeedsToChargeUp
.metronomeCheck:
    cmp al, METRONOME_EFFECT
    jne .mirrorNext
    call MetronomePickMove              ; real random move selection
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
    call PrintCriticalOHKOText          ; real battle text path
    call DisplayEffectiveness           ; real display_effectiveness.asm path
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecuteEnemyMove; behavior=enemy Psywave reroll never terminates when the byte-truncated upper bound is zero; evidence=pret source ExecuteEnemyMove plus docs/references/yellow_glitches.md battle-system Psywave Infinite Loop; lifetime=permanent Gen-1 behavior}
    ; "Psywave Infinite Loop" (enemy side) — same root cause as the
    ; player-side loop above: bh truncates to 0 at level 0/1/171, and with no
    ; reject-0 check here even `cmp al,bh(0)`/`jae` alone is unconditionally taken
    ; (any al is >=0), hanging the battle engine. pret ref: engine/battle/core.asm
    ; (Psywave damage calc, enemy side), docs/references/yellow_glitches.md
    ; #battle-system (Psywave Infinite Loop). Safety: hang only, no ACE.
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
    ; Calls pret's real animated engine directly since the AnimatePlayerHPBar fork
    ; retirement. The stride republish carries the same justification as the
    ; DrawPlayerHUDAndHPBar DEVIATION (class=projection) above: UpdateHPBar2's
    ; number print places the cur digits at bar + [text_row_stride] + 1, and the
    ; last dialog print may have left the stride at 20.
    mov dword [text_row_stride], FW
    mov esi, wTileMap + P_HPBAR             ; hlcoord 10,9 (BCOORD battle projection)
    mov al, 1                                ; ld a, $1
    mov [ebp + wHPBarType], al               ; ld [wHPBarType], a — player: tick the number
    call UpdateHPBar2                        ; predef UpdateHPBar2
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:AttackSubstitute; behavior=substitute overflow damage uses stale wDamage rather than the substitute's pre-hit HP; evidence=pret source AttackSubstitute damage flow; lifetime=permanent Gen-1 behavior}
    ; wDamage is NOT updated with the substitute's pre-hit HP on a
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecuteEnemyMove; behavior=enemy freeze bypasses recharge-bit clearing and leaves an extra recharge turn after thaw; evidence=pret check order plus docs/references/yellow_glitches.md battle-system Hyper Beam and Freeze; lifetime=permanent Gen-1 behavior}
    ; "Hyper Beam + Freeze" (enemy side) — same ordering issue as
    ; the player-side .frozenCheck above: this returns before the enemy's
    ; .eHyperBeamCheck can clear NEEDS_TO_RECHARGE, so the stale bit survives
    ; every frozen turn and costs one extra forced-idle turn once thawed. pret
    ; ref: engine/battle/core.asm (ExecuteEnemyMove .eFrozenCheck vs
    ; .eHyperBeamCheck ordering), docs/references/yellow_glitches.md
    ; #battle-system (Hyper Beam + Freeze).
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
    ; BUG{class=data-model; pret=engine/battle/core.asm:ExecuteEnemyMove; behavior=enemy full paralysis or confusion self-hit clears charging without clearing invulnerability; evidence=pret source ExecuteEnemyMove status-bit mask; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; "invulnerable for the whole battle" glitch (enemy side) — see the
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
    ; pret :6085. This swap pairs with the un-swaps on the
    ; HandleIfEnemyMoveMissed continuations (.moveDidNotMiss,
    ; HandleExplosionMiss, EnemyCheckIfFlyOrChargeEffect) — restored 2026-08-13
    ; as a SET, which is what makes it safe. The earlier note here was right
    ; that adding this one alone would leave it un-undone.
    call SwapPlayerAndEnemyLevels
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
; AnimateRetreatingPlayerMon — pret core.asm:1828. The withdraw animation: the
; player's mon shrinks 7x7 -> 5x5 -> 3x3 -> a single ball tile, then the frame is
; cleared. The starter Pikachu takes a different path entirely (it walks off via
; AnimationSlideMonOff rather than returning to a ball).
;
; PORTED 2026-08-12 (battle plan 2a). It read `missing` in the label DB; the
; voluntary switch (PartyMenuOrRockOrRun -> SwitchPlayerMon) cannot be faithful
; without it.
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:AnimateRetreatingPlayerMon; behavior=the four tilemap positions are BCOORD(1,5) BCOORD(3,7) BCOORD(4,9) and BCOORD(5,11) on the port's 40x25 canvas instead of pret's raw hlcoord/ldcoord_a addresses; evidence=every in-battle screen in this port is drawn through the BCOORD battle-frame projection in include/coords.inc which offsets pret hlcoords by +10 columns and +3 rows, and the send-out twin of this animation in init_battle.asm already uses it for the same mon area; lifetime=permanent while the port renders a 40x25 canvas}
;
; The predef CopyDownscaledMonTiles is called directly (ESI dest, BH rows, BL
; cols) under the port's standing no-predef-dispatcher convention, which that
; routine already carries its own DEVIATION{class=HAL} for.
;
; In: EBP = GB base, [wPlayerMonNumber], [wWhichPokemon].
; ---------------------------------------------------------------------------
AnimateRetreatingPlayerMon:
    mov al, [ebp + wWhichPokemon]
    push eax                                ; pret: push af (A = caller's wWhichPokemon)
    mov al, [ebp + wPlayerMonNumber]
    mov [ebp + wWhichPokemon], al
    call IsThisPartyMonStarterPikachu       ; callfar; CF=1 iff it is our Pikachu
    pop ebx                                 ; pret: pop bc — b = the saved value.
                                            ; pret's push af/pop bc lands it in B
                                            ; because af pushes A high; the port's
                                            ; push eax/pop ebx lands it in BL.
    mov al, bl                              ; pret: ld a, b
    mov [ebp + wWhichPokemon], al           ; restore the caller's index
    jc .starterPikachu                      ; jr c  (pop/mov do not touch CF)
    mov esi, BCOORD(1, 5)                   ; PROJ — pret hlcoord 1, 5
    mov bh, 7                               ; lb bc, 7, 7
    mov bl, 7
    call ClearScreenArea
    mov esi, BCOORD(3, 7)                   ; PROJ — pret hlcoord 3, 7
    mov bh, 5                               ; lb bc, 5, 5
    mov bl, 5
    mov byte [ebp + wDownscaledMonSize], 0  ; xor a / ld [wDownscaledMonSize], a
    mov byte [ebp + hBaseTileID], 0         ; ldh [hBaseTileID], a
    call CopyDownscaledMonTiles             ; predef
    mov bl, 4                               ; ld c, 4
    call DelayFrames
    call .clearScreenArea
    mov esi, BCOORD(4, 9)                   ; PROJ — pret hlcoord 4, 9
    mov bh, 3                               ; lb bc, 3, 3
    mov bl, 3
    mov byte [ebp + wDownscaledMonSize], 1  ; ld a,1 / ld [wDownscaledMonSize],a
    mov byte [ebp + hBaseTileID], 0         ; xor a / ldh [hBaseTileID], a
    call CopyDownscaledMonTiles             ; predef
    call Delay3
    call .clearScreenArea
    mov byte [ebp + BCOORD(5, 11)], 0x4c    ; PROJ — pret ld a,$4c / ldcoord_a 5,11
    jmp short .clearScreenArea              ; jr .clearScreenArea (tail)
.starterPikachu:
    mov byte [ebp + hWhoseTurn], 0          ; xor a / ldh [hWhoseTurn], a
    call AnimationSlideMonOff               ; callfar
    ret
.clearScreenArea:
    mov esi, BCOORD(1, 5)                   ; PROJ — pret hlcoord 1, 5
    mov bh, 7                               ; lb bc, 7, 7
    mov bl, 7
    call ClearScreenArea
    ret

; ---------------------------------------------------------------------------
; ReadPlayerMonCurHPAndStatus — pret core.asm:1875. "Copies player's current
; pokemon's current HP, party pos, and status into the party struct data so it
; stays after battle or switching." The copy runs BATTLE MON -> PARTY, four bytes
; (MON_STATUS + 1 - MON_HP): the big-endian HP word, the party-pos byte that sits
; between HP and status, and the status byte.
;
; This was a no-op stub whose comment had the direction backwards ("the battle-mon
; struct IS the live source"). The direction is load-bearing: RemoveFaintedPlayerMon
; calls this (pret core.asm:1036) and HandlePlayerMonFainted then consults
; AnyPartyAlive, which reads the PARTY HP words. With the write-back missing, a
; fainted mon still read as alive in its party slot, so the black-out branch was
; unreachable and ChooseNextMon re-sent the same mon at its pre-faint HP — an
; infinite faint loop, found by the battle_blackout gate.
; ---------------------------------------------------------------------------
ReadPlayerMonCurHPAndStatus:
    mov al, [ebp + wPlayerMonNumber]
    mov esi, wPartyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; ESI = &wPartyMon<n>HP
    mov edx, esi                        ; pret: ld d,h / ld e,l
    mov esi, wBattleMonHP
    mov bx, MON_STATUS + 1 - MON_HP     ; HP word + party pos + status
    jmp CopyData                        ; tail (pret: jp CopyData)

; ---------------------------------------------------------------------------
; CheckNumAttacksLeft — pret core.asm:692. Called at the end of every turn from
; both MainInBattleLoop tails: when a side's multi-turn counter has run out,
; clear USING_TRAPPING_MOVE so Wrap/Bind/Fire Spin/Clamp stop trapping.
;
; TRANSLATED 2026-08-11 (battle_completion 3a). It was a bare `ret` under the
; comment "No-op until the multi-turn move effects are wired" — stale: the
; effects that seed the counters ARE wired and linked. TrappingEffect_ sets
; USING_TRAPPING_MOVE and seeds wXxxNumAttacksLeft (effects.asm:1451-1480), and
; the Bide, Thrash and multi-strike effects all write the same overloaded byte
; (effects.asm:1000-1096, 1238-1290). With this routine a no-op, nothing on the
; ordinary turn path ever cleared the flag once set.
;
; pret's `ret nz` is spelled `jnz .done` here so the enemy half stays a
; fallthrough; no call graph or flag contract changes.
; ---------------------------------------------------------------------------
CheckNumAttacksLeft:
    mov al, [ebp + wPlayerNumAttacksLeft]
    test al, al
    jnz .checkEnemy                      ; jr nz, .checkEnemy
    ; player has 0 attacks left — no longer using a multi-turn attack like Wrap
    and byte [ebp + wPlayerBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
.checkEnemy:
    mov al, [ebp + wEnemyNumAttacksLeft]
    test al, al
    jnz .done                            ; ret nz
    ; enemy has 0 attacks left
    and byte [ebp + wEnemyBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
.done:
    ret

; ---------------------------------------------------------------------------
; BagWasSelected / DisplayPlayerBag / DisplayBagMenu / UseBagItem —
; pret core.asm:2292-2400. The in-battle bag: pick an item off the real list
; menu, run it through the shared item dispatcher, and decide whether the enemy
; got a turn and whether the battle ended.
;
; PORTED 2026-08-12 (battle plan 2c). It replaces the port-only `BattleItemMenu`,
; which is DELETED rather than renamed — pret's body belongs here in core.asm
; under the mirror rule, exactly as 2a did for BattlePartyMenu. Nothing about
; the item EFFECTS is forked: this calls the same UseItem the overworld bag uses.
;
; DEVIATION{class=data-model; pret=engine/battle/core.asm:BagWasSelected; behavior=the OLD_MAN and PIKACHU tutorial branch keeps the port's one-line POKe BALL presentation instead of pointing wListPointer at pret SimulatedInputBattleItemList and running the list menu over it; evidence=wListPointer is a 16-bit GB address in this port and DisplayListMenuID reads the list through it as [ebp+esi], so a flat program-image table cannot be stored there without first staging a copy into GB memory, and the tutorial flow only ever makes the one scripted selection that presentation already performs; lifetime=until battle_completion 4b stages the simulated-input list into GB memory}
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:UseBagItem; behavior=every path back to the battle screen clears the port-only g_window_count and g_bg_whiteout and re-asserts text_msgbox; evidence=the port draws the bag through the list menu which registers its own window descriptors in list_draw_box_border and blanks the background, so without the teardown the restored battle screen is composited as a blank frame - the same three obligations PartyMenuOrRockOrRun already carries and which start_sub_menus.asm performs for the START-menu bag; lifetime=permanent while the port composites windows over a blankable background}
; ---------------------------------------------------------------------------
BagWasSelected:
    call LoadScreenTilesFromBuffer1
    cmp byte [ebp + wBattleType], 0     ; is it a normal battle?
    jne .next                           ; jr nz
    call DrawHUDsAndHPBars
.next:
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN         ; the old man tutorial?
    je .simulatedInputBattle
    cmp al, BATTLE_TYPE_PIKACHU         ; the Prof. Oak / Pikachu battle?
    je .simulatedInputBattle
    jmp DisplayPlayerBag                ; jr
.simulatedInputBattle:
    ; pret points wListPointer at SimulatedInputBattleItemList (one POKé BALL)
    ; and lets the simulated input select it. See the class=data-model note
    ; above for why the port cannot store that flat table in wListPointer; the
    ; scripted selection is performed directly instead. 4b owns the real list.
    call ShowSimulatedInputBagBox       ; port-only presentation (was BattleItemMenu)
    mov byte [ebp + wCurItem], POKE_BALL
    jmp UseBagItem

DisplayPlayerBag:
    ; get the pointer to the player's bag when in a normal battle
    mov word [ebp + wListPointer], wNumBagItems
DisplayBagMenu:
    ; PORT-ONLY: raise the background whiteout for the duration of the list.
    ; The port draws the list menu into the scratch AND shows it through window
    ; descriptors (list_draw_box_border); with the battle canvas still
    ; composited underneath, BOTH copies are visible — measured 2026-08-12, the
    ; bag rendered twice, once top-left and once top-right. Every other in-game
    ; caller that owns the screen for a list raises this first
    ; (bills_pc.asm:308). RestoreBattleScreenState clears it on every exit.
    mov dword [g_bg_whiteout], 1
    mov byte [ebp + wPrintItemPrices], 0            ; xor a
    mov byte [ebp + wListMenuID], ITEMLISTMENU
    mov al, [ebp + wBagSavedMenuItem]
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wBagSavedMenuItem], al
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 0
    mov byte [ebp + wMenuItemToSwap], 0
    jnc UseBagItem                                  ; pret: jp c, DisplayBattleMenu
    call RestoreBattleScreenState                   ; cancelled — port-only teardown
    jmp DisplayBattleMenu

UseBagItem:
    ; either use an item from the bag or use a safari zone item
    mov al, [ebp + wCurItem]
    mov [ebp + wNamedObjectIndex], al
    call GetItemName
    call CopyToStringBuffer
    mov byte [ebp + wPseudoItemID], 0               ; xor a
    call UseItem
    call LoadHudTilePatterns
    call ClearSprites
    mov byte [ebp + wCurrentMenuItem], 0            ; xor a
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    je .checkIfMonCaptured                          ; jr z
    mov al, [ebp + wActionResultOrTookBattleTurn]
    and al, al                                      ; was the item used successfully?
    jz BagWasSelected                               ; jp z — back to the bag menu
    mov al, [ebp + wPlayerBattleStatus1]
    test al, (1 << USING_TRAPPING_MOVE)             ; mid-Wrap?
    jz .checkIfMonCaptured                          ; jr z
    dec byte [ebp + wPlayerNumAttacksLeft]
    jnz .checkIfMonCaptured                         ; jr nz
    and byte [ebp + wPlayerBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
.checkIfMonCaptured:
    mov al, [ebp + wCapturedMonSpecies]
    and al, al                                      ; captured with a ball?
    jnz .returnAfterCapturingMon                    ; jr nz
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    je .returnAfterUsingItem_NoCapture               ; jr z
; not a safari battle
    call RestoreBattleScreenState                   ; port-only teardown, then pret's:
    call LoadScreenTilesFromBuffer1
    call DrawHUDsAndHPBars
    call Delay3
.returnAfterUsingItem_NoCapture:
    call GBPalNormal
    and al, al                                      ; reset carry
    ret
.returnAfterCapturingMon:
    call GBPalNormal
    mov byte [ebp + wCapturedMonSpecies], 0         ; xor a
    mov byte [ebp + wBattleResult], 2               ; ld a,$2
    stc                                             ; scf — the battle is over
    ret

; ---------------------------------------------------------------------------
; RestoreBattleScreenState — port-only. Undo the list menu's screen takeover so
; the battle screen composites again: drop its window descriptors, clear the
; background whiteout, and put the text projection back on the battle record.
; pret has no counterpart; see the class=projection note on UseBagItem, and the
; identical trio in PartyMenuOrRockOrRun.
; ---------------------------------------------------------------------------
RestoreBattleScreenState:
    mov dword [g_window_count], 0
    mov dword [g_bg_whiteout], 0
    mov dword [text_msgbox], msgbox_centered
    ret

; ---------------------------------------------------------------------------
; PartyMenuOrRockOrRun — pret core.asm:2404. The battle menu's third slot: PKMN
; on a normal battle, ROCK in the Safari Zone, and RUN when the id says so.
;
; PORTED 2026-08-12 (battle plan 2a). It replaces the port-only ret-only helper
; `BattlePartyMenu`, which was a forked name for this routine's tail; that name
; is gone rather than renamed, because the mirror rule puts pret's body here in
; core.asm. `DisplayBattleMenu.partyMenuOrRun` now tail-jumps here exactly as
; pret's `jp PartyMenuOrRockOrRun` does, so the `dec a` run check lives at the
; head of this routine where pret keeps it.
;
; Structure, all pret's: pick the party mon, then SWITCH / STATS / CANCEL.
; STATS opens both status screens and then RELOADS the enemy pic (substitute or
; minimized forms take their animation instead) before returning to the list.
; SWITCH refuses a mon that is already out or fainted, and otherwise falls
; through into SwitchPlayerMon below — pret's own fall-through, preserved.
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:PartyMenuOrRockOrRun; behavior=the deselect wipe starts at BCOORD(11, 11) and its length uses the port SCREEN_WIDTH of 40 rather than the Game Boy 20; evidence=every in-battle screen here is drawn through the BCOORD battle-frame projection in include/coords.inc and the port redefines SCREEN_WIDTH to SCREEN_TILES_W as ClearScreenArea already documents, so pret's 6 * SCREEN_WIDTH + 9 expression carries the canvas width unchanged; lifetime=permanent while the port renders a 40x25 canvas}
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:PartyMenuOrRockOrRun; behavior=both exits from the party menu clear the port-only g_window_count and g_bg_whiteout before restoring the battle screen; evidence=this port draws the party menu as a full-screen takeover from two window descriptors over a blanked background which party_menu.asm turns on with g_bg_whiteout and render_bg then skips the tilemap entirely, so without the teardown the restored battle screen is composited as a blank frame - the START-menu caller in start_sub_menus.asm performs the identical pair; lifetime=permanent while the port composites windows over a blankable background}
;
; DEVIATION{class=banking; pret=engine/battle/core.asm:PartyMenuOrRockOrRun; behavior=the two StatusScreen predefs are direct calls and the enemy-animation Bankswitch is an indirect call through ESI; evidence=the port has one flat address space and no predef dispatcher so every predef target is called directly, and pret's Bankswitch is a bank load plus jp hl which in a flat image is just the indirect call; lifetime=permanent while the port is flat-addressed and dispatcher-free}
;
; In: AL = the battle-menu item id (2 = PKMN/ROCK, 3 = RUN).
; ---------------------------------------------------------------------------
PartyMenuOrRockOrRun:
    dec al                              ; was Run selected?
    jnz BattleMenu_RunWasSelected       ; jp nz
; party menu or rock was selected
    call SaveScreenTilesToBuffer2
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_SAFARI
    jne .partyMenuWasSelected           ; jr nz
; safari battle
    mov byte [ebp + wCurItem], SAFARI_ROCK
    jmp UseBagItem                      ; jp — STUB today, retired by plan 2c
.partyMenuWasSelected:
    call LoadScreenTilesFromBuffer1
    mov byte [ebp + wPartyMenuTypeOrMessageID], NORMAL_PARTY_MENU  ; xor a
    mov byte [ebp + wMenuItemToSwap], 0
    call DisplayPartyMenu
.checkIfPartyMonWasSelected:
    jnc .partyMonWasSelected            ; jp nc — CF=0 means a mon was chosen
.quitPartyMenu:
    call ClearSprites
    call GBPalWhiteOut
    call LoadHudTilePatterns
    ; PORT-ONLY TEARDOWN — pret has no counterpart, and without it the battle
    ; screen never comes back. The port's party menu is a FULL-SCREEN TAKEOVER
    ; drawn from two window descriptors over a blanked background
    ; (party_menu.asm sets g_bg_whiteout=1), so leaving it must drop both. Only
    ; the START-menu caller did this — src/engine/menus/start_sub_menus.asm
    ; does exactly `g_window_count = 0` + `g_bg_whiteout = 0` on its way out —
    ; and battle plan 2a added the second-ever caller without it.
    ; Measured 2026-08-12 (DEBUG_BATTLE_SWITCH): windows go 0 -> 2 when the menu
    ; opens and the back buffer drops from 14 distinct colours to 8, then stays
    ; blank afterwards, because render_bg's g_bg_whiteout early-out fills with BG
    ; colour 0 and skips the map entirely. Clearing the window list ALONE is
    ; inert — that was tried and measured — because the whiteout is what blanks
    ; the background.
    mov dword [g_window_count], 0
    mov dword [g_bg_whiteout], 0
    ; ...and re-assert the BATTLE text projection. The party menu scopes
    ; text_msgbox around its own PrintText and restores it to msgbox_dialog, the
    ; OVERWORLD record (party_menu.asm:436) — right for its START-menu caller,
    ; wrong for this one. Left alone, the next battle message (RetreatMon's
    ; switch-out line, printed through the plain PrintText pret uses) comes out
    ; with overworld geometry: measured 2026-08-12 at canvas rows 6-8 cols 0-20,
    ; a stride-20 box at GB(0,12), while the battle's own dialog box sat empty at
    ; rows 15-20. The record is the caller's to own — party_menu.asm's own
    ; annotation says as much, putting the choice in the screen that makes it.
    mov dword [text_msgbox], msgbox_centered
    call LoadScreenTilesFromBuffer2
    call RunDefaultPaletteCommand
    call GBPalNormal
    jmp DisplayBattleMenu               ; jp
.partyMonDeselected:
    ; Wipe the SWITCH/STATS/CANCEL box before going back to the list. This has to
    ; erase it where DisplaySwitchStatsCancelPartyBox DREW it — the party screen's
    ; stride-20 scratch — not the canvas. Both the address and the count are
    ; stride-bearing: pret's `ld bc, 6 * SCREEN_WIDTH + 9` is 6 GB rows plus 9
    ; cells (129), and taking the port's SCREEN_WIDTH (40, the canvas) made it 249
    ; bytes at a canvas address, which cleared cells this box never occupied and
    ; left the real ones standing.
    mov esi, wTileMap + 11 * PARTY_SCRATCH_STRIDE + 11   ; pret hlcoord 11, 11
    mov bx, 6 * PARTY_SCRATCH_STRIDE + 9  ; ld bc, ... (FillMemory count in BX)
    mov al, 0x7f                        ; ld a, " " — the blank tile
    call FillMemory
    call PartyMenuMirror                ; port: push the erase to the window too
    mov byte [ebp + wPartyMenuTypeOrMessageID], NORMAL_PARTY_MENU  ; xor a
    call GoBackToPartyMenu
    jmp .checkIfPartyMonWasSelected     ; jr
.partyMonWasSelected:
    ; DEVIATION{class=projection; pret=engine/battle/core.asm:PartyMenuOrRockOrRun; behavior=the SWITCH STATS CANCEL box is drawn by a port-only routine into the party screen stride-20 scratch instead of through DisplayTextBoxID, and PartyMenuMirror is hooked as the cursor redraw callback; evidence=DisplayTextBoxID_ forces text_row_stride to the canvas width and works in canvas coordinates while this screen is a full-screen takeover that sets g_bg_whiteout so render_bg skips the tilemap entirely and the visible surface is the stride-20 scratch that PartyMenuMirror carries into GB_TILEMAP1 for the window descriptors, so a canvas draw is never composited - the geometry drawn is pret's own text_box_text row 11 11 19 17 with text at 13 12; lifetime=permanent window-compositor boundary, the same one msgbox_party already crossed for this screen's message box}
    ; Backlog item 10c — RESOLVED. Was: drawn to the canvas, invisible (the menu
    ; still worked; only the draw was missing).
    call DisplaySwitchStatsCancelPartyBox
    call PartyMenuMirror                ; port: carry the finished box to the window
    ; pret walks hl from wTopMenuItemY; the port writes each field directly.
    mov byte [ebp + wTopMenuItemY], 0x0c
    mov byte [ebp + wTopMenuItemX], 0x0c
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wMaxMenuItem], 2
    mov byte [ebp + wMenuWatchedKeys], PAD_B | PAD_A
    mov byte [ebp + wLastMenuItem], 0
    ; port: the cursor the generic driver draws lands in the same scratch, so it
    ; needs the same mirror hook HandlePartyMenuInput uses (home/pokemon.asm).
    ; text_row_stride and menu_item_step are already the party screen's (20 and
    ; 2*20, set by home/pokemon.asm) — this box shares that geometry by design.
    mov dword [menu_redraw_cb], PartyMenuMirror
    call HandleMenuInput
    mov dword [menu_redraw_cb], 0
    test al, PAD_B                      ; bit B_PAD_B, a
    jnz .partyMonDeselected             ; jr nz — B cancels
; A was pressed
    call PlaceUnfilledArrowMenuCursor
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 2                           ; was Cancel selected?
    je .quitPartyMenu                   ; jr z
    and al, al                          ; was Switch selected?
    jz .switchMon                       ; jr z
; Stats was selected
    mov byte [ebp + wMonDataLocation], 0    ; xor a — PLAYER_PARTY_DATA
    mov esi, wPartyMon1                     ; ld hl, wPartyMon1
    call ClearSprites
    call StatusScreen                       ; predef
    call StatusScreen2                      ; predef
; now we need to reload the enemy mon pic
    mov byte [ebp + hWhoseTurn], 1
    mov al, [ebp + wEnemyBattleStatus2]
    test al, (1 << HAS_SUBSTITUTE_UP)       ; does the enemy mon have a substitute?
    mov esi, AnimationSubstitute            ; ld hl, AnimationSubstitute
    jnz .doEnemyMonAnimation                ; jr nz
; enemy mon doesn't have substitute
    mov al, [ebp + wEnemyMonMinimized]
    test al, al                             ; has the enemy mon used Minimize?
    mov esi, AnimationMinimizeMon           ; ld hl, AnimationMinimizeMon
    jnz .doEnemyMonAnimation                ; jr nz
; enemy mon is not minimized
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    ; DEVIATION{class=data-model; pret=engine/battle/core.asm:PartyMenuOrRockOrRun; behavior=converts the enemy species to a national dex number through IndexToPokedex and passes dex-1 in EAX before LoadMonFrontSprite, and skips the reload entirely when the species has no dex number; evidence=this port resolves front pics through the dex-keyed MonFrontPics table because the mon header's front-pic pointer is a GB ROM address with no meaning in a flat image, so LoadMonFrontSprite takes dex-1 in EAX where pret's reads the header and takes no such argument, and the two other call sites already supply it - home/pokemon.asm with dec eax after IndexToPokedex and init_battle.asm with xor eax eax on the special-pic handle path; lifetime=permanent, the port's dex-keyed pic-resolution boundary}
    ; PORT-ONLY, LOAD-BEARING: this port's LoadMonFrontSprite is DEX-KEYED —
    ; `In: EAX = dex-1`, and UncompressMonSprite does `lea esi, [MonFrontPics +
    ; eax*8]` — because the mon header's front-pic pointer is a GB ROM address
    ; with no meaning in a flat image (home/pics.asm's header says so). pret's
    ; is header-keyed and needs no such argument, so translating its
    ; `ld de, vFrontPic / call LoadMonFrontSprite` literally left EAX holding
    ; whatever GetMonHeader happened to leave, and this call decoded an
    ; ARBITRARY species over the enemy. MEASURED 2026-08-15: view STATS on a
    ; party mon in battle and the enemy came back wearing that mon's sprite
    ; (PIDGEY rendered as PERSIAN, the mon whose stats were shown) — because
    ; StatusScreen's own dex-keyed load is what left EAX set.
    ; The other two call sites already honor the contract: home/pokemon.asm's
    ; `dec eax` after IndexToPokedex, and init_battle.asm's documented
    ; `xor eax, eax` on the special-pic handle path.
    push ebx
    movzx ebx, byte [ebp + wPokedexNum]     ; save the caller's wPokedexNum
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wPokedexNum], al
    call IndexToPokedex                     ; species index -> national dex no.
    movzx eax, byte [ebp + wPokedexNum]
    mov [ebp + wPokedexNum], bl             ; restore it, as pokemon.asm does
    pop ebx
    test al, al
    jz .enemyMonPicReloaded                 ; dex 0 = no dex number: MonFrontPics
                                            ; has no row, and dec would index
                                            ; [-1]. Ghosts/fossils never reach
                                            ; here — UncompressMonSprite takes
                                            ; the header's special-pic handle
                                            ; first and ignores EAX entirely.
    dec eax                                 ; dex-1 = index into MonFrontPics
    mov edx, vFrontPic                      ; ld de, vFrontPic
    call LoadMonFrontSprite
    jmp .enemyMonPicReloaded                ; jr
.doEnemyMonAnimation:
    call esi                                ; pret: ld b, BANK(...) / call Bankswitch
.enemyMonPicReloaded:
    jmp .partyMenuWasSelected               ; jp — back to the list
.switchMon:
    mov dh, [ebp + wPlayerMonNumber]        ; ld a,[wPlayerMonNumber] / ld d,a
    mov al, [ebp + wWhichPokemon]
    cmp al, dh                              ; already out?
    jne .notAlreadyOut                      ; jr nz
; mon is already out
    mov esi, AlreadyOutText
    call PrintText
    jmp .partyMonDeselected                 ; jp
.notAlreadyOut:
    call HasMonFainted
    jz .partyMonDeselected                  ; jp z — can't switch to a fainted mon
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    call GBPalWhiteOut
    call ClearSprites
    call LoadHudTilePatterns
    mov dword [g_window_count], 0       ; port-only teardown — see .quitPartyMenu
    mov dword [g_bg_whiteout], 0
    mov dword [text_msgbox], msgbox_centered  ; battle geometry again — ditto
    call LoadScreenTilesFromBuffer1
    call RunDefaultPaletteCommand
    call GBPalNormal
    ; fall through to SwitchPlayerMon, exactly as pret does

; ---------------------------------------------------------------------------
; SwitchPlayerMon — pret core.asm:2525. Withdraw the active mon and send out the
; one the player picked. Reached two ways in pret: as the fall-through tail of
; PartyMenuOrRockOrRun's `.switchMon` (the voluntary switch, battle plan 2a), and
; by the forced-switch path (2b).
;
; PORTED 2026-08-12 (battle plan 2a). It read `missing`, along with its two
; callees RetreatMon (now src/engine/battle/common_text.asm) and
; AnimateRetreatingPlayerMon (above in this file).
;
; The 50-frame wait is pret's and it is load-bearing rather than decorative:
; RetreatMon has just printed the trainer's parting line, and the wait is what
; leaves it on screen before the withdraw animation paints over it.
;
; DEVIATION{class=banking; pret=engine/battle/core.asm:SwitchPlayerMon; behavior=RetreatMon is called directly and the two FlagActionPredef predef calls are plain FlagAction calls; evidence=the port has one flat address space so callfar is a plain call, and it has no predef dispatcher so every predef target is called directly with its arguments in registers - the same standing convention CopyDownscaledMonTiles and UpdateHPBar2 already carry their own annotations for; lifetime=permanent while the port is flat-addressed and dispatcher-free}
;
; Out: wCurrentMenuItem = 2, and ZF=0 — pret sets A=2 and then does `and a`, so
;      the closing flags say NON-ZERO. The caller reads that as "a turn was
;      taken" (the same shape BattleMenu_RunWasSelected returns).
; ---------------------------------------------------------------------------
SwitchPlayerMon:
    call RetreatMon                     ; callfar — "<TRAINER>: Good! Come back!"
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    call AnimateRetreatingPlayerMon
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wPlayerMonNumber], al
    ; pret: ld c,a / ld b,FLAG_SET / push bc / ... / pop bc / ... — the same
    ; (bit, action) pair is used for BOTH flag arrays, which is why it is saved.
    mov cl, al                          ; ld c, a  (bit index = party slot)
    mov bh, FLAG_SET                    ; ld b, FLAG_SET
    push ebx                            ; push bc
    push ecx
    mov esi, wPartyGainExpFlags
    call FlagAction                     ; predef FlagActionPredef
    pop ecx                             ; pop bc (restore bit + action)
    pop ebx
    mov esi, wPartyFoughtCurrentEnemyFlags
    call FlagAction                     ; predef FlagActionPredef
    call LoadBattleMonFromParty
    call SendOutMon
    call SaveScreenTilesToBuffer1
    mov al, 2                           ; ld a, $2
    mov [ebp + wCurrentMenuItem], al    ; ld [wCurrentMenuItem], a
    and al, al                          ; and a — A=2, so ZF=0
    ret

; ---------------------------------------------------------------------------
; BattleMenu_RunWasSelected — pret core.asm:BattleMenu_RunWasSelected (2552). Restore
; the clean screen, try to flee; CF=escaped (battle ends), else if the turn was used
; the enemy gets a free move (MainInBattleLoop continues), else re-show the menu.
; ---------------------------------------------------------------------------
BattleMenu_RunWasSelected:
    call LoadScreenTilesFromBuffer1
    mov byte [ebp + wCurrentMenuItem], 3
    mov esi, wBattleMonSpeed            ; ld hl, wBattleMonSpeed
    mov edx, wEnemyMonSpeed             ; ld de, wEnemyMonSpeed
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

; ===========================================================================
; Consolidated from other port files — grind session 8. These are pret
; engine/battle/core.asm labels that had been split into satellite port files;
; the mirror rule puts them here. Bodies are byte-for-byte the code that was in
; those files (moved by line range, not retyped).
; ===========================================================================

; ---------------------------------------------------------------------------
; GetCurrentMove — pret engine/battle/core.asm:6142. Moved here from
; src/engine/battle/get_current_move.asm (grind session 8).
; ---------------------------------------------------------------------------
GetCurrentMove:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .player
    mov edx, wEnemyMoveNum
    mov al, [ebp + wEnemySelectedMove]
    jmp .selected
.player:
    mov edx, wPlayerMoveNum
    ; TestBattle (debug) forces a specific player move
    mov al, [ebp + wStatusFlags7]
    test al, (1 << BIT_TEST_BATTLE)
    mov al, [ebp + wTestBattlePlayerSelectedMove]
    jnz .selected
    mov al, [ebp + wPlayerSelectedMove]
.selected:
    mov [ebp + wNameListIndex], al       ; ld [wNameListIndex], a (name fetch input)
    ; esi = &Moves[(id - 1) * MOVE_LENGTH]  (flat)
    dec al
    movzx ecx, al
    imul ecx, ecx, MOVE_LENGTH
    mov esi, Moves
    add esi, ecx
    ; copy MOVE_LENGTH bytes flat [esi] → WRAM [ebp + edx]
    mov ecx, MOVE_LENGTH
.copy:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .copy
    ret

; ---------------------------------------------------------------------------
; LoadEnemyMonData — pret engine/battle/core.asm:6174. Moved here from
; src/engine/battle/load_enemy_mon_data.asm (grind session 8).
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
LoadEnemyMonData:
    ; link battle → copy from the enemy party structs instead (pret: jp z)
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je  LoadEnemyMonFromParty

    ; wCurSpecies = wEnemyMonSpecies = wEnemyMonSpecies2, then load its header.
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wEnemyMonSpecies], al
    mov [ebp + wCurSpecies], al
    ; ; PROJ(port): the port's WriteMonMoves->GetMonLearnset reads wCurPartySpecies
    ; (not pret's wCurSpecies), so mirror the species there too for the moveset gen.
    mov [ebp + wCurPartySpecies], al
    call GetMonHeader

    ; --- DVs: transformed → original DVs; trainer → fixed; wild → random ---
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << TRANSFORMED
    mov esi, wTransformedEnemyMonOriginalDVs
    mov al, [ebp + esi]                 ; a = orig DV byte 1
    ; FLAG PRESERVATION, and this WAS the defect: `inc esi` writes ZF, so the
    ; `jnz` below read the INCREMENT's result instead of the TRANSFORMED test.
    ; ESI is a WRAM address and never zero, so ZF was always clear, the branch
    ; was ALWAYS taken, and every enemy mon got its DVs from
    ; wTransformedEnemyMonOriginalDVs — zero in an ordinary battle. pret's
    ; `ld a,[hli]` / `ld b,[hl]` are flag-neutral on SM83, which is why the
    ; sequence works there. `lea` is the flag-neutral x86 equivalent.
    lea esi, [esi + 1]
    mov bh, [ebp + esi]                 ; b = orig DV byte 2
    jnz .storeDVs                       ; transformed → keep original DVs
    mov al, [ebp + wIsInBattle]
    cmp al, 2                           ; trainer battle?
    mov al, ATKDEFDV_TRAINER
    mov bh, SPDSPCDV_TRAINER
    jz  .storeDVs                       ; trainer → fixed DVs
    call BattleRandom                   ; wild → random DVs
    mov bh, al
    call BattleRandom
.storeDVs:
    mov esi, wEnemyMonDVs
    mov [ebp + esi], al                 ; DV byte 1
    inc esi
    mov [ebp + esi], bh                 ; DV byte 2

    ; --- level + stats ---
    mov edx, wEnemyMonLevel
    mov al, [ebp + wCurEnemyLevel]
    mov [ebp + edx], al                 ; store level
    inc edx                             ; edx → wEnemyMonMaxHP (stat block dest)
    mov bh, 0                           ; b = 0 (don't consider stat exp)
    mov esi, wEnemyMonHP                ; hl = EV base (pret passes wEnemyMonHP; unused, b=0)
    push esi
    call CalcStats                      ; writes MaxHP/Atk/Def/Spd/Spc to [edx]
    pop esi                             ; esi = wEnemyMonHP (current-HP dest below)

    mov al, [ebp + wIsInBattle]
    cmp al, 2
    jz  .copyHPAndStatusFromPartyData
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << TRANSFORMED
    jnz .copyTypes                      ; transformed → HP already set, skip
    ; wild, not transformed: current HP = max HP, status = 0
    mov al, [ebp + wEnemyMonMaxHP]
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    mov al, [ebp + wEnemyMonMaxHP + 1]
    mov [ebp + esi], al
    inc esi
    inc esi                             ; skip wEnemyMonPartyPos (pret: inc hl)
    mov byte [ebp + esi], 0             ; status = 0
    jmp .copyTypes

.copyHPAndStatusFromPartyData:
    ; trainer mon: copy HP + status from the enemy party struct wWhichPokemon
    mov esi, wEnemyMon1HP
    mov al, [ebp + wWhichPokemon]
    mov ebx, PARTYMON_STRUCT_LENGTH     ; pret: wEnemyMon2 - wEnemyMon1 (enemy party stride)
    call AddNTimes                      ; esi += ebx*al
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonHP], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonHP + 1], al
    inc esi
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wEnemyMonPartyPos], al
    inc esi                             ; pret: inc hl (skip to status byte)
    mov al, [ebp + esi]
    mov [ebp + wEnemyMonStatus], al

.copyTypes:
    ; types (2) + catch rate (1) from the mon header
    mov esi, wMonHTypes
    mov edx, wEnemyMonType
    mov al, [ebp + esi]                 ; type 1
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; type 2
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; catch rate
    inc esi
    mov [ebp + edx], al
    inc edx                             ; edx → wEnemyMonMoves

    mov al, [ebp + wIsInBattle]
    cmp al, 2
    jnz .copyStandardMoves
    ; trainer: copy the 4 moves straight from the enemy party struct
    mov esi, wEnemyMon1Moves
    mov al, [ebp + wWhichPokemon]
    mov ebx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov ebx, NUM_MOVES
    call CopyData                       ; copies to [edx], advances edx by NUM_MOVES
    jmp .loadMovePPs

.copyStandardMoves:
    ; wild: copy the header's 4 default moves, then WriteMonMoves fills level-up moves
    mov esi, wMonHMoves
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; 4th move (no esi advance needed)
    mov [ebp + edx], al
    dec edx
    dec edx
    dec edx                             ; edx → wEnemyMonMoves (base) for the predef
    mov byte [ebp + wLearningMovesFromDayCare], 0
    ; predef WriteMonMoves — stage de = wEnemyMonMoves in wPredefDE (big-endian)
    mov [ebp + wPredefDE], dh
    mov [ebp + wPredefDE + 1], dl
    call WriteMonMoves

.loadMovePPs:
    ; predef LoadMovePPs — hl = wEnemyMonMoves, de = wEnemyMonPP - 1
    mov word [ebp + wPredefHL], (wEnemyMonMoves >> 8) | ((wEnemyMonMoves & 0xFF) << 8)
    mov edx, wEnemyMonPP - 1
    mov [ebp + wPredefDE], dh
    mov [ebp + wPredefDE + 1], dl
    call LoadMovePPs

    ; --- base stats (NUM_STATS) + catch rate + base exp from the header ---
    mov esi, wMonHBaseStats
    mov edx, wEnemyMonBaseStats
    mov bh, NUM_STATS
.copyBaseStatsLoop:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec bh
    jnz .copyBaseStatsLoop
    mov esi, wMonHCatchRate
    mov al, [ebp + esi]                 ; catch rate
    inc esi
    mov [ebp + edx], al
    inc edx
    mov al, [ebp + esi]                 ; base exp
    mov [ebp + edx], al

    ; --- nickname = species name ---
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, wNameBuffer
    mov edx, wEnemyMonNick
    mov ebx, NAME_LENGTH
    call CopyData

    ; --- mark seen in the pokédex ---
    mov al, [ebp + wEnemyMonSpecies2]   ; ld a, [wEnemyMonSpecies2]
    mov [ebp + wPokedexNum], al         ; ld [wPokedexNum], a
    call IndexToPokedex                 ; predef IndexToPokedex
    movzx eax, byte [ebp + wPokedexNum] ; ld a, [wPokedexNum]
    dec eax                             ; dex bit index (0-based)
    mov cl, al
    mov bh, FLAG_SET                    ; FlagAction reads the action in BH
    mov esi, wPokedexSeen
    call FlagAction

    ; --- snapshot unmodified level + stats (1 + NUM_STATS*2 bytes) ---
    mov esi, wEnemyMonLevel
    mov edx, wEnemyMonUnmodifiedLevel
    mov ebx, 1 + NUM_STATS * 2
    call CopyData

    ; --- default stat mods ($7) ---
    mov esi, wEnemyMonStatMods
    mov bh, NUM_STAT_MODS
.statModLoop:
    mov byte [ebp + esi], 7
    inc esi
    dec bh
    jnz .statModLoop
    ret

; ---------------------------------------------------------------------------
; ApplyBurnAndParalysisPenaltiesToPlayer / ...ToEnemy / ApplyBurnAndParalysisPenalties /
; QuarterSpeedDueToParalysis / HalveAttackDueToBurn — pret engine/battle/core.asm:
; 6456-6511. Moved here from
; src/engine/battle/status_penalties.asm (grind session 8).
; The ...ToEnemy -> ApplyBurnAndParalysisPenalties FALLTHROUGH is preserved: the two
; labels stay adjacent and in that order, exactly as in the source file.
; ---------------------------------------------------------------------------
ApplyBurnAndParalysisPenaltiesToPlayer:
    mov al, 1
    jmp ApplyBurnAndParalysisPenalties

ApplyBurnAndParalysisPenaltiesToEnemy:
    xor al, al
ApplyBurnAndParalysisPenalties:
    mov [ebp + hWhoseTurn], al
    call QuarterSpeedDueToParalysis
    jmp HalveAttackDueToBurn

; --- Speed /= 4 if the off-turn mon is paralysed (min 1) ---
QuarterSpeedDueToParalysis:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
; enemy's turn -> quarter the player's speed
    mov al, [ebp + wBattleMonStatus]
    and al, 1 << PAR
    jz .ret
    mov esi, wBattleMonSpeed + 1
    mov al, [ebp + esi]              ; low ([hld])
    dec esi
    mov bl, al
    mov al, [ebp + esi]              ; high
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1                        ; (a:bl) = speed >> 2
    mov [ebp + esi], al              ; store high ([hli])
    inc esi
    or al, bl
    jnz .storePlayerSpeed
    mov bl, 1                        ; minimum 1
.storePlayerSpeed:
    mov [ebp + esi], bl
.ret:
    ret
.playerTurn:
; quarter the enemy's speed
    mov al, [ebp + wEnemyMonStatus]
    and al, 1 << PAR
    jz .ret
    mov esi, wEnemyMonSpeed + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storeEnemySpeed
    mov bl, 1
.storeEnemySpeed:
    mov [ebp + esi], bl
    ret

; --- Attack /= 2 if the off-turn mon is burned (min 1) ---
HalveAttackDueToBurn:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
; enemy's turn -> halve the player's attack
    mov al, [ebp + wBattleMonStatus]
    and al, 1 << BRN
    jz .ret
    mov esi, wBattleMonAttack + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1                        ; (a:bl) = attack >> 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storePlayerAttack
    mov bl, 1
.storePlayerAttack:
    mov [ebp + esi], bl
.ret:
    ret
.playerTurn:
; halve the enemy's attack
    mov al, [ebp + wEnemyMonStatus]
    and al, 1 << BRN
    jz .ret
    mov esi, wEnemyMonAttack + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storeEnemyAttack
    mov bl, 1
.storeEnemyAttack:
    mov [ebp + esi], bl
    ret

; ---------------------------------------------------------------------------
; ApplyBadgeStatBoosts — pret engine/battle/core.asm:6639. Moved here from
; src/engine/battle/badge_boosts.asm (grind session 8).
; Its file-local `wObtainedBadges equ 0xD355` is NOT carried: this file already
; defines it under %ifndef with the identical value.
; ---------------------------------------------------------------------------
ApplyBadgeStatBoosts:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    je .ret                          ; ret z — no badge boosts in link battles
    mov al, [ebp + wObtainedBadges]
    mov bh, al                       ; b = badge bitfield
    mov esi, wBattleMonAttack
    mov bl, 4                        ; c = 4 stats (Atk, Def, Spd, Spc)
.loop:
    shr bh, 1                        ; srl b
    jnc .skipBoost
    call .applyBoostToStat           ; call c
.skipBoost:
    inc esi
    inc esi
    shr bh, 1                        ; srl b (skip odd-position badge bit)
    dec bl
    jnz .loop
.ret:
    ret

; multiply 16-bit big-endian stat at [esi] by 1.125 (stat + stat/8), cap at 999.
; esi unchanged on return.
.applyBoostToStat:
    mov al, [ebp + esi]              ; high byte ([hli])
    inc esi
    mov dh, al                       ; d = high
    mov dl, [ebp + esi]              ; e = low (esi at low byte)
    shr dx, 1                        ; de = stat >> 3 = stat / 8
    shr dx, 1
    shr dx, 1
    mov al, [ebp + esi]              ; low byte
    add al, dl
    mov [ebp + esi], al              ; [hld] -> store low; esi -> high
    dec esi
    mov al, [ebp + esi]              ; high byte
    adc al, dh
    mov [ebp + esi], al              ; [hli] -> store high; esi -> low
    inc esi
    mov al, [ebp + esi]              ; low ([hld])
    dec esi
    sub al, MAX_STAT_VALUE & 0xFF
    mov al, [ebp + esi]              ; high
    sbb al, MAX_STAT_VALUE >> 8      ; sbb (x86), not sbc (SM83)
    jc .boostRet                     ; ret c — stat below cap
    mov al, MAX_STAT_VALUE >> 8
    mov [ebp + esi], al              ; [hli] high = 999 high
    inc esi
    mov al, MAX_STAT_VALUE & 0xFF
    mov [ebp + esi], al              ; [hld] low = 999 low
    dec esi
.boostRet:
    ret

; ---------------------------------------------------------------------------
; PlayMoveAnimation — pret engine/battle/core.asm:6820. Moved here from
; src/engine/battle/animations.asm (grind session 8).
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; PlayMoveAnimation — pret core.asm:PlayMoveAnimation → predef MoveAnimation, the
; ANIMATION=OFF realization. In: AL = animation id (the move number, as core.asm
; passes wPlayerMoveNum/wEnemyMoveNum). All registers preserved.
; NOTE (battle_animations Stage 2b, 2026-08-08): wiring this to the real
; MoveAnimation interpreter was attempted and REVERTED — the never-run interpreter
; crashes when executed (bisected to GetMoveSound's wFrequencyModifier write; repro
; goldencheck battle_faint after wiring). See memory
; regression-battle-anim-interp-runtime-crash before re-wiring.
; ---------------------------------------------------------------------------
PlayMoveAnimation:
    mov [ebp + wAnimationID], al        ; ld [wAnimationID], a
    call Delay3
    call MoveAnimation                  ; predef MoveAnimation (direct in flat model)
    call Func_78e98                     ; callfar Func_78e98
    ret

; ---------------------------------------------------------------------------
; The damage pipeline — pret engine/battle/core.asm, moved here from
; src/engine/battle/core_damage.asm (grind session 8, unit B). That file held
; nothing but these twelve pret core.asm labels, so it is gone. Bodies moved by
; line range, not retyped; the file had zero fallthrough edges.
; ---------------------------------------------------------------------------

; ===========================================================================
; BattleRandom — battle PRNG. In a link battle (Phase 4) this reads from a
; shared seed list; single-player just uses Random. Returns value in AL.
; TODO-HW: link-battle shared PRNG (Phase 4 network HAL).
; ===========================================================================
BattleRandom:
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne Random              ; tail-call Random (returns value in AL)
    ; link path not yet implemented; fall back to Random for determinism
    jmp Random

; ===========================================================================
; GetDamageVarsForPlayerAttack
; Out: BH=attack, BL=defense, DH=base power, DL=level (for CalculateDamage),
;      or returns with move power 0 if the move does no damage.
; ===========================================================================
GetDamageVarsForPlayerAttack:
    xor eax, eax
    mov esi, wDamage           ; init wDamage = 0
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov esi, wPlayerMovePower
    mov al, [ebp + esi]        ; a = move power ([hli])
    inc esi
    test al, al
    mov dh, al                 ; d = move power
    jz .retpower               ; ret z (move power 0)
    mov al, [ebp + esi]        ; a = [wPlayerMoveType]
    cmp al, SPECIAL
    jae .specialAttack
; physical attack
    mov esi, wEnemyMonDefense
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]        ; bc = enemy defense
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << HAS_REFLECT_UP
    jz .physicalAttackCritCheck
    shl bx, 1                  ; double enemy defense (sla c / rl b)
.physicalAttackCritCheck:
    mov esi, wBattleMonAttack
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
; critical hit: reset player attack & enemy defense to base values
    mov bl, STAT_DEFENSE
    call GetEnemyMonStat
    mov al, [ebp + hMultiplicand + 1]  ; hProduct+2
    mov bh, al
    mov al, [ebp + hMultiplicand + 2]  ; hProduct+3
    mov bl, al
    push ebx
    mov esi, wPartyMon1Attack
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    pop ebx
    jmp .scaleStats
.specialAttack:
    mov esi, wEnemyMonSpecial
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]        ; bc = enemy special
    mov al, [ebp + wEnemyBattleStatus3]
    test al, 1 << HAS_LIGHT_SCREEN_UP
    jz .specialAttackCritCheck
    shl bx, 1                  ; double enemy special
.specialAttackCritCheck:
    mov esi, wBattleMonSpecial
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
    mov bl, STAT_SPECIAL
    call GetEnemyMonStat
    mov al, [ebp + hMultiplicand + 1]
    mov bh, al
    mov al, [ebp + hMultiplicand + 2]
    mov bl, al
    push ebx
    mov esi, wPartyMon1Special
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    pop ebx
.scaleStats:
; esi = pointer to player's 16-bit offensive stat (big-endian); bc = enemy def
    movzx eax, byte [ebp + esi]   ; a = high byte ([hli])
    inc esi
    movzx ecx, byte [ebp + esi]   ; c-scratch = low byte ([hl])
    mov esi, eax
    shl esi, 8
    or esi, ecx                   ; hl = player offensive stat
    or al, bh                     ; (stat high | enemy def high); sets ZF
    jz .next
; scale: bc /= 4, hl /= 4
    shr bx, 1
    shr bx, 1
    shr esi, 1
    shr esi, 1
    test si, si                   ; player offensive stat 0?
    jnz .next
    inc esi                       ; bump to 1
.next:
    mov eax, esi
    mov bh, al                    ; b = player offensive stat (low byte of hl)
    mov al, [ebp + wBattleMonLevel]
    mov dl, al                    ; e = level
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .done
    shl dl, 1                     ; double level on crit
.done:
    mov al, 1
    test al, al                   ; nz, nc
    ret
.retpower:
    ret

; ===========================================================================
; GetDamageVarsForEnemyAttack — mirror of the player version (attacker = enemy)
; ===========================================================================
GetDamageVarsForEnemyAttack:
    mov esi, wDamage
    xor eax, eax
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov esi, wEnemyMovePower
    mov al, [ebp + esi]
    inc esi
    mov dh, al                    ; d = move power
    test al, al
    jz .retpower
    mov al, [ebp + esi]           ; [wEnemyMoveType]
    cmp al, SPECIAL
    jae .specialAttack
; physical
    mov esi, wBattleMonDefense
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]           ; bc = player defense
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << HAS_REFLECT_UP
    jz .physicalAttackCritCheck
    shl bx, 1
.physicalAttackCritCheck:
    mov esi, wEnemyMonAttack
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
; crit: player defense & enemy attack to base
    mov esi, wPartyMon1Defense
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    push ebx
    mov bl, STAT_ATTACK
    call GetEnemyMonStat
    mov esi, hMultiplicand + 1    ; hProduct+2 (enemy attack base, big-endian)
    pop ebx
    jmp .scaleStats
.specialAttack:
    mov esi, wBattleMonSpecial
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    mov al, [ebp + wPlayerBattleStatus3]
    test al, 1 << HAS_LIGHT_SCREEN_UP
    jz .specialAttackCritCheck
    shl bx, 1
.specialAttackCritCheck:
    mov esi, wEnemyMonSpecial
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .scaleStats
    mov esi, wPartyMon1Special
    mov al, [ebp + wPlayerMonNumber]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    inc esi
    mov bh, al
    mov bl, [ebp + esi]
    push ebx
    mov bl, STAT_SPECIAL
    call GetEnemyMonStat
    mov esi, hMultiplicand + 1
    pop ebx
.scaleStats:
    movzx eax, byte [ebp + esi]
    inc esi
    movzx ecx, byte [ebp + esi]
    mov esi, eax
    shl esi, 8
    or esi, ecx                   ; hl = enemy offensive stat
    or al, bh
    jz .next
    shr bx, 1
    shr bx, 1
    shr esi, 1
    shr esi, 1
    test si, si
    jnz .next
    inc esi
.next:
    mov eax, esi
    mov bh, al
    mov al, [ebp + wEnemyMonLevel]
    mov dl, al
    mov al, [ebp + wCriticalHitOrOHKO]
    test al, al
    jz .done
    shl dl, 1
.done:
    mov al, 1
    test al, al
    ret
.retpower:
    ret

; ===========================================================================
; GetEnemyMonStat — get base (stat-stage-ignoring) stat BL of the enemy mon.
; In:  BL = stat index (STAT_*). Out: big-endian result at hMultiplicand+1/+2.
; Preserves DX (d/e).
; ===========================================================================
GetEnemyMonStat:
    push edx
    push ebx
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .notLinkBattle
; link battle: read precomputed enemy party stats. TODO-HW: link (Phase 4).
    mov esi, wEnemyMon1Stats
    dec bl
    shl bl, 1
    mov bh, 0
    movzx ecx, bx
    add esi, ecx
    mov al, [ebp + wEnemyMonPartyPos]
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 1], al
    inc esi
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 2], al
    pop ebx
    pop edx
    ret
.notLinkBattle:
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wCurEnemyLevel], al
    mov al, [ebp + wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov esi, wEnemyMonDVs
    mov edi, wLoadedMonSpeedExp
    mov al, [ebp + esi]           ; DV byte 0 ([hli])
    mov [ebp + edi], al
    inc esi
    inc edi
    mov al, [ebp + esi]           ; DV byte 1
    mov [ebp + edi], al
    pop ebx                       ; restore bl = stat index
    mov bh, 0                     ; b = 0 (don't consider stat exp)
    mov esi, wLoadedMonSpeedExp - 0x0B  ; base ptr so CalcStat finds DVs here
    call CalcStat
    pop edx
    ret

; ===========================================================================
; CalculateDamage
; In: BH=attack, BL=defense, DH=base power, DL=level.
; Out: wDamage (big-endian) updated; returns nz,nc (a=1) unless 0-power early-out.
; ===========================================================================
CalculateDamage:
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMoveEffect]
    jz .effect
    mov al, [ebp + wEnemyMoveEffect]
.effect:
; EXPLODE_EFFECT halves defense (min 1)
    cmp al, EXPLODE_EFFECT
    jne .ok
    shr bl, 1
    jnz .ok
    inc bl
.ok:
    cmp al, TWO_TO_FIVE_ATTACKS_EFFECT
    je .skipbp
    cmp al, EFFECT_1E
    je .skipbp
    cmp al, OHKO_EFFECT
    je JumpToOHKOMoveEffect
    test dh, dh                   ; base power 0?
    jnz .skipbp
    ret
.skipbp:
; zero hDividend[0..2]
    xor eax, eax
    mov esi, hDividend
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al           ; esi = hDividend+2
; level * 2 (with carry into hDividend+2)
    mov al, dl
    add al, al
    jnc .nc
    push eax
    mov byte [ebp + esi], 1       ; ld [hl],1 (high byte)
    pop eax
.nc:
    inc esi                       ; hDividend+3
    mov [ebp + esi], al           ; store 2*level low byte; esi -> hDividend+4 (=hDivisor)
    inc esi
; divide by 5
    mov byte [ebp + esi], 5       ; ld [hld],a (hDivisor=5)
    dec esi                       ; -> hDividend+3
    push ebx
    mov bh, 4
    call Divide
    pop ebx
; add 2 (inc [hl] twice at hDividend+3)
    inc byte [ebp + esi]
    inc byte [ebp + esi]
    inc esi                       ; -> hDivisor (multiplier slot)
; multiply by base power
    mov [ebp + esi], dh
    call Multiply
; multiply by attack stat
    mov [ebp + esi], bh
    call Multiply
; divide by defense stat
    mov [ebp + esi], bl
    mov bh, 4
    call Divide
; divide by 50
    mov byte [ebp + esi], 50
    mov bh, 4
    call Divide
; add wDamage's high byte; cap at 997; add MIN_NEUTRAL_DAMAGE
    mov esi, wDamage
    mov bh, [ebp + esi]           ; b = [wDamage]
    mov al, [ebp + hQuotient + 3]
    add al, bh
    mov [ebp + hQuotient + 3], al
    jnc .dont_cap_1
    mov al, [ebp + hQuotient + 2]
    inc al
    mov [ebp + hQuotient + 2], al
    test al, al
    jz .cap
.dont_cap_1:
    mov al, [ebp + hQuotient]
    mov bh, al
    mov al, [ebp + hQuotient + 1]
    or al, al
    jnz .cap
    mov al, [ebp + hQuotient + 2]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8
    jb .dont_cap_2
    cmp al, ((MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8) + 1
    jae .cap
    mov al, [ebp + hQuotient + 3]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) & 0xFF
    jae .cap
.dont_cap_2:
    inc esi                       ; wDamage+1
    mov al, [ebp + hQuotient + 3]
    mov bh, [ebp + esi]
    add al, bh
    mov [ebp + esi], al
    dec esi                       ; wDamage
    mov al, [ebp + hQuotient + 2]
    mov bh, [ebp + esi]
    adc al, bh
    mov [ebp + esi], al
    jc .cap
    mov al, [ebp + esi]
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8
    jb .dont_cap_3
    cmp al, ((MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) >> 8) + 1
    jae .cap
    inc esi
    mov al, [ebp + esi]
    dec esi
    cmp al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE + 1) & 0xFF
    jb .dont_cap_3
.cap:
    mov al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE) >> 8
    mov [ebp + esi], al           ; ld [hli],a
    inc esi
    mov al, (MAX_NEUTRAL_DAMAGE - MIN_NEUTRAL_DAMAGE) & 0xFF
    mov [ebp + esi], al
    dec esi                       ; ld [hld],a -> back to wDamage
.dont_cap_3:
    inc esi                       ; wDamage+1
    mov al, [ebp + esi]
    add al, MIN_NEUTRAL_DAMAGE
    mov [ebp + esi], al
    dec esi                       ; -> wDamage
    jnc .dont_floor
    inc byte [ebp + esi]
.dont_floor:
    mov al, 1
    test al, al
    ret

; ===========================================================================
; JumpToOHKOMoveEffect — OHKO moves compute damage via their effect handler.
; ===========================================================================
JumpToOHKOMoveEffect:
    call JumpMoveEffect
    mov al, [ebp + wMoveMissed]
    dec al
    ret

; ===========================================================================
; CriticalHitTest — sets wCriticalHitOrOHKO if this attack crits.
; ===========================================================================
CriticalHitTest:
    xor eax, eax
    mov [ebp + wCriticalHitOrOHKO], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wEnemyMonSpecies]
    jnz .handleEnemy
    mov al, [ebp + wBattleMonSpecies]
.handleEnemy:
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov al, [ebp + wMonHBaseSpeed]
    mov bh, al
    shr bh, 1                     ; b = base speed / 2
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov esi, wPlayerMovePower
    mov edx, wPlayerBattleStatus2
    jz .calcCriticalHitProbability
    mov esi, wEnemyMovePower
    mov edx, wEnemyBattleStatus2
.calcCriticalHitProbability:
    mov al, [ebp + esi]           ; base power ([hld])
    dec esi
    test al, al
    jz .ret0                      ; ret z (0 power)
    dec esi
    mov bl, [ebp + esi]           ; c = move id
    mov al, [ebp + edx]
    test al, 1 << GETTING_PUMPED  ; focus energy?
    ; BUG{class=data-model; pret=engine/battle/core.asm:CriticalHitTest; behavior=Focus Energy and Dire Hit quarter the critical-hit threshold instead of quadrupling it; evidence=pret source CriticalHitTest plus docs/references/yellow_glitches.md battle-system Critical Hit Ratio Error; lifetime=permanent Gen-1 behavior}
    ; "Critical Hit Ratio Error" — Focus Energy (and Dire Hit)
    ; are intended to quadruple the crit chance but a bit-shift error makes
    ; .focusEnergyUsed shr (halve) where the intent was to skip the later shl;
    ; combined with the normal-move shr below this quarters the crit ratio for
    ; non-high-crit moves instead of quadrupling it. Gen-1 behavior, preserved
    ; verbatim. pret ref: engine/battle/core.asm:CriticalHitTest,
    ; docs/references/yellow_glitches.md#battle-system (Critical Hit Ratio Error)
    jnz .focusEnergyUsed
    shl bh, 1                     ; base speed/2 * 2
    jnc .noFocusEnergyUsed
    mov bh, 0xFF                  ; cap at 255
    jmp .noFocusEnergyUsed
.focusEnergyUsed:
    shr bh, 1
.noFocusEnergyUsed:
    mov esi, HighCriticalMoves
.loop:
    mov al, [esi]                 ; flat program-image table -> [esi], NOT [ebp+esi]
    inc esi
    cmp al, bl
    je .highCritical
    inc al                        ; FF terminates ($FF+1=0 -> ZF)
    jnz .loop
    shr bh, 1                     ; normal move: /2
    jmp .skipHighCritical
.highCritical:
    shl bh, 1
    jnc .noCarry
    mov bh, 0xFF
.noCarry:
    shl bh, 1
    jnc .skipHighCritical
    mov bh, 0xFF
.skipHighCritical:
    call BattleRandom
    rol al, 1
    rol al, 1
    rol al, 1
    cmp al, bh
    jae .ret0                     ; ret nc (no crit)
    mov al, 1
    mov [ebp + wCriticalHitOrOHKO], al
    ret
.ret0:
    ret

; ===========================================================================
; AdjustDamageForMoveType — apply STAB (1.5x) and type effectiveness to wDamage.
; ===========================================================================
AdjustDamageForMoveType:
; player-turn values: attacker = player, defender = enemy
    mov al, [ebp + wBattleMonType1]
    mov bh, al                    ; b = attacker type 1
    mov al, [ebp + wBattleMonType2]
    mov bl, al                    ; c = attacker type 2
    mov al, [ebp + wEnemyMonType1]
    mov dh, al                    ; d = defender type 1
    mov al, [ebp + wEnemyMonType2]
    mov dl, al                    ; e = defender type 2
    mov al, [ebp + wPlayerMoveType]
    mov [ebp + wMoveType], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .next
; enemy-turn values: attacker = enemy, defender = player
    mov al, [ebp + wEnemyMonType1]
    mov bh, al
    mov al, [ebp + wEnemyMonType2]
    mov bl, al
    mov al, [ebp + wBattleMonType1]
    mov dh, al
    mov al, [ebp + wBattleMonType2]
    mov dl, al
    mov al, [ebp + wEnemyMoveType]
    mov [ebp + wMoveType], al
.next:
    mov al, [ebp + wMoveType]
    cmp al, bh
    je .stab
    cmp al, bl
    je .stab
    jmp .skipStab
.stab:
; hl = damage (big-endian); hl = floor(1.5 * damage)
    movzx eax, byte [ebp + wDamage]   ; high
    shl eax, 8
    mov al, [ebp + wDamage + 1]        ; low
    mov esi, eax                       ; hl = damage
    mov ebx, eax
    shr bx, 1                          ; bc = damage / 2
    movzx eax, bx
    add esi, eax                       ; hl = 1.5 * damage
    mov eax, esi
    shr eax, 8
    mov [ebp + wDamage], al            ; high
    mov eax, esi
    mov [ebp + wDamage + 1], al        ; low
    mov al, [ebp + wDamageMultipliers]
    or al, 1 << BIT_STAB_DAMAGE
    mov [ebp + wDamageMultipliers], al
.skipStab:
    mov al, [ebp + wMoveType]
    mov bh, al                         ; b = move type
    mov esi, TypeEffects               ; flat table -> [esi]
.loop:
    mov al, [esi]                      ; attacking type ([hli])
    inc esi
    cmp al, 0xFF
    je .done
    cmp al, bh
    jne .nextTypePair
    mov al, [esi]                      ; defending type ([hl])
    cmp al, dh
    je .match
    cmp al, dl
    je .match
    jmp .nextTypePair
.match:
    push esi
    push ebx
    inc esi                            ; -> effectiveness factor
    mov al, [ebp + wDamageMultipliers]
    and al, 1 << BIT_STAB_DAMAGE
    mov bh, al
    mov al, [esi]                      ; a = damage multiplier (factor*10)
    mov [ebp + hMultiplier], al
    add al, bh
    mov [ebp + wDamageMultipliers], al
    xor al, al
    mov [ebp + hMultiplicand], al
    mov al, [ebp + wDamage]            ; ld hl,wDamage; [hli]
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + wDamage + 1]        ; [hld]
    mov [ebp + hMultiplicand + 2], al
    call Multiply
    mov byte [ebp + hDivisor], 10
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 2]
    mov [ebp + wDamage], al            ; ld [hli],a
    mov bh, al
    mov al, [ebp + hQuotient + 3]
    mov [ebp + wDamage + 1], al        ; ld [hl],a
    ; BUG{class=data-model; pret=engine/battle/core.asm:CalculateDamage; behavior=damage can remain zero after truncation instead of being raised to the minimum one; evidence=pret source CalculateDamage zero-damage branch plus docs/references/yellow_glitches.md battle-system 0 Damage Glitch; lifetime=permanent Gen-1 behavior}
    ; "0 Damage Glitch" — pret's own comment: "if damage is 0,
    ; make the move miss; this only occurs if a move that would do 2 or 3
    ; damage is 0.25x effective against the target." A real hit that rounds
    ; to 0 damage against a dual-type resist is logged as a miss instead of a
    ; 0-damage hit. Gen-1 behavior, preserved verbatim. pret ref: engine/battle/
    ; core.asm:AdjustDamageForMoveType, docs/references/yellow_glitches.md
    ; #battle-system (0 Damage Glitch)
    or al, bh                          ; damage 0?
    jnz .skipTypeImmunity
    inc al
    mov [ebp + wMoveMissed], al
.skipTypeImmunity:
    pop ebx
    pop esi
.nextTypePair:
    inc esi
    inc esi
    jmp .loop
.done:
    ret

; ===========================================================================
; MoveHitTest — accuracy / mist / substitute / invulnerability checks.
; Sets wMoveMissed (1 = missed) and zeroes wDamage on miss.
; ===========================================================================
MoveHitTest:
    mov esi, wEnemyBattleStatus1       ; hl
    mov edx, wPlayerMoveEffect          ; de
    mov ebx, wEnemyMonStatus            ; bc
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .dreamEaterCheck
    mov esi, wPlayerBattleStatus1
    mov edx, wEnemyMoveEffect
    mov ebx, wBattleMonStatus
.dreamEaterCheck:
    mov al, [ebp + edx]
    cmp al, DREAM_EATER_EFFECT
    jne .swiftCheck
    mov al, [ebp + ebx]
    and al, SLP_MASK
    jz .moveMissed
.swiftCheck:
    mov al, [ebp + edx]
    cmp al, SWIFT_EFFECT
    je .hit                            ; Swift never misses
    call CheckTargetSubstitute         ; sets ZF; overwrites a
    jz .checkForDigOrFlyStatus
    cmp al, DRAIN_HP_EFFECT
    je .moveMissed
    cmp al, DREAM_EATER_EFFECT
    je .moveMissed
.checkForDigOrFlyStatus:
    test byte [ebp + esi], 1 << INVULNERABLE
    jnz .moveMissed
    mov al, [ebp + hWhoseTurn]
    test al, al
    jnz .enemyTurn
; player turn: enemy mist check
    mov al, [ebp + wPlayerMoveEffect]
    cmp al, ATTACK_DOWN1_EFFECT
    jb .skipEnemyMistCheck
    cmp al, HAZE_EFFECT + 1
    jb .enemyMistCheck
    cmp al, ATTACK_DOWN2_EFFECT
    jb .skipEnemyMistCheck
    cmp al, REFLECT_EFFECT + 1
    jb .enemyMistCheck
    jmp .skipEnemyMistCheck
.enemyMistCheck:
    mov al, [ebp + wEnemyBattleStatus2]
    test al, 1 << PROTECTED_BY_MIST
    jnz .moveMissed
.skipEnemyMistCheck:
    mov al, [ebp + wPlayerBattleStatus2]
    test al, 1 << USING_X_ACCURACY
    jnz .hit
    jmp .calcHitChance
.enemyTurn:
    mov al, [ebp + wEnemyMoveEffect]
    cmp al, ATTACK_DOWN1_EFFECT
    jb .skipPlayerMistCheck
    cmp al, HAZE_EFFECT + 1
    jb .playerMistCheck
    cmp al, ATTACK_DOWN2_EFFECT
    jb .skipPlayerMistCheck
    cmp al, REFLECT_EFFECT + 1
    jb .playerMistCheck
    jmp .skipPlayerMistCheck
.playerMistCheck:
    mov al, [ebp + wPlayerBattleStatus2]
    test al, 1 << PROTECTED_BY_MIST
    jnz .moveMissed
.skipPlayerMistCheck:
    mov al, [ebp + wEnemyBattleStatus2]
    test al, 1 << USING_X_ACCURACY
    jnz .hit
.calcHitChance:
    call CalcHitChance
    mov al, [ebp + wPlayerMoveAccuracy]
    mov bh, al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .doAccuracyCheck
    mov al, [ebp + wEnemyMoveAccuracy]
    mov bh, al
.doAccuracyCheck:
    ; BUG{class=data-model; pret=engine/battle/core.asm:MoveHitTest; behavior=an accuracy threshold of 255 still misses when BattleRandom returns 255; evidence=pret source MoveHitTest plus docs/references/yellow_glitches.md battle-system 1 in 256 Miss Glitch; lifetime=permanent Gen-1 behavior}
    ; "1/256 Miss Glitch" — the unsigned `jae` below misses
    ; whenever the roll equals the accuracy threshold, so even a nominal 100%
    ; move (accuracy capped at 255) still misses on roll=255 (1/256 chance).
    ; Gen-1 behavior, preserved verbatim. pret ref: engine/battle/core.asm:
    ; MoveHitTest (jr nc, .moveMissed / cp b), docs/references/yellow_glitches.md
    ; #battle-system (1/256 Miss Glitch)
    call BattleRandom
    cmp al, bh
    jae .moveMissed
.hit:
    ret
.moveMissed:
    xor al, al
    mov [ebp + wDamage], al
    mov [ebp + wDamage + 1], al
    inc al
    mov [ebp + wMoveMissed], al
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
    and byte [ebp + wEnemyBattleStatus1], ~(1 << USING_TRAPPING_MOVE)
    ret
.playerTurn:
    and byte [ebp + wPlayerBattleStatus1], ~(1 << USING_TRAPPING_MOVE)
    ret

; ===========================================================================
; CalcHitChance — scale move accuracy by attacker accuracy & target evasion mods.
; Result stored into wPlayerMoveAccuracy / wEnemyMoveAccuracy.
; ===========================================================================
CalcHitChance:
    mov esi, wPlayerMoveAccuracy
    mov al, [ebp + hWhoseTurn]
    test al, al
    mov al, [ebp + wPlayerMonAccuracyMod]
    mov bh, al
    mov al, [ebp + wEnemyMonEvasionMod]
    mov bl, al
    jz .next
    mov esi, wEnemyMoveAccuracy
    mov al, [ebp + wEnemyMonAccuracyMod]
    mov bh, al
    mov al, [ebp + wPlayerMonEvasionMod]
    mov bl, al
.next:
    mov al, 0x0E
    sub al, bl
    mov bl, al                         ; c = 14 - evasion mod
    xor al, al
    mov [ebp + hMultiplicand], al
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + esi]
    mov [ebp + hMultiplicand + 2], al  ; multiplicand = move accuracy
    push esi
    mov dh, 2                          ; d = 2 iterations
.loop:
    push ebx
    mov esi, StatModifierRatios        ; flat table
    dec bh
    shl bh, 1
    mov bl, bh
    mov bh, 0
    movzx ecx, bx
    add esi, ecx                       ; hl = ratio entry
    pop ebx
    mov al, [esi]                      ; numerator ([hli])
    inc esi
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, [esi]                      ; denominator ([hl])
    mov [ebp + hDivisor], al
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 3]
    mov bh, al
    mov al, [ebp + hQuotient + 2]
    or al, bh
    jnz .nextCalculation
; clamp result to at least 1
    mov byte [ebp + hQuotient + 2], 0
    mov byte [ebp + hQuotient + 3], 1
.nextCalculation:
    mov bh, bl                         ; b = c (next stage index)
    dec dh
    jnz .loop
    mov al, [ebp + hQuotient + 2]
    test al, al
    mov al, [ebp + hQuotient + 3]
    jz .storeAccuracy
    mov al, 0xFF                       ; > 0xFF -> cap at 255
.storeAccuracy:
    pop esi
    mov [ebp + esi], al
    ret

; ===========================================================================
; RandomizeDamage — multiply wDamage by a random ~85%..100% factor.
; ===========================================================================
RandomizeDamage:
    mov esi, wDamage
    mov al, [ebp + esi]                ; high byte ([hli])
    inc esi
    test al, al
    jnz .greaterThanOne
    mov al, [ebp + esi]                ; low byte
    cmp al, 2
    jb .ret                            ; ret c (damage 0 or 1)
.greaterThanOne:
    xor al, al
    mov [ebp + hMultiplicand], al
    dec esi                            ; -> wDamage
    mov al, [ebp + esi]                ; high ([hli])
    inc esi
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + esi]                ; low ([hl])
    mov [ebp + hMultiplicand + 2], al
.loop:
    call BattleRandom
    ror al, 1
    cmp al, (85 * 0xFF / 100) + 1      ; 85 percent + 1 = 217
    jb .loop
    mov [ebp + hMultiplier], al
    call Multiply
    mov byte [ebp + hDivisor], 255
    mov bh, 4
    call Divide
    mov al, [ebp + hQuotient + 2]
    mov esi, wDamage
    mov [ebp + esi], al                ; [hli]
    inc esi
    mov al, [ebp + hQuotient + 3]
    mov [ebp + esi], al                ; [hl]
.ret:
    ret

; ===========================================================================
; AIGetTypeEffectiveness — single-type effectiveness of the enemy move vs the
; player mon, stored in wTypeEffectiveness (scaled by 10). Does NOT handle dual-
; type stacking (4x / cancel). Used by trainer AI move selection.
;
; BUG{class=data-model; pret=engine/battle/core.asm:AIGetTypeEffectiveness; behavior=wTypeEffectiveness initializes to hexadecimal $10 rather than decimal 10; evidence=pret source AIGetTypeEffectiveness immediate value; lifetime=permanent Gen-1 behavior}
; The original initializes wTypeEffectiveness to $10 (16) rather
; than EFFECTIVE (10). Preserved at BUG_FIX_LEVEL 0; pret ref core.asm:5371.
; ===========================================================================

AIGetTypeEffectiveness:
    mov al, [ebp + wEnemyMoveType]
    mov dh, al                       ; d = enemy move type
    mov esi, wBattleMonType1
    mov bh, [ebp + esi]              ; b = player type 1
    inc esi
    mov bl, [ebp + esi]              ; c = player type 2
    mov byte [ebp + wTypeEffectiveness], 0x10   ; faithful original; should be decimal 10
    mov esi, TypeEffects             ; flat table -> [esi]
.loop:
    mov al, [esi]
    inc esi
    cmp al, 0xFF
    je .ret
    cmp al, dh
    jne .nextTypePair1
    mov al, [esi]
    inc esi
    cmp al, bh
    je .done
    cmp al, bl
    je .done
    jmp .nextTypePair2
.nextTypePair1:
    inc esi
.nextTypePair2:
    inc esi
    jmp .loop
.done:
    mov al, [ebp + wTrainerClass]
    cmp al, LORELEI
    jne .ok
    mov al, [ebp + wEnemyMonSpecies]
    cmp al, DEWGONG
    jne .ok
    call BattleRandom
    cmp al, 0x66                     ; 40% chance to ignore effectiveness
    jb .ret
.ok:
    mov al, [esi]                    ; effectiveness factor
    mov [ebp + wTypeEffectiveness], al
.ret:
    ret

; ---------------------------------------------------------------------------
; The faint / send-out / residual-damage cluster — pret engine/battle/core.asm,
; moved here from seven satellite port files (grind session 8, unit C). Each of
; those files held nothing but pret core.asm labels, so all seven are gone.
; Bodies moved by line range, not retyped.
; ---------------------------------------------------------------------------

; --- was src/engine/battle/faint_switch.asm ---

; ===========================================================================
; HasMonFainted — pret core.asm:HasMonFainted. Tests whether the mon at
; wWhichPokemon has fainted; returns ZF=1 if fainted (HP == 0).
; (pret also prints NoWillText when wFirstMonsNotOutYet==0; that text path is a
; TODO — the ZF contract, which the switch loop reads, is exact.)
; ===========================================================================
HasMonFainted:
    mov esi, wPartyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                      ; esi -> this mon's HP word
    mov al, [ebp + esi]
    or  al, [ebp + esi + 1]             ; ZF=1 → fainted
    ret

; ===========================================================================
; RemoveFaintedPlayerMon — pret core.asm:1015-1090. Clears the fainted mon's
; gain-exp flag, resets the enemy's multi-attack + accumulated Bide damage,
; sets wBattleResult=loss, and (only when called from HandlePlayerMonFainted,
; i.e. wInHandlePlayerMonFainted==1) plays the cry + "<mon> fainted!" message.
; Deferred (audio HAL): the low-health alarm and the cry (PlayCry, and the Yellow
; starter-Pikachu arm that replaces it).
;
; ModifyPikachuHappiness was ALSO listed here as deferred, and that was wrong —
; it is pure WRAM arithmetic with no HAL boundary anywhere in it. Restored
; 2026-08-12 (battle plan 4a); see the block at .regularFaint.
; ===========================================================================
RemoveFaintedPlayerMon:
    ; clear gain-exp flag for the fainted mon (pret: predef FlagActionPredef, FLAG_RESET)
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_RESET
    call FlagAction
    ; res ATTACKING_MULTIPLE_TIMES on the enemy
    and byte [ebp + wEnemyBattleStatus1], (~(1 << ATTACKING_MULTIPLE_TIMES)) & 0xFF
    ; pret core.asm:1023-1029, RESTORED 2026-08-21. The "TODO-HW: low-health alarm
    ; (audio HAL, Phase 3)" that stood here was stale in the same way EndOfBattle's
    ; WaitForSoundToFinish note was (retired 2026-08-14): the audio HAL is real and
    ; WaitForSoundToFinish is translated and already called from MoveAnimation.
    ;
    ; SILENCE THE ALARM BEFORE THE FAINT. Without the store, wLowHealthAlarm keeps
    ; its armed value across the faint and the beeping outlives the mon that caused
    ; it; without the wait, the cry/faint audio steps on a still-sounding alarm.
    ; The wait is GUARDED on the alarm actually sounding — it is pret's guard, and
    ; it is what keeps a blocking call off the faint path in the common case.
    mov al, [ebp + wLowHealthAlarm]
    test al, (1 << BIT_LOW_HEALTH_ALARM)     ; pret: bit BIT_LOW_HEALTH_ALARM, a
    jz .skipWaitForSound                     ; pret: jr z, .skipWaitForSound
    mov byte [ebp + wLowHealthAlarm], DISABLE_LOW_HEALTH_ALARM
    call WaitForSoundToFinish
    xor al, al                               ; pret: xor a
.skipWaitForSound:
    ; pret's comment: "a is 0, so this zeroes the enemy's accumulated damage." On the
    ; NOT-taken path that holds only because wLowHealthAlarm is 0 whenever the alarm
    ; bit is clear — pret relies on it and so does this, deliberately, rather than
    ; inserting an `xor` pret does not have. The port previously zeroed AL
    ; unconditionally here, which was the same value by a different route.
    ; a==0 here → zero the enemy's accumulated Bide damage (both bytes) + status
    mov [ebp + wEnemyBideAccumulatedDamage + 0], al
    mov [ebp + wEnemyBideAccumulatedDamage + 1], al
    mov [ebp + wBattleMonStatus], al
    call ReadPlayerMonCurHPAndStatus
    ; pret `hlcoord 1, 10 / decoord 1, 11 / call SlideDownFaintedMonPic`
    mov esi, BCOORD(1, 10)               ; PROJ — pret hlcoord 1, 10
    mov edx, BCOORD(1, 11)               ; PROJ — pret decoord 1, 11
    call SlideDownFaintedMonPic
    mov byte [ebp + wBattleResult], 1    ; player lost (overwritten on later continue)
    ; When both mons faint and the enemy faint was detected first, don't print /
    ; cry (pret: called by HandleEnemyMonFainted with wInHandlePlayerMonFainted==0).
    mov al, [ebp + wInHandlePlayerMonFainted]
    and al, al
    jz .ret
    ; pret core.asm:1054 — wWhichPokemon selects the mon IsThisPartyMonStarterPikachu
    ; tests, and BOTH the cry arm below and the happiness block further down read it.
    ; pret stores it twice (1054 and 1067) because PrintText sits between; the second
    ; store is the one the happiness block depends on, so neither is redundant.
    mov al, [ebp + wPlayerMonNumber]
    mov [ebp + wWhichPokemon], al
    ; pret core.asm:1056-1063, RESTORED 2026-08-21 — the fainting mon's cry. It was
    ; dropped as "TODO-HW: PlayCry (audio HAL)"; the audio HAL is real, PlayCry is
    ; translated, and both arms' callees are live (IsThisPartyMonStarterPikachu is
    ; translated, PlayPikachuSoundClip is the real digitized-clip player).
    ; The starter Pikachu gets its digitized clip instead of a synthesized cry —
    ; `ldpikacry e, PikachuCry4` is clip INDEX 3, since PikachuCryN is index N-1
    ; (the pointer table is strictly ordinal across all 42 entries; same lowering
    ; the scripts already use).
    call IsThisPartyMonStarterPikachu    ; callfar; CF=1 iff it is our Pikachu
    jnc .notPlayerPikachu                ; pret: jr nc, .notPlayerPikachu
    mov dl, 3                            ; ldpikacry e, PikachuCry4 (0-based index)
    call PlayPikachuSoundClip            ; callfar PlayPikachuSoundClip
    jmp .printFaintText                  ; pret: jr .printText
.notPlayerPikachu:
    mov al, [ebp + wBattleMonSpecies]    ; ld a, [wBattleMonSpecies]
    call PlayCry
.printFaintText:
    mov eax, PlayerMonFaintedText
    call PrintBattleText                 ; "<nick> fainted!"
    ; pret core.asm:1067-1083 — the fainting penalty. Two reason codes, chosen by
    ; how badly outlevelled the player was.
    mov al, [ebp + wPlayerMonNumber]
    mov [ebp + wWhichPokemon], al
    mov al, [ebp + wBattleMonLevel]
    mov bh, al                           ; ld b, a
    mov al, [ebp + wEnemyMonLevel]
    sub al, bh                           ; enemylevel - playerlevel; CF = we were stronger
    jb .regularFaint                     ; jr c — deduct happiness regularly
    cmp al, 30                           ; enemy 30+ levels above us?
    jae .carelessTrainer                 ; jr nc — punish the careless trainer
.regularFaint:
    mov dh, PIKAHAPPY_FAINTED            ; farcall_ModifyPikachuHappiness: ld d, kind
    call ModifyPikachuHappiness
    ret
.carelessTrainer:
    mov dh, PIKAHAPPY_CARELESSTRAINER    ; farcall_ModifyPikachuHappiness: ld d, kind
    call ModifyPikachuHappiness
    ret
.ret:
    ret

; ===========================================================================
; DoUseNextMonDialogue — pret core.asm:1091-1117. Trainer battles: no prompt,
; return CF=0. Wild battles: ask "Use next Pokémon?" — YES falls through to the
; forced switch, NO tries to run. Returns CF=1 if the player ran.
;
; RESTORED 2026-08-12 (battle plan 2b). The body auto-answered YES under a
; `TODO(faithful)` and faithdiff read 5 pret / 2 port, with the whole Yes/No box
; and the run arm missing.
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:DoUseNextMonDialogue; behavior=the two-option box is placed at BCOORD(13, 9) rather than pret's raw hlcoord 13 9; evidence=every in-battle screen in this port is drawn through the BCOORD battle-frame projection in include/coords.inc, the same offset PartyMenuOrRockOrRun's deselect wipe uses; lifetime=permanent while the port renders a 40x25 canvas}
;
; Out: CF=1 iff the player ran (TryRunningFromBattle's contract), CF=0 otherwise.
; ===========================================================================
DoUseNextMonDialogue:
    call PrintEmptyString
    call SaveScreenTilesToBuffer1
    mov al, [ebp + wIsInBattle]
    and al, al
    dec al                               ; wIsInBattle==2 (trainer) → nz
    jnz .ret                             ; ret nz — trainer battle: no prompt
    mov esi, UseNextMonText
    call PrintText
.displayYesNoBox:
    mov esi, BCOORD(13, 9)               ; PROJ — pret hlcoord 13, 9
    mov bh, 10                           ; lb bc, 10, 14
    mov bl, 14
    ; The port places this box from yn_box_col/row/proj_mode (the window
    ; compositor), not from esi/bh/bl above — those stay for pret cross-
    ; reference only. Battle anchor, matching EnemySendOutFirstMon.
    mov dword [yn_box_col], 13
    mov dword [yn_box_row], 9
    mov dword [yn_proj_mode], 1          ; battle anchor
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    mov al, [ebp + wMenuExitMethod]
    cmp al, CHOSE_SECOND_ITEM            ; did the player choose NO?
    je .tryRunning                       ; jr z
    and al, al                           ; reset carry
    ret
.tryRunning:
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jz .displayYesNoBox                  ; jr z — pret: "xxx when does this happen?"
    ; pret passes PARTY MON 1's speed here, not the battle mon's: the active mon
    ; has just fainted. TryRunningFromBattle honours those pointers as of 2b.
    mov esi, wPartyMon1Speed             ; ld hl, wPartyMon1Speed
    mov edx, wEnemyMonSpeed              ; ld de, wEnemyMonSpeed
    jmp TryRunningFromBattle             ; jp (tail — its CF is ours)
.ret:
    clc                                  ; pret returns here with CF clear
    ret

; ===========================================================================
; ChooseNextMon — pret core.asm:1125-1167. The FORCED switch after a faint: the
; party menu with no cancel, refusing fainted mons, then the send-out.
;
; RESTORED 2026-08-12 (battle plan 2b). The body auto-selected the first live
; party slot with its own scan loop under a "DEFERRAL" note, and faithdiff read
; 13 pret / 3 port. The picker it was standing in for is DisplayPartyMenu in
; BATTLE_PARTY_MENU mode, which has been linked all along; the deferral was the
; interactive UI, and 2a's PartyMenuOrRockOrRun proved that flow works.
;
; NO-CANCEL IS STRUCTURAL, not a flag: pret loops back to GoBackToPartyMenu
; whenever DisplayPartyMenu returns CF=1 (cancelled) or the chosen mon has
; fainted, so there is no way out of this menu except a live mon.
;
; DEVIATION{class=banking; pret=engine/battle/core.asm:ChooseNextMon; behavior=the two FlagActionPredef predefs are plain FlagAction calls; evidence=the port has no predef dispatcher so every predef target is called directly with its arguments in registers, the same standing convention SwitchPlayerMon and CopyDownscaledMonTiles already carry; lifetime=permanent while the port is dispatcher-free}
;
; Out: ZF from the enemy's HP word (pret's contract, read by
;      HandlePlayerMonFainted).
; ===========================================================================
ChooseNextMon:
    mov byte [ebp + wPartyMenuTypeOrMessageID], BATTLE_PARTY_MENU
    call DisplayPartyMenu
.checkIfMonChosen:
    jnc .monChosen                      ; jr nc
.goBackToPartyMenu:
    call GoBackToPartyMenu
    jmp .checkIfMonChosen               ; jr
.monChosen:
    call HasMonFainted
    jz .goBackToPartyMenu               ; jr z — a fainted mon is not a choice
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jne .notLinkBattle                  ; jr nz
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    call LinkBattleExchangeData         ; ret-stand-in; link play is unported
.notLinkBattle:
    mov byte [ebp + wActionResultOrTookBattleTurn], 0   ; xor a
    call ClearSprites
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wPlayerMonNumber], al
    ; pret: ld c,a / ld hl,wPartyGainExpFlags / ld b,FLAG_SET / push bc /
    ;       predef / pop bc / ld hl,wPartyFoughtCurrentEnemyFlags / predef
    mov cl, al
    mov bh, FLAG_SET
    push ebx
    push ecx
    mov esi, wPartyGainExpFlags
    call FlagAction
    pop ecx
    pop ebx
    mov esi, wPartyFoughtCurrentEnemyFlags
    call FlagAction
    call LoadBattleMonFromParty
    call GBPalWhiteOut
    call LoadHudTilePatterns
    call LoadScreenTilesFromBuffer1
    call RunDefaultPaletteCommand
    call GBPalNormal
    call SendOutMon
    mov al, [ebp + wEnemyMonHP]
    or  al, [ebp + wEnemyMonHP + 1]     ; ZF = enemy has 0 HP (pret return contract)
    ret

; ===========================================================================
; SendOutMon — pret core.asm:1764+. Prints the send-out message, redraws the
; HUDs, resets the player-side per-mon battle state, and plays the send-out
; animation + cry for the incoming mon.
;
; RESTORED 2026-08-11 (battle_completion plan item 1f). The previous body ended
; at RunPaletteCommand under the comment "ANIMATION=OFF: PlayMoveAnimation
; (POOF_ANIM) / AnimateSendingOutMon / Pikachu.", which was STALE — faithdiff
; reported calls 14 pret / 2 port. That dropped chain is why IO_OBP1 stayed 0:
; pret reaches SetAnimationPalette (the only writer of rOBP1=$6c) through
; PlayMoveAnimation, so the composed CGB OBJ palettes 4-7 collapsed to white in
; every battle golden. Measurement: docs/current_plan_palette_fidelity.md and
; memory regression-battle-sendoutmon-animation-tail-dropped.
;
; Two callees are ret-stubs, each with its own STUB annotation at its stub
; site: PrintSendOutMonMessage and StarterPikachuBattleEntranceAnimation
; (battle_stubs.asm). IsPlayerPikachuAsleepInParty was the third until
; 2026-08-13, when it was translated into the mirror
; engine/pikachu/pikachu_emotions.asm. PlayCry
; and PrintEmptyString were already linked stubs. The call SHAPE is pret's; the
; stubs are what remains to retire.
; ===========================================================================
SendOutMon:
    call PrintSendOutMonMessage          ; callfar PrintSendOutMonMessage (STUB)
    mov al, [ebp + wEnemyMonHP]          ; ld hl,wEnemyMonHP / ld a,[hli]
    or  al, [ebp + wEnemyMonHP + 1]      ; or [hl] — is enemy mon HP zero?
    jz .skipDrawingEnemyHUDAndHPBar      ; jp z
    call DrawEnemyHUDAndHPBar
.skipDrawingEnemyHUDAndHPBar:
    call DrawPlayerHUDAndHPBar
    call LoadMonBackPic                  ; predef LoadMonBackPic (direct in flat model)
    xor al, al
    mov [ebp + hStartTileID], al         ; xor a / ldh [hStartTileID],a
    mov [ebp + wBattleAndStartSavedMenuItem + 0], al
    mov [ebp + wBattleAndStartSavedMenuItem + 1], al
    mov [ebp + wBoostExpByExpAll], al
    mov [ebp + wDamageMultipliers], al
    mov [ebp + wPlayerMoveNum], al
    mov [ebp + wPlayerUsedMove + 0], al
    mov [ebp + wPlayerUsedMove + 1], al
    mov [ebp + wPlayerStatsToDouble + 0], al
    mov [ebp + wPlayerStatsToDouble + 1], al   ; StatsToHalve
    mov [ebp + wPlayerBattleStatus1], al
    mov [ebp + wPlayerBattleStatus2], al
    mov [ebp + wPlayerBattleStatus3], al
    mov [ebp + wPlayerDisabledMove], al
    mov [ebp + wPlayerDisabledMoveNumber], al
    mov [ebp + wPlayerMonMinimized], al
    ; FIXED: pret is `ld b, SET_PAL_BATTLE / call RunPaletteCommand`. The port set
    ; B NOT AT ALL and dispatched on whatever junk BX happened to hold — harmless only
    ; while RunPaletteCommand ignored its argument, which stopped being true when the
    ; palette engine landed. Ledger M-72.
    mov bh, SET_PAL_BATTLE               ; ld b, SET_PAL_BATTLE
    call RunPaletteCommand
    and byte [ebp + wEnemyBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
    call IsThisPartyMonStarterPikachu    ; callfar — CF=1 when it is the starter
    jc .starterPikachu                   ; jr c
    mov byte [ebp + hWhoseTurn], 1       ; ld a,$1 / ldh [hWhoseTurn],a
    mov al, POOF_ANIM                    ; ld a, POOF_ANIM
    call PlayMoveAnimation               ; -> MoveAnimation -> SetAnimationPalette
    ; hlcoord 4, 11 -> the predef HL mailbox. pret's `predef` macro stashes HL in
    ; wPredefHL and AnimateSendingOutMon reads it back itself; the port stages the
    ; same big-endian word inline, as add_mon.asm / evos_moves.asm do.
    mov eax, BCOORD(4, 11)
    mov [ebp + wPredefHL + 1], al        ; L (low byte)
    mov [ebp + wPredefHL], ah            ; H (high byte) — GB predef word is big-endian
    call AnimateSendingOutMon            ; predef AnimateSendingOutMon
    jmp short .playRegularCry            ; jr .playRegularCry
.starterPikachu:
    mov byte [ebp + hWhoseTurn], 0       ; xor a / ldh [hWhoseTurn],a
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call StarterPikachuBattleEntranceAnimation ; callfar (STUB)
    call IsPlayerPikachuAsleepInParty    ; callfar — CF=1 when the starter is asleep
    mov dl, 36                           ; ldpikacry e, PikachuCry37 (0-based)
    jc .asm_3cd81                        ; jr c
    mov dl, 10                           ; ldpikacry e, PikachuCry11 (0-based)
.asm_3cd81:
    call PlayPikachuSoundClip            ; callfar PlayPikachuSoundClip
    jmp short .done                      ; jr .done
.playRegularCry:
    mov al, [ebp + wCurPartySpecies]     ; ld a,[wCurPartySpecies]
    call PlayCry                         ; (STUB — home_stubs.asm)
.done:
    call PrintEmptyString                ; REAL (this file, pret core.asm:6720)
    jmp SaveScreenTilesToBuffer1         ; jp SaveScreenTilesToBuffer1

; ===========================================================================
; HandlePlayerBlackOut — pret core.asm:1171-1204. Called when the player has no
; usable mons. Prints the appropriate lose message and returns CF=1, EXCEPT for
; the Oak's Lab rival-1 starter battle, which returns early without blacking out.
;
; RESTORED 2026-08-11 (battle plan 1d). The body was a three-line stand-in
; (`call ClearScreen / stc / ret`) whose `TODO-HW` claimed the palette command
; and PlayerBlackedOutText2 were unavailable; both are present —
; SET_PAL_BATTLE_BLACK in engine/gfx/palettes.asm and the three lose-text
; streams generated into assets/battle_text.inc (lines 285, 369, 402).
; `faithdiff HandlePlayerBlackOut` read 6 pret / 1 port before this change.
;
; Out: CF=1 = player blacked out; CF=0 = Oak's Lab starter loss (no blackout).
; ===========================================================================
HandlePlayerBlackOut:
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jz .notRival1Battle                  ; jr z
    mov al, [ebp + wCurOpponent]
    cmp al, OPP_RIVAL1
    jnz .notRival1Battle                 ; jr nz
    ; rival 1 battle: wipe the battle frame and scroll the rival's pic back in
    mov esi, BCOORD(0, 0)                ; PROJ — pret hlcoord 0, 0
    mov bh, 8                            ; lb bc, 8, 21 — b = height
    mov bl, 21                           ;               c = width (pret clears
                                         ;               21 columns on a 20-wide
                                         ;               GB screen; kept verbatim)
    call ClearScreenArea
%ifndef DEBUG_TRAINER_RESULT
    call ScrollTrainerPicAfterBattle
    mov bl, 40                           ; ld c, 40
    call DelayFrames
    mov eax, Rival1WinText
    call PrintBattleText
%endif
    mov al, [ebp + wCurMap]
    cmp al, MAP_ID_OAKS_LAB
    jz .noBlackOut                       ; ret z — starter battle: don't black out
.notRival1Battle:
    mov bh, SET_PAL_BATTLE_BLACK         ; ld b (port RunPaletteCommand reads BH)
    call RunPaletteCommand
%ifndef DEBUG_TRAINER_RESULT
    mov eax, PlayerBlackedOutText2       ; ld hl, PlayerBlackedOutText2
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jnz .noLinkBattle                    ; jr nz
    mov eax, LinkBattleLostText
.noLinkBattle:
    call PrintBattleText
%endif
    ; ld a,[wStatusFlags6] / res BIT_ALWAYS_ON_BIKE, a / ld [wStatusFlags6], a
    and byte [ebp + wStatusFlags6], (~(1 << BIT_ALWAYS_ON_BIKE)) & 0xFF
    call ClearScreen
    stc                                  ; CF=1 → player blacked out
    ret
.noBlackOut:
    ret                                  ; pret `ret z`: CF is clear here

; ===========================================================================
; EnemyRan — pret core.asm:263.
;
; THE COMMENT THAT USED TO SIT HERE WAS WRONG, AND IT GUARDED THREE DROPS. It
; read "Reached (single-player) only as the ReplaceFaintedEnemyMon 'ran' tail,
; which is link-only, so this is effectively a safety path". MEASURED FALSE
; 2026-08-14: the SAFARI flee reaches it in single player —
; _InitBattleCommon.specialBattleLoop's `add a / jc EnemyRan` on the enemy speed
; low byte — and a DEBUG_BATTLE_SAFARI_RESULT run stops here with "Wild PIDGEY /
; ran!" on the tilemap. Nothing about this path is link-only or a safety net.
;
; The body is now pret's, including the link/non-link split that decides BOTH
; the text and whether wBattleResult is written. The port previously printed
; WildRanText unconditionally and wrote wBattleResult UNCONDITIONALLY, where
; pret writes it only on the link arm.
; ===========================================================================
EnemyRan:
    call LoadScreenTilesFromBuffer1
    mov eax, WildRanText                 ; ld hl, WildRanText
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jne .printText                       ; jr nz
; link battle
    mov byte [ebp + wBattleResult], 0    ; xor a / ld [wBattleResult], a
    mov eax, EnemyRanText                ; ld hl, EnemyRanText
.printText:
    call PrintBattleText                 ; call PrintText (port battle msgbox wrapper)
    mov al, SFX_RUN
    call PlaySoundWaitForCurrent
    mov byte [ebp + hWhoseTurn], 0       ; xor a / ldh [hWhoseTurn], a
    ; NOT `ANIMATION=OFF` ANY MORE — the provider landed. AnimationSlideEnemyMonOff
    ; was retired from core_stubs.asm on 2026-08-08 and is `translated`; the
    ; deferral note here outlived it. pret's `jpfar` is a TAIL call, so the
    ; slide's ret IS this routine's ret. The hWhoseTurn zeroing above is what
    ; makes it slide the ENEMY: the routine goes through CallWithTurnFlipped.
    jmp AnimationSlideEnemyMonOff        ; jpfar

; --- was src/engine/battle/faint_sendout.asm ---

; ===========================================================================
; SlideTrainerPicOffScreen — pret core.asm:1274.
;
; In: AL = slide amount (pret's `a`), ESI = tilemap top-left (pret's `hl`).
;     amount 8 slides RIGHT (enemy trainer), anything else slides LEFT (player).
;
; THE MECHANISM, because it is easy to misread: this is a FIXED-WINDOW in-place
; shift ANCHORED TO THE SCREEN EDGE, not a translation of the pic to a new
; position. Simulated against pret cell-by-cell: the player pass (amount 9, from
; GB col 1) READS cols 1-9 and WRITES cols 0-8; the enemy pass (amount 8, from
; GB col 18) READS cols 18-11 and WRITES cols 19-12. Neither ever touches a cell
; outside the 20-wide GB screen — the pic is destroyed AT the edge as blanks
; propagate in from the far side, and after `amount` steps the window is empty.
;
; THAT IS WHY THIS NEEDS NO PROJECTION DEVIATION. Because the window is anchored
; to the GB screen edge, every write stays inside the projected GB window
; (canvas cols 10-29) once the caller passes a BCOORD origin. pret's row step is
; `ld de, SCREEN_WIDTH / add hl, de`, and the port's SCREEN_WIDTH is 40 — the
; same source expression, the canvas constant — so the row walk is literal too.
; An earlier analysis in docs/current_plan_battle_completion.md concluded a slid
; pic would land at canvas col 2 / col 36, out in the unguarded margin; that read
; the slide as MOVING the pic `amount` columns. It does not move anywhere.
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:SlideTrainerPicOffScreen; behavior=pret's hSlideAmount HRAM byte is realized as the file-local .bss byte slide_amount; evidence=hSlideAmount has no slot in the port memmap and engine/movie/oak_speech/oak_speech2.asm already sets the precedent of keeping pret's hSlideDirection/hSlideAmount/hSlidingRegionSize as file-local .bss under the same class; lifetime=retire if the port ever models pret HRAM directly}
; ===========================================================================
global SlideTrainerPicOffScreen
SlideTrainerPicOffScreen:
    mov [slide_amount], al                   ; ldh [hSlideAmount], a
    mov bl, al                               ; ld c, a
.slideStepLoop:                              ; each iteration slides the pic one tile
    push ebx                                 ; push bc
    push esi                                 ; push hl
    mov bh, PIC_HEIGHT                       ; ld b, PIC_HEIGHT
.rowLoop:
    push esi                                 ; push hl
    mov al, [slide_amount]
    mov bl, al                               ; ld c, a
.columnLoop:
    mov al, [slide_amount]
    cmp al, 8
    jz .slideRight
; slide player sprite left off screen
    mov al, [ebp + esi]                      ; ld a, [hld]
    dec esi
    mov [ebp + esi], al                      ; ld [hli], a
    inc esi
    inc esi                                  ; inc hl
    jmp short .nextColumn
.slideRight:                                 ; slide enemy trainer sprite off screen
    mov al, [ebp + esi]                      ; ld a, [hli]
    inc esi
    mov [ebp + esi], al                      ; ld [hld], a
    dec esi
    dec esi                                  ; dec hl
.nextColumn:
    dec bl                                   ; dec c — 8-bit, as pret
    jnz .columnLoop
    pop esi                                  ; pop hl
    add esi, SCREEN_WIDTH                    ; ld de, SCREEN_WIDTH / add hl, de
    dec bh                                   ; dec b — 8-bit, as pret
    jnz .rowLoop
    mov bl, 2                                ; ld c, 2
    call DelayFrames
    pop esi                                  ; pop hl
    pop ebx                                  ; pop bc
    dec bl                                   ; dec c — 8-bit, as pret
    jnz .slideStepLoop
    ret

section .data
slide_amount: db 0                           ; pret hSlideAmount (see the DEVIATION above)
section .text

; ===========================================================================
; EnemySendOut — pret core.asm:1315. Player-exp bookkeeping, then send out the
; enemy's next live mon (faint path enters the .next scan with b=$ff).
; ===========================================================================
EnemySendOut:
    ; pret: clear then set the active player mon's gain-exp + fought flags, so the
    ; mon currently out earns EXP from the incoming enemy mon.
    mov byte [ebp + wPartyGainExpFlags], 0
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyGainExpFlags
    mov bh, FLAG_SET
    call FlagAction
    mov byte [ebp + wPartyFoughtCurrentEnemyFlags], 0
    mov cl, [ebp + wPlayerMonNumber]
    mov esi, wPartyFoughtCurrentEnemyFlags
    mov bh, FLAG_SET
    call FlagAction
EnemySendOutFirstMon:
    ; clear enemy statuses (5 contiguous bytes) + disabled/minimized/used-move
    xor al, al
    mov [ebp + wEnemyStatsToDouble], al
    mov [ebp + wEnemyStatsToHalve], al
    mov [ebp + wEnemyBattleStatus1], al
    mov [ebp + wEnemyBattleStatus2], al
    mov [ebp + wEnemyBattleStatus3], al
    mov [ebp + wEnemyDisabledMove], al
    mov [ebp + wEnemyDisabledMoveNumber], al
    mov [ebp + wEnemyMonMinimized], al
    mov [ebp + wPlayerUsedMove], al
    mov [ebp + wEnemyUsedMove], al
    mov byte [ebp + wAICount], 0xFF             ; pret: dec a → $ff
    and byte [ebp + wPlayerBattleStatus1], (~(1 << USING_TRAPPING_MOVE)) & 0xFF
    ; pret 1349-1352: hlcoord 18,0 / ld a,8 / call SlideTrainerPicOffScreen.
    ; BCOORD is the GB->canvas projection; the routine's writes stay inside the
    ; GB window because its shift window is anchored to the screen edge.
    mov esi, BCOORD(18, 0)                       ; hlcoord 18, 0
    mov al, 8                                    ; ld a, 8 — 8 = slide RIGHT
    call SlideTrainerPicOffScreen
    call PrintEmptyString
    call SaveScreenTilesToBuffer1
    ; TODO-HW: link-battle received-switch index (Phase 4).
    ; --- find the next non-fainted enemy party mon (skip the current fainted slot) ---
.next:
    mov bh, 0xFF                                 ; b = $ff
.next2:
    inc bh
    mov al, [ebp + wEnemyMonPartyPos]
    cmp al, bh
    je  .next2                                   ; skip the current (fainted) slot
    mov al, bh                                   ; al = slot index (AddNTimes count)
    mov [ebp + wWhichPokemon], al
    mov esi, wEnemyMon1
    push ebx                                      ; preserve the loop counter (BH)
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes                               ; esi -> this mon's struct (clobbers BX/AL)
    pop ebx
    inc esi                                      ; -> HP word
    mov al, [ebp + esi]
    or  al, [ebp + esi + 1]
    jz  .next2                                   ; fainted → try the next slot
.next3:
    ; wCurEnemyLevel = party-slot level
    mov al, [ebp + wWhichPokemon]
    mov esi, wEnemyMon1Level
    mov bx, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]
    mov [ebp + wCurEnemyLevel], al
    ; wEnemyMonSpecies2 / wCurPartySpecies = enemy party species list[idx]
    mov al, [ebp + wWhichPokemon]
    inc al
    movzx ecx, al
    mov al, [ebp + wEnemyPartyCount + ecx]       ; wEnemyPartyCount+(idx+1) = species
    mov [ebp + wEnemyMonSpecies2], al
    mov [ebp + wCurPartySpecies], al
    call LoadEnemyMonData                        ; pret: load the selected trainer mon + EXP fields
    ; pret core.asm:1398-1402 — snapshot the incoming enemy mon's HP. RESTORED
    ; 2026-08-12 (battle plan 2a): both stores were dropped, and the word was not
    ; even declared in gb_memmap.inc until this plan. It is the baseline
    ; PlayerMon2Text subtracts from to decide the player's switch-out line, so
    ; without it that message is chosen from whatever WRAM happened to hold.
    mov al, [ebp + wEnemyMonHP]                  ; ld a,[hli] (big-endian high)
    mov [ebp + wLastSwitchInEnemyMonHP], al
    mov al, [ebp + wEnemyMonHP + 1]              ; ld a,[hl]  (low)
    mov [ebp + wLastSwitchInEnemyMonHP + 1], al
    mov byte [ebp + wCurrentMenuItem], 1         ; pret: default (no player switch)
    ; pret core.asm:1405-1451 — the BIT_BATTLE_SHIFT "TrainerAboutToUse / switch?"
    ; prompt. RESTORED 2026-08-15 (battle plan tail). All four early-outs land
    ; directly on .next4 (SET-mode/no-prompt), exactly as pret's four `jr z`s do.
    mov al, [ebp + wFirstMonsNotOutYet]
    dec al
    jz .next4                                    ; jr z — first mons never went out
    mov al, [ebp + wPartyCount]
    dec al
    jz .next4                                    ; jr z — solo party, nothing to switch to
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    je .next4                                    ; jr z — link battle: no prompt
    test byte [ebp + wOptions], 1 << BIT_BATTLE_SHIFT
    jnz .next4                                   ; jr nz — SET battle style: no prompt
    mov eax, TrainerAboutToUseText
    call PrintBattleText                         ; ld hl,.../call PrintText
    ; pret: hlcoord 0, 7 / lb bc, 8, 1 / wTextBoxID=TWO_OPTION_MENU / DisplayTextBoxID.
    ; DEVIATION{class=projection; pret=engine/battle/core.asm:EnemySendOutFirstMon; behavior=the switch-prompt YES/NO box is drawn from the port's YES_NO_MENU descriptor (4x3 interior, str_yes/str_no) at yn_box_col/row=(0,7) with yn_proj_mode=1 (battle anchor, X+10/Y+3) instead of pret's raw hlcoord 0,7 / lb bc,8,1 box; evidence=DisplayTwoOptionMenu is table-driven by wTwoOptionMenuID in this port (TwoOptionMenuDesc, engine/menus/text_box.asm) rather than pret's HL/BC triple, exactly as SaveTheGame_YesOrNo (engine/menus/save.asm) already established for the identical hlcoord 0,7 / lb bc,8,1 box, and this is the first caller to select yn_proj_mode=1 rather than the overworld default, closing engine/menus/text_box.asm's own TODO(battle-verify) note on that branch; lifetime=permanent window-compositor boundary, same as SaveTheGame_YesOrNo's}
    mov dword [yn_box_col], 0
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 1                  ; battle anchor
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jnz .next4                                   ; jr nz — chose NO, skip the party menu
    mov byte [ebp + wPartyMenuTypeOrMessageID], BATTLE_PARTY_MENU
    call DisplayPartyMenu
.next9:
    mov byte [ebp + wCurrentMenuItem], 1
    jc .next7                                    ; jr c — cancelled: keep SET-mode default
    mov al, [ebp + wWhichPokemon]
    cmp al, [ebp + wPlayerMonNumber]
    jnz .next6                                   ; jr nz
    mov eax, AlreadyOutText
    call PrintBattleText
.next8:
    call GoBackToPartyMenu
    jmp .next9                                   ; jr .next9
.next6:
    call HasMonFainted
    jz .next8                                    ; jr z
    mov byte [ebp + wCurrentMenuItem], 0         ; xor a
.next7:
    call GBPalWhiteOut
    call LoadHudTilePatterns
    ; PORT-ONLY TEARDOWN — the party menu is a full-screen takeover (two window
    ; descriptors over a blanked background) and restores the OVERWORLD msgbox
    ; record on exit; both are wrong here. Same trio PartyMenuOrRockOrRun and
    ; RestoreBattleScreenState already carry for the identical reason.
    mov dword [g_window_count], 0
    mov dword [g_bg_whiteout], 0
    mov dword [text_msgbox], msgbox_centered
    call LoadScreenTilesFromBuffer1
.next4:
    call ClearSprites
    ; pret: hlcoord 0,0 / lb bc, 4, 11 / call ClearScreenArea — wipe the enemy
    ; name/HUD corner before the redraw (the new mon's name can be shorter).
    mov esi, BCOORD(0, 0)
    mov bh, 4                                     ; height
    mov bl, 11                                    ; width
    call ClearScreenArea
    ; FIXED: pret is `ld b, SET_PAL_BATTLE / call RunPaletteCommand`; the port set B
    ; not at all and dispatched on junk. See faint_switch.asm. Ledger M-72.
    mov bh, SET_PAL_BATTLE                        ; ld b, SET_PAL_BATTLE
    call RunPaletteCommand
    ; pret: GBPalNormal (palette fade path) — Phase-5 deferral, unchanged.
    ; pret: ld hl, TrainerSentOutText / call PrintText
    mov eax, TrainerSentOutText
    call PrintBattleText
    ; pret: wEnemyMonSpecies2 -> wCurPartySpecies/wCurSpecies, GetMonHeader,
    ; LoadMonFrontSprite -> vFrontPic, then the tilemap placement. The port folds
    ; decode + placement into LoadFrontSpriteByMonIndex — the SAME path the battle
    ; intro takes for the first mon (init_battle.asm .enemyFrontReady), which is
    ; what makes the send-out pic actually change (it was elided before: Weedle
    ; kept wearing Caterpie's sprite — regression-battle-trainer-post-battle-and-hud
    ; symptom 2).
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    ; PROJ battle: the PROJECTED enemy-pic cell, not pret's raw hlcoord 12,0.
    ; LoadFrontSpriteByMonIndex places the 7x7 block at ESI, and nothing clears the
    ; canvas after send-out (SlideBattlePicsIn only runs at battle entry), so a raw
    ; GB anchor leaves a ghost pic block at rows 0-6 / cols 12-18 while the real pic
    ; and the whole HUD sit at UI_ENEMY_PIC_* / cols 22-28. The enemy HUD is then
    ; drawn ON TOP of that ghost, and every cell the name/level/HP text does not
    ; cover keeps rendering pic tiles. MEASURED 2026-08-06, DEBUG_TRAINER_ROUTE dump
    ; at frame 2000: wTileMap row 4 = `04 0B 6E F7 F6 27 2E` — pic tile ids $04/$0B/
    ; $27/$2E flanking the ":L10" text — with the VRAM tiles byte-perfect at the
    ; same instant, so the defect was never in the tile data.
    mov esi, wTileMap + UI_ENEMY_PIC_ROW * SCREEN_TILES_W + UI_ENEMY_PIC_COL
    call LoadFrontSpriteByMonIndex
    ; pret core.asm:1465-1473 — GetMonHeader/LoadMonFrontSprite are already folded
    ; into LoadFrontSpriteByMonIndex above (see its comment); this stage is the
    ; remaining "grow out of the ball" animation + cry, RESTORED 2026-08-15
    ; (battle plan tail). Mirrors SendOutMon's own AnimateSendingOutMon call
    ; (this file, above): hStartTileID staged, wPredefHL staged big-endian, then
    ; the predef and the cry. Two differences from SendOutMon, both pret's own:
    ; hStartTileID is pret's literal -$31 here (SendOutMon's caller zeroed it
    ; instead — AnimateSendingOutMon adds $31 back either way, landing both at
    ; tile 0, the enemy front-pic base), and there is no POOF_ANIM / starter-
    ; Pikachu fork — pret's EnemySendOutFirstMon never had one.
    mov al, -0x31                                ; ld a, -$31
    mov [ebp + hStartTileID], al                 ; ldh [hStartTileID], a
    ; PROJ battle: pret's hlcoord 15,6 is BCOORD(15,6) here — a cell inside the
    ; enemy pic block (BCOORD(12,0), 7x7), offset (3,6), exactly like
    ; UI_ENEMY_PIC_ROW/_COL's own +10/+3 anchor above.
    mov eax, BCOORD(15, 6)                       ; hlcoord 15, 6
    mov [ebp + wPredefHL + 1], al                 ; L (low byte)
    mov [ebp + wPredefHL], ah                     ; H (high byte) — big-endian predef word
    call AnimateSendingOutMon                     ; predef AnimateSendingOutMon
    mov al, [ebp + wEnemyMonSpecies2]             ; ld a,[wEnemyMonSpecies2]
    call PlayCry
    ; pret core.asm:1474 draws the ENEMY HUD ONLY here — the player mon is not
    ; out yet at the first send-out, so wBattleMon is still zeroed. The old
    ; `call DrawHUDsAndHPBars` stand-in painted a garbage player HUD (":L0",
    ; empty HP) whose edge triangle then sat inside the player-pic slide window
    ; and was dragged left by SlideTrainerPicOffScreen, and Buffer1 carried the
    ; duplicate arrow into the battle menu. Invisible while the send-out ran
    ; before the intro (the slide cleared the canvas each frame); measured
    ; live 2026-08-15 (maintainer screenshot + DEBUG_TRAINER_ROUTE frames)
    ; once 422a523d6 restored pret's send-out position.
    call DrawEnemyHUDAndHPBar                      ; pret: call DrawEnemyHUDAndHPBar
    ; pret core.asm:1475-1482 — RESTORED 2026-08-15 (battle plan tail). This tail
    ; is reachable now that the switch prompt above can actually clear
    ; wCurrentMenuItem: a player who accepts the switch-prompt and picks a live,
    ; not-already-out mon falls through into SwitchPlayerMon exactly as pret does.
    mov al, [ebp + wCurrentMenuItem]
    and al, al
    jnz .ret                                       ; ret nz
    mov byte [ebp + wPartyGainExpFlags], 0          ; xor a
    mov byte [ebp + wPartyFoughtCurrentEnemyFlags], 0
    call SaveScreenTilesToBuffer1
    jmp SwitchPlayerMon                             ; jp SwitchPlayerMon
.ret:
    ret

; ===========================================================================
; ReplaceFaintedEnemyMon — pret core.asm:901. Palette/pokéball redraw (stubbed),
; then send out the next mon and reset the enemy move/AI bookkeeping. Returns ZF=0
; (single-player never "runs"; the ZF=1 → EnemyRan path is link-only).
; ===========================================================================
ReplaceFaintedEnemyMon:
    ; pret :902-904 — refresh the ENEMY bar's colour for the incoming mon at a
    ; full bar ($30 = 48 px) and republish the battle palette only if that
    ; changes the colour. This was listed as an ANIMATION/palette TODO here; the
    ; routine now exists, so the call is real rather than deferred.
    mov esi, wEnemyHPBarColor                      ; ld hl, wEnemyHPBarColor
    mov dl, 0x30                                   ; ld e, $30 — full bar
    call GetBattleHealthBarColor
    ; pret :905-909 — the OBP half of that TODO-HW was STALE and is retired
    ; 2026-08-14. rOBP0/rOBP1 are NOT a hardware boundary in this port: a write
    ; to [ebp + IO_OBP*] IS the whole effect, because commit_palette (boot/
    ; video.asm) runs from DelayFrame and early-outs unless one of the three DMG
    ; palette registers changed — which is exactly how the whole battle-animation
    ; flash family is translated. UpdateCGBPal_OBP0/1 are translated and linked.
    ; pret's `ldpal a, SHADE_BLACK, SHADE_DARK, SHADE_LIGHT, SHADE_WHITE` packs
    ; (3<<6)|(2<<4)|(1<<2)|0 = $E4, the identity sprite palette DrawBattlePokeballs
    ; already writes by that name.
    mov al, 0xE4                                   ; ldpal a, BLACK,DARK,LIGHT,WHITE
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov [ebp + IO_OBP1], al                        ; ldh [rOBP1], a
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    ; STILL DROPPED, and each for its own reason rather than one blanket TODO:
    ;   * DrawEnemyPokeballs — now translatable (every callee took its pret name
    ;     in 337a2b0ab) but NOT yet wired, because pret reaches the screen through
    ;     a shadow-OAM DMA this port deliberately skips while a ball row is up;
    ;     wiring it needs the PrepareStaticOAM publish DrawBattlePokeballs
    ;     carries, and that is a HAL decision, not a translation.
    ;   * LinkBattleExchangeData / LINKBATTLE_RUN → EnemyRan — link battle,
    ;     TODO-HW: network HAL (Phase 4).
    ;   * LoadScreenTilesFromBuffer1 — on the link arm only, same reason.
    call EnemySendOut
    mov byte [ebp + wEnemyMoveNum], 0
    mov byte [ebp + wActionResultOrTookBattleTurn], 0
    mov byte [ebp + wAILayer2Encouragement], 0
    mov al, 1
    and al, al                                     ; ZF=0 → sent out (did not run)
    ret

; ===========================================================================
; CalculateModifiedStats — pret core.asm:6550. Recompute the four modifiable
; battle stats (attack, defense, speed, special) from the UNMODIFIED stats and
; the current stat-stage modifiers. Called after a level-up in GainExperience
; and by the stat-stage effects.
;
; PORTED 2026-08-12 (battle plan 3d). It was a ret-only STUB in
; battle_exp_stubs.asm because CalculateModifiedStat read `missing`. Everything
; it needs already existed: StatModifierRatios (src/data/battle/stat_modifiers.asm),
; Multiply and Divide (src/home/math.asm), and every WRAM/HRAM symbol.
;
; UNLIKE DoubleSelectedStats/HalveSelectedStats BELOW, THIS IS NOT A NO-OP. Those
; two are gated on masks that are always 0; this one runs unconditionally and
; rewrites wBattleMonAttack..Special, so it changes behaviour and needs a witness.
;
; The counter is pret's 8-bit `ld c,0 … cp NUM_STATS - 1`, kept 8-bit here.
; CalculateModifiedStat preserves BC (push/pop), so BL survives the call.
; ===========================================================================
CalculateModifiedStats:
    mov bl, 0                               ; ld c, 0
.loop:
    call CalculateModifiedStat
    inc bl                                  ; inc c
    mov al, bl                              ; ld a, c
    cmp al, NUM_STATS - 1                   ; cp NUM_STATS - 1
    jne .loop                               ; jr nz
    ret

; ===========================================================================
; CalculateModifiedStat — pret core.asm:6560. One stat, selected by C
; (0 = attack, 1 = defense, 2 = speed, 3 = special):
;   stat = unmodified * StatModifierRatios[stage].num / .den, capped at
;   MAX_STAT_VALUE (999) and floored at 1.
; In:  BL (pret C) = stat index; wCalculateWhoseStats (0 = player, else enemy).
; Out: the stat word rewritten in place. BC preserved.
;
; TWO ADDRESS SPACES IN ESI, DELIBERATELY. pret keeps everything in HL; the port
; does not, because wBattleMonAttack is GB memory (read `[ebp + esi]`) while
; StatModifierRatios is a FLAT program table in .data (read `[esi]`). The stat
; pointer is therefore pushed across the ratio-table walk, exactly as pret's
; `push hl` does, and each dereference below says which space it is in.
;
; hMultiplier AND hDivisor ARE THE SAME BYTE ($FF99) — pret's own union. The
; sequence write-hMultiplier / Multiply / write-hDivisor / Divide is load-bearing
; and must not be reordered or hoisted.
;
; DEVIATION{class=projection; pret=engine/battle/core.asm:CalculateModifiedStat; behavior=StatModifierRatios is walked as a flat program pointer with [esi] while the stat and unmodified-stat pointers stay GB-relative with [ebp+esi] and [ebp+edx]; evidence=the ratio table is Tier-1 data emitted into the port image by src/data/battle/stat_modifiers.asm rather than into emulated GB memory, the same split every other flat table read in this port uses, and the arithmetic including the pointer walk is unchanged; lifetime=permanent while the port keeps generated tables in the program image}
; ===========================================================================
CalculateModifiedStat:
    push ebx                                ; push bc — caller's stat index
    push ebx                                ; push bc — again (pret does)
    mov al, [ebp + wCalculateWhoseStats]
    test al, al                             ; and a
    ; pret's ld a,c / ld hl / ld de / ld bc are flag-neutral, and so are these
    ; movs, so the ZF above survives to the branch.
    mov al, bl                              ; ld a, c — the stat index
    mov esi, wBattleMonAttack               ; GB pointer
    mov edx, wPlayerMonUnmodifiedAttack     ; GB pointer
    mov ebx, wPlayerMonStatMods             ; 32-bit: keeps EBX clean for [ebp+ebx]
    jz .next                                ; jr z
    mov esi, wEnemyMonAttack
    mov edx, wEnemyMonUnmodifiedAttack
    mov ebx, wEnemyMonStatMods
.next:
    add al, bl                              ; add c   — index + low(statmods)
    mov bl, al                              ; ld c, a
    jnc .noCarry1                           ; jr nc
    inc bh
.noCarry1:
    mov al, [ebp + ebx]                     ; ld a,[bc] — the stat's stage
    pop ebx                                 ; pop bc  — C = stat index again
    mov bh, al                              ; ld b, a — B = stage
    push ebx                                ; push bc
    shl bl, 1                               ; sla c   — index * 2
    mov bh, 0                               ; ld b, 0
    movzx ecx, bx                           ; (16-bit BC, as `add hl,bc` sees it)
    add esi, ecx                            ; add hl, bc — &stat word
    mov al, bl                              ; ld a, c
    add al, dl                              ; add e
    mov dl, al                              ; ld e, a
    jnc .noCarry2                           ; jr nc
    inc dh
.noCarry2:                                  ; EDX = &unmodified stat word
    pop ebx                                 ; pop bc — B = stage, C = index
    push esi                                ; push hl — save the GB stat pointer
    mov esi, StatModifierRatios             ; FLAT table from here until the pop
    dec bh                                  ; dec b  — stage - 1
    shl bh, 1                               ; sla b  — * 2 (num/den pairs)
    mov bl, bh                              ; ld c, b
    mov bh, 0                               ; ld b, 0
    movzx ecx, bx
    add esi, ecx                            ; add hl, bc — &ratio pair
    xor al, al
    mov [ebp + hMultiplicand], al
    mov al, [ebp + edx]                     ; ld a,[de] — unmodified stat, high
    mov [ebp + hMultiplicand + 1], al
    inc edx                                 ; inc de
    mov al, [ebp + edx]                     ; ld a,[de] — unmodified stat, low
    mov [ebp + hMultiplicand + 2], al
    mov al, [esi]                           ; ld a,[hli] — numerator (FLAT)
    inc esi
    mov [ebp + hMultiplier], al
    call Multiply
    mov al, [esi]                           ; ld a,[hl]  — denominator (FLAT)
    mov [ebp + hDivisor], al                ; same byte as hMultiplier — see above
    mov bh, 4                               ; ld b, $4
    call Divide
    pop esi                                 ; pop hl — the GB stat pointer is back
    ; Cap at MAX_STAT_VALUE. pret's two-byte compare is a borrow chain, so the
    ; `mov` between the halves must not touch CF — on x86 it does not.
    mov al, [ebp + hDividend + 3]
    sub al, MAX_STAT_VALUE & 0xFF           ; sub LOW(MAX_STAT_VALUE)
    mov al, [ebp + hDividend + 2]
    sbb al, MAX_STAT_VALUE >> 8             ; sbc HIGH(MAX_STAT_VALUE)
    jc .storeNewStatValue                   ; jp c
    mov byte [ebp + hDividend + 2], MAX_STAT_VALUE >> 8
    mov byte [ebp + hDividend + 3], MAX_STAT_VALUE & 0xFF
.storeNewStatValue:
    mov al, [ebp + hDividend + 2]
    mov [ebp + esi], al                     ; ld [hli],a — stat word, HIGH byte
    inc esi
    mov bh, al                              ; ld b, a
    mov al, [ebp + hDividend + 3]
    mov [ebp + esi], al                     ; ld [hl],a  — stat word, LOW byte
    or al, bh                               ; or b — ZF = the whole word is 0
    jnz .done                               ; jr nz
    inc byte [ebp + esi]                    ; inc [hl] — a 0 stat becomes 1
.done:
    pop ebx                                 ; pop bc
    ret

; ===========================================================================
; DoubleOrHalveSelectedStats — pret core.asm:6449. Two far calls and nothing
; else; the bodies live in the pret-mirrored
; src/engine/battle/unused_stats_functions.asm.
;
; PORTED 2026-08-12 (battle plan 3d). It was a ret-only STUB in
; battle_exp_stubs.asm because both callees read `missing`. Its one caller is
; ItemUseMedicine, which invokes it after curing the ACTIVE battler so the
; in-battle stat copy re-applies any Reflect/Light Screen doubling — a path that
; only became reachable when the in-battle ITEM menu landed (plan item 2c), and
; which the plan's ordering rule blocked this box on until then.
;
; DEVIATION{class=banking; pret=engine/battle/core.asm:DoubleOrHalveSelectedStats; behavior=the callfar and jpfar are a plain call and a plain tail jump; evidence=the port has one flat address space so a far call is an ordinary call and jpfar is jmp - the same standing convention ScrollTrainerPicAfterBattle below and SwitchPlayerMon already carry; lifetime=permanent while the port is flat-addressed}
; ===========================================================================
DoubleOrHalveSelectedStats:
    call DoubleSelectedStats            ; pret: callfar
    jmp HalveSelectedStats              ; pret: jpfar (tail)

; ===========================================================================
; ScrollTrainerPicAfterBattle — pret core.asm:6453 (`jpfar
; _ScrollTrainerPicAfterBattle`). The port has one flat address space, so the
; far-call thunk is a plain tail jump; the body lives in its own pret-mirrored
; file, src/engine/battle/scroll_draw_trainer_pic.asm.
; ===========================================================================
ScrollTrainerPicAfterBattle:
    jmp _ScrollTrainerPicAfterBattle

; ===========================================================================
; TrainerBattleVictory — pret core.asm:929. Victory music, "<TRAINER> was
; defeated!", the trainer pic scrolling back in, the class-specific end-battle
; text, then the prize money. wAmountMoneyWon was computed by ReadTrainer at
; battle start.
;
; RESTORED 2026-08-11 (battle plan 1d). The body previously printed only
; MoneyForWinningText and carried a `TODO-HW` claiming PlayBattleVictoryMusic,
; ScrollTrainerPicAfterBattle and TrainerDefeatedText were unavailable. Two of
; those three claims were FALSE when measured: PlayBattleVictoryMusic is a
; translated routine in this very file, and TrainerDefeatedText IS generated
; into assets/battle_text.inc (line 473), which core.asm %includes. Only
; ScrollTrainerPicAfterBattle was genuinely absent — `label_status` read
; `missing` for both _ScrollTrainerPicAfterBattle and DrawTrainerPicColumn — and
; it is ported now. `faithdiff TrainerBattleVictory` read 7 pret / 2 port before
; this change.
; ===========================================================================
TrainerBattleVictory:
    call EndLowHealthAlarm
    mov bh, MUSIC_DEFEATED_GYM_LEADER              ; ld b, MUSIC_DEFEATED_GYM_LEADER
    cmp byte [ebp + wGymLeaderNo], 0               ; ld a,[wGymLeaderNo] / and a
    jnz .gymleader
    mov bh, MUSIC_DEFEATED_TRAINER
.gymleader:
    mov al, [ebp + wTrainerClass]
    cmp al, RIVAL3                                 ; final battle against rival
    jnz .notrival
    mov bh, MUSIC_DEFEATED_GYM_LEADER
    ; ld hl, wStatusFlags7 / set BIT_NO_MAP_MUSIC, [hl]
    or byte [ebp + wStatusFlags7], 1 << BIT_NO_MAP_MUSIC
.notrival:
    ; ld a,[wLinkState] / cp LINK_STATE_BATTLING / ld a,b / call nz, ...
    ; `mov al, bh` sets no flags, exactly as pret's `ld a, b` — the ZF the
    ; conditional call reads is still the one `cmp` produced.
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    mov al, bh
    jz .noVictoryMusic
    call PlayBattleVictoryMusic
.noVictoryMusic:
    ; Only the TEXT/ANIMATION waits are gated below — the link-state early
    ; return stays on both builds so the guard cannot change which battles award
    ; prize money. Harness-only: the Stage-1b state oracle has no input driver,
    ; so it must not park in an acknowledgement wait; it stops at the same
    ; post-victory arithmetic boundary the production path reaches.
%ifndef DEBUG_TRAINER_RESULT
    mov eax, TrainerDefeatedText
    call PrintBattleText
%endif
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    jz .ret                                        ; pret: ret z (link battle ends here)
%ifndef DEBUG_TRAINER_RESULT
    call ScrollTrainerPicAfterBattle
    mov bl, 40                                     ; ld c, 40
    call DelayFrames
    call PrintEndBattleText                        ; class-specific "<TRAINER>: …"
    mov eax, MoneyForWinningText
    call PrintBattleText
%endif
    ; win money: wPlayerMoney += wAmountMoneyWon (3-byte BCD). pret:
    ;   ld de, wPlayerMoney+2 / ld hl, wAmountMoneyWon+2 / ld c,3 / predef AddBCDPredef.
    ; Flat call to AddBCD (predef bank drop, §2 item 4): ESI=src LSB, EDX=dst LSB, CL=count.
    mov esi, wAmountMoneyWon + 2
    mov edx, wPlayerMoney + 2
    mov cl, 3
    call AddBCD
    mov byte [ebp + wBattleResult], 0              ; player won
    ret
.ret:
    ; pret's `ret z` on LINK_STATE_BATTLING: a link battle ends here with no
    ; prize money. Port-only addition on this path: the wBattleResult store
    ; above is not pret's (pret sets it elsewhere), so it is deliberately NOT
    ; duplicated here — this arm mirrors pret's bare `ret`.
    ret

; --- was src/engine/battle/faint_leaves.asm ---

; ---------------------------------------------------------------------------
; AnyEnemyPokemonAliveCheck — pret engine/battle/core.asm:883-898
;
; Loops wEnemyPartyCount times over the enemy party, OR-ing the big-endian HP
; word (2 bytes) of each mon at stride PARTYMON_STRUCT_LENGTH into AL. Returns
; with ZF set from that accumulated AL (pret: `and a` / `ret` — ZF=1 means
; every enemy mon's HP bytes were all zero, i.e. every mon has fainted; ZF=0
; means at least one enemy mon is still alive). Caller is expected to
; `jz`/`jnz` on return, per pret's "stores whether enemy ran in Z flag"-style
; contract used throughout core.asm.
;
; In:  wEnemyPartyCount, wEnemyMon1HP..HP array (WRAM only). No caller-set
;      registers required (pure GB-memory loop).
; Out: ZF = all-fainted flag (1 = all fainted, matches pret `and a`/ret).
;      AL clobbered (final OR accumulator, no defined meaning beyond ZF).
;      ESI, ECX clobbered. EBX/EDX untouched.
; ---------------------------------------------------------------------------
AnyEnemyPokemonAliveCheck:
    movzx ecx, byte [ebp + wEnemyPartyCount]   ; ld a,[wEnemyPartyCount] / ld b,a
    xor al, al                                 ; xor a
    mov esi, wEnemyMon1HP                      ; ld hl, wEnemyMon1HP (raw GB offset)
.nextPokemon:
    or al, [ebp + esi]                         ; or [hl]
    inc esi                                    ; inc hl
    or al, [ebp + esi]                         ; or [hl]
    dec esi                                    ; dec hl
    add esi, PARTYMON_STRUCT_LENGTH            ; add hl, de (de was a compile-time constant)
    ; FIXED at integration: pret's counter is the 8-bit B (`dec b`), so a 0 count
    ; (a wild battle: wEnemyPartyCount==0) wraps at 256 and stays inside GB RAM — benign.
    ; This was widened to 32-bit `dec ecx`, so count 0 → ~4 billion iterations, walking
    ; ESI off the ~96 KB allocation → page fault. Restore pret's 8-bit wrap with `dec cl`
    ; (matches the sibling ChooseNextMon's `dec bl`). Reached only via a wild faint that
    ; shouldn't hit this routine at all — see the wIsInBattle-guard TODO below.
    dec cl                                     ; dec b (8-bit: count 0 wraps at 256, bounded)
    jnz .nextPokemon                           ; jr nz, .nextPokemon
    test al, al                                ; and a — sets ZF from AL, AL unchanged
    ret

; ---------------------------------------------------------------------------
; LoadBattleMonFromParty — pret engine/battle/core.asm:1667-1708
; "copies from party data to battle mon data when sending out a new player mon"
;
; Faithful chunked copy. GEN-2 FORWARD-COMPAT (CLAUDE.md, load-bearing): the
; party struct's offset 7 (MON_CATCH_RATE, aka held-item slot after a Gen1<->
; Gen2 trade) must never be clobbered by this routine. It never is: every
; CopyData call below only *reads* the party struct as a source; the byte at
; source offset 7 is read (as part of the first 12-byte species..moves chunk,
; core.asm:1673-1674) but never written back into the party struct. The
; `add hl, MON_DVS - MON_OTID` (core.asm:1675-1676) skips the source cursor
; over the party-only OTID/Exp/StatExp region (offsets 12-26, absent from the
; battle-mon struct) so the *next* chunk copy resumes at the party struct's
; DVs field (offset 27) — it does not re-touch offset 7. Preserved exactly,
; chunk-for-chunk, per the task brief: do not collapse this into one copy.
;
; In:  wWhichPokemon = party index of the mon being sent out (WRAM only).
;      No caller-set registers required.
; Out: wBattleMon* struct populated; wCurSpecies/wMonHeader set via
;      GetMonHeader; wPlayerMonUnmodifiedLevel..stats block set; burn/
;      paralysis + badge boosts applied; wPlayerMonAttackMod..(+7) reset to
;      the default stat modifier ($7). All GP registers clobbered (matches
;      pret: no register state is preserved across this routine acting as a
;      call boundary with several nested calls).
; ---------------------------------------------------------------------------
LoadBattleMonFromParty:
    ; --- hl = wPartyMon1Species + wWhichPokemon * PARTYMON_STRUCT_LENGTH ---
    mov al, [ebp + wWhichPokemon]              ; ld a, [wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH              ; ld bc, PARTYMON_STRUCT_LENGTH
    mov esi, wPartyMon1Species                  ; ld hl, wPartyMon1Species
    call AddNTimes                              ; hl = party mon base (raw GB offset)

    ; --- species..moves (12 bytes, core.asm:1673-1674) — includes offset 7
    ;     (MON_CATCH_RATE) as a READ-ONLY source byte; see header note. ---
    mov edx, wBattleMonSpecies                  ; ld de, wBattleMonSpecies
    mov bx, wBattleMonDVs - wBattleMonSpecies    ; ld bc, wBattleMonDVs - wBattleMonSpecies
    call CopyData                                ; hl/de both advance by 12

    ; --- skip party-only OTID/Exp/StatExp (core.asm:1675-1676) ---
    add esi, MON_DVS - MON_OTID                  ; ld bc, MON_DVS - MON_OTID / add hl, bc

    ; --- DVs word (core.asm:1677-1679) ---
    mov edx, wBattleMonDVs                       ; ld de, wBattleMonDVs
    mov bx, MON_PP - MON_DVS                     ; ld bc, MON_PP - MON_DVS
    call CopyData

    ; --- PP, 4 bytes (core.asm:1680-1682) ---
    mov edx, wBattleMonPP                        ; ld de, wBattleMonPP
    mov bx, NUM_MOVES                            ; ld bc, NUM_MOVES
    call CopyData

    ; --- Level + 5 stats, 11 bytes (core.asm:1683-1685) ---
    mov edx, wBattleMonLevel                     ; ld de, wBattleMonLevel
    mov bx, wBattleMonPP - wBattleMonLevel        ; ld bc, wBattleMonPP - wBattleMonLevel
    call CopyData

    ; --- header lookup: wCurSpecies = wBattleMonSpecies2; call GetMonHeader ---
    mov al, [ebp + wBattleMonSpecies2]           ; ld a, [wBattleMonSpecies2]
    mov [ebp + wCurSpecies], al                  ; ld [wCurSpecies], a
    call GetMonHeader

    ; --- nickname copy: skip wPlayerMonNumber NAME_LENGTH entries, then copy ---
    mov esi, wPartyMonNicks                      ; ld hl, wPartyMonNicks
    mov al, [ebp + wPlayerMonNumber]             ; ld a, [wPlayerMonNumber]
    call SkipFixedLengthTextEntries              ; hl += NAME_LENGTH * a
    mov edx, wBattleMonNick                      ; ld de, wBattleMonNick
    mov bx, NAME_LENGTH                          ; ld bc, NAME_LENGTH
    call CopyData

    ; --- snapshot unmodified level+stats block (1 + NUM_STATS*2 bytes) ---
    mov esi, wBattleMonLevel                     ; ld hl, wBattleMonLevel
    mov edx, wPlayerMonUnmodifiedLevel            ; ld de, wPlayerMonUnmodifiedLevel
    mov bx, 1 + NUM_STATS * 2                    ; ld bc, 1 + NUM_STATS * 2
    call CopyData

    ; --- burn/paralysis penalties + badge boosts ---
    call ApplyBurnAndParalysisPenaltiesToPlayer
    call ApplyBadgeStatBoosts

    ; --- reset the 8 stat mods (wPlayerMonAttackMod..) to the default $7 ---
    mov al, 7                                    ; ld a, $7
    mov ecx, NUM_STAT_MODS                       ; ld b, NUM_STAT_MODS
    mov esi, wPlayerMonAttackMod                  ; ld hl, wPlayerMonAttackMod
.statModLoop:
    mov [ebp + esi], al                          ; ld [hli], a
    inc esi
    dec ecx                                      ; dec b
    jnz .statModLoop                             ; jr nz, .statModLoop
    ret

; --- was src/engine/battle/residual_damage.asm ---

; ===========================================================================
; HandlePoisonBurnLeechSeed
;
; Called at end of each turn to apply Poison/Burn/Leech-Seed residual damage.
; hWhoseTurn selects which mon's residuals are processed:
;   0 = player's turn → process player mon's residuals (wBattleMonHP/Status)
;   1 = enemy's turn  → process enemy mon's residuals  (wEnemyMonHP/Status)
;
; Returns: ZF=0, AL≠0  — mon still alive
;          ZF=1, AL=0  — mon fainted (HP became 0)
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed (line 479)
; ===========================================================================
HandlePoisonBurnLeechSeed:
    ; Select HP pointer (ESI=HL) and status byte address (EDX=DE).
    mov esi, wBattleMonHP
    mov edx, wBattleMonStatus
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn
    mov esi, wEnemyMonHP
    mov edx, wEnemyMonStatus
.playersTurn:

    ; ── Burn / Poison check ─────────────────────────────────────────────────
    mov al, [ebp + edx]
    and al, (1 << BRN) | (1 << PSN)
    jz .notBurnedOrPoisoned

    ; Select text label: default to poison text, override to burn if BRN bit set.
    ; (pret loads HurtByPoisonText first, then conditionally overwrites with
    ;  HurtByBurnText if the BRN flag is present — BRN bit is higher than PSN.)
    push esi                        ; save HP pointer around PrintText call
    mov esi, HurtByPoisonText
    mov al, [ebp + edx]
    test al, (1 << BRN)
    jz .poisoned
    mov esi, HurtByBurnText
.poisoned:
    call PrintText                  ; deferred UI — print hurt-by-burn/poison text

    ; Play burn/poison animation (wAnimationType=0 = move animation type).
    xor al, al
    mov [ebp + wAnimationType], al
    mov al, BURN_PSN_ANIM
    call PlayMoveAnimation          ; deferred UI — AL = animation ID

    pop esi                         ; restore HP pointer
    call HandlePoisonBurnLeechSeed_DecreaseOwnHP

.notBurnedOrPoisoned:
    ; ── Leech Seed check (SEEDED = bit 7 of wPlayer/EnemyBattleStatus2) ────
    ; pret: ld de, wPlayerBattleStatus2/wEnemyBattleStatus2 based on hWhoseTurn,
    ;       then "add a" (shifts SEEDED bit 7 into carry).
    mov edx, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn2
    mov edx, wEnemyBattleStatus2
.playersTurn2:
    test byte [ebp + edx], (1 << SEEDED)
    jz .notLeechSeeded

    ; Flip hWhoseTurn so the ABSORB animation fires from the seeder's side,
    ; then restore it before the drain math.
    push esi                        ; save HP pointer
    mov al, [ebp + hWhoseTurn]
    push eax                        ; save hWhoseTurn across animation
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; flip turn for the animation
    xor al, al
    mov [ebp + wAnimationType], al
    mov al, ABSORB
    call PlayMoveAnimation          ; deferred UI — Leech Seed animation
    pop eax                         ; restore saved hWhoseTurn (low byte = value)
    mov [ebp + hWhoseTurn], al
    pop esi                         ; restore HP pointer

    ; Drain the seeded mon (BX = drain amount on return).
    ; GLITCH{class=data-model; pret=engine/battle/core.asm:HandlePoisonBurnLeechSeed; behavior=the Leech Seed call increments Toxic's counter a second time in the same turn; evidence=pret call flow into DecreaseOwnHP; lifetime=permanent Gen-1 behavior; safety=bounded WRAM arithmetic with no ACE potential under DPMI}
    ; If the mon is also Badly Poisoned, the toxic counter is incremented
    ; here too, scaling the drain by the (now twice-bumped) counter.
    call HandlePoisonBurnLeechSeed_DecreaseOwnHP
    ; GLITCH{class=data-model; pret=engine/battle/core.asm:HandlePoisonBurnLeechSeed_IncreaseEnemyHP; behavior=BX can exceed actual HP taken and over-heal the seeder; evidence=pret uncapped BC handoff between decrease and increase helpers; lifetime=permanent Gen-1 behavior; safety=bounded WRAM arithmetic with no ACE potential under DPMI}
    ; Overkill heal: BX may exceed actual HP taken if HP was < 1/16 maxHP.
    call HandlePoisonBurnLeechSeed_IncreaseEnemyHP  ; heals seeder by BX

    push esi
    mov esi, HurtByLeechSeedText
    call PrintText                  ; deferred UI
    pop esi                         ; restore HP pointer

.notLeechSeeded:
    ; ── Faint check ─────────────────────────────────────────────────────────
    ; pret: ld a, [hli] / or [hl] — test whether the current-mon HP is zero.
    ; ESI = hp_ptr (wBattleMonHP or wEnemyMonHP), pointing to HP high byte.
    mov al, [ebp + esi]             ; HP high byte
    or al, [ebp + esi + 1]          ; OR with HP low byte
    ; pret: ret nz (return if ZF=0 → alive). x86 has no conditional ret.
    jz .fainted
    ret                             ; HP > 0: alive — ZF=0, AL≠0
.fainted:
    ; HP == 0: mon fainted.
    call DrawHUDsAndHPBars          ; deferred UI — redraw HUDs
    mov bl, 20
    call DelayFrames                ; deferred UI — delay 20 frames
    xor al, al                      ; ZF=1, AL=0 → caller sees "fainted"
    ret

; ===========================================================================
; HandlePoisonBurnLeechSeed_DecreaseOwnHP
;
; Decreases the current mon's HP by 1/16 of its maxHP (min 1).
; If the mon has BADLY_POISONED (Toxic), the toxic counter is incremented and
; the per-tick damage is multiplied by the new counter value.
;
; On entry:  ESI = GB address of the mon's current HP high byte.
; On return: BX  = total damage applied (or uncapped amount if HP was < drain);
;            ESI = restored to entry value (HP pointer).
; Clobbers:  EAX, EDX, EDI (EDI used as 16-bit accumulator for toxic multiply).
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed_DecreaseOwnHP (line 559)
; ===========================================================================
HandlePoisonBurnLeechSeed_DecreaseOwnHP:
    push esi                        ; push #1 — caller's HP pointer restore
    push esi                        ; push #2 — HP pointer for subtraction section

    ; ── Read MaxHP (big-endian 16-bit at hp_ptr + 14) ───────────────────────
    ; wBattleMonHP + 0xE = wBattleMonMaxHP; same gap for the enemy side.
    add esi, 0xE                    ; ESI → MaxHP high byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP + 1], al ; scratch (pret: ld [wHPBarMaxHP+1], a)
    mov bh, al                      ; BH = MaxHP high byte
    inc esi                         ; ESI → MaxHP low byte
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP], al     ; scratch (pret: ld [wHPBarMaxHP], a)
    mov bl, al                      ; BL = MaxHP low byte
    ; BX = MaxHP (BH:BL big-endian)

    ; ── Compute base damage = MaxHP / 16 ────────────────────────────────────
    ; pret: two 16-bit right-shifts (srl b / rr c pairs) then two BL-only shifts.
    ; For MaxHP < 1024: after the two 16-bit shifts BH = 0; result lives in BL.
    shr bh, 1
    rcr bl, 1
    shr bh, 1
    rcr bl, 1                       ; BX >>= 2 (16-bit; BH = 0 for MaxHP < 1024)
    shr bl, 1
    shr bl, 1                       ; BL >>= 2 more → BL = MaxHP / 16, BH = 0

    ; Minimum damage is 1 (pret: inc c if c == 0)
    test bl, bl
    jnz .nonZeroDamage
    mov bl, 1
.nonZeroDamage:
    ; BX = (BH=0, BL=per-tick damage)

    ; ── Toxic counter check and multiply ────────────────────────────────────
    ; pret selects the BADLY_POISONED flag from wPlayer/EnemyBattleStatus3
    ; and the toxic counter from wPlayer/EnemyToxicCounter based on hWhoseTurn.
    ; GLITCH{class=data-model; pret=engine/battle/core.asm:HandlePoisonBurnLeechSeed_DecreaseOwnHP; behavior=Toxic multiplication executes for Leech Seed as well as poison and burn; evidence=pret shared helper branch; lifetime=permanent Gen-1 behavior; safety=bounded WRAM arithmetic with no ACE potential under DPMI}
    ; This branch executes even when called from the Leech Seed path,
    ; causing the toxic counter to scale Leech Seed drain too.
    mov esi, wPlayerBattleStatus3
    mov edx, wPlayerToxicCounter
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn_toxic
    mov esi, wEnemyBattleStatus3
    mov edx, wEnemyToxicCounter
.playersTurn_toxic:
    test byte [ebp + esi], (1 << BADLY_POISONED)
    jz .noToxic

    ; Increment the toxic counter (pret: ld a, [de] / inc a / ld [de], a).
    mov al, [ebp + edx]
    inc al
    mov [ebp + edx], al             ; save incremented counter

    ; Multiply base damage BX by the counter (AL) via repeated addition:
    ; pret: ld hl, 0 / .loop: add hl, bc / dec a / jr nz / ld b, h / ld c, l
    ; Use EDI as the 16-bit HL accumulator (pushed to avoid clobbering caller).
    push edi
    xor edi, edi                    ; EDI = 0 (HL accumulator)
.toxicTicksLoop:
    add di, bx                      ; DI += BX (16-bit; pret: add hl, bc)
    dec al
    jnz .toxicTicksLoop
    movzx ebx, di                   ; BX = total damage (pret: ld b, h / ld c, l)
    pop edi

.noToxic:
    ; BX = total damage (BH:BL, 16-bit)

    ; ── Subtract damage from current HP ─────────────────────────────────────
    pop esi                         ; pop #2 → ESI = original HP ptr (high byte)
    inc esi                         ; ESI → HP low byte (pret: inc hl)

    ; Subtract low byte (pret: ld a, [hl] / sub c / ld [hld], a):
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP], al     ; save old HP low byte
    sub al, bl                      ; HP_low -= damage_low
    mov [ebp + esi], al             ; store new HP_low (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al     ; save new HP low byte
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)

    ; Subtract high byte with borrow (pret: ld a, [hl] / sbc b / ld [hl], a):
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP + 1], al ; save old HP high byte
    sbb al, bh                      ; HP_high -= damage_high + borrow
    mov [ebp + esi], al             ; store new HP high byte
    mov [ebp + wHPBarNewHP + 1], al

    ; Overkill check (carry = result was negative):
    jnc .noOverkill
    ; Zero HP (pret: xor a / ld [hli], a / ld [hl], a):
    xor al, al
    mov [ebp + esi], al             ; zero HP high byte
    inc esi                         ; ESI → HP low byte (pret: [hli] auto-inc)
    mov [ebp + esi], al             ; zero HP low byte
    mov [ebp + wHPBarNewHP], al
    mov [ebp + wHPBarNewHP + 1], al
    dec esi                         ; restore ESI to HP high byte
    ; BX still holds uncapped damage (see Leech Seed overkill GLITCH in header)
.noOverkill:

    ; Update HP bar (pret: UpdateCurMonHPBar, which does push bc / pop bc).
    ; Push BX for safety in case the deferred impl forgets the pret contract.
    push ebx
    call UpdateCurMonHPBar          ; deferred UI
    pop ebx

    pop esi                         ; pop #1 → ESI = original HP ptr (for caller)
    ret

; ===========================================================================
; HandlePoisonBurnLeechSeed_IncreaseEnemyHP
;
; Heals the opposing mon (the Leech Seed attacker) by BX (the drain amount
; computed by DecreaseOwnHP). Caps at MaxHP.
;
; On entry:  ESI = seeded mon's HP pointer (caller's HL, pushed/restored here).
;            BX  = drain amount (from DecreaseOwnHP).
;            hWhoseTurn: 0 = player's turn → heal enemy; 1 = enemy's turn → heal player.
; On return: ESI = restored (caller's HP pointer).
;
; pret: engine/battle/core.asm:HandlePoisonBurnLeechSeed_IncreaseEnemyHP (line 627)
; ===========================================================================
HandlePoisonBurnLeechSeed_IncreaseEnemyHP:
    push esi                        ; save caller's HP pointer (seeded mon's)

    ; ── Select MaxHP pointer for the healing side ────────────────────────────
    ; pret: player's turn → heal enemy (wEnemyMonMaxHP);
    ;       enemy's turn  → heal player (wBattleMonMaxHP).
    mov esi, wEnemyMonMaxHP
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playersTurn_heal
    mov esi, wBattleMonMaxHP
.playersTurn_heal:

    ; ── Read MaxHP of the healing mon ───────────────────────────────────────
    ; pret: ld a, [hli] (high byte → [wHPBarMaxHP+1], HL++);
    ;       ld a, [hl]  (low byte  → [wHPBarMaxHP],   HL stays).
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP + 1], al ; MaxHP high byte to scratch
    inc esi                         ; ESI → MaxHP low byte (pret: [hli] auto-inc)
    mov al, [ebp + esi]
    mov [ebp + wHPBarMaxHP], al     ; MaxHP low byte to scratch

    ; ── Navigate from MaxHP+1 to HP low byte ────────────────────────────────
    ; pret: ld de, wBattleMonHP - wBattleMonMaxHP = -14
    ;       add hl, de → HL = (MaxHP_low address) - 14 = HP_low address.
    ; The gap is the same for both sides:
    ;   wBattleMonHP (0xD014) - wBattleMonMaxHP (0xD022) = -14
    ;   wEnemyMonHP  (0xCFE5) - wEnemyMonMaxHP  (0xCFF3) = -14  (then +1 = HP_low)
    ; After ld a,[hli] ESI is at MaxHP_low (+1 from MaxHP base); -14 → HP_low.
    sub esi, 14                     ; ESI → HP low byte of the healing mon

    ; ── Add BX (drain amount) to current HP ─────────────────────────────────
    ; pret: ld a,[hl] / add c / ld [hld],a ; ld a,[hl] / adc b / ld [hli],a
    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP], al     ; old HP low byte
    add al, bl                      ; HP_low += damage_low (pret: add c)
    mov [ebp + esi], al             ; store new HP_low (pret: ld [hld], a)
    mov [ebp + wHPBarNewHP], al
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)

    mov al, [ebp + esi]
    mov [ebp + wHPBarOldHP + 1], al ; old HP high byte
    adc al, bh                      ; HP_high += damage_high + carry (pret: adc b)
    mov [ebp + esi], al             ; store new HP_high (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al
    inc esi                         ; ESI → HP low byte again (pret: [hli] auto-inc)

    ; ── Overheal clamp: if new HP > MaxHP, set HP = MaxHP ───────────────────
    ; pret reads MaxHP from the wHPBarMaxHP scratch (stored above), loads new HP
    ; from memory, then does a 16-bit subtraction to detect overflow.
    ; If HP - MaxHP >= 0 (no borrow), HP is >= MaxHP → clamp.
    mov al, [ebp + esi]             ; new HP low byte (pret: ld a, [hld])
    sub al, [ebp + wHPBarMaxHP]     ; HP_low - MaxHP_low (pret: sub c)
    dec esi                         ; ESI → HP high byte (pret: [hld] auto-dec)
    mov al, [ebp + esi]             ; new HP high byte (pret: ld a, [hl])
    sbb al, [ebp + wHPBarMaxHP + 1] ; HP_high - MaxHP_high - borrow (pret: sbc b)
    jc .noOverfullHeal              ; carry set → HP < MaxHP, no clamp

    ; Clamp HP to MaxHP (pret: ld a, b / ld [hli], a / ld a, c / ld [hl], a):
    mov al, [ebp + wHPBarMaxHP + 1] ; MaxHP high byte (pret: ld a, b)
    mov [ebp + esi], al             ; store to HP high byte (pret: ld [hli], a)
    mov [ebp + wHPBarNewHP + 1], al
    inc esi                         ; ESI → HP low byte
    mov al, [ebp + wHPBarMaxHP]     ; MaxHP low byte (pret: ld a, c)
    mov [ebp + esi], al             ; store to HP low byte
    mov [ebp + wHPBarNewHP], al
.noOverfullHeal:

    ; ── Update HP bar for the healing side ──────────────────────────────────
    ; pret flips hWhoseTurn so UpdateCurMonHPBar draws the correct (healed) side.
    mov al, [ebp + hWhoseTurn]
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; flip turn (pret: ldh a,[hWhoseTurn] / xor $1)
    call UpdateCurMonHPBar          ; deferred UI
    mov al, [ebp + hWhoseTurn]
    xor al, 1
    mov [ebp + hWhoseTurn], al      ; restore turn

    pop esi                         ; restore caller's HP pointer
    ret

; --- was src/engine/battle/mirror_move.asm ---

; wEnemyMon1PP now lives in gb_memmap.inc (0xD8C0) — added during integration.

; ===========================================================================
; MirrorMoveCopyMove — pret core.asm:5132. Copies the target's last-used move
; (wEnemyUsedMove on the player's turn, wPlayerUsedMove on the enemy's turn)
; into the acting side's SelectedMove slot, then tail-jumps into ReloadMoveData.
; Fails (AL=0, ZF=1) if the target hasn't used a move yet, or if the target's
; last move was Mirror Move itself (Gen-1: Mirror Move can't mirror Mirror Move).
; Out: ZF=1 -> failed (caller: jz ExecutePlayerMoveDone); ZF=0 -> success,
;      control passed into ReloadMoveData (falls through / tail-jumps).
; ===========================================================================
MirrorMoveCopyMove:
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a  (ZF tested below; not clobbered by
                                          ;         the plain `mov`s that follow)
    ; values for player turn
    mov al, [ebp + wEnemyUsedMove]      ; ld a, [wEnemyUsedMove]
    mov esi, wPlayerSelectedMove        ; ld hl, wPlayerSelectedMove
    mov edx, wPlayerMoveNum             ; ld de, wPlayerMoveNum
    jz .next                            ; jr z, .next
    ; values for enemy turn
    mov al, [ebp + wPlayerUsedMove]     ; ld a, [wPlayerUsedMove]
    mov edx, wEnemyMoveNum              ; ld de, wEnemyMoveNum
    mov esi, wEnemySelectedMove         ; ld hl, wEnemySelectedMove
.next:
    mov [ebp + esi], al                 ; ld [hl], a
    cmp al, MIRROR_MOVE                 ; did the target last use Mirror Move (and miss)?
    je .mirrorMoveFailed                ; jr z, .mirrorMoveFailed
    test al, al                         ; and a — has the target selected any move yet?
    jnz ReloadMoveData                  ; jr nz, ReloadMoveData (tail jump)
.mirrorMoveFailed:
    mov esi, MirrorMoveFailedText       ; ld hl, MirrorMoveFailedText
    call PrintText
    xor al, al                          ; xor a  (AL=0, ZF=1 -> failure)
    ret

; ===========================================================================
; ReloadMoveData — pret core.asm:5167. Reloads move [AL]'s (1-based id) 6-byte
; record into the struct at [EDX] (wPlayerMoveNum/wEnemyMoveNum), restores its
; PP (IncrementMovePP), and reloads its name into wStringBuffer. Shared tail
; target for MirrorMoveCopyMove and MetronomePickMove (scratch/metronome.asm).
; In:  AL = move id (1-based), EDX = dest struct offset.
; Out: AL=1, ZF=0 (success). ESI/EDX left advanced past the copied range.
; ===========================================================================
ReloadMoveData:
    mov [ebp + wNamedObjectIndex], al   ; ld [wNamedObjectIndex], a
    dec al                              ; dec a
    mov esi, Moves                      ; ld hl, Moves  (flat program-image table)
    mov bx, MOVE_LENGTH                 ; ld bc, MOVE_LENGTH
    call AddNTimes                      ; esi = Moves + (id-1)*MOVE_LENGTH  (flat; AddNTimes
                                          ; does a plain `add esi,ecx` — no EBP bias — so it's
                                          ; safe to use on this flat pointer, exactly as
                                          ; names.asm:GetMonName does for the flat MonsterNames
                                          ; table)
    ; ALLOWLIST (§2 item 4, bank switching): pret does `ld a, BANK(Moves)` here before
    ; FarCopyData. The flat DPMI model has no ROM banks, so that load is dropped entirely
    ; (nothing to translate it into).
    ;
    ; DIVERGENCE (forced by the above, not itself allowlisted — reported per ticket):
    ; pret's next step is `call FarCopyData` (copy MOVE_LENGTH bytes a:HL -> DE). This
    ; port's FarCopyData/CopyData (src/home/copy.asm) both do `lea esi, [ebp+esi]`
    ; on the SOURCE: they assume the source is a GB-space offset relative to EBP. `Moves`
    ; is a FLAT program-image label (data/pokemon_data.asm / assets/moves.inc), not a GB
    ; WRAM offset — the identical situation already documented and solved in
    ; get_current_move.asm's "Flat-source note" for this same Moves table. Calling
    ; FarCopyData on the ESI computed above would compute [ebp + (Moves+offset)],
    ; double-counting the bias and copying garbage. So, exactly as get_current_move.asm
    ; already does, this uses an inline flat-src -> WRAM-dst byte copy instead of
    ; FarCopyData/CopyData.
    push ecx
    mov ecx, MOVE_LENGTH
.copy:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .copy
    pop ecx
    ; the following two calls are used to reload the move's PP and name
    call IncrementMovePP
    call GetMoveName
    ; DIVERGENCE-COMPENSATION (not a bug in this file — a pre-existing gap in the
    ; already-linked GetMoveName): pret's GetMoveName (home/names.asm:129) explicitly
    ; does `ld de, wNameBuffer` right after `call GetName`, so DE is guaranteed to point
    ; at the freshly-loaded name string when the caller (here) falls into
    ; CopyToStringBuffer. The PORT's GetMoveName (dos_port/src/home/names.asm) instead
    ; tail-jumps into GetName (`jmp GetName`) and never sets EDX = wNameBuffer itself
    ; before returning — GetName's own `.walk`/GetMonName paths never touch EDX either.
    ; Left alone, EDX here would still hold the stale wPlayerMoveNum/wEnemyMoveNum offset
    ; from earlier in this routine, and CopyToStringBuffer would copy the wrong bytes.
    ; Set EDX = wNameBuffer explicitly to preserve ReloadMoveData's faithful behavior
    ; without editing names.asm (out of scope for this file).
    mov edx, wNameBuffer
    call CopyToStringBuffer
    mov al, 1                           ; ld a, $01
    test al, al                         ; and a  (AL=1, ZF=0 -> success)
    ret

; ===========================================================================
; IncrementMovePP — pret core.asm:5214. Increments PP for the move at
; [wPlayerMoveListIndex]/[wEnemyMoveListIndex] in BOTH the currently-battling
; copy (wBattleMonPP/wEnemyMonPP) and the underlying party-mon copy
; (wPartyMon1PP/wEnemyMon1PP, offset by the active party position), so that a
; move which runs another move within the same turn (Mirror Move, Metronome)
; doesn't lose 2 PP net.
; ===========================================================================
IncrementMovePP:
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a
    ; values for player turn
    mov esi, wBattleMonPP               ; ld hl, wBattleMonPP
    mov edx, wPartyMon1PP               ; ld de, wPartyMon1PP
    mov al, [ebp + wPlayerMoveListIndex]; ld a, [wPlayerMoveListIndex]
    jz .next                            ; jr z, .next
    ; values for enemy turn
    mov esi, wEnemyMonPP                ; ld hl, wEnemyMonPP
    mov edx, wEnemyMon1PP               ; ld de, wEnemyMon1PP  (derived above)
    mov al, [ebp + wEnemyMoveListIndex] ; ld a, [wEnemyMoveListIndex]
.next:
    mov bh, 0                           ; ld b, $00
    mov bl, al                          ; ld c, a
    movzx ecx, bx                       ; add hl, bc  (16-bit add, zero-extended per
    add esi, ecx                        ;              src/home/move_mon.asm precedent)
    inc byte [ebp + esi]                ; inc [hl]  — battle-mon copy's PP
    mov esi, edx                        ; ld h, d / ld l, e
    add esi, ecx                        ; add hl, bc  (same bc: move-list index)
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    test al, al                         ; and a
    mov al, [ebp + wPlayerMonNumber]    ; ld a, [wPlayerMonNumber]  (value for player turn)
    jz .updatePP                        ; jr z, .updatePP
    mov al, [ebp + wEnemyMonPartyPos]   ; ld a, [wEnemyMonPartyPos]  (value for enemy turn)
.updatePP:
    mov bx, PARTYMON_STRUCT_LENGTH      ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes                      ; esi += PARTYMON_STRUCT_LENGTH * (party position)
    inc byte [ebp + esi]                ; inc [hl]  — party-mon copy's PP
    ret

; --- was src/engine/battle/ghost.asm ---
                                  ; Out: ZF=1 if NOT in bag, ZF=0 if in bag; BH=qty.
                                  ; (Matches pret home/map_objects.asm:IsItemInBag
                                  ; exactly — no polarity adaptation needed.)

; ===========================================================================
; PrintGhostText — pret engine/battle/core.asm:PrintGhostText.
; Prints the "Sacred ash..."/scared flavor text on the player's turn (unless
; frozen/asleep) or the "You're not scaring me!"-style get-out text on the
; ghost's turn, but only during an actual disguised-ghost battle.
; Out: ZF=0 (via IsGhostBattle) if not a ghost battle (no-op, no text printed).
;      Otherwise prints text and returns with ZF=1 (xor a).
; ===========================================================================
PrintGhostText:
    call IsGhostBattle
    jnz .ret                            ; ret nz
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .Ghost                          ; jr nz, .Ghost
    mov al, [ebp + wBattleMonStatus]    ; ld a, [wBattleMonStatus]
    and al, (1 << FRZ) | SLP_MASK       ; = 0x27
    jnz .ret                            ; ret nz
    mov esi, ScaredText                 ; ld hl, ScaredText
    call PrintText
    xor al, al
    ret
.Ghost:
    mov esi, GetOutText                 ; ld hl, GetOutText
    call PrintText
    xor al, al
    ret
.ret:
    ret

; ===========================================================================
; IsGhostBattle — pret engine/battle/core.asm:IsGhostBattle.
; Out: ZF=1 if this IS a disguised-ghost battle; ZF=0 if it is not.
; (wIsInBattle != 1 [not a wild battle], or outside the Pokémon Tower ghost
; floors, or the player holds the Silph Scope → all ZF=0 "not ghost".)
; ===========================================================================
IsGhostBattle:
    mov al, [ebp + wIsInBattle]         ; ld a, [wIsInBattle]
    dec al                              ; dec a
    jnz .ret                            ; ret nz
    mov al, [ebp + wCurMap]             ; ld a, [wCurMap]
    cmp al, 0x8E                        ; cp POKEMON_TOWER_1F
    jb .next                            ; jr c, .next
    cmp al, 0x95                        ; cp POKEMON_TOWER_7F + 1
    jae .next                           ; jr nc, .next
    mov bh, 0x48                        ; ld b, SILPH_SCOPE
    call IsItemInBag
    jz .ret                             ; ret z
.next:
    mov al, 1                           ; ld a, 1
    and al, al                          ; and a
    ret
.ret:
    ret

; --- was src/engine/battle/print_critical_ohko.asm ---
section .data
; STRUCTURAL PORT ADAPTATION: dw->dd flat pointer table (index *2 -> *4).
; pret: CriticalOHKOTextPointers: dw CriticalHitText, dw OHKOText (engine/battle/core.asm)
CriticalOHKOTextPointers:
    dd CriticalHitText
    dd OHKOText

section .text
; ===========================================================================
; PrintCriticalOHKOText — pret engine/battle/core.asm:3967
;
;	ld a, [wCriticalHitOrOHKO]
;	and a
;	jr z, .done
;	dec a
;	add a                    ; *2 (port: *4)
;	ld hl, CriticalOHKOTextPointers
;	ld b, $0
;	ld c, a
;	add hl, bc
;	ld a, [hli]
;	ld h, [hl]
;	ld l, a
;	call PrintText
;	xor a
;	ld [wCriticalHitOrOHKO], a
;.done
;	ld c, 20
;	jp DelayFrames
; ===========================================================================
PrintCriticalOHKOText:
    mov al, [ebp + wCriticalHitOrOHKO]
    and al, al
    jz .done                            ; no crit / no OHKO -> nothing to print
    dec al                              ; a -= 1  (1=crit -> 0, 2=OHKO -> 1)
    movzx eax, al                       ; widen index byte, zero upper bits
    mov esi, [CriticalOHKOTextPointers + eax*4]   ; *4: dd flat-pointer table (was *2 dw in pret)
    call PrintText
    mov byte [ebp + wCriticalHitOrOHKO], 0
.done:
    mov bl, 20                          ; PORT: DelayFrames reads BL, not C
    jmp DelayFrames                     ; tail call (pret: jp DelayFrames)

; ---------------------------------------------------------------------------
; LoadHudTilePatterns — load the battle HUD frame/divider tiles (pret
; engine/battle/core.asm:LoadHudTilePatterns + BattleHudTiles1/2/3). These overwrite
; the font_extra placeholders ("ID No.") at $73/$74 with the real underline/corner
; pieces the HP bar and pokéballs sit on. Source is pret's 1bpp data already expanded
; to 2bpp by the generator (FarCopyDataDouble equivalent):
;   battle_hud_tiles1  (3 tiles) → vChars2 tile $6d ($96d0)
;   battle_hud_tiles23 (6 tiles) → vChars2 tile $73 ($9730)
; Call right after LoadHpBarAndStatusTilePatterns (pret's combined
; LoadHudAndHpBarAndStatusTilePatterns). In: EBP = GB base. All registers preserved.
; ---------------------------------------------------------------------------
section .text
global LoadHudAndHpBarAndStatusTilePatterns
global LoadHudTilePatterns
extern g_tilecache_dirty               ; src/ppu/ppu.asm — tile-cache invalidation flag
extern LoadHpBarAndStatusTilePatterns  ; src/home/load_font.asm

; pret core.asm:6692 — call LoadHpBarAndStatusTilePatterns, then fall through
; into LoadHudTilePatterns.
LoadHudAndHpBarAndStatusTilePatterns:
    call LoadHpBarAndStatusTilePatterns

LoadHudTilePatterns:
    mov byte [g_tilecache_dirty], 1
    push eax
    push ecx
    push esi
    push edi

    mov esi, battle_hud_tiles1_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x6d * TILE_SIZE]
    mov ecx, BATTLE_HUD_TILES1_SIZE / 4
    rep movsd

    mov esi, battle_hud_tiles23_2bpp
    lea edi, [ebp + GB_VCHARS2 + 0x73 * TILE_SIZE]
    mov ecx, BATTLE_HUD_TILES23_SIZE / 4
    rep movsd

    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ===========================================================================
; Consolidated here from the port-only front-end files (relocated-labels grind):
; the two HUD+HP-bar aliases and DrawHUDsAndHPBars came from battle_hud.asm /
; battle_menu.asm, TryRunningFromBattle (with its private PrintRunLine helper)
; from battle_menu.asm. All four are pret engine/battle/core.asm labels and
; belong in this mirror; the draw primitives they tail-call stay behind as the
; sanctioned front-end divergence point.
; ===========================================================================
section .text
global DrawEnemyHUDAndHPBar
global DrawPlayerHUDAndHPBar
global DrawHUDsAndHPBars
global LoadPlayerBackPic
global SlidePlayerAndEnemySilhouettesOnScreen ; pret entry point for the battle-entry slide
extern LoadMonBackPicToVRAM            ; src/home/pics.asm — decode + 2x scale + merge
extern SetBGCellAttrFlat               ; ppu.asm — publish one per-cell BG attribute
; ENEMY_GAUGE_SLOT is 1 because SetPal_Battle publishes wEnemyHPBarColor into
; bg_slot_pal[1] (engine/gfx/palettes.asm); see the publish DEVIATION at
; DrawEnemyHUDAndHPBar's bar draw.
ENEMY_GAUGE_SLOT equ 1
extern SlideBattlePicsIn               ; src/home/pics.asm — the port's slide realization
global TryRunningFromBattle
extern WaitForAPress                   ; src/home/joypad2.asm — alias of pret WaitForTextScrollButtonPress
; (str_gotaway/str_cantesc/str_norun1-3 externs retired 2026-08-06: the run
; messages now print their generated battle_text.inc streams — CantEscapeText /
; NoRunningText / GotAwayText, local via the %include — through PrintBattleText,
; matching pret's PrintText presentation. The runtime strings stay in
; battle_menu_runtime_strings.inc for battle_menu.asm's own consumers.)
extern PlaySoundWaitForCurrent         ; src/home/delay.asm — In: AL = sound id
extern WaitForSoundToFinish            ; src/home/delay.asm
extern StopAllMusic                    ; src/home/audio.asm
extern PlayMusic                       ; src/home/audio.asm
extern StatModifierUpEffect            ; src/engine/battle/effects.asm
extern BuildingRageText                ; dos_port/assets/battle_text.inc
extern EnemyMonFaintedText             ; dos_port/assets/battle_text.inc (global label, battle_text stream)
extern DoesntAffectMonText             ; dos_port/assets/battle_text.inc
extern RunAwayText                     ; dos_port/assets/battle_text.inc
extern AttackMissedText                ; dos_port/assets/battle_text.inc
extern UnaffectedText                  ; dos_port/assets/battle_text.inc
extern KeptGoingAndCrashedText         ; dos_port/assets/battle_text.inc
extern PredefShakeScreenHorizontally   ; src/engine/gfx/screen_effects.asm (live since Stage 3b)
extern AIEnemyTrainerChooseMoves       ; src/engine/battle/trainer_ai.asm — score-adjust the move weights
global FaintEnemyPokemon
global EndLowHealthAlarm
global PlayBattleVictoryMusic
global AnyPartyAlive
global LoadEnemyMonFromParty
global SelectEnemyMove
global PrintMoveFailureText
global HandleCounterMove
global HandleBuildingRage
global MetronomePickMove
global HandleExplodingAnimation
; Carried in with the moved blocks (battle_menu.asm preamble). MSG_LINE1 is the
; same UI_DIALOG_LINE1_OFS this file already calls BTXT_LINE1; DLG_INT(n) is the
; box-relative single-spaced interior row used by the trainer-battle run message.
%define MSG_LINE1    UI_DIALOG_LINE1_OFS
%define DLG_INT(n)   (UI_DIALOG_BOX_OFS + (n) * FW + 1)

; ---------------------------------------------------------------------------
; DrawPlayerHUDAndHPBar — faithful player-ONLY HUD+HP-bar redraw (pret
; engine/battle/core.asm:DrawPlayerHUDAndHPBar). Retires the former bare-ret stub in
; battle_exp_stubs.asm: the player-side
; name+level+HP-bar+frame redraw into wTileMap, so this is the pret-named alias
; (same shape as DrawEnemyHUDAndHPBar above). Same Phase-5 palette / hAutoBGTransfer
; divergences as the enemy-side alias apply.
; ---------------------------------------------------------------------------
; GetBattleHealthBarColor — pret engine/battle/core.asm:GetBattleHealthBarColor.
; In: ESI (pret HL) = flat GB address of the bar's colour byte
;     (wPlayerHPBarColor / wEnemyHPBarColor); DL (pret E) = HP-bar pixels.
;
; It republishes the battle palette ONLY WHEN THE COLOUR ACTUALLY CHANGED. The
; port previously called GetHealthBarColor bare and let DrawHUDsAndHPBars publish
; unconditionally, so it did the palette work on every HUD draw where hardware
; does it on a green->yellow->red transition only. faithdiff reported this as a
; DROPPED GetBattleHealthBarColor on BOTH of pret's call sites.
;
; The old value must be read BEFORE GetHealthBarColor overwrites it — that read
; is the whole routine. BH survives the call (GetHealthBarColor touches only
; DH/DL and [ESI]), which is why pret can keep it in `b` across it.
; ---------------------------------------------------------------------------
GetBattleHealthBarColor:
    mov bh, [ebp + esi]                           ; ld b, [hl] — the OLD colour
    call GetHealthBarColor                        ; writes the new colour to [hl]
    mov al, [ebp + esi]                           ; ld a, [hl]
    cmp al, bh                                    ; cp b
    je .unchanged                                 ; ret z — no transition, no publish
    mov bh, SET_PAL_BATTLE                        ; ld b, SET_PAL_BATTLE
    jmp RunPaletteCommand                         ; jp (tail)
.unchanged:
    ret

; ---------------------------------------------------------------------------
; CenterMonName — pret engine/battle/core.asm:CenterMonName.
; In:  ESI (pret HL) = tilemap offset the name would be placed at
;      EDX (pret DE) = GB address of the nickname
; Out: ESI advanced by 2 / 1 / 0 columns for a name of 1-2 / 3-4 / 5+ chars.
; Clobbers AL and BH, exactly as pret clobbers A and B; EDX is restored.
;
; It counts in PAIRS: `inc de` before each read, so the FIRST character is
; skipped and each loop iteration consumes two more. Two iterations, so it
; stops looking after character 5 — which is why every name of 5 or more
; characters lands at the unshifted coordinate.
;
; `dec bh`, not `dec ebx`: pret's counter is the 8-bit B, preloaded with 2 and
; never entered at 0, so the width is not load-bearing here — but keeping it
; 8-bit keeps the translation exact and costs nothing.
;
; The column step is +/-1 BYTE in the port as it is on the GB: wTileMap is
; row-major with stride FW, so pret's `inc hl` / `dec hl` need no projection.
; ---------------------------------------------------------------------------
CHAR_TERMINATOR equ 0x50               ; '@' — end of a charmap string

CenterMonName:
    push edx                           ; push de
    lea esi, [esi + 2]                 ; inc hl / inc hl
    mov bh, 2                          ; ld b, $2
.loop:
    inc edx                            ; inc de
    mov al, [ebp + edx]                ; ld a, [de]
    cmp al, CHAR_TERMINATOR            ; cp "@"
    je .done                           ; jr z, .done
    inc edx                            ; inc de
    mov al, [ebp + edx]                ; ld a, [de]
    cmp al, CHAR_TERMINATOR            ; cp "@"
    je .done                           ; jr z, .done
    dec esi                            ; dec hl
    dec bh                             ; dec b
    jnz .loop                          ; jr nz, .loop
.done:
    pop edx                            ; pop de
    ret

; ---------------------------------------------------------------------------
; DrawHUDsAndHPBars / DrawPlayerHUDAndHPBar / DrawEnemyHUDAndHPBar — pret
; engine/battle/core.asm:1885/1889/1951. Moved here from the port-only file
; src/engine/battle/battle_hud.asm on 2026-08-13, where the three bodies had
; lived under the port-only names DrawBattleHUDs / DrawPlayerHUD / DrawEnemyHUD
; while this file carried the pret names as bare `jmp` aliases. faithdiff
; therefore saw 9 pret calls against 1 port on each of the two halves and
; attributed the whole body to a name it does not model — the same forked-name
; shape as EnemyMoveHitTest, and the reason CenterMonName and
; GetBattleHealthBarColor read DROPPED at call sites where the call was real.
;
; pret splits the work exactly this way too (DrawHUDsAndHPBars calls the player
; half and tail-jumps the enemy half), so the port's split needed no invention —
; only the names. The battle intro's enemy-only draw, which was the reason the
; port kept a separate entry, is pret's own DrawEnemyHUDAndHPBar and is called
; by that name from _InitBattleCommon.
;
; Both sides now go through pret's shared draw/animate machinery (DrawHP /
; DrawHPBar / UpdateHPBar2): the battle_hud.asm fork engine (calc_hp_pixels,
; draw_enemy_hp_bar, Animate{Player,Enemy}HPBar) was retired 2026-08-15 and the
; file deleted. The one port-only step that survives is the enemy gauge's
; per-cell palette publish, inlined below under its own DEVIATION.
;
; RETIRING THE FORK MADE FOUR REAL DIVERGENCES VISIBLE FOR THE FIRST TIME. They
; are pre-existing, not introduced by the move, and the alias is exactly why
; nothing reported them: faithdiff attributed the body to a port-only name.
; Measured 2026-08-13 with label_status — every one of these callees is
; `translated` and linked, so "not available yet" is NOT the reason for any of
; them, and the alias-era comments that said so were wrong:
;   1. ClearScreenArea (home/copy2.asm) — pret clears the HUD tile area before
;      drawing. The old comment claimed copy2.asm was "not linked here".
;   2. PrintStatusConditionNotFainted + PrintLevel (home/pokemon.asm) — pret
;      prints the status condition and prints the level ONLY when there is
;      none. The old comment blamed "status_ailments.asm is an empty
;      placeholder"; the routine lives in home/pokemon.asm and is translated.
;      The port prints the level unconditionally, via its own print_level.
;   3. DrawHP (predef) / DrawHPBar + Multiply + Divide — FIXED (player side
;      2026-08-13 via DrawHP; enemy side 2026-08-15: pret's inline bar math +
;      DrawHPBar below, with the fork engine deleted).
;   4. The low-health alarm tail — FIXED 2026-08-13, see .fainted below.
; Tracked in docs/current_plan_battle_completion.md under the core.asm-residue
; box.
; ---------------------------------------------------------------------------
DrawHUDsAndHPBars:
    ; HUD names are drawn with PlaceString, which (like pret's PlaceNextChar) calls
    ; PrintLetterDelay — so make sure the per-letter delay is OFF here (BIT_TEXT_DELAY is
    ; set only while a dialog MESSAGE prints). Otherwise the mon names would type out.
    and byte [ebp + wLetterPrintingDelayFlags], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    ; pret DrawHUDsAndHPBars order: PLAYER first, then ENEMY (core.asm:1886).
    ; Load-bearing since the wLoadedMon staging landed: both HUDs write
    ; wLoadedMonLevel, and the surviving value must be the ENEMY's (measured in
    ; the battle_menu golden: wLoadedMon = battle mon, level byte = enemy's).
    call DrawPlayerHUDAndHPBar
    call DrawEnemyHUDAndHPBar
    ; Both bars have now refreshed their color IDs; publish their independent
    ; palette slots together (the enemy gauge takes slot 1 via the per-cell
    ; attribute publish in DrawEnemyHUDAndHPBar — the F-19 tile clones are gone).
    call SetPal_Battle
    ret
DrawPlayerHUDAndHPBar:
    ; ===== player HUD (lower-right) =====
    ; pret DrawPlayerHUDAndHPBar:1893-1894 — `hlcoord 9, 7 / lb bc, 5, 11`.
    ; Restored 2026-08-13; the alias fork had hidden the dropped call, and the
    ; comment that justified it ("home/copy2.asm not linked here") was false.
    ; Without it a previous draw's glyphs survive wherever this draw writes
    ; fewer cells — measured as a stale `:L` at the enemy LV cell once the
    ; status-condition rule started suppressing the level.
    ; PROJ battle: BCOORD is the uniform (X+10, Y+3) battle projection the
    ; generated UI_* layout uses, so the rectangle is pret's, not a new one.
    mov esi, BCOORD(9, 7)
    mov bh, 5                            ; b = rows
    mov bl, 11                           ; c = width
    call ClearScreenArea
    ; pret DrawPlayerHUDAndHPBar draws the frame FIRST: PlacePlayerHUDTiles +
    ; the (18,9) $73 connector, which DrawHP later OVERWRITES with the HP bar's
    ; right cap $6D — pret's second $73 is dead the moment the bar draws. The
    ; port used to draw the frame/connector last, leaving $73 where the golden
    ; shows $6D (F-18). Frame first, bar last, like pret.
    call PlacePlayerHUDTiles
    mov byte [ebp + wTileMap + P_FRAME_CONN], T_HUD_73
    ; pret stages the battle mon in wLoadedMon — species..DVs then level..PP
    ; (core.asm:1903-1910); PrintLevel/DrawHP read it there, and it is
    ; battle-visible WRAM the goldens compare. The enemy HUD (drawn after,
    ; pret order) then overwrites wLoadedMonLevel with the enemy's level.
    mov esi, wBattleMonSpecies
    mov edx, wLoadedMon
    mov ebx, wBattleMonDVs - wBattleMonSpecies
    call CopyData
    mov esi, wBattleMonLevel
    mov edx, wLoadedMonLevel
    mov ebx, wBattleMonPP - wBattleMonLevel
    call CopyData
    ; pret DrawPlayerHUDAndHPBar:1901 runs CenterMonName between the coord load
    ; and PlaceString: a 1-2 letter nick shifts 2 columns right, 3-4 shifts 1,
    ; 5+ is unshifted. The port placed every name flush-left.
    mov esi, wTileMap + P_NAME
    mov edx, wBattleMonNick              ; CenterMonName reads the nick via [ebp+EDX]
    call CenterMonName                   ; adjusts ESI; restores EDX
    lea eax, [ebp + wBattleMonNick]      ; PlaceString src = flat-linear
    call PlaceString
    ; pret DrawPlayerHUDAndHPBar:1913-1918 prints the STATUS CONDITION one cell
    ; right of the level cell, and prints the level ONLY when there is none.
    ; The port printed the level unconditionally; the alias fork hid the dropped
    ; call, and the comment that justified it ("status_ailments.asm is an empty
    ; placeholder") was false — PrintStatusAilment is a complete implementation.
    ; ZF contract: PrintStatusAilment rets Z when the mon is healthy and printed
    ; nothing, and NZ otherwise (its printing tail ends `add esi, 3` on a nonzero
    ; tilemap offset). `pop`/`mov` are flag-neutral, so the flag survives to here
    ; exactly as pret's `pop hl` lets it survive.
    mov edx, wLoadedMonStatus
    mov esi, wTileMap + P_LV + 1        ; pret: hlcoord 14,8 / push hl / inc hl
    call PrintStatusConditionNotFainted
    jnz .doNotPrintLevel                 ; jr nz — status shown, no level
    ; pret :1919 `call PrintLevel`, reading the wLoadedMonLevel the CopyData
    ; above staged. The port used its own print_level, which PADS a one-digit
    ; level with a leading space; pret's PrintNumber runs LEFT_ALIGN, which
    ; writes nothing for a leading zero and does not advance — it relies on the
    ; ClearScreenArea above having blanked the cell. Those two belong together,
    ; which is why this follows the clear rather than preceding it.
    mov esi, wTileMap + P_LV
    call PrintLevel
.doNotPrintLevel:
    ; pret :1922-1926 — `ld a,[wLoadedMonSpecies] / ld [wCurPartySpecies],a /
    ; hlcoord 10,9 / predef DrawHP`. DrawHP draws the gauge AND the cur/max
    ; fraction (one row down, one column right, at [text_row_stride]) and
    ; returns DL = bar pixels, which is exactly what GetBattleHealthBarColor
    ; consumes next — that return is why pret can order them this way.
    ; Replaces the port-only calc_hp_pixels + draw_hp_bar + hud_print_num3
    ; trio. The wLoadedMon staging feeding it is the two CopyDatas above:
    ; MEASURED against pret macros/ram.asm — copy 1 is battle_struct offsets
    ; 0..11 into party_struct 0..11 (same fields, so wLoadedMonHP is right) and
    ; copy 2 is battle_struct Level..Special into party_struct Level..Special
    ; (so wLoadedMonMaxHP at party offset 34 is right). The two structs differ
    ; in the middle, which is why this needed checking rather than assuming.
    mov al, [ebp + wLoadedMonSpecies]
    mov [ebp + wCurPartySpecies], al
    ; DEVIATION{class=projection; pret=engine/battle/core.asm:DrawPlayerHUDAndHPBar; behavior=the battle canvas row stride is republished here before predef DrawHP where pret needs no such step; evidence=the port made DrawHP stride-parameterised through text_row_stride so one routine can serve the 20-wide status and party screens and the 40-wide battle canvas, and DrawHP places the cur/max fraction at bar plus one stride plus one - so whatever stride the last PrintText published decides where the fraction lands, and the bag and item flow leaves it at 20; lifetime=permanent while DrawHP stays stride-parameterised}
    ;
    ; MEASURED 2026-08-13 (run_headless DEBUG_BATTLE_ITEM=1): without this the
    ; potion path drew a correct "120/362" at canvas row 13 col 1 — one 20-cell
    ; stride below the bar instead of one 40-cell stride — which is off the
    ; GB-projected window entirely, so the golden could never see it while it
    ; was plainly on the port's widescreen screen. The HUD's own cells were
    ; left blank by the ClearScreenArea above.
    mov dword [text_row_stride], FW
    mov esi, wTileMap + P_HPBAR
    call DrawHP
    ; pret :1928 — GetBattleHealthBarColor, not the bare GetHealthBarColor: it
    ; republishes the battle palette ONLY on a colour transition. The joint
    ; SetPal_Battle in DrawHUDsAndHPBars stays — it is the port's own two-slot
    ; publish and republishing the same values is harmless.
    mov esi, wPlayerHPBarColor
    call GetBattleHealthBarColor
    ; --- pret DrawPlayerHUDAndHPBar tail (core.asm:1929-1949): the low-health
    ; --- alarm. Translated 2026-08-13; before that the port stopped at the HP
    ; --- fraction and .setLowHealthAlarm, the game's ONLY setter of
    ; --- BIT_LOW_HEALTH_ALARM, had no counterpart, so the red-HP beeping could
    ; --- never start (Music_DoLowHealthAlarm returns unless the bit is already
    ; --- set). The alias fork hid it from faithdiff for its whole life.
    mov al, [ebp + wBattleMonHP]         ; ld a, [hli]
    or  al, [ebp + wBattleMonHP + 1]     ; or [hl]  — BIG-ENDIAN pair, both halves
    jz .fainted                          ; jr z
    mov al, [ebp + wLowHealthAlarmDisabled]
    test al, al                          ; and a — already won?
    jnz .doneAlarm                       ; ret nz
    mov al, [ebp + wPlayerHPBarColor]
    cmp al, HP_BAR_RED                   ; cp HP_BAR_RED
    je .setLowHealthAlarm                ; jr z
.fainted:
    ; pret: ld hl, wLowHealthAlarm / bit BIT_LOW_HEALTH_ALARM, [hl] / ld [hl], 0
    ; The STORE happens before the branch on the bit — `ld [hl], 0` is
    ; flag-neutral on SM83, so the ZF that `ret z` reads is still the BIT's.
    mov al, [ebp + wLowHealthAlarm]
    mov byte [ebp + wLowHealthAlarm], 0
    test al, 1 << BIT_LOW_HEALTH_ALARM
    jz .doneAlarm                        ; ret z — alarm was not running
    mov byte [ebp + wChannelSoundIDs + CHAN5], 0
.doneAlarm:
    ret
.setLowHealthAlarm:
    or byte [ebp + wLowHealthAlarm], 1 << BIT_LOW_HEALTH_ALARM
    ret

DrawEnemyHUDAndHPBar:
    ; ===== enemy HUD (upper-left) =====
    ; pret DrawEnemyHUDAndHPBar:1955-1956 — `hlcoord 0, 0 / lb bc, 4, 12`.
    ; Same restoration and same BCOORD projection as the player half above.
    mov esi, BCOORD(0, 0)
    mov bh, 4                            ; b = rows
    mov bl, 12                           ; c = width
    call ClearScreenArea
    mov esi, wTileMap + E_NAME          ; PlaceString: ESI=dest(GB offset), EAX=src(flat)
    mov edx, wEnemyMonNick               ; pret DrawEnemyHUDAndHPBar:1960 — same centering
    call CenterMonName
    lea eax, [ebp + wEnemyMonNick]
    call PlaceString
    ; pret DrawEnemyHUDAndHPBar:1963-1972 — same status-vs-level rule as the
    ; player half above, reading wEnemyMonStatus directly.
    mov edx, wEnemyMonStatus
    mov esi, wTileMap + E_LV + 1        ; pret: hlcoord 4,1 / push hl / inc hl
    call PrintStatusConditionNotFainted
    jnz .skipPrintLevel                  ; jr nz
    ; pret DrawEnemyHUDAndHPBar stages the level in wLoadedMonLevel before
    ; PrintLevel (core.asm:1969-1971) — battle-visible WRAM the goldens compare.
    mov al, [ebp + wEnemyMonLevel]
    mov [ebp + wLoadedMonLevel], al
    mov esi, wTileMap + E_LV
    call PrintLevel
.skipPrintLevel:
    ; pret DrawEnemyHUDAndHPBar:1973-2036 — the bar length is computed INLINE
    ; here (hMultiplicand/hDivisor scratch), not via GetHPBarLength: zero HP
    ; short-circuits to an empty bar with NO sliver (ld c,a with a=0), and a
    ; nonzero HP passes c=6 so DrawHPBar draws at least a 1-pixel sliver.
    ; Native arithmetic keeps pret's truncations: when max HP >= 256 BOTH the
    ; 16-bit product lane and the divisor are quarter-scaled (lossy) before the
    ; byte divide — the product is <= 47952 (HP caps at 999), so the 16-bit
    ; lane pret shifts is the whole product, the same argument
    ; engine/gfx/hp_bar.asm:GetHPBarLength records. Draw FIRST, colour SECOND
    ; is pret's own order (the fork's colour-before-draw let GetHealthBarColor
    ; clobber DH and snap a damaged bar back to full — measured 2026-08-15,
    ; fixed in ab0c30930; this faithful sequence keeps that order).
    movzx eax, byte [ebp + wEnemyMonHP]  ; ld a,[hli] — current HP, big-endian
    shl eax, 8
    mov al, [ebp + wEnemyMonHP + 1]
    test eax, eax                        ; or [hl] — is current HP zero?
    jnz .hpNonzero
    xor ebx, ebx                         ; ld c, a — sliver flag OFF
    xor edx, edx                         ; ld e, a — 0 pixels
    mov dh, 6                            ; ld d, $6 — bar is 6 tiles
    jmp .drawHPBar
.hpNonzero:
    imul eax, eax, 48                    ; ld a,48 / call Multiply — current HP * 48
    movzx ecx, byte [ebp + wEnemyMonMaxHP]   ; max HP, big-endian
    shl ecx, 8
    mov cl, [ebp + wEnemyMonMaxHP + 1]   ; ldh [hDivisor], a
    cmp ecx, 0x100                       ; ld a,b / and a — is max HP > 255?
    jb .doDivide
    shr eax, 2                           ; srl/rr pairs — scale the product lane
    shr ecx, 2                           ; and the divisor by 4, both truncating
    and ecx, 0xFF                        ; the divide is by the BYTE, as pret stages it
.doDivide:
    ; DEVIATION{class=data-model; pret=engine/battle/core.asm:DrawEnemyHUDAndHPBar; behavior=zero max HP clamps to a full bar instead of executing native DIV by zero; evidence=pret byte Divide with divisor 0 spins its subtract loop harmlessly where native DIV faults under DPMI and max HP 0 is unreachable from real mon data, the same clamp GetHPBarLength in engine/gfx/hp_bar.asm carries; lifetime=permanent native safety boundary}
    test ecx, ecx
    jnz .divSafe
    mov eax, 48
    jmp .gotPixels
.divSafe:
    xor edx, edx
    div ecx                              ; ld b,$2 / call Divide — (HP*48)/max
.gotPixels:
    mov dl, al                           ; ldh a,[hQuotient+3] / ld e,a — pixels
    mov dh, 6                            ; ld d, a ($6) — bar is 6 tiles
    mov bl, 6                            ; ld c, a — sliver flag ON
.drawHPBar:
    xor al, al                           ; xor a
    mov [ebp + wHPBarType], al           ; ld [wHPBarType], a — enemy: cap $6C
    mov esi, wTileMap + E_HPBAR         ; hlcoord 2,2 (BCOORD battle projection)
    call DrawHPBar                       ; DL survives (DrawHPBar preserves EDX)
    ; DEVIATION{class=projection; pret=engine/battle/core.asm:DrawEnemyHUDAndHPBar; behavior=the six gauge segment cells additionally publish a per-cell BG attribute binding them to the enemy HP palette slot; evidence=the port composites from tile_cache whose palette band is baked per tile id, and both bars keep the canonical gauge tile ids 63-6B since the F-19 clone retirement, so only the per-cell attribute layer can give the enemy gauge its own colour - SetPal_Battle publishes wEnemyHPBarColor into bg_slot_pal slot 1; lifetime=permanent while the compositor bakes palette per tile id}
    ; (Publish moved here verbatim from the retired draw_enemy_hp_bar; same six
    ; cells, same slot, so the colour behaviour is unchanged. SetBGCellAttrFlat
    ; preserves all registers, so DL still carries the pixel count to the
    ; colour routine below, and it only arms a re-decode when the byte changes.)
    push edx
    mov eax, E_HPBAR + 2                 ; first of the six gauge segment cells
    mov dl, ENEMY_GAUGE_SLOT | BG_ATTR_PRESENT
    mov ecx, 6
.publishGaugeAttr:
    call SetBGCellAttrFlat
    inc eax
    dec ecx
    jnz .publishGaugeAttr
    pop edx
    ; pret uses GetBattleHealthBarColor (republish-on-transition), not the bare
    ; GetHealthBarColor — matters when this routine runs OUTSIDE the joint
    ; DrawHUDsAndHPBars (whose SetPal_Battle covered the gap): the send-out
    ; sites call it alone, and the gauge's slot-1 palette must follow a
    ; green→yellow→red transition immediately.
    mov esi, wEnemyHPBarColor
    call GetBattleHealthBarColor
    call PlaceEnemyHUDTiles
    ret

; ---------------------------------------------------------------------------
; LoadPlayerBackPic — decode the PLAYER (Red/Yellow) back sprite to vBackPic
; ($9310, signed tile ID $31). This is the sprite that slides in on the player's
; side at battle start; the sent-out mon's back pic (LoadMonBackPic) replaces it
; only once the player sends a mon out. Scaled like a mon back pic.
;
; Faithful to pret engine/battle/core.asm:LoadPlayerBackPic, which likewise loads
; the fixed RedPicBack blob — this is NOT a species-dependent path, so the embedded
; blob below is the correct permanent implementation, not a stand-in. It carried
; the forked name DrawPlayerRedBackPic_Stub until 2026-07-27, which misread as
; temporary scaffolding while being live production code in the battle intro
; (src/engine/battle/init_battle.asm).
;
; DEVIATION{class=banking; pret=engine/battle/core.asm:LoadPlayerBackPic; behavior=the pic source is an incbin of gfx/player/redb.pic in .data instead of a ROM-bank pointer plus bank switch, and pret's OpenSRAM/CloseSRAM bracket is not repeated at this level; evidence=the port has no ROM banking so pret's ld de RedPicBack plus BANK load has no counterpart, and this routine no longer touches sSpriteBuffer* itself - it tail-jumps to LoadMonBackPicToVRAM, whose buffer work runs inside LoadUncompressedSpriteData and InterlaceMergeSpriteBuffers (src/home/pics.asm), each of which carries pret's own OpenSRAM/CloseSRAM bracket as of 2026-08-23, so bracketing here would guard no access; lifetime=permanent, the flat ROM model is by design}
; DEVIATION{class=projection; pret=engine/battle/core.asm:LoadPlayerBackPic; behavior=this routine only decodes to vBackPic, whereas pret also runs ScaleSpriteByTwo, InterlaceMergeSpriteBuffers and predef CopyUncompressedPicToTilemap plus the hStartTileID and hOAMTile setup to place the pic; evidence=the port folds decode plus 2x scale plus merge into LoadMonBackPicToVRAM and defers tilemap placement to SlideBattlePicsIn, which composites both battle pics onto the 40x25 canvas at projected coordinates; lifetime=permanent, the widescreen canvas composition is by design}
; In:  EBP = GB memory base.  Out: vBackPic filled.  Clobbers: EAX, ECX, EDX, ESI, EDI.
; ---------------------------------------------------------------------------
LoadPlayerBackPic:
    ; pret 6384-6393: wBattleType picks the back pic — OldManPicBack for the
    ; old-man tutorial, ProfOakPicBack for the intro Pikachu battle (it is OAK
    ; standing on the player's side of that battle), RedPicBack otherwise.
    mov al, [ebp + wBattleType]
    mov esi, OldManPicBack                 ; pret: ld de, OldManPicBack
    mov ecx, OldManPicBack_len
    cmp al, BATTLE_TYPE_OLD_MAN            ; pret: cp BATTLE_TYPE_OLD_MAN
    je .next
    mov esi, ProfOakPicBack                ; pret: ld de, ProfOakPicBack
    mov ecx, ProfOakPicBack_len
    cmp al, BATTLE_TYPE_PIKACHU            ; pret: cp BATTLE_TYPE_PIKACHU
    je .next
    mov esi, RedPicBack                    ; pret: ld de, RedPicBack
    mov ecx, RedPicBack_len
.next:
    lea edi, [ebp + PIC_STAGE]
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0
    mov edx, GB_VCHARS2 + 0x31 * 16        ; vBackPic -> signed tile ID $31
    jmp LoadMonBackPicToVRAM               ; decode -> 2x scale -> merge to VRAM

; ---------------------------------------------------------------------------
; SlidePlayerAndEnemySilhouettesOnScreen — pret engine/battle/core.asm:9. The
; pret-named ENTRY POINT for the battle-entry silhouette slide, which the port
; realizes with a different mechanism (SlideBattlePicsIn, src/home/pics.asm).
;
; This exists so pret's one call site — `callfar
; SlidePlayerAndEnemySilhouettesOnScreen` at engine/battle/init_battle.asm:103
; — has a counterpart by name instead of an open-coded pair, per the
; Preserve-pret-Labels rule ("where pret's structure splits differently in the
; port, keep pret's names on both halves"). SlideBattlePicsIn keeps its
; port-only name because it has NO pret counterpart to inherit one from: pret's
; slide is inline in this routine's .slideSilhouettesLoop.
;
; AUDITED 2026-08-12 (battle plan, core.asm inventory): the omitted pret
; internals are a HAL boundary, not a fork. SetScrollXForSlidingPlayerBodyLeft
; is a self-loop on rLY (`ldh a,[rLY] / cp l / jr nz` to its own label) and rLY
; is inert in the port, so a literal translation never terminates;
; SlidePlayerHeadLeft exists only because that raster trick forces the player's
; head to be an OBJ while his body is BG, and the port composites both pics into
; wTileMap with no such split.
;
; DEVIATION{class=HAL; pret=engine/battle/core.asm:SlidePlayerAndEnemySilhouettesOnScreen; behavior=the per-scanline SCX raster slide plus its OBJ-head helper are replaced by a whole-canvas tilemap recomposition per step in SlideBattlePicsIn, and this entry point omits pret's DisableLCD or EnableLCD bracket, the vBGMap0 clear and work-RAM-to-VRAM tilemap copy, the hWY and hAutoBGTransferEnabled and hTileAnimations register staging, the trailing CopyUncompressedPicToTilemap plus HideSprites, and the closing jpfar PrintBeginningBattleText; evidence=SetScrollXForSlidingPlayerBodyLeft polls rLY in a self-loop and rLY is never written by the port so a literal translation cannot terminate, the port has no torus tilemap or auto-BG-transfer for the VRAM copy and register staging to drive, and the intro text plus final pic placement are already owned by the caller in _InitBattleCommon which calls DrawBattleIntroBox or DrawEmptyDialogBox after this returns; lifetime=permanent, the software compositor is by design}
; ---------------------------------------------------------------------------
SlidePlayerAndEnemySilhouettesOnScreen:
    call LoadPlayerBackPic                 ; pret core.asm:10
    jmp SlideBattlePicsIn                  ; the port's realization of the slide

section .data
align 4
; RedPicBack — pret gfx/pics.asm:RedPicBack (INCBIN "gfx/player/redb.pic").
; Kept with its only consumer; gfx/ has no mirrored port file.
RedPicBack:
    incbin "../gfx/player/redb.pic"        ; player (Red/Yellow) back sprite
RedPicBack_len equ $ - RedPicBack
; OldManPicBack / ProfOakPicBack — pret gfx/pics.asm:381-382 (the tutorial and
; intro-battle stand-ins pret's LoadPlayerBackPic selects by wBattleType).
; Same blob-with-consumer pattern and banking DEVIATION as RedPicBack above.
OldManPicBack:
    incbin "../gfx/battle/oldmanb.pic"     ; old-man tutorial back sprite
OldManPicBack_len equ $ - OldManPicBack
ProfOakPicBack:
    incbin "../gfx/battle/prof.oakb.pic"   ; Prof. Oak back sprite (intro battle)
ProfOakPicBack_len equ $ - ProfOakPicBack

section .text

; ===========================================================================
; TryRunningFromBattle — faithful pret escape-odds (engine/battle/core.asm).
; Guaranteed-escape special cases first (Safari / "hurry get away" / link), then the
; wild-mon speed odds; trainer battles can't be fled. Returns CF=1 on escape ("Got
; away safely!"), CF=0 otherwise; on a failed escape sets wActionResultOrTookBattleTurn
; (wild) and wForcePlayerToChooseMon (both paths).
; ===========================================================================
TryRunningFromBattle:
    ; pret core.asm:1536-1545 — guaranteed-escape special cases before the odds math.
    ;
    ; BUG{class=data-model; pret=engine/battle/core.asm:TryRunningFromBattle; behavior=a wild battle on Pokemon Tower 1F-7F while the player HOLDS the Silph Scope computes its run odds from a destroyed player-speed pointer and reads bag bytes as the speed; evidence=pret calls IsGhostBattle first and then reads the player speed with ld a [hli] at core.asm:1553 without reloading hl, the only path inside IsGhostBattle reaching call IsItemInBag is the Pokemon Tower map range, and the whole predef chain there destroys hl - engine/predefs.asm GetPredefPointer backs hl up into wPredefHL, GetQuantityOfItemInBag restores it via GetPredefRegisters and then immediately overwrites it with ld hl wNumBagItems and walks the list, and home/predef.asm Predef returns through pop af then BankswitchCommon then ret with no register restore, so hl survives every other route into this routine and is garbage on exactly that one; lifetime=permanent Gen-1 behavior at compatibility level below 2}
    ; "Silph Scope run-odds pointer clobber". UNDOCUMENTED as far as the
    ; references in this tree go, and the search is named so the claim can be
    ; re-tested rather than trusted: docs/bugs_and_glitches.md,
    ; docs/references/yellow_glitches.md, and the local mirrors under
    ; docs/references/glitchcity and docs/references/moddingwiki (which cover
    ; the MissingNo./underflow/ACE families, not this).
    ; It is reproduced rather than fixed: the escape rule below is faithful only
    ; if the clobber comes with it, so ESI is deliberately NOT saved around the
    ; call. When the scope is ABSENT the routine returns ZF=1 and jumps to
    ; .canEscape, which never reads ESI, so the damage is confined to the
    ; scope-in-bag case.
%if BUG_FIX_LEVEL >= 2
    push esi                             ; fixed: keep the caller's speed pointer
    call IsGhostBattle
    pop esi
%else
    call IsGhostBattle
%endif
    je .canEscape                        ; jp z — a ghost battle always escapes
    cmp byte [ebp + wBattleType], BATTLE_TYPE_SAFARI
    je .canEscape                        ; Safari battle always escapes (reachable)
    cmp byte [ebp + wBattleType], BATTLE_TYPE_RUN
    je .canEscape                        ; "hurry, get away?" forced-run
    cmp byte [ebp + wLinkState], LINK_STATE_BATTLING
    je .canEscape                        ; link battle always escapes
    cmp byte [ebp + wIsInBattle], 2
    je .trainerBattle
    inc byte [ebp + wNumRunAttempts]
    ; pret reads the PLAYER speed through hl and the ENEMY speed through de,
    ; both supplied by the caller. The port used to hardcode wBattleMonSpeed /
    ; wEnemyMonSpeed here, which is right for BattleMenu_RunWasSelected and
    ; WRONG for the other pret caller: DoUseNextMonDialogue's "NO, run" arm
    ; passes wPartyMon1Speed, because the battle mon has just fainted. The
    ; parameters are honoured now (battle plan 2b) — ESI = player speed word,
    ; EDX = enemy speed word, both big-endian GB offsets.
    mov al, [ebp + esi]                 ; ld a,[hli]
    mov [ebp + hMultiplicand + 1], al
    mov al, [ebp + esi + 1]             ; ld a,[hl]
    mov [ebp + hMultiplicand + 2], al
    mov al, [ebp + edx]                 ; ld a,[de]
    mov [ebp + hEnemySpeed], al
    mov al, [ebp + edx + 1]             ; inc de / ld a,[de]
    mov [ebp + hEnemySpeed + 1], al
    ; player speed >= enemy speed → guaranteed escape (pret StringCmp + jr nc)
    movzx eax, byte [ebp + esi]
    shl eax, 8
    mov al, [ebp + esi + 1]
    movzx ecx, byte [ebp + edx]
    shl ecx, 8
    mov cl, [ebp + edx + 1]
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
    ; can't escape: forfeit the turn (pret core.asm:1611-1615)
    mov byte [ebp + wActionResultOrTookBattleTurn], 1
    mov eax, CantEscapeText              ; pret: ld hl, CantEscapeText
    jmp .printCantEscapeOrNoRunningText  ; pret: jr .printCantEscapeOrNoRunningText
.trainerBattle:
    mov eax, NoRunningText               ; pret: ld hl, NoRunningText
.printCantEscapeOrNoRunningText:
    ; The generated battle_text.inc streams carry pret's real text commands
    ; (text/line/cont/prompt), so PrintBattleText gives the GB presentation:
    ; two double-spaced rows, char-by-char reveal, button-gated <CONT> scroll.
    ; This replaces a bespoke TextBoxBorder + 3x PlaceString block that dumped
    ; all three lines at once, single-spaced (maintainer-reported 2026-08-06).
    call PrintBattleText                 ; pret: call PrintText
    mov byte [ebp + wForcePlayerToChooseMon], 1  ; pret core.asm:1620-1622
    call SaveScreenTilesToBuffer1
    clc                                  ; pret: and a — reset carry
    ret
.canEscape:
    ; pret core.asm:1626-1645: the LINK_STATE_BATTLING exchange branch is
    ; unreachable in the port (no link HAL — see EndOfBattle's link TODO-HW);
    ; the non-link path sets wBattleResult=2 and plays the run SFX. The old
    ; bespoke tail dropped wBattleResult, the SFX and SaveScreenTilesToBuffer1.
    mov byte [ebp + wBattleResult], 2    ; pret: ld a,$2 / ld [wBattleResult],a
    mov al, SFX_RUN
    call PlaySoundWaitForCurrent         ; pret: call PlaySoundWaitForCurrent
    mov eax, GotAwayText                 ; pret: ld hl, GotAwayText
    call PrintBattleText                 ; pret: call PrintText
    call WaitForSoundToFinish
    call SaveScreenTilesToBuffer1
    stc                                  ; pret: scf
    ret

; ===========================================================================
; Consolidated here from move_effect_helpers.asm (relocated-labels grind; that
; file was itself deleted in chunk 17): both
; are pret engine/battle/core.asm labels and belong in this mirror. Their
; dependencies were already present in this file — UpdateHPBar2 /
; PrintText are externed above, and DoesntAffectMonText is
; local here via the assets/battle_text.inc include (nm: R, not U), so it must
; NOT be re-externed. move_effect_helpers.asm went on to keep only the labels
; whose pret home was some other file, and chunk 17 sent those to their own
; mirrors (EffectCallBattleCore, Bankswitch, StatModTextStrings).
; ===========================================================================
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
; UpdateCurMonHPBar — pret engine/battle/core.asm:677 (UpdateCurMonHPBar → predef
; UpdateHPBar2). Selects the bar by hWhoseTurn exactly as pret: hWhoseTurn==0
; (player's turn) → the PLAYER mon's bar (pret hlcoord 10,9 / wHPBarType=1, the
; side that also ticks the HP number); else → the ENEMY mon's bar (pret hlcoord
; 2,2 / wHPBarType=0, no number). Each caller — residual_damage / drain_hp /
; heal / recoil — populates wHPBar{Old,New,Max}HP and the mon-struct HP before
; calling, matching pret. Since the Animate{Player,Enemy}HPBar fork retirement
; this goes through pret's real UpdateHPBar2 (engine/gfx/hp_bar.asm). The stride
; republish carries the DrawPlayerHUDAndHPBar DEVIATION's justification
; (class=projection): the number print places digits at bar+[text_row_stride]+1.
; ===========================================================================
global UpdateCurMonHPBar
UpdateCurMonHPBar:
    mov esi, wTileMap + P_HPBAR        ; hlcoord 10,9 — player HP bar (BCOORD)
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov al, 1                           ; ld a, $1 (mov is flag-neutral, as pret's ld)
    jz .playersTurn
    mov esi, wTileMap + E_HPBAR        ; hlcoord 2,2 — enemy HP bar (BCOORD)
    xor al, al                          ; xor a
.playersTurn:
    push ebx                            ; push bc
    mov [ebp + wHPBarType], al          ; ld [wHPBarType], a
    mov dword [text_row_stride], FW     ; port stride republish (header note above)
    call UpdateHPBar2                   ; predef UpdateHPBar2
    pop ebx                             ; pop bc
    ret

; ===========================================================================
; Consolidated 2026-07-26 (mirror rule): the eleven pret engine/battle/core.asm
; labels the port had grown in ten separate files. Grouped by the file each came
; from, following this file's existing "; --- was <file> ---" convention (s8).
; ORDER CAVEAT: pret orders these 741/873/973/1494/1711/3086/3889/4718/5084/
; 5184/6787, but this file has never been in pret order — s8 assembled it by
; APPENDING whole files, so its own existing content is already out of order.
; Interleaving 5.5k lines into pret order is a separate change from a
; relocation, so these are appended in pret order among THEMSELVES.
; ===========================================================================

; --- was src/engine/battle/faint_enemy.asm ---

; 1. TRUE — pret constants/misc_constants.asm:3 `DEF TRUE EQU 1`. Not defined
;    anywhere in dos_port/include/*.inc. Used for wBoostExpByExpAll = TRUE
;    (core.asm:857). Move into gb_constants.inc when integrating.
%ifndef TRUE
TRUE equ 1
%endif

; 2. wEnemyStatsToDouble / wEnemyStatsToHalve — now defined directly in
;    gb_memmap.inc (0xD064/0xD065, = wEnemyBattleStatus1 - 2/-1), so the
;    %ifndef guard below is inert. Kept only as a fallback.

; 3. EXP_ALL — item id constant, not defined anywhere in gb_constants.inc or
;    dos_port/assets (grepped the whole dos_port/ tree). Value from pret
;    constants/item_constants.asm:87 (`const EXP_ALL` is the 76th entry in the
;    0-based `const_value` chain starting at NO_ITEM=$00, i.e. $4B). Move into
;    gb_constants.inc when integrating.
%ifndef EXP_ALL
; EXP_ALL moved to include/gb_constants.inc (the debug gate needs it too)
%endif

; 4. MUSIC_DEFEATED_WILD_MON — victory jingle id ($F9), from assets/audio_constants.inc
;    (not included here to avoid pulling the whole audio table). Local guard mirrors
;    the constants above.
%ifndef MUSIC_DEFEATED_WILD_MON
MUSIC_DEFEATED_WILD_MON equ 0xF9
%endif

; ---------------------------------------------------------------------------
; FaintEnemyPokemon — pret engine/battle/core.asm:741-867.
;
; No caller-set registers required (pure GB-memory / extern-call routine,
; matching pret's parameterless call convention). Clobbers all GP registers
; (matches pret: acts as a call boundary with several nested calls).
; ---------------------------------------------------------------------------
FaintEnemyPokemon:
    call ReadPlayerMonCurHPAndStatus

    ; --- trainer-only: zero the fainted enemy's party-slot HP word ---
    mov al, [ebp + wIsInBattle]
    dec al
    jz .wild                              ; wIsInBattle == 1 (wild) -> skip

    mov al, [ebp + wEnemyMonPartyPos]     ; ld a, [wEnemyMonPartyPos]
    mov esi, wEnemyMon1HP                 ; ld hl, wEnemyMon1HP
    mov bx, PARTYMON_STRUCT_LENGTH        ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes                        ; hl = &party-slot HP word
    mov byte [ebp + esi], 0               ; ld [hli], a  (a=0)
    inc esi
    mov byte [ebp + esi], 0               ; ld [hl], a

.wild:
    and byte [ebp + wPlayerBattleStatus1], (~(1 << ATTACKING_MULTIPLE_TIMES)) & 0xFF
                                           ; res ATTACKING_MULTIPLE_TIMES, [hl]

    ; BUG{class=data-model; pret=engine/battle/core.asm:FaintEnemyPokemon; behavior=only the high byte of accumulated Bide damage is cleared at compatibility level 0; evidence=pret source FaintEnemyPokemon plus docs/bugs_and_glitches.md Bide link-desync entry; lifetime=permanent Gen-1 behavior at compatibility level 0}
    ; Gen-1 zeroes only the high byte of wPlayerBideAccumulatedDamage
    ; (link desync) — pret core.asm:756-766, docs/bugs_and_glitches.md. Preserved by default.
    ; Endianness confirmed against pret core.asm:3662-3681 (adds to "+1" first with
    ; `add c`, then to the base "+0" with `adc b` after `ld hl,...+1`/`ld a,[hld]`):
    ; the BASE address (+0) is the HIGH byte pret's `ld [wPlayerBideAccumulatedDamage],a`
    ; targets; "+1" is the low byte the real bug leaves untouched.
%if BUG_FIX_LEVEL >= 1
    mov byte [ebp + wPlayerBideAccumulatedDamage + 0], 0
    mov byte [ebp + wPlayerBideAccumulatedDamage + 1], 0
%else
    mov byte [ebp + wPlayerBideAccumulatedDamage], 0   ; high byte only (Gen-1 bug)
%endif

    ; --- clear enemy statuses: 5 contiguous bytes starting at wEnemyStatsToDouble
    ;     (wEnemyStatsToDouble, wEnemyStatsToHalve, wEnemyBattleStatus1/2/3) ---
    mov byte [ebp + wEnemyStatsToDouble], 0
    mov byte [ebp + wEnemyStatsToHalve], 0
    mov byte [ebp + wEnemyBattleStatus1], 0
    mov byte [ebp + wEnemyBattleStatus2], 0
    mov byte [ebp + wEnemyBattleStatus3], 0

    mov byte [ebp + wEnemyDisabledMove], 0
    mov byte [ebp + wEnemyDisabledMoveNumber], 0
    mov byte [ebp + wEnemyMonMinimized], 0

    mov byte [ebp + wPlayerUsedMove], 0       ; ld hl,wPlayerUsedMove / ld[hli],a
    mov byte [ebp + wEnemyUsedMove], 0        ; ld[hl],a

    ; pret `hlcoord 12,5 / decoord 12,6 / call SlideDownFaintedMonPic`. The real
    ; body landed in battle_animations Stage 4g, so the coordinate setup is live.
    mov esi, BCOORD(12, 5)               ; PROJ — pret hlcoord 12, 5
    mov edx, BCOORD(12, 6)               ; PROJ — pret decoord 12, 6
    call SlideDownFaintedMonPic

    ; ClearScreenArea IS real: pret `hlcoord 0,0 / lb bc,4,11` — wipe the enemy
    ; HUD corner after the faint. FOURTH instance of the raw-GB-anchor class
    ; (see regression-battle-second-battle-hud-tile-band): this was the bare
    ; `wTileMap + 0`, so the wipe landed in the blank canvas margin at (0,0)
    ; and the fainted mon's HUD survived on screen through the victory text
    ; (maintainer screenshot, 2026-08-15). The sibling clear in EnemySendOut
    ; .next4 already used the projected anchor.
    mov esi, BCOORD(0, 0)                     ; PROJ — pret hlcoord 0, 0
    mov bh, 4                                 ; b = 4 rows
    mov bl, 11                                ; c = 11 width
    call ClearScreenArea

    ; --- win audio (pret core.asm:786-806): a trainer win plays SFX_FAINT_FALL then
    ;     SFX_FAINT_THUD; a wild win ends the low-health alarm and plays the victory
    ;     jingle. The post-audio logic at .sfxplayed is common to both. ---
    mov al, [ebp + wIsInBattle]
    dec al
    jz .wild_win                              ; wIsInBattle == 1 (wild) -> victory music
    ; Trainer win: SFX_FAINT_FALL / SFX_FAINT_THUD.
    ; TODO-HW: trainer faint SFX (wFrequencyModifier/wTempoModifier=0,
    ; PlaySoundWaitForCurrent SFX_FAINT_FALL, wait CHAN5, PlaySound SFX_FAINT_THUD,
    ; WaitForSoundToFinish). Trainer battles aren't the live overworld path yet.
    jmp .sfxplayed
.wild_win:
    call EndLowHealthAlarm                     ; pret: call EndLowHealthAlarm
    ; BUG{class=timing; pret=engine/battle/core.asm:FaintEnemyPokemon; behavior=the wild victory jingle is started before the player mon's HP is checked at compatibility level 0, so a simultaneous faint plays the win music for a battle the player did not win; evidence=pret comments this at the .sfxplayed label - "win sfx is played for wild battles before checking for player mon HP, this can lead to odd scenarios where both player and enemy faint, as the win sfx plays yet the player never won the battle" - and the double-faint guard immediately below is what detects the case too late; lifetime=permanent Gen-1 behavior at compatibility level 0, corrected at BUG_FIX_LEVEL 2}
%if BUG_FIX_LEVEL >= 2
    ; Fixed: decide first. wBattleMonHP is current here — ReadPlayerMonCurHPAndStatus
    ; runs at the top of FaintEnemyPokemon — so a player mon that fainted on the same
    ; turn skips the jingle and falls into the double-faint guard below unchanged.
    mov al, [ebp + wBattleMonHP]
    or  al, [ebp + wBattleMonHP + 1]
    jz .sfxplayed                              ; both fainted -> no victory music
%endif
    mov al, MUSIC_DEFEATED_WILD_MON            ; pret: ld a, MUSIC_DEFEATED_WILD_MON
    call PlayBattleVictoryMusic                ; pret: call PlayBattleVictoryMusic

.sfxplayed:
    ; --- double-faint guard (pret :808-815) ---
    mov al, [ebp + wBattleMonHP]
    or al, [ebp + wBattleMonHP + 1]
    jnz .playermonnotfaint                    ; battle mon HP != 0 -> not fainted
    mov al, [ebp + wInHandlePlayerMonFainted]
    and al, al
    jnz .playermonnotfaint                    ; already inside HandlePlayerMonFainted -> skip
    call RemoveFaintedPlayerMon

.playermonnotfaint:
    call AnyPartyAlive
    test dh, dh
    jz .return                                  ; ret z (no party alive -> just return)

    mov eax, EnemyMonFaintedText
    call PrintBattleText                       ; ld hl,EnemyMonFaintedText / call PrintText
    call PrintEmptyString
    call SaveScreenTilesToBuffer1

    mov byte [ebp + wBattleResult], 0

    mov bh, EXP_ALL                            ; ld b, EXP_ALL (B -> BH per register map)
    call IsItemInBag                           ; ZF=1 -> not in bag
    setz byte [faint_enemy_has_exp_all]         ; push af (parked in memory, see .bss note)
    jz .giveExpToMonsThatFought                 ; jr z, .giveExpToMonsThatFought

    ; --- has EXP_ALL: halve wEnemyMonBaseStats for NUM_STATS+2 bytes ---
    mov esi, wEnemyMonBaseStats
    mov ecx, NUM_STATS + 2
.halveExpDataLoop:
    shr byte [ebp + esi], 1                    ; srl [hl]
    inc esi
    dec ecx
    jnz .halveExpDataLoop

.giveExpToMonsThatFought:
    mov byte [ebp + wBoostExpByExpAll], 0
    call GainExperience                        ; callfar GainExperience

    ; pret: `pop af / ret z` — ret if the saved IsItemInBag ZF was set (EXP_ALL
    ; NOT in bag). faint_enemy_has_exp_all = setz(that ZF) = 1 when NOT in bag, so
    ; the faithful test is `ret nz` here, NOT `ret z` — the byte holds the raw ZF,
    ; not "has exp all". (Was `jz`: inverted → on a normal wild win it wrongly ran
    ; the EXP_ALL block, a 2nd whole-party GainExperience that clobbered wIsInBattle
    ; → TrainerAI `call edi` page fault. bug#3.)
    cmp byte [faint_enemy_has_exp_all], 0       ; pop af / ret z (byte=1 ⇒ ZF was set ⇒ no EXP_ALL)
    jnz .return                                  ; no EXP_ALL -> done

    ; --- has EXP_ALL: award to every party mon (halved share) ---
    mov byte [ebp + wBoostExpByExpAll], TRUE
    mov al, [ebp + wPartyCount]
    xor bh, bh                                  ; ld b, 0 (B -> BH per register map)
.gainExpFlagsLoop:
    stc                                          ; scf
    rcl bh, 1                                    ; rl b
    dec al
    jnz .gainExpFlagsLoop
    mov [ebp + wPartyGainExpFlags], bh
    call GainExperience                          ; jpfar GainExperience (tail call -> plain call+ret)

.return:
    ret

section .bss
; Local scratch: pret uses `push af` / `pop af` to carry the "does the player
; have EXP_ALL" ZF result across the halving loop and the first GainExperience
; call. x86 EFLAGS are not guaranteed to survive a `call` (GainExperience
; clobbers freely), so the boolean is parked in memory instead of relying on
; ZF/pushfd across the call boundary.
faint_enemy_has_exp_all: resb 1

section .text

; --- was src/audio/play_battle_music.asm ---

; ---------------------------------------------------------------------------
; EndLowHealthAlarm — pret engine/battle/core.asm:EndLowHealthAlarm.
; Called on battle win: turn off the low-health alarm and free its SFX channel.
; DIVERGENCE: pret also sets wLowHealthAlarmDisabled=1 to prevent the alarm from
; reactivating until the next battle. The port's alarm engine does not consult that
; flag (no reader exists in the tree), and the alarm can only re-arm while in battle
; — which is ending here — so the store is inert and omitted (no memmap symbol added).
; ---------------------------------------------------------------------------
EndLowHealthAlarm:
    xor al, al
    mov [ebp + wLowHealthAlarm], al               ; turn off low-health alarm
    mov [ebp + wChannelSoundIDs + CHAN5], al       ; free the alarm's SFX channel
    ret

; ---------------------------------------------------------------------------
; PlayBattleVictoryMusic — pret engine/battle/core.asm:PlayBattleVictoryMusic.
; In: AL = victory music id (MUSIC_DEFEATED_WILD_MON or MUSIC_DEFEATED_TRAINER).
; Stops the current battle theme and plays the victory jingle, then Delay3.
; The bank is fixed (BANK(Music_DefeatedTrainer) = $08); both victory tracks
; share it, matching pret. Preserves the id in AL across StopAllMusic (pret push/pop af).
; ---------------------------------------------------------------------------
PlayBattleVictoryMusic:
    push eax                       ; pret: push af (keep music id across StopAllMusic)
    call StopAllMusic
    mov bl, AUDIO_BANK_2           ; pret: ld c, BANK(Music_DefeatedTrainer) = $08
    pop eax                        ; pret: pop af
    call PlayMusic                 ; AL = song, BL = bank
    jmp Delay3                     ; pret: jp Delay3 (tail)

; --- was src/home/wild_encounter_check.asm ---

; --------------------------------------------------------------------------
; StepCountCheck — decrement the per-step counters (pret home/overworld.asm:298).
; If simulated joypad input is active (scripted movement) it does nothing, so
; scripted door-exit steps don't count. Otherwise it decrements wStepCounter, and
; — only while the post-battle "no random battle" cooldown is armed — decrements
; wNumberOfNoRandomBattleStepsLeft, clearing the cooldown bit when it hits 0.
; Touches WRAM only; safe to call unconditionally.
; --------------------------------------------------------------------------

; --------------------------------------------------------------------------
; AnyPartyAlive — OR together every party mon's 2-byte HP. Returns the OR in DH
; (pret returns it in d): DH == 0 => all party mons fainted; DH != 0 => at least
; one is alive. This is pret's `callfar AnyPartyAlive` (home/overworld.asm:289),
; the scan NewBattle's blackout decision consumes. Self-contained; LINK-clean.
; Guard: pret assumes wPartyCount >= 1; the port adds a count==0 -> DH=0 guard so
; an empty/uninitialised party can't spin the loop 2^32 times.
; --------------------------------------------------------------------------
AnyPartyAlive:
    ; pret: ld e,[wPartyCount] / .loop: or [hl] hi / or [hl] lo / add hl,44 / dec e / jr nz.
    ; The counter MUST stay 8 bits wide (CL, dec cl) — and there is NO zero-guard.
    ; With an EMPTY party (wPartyCount==0) pret's `dec e / jr nz` wraps E 0->255 and
    ; loops 256 times, OR-ing 256 mons' worth of WRAM past the party array; that span
    ; holds nonzero bytes, so D comes back NON-ZERO = "a mon is alive" = do NOT black out.
    ; That empty-party path is load-bearing for the Oak intro: after the Pallet Town
    ; BATTLE_TYPE_PIKACHU battle the player still owns no mon, and .battleOccurred calls
    ; here; a widened counter + `test/jz` zero-guard (the old "port safety") returned D=0
    ; => AllPokemonFainted => HandleBlackOut => SpecialEnterMap => EnterMapBoot =>
    ; SetupPlayerSprite stomped the player to (8,8), wedging PLAYER_FOLLOWS_OAK
    ; (regression-oak-intro-follow-stall-after-battle). Reproducing pret's 8-bit wrap
    ; both matches the disassembly and fixes the stall.
    mov cl, [ebp + wPartyCount]               ; e = party count (0 => 256 iterations)
    xor al, al
    lea esi, [ebp + wPartyMon1 + MON_HP]      ; hl = &wPartyMon1HP (0xD16B)
.partyLoop:
    or al, [esi]                              ; HP high byte
    or al, [esi + 1]                          ; HP low byte
    add esi, PARTYMON_STRUCT_LENGTH           ; next party mon (44 bytes)
    dec cl                                     ; pret: dec e (8-bit; 0 wraps to 255)
    jnz .partyLoop
    mov dh, al                                ; d = OR of all HP bytes
    ret

; --- was src/engine/battle/load_enemy_from_party.asm ---

; ---------------------------------------------------------------------------
; LoadEnemyMonFromParty — pret engine/battle/core.asm:1711-1762
; "copies from enemy party data to current enemy mon data when sending out a
; new enemy mon"
;
; Faithful chunked copy, mirroring LoadBattleMonFromParty's structure exactly
; (see dos_port/scratch/faint_leaves.asm for the player-side twin and its
; header note on the CopyData/AddNTimes/SkipFixedLengthTextEntries register
; contracts, verified there against dos_port/src/home/copy.asm and
; dos_port/src/home/array.asm — reused unchanged here).
;
; GEN-2 FORWARD-COMPAT (CLAUDE.md, load-bearing): the enemy party struct's
; offset 7 (MON_CATCH_RATE, aka held-item slot after a Gen1<->Gen2 trade) must
; never be clobbered by this routine. It never is: the first CopyData call
; below (species..moves, 12 bytes, core.asm:1714-1717 / wEnemyMonSpecies..
; wEnemyMonDVs) only *reads* offset 7 out of wEnemyMons (the party struct) as
; a source byte and writes it into wEnemyMonCatchRate (0xCFEB, offset 7 of
; the battle-mon struct — a real, distinct field there, not a repurposed
; slot) — it never writes back into the party struct. The `add hl, MON_DVS - MON_OTID`
; (core.asm:1718-1719) then skips the source cursor over the party-only
; OTID/Exp/StatExp region (offsets 12-26, absent from the battle-mon struct)
; so the *next* chunk copy resumes at the party struct's DVs field (offset
; 27) — it does not re-touch offset 7. Preserved exactly, chunk-for-chunk.
;
; In:  wWhichPokemon = party index of the enemy mon being sent out (WRAM
;      only). No caller-set registers required.
; Out: wEnemyMon* struct populated; wCurSpecies/wMonHeader set via
;      GetMonHeader; wEnemyMonUnmodifiedLevel..stats block set; burn/
;      paralysis penalties applied; wEnemyMonBaseStats copied from
;      wMonHBaseStats; wEnemyMonAttackMod..(+7) reset to the default stat
;      modifier ($7); wEnemyMonPartyPos = wWhichPokemon. All GP registers
;      clobbered (matches pret: no register state is preserved across this
;      routine acting as a call boundary with several nested calls).
; ---------------------------------------------------------------------------
LoadEnemyMonFromParty:
    ; --- hl = wEnemyMons + wWhichPokemon * PARTYMON_STRUCT_LENGTH ---
    mov al, [ebp + wWhichPokemon]               ; ld a, [wWhichPokemon]
    mov bx, PARTYMON_STRUCT_LENGTH               ; ld bc, PARTYMON_STRUCT_LENGTH
    mov esi, wEnemyMons                          ; ld hl, wEnemyMons
    call AddNTimes                               ; hl = enemy party mon base (raw GB offset)

    ; --- species..moves (12 bytes, core.asm:1714-1717) — includes offset 7
    ;     (MON_CATCH_RATE) as a READ-ONLY source byte; see header note. ---
    mov edx, wEnemyMonSpecies                    ; ld de, wEnemyMonSpecies
    mov bx, wEnemyMonDVs - wEnemyMonSpecies       ; ld bc, wEnemyMonDVs - wEnemyMonSpecies
    call CopyData                                 ; hl/de both advance by 12

    ; --- skip party-only OTID/Exp/StatExp (core.asm:1718-1719) ---
    add esi, MON_DVS - MON_OTID                   ; ld bc, MON_DVS - MON_OTID / add hl, bc

    ; --- DVs word (core.asm:1720-1722) ---
    mov edx, wEnemyMonDVs                         ; ld de, wEnemyMonDVs
    mov bx, MON_PP - MON_DVS                      ; ld bc, MON_PP - MON_DVS
    call CopyData

    ; --- PP, 4 bytes (core.asm:1723-1725) ---
    mov edx, wEnemyMonPP                          ; ld de, wEnemyMonPP
    mov bx, NUM_MOVES                             ; ld bc, NUM_MOVES
    call CopyData

    ; --- Level + 5 stats, 11 bytes (core.asm:1726-1728) ---
    mov edx, wEnemyMonLevel                       ; ld de, wEnemyMonLevel
    mov bx, wEnemyMonPP - wEnemyMonLevel           ; ld bc, wEnemyMonPP - wEnemyMonLevel
    call CopyData

    ; --- header lookup: wCurSpecies = wEnemyMonSpecies; call GetMonHeader ---
    mov al, [ebp + wEnemyMonSpecies]              ; ld a, [wEnemyMonSpecies]
    mov [ebp + wCurSpecies], al                   ; ld [wCurSpecies], a
    call GetMonHeader

    ; --- nickname copy: skip wWhichPokemon NAME_LENGTH entries, then copy ---
    mov esi, wEnemyMonNicks                       ; ld hl, wEnemyMonNicks
    mov al, [ebp + wWhichPokemon]                 ; ld a, [wWhichPokemon]
    call SkipFixedLengthTextEntries               ; hl += NAME_LENGTH * a
    mov edx, wEnemyMonNick                        ; ld de, wEnemyMonNick
    mov bx, NAME_LENGTH                           ; ld bc, NAME_LENGTH
    call CopyData

    ; --- snapshot unmodified level+stats block (1 + NUM_STATS*2 bytes) ---
    mov esi, wEnemyMonLevel                       ; ld hl, wEnemyMonLevel
    mov edx, wEnemyMonUnmodifiedLevel             ; ld de, wEnemyMonUnmodifiedLevel
    mov bx, 1 + NUM_STATS * 2                     ; ld bc, 1 + NUM_STATS * 2
    call CopyData

    ; --- burn/paralysis penalties (enemy has no badge boosts) ---
    call ApplyBurnAndParalysisPenaltiesToEnemy

    ; --- base-stats copy loop: wMonHBaseStats -> wEnemyMonBaseStats, NUM_STATS bytes ---
    mov esi, wMonHBaseStats                       ; ld hl, wMonHBaseStats
    mov edx, wEnemyMonBaseStats                   ; ld de, wEnemyMonBaseStats
    mov ecx, NUM_STATS                            ; ld b, NUM_STATS
.copyBaseStatsLoop:
    mov al, [ebp + esi]                           ; ld a, [hli]
    inc esi
    mov [ebp + edx], al                           ; ld [de], a
    inc edx                                        ; inc de
    dec ecx                                        ; dec b
    jnz .copyBaseStatsLoop                        ; jr nz, .copyBaseStatsLoop

    ; --- reset the 8 stat mods (wEnemyMonAttackMod..) to the default $7 ---
    mov al, 7                                     ; ld a, $7
    mov ecx, NUM_STAT_MODS                        ; ld b, NUM_STAT_MODS
    mov esi, wEnemyMonStatMods                    ; ld hl, wEnemyMonStatMods
.statModLoop:
    mov [ebp + esi], al                           ; ld [hli], a
    inc esi
    dec ecx                                        ; dec b
    jnz .statModLoop                              ; jr nz, .statModLoop

    ; --- wEnemyMonPartyPos = wWhichPokemon ---
    mov al, [ebp + wWhichPokemon]                 ; ld a, [wWhichPokemon]
    mov [ebp + wEnemyMonPartyPos], al             ; ld [wEnemyMonPartyPos], a
    ret

; --- was src/engine/battle/select_enemy_move.asm ---

; pret `n percent` = n * $ff / 100 (macros/data.asm). 25→63, 50→127, 75→191.
%define PERCENT(n) ((n) * 0xFF / 100)

SelectEnemyMove:
    ; TODO-HW: link-battle move exchange (Phase 4 network HAL). Single-player skips
    ; it and selects locally; the link path would read the opponent's chosen move.
    mov al, [ebp + wLinkState]
    cmp al, LINK_STATE_BATTLING
    jne .noLinkBattle
    ; (link path not implemented; fall through to local selection for determinism)
.noLinkBattle:
    ; --- forced-move early-outs: keep the current wEnemySelectedMove ---
    mov al, [ebp + wEnemyBattleStatus2]
    test al, (1 << NEEDS_TO_RECHARGE) | (1 << USING_RAGE)   ; Hyper Beam recharge / Rage
    jnz .ret
    mov al, [ebp + wEnemyBattleStatus1]
    test al, (1 << CHARGING_UP) | (1 << THRASHING_ABOUT)    ; Solar Beam/Fly / Thrash
    jnz .ret
    mov al, [ebp + wEnemyMonStatus]
    test al, (1 << FRZ) | SLP_MASK                          ; frozen or asleep
    jnz .ret
    mov al, [ebp + wEnemyBattleStatus1]
    test al, (1 << USING_TRAPPING_MOVE) | (1 << STORING_ENERGY)  ; Wrap etc. / Bide
    jnz .ret
    mov al, [ebp + wPlayerBattleStatus1]
    test al, (1 << USING_TRAPPING_MOVE)   ; caught in the player's trapping move
    jz .canSelectMove
.unableToSelectMove:
    mov al, 0xFF
    jmp .done
.canSelectMove:
    ; if the 2nd move slot is empty there is only one move; Struggle if it is disabled
    mov esi, wEnemyMonMoves + 1
    mov al, [ebp + esi]                   ; a = move slot 1 ([hld])
    dec esi                               ; esi -> slot 0
    test al, al
    jnz .atLeastTwoMovesAvailable
    mov al, [ebp + wEnemyDisabledMove]
    test al, al
    mov al, STRUGGLE
    jnz .done                             ; only move is disabled → Struggle
    ; else: one usable move — fall through; the random loop re-rolls onto slot 0
.atLeastTwoMovesAvailable:
    ; pret core.asm:3138-3141 — wild encounters roll uniformly; trainer battles first
    ; run the class-based AI, which RETURNS a move-candidate buffer pointer in ESI
    ; (filtered wBuffer, non-minimum slots zeroed — or wEnemyMonMoves if no mods). It
    ; does NOT pick wEnemySelectedMove itself; ESI carries into .chooseRandomMove below,
    ; whose uniform roll then only lands on the AI's preferred (non-zero) slots.
    mov al, [ebp + wIsInBattle]
    dec al
    jz .chooseRandomMove                  ; wild encounter → uniform random
    call AIEnemyTrainerChooseMoves        ; trainer → weighted move choice
.chooseRandomMove:
    push esi                              ; remember slot-0 ptr for re-rolls
    call BattleRandom
    mov bh, 1                             ; b = 1: 25% → move 1
    cmp al, PERCENT(25)
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 2
    cmp al, PERCENT(50)
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 3
    cmp al, PERCENT(75) - 1
    jb .moveChosen
    inc esi
    inc bh                                ; 25% → move 4
.moveChosen:
    mov al, bh
    dec al
    mov [ebp + wEnemyMoveListIndex], al
    mov al, [ebp + wEnemyDisabledMove]
    shr al, 4                             ; pret `swap a` + `and $f` = high nybble = disabled slot
    cmp al, bh                            ; chosen slot == disabled slot?
    mov al, [ebp + esi]                   ; a = candidate move id ([hl]); preserves flags
    pop esi                               ; restore slot-0 ptr
    je .chooseRandomMove                  ; disabled → re-roll
    test al, al
    jz .chooseRandomMove                  ; empty slot → re-roll
.done:
    mov [ebp + wEnemySelectedMove], al
.ret:
    ret

; --- was src/engine/battle/print_move_failure.asm ---

; ===========================================================================
; PrintMoveFailureText — pret engine/battle/core.asm:3889
; Prints why a move had no effect (immune / missed / already-unaffected via
; the OHKO "unaffected" marker), then clears wCriticalHitOrOHKO. If the move
; whose turn just failed was Jump Kick/Hi Jump Kick (JUMP_KICK_EFFECT), applies
; the Gen-1 crash-recoil damage (always damage/8, minimum 1) to the user.
; ===========================================================================
PrintMoveFailureText:
    mov edx, wPlayerMoveEffect          ; ld de, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .playersTurn
    mov edx, wEnemyMoveEffect           ; ld de, wEnemyMoveEffect
.playersTurn:
    mov esi, DoesntAffectMonText        ; ld hl, DoesntAffectMonText
    mov al, [ebp + wDamageMultipliers]
    and al, EFFECTIVENESS_MASK          ; 0x7F
    jz .gotTextToPrint                  ; multiplier==0 -> "doesn't affect"
    mov esi, AttackMissedText           ; ld hl, AttackMissedText
    mov al, [ebp + wCriticalHitOrOHKO]
    cmp al, 0xFF
    jnz .gotTextToPrint                 ; not the "unaffected" OHKO marker -> "missed"
    mov esi, UnaffectedText             ; ld hl, UnaffectedText
.gotTextToPrint:
    push edx                            ; push de (move-effect ptr survives PrintText)
    call PrintText
    xor al, al
    mov [ebp + wCriticalHitOrOHKO], al
    pop edx                             ; pop de
    mov al, [ebp + edx]                 ; ld a, [de] — move effect
    cmp al, JUMP_KICK_EFFECT            ; 0x2D
    jnz .ret                            ; ret nz

    ; GLITCH{class=data-model; pret=engine/battle/core.asm:PrintMoveFailureText; behavior=Jump Kick and Hi Jump Kick crash recoil is always one HP because wDamage is zero before the shifts; evidence=pret source PrintMoveFailureText arithmetic; lifetime=permanent Gen-1 behavior; safety=bounded WRAM arithmetic with no ACE potential under DPMI}
    ; Gen-1 Jump Kick/Hi Jump Kick crash recoil is always exactly 1 HP.
    ; wDamage is 0 here (the move missed before any damage was calculated), so the
    ; intended "damage/8" recoil always collapses to the post-shift minimum of 1.
    ; Preserved as-is. Not separately catalogued in docs/bugs_and_glitches.md or
    ; docs/references/yellow_glitches.md (corrected a stale backref to the former
    ; this pass — that file has no Jump Kick entry). pret ref:
    ; engine/battle/core.asm:PrintMoveFailureText. Safety: safe under DPMI
    ; (bounded WRAM arithmetic, no ACE potential).
    mov esi, wDamage                    ; ld hl, wDamage
    mov al, [ebp + esi]                 ; ld a, [hli] — high byte
    inc esi
    mov bl, [ebp + esi]                 ; ld b, [hl] — low byte (hl == wDamage+1)
    ; 16-bit big-endian {al:bl} >>= 3, faithful SRL A / RR B x3 (x86 SHR/RCR are
    ; bit-for-bit equivalent to Z80 SRL/RR w.r.t. the carry flag).
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], bl                 ; ld [hl], b — store low byte at wDamage+1
    dec esi                             ; dec hl -> wDamage
    mov [ebp + esi], al                 ; ld [hli], a — store high byte at wDamage
    inc esi                             ; (hli post-increment) hl -> wDamage+1
    or al, bl                           ; or b — a = high | low, sets ZF
    jnz .applyRecoil
    inc al                              ; inc a (a was 0 here -> a = 1)
    mov [ebp + esi], al                 ; ld [hl], a — clamp low byte (== wDamage+1) to 1
.applyRecoil:
    mov esi, KeptGoingAndCrashedText    ; ld hl, KeptGoingAndCrashedText
    call PrintText
    mov bh, 4                           ; ld b, $4
    call PredefShakeScreenHorizontally  ; pret: predef PredefShakeScreenHorizontally — called
                                        ; directly (the port has no predef dispatcher, so the
                                        ; callee must not run GetPredefRegisters; b is passed in
                                        ; BH above). Same convention as ReadTrainer -> AddBCD.
                                        ; The old "(allowlist §2.4)" citation here was dangling:
                                        ; pret_label_allowlist.json is empty in every category,
                                        ; and a direct call is not a relocation needing one.
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jnz .enemyTurn
    jmp ApplyDamageToPlayerPokemon      ; jp ApplyDamageToPlayerPokemon — recoil hits the user
.enemyTurn:
    jmp ApplyDamageToEnemyPokemon
.ret:
    ret

; --- was src/engine/battle/counter.asm ---

; ===========================================================================
; HandleCounterMove — engine/battle/core.asm:4718.
;
; The variables checked by Counter are updated whenever the cursor points to a new move
; in the battle selection menu. This is irrelevant for the opponent's side outside of
; link battles, since the move selection is controlled by the AI. However, in the
; scenario where the player switches out and the opponent uses Counter, the outcome may
; be affected by the player's actions in the move selection menu prior to switching the
; Pokemon. This might also lead to desync glitches in link battles.
;
; Caller contract (do not change): "Not Counter" returns ZF=0 (caller falls through to
; normal damage); every path where the attacker's move IS Counter returns ZF=1 (its
; damage, if any, is already in wDamage) — this is exactly what the faithful translation
; below produces, with no manual ZF massaging.
; ===========================================================================
HandleCounterMove:
    mov al, [ebp + hWhoseTurn]      ; ldh a, [hWhoseTurn] ; whose turn
    and al, al
    ; player's turn
    mov esi, wEnemySelectedMove     ; ld hl, wEnemySelectedMove
    mov edx, wEnemyMovePower        ; ld de, wEnemyMovePower
    mov al, [ebp + wPlayerSelectedMove]   ; ld a, [wPlayerSelectedMove]
    jz .next                        ; jr z, .next
    ; enemy's turn
    mov esi, wPlayerSelectedMove    ; ld hl, wPlayerSelectedMove
    mov edx, wPlayerMovePower       ; ld de, wPlayerMovePower
    mov al, [ebp + wEnemySelectedMove]    ; ld a, [wEnemySelectedMove]
.next:
    cmp al, 0x44                    ; cp COUNTER
    jnz .notCounter                 ; ret nz ; return if not using Counter (ZF=0 preserved)
    mov byte [ebp + wMoveMissed], 1 ; ld a,$01 / ld [wMoveMissed],a — assume miss until it lands
    mov al, [ebp + esi]             ; ld a, [hl]
    cmp al, 0x44                    ; cp COUNTER
    jz .ret                         ; ret z ; miss if the opponent's last selected move is Counter.
    mov al, [ebp + edx]             ; ld a, [de]
    and al, al
    jz .ret                         ; ret z ; miss if the opponent's last selected move's Base Power is 0.
    ; check if the move the target last selected was Normal or Fighting type
    ; (wPlayerMoveType/wEnemyMoveType sit immediately after MovePower in gb_memmap.inc,
    ; so this indexes [edx+1] rather than a pret "inc de")
    mov al, [ebp + edx + 1]         ; inc de / ld a, [de]
    and al, al                      ; normal type
    jz .counterableType
    cmp al, 0x01                    ; cp FIGHTING
    jz .counterableType
    ; if the move wasn't Normal or Fighting type, miss
    xor al, al
    ret
.counterableType:
    ; BUG{class=data-model; pret=engine/battle/move_effects/counter.asm:HandleCounterMove; behavior=Counter doubles stale wDamage without proving the immediately previous hit was counterable; evidence=pret source HandleCounterMove plus docs/references/yellow_glitches.md battle-system Unexpected Counter damage; lifetime=permanent Gen-1 behavior}
    ; "Unexpected Counter damage" — Counter simply doubles wDamage, which
    ; holds the last damage value dealt by *anyone* (player, opponent, a since-switched-out
    ; opponent, or even another link-battle player) because wDamage is shared and never
    ; cleared between turns/switches/battles. Inherent Gen-1 behavior, preserved verbatim.
    ; pret ref: engine/battle/core.asm#L4960, bugs_and_glitches.md#unexpected-counter-damage
    ; (fix listed as TBD upstream — no BUG_FIX_LEVEL gate to key off here).
    ; Same root cause as yellow_glitches.md's "Counter Glitch" entry ("Counter
    ; can reflect non-Normal/Fighting moves or the user's own damage"): the
    ; type check above (Normal/Fighting) only inspects the *last-selected-move*
    ; type field, not what actually produced the shared wDamage value being
    ; doubled here — so a stale/mismatched wDamage from an unrelated attack can
    ; still pass the type gate and get reflected.
    mov esi, wDamage                ; ld hl, wDamage
    mov al, [ebp + esi]             ; ld a, [hli] — high byte
    or al, [ebp + esi + 1]          ; or [hl] — or with low byte
    jz .ret                         ; ret z
    mov al, [ebp + esi + 1]         ; ld a, [hl] — low byte
    add al, al                      ; add a
    mov [ebp + esi + 1], al         ; ld [hld], a — write doubled low byte
    mov al, [ebp + esi]             ; ld a, [hl] — high byte
    adc al, al                      ; adc a
    mov [ebp + esi], al             ; ld [hl], a — write doubled(+carry) high byte
    jnc .noCarry                    ; jr nc, .noCarry
    mov byte [ebp + esi], 0xff      ; ld a,$ff / ld [hli],a
    mov byte [ebp + esi + 1], 0xff  ; ld [hl], a
.noCarry:
    mov byte [ebp + wMoveMissed], 0 ; xor a / ld [wMoveMissed], a
    call MoveHitTest
    xor al, al
    ret
.notCounter:
    ret                              ; ZF=0 still set from the cmp above
.ret:
    ret

; --- was src/engine/battle/building_rage.asm ---

HandleBuildingRage:
    ; values for the player's turn (target = enemy mon)
    mov esi, wEnemyBattleStatus2
    mov edx, wEnemyMonStatMods
    mov ebx, wEnemyMoveNum
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .next
    ; values for the enemy's turn (target = player mon)
    mov esi, wPlayerBattleStatus2
    mov edx, wPlayerMonStatMods
    mov ebx, wPlayerMoveNum
.next:
    test byte [ebp + esi], (1 << USING_RAGE)
    jz .ret                          ; ret z — target not raging
    mov al, [ebp + edx]
    cmp al, 0x0D                     ; attack mod already maxed (+6)?
    je .ret                          ; ret z
    mov al, [ebp + hWhoseTurn]
    xor al, 0x01                     ; flip turn for the stat-raise
    mov [ebp + hWhoseTurn], al
    ; temporarily set the target's move to $00 / effect to ATTACK_UP1_EFFECT
    mov esi, ebx                     ; hl = bc (move-number address)
    mov byte [ebp + esi], 0x00       ; null move number
    inc esi
    mov byte [ebp + esi], ATTACK_UP1_EFFECT
    push esi
    mov esi, BuildingRageText
    call PrintText
    call StatModifierUpEffect
    pop esi                          ; esi = move-effect address
    xor al, al
    mov [ebp + esi], al              ; ld [hld], a — null move effect
    dec esi
    mov al, RAGE
    mov [ebp + esi], al              ; restore the target's move to Rage
    mov al, [ebp + hWhoseTurn]
    xor al, 0x01                     ; flip turn back
    mov [ebp + hWhoseTurn], al
.ret:
    ret

; --- was src/engine/battle/metronome.asm ---

                              ; EDX = dest struct offset (wPlayerMoveNum/wEnemyMoveNum).

; move ids (pret constants.asm move_constants.asm)
METRONOME_MOVE  equ 0x4C     ; METRONOME
STRUGGLE_MOVE   equ 0xA5     ; STRUGGLE — pret ASSERT NUM_ATTACKS == STRUGGLE;
                              ; ids >= STRUGGLE are not real moves and are rejected.

                              ; ids >= STRUGGLE are not real moves and are rejected.

; ===========================================================================
; MetronomePickMove — pret core.asm:5184. Picks a random move (not METRONOME,
; not >= STRUGGLE) for the acting side and reloads its move data.
; ===========================================================================
MetronomePickMove:
    xor al, al
    mov [ebp + wAnimationType], al      ; xor a / ld [wAnimationType], a
    mov al, METRONOME_MOVE              ; ld a, METRONOME
    ; pret plays Metronome's own subanim here
    ; (xor a / ld [wAnimationType],a / ld a, METRONOME / call PlayMoveAnimation).
    ; PlayMoveAnimation is the real interpreter as of Stage 2b — faithful call.
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

; --- was src/engine/battle/exploding_animation.asm ---

; Numeric ids not present as named constants in gb_constants.inc — literal + comment,
; per the swarm's numeric-id convention (matches poison.asm's TOXIC/POISON_EFFECT style).
%define SELFDESTRUCT_MOVE 0x4E      ; SELFDESTRUCT move id
%define EXPLOSION_MOVE     0x63     ; EXPLOSION move id
%define MEGA_PUNCH_ANIM    0x05     ; MEGA_PUNCH animation id — pret ASSERTs this ==
                                     ; ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT (5)

                                     ; ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT (5)

; ===========================================================================
; HandleExplodingAnimation — pret core.asm:6787. Called after a Self-Destruct/
; Explosion hit resolves; decides whether to shake the screen. All branches that
; don't reach the "isExplodingMove" success path return without touching
; wAnimationType (faithful to pret's ret nz/ret z guards — no animation plays).
;
; In: EBP = GB base, [ebp+hWhoseTurn] = whose turn (0 = player, 1 = enemy).
; Out (success path only): [ebp+wAnimationType] = 5, tail-jumps into
;   PlayMoveAnimation with AL = 5 (MEGA_PUNCH id == ANIMATIONTYPE_SHAKE_SCREEN_
;   HORIZONTALLY_LIGHT); PlayMoveAnimation's ret returns to our caller.
; Out (no-op paths): ret, registers as left by the guard that fired.
; ===========================================================================
HandleExplodingAnimation:
    mov al, [ebp + hWhoseTurn]
    and al, al
    mov esi, wEnemyMonType1         ; hl = target type1 — player's turn → target = enemy
    ; NOTE: pret reads wEnemyBattleStatus1 in BOTH branches (ld de, wEnemyBattleStatus1
    ; appears on both the z and fallthrough paths of the original code) — translated
    ; verbatim, not "fixed" to wPlayerBattleStatus1 for the enemy's-turn case.
    mov edx, wEnemyBattleStatus1    ; de = wEnemyBattleStatus1 (both branches, faithful)
    mov al, [ebp + wPlayerMoveNum]
    jz .player
    mov esi, wBattleMonType1        ; hl = target type1 — enemy's turn → target = player
    mov edx, wEnemyBattleStatus1    ; de = wEnemyBattleStatus1 (verbatim pret quirk, see above)
    mov al, [ebp + wEnemyMoveNum]
.player:
    cmp al, SELFDESTRUCT_MOVE
    je .isExplodingMove
    cmp al, EXPLOSION_MOVE
    jne .ret                        ; ret nz — not an exploding move, no animation
.isExplodingMove:
    mov al, [ebp + edx]
    test al, 1 << INVULNERABLE      ; bit 6 — fly/dig target is invulnerable
    jnz .ret                        ; ret nz — invulnerable target, no animation
    mov al, [ebp + esi]             ; ld a,[hli] — target type1
    inc esi
    cmp al, GHOST
    je .ret                         ; ret z — Ghost-type immune, no animation
    mov al, [ebp + esi]             ; ld a,[hl] — target type2 (immediately follows type1)
    cmp al, GHOST
    je .ret                         ; ret z — Ghost-type immune, no animation
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .ret                        ; ret nz — move missed, no animation
    mov byte [ebp + wAnimationType], MEGA_PUNCH_ANIM   ; == ANIMATIONTYPE_SHAKE_SCREEN_HORIZONTALLY_LIGHT
    ; falls through (pret) into PlayMoveAnimation with a == 5; ported as an
    ; explicit tail jmp — PlayMoveAnimation's ret returns to our caller.
    mov al, MEGA_PUNCH_ANIM
    jmp PlayMoveAnimation
.ret:
    ret

; ---------------------------------------------------------------------------
; SlideDownFaintedMonPic — pret engine/battle/core.asm. Slides the fainted mon's
; pic off the screen one row at a time, blanking the row it vacates.
; battle_animations Stage 4g; the core_stubs.asm ret-stub is retired.
;
; In: ESI = pic bottom-row source (pret hl), EDX = one row below it (pret de).
;     Both are BCOORD-projected by the caller — see the ; PROJ tags there.
; ---------------------------------------------------------------------------
global SlideDownFaintedMonPic
SlideDownFaintedMonPic:
    mov al, [ebp + wStatusFlags5]
    push eax                                 ; push af
    or al, 1 << BIT_NO_TEXT_DELAY            ; set BIT_NO_TEXT_DELAY, a
    mov [ebp + wStatusFlags5], al
    mov bh, PIC_HEIGHT                       ; number of times to slide
.slideStepLoop:                              ; each pass slides the mon down one row
    push ebx
    push edx
    push esi
    mov bh, PIC_HEIGHT - 1                   ; number of rows
.rowLoop:
    push ebx
    push esi
    push edx
    mov ebx, PIC_WIDTH                       ; ld bc, PIC_WIDTH
    call CopyData
    pop edx
    pop esi
    sub esi, SCREEN_WIDTH                    ; ld bc, -SCREEN_WIDTH / add hl, bc
    sub edx, SCREEN_WIDTH                    ; pret does the same via hl, then de = hl
    pop ebx
    dec bh
    jnz .rowLoop
    add esi, SCREEN_WIDTH                    ; stride, not a coordinate
    mov eax, SevenSpacesText                 ; ld de, SevenSpacesText (flat string ptr)
    call PlaceString
    mov bl, 2
    call DelayFrames
    pop esi
    pop edx
    pop ebx
    dec bh                                   ; 8-bit, as pret
    jnz .slideStepLoop
    pop eax                                  ; pop af
    mov [ebp + wStatusFlags5], al
    ret
