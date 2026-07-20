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

global DisplayPicCenteredOrUpperRight
global IntroDisplayPicCenteredOrUpperRight

; The GB scratch the pic decoder addresses its input through (home/pics.asm).
%define PIC_STAGE_GB  0xA4A0

; Projected 7×7 placement corners (pret coord + UI_OAK_SPEECH origin), as flat
; GB tilemap addresses. Centred = hlcoord(6,4); upper-right = hlcoord(15,1).
OAKPIC_CENTER  equ (W_TILEMAP + (4 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (6 + UI_OAK_SPEECH_COL))
OAKPIC_UPRIGHT equ (W_TILEMAP + (1 + UI_OAK_SPEECH_ROW) * SCREEN_TILES_W + (15 + UI_OAK_SPEECH_COL))

section .text

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
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer               ; never returns
.hang:
    jmp .hang
%endif
