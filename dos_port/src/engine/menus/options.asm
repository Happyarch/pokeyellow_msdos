; options.asm — the OPTION menu (menus-port Session 6, package D).
;
; Faithful port of pret engine/menus/options.asm: DisplayOptionMenu_ +
; InitOptionsMenu + OptionsControl + GetOptionPointer jump table + the six
; per-row handlers (text speed / battle animations / battle style / sound /
; GB-printer brightness / cancel) + OptionsMenu_UpdateCursorPosition.
;
; This screen does NOT use the generic HandleMenuInput driver. It runs its own
; JoypadLowSensitivity loop with a 3×DelayFrame cadence (pret's own dpad delay);
; JoypadLowSensitivity is already ported (src/input/joypad_lowsens.asm) and is
; extern'd here — the hJoy5 read model is preserved verbatim.
;
; The 18 rendered strings are GENERATED (assets/options_strings.inc, from
; tools/gen_menu_strings.py). They were hand-encoded charmap `db` bytes here until
; menu-fidelity row 14, described by this header as "Tier-2 code data" — which was
; the violation, not an exemption from it (CLAUDE.md: a string the player reads is
; Tier-1 DATA). Only OptionMenuJumpTable stays hand-written: it holds flat CODE
; addresses, which no data generator can emit.
;
; PORT MODEL (window compositor, same as party_menu.asm's full-screen takeover):
; - The menu is drawn at pret GB coords into the 20-wide stride-20 W_TILEMAP
;   scratch (hlcoord X,Y = W_TILEMAP + Y*20 + X; GBSCR_W = 20). One full-screen
;   window shows it: options_mirror blits the 20×18 scratch → GB_TILEMAP1 rows
;   0-17 and OptionsShowWindow defines the single descriptor at UI_OPTIONS_*.
;   g_bg_whiteout blanks the overworld behind it (pret's OPTION screen is a
;   full-screen takeover). This stands in for pret's hAutoBGTransferEnabled
;   VBlank BGMap transfer (the legacy do_bg_transfer is retired; explicit
;   mirrors are the port's only WRAM→tilemap path — same pattern as
;   S3 list_mirror / S5 PartyMenuMirror).
; - This menu redraws the ONE value row under the cursor on every left/right
;   press (GetOptionPointer → the row handler → PlaceString). options_mirror is
;   therefore called once per loop iteration, in the slot pret uses for its
;   auto BGMap transfer (right after OptionsMenu_UpdateCursorPosition, before
;   the three DelayFrames), so the fresh value + ▶ cursor reach the window.
;
; ; PROJ menus: box + cursor + labels project onto the UI_OPTIONS window
;   (GB(0,0) 20x18 --(center/top)--> wx=87 wy=0 clip=160 max_y=144 [UI_OPTIONS_*]).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL),
; HL=ESI, EBP = GB memory base. GB memory is [ebp + symbol].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/options.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global DisplayOptionMenu_
global InitOptionsMenu
global OptionsControl
global GetOptionPointer
global OptionsMenu_UpdateCursorPosition

extern JoypadLowSensitivity          ; input/joypad_lowsens.asm — → [hJoy5]
extern DelayFrame                    ; video/frame.asm
extern Delay3                        ; video/frame.asm — 3× DelayFrame
extern TextBoxBorder                 ; text/text.asm — ESI=top-left, BL=int w, BH=int h
extern PlaceString                   ; text/text.asm — ESI=dest, EAX=flat src
extern AddNTimes                     ; home/array.asm — AL=n, BX=step, ESI=base → ESI+=n*step
extern set_single_window             ; ppu/ppu.asm
extern g_bg_whiteout                 ; ppu/ppu.asm
extern text_row_stride               ; text/text.asm — active W_TILEMAP row stride

; SOUND_MASK, wOptionsCursorLocation, wPrinterSettings now live in gb_memmap.inc
; (root-promoted at integration; wOptionsCursorLocation corrected to the sym
; address 0xCD3D). OPT_*/NUM_*/PRINTER_BRIGHTNESS_* stay local (options-only
; jump-table index enums, per the two-tier rule).

; OptionMenuJumpTable indexes (pret ref: constants/ram_constants.asm)
OPT_TEXT_SPEED        equ 0
OPT_BATTLE_ANIMS      equ 1
OPT_BATTLE_STYLE      equ 2
OPT_SOUND             equ 3
OPT_PRINTER           equ 4
OPT_CANCEL            equ 7
NUM_OPTIONS           equ 8

OPT_TEXT_SPEED_FAST   equ 0
OPT_TEXT_SPEED_MID    equ 1
OPT_TEXT_SPEED_SLOW   equ 2
NUM_TEXT_SPEED_OPTS   equ 3

OPT_PRINTER_LIGHTEST  equ 0
OPT_PRINTER_LIGHTER   equ 1
OPT_PRINTER_NORMAL    equ 2
OPT_PRINTER_DARKER    equ 3
OPT_PRINTER_DARKEST   equ 4
NUM_PRINTER_OPTS      equ 5

PRINTER_BRIGHTNESS_LIGHTEST equ 0x00
PRINTER_BRIGHTNESS_LIGHTER  equ 0x20
PRINTER_BRIGHTNESS_NORMAL   equ 0x40
PRINTER_BRIGHTNESS_DARKER   equ 0x60
PRINTER_BRIGHTNESS_DARKEST  equ 0x7F

GBSCR_W   equ 20        ; pret SCREEN_WIDTH — stride of the stride-20 scratch
TILE_SPC       equ 0x7F      ; ' ' blank tile
TILE_CURSOR    equ 0xED      ; '▶'

; hlcoord X,Y helper (stride-20 scratch)
%define HL(X,Y)  (W_TILEMAP + (Y) * GBSCR_W + (X))

section .text

; ---------------------------------------------------------------------------
; DisplayOptionMenu_ — pret ref: engine/menus/options.asm:DisplayOptionMenu_.
; Draw the menu, then loop: read the debounced joypad, exit on START/B, move
; the cursor on up/down (OptionsControl) or edit the highlighted row's value
; (GetOptionPointer), redraw the cursor, wait the 3-frame dpad delay.
; In: EBP = GB base.
; ---------------------------------------------------------------------------
; BUG(cosmetic): "Options menu code fails to clear joypad state on initialization"
; — the first JoypadLowSensitivity read inside .optionMenuLoop below picks up
; whatever direction was already held when the menu opened, shifting that row's
; option left/right on the opening frame. pret's own doc calls it "(or feature!)"
; and notes it exists in pokegold/pokecrystal too. Preserved at BUG_FIX_LEVEL 0,
; as the convention requires; the fix below is pret's own, verbatim.
; pret ref: engine/menus/options.asm:DisplayOptionMenu_,
;   docs/bugs_and_glitches.md#options-menu-code-fails-to-clear-joypad-state-on-initialization
;   ("Fix: + call JoypadLowSensitivity" immediately before InitOptionsMenu)
DisplayOptionMenu_:
%if BUG_FIX_LEVEL >= 2
    call JoypadLowSensitivity                ; consume the held direction so the
                                             ; opening frame cannot shift a row
%endif
    call InitOptionsMenu
.optionMenuLoop:
    call JoypadLowSensitivity
    mov al, [ebp + H_JOY5]                  ; ldh a, [hJoy5]
    and al, PAD_START | PAD_B
    jnz .exitOptionMenu                      ; jr nz
    call OptionsControl
    jc .dpadDelay                            ; jr c (cursor moved)
    call GetOptionPointer
    jc .exitOptionMenu                       ; jr c (CANCEL chosen)
.dpadDelay:
    call OptionsMenu_UpdateCursorPosition
    ; port: mirror the scratch (fresh value row + ▶) → the window, in the slot
    ; pret's hAutoBGTransferEnabled VBlank transfer occupies.
    call options_mirror
    call DelayFrame
    call DelayFrame
    call DelayFrame
    jmp .optionMenuLoop
.exitOptionMenu:
    ret

; ---------------------------------------------------------------------------
; GetOptionPointer — pret ref: engine/menus/options.asm:GetOptionPointer.
; Tail-jump to the handler for the currently highlighted option (pret `jp hl`).
; ---------------------------------------------------------------------------
GetOptionPointer:
    movzx eax, byte [ebp + wOptionsCursorLocation]
    jmp [OptionMenuJumpTable + eax * 4]      ; ld hl,tbl / add hl,de×2 / jp hl

; ---------------------------------------------------------------------------
; OptionsMenu_TextSpeed — pret ref: options.asm:OptionsMenu_TextSpeed.
; Cycle the text-speed row (bits 3-0 of wOptions) on left/right; redraw it.
; ---------------------------------------------------------------------------
OptionsMenu_TextSpeed:
    call GetTextSpeed                        ; BL=sel, DH=left delay, DL=right delay
    mov al, [ebp + H_JOY5]
    test al, PAD_RIGHT                       ; bit B_PAD_RIGHT
    jnz .pressedRight
    test al, PAD_LEFT                        ; bit B_PAD_LEFT
    jnz .pressedLeft
    jmp .nonePressed
.pressedRight:
    mov al, bl                               ; ld a,c
    cmp al, NUM_TEXT_SPEED_OPTS - 1
    jc .increase                             ; jr c
    mov bl, -1                               ; ld c,-1
.increase:
    inc bl                                   ; inc c
    mov al, dl                               ; ld a,e (right delay)
    jmp .save
.pressedLeft:
    mov al, bl                               ; ld a,c
    and al, al
    jnz .decrease                            ; jr nz
    mov bl, NUM_TEXT_SPEED_OPTS              ; ld c,NUM_TEXT_SPEED_OPTS
.decrease:
    dec bl                                   ; dec c
    mov al, dh                               ; ld a,d (left delay)
.save:
    mov bh, al                               ; ld b,a
    mov al, [ebp + wOptions]
    and al, ~TEXT_DELAY_MASK & 0xFF
    or al, bh                                ; or b
    mov [ebp + wOptions], al
.nonePressed:
    movzx ebx, bl                            ; ld b,0 ; index = c
    mov eax, [.Strings + ebx * 4]
    mov esi, HL(14, 2)                       ; hlcoord 14,2
    call PlaceString
    and al, al                               ; clear carry flag
    ret

.Strings:
    dd opt_ts_fast, opt_ts_mid, opt_ts_slow

; GetTextSpeed — pret ref: options.asm:GetTextSpeed.
; Out: BL = current selection, DH = left-neighbour delay, DL = right-neighbour.
GetTextSpeed:
    mov al, [ebp + wOptions]
    and al, TEXT_DELAY_MASK
    cmp al, TEXT_DELAY_SLOW
    jz .slowTextOption
    cmp al, TEXT_DELAY_FAST
    jz .fastTextOption
    mov bl, OPT_TEXT_SPEED_MID
    mov dh, TEXT_DELAY_FAST                   ; lb de, FAST, SLOW
    mov dl, TEXT_DELAY_SLOW
    ret
.slowTextOption:
    mov bl, OPT_TEXT_SPEED_SLOW
    mov dh, TEXT_DELAY_MEDIUM                 ; lb de, MEDIUM, FAST
    mov dl, TEXT_DELAY_FAST
    ret
.fastTextOption:
    mov bl, OPT_TEXT_SPEED_FAST
    mov dh, TEXT_DELAY_SLOW                   ; lb de, SLOW, MEDIUM
    mov dl, TEXT_DELAY_MEDIUM
    ret

; ---------------------------------------------------------------------------
; OptionsMenu_BattleAnimations — pret ref: options.asm:OptionsMenu_BattleAnimations.
; Toggle wOptions bit BIT_BATTLE_ANIMATION on left/right; redraw ON/OFF.
; ---------------------------------------------------------------------------
OptionsMenu_BattleAnimations:
    mov al, [ebp + H_JOY5]
    and al, PAD_LEFT | PAD_RIGHT
    jnz .buttonPressed
    mov al, [ebp + wOptions]
    and al, 1 << BIT_BATTLE_ANIMATION
    jmp .nothingPressed
.buttonPressed:
    mov al, [ebp + wOptions]
    xor al, 1 << BIT_BATTLE_ANIMATION
    mov [ebp + wOptions], al
.nothingPressed:
    xor ebx, ebx                             ; ld bc,0
    shl al, 1                                 ; sla a — bit7 → CF
    rcl bl, 1                                 ; rl c — c = old bit7 (anim disabled?)
    mov eax, [.Strings + ebx * 4]
    mov esi, HL(14, 4)                        ; hlcoord 14,4
    call PlaceString
    and al, al                               ; clear carry flag
    ret

.Strings:
    dd opt_ba_on, opt_ba_off

; ---------------------------------------------------------------------------
; OptionsMenu_BattleStyle — pret ref: options.asm:OptionsMenu_BattleStyle.
; Toggle wOptions bit BIT_BATTLE_SHIFT on left/right; redraw SHIFT/SET.
; ---------------------------------------------------------------------------
OptionsMenu_BattleStyle:
    mov al, [ebp + H_JOY5]
    and al, PAD_LEFT | PAD_RIGHT
    jnz .buttonPressed
    mov al, [ebp + wOptions]
    and al, 1 << BIT_BATTLE_SHIFT
    jmp .nothingPressed
.buttonPressed:
    mov al, [ebp + wOptions]
    xor al, 1 << BIT_BATTLE_SHIFT
    mov [ebp + wOptions], al
.nothingPressed:
    xor ebx, ebx                             ; ld bc,0
    shl al, 1                                 ; sla a
    shl al, 1                                 ; sla a — bit6 → CF
    rcl bl, 1                                 ; rl c — c = old bit6 (SET style?)
    mov eax, [.Strings + ebx * 4]
    mov esi, HL(14, 6)                        ; hlcoord 14,6
    call PlaceString
    and al, al                               ; clear carry flag
    ret

.Strings:
    dd opt_bs_shift, opt_bs_set

; ---------------------------------------------------------------------------
; OptionsMenu_SpeakerSettings — pret ref: options.asm:OptionsMenu_SpeakerSettings.
; Cycle wOptions bits 4-5 (sound) 0..3 on left/right; redraw MONO/EARPHONE*.
; ---------------------------------------------------------------------------
OptionsMenu_SpeakerSettings:
    mov al, [ebp + wOptions]
    and al, SOUND_MASK
    rol al, 4                                ; swap a — bits 4-5 → 0-1
    mov bl, al                               ; ld c,a
    mov al, [ebp + H_JOY5]
    test al, PAD_RIGHT
    jnz .pressedRight
    test al, PAD_LEFT
    jnz .pressedLeft
    jmp .nothingPressed
.pressedRight:
    mov al, bl                               ; ld a,c
    inc al
    and al, SOUND_MASK >> 4                   ; and 3
    jmp .save
.pressedLeft:
    mov al, bl                               ; ld a,c
    dec al
    and al, SOUND_MASK >> 4
.save:
    mov bl, al                               ; ld c,a
    rol al, 4                                ; swap a
    mov bh, al                               ; ld b,a
    ; xor a / ldh [rAUDTERM], a — silence all channel output while the speaker
    ; setting changes. This store was DROPPED behind a "TODO-HW: audio HAL
    ; (Phase 3) — no APU register in the port" comment, which was false: rAUDTERM
    ; is a live GB-memory byte here (gb_memmap.inc, $FF25), written by the audio
    ; engine (src/audio/engine_1.asm, engine_2.asm) and READ every frame by the
    ; output shims (opl_shim.asm, tandy_shim.asm, spk_shim.asm) to decide channel
    ; routing. Nothing was blocking the store; restored. (M-53)
    xor al, al
    mov [ebp + rAUDTERM], al
    mov al, [ebp + wOptions]
    and al, ~SOUND_MASK & 0xFF
    or al, bh                                ; or b
    mov [ebp + wOptions], al
.nothingPressed:
    movzx ebx, bl                            ; ld b,0 ; index = c
    mov eax, [.Strings + ebx * 4]
    mov esi, HL(8, 8)                         ; hlcoord 8,8
    call PlaceString
    and al, al                               ; clear carry flag
    ret

.Strings:
    dd opt_snd_mono, opt_snd_ear1, opt_snd_ear2, opt_snd_ear3

; ---------------------------------------------------------------------------
; OptionsMenu_GBPrinterBrightness — pret ref: options.asm:OptionsMenu_GBPrinterBrightness.
; Cycle wPrinterSettings 0..4 on left/right; redraw LIGHTEST..DARKEST. The
; value is stored; nothing is transmitted (no serial link).
; ---------------------------------------------------------------------------
OptionsMenu_GBPrinterBrightness:
    ; TODO-HW: printer (no serial) — the row renders and the brightness value is
    ; stored in wPrinterSettings, but there is no GB Printer HAL to drive.
    call GetGBPrinterBrightness              ; BL=sel, DH=left, DL=right
    mov al, [ebp + H_JOY5]
    test al, PAD_RIGHT
    jnz .pressedRight
    test al, PAD_LEFT
    jnz .pressedLeft
    jmp .nothingPressed
.pressedRight:
    mov al, bl                               ; ld a,c
    cmp al, NUM_PRINTER_OPTS - 1
    jc .increase                             ; jr c
    mov bl, -1                               ; ld c,-1
.increase:
    inc bl                                   ; inc c
    mov al, dl                               ; ld a,e (right value)
    jmp .save
.pressedLeft:
    mov al, bl                               ; ld a,c
    and al, al
    jnz .decrease                            ; jr nz
    mov bl, NUM_PRINTER_OPTS                 ; ld c,NUM_PRINTER_OPTS
.decrease:
    dec bl                                   ; dec c
    mov al, dh                               ; ld a,d (left value)
.save:
    mov bh, al                               ; ld b,a
    mov [ebp + wPrinterSettings], al         ; ld [wPrinterSettings],a
.nothingPressed:
    movzx ebx, bl                            ; ld b,0 ; index = c
    mov eax, [.Strings + ebx * 4]
    mov esi, HL(8, 10)                        ; hlcoord 8,10
    call PlaceString
    and al, al                               ; clear carry flag
    ret

.Strings:
    dd opt_pr_lightest, opt_pr_lighter, opt_pr_normal, opt_pr_darker, opt_pr_darkest

; GetGBPrinterBrightness — pret ref: options.asm:GetGBPrinterBrightness.
; Out: BL = current selection, DH = left-neighbour value, DL = right-neighbour.
GetGBPrinterBrightness:
    mov al, [ebp + wPrinterSettings]
    and al, al                               ; cp PRINTER_BRIGHTNESS_LIGHTEST (0)
    jz .setLightest
    cmp al, PRINTER_BRIGHTNESS_LIGHTER
    jz .setLighter
    cmp al, PRINTER_BRIGHTNESS_DARKER
    jz .setDarker
    cmp al, PRINTER_BRIGHTNESS_DARKEST
    jz .setDarkest
    mov bl, OPT_PRINTER_NORMAL
    mov dh, PRINTER_BRIGHTNESS_LIGHTER        ; lb de, LIGHTER, DARKER
    mov dl, PRINTER_BRIGHTNESS_DARKER
    ret
.setLightest:
    mov bl, OPT_PRINTER_LIGHTEST
    mov dh, PRINTER_BRIGHTNESS_DARKEST        ; lb de, DARKEST, LIGHTER
    mov dl, PRINTER_BRIGHTNESS_LIGHTER
    ret
.setLighter:
    mov bl, OPT_PRINTER_LIGHTER
    mov dh, PRINTER_BRIGHTNESS_LIGHTEST       ; lb de, LIGHTEST, NORMAL
    mov dl, PRINTER_BRIGHTNESS_NORMAL
    ret
.setDarker:
    mov bl, OPT_PRINTER_DARKER
    mov dh, PRINTER_BRIGHTNESS_NORMAL         ; lb de, NORMAL, DARKEST
    mov dl, PRINTER_BRIGHTNESS_DARKEST
    ret
.setDarkest:
    mov bl, OPT_PRINTER_DARKEST
    mov dh, PRINTER_BRIGHTNESS_DARKER         ; lb de, DARKER, LIGHTEST
    mov dl, PRINTER_BRIGHTNESS_LIGHTEST
    ret

; ---------------------------------------------------------------------------
; OptionsMenu_Dummy — pret ref: options.asm:OptionsMenu_Dummy. Unused rows 5,6.
; ---------------------------------------------------------------------------
OptionsMenu_Dummy:
    and al, al                               ; clear carry flag
    ret

; ---------------------------------------------------------------------------
; OptionsMenu_Cancel — pret ref: options.asm:OptionsMenu_Cancel.
; A press → carry set (leave the menu); otherwise carry clear.
; ---------------------------------------------------------------------------
OptionsMenu_Cancel:
    mov al, [ebp + H_JOY5]
    and al, PAD_A
    jnz .pressedCancel
    and al, al                               ; clear carry flag
    ret
.pressedCancel:
    stc                                      ; scf
    ret

; ---------------------------------------------------------------------------
; OptionsControl — pret ref: options.asm:OptionsControl.
; Move the cursor on up/down (with the printer→cancel skip over the two dummy
; rows and top/bottom wrap). Out: CF set iff the cursor moved.
; ---------------------------------------------------------------------------
OptionsControl:
    mov al, [ebp + H_JOY5]
    cmp al, PAD_DOWN
    jz .pressedDown
    cmp al, PAD_UP
    jz .pressedUp
    and al, al                               ; clear carry flag
    ret
.pressedDown:
    mov al, [ebp + wOptionsCursorLocation]
    cmp al, NUM_OPTIONS - 1
    jnz .doNotWrap
    mov byte [ebp + wOptionsCursorLocation], 0
    stc
    ret
.doNotWrap:
    cmp al, OPT_PRINTER                       ; skip the two dummy rows
    jc .increase                              ; jr c
    mov byte [ebp + wOptionsCursorLocation], OPT_CANCEL - 1   ; Cancel is after Print
.increase:
    inc byte [ebp + wOptionsCursorLocation]
    stc
    ret
.pressedUp:
    mov al, [ebp + wOptionsCursorLocation]
    cmp al, OPT_CANCEL                        ; skip the two dummy rows
    jnz .doNotSkip
    mov byte [ebp + wOptionsCursorLocation], OPT_PRINTER      ; Print is before Cancel
    stc
    ret
.doNotSkip:
    and al, al
    jnz .decrease
    mov byte [ebp + wOptionsCursorLocation], NUM_OPTIONS
.decrease:
    dec byte [ebp + wOptionsCursorLocation]
    stc
    ret

; ---------------------------------------------------------------------------
; OptionsMenu_UpdateCursorPosition — pret ref: options.asm:OptionsMenu_UpdateCursorPosition.
; Blank the cursor column (rows 1-16) then draw ▶ at the selected row.
; ---------------------------------------------------------------------------
OptionsMenu_UpdateCursorPosition:
    mov esi, HL(1, 1)                         ; hlcoord 1,1
    mov ecx, 16                               ; ld c,16
.loop:
    mov byte [ebp + esi], TILE_SPC            ; ld [hl],' '
    add esi, GBSCR_W                          ; add hl,de (de=SCREEN_WIDTH)
    dec ecx
    jnz .loop
    mov esi, HL(1, 2)                         ; hlcoord 1,2
    mov bx, 2 * GBSCR_W                        ; ld bc,SCREEN_WIDTH*2 (BX = AddNTimes step)
    mov al, [ebp + wOptionsCursorLocation]
    call AddNTimes
    mov byte [ebp + esi], TILE_CURSOR         ; ld [hl],'▶'
    ret

; ---------------------------------------------------------------------------
; InitOptionsMenu — pret ref: options.asm:InitOptionsMenu.
; Draw the border + labels, prime each value row, reset the cursor, then (port)
; mirror the scratch to the window and settle for 3 frames.
; ---------------------------------------------------------------------------
InitOptionsMenu:
    ; port: the OPTION screen runs on the 20-wide stride-20 scratch (TextBoxBorder
    ; and PlaceString <NEXT> both advance by text_row_stride; the START menu leaves
    ; it at 40). Same reset the party menu's home driver does (home/pokemon.asm).
    mov dword [text_row_stride], 20
    mov esi, HL(0, 0)                         ; hlcoord 0,0
    mov bx, (16 << 8) | 18                    ; lb bc, SCREEN_HEIGHT-2, SCREEN_WIDTH-2
    call TextBoxBorder                        ; BH=16 int rows, BL=18 int cols
    mov eax, AllOptionsText
    mov esi, HL(2, 2)                         ; hlcoord 2,2
    call PlaceString
    mov eax, OptionMenuCancelText
    mov esi, HL(2, 16)                        ; hlcoord 2,16
    call PlaceString
    mov byte [ebp + wOptionsCursorLocation], 0
    mov ecx, 5                                ; ld c,5 — number of options to prime
.loop:
    push ecx
    call GetOptionPointer                     ; draws the current row's value
    pop ecx
    inc byte [ebp + wOptionsCursorLocation]   ; advance to the next row
    dec ecx
    jnz .loop
    mov byte [ebp + wOptionsCursorLocation], 0
    ; ld a,1 / ldh [hAutoBGTransferEnabled],a. The flag is WRITE-ONLY in the port
    ; (do_bg_transfer is retired; the explicit mirror below is the WRAM→tilemap
    ; path), but the store is pret's and is kept: a screen that quietly stops
    ; writing a flag pret writes is how port state drifts out of step with the
    ; disassembly. Same call made at party_menu.asm / start_sub_menus.asm (M-24).
    mov al, 1
    mov [ebp + hAutoBGTransferEnabled], al
    ; DEVIATION(window-compositor): pret's VBlank BGMap transfer has no port
    ; counterpart, so the finished scratch is published explicitly — mirror it into
    ; GB_TILEMAP1 and register the single full-screen window — then settle (Delay3).
    call options_mirror
    call OptionsShowWindow
    call Delay3
    ret

; ---------------------------------------------------------------------------
; OptionsShowWindow — port plumbing: full-screen window over the whited-out
; overworld, sourced from GB_TILEMAP1 rows 0-17 at the UI_OPTIONS anchor.
; ; PROJ menus: window = UI_OPTIONS_(WX,WY,CLIP,MAXY) (GB 20x18 full screen).
; ---------------------------------------------------------------------------
OptionsShowWindow:
    mov dword [g_bg_whiteout], 1              ; OPTION screen is a full takeover
    mov eax, UI_OPTIONS_WX
    mov ebx, UI_OPTIONS_WY
    mov ecx, UI_OPTIONS_CLIP
    mov edx, UI_OPTIONS_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi                              ; start_row = 0
    call set_single_window
    ret

; ---------------------------------------------------------------------------
; options_mirror — blit the stride-20 scratch rows 0-17 → GB_TILEMAP1 rows 0-17
; (the window's source; port stand-in for the hAutoBGTransferEnabled transfer).
; Preserves all registers.
; ---------------------------------------------------------------------------
options_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                ; ×32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, UI_OPTIONS_GBH                   ; 18 rows
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; Jump table (Tier-2 code data: it holds flat CODE addresses, which no generator
; can produce — this is the one table that belongs in the .asm) + the generated
; strings.
;
; The 18 rendered strings below USED to be hand-authored charmap `db` bytes here,
; under a header that called them "Tier-2 code data". They are not: a string the
; player reads is Tier-1 DATA (CLAUDE.md, "Text strings are DATA — never
; hand-encode charmap bytes"). They are now generated by tools/gen_menu_strings.py
; into assets/options_strings.inc (byte-compared against the old literals:
; identical, all 18). AllOptionsText and OptionMenuCancelText keep their pret
; GLOBAL names; the opt_* labels stand in for pret's RGBDS locals and are mapped
; back to them by the .Strings tables above.
; ---------------------------------------------------------------------------
section .data
align 4
; pret ref: options.asm:OptionMenuJumpTable
OptionMenuJumpTable:
    dd OptionsMenu_TextSpeed
    dd OptionsMenu_BattleAnimations
    dd OptionsMenu_BattleStyle
    dd OptionsMenu_SpeakerSettings
    dd OptionsMenu_GBPrinterBrightness
    dd OptionsMenu_Dummy
    dd OptionsMenu_Dummy
    dd OptionsMenu_Cancel

; AllOptionsText, OptionMenuCancelText, opt_ts_*, opt_ba_*, opt_bs_*, opt_snd_*,
; opt_pr_* — generated (pret ref: options.asm:AllOptionsText / OptionMenuCancelText
; and the six handlers' local .Strings entries).
%include "assets/options_strings.inc"

; ---------------------------------------------------------------------------
; RunOptionsTest — menus S6 package D FRAME.BIN gate (static open state).
; Seeds wOptions/wPrinterSettings, loads the font, opens the OPTION menu via the
; real InitOptionsMenu (border + labels + value rows + window), draws the ▶
; cursor once (as the loop's first iteration would), mirrors, renders, dumps
; FRAME.BIN, exits. Nav / edit is the S10 interactive sweep. Never returns.
; In: EBP = GB base.  make DEBUG_OPTIONS=1  (root wires the flag + call site).
; ---------------------------------------------------------------------------
%ifdef DEBUG_OPTIONS
global RunOptionsTest
extern LoadFontTilePatterns          ; gfx/load_font.asm
extern ClearSprites                  ; gfx/sprites.asm
extern DumpBackbuffer                ; debug/debug_dump.asm — writes FRAME.BIN + exits
extern SeedDeterministicPlayerIdentity ; engine/debug/debug_party.asm — "RED"/id 0 (seed.lua spec)

section .text
RunOptionsTest:
    ; identity = the golden spec ("RED" / id 0): the bare boot leaves wPlayerID
    ; as InitPlayerData's RNG roll (F-5 class — not even reproducible run to
    ; run), and the options_menu golden compares wPlayerName/wPlayerID
    call SeedDeterministicPlayerIdentity
    ; seed a representative options state (pret main_menu InitOptions defaults:
    ; MID text speed, animations ON, SHIFT style, MONO sound; printer NORMAL)
    mov byte [ebp + wOptions], TEXT_DELAY_MEDIUM
    mov byte [ebp + wPrinterSettings], PRINTER_BRIGHTNESS_NORMAL
    ; font glyphs + box-border tiles into vFont
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; no stray OAM over the full-screen menu
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    call InitOptionsMenu                      ; draw + window + settle
    call OptionsMenu_UpdateCursorPosition     ; draw the ▶ on TEXT SPEED
    call options_mirror
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                        ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
