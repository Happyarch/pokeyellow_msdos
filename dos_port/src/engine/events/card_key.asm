; card_key.asm — Card Key door handling and player coordinate lookup.
;
; Faithful translation of pret engine/events/card_key.asm.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI; GB memory at [EBP + addr].
;
; WIRED: pret caller is engine/events/hidden_events/bookshelves.asm:37
; (`farjp PrintCardKeyText`), called by PrintBookshelfText in
; src/engine/events/hidden_events/bookshelves.asm.
;
; SilphCoMapList is a pret data/events/card_key_maps.asm label, generated into
; assets/card_key_maps.inc by tools/generators/gen_card_key_maps.py and %included
; below. Its pret-mirrored carrier would be src/data/events/card_key_maps.asm
; (compare src/data/events/card_key_coords.asm), which is outside this change's
; file allow-list — see the report.
;
; Build: nasm -f coff -I include/ -I . -o card_key.o src/engine/events/card_key.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"
%include "assets/map_dims.inc"
%include "assets/script_constants.inc"
%include "assets/audio_constants.inc"

global PrintCardKeyText
global GetCoordsInFrontOfPlayer

extern IsItemInBag                      ; src/home/map_objects.asm
extern PrintPredefTextID                ; src/home/predef_text.asm
extern ReplaceTileBlock                 ; src/engine/overworld/update_map.asm
extern PlaySound                        ; src/home/audio.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; PrintCardKeyText — pret engine/events/card_key.asm:PrintCardKeyText
; ─────────────────────────────────────────────────────────────────────────────
PrintCardKeyText:
    mov esi, SilphCoMapList
    mov al, [ebp + wCurMap]
    mov bh, al                          ; ld b, a
.silphCoMapListLoop:
    mov al, [esi]                       ; ld a, [hli]
    inc esi
    cmp al, 0xFF                        ; cp -1
    jz .done_ret                        ; ret z
    cmp al, bh                          ; cp b
    jnz .silphCoMapListLoop             ; jr nz, .silphCoMapListLoop
; does not check for tile in front of player. This might be buggy.
    mov al, [ebp + wTileInFrontOfPlayer]
    cmp al, 0x18
    jz .cardKeyDoorInFrontOfPlayer
    cmp al, 0x24
    jz .cardKeyDoorInFrontOfPlayer
    mov bh, al                          ; ld b, a
    mov al, [ebp + wCurMap]
    cmp al, SILPH_CO_11F
    jnz .done_ret                       ; ret nz
    mov al, bh
    cmp al, 0x5E
    jnz .done_ret                       ; ret nz
.cardKeyDoorInFrontOfPlayer:
    mov bh, CARD_KEY                    ; ld b, CARD_KEY
    call IsItemInBag
    jz .noCardKey
    xor al, al                          ; xor a
    mov [ebp + wPlayerMovingDirection], al
    tx_pre_id CardKeySuccessText
    mov [ebp + hTextID], al
    call PrintPredefTextID
    call GetCoordsInFrontOfPlayer
    shr dh, 1                           ; srl d
    mov al, dh
    mov bh, al                          ; ld b, a
    mov [ebp + wCardKeyDoorY], al
    shr dl, 1                           ; srl e
    mov al, dl
    mov bl, al                          ; ld c, a
    mov [ebp + wCardKeyDoorX], al
    mov al, [ebp + wCurMap]
    cmp al, SILPH_CO_11F
    jnz .notSilphCo11F
    mov al, 0x03
    jmp .replaceCardKeyDoorTileBlock
.notSilphCo11F:
    mov al, 0x0E
.replaceCardKeyDoorTileBlock:
    mov [ebp + wNewTileBlockID], al
    mov [ebp + wPredefBC], bh
    mov [ebp + wPredefBC + 1], bl
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by direct call to ReplaceTileBlock; evidence=flat memory model, ReplaceTileBlock called directly across port; lifetime=permanent}
    call ReplaceTileBlock
    or byte [ebp + wCurrentMapScriptFlags], 1 << BIT_CUR_MAP_LOADED_1
    mov al, SFX_GO_INSIDE
    jmp PlaySound
.noCardKey:
    tx_pre_id CardKeyFailText
    mov [ebp + hTextID], al
    jmp PrintPredefTextID
.done_ret:
    ret

; ─────────────────────────────────────────────────────────────────────────────
; GetCoordsInFrontOfPlayer — pret engine/events/card_key.asm:GetCoordsInFrontOfPlayer
; Out: DH = Y (d), DL = X (e)
; ─────────────────────────────────────────────────────────────────────────────
GetCoordsInFrontOfPlayer:
    mov dh, [ebp + wYCoord]             ; ld a, [wYCoord] / ld d, a
    mov dl, [ebp + wXCoord]             ; ld a, [wXCoord] / ld e, a
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    test al, al                         ; and a
    jnz .notFacingDown
; facing down
    inc dh                              ; inc d
    ret
.notFacingDown:
    cmp al, SPRITE_FACING_UP
    jnz .notFacingUp
; facing up
    dec dh                              ; dec d
    ret
.notFacingUp:
    cmp al, SPRITE_FACING_LEFT
    jnz .notFacingLeft
; facing left
    dec dl                              ; dec e
    ret
.notFacingLeft:
; facing right
    inc dl                              ; inc e
    ret

section .data

%include "assets/card_key_maps.inc"
