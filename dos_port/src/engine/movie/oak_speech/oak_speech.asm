; oak_speech.asm — the Oak-speech intro cutscene (menu-intro A4).
;
; Source: engine/movie/oak_speech/oak_speech.asm.
;
; This file is being ported incrementally (A4.1 first). It currently holds the
; PIC DISPLAY layer that the cutscene's picture beats use; PrepareOakSpeech /
; OakSpeech and the naming flow land in later A4 subtasks.
;
; PROJECTION: like every boot cinematic, Oak speech keeps the Game Boy's 160x144
; composition centred on the canvas (movie_projection, UI_OAK_SPEECH). pret's
; picture coords (hlcoord 6,4 centred / 15,1 upper-right) are therefore offset by
; UI_OAK_SPEECH_(COL,ROW) = (10,3) into the 40-wide canvas.
;
; Build: nasm -f coff -I include/ -I . -o oak_speech.o oak_speech.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"
%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_intro.inc"   ; UI_OAK_SPEECH_*

; --- decode + placement infra (all already in the port) ---
extern LoadMonPicToVRAM              ; home/pics.asm — decode staged pic → [EDX] VRAM, arm tilecache
extern GetPredefRegisters            ; home/predef.asm — restore HL/DE/BC for a predef body
extern CopyUncompressedPicToTilemap  ; engine/battle/init_battle.asm — predef; place 7×7 ids at wPredefHL
extern UpdateCGBPal_BGP              ; home/cgb_palettes.asm — commit rBGP to the DAC
extern DelayFrames                   ; video/frame.asm — wait BL frames
extern DelayFrame                    ; video/frame.asm — wait one frame (MovePicLeft)
extern MovieSyncWindow               ; movie_projection.asm — project rWX/hWY to the window descriptor
extern DebugNewGamePlayerName        ; movie/title.asm — shared debug boot names
extern DebugNewGameRivalName         ; movie/title.asm
extern FillMemory                    ; home/fill_memory.asm — ESI=dest, BX=len, AL=val
extern InitOptions                   ; engine/menus/main_menu.asm

NAME_LENGTH  equ 11                  ; wPlayerName / wRivalName field size

; wSurfingMinigameHiScore (pret sym 00:d494) — not yet in gb_memmap.inc; report
; to root for promotion. %ifndef-guarded so promotion is a no-op here.
%ifndef wSurfingMinigameHiScore
wSurfingMinigameHiScore equ 0xD494
%endif

global DisplayPicCenteredOrUpperRight
global IntroDisplayPicCenteredOrUpperRight
global FadeInIntroPic
global PrepareOakSpeech
global MovePicLeft

; The GB scratch the pic decoder addresses its input through (home/pics.asm).
%define PIC_STAGE_GB  0xA4A0

; Projected 7×7 placement corners (pret coord + UI_OAK_SPEECH origin), as flat
; GB tilemap addresses. Centred = hlcoord(6,4); upper-right = hlcoord(15,1).
OAKPIC_CENTER  equ (W_TILEMAP + (4 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (6 + UI_OAK_SPEECH_COL))
OAKPIC_UPRIGHT equ (W_TILEMAP + (1 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (15 + UI_OAK_SPEECH_COL))

; Oak-speech intro text streams (Tier-1 generated: OakSpeechText1/2/3,
; IntroducePlayerText, IntroduceRivalText + their _ref pairs). The A4.3 control
; flow PrintText's these; declared here so the data links with the cutscene.
%include "assets/oak_speech_strings.inc"

section .data
align 4
; msgbox_oak_speech — the intro dialog projection. Modelled on the battle's
; msgbox_centered: draw the box + text DIRECTLY into the surface canvas
; (W_TILEMAP, stride 40) at the UI_OAK_SPEECH-projected dialog location, with NO
; window of its own (MB_WIN_TILEMAP = 0). MovieMirrorSurface then commits the
; whole surface — pic AND text — to GB_TILEMAP0, and the ONE surface window
; MovieBeginSurface published shows both. This is why the intro must NOT use
; msgbox_dialog: that descriptor creates a second, screen-space window that
; replaces the surface (pic vanishes) and leaks into the matte (the DEBUG_OAKINTRO
; finding). MB_PROMPT = 0 ("caller waits"), so PrintText types the first page and
; returns at the paragraph break — exactly the oak_intro checkpoint state.
;
; pret's dialog box is GB(0,12) 20x6, text lines at (1,14)/(1,16), ▼ at (18,16);
; every coord is offset by UI_OAK_SPEECH_(COL,ROW) = (10,3) into the 40-wide canvas.
global msgbox_oak_speech
msgbox_oak_speech:
    dd SCREEN_TILES_W                                                   ; MB_STRIDE (40, canvas)
    dd (W_TILEMAP + (12 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (0 + UI_OAK_SPEECH_COL))  ; MB_BOX_OFS
    dd 18                                                               ; MB_BOX_W (interior cols)
    dd 4                                                                ; MB_BOX_H (interior rows)
    dd (W_TILEMAP + (14 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (1 + UI_OAK_SPEECH_COL))  ; MB_LINE1
    dd (W_TILEMAP + (16 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (1 + UI_OAK_SPEECH_COL))  ; MB_LINE2
    dd (W_TILEMAP + (16 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (18 + UI_OAK_SPEECH_COL)) ; MB_ARROW
    dd 0                                                                ; MB_PROMPT (0 = caller waits)
    dd 0                                                                ; MB_WIN_WX  ] no window:
    dd 0                                                                ; MB_WIN_WY  ] drawn into the
    dd 0                                                                ; MB_WIN_CLIP] surface canvas,
    dd 0                                                                ; MB_WIN_MAXY] shown through
    dd 0                                                                ; MB_WIN_TILEMAP (0 = none)
    dd 0                                                                ; MB_WIN_STARTROW

; IntroFadePalettes — 6 BGP ramp bytes, computed from pret's `dc a,b,c,d` macro
; (macros/data.asm: db (a<<6)|(b<<4)|(c<<2)|d). The ramp fades the pic UP from
; darkest to the normal DMG palette; the final 0xE4 == %11100100 is the normal
; BGP, which is the load-bearing check that these bytes are right.
IntroFadePalettes:
    db 0x54    ; dc 1,1,1,0
    db 0xA8    ; dc 2,2,2,0
    db 0xFC    ; dc 3,3,3,0
    db 0xF8    ; dc 3,3,2,0
    db 0xF4    ; dc 3,3,1,0
    db 0xE4    ; dc 3,2,1,0  (= %11100100, normal BGP)

section .text

; ---------------------------------------------------------------------------
; FadeInIntroPic — fade the current picture up through 6 BGP steps, 10 frames
; each. Source: engine/movie/oak_speech/oak_speech.asm:FadeInIntroPic.
; DelayFrames touches only BL, so the BH step counter survives the call (matching
; pret keeping b across the DelayFrames).
; ---------------------------------------------------------------------------
FadeInIntroPic:
    lea esi, [IntroFadePalettes]         ; ld hl, IntroFadePalettes
    mov bh, 6                             ; ld b, 6
.next:
    mov al, [esi]                         ; ld a, [hli]
    inc esi
    mov [ebp + IO_BGP], al                ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov bl, 10                            ; ld c, 10
    call DelayFrames
    dec bh
    jnz .next
    ret

; ---------------------------------------------------------------------------
; MovePicLeft — slide the on-window picture in from the right by walking rWX from
; 119 down to 0 (8 px/frame), after snapping BGP to normal. Source:
; engine/movie/oak_speech/oak_speech.asm:MovePicLeft.
;
; pret writes rWX and lets the LCD reveal more of the window each frame. The port's
; compositor reads the window DESCRIPTOR, not rWX, so each rWX change is projected
; through MovieSyncWindow (the same helper the title bounce uses) to move the
; window descriptor's x — otherwise the slide would not appear.
;
; DEVIATION{class=projection; pret=engine/movie/oak_speech/oak_speech.asm:MovePicLeft; behavior=each rWX write is followed by MovieSyncWindow so the projected window descriptor tracks the slide; evidence=the port renders the window from a descriptor list (movie_projection) rather than sampling rWX per scanline like the GB LCD; lifetime=permanent widescreen projection}
;
; In: EBP = GB base.
; ---------------------------------------------------------------------------
MovePicLeft:
    mov byte [ebp + IO_WX], 119           ; ld a, 119 / ldh [rWX], a
    call MovieSyncWindow                   ; project the initial window position
    call DelayFrame
    mov byte [ebp + IO_BGP], 0xE4         ; ld a, %11100100 / ldh [rBGP], a
    call UpdateCGBPal_BGP
.next:
    call DelayFrame
    movzx eax, byte [ebp + IO_WX]         ; ldh a, [rWX]
    sub al, 8                              ; sub 8
    cmp al, 0xFF                           ; cp $FF (dropped below 0)
    je .done                               ; ret z
    mov [ebp + IO_WX], al                  ; ldh [rWX], a
    call MovieSyncWindow                   ; re-project after the slide step
    jmp .next
.done:
    ret

; ---------------------------------------------------------------------------
; PrepareOakSpeech — clear the save block for a new game, keeping only the four
; option/status bytes, (re)init options, then seed the debug player/rival names.
; Source: engine/movie/oak_speech/oak_speech.asm:PrepareOakSpeech.
;
; The name copy uses NAME_LENGTH=11, overrunning each 7/5-byte string into the
; next (wPlayerName = "NINTEN@SONY"); the shared title.asm block lays the strings
; out contiguously so the overrun is reproduced faithfully. pret's `call CopyData`
; (GB->GB) becomes rep movsb here because the names are program-image data — the
; port's PrepareTitleScreen does the same.
; ---------------------------------------------------------------------------
PrepareOakSpeech:
    ; Preserve the option/status bytes across the wholesale save-block clear.
    movzx eax, byte [ebp + W_LETTER_PRINTING_DELAY]
    push eax
    movzx eax, byte [ebp + wOptions]
    push eax
    movzx eax, byte [ebp + W_STATUS_FLAGS_6]      ; carries BIT_DEBUG_MODE (pret note)
    push eax
    movzx eax, byte [ebp + wPrinterSettings]
    push eax

    ; Zero wPlayerName..wBoxDataEnd (the whole main+box save block) and the
    ; sprite state block.
    mov esi, W_PLAYER_NAME
    mov bx, (wBoxDataEnd - W_PLAYER_NAME) & 0xFFFF
    xor al, al
    call FillMemory
    mov esi, wSpriteDataStart
    mov bx, (wSpriteDataEnd - wSpriteDataStart) & 0xFFFF
    xor al, al
    call FillMemory
    xor al, al
    mov [ebp + wSurfingMinigameHiScore + 0], al
    mov [ebp + wSurfingMinigameHiScore + 1], al
    mov [ebp + wSurfingMinigameHiScore + 2], al

    ; Restore the four preserved bytes (pop order mirrors the pushes).
    pop eax
    mov [ebp + wPrinterSettings], al
    pop eax
    mov [ebp + W_STATUS_FLAGS_6], al
    pop eax
    mov [ebp + wOptions], al
    pop eax
    mov [ebp + W_LETTER_PRINTING_DELAY], al

    ; InitOptions only if it has not run yet (pret: call z, InitOptions).
    cmp byte [ebp + wOptionsInitialized], 0
    jnz .optsReady
    call InitOptions
.optsReady:

    ; Seed the debug names.
    lea esi, [DebugNewGamePlayerName]
    lea edi, [ebp + W_PLAYER_NAME]
    mov ecx, NAME_LENGTH
    rep movsb
    lea esi, [DebugNewGameRivalName]
    lea edi, [ebp + W_RIVAL_NAME]
    mov ecx, NAME_LENGTH
    rep movsb
    ret

; ---------------------------------------------------------------------------
; DisplayPicCenteredOrUpperRight — predef entry. Restores the predef registers,
; then falls into the intro variant. Source: oak_speech.asm.
; ---------------------------------------------------------------------------
DisplayPicCenteredOrUpperRight:
    call GetPredefRegisters
    ; fall through

; ---------------------------------------------------------------------------
; IntroDisplayPicCenteredOrUpperRight — decode a compressed pic and place its
; 7×7 tile block centred or upper-right on the projected surface.
;
; Source: oak_speech.asm:IntroDisplayPicCenteredOrUpperRight. pret takes
;   b  = ROM bank of the pic
;   de = GB ROM address of the compressed pic
;   c  = 0 centred / non-zero upper-right
; and copies sSpriteBuffer1 -> sSpriteBuffer0 through SRAM before merging.
;
; DEVIATION{class=data-model; pret=engine/movie/oak_speech/oak_speech.asm:IntroDisplayPicCenteredOrUpperRight; behavior=the pic is taken as a FLAT program-image pointer plus a byte length instead of a bank+GB-ROM address, and the SRAM sprite-buffer copy is dropped; evidence=the port's compressed pics are generated program-image data not GB ROM, and its LoadMonPicToVRAM decodes straight to the sprite buffers so there is no SRAM buffer to shuffle (the LoadFrontSpriteByMonIndex / trainer_card precedent); lifetime=permanent flat-memory model}
;
; Port In:  ESI = flat compressed-pic pointer, ECX = pic byte length,
;           BL = 0 centred / non-zero upper-right. EBP = GB base.
; Out: 7×7 pic on the projected surface; g_tilecache_dirty armed by LoadMonPicToVRAM.
; ---------------------------------------------------------------------------
IntroDisplayPicCenteredOrUpperRight:
    push ebx                              ; save the centre/UR selector (pret push bc)

    ; Stage the compressed stream into GB scratch — the decoder reads it through
    ; a 16-bit GB pointer (wSpriteInputPtr), and the source lives in the program
    ; image (pics.asm PIC_STAGE contract, same as LoadFrontSpriteByMonIndex).
    lea edi, [ebp + PIC_STAGE_GB]
    rep movsb                             ; ESI (flat src) -> PIC_STAGE, ECX bytes
    mov word [ebp + wSpriteInputPtr], PIC_STAGE_GB
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [ebp + PIC_STAGE_GB]          ; dimensions byte (hi=H, lo=W tiles)
    mov edx, GB_VCHARS2                    ; merge dest = vFrontPic ($9000, signed tile $00)
    call LoadMonPicToVRAM                 ; decode + centre + merge + arm tilecache

    pop ebx
    test bl, bl
    jz .centred
    mov eax, OAKPIC_UPRIGHT
    jmp .place
.centred:
    mov eax, OAKPIC_CENTER
.place:
    ; predef_jump CopyUncompressedPicToTilemap: hand it the dest via wPredefHL
    ; (big-endian, as GetPredefRegisters expects) and hStartTileID = 0.
    mov byte [ebp + wPredefHL], ah        ; high byte of the dest
    mov byte [ebp + wPredefHL + 1], al    ; low byte
    mov byte [ebp + hStartTileID], 0
    jmp CopyUncompressedPicToTilemap      ; tail (places ids $00.. down each column)

%ifdef DEBUG_OAKPIC
; ---------------------------------------------------------------------------
; RunOakPicTest — A4.1 pixel harness. Put Prof. Oak's pic on the centred
; cinematic surface and dump FRAME.BIN. Proves the pic-display layer renders
; through the projection; not a faithful OakSpeech frame (no palette/fade/text —
; that is A4.3/A4.5). In: EBP = GB base. Never returns.
; ---------------------------------------------------------------------------
extern LoadFontTilePatterns          ; home/load_font.asm — $7F space tile
extern MovieBeginSurface             ; movie_projection.asm
extern MovieMirrorSurface            ; movie_projection.asm
extern DumpBackbuffer                ; debug/debug_dump.asm — FRAME.BIN + exit
extern DelayFrame                    ; video/frame.asm
extern ProfOakPic                    ; data/trainer_pics.asm (== pret ProfOakPic)
global RunOakPicTest

PROF_OAK_PIC_LEN equ 286             ; gfx/trainers/prof.oak.pic byte length

RunOakPicTest:
    call LoadFontTilePatterns         ; decode the font so the $7F blank has a pattern
    call MovieBeginSurface            ; centred surface + matte, window over GB_TILEMAP0

    ; Blank the projected 20x18 rect to $7F so the matte is space, not the pic's
    ; tile id 0 (MovieBeginSurface zeroes W_TILEMAP; id 0 == the pic's first tile).
    lea edi, [ebp + W_TILEMAP + UI_OAK_SPEECH_ROW * SCREEN_TILES_W + UI_OAK_SPEECH_COL]
    mov edx, 18
.blank:
    mov ecx, 20
    push edi
    mov al, 0x7F
    rep stosb
    pop edi
    add edi, SCREEN_TILES_W
    dec edx
    jnz .blank

    ; Display Prof. Oak centred (BL = 0).
    mov esi, ProfOakPic
    mov ecx, PROF_OAK_PIC_LEN
    xor bl, bl
    call IntroDisplayPicCenteredOrUpperRight

    call MovieMirrorSurface           ; commit the 20x18 rect to GB_TILEMAP0
    mov byte [ebp + IO_BGP], 0        ; start blacked-out, then fade the pic UP
    call FadeInIntroPic               ; ends at BGP 0xE4 (normal) — the checkpoint palette
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer               ; never returns
.hang:
    jmp .hang
%endif

%ifdef DEBUG_OAKINTRO
; ---------------------------------------------------------------------------
; RunOakSpeechCheckpoint — A4.3/A4.5 oak_intro checkpoint DIAGNOSTIC. Drives the
; opening beats — Prof. Oak's pic, FadeInIntroPic, PrintText(OakSpeechText1) — on
; the projected surface, then AutoKeyDrive (AUTOKEY_QUIET) photographs the parked
; page-1 frame at AUTOKEY_DUMP_FRAME.
;
; STATUS (2026-07-20): rendering resolved. The earlier "crash before dump" was a
; MISDIAGNOSIS: page 1 of OakSpeechText1 ends with <PARA> ($51), not <PROMPT>
; ($58), and <PARA> parks in text_pause's key-wait — headless with no dump timer it
; simply HUNG, and the blank FRAME.BIN read back was a stale leftover, not a real
; render. Two mechanism facts drove the fix:
;   1. The surface is shown through a WINDOW sampling GB_TILEMAP0 (stride 32), but
;      PrintText types into W_TILEMAP (stride 40), and the text engine's own
;      per-char mirror (sync_dialog_window) is gated off under g_bg_whiteout and
;      targets GB_TILEMAP1. So canvas text was invisible. FIX: g_surface_redraw_cb
;      (ppu.asm) — DelayFrame repacks W_TILEMAP -> GB_TILEMAP0 every frame while a
;      cinematic owns the screen (armed by MovieBeginSurface = MovieMirrorSurface).
;   2. <PARA>/<PROMPT> dispatch through text_prompt_hook, and PrintText's box setup
;      copies the descriptor's MB_PROMPT into it — so the hold is installed via
;      msgbox_oak_speech's MB_PROMPT (= .introWait), which parks WITHOUT the
;      windowed overworld scroll that replaces the surface.
; AUTOKEY_QUIET + AUTOKEY_DUMP_FRAME photograph the parked page-1 frame.
;
; In: EBP = GB base. Never returns (AutoKeyDrive dumps FRAME.BIN + exits).
; ---------------------------------------------------------------------------
extern MovieBeginSurface             ; movie_projection.asm
extern MovieMirrorSurface            ; movie_projection.asm
extern LoadFontTilePatterns          ; home/load_font.asm
extern LoadTextBoxTilePatterns       ; home/load_font.asm
extern PrintText                     ; home/window.asm — ESI = text stream
extern text_msgbox                   ; home/text.asm — active msgbox projection
; text_prompt_hook is driven via msgbox_oak_speech's MB_PROMPT (PrintText copies it)
extern DumpBackbuffer                ; debug/debug_dump.asm — FRAME.BIN + exit
extern DelayFrame                    ; video/frame.asm
extern ProfOakPic                    ; data/trainer_pics.asm
global RunOakSpeechCheckpoint

OAKINTRO_PIC_LEN equ 286             ; gfx/trainers/prof.oak.pic byte length

RunOakSpeechCheckpoint:
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call MovieBeginSurface

    ; Prof. Oak, centred, faded up.
    mov byte [ebp + IO_BGP], 0
    mov esi, ProfOakPic
    mov ecx, OAKINTRO_PIC_LEN
    xor bl, bl                        ; centred
    call IntroDisplayPicCenteredOrUpperRight
    call MovieMirrorSurface
    call FadeInIntroPic

    ; First text page, typed into the surface canvas (msgbox_oak_speech = no window).
    ; The per-frame g_surface_redraw_cb (armed by MovieBeginSurface = MovieMirrorSurface)
    ; repacks the canvas into GB_TILEMAP0 every DelayFrame, so each character appears
    ; through the surface window as PrintText types it — no manual per-page mirror.
    ; At the page-1 <PARA> the engine calls text_pause -> text_prompt_hook; PrintText's
    ; box setup COPIES the descriptor's MB_PROMPT (offset 28) into that global, so the
    ; hold must be installed via MB_PROMPT (setting text_prompt_hook directly is
    ; clobbered). .introWait parks (the ▼-wait) without hijacking the window.
    mov dword [msgbox_oak_speech + 28], .introWait   ; MB_PROMPT
    mov dword [text_msgbox], msgbox_oak_speech
    mov esi, OakSpeechText1
    call PrintText                    ; types page 1, then parks in .introWait at <PARA>
    jmp $                             ; unreached: AutoKeyDrive photographs + exits mid-wait

    ; .introWait — the intro's <PARA>/<PROMPT> hold: park until A/B, letting each frame
    ; mirror via the surface hook. Returns so the engine advances to the next paragraph
    ; in real gameplay; under AUTOKEY_QUIET no key is pressed, so it parks until
    ; AutoKeyDrive writes FRAME.BIN at AUTOKEY_DUMP_FRAME and exits. All regs saved by
    ; text_pause's pushad, so this need not preserve them.
.introWait:
    call DelayFrame
    movzx eax, byte [ebp + H_JOY_PRESSED]
    test al, (PAD_A | PAD_B)
    jz .introWait
    ret
%endif
