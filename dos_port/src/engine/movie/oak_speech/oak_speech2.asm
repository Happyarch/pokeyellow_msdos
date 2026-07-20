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
