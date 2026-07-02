; ===========================================================================
; display_text_id_init.asm — initialization for DisplayTextID.
; Faithful port of pret engine/menus/display_text_id_init.asm
; (menus-port Session 2, docs/current_plan_menus.md).
;
;   DisplayTextIDInit — draw the dialog/start-menu text box border, mark the
;   font loaded, run/skip UpdateSprites per wMiscFlags, save every NPC's
;   facing direction (restored by CloseTextDisplay), freeze mid-step walk
;   animation, and re-enable the VBlank BG transfer.
;
; Called by DisplayTextID (src/home/text_script.asm) before the text-ID
; dispatch; the teardown mirror is CloseTextDisplay in the same file.
;
; ── SCREEN MODEL (overworld stride-20 scratch) ──────────────────────────────
; DisplayTextID runs in OVERWORLD context: text_row_stride is the default 20
; and dialog text is composited through the window layer (set_single_window /
; sync_dialog_window mirror W_TILEMAP rows 12-17, stride 20 — see text.asm).
; Both borders below therefore draw at pret's GB coords into the stride-20
; W_TILEMAP scratch (NOT the 40-wide canvas the DisplayTextBoxID_ tables use):
;   * dialog border at (0,12) = MSG_BOX_ESI — the same cell PrintText_Overworld
;     redraws; an idempotent double-draw, exactly as pret (TextBoxBorder here,
;     again inside PrintText).
;   * start-menu border at (10,0) — redundant in pret too (DisplayStartMenu
;     redraws it); kept for call-structure parity, invisible in the port (no
;     window descriptor covers it until DisplayStartMenu runs).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=DX, HL=ESI,
; EBP = GB base; GB memory = [EBP+addr].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/display_text_id_init.asm
; ===========================================================================

%include "gb_memmap.inc"
%include "assets/event_constants.inc"   ; EVENT_GOT_POKEDEX
%include "events.inc"                   ; CheckEvent (clobbers AL, sets ZF)
%include "gb_constants.inc"

bits 32

global DisplayTextIDInit

extern TextBoxBorder                    ; text.asm — ESI=top-left, BL=int_w, BH=int_h
extern UpdateSprites                    ; engine/overworld/movement.asm
extern CopyScreenTileBufferToVRAM       ; home/copy2.asm — 3-frame pacing (port model)
extern LoadFontTilePatterns             ; gfx/load_font.asm — font glyphs → vFont

; Local screen-model constant (matches text.asm's private SCREEN_W_TILES):
; the GB 20-tile overworld row stride used by the window-composited dialog.
GB_SCREEN_W  equ 20

section .text

; ---------------------------------------------------------------------------
; DisplayTextIDInit — function that performs initialization for DisplayTextID.
; pret ref: engine/menus/display_text_id_init.asm:DisplayTextIDInit
; ---------------------------------------------------------------------------
DisplayTextIDInit:
    ; xor a / ld [wListMenuID],a
    xor al, al
    mov [ebp + wListMenuID], al
    ; ld a,[wAutoTextBoxDrawingControl] / bit BIT_NO_AUTO_TEXT_BOX,a / jr nz
    mov al, [ebp + wAutoTextBoxDrawingControl]
    test al, (1 << BIT_NO_AUTO_TEXT_BOX)
    jnz .skipDrawingTextBoxBorder
    ; ldh a,[hTextID] / and a / jr nz,.notStartMenu
    mov al, [ebp + hTextID]
    test al, al
    jnz .notStartMenu
; if text ID is 0 (i.e. the start menu)
; Note that the start menu text border is also drawn in the function directly
; below this, so this seems unnecessary. (pret comment; see SCREEN MODEL note.)
    CheckEvent EVENT_GOT_POKEDEX        ; ZF=0 → have pokédex (clobbers AL)
; start menu with pokedex: hlcoord 10,0 / lb bc,14,8
    mov esi, W_TILEMAP + 0 * GB_SCREEN_W + 10
    mov bh, 14                          ; b = interior height
    mov bl, 8                           ; c = interior width
    jnz .drawTextBoxBorder
; start menu without pokedex: hlcoord 10,0 / lb bc,12,8
    mov esi, W_TILEMAP + 0 * GB_SCREEN_W + 10
    mov bh, 12
    mov bl, 8
    jmp .drawTextBoxBorder
; if text ID is not 0 (i.e. not the start menu) then do a standard dialogue text box
.notStartMenu:
    ; hlcoord 0,12 / lb bc,4,18 — the (0,12) dialog cell = text.asm MSG_BOX_ESI
    mov esi, W_TILEMAP + 12 * GB_SCREEN_W
    mov bh, 4
    mov bl, 18
.drawTextBoxBorder:
    call TextBoxBorder                  ; stride = text_row_stride (20, overworld)
.skipDrawingTextBoxBorder:
    ; ld hl,wFontLoaded / set BIT_FONT_LOADED,[hl]
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    ; ld hl,wMiscFlags / bit BIT_NO_SPRITE_UPDATES,[hl] / res .. ,[hl] / jr nz
    ; (pret tests, then clears, then branches on the ORIGINAL bit — keep AH copy)
    mov al, [ebp + wMiscFlags]
    mov ah, al
    and al, ~(1 << BIT_NO_SPRITE_UPDATES) & 0xFF
    mov [ebp + wMiscFlags], al
    test ah, (1 << BIT_NO_SPRITE_UPDATES)
    jnz .skipMovingSprites
    call UpdateSprites
.skipMovingSprites:
; loop to copy [x#SPRITESTATEDATA1_FACINGDIRECTION] to
; [x#SPRITESTATEDATA2_ORIGFACINGDIRECTION] for each non-player sprite
; this is done because when you talk to an NPC, they turn to look your way
; the original direction they were facing must be restored after the dialogue
; is over (CloseTextDisplay's restore loop is the exact inverse)
    ; ld hl,wSprite01StateData1FacingDirection ($C119, slot 1) /
    ; ld c,NUM_SPRITESTATEDATA_STRUCTS-1 / ld de,SPRITESTATEDATA1_LENGTH
    mov esi, W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_LENGTH + SPRITESTATEDATA1_FACINGDIRECTION
    mov cl, NUM_SPRITESTATEDATA_STRUCTS - 1
.spriteFacingDirectionCopyLoop:
    ; ld a,[hl] / inc h / ld [hl],a / dec h / add hl,de
    ; (inc h = +$100: StateData1 $C1xx → StateData2 $C2xx, same low byte)
    mov al, [ebp + esi]
    mov [ebp + esi + 0x100], al
    add esi, SPRITESTATEDATA1_LENGTH
    dec cl
    jnz .spriteFacingDirectionCopyLoop
; loop to force all the sprites in the middle of animation to stand still
; (so that they don't look like they're frozen mid-step during the dialogue)
    ; ld hl,wSpritePlayerStateData1ImageIndex / ld de,SPRITESTATEDATA1_LENGTH /
    ; ld c,e   (pret ASSERT NUM_SPRITESTATEDATA_STRUCTS == SPRITESTATEDATA1_LENGTH)
    mov esi, W_SPRITE_PLAYER_IMAGE_INDEX
    mov cl, NUM_SPRITESTATEDATA_STRUCTS
.spriteStandStillLoop:
    ; ld a,[hl] / cp $ff / jr z,.nextSprite — is the sprite visible?
    mov al, [ebp + esi]
    cmp al, 0xFF
    je .nextSprite
    ; if it is visible: and $fc / ld [hl],a — snap to the standing frame
    and al, 0xFC
    mov [ebp + esi], al
.nextSprite:
    add esi, SPRITESTATEDATA1_LENGTH    ; add hl,de
    dec cl
    jnz .spriteStandStillLoop
    ; ld b,HIGH(vBGMap1) / call CopyScreenTileBufferToVRAM
    mov bh, 0x9C                        ; HIGH(vBGMap1) — ignored by the port
                                        ; routine (native renderer owns W_TILEMAP);
                                        ; kept for register-contract parity
    call CopyScreenTileBufferToVRAM     ; = 3-frame pacing (see copy2.asm)
    ; xor a / ldh [hWY],a — put the window on the screen
    ; TODO-HW: rWY write. The port's window compositor owns dialog placement —
    ; PrintText_Overworld calls set_single_window (which mirrors wy→H_WY as the
    ; dialog-open gate); writing H_WY=0 here would falsely open that gate with
    ; no window descriptor, so the write is intentionally NOT performed.
    ; call LoadFontTilePatterns
    call LoadFontTilePatterns
    ; ld a,$01 / ldh [hAutoBGTransferEnabled],a — continuous WRAM→VRAM per VBlank
    mov al, 0x01
    mov [ebp + H_AUTO_BG_TRANSFER_EN], al
    ret
