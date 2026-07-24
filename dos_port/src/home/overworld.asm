; overworld.asm — home-bank overworld helpers, at their pret mirror.
;
; Source: home/overworld.asm (pret/pokeyellow). Started at the menu-intro review
; (2026-07-23) to retire relocations: CheckForUserInterruption (was a dedicated
; home/check_user_interruption.asm), IsSpriteInFrontOfPlayer/-2 (were in
; engine/overworld/overworld.asm), SwitchToMapRomBank (was in home/bankswitch.asm),
; and the complete IsSpriteOrSignInFrontOfPlayer (R-002 retirement, 2026-07-23 —
; sign branch + counter-range extension + fallthrough into the sprite scan;
; a sign-branch-only version previously lived in engine/overworld/overworld.asm).
; pret home/overworld.asm's REMAINING labels still live in
; engine/overworld/overworld.asm (the port's historical home for them — legacy
; relocation debt, see tools/pret_label_allowlist.json); move them here when
; touched.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI; GB mem = [ebp+SYM].
;
; Build: nasm -f coff -I include/ -o overworld.o overworld.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern DelayFrame                    ; video/frame.asm
extern JoypadLowSensitivity          ; home/joypad_lowsens.asm — writes hJoy5
extern BankswitchCommon              ; home/bankswitch2.asm — AL = bank (flat no-op)
extern GetTileAndCoordsInFrontOfPlayer ; engine/overworld/player_state.asm (predef
                                     ; entry) — DH/DL = front map coords, CL = tile
extern SignLoop                      ; home/hidden_events.asm — DH/DL in;
                                     ; CF=1 + [hTextID]=sign text id on a match

section .text

; ---------------------------------------------------------------------------
; CheckForUserInterruption — return CF set if Up+Select+B, Start, or A are pressed
; within BL (pret C) frames; CF clear on timeout. The intro / title / Game Freak
; splash skip-check.
;
; DEVIATION{class=data-model; pret=home/overworld.asm:CheckForUserInterruption; behavior=the _DEBUG-only extra Select skip is dropped (release build); evidence=the port defines no _DEBUG, so pret's ELSE branch (Start|A) is the live one; lifetime=until a debug build defines _DEBUG}
;
; In:  BL = frame count (pret C). EBP = GB base.
; Out: CF = 1 if interrupted, 0 on timeout. Clobbers EAX; BL decremented to 0.
; ---------------------------------------------------------------------------
global CheckForUserInterruption
CheckForUserInterruption:
    call DelayFrame
    push ebx                          ; pret push bc — preserve the frame counter
    call JoypadLowSensitivity
    pop ebx
    mov al, [ebp + H_JOY_HELD]        ; ldh a, [hJoyHeld]
    cmp al, PAD_UP + PAD_SELECT + PAD_B   ; exactly Up+Select+B (the skip combo)
    je .input
    mov al, [ebp + H_JOY5]            ; ldh a, [hJoy5]
    and al, PAD_START | PAD_A         ; release build (pret _DEBUG also allows Select)
    jnz .input
    dec bl                            ; dec c
    jnz CheckForUserInterruption      ; jr nz — loop for the remaining frames
    and al, al                        ; pret `and a` — clear CF (no interruption)
    ret
.input:
    stc                               ; scf
    ret

; ---------------------------------------------------------------------------
; SwitchToMapRomBank — set the ROM bank for the current map's data/scripts.
; pret home/overworld.asm:SwitchToMapRomBank: reads the map's bank from
; MapHeaderBanks and BankswitchCommon-s to it. Flat-model: record the requested
; bank (bookkeeping); the physical MBC write is a no-op. Consumers (reload_tiles,
; text_script, run_map_script) keep the pret call structure.
; In: AL = map bank id. All other registers preserved.
; ---------------------------------------------------------------------------
global SwitchToMapRomBank
SwitchToMapRomBank:
    call BankswitchCommon                        ; record AL in hLoadedROMBank (flat no-op MBC)
    ret

global IsSpriteOrSignInFrontOfPlayer         ; A-press dispatch head (overworld.asm)
global IsSpriteInFrontOfPlayer               ; sprite scan — TryPushingBoulder (push_boulder.asm)
global IsSpriteInFrontOfPlayer2              ; long-range entry — counter branch above; Surf open

; ---------------------------------------------------------------------------
; IsSpriteInFrontOfPlayer / IsSpriteInFrontOfPlayer2 — detect-only sprite scan.
; Pret ref: home/overworld.asm:IsSpriteInFrontOfPlayer (:1084-1175)
;
; Finds the sprite (if any) standing at the pixel position the player faces, sets
; BIT_FACE_PLAYER on it, and reports its SLOT in [hSpriteIndex]. pret's two labels
; are one routine with two entry points: IsSpriteInFrontOfPlayer presets the normal
; $10-pixel talking range, IsSpriteInFrontOfPlayer2 expects the caller to have set
; DH (the long $20 range used over pokécenter/mart counter tiles). Both labels are
; kept, per CLAUDE.md's rule on structural splits.
;
; STRUCTURAL SPLIT — this is the SECOND realization of pret's sprite scan, and that
; is deliberate. The port already has IsNPCAtTargetBlock (map_sprites.asm), a
; bespoke MAPY/MAPX *block* scan used by CollisionCheckOnLand (see its note at
; pret :1234). The two are NOT interchangeable:
;   - IsNPCAtTargetBlock answers "is a block occupied" for collision, in map coords.
;   - This answers "which slot is at the faced PIXEL position", in screen coords,
;     with the BIT_FACE_PLAYER side effect and the hSpriteIndex hand-off that
;     TryPushingBoulder's boulder identification depends on.
; Rewiring CollisionCheckOnLand onto this routine is deliberately NOT done here: it
; would change live collision behavior, which this bullet does not own. The port
; therefore keeps pret's name on this half and IsNPCAtTargetBlock's on the other.
;
; CONSUMERS: TryPushingBoulder (push_boulder.asm), and the
; IsSpriteOrSignInFrontOfPlayer head above (counter branch → the -2 entry,
; no-counter fallthrough → the normal entry). ItemUseSurfboard's -2 check at
; pret engine/items/item_effects.asm:725 is still open (Stage 4 Surf bullet,
; which lists "supply IsSpriteInFrontOfPlayer2" as its dependency).
;
; Register map: a=AL, b=BH (player Y), c=BL (player X), d=DH, e=DL, hl=ESI.
; pret reuses D: it is the talking RANGE until .doneCheckingDirection, then the
; loop COUNTER. That reuse is preserved here rather than tidied away.
;
; Out: CF=1 and [hSpriteIndex] = slot (1-15) if a sprite faces the player;
;      CF=0 and AL=0 otherwise ([hSpriteIndex] is left alone — pret makes the
;      CALLER zero it first, and TryPushingBoulder does exactly that).
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; IsSpriteOrSignInFrontOfPlayer — pret home/overworld.asm:IsSpriteOrSignInFrontOfPlayer.
; The A-press interaction head: sign lookup first, then the counter-tile
; talking-range extension, then FALLS THROUGH into the sprite scan below —
; pret has no ret between the counter loop and IsSpriteInFrontOfPlayer, and
; that fallthrough is load-bearing: do not insert anything between them.
;
; Leaves the found id in [hTextID] (== [hSpriteIndex] — same HRAM byte, the
; linchpin of pret's contract): SignLoop stores the sign's text id, the sprite
; scan stores the slot number. Out: CF=1 if a sign or sprite faces the player;
; CF=0 and [hTextID]=0 otherwise. The caller distinguishes sign vs sprite by
; id <= [wNumSprites] (pret DisplayTextID's rule) and zeroes wd435 first
; (pret OverworldLoop does both).
;
; A counter-tile match enters the scan at IsSpriteInFrontOfPlayer2 with
; DH = $20 (two-tile range) still live — that is the entire effect of the
; counter branch: at a mart/center counter you can talk to the clerk one tile
; behind it. wTilesetTalkingOverTiles is loaded per-map by LoadTilesetHeader.
; ---------------------------------------------------------------------------
IsSpriteOrSignInFrontOfPlayer:
    mov byte [ebp + hTextID], 0      ; xor a / ldh [hTextID], a
    mov al, [ebp + W_NUM_SIGNS]      ; ld a, [wNumSigns]
    test al, al                      ; and a
    jz .extendRangeOverCounter       ; jr z, .extendRangeOverCounter
; if there are signs
    call GetTileAndCoordsInFrontOfPlayer ; predef — front map coords in DH/DL
    call SignLoop                    ; CF=1 + [hTextID]=sign id on a match
    jnc .extendRangeOverCounter      ; ┐ pret `ret c`: return only when a sign
    ret                              ; ┘ matched (CF stays set for the caller)
.extendRangeOverCounter:
; counter tile in front? then extend the range at which the player can talk
    call GetTileAndCoordsInFrontOfPlayer ; predef — front tile id in CL
    mov esi, W_TILESET_TALKING_OVER_TILES ; ld hl, wTilesetTalkingOverTiles
    mov bh, 3                        ; ld b, 3 — the list is 3 bytes
    mov dh, 0x20                     ; ld d, $20 — long talking range, in pixels
.counterTilesLoop:
    mov al, [ebp + esi]              ; ld a, [hli]
    inc esi
    cmp al, cl                       ; cp c — is the front tile a counter tile?
    je IsSpriteInFrontOfPlayer2      ; jr z — long-range scan (DH = $20 survives)
    dec bh                           ; dec b
    jnz .counterTilesLoop            ; jr nz
    ; fall through into IsSpriteInFrontOfPlayer (which presets DH = $10)

IsSpriteInFrontOfPlayer:
    mov dh, 0x10                     ; ld d, $10 — normal talking range, in pixels
IsSpriteInFrontOfPlayer2:
    mov bh, 0x3c                     ; lb bc, $3c, $40 — the player sprite's fixed
    mov bl, 0x40                     ; screen Y ($3c) and X ($40)
    mov al, [ebp + W_SPRITE_PLAYER_FACING_DIR]
.checkIfPlayerFacingUp:
    cmp al, SPRITE_FACING_UP
    jne .checkIfPlayerFacingDown
    sub bh, dh                       ; ld a,b / sub d / ld b,a
    mov al, PLAYER_DIR_UP
    jmp .doneCheckingDirection
.checkIfPlayerFacingDown:
    cmp al, SPRITE_FACING_DOWN
    jne .checkIfPlayerFacingRight
    add bh, dh
    mov al, PLAYER_DIR_DOWN
    jmp .doneCheckingDirection
.checkIfPlayerFacingRight:
    cmp al, SPRITE_FACING_RIGHT
    jne .playerFacingLeft
    add bl, dh
    mov al, PLAYER_DIR_RIGHT
    jmp .doneCheckingDirection
.playerFacingLeft:
    sub bl, dh
    mov al, PLAYER_DIR_LEFT
.doneCheckingDirection:
    mov [ebp + W_PLAYER_DIRECTION], al
    mov esi, wSprite01StateData1     ; slot 1 (slot 0 is the player)
    mov dl, 0x01                     ; e = slot index, 1-based
    mov dh, 0x0f                     ; d = 15 slots to scan (range is dead from here)
; Yellow does not have Red's "if sprites are existent" check.
.spriteLoop:
    push esi
    mov al, [ebp + esi + SPRITESTATEDATA1_PICTUREID]
    test al, al
    jz .nextSprite                   ; 0 = no sprite in this slot
    mov al, [ebp + esi + SPRITESTATEDATA1_IMAGEINDEX]
    inc al
    jz .nextSprite                   ; $ff = sprite hidden (pret: inc a / jr z)
    mov al, [ebp + esi + SPRITESTATEDATA1_YPIXELS]
    cmp al, bh
    jne .nextSprite
    mov al, [ebp + esi + SPRITESTATEDATA1_XPIXELS]
    cmp al, bl
    je .foundSpriteInFrontOfPlayer
.nextSprite:
    pop esi
    ; pret does this as `ld a,l / add SPRITESTATEDATA1_LENGTH / ld l,a` — 8-bit math
    ; on L alone. Equivalent here: the scan runs slots 1-15 ($C110..$C1F0), so L never
    ; wraps before the counter ends the loop.
    add esi, SPRITESTATEDATA1_LENGTH
    inc dl
    dec dh                           ; sets the ZF the loop branch reads
    jnz .spriteLoop
    xor al, al                       ; also clears CF: no sprite in front
    ret
.foundSpriteInFrontOfPlayer:
    pop esi
    ; pret: ld a,l / and $f0 / inc a / ld l,a — mask back to the slot base, then +1.
    ; ESI is already the slot base (16-aligned), so the mask is a no-op here.
    add esi, SPRITESTATEDATA1_MOVEMENTSTATUS
    or byte [ebp + esi], (1 << BIT_FACE_PLAYER)  ; set BIT_FACE_PLAYER, [hl]
    mov al, dl
    mov [ebp + H_SPRITE_INDEX], al
    ; pret re-reads hSpriteIndex here ("possible useless read because a already has
    ; the value") — elided; AL already holds it.
    cmp al, PIKACHU_SPRITE_INDEX
    jne .dontwritetowd436            ; pret's label typo (.dontwritetowd436 → wd435) kept
    mov byte [ebp + wd435], 0xFF
.dontwritetowd436:
    stc                              ; scf: found
    ret
