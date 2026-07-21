; oak_speech2.asm — the Oak-speech naming flow (menu-intro A4.4).
;
; Source: engine/movie/oak_speech/oak_speech2.asm.
;
; This file is being ported incrementally. It currently holds GetDefaultName (the
; default-name lookup). ChoosePlayerName / ChooseRivalName, the OakSpeechSlidePic*
; slides, and DisplayIntroNameTextBox land in the following A4.4 steps, each with
; its own pixel/golden verification (the slides and the name menu draw into the
; projected UI_OAK_SPEECH surface, so they need runtime evidence, not just an
; assemble).
;
; PROJECTION: like every boot cinematic, the naming flow keeps the Game Boy's
; 160x144 composition centred on the canvas (movie_projection, UI_OAK_SPEECH).
; pret's hlcoord coordinates are offset by UI_OAK_SPEECH_(COL,ROW) = (10,3) into
; the 40-wide canvas, and the slide's row-stride math uses the port's 40-wide
; SCREEN_TILES_W, not pret's 20. (Applied as each routine lands.)
;
; The default-name DATA (DefaultNames{Player,Rival}{,List}) is Tier-1 generated
; data — see tools/generators/gen_default_names.py / assets/default_names.inc.
;
; Build: nasm -f coff -I include/ -I . -o oak_speech2.o oak_speech2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_OAK_SPEECH_*

%include "assets/default_names.inc"   ; DefaultNames{Player,Rival}{,List}, IntroNameString (.data)

; --- naming-flow infra (already in the port) ---
extern TextBoxBorder                 ; home/text.asm — box at ESI, BL wide x BH tall
extern PlaceString                   ; home/text.asm — EAX flat src, ESI GB dest
extern UpdateSprites                 ; engine/overworld/movement.asm
extern HandleMenuInput               ; home/window.asm — menu loop; returns choice in wCurrentMenuItem
extern text_row_stride               ; home/text.asm — W_TILEMAP row stride for the box/string helpers
extern menu_item_step                ; home/window.asm — menu cursor vertical spacing
extern ClearScreenArea               ; home/copy2.asm — clear BL x BH tiles of W_TILEMAP at ESI
extern CopyData                      ; home/copy_data.asm — ESI/EDX EBP-relative, BX count
extern Delay3                        ; video/frame.asm — wait 3 frames
extern DelayFrames                   ; video/frame.asm — wait BL frames
extern DisplayNamingScreen           ; engine/menus/naming_screen.asm — ESI = name dest (pret HL)
extern IntroDisplayPicCenteredOrUpperRight  ; oak_speech.asm — ESI flat pic, ECX len, BL centre/UR
extern MovieBeginSurface             ; movie_projection.asm — re-establish the UI_OAK_SPEECH surface
extern PrintText                     ; home/window.asm — ESI = text stream
extern text_msgbox                   ; home/text.asm — active projection record
extern msgbox_oak_speech             ; oak_speech.asm — the intro no-window text descriptor
extern RedPicFront                   ; data/trainer_pics.asm — player intro pic (= PlayerPicFront)
extern Rival1Pic                     ; data/trainer_pics.asm — rival intro pic
extern YourNameIsText                ; assets/oak_speech_strings.inc (linked via oak_speech.o)
extern HisNameIsText                 ; assets/oak_speech_strings.inc

RED_PIC_LEN    equ 255               ; gfx/player/red.pic byte length
RIVAL1_PIC_LEN equ 241               ; gfx/trainers/rival1.pic byte length

; The slide band spans `SLIDE_ROWS` tile-rows; in a 40-wide canvas its linear size
; is SLIDE_ROWS*SCREEN_TILES_W + 5 (pret's 6*SCREEN_WIDTH+5, restrided). Fits a byte.
SLIDE_ROWS       equ 6
SLIDE_REGION     equ (SLIDE_ROWS * SCREEN_TILES_W + 5)
SLIDE_STEPS      equ 6                ; pret hSlideAmount — columns to slide

; Projected slide-band origins (pret hlcoord + UI_OAK_SPEECH). Right slide starts at
; hlcoord(5,4); left at hlcoord(12,4); the name-box clear at hlcoord(0,0).
SLIDE_RIGHT_ORIGIN equ (W_TILEMAP + (4 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (5 + UI_OAK_SPEECH_COL))
SLIDE_LEFT_ORIGIN  equ (W_TILEMAP + (4 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (12 + UI_OAK_SPEECH_COL))
SLIDE_CLEAR_ORIGIN equ (W_TILEMAP + (0 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (0 + UI_OAK_SPEECH_COL))

section .bss
slide_dir:    resb 1                  ; 0 = right, 0xFF = left (pret hSlideDirection)
slide_steps:  resb 1                  ; columns remaining (pret hSlideAmount)
slide_region: resb 1                  ; linear tiles per column-shift (pret hSlidingRegionSize)

; Projected tilemap corners for the name menu (pret hlcoord + UI_OAK_SPEECH origin,
; 40-wide canvas). Box hlcoord(0,0); "NAME" title hlcoord(3,0); list hlcoord(2,2).
INTRO_NAME_BOX   equ (W_TILEMAP + (0 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (0 + UI_OAK_SPEECH_COL))
INTRO_NAME_TITLE equ (W_TILEMAP + (0 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (3 + UI_OAK_SPEECH_COL))
INTRO_NAME_LIST  equ (W_TILEMAP + (2 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (2 + UI_OAK_SPEECH_COL))

section .text

; ---------------------------------------------------------------------------
; GetDefaultName — copy the AL-th name from a default-name list into wNameBuffer.
;
; Source: engine/movie/oak_speech/oak_speech2.asm:GetDefaultName. pret walks the
; '@'-terminated list counting entries until the running index matches, then
; `jp CopyData` copies NAME_BUFFER_LENGTH bytes from that name to wNameBuffer.
;
; DEVIATION{class=data-model; pret=engine/movie/oak_speech/oak_speech2.asm:GetDefaultName; behavior=the tail jp CopyData is realised as an inline flat->GB rep movsb instead of a call; evidence=the name list is flat program-image data (assets/default_names.inc) not GB WRAM, and the port's CopyData adds EBP to BOTH source and dest (copy_data.asm), so a flat source pointer cannot go through it -- PrepareOakSpeech takes the same flat rep movsb path for the same reason; lifetime=permanent flat-memory model}
;
; In:  AL = name index (0-based), ESI = FLAT ptr to the '@'-terminated name list.
; Out: the chosen name (NAME_BUFFER_LENGTH bytes) copied to [EBP + wNameBuffer].
;      Clobbers EAX/EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
global GetDefaultName
GetDefaultName:
    mov bh, al                        ; BH = target index   (pret ld b, a)
    xor bl, bl                        ; BL = running index  (pret ld c, 0)
.loop:
    mov edi, esi                      ; EDI = start of current name (pret ld d,h / ld e,l)
.innerLoop:
    mov al, [esi]                     ; ld a, [hli]  — flat list read
    inc esi
    cmp al, '@'                       ; cp '@'
    jne .innerLoop
    cmp bh, bl                        ; ld a,b / cp c
    je .foundName
    inc bl                            ; inc c
    jmp .loop
.foundName:
    ; ESI (found name start) is in EDI; copy NAME_BUFFER_LENGTH bytes flat -> GB.
    mov esi, edi                      ; pret ld h,d / ld l,e
    lea edi, [ebp + wNameBuffer]      ; ld de, wNameBuffer (GB dest)
    mov ecx, NAME_BUFFER_LENGTH       ; ld bc, NAME_BUFFER_LENGTH
    rep movsb
    ret

; ---------------------------------------------------------------------------
; DisplayIntroNameTextBox — draw the "NAME" box + the default-name menu list and
; run the selection menu. Source: oak_speech2.asm:DisplayIntroNameTextBox.
;
; pret draws a c=9 x b=10 box at hlcoord(0,0), embeds "NAME" in the top border at
; (3,0), places the DE menu string ("NEW NAME<NEXT>n1<NEXT>...") at (2,2), then
; runs HandleMenuInput. Under the cinematic all coords are projected by
; UI_OAK_SPEECH; the box/string helpers walk W_TILEMAP at text_row_stride and the
; menu cursor is placed scratch-relative (PlaceMenuCursor), so text_row_stride and
; the projected wTopMenuItem{X,Y} are what put both on the surface. The per-frame
; g_surface_redraw_cb (MovieBeginSurface) mirrors the canvas so the menu is visible.
;
; DEVIATION{class=projection; pret=engine/movie/oak_speech/oak_speech2.asm:DisplayIntroNameTextBox; behavior=the box, title, list, and menu cursor are placed at UI_OAK_SPEECH-projected coordinates with text_row_stride=SCREEN_TILES_W instead of pret's fixed 20-wide hlcoord literals; evidence=the naming menu is a boot cinematic centred on the 320x200 canvas (movie_projection UI_OAK_SPEECH); lifetime=permanent widescreen projection}
;
; In:  EDX = FLAT ptr to the DefaultNames* menu string (pret de). EBP = GB base.
; Out: choice in wCurrentMenuItem (0 = "NEW NAME"/custom, 1..3 = default index).
; ---------------------------------------------------------------------------
global DisplayIntroNameTextBox
DisplayIntroNameTextBox:
    push edx                              ; pret push de (the menu string)
    mov dword [text_row_stride], SCREEN_TILES_W  ; project into the 40-wide canvas
    ; box: c=9 wide x b=10 tall at projected (0,0)
    mov esi, INTRO_NAME_BOX
    mov bh, 10                            ; height (pret b)
    mov bl, 9                             ; width  (pret c)
    call TextBoxBorder
    ; "NAME" embedded in the top border at projected (3,0)
    mov eax, IntroNameString              ; flat src
    mov esi, INTRO_NAME_TITLE
    call PlaceString
    pop edx                               ; pret pop de
    mov eax, edx                          ; PlaceString flat src = the menu string
    mov esi, INTRO_NAME_LIST              ; projected (2,2)
    call PlaceString
    call UpdateSprites
    ; pret: xor a / [wCurrentMenuItem]=[wLastMenuItem]=0 / inc a / [wTopMenuItemX]=1
    ; / [wMenuWatchedKeys]=1(PAD_A) / inc a / [wTopMenuItemY]=2 / inc a / [wMaxMenuItem]=3
    ; wTopMenuItem{X,Y} are projected so PlaceMenuCursor lands on the surface.
    mov byte [ebp + wCurrentMenuItem], 0
    mov byte [ebp + wLastMenuItem], 0
    mov byte [ebp + wTopMenuItemX], 1 + UI_OAK_SPEECH_COL
    mov byte [ebp + wMenuWatchedKeys], PAD_A
    mov byte [ebp + wTopMenuItemY], 2 + UI_OAK_SPEECH_ROW
    mov byte [ebp + wMaxMenuItem], 3
    ; The menu list is <NEXT>-DOUBLE-spaced (PlaceString default, no
    ; BIT_SINGLE_SPACED_LINES), so the cursor steps two rows per item — pret
    ; PlaceMenuCursor's fixed `ld bc, 2 * SCREEN_WIDTH`. The port caller publishes
    ; that as menu_item_step = 2 * text_row_stride.
    mov eax, [text_row_stride]
    add eax, eax
    mov [menu_item_step], eax
    jmp HandleMenuInput

; ---------------------------------------------------------------------------
; ChoosePlayerName / ChooseRivalName — the intro name-selection flow. Source:
; engine/movie/oak_speech/oak_speech2.asm. Slide the pic aside, run the default-name
; menu; a default choice slides the chosen name/pic back in, "NEW NAME" opens the
; naming screen (retrying on an empty '@' name). Then re-show the pic and print
; "YOUR/HIS NAME IS ...". On the projected surface, the naming screen takes the whole
; screen, so the custom path re-establishes the UI_OAK_SPEECH surface on return.
;
; DEVIATION{class=projection; pret=engine/movie/oak_speech/oak_speech2.asm:ChoosePlayerName; behavior=the custom-name path re-establishes the cinematic surface with MovieBeginSurface in place of pret's ClearScreen, and the shared final PrintText is given the msgbox_oak_speech projection record; evidence=DisplayNamingScreen takes over the window list and whiteout on the projected surface, and the port's PrintText reads its text box from a projection record instead of fixed hlcoord; lifetime=permanent widescreen projection}
;
; In: EBP = GB base.
; ---------------------------------------------------------------------------
global ChoosePlayerName
ChoosePlayerName:
    call OakSpeechSlidePicRight            ; slide the current pic right, reveal the box
    mov edx, DefaultNamesPlayer            ; ld de, DefaultNamesPlayer
    call DisplayIntroNameTextBox           ; -> wCurrentMenuItem
    movzx eax, byte [ebp + wCurrentMenuItem]
    test al, al
    jz .customNamePlayer                   ; item 0 = "NEW NAME" -> custom
    mov esi, DefaultNamesPlayerList        ; ld hl, DefaultNamesPlayerList
    call GetDefaultName                    ; AL = menu item = list index
    mov edx, W_PLAYER_NAME                  ; ld de, wPlayerName
    call OakSpeechSlidePicLeft             ; slide the chosen name/pic back in
    jmp .donePlayer
.customNamePlayer:
    mov esi, W_PLAYER_NAME                  ; ld hl, wPlayerName (naming dest, pret HL)
    mov byte [ebp + wNamingScreenType], NAME_PLAYER_SCREEN
    call DisplayNamingScreen
    cmp byte [ebp + wStringBuffer], '@'     ; empty name -> retry
    je .customNamePlayer
    call MovieBeginSurface                  ; pret ClearScreen: re-establish the surface
    call Delay3
    mov esi, RedPicFront
    mov ecx, RED_PIC_LEN
    xor bl, bl                              ; centred
    call IntroDisplayPicCenteredOrUpperRight
.donePlayer:
    mov dword [text_msgbox], msgbox_oak_speech
    mov esi, YourNameIsText
    jmp PrintText                           ; jp PrintText

global ChooseRivalName
ChooseRivalName:
    call OakSpeechSlidePicRight
    mov edx, DefaultNamesRival             ; ld de, DefaultNamesRival
    call DisplayIntroNameTextBox
    movzx eax, byte [ebp + wCurrentMenuItem]
    test al, al
    jz .customNameRival
    mov esi, DefaultNamesRivalList         ; ld hl, DefaultNamesRivalList
    call GetDefaultName
    mov edx, W_RIVAL_NAME                    ; ld de, wRivalName
    call OakSpeechSlidePicLeft
    jmp .doneRival
.customNameRival:
    mov esi, W_RIVAL_NAME                    ; ld hl, wRivalName
    mov byte [ebp + wNamingScreenType], NAME_RIVAL_SCREEN
    call DisplayNamingScreen
    cmp byte [ebp + wStringBuffer], '@'
    je .customNameRival
    call MovieBeginSurface
    call Delay3
    mov esi, Rival1Pic
    mov ecx, RIVAL1_PIC_LEN
    xor bl, bl                              ; centred
    call IntroDisplayPicCenteredOrUpperRight
.doneRival:
    mov dword [text_msgbox], msgbox_oak_speech
    mov esi, HisNameIsText
    jmp PrintText

; ---------------------------------------------------------------------------
; OakSpeechSlidePicLeft / Right / Common — slide the on-surface picture one tile
; column at a time. Source: engine/movie/oak_speech/oak_speech2.asm.
;
; pret shifts a `SLIDE_ROWS*SCREEN_WIDTH + 5`-tile linear band of wTileMap one
; column per Delay3, SLIDE_STEPS times, walking backward (right) or forward (left).
; Under projection the band starts at a UI_OAK_SPEECH-projected origin and its
; linear span uses the port's 40-wide stride (SLIDE_ROWS*SCREEN_TILES_W + 5), so it
; shifts the same 6-row region. The per-frame g_surface_redraw_cb commits each
; shifted column to the surface; pret's hAutoBGTransferEnabled/Portion toggles are
; dropped (the port retired the VBlank auto-BG-transfer they gate).
;
; DEVIATION{class=projection; pret=engine/movie/oak_speech/oak_speech2.asm:OakSpeechSlidePicCommon; behavior=the slide band starts at a UI_OAK_SPEECH-projected origin and its linear span is restrided to SLIDE_ROWS*SCREEN_TILES_W+5 for the 40-wide canvas, the hAutoBGTransferEnabled/Portion toggles are dropped, and pret's hSlideDirection/hSlideAmount/hSlidingRegionSize HRAM scratch becomes file-local .bss (slide_dir/steps/region); evidence=the picture is a boot cinematic centred on the 320x200 canvas, the port has no VBlank auto-BG-transfer (do_bg_transfer retired -- g_surface_redraw_cb mirrors W_TILEMAP every frame instead), and those pret HRAM slide temps are not in the port memmap; lifetime=permanent widescreen projection}
;
; Left In: EDX = GB dest for the chosen name (pret de). EBP = GB base.
; ---------------------------------------------------------------------------
global OakSpeechSlidePicLeft
global OakSpeechSlidePicRight
global OakSpeechSlidePicCommon
OakSpeechSlidePicLeft:
    push edx                              ; pret push de (the name dest)
    mov dword [text_row_stride], SCREEN_TILES_W
    mov esi, SLIDE_CLEAR_ORIGIN           ; hlcoord 0,0 -> clear the name list box
    mov bh, 12                            ; height (pret b)
    mov bl, 11                            ; width  (pret c)
    call ClearScreenArea
    mov bl, 10
    call DelayFrames                      ; ld c,10 / DelayFrames
    pop edx                               ; pret pop de
    mov esi, wNameBuffer                  ; ld hl, wNameBuffer (GB src)
    mov bx, NAME_LENGTH                   ; ld bc, NAME_LENGTH
    call CopyData                         ; copy name -> [EDX]
    call Delay3
    mov esi, SLIDE_LEFT_ORIGIN            ; hlcoord 12,4 (projected)
    mov al, 0xFF                          ; direction = left
    jmp OakSpeechSlidePicCommon
OakSpeechSlidePicRight:
    mov esi, SLIDE_RIGHT_ORIGIN           ; hlcoord 5,4 (projected)
    xor al, al                            ; direction = right
OakSpeechSlidePicCommon:
    ; In: ESI = start tilemap offset (hl), AL = 0 right / $ff left.
    mov [slide_dir], al
    mov byte [slide_steps], SLIDE_STEPS
    mov byte [slide_region], SLIDE_REGION
    test al, al
    jnz .haveStart                        ; left: ESI already at the region start
    add esi, SLIDE_REGION                 ; right: point to the region end (pret add hl,de)
.haveStart:
    mov edi, esi                          ; EDI = de = saved start-of-pass (pret ld d,h/ld e,l)
.colLoop:
    ; --- shift the whole band one column ---
    movzx ecx, byte [slide_region]
    cmp byte [slide_dir], 0
    jne .shiftLeft
.shiftRight:
    mov al, [ebp + esi]                   ; ld a, [hli]
    inc esi
    mov [ebp + esi], al                   ; ld [hld], a
    dec esi
    dec esi                               ; dec hl
    dec ecx
    jnz .shiftRight
    jmp .colDone
.shiftLeft:
    mov al, [ebp + esi]                   ; ld a, [hld]
    dec esi
    mov [ebp + esi], al                   ; ld [hli], a
    inc esi
    inc esi                               ; inc hl
    dec ecx
    jnz .shiftLeft
.colDone:
    cmp byte [slide_dir], 0
    je .afterZero                         ; right: nothing to blank
    ; left: zero the last tile in the pic (pret dec hl / xor a / ld [hl], a)
    dec esi
    mov byte [ebp + esi], 0
.afterZero:
    call Delay3                           ; let the shifted column show (per-frame mirror)
    ; reset the walk to the saved start, advance it one tile, loop for SLIDE_STEPS
    mov esi, edi                          ; ld h,d / ld l,e
    cmp byte [slide_dir], 0
    jne .startBack
    inc esi                               ; right: start++
    jmp .startSet
.startBack:
    dec esi                               ; left: start--
.startSet:
    mov edi, esi                          ; EDI = new saved start
    dec byte [slide_steps]
    jnz .colLoop
    ret

%ifdef DEBUG_OAKSLIDE
; ---------------------------------------------------------------------------
; RunOakSlideTest — A4.4 pixel harness. Display Oak centred, then slide the pic
; right (OakSpeechSlidePicRight). AUTOKEY_QUIET photographs the parked frame at
; AUTOKEY_DUMP_FRAME: a low frame captures the pic centred (pre-slide), a high one
; captures it slid right. Proves the projected slide shifts the pic on the surface.
; In: EBP = GB base. Never returns.
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns          ; home/load_font.asm
extern LoadTextBoxTilePatterns       ; home/load_font.asm
extern MovieBeginSurface             ; movie_projection.asm
extern MovieMirrorSurface            ; movie_projection.asm
extern IntroDisplayPicCenteredOrUpperRight  ; oak_speech.asm
extern FadeInIntroPic                ; oak_speech.asm
extern ProfOakPic                    ; data/trainer_pics.asm
extern DelayFrame                    ; video/frame.asm
global RunOakSlideTest
OAKSLIDE_PIC_LEN equ 286
RunOakSlideTest:
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call MovieBeginSurface
    mov byte [ebp + IO_BGP], 0
    mov esi, ProfOakPic
    mov ecx, OAKSLIDE_PIC_LEN
    xor bl, bl                            ; centred
    call IntroDisplayPicCenteredOrUpperRight
    call MovieMirrorSurface
    call FadeInIntroPic                   ; pic centred + faded (pre-slide capture window)
    call OakSpeechSlidePicRight           ; slide it right (each column Delay3-paced)
.hang:
    call DelayFrame                       ; keep the per-frame mirror running for the dump
    jmp .hang
%endif

%ifdef DEBUG_NAMEMENU
; ---------------------------------------------------------------------------
; RunNameMenuTest — A4.4 pixel harness. Draw the projected player-name menu on the
; cinematic surface; AUTOKEY_QUIET photographs it parked in HandleMenuInput at
; AUTOKEY_DUMP_FRAME. Proves DisplayIntroNameTextBox + the A4.4.a menu data render
; through the projection. In: EBP = GB base. Never returns.
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns          ; home/load_font.asm
extern LoadTextBoxTilePatterns       ; home/load_font.asm
extern MovieBeginSurface             ; movie_projection.asm
global RunNameMenuTest
RunNameMenuTest:
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call MovieBeginSurface
    mov edx, DefaultNamesPlayer           ; the player default-name menu string
    call DisplayIntroNameTextBox          ; parks in HandleMenuInput; AUTOKEY dumps
.hang:
    jmp .hang
%endif

%ifdef DEBUG_CHOOSENAME
; ---------------------------------------------------------------------------
; RunChooseNameTest — A4.5f end-to-end naming (default path). Show the player pic,
; run ChoosePlayerName; AUTOKEY_CHOOSENAME taps DOWN then A to pick the first default
; name (YELLOW), exercising DisplayIntroNameTextBox -> GetDefaultName ->
; OakSpeechSlidePicLeft -> PrintText(YourNameIsText). AUTOKEY_DUMP_FRAME photographs
; the "YOUR NAME IS ..." result. In: EBP = GB base. Never returns.
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns          ; home/load_font.asm
extern LoadTextBoxTilePatterns       ; home/load_font.asm
extern MovieMirrorSurface            ; movie_projection.asm
extern FadeInIntroPic                ; oak_speech.asm
extern DelayFrame                    ; video/frame.asm
global RunChooseNameTest
RunChooseNameTest:
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call MovieBeginSurface
    mov byte [ebp + IO_BGP], 0
    mov esi, RedPicFront
    mov ecx, RED_PIC_LEN
    xor bl, bl                            ; centred
    call IntroDisplayPicCenteredOrUpperRight
    call MovieMirrorSurface
    call FadeInIntroPic
    mov dword [text_row_stride], SCREEN_TILES_W
    mov dword [text_msgbox], msgbox_oak_speech
    call ChoosePlayerName                 ; AUTOKEY_CHOOSENAME drives DOWN+A -> YELLOW
.hang:
    call DelayFrame
    jmp .hang
%endif
