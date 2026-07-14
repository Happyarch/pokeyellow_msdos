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

; W-1 FIX (docs/battle_audit_findings.md): saved overworld view pointer across the
; battle's flat-canvas hack. Port-only render-HAL state; see InitBattle / the
; _InitBattleCommon tail.
saved_ow_view_ptr: dw 0

section .text

global InitBattle
global DrawBattleIntroBox
global _InitBattleCommon
extern text_msgbox                     ; src/home/text.asm — active msgbox projection
extern msgbox_dialog                   ; src/home/text.asm — overworld dialog projection
extern InitBattleVariables
extern text_row_stride                   ; text.asm — unified engine row stride
extern ClearSprites
extern hide_window
extern LoadHpBarAndStatusTilePatterns
extern LoadHudTilePatterns
extern DuplicateEnemyHPBarTiles        ; battle_hud.asm — distinct palette-able enemy gauge IDs
extern DrawBattleHUDs
extern DrawEnemyHUD
extern SetPal_Battle                    ; engine/gfx/palettes.asm

; --- _InitBattleCommon dependencies (the real overworld→battle orchestration) ---
extern LoadFontTilePatterns              ; home/load_font.asm
extern LoadTextBoxTilePatterns           ; home/load_font.asm
extern LoadEnemyMonData                  ; load_enemy_mon_data.asm — build wEnemyMon*
extern LoadFrontSpriteByMonIndex         ; home/pics.asm — enemy front pic (generic)
extern HasMonFainted                     ; faint_switch.asm — ZF=1 → fainted
extern FlagAction                        ; flag_action.asm — ESI=array, CL=bit, BH=action
extern LoadBattleMonFromParty            ; faint_leaves.asm — build wBattleMon* + stat mods
extern DrawPlayerRedBackPic_Stub         ; home/pics.asm — player trainer (Red) back pic
extern LoadMonBackPic                    ; home/pics.asm — generic send-out back pic (MonBackPics)
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
    ; NOTE: zero the SCX/SCY SHADOWS too — DelayFrame's commit_shadow_regs copies
    ; H_SCX/H_SCY → IO_SCX/IO_SCY every frame, so without this the stale overworld
    ; fine-scroll is restored next frame and the whole battle canvas blits offset by
    ; however far the player had scrolled (the "battle lands in different places"
    ; bug). Same fix the status screen carries (status_screen.asm:174-175). The
    ; overworld recomputes H_SCX/H_SCY from player position on return, so zeroing
    ; here is safe. pret zeroes rSCX/rSCY analogues via the transition/ClearScreen.
    ;
    ; W-1 FIX: SAVE the overworld view pointer before zeroing it. Unlike hTileAnimations
    ; (re-armed from the tileset by LoadTilesetHeader on map re-entry) and H_SCX/H_SCY
    ; (recomputed from player position), NOTHING on the same-map post-battle return
    ; re-derives this pointer: LoadMapData explicitly does NOT (overworld.asm:2278 — the
    ; derivation lives in LoadWarpDestination, which the post-battle EnterMap skips because
    ; EndOfBattle set wDestinationWarpID=$FF "don't reposition"). So render_bg would stay on
    ; its flat-canvas path (ppu.asm:188 — zero ptr ⇒ decode W_TILEMAP directly) and paint
    ; stale W_TILEMAP = solid grass. Restored at the _InitBattleCommon tail (same map + same
    ; coords ⇒ the pre-battle value is still correct), mirroring status_screen.asm's view-ptr
    ; save/restore. The debug harnesses that call InitBattle standalone never return to the
    ; field, so the unrestored save is harmless there.
    mov ax, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]
    mov [saved_ow_view_ptr], ax
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + H_SCX], 0
    mov byte [ebp + H_SCY], 0
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    ; Disable BG tile animations for the battle. pret: DoBattleTransitionAndInit-
    ; BattleVariables does `xor a / ldh [hTileAnimations],a` (core.asm:6359). The
    ; port's collapsed battle init dropped it, so UpdateMovingBgTiles (frame.asm,
    ; every DelayFrame) kept cycling the overworld water/flower tiles ($03/$14) —
    ; but in battle those VRAM slots hold mon-pic / HUD tile data ($9000+), so the
    ; animation painted flowers over the battle graphics. LoadTilesetHeader re-arms
    ; it from the tileset on map re-entry, so no save/restore is needed here (same
    ; rationale as status_screen.asm:200-202, which must save/restore only because
    ; it returns to the very same overworld frame without a map reload).
    mov byte [ebp + hTileAnimations], 0
    call hide_window                         ; no window overlay — battle screen is the BG
    ; Load the HP-bar / status / ":L" tiles ($62-$71) the HUD needs. Tiles $79-$7E
    ; (the dialog box border) are byte-identical in both tile sets, so this does NOT
    ; clobber the box drawn below despite the load_font.asm warning.
    call LoadHpBarAndStatusTilePatterns
    call LoadHudTilePatterns                 ; HUD frame/divider tiles ($6d-$6f, $73-$78)
    call DuplicateEnemyHPBarTiles            ; $63-$6b -> battle-local vFont clones

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

    ; R1: species and initial HP-bar colors are now final, so bind the generated
    ; battle tile slots before the first cache rebuild/slide frame.
    call SetPal_Battle

    ; --- intro scene (proven DEBUG_BATTLE_LIVE order) ---
    call DrawPlayerRedBackPic_Stub             ; player trainer (Red) back pic — fixed sprite
    call SlideBattlePicsIn                      ; silhouette slide-in
    call DrawBattleIntroBox                      ; box + "Wild <nick> appeared!" + enemy HUD
    call SaveBattleScreen                        ; snapshot for menu re-entry
    call DrawBattlePokeballs                      ; party-status ball row
    call WaitForAPress
    call HideBattlePokeballs
    ; send-out: decode the actual sent-out mon's back sprite (generic, MonBackPics-indexed
    ; from wBattleMonSpecies2) → vBackPic. pret LoadMonBackPic; see home/pics.asm.
    call LoadMonBackPic

    ; --- the battle itself ---
    call MainInBattleLoop                       ; menu/turns/damage/faint/EXP/run
    call EndOfBattle                             ; win: PayDay/evo/reset; then whiteout

    ; --- W-1 FIX: restore the overworld view pointer InitBattle zeroed (see InitBattle),
    ;     so render_bg takes the overworld path again on the same-map post-battle EnterMap.
    ;     This survives EnterMap/LoadMapData (which never writes the pointer — verified:
    ;     ResetMapVariables et al. leave it alone); the trailing LoadCurrentMapView then
    ;     rebuilds wSurroundingTiles for this (unchanged) view. Without it the returning
    ;     overworld renders as one repeated tile. ---
    mov ax, [saved_ow_view_ptr]
    mov [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], ax

    ; --- W-1 FIX (sprites): re-enable OBJ rendering. HideBattlePokeballs
    ;     (pokeballs.asm:112, run after the intro) cleared LCDCF_OBJ_ON so the battle
    ;     proper draws no OBJ sprites; the overworld default (LCDC_DEFAULT_VAL=$E3) has
    ;     it set. Nothing on the return path restores it — EnableLCD (lcd_control.asm:38,
    ;     in LoadMapData) only touches the LCD-ON bit — so render_sprites' gate
    ;     (ppu.asm: test IO_LCDC,LCDCF_OBJ_ON / jz .done) stays closed and the player +
    ;     every NPC vanish while the BG renders fine. Restore it here alongside the view
    ;     ptr; EnterMap leaves IO_LCDC's OBJ bit alone, so this survives to the field. ---
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON

    ; --- restore the overworld dialog stride so the map/menus render at stride 20
    ;     (InitBattle raised it to 40 for the widescreen canvas), and put the message
    ;     box back on the overworld dialog projection. Every printer call site
    ;     declares its own projection, so this is belt-and-braces — but it is also the
    ;     one place a battle's centered box could otherwise outlive the battle. ---
    mov dword [text_row_stride], 20
    mov dword [text_msgbox], msgbox_dialog
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
