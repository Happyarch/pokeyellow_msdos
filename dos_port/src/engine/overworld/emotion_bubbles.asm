; emotion_bubbles.asm — pret mirror of engine/overworld/emotion_bubbles.asm
; (M8.2 promotion, 2026-07-24: carved out of the dissolved trainer_engine.asm
; bundle; LINKED, replacing the overworld_stubs.asm EmotionBubble ret-stub).
;
; Draws an emotion bubble ("!", "?", heart, ...) above a sprite for 60 frames.
; Callers: CheckFightingMapTrainers (home/trainers.asm, pret: predef),
; FishingAnim (player_animations.asm), pallet_town.asm's Oak walk-up script.
;
; Register map: A->AL, HL->ESI, B->BH, C->BL, D->DH, E->DL; GB mem = [ebp+SYM].
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                src/engine/overworld/emotion_bubbles.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "m8_2_pending_symbols.inc"   ; wWhichEmotionBubble/wEmotionBubbleSpriteIndex

extern CopyVideoData            ; src/home/copy2.asm: ESI=dst VRAM offset, EDX=flat src, BL=tile count
extern WriteOAMBlock            ; src/home/oam.asm (flat tile/attr source in EDX)
extern DelayFrame               ; src/home/vblank.asm
extern DelayFrames              ; src/home/delay.asm
extern UpdateSprites            ; src/engine/overworld/movement.asm

global EmotionBubble
global EmotionBubblesOAMBlock

; VRAM target for the emotion bubble tiles (pret: vChars1 tile $78).
; vChars1 = GB_VFONT ($8800), tile $78 -> +$780 = $8F80 = OBJ tile $F8
; ($8000 + $F8*$10), matching EmotionBubblesOAMBlock's $F8-$FB tile ids.
GB_VCHARS1_TILE78 equ GB_VFONT + 0x780

section .text

; ----------------------------------------------------------------------------
; EmotionBubble — draw an emotion bubble (e.g. "!") above a sprite for a beat.
; pret: engine/overworld/emotion_bubbles.asm:EmotionBubble
; In: wWhichEmotionBubble = which bubble, wEmotionBubbleSpriteIndex = target sprite.
; VRAM write goes through CopyVideoData, which arms g_tilecache_dirty itself.
; ----------------------------------------------------------------------------
EmotionBubble:
    ; source tiles: EmotionBubbleGfx + (wWhichEmotionBubble & $f) * EMOTE_BUBBLE_BYTES.
    ; pret: `swap a` (*16) then four `add hl,bc` = *64 (each emote is 4 tiles = 64 bytes).
    mov al, [ebp + wWhichEmotionBubble]
    and al, 0x0f
    movzx ebx, al
    shl ebx, 6                      ; * EMOTE_BUBBLE_BYTES (64)
    ; CopyVideoData ABI (copy2.asm): ESI = dst VRAM offset, EDX = flat src, BL = tiles.
    lea edx, [EmotionBubbleGfx + ebx]    ; EDX = flat source
    mov esi, GB_VCHARS1_TILE78           ; ESI = dst VRAM offset
    mov bl, EMOTE_TILES_PER_BUBBLE       ; BL = tile count 4 (pret bank byte = flat no-op)
    call CopyVideoData
    ; force sprite updates on while the bubble shows
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0xff
    ; shift shadow-OAM forward 16 bytes to make room for the 4 bubble sprites.
    ; last-4-OAM reserved for shadow/rod if BIT_LEDGE_OR_FISHING set.
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .reserved
    ; wShadowOAMSprite35Attributes -> wShadowOAMSprite39Attributes
    mov esi, W_SHADOW_OAM + 35*4 + 3
    mov edi, W_SHADOW_OAM + 39*4 + 3
    jmp .shift
.reserved:
    mov esi, W_SHADOW_OAM + 31*4 + 3
    mov edi, W_SHADOW_OAM + 35*4 + 3
.shift:
    mov ecx, 0x90
.shiftLoop:
    mov al, [ebp + esi]
    mov [ebp + edi], al
    dec esi
    dec edi
    dec ecx
    jnz .shiftLoop
    ; screen coords of the target sprite (YPIXELS -> b, XPIXELS+8 -> c)
    movzx esi, byte [ebp + wEmotionBubbleSpriteIndex]
    shl esi, 4                      ; slot*0x10
    mov bh, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    add al, 8
    mov bl, al                      ; c = x+8
    ; WriteOAMBlock takes the tile/attr source as a FLAT pointer in EDX
    ; (home/oam.asm — the OAM-block tables are flat .data labels). pret: ld de, block.
    mov edx, EmotionBubblesOAMBlock ; de = OAM block (flat)
    xor al, al
    call WriteOAMBlock
    mov bl, 60
    call DelayFrames                ; c = 60 frames
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    call DelayFrame
    call UpdateSprites
    ret

; ============================================================================
section .data

; EmotionBubble OAM block (tile id, attributes) — pret EmotionBubblesOAMBlock
EmotionBubblesOAMBlock:
    db 0xF8, 0
    db 0xF9, 0
    db 0xFA, 0
    db 0xFB, 0

; Overworld emotion-bubble tiles (pret gfx/emotes/*.2bpp, INCBIN'd here in pret).
; Defines EmotionBubbles / EmotionBubbleGfx + EMOTE_TILE_BYTES /
; EMOTE_TILES_PER_BUBBLE / EMOTE_BUBBLE_BYTES / NUM_EMOTES. The .inc does NOT
; self-open a section — it relies on this .data context.
%include "assets/emotes.inc"
