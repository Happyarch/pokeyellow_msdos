; museum_fossils2.asm — Displays a pokemon's front sprite in a pop-up window.
;
; Faithful translation of pret `engine/events/hidden_events/museum_fossils2.asm`.
;
; Register map: A=AL, DE=EDX, HL=ESI; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/museum_fossils2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "coords.inc"

global DisplayMonFrontSpriteInBox

extern Delay3                           ; src/home/palettes.asm
extern SaveScreenTilesToBuffer1         ; src/home/tilemap.asm
extern DisplayTextBoxID                 ; src/home/textbox.asm
extern UpdateSprites                    ; src/home/update_sprites.asm
extern GetMonHeader                     ; src/home/pokemon.asm
extern IndexToPokedex                   ; src/engine/menus/pokedex.asm
extern LoadMonFrontSprite               ; src/home/pics.asm
extern AnimateSendingOutMon             ; src/engine/battle/init_battle.asm
extern WaitForTextScrollButtonPress     ; src/home/joypad2.asm
extern LoadScreenTilesFromBuffer1       ; src/home/tilemap.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; DisplayMonFrontSpriteInBox — pret engine/events/hidden_events/museum_fossils2.asm:DisplayMonFrontSpriteInBox
; Displays a pokemon's front sprite in a pop-up window.
; ─────────────────────────────────────────────────────────────────────────────
; DEVIATION{class=data-model; pret=engine/events/hidden_events/museum_fossils2.asm:DisplayMonFrontSpriteInBox; behavior=convert wCurPartySpecies to dex-1 through IndexToPokedex and pass in EAX before LoadMonFrontSprite; evidence=the port resolves standard front pics through the dex-keyed MonFrontPics table because the mon header front-pic pointer is a GB ROM address, matching the core.asm and init_battle.asm convention; lifetime=permanent flat-data pic-resolution boundary}
; DEVIATION{class=projection; pret=engine/events/hidden_events/museum_fossils2.asm:DisplayMonFrontSpriteInBox; behavior=project hlcoord 10, 11 to BCOORD(10, 11) for AnimateSendingOutMon; evidence=MON_SPRITE_POPUP is centered in the widescreen canvas via the standard +10 col / +3 row projection in ui_layout_menus.inc; lifetime=permanent widescreen UI projection}
DisplayMonFrontSpriteInBox:
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    mov byte [ebp + hWY], 0
    call SaveScreenTilesToBuffer1
    mov byte [ebp + wTextBoxID], MON_SPRITE_POPUP
    call DisplayTextBoxID
    call UpdateSprites
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov edx, vChars1 + 0x31 * 16        ; dest VRAM GB addr (vChars1 tile $31 = $8B10)
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wPokedexNum], al
    call IndexToPokedex
    movzx eax, byte [ebp + wPokedexNum]
    dec eax                             ; dex-1 in EAX (or ignored for SPECIAL_PIC_* handles)
    call LoadMonFrontSprite
    mov byte [ebp + hStartTileID], 0x80
    ; PROJ overworld-ui (mon sprite popup): GB(10,11) --(anchor=center/center, X+10, Y+3)--> BCOORD(10, 11)
    mov eax, BCOORD(10, 11)
    mov [ebp + wPredefHL + 1], al        ; L (low byte)
    mov [ebp + wPredefHL], ah            ; H (high byte) — big-endian GB word
    call AnimateSendingOutMon
    call WaitForTextScrollButtonPress
    call LoadScreenTilesFromBuffer1
    call Delay3
    mov byte [ebp + hWY], 0x90
    ret
