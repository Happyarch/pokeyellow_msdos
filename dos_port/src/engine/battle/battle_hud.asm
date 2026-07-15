; battle_hud.asm — DrawBattleHUDs (battle front-end, Wave 2 Stage 1b).
;
; Draws the two battle HUDs directly into the 40×25 widescreen W_TILEMAP canvas
; (the BG plane render_bg shows in battle — see init_battle.asm): the enemy HUD
; upper-left, the player HUD lower-right, the faithful GB default layout centered
; (GB coords + (10,3) offset). Each HUD shows the mon's name, ":L"level, and a
; 6-segment HP bar; the player HUD also shows the cur/max HP fraction.
;
; The HP-bar / level / digit logic mirrors the (already-shipped) party-menu
; renderer (src/engine/menus/party_menu.asm): the bar is "HP" + ":"gauge-left +
; 6 segments + cap, filled by pixels = curHP*48/maxHP (≥1 sliver if alive, 0 if
; fainted). All of it writes consecutive tiles within one row, so it is
; stride-agnostic and works at any canvas coordinate (unlike TextBoxBorder /
; multi-line PlaceString, which are locked to text.asm's 20-wide stride).
;
; HP-bar gauge tiles ($62-$71, ":L"=$6e) come from LoadHpBarAndStatusTilePatterns
; (called by InitBattle). Names are read from the battle-mon WRAM structs via
; PlaceString (single line → stride-agnostic). In a real battle those structs are
; populated by LoadBattleMonFromParty / the enemy build (Stage 2/3); for now the
; DEBUG_BATTLE harness seeds them.
;
; Register map: A=AL, HL=ESI, EBP=GB memory base; GB memory = [EBP+addr].
;
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

bits 32

%define FW        SCREEN_TILES_W   ; 40 — canvas stride

; HP-bar gauge tiles (HpBarAndStatus set, loaded over $62+); same as party_menu.
%define HPB_HP    0x71             ; narrow "HP" label
%define HPB_LEFT  0x62             ; ":" + gauge left edge
%define HPB_EMPTY 0x63             ; empty gauge segment; $63+n = n-pixel partial
%define HPB_FULL  0x6b             ; full (8px) gauge segment
; Right cap = pret DrawHPBar's [wHPBarType] switch: the player battle bar is
; ALWAYS drawn with type 1 (DrawHP / core.asm:5015 / core.asm:687 player turn)
; → cap $6D; the enemy bar ALWAYS with type 0 (core.asm:2034/4897/686) → $6C.
; The port's player/enemy helper split maps 1:1 onto that, so the cap is
; per-helper instead of a WRAM flag. (F-20, battle_menu golden: (18,9) $6D.)
%define HPB_END_PLAYER 0x6d        ; gauge right cap, wHPBarType 1 (battle player)
%define HPB_END_ENEMY  0x6c       ; gauge right cap, wHPBarType 0 (enemy)
; Battle-local clones of $63-$6b. These English glyph slots are not used by
; the battle UI, so the two HP bars can own distinct physical tile IDs.
%define TILE_LV   0x6e             ; ":L" level prefix
; HUD frame ("shelf"/divider) tiles — now loaded by LoadHudTilePatterns (the real
; BattleHudTiles, not the font_extra "ID No." placeholders): pret PlaceHUDTiles uses
; $73 (vertical connector), corner ($74 enemy / $77 player), $76 line, triangle
; ($78 enemy / $6f player).
%define T_HUD_73   0x73            ; vertical connector
%define T_HUD_LINE 0x76            ; horizontal underline segment
%define T_PCORNER  0x77            ; player corner (bottom-right)
%define T_PTRI     0x6f            ; player triangle (bottom-left)
%define T_ECORNER  0x74            ; enemy corner (bottom-left)
%define T_ETRI     0x78            ; enemy triangle (bottom-right)
%define CHAR_DIG0 0xF6             ; '0'; digit d → +d
%define CHAR_SLSH 0xF3             ; /
%define T_SP      0x7F             ; blank/space

; Layout geometry is the generated battle UI layout (Tier 1,
; assets/ui_layout_battle.inc ← ui_layout_battle_sidecar.json; edit with
; tools/ui_layout/battle.py — never hand-edit offsets here). Enemy upper-left,
; player lower-right; the bottom dialog box (init_battle.asm) is UI_DIALOG_BOX_*.
; The player HUD sits one row above pret's so the frame "shelf" gets its own
; row instead of colliding with the HP fraction (seeded into the sidecar).
; PROJ battle: enemy HUD = UI_ENEMY_{NAME,LV,HPBAR}_OFS
; PROJ battle: player HUD = UI_PLAYER_{NAME,LV,HPBAR,HPFRAC}_OFS
%define E_NAME    UI_ENEMY_NAME_OFS
%define E_LV      UI_ENEMY_LV_OFS      ; ":L" + 2 digits
%define E_HPBAR   UI_ENEMY_HPBAR_OFS   ; "HP" + ":" + 6 seg + cap (9 tiles)
%define P_NAME    UI_PLAYER_NAME_OFS
%define P_LV      UI_PLAYER_LV_OFS
%define P_HPBAR   UI_PLAYER_HPBAR_OFS
%define P_HPFRAC  UI_PLAYER_HPFRAC_OFS ; "cur/max" (3 + 1 + 3 tiles)
; PROJ battle: the player connectors stack in the element's top-RIGHT column
%define P_FRAME_CONN (UI_PLAYER_HUD_FRAME_OFS + UI_PLAYER_HUD_FRAME_GBW - 1)

section .bss
; AnimateHPBar loop state (kept in BSS so draw_hp_bar / print_num3 / DelayFrame
; register clobbering can't corrupt it; the public entry points take registers).
anim_new_addr: resd 1          ; GB addr of the final HP word (big-endian)
anim_max_addr: resd 1          ; GB addr of the maxHP word
anim_bar_off:  resd 1          ; W_TILEMAP offset of the bar
anim_frac_off: resd 1          ; W_TILEMAP offset of the HP "cur" digits (0 = none)
anim_cur_hp:   resd 1          ; the HP value currently displayed (ticks toward final)
anim_last_px:  resb 1          ; last-drawn pixel count (walked ±1 toward target each unit)
anim_target_px: resb 1         ; this HP-unit tick's freshly computed pixel target
anim_enemy:     resb 1         ; nonzero -> use cloned enemy HP gauge tiles

section .text

global DrawBattleHUDs
global DrawEnemyHUD
global DrawEnemyHUDAndHPBar
global DrawPlayerHUDAndHPBar
global DrawPlayerHUD
global DrawEnemyHUDFrame
global DrawPlayerHUDFrame
global AnimateEnemyHPBar
global AnimatePlayerHPBar
extern PlaceString
extern DelayFrame
extern Delay3                          ; frame.asm — wait 3 frames (pret UpdateHPBar2 tail)
extern g_tilecache_dirty                ; ppu.asm — cloned VRAM patterns need re-decode
extern GetHealthBarColor                ; fade.asm — pixel length -> green/yellow/red id
extern SetPal_Battle                    ; palettes.asm — consume both live HP-color ids
extern CopyData                         ; home/copy_data.asm — wLoadedMon staging

; DrawBattleHUDs draws both HUDs; the battle intro draws only the enemy HUD (the
; player side shows party-status pokéballs until the battle proper), so the two
; halves are split into DrawEnemyHUD / DrawPlayerHUD.
DrawBattleHUDs:
    ; HUD names are drawn with PlaceString, which (like pret's PlaceNextChar) calls
    ; PrintLetterDelay — so make sure the per-letter delay is OFF here (BIT_TEXT_DELAY is
    ; set only while a dialog MESSAGE prints). Otherwise the mon names would type out.
    and byte [ebp + W_LETTER_PRINTING_DELAY], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    ; pret DrawHUDsAndHPBars order: PLAYER first, then ENEMY (core.asm:1886).
    ; Load-bearing since the wLoadedMon staging landed: both HUDs write
    ; wLoadedMonLevel, and the surviving value must be the ENEMY's (measured in
    ; the battle_menu golden: wLoadedMon = battle mon, level byte = enemy's).
    call DrawPlayerHUD
    call DrawEnemyHUD
    ; Both bars have now refreshed their color IDs; publish their independent
    ; palette slots together (the enemy uses cloned gauge tile IDs).
    call SetPal_Battle
    ret
DrawPlayerHUD:
    ; ===== player HUD (lower-right) =====
    ; pret DrawPlayerHUDAndHPBar draws the frame FIRST: PlacePlayerHUDTiles +
    ; the (18,9) $73 connector, which DrawHP later OVERWRITES with the HP bar's
    ; right cap $6D — pret's second $73 is dead the moment the bar draws. The
    ; port used to draw the frame/connector last, leaving $73 where the golden
    ; shows $6D (F-18). Frame first, bar last, like pret.
    call DrawPlayerHUDFrame
    mov byte [ebp + W_TILEMAP + P_FRAME_CONN], T_HUD_73
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
    mov esi, W_TILEMAP + P_NAME
    lea eax, [ebp + wBattleMonNick]      ; PlaceString src = flat-linear
    call PlaceString
    movzx eax, byte [ebp + wBattleMonLevel]
    mov edi, W_TILEMAP + P_LV
    call print_level
    mov ebx, wBattleMonHP
    mov esi, wBattleMonMaxHP
    call calc_hp_pixels
    mov esi, wPlayerHPBarColor
    call GetHealthBarColor
    mov edi, W_TILEMAP + P_HPBAR
    call draw_hp_bar
    ; player HP fraction: cur / max
    movzx eax, byte [ebp + wBattleMonHP]
    shl eax, 8
    mov al, [ebp + wBattleMonHP + 1]
    mov edi, W_TILEMAP + P_HPFRAC
    call print_num3
    mov byte [ebp + W_TILEMAP + P_HPFRAC + 3], CHAR_SLSH
    movzx eax, byte [ebp + wBattleMonMaxHP]
    shl eax, 8
    mov al, [ebp + wBattleMonMaxHP + 1]
    mov edi, W_TILEMAP + P_HPFRAC + 4
    call print_num3
    ret

DrawEnemyHUD:
    ; ===== enemy HUD (upper-left) =====
    mov esi, W_TILEMAP + E_NAME          ; PlaceString: ESI=dest(GB offset), EAX=src(flat)
    lea eax, [ebp + wEnemyMonNick]
    call PlaceString
    movzx eax, byte [ebp + wEnemyMonLevel]
    ; pret DrawEnemyHUDAndHPBar stages the level in wLoadedMonLevel before
    ; PrintLevel (core.asm:1969-1970) — battle-visible WRAM the goldens compare.
    mov [ebp + wLoadedMonLevel], al
    mov edi, W_TILEMAP + E_LV
    call print_level
    mov ebx, wEnemyMonHP                 ; calc_hp_pixels: EBX=curHP addr, ESI=maxHP addr
    mov esi, wEnemyMonMaxHP
    call calc_hp_pixels                  ; → EDX = fill pixels
    mov esi, wEnemyHPBarColor
    call GetHealthBarColor
    mov edi, W_TILEMAP + E_HPBAR
    call draw_enemy_hp_bar
    call DrawEnemyHUDFrame
    ret

; ---------------------------------------------------------------------------
; DrawEnemyHUDAndHPBar — faithful enemy-ONLY HUD+HP-bar redraw (pret
; engine/battle/core.asm:1951). Used where the port previously substituted the
; both-bars DrawHUDsAndHPBars. The port's DrawEnemyHUD already is the faithful
; enemy-only name+level+HP-bar+frame redraw (stride-agnostic, writing W_TILEMAP that
; render_bg blits every frame). DIVERGENCES vs pret (all hardware/pre-existing, not
; invented here): pret's hAutoBGTransferEnabled suspend/resume bracket is dropped —
; it gates the GB torus-tilemap DMA (do_bg_transfer, frame.asm) which the native
; render_bg does not use and which the overworld deliberately keeps disabled, so
; forcing it on would run a pointless per-frame copy; pret's leading ClearScreenArea
; of the 12×4 HUD tile area (home/copy2.asm not linked here; only needed when the
; enemy name changes length — a multi-mon case not reachable in a wild battle);
; CenterMonName (never ported → short names flush-left); status-condition-vs-level
; (status_ailments.asm is an empty placeholder → always prints level); the
; GetBattleHealthBarColor/RunPaletteCommand recolor tail (Phase-5 palette deferral).
DrawEnemyHUDAndHPBar:
    jmp DrawEnemyHUD                              ; name + level + HP bar + frame (enemy-only)

; ---------------------------------------------------------------------------
; DrawPlayerHUDAndHPBar — faithful player-ONLY HUD+HP-bar redraw (pret
; engine/battle/core.asm:DrawPlayerHUDAndHPBar). Retires the former bare-ret stub in
; battle_exp_stubs.asm: the port's DrawPlayerHUD already is the faithful player-side
; name+level+HP-bar+frame redraw into W_TILEMAP, so this is the pret-named alias
; (same shape as DrawEnemyHUDAndHPBar above). Same Phase-5 palette / hAutoBGTransfer
; divergences as the enemy-side alias apply.
DrawPlayerHUDAndHPBar:
    jmp DrawPlayerHUD                             ; name + level + HP bar + frame (player-only)

; ---------------------------------------------------------------------------
; DrawEnemyHUDFrame / DrawPlayerHUDFrame — the HUD underline "shelf" (pret
; PlaceEnemyHUDTiles / PlacePlayerHUDTiles + PlaceHUDTiles): a $73 connector with
; the row below = corner + 8×$76 underline + triangle, at the centered (+10,+3)
; positions. The enemy frame sits below the enemy HP bar; the player frame is the
; shelf under the intro pokéball row. EBP = GB base. Clobbers EAX/EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
DrawEnemyHUDFrame:
    ; PROJ battle: $73 connector = UI_ENEMY_HUD_FRAME_OFS (element top-left)
    mov edi, W_TILEMAP + UI_ENEMY_HUD_FRAME_OFS
    mov esi, 1                            ; underline marches right
    mov bh, T_ECORNER
    mov bl, T_ETRI
    jmp place_hud_frame
; (P_FRAME_CONN defined with the other P_* equates at the top of the file —
; DrawPlayerHUD uses it too, and %defines must precede first use.)
DrawPlayerHUDFrame:
    ; pret PlacePlayerHUDTiles: ONE $73 connector + the shelf row below. The
    ; element rect's top row is the UPPER connector row (DrawPlayerHUD's, F-18),
    ; so this frame's $73 sits one row down at +FW.
    mov edi, W_TILEMAP + P_FRAME_CONN + FW
    mov esi, -1                           ; underline marches left
    mov bh, T_PCORNER
    mov bl, T_PTRI
    ; fall through
; place_hud_frame — EDI=GB offset of the $73 tile, ESI=signed step (±1),
; BH=corner tile, BL=triangle tile.
place_hud_frame:
    mov byte [ebp + edi], T_HUD_73
    add edi, FW                           ; row below
    mov [ebp + edi], bh                   ; corner
    mov ecx, 8
.line:
    add edi, esi
    mov byte [ebp + edi], T_HUD_LINE
    dec ecx
    jnz .line
    add edi, esi
    mov [ebp + edi], bl                   ; triangle
    ret

; --- draw_hp_bar — 6-segment HP gauge at [ebp+EDI]; EDX = fill pixels (0..48) ---
; "HP" + ":"gauge-left + 6 segments + cap. Clobbers EAX/ECX/EDX/EDI.
draw_hp_bar:
    mov byte [ebp + edi], HPB_HP
    mov byte [ebp + edi + 1], HPB_LEFT
    mov byte [ebp + edi + 8], HPB_END_PLAYER
    add edi, 2                           ; first of 6 gauge segments
    mov ecx, 6
.seg:
    cmp edx, 8
    jb .partial
    mov byte [ebp + edi], HPB_FULL
    sub edx, 8
    jmp .next
.partial:
    lea eax, [edx + HPB_EMPTY]           ; $63 + n-pixel partial (n=0 → empty)
    mov [ebp + edi], al
    xor edx, edx                         ; rest of the gauge stays empty
.next:
    inc edi
    dec ecx
    jnz .seg
    ret

; draw_enemy_hp_bar — same geometry, but its 9 gauge patterns come from the
; battle-local copies made by DuplicateEnemyHPBarTiles.
draw_enemy_hp_bar:
    mov byte [ebp + edi], HPB_HP
    mov byte [ebp + edi + 1], HPB_LEFT
    mov byte [ebp + edi + 8], HPB_END_ENEMY
    add edi, 2
    mov ecx, 6
.seg:
    cmp edx, 8
    jb .partial
    mov al, [enemy_hp_tile_ids + 8]
    mov [ebp + edi], al
    sub edx, 8
    jmp .next
.partial:
    mov al, [enemy_hp_tile_ids + edx]
    mov [ebp + edi], al
    xor edx, edx
.next:
    inc edi
    dec ecx
    jnz .seg
    ret

; Copy $63-$6b (empty, partial 1..7, full) to unused English glyph slots.
; Called after the source HP/HUD patterns are loaded; all registers preserved.
global DuplicateEnemyHPBarTiles
DuplicateEnemyHPBarTiles:
    pushad
    mov esi, GB_VCHARS2 + HPB_EMPTY * TILE_SIZE
    xor ecx, ecx
.copy:
    movzx eax, byte [enemy_hp_tile_ids + ecx]
    sub eax, 0x80
    shl eax, 4
    lea edi, [ebp + GB_VFONT + eax]
    mov eax, [ebp + esi]
    mov [edi], eax
    mov eax, [ebp + esi + 4]
    mov [edi + 4], eax
    mov eax, [ebp + esi + 8]
    mov [edi + 8], eax
    mov eax, [ebp + esi + 12]
    mov [edi + 12], eax
    add esi, TILE_SIZE
    inc ecx
    cmp ecx, 9
    jb .copy
    mov byte [g_tilecache_dirty], 1
    popad
    ret

; --- calc_hp_pixels — EBX=curHP addr, ESI=maxHP addr (big-endian words) ---
; → EDX = curHP*48/maxHP (≥1 if alive, 0 if fainted). Clobbers EAX/ECX.
calc_hp_pixels:
    movzx eax, byte [ebp + ebx]          ; curHP high
    shl eax, 8
    mov al, [ebp + ebx + 1]              ; curHP low → EAX = curHP
    ; fall through to hp_to_pixels
; --- hp_to_pixels — EAX=curHP value, ESI=maxHP addr → EDX pixels (≥1 alive, 0 dead).
; The pixel math factored out so the animation can compute pixels for an arbitrary
; (ticking) HP value, not just one read from WRAM. Clobbers EAX/ECX.
hp_to_pixels:
    test eax, eax
    jz .dead
    imul eax, eax, 48
    movzx ecx, byte [ebp + esi]          ; maxHP high
    shl ecx, 8
    mov cl, [ebp + esi + 1]              ; maxHP low → ECX = maxHP
    ; BUG{class=data-model; pret=engine/gfx/hp_bar.asm:GetHPBarLength; behavior=max HP at least 256 uses pret's lossy quarter-scale division at BUG_FIX_LEVEL below 2; evidence=pret source GetHPBarLength plus guarded x86 implementation; lifetime=permanent at compatibility levels 0 and 1}
    ; pret GetHPBarLength (gfx/hp_bar.asm:17-33) right-shifts BOTH
    ; curHP*48 and maxHP by 2 (lossy ÷4) when maxHP >= 256 before an 8-bit divide,
    ; so high-maxHP mons get a slightly imprecise bar. Preserved at levels 0/1.
%if BUG_FIX_LEVEL < 2
    cmp ecx, 256
    jb .exactDiv
    shr eax, 2
    shr ecx, 2
.exactDiv:
%endif
    xor edx, edx
    div ecx                              ; EAX = curHP*48 / maxHP
    test eax, eax
    jnz .ok
    mov eax, 1                           ; alive → at least a sliver
.ok:
    mov edx, eax
    ret
.dead:
    xor edx, edx
    ret

; ---------------------------------------------------------------------------
; AnimateEnemyHPBar / AnimatePlayerHPBar — tick a HUD's HP bar from a starting HP
; value (ECX) down/up to the FINAL value already stored in WRAM, the port's stride-
; agnostic stand-in for pret UpdateHPBar. The bar (and, for the player, the HP "cur"
; digits) is redrawn each time the pixel count changes, with a 2-frame wait — so a
; hit visibly drains the gauge instead of snapping. A 0-difference (status move,
; miss) animates nothing. In: ECX = old HP value; EBP = GB base.
; ---------------------------------------------------------------------------
AnimateEnemyHPBar:
    mov ebx, wEnemyMonHP
    mov esi, wEnemyMonMaxHP
    mov edi, W_TILEMAP + E_HPBAR
    xor edx, edx                         ; enemy HUD: no HP number
    mov byte [anim_enemy], 1
    jmp AnimateHPBar
AnimatePlayerHPBar:
    mov ebx, wBattleMonHP
    mov esi, wBattleMonMaxHP
    mov edi, W_TILEMAP + P_HPBAR
    mov edx, W_TILEMAP + P_HPFRAC        ; player HUD: tick the "cur" digits too
    mov byte [anim_enemy], 0
    ; fall through

; AnimateHPBar — faithful port of pret UpdateHPBar2 (engine/gfx/hp_bar.asm:48-135).
; EBX=final-HP addr, ESI=maxHP addr, EDI=bar offset, ECX=old HP, EDX=HP-cur-digits
; offset (0 = none). Internals run off the BSS copy (so register clobbering by
; DelayFrame/draw_hp_bar/print_num3 is harmless). pret cadence, both fixed here:
;   • the HP NUMBER ticks every HP unit (player HUD), with a DelayFrame, independent
;     of pixel-fill change (pret UpdateHPBar_PrintHPNumber, unconditional per unit);
;   • the bar walks EVERY intermediate pixel (2 frames each), not a jump to the final
;     pixel — matters for low-maxHP mons where one HP unit spans >1 pixel of 48
;     (pret UpdateHPBar_AnimateHPBar). A trailing Delay3 settles the bar (pret jp Delay3);
;   • a genuine zero-delta call (status move / miss) does nothing — no draw/delay/settle
;     (pret's leading `call UpdateHPBar_CompareNewHPToOldHP / ret z`).
AnimateHPBar:
    mov [anim_new_addr], ebx
    mov [anim_max_addr], esi
    mov [anim_bar_off], edi
    mov [anim_cur_hp], ecx
    mov [anim_frac_off], edx
    ; zero-delta (old == new) → return with no draw/delay/settle (pret ret z)
    mov ebx, [anim_new_addr]
    movzx eax, byte [ebp + ebx]
    shl eax, 8
    mov al, [ebp + ebx + 1]
    cmp ecx, eax
    je .reallyDone
    mov eax, ecx                         ; pixels(old HP) → seed the walked "last drawn" count
    call hp_to_pixels
    mov [anim_last_px], dl
.loop:
    mov ebx, [anim_new_addr]             ; target = final HP (big-endian)
    movzx eax, byte [ebp + ebx]
    shl eax, 8
    mov al, [ebp + ebx + 1]
    mov ecx, [anim_cur_hp]
    cmp ecx, eax
    je .done
    jb .up
    dec ecx                              ; HP decrease (damage)
    jmp .stepped
.up:
    inc ecx                              ; HP increase (heal)
.stepped:
    mov [anim_cur_hp], ecx
    ; ---- number: tick digits + DelayFrame every HP unit (player HUD only) ----
    mov edi, [anim_frac_off]
    test edi, edi
    jz .noNumber
    movzx eax, cx                        ; HP < 1000 always fits 16 bits
    call print_num3
    call DelayFrame
.noNumber:
    ; ---- bar: walk every intermediate pixel toward this unit's target, 2 frames each ----
    mov eax, [anim_cur_hp]               ; reload (print_num3 clobbers ECX)
    mov esi, [anim_max_addr]
    call hp_to_pixels                    ; EDX = pixel target for this HP tick
    mov [anim_target_px], dl
    mov al, [anim_last_px]
    cmp al, dl
    je .loop                             ; no pixel-fill change this unit
    jb .pixInc                           ; last < target → fill up (heal)
.pixDec:
    dec byte [anim_last_px]
    movzx edx, byte [anim_last_px]
    mov edi, [anim_bar_off]
    call draw_animated_hp_bar
    call DelayFrame
    call DelayFrame
    mov al, [anim_last_px]
    cmp al, [anim_target_px]
    jne .pixDec
    jmp .loop
.pixInc:
    inc byte [anim_last_px]
    movzx edx, byte [anim_last_px]
    mov edi, [anim_bar_off]
    call draw_animated_hp_bar
    call DelayFrame
    call DelayFrame
    mov al, [anim_last_px]
    cmp al, [anim_target_px]
    jne .pixInc
    jmp .loop
.done:
    ; Match pret's UpdateHPBar tail: color follows the final fill length, not
    ; just the initial HUD draw.  The duplicate enemy gauge tiles make the two
    ; slots independent even while the bars animate in opposite directions.
    mov eax, [anim_cur_hp]
    mov esi, [anim_max_addr]
    call hp_to_pixels
    cmp byte [anim_enemy], 0
    je .playerColor
    mov esi, wEnemyHPBarColor
    jmp .setColor
.playerColor:
    mov esi, wPlayerHPBarColor
.setColor:
    call GetHealthBarColor
    call SetPal_Battle
    call Delay3                          ; pret trailing settle (jp Delay3)
.reallyDone:
    ret

draw_animated_hp_bar:
    cmp byte [anim_enemy], 0
    je draw_hp_bar
    jmp draw_enemy_hp_bar

; --- print_num2 — 2-digit (tens, ones) at [ebp+EDI]; AL = value (<100) ---
; Leading space if tens == 0. Clobbers EAX/ECX/EDX.
print_num2:
    movzx eax, al
    xor edx, edx
    mov ecx, 10
    div ecx                              ; EAX=tens, EDX=ones
    test al, al
    jnz .tens
    mov byte [ebp + edi], T_SP
    jmp .ones
.tens:
    add al, CHAR_DIG0
    mov [ebp + edi], al
.ones:
    add dl, CHAR_DIG0
    mov [ebp + edi + 1], dl
    ret

; --- print_level — EDI = ":L" tile position, AL = level. Faithful to pret
; PrintLevel (home/pokemon.asm:PrintLevel): level < 100 → ":L" + 2 digits at
; EDI/EDI+1; level >= 100 → overwrite the ":L" tile with 3 digits at EDI.
print_level:
    cmp al, 100
    jae .threeDigits
    mov byte [ebp + edi], TILE_LV
    inc edi
    call print_num2
    ret
.threeDigits:
    movzx eax, al                        ; 3 digits start where ":L" was
    call print_num3
    ret

; --- print_num3 — 3-digit (hundreds, tens, ones) at [ebp+EDI]; AX = value ---
; Leading spaces for leading zeros. Clobbers EAX/EBX/ECX/EDX. (Mirrors party_menu.)
print_num3:
    movzx eax, ax
    xor edx, edx
    mov ecx, 100
    div ecx                              ; EAX=hundreds, EDX=remainder
    mov bl, al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx                              ; EAX=tens, EDX=ones
    mov bh, al
    mov cl, dl
    test bl, bl
    jnz .h
    mov byte [ebp + edi], T_SP
    test bh, bh
    jnz .t
    mov byte [ebp + edi + 1], T_SP
    jmp .o
.h:
    add bl, CHAR_DIG0
    mov [ebp + edi], bl
.t:
    add bh, CHAR_DIG0
    mov [ebp + edi + 1], bh
.o:
    add cl, CHAR_DIG0
    mov [ebp + edi + 2], cl
    ret

section .data
; $63+$n (n=0..8): empty, partial 1..7, full.  These IDs are deliberately
; noncontiguous so no live English battle glyph is overwritten.
; F-19 FIX (fidelity plan Stage 2): these ids used to be $E9,$EA,$EB,$EC,$EE,
; $EF,$F0,$F1,$F4 — claimed "unused English glyph slots", but only $E9-$EB are
; unused (charmap.asm): $EC=▷, $EE=▼(!), $EF=♂, $F0=¥, $F1=×, $F4=comma. The
; clones clobbered the battle dialog's ▼ prompt glyph (and ×/¥/▷ wherever they
; appear in battle text). Ids $C0-$DF have NO charmap mapping at all — no text
; can ever reference them — so the nine clones live there now.
enemy_hp_tile_ids: db 0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc6, 0xc7, 0xc8
