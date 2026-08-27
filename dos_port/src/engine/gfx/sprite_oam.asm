; sprite_oam.asm — PrepareOAMData: build shadow OAM from sprite state data.
;
; Faithful translation of engine/gfx/sprite_oam.asm:PrepareOAMData (the Yellow
; version), plus GetSpriteScreenXY and Func_4a7b. This replaces the Phase 2
; UpdatePlayerOAM scaffold: instead of hand-writing the player's four OAM
; entries, the engine now iterates all 16 sprite slots in wSpriteStateData1/2,
; looks each visible sprite's pose up in SpriteFacingAndAnimationTable, and
; writes the resulting OBJ entries into wShadowOAM ($C300). The frame pipeline
; (vblank.asm DelayFrame) then DMA-copies wShadowOAM into OAM ($FE00) before
; render_sprites composites it.
;
; Only the player slot (0) is populated for now (see overworld.asm), but the
; loop, priority handling, and tile/VRAM-offset logic are the real engine, so
; NPC slots will render as soon as InitMapSprites fills them in.
;
; Sprite state layout (per $10-byte slot):
;   data1+0 picture ID (0 = unused)   data1+2 image index (facing+anim, $ff=hidden)
;   data1+4 Y pixels                  data1+6 X pixels
;   data1+9 facing direction          data2+7 grass priority ($80 bit)
;
; Pret refs: engine/gfx/sprite_oam.asm, data/sprites/facings.asm.
;
; Build: nasm -f coff -I include/ -I . -o sprite_oam.o src/gfx/sprite_oam.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern HideSprites
extern spr_dos_sy, spr_dos_sx, spr_oam_valid

global PrepareOAMData
global PrepareStaticOAM
global PublishProjectedOAM
global GBScreenToCanvasXY

section .bss
dos_base_y_tmp: resd 1      ; per-sprite DOS base Y for extended viewport
dos_base_x_tmp: resd 1      ; per-sprite DOS base X for extended viewport

section .text

; ---------------------------------------------------------------------------
; GBScreenToCanvasXY — port-only shared OBJ projection: convert a Y/X pair
; expressed in the GB's standard OAM-byte convention (screen row + 16, screen
; col + 8 — i.e. as if about to be DMA'd verbatim to real hardware OAM) into
; the extended 320x200 overworld canvas coords render_sprites reads from
; spr_dos_sy/sx (src/ppu/ppu.asm).
;
; This factors out the fixed camera-centering constant PrepareOAMData (below)
; applies to the player sprite (slot 0, see .dos_base_done):
;   dos_base_y = hSpriteScreenY + 36     ; hSpriteScreenY is the sprite's
;   dos_base_x = hSpriteScreenX + 96     ; PHYSICAL on-screen Y/X (no +16/+8)
; An OAM-byte-convention Y/X is physical+16 / physical+8, so the same constant
; collapses to input+20 (Y) / input+88 (X). WriteOAMBlock (src/home/oam.asm)
; writes raw (Y, X, tile, attr) OAM-byte-convention entries directly into
; wShadowOAM — this lets it publish the matching canvas position for the
; software renderer instead of re-deriving the constant. See the annotation on
; WriteOAMBlock for why that publish is required.
;
; In:  BH = OAM-byte-convention Y, BL = OAM-byte-convention X — UNSIGNED, as on
;      hardware, where the OAM bytes span 0-255 with no sign. This was `movsx`
;      until 2026-08-15, which sent every sprite in the right half / lower rows
;      of the GB window (OAM X >= 128, i.e. GB column >= 120, or OAM Y >= 128)
;      to a NEGATIVE canvas position: measured as the trainer-sight '!' bubble
;      appearing over a left-side trainer but never over the Route 3 lass
;      standing right of center. The player slot never exposed it (pinned near
;      screen center, coords always < 128).
; Out: EAX = canvas Y, EDX = canvas X. Clobbers EAX, EDX only.
; ---------------------------------------------------------------------------
GBScreenToCanvasXY:
    movzx eax, bh
    add eax, 20
    movzx edx, bl
    add edx, 88
    ret

; ---------------------------------------------------------------------------
; PrepareStaticOAM — make render_sprites display ECX OAM entries that the caller
; has written directly into $FE00 (Y, X, tile, attr), WITHOUT the wSpriteStateData
; path PrepareOAMData uses. Fills the DOS position tables render_sprites reads from
; the raw OAM Y/X (DOS = OAM_Y − 16, OAM_X − 8 — the standard GB OAM offset) and
; publishes the entry count. Used by the battle pokéball row (the only OAM in the
; OAM-disabled battle screen). In: ECX = entry count; EBP = GB base.
;
; DEVIATION{class=HAL; pret=engine/gfx/sprite_oam.asm:PrepareOAMData; behavior=a port-only entry point publishes raw hand-written $FE00 entries to the software renderer by filling its DOS position tables and entry count, bypassing the wSpriteStateData walk that PrepareOAMData does; evidence=render_sprites positions from spr_dos_sx spr_dos_sy rather than reading OAM X and Y, so a screen that writes OAM directly, the battle pokeball row, would otherwise draw nothing, and on the Game Boy the hardware needs no such publication because it scans $FE00 itself; lifetime=permanent, the OBJ side of the software video HAL}
; ---------------------------------------------------------------------------
PrepareStaticOAM:
    mov [spr_oam_valid], ecx
    test ecx, ecx
    jz .done
    xor edx, edx                         ; OAM entry index
.loop:
    lea esi, [ebp + GB_OAM + edx*4]
    movzx eax, byte [esi]                ; OAM Y
    sub eax, 16
    mov [spr_dos_sy + edx*4], eax
    movzx eax, byte [esi + 1]            ; OAM X
    sub eax, 8
    mov [spr_dos_sx + edx*4], eax
    inc edx
    cmp edx, ecx
    jb .loop
.done:
    ret

; ---------------------------------------------------------------------------
; PublishProjectedOAM — port-only. Publish canonical GB OAM records onto the
; widescreen canvas at a fixed projection offset, for cinematic screens.
;
; No pret counterpart: pret's OAM IS screen space. Here the cinematic surface is
; a 160x144 GB screen centred on a 320x200 canvas, so canonical OAM stays exactly
; what the GB would hold (byte-comparable against a golden) while the compositor
; draws from separately published native coordinates.
;
; Deliberately performs NO visibility culling. A record the GB would hide
; (OAM_Y=0, OAM_Y>=160, OAM_X=0, OAM_X>=168) is published with its raw value and
; falls outside g_obj_clip, so render_sprites produces no pixels for it; a record
; straddling the GB screen edge is clipped PER PIXEL by the same rectangle. That
; is what preserves partial edge clipping — culling here would round it to
; all-or-nothing and diverge from hardware.
;
; In:  ESI = GB-relative address of the canonical Y,X,tile,attr records
;      ECX = valid entry count, 0..40
;      EAX = projection X offset (80 for every cinematic surface)
;      EBX = projection Y offset (24)
;      EBP = GB memory base
; Out: all 160 canonical bytes copied to GB_OAM; spr_dos_sx/sy published for the
;      first ECX entries; spr_oam_valid = ECX. Entries beyond ECX are not drawn.
;      Clip rectangle and z-order are left to the calling screen.
; Registers: ALL preserved (pushad/popad); flags clobbered.
;
; DEVIATION{class=projection; pret=engine/gfx/sprite_oam.asm:PrepareOAMData; behavior=a port-only entry point publishes a cinematic screen's OAM records at a fixed pixel offset into the canvas, translating GB screen coordinates onto the centred 160x144 surface while copying all 160 canonical bytes through unchanged; evidence=cinematic screens compose onto the offset surface movie_projection.asm owns, so OBJ have to be displaced by the same 80,24 origin as the BG or they would land in the matte, and the offset is applied to the renderer position tables rather than to the OAM bytes so pret-authored coordinates stay byte-faithful for anything that reads them back, offscreen entries are deliberately not culled so per-pixel edge clipping still matches hardware; lifetime=permanent, part of the cinematic presentation boundary documented in movie_projection.asm}
; ---------------------------------------------------------------------------
PublishProjectedOAM:
    pushad
    mov [proj_oam_x], eax
    mov [proj_oam_y], ebx
    mov [proj_oam_n], ecx

    ; 1. Canonical OAM: copy every byte, including records the GB would hide, so
    ;    a GBSTATE diff against the golden compares like for like.
    lea esi, [ebp + esi]
    lea edi, [ebp + GB_OAM]
    mov ecx, OAM_COUNT * OAM_ENTRY_SIZE / 4
    rep movsd

    ; 2. Native positions: GB screen space -> canvas, at the projection offset.
    mov ecx, [proj_oam_n]
    mov [spr_oam_valid], ecx
    test ecx, ecx
    jz .done
    xor edx, edx
.loop:
    lea esi, [ebp + GB_OAM + edx*4]
    movzx eax, byte [esi]                ; raw OAM Y (no culling)
    sub eax, 16                          ; OAM stores screen + (8,16)
    add eax, [proj_oam_y]
    mov [spr_dos_sy + edx*4], eax
    movzx eax, byte [esi + 1]            ; raw OAM X
    sub eax, 8
    add eax, [proj_oam_x]
    mov [spr_dos_sx + edx*4], eax
    inc edx
    cmp edx, ecx
    jb .loop
.done:
    popad
    ret

section .bss
align 4
proj_oam_x:  resd 1
proj_oam_y:  resd 1
proj_oam_n:  resd 1

section .text

; ---------------------------------------------------------------------------
; PrepareOAMData — determine OAM data for visible sprites, write to wShadowOAM.
; Pret ref: engine/gfx/sprite_oam.asm:PrepareOAMData (Yellow).
;
; In:  EBP = GB memory base. Out: wShadowOAM populated. Clobbers caller-saved.
; ---------------------------------------------------------------------------
PrepareOAMData:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov al, [ebp + wUpdateSpritesEnabled]
    cmp al, 1
    je .updateEnabled
    ; pret: `dec a / jr z,.updateEnabled / cp -1 / ret nz / ld [wUpdateSpritesEnabled],a
    ; / jp HideSprites` — after the dec, `cp -1` is true when the value WAS 0, and the
    ; $FF (= the decremented a) is stored back. So 0 means "hide all sprites once, then
    ; park at $FF"; $FF means "already hidden/frozen, do nothing". The old port code
    ; compared the RAW value against $FF — the exact inversion — so a menu writing 0
    ; froze stale OAM instead of hiding it (caught by the pokedex_list golden, whose
    ; GB-side OAM is all Y=160).
    test al, al
    jnz .ret                             ; $FF (or anything but 0/1): frozen, no-op
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    call HideSprites
    jmp .ret

.updateEnabled:
    mov byte [ebp + hOAMBufferOffset], 0
    xor esi, esi                         ; ESI = current slot byte offset (0,$10,..,$f0)

.spriteLoop:
    mov eax, esi
    mov [ebp + hSpriteOffset2], al

    ; picture ID == 0 → slot unused
    mov al, [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .nextSprite

    ; image index; $ff → off-screen (still update adjusted coords, then skip)
    mov al, [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_IMAGEINDEX]
    mov [ebp + wSavedSpriteImageIndex], al
    cmp al, 0xFF
    jne .visible
    call GetSpriteScreenXY
    jmp .nextSprite

.visible:
    cmp al, 0xA0                         ; unchanging sprite (item ball / boulder)?
    jb .usefacing
    xor al, al                           ; unchanging → table index 0
    jmp .gotIndex
.usefacing:
    and al, 0x0F                         ; facing*4 + anim frame
.gotIndex:
    movzx eax, al
    mov edx, [SpriteFacingAndAnimationTable + eax*4]   ; EDX → facing data block (count byte first)

    ; sprite BG priority = data2 grass-priority bit 7
    mov al, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_GRASSPRIORITY]
    and al, 0x80
    mov [ebp + hSpritePriority], al

    call GetSpriteScreenXY

    ; OAM overflow guard: hOAMBufferOffset + count > $a0 → stop (clear rest)
    movzx eax, byte [ebp + hOAMBufferOffset]
    add al, [edx]
    cmp al, 0xA0
    ja .clearUnused

    ; --- draw the sprite's OAM entries ---
    call Func_4a7b                       ; AL = VRAM base tile from image index
    mov [ebp + wSavedSpriteImageIndex], al

    ; Compute 32-bit DOS base position for extended 320×200 viewport.
    ; Slot 0 (player): YPIXELS-based (always ≤127, no 8-bit overflow).
    ; Scripted NPCs (DoScriptedNPCMovement): YPIXELS-based screen projection.
    ; Slots 1-15 (regular NPCs): MAPY/MAPX-based (32-bit, handles full map range).
    test esi, esi
    jz .dos_base_screen_relative
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .dos_base_npc
    movzx eax, byte [ebp + wNPCMovementScriptSpriteOffset]
    cmp esi, eax
    je .dos_base_screen_relative
    jmp .dos_base_npc

.dos_base_screen_relative:
    ; Shared with WriteOAMBlock (src/home/oam.asm) via GBScreenToCanvasXY, which
    ; takes OAM-byte-convention (+16/+8) input; add that back on before calling
    ; so this stays byte-identical to the direct hSpriteScreenY+36 it replaced
    ; (8-bit wraparound cancels: see GBScreenToCanvasXY's header).
    ; EDX currently holds the facing-data-block pointer (set above, consumed
    ; below by `mov ebx, edx` before .tileLoop) — the helper clobbers EDX, so
    ; save/restore around the call.
    push edx
    mov bh, [ebp + hSpriteScreenY]
    add bh, 0x10
    mov bl, [ebp + hSpriteScreenX]
    add bl, 0x08
    call GBScreenToCanvasXY
    mov [dos_base_y_tmp], eax
    mov [dos_base_x_tmp], edx
    pop edx
    jmp .dos_base_done
.dos_base_npc:
    movsx eax, byte [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_MAPY]
    movsx ecx, byte [ebp + wYCoord]
    sub eax, ecx
    imul eax, 16
    add eax, 32
    mov [dos_base_y_tmp], eax
    movsx eax, byte [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_MAPX]
    movsx ecx, byte [ebp + wXCoord]
    sub eax, ecx
    imul eax, 16
    add eax, 96
    mov [dos_base_x_tmp], eax
    ; NPC walk interpolation: if MOVEMENTSTATUS=3 (walking), Func_5349 already advanced
    ; MAPY/MAPX to the destination at walk start. Subtract YSTEP*WALKANIMCOUNTER
    ; to interpolate between source and destination over the 16-frame animation (1 px/frame).
    ; If MOVEMENTSTATUS=4 (glide/quick-step), Func_5349 also advanced MAPY/MAPX to the destination,
    ; but WALKANIMCOUNTER counts down 8 frames at 2 px/frame (subtract 2*STEP*WALKANIMCOUNTER).
    mov al, [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_MOVEMENTSTATUS]
    cmp al, 3
    je .interp_status3
    cmp al, 4
    je .interp_status4
    jmp .dos_base_done
.interp_status4:
    movzx eax, byte [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER]
    shl eax, 1                              ; 2 px per frame for status 4
    jmp .apply_interp
.interp_status3:
    movzx eax, byte [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_WALKANIMCOUNTER]
.apply_interp:
    movsx ecx, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_YSTEPVECTOR]
    imul ecx, eax
    sub [dos_base_y_tmp], ecx
    movsx ecx, byte [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_XSTEPVECTOR]
    imul ecx, eax
    sub [dos_base_x_tmp], ecx
.dos_base_done:
    ; Sub-block walk tracking: subtract the player's current walk pixel offset from
    ; NPC dos_base so NPCs scroll in lockstep with the BG during a walk step.
    ; Screen-relative sprites (slot 0 player, and scripted NPCs) track screen coords directly — skip.
    test esi, esi
    jz .no_walk_offset                      ; slot 0 = player
    test byte [ebp + wStatusFlags5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jz .apply_walk_offset
    movzx eax, byte [ebp + wNPCMovementScriptSpriteOffset]
    cmp esi, eax
    je .no_walk_offset                      ; scripted NPC
.apply_walk_offset:
    movzx ecx, byte [ebp + wWalkCounter]
    test ecx, ecx
    jz .no_walk_offset                      ; not walking
    mov eax, 8
    sub eax, ecx                            ; frames elapsed = 8 - walk_counter
    shl eax, 1                              ; * 2 px/frame
    movsx ecx, byte [ebp + W_SPRITE_PLAYER_Y_STEP_VECTOR]
    imul ecx, eax                           ; walk_offset_y = YSTEP * elapsed * 2
    sub [dos_base_y_tmp], ecx              ; NPC tracks BG vertical scroll
    movsx ecx, byte [ebp + W_SPRITE_PLAYER_X_STEP_VECTOR]
    imul ecx, eax                           ; walk_offset_x = XSTEP * elapsed * 2
    sub [dos_base_x_tmp], ecx             ; NPC tracks BG horizontal scroll
.no_walk_offset:

    movzx edi, byte [ebp + hOAMBufferOffset]
    add edi, wShadowOAM                ; EDI = GB offset of shadow-OAM write cursor
    mov ebx, edx                         ; EBX walks the facing data block
    movzx ecx, byte [ebx]                ; entry count
    inc ebx

.tileLoop:
    ; OAM entry index from write cursor: EDI = wShadowOAM + N*4 at loop top
    mov edx, edi
    sub edx, wShadowOAM
    shr edx, 2                              ; EDX = OAM entry index 0..39

    ; spr_dos_sy[N] = dos_base_y + signed(tableY)
    movsx eax, byte [ebx]
    add eax, [dos_base_y_tmp]
    mov [spr_dos_sy + edx*4], eax

    ; OAM Y = hSpriteScreenY + 16 + tableY
    mov al, [ebp + hSpriteScreenY]
    add al, 0x10
    add al, byte [ebx]
    mov [ebp + edi], al
    inc ebx
    inc edi

    ; spr_dos_sx[N] = dos_base_x + signed(tableX)
    movsx eax, byte [ebx]
    add eax, [dos_base_x_tmp]
    mov [spr_dos_sx + edx*4], eax

    ; OAM X = hSpriteScreenX + 8 + tableX
    mov al, [ebp + hSpriteScreenX]
    add al, 0x08
    add al, byte [ebx]
    mov [ebp + edi], al
    inc ebx
    inc edi
    ; tile = savedImageIndex + tableTile; tiles >= $80 get Pikachu VRAM offset
    mov al, [ebp + wSavedSpriteImageIndex]
    add al, [ebx]
    cmp al, 0x80
    jb .tileResolved
    add al, [ebp + hPikachuSpriteVRAMOffset]
.tileResolved:
    mov [ebp + edi], al
    inc ebx
    inc edi
    ; attributes
    mov al, [ebx]                        ; table attr byte
    test al, UNDER_GRASS
    jz .skipPriority
    or al, [ebp + hSpritePriority]     ; OR in the BG-priority bit when under grass
.skipPriority:
    and al, 0xF0                         ; drop engine-internal low bits (UNDER_GRASS/FACING_END)
    test al, OAM_PAL1                    ; bit B_OAM_PAL1 set → CGB high palettes
    jz .obp0
    or al, OAM_HIGH_PALS
.obp0:
    mov [ebp + edi], al
    inc ebx
    inc edi
    dec ecx
    jnz .tileLoop

    ; commit write cursor
    mov eax, edi
    sub eax, wShadowOAM
    mov [ebp + hOAMBufferOffset], al

.nextSprite:
    add esi, 0x10
    cmp esi, 0x100
    jne .spriteLoop

.clearUnused:
    ; Clear unused shadow-OAM entries' Y to $a0 (off-screen). Keep the last 4
    ; entries when a ledge-jump / fishing animation owns them.
    mov cl, 0xA0                         ; LOW(wShadowOAMEnd)
    mov al, [ebp + wMovementFlags]
    test al, 1 << BIT_LEDGE_OR_FISHING
    jz .clear
    mov cl, 0x90                         ; LOW(wShadowOAMSprite36) — keep 4 entries
.clear:
    movzx eax, byte [ebp + hOAMBufferOffset]
    cmp al, cl
    jae .ret                             ; ret nc (nothing to clear)
    movzx edi, al
    add edi, wShadowOAM
; DEVIATION{class=projection; pret=engine/gfx/sprite_oam.asm:PrepareOAMData; behavior=the port additionally parks spr_dos_sy and spr_dos_sx off-canvas for every shadow-OAM index this loop clears, in addition to pret clearing only the OAM Y byte; evidence=this loop is the only place that marks an index unused, it never wrote spr_dos_sy/sx (only render_sprites in src/ppu/ppu.asm reads them, keyed on spr_oam_valid as a count from index 0), and WriteOAMBlock in src/home/oam.asm now grows spr_oam_valid past whatever index it publishes, so without this an index between the active count and WriteOAMBlock's target that this loop clears would still hold a stale or zero canvas position from a previous, larger sprite count and render garbage; lifetime=permanent, part of the software OBJ HAL WriteOAMBlock relies on}
.clearLoop:
    mov byte [ebp + edi], 0xA0
    push eax
    push ecx
    mov ecx, edi
    sub ecx, wShadowOAM
    shr ecx, 2                            ; ECX = OAM entry index 0..39
    mov dword [spr_dos_sy + ecx*4], -1000 ; comfortably off both canvas edges
    mov dword [spr_dos_sx + ecx*4], -1000
    pop ecx
    pop eax
    add edi, 4
    mov eax, edi
    sub eax, wShadowOAM                 ; back to 0-based offset
    cmp al, cl                            ; compare low byte (GB: cp l)
    jne .clearLoop

.ret:
    ; Publish the count of valid OAM entries written this frame.
    ; render_sprites uses this instead of the OAM Y byte to detect active entries
    ; (OAM Y can exceed $A0 due to 8-bit YPIXELS overflow for far NPCs).
    movzx eax, byte [ebp + hOAMBufferOffset]
    shr eax, 2                          ; byte count / 4 = entry count
    mov [spr_oam_valid], eax
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; GetSpriteScreenXY — load the current slot's screen Y/X into hSpriteScreenY/X
; and recompute the adjusted (grid-snapped) Y/X used by collision logic.
; Pret ref: engine/gfx/sprite_oam.asm:GetSpriteScreenXY.
; In: ESI = slot byte offset. Clobbers AL.
; ---------------------------------------------------------------------------
GetSpriteScreenXY:
    mov al, [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + hSpriteScreenY], al
    mov al, [ebp + esi + wSpriteStateData1 + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + hSpriteScreenX], al
    ; adjusted Y = (Y + 4) & $f0 → data1+$a
    mov al, [ebp + hSpriteScreenY]
    add al, 4
    and al, 0xF0
    mov [ebp + esi + wSpriteStateData1 + 0x0A], al
    ; adjusted X = X & $f0 → data1+$b
    mov al, [ebp + hSpriteScreenX]
    and al, 0xF0
    mov [ebp + esi + wSpriteStateData1 + 0x0B], al
    ret

; ---------------------------------------------------------------------------
; Func_4a7b — map the saved image index's high nibble (which sprite) to its
; VRAM base tile (sprite n occupies 12 tiles; sprites $a/$b use only 4).
; Pret ref: engine/gfx/sprite_oam.asm:Func_4a7b.
; In: wSavedSpriteImageIndex. Out: AL = VRAM base tile. Clobbers EAX, ECX.
; ---------------------------------------------------------------------------
Func_4a7b:
    mov al, [ebp + wSavedSpriteImageIndex]
    ror al, 4                            ; swap a — high nibble = sprite number
    and al, 0x0F
    cmp al, 0x0B
    jne .notFourTileSprite
    mov al, 0x7C                         ; $a*12 + 4
    ret
.notFourTileSprite:
    movzx ecx, al
    imul ecx, ecx, 12
    mov al, cl
    ret

; ---------------------------------------------------------------------------
; _IsTilePassable — scan the tileset's passable-tile list for a tile id.
; Pret ref: engine/gfx/sprite_oam.asm:_IsTilePassable (last routine in the pret
; file, before its collision_tile_ids.asm INCLUDE). Reached through the
; IsTilePassable trampoline in home/copy2.asm (pret homecall_sf; flat tail jmp).
;
; In:  CL = tile ID. Scans the $FF-terminated passable-tile list pointed to by
;      wTilesetCollisionPtr (GB pointer to list in ROM window at OW_COLL_GBADDR).
; Out: CF = 0 if CL is in the list (passable), CF = 1 otherwise.
; Clobbers AL, ESI.
;
; SM83 original:
;   ld hl, wTilesetCollisionPtr  ; load the pointer-to-pointer
;   ld a, [hli]
;   ld h, [hl]
;   ld l, a                       ; HL = *wTilesetCollisionPtr (the actual list address)
;   .loop:
;     ld a, [hli]
;     cp $ff
;     jr z, .tileNotPassable
;     cp c                         ; c = tile to test
;     jr nz, .loop
;     xor a                        ; ZF=1 CF=0 → passable
;     ret
;   .tileNotPassable:
;     scf                          ; CF=1 → not passable
;     ret
; ---------------------------------------------------------------------------
global _IsTilePassable
_IsTilePassable:
    ; ESI = *wTilesetCollisionPtr (the flat GB address of the passable-tile list)
    movzx esi, word [ebp + wTilesetCollisionPtr]
.loop:
    mov al, byte [ebp + esi]
    inc esi
    cmp al, 0xFF
    je  .tileNotPassable            ; hit terminator → blocked
    cmp al, cl
    jne .loop                       ; not this tile → keep scanning
    clc                             ; found in list → passable
    ret
.tileNotPassable:
    stc                             ; not found → blocked
    ret

; ---------------------------------------------------------------------------
; SpriteFacingAndAnimationTable — 33 pointers to facing/animation OAM blocks.
; Pret ref: data/sprites/facings.asm. Original is a dw table of 16-bit GB
; addresses; here it is a dd table of absolute label addresses, indexed *4.
;
; Each block: db count, then count × (db Yofs, Xofs, tile, attributes).
; Indices 0-15 are facing*4 + anim frame for overworld sprites $1-$9;
; 16-31 (all StandingDown) are for the immobile sprites $a/$b; 32 is Pikachu.
; ---------------------------------------------------------------------------
section .rodata

SpriteFacingAndAnimationTable:
    dd .StandingDown, .WalkingDown,  .StandingDown, .WalkingDown2   ; facing down
    dd .StandingUp,   .WalkingUp,    .StandingUp,   .WalkingUp2     ; facing up
    dd .StandingLeft, .WalkingLeft,  .StandingLeft, .WalkingLeft    ; facing left
    dd .StandingRight,.WalkingRight, .StandingRight,.WalkingRight   ; facing right
    ; sprites $a/$b (immobile) — every orientation maps to StandingDown
    dd .StandingDown, .StandingDown, .StandingDown, .StandingDown
    dd .StandingDown, .StandingDown, .StandingDown, .StandingDown
    dd .StandingDown, .StandingDown, .StandingDown, .StandingDown
    dd .StandingDown, .StandingDown, .StandingDown, .StandingDown
    dd .SpecialCase                                                 ; Pikachu

.StandingDown:
    db 4
    db  0,  0, 0x00, 0
    db  0,  8, 0x01, 0
    db  8,  0, 0x02, UNDER_GRASS
    db  8,  8, 0x03, UNDER_GRASS | FACING_END
.WalkingDown:
    db 4
    db  0,  0, 0x80, 0
    db  0,  8, 0x81, 0
    db  8,  0, 0x82, UNDER_GRASS
    db  8,  8, 0x83, UNDER_GRASS | FACING_END
.WalkingDown2:
    db 4
    db  0,  8, 0x80, OAM_XFLIP
    db  0,  0, 0x81, OAM_XFLIP
    db  8,  8, 0x82, OAM_XFLIP | UNDER_GRASS
    db  8,  0, 0x83, OAM_XFLIP | UNDER_GRASS | FACING_END
.StandingUp:
    db 4
    db  0,  0, 0x04, 0
    db  0,  8, 0x05, 0
    db  8,  0, 0x06, UNDER_GRASS
    db  8,  8, 0x07, UNDER_GRASS | FACING_END
.WalkingUp:
    db 4
    db  0,  0, 0x84, 0
    db  0,  8, 0x85, 0
    db  8,  0, 0x86, UNDER_GRASS
    db  8,  8, 0x87, UNDER_GRASS | FACING_END
.WalkingUp2:
    db 4
    db  0,  8, 0x84, OAM_XFLIP
    db  0,  0, 0x85, OAM_XFLIP
    db  8,  8, 0x86, OAM_XFLIP | UNDER_GRASS
    db  8,  0, 0x87, OAM_XFLIP | UNDER_GRASS | FACING_END
.StandingLeft:
    db 4
    db  0,  0, 0x08, 0
    db  0,  8, 0x09, 0
    db  8,  0, 0x0A, UNDER_GRASS
    db  8,  8, 0x0B, UNDER_GRASS | FACING_END
.WalkingLeft:
    db 4
    db  0,  0, 0x88, 0
    db  0,  8, 0x89, 0
    db  8,  0, 0x8A, UNDER_GRASS
    db  8,  8, 0x8B, UNDER_GRASS | FACING_END
.StandingRight:
    db 4
    db  0,  8, 0x08, OAM_XFLIP
    db  0,  0, 0x09, OAM_XFLIP
    db  8,  8, 0x0A, OAM_XFLIP | UNDER_GRASS
    db  8,  0, 0x0B, OAM_XFLIP | UNDER_GRASS | FACING_END
.WalkingRight:
    db 4
    db  0,  8, 0x88, OAM_XFLIP
    db  0,  0, 0x89, OAM_XFLIP
    db  8,  8, 0x8A, OAM_XFLIP | UNDER_GRASS
    db  8,  0, 0x8B, OAM_XFLIP | UNDER_GRASS | FACING_END
.SpecialCase:
    db 9
    db -4, -4, 0x00, 0
    db -4,  4, 0x01, 0
    db -4, 12, 0x00, OAM_XFLIP
    db  4, -4, 0x01, 0
    db  4,  4, 0x02, 0
    db  4, 12, 0x01, 0
    db 12, -4, 0x00, OAM_YFLIP | UNDER_GRASS
    db 12,  4, 0x01, UNDER_GRASS
    db 12, 12, 0x00, OAM_YFLIP | OAM_XFLIP | UNDER_GRASS | FACING_END
