; battle_menu.asm — battle DRAW HELPERS + EXP/level-up display.
;
; This file is the sanctioned DRAW-LAYER divergence point for the battle front end.
; The bespoke battle ORCHESTRATION it used to hold (DisplayBattleMenu, MoveSelectionMenu,
; the turn loop, Render*/Do*AttackDamage, the fainted/no-PP/run message draws) has been
; replaced by the faithful translation in core.asm (engine/battle/core.asm). What remains
; here are: (1) the centered-canvas draw primitives core.asm calls (DrawEmptyDialogBox /
; DrawBattleMenuBox / DrawBattleHUDs); (2) the EXP/level-up display
; routines that GainExperience (experience.asm) calls inside its per-mon loop; (3) the
; move TYPE/PP box and FindMoveName helper.
;
; The pret engine/battle/core.asm labels this file used to carry — DrawHUDsAndHPBars
; and TryRunningFromBattle (with its private PrintRunLine helper) — now live in that
; mirror; the Buffer1 pair moved earlier to src/home/tilemap.asm. LearnMoveFromLevelUp
; is an engine/pokemon/evos_moves.asm label and moved to that mirror,
; src/engine/pokemon/evos_moves.asm; it still writes this file's lvl_mon_ptr scratch,
; which is exported for it. WaitForTextScrollButtonPress (with its WaitForAPress alias
; and the wtsbp_saved_c1/c2 counters) is a pret home/joypad2.asm label and moved to that
; mirror, src/home/joypad2.asm; the routines here still call it as WaitForAPress.
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
; PROJ battle: message lines = UI_DIALOG_LINE1 / UI_DIALOG_LINE2
%define MSG_LINE1    UI_DIALOG_LINE1_OFS
%define MSG_LINE2    UI_DIALOG_LINE2_OFS

; (The TYPE/PP info-box coords used to live here for PrintMoveInfoBox; row 22 moved that
; box to pret's PrintMenuItem in core.asm, which projects pret's own hlcoords directly.)
%define CHAR_DIG0     0xF6

; PROJ battle: level-up stats box = UI_LVLUP_BOX / UI_LVLUP_LBL / UI_LVLUP_VAL
; (pret PrintStatsBox.LevelUpStatsBox; labels/values step 2 rows ×4).

; ▼ "more text" advance arrow. UI_DIALOG_ARROW's ARROW_OFF projection left with
; WaitForTextScrollButtonPress (src/home/joypad2.asm); these two are unread by
; anything in this file and were already dead before that move, so they are left
; alone rather than swept inside a relocation commit.
%define T_DOWNARROW        0xEE
%define ARROW_BLINK_FRAMES 20

section .data
; TryRunningFromBattle / PrintRunLine moved to their pret mirror core.asm and
; still read these run-message strings, so the five they use are exported.
global print_num3                     ; PrintStatsBox, now engine/pokemon/status_screen.asm
global str_gotaway
global str_attack                     ; PrintStatsBox, now engine/pokemon/status_screen.asm
global str_defense                    ; PrintStatsBox, now engine/pokemon/status_screen.asm
global str_speed                      ; PrintStatsBox, now engine/pokemon/status_screen.asm
global str_special                    ; PrintStatsBox, now engine/pokemon/status_screen.asm
global str_cantesc
global str_norun1
global str_oldman_name                ; DisplayBattleMenu .doSimulatedMenuInput (core.asm)
global str_profoak_name               ; DisplayBattleMenu .doSimulatedMenuInput (core.asm)
global str_norun2
global str_norun3
%include "assets/battle_menu_runtime_strings.inc"

section .bss
; Battle terminal state (legacy harness hook): 0 = ongoing. core.asm uses wBattleResult;
; the DEBUG_BATTLE harness still seeds this for compatibility.
global wBattleOver
wBattleOver: resb 1
; screen_save moved to src/home/tilemap.asm with the Buffer1 routines
; (menu-intro review: the pret labels belong in the home/tilemap.asm mirror).
global lvl_mon_ptr                        ; also written by LearnMoveFromLevelUp (evos_moves.asm)
lvl_mon_ptr: resd 1                       ; GB offset of the leveling party mon (PrintStatsBox)

section .text

global DrawBattleMenu
global DrawBattleMenuBox
global DrawEmptyDialogBox
global EndBattleScreen
global ShowGainedExpText
global ShowGrewLevelText
global FindMoveName
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
extern DelayFrame
extern WaitForAPress                  ; src/home/joypad2.asm — alias of pret WaitForTextScrollButtonPress
; --- DEBUG_BATTLE_ENEMYHIT ground-truth scaffold only ---
extern GetCurrentMove                 ; engine/battle/core.asm — move record -> wPlayerMove*/wEnemyMove*
extern GetDamageVarsForEnemyAttack    ; engine/battle/core.asm
extern CalculateDamage                ; engine/battle/core.asm (ZF if 0 BP)
extern AdjustDamageForMoveType        ; engine/battle/core.asm
extern RandomizeDamage                ; engine/battle/core.asm

; ===========================================================================
; Draw primitives (the sanctioned divergence point) under pret names.
; ===========================================================================

; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 moved to their pret
; mirror, src/home/tilemap.asm (menu-intro review 2026-07-23) — this file held
; them under the pret names but with a private host buffer and no annotation.
; The battle-flavored aliases SaveBattleScreen / RestoreBattleScreen live there
; too, alongside the pret names.
extern SaveScreenTilesToBuffer1      ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1    ; src/home/tilemap.asm
extern RestoreBattleScreen           ; src/home/tilemap.asm — alias of the Buffer1 pair
extern UseItem                       ; src/home/item.asm — In: [wCurItem]; Out: [wActionResultOrTookBattleTurn]
extern DelayFrames                   ; src/home/delay.asm — In: BL = frame count

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

; BattleItemMenu — pret engine/battle/core.asm:BagWasSelected. REAL for the
; tutorial battles (2026-08-06, battle-completion Stage 4a): pret swaps the bag
; for SimulatedInputBattleItemList (one POKé BALL) in OLD_MAN / PIKACHU battles
; and the simulated input throws it; the capture tail (pret
; .checkIfMonCaptured / .returnAfterCapturingMon) clears wCapturedMonSpecies,
; sets wBattleResult=2 and returns CF=1, which ends the special battle at the
; caller (_InitBattleCommon .specialBattleLoop / DisplayBattleMenu's ITEM tail).
;
; The NORMAL-battle branch is still the no-op (CF=0 → the menu redisplays,
; exactly the old stub behavior); the real in-battle bag UI belongs to
; battle-completion item 2c. The naming CONVENTION DEBT below it stands: this
; label should become pret's BagWasSelected when 2c lands (measured 2026-08-01,
; a stub-file move is mechanically rejected for a port_only-status name).
;
; DEVIATION{class=temporary; pret=engine/battle/core.asm:BagWasSelected; behavior=the tutorial-battle bag presentation is a one-line POKe BALL x1 box with a fixed dwell instead of pret's DisplayBagMenu list UI over SimulatedInputBattleItemList, the normal-battle branch remains a no-op, and pret's no-capture HUD-redraw and GBPalNormal tail is dropped; evidence=the in-battle DisplayBagMenu and DisplayListMenuID stack is unported (battle-completion item 2c) and the tutorial flow needs only the single scripted POKE BALL selection pret's simulated input always makes, while OLD_MAN and PIKACHU capture on the scripted first throw so the no-capture tail is one retrained-old-man shake away from unreachable; lifetime=battle-completion items 2c and 4b}
BattleItemMenu:
    mov al, [ebp + wBattleType]
    cmp al, BATTLE_TYPE_OLD_MAN
    je .simulatedInputBattle
    cmp al, BATTLE_TYPE_PIKACHU
    je .simulatedInputBattle
    clc                                 ; normal battle: bag UI deferred (item 2c)
    ret
.simulatedInputBattle:
    ; the one-item bag (pret SimulatedInputBattleItemList): show it, dwell as
    ; the simulated cursor "selects" the ball, then use it.
    mov dword [menu_item_step], 2 * FW
    mov esi, W_TILEMAP + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov esi, W_TILEMAP + MSG_LINE1
    mov eax, str_pokeball
    call PlaceString
    mov esi, W_TILEMAP + MSG_LINE2
    mov eax, str_x1
    call PlaceString
    mov bl, 30
    call DelayFrames
    mov byte [ebp + wCurItem], POKE_BALL
    call UseItem                        ; -> ItemUseBall: throw, shakes, catch text
    ; pret BagWasSelected tail (.checkIfMonCaptured):
    mov al, [ebp + wCapturedMonSpecies]
    test al, al
    jz .noCapture
    mov byte [ebp + wCapturedMonSpecies], 0
    mov byte [ebp + wBattleResult], 2   ; pret: ld a,$2 / ld [wBattleResult],a
    stc                                 ; pret: scf — the battle is over
    ret
.noCapture:
    clc                                 ; pret: and a
    ret

; BattlePartyMenu — still the deferred no-op (battle-completion item 2a owns
; the voluntary-switch body; pret counterpart is the TAIL of
; PartyMenuOrRockOrRun from pret core.asm:2409 — the dec-a run check is already
; inline in DisplayBattleMenu .partyMenuOrRun). Same naming debt as above.
BattlePartyMenu:
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

; (The TYPE/PP box used to be drawn here by a port-invented PrintMoveInfoBox, with a
; hand-rolled 2-digit printer and a direct Moves-table type lookup. Menu-fidelity row 22
; replaced it with pret's own PrintMenuItem — core.asm:3010 — which reads the max PP from
; GetMaxPP (so PP Ups count, which PrintMoveInfoBox got wrong) and prints the type through
; PrintMoveType. Both it and its print_2d helper are deleted; FindMoveName above stays,
; it has other callers.)

; ===========================================================================
; DEBUG_BATTLE_ENEMYHIT ground-truth scaffold (NOT the live battle path).
; ===========================================================================
; DoEnemyAttackDamage — run the faithful Gen-1 damage pipeline for the enemy's selected
; move and subtract wDamage from the player mon's HP (floored). Used only by the static
; DEBUG_BATTLE_ENEMYHIT WRAM-dump harness; the live battle resolves moves via core.asm.
;
; DEVIATION{class=temporary; pret=engine/battle/core.asm:EnemyCalcMoveDamage; behavior=a harness-only entry point drives the same damage pipeline pret runs inside EnemyCalcMoveDamage and applies the result, so a dump can be taken at a known point without stepping the whole turn loop; evidence=label_status reports its only caller as RunBattleTest in src/debug/debug_dump.asm and the port already translates EnemyCalcMoveDamage faithfully in the core.asm mirror at line 2090, so this duplicates a pret routine under a port name and exists only for the harness, it is not a second implementation of the live path; lifetime=retire by pointing the DEBUG_BATTLE_ENEMYHIT harness at EnemyCalcMoveDamage, tracked as a battle-completion cleanup}
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
