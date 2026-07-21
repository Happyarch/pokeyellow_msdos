; movie_projection.asm — shared cinematic surface projection (port-only).
;
; The boot movie (Game Freak splash, Yellow intro, title, Oak speech) keeps the
; Game Boy's 160x144 composition instead of expanding to the overworld's 40x25
; camera. That is deliberate and is NOT a shortcut: cinematic framing, entrances,
; exits, slide distances, object masks and screen-edge timing are authored
; against the GB viewport. Expanding them would either expose artwork and sprite
; states pret deliberately hides, or require inventing staging. Either violates
; fidelity. See docs/current_plan_menu_intro.md, "Presentation boundary".
;
; So every cinematic screen is an exact 160x144 GB surface centred on the canvas:
; canvas tile (10,3), pixel (80,24), ending exclusively at (240,168). The
; surrounding border is a presentation matte carrying only the cinematic's
; colour-zero/whiteout field — no duplicated artwork, no overworld residue, no
; OBJ. Geometry comes from the generated assets/ui_layout_intro.inc, never from
; literals, so the layout tool stays the single source of truth.
;
; This module owns the mechanics every cinematic screen shares, so no screen
; hand-rolls them: the stride-40 -> stride-32 mirror, matte publication, the
; hSCX/hSCY -> WIN_SRC_X/WIN_SRC_Y scroll transfer, and teardown.
;
; NOTE: port-only HAL/projection glue, not a pret translation. Routines carry
; descriptive port names because they have no pret counterpart.

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"

extern set_single_window        ; ppu.asm — EAX=wx EBX=wy ECX=clip_w EDX=max_y ESI=tilemap EDI=start_row
extern add_window               ; ppu.asm — same args, appends (painter's order)
extern hide_window              ; ppu.asm
extern g_window_count           ; ppu.asm
extern g_windows                ; ppu.asm — descriptor array (slot 0 is ours)
extern g_bg_whiteout            ; ppu.asm
extern g_obj_over_window        ; ppu.asm
extern g_obj_clip               ; ppu.asm — (x0,y0,x1,y1), upper bounds exclusive
extern g_surface_redraw_cb      ; ppu.asm — cinematic per-frame surface-mirror hook
extern spr_oam_valid            ; ppu.asm

global MovieBeginSurface
global MovieEndSurface
global MovieMirrorSurface
global MovieSyncScroll
global MovieSyncWindow

; The GB hides its window layer by parking rWY at or past the bottom scanline.
; This is the Game Boy's 144, NOT the port's RENDER_H — a cinematic reasons in
; GB screen space, and the projection converts.
SCREEN_HEIGHT_PX equ 144

section .text

; ---------------------------------------------------------------------------
; MovieBeginSurface — take over the screen as a centred GB cinematic surface.
;
; Establishes, in the order the compositor expects:
;   1. a cleared 40x25 W_TILEMAP (the matte field),
;   2. one window descriptor at the projected rectangle, sourcing GB_TILEMAP0,
;   3. g_bg_whiteout so the matte is the cinematic's colour-zero field,
;   4. the cinematic OBJ clip rectangle,
;   5. GB OBJ-over-window z-order, because on a cinematic the window IS the
;      screen and its OBJ belong on top (the port otherwise composites the
;      window last so the overworld dialog box can occlude NPCs).
;
; Does NOT publish OAM — the screen owns that via PublishProjectedOAM.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
MovieBeginSurface:
    pushad

    ; 1. Clear the canvas tilemap. The matte is whatever colour zero maps to;
    ;    leaving overworld tiles here is what would leak scene content.
    lea edi, [ebp + W_TILEMAP]
    mov ecx, W_TILEMAP_SIZE
    xor al, al
    rep stosb

    ; 2. One descriptor, geometry straight from the generated layout.
    movzx eax, byte [ebp + IO_WX]       ; stash the GB's own rWX first
    push eax
    mov eax, UI_TITLE_WX                ; 87 -> screen x 80
    mov ebx, UI_TITLE_WY                ; 24
    mov ecx, UI_TITLE_CLIP              ; 160
    mov edx, UI_TITLE_MAXY              ; 168 (exclusive)
    mov esi, GB_TILEMAP0
    xor edi, edi                        ; start_row 0
    call set_single_window              ; also zeroes WIN_SRC_X/WIN_SRC_Y
    pop eax

    ; set_single_window mirrors the descriptor's wx/wy into rWX/hWY for the
    ; overworld's "is the dialog open?" gate. A cinematic needs both bytes back:
    ; they are where the screen's own `ldh [hWY], a` / rWX writes land, and
    ; MovieSyncWindow reads them as the GB window position. Leaving the PROJECTED
    ; wx in rWX is the subtle one — MovieSyncWindow would then project an already
    ; projected value and place the window a full 80 px right of the surface.
    mov [ebp + IO_WX], al               ; restore the GB rWX (Init leaves it 7)
    mov byte [ebp + H_WY], SCREEN_HEIGHT_PX  ; GB "window hidden", pret's start state

    ; Park the overworld OAM rebuild. $FF is "already hidden/frozen, do nothing";
    ; 0 would make PrepareOAMData run HideSprites and republish spr_oam_valid = 0,
    ; erasing the screen's own OAM on the very next DelayFrame. The cinematic owns
    ; OAM from here via PublishProjectedOAM.
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0xFF
    ; Clear any OAM the previous screen left (e.g. the overworld player sprite, or an
    ; init-path publish before a cutscene). The cinematic starts with no sprites and
    ; publishes its own via PublishProjectedOAM; screens that DO show OBJ (the title's
    ; eyes) call PublishProjectedOAM AFTER this, so nothing they own is lost.
    mov dword [spr_oam_valid], 0

    ; 3-5. Cinematic compositor state.
    mov dword [g_bg_whiteout], 1
    mov dword [g_obj_over_window], 1
    ; Per-frame surface commit: repack W_TILEMAP -> GB_TILEMAP0 (MovieMirrorSurface)
    ; every DelayFrame, so pic/text drawn into the canvas becomes visible through the
    ; surface window without every caller mirroring by hand. MovieEndSurface clears it.
    mov dword [g_surface_redraw_cb], MovieMirrorSurface
    mov dword [g_obj_clip + 0], UI_TITLE_COL * 8            ; x0 = 80
    mov dword [g_obj_clip + 4], UI_TITLE_WY                 ; y0 = 24
    mov dword [g_obj_clip + 8], UI_TITLE_COL * 8 + UI_TITLE_CLIP   ; x1 = 240
    mov dword [g_obj_clip + 12], UI_TITLE_MAXY              ; y1 = 168

    popad
    ret

; ---------------------------------------------------------------------------
; MovieEndSurface — hand the screen to the next owner.
;
; Restores every piece of state MovieBeginSurface took, so a leaked narrow clip
; rectangle or a stuck whiteout cannot follow the cinematic into the overworld.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
MovieEndSurface:
    pushad
    call hide_window
    mov dword [g_bg_whiteout], 0
    mov dword [g_obj_over_window], 0
    mov dword [g_surface_redraw_cb], 0  ; stop mirroring the canvas once the surface ends
    mov dword [spr_oam_valid], 0        ; cinematic OBJ die with the screen
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 1  ; hand the rebuild back on
    mov dword [g_obj_clip + 0], 0       ; back to the full canvas
    mov dword [g_obj_clip + 4], 0
    mov dword [g_obj_clip + 8], RENDER_W
    mov dword [g_obj_clip + 12], RENDER_H
    popad
    ret

; ---------------------------------------------------------------------------
; MovieMirrorSurface — copy the drawn 20x18 rectangle into the GB tilemap.
;
; Cinematic code draws into W_TILEMAP at the projected position (stride 40) like
; every other screen; the window compositor samples a 32-stride GB tilemap. This
; is that transfer, and it must run after every tilemap mutation and before the
; next frame — menu_redraw_cb is driven by generic menu-input loops, not by
; DelayFrame, so it cannot be relied on here.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
MovieMirrorSurface:
    pushad
    lea esi, [ebp + W_TILEMAP + UI_TITLE_ROW * SCREEN_WIDTH + UI_TITLE_COL]
    lea edi, [ebp + GB_TILEMAP0]
    mov edx, UI_TITLE_GBH               ; 18 rows
.row:
    mov ecx, UI_TITLE_GBW               ; 20 columns
    push esi
    push edi
    rep movsb
    pop edi
    pop esi
    add esi, SCREEN_WIDTH               ; next canvas row (stride 40)
    add edi, 32                         ; next GB tilemap row (stride 32)
    dec edx
    jnz .row
    popad
    ret

; ---------------------------------------------------------------------------
; MovieSyncWindow — present the GB WINDOW LAYER as a second projected descriptor.
;
; A cinematic is not always BG-only. The title enables the window at hWY=64 for
; the whole logo bounce, and that is load-bearing: the row-24 tilemap copy runs
; contiguously off tilemap 0 into tilemap 1 at $9C00, which lands wTileMap rows
; 8..17 (Pikachu and the copyright line) in vBGMap1 rows 0..9. With LCDC bit 6
; selecting $9C00, the window at y=64 paints exactly those rows at exactly the
; screen position they belong to — so the top 64 px bounce with hSCY while the
; bottom 80 px stay nailed down. Drop the window and the copyright bounces too.
;
; Descriptor 0 is the cinematic surface itself (MovieBeginSurface). This appends
; descriptor 1 for the GB window on top of it, and drops back to just the surface
; when the window is parked off-screen. It never touches descriptor 0, so a
; MovieSyncScroll fine offset set for the bounce survives across this call.
;
; hWY carries pret's OWN hWY value during a cinematic (see MovieBeginSurface),
; not the descriptor mirror set_single_window would otherwise leave there — that
; is what lets the screen keep pret's `ldh [hWY], a` writes verbatim.
;
; LCDC bit 5 (window enable) and bit 6 (window map select) are honoured, so this
; is GB window semantics rather than a title-shaped special case.
;
; Must run after the screen writes hWY and before the next frame.
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
MovieSyncWindow:
    pushad
    mov dword [g_window_count], 1       ; surface only; re-add the window below

    test byte [ebp + IO_LCDC], (1 << 5) ; window layer disabled?
    jz .done
    movzx eax, byte [ebp + H_WY]
    cmp eax, SCREEN_HEIGHT_PX           ; parked at/past the bottom scanline?
    jae .done

    mov ebx, eax
    add ebx, UI_TITLE_WY                ; GB screen y -> canvas y
    movzx eax, byte [ebp + IO_WX]       ; WX units; 7 == GB x 0
    add eax, UI_TITLE_COL * 8           ; -> projected WX units
    mov ecx, UI_TITLE_CLIP
    mov edx, UI_TITLE_MAXY              ; clipped to the surface, never the matte
    mov esi, GB_TILEMAP0
    test byte [ebp + IO_LCDC], (1 << 6) ; window map select
    jz .map_selected
    mov esi, GB_TILEMAP1
.map_selected:
    xor edi, edi                        ; window always starts at map row 0
    call add_window
.done:
    popad
    ret

; ---------------------------------------------------------------------------
; MovieSyncScroll — present the GB scroll registers as fine source offsets.
;
; hSCX/hSCY are raw unsigned bytes and are transferred as such: pret's title
; bounce walks hSCY one pixel at a time including overshoot entries (the -3 crash
; step) whose unsigned value wraps near 255, and render_window reproduces the
; hardware mod-256 / mod-32 wrap. Screens call this instead of writing the
; descriptor themselves, so no screen can quietly reintroduce a linear read.
;
; Must run after the screen updates hSCX/hSCY and before the next frame.
;
; In:  EBP = GB memory base. All registers preserved.
; ---------------------------------------------------------------------------
MovieSyncScroll:
    pushad
    movzx eax, byte [ebp + H_SCX]
    mov [g_windows + WIN_SRC_X], eax
    movzx eax, byte [ebp + H_SCY]
    mov [g_windows + WIN_SRC_Y], eax
    popad
    ret
