; mon_icons.asm — party-mon icons as OAM sprites.
;
; Faithful port of pret engine/gfx/mon_icons.asm: AnimatePartyMon /
; AnimatePartyMon_ForceSpeed1 / GetAnimationSpeed / PartyMonSpeeds,
; LoadMonPartySpriteGfx / LoadAnimSpriteGfx / LoadMonPartySpriteGfxWithLCDDisabled,
; WriteMonPartySpriteOAMByPartyIndex / …BySpecies / WriteMonPartySpriteOAM,
; GetPartyMonSpriteID, and the MonPartySpritePointers table (pret
; data/icon_pointers.asm). The two OAM writers this file calls live in
; engine/items/town_map.asm on both sides (pret puts them there; the port mirrors
; the path). Consumers: party_menu.asm, naming_screen.asm, home/window.asm
; (HandleMenuInput_'s in-loop AnimatePartyMon); trade / Bill's PC inherit it.
;
; This replaces the port's old BG-tile icon hack (icons parked in vTileset,
; frame-swapped by PartyMenuAnimCB, right column baked as a mirror). Icons are OBJ
; now: 4 entries per mon, the right column is the left column X-flipped
; (OAM_XFLIP), the tile patterns live in vSprites ($8000) where pret puts them, and
; the animation is pret's own 2-frame swap. See docs/plans/party_icons_oam.md.
;
; PORT — publishing OAM to the compositor (the one non-pret piece here):
;   The GB DMAs wShadowOAM → $FE00 every VBlank unconditionally. The port's
;   update_oam (video/frame.asm) gates BOTH PrepareOAMData and that DMA on
;   wUpdateSpritesEnabled — and every screen that shows mon icons zeroes it
;   (StartMenu_Pokemon, DisplayNamingScreen; pret does the same, because on the GB
;   the menu writes shadow OAM itself). So these writers publish their own OAM:
;   CommitMonPartySpriteOAM copies the 24 icon entries into $FE00 AND fills
;   spr_dos_sy/sx — render_sprites positions sprites from those tables, not from the
;   OAM Y byte — and publishes spr_oam_valid.
;   The GB→canvas projection is the owning screen's window anchor
;   (docs/ui_projection.md): canvas_x = WX - 7, canvas_y = WY. The screen sets it
;   with SetMonPartySpriteOrigin before drawing; it defaults to (0,0) — a
;   GB-absolute flat canvas.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/gfx/mon_icons.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

global AnimatePartyMon
global AnimatePartyMon_ForceSpeed1
global GetAnimationSpeed
global LoadMonPartySpriteGfx
global LoadAnimSpriteGfx
global LoadMonPartySpriteGfxWithLCDDisabled
global WriteMonPartySpriteOAMByPartyIndex
global WriteMonPartySpriteOAMBySpecies
global WriteMonPartySpriteOAM
global GetPartyMonSpriteID
global SetMonPartySpriteOrigin
global CommitMonPartySpriteOAM

extern CopyData                 ; home/copy_data.asm — ESI=src, EDX=dest, BX=count
extern CopyVideoData            ; home/copy2.asm — ESI=dest VRAM, EDX=src flat, BL=tiles
extern DelayFrame               ; video/frame.asm
extern DisableLCD               ; video/lcd_control.asm
extern EnableLCD                ; video/lcd_control.asm
extern IndexToPokedex           ; data/pokemon_data.asm — flat table, [species-1] → dex #
extern spr_dos_sy, spr_dos_sx   ; ppu/ppu.asm — render_sprites' canvas positions
extern spr_oam_valid            ; ppu/ppu.asm — render_sprites' live-entry count

; 4 OAM entries per mon, PARTY_LENGTH mons — pret OBJ_SIZE * 4 * PARTY_LENGTH.
MON_OAM_BYTES  equ OBJ_SIZE * 4 * PARTY_LENGTH   ; 96
MON_OAM_ENTRIES equ 4 * PARTY_LENGTH             ; 24

; MonPartySpritePointers entry (port shape). pret's is
; {dw gfx, db tile_offset, db bank, dw vSprites dest}; the flat 32-bit port folds
; the tile offset into the pointer and drops the bank:
;   dd flat src   dd tile count   dd dest GB VRAM offset
MON_ICON_HDR_SIZE  equ 12
MON_ICON_HDR_COUNT equ 30                        ; pret: ld a, $1e

OBJ_SIZE  equ OAM_ENTRY_SIZE                     ; 4 — pret's name for it

section .data
align 4
; Icon tile patterns + the ICON_* enum + MonPartyData (tools/gen_mon_icons_inc.py).
; Tier-1 data — never hand-edit; MonPartySpritePointers below is the Tier-2 pointer
; table that indexes it (project-conventions: pointer tables are code).
%include "assets/mon_icons.inc"

; --- MonPartySpritePointers — pret data/icon_pointers.asm --------------------
; "gfx pointer, gfx tile offset, # tiles, vSprites tile offset", frame 1 then
; frame 2 (ICONOFFSET apart in vSprites). Entry 2's 8-tile copy deliberately runs
; off the end of the 4-tile PokeBallSprite into FossilSprite — that is where the
; helix icon's graphics come from (the two blobs are emitted adjacent by the
; generator, as they are adjacent in the ROM).
align 4
MonPartySpritePointers:
    ; --- frame 1 ---
    dd MonsterSprite       + 12 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_MON        << 2)     ) * TILE_SIZE
    dd PokeBallSprite      +  0 * TILE_SIZE, 8, GB_VCHARS0 + ((ICON_BALL       << 2)     ) * TILE_SIZE
    dd FairySprite         + 12 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_FAIRY      << 2)     ) * TILE_SIZE
    dd BirdSprite          + 12 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_BIRD       << 2)     ) * TILE_SIZE
    dd SeelSprite          +  0 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_WATER      << 2)     ) * TILE_SIZE
    dd BugIconFrame2       +  0 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_BUG        << 2)     ) * TILE_SIZE
    dd BugIconFrame2       +  1 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_BUG        << 2) + 2 ) * TILE_SIZE
    dd PlantIconFrame2     +  0 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_GRASS      << 2)     ) * TILE_SIZE
    dd PlantIconFrame2     +  1 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_GRASS      << 2) + 2 ) * TILE_SIZE
    dd SnakeIconFrame1     +  0 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_SNAKE      << 2)     ) * TILE_SIZE
    dd SnakeIconFrame1     +  1 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_SNAKE      << 2) + 2 ) * TILE_SIZE
    dd QuadrupedIconFrame1 +  0 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_QUADRUPED  << 2)     ) * TILE_SIZE
    dd QuadrupedIconFrame1 +  1 * TILE_SIZE, 1, GB_VCHARS0 + ((ICON_QUADRUPED  << 2) + 2 ) * TILE_SIZE
    dd PikachuSprite       +  0 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_PIKACHU    << 2)     ) * TILE_SIZE
    dd TradeBubbleIconGFX  +  0 * TILE_SIZE, 4, GB_VCHARS0 + ((ICON_TRADEBUBBLE << 2)    ) * TILE_SIZE
    ; --- frame 2 (ICONOFFSET tiles later) ---
    dd MonsterSprite       +  0 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_MON        << 2)     ) * TILE_SIZE
    dd PokeBallSprite      +  0 * TILE_SIZE, 8, GB_VCHARS0 + (ICONOFFSET + (ICON_BALL       << 2)     ) * TILE_SIZE
    dd FairySprite         +  0 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_FAIRY      << 2)     ) * TILE_SIZE
    dd BirdSprite          +  0 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_BIRD       << 2)     ) * TILE_SIZE
    dd SeelSprite          + 12 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_WATER      << 2)     ) * TILE_SIZE
    dd BugIconFrame1       +  0 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_BUG        << 2)     ) * TILE_SIZE
    dd BugIconFrame1       +  1 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_BUG        << 2) + 2 ) * TILE_SIZE
    dd PlantIconFrame1     +  0 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_GRASS      << 2)     ) * TILE_SIZE
    dd PlantIconFrame1     +  1 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_GRASS      << 2) + 2 ) * TILE_SIZE
    dd SnakeIconFrame2     +  0 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_SNAKE      << 2)     ) * TILE_SIZE
    dd SnakeIconFrame2     +  1 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_SNAKE      << 2) + 2 ) * TILE_SIZE
    dd QuadrupedIconFrame2 +  0 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_QUADRUPED  << 2)     ) * TILE_SIZE
    dd QuadrupedIconFrame2 +  1 * TILE_SIZE, 1, GB_VCHARS0 + (ICONOFFSET + (ICON_QUADRUPED  << 2) + 2 ) * TILE_SIZE
    dd PikachuSprite       + 12 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_PIKACHU    << 2)     ) * TILE_SIZE
    dd TradeBubbleIconGFX  +  4 * TILE_SIZE, 4, GB_VCHARS0 + (ICONOFFSET + (ICON_TRADEBUBBLE << 2)    ) * TILE_SIZE
MonPartySpritePointersEnd:

; Party mon animations cycle between 2 frames. The members of the PartyMonSpeeds
; array specify the number of V-blanks that each frame lasts for green HP, yellow
; HP, and red HP in order. On the naming screen, the yellow HP speed is always used.
PartyMonSpeeds:
    db 5, 16, 32

section .bss
align 4
las_cur:   resd 1       ; LoadAnimSpriteGfx cursor (CopyVideoData needs ESI for the dest)
las_left:  resd 1
mps_org_x: resd 1       ; canvas origin of the owning screen's GB window (see header)
mps_org_y: resd 1

section .text

; ---------------------------------------------------------------------------
; SetMonPartySpriteOrigin — PORT: where GB screen (0,0) lands on the 320×200
; canvas for the screen that owns the icons. Pass the window anchor's
; UI_*_WX - 7 / UI_*_WY (docs/ui_projection.md); (0,0) = GB-absolute.
; In: EAX = canvas X, EBX = canvas Y. Preserves all registers.
; ---------------------------------------------------------------------------
SetMonPartySpriteOrigin:
    mov [mps_org_x], eax
    mov [mps_org_y], ebx
    ret

; ---------------------------------------------------------------------------
; CommitMonPartySpriteOAM — PORT: publish the 24 icon OAM entries to the
; compositor (see the header). Copies shadow OAM → $FE00 (render_sprites reads
; tile/attr there), derives the canvas positions render_sprites actually draws at
; (spr_dos_sy/sx = OAM Y - 16 / OAM X - 8, plus the screen's origin), and sets
; spr_oam_valid. Entries past the party count are zero (ClearSprites), so their
; Y - 16 = -16 culls them. Preserves all registers.
; ---------------------------------------------------------------------------
CommitMonPartySpriteOAM:
    pushad
    xor edx, edx                            ; OAM entry index
.loop:
    mov eax, [ebp + W_SHADOW_OAM + edx*4]   ; Y, X, tile, attr
    mov [ebp + GB_OAM + edx*4], eax
    movzx eax, byte [ebp + W_SHADOW_OAM + edx*4]      ; OAM Y
    sub eax, OAM_Y_OFS
    add eax, [mps_org_y]
    mov [spr_dos_sy + edx*4], eax
    movzx eax, byte [ebp + W_SHADOW_OAM + edx*4 + 1]  ; OAM X
    sub eax, OAM_X_OFS
    add eax, [mps_org_x]
    mov [spr_dos_sx + edx*4], eax
    inc edx
    cmp edx, MON_OAM_ENTRIES
    jb .loop
    mov dword [spr_oam_valid], MON_OAM_ENTRIES
    or byte [ebp + IO_LCDC], LCDCF_OBJ_ON   ; the icons ARE OBJ — make sure they draw
    popad
    ret

; ---------------------------------------------------------------------------
; AnimatePartyMon_ForceSpeed1 — pret ref: mon_icons.asm:AnimatePartyMon_ForceSpeed1.
; The naming screen's entry point: always the yellow-HP speed, mon slot 0.
; ---------------------------------------------------------------------------
AnimatePartyMon_ForceSpeed1:
    xor al, al
    mov [ebp + wCurrentMenuItem], al        ; ld [wCurrentMenuItem],a
    mov bh, al                              ; ld b,a
    inc al                                  ; inc a — speed index 1 (yellow)
    jmp GetAnimationSpeed                   ; jr GetAnimationSpeed

; ---------------------------------------------------------------------------
; AnimatePartyMon — pret ref: mon_icons.asm:AnimatePartyMon. Called once per frame
; from HandleMenuInput_ while wPartyMenuAnimMonEnabled is set; ends in DelayFrame,
; so it IS that loop's frame pacing (as on the GB).
; wPartyMenuHPBarColors holds the selected mon's bar color: 0 green, 1 yellow, 2 red.
; ---------------------------------------------------------------------------
AnimatePartyMon:
    movzx eax, byte [ebp + wCurrentMenuItem] ; ld a,[wCurrentMenuItem]
    mov bl, al                              ; ld c,a
    xor bh, bh                              ; ld b,0
    mov al, [ebp + eax + wPartyMenuHPBarColors] ; ld hl,wPartyMenuHPBarColors / add hl,bc / ld a,[hl]

; ---------------------------------------------------------------------------
; GetAnimationSpeed — pret ref: mon_icons.asm:GetAnimationSpeed.
; In: AL = speed index (the HP-bar color). Advances wAnimCounter, flipping the
; icon's frame when it reaches the per-color period, and delays one frame.
; ---------------------------------------------------------------------------
GetAnimationSpeed:
    mov bl, al                              ; ld c,a
    movzx eax, bl
    ; a = (wOnSGB ^ 1) + PartyMonSpeeds[c]. TODO-HW: SGB detect — wOnSGB is
    ; always 0 in the port (home/init.asm), so this is PartyMonSpeeds[c] + 1.
    mov al, [PartyMonSpeeds + eax]          ; ld hl,PartyMonSpeeds / add hl,bc / add [hl]
    inc al                                  ; ld a,[wOnSGB] / xor $1  → 1
    mov bl, al                              ; ld c,a — the frame period
    add al, al                              ; add a
    mov bh, al                              ; ld b,a — the full cycle (2 × period)
    mov al, [ebp + wAnimCounter]            ; ld a,[wAnimCounter]
    test al, al                             ; and a
    jz .resetSprites
    cmp al, bl                              ; cp c
    jz .animateSprite
.incTimer:
    inc al
    cmp al, bh                              ; cp b
    jnz .skipResetTimer
    xor al, al                              ; reset timer
.skipResetTimer:
    mov [ebp + wAnimCounter], al            ; ld [wAnimCounter],a
    call CommitMonPartySpriteOAM            ; PORT: the GB's VBlank OAM DMA (see header)
    jmp DelayFrame                          ; jp DelayFrame
.resetSprites:
    push ebx                                ; push bc
    mov esi, wMonPartySpritesSavedOAM       ; ld hl,wMonPartySpritesSavedOAM
    mov edx, W_SHADOW_OAM                   ; ld de,wShadowOAM
    mov bx, MON_OAM_BYTES                   ; ld bc,OBJ_SIZE*4*PARTY_LENGTH
    call CopyData
    pop ebx                                 ; pop bc
    xor al, al
    jmp .incTimer                           ; jr .incTimer
.animateSprite:
    push ebx                                ; push bc
    ; hl = wShadowOAMSprite00TileID + OBJ_SIZE*4 * wCurrentMenuItem (call AddNTimes)
    movzx esi, byte [ebp + wCurrentMenuItem]
    imul esi, esi, OBJ_SIZE * 4
    add esi, W_SHADOW_OAM + 2               ; +2 = the entry's tile-id byte
    mov bl, ICONOFFSET                      ; ld c,ICONOFFSET — swap to the other frame
    mov al, [ebp + esi]                     ; ld a,[hl] — this mon's frame-1 base tile
    cmp al, ICON_BALL << 2
    jz .editCoords
    cmp al, ICON_HELIX << 2
    jnz .editTileIDS
.editCoords:
    ; ICON_BALL and ICON_HELIX only shake up and down (no second frame exists).
    sub esi, 2                              ; dec hl / dec hl — back to the OAM y coord
    mov bl, 1                               ; ld c,$1 — amount to raise y by
.editTileIDS:
    mov bh, 4                               ; ld b,4 — the mon's 4 OAM entries
    mov edx, OBJ_SIZE                       ; ld de,OBJ_SIZE
.loop:
    mov al, [ebp + esi]                     ; ld a,[hl]
    add al, bl                              ; add c
    mov [ebp + esi], al                     ; ld [hl],a
    add esi, edx                            ; add hl,de
    dec bh                                  ; dec b
    jnz .loop
    pop ebx                                 ; pop bc
    mov al, bl                              ; ld a,c — restore the frame period
    jmp .incTimer                           ; jr .incTimer

; ---------------------------------------------------------------------------
; LoadMonPartySpriteGfx — pret ref: mon_icons.asm:LoadMonPartySpriteGfx.
; Load the mon party sprite tile patterns into VRAM (pret: during V-blank).
; ---------------------------------------------------------------------------
LoadMonPartySpriteGfx:
    mov esi, MonPartySpritePointers         ; ld hl,MonPartySpritePointers
    mov eax, MON_ICON_HDR_COUNT             ; ld a,$1e
    ; fall through

; ---------------------------------------------------------------------------
; LoadAnimSpriteGfx — pret ref: mon_icons.asm:LoadAnimSpriteGfx.
; Load animated sprite tile patterns into VRAM. ESI (hl) = a header array, EAX (a)
; = the number of headers. Each header is CopyVideoData's arguments.
; Preserves all registers. (VRAM tile writes go through CopyVideoData, which arms
; g_tilecache_dirty — the compositor decodes OBJ tiles from tile_cache too.)
; ---------------------------------------------------------------------------
LoadAnimSpriteGfx:
    pushad
    mov [las_cur], esi
    mov [las_left], eax
.loop:
    mov esi, [las_cur]
    mov edx, [esi + 0]                      ; source (flat, tile offset folded in)
    mov ebx, [esi + 4]                      ; BL = tile count (BH = 0: pret's bank byte)
    mov esi, [esi + 8]                      ; dest — CopyVideoData takes it in ESI
    call CopyVideoData
    add dword [las_cur], MON_ICON_HDR_SIZE  ; ld a,$6 / add c (pret's 6-byte stride)
    dec dword [las_left]                    ; dec a
    jnz .loop
    popad
    ret

; ---------------------------------------------------------------------------
; LoadMonPartySpriteGfxWithLCDDisabled — pret ref:
; mon_icons.asm:LoadMonPartySpriteGfxWithLCDDisabled. Same tile patterns, loaded
; with the LCD off so the copy needn't fit in V-blank. pret reaches for FarCopyData
; (no VRAM-timing restriction); the port's CopyVideoData has no timing restriction
; either, so this is the same loop between DisableLCD/EnableLCD.
; ---------------------------------------------------------------------------
LoadMonPartySpriteGfxWithLCDDisabled:
    call DisableLCD
    mov esi, MonPartySpritePointers
    mov eax, MON_ICON_HDR_COUNT
    call LoadAnimSpriteGfx
    jmp EnableLCD                           ; jp EnableLCD

; ---------------------------------------------------------------------------
; WriteMonPartySpriteOAMByPartyIndex — pret ref:
; mon_icons.asm:WriteMonPartySpriteOAMByPartyIndex. Write the OAM blocks for the
; party mon in [hPartyMonIndex]; $ff instead saves the current shadow OAM as the
; animation's frame-1 reference. Preserves all registers.
; ---------------------------------------------------------------------------
WriteMonPartySpriteOAMByPartyIndex:
    pushad                                  ; push hl / push de / push bc
    movzx eax, byte [ebp + hPartyMonIndex]  ; ldh a,[hPartyMonIndex]
    cmp al, 0xFF
    jz .saveOAM                             ; pret .asm_7191f
    mov al, [ebp + eax + wPartySpecies]     ; ld hl,wPartySpecies / add hl,de / ld a,[hl]
    call GetPartyMonSpriteID
    mov [ebp + wOAMBaseTile], al            ; ld [wOAMBaseTile],a
    call WriteMonPartySpriteOAM
    popad
    ret
.saveOAM:
    mov esi, W_SHADOW_OAM                   ; ld hl,wShadowOAM
    mov edx, wMonPartySpritesSavedOAM       ; ld de,wMonPartySpritesSavedOAM
    mov bx, MON_OAM_BYTES                   ; ld bc,$60
    call CopyData
    popad
    ret

; ---------------------------------------------------------------------------
; WriteMonPartySpriteOAMBySpecies — pret ref:
; mon_icons.asm:WriteMonPartySpriteOAMBySpecies. Write the OAM blocks for the party
; sprite of the species in [wMonPartySpriteSpecies] (the naming screen's icon).
; Preserves all registers.
; ---------------------------------------------------------------------------
WriteMonPartySpriteOAMBySpecies:
    pushad
    mov byte [ebp + hPartyMonIndex], 0      ; xor a / ldh [hPartyMonIndex],a
    mov al, [ebp + wMonPartySpriteSpecies]  ; ld a,[wMonPartySpriteSpecies]
    call GetPartyMonSpriteID
    mov [ebp + wOAMBaseTile], al            ; ld [wOAMBaseTile],a
    call WriteMonPartySpriteOAM             ; jr WriteMonPartySpriteOAM
    popad
    ret

; ---------------------------------------------------------------------------
; WriteMonPartySpriteOAM — pret ref: mon_icons.asm:WriteMonPartySpriteOAM.
; Write the 4 OAM blocks for the first animation frame into the OAM buffer and make
; a copy at wMonPartySpritesSavedOAM (so the animation can flip back to it).
; In: AL = the sprite id (ICON_* << 2, = the icon's base tile), [hPartyMonIndex]
; = the party slot, which fixes both the shadow-OAM block and the screen row.
; Clobbers EAX/EBX/EDX/ESI.
; ---------------------------------------------------------------------------
WriteMonPartySpriteOAM:
    push eax                                ; push af
    mov bl, 0x10                            ; ld c,$10 — OAM X (GB col 1)
    movzx esi, byte [ebp + hPartyMonIndex]
    shl esi, 4                              ; swap a / ld l,a — 16 bytes per mon
    mov eax, esi
    add eax, 0x10                           ; add $10
    mov bh, al                              ; ld b,a — OAM Y (2 tile rows per mon)
    add esi, W_SHADOW_OAM                   ; ld h,HIGH(wShadowOAM)
    pop eax                                 ; pop af
    cmp al, ICON_HELIX << 2
    jz .helix
    call WriteSymmetricMonPartySpriteOAM
    jmp .makeCopy
.helix:
    call WriteAsymmetricMonPartySpriteOAM
.makeCopy:
    mov esi, W_SHADOW_OAM                   ; ld hl,wShadowOAM
    mov edx, wMonPartySpritesSavedOAM       ; ld de,wMonPartySpritesSavedOAM
    mov bx, MON_OAM_BYTES                   ; ld bc,OBJ_SIZE*4*PARTY_LENGTH
    call CopyData
    jmp CommitMonPartySpriteOAM             ; PORT: the GB's VBlank OAM DMA (see header)

; ---------------------------------------------------------------------------
; GetPartyMonSpriteID — pret ref: mon_icons.asm:GetPartyMonSpriteID.
; In:  AL = species (internal index).
; Out: AL = ICON_* << 2 — the icon's base tile id in vSprites.
; MonPartyData is a dex-ordered nybble array: the high nybble is the odd dex number.
; Preserves EBX/ESI.
; ---------------------------------------------------------------------------
GetPartyMonSpriteID:
    push ebx
    push esi
    mov [ebp + wPokedexNum], al             ; ld [wPokedexNum],a
    ; predef IndexToPokedex — the port keeps it as a flat table, not a routine
    ; (see home/pokemon.asm; port-predefs-as-inline-tables).
    movzx eax, al
    dec eax
    movzx eax, byte [IndexToPokedex + eax]  ; internal index → national dex #
    mov [ebp + wPokedexNum], al
    mov bl, al                              ; ld c,a
    dec al                                  ; dec a
    shr al, 1                               ; srl a — 2 mons per byte
    movzx esi, al
    mov al, [MonPartyData + esi]            ; ld hl,MonPartyData / add hl,de / ld a,[hl]
    test bl, 1                              ; bit 0,c — even or odd dex number?
    jnz .skipSwap
    shl al, 4                               ; swap a — use the lower nybble if even
.skipSwap:
    and al, 0xF0
    shr al, 2                               ; srl a / srl a — value == ICON constant << 2
    pop esi
    pop ebx
    ret

; ===========================================================================
; The two OAM writers. pret defines them in engine/items/town_map.asm (they sit
; beside the town-map's own OAM code, which is where the bank had room), and they
; are called only from here. The port's src/engine/items/town_map.asm is a DANGLING
; file — it assembles but is not in the linked build — so hosting them there would
; not link. They live with their only caller instead; the relocation is registered
; in tools/pret_label_allowlist.json.
; ===========================================================================

; ---------------------------------------------------------------------------
; WriteSymmetricMonPartySpriteOAM — pret ref: town_map.asm:WriteSymmetricMonPartySpriteOAM.
; Writes 4 OAM blocks for a mon party sprite other than a helix. All the sprites
; other than the helix one have a vertical line of symmetry, which lets the X-flip
; OAM bit cover the right column — so only 2 rather than 4 tile patterns are needed.
; In: ESI (hl) = shadow-OAM cursor, BH (b) = Y, BL (c) = X, [wOAMBaseTile] = tile.
; ---------------------------------------------------------------------------
global WriteSymmetricMonPartySpriteOAM
WriteSymmetricMonPartySpriteOAM:
    mov byte [ebp + wSymmetricSpriteOAMAttributes], 0 ; xor a / ld [..],a
    mov dh, 2                               ; lb de, 2, 2 — d = rows
    mov dl, 2                               ;              e = columns
.loop:
    push edx                                ; push de
    push ebx                                ; push bc
.innerLoop:
    mov al, bh
    mov [ebp + esi], al                     ; ld [hli],a — Y
    inc esi
    mov al, bl
    mov [ebp + esi], al                     ; ld [hli],a — X
    inc esi
    mov al, [ebp + wOAMBaseTile]
    mov [ebp + esi], al                     ; ld [hli],a — tile (BOTH columns: the
    inc esi                                 ;   right one is the left one, X-flipped)
    mov al, [ebp + wSymmetricSpriteOAMAttributes]
    mov [ebp + esi], al                     ; ld [hli],a — attributes
    inc esi
    xor al, OAM_XFLIP                       ; xor OAM_XFLIP
    mov [ebp + wSymmetricSpriteOAMAttributes], al
    inc dh                                  ; inc d — dead (the pop below restores d)
    add bl, 8                               ; ld a,8 / add c / ld c,a — next column
    dec dl                                  ; dec e
    jnz .innerLoop
    pop ebx                                 ; pop bc
    pop edx                                 ; pop de
    add byte [ebp + wOAMBaseTile], 2        ; inc [hl] / inc [hl] — next tile row
    add bh, 8                               ; ld a,8 / add b / ld b,a — next row
    dec dh                                  ; dec d
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; WriteAsymmetricMonPartySpriteOAM — pret ref: town_map.asm:WriteAsymmetricMonPartySpriteOAM.
; Writes 4 OAM blocks for a helix mon party sprite, which has no vertical line of
; symmetry — so all four tile patterns are distinct and no X-flip is used.
; Same in/out contract as the symmetric writer.
; ---------------------------------------------------------------------------
global WriteAsymmetricMonPartySpriteOAM
WriteAsymmetricMonPartySpriteOAM:
    mov dh, 2                               ; lb de, 2, 2
    mov dl, 2
.loop:
    push edx                                ; push de
    push ebx                                ; push bc
.innerLoop:
    mov al, bh
    mov [ebp + esi], al                     ; ld [hli],a — Y
    inc esi
    mov al, bl
    mov [ebp + esi], al                     ; ld [hli],a — X
    inc esi
    mov al, [ebp + wOAMBaseTile]
    mov [ebp + esi], al                     ; ld [hli],a — tile
    inc esi
    inc al                                  ; inc a — every tile is its own pattern
    mov [ebp + wOAMBaseTile], al
    mov byte [ebp + esi], 0                 ; xor a / ld [hli],a — attributes
    inc esi
    inc dh                                  ; inc d — dead (as above)
    add bl, 8                               ; next column
    dec dl
    jnz .innerLoop
    pop ebx                                 ; pop bc
    pop edx                                 ; pop de
    add bh, 8                               ; next row
    dec dh
    jnz .loop
    ret
