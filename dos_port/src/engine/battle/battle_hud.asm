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

bits 32

%define FW        SCREEN_TILES_W   ; 40 — canvas stride

; HP-bar gauge tiles (HpBarAndStatus set, loaded over $62+); same as party_menu.
%define HPB_HP    0x71             ; narrow "HP" label
%define HPB_LEFT  0x62             ; ":" + gauge left edge
%define HPB_EMPTY 0x63             ; empty gauge segment; $63+n = n-pixel partial
%define HPB_FULL  0x6b             ; full (8px) gauge segment
%define HPB_END   0x6c             ; gauge right cap
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

; centered default layout: GB coords + (10 col, 3 row). Enemy upper-left, player
; lower-right; the bottom dialog box (init_battle.asm) sits at rows 15-20.
%define E_NAME    (3 * FW + 11)
%define E_LV      (4 * FW + 14)    ; ":L" + 2 digits — pret hlcoord 4,1 → col 4+10=14
%define E_HPBAR   (5 * FW + 12)    ; "HP" + ":" + 6 seg + cap (9 tiles)
; Player HUD shifted up one row (to pret's +3 centering, matching the enemy) so the
; HUD frame "shelf" gets its own row (14) instead of colliding with the HP fraction.
%define P_NAME    (10 * FW + 20)
%define P_LV      (11 * FW + 24)
%define P_HPBAR   (12 * FW + 20)
%define P_HPFRAC  (13 * FW + 21)   ; "cur/max" (3 + 1 + 3 tiles)
; PROJ battle-ui: enemy HUD GB(1,0)/(4,1)/(2,2) --(+10col,+3row)--> canvas name(11,3) lv(14,4) hpbar(12,5)
; PROJ battle-ui: player HUD GB(10,7)/.. --(+10col,+3row)--> canvas name(20,10) lv(24,11) hpbar(20,12) frac(21,13); HUD shelf (PlacePlayerHUDTiles) row 14

section .bss
; AnimateHPBar loop state (kept in BSS so draw_hp_bar / print_num3 / DelayFrame
; register clobbering can't corrupt it; the public entry points take registers).
anim_new_addr: resd 1          ; GB addr of the final HP word (big-endian)
anim_max_addr: resd 1          ; GB addr of the maxHP word
anim_bar_off:  resd 1          ; W_TILEMAP offset of the bar
anim_frac_off: resd 1          ; W_TILEMAP offset of the HP "cur" digits (0 = none)
anim_cur_hp:   resd 1          ; the HP value currently displayed (ticks toward final)
anim_last_px:  resb 1          ; last drawn pixel count (redraw only on change)

section .text

global DrawBattleHUDs
global DrawEnemyHUD
global DrawPlayerHUD
global DrawEnemyHUDFrame
global DrawPlayerHUDFrame
global AnimateEnemyHPBar
global AnimatePlayerHPBar
extern PlaceString
extern DelayFrame

; DrawBattleHUDs draws both HUDs; the battle intro draws only the enemy HUD (the
; player side shows party-status pokéballs until the battle proper), so the two
; halves are split into DrawEnemyHUD / DrawPlayerHUD.
DrawBattleHUDs:
    ; HUD names are drawn with PlaceString, which (like pret's PlaceNextChar) calls
    ; PrintLetterDelay — so make sure the per-letter delay is OFF here (BIT_TEXT_DELAY is
    ; set only while a dialog MESSAGE prints). Otherwise the mon names would type out.
    and byte [ebp + W_LETTER_PRINTING_DELAY], (~(1 << BIT_TEXT_DELAY)) & 0xFF
    call DrawEnemyHUD
    ; fall through to DrawPlayerHUD
DrawPlayerHUD:
    ; ===== player HUD (lower-right) =====
    mov esi, W_TILEMAP + P_NAME
    lea eax, [ebp + wBattleMonNick]      ; PlaceString src = flat-linear
    call PlaceString
    mov byte [ebp + W_TILEMAP + P_LV], TILE_LV
    movzx eax, byte [ebp + wBattleMonLevel]
    mov edi, W_TILEMAP + P_LV + 1
    call print_num2
    mov ebx, wBattleMonHP
    mov esi, wBattleMonMaxHP
    call calc_hp_pixels
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
    call DrawPlayerHUDFrame               ; the shelf persists into the battle proper
    ret

DrawEnemyHUD:
    ; ===== enemy HUD (upper-left) =====
    mov esi, W_TILEMAP + E_NAME          ; PlaceString: ESI=dest(GB offset), EAX=src(flat)
    lea eax, [ebp + wEnemyMonNick]
    call PlaceString
    mov byte [ebp + W_TILEMAP + E_LV], TILE_LV
    movzx eax, byte [ebp + wEnemyMonLevel]
    mov edi, W_TILEMAP + E_LV + 1
    call print_num2
    mov ebx, wEnemyMonHP                 ; calc_hp_pixels: EBX=curHP addr, ESI=maxHP addr
    mov esi, wEnemyMonMaxHP
    call calc_hp_pixels                  ; → EDX = fill pixels
    mov edi, W_TILEMAP + E_HPBAR
    call draw_hp_bar
    call DrawEnemyHUDFrame
    ret

; ---------------------------------------------------------------------------
; DrawEnemyHUDFrame / DrawPlayerHUDFrame — the HUD underline "shelf" (pret
; PlaceEnemyHUDTiles / PlacePlayerHUDTiles + PlaceHUDTiles): a $73 connector with
; the row below = corner + 8×$76 underline + triangle, at the centered (+10,+3)
; positions. The enemy frame sits below the enemy HP bar; the player frame is the
; shelf under the intro pokéball row. EBP = GB base. Clobbers EAX/EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
DrawEnemyHUDFrame:
    mov edi, W_TILEMAP + (5 * FW + 11)    ; $73 at canvas (11,5) = GB(1,2)+(10,3)
    mov esi, 1                            ; underline marches right
    mov bh, T_ECORNER
    mov bl, T_ETRI
    jmp place_hud_frame
DrawPlayerHUDFrame:
    ; pret DrawPlayerHUDAndHPBar writes a 2nd $73 connector at hlcoord 18,9 →
    ; canvas (28,12), above the PlacePlayerHUDTiles $73 at (28,13).
    mov byte [ebp + W_TILEMAP + (12 * FW + 28)], T_HUD_73
    mov edi, W_TILEMAP + (13 * FW + 28)   ; $73 at canvas (28,13) = GB(18,10)+(10,3)
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
    mov byte [ebp + edi + 8], HPB_END
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
    jmp AnimateHPBar
AnimatePlayerHPBar:
    mov ebx, wBattleMonHP
    mov esi, wBattleMonMaxHP
    mov edi, W_TILEMAP + P_HPBAR
    mov edx, W_TILEMAP + P_HPFRAC        ; player HUD: tick the "cur" digits too
    ; fall through

; AnimateHPBar — EBX=final-HP addr, ESI=maxHP addr, EDI=bar offset, ECX=old HP,
; EDX=HP-cur-digits offset (0 = none). Internals run off the BSS copy.
AnimateHPBar:
    mov [anim_new_addr], ebx
    mov [anim_max_addr], esi
    mov [anim_bar_off], edi
    mov [anim_cur_hp], ecx
    mov [anim_frac_off], edx
    mov eax, ecx                         ; pixels(old HP) → seed the "last drawn" count
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
    inc ecx                              ; HP increase (heal) — faithful, unused now
.stepped:
    mov [anim_cur_hp], ecx
    mov eax, ecx
    mov esi, [anim_max_addr]
    call hp_to_pixels                    ; EDX = pixels for this tick
    cmp dl, [anim_last_px]
    je .loop                             ; same pixel count → keep ticking (no draw/delay)
    mov [anim_last_px], dl
    mov edi, [anim_bar_off]              ; redraw the bar (EDX = pixels)
    call draw_hp_bar
    mov edi, [anim_frac_off]             ; redraw the "cur" digits (player only)
    test edi, edi
    jz .nofrac
    movzx eax, word [anim_cur_hp]
    call print_num3
.nofrac:
    call DelayFrame                      ; ~2 frames per pixel step (pret cadence)
    call DelayFrame
    jmp .loop
.done:
    ret

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
