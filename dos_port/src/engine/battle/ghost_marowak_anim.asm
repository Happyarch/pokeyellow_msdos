; ghost_marowak_anim.asm — mirror of pret engine/battle/ghost_marowak_anim.asm.
;
; Source (faithful translation): engine/battle/ghost_marowak_anim.asm:1-92, both
; routines. MarowakAnim unveils the Pokémon Tower ghost as a Marowak: it covers
; the BG ghost pic with an identical SPRITE copy, clears the BG copy, swaps the
; BG pic to RESTLESS_SOUL underneath, fades the sprite ghost out through rOBP1,
; then fades the (now Marowak) sprite copy back in.
;
; PORTED 2026-08-12 (battle plan 4c, the animation half). Both labels were
; `missing`; every other callee was already translated, so this needed no stubs.
;
; REACHABILITY, STATED RATHER THAN IMPLIED: nothing calls MarowakAnim yet. The
; rest of 4c — ghost initialization/identity, the unidentified-ghost move
; refusal, escape rules, the Poké Doll consumer — is what makes it reachable, and
; is NOT in this change. This lands the translation with its faithfulness gates;
; it is UNWITNESSED by any scenario and that is not a claim to paper over.
;
; Register map (CLAUDE.md): A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI,
; EBP = GB base, [ebp+addr].
;
; ---------------------------------------------------------------------------
; THREE THINGS THAT ARE NOT OBVIOUS FROM THE SM83, each measured:
;
; 1. `jr nz` READS ZF ACROSS A CALL, in BOTH fade loops. pret does
;    `sla a / sla a / ldh [rOBP1], a / call UpdateCGBPal_OBP1 / jr nz`, so the
;    branch consumes the ZF that the second shift set. That survives on the GB
;    because pret's UpdateCGBPal_OBP1 is `push af ... pop af / ret`
;    (home/cgb_palettes.asm:48), and it survives here because the port's is
;    `mov byte [g_pal_dirty], 1 / ret` — a mov immediate-to-memory sets no flags,
;    and neither does `ret`. **Adding any compare to that two-line routine would
;    silently break both loops below.** The `mov [ebp + IO_OBP1], al` between the
;    shift and the call is likewise flag-neutral.
;
; 2. `rra` IS `rcr`, NOT `shr`. The fade-in shifts a 16-bit-ish quantity through
;    CF: `srl b / rra` twice. `srl b` -> `shr bh, 1` (CF = ejected bit), and
;    `rra` -> `rcr al, 1` (rotate A right THROUGH carry). A plain `shr al, 1`
;    would drop the bit the pair exists to carry.
;
; 3. THE FADE-IN LOOP KEEPS TWO LIVE VALUES IN BX. pret holds the fade mask in
;    `b` and the DelayFrames count in `c`; those are BH and BL of the same
;    register here. That is safe because the port's DelayFrames decrements BL
;    only and its inner DelayFrame is `pushad`-wrapped, so BH survives the call.
; ---------------------------------------------------------------------------

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/ui_layout_battle.inc"     ; UI_ENEMY_PIC_ROW / _COL

extern UpdateCGBPal_OBP1        ; home/cgb_palettes.asm — flag-neutral, see note 1
extern ClearScreenArea          ; home/copy2.asm
extern Delay3                   ; home/palettes.asm
extern DelayFrames              ; home/delay.asm — decrements BL only
extern ClearSprites             ; home/clear_sprites.asm
extern ChangeMonPic             ; engine/battle/animations.asm (pret callfar)
extern FlashSprite8Times        ; engine/overworld/healing_machine.asm
extern CopyVideoData            ; home/copy2.asm

global MarowakAnim
global CopyMonPicFromBGToSpriteVRAM

section .text

; ---------------------------------------------------------------------------
; MarowakAnim — pret ghost_marowak_anim.asm:1.
; ---------------------------------------------------------------------------
MarowakAnim:
    mov byte [ebp + IO_OBP1], 0xE4          ; ld a, $e4 / ldh [rOBP1], a
    call UpdateCGBPal_OBP1
    ; Cover the BG ghost pic with a sprite ghost pic that looks the same.
    call CopyMonPicFromBGToSpriteVRAM
    ; Now clear the ghost pic from the BG tilemap.
    ;
    ; PROJECTION: pret's `hlcoord 12, 0` is a 20-wide-screen coordinate. The port
    ; composites on a 40-wide canvas and the enemy pic lives at UI_ENEMY_PIC_*,
    ; the same expression init_battle.asm:434 and core.asm:5217 already use.
    ; Using pret's RAW column here is a SHIPPED BUG in this exact 7x7 block —
    ; see regression-battle-second-battle-hud-tile-band, where two sites left a
    ; ghost band at cols 12-18.
    mov esi, wTileMap + UI_ENEMY_PIC_ROW * SCREEN_TILES_W + UI_ENEMY_PIC_COL
    mov bh, 7                               ; lb bc, 7, 7
    mov bl, 7
    call ClearScreenArea
    call Delay3
    ; Disable BG transfer so we don't see the Marowak too soon.
    ;
    ; FAITHFUL BUT INERT HERE, and that is a tree-wide port state rather than a
    ; deviation of this routine: the port retired pret's hAutoBGTransferEnabled
    ; VBlank auto-transfer (src/home/vblank.asm:136) while keeping the faithful
    ; writes throughout. The consequence for THIS animation is real and belongs
    ; to whoever first puts it on screen — the BG swap below is not hidden the
    ; way the Game Boy hides it.
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ; Replace the ghost pic with Marowak in the BG.
    mov byte [ebp + wChangeMonPicEnemyTurnSpecies], RESTLESS_SOUL
    mov byte [ebp + hWhoseTurn], 1
    call ChangeMonPic                       ; pret: callfar ChangeMonPic
    ; Alternate between black and light grey 8 times — the ghost's body flashes.
    mov dh, 0x80                            ; ld d, $80
    call FlashSprite8Times

.fadeOutGhostLoop:
    mov bl, 10                              ; ld c, 10
    call DelayFrames
    mov al, [ebp + IO_OBP1]                 ; ldh a, [rOBP1]
    shl al, 1                               ; sla a
    shl al, 1                               ; sla a  — THIS sets the ZF below
    mov [ebp + IO_OBP1], al                 ; flag-neutral
    call UpdateCGBPal_OBP1                  ; flag-neutral (see note 1)
    jnz .fadeOutGhostLoop                   ; jr nz
    call ClearSprites
    ; Copy the Marowak pic from BG to sprite VRAM.
    call CopyMonPicFromBGToSpriteVRAM
    mov bh, 0xE4                            ; ld b, $e4

.fadeInMarowakLoop:
    mov bl, 10                              ; ld c, 10 — BH (the mask) survives,
    call DelayFrames                        ;            DelayFrames touches BL
    mov al, [ebp + IO_OBP1]                 ; ldh a, [rOBP1]
    shr bh, 1                               ; srl b  — CF = ejected bit
    rcr al, 1                               ; rra    — rotate A right THROUGH CF
    shr bh, 1                               ; srl b
    rcr al, 1                               ; rra
    mov [ebp + IO_OBP1], al                 ; ldh [rOBP1], a
    call UpdateCGBPal_OBP1
    mov al, bh                              ; ld a, b
    test al, al                             ; and a
    jnz .fadeInMarowakLoop                  ; jr nz
    ; Re-enable BG transfer so the BG Marowak pic is visible once the sprite
    ; copy is cleared (inert here — see the note at the disable above).
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call Delay3
    jmp ClearSprites                        ; jp ClearSprites (tail)

; ---------------------------------------------------------------------------
; CopyMonPicFromBGToSpriteVRAM — pret ghost_marowak_anim.asm:55.
; Copies a mon pic from background VRAM to sprite VRAM and sets up OAM.
;
; THE VRAM->VRAM COPY IS EXPRESSIBLE WITH THE PORT'S CopyVideoData, and I record
; why because the shape of the two contracts makes it look otherwise at a
; glance. pret's routine is documented "copy c 2bpp tiles from b:de to hl", i.e.
; DE is the SOURCE, HL the DEST and C a TILE count — and PIC_SIZE is
; PIC_WIDTH * PIC_HEIGHT = 49 TILES, not bytes. The port's contract is the same
; shape: ESI = destination GB VRAM offset, EDX = source pointer, BH = bank
; (no-op), BL = tile count. The one thing to get right is that the port
; dereferences EDX FLAT (`mov esi, edx` then `rep movsb`), so a source that
; lives in emulated VRAM is passed as `lea edx, [ebp + vFrontPic]` rather than
; as a bare constant. Its doc comment says ".data / ROM" because every previous
; caller happened to copy from there; nothing in the routine requires it.
; ---------------------------------------------------------------------------
CopyMonPicFromBGToSpriteVRAM:
    lea edx, [ebp + vFrontPic]              ; ld de, vFrontPic — SOURCE, flat
    mov esi, GB_VCHARS0                     ; ld hl, vSprites  — DEST, GB offset
    mov bh, 0                               ; bank: no-op under the flat model
    mov bl, PIC_SIZE                        ; ld bc, PIC_SIZE — 49 TILES
    call CopyVideoData                      ; arms g_tilecache_dirty itself
    mov byte [ebp + wBaseCoordY], 0x10      ; ld a, $10 / ld [wBaseCoordY], a
    mov byte [ebp + wBaseCoordX], 0x70      ; ld a, $70 / ld [wBaseCoordX], a
    mov esi, wShadowOAM                   ; ld hl, wShadowOAM
    mov bh, 6                               ; lb bc, 6, 6 — b = columns
    mov bl, 6                               ;              c = rows
    mov dh, 8                               ; ld d, $8 — first tile id
.oamLoop:
    push ebx                                ; push bc — restores BOTH halves, so
                                            ; the row count is 6 again next column
    mov al, [ebp + wBaseCoordY]
    mov dl, al                              ; ld e, a
.oamInnerLoop:
    mov al, dl                              ; ld a, e
    add al, 8                               ; add $8
    mov dl, al                              ; ld e, a
    mov [ebp + esi], al                     ; ld [hli], a — OAM Y
    inc esi
    mov al, [ebp + wBaseCoordX]
    mov [ebp + esi], al                     ; ld [hli], a — OAM X
    inc esi
    mov al, dh                              ; ld a, d
    mov [ebp + esi], al                     ; ld [hli], a — tile id
    inc esi
    mov byte [ebp + esi], OAM_PAL1 | OAM_HIGH_PALS  ; ld [hli], a — attributes
    inc esi
    inc dh                                  ; inc d
    dec bl                                  ; dec c — 8-bit, entered at 6
    jnz .oamInnerLoop
    inc dh                                  ; inc d — skip a tile between columns
    mov al, [ebp + wBaseCoordX]
    add al, 8                               ; add $8
    mov [ebp + wBaseCoordX], al
    pop ebx                                 ; pop bc
    dec bh                                  ; dec b — 8-bit, entered at 6
    jnz .oamLoop
    ; NOTE, deliberately not "fixed" here: these 36 records are written to
    ; wShadowOAM exactly as pret writes them, and on this port that DRAWS
    ; NOTHING on its own — render_sprites positions from spr_dos_sx/sy and
    ; honours spr_oam_valid, so a screen has to publish its records
    ; (PublishProjectedOAM) for them to appear. The publish carries a projection
    ; OFFSET, and the correct offset is a property of the screen that owns the
    ; canvas, not of this routine; the ghost battle that owns it is the rest of
    ; 4c and does not exist yet. Inventing an offset here would be a guess, and
    ; a wrong one would be invisible until someone finally saw the animation.
    ; The GB-side bytes this routine produces are byte-faithful either way.
    ret
