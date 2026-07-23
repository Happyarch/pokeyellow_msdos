; tilemap.asm — the wTileMap save/restore buffer routines.
;
; Source: home/tilemap.asm (pret/pokeyellow). That file's remaining label,
; UncompressSpriteFromDE, is realized by the pic-staging path in home/pics.asm
; (the PIC_STAGE flat-source model) and is not defined here.
;
; This file is the single canonical provider of the five pret buffer labels.
; It retires two prior placements (menu-intro review, 2026-07-23):
;   * engine/battle/battle_menu.asm held the Buffer1 pair under the pret names
;     but copied to a private host buffer with no annotation;
;   * movie/title.asm held the Buffer2 pair as globals, plus private
;     Title_SaveScreenTilesToBuffer1 / Title_LoadScreenTilesFromBuffer1 /
;     forked copies of the Buffer1 pair — forked names are barred by the
;     preserve-pret-labels rule.
; SaveBattleScreen / RestoreBattleScreen remain as aliases ALONGSIDE the pret
; names (init_battle.asm and debug_dump.asm call them by those names).
;
; All five routines preserve every register (strictly safer than both prior
; implementations, whose callers survived different clobber sets).
;
; Build: nasm -f coff -I include/ -o tilemap.o tilemap.asm

bits 32

%include "gb_memmap.inc"

section .bss
; The port realization of pret's wTileMapBackup (see the DEVIATION below).
; Moved here from battle_menu.asm, which named it screen_save.
screen_save: resb SCREEN_AREA

section .text

global SaveScreenTilesToBuffer1
global LoadScreenTilesFromBuffer1
global SaveScreenTilesToBuffer2
global LoadScreenTilesFromBuffer2
global LoadScreenTilesFromBuffer2DisableBGTransfer
global SaveBattleScreen
global RestoreBattleScreen

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 — snapshot W_TILEMAP
; and restore it. Load1 brackets the copy with pret's hAutoBGTransferEnabled
; off/on writes (the byte is inert in the port — kept for faithfulness).
;
; DEVIATION{class=data-model; pret=home/tilemap.asm:SaveScreenTilesToBuffer1; behavior=wTileMapBackup is realized as the host .bss buffer screen_save instead of pret's $E000 region, and the CopyData calls become flat rep movsb; evidence=pret unions wTileMapBackup with wSurroundingTiles, but the port keeps a persistent overworld map view whose wSurroundingTiles stays live across in-overworld menus (players_pc and the naming screen save the tilemap mid-overworld), so the union would corrupt surrounding-tile state, and a host buffer cannot go through the EBP-relative CopyData; lifetime=permanent port memory model (wTileMapBackup2 below has a dedicated GB region at $F100 and needs no carve-out)}
; ---------------------------------------------------------------------------
SaveScreenTilesToBuffer1:
SaveBattleScreen:
    pushad
    lea esi, [ebp + W_TILEMAP]            ; hlcoord 0, 0
    mov edi, screen_save                  ; ld de, wTileMapBackup
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret

LoadScreenTilesFromBuffer1:
RestoreBattleScreen:
    pushad
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0   ; xor a / ldh [hAutoBGTransferEnabled], a
    mov esi, screen_save                  ; ld hl, wTileMapBackup
    lea edi, [ebp + W_TILEMAP]            ; decoord 0, 0
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; call CopyData
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1   ; ld a, 1 / ldh [hAutoBGTransferEnabled], a
    popad
    ret

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer2 / LoadScreenTilesFromBuffer2 — the second snapshot
; buffer, at its dedicated GB region W_TILEMAP_BACKUP2 ($F100). Load2 goes
; through the DisableBGTransfer entry then re-enables, exactly as pret.
; ---------------------------------------------------------------------------
SaveScreenTilesToBuffer2:
    pushad
    lea esi, [ebp + W_TILEMAP]            ; hlcoord 0, 0
    lea edi, [ebp + W_TILEMAP_BACKUP2]    ; ld de, wTileMapBackup2
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret

LoadScreenTilesFromBuffer2:
    call LoadScreenTilesFromBuffer2DisableBGTransfer
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1   ; ld a, 1 / ldh [hAutoBGTransferEnabled], a
    ret

; loads screen tiles stored in wTileMapBackup2 but leaves hAutoBGTransferEnabled disabled
LoadScreenTilesFromBuffer2DisableBGTransfer:
    pushad
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0   ; xor a / ldh [hAutoBGTransferEnabled], a
    lea esi, [ebp + W_TILEMAP_BACKUP2]    ; ld hl, wTileMapBackup2
    lea edi, [ebp + W_TILEMAP]            ; decoord 0, 0
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret
