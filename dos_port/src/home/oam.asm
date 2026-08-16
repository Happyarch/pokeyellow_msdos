; oam.asm — WriteOAMBlock translated from SM83 to x86.
;
; Source: home/oam.asm:WriteOAMBlock (pret/pokeyellow).
; Intended path: dos_port/src/home/oam.asm
;
; WriteOAMBlock writes a 2x2 block of OAM entries (used by Cut/emotion-bubble/
; trade animations). In pret it targets wShadowOAM ($C300), the 40-entry shadow
; buffer that the DMA routine copies to real OAM ($FE00) each VBlank. THIS PORT
; USES THE SAME SHADOW-OAM MODEL: PrepareOAMData (src/engine/gfx/sprite_oam.asm)
; builds wShadowOAM (= wShadowOAM, $C300) and vblank.asm:update_oam DMA-copies
; it to GB_OAM ($FE00) each frame. Writing the (Y, X, tile, attr) layout into
; wShadowOAM is the right target and is byte-faithful to pret — but it is NOT
; sufficient on its own, and an earlier version of this comment claimed it was.
;
; render_sprites (src/ppu/ppu.asm) does NOT read sprite POSITION out of $FE00.
; It takes tile/attr from $FE00 but takes each entry's screen position from the
; port-only spr_dos_sx/spr_dos_sy tables, gated by spr_oam_valid (a count of
; valid entries from index 0) — published exclusively by PrepareOAMData /
; PrepareStaticOAM / PublishProjectedOAM / the mon-icon writers. A raw
; wShadowOAM write that never touches those tables is invisible: this is
; exactly how the trainer-sight emotion bubble regressed (diagnosed
; 2026-08-15) — EmotionBubble wrote a faithful 2x2 block via this routine, but
; nothing published its canvas position, so render_sprites' `cmp ecx,
; [spr_oam_valid] / jae .nextSprite` skipped it every frame. And the position
; publish alone is still not enough: tile/attr are read from GB_OAM ($FE00),
; which the shadow write only reaches via update_oam's DMA — gated OFF by the
; wUpdateSpritesEnabled=$ff state these callers run under, so the first fix
; drew the STALE $FE00 tiles at the right position (maintainer-observed:
; the trainer's own sprite where the '!' belonged). WriteOAMBlock therefore
; publishes spr_dos_sx/sy (growing spr_oam_valid) AND mirrors each entry into
; GB_OAM itself — see the DEVIATION below and GBScreenToCanvasXY's header
; (src/engine/gfx/sprite_oam.asm).
;
; INPUT (pret contract, mapped to the port register map):
;   AL = OAM block index (each block = 4 OAM entries = 16 shadow-OAM bytes)
;        pret: `swap a` (a << 4) gives the low byte of the wShadowOAM slot.
;   BH = Y coordinate of the upper-left corner of the block  (pret b)
;   BL = X coordinate of the upper-left corner of the block  (pret c)
;   EDX = FLAT pointer to the 4 (tile, attribute) pairs        (pret de)
;        i.e. 8 source bytes: tile0,attr0, tile1,attr1, tile2,attr2, tile3,attr3.
;        These blocks are flat image labels (.data), not GB WRAM offsets.
;
; The four entries are emitted in pret's order:
;   upper-left  (Y=b,   X=c)
;   upper-right (Y=b,   X=c+8)
;   lower-left  (Y=b+8, X=c)
;   lower-right (Y=b+8, X=c+8)
; Each entry consumes one (tile, attr) pair from DE in sequence.
;
; All registers preserved (leaf-style: caller state is unchanged on return).
;
; Build: nasm -f coff -I include/ -o oam.o oam.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global WriteOAMBlock

extern spr_dos_sy, spr_dos_sx, spr_oam_valid  ; src/ppu/ppu.asm
extern GBScreenToCanvasXY                      ; src/engine/gfx/sprite_oam.asm — shared GB-screen->canvas projection

section .text

; ---------------------------------------------------------------------------
; WriteOAMBlock — write a 2x2 sprite block into shadow OAM (wShadowOAM).
;
; DEVIATION{class=projection; pret=home/oam.asm:WriteOAMBlock; behavior=in addition to the faithful (Y, X, tile, attr) writes into wShadowOAM, each entry also publishes its render_sprites canvas position into spr_dos_sy and spr_dos_sx, grows spr_oam_valid to at least cover its own index without lowering an index some other publisher already raised the count past, and mirrors its four bytes into GB_OAM at fe00 directly; evidence=render_sprites in src/ppu/ppu.asm positions every OAM entry exclusively from spr_dos_sy and spr_dos_sx gated by spr_oam_valid and reads tile and attr from GB_OAM, never from the shadow bytes this routine writes, and its callers run under wUpdateSpritesEnabled ff which keeps update_oam from DMA-copying shadow to GB_OAM - the missing position publish was the emotion-bubble-never-renders regression and the missing GB_OAM mirror then drew the STALE fe00 tiles at the bubble position, both measured 2026-08-15 with maintainer visual confirmation of the second; lifetime=permanent, part of the software OBJ HAL - on hardware the unconditional VBlank DMA does the mirroring}
; ---------------------------------------------------------------------------
WriteOAMBlock:
    push eax
    push ebx
    push esi
    push edi

    ; destination = ebp + wShadowOAM + (block_index << 4)   (pret: swap a; ld l,a)
    movzx edi, al
    shl   edi, 4
    lea   edi, [ebp + edi + wShadowOAM]

    ; source = flat pointer in EDX. pret's `de` is the ROM base address of the
    ; tile/attr pairs; in the flat port those OAM-block tables are flat image
    ; labels (.data), NOT GB WRAM offsets — so take EDX as a full flat pointer
    ; rather than biasing a 16-bit offset by ebp. (.writeOneEntry already reads
    ; the source flat via [esi].)  Callers: pass the block label in EDX.
    mov   esi, edx

    ; BH = Y (pret b), BL = X (pret c)
    call .writeOneEntry             ; upper left  (Y=b,   X=c)
    add  bl, 8                      ; c += 8
    call .writeOneEntry             ; upper right (Y=b,   X=c+8)
    sub  bl, 8                      ; restore c   (pret pop bc)
    add  bh, 8                      ; b += 8
    call .writeOneEntry             ; lower left  (Y=b+8, X=c)
    add  bl, 8                      ; c += 8
    call .writeOneEntry             ; lower right (Y=b+8, X=c+8)

    pop edi
    pop esi
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; .writeOneEntry — write one 4-byte OAM entry, advance cursors.
;   In:  EDI = dest cursor (flat), ESI = source cursor (flat),
;        BH = Y, BL = X.
;   Out: EDI += 4, ESI += 2. Clobbers AL (restored by the outer push eax).
;   Layout matches the renderer: byte0=Y, byte1=X, byte2=tile, byte3=attr.
;
;   Also publishes this entry's canvas position for render_sprites — see the
;   annotation on WriteOAMBlock above. BH/BL are already the OAM-byte-convention
;   Y/X being written to [edi]/[edi+1], so they feed GBScreenToCanvasXY
;   directly. EDI's own bias gives the OAM entry index (0..39); spr_oam_valid
;   is grown max-style (never lowered) so this never hides a higher slot some
;   other publisher already raised the count past.
; ---------------------------------------------------------------------------
.writeOneEntry:
    mov [edi],   bh                 ; Y coordinate   (pret: ld [hl], b)
    mov [edi+1], bl                 ; X coordinate   (pret: ld [hl], c)
    mov al, [esi]                   ; tile number    (pret: ld a,[de]; ld [hli],a)
    mov [edi+2], al
    mov al, [esi+1]                 ; attribute      (pret: ld a,[de]; ld [hli],a)
    mov [edi+3], al

    push eax
    push ecx
    push edx
    mov ecx, edi
    sub ecx, ebp
    sub ecx, wShadowOAM
    shr ecx, 2                       ; ECX = OAM entry index 0..39
    ; Mirror the entry into GB_OAM ($FE00) — render_sprites takes tile/attr
    ; from THERE, not from the shadow, and the wUpdateSpritesEnabled=$ff state
    ; these callers run under keeps update_oam's shadow->GB_OAM DMA from doing
    ; it (measured 2026-08-15: without this, the bubble drew the stale $FE00
    ; tiles — the trainer's own sprite — at the bubble's canvas position).
    mov eax, [edi]                   ; the 4 bytes just written (Y,X,tile,attr)
    mov [ebp + GB_OAM + ecx*4], eax
    call GBScreenToCanvasXY          ; in: BH/BL -> out: EAX=canvas Y, EDX=canvas X
    mov [spr_dos_sy + ecx*4], eax
    mov [spr_dos_sx + ecx*4], edx
    inc ecx
    cmp ecx, [spr_oam_valid]
    jbe .skipValidBump
    mov [spr_oam_valid], ecx
.skipValidBump:
    pop edx
    pop ecx
    pop eax

    add edi, 4
    add esi, 2
    ret
