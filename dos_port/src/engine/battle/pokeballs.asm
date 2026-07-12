; pokeballs.asm — battle party-status pokéballs (Wave 2, battle-intro polish).
;
; Faithful-in-spirit port of engine/battle/draw_hud_pokeball_gfx.asm (DrawAllPokeballs
; / SetupPokeballs / PickPokeball / WritePokeballOAMData). pret draws the party-status
; balls as OAM sprites; the port's battle screen is BG-tilemap with OAM otherwise off,
; and its $00-$7F BG tile range is fully used, so we keep pret's OAM approach: the four
; ball tiles (gfx/battle/balls.2bpp: ok / status / fainted / empty) load into the free
; OBJ tile area ($8000), the row is written as OAM entries, and PrepareStaticOAM +
; render_sprites composite them. They are an INTRO element (faithful): shown over the
; "Wild X appeared!" screen, then the HP-bar HUD replaces them for the battle proper.
;
; Wild battle: only the player's balls (pret returns early). Trainer battle
; (wIsInBattle == 2): the enemy's row too.
;
; Positions follow pret's OAM coords + the port's battle centering (+80px X, +24px Y).
;
; Register map: a=AL, EBP=GB base; GB memory [EBP+addr]. OAM/params via .bss/.data.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_battle.inc"

%define BALL_OK       0x00
%define BALL_STATUS   0x01
%define BALL_FAINTED  0x02
%define BALL_EMPTY    0x03

; OAM bases from the generated battle layout (the elements are the rows'
; LEFT tiles; OAM = screen px + (8,16), see PrepareStaticOAM).
; PROJ battle: player row = UI_PLAYER_BALLS (OAM base = left ball, marches +8)
%define PB_X   UI_PLAYER_BALLS_OAM_X
%define PB_Y   UI_PLAYER_BALLS_OAM_Y
; PROJ battle: enemy row = UI_ENEMY_BALLS (OAM base = RIGHT-end ball, marches -8)
%define EB_X   (UI_ENEMY_BALLS_OAM_X + (UI_ENEMY_BALLS_GBW - 1) * 8)
%define EB_Y   UI_ENEMY_BALLS_OAM_Y

section .data
ball_gfx: incbin "../gfx/battle/balls.2bpp"      ; 4 tiles (ok/status/fainted/empty)

section .bss
pb_x:     resb 1            ; current OAM X
pb_y:     resb 1            ; OAM Y
pb_step:  resb 1            ; signed OAM X step per ball
pb_count: resb 1            ; party count
pb_oam:   resd 1            ; GB offset of the current OAM entry
pb_base:  resd 1            ; party struct base (GB addr)

section .text

global DrawBattlePokeballs
global HideBattlePokeballs
global LoadPokeballGfx
extern PrepareStaticOAM
extern HideSprites
extern DrawPlayerHUDFrame
extern g_tilecache_dirty        ; src/ppu/ppu.asm — arm cache re-decode after a vChars write

; ---------------------------------------------------------------------------
; LoadPokeballGfx — copy the 4 ball tiles to OBJ tile area $8000 (tiles $00-$03).
; EBP = GB base.
;
; render_sprites composites from tile_cache as of the compositor-perf plan
; (docs/plans/compositor_perf.md Stage 4b) — it no longer bit-decodes raw OBJ
; VRAM — so this write MUST arm g_tilecache_dirty or the balls draw whatever
; those cache slots held before.
; ---------------------------------------------------------------------------
LoadPokeballGfx:
    mov byte [g_tilecache_dirty], 1      ; VRAM tile data changes → rebuild decode cache
    mov esi, ball_gfx
    lea edi, [ebp + GB_VCHARS0]          ; $8000 → OBJ tiles $00..$03
    mov ecx, (4 * 16) / 4                ; 64 bytes
    rep movsd
    ret

; ---------------------------------------------------------------------------
; DrawBattlePokeballs — load gfx, build the player ball row (and the enemy's in a
; trainer battle), publish them to the OAM compositor, and enable OBJ rendering.
; In: EBP = GB base; wPartyCount/wPartyMons (+ wEnemyPartyCount/wEnemyMons) seeded.
; ---------------------------------------------------------------------------
DrawBattlePokeballs:
    call LoadPokeballGfx
    call DrawPlayerHUDFrame               ; the shelf the player's balls sit on
    ; player row → OAM entries 0..5
    mov dword [pb_oam], GB_OAM
    mov dword [pb_base], wPartyMons
    mov al, [ebp + wPartyCount]
    mov [pb_count], al
    mov byte [pb_x], PB_X
    mov byte [pb_y], PB_Y
    mov byte [pb_step], 8
    call build_ball_row
    mov ecx, 6                            ; entries so far
    ; trainer battle → enemy row at entries 6..11 (pb_oam already at entry 6)
    cmp byte [ebp + wIsInBattle], 2
    jne .publish
    mov dword [pb_base], wEnemyMons
    mov al, [ebp + wEnemyPartyCount]
    mov [pb_count], al
    mov byte [pb_x], EB_X
    mov byte [pb_y], EB_Y
    mov byte [pb_step], -8
    call build_ball_row
    mov ecx, 12
.publish:
    call PrepareStaticOAM                 ; ECX entries → DOS position tables
    mov byte [ebp + IO_OBP0], 0xE4        ; identity sprite palette (colors 1-3 visible)
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON ; enable OBJ rendering
    ret

; ---------------------------------------------------------------------------
; HideBattlePokeballs — remove the ball row when the HP-bar HUD takes over (the
; intro → battle handoff): clear the OAM and turn OBJ rendering back off.
; ---------------------------------------------------------------------------
HideBattlePokeballs:
    call HideSprites                      ; zero shadow OAM + publish 0 valid entries
    and byte [ebp + IO_LCDC], ~LCDCF_OBJ_ON
    ret

; ---------------------------------------------------------------------------
; build_ball_row — write PARTY_LENGTH OAM entries from the pb_* params: each ball's
; tile is ok / status / fainted (per the mon's HP+status) or empty (past the count).
; Faithful to PickPokeball. Advances pb_oam/pb_x. Clobbers EAX/EBX/ESI/EDI.
; ---------------------------------------------------------------------------
build_ball_row:
    xor ebx, ebx                          ; bl = slot 0..5
.slot:
    mov edi, [pb_oam]
    mov al, [pb_y]
    mov [ebp + edi], al                   ; OAM Y
    mov al, [pb_x]
    mov [ebp + edi + 1], al               ; OAM X
    mov al, [pb_step]
    add [pb_x], al                        ; next ball's X
    ; tile: empty if slot >= count
    mov al, [pb_count]
    cmp bl, al
    jae .empty
    movzx esi, bl
    imul esi, esi, PARTYMON_STRUCT_LENGTH
    add esi, [pb_base]                    ; ESI = GB addr of this mon's struct
    mov al, [ebp + esi + MON_HP]          ; HP high
    or al, [ebp + esi + MON_HP + 1]       ; | HP low
    jz .fainted                           ; HP == 0
    mov al, [ebp + esi + MON_STATUS]
    test al, al
    jnz .status
    mov al, BALL_OK
    jmp .writeTile
.status:
    mov al, BALL_STATUS
    jmp .writeTile
.fainted:
    mov al, BALL_FAINTED
    jmp .writeTile
.empty:
    mov al, BALL_EMPTY
.writeTile:
    mov edi, [pb_oam]
    mov [ebp + edi + 2], al               ; OAM tile
    mov byte [ebp + edi + 3], 0           ; OAM attr (OBP0, no flip, no priority)
    add dword [pb_oam], 4                 ; next OAM entry
    inc bl
    cmp bl, PARTY_LENGTH
    jb .slot
    ret
