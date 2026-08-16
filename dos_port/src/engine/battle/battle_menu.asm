; battle_menu.asm — battle DRAW HELPERS.
;
; This file is the sanctioned DRAW-LAYER divergence point for the battle front end.
; The bespoke battle ORCHESTRATION it used to hold (DisplayBattleMenu, MoveSelectionMenu,
; the turn loop, Render*/Do*AttackDamage, the fainted/no-PP/run message draws) has been
; replaced by the faithful translation in core.asm (engine/battle/core.asm). What remains
; here, current as of 2026-08-15 (this slice's remediation pass — see the DEVIATION
; annotations on each routine for the evidence behind these classifications):
;   DrawEmptyDialogBox / DrawBattleMenuBox   centered-canvas draw primitives core.asm calls
;   DrawBattleMenu                           debug-harness-only composite of the two above
;   EndBattleScreen                          canvas-blank exit; core.asm's DrawHUDsAndHPBars
;                                             is NOT in this file, it lives in the core.asm
;                                             mirror (see below)
;   ShowSimulatedInputBagBox                 OLD_MAN/PIKACHU tutorial substitute presentation
;   print_num3                               fork of home/print_num.asm:PrintNumber, flagged
;                                             for retirement (DEVIATION below) but still the
;                                             only caller path status_screen.asm uses
;   lvl_mon_ptr                              exported scratch for evos_moves.asm
; The move TYPE/PP box helper (PrintMoveInfoBox) and FindMoveName (a fork of pret's
; GetMoveName) are BOTH gone — see the retirement notes at their old locations below.
; The EXP/level-up display routines GainExperience (experience.asm) used to call here
; (ShowGainedExpText / ShowGrewLevelText, forked names for pret's GainedText /
; GrewLevelText) were retired 2026-08-15 — GainExperience now drives the pret text
; streams directly through PrintBattleText (core.asm).
;
; The pret engine/battle/core.asm labels this file used to carry — DrawHUDsAndHPBars
; and TryRunningFromBattle (with its private PrintRunLine helper) — now live in that
; mirror; the Buffer1 pair moved earlier to src/home/tilemap.asm. LearnMoveFromLevelUp
; is an engine/pokemon/evos_moves.asm label and moved to that mirror,
; src/engine/pokemon/evos_moves.asm; it still writes this file's lvl_mon_ptr scratch,
; which is exported for it. WaitForTextScrollButtonPress (with its WaitForAPress alias
; and the wtsbp_saved_c1/c2 counters) is a pret home/joypad2.asm label and moved to that
; mirror, src/home/joypad2.asm; no routine here calls it any more (its only caller was
; the retired ShowGainedExpText). DoEnemyAttackDamage and wBattleOver (the
; DEBUG_BATTLE_ENEMYHIT ground-truth scaffold) were debug-harness-only — see the
; relocation note near the foot of this file — and moved to src/debug/debug_dump.asm,
; their only referrer tree-wide.
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

%define FW   SCREEN_TILES_W            ; 40 — wTileMap stride
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
; screen_save moved to src/home/tilemap.asm with the Buffer1 routines
; (menu-intro review: the pret labels belong in the home/tilemap.asm mirror).
global lvl_mon_ptr                        ; also written by LearnMoveFromLevelUp (evos_moves.asm)
lvl_mon_ptr: resd 1                       ; GB offset of the leveling party mon (PrintStatsBox)

section .text

global DrawBattleMenu
global DrawBattleMenuBox
global DrawEmptyDialogBox
global EndBattleScreen
global ShowSimulatedInputBagBox

extern TextBoxBorder                 ; unified text engine (text.asm), stride-aware
extern PlaceString                   ; unified text engine; src=EAX, returns end in EBX
extern menu_item_step                ; src/home/window.asm — menu cursor item spacing
extern text_row_stride               ; text.asm — wTileMap row stride (battle sets 40)
extern DelayFrame

; ===========================================================================
; Draw primitives — the sanctioned divergence point. Their names are
; descriptive port-only labels, NOT pret names (none of DrawEmptyDialogBox /
; DrawBattleMenuBox / DrawBattleMenu / EndBattleScreen matches a pret label;
; see each routine's DEVIATION annotation for the pret call it substitutes
; for). The externs immediately below ARE pret names (SaveScreenTilesToBuffer1
; / LoadScreenTilesFromBuffer1), moved to their pret mirror elsewhere.
; ===========================================================================

; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 moved to their pret
; mirror, src/home/tilemap.asm (menu-intro review 2026-07-23) — this file held
; them under the pret names but with a private host buffer and no annotation.
; The battle-flavored aliases SaveBattleScreen / RestoreBattleScreen live there
; too, alongside the pret names.
extern SaveScreenTilesToBuffer1      ; src/home/tilemap.asm
extern LoadScreenTilesFromBuffer1    ; src/home/tilemap.asm
extern UseItem                       ; src/home/item.asm — In: [wCurItem]; Out: [wActionResultOrTookBattleTurn]
extern DelayFrames                   ; src/home/delay.asm — In: BL = frame count

; DrawEmptyDialogBox — pret PrintEmptyString: redraw the outer dialog box with a BLANK
; interior (clears any prior message). Labels/box are instant (pret PlaceString).
; DEVIATION{class=projection; pret=engine/battle/core.asm:PrintEmptyString; behavior=pret prints a one-character empty string through the shared PrintText/TextCommandProcessor engine over the box the prior DisplayTextBoxID call already drew, the port instead redraws the whole outer box outline via TextBoxBorder against the generated UI_DIALOG_BOX layout constants; evidence=pret PrintEmptyString (engine/battle/core.asm:6720) is ld hl, dot emptyString / jp PrintText with no box-border call of its own, and this file is the declared sanctioned draw-layer divergence point per its header, projecting pret box coordinates through assets/ui_layout_battle.inc for the port's widened canvas; lifetime=permanent, retires only if the battle front end moves onto the shared PrintText/TextBoxBorder pipeline core.asm already uses for the rest of the screen}
DrawEmptyDialogBox:
    and byte [ebp + wLetterPrintingDelayFlags], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov dword [menu_item_step], 2 * FW
    mov esi, wTileMap + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    ret

; DrawBattleMenuBox — pret DisplayTextBoxID(BATTLE_MENU_TEMPLATE): the smaller menu box
; (divider) + the FIGHT/PKMN/ITEM/RUN labels. In: EBP = GB base.
; DEVIATION{class=projection; pret=engine/battle/core.asm:DisplayBattleMenu; behavior=pret sets wTextBoxID to BATTLE_MENU_TEMPLATE and dispatches through the generic menu-template DisplayTextBoxID system, the port draws the box and labels directly via TextBoxBorder plus PlaceString against the generated UI_ACTION_MENU_BOX/UI_ACTION_TEXT layout constants; evidence=pret DisplayBattleMenu (engine/battle/core.asm around line 2087) does ld a, BATTLE_MENU_TEMPLATE / ld [wTextBoxID], a / call DisplayTextBoxID rather than a direct box-border call, and this file is the declared sanctioned draw-layer divergence point per its header; lifetime=permanent, tracked with the rest of this file's draw primitives}
DrawBattleMenuBox:
    mov dword [menu_item_step], 2 * FW
    mov esi, wTileMap + BOX_OFF
    mov bh, BOX_H
    mov bl, BOX_W
    call TextBoxBorder
    mov esi, wTileMap + TEXT_OFF
    mov eax, BattleMenuText
    call PlaceString
    mov esi, ebx
    ret

; DrawBattleMenu — outer dialog box + menu box + labels (static; used by the DEBUG_BATTLE
; non-interactive dump harness). Equivalent to DrawEmptyDialogBox + DrawBattleMenuBox.
; DEVIATION{class=temporary; pret=engine/battle/core.asm:DisplayBattleMenu; behavior=a convenience wrapper composing the two real draw primitives (DrawEmptyDialogBox then DrawBattleMenuBox) under one call, not itself part of the live battle draw path; evidence=label_status reports both its callers as anim_show_label in src/debug/debug_dump.asm (lines 4311 and 4317) and this file's own header note of what core.asm calls does not list DrawBattleMenu, only DrawEmptyDialogBox and DrawBattleMenuBox individually; lifetime=stays here since it composes two labels this file already exports, retire or move to the debug subsystem only if the DEBUG_BATTLE harness stops needing the combined call}
DrawBattleMenu:
    call DrawEmptyDialogBox
    jmp DrawBattleMenuBox

; EndBattleScreen — clean battle terminal: blank the canvas, present it, restore the
; overworld text stride. (Placeholder exit; real exit returns to the overworld.)
; DEVIATION{class=projection; pret=engine/battle/end_of_battle.asm:EndOfBattle; behavior=port-only canvas-blanking exit used by init_battle.asm and the debug harness, there is no single pret label for it because pret's EndOfBattle returns control to the overworld map draw rather than blanking a shared canvas the port reuses for both screens; evidence=label_status reports its callers as anim_show_label in src/debug/debug_dump.asm and init_battle.asm citing it as clean terminal, and this file header documents the port compositing model (single wTileMap canvas reused across screens) that makes an explicit blank-and-restore step necessary where pret simply draws the next screen over VRAM; lifetime=permanent while the port keeps one shared canvas for battle and overworld}
EndBattleScreen:
    mov dword [text_row_stride], 20       ; restore the overworld/GB text stride
    lea edi, [ebp + wTileMap]
    mov ecx, SCREEN_AREA
    mov al, T_SP
    rep stosb
    call DelayFrame
    ret

; ShowSimulatedInputBagBox — port-only presentation for the OLD_MAN / PIKACHU
; tutorial battles: pret swaps the bag for SimulatedInputBattleItemList (one
; POKé BALL) and lets the simulated input select it; this draws that one-item
; box and dwells for the same beat.
;
; RENAMED AND NARROWED 2026-08-12 (battle plan 2c). It used to be
; `BattleItemMenu`, a port-only FORKED NAME standing in for pret's
; BagWasSelected, with the normal-battle branch a no-op and the item use plus
; capture tail inline. All of that moved to pret's own routines in
; src/engine/battle/core.asm, where the mirror rule puts them; what is left here
; is the one genuinely port-only piece — the substitute presentation — under a
; descriptive name that claims no pret label. Its caller is
; BagWasSelected.simulatedInputBattle, and the class=data-model note there
; records why the port cannot use pret's list (wListPointer is a 16-bit GB
; address, so a flat program-image table cannot be stored in it).
; Retires when battle_completion 4b stages that list into GB memory.
ShowSimulatedInputBagBox:
    mov dword [menu_item_step], 2 * FW
    mov esi, wTileMap + OUTER_OFF
    mov bh, OUTER_H
    mov bl, OUTER_W
    call TextBoxBorder
    mov esi, wTileMap + MSG_LINE1
    mov eax, str_pokeball
    call PlaceString
    mov esi, wTileMap + MSG_LINE2
    mov eax, str_x1
    call PlaceString
    mov bl, 30
    call DelayFrames
    ret

; BattlePartyMenu — DELETED 2026-08-12 (battle plan 2a). It was a port-only
; ret-only helper standing in for pret's PartyMenuOrRockOrRun, i.e. a forked
; name, which is exactly what the Preserve-pret-Labels rule forbids. The real
; body now lives under pret's own name in src/engine/battle/core.asm, where the
; mirror rule puts it, and DisplayBattleMenu tail-jumps to it. The name is gone
; rather than renamed: renaming would have moved a pret label into the wrong
; file.

; ===========================================================================
; EXP / level-up display — RETIRED 2026-08-15 (fork retirement).
;
; ShowGainedExpText / ShowGrewLevelText used to live here: forked names for
; pret's GainedText / GrewLevelText (pret engine/battle/experience.asm:149,249
; — `ld hl, GainedText / call PrintText`; pret has no battle_menu.asm at all).
; They hand-painted the box and the EXP/level number with PlaceString/print_dec
; instead of driving the text engine, which is also why they needed their own
; wLetterPrintingDelayFlags save/restore bracket (d9d97f186, interim) — pret's
; PrintText/TextCommandProcessor already brackets that flag per session.
;
; Both call sites (experience.asm's GainExperience, per pret's own two
; `ld hl, Xxx / call PrintText` sites) now call GainedText/GrewLevelText
; directly through PrintBattleText (engine/battle/core.asm), the same
; battle-msgbox-record wrapper every other in-battle text site in the port
; uses. GainedText/WithExpAllText are real `text_far`+`text_asm` wrappers in
; experience.asm; BoostedText/ExpPointsText/GrewLevelText are generated Tier-1
; data (assets/battle_text.inc) carrying pret's own prompt/no-prompt shape, so
; no bolted-on WaitForAPress is needed at the call sites either.
;
; Deleted with the fork: get_party_nick (nick staging now goes through the
; real GetPartyMonName, which experience.asm already calls) and print_dec (its
; only caller), plus the str_gained/str_exppts/str_grew/str_tolevel/str_excl
; generated runtime strings (tools/generators/gen_runtime_strings.py) and the
; RestoreBattleScreen extern above, all now unreferenced. print_num3 stays —
; PrintStatsBox (engine/pokemon/status_screen.asm) still calls it.
; ===========================================================================

; print_num3 — EAX (0..999) → 3-digit right-aligned, space-padded, at [ebp+EDI..EDI+2].
;
; DEVIATION{class=temporary; pret=home/print_num.asm:PrintNumber; behavior=reimplements PrintNumber's div-based big-endian decimal conversion (space-padded, no leading zeroes, no left-align) under an invented name and a different calling convention, value pre-loaded in EAX and dest offset in EDI instead of a source pointer in EDX and dest cursor in ESI; evidence=pret PrintStatsBox.PrintStat (engine/pokemon/status_screen.asm) calls the real PrintNumber with BH=2 (byte count) and BL=3 (digit count) and no flag bits for exactly this ATTACK/DEFENSE/SPEED/SPECIAL stat field, and the port's own already-ported PrintNumber (src/home/print_num.asm) implements that identical contract and is called that way elsewhere in status_screen.asm; lifetime=retires when the four call sites in engine/pokemon/status_screen.asm PrintStatsBox.LevelUpStatsBox (status_screen.asm:575,581,587,593) are converted to call PrintNumber directly with ESI=dest cursor, EDX=stat field address, BH=2, BL=3, matching pret, a change outside this slice's edit scope and reported in this slice's report for the exact conversion}
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

; ===========================================================================
; Move list helpers — EMPTY as of 2026-08-15 (this slice's remediation pass).
; This section used to hold FindMoveName, called by core.asm's
; MoveSelectionMenu-adjacent move-name printing; that call graph never
; actually reached core.asm (label_status showed zero core.asm callers, only
; the extern), so the banner's claim was already stale before the retirement.
; ===========================================================================

; FindMoveName — RETIRED 2026-08-15 (fork retirement, this slice). It was a
; port-invented duplicate of pret's GetMoveName (home/names.asm:129): the same
; "scan MoveNames for the Nth 0x50-terminated entry" walk that GetName
; (src/home/names2.asm, the mirror of pret home/names2.asm:GetName) already
; performs faithfully, reimplemented under an invented name that returned a
; flat pointer instead of going through wNameBuffer. Its only caller,
; DisplayUsedMoveText (src/engine/battle/used_move_text.asm), now calls the
; real GetMoveName (src/home/names.asm) directly, copying the WRAM
; wNameBuffer result instead of a flat MoveNames pointer. `MoveNames` is no
; longer referenced by this file (extern removed below).

; (The TYPE/PP box used to be drawn here by a port-invented PrintMoveInfoBox, with a
; hand-rolled 2-digit printer and a direct Moves-table type lookup. Menu-fidelity row 22
; replaced it with pret's own PrintMenuItem — core.asm:3010 — which reads the max PP from
; GetMaxPP (so PP Ups count, which PrintMoveInfoBox got wrong) and prints the type through
; PrintMoveType. Both it and its print_2d helper are deleted; FindMoveName, which used to
; be described here as staying because it had other callers, is also retired above — its
; only caller now goes straight to the real pret GetMoveName.)

; ===========================================================================
; DEBUG_BATTLE_ENEMYHIT ground-truth scaffold — RELOCATED 2026-08-15 (this
; slice's remediation pass). DoEnemyAttackDamage and wBattleOver (former .bss
; global above) had exactly one referrer tree-wide: src/debug/debug_dump.asm
; (label_status --callers DoEnemyAttackDamage: 1 port caller, anim_show_label
; at debug_dump.asm:4286, plus the extern at :186; wBattleOver: 0 port
; callers, extern only at debug_dump.asm:182, written at :4267). Neither is
; reachable from the live battle path (core.asm resolves moves through its
; own EnemyCalcMoveDamage and tracks wBattleResult, not this pair), so they
; are debug-harness-only and belong in the debug subsystem, not this pret
; draw-layer mirror. Both bodies moved verbatim into
; src/debug/debug_dump.asm (owned by another slice in this remediation
; fan-out) — see that slice's edit for the relocated DEVIATION annotation and
; code. Nothing here still references GetCurrentMove /
; GetDamageVarsForEnemyAttack / CalculateDamage / AdjustDamageForMoveType /
; RandomizeDamage / hWhoseTurn / wCriticalHitOrOHKO / wBattleMonHP / wDamage;
; their externs were removed from this file's header.
; ===========================================================================
