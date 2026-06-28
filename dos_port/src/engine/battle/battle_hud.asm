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
%define CHAR_DIG0 0xF6             ; '0'; digit d → +d
%define CHAR_SLSH 0xF3             ; /
%define T_SP      0x7F             ; blank/space

; centered default layout: GB coords + (10 col, 3 row). Enemy upper-left, player
; lower-right; the bottom dialog box (init_battle.asm) sits at rows 15-20.
%define E_NAME    (3 * FW + 11)
%define E_LV      (4 * FW + 15)    ; ":L" + 2 digits
%define E_HPBAR   (5 * FW + 12)    ; "HP" + ":" + 6 seg + cap (9 tiles)
%define P_NAME    (11 * FW + 20)
%define P_LV      (12 * FW + 24)
%define P_HPBAR   (13 * FW + 20)
%define P_HPFRAC  (14 * FW + 21)   ; "cur/max" (3 + 1 + 3 tiles)
; PROJ battle-ui: enemy HUD GB(1,0)/(4,1)/(2,2) --(+10col,+3row)--> canvas name(11,3) lv(15,4) hpbar(12,5)
; PROJ battle-ui: player HUD GB(10,7)/.. --(+10col,+3row)--> canvas name(20,11) lv(24,12) hpbar(20,13) frac(21,14)

section .text

global DrawBattleHUDs
extern PlaceString

DrawBattleHUDs:
    ; ===== enemy HUD (upper-left) =====
    mov esi, W_TILEMAP + E_NAME          ; PlaceString: ESI=dest, EDX=src (both GB offsets)
    mov edx, wEnemyMonNick
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

    ; ===== player HUD (lower-right) =====
    mov esi, W_TILEMAP + P_NAME
    mov edx, wBattleMonNick
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
