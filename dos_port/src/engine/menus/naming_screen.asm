; naming_screen.asm — the letter-grid naming screen (menus S7, package C).
;
; Faithful port of pret engine/menus/naming_screen.asm: AskName,
; DisplayNameRaterScreen::, DisplayNamingScreen (+ its whole button-function
; table / handlers), PrintAlphabet, PrintNicknameAndUnderscores, PrintNamingText,
; CalcStringLength, LoadEDTile. Same routines, same labels, same branch
; structure/order as pret; divergences are tagged PROJ / TODO-HW / DEVIATION only.
;
; pret ref: engine/menus/naming_screen.asm (510 lines)
;
; PORT MODEL (full-screen takeover, same shape as options.asm / party_menu.asm):
; - DisplayNamingScreen draws into the 20-wide stride-20 W_TILEMAP scratch
;   (hlcoord X,Y = W_TILEMAP + Y*20 + X via the local HL(x,y) macro; GBSCR_W=20)
;   — this is pret's OWN coordinate space (pret's hlcoord is always stride-20;
;   the port's 40-wide battle canvas doesn't apply here). One full-screen window
;   (naming_show_window) shows it, sourced from GB_TILEMAP1 rows 0-17 at the
;   UI_NAMING_SCREEN anchor; naming_mirror blits the scratch -> GB_TILEMAP1 each
;   loop iteration (pret's hAutoBGTransferEnabled VBlank auto-transfer has no
;   literal equivalent in this engine, so an explicit per-frame mirror stands in
;   — same pattern as options_mirror/S3 list_mirror/S5 PartyMenuMirror).
; - This screen runs its OWN input loop (JoypadLowSensitivity + a 4-byte-entry
;   button-function jump table, exactly mirroring pret's sla-a bit scan +
;   push-de/jp-hl fake-call idiom) — not the generic HandleMenuInput driver,
;   matching pret's own bespoke structure here.
; - DisplayNamingScreen carries an IMPLICIT dest-pointer parameter in ESI (pret:
;   HL), preserved via a single push at entry / pop at .submitNickname (pret's
;   own `push hl` ... `.submitNickname: pop de` pairing) — the submitted name's
;   CopyData target. Every OTHER push/pop inside the routine (the per-frame
;   AnimatePartyMon save/restore slot, the button-table fake-call return
;   address) is balanced, so that one stacked value survives untouched until
;   .submitNickname, exactly as pret relies on.
;
; ; PROJ menus: box + grid + cursor project onto the UI_NAMING_SCREEN window
;   (GB(0,0) 20x18 --(center/top)--> wx=87 wy=0 clip=160 max_y=144 [UI_NAMING_SCREEN_*]).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX (D=DH,E=DL),
; HL=ESI, EBP = GB memory base; GB memory is [ebp + symbol].
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/naming_screen.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

global AskName
global DisplayNameRaterScreen
global DisplayNamingScreen

extern msgbox_centered                  ; src/engine/battle/core.asm — centered projection
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)
extern SaveScreenTilesToBuffer1        ; movie/title.asm
extern LoadScreenTilesFromBuffer1      ; movie/title.asm
extern GetPredefRegisters              ; home/predef.asm — ESI/EDX/EBX = hl/de/bc
extern GetMonName                      ; home/names.asm — AL=wNamedObjectIndex -> wNameBuffer
extern ClearScreenArea                 ; home/copy2.asm — ESI=dest, BH=rows, BL=cols
extern CopyData                        ; home/copy_data.asm — ESI=src,EDX=dest,BX=count
extern PrintText                   ; src/home/window.asm — the one printer; ESI = FLAT TX stream ptr
extern YesNoChoice                     ; home/yes_no.asm — the standard hlcoord(14,7) YES/NO box
extern ReloadMapSpriteTilePatterns     ; engine/overworld/reload_sprites.asm
extern GBPalWhiteOutWithDelay3         ; home/fade.asm
extern RestoreScreenTilesAndReloadTilePatterns ; home/fade.asm
extern LoadGBPal                       ; home/fade.asm
extern ClearScreen                     ; movie/title.asm — whole-canvas blank + auto-BG re-arm
extern ClearSprites                    ; gfx/sprites.asm
extern GBPalNormal                     ; init/init.asm
extern UpdateSprites                   ; engine/overworld/movement.asm
extern RunPaletteCommand               ; engine/battle/faint_switch.asm — palette HAL stub
extern LoadHpBarAndStatusTilePatterns  ; gfx/load_font.asm
extern LoadTextBoxTilePatterns         ; gfx/load_font.asm
extern LoadHudTilePatterns             ; gfx/load_font.asm
extern LoadMonPartySpriteGfx           ; engine/gfx/mon_icons.asm — pret's farcall target (same name)
extern WriteMonPartySpriteOAMBySpecies ; engine/gfx/mon_icons.asm
extern AnimatePartyMon_ForceSpeed1     ; engine/gfx/mon_icons.asm — ends in DelayFrame
extern SetMonPartySpriteOrigin         ; engine/gfx/mon_icons.asm (port: OAM→canvas projection)
extern g_obj_over_window               ; ppu/ppu.asm — OBJ over the window layer (GB order)
extern TextBoxBorder                   ; text/text.asm — ESI=dest, BL=int_w, BH=int_h
extern PlaceString                     ; text/text.asm — ESI=dest, EAX=flat src
extern AddNTimes                       ; home/array.asm — AL=n, BX=step, ESI+=n*step
extern JoypadLowSensitivity            ; input/joypad_lowsens.asm -> H_JOY5
extern DelayFrame                      ; video/frame.asm
extern Delay3                          ; video/frame.asm — 3x DelayFrame
extern PlaceMenuCursor                 ; home/window.asm
extern EraseMenuCursor                 ; home/window.asm
extern menu_item_step                  ; home/window.asm — cursor per-item row step
extern text_row_stride                 ; text/text.asm — active W_TILEMAP row stride
extern PlaySound                       ; engine/battle/move_effect_helpers.asm — audio HAL stub
extern set_single_window               ; ppu/ppu.asm
extern g_bg_whiteout                   ; ppu/ppu.asm
extern g_tilecache_dirty               ; ppu/ppu.asm — VRAM tile writes must set this

; ---------------------------------------------------------------------------
; Local enums (Tier-2, naming-screen-only; not in gb_memmap.inc/gb_constants.inc
; per the two-tier rule — these are jump-table indices / UI enums, not data).
; pret ref: constants/menu_constants.asm, constants/text_constants.asm
; ---------------------------------------------------------------------------
NAME_PLAYER_SCREEN     equ 0
NAME_RIVAL_SCREEN      equ 1
NAME_MON_SCREEN        equ 2
PLAYER_NAME_LENGTH     equ 8

; pret ref: constants/palette_constants.asm
SET_PAL_GENERIC        equ 0x08
SET_PAL_DEFAULT        equ 0xFF

; TODO-HW(audio): real id = SFX_PRESS_AB (constants/music_constants.asm, table
; index 62). PlaySound is a stub in this port (engine/battle/move_effect_helpers.asm);
; value not yet load-bearing. Placeholder kept explicit (matches ledges.asm's
; SFX_LEDGE convention) so the audio pass can wire the true id.
SFX_PRESS_AB            equ 0x3E

; Charmap control/glyph bytes used by hand-authored strings below
; (constants/charmap.asm).
CHAR_TERMINATOR equ 0x50   ; '@'
CHAR_LINE       equ 0x4F   ; <LINE>
CHAR_CONT       equ 0x55   ; <CONT>
CHAR_DAKUTEN    equ 0xE5   ; 'ﾞ' (charmap.asm:364) — JP-only, unreachable in EN
CHAR_HANDAKUTEN equ 0xE4   ; 'ﾟ' (charmap.asm:363) — JP-only, unreachable in EN

; Raw VRAM tile ids (written directly, not through the charmap glyph table).
TILE_UNDERSCORE        equ 0x76
TILE_UNDERSCORE_RAISED equ 0x77

GBSCR_W equ 20   ; pret SCREEN_WIDTH — stride of the naming screen's own stride-20 scratch

; hlcoord X,Y helper (stride-20 scratch)
%define HL(X,Y)  (W_TILEMAP + (Y) * GBSCR_W + (X))

; assets/alphabets.inc — Tier-1 generated letter-grid blobs (gen_alphabets.py).
; %include-in-.data, same pattern as gfx/load_font.asm's font asset includes.
section .data
%include "assets/alphabets.inc"

section .text

; ---------------------------------------------------------------------------
; AskName — pret ref: naming_screen.asm:AskName.
; Ask "do you want to nickname <mon>?" (YES/NO); on YES, run the full naming
; screen; on NO (or an empty submitted name), copy the default species name.
; In: ESI (HL) = flat GB-mem dest for the resulting NAME_LENGTH-byte name.
;     EBP = GB base.
; ---------------------------------------------------------------------------
AskName:
    call SaveScreenTilesToBuffer1
    call GetPredefRegisters              ; ESI(hl)/EDX(de)/EBX(bc) = predef regs
    push esi                             ; [S1] save dest — consumed at the very end

    mov al, [ebp + wIsInBattle]
    dec al
    ; pret: `call z, ClearScreenArea` (conditional CALL). hlcoord 0,0 / lb bc,4,11
    ; are pret's own (always-stride-20) coords — this call runs before the
    ; naming screen's own canvas takeover, so it targets whatever scratch is
    ; live at the call site (battle or overworld).
    jnz .skipBattleClear
    mov esi, HL(0, 0)
    mov bh, 4
    mov bl, 11
    call ClearScreenArea
.skipBattleClear:

    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wNamedObjectIndex], al
    call GetMonName                      ; default species name -> wNameBuffer

    ; pret: `ld hl, DoYouWantToNicknameText / call PrintText`. pret's single
    ; PrintText serves both battle and overworld; the port keeps the one PrintText
    ; and selects which msgbox PROJECTION it draws through (centered vs dialog) by
    ; wIsInBattle — the same signal this routine already branches on above.
    ; DEVIATION: projection selection added (text content/behavior unchanged).
    ;
    ; BUG(critical) [fixed here, no guard]: the battle branch used to pass the
    ; stream in EAX ("battle PrintText copies EAX itself" — false; there is one
    ; PrintText and it has always read ESI), so in battle it printed whatever
    ; GetMonName happened to leave in ESI. Not a Gen-1 bug to preserve — a port
    ; defect, so it is simply fixed rather than tagged BUG_FIX_LEVEL.
    mov esi, DoYouWantToNicknameText     ; flat stream — TCP walks it in place
    mov edx, msgbox_dialog               ; overworld: the dialog window projection
    cmp byte [ebp + wIsInBattle], 0
    je .nicknamePromptSetBox
    mov edx, msgbox_centered             ; battle: centered box, keeps this screen's window list
.nicknamePromptSetBox:
    mov [text_msgbox], edx
    call PrintText

    ; pret: hlcoord 14,7 / lb bc,8,15 / ld a,TWO_OPTION_MENU / ld[wTextBoxID],a /
    ; call DisplayTextBoxID — this is exactly the standard YES/NO box
    ; (home/yes_no.asm:InitYesNoTextBoxParameters also targets GB(14,7)); call
    ; the port's equivalent generic entry point directly instead of duplicating
    ; its body. Out: CF/wCurrentMenuItem — 0=YES(first), 1=NO(second).
    call YesNoChoice

    pop esi                              ; restore dest [S1]
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .declinedNickname

    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0
    push esi                             ; dest, again — DisplayNamingScreen's own [S1]
    mov byte [ebp + wNamingScreenType], NAME_MON_SCREEN
    call DisplayNamingScreen
    cmp byte [ebp + wIsInBattle], 0
    jnz .inBattle
    call ReloadMapSpriteTilePatterns
.inBattle:
    call LoadScreenTilesFromBuffer1
    pop esi                              ; restore dest
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    mov al, [ebp + wStringBuffer]
    cmp al, CHAR_TERMINATOR
    jne .ret                             ; non-empty name already landed via CopyData inside .submitNickname
.declinedNickname:
    mov edx, esi                         ; DE = dest
    mov esi, wNameBuffer                 ; HL = default name source
    mov bx, NAME_LENGTH
    call CopyData
.ret:
    ret

DoYouWantToNicknameText:
    ; DEVIATION: pret is `text_far _DoYouWantToNicknameText` (data/text/text_3.asm,
    ; a different ROM bank) + text_end; the far target's content is inlined here
    ; instead — byte-identical to what pret's bank-switch splice prints.
    ;
    ; The comment that used to sit here said TX_FAR "cannot address flat .data
    ; content". That was true of the broken .cmd_far and is now FALSE: TX_FAR takes
    ; a 32-bit flat operand and works (see docs/current_plan_text_engine.md T-2).
    ; The inline stays only because data/text/text_3.asm has no generator yet —
    ; when one lands, this becomes a real `text_far`. The hand-encoded charmap
    ; bytes below are the same pre-existing Tier-1 debt (they must be generated,
    ; not hand-written) and should be migrated with it.
    ; pret ref: data/text/text_3.asm:_DoYouWantToNicknameText
    ;   text "Do you want to" / line "give a nickname" / cont "to @" /
    ;   text_ram wNameBuffer / text "?" / done
    db 0x00                                    ; TX_START
    db 0x83,0xAE,0x7F,0xB8,0xAE,0xB4,0x7F,0xB6,0xA0,0xAD,0xB3,0x7F,0xB3,0xAE ; "Do you want to"
    db CHAR_LINE
    db 0xA6,0xA8,0xB5,0xA4,0x7F,0xA0,0x7F,0xAD,0xA8,0xA2,0xAA,0xAD,0xA0,0xAC,0xA4 ; "give a nickname"
    db CHAR_CONT
    db 0xB3,0xAE,0x7F                          ; "to "
    db CHAR_TERMINATOR                         ; '@'
    db 0x01                                    ; TX_RAM
    dw wNameBuffer
    db 0x00                                    ; TX_START
    db 0xE6                                    ; "?"
    db 0x57                                    ; <DONE> — terminates the stream, no wait
DoYouWantToNicknameText_end:

; ---------------------------------------------------------------------------
; DisplayNameRaterScreen — pret ref: naming_screen.asm:DisplayNameRaterScreen::.
; Rename an already-owned party mon (wWhichPokemon) via the full naming screen.
; In: EBP = GB base. Out: CF=0 (renamed, wPartyMonNicks updated) / CF=1 (cancelled).
; ---------------------------------------------------------------------------
DisplayNameRaterScreen:
    mov esi, wBuffer                     ; dest param for DisplayNamingScreen
    mov byte [ebp + wUpdateSpritesEnabled], 0
    mov byte [ebp + wNamingScreenType], NAME_MON_SCREEN
    call DisplayNamingScreen
    call GBPalWhiteOutWithDelay3
    call RestoreScreenTilesAndReloadTilePatterns
    call LoadGBPal
    mov al, [ebp + wStringBuffer]
    cmp al, CHAR_TERMINATOR
    je .playerCancelled
    mov esi, wPartyMonNicks
    mov bx, NAME_LENGTH
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                       ; ESI -> wPartyMonNicks[wWhichPokemon]
    mov edx, esi                         ; DE = target
    mov esi, wBuffer                     ; HL = source
    mov bx, NAME_LENGTH
    call CopyData
    clc                                  ; and a
    ret
.playerCancelled:
    stc
    ret

; ---------------------------------------------------------------------------
; DisplayNamingScreen — pret ref: naming_screen.asm:DisplayNamingScreen.
; The full-screen letter-grid entry UI. In: ESI (HL) = flat GB-mem dest for the
; submitted NAME_LENGTH-byte name (consumed at .submitNickname via CopyData);
; [wNamingScreenType] selects PLAYER/RIVAL/MON. EBP = GB base.
; ---------------------------------------------------------------------------
DisplayNamingScreen:
    push esi                              ; [S1] dest — popped at .submitNickname only
    mov dword [text_row_stride], GBSCR_W  ; port: this screen's own stride-20 scratch
    or byte [ebp + wStatusFlags5], (1 << BIT_NO_TEXT_DELAY)
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call UpdateSprites
    mov bl, SET_PAL_GENERIC
    call RunPaletteCommand
    call LoadHpBarAndStatusTilePatterns
    call LoadEDTile
    ; PORT: the icon is OBJ, and this screen is a window over a whited-out canvas —
    ; tell mon_icons.asm where GB (0,0) lands (docs/ui_projection.md: x = WX - 7, y = WY).
    mov eax, UI_NAMING_SCREEN_WX - 7
    mov ebx, UI_NAMING_SCREEN_WY
    call SetMonPartySpriteOrigin
    call LoadMonPartySpriteGfx            ; pret: farcall LoadMonPartySpriteGfx

    mov esi, HL(0, 4)
    mov bh, 9
    mov bl, 18
    call TextBoxBorder
    call PrintNamingText

    mov byte [ebp + wTopMenuItemY], 3
    mov byte [ebp + wTopMenuItemX], 1
    mov byte [ebp + wLastMenuItem], 1
    mov byte [ebp + wCurrentMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], 0xFF
    mov byte [ebp + wMaxMenuItem], 7
    mov byte [ebp + wStringBuffer], CHAR_TERMINATOR
    mov byte [ebp + wNamingScreenSubmitName], 0
    mov byte [ebp + wAlphabetCase], 0     ; pret: ld hl,wNamingScreenSubmitName / ld[hli],a x2
    mov byte [ebp + wAnimCounter], 0      ; ld [wAnimCounter],a — primes AnimatePartyMon_ForceSpeed1

    ; port: draw the initial frame, then show the window (options.asm InitOptionsMenu model)
    call naming_mirror
    call naming_show_window

.selectReturnPoint:
    call PrintAlphabet
    call GBPalNormal
.ABStartReturnPoint:
    mov al, [ebp + wNamingScreenSubmitName]
    test al, al
    jnz .submitNickname
    call PrintNicknameAndUnderscores
.dPadReturnPoint:
    mov dword [menu_item_step], GBSCR_W   ; single-spaced: 1 row/item (see header note)
    call PlaceMenuCursor
.inputLoop:
    ; pret saves/restores wCurrentMenuItem around the animation (which uses it as
    ; the party slot) and relies on its internal DelayFrame for this loop's frame
    ; pacing — so AnimatePartyMon_ForceSpeed1 IS the port's frame wait here too.
    ; The per-frame scratch→window mirror stays (port: hAutoBGTransferEnabled analog).
    call naming_mirror
    mov al, [ebp + wCurrentMenuItem]      ; ld a,[wCurrentMenuItem] / push af
    push eax
    call AnimatePartyMon_ForceSpeed1      ; farcall — shake the mini sprite (+ DelayFrame)
    pop eax                               ; pop af
    mov [ebp + wCurrentMenuItem], al      ; ld [wCurrentMenuItem],a
    call JoypadLowSensitivity
    ; DEVIATION: pret reads hJoyPressed directly here; the port convention
    ; (options.asm et al.) reads the debounced H_JOY5 post-JoypadLowSensitivity
    ; — behaviorally identical under the assumed default (mode 1: newly-pressed
    ; passthrough), which is what every other menu in this port already assumes.
    mov al, [ebp + H_JOY5]
    test al, al
    jz .inputLoop
    lea esi, [.namingScreenButtonFunctions]
.checkForPressedButton:
    shl al, 1                             ; sla a
    jc .foundPressedButton
    add esi, 8                            ; inc hl x4 (port: 2 dd = 8 bytes/entry)
    jmp .checkForPressedButton
.foundPressedButton:
    mov edx, [esi]                        ; DE = return point
    mov ecx, [esi + 4]                    ; HL = handler
    push edx
    jmp ecx

.pressedA_changedCase:
    pop edx
    mov edx, .selectReturnPoint
    push edx
    ; falls into .pressedSelect
.pressedSelect:
    mov al, [ebp + wAlphabetCase]
    xor al, 1
    mov [ebp + wAlphabetCase], al
    ret

.pressedStart:
    mov byte [ebp + wNamingScreenSubmitName], 1
    ret

.pressedA:
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 5                             ; "ED" row
    jne .didNotPressED
    mov al, [ebp + wTopMenuItemX]
    cmp al, 0x11                          ; "ED" column
    je .pressedStart
.didNotPressED:
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 6                             ; case switch row
    jne .didNotPressCaseSwitch
    mov al, [ebp + wTopMenuItemX]
    cmp al, 1                             ; case switch column
    je .pressedA_changedCase
.didNotPressCaseSwitch:
    movzx esi, word [ebp + wMenuCursorLocation]
    inc esi                               ; letter cell sits one column right of the cursor
    mov al, [ebp + esi]
    mov [ebp + wNamingScreenLetter], al
    call CalcStringLength                 ; ESI -> '@' in wStringBuffer (append point)
    mov al, [ebp + wNamingScreenLetter]
    cmp al, CHAR_DAKUTEN
    je .dakutensAndHandakutens
    cmp al, CHAR_HANDAKUTEN
    je .dakutensAndHandakutens
    mov al, [ebp + wNamingScreenType]
    cmp al, NAME_MON_SCREEN
    jae .checkMonNameLength
    mov al, [ebp + wNamingScreenNameLength]
    cmp al, PLAYER_NAME_LENGTH - 1
    jmp .checkNameLength
.checkMonNameLength:
    mov al, [ebp + wNamingScreenNameLength]
    cmp al, NAME_LENGTH - 1
.checkNameLength:
    jb .addLetter
    ret
.dakutensAndHandakutens:
    ; DEVIATION: JP-only (dakuten/hiragana pages not shipped in EN port — S1
    ; precedent). pret calls DakutensAndHandakutens (data/text/dakutens.asm) to
    ; substitute the voiced-kana variant; the EN alphabet grid (assets/alphabets.inc)
    ; never emits CHAR_DAKUTEN/CHAR_HANDAKUTEN, so this branch is unreachable —
    ; the two cmp/je checks above are kept for structural fidelity, falling
    ; straight through to .addLetter (matching the pret non-substitution `ret nc`
    ; fallthrough shape) rather than porting the dead lookup.
.addLetter:
    mov al, [ebp + wNamingScreenLetter]
    mov [ebp + esi], al
    inc esi
    mov byte [ebp + esi], CHAR_TERMINATOR
    mov al, SFX_PRESS_AB
    call PlaySound
    ret

.pressedB:
    mov al, [ebp + wNamingScreenNameLength]
    test al, al
    jz .ret_pressedB
    call CalcStringLength                 ; ESI -> '@'
    dec esi
    mov byte [ebp + esi], CHAR_TERMINATOR
.ret_pressedB:
    ret

.pressedRight:
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 6
    je .ret_dpad                          ; can't scroll right on bottom row
    mov al, [ebp + wTopMenuItemX]
    cmp al, 0x11                          ; max
    je .wrapToFirstColumn
    add al, 2
    jmp .doneH
.wrapToFirstColumn:
    mov al, 1
    jmp .doneH
.pressedLeft:
    mov al, [ebp + wCurrentMenuItem]
    cmp al, 6
    je .ret_dpad                          ; can't scroll left on bottom row
    mov al, [ebp + wTopMenuItemX]
    dec al
    jz .wrapToLastColumn
    dec al
    jmp .doneH
.wrapToLastColumn:
    mov al, 0x11                          ; max
    jmp .doneH
.pressedUp:
    mov al, [ebp + wCurrentMenuItem]
    dec al
    mov [ebp + wCurrentMenuItem], al
    test al, al
    jnz .ret_dpad
    mov byte [ebp + wCurrentMenuItem], 6  ; wrap to bottom row
    mov al, 1                             ; force left column
    jmp .doneH
.pressedDown:
    mov al, [ebp + wCurrentMenuItem]
    inc al
    mov [ebp + wCurrentMenuItem], al
    cmp al, 7
    jne .wrapToTopRow
    mov byte [ebp + wCurrentMenuItem], 1
    mov al, 1
    jmp .doneH
.wrapToTopRow:
    cmp al, 6
    jne .ret_dpad
    mov al, 1
.doneH:
    mov [ebp + wTopMenuItemX], al
    jmp EraseMenuCursor                   ; tail jump (pret: jp EraseMenuCursor)
.ret_dpad:
    ret

.submitNickname:
    pop edx                               ; [S1] dest, restored
    mov esi, wStringBuffer
    mov bx, NAME_LENGTH
    call CopyData
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call ClearSprites
    call RunDefaultPaletteCommand
    call GBPalNormal
    mov byte [ebp + wAnimCounter], 0      ; xor a / ld [wAnimCounter],a
    and byte [ebp + wStatusFlags5], ~(1 << BIT_NO_TEXT_DELAY) & 0xFF
    cmp byte [ebp + wIsInBattle], 0
    jz LoadTextBoxTilePatterns            ; tail jump (pret: jp z, LoadTextBoxTilePatterns)
    jmp LoadHudTilePatterns               ; tail jump (pret: jpfar LoadHudTilePatterns)

; pret ref: naming_screen.asm:.namingScreenButtonFunctions (8 entries: Down, Up,
; Left, Right, Start, Select, B, A — matches PAD_DOWN..PAD_A bit7..bit0 scan
; order). Each port entry = (dd returnPoint, dd handler), 8 bytes/slot. Kept as
; a LOCAL (dot) label, same as pret, so it — and the entries below — stay within
; DisplayNamingScreen's local-label scope (a plain non-dot label here would
; reset NASM's local-label context and break every `.foo` reference below it).
.namingScreenButtonFunctions:
    dd .dPadReturnPoint,   .pressedDown
    dd .dPadReturnPoint,   .pressedUp
    dd .dPadReturnPoint,   .pressedLeft
    dd .dPadReturnPoint,   .pressedRight
    dd .ABStartReturnPoint,.pressedStart
    dd .selectReturnPoint, .pressedSelect
    dd .ABStartReturnPoint,.pressedB
    dd .ABStartReturnPoint,.pressedA

; ---------------------------------------------------------------------------
; RunDefaultPaletteCommand — pret ref: home/palettes.asm:RunDefaultPaletteCommand
; (a 1-line label that sets B=SET_PAL_DEFAULT and falls into RunPaletteCommand).
; Promoted to a global (2026-07-12): ExitTownMap needs it too, which is the reuse
; the old note here flagged. It still lives in this file rather than beside
; RunPaletteCommand (engine/battle/faint_switch.asm) — hoisting it there is a
; separate move. NOTE the register: pret sets `b` (= BH), this sets BL. Harmless
; today because RunPaletteCommand is a ret-stub (Phase 5 palette engine), but it
; must be fixed to BH when that engine lands or every caller picks the wrong palette.
; ---------------------------------------------------------------------------
global RunDefaultPaletteCommand
RunDefaultPaletteCommand:
    mov bl, SET_PAL_DEFAULT
    jmp RunPaletteCommand

; ---------------------------------------------------------------------------
; naming_show_window — port plumbing: full-screen window over the whited-out
; background, sourced from GB_TILEMAP1 rows 0-17 at the UI_NAMING_SCREEN anchor.
; ; PROJ menus: window = UI_NAMING_SCREEN_(WX,WY,CLIP,MAXY) (GB 20x18 full screen).
; ---------------------------------------------------------------------------
naming_show_window:
    mov dword [g_bg_whiteout], 1
    ; The window IS this screen, and the mon icon is OBJ on top of it — restore the
    ; GB's OBJ-over-window order (see frame.asm). ClearSprites drops it on exit.
    mov dword [g_obj_over_window], 1
    mov eax, UI_NAMING_SCREEN_WX
    mov ebx, UI_NAMING_SCREEN_WY
    mov ecx, UI_NAMING_SCREEN_CLIP
    mov edx, UI_NAMING_SCREEN_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call set_single_window
    ret

; ---------------------------------------------------------------------------
; naming_mirror — blit the stride-20 scratch rows 0-17 -> GB_TILEMAP1 rows 0-17
; (the window's source; port stand-in for hAutoBGTransferEnabled). Preserves
; all registers.
; ---------------------------------------------------------------------------
naming_mirror:
    pushad
    xor ebx, ebx
.row:
    imul esi, ebx, GBSCR_W
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                            ; x32 tilemap stride
    lea edi, [ebp + edi + GB_TILEMAP1]
    mov ecx, GBSCR_W
    rep movsb
    inc ebx
    cmp ebx, UI_NAMING_SCREEN_GBH          ; 18 rows
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; LoadEDTile — pret ref: naming_screen.asm:LoadEDTile.
; DEVIATION: pret copies ED_Tile to VRAM during HBlank (rSTAT %10 poll) because
; the bank for ED_Tile was defined incorrectly as bank0 and GameFreak worked
; around it by racing the PPU instead of fixing the bank (see pret's own comment
; at LoadEDTile). The port has no bank/timing constraint, so this is a plain
; copy: alphabet_ed_tile (16 bytes, already 1bpp->2bpp expanded by gen_alphabets.py)
; to the vChars1 slot for char ALPHABET_ED_CHAR ($F0) in $8800-signed addressing.
; ---------------------------------------------------------------------------
LoadEDTile:
    mov byte [g_tilecache_dirty], 1
    push esi
    push edi
    push ecx
    mov esi, alphabet_ed_tile
    lea edi, [ebp + GB_VFONT + (ALPHABET_ED_CHAR - 0x80) * TILE_SIZE]
    mov ecx, ALPHABET_ED_TILE_SIZE
    rep movsb
    pop ecx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------------
; PrintAlphabet — pret ref: naming_screen.asm:PrintAlphabet.
; Draw the 5x9 letter grid (upper/lower selected by wAlphabetCase) at (2,5),
; then PlaceString the trailing "UPPER CASE@"/"lower case@" toggle label at
; wherever the grid loop's cursor lands (row 15, col 2) — the SAME sequential
; blob read continuing past the grid's 45 bytes (pret relies on this; ported
; verbatim, not re-derived from a separate label).
; ---------------------------------------------------------------------------
PrintAlphabet:
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    mov edx, LowerCaseAlphabet
    cmp byte [ebp + wAlphabetCase], 0
    jne .lowercase
    mov edx, UpperCaseAlphabet
.lowercase:
    mov esi, HL(2, 5)
    mov ebx, 5                            ; row count (B)
.outerLoop:
    push ebx
    mov ecx, 9                            ; col count (C)
.innerLoop:
    mov al, [edx]                         ; flat .data read (no EBP bias)
    mov [ebp + esi], al
    inc esi
    inc esi
    inc edx
    dec ecx
    jnz .innerLoop
    add esi, GBSCR_W + 2
    pop ebx
    dec ebx
    jnz .outerLoop
    mov eax, edx                          ; PlaceString: EAX = flat src (continuing blob)
    call PlaceString
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
    jmp Delay3

; ---------------------------------------------------------------------------
; PrintNicknameAndUnderscores — pret ref: naming_screen.asm:PrintNicknameAndUnderscores.
; Redraw the typed name + trailing underscores at (10,2)/(10,3); when the name
; is full, force the cursor onto the ED cell and raise the last underscore.
; ---------------------------------------------------------------------------
PrintNicknameAndUnderscores:
    call CalcStringLength                 ; ECX = length
    mov [ebp + wNamingScreenNameLength], cl
    mov esi, HL(10, 2)
    mov bh, 1
    mov bl, 10
    call ClearScreenArea
    mov esi, HL(10, 2)
    lea eax, [ebp + wStringBuffer]
    call PlaceString
    mov esi, HL(10, 3)
    mov al, [ebp + wNamingScreenType]
    cmp al, NAME_MON_SCREEN
    jae .pokemon
    mov ebx, PLAYER_NAME_LENGTH - 1
    jmp .gotUnderscoreCount
.pokemon:
    mov ebx, NAME_LENGTH - 1
.gotUnderscoreCount:
    mov al, TILE_UNDERSCORE
.placeUnderscoreLoop:
    mov [ebp + esi], al
    inc esi
    dec ebx
    jnz .placeUnderscoreLoop
    mov al, [ebp + wNamingScreenType]
    cmp al, NAME_MON_SCREEN
    mov al, [ebp + wNamingScreenNameLength]
    jae .pokemon2
    cmp al, PLAYER_NAME_LENGTH - 1
    jmp .checkEmptySpaces
.pokemon2:
    cmp al, NAME_LENGTH - 1
.checkEmptySpaces:
    jne .placeRaisedUnderscore
    ; full: force the cursor onto the ED cell, keep the last underscore raised
    call EraseMenuCursor
    mov byte [ebp + wTopMenuItemX], 0x11  ; "ED" x coord
    mov byte [ebp + wCurrentMenuItem], 5  ; "ED" y coord
    mov al, [ebp + wNamingScreenType]
    cmp al, NAME_MON_SCREEN
    mov al, NAME_LENGTH - 2
    jae .placeRaisedUnderscore
    mov al, PLAYER_NAME_LENGTH - 2
.placeRaisedUnderscore:
    movzx ecx, al
    mov esi, HL(10, 3)
    add esi, ecx
    mov byte [ebp + esi], TILE_UNDERSCORE_RAISED
    ret

; ---------------------------------------------------------------------------
; DakutensAndHandakutens — DEVIATION: JP-only (see .dakutensAndHandakutens
; above); not ported. data/text/dakutens.asm (Dakutens/Handakutens tables) is
; not part of the EN asset set.
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; CalcStringLength — pret ref: naming_screen.asm:CalcStringLength (file-local
; in pret too — no `::`). Length of the '@'-terminated wStringBuffer.
; Out: ECX = length. ESI = EBP-relative pointer to the '@' terminator.
; ---------------------------------------------------------------------------
CalcStringLength:
    mov esi, wStringBuffer
    xor ecx, ecx
.loop:
    mov al, [ebp + esi]
    cmp al, CHAR_TERMINATOR
    je .done
    inc esi
    inc ecx
    jmp .loop
.done:
    ret

; ---------------------------------------------------------------------------
; PrintNamingText — pret ref: naming_screen.asm:PrintNamingText.
; PLAYER/RIVAL: "YOUR @NAME?@" / "RIVAL's @NAME?@". MON: "<species name>@ の"
; (the の is a leftover Japanese blank tile, $C9, harmless in the EN font) +
; "NICKNAME?@".
; ---------------------------------------------------------------------------
PrintNamingText:
    mov esi, HL(0, 1)
    mov al, [ebp + wNamingScreenType]
    mov eax, YourTextString
    test al, al
    jz .notNickname
    mov eax, RivalsTextString
    dec al
    jz .notNickname

    ; NAME_MON_SCREEN: species default name + "の" leftover + "NICKNAME?"
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wMonPartySpriteSpecies], al  ; ld [wMonPartySpriteSpecies],a
    push eax                                ; push af
    call WriteMonPartySpriteOAMBySpecies    ; farcall — the named mon's icon
    pop eax                                 ; pop af
    mov [ebp + wNamedObjectIndex], al
    call GetMonName
    mov esi, HL(4, 1)
    lea eax, [ebp + wNameBuffer]
    call PlaceString
    inc ebx                               ; pret: ld hl,1 / add hl,bc
    mov byte [ebp + ebx], 0xC9            ; 'の' leftover — blank tile in EN font
    mov esi, HL(1, 3)
    mov eax, NicknameTextString
    jmp .placeString
.notNickname:
    call PlaceString
    mov esi, ebx                          ; continue at the cursor PlaceString left
    mov eax, NameTextString
.placeString:
    jmp PlaceString

section .data
YourTextString:
    db 0x98,0x8E,0x94,0x91,0x7F,0x50                                   ; "YOUR @"
RivalsTextString:
    db 0x91,0x88,0x95,0x80,0x8B,0xBD,0x7F,0x50                        ; "RIVAL's @"
NameTextString:
    db 0x8D,0x80,0x8C,0x84,0xE6,0x50                                  ; "NAME?@"
NicknameTextString:
    db 0x8D,0x88,0x82,0x8A,0x8D,0x80,0x8C,0x84,0xE6,0x50               ; "NICKNAME?@"
section .text

; ===========================================================================
; RunNamingScreenTest — menus S7 package C FRAME.BIN gate (static open state).
; Seeds wNamingScreenType=PLAYER, loads the font, draws the naming screen's
; letter grid (PrintAlphabet + PrintNicknameAndUnderscores + the window) WITHOUT
; entering the blocking input loop, mirrors, renders, dumps FRAME.BIN, exits.
; Full grid navigation is the S10 interactive sweep.
; In: EBP = GB base.  make DEBUG_NAMINGSCREEN=1  (root wires the flag + call site).
; ===========================================================================
%ifdef DEBUG_NAMINGSCREEN
global RunNamingScreenTest
extern LoadFontTilePatterns            ; gfx/load_font.asm
extern DumpBackbuffer                  ; debug/debug_dump.asm — writes FRAME.BIN + exits

section .text
RunNamingScreenTest:
    mov dword [text_row_stride], GBSCR_W

    ; font glyphs into vFont/vChars2
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadEDTile

    ; no stray OAM over the full-screen menu
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0

    ; seed a representative PLAYER-naming state (pret DisplayNamingScreen init)
    mov byte [ebp + wNamingScreenType], NAME_PLAYER_SCREEN
    mov byte [ebp + wTopMenuItemY], 3
    mov byte [ebp + wTopMenuItemX], 1
    mov byte [ebp + wLastMenuItem], 1
    mov byte [ebp + wCurrentMenuItem], 1
    mov byte [ebp + wMenuWatchedKeys], 0xFF
    mov byte [ebp + wMaxMenuItem], 7
    mov byte [ebp + wStringBuffer], CHAR_TERMINATOR
    mov byte [ebp + wNamingScreenSubmitName], 0
    mov byte [ebp + wAlphabetCase], 0

    mov esi, HL(0, 4)
    mov bh, 9
    mov bl, 18
    call TextBoxBorder
    call PrintNamingText

    call PrintAlphabet
    call PrintNicknameAndUnderscores
    mov dword [menu_item_step], GBSCR_W
    call PlaceMenuCursor

    call naming_mirror
    call naming_show_window

    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                    ; writes FRAME.BIN + exits
.hang:
    jmp .hang
%endif
