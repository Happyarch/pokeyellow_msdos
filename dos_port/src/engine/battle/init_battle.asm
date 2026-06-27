; init_battle.asm — InitBattle (battle front-end, Wave 2 Stage 0/0.5 scaffold).
;
; Stage-0.5 baseline: enter battle mode and draw a deterministic, CENTERED GB-sized
; battle frame so the render path is proven before the real HUD (Stage 1). Per the
; layout decision (user, 2026-06-27) the faithful GB 20×18 screen is built and
; centered in the 320×200 viewport; widescreen spacing is a later iteration pass.
;
; Pipeline (mirrors the menu screens): build content in W_TILEMAP (40-wide scratch)
; → copy the 20×18 rect into GB_TILEMAP1 (32-stride GB tilemap) → one centered
; window descriptor (set_single_window) that render_window composites over the
; battle-cleared backbuffer (frame.asm clears to bg while wIsInBattle).
;
; In (seeded by the DEBUG_BATTLE harness): wEnemyMonSpecies, wEnemyMonLevel.
; Register map: A=AL, HL=ESI, EBP=GB memory base; GB memory = [EBP+addr].
;
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

%define TILE_SPC   0x7F          ; blank/space tile
%define GB_W       20            ; GB screen width in tiles
%define GB_H       18            ; GB screen height in tiles
; centered placement of the 160×144 GB screen in 320×200
%define BAT_WX     ((RENDER_W - GB_W*8) / 2)    ; = 80
%define BAT_WY     ((RENDER_H - GB_H*8) / 2)    ; = 28

section .text

global InitBattle
extern InitBattleVariables
extern TextBoxBorder
extern set_single_window
extern ClearSprites

InitBattle:
    call InitBattleVariables
    mov byte [ebp + wIsInBattle], 1          ; wild battle (placeholder)
    call ClearSprites                        ; drop the overworld OAM (player etc.)

    ; --- build a full-frame box over the 20×18 region of W_TILEMAP ---
    ; TextBoxBorder: ESI=dest (W_TILEMAP offset), BL=interior width, BH=interior height.
    mov esi, W_TILEMAP
    mov bl, GB_W - 2                          ; interior width = 18
    mov bh, GB_H - 2                          ; interior height = 16
    call TextBoxBorder

    ; --- copy 20×18 from W_TILEMAP (stride 40) → GB_TILEMAP1 (stride 32) ---
    xor edx, edx                              ; row = 0
.copyrow:
    mov eax, edx
    imul eax, SCREEN_TILES_W                  ; row * 40
    lea esi, [ebp + eax + W_TILEMAP]
    mov eax, edx
    shl eax, 5                                ; row * 32
    lea edi, [ebp + eax + GB_TILEMAP1]
    mov ecx, GB_W                             ; 20 bytes
    rep movsb
    inc edx
    cmp edx, GB_H
    jb .copyrow

    ; --- one centered window descriptor showing the GB frame ---
    mov eax, BAT_WX                           ; wx = 80
    mov ebx, BAT_WY                           ; wy = 28
    mov ecx, GB_W * 8                         ; clip_w = 160
    mov edx, BAT_WY + GB_H * 8                ; max_y = 28 + 144 = 172
    mov esi, GB_TILEMAP1
    xor edi, edi                              ; start_row = 0
    call set_single_window
    ret
