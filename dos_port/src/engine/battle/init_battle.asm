; init_battle.asm — InitBattle (battle front-end, Wave 2 Stage 1a).
;
; WIDESCREEN CANVAS (user direction, 2026-06-28): the battle uses the FULL 320×200
; (40×25-tile) screen, with the faithful GB default UI built CENTERED in it, so
; individual elements can be spread out into the widescreen margins later on a
; case-by-case basis. There is NO centered 20×18 window any more.
;
; Render path: the battle screen is the BG plane. render_bg already has a
; non-overworld branch that decodes the whole 40×25 W_TILEMAP straight to the
; 320×200 back buffer (the path the title/menu screens use) — it only renders the
; overworld when wCurrentTileBlockMapViewPointer is nonzero. So InitBattle zeroes
; that pointer (+ SCX/SCY) and builds the layout directly in the 40-wide W_TILEMAP;
; frame.asm then renders it via render_bg. No window descriptor (hide_window).
;
; NOTE on the text helpers: TextBoxBorder / PlaceString hardcode a 20-wide stride
; (text.asm: SCREEN_W_TILES = 20), so they cannot lay out into the 40-wide canvas.
; The dialog box is therefore hand-drawn here with the box-border charmap tiles
; ($79-$7E) at stride 40. Single-line text (no <NEXT>/<LINE>) is stride-agnostic,
; so PlaceString still works for names later; the fixed intro string is written as
; raw glyph tile-bytes (renderable glyphs $60+ map 1:1 to tile IDs).
;
; Default GB layout centered in 40×25: col offset 10 = (40−20)/2, row offset 3
; ≈ (25−18)/2. GB battle dialog box is at GB (0,12); centered → canvas (10,15).
;
; In (seeded by the DEBUG_BATTLE harness): wEnemyMonSpecies, wEnemyMonLevel.
; Register map: A=AL, HL=ESI, EBP=GB memory base; GB memory = [EBP+addr].
;
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

bits 32

; box-border / blank tiles (constants/charmap.asm $79-$7F)
%define T_TL  0x79          ; ┌
%define T_H   0x7A          ; ─
%define T_TR  0x7B          ; ┐
%define T_V   0x7C          ; │
%define T_BL  0x7D          ; └
%define T_BR  0x7E          ; ┘
%define T_SP  0x7F          ; blank/space

%define FW    SCREEN_TILES_W           ; 40 — canvas stride (full widescreen)

; Bottom dialog box — geometry from the generated battle UI layout (Tier 1,
; assets/ui_layout_battle.inc; edit via tools/ui_layout/battle.py). The old
; +10col/+3row GB-centering now lives in the sidecar's per-element shifts.
; PROJ battle: dialog box = UI_DIALOG_BOX_OFS, outer UI_DIALOG_BOX_GBW x GBH
%define BOX_OFS   UI_DIALOG_BOX_OFS
%define BOX_INT_W (UI_DIALOG_BOX_GBW - 2)
%define BOX_INT_H (UI_DIALOG_BOX_GBH - 2)

section .data

; Intro text (faithful _WildMonAppearedText = "Wild <nick>" / "appeared!").
; Line 1 is the "Wild " prefix; the enemy mon's nick is appended at draw time.
intro_line1: db 0x96,0xa8,0xab,0xa3,0x7f         ; "Wild "
INTRO_LINE1_LEN equ $ - intro_line1
; "appeared!"     (a p p e a r e d !)
intro_line2: db 0xa0,0xaf,0xaf,0xa4,0xa0,0xb1,0xa4,0xa3,0xe7
INTRO_LINE2_LEN equ $ - intro_line2

section .text

global InitBattle
global DrawBattleIntroBox
global _InitBattleCommon
extern InitBattleVariables
extern text_row_stride                   ; text.asm — unified engine row stride
extern ClearSprites
extern hide_window
extern LoadHpBarAndStatusTilePatterns
extern LoadHudTilePatterns
extern DrawBattleHUDs
extern DrawEnemyHUD

; --- _InitBattleCommon dependencies (the real overworld→battle orchestration) ---
extern LoadFontTilePatterns              ; home/load_font.asm
extern LoadTextBoxTilePatterns           ; home/load_font.asm
extern LoadEnemyMonData                  ; load_enemy_mon_data.asm — build wEnemyMon*
extern LoadFrontSpriteByMonIndex         ; home/pics.asm — enemy front pic (generic)
extern HasMonFainted                     ; faint_switch.asm — ZF=1 → fainted
extern FlagAction                        ; flag_action.asm — ESI=array, CL=bit, BH=action
extern LoadBattleMonFromParty            ; faint_leaves.asm — build wBattleMon* + stat mods
extern DrawPlayerRedBackPic_Stub         ; home/pics.asm — player trainer (Red) back pic
extern DrawPlayerBackPic_Stub            ; home/pics.asm — INTERIM: hardcoded send-out pic
extern SlideBattlePicsIn                 ; home/pics.asm — silhouette slide-in
extern SaveBattleScreen                  ; battle_menu.asm — snapshot clean screen
extern DrawBattlePokeballs               ; pokeballs.asm — party-status ball row
extern WaitForAPress                     ; battle_menu.asm
extern HideBattlePokeballs               ; pokeballs.asm
extern MainInBattleLoop                  ; core.asm — the whole battle loop
extern EndOfBattle                       ; end_of_battle.asm — post-battle (EXP/evo/reset)
extern EndBattleScreen                   ; battle_menu.asm — clean terminal

InitBattle:
    ; The battle projects the GB viewport into the full 40-wide W_TILEMAP canvas, so
    ; the ONE text engine renders at stride 40 here (the overworld leaves it at 20).
    ; TODO: a clean overworld exit must restore text_row_stride to 20 (Stage 3).
    mov dword [text_row_stride], SCREEN_TILES_W   ; 40
    call InitBattleVariables
    ; reset the remembered FIGHT-menu cursor (wPlayerMoveListIndex persists across move
    ; uses/menu exits for the whole battle; only a new battle clears it). It sits
    ; outside InitBattleVariables' clear block, so clear it explicitly here.
    mov byte [ebp + wPlayerMoveListIndex], 0
    mov byte [ebp + wIsInBattle], 1          ; wild battle (placeholder)
    ; Text-delay config for battle dialog (faithful to pret): set BIT_FAST_TEXT_DELAY so
    ; PrintLetterDelay reads the wOptions speed, and ensure BIT_TEXT_DELAY is OFF. The
    ; delay is enabled ONLY while a dialog MESSAGE prints (like TextCommandProcessor) —
    ; PlaceString/WidePlaceString call PrintLetterDelay unconditionally, so with the bit
    ; off here the menus/HUD/boxes type out instantly; only messages reveal char-by-char.
    mov al, [ebp + W_LETTER_PRINTING_DELAY]
    or  al, (1 << BIT_FAST_TEXT_DELAY)
    and al, (~(1 << BIT_TEXT_DELAY)) & 0xFF
    mov [ebp + W_LETTER_PRINTING_DELAY], al
    mov al, [ebp + wOptions]
    and al, 0xF0                              ; keep battle-style/anim bits, reset speed nibble (TEXT_DELAY_MASK)
    or al, TEXT_DELAY_MEDIUM                  ; default 3 frames/char
    mov [ebp + wOptions], al
    call ClearSprites                        ; drop the overworld OAM (player etc.)
    ; Stop the per-frame OAM rebuild (update_oam → PrepareOAMData) re-showing the
    ; overworld player sprite after ClearSprites; battle manages its own sprites.
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    ; Switch render_bg to its flat-canvas (non-overworld) path: zero the overworld
    ; view pointer so it decodes W_TILEMAP directly, and zero scroll so the 40×25
    ; canvas blits at screen (0,0).
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    call hide_window                         ; no window overlay — battle screen is the BG
    ; Load the HP-bar / status / ":L" tiles ($62-$71) the HUD needs. Tiles $79-$7E
    ; (the dialog box border) are byte-identical in both tile sets, so this does NOT
    ; clobber the box drawn below despite the load_font.asm warning.
    call LoadHpBarAndStatusTilePatterns
    call LoadHudTilePatterns                 ; HUD frame/divider tiles ($6d-$6f, $73-$78)

    ; --- full-screen blank: clear the whole 40×25 canvas to the space tile ---
    ; (per pret init order — blank the entire screen before drawing the layout).
    lea edi, [ebp + W_TILEMAP]
    mov al, T_SP
    mov ecx, SCREEN_TILES_W * SCREEN_TILES_H  ; 40 × 25 = 1000
    rep stosb
    ret

; ---------------------------------------------------------------------------
; _InitBattleCommon — the real overworld→battle orchestration.
;
; This is the routine the overworld's NewBattle path calls to actually RUN a wild
; battle (previously it called only the InitBattle canvas scaffold, which set the
; screen up and returned instantly — the "grass + instant return" defect).
;
; pret splits this across InitBattle→InitWildBattle→_InitBattleCommon→StartBattle
; (engine/battle/{init_battle,core}.asm). The port collapses the visual half of
; StartBattle (silhouette slide-in, intro, pokéball row, send-out) into the proven
; DEBUG_BATTLE_LIVE sequence (debug_dump.asm) and drives the loop with
; MainInBattleLoop; this promotes that sequence into a real routine fed by the real
; data loaders (LoadEnemyMonData / LoadBattleMonFromParty) instead of debug seeds.
;
; Faithful order (pret InitWildBattle then StartBattle.playerSendOutFirstMon):
;   InitBattle canvas → LoadEnemyMonData → enemy front pic → pick first-alive party
;   mon → LoadBattleMonFromParty → intro (Red back pic, slide-in, box, pokéballs) →
;   send-out pic → MainInBattleLoop → EndOfBattle → restore overworld stride.
;
; In: wEnemyMonSpecies2 + wCurEnemyLevel set (by TryDoWildEncounter / forced
;     opponent). Out: CF=1 (a battle occurred), matching pret _InitBattleCommon's scf.
; ---------------------------------------------------------------------------
_InitBattleCommon:
    ; --- font + text-box tiles the box/HUD need (harness-proven prerequisite) ---
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns

    ; --- canvas + battle-var init (port InitBattle: InitBattleVariables, HUD tiles,
    ;     wIsInBattle=1, stride 40, blank W_TILEMAP). Matches pret's InitBattleVariables-
    ;     first ordering; InitBattleVariables does not touch wEnemyMon*. ---
    call InitBattle

    ; --- pret InitWildBattle: build the wild enemy mon (wIsInBattle already 1) ---
    call LoadEnemyMonData                    ; wEnemyMon* from wEnemyMonSpecies2 + level

    ; --- enemy front pic (pret: LoadMonFrontSprite→vFrontPic + CopyUncompressedPicToTilemap
    ;     at hlcoord 12,0). Port LoadFrontSpriteByMonIndex does both halves from
    ;     wCurPartySpecies. LoadEnemyMonData already leaves it = enemy species, but re-set
    ;     it explicitly for clarity (it is about to be overwritten by the player scan). ---
    mov al, [ebp + wEnemyMonSpecies2]
    mov [ebp + wCurPartySpecies], al
    mov esi, W_TILEMAP + 12                   ; hlcoord 12,0 (stride 40)
    call LoadFrontSpriteByMonIndex

    ; --- player send-out (pret StartBattle.playerSendOutFirstMon): first non-fainted mon ---
    ; PROJ(port safety): pret's StartBattle runs AnyPartyAlive→HandlePlayerBlackOut before
    ; this scan, guaranteeing a live mon; the port collapsed StartBattle away, so bound the
    ; scan by wPartyCount and fall back to slot 0 rather than run off the party array. The
    ; overworld can't legitimately reach here all-fainted (a faint blacks you out first).
    mov byte [ebp + wWhichPokemon], 0
.findFirstAliveMonLoop:
    mov al, [ebp + wWhichPokemon]
    cmp al, [ebp + wPartyCount]
    jae .allFaintedFallback                    ; scanned every mon, none alive → slot 0
    call HasMonFainted                        ; ZF=1 → fainted (reads wWhichPokemon)
    jnz .foundFirstAliveMon                    ; pret: jr nz (not fainted → found)
    inc byte [ebp + wWhichPokemon]
    jmp .findFirstAliveMonLoop
.allFaintedFallback:
    mov byte [ebp + wWhichPokemon], 0
.foundFirstAliveMon:
    mov al, [ebp + wWhichPokemon]
    mov [ebp + wPlayerMonNumber], al
    ; wCurPartySpecies = wBattleMonSpecies2 = wPartySpecies[wPlayerMonNumber]
    ; (pret: ld hl, wPartySpecies-1; ld c, num+1; add hl,bc → wPartySpecies + num)
    movzx eax, byte [ebp + wWhichPokemon]
    mov al, [ebp + wPartySpecies + eax]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wBattleMonSpecies2], al
    ; flag this mon to gain EXP + as having fought the current enemy
    mov cl, [ebp + wWhichPokemon]
    mov bh, FLAG_SET
    mov esi, wPartyGainExpFlags
    call FlagAction
    mov cl, [ebp + wWhichPokemon]
    mov bh, FLAG_SET
    mov esi, wPartyFoughtCurrentEnemyFlags
    call FlagAction
    call LoadBattleMonFromParty                ; wBattleMon* + player stat mods = $7

    ; --- intro scene (proven DEBUG_BATTLE_LIVE order) ---
    call DrawPlayerRedBackPic_Stub             ; player trainer (Red) back pic — fixed sprite
    call SlideBattlePicsIn                      ; silhouette slide-in
    call DrawBattleIntroBox                      ; box + "Wild <nick> appeared!" + enemy HUD
    call SaveBattleScreen                        ; snapshot for menu re-entry
    call DrawBattlePokeballs                      ; party-status ball row
    call WaitForAPress
    call HideBattlePokeballs
    ; TODO(send-out pic): DrawPlayerBackPic_Stub decodes a HARDCODED PIKACHU back pic.
    ; The faithful path is a generic LoadMonBackPic from the player mon's wMonHBackSprite
    ; (pret LoadMonBackPic / UncompressMonSprite); no generic port loader exists yet, so
    ; this stays interim. Correct for the common Yellow starter case; wrong pic otherwise.
    call DrawPlayerBackPic_Stub

    ; --- the battle itself ---
    call MainInBattleLoop                       ; menu/turns/damage/faint/EXP/run
    call EndOfBattle                             ; win: PayDay/evo/reset; then whiteout

    ; --- restore the overworld dialog stride so the map/menus render at stride 20
    ;     (InitBattle raised it to 40 for the widescreen canvas). ---
    mov dword [text_row_stride], 20
    stc                                          ; pret _InitBattleCommon: scf
    ret

; ---------------------------------------------------------------------------
; DrawBattleIntroBox — draw the bottom dialog box + "Wild <nick> appeared!" intro
; text + the enemy HUD. Faithful flow: this runs AFTER the silhouette slide-in
; (SlideBattlePicsIn), so it draws over the already-slid mon pics. In: EBP = GB base.
; ---------------------------------------------------------------------------
DrawBattleIntroBox:
    ; --- hand-draw the bottom dialog box (stride 40) at UI_DIALOG_BOX_OFS ---
    ; top border: ┌ + ─×18 + ┐
    lea edi, [ebp + W_TILEMAP + BOX_OFS]
    mov byte [edi], T_TL
    lea edx, [edi + 1]                        ; save interior-fill start for reuse
    inc edi
    mov al, T_H
    mov ecx, BOX_INT_W
    rep stosb                                 ; ─×18  (edi now at right corner col)
    mov byte [edi], T_TR
    ; middle rows: │ + space×18 + │   (BOX_INT_H rows)
    mov ebx, BOX_INT_H
.midrow:
    add edx, FW                               ; next row's interior-fill start
    lea edi, [edx - 1]
    mov byte [edi], T_V                        ; left wall (col 0)
    inc edi                                    ; advance past it before filling
    mov al, T_SP
    mov ecx, BOX_INT_W
    rep stosb                                 ; spaces col 1..18 (edi → col 19)
    mov byte [edi], T_V                        ; right wall (col 19)
    dec ebx
    jnz .midrow
    ; bottom border: └ + ─×18 + ┘
    add edx, FW
    lea edi, [edx - 1]
    mov byte [edi], T_BL                        ; col 0
    inc edi                                    ; advance past it before filling
    mov al, T_H
    mov ecx, BOX_INT_W
    rep stosb                                 ; ─×18 col 1..18 (edi → col 19)
    mov byte [edi], T_BR                        ; col 19

    ; --- intro text on the dialog message lines (PROJ battle: UI_DIALOG_LINE1/2) ---
    ; line 1: "Wild " + enemy mon nick (faithful _WildMonAppearedText; nick is the
    ; $50-terminated string in wEnemyMonNick).
    mov esi, intro_line1                       ; flat .data source
    lea edi, [ebp + W_TILEMAP + UI_DIALOG_LINE1_OFS]
    mov ecx, INTRO_LINE1_LEN
    rep movsb                                  ; "Wild "
    lea esi, [ebp + wEnemyMonNick]             ; GB WRAM nick
.introNick:
    mov al, [esi]
    inc esi
    cmp al, 0x50                               ; '@' terminator
    je .introNickDone
    mov [edi], al
    inc edi
    jmp .introNick
.introNickDone:
    mov esi, intro_line2
    lea edi, [ebp + W_TILEMAP + UI_DIALOG_LINE2_OFS]
    mov ecx, INTRO_LINE2_LEN
    rep movsb

    ; --- enemy HUD: a WILD mon is already "out", so it shows its HP bar during the
    ; intro; a TRAINER (wIsInBattle==2) hasn't sent a mon out yet, so the enemy side
    ; shows the trainer's pokéball row instead (drawn by the caller). ---
    cmp byte [ebp + wIsInBattle], 1
    jne .skipEnemyHUD
    call DrawEnemyHUD
.skipEnemyHUD:
    ret
