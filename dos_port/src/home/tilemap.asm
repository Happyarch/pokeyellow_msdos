; tilemap.asm — the wTileMap save/restore buffer routines.
;
; Source: home/tilemap.asm (pret/pokeyellow). All six of its labels live here as
; of the pikapic port: the five buffer routines below plus UncompressSpriteFromDE,
; which had been left undefined while every caller open-coded the PIC_STAGE
; flat-source staging inline.  The first caller that could not open-code it
; (DecompressRequestPikaPicAnimGFX, which reaches it through a data table rather
; than a literal blob label) is what brought it back to its mirrored path.
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

extern UncompressSpriteData             ; src/home/uncompress.asm

section .bss
; The port realization of pret's wTileMapBackup (see the DEVIATION below).
; Moved here from battle_menu.asm, which named it screen_save.
screen_save: resb SCREEN_AREA

section .text

global UncompressSpriteFromDE
global SaveScreenTilesToBuffer1
global LoadScreenTilesFromBuffer1
global SaveScreenTilesToBuffer2
global LoadScreenTilesFromBuffer2
global LoadScreenTilesFromBuffer2DisableBGTransfer
global SaveBattleScreen
global RestoreBattleScreen

; ---------------------------------------------------------------------------
; UncompressSpriteFromDE — pret home/tilemap.asm: "decompress pic at a:de".
;
; pret stores DE into wSpriteInputPtr and tail-jumps to UncompressSpriteData,
; because on the GB the compressed stream is already addressable at a 16-bit
; address.  Here it is a flat program-image blob and the decoder reads its input
; EBP-relative, so the stream is first staged into the GB-space PIC_STAGE scratch
; — the same staging every open-coded call site in this port performs, now in one
; place.  The bank byte is a flat-model no-op.
;
; DEVIATION{class=data-model; pret=home/tilemap.asm:UncompressSpriteFromDE; behavior=takes a flat source pointer plus a byte length and copies the stream into the PIC_STAGE GB scratch before pointing wSpriteInputPtr at it, where pret points wSpriteInputPtr straight at the caller's DE; evidence=UncompressSpriteData reads its input through EBP-relative GB memory but the port links compressed pics into the DOS program image outside that space, so a flat pointer cannot be stored in the 16-bit wSpriteInputPtr and the length is needed to bound the staging copy; lifetime=permanent flat 32-bit memory model}
;
; In:  EDX = flat pointer to the compressed stream, ECX = its byte length,
;      AL = source bank (ignored).
; Out: as UncompressSpriteData. All other registers preserved.
; ---------------------------------------------------------------------------
UncompressSpriteFromDE:
    pushad
    mov esi, edx                             ; flat source
    lea edi, [ebp + PIC_STAGE]
    rep movsb                                ; ECX bytes into the GB-space scratch
    mov word [ebp + wSpriteInputPtr], PIC_STAGE   ; ld [hl], e / inc hl / ld [hl], d
    popad
    jmp UncompressSpriteData                 ; jp UncompressSpriteData

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer1 / LoadScreenTilesFromBuffer1 — snapshot wTileMap
; and restore it. Load1 brackets the copy with pret's hAutoBGTransferEnabled
; off/on writes (the byte is inert in the port — kept for faithfulness).
;
; DEVIATION{class=data-model; pret=home/tilemap.asm:SaveScreenTilesToBuffer1; behavior=wTileMapBackup is realized as the host .bss buffer screen_save instead of pret's $E000 region, and the CopyData calls become flat rep movsb; evidence=pret unions wTileMapBackup with wSurroundingTiles, but the port keeps a persistent overworld map view whose wSurroundingTiles stays live across in-overworld menus (players_pc and the naming screen save the tilemap mid-overworld), so the union would corrupt surrounding-tile state, and a host buffer cannot go through the EBP-relative CopyData; lifetime=permanent port memory model (wTileMapBackup2 below has a dedicated GB region at $F100 and needs no carve-out)}
; ---------------------------------------------------------------------------
SaveScreenTilesToBuffer1:
SaveBattleScreen:
    pushad
    lea esi, [ebp + wTileMap]            ; hlcoord 0, 0
    mov edi, screen_save                  ; ld de, wTileMapBackup
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret

LoadScreenTilesFromBuffer1:
RestoreBattleScreen:
    pushad
    mov byte [ebp + hAutoBGTransferEnabled], 0   ; xor a / ldh [hAutoBGTransferEnabled], a
    mov esi, screen_save                  ; ld hl, wTileMapBackup
    lea edi, [ebp + wTileMap]            ; decoord 0, 0
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; call CopyData
    mov byte [ebp + hAutoBGTransferEnabled], 1   ; ld a, 1 / ldh [hAutoBGTransferEnabled], a
    popad
    ret

; ---------------------------------------------------------------------------
; SaveScreenTilesToBuffer2 / LoadScreenTilesFromBuffer2 — the second snapshot
; buffer, at its dedicated GB region wTileMapBackup2 ($F100). Load2 goes
; through the DisableBGTransfer entry then re-enables, exactly as pret.
; ---------------------------------------------------------------------------
SaveScreenTilesToBuffer2:
    pushad
    lea esi, [ebp + wTileMap]            ; hlcoord 0, 0
    lea edi, [ebp + wTileMapBackup2]    ; ld de, wTileMapBackup2
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret

LoadScreenTilesFromBuffer2:
    call LoadScreenTilesFromBuffer2DisableBGTransfer
    mov byte [ebp + hAutoBGTransferEnabled], 1   ; ld a, 1 / ldh [hAutoBGTransferEnabled], a
    ret

; loads screen tiles stored in wTileMapBackup2 but leaves hAutoBGTransferEnabled disabled
LoadScreenTilesFromBuffer2DisableBGTransfer:
    pushad
    mov byte [ebp + hAutoBGTransferEnabled], 0   ; xor a / ldh [hAutoBGTransferEnabled], a
    lea esi, [ebp + wTileMapBackup2]    ; ld hl, wTileMapBackup2
    lea edi, [ebp + wTileMap]            ; decoord 0, 0
    mov ecx, SCREEN_AREA                  ; ld bc, SCREEN_AREA
    rep movsb                             ; jp CopyData
    popad
    ret
