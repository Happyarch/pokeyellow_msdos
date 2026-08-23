; pikachu_pic_animation.asm — mirror of pret engine/pikachu/pikachu_pic_animation.asm.
;
; The pikapic engine: the animated Pikachu front-pic portrait an emotion script
; plays with `pikaemotion_pikapic`.  Which portrait is chosen comes from a
; mood x happiness matrix (GetPikaPicAnimationScriptIndex); the portrait itself is
; a small bytecode program (RunPikaPicAnimSetupScript) that loads graphics into
; vNPCSprites, registers up to four animation OBJECTS, and then lets
; AnimateCurrentPikaPicAnimFrame step each object's frame list, stamping a cel
; tilemap into wTileMap every frame until the duration expires or A/B is pressed.
;
; Register map (CLAUDE.md): A->AL, BC->BX, DE->EDX, HL->ESI, EBP = GB memory base.
;
; ---------------------------------------------------------------------------
; PRESENTATION — WHAT ACTUALLY PUTS THESE CELLS ON THE SCREEN
;
; pikapic plays during overworld emotion playback, so the overworld view pointer
; is LIVE.  That rules out both of the port's other two surfaces, and it was
; settled by reading the compositor rather than by preference:
;
;  * NOT the flat canvas.  render_bg (src/ppu/ppu.asm) selects
;    decode_surface_overworld whenever wCurrentTileBlockMapViewPointer is
;    non-zero and only reads wTileMap on its `.flat_path`, so a write to wTileMap
;    while the map is up composites nothing at all.
;  * NOT canvas ownership either.  The evo_canvas_enter/_exit pattern
;    (src/engine/movie/evolution.asm) buys the flat path by ZEROING that view
;    pointer, which blanks the overworld map — while on hardware pikapic is a 7x7
;    box drawn OVER a map that stays visible around it.  Taking the canvas here
;    would be a bigger divergence than the one it fixes.
;  * NOT the retired auto-transfer.  pret brackets its box placement with
;    hAutoBGTransferEnabled 0/1 writes; src/home/vblank.asm:136 records
;    do_bg_transfer as RETIRED, so those faithful writes move nothing.
;
; What is left is the mechanism the port already uses for "a box over the live
; overworld": a WINDOW descriptor whose source tilemap is filled by an explicit
; mirror.  That is exactly how the overworld dialog works (set_single_window +
; sync_dialog_window, src/home/text.asm) and how the party menu works
; (PartyMenuMirror).  pikapic_window_enter appends its descriptor with
; add_window — APPEND, not set_single_window, so an emotion script's already-open
; dialog box survives underneath — and pikapic_mirror carries the 7x7 block into
; GB_TILEMAP0 rows 0-6 once per animated frame.
;
; DEVIATION{class=projection; pret=engine/pikachu/pikachu_pic_animation.asm:StarterPikachuEmotionCommand_pikapic; behavior=the portrait box is composited as a window descriptor fed by an explicit 7x7 mirror into GB_TILEMAP0, and the 7x7 wTileMap block it draws through is saved and restored around the animation, where pret simply draws into the live background tilemap and lets the VBlank auto-transfer carry it; evidence=render_bg only reads wTileMap when wCurrentTileBlockMapViewPointer is zero and the overworld keeps it non-zero, the port retired the hAutoBGTransferEnabled VBlank transfer that pret relies on here, and the port's stride-20 dialog scratch overlaps the stride-40 canvas rows this box occupies so the block must be saved; lifetime=permanent window-compositor boundary}
;
; ---------------------------------------------------------------------------
; PROJECTION — THE FRAME AND THE CELS MOVE TOGETHER
;
; docs/ui_projection.md, "Pikachu front-pic animation (pikapic)": the box is the
; first overworld-ui element ruled that is not flush against a screen edge, so it
; takes the CENTER rule (X+10, Y+0), not an edge anchor.
;
; The cels are NOT placed by an hlcoord literal — LoadCurPikaPicObjectTilemap's
; .GetStartCoords computes wTileMap + wPikaPicPikaDrawStartY * SCREEN_WIDTH +
; wPikaPicPikaDrawStartX.  So the DRAW START carries the same +10/+0 projection
; as the frame (see ResetPikaPicAnimBuffer), or the cels would render at the GB
; origin while their frame sat ten columns right.  SCREEN_WIDTH there is a
; STRIDE and is already correct at 40; pret's 20 is NOT substituted.
;
; ---------------------------------------------------------------------------
; VRAM
;
; PikaPicAnimCommand_loadgfx writes tile patterns into vNPCSprites ($8000), at
; byte offset (tile id) * 16, so the cel tile ids $80.. land at $8800.. — which
; is vFont, exactly as on hardware (the emotion script's LOADFONT subcmd is what
; puts the font back).  Both writers arm the decode cache: CopyVideoDataAlternate
; routes through CopyVideoData, and InterlaceMergeSpriteBuffers sets
; g_tilecache_dirty itself.  OBJ tiles would not be exempt either — nothing here
; may `rep movs` into vChars without arming it.
;
; Build: nasm -f coff -I include/ -I . -o pikachu_pic_animation.o pikachu_pic_animation.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; ---------------------------------------------------------------------------
; pikapic WRAM — pret ram/wram.asm:2052-2068, the NEXTU arm that overlays
; wCurPikaMovementData (which src/engine/pikachu/pikachu_movement.asm anchors at
; $D44D).  The port models GB memory flat, so the union aliasing is reproduced
; for free.  wPikaPicUsedGFX* / wPikaPicAnimObjectDataBuffer* are the other pret
; union (ram/wram.asm:673-693) sharing bytes with wTrainerCardBadgeAttributes,
; whose $CC5D is already pinned in gb_memmap.inc — so that union's base is $CC5B.
; ---------------------------------------------------------------------------

; pret ram/vram.asm:20 — the overworld UNION arm at $8000. gb_memmap.inc carries
; its sibling vNPCSprites2 (= vChars1) but not this one.
vNPCSprites                      equ vChars0

PIKAPIC_OBJECT_STRUCT_SIZE       equ 8
PIKAPIC_OBJECT_SLOTS             equ 4
PIKAPIC_GFX_SLOTS                equ 8

; ---------------------------------------------------------------------------
; The projected placement.  ; PROJ overworld-ui (pikapic frame): GB(6,5) 7x7 --(center, X+10, Y+0)--> wx=135 wy=40 clip=56 max_y=96
; ---------------------------------------------------------------------------
PIKAPIC_BOX_COL     equ 6 + 10          ; GB col 6, center rule X+10 -> canvas col 16
PIKAPIC_BOX_ROW     equ 5 + 0           ; GB row 5, Y untranslated        -> canvas row 5
PIKAPIC_BOX_W       equ 7               ; TextBoxBorder lb bc,5,5 -> 7x7 including border
PIKAPIC_BOX_H       equ 7
PIKAPIC_BOX_OFS     equ wTileMap + PIKAPIC_BOX_ROW * SCREEN_WIDTH + PIKAPIC_BOX_COL
PIKAPIC_WIN_WX      equ PIKAPIC_BOX_COL * 8 + 7      ; 135 — render_window's left edge is WX-7
PIKAPIC_WIN_WY      equ PIKAPIC_BOX_ROW * 8          ; 40
PIKAPIC_WIN_CLIP    equ PIKAPIC_BOX_W * 8            ; 56
PIKAPIC_WIN_MAXY    equ (PIKAPIC_BOX_ROW + PIKAPIC_BOX_H) * 8   ; 96
PIKAPIC_WIN_TILEMAP equ GB_TILEMAP0                  ; free while the map is up: the
                                                     ; overworld composites from
                                                     ; wSurroundingTiles, and
                                                     ; CopyMapViewToVRAM is retired
PIKAPIC_WIN_SROW    equ 0

; ---------------------------------------------------------------------------
; Externs
; ---------------------------------------------------------------------------
extern FillMemory                       ; src/home/copy2.asm — ESI dest, BX count, AL value
extern AddNTimes                        ; src/home/array.asm — ESI += BX * AL
extern TextBoxBorder                    ; src/home/text.asm — ESI top-left, BH rows, BL cols
extern Delay3                           ; src/home/palettes.asm
extern DelayFrame                       ; src/home/vblank.asm
extern DelayFrames                      ; src/home/delay.asm — BL frames
extern UpdateSprites                    ; src/home/update_sprites.asm
extern JoypadLowSensitivity             ; src/home/joypad2.asm
extern RunDefaultPaletteCommand         ; src/home/palettes.asm
extern LoadOverworldPikachuFrontpicPalettes ; src/engine/gfx/palettes.asm
extern CopyData                         ; src/home/copy.asm — ESI src, EDX dst, BX count
extern CopyVideoDataAlternate           ; src/home/copy.asm — ESI VRAM dest, EDX flat src, BL tiles
extern UncompressSpriteFromDE           ; src/home/tilemap.asm — EDX flat src, ECX length
extern InterlaceMergeSpriteBuffers      ; src/home/pics.asm — merges into [pic_dest]
extern pic_dest                         ; src/home/pics.asm — the merge destination
extern PlayPikachuSoundClip             ; src/audio/pikachu_pcm.asm — DL = clip index
extern PlaySound                        ; src/home/audio.asm — AL = sound id
extern WaitForSoundToFinish             ; src/home/delay.asm
extern UpdateCGBPal_BGP                 ; src/home/cgb_palettes.asm
extern MoveSoundTable                   ; src/data/moves/sfx.asm — stride 3, read flat
extern add_window                       ; src/ppu/ppu.asm
extern g_window_count                   ; src/ppu/ppu.asm
extern text_row_stride                  ; src/home/text.asm

extern PikaPicAnimBGFramesPointers      ; src/data/pikachu/pikachu_pic_objects.asm
extern PikaPicTilemapPointers           ; src/data/pikachu/pikachu_pic_tilemaps.asm
extern PikaPicAnimGFXHeaders            ; src/data/pikachu/pikachu_pic_animation.asm
extern PikaPicAnimThunderboltPals
extern PikaPicAnimScript0,  PikaPicAnimScript1,  PikaPicAnimScript2
extern PikaPicAnimScript3,  PikaPicAnimScript4,  PikaPicAnimScript5
extern PikaPicAnimScript6,  PikaPicAnimScript7,  PikaPicAnimScript8
extern PikaPicAnimScript9,  PikaPicAnimScript10, PikaPicAnimScript11
extern PikaPicAnimScript12, PikaPicAnimScript13, PikaPicAnimScript14
extern PikaPicAnimScript15, PikaPicAnimScript16, PikaPicAnimScript17
extern PikaPicAnimScript18, PikaPicAnimScript19, PikaPicAnimScript20
extern PikaPicAnimScript21, PikaPicAnimScript22, PikaPicAnimScript23
extern PikaPicAnimScript24, PikaPicAnimScript25, PikaPicAnimScript26
extern PikaPicAnimScript27, PikaPicAnimScript28, PikaPicAnimScript29
extern OpenSRAM                         ; src/home/bankswitch2.asm
extern CloseSRAM                        ; src/home/bankswitch2.asm

%include "assets/audio_constants.inc"   ; SFX_BATTLE_2F, AUDIO_BANK_2

PIKAPIC_GFX_HEADER_STRIDE equ 8         ; db size, db bank, dw len, dd ptr

; ---------------------------------------------------------------------------
; Globals
; ---------------------------------------------------------------------------
global GetPikaPicAnimationScriptIndex
global PikachuMoodLookupTable
global PikaPicAnimationScriptPointerLookupTable
global StarterPikachuEmotionCommand_pikapic
global ResetPikaPicAnimBuffer
global PlacePikapicTextBoxBorder
global LoadCurrentPikaPicAnimScriptPointer
global PikaPicAnimPointers
global ExecutePikaPicAnimScript
global PikaPicAnimTimerAndJoypad
global CheckPikaPicAnimTimer
global DummyFunction_fdad5
global AnimateCurrentPikaPicAnimFrame
global PikaPicAnimCommand_object
global PikaPicAnimCommand_deleteobject
global LoadPikaPicAnimObjectData
global LoadCurPikaPicObjectTilemap
global LoadPikaPicAnimGFXHeader
global RunPikaPicAnimSetupScript
global PikaPicAnimCommand_nop
global PikaPicAnimCommand_ret
global PikaPicAnimCommand_setduration
global PikaPicAnimCommand_run
global PikaPicAnimCommand_writebyte
global PikaPicAnimCommand_nop4
global PikaPicAnimCommand_nop5
global PikaPicAnimCommand_nop7
global PikaPicAnimCommand_nop8
global PikaPicAnimCommand_jump
global GetPikaPicAnimByte
global UpdatePikaPicAnimPointer
global PikaPicAnimCommand_loadgfx
global RequestPikaPicAnimGFX
global DecompressRequestPikaPicAnimGFX
global ClearPikaPicUsedGFXBuffer
global GetPikaPicVRAMAddressForNewGFX
global CheckIfThereIsRoomForPikaPicAnimGFX
global LookUpTileOffsetForCurrentPikaPicAnimGFX
global PikaPicAnimCommand_cry
global PikaPicAnimCommand_thunderbolt

; Port-only presentation helper, exported ONLY so the DEBUG_PIKAPIC harness
; (src/debug/debug_dump.asm:RunPikaPicTest) can drive the same choreography
; StarterPikachuEmotionCommand_pikapic runs without going through that routine
; itself (which has no natural mid-animation return point to dump a frame at —
; see RunPikaPicTest's header). No behavior change: `global` only affects link
; visibility. pikapic_mirror / pikapic_window_exit stay file-local because
; ExecutePikaPicAnimScript (already global) calls pikapic_mirror internally
; every frame, and the harness dumps-and-exits before window_exit would run.
global pikapic_window_enter

section .bss
align 4
; DEVIATION{class=data-model; pret=engine/pikachu/pikachu_pic_animation.asm:UpdatePikaPicAnimPointer; behavior=the live animation-script cursor is a 32-bit host dword and the pret-named 16-bit wPikaPicAnimPointer keeps only its low half as a write-only shadow, where pret reads its cursor straight back out of that WRAM word; evidence=the pikapic scripts are linked into the DOS program image above the 16-bit GB address space so a dw cannot hold one, and every reader here goes through GetPikaPicAnimByte or PikaPicAnimCommand_jump which take the dword; lifetime=permanent flat 32-bit memory model}
pikapic_anim_ptr:    resd 1
; Port-only presentation state, saved by pikapic_window_enter.
pikapic_saved_wincount: resd 1
pikapic_saved_stride:   resd 1
pikapic_saved_block:    resb PIKAPIC_BOX_W * PIKAPIC_BOX_H

section .data
align 4

; First byte: mood threshold.  Second byte: column index in the table below.
PikachuMoodLookupTable:
    db  40, 1
    db 127, 2
    db 128, 3
    db 210, 4
    db 255, 5

; First byte: happiness threshold.  Remaining five: the PikaPicAnimPointers index
; to run, selected by Pikachu's mood column.  Six bytes per row — the `ld bc, 6`
; stride in GetPikaPicAnimationScriptIndex.  pret writes these through `dpikapic`,
; which resolves to the script's position in PikaPicAnimPointers; that table is
; PikaPicAnimScript0..29 in order, so the index IS the script number.
PikaPicAnimationScriptPointerLookupTable:
    db  50
    db 14, 14,  6, 13, 13
    db 100
    db  9,  9,  5, 12, 12
    db 130
    db  3,  3,  1,  8,  8
    db 160
    db  3,  3,  4, 15, 15
    db 200
    db 17, 17,  7,  2,  2
    db 250
    db 17, 17, 16, 10, 10
    db 255
    db 17, 17, 19, 20, 20

; pret builds this with the `pikapic_def` macro (dw per entry).  Flat `dd` here:
; LoadCurrentPikaPicAnimScriptPointer indexes it by 4, not pret's 2.
PikaPicAnimPointers:
    dd PikaPicAnimScript0,  PikaPicAnimScript1,  PikaPicAnimScript2
    dd PikaPicAnimScript3,  PikaPicAnimScript4,  PikaPicAnimScript5
    dd PikaPicAnimScript6,  PikaPicAnimScript7,  PikaPicAnimScript8
    dd PikaPicAnimScript9,  PikaPicAnimScript10, PikaPicAnimScript11
    dd PikaPicAnimScript12, PikaPicAnimScript13, PikaPicAnimScript14
    dd PikaPicAnimScript15, PikaPicAnimScript16, PikaPicAnimScript17
    dd PikaPicAnimScript18, PikaPicAnimScript19, PikaPicAnimScript20
    dd PikaPicAnimScript21, PikaPicAnimScript22, PikaPicAnimScript23
    dd PikaPicAnimScript24, PikaPicAnimScript25, PikaPicAnimScript26
    dd PikaPicAnimScript27, PikaPicAnimScript28, PikaPicAnimScript29

; RunPikaPicAnimSetupScript's command dispatch.  pret's `dw` + JumpToAddress
; becomes an indirect `call` through a flat table.
PikaPicAnimSetupJumptable:
    dd PikaPicAnimCommand_nop           ; 00, 0 params
    dd PikaPicAnimCommand_writebyte     ; 01, 1 param
    dd PikaPicAnimCommand_loadgfx       ; 02, 1 param
    dd PikaPicAnimCommand_object        ; 03, 5 params
    dd PikaPicAnimCommand_nop4          ; 04, 0 params
    dd PikaPicAnimCommand_nop5          ; 05, 0 params
    dd PikaPicAnimCommand_deleteobject  ; 06, 1 param
    dd PikaPicAnimCommand_nop7          ; 07, 0 params
    dd PikaPicAnimCommand_nop8          ; 08, 0 params
    dd PikaPicAnimCommand_jump          ; 09, 1 dd param (pret: 1 dw param)
    dd PikaPicAnimCommand_setduration   ; 0a, 1 dw param
    dd PikaPicAnimCommand_cry           ; 0b, 1 param
    dd PikaPicAnimCommand_thunderbolt   ; 0c, 0 params
    dd PikaPicAnimCommand_run           ; 0d, 0 params (ret)
    dd PikaPicAnimCommand_ret           ; 0e, 0 params (ret)

section .text

; ===========================================================================
; GetPikaPicAnimationScriptIndex — pret :1.
; Pick the portrait script from the mood x happiness matrix.  Out: AL = index.
; ===========================================================================
GetPikaPicAnimationScriptIndex:
    mov esi, PikachuMoodLookupTable         ; ld hl, PikachuMoodLookupTable
    mov al, [ebp + wPikachuMood]            ; ld a, [wPikachuMood]
    mov dh, al                              ; ld d, a
.get_mood_param:
    mov al, [esi]                           ; ld a, [hli]
    add esi, 2                              ;   ... and the following inc hl
    cmp al, dh                              ; cp d
    jb .get_mood_param                      ; jr c, .get_mood_param
    dec esi                                 ; dec hl
    mov dl, [esi]                           ; ld e, [hl] — the mood column
    mov esi, PikaPicAnimationScriptPointerLookupTable
    mov al, [ebp + wPikachuHappiness]       ; ld a, [wPikachuHappiness]
    mov dh, al                              ; ld d, a
    mov bx, 6                               ; ld bc, 6
.get_happiness_param:
    mov al, [esi]                           ; ld a, [hl]
    cmp al, dh                              ; cp d
    jae .got_animation                      ; jr nc, .got_animation
    movzx ecx, bx
    add esi, ecx                            ; add hl, bc
    jmp .get_happiness_param
.got_animation:
    mov dh, 0                               ; ld d, 0
    movzx ecx, dx                           ; add hl, de
    add esi, ecx
    mov al, [esi]                           ; ld a, [hl]
    ret

; ===========================================================================
; StarterPikachuEmotionCommand_pikapic — pret :90.
; Emotion-script command 5.  In: EDX = the emotion script cursor (flat, phase 3).
; ===========================================================================
StarterPikachuEmotionCommand_pikapic:
    mov al, [ebp + hAutoBGTransferEnabled]  ; ldh a, [hAutoBGTransferEnabled]
    push eax                                ; push af
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al  ; ldh [hAutoBGTransferEnabled], a
    mov al, [edx]                           ; ld a, [de]
    mov [ebp + wPikaPicAnimNumber], al      ; ld [wPikaPicAnimNumber], a
    inc edx                                 ; inc de
    push edx                                ; push de
    call .RunPikapic
    pop edx                                 ; pop de
    pop eax                                 ; pop af
    mov [ebp + hAutoBGTransferEnabled], al
    ret

.RunPikapic:
    call pikapic_window_enter               ; PORT-ONLY presentation — see the header
    call PlacePikapicTextBoxBorder
    call LoadOverworldPikachuFrontpicPalettes   ; pret: callfar
    call ResetPikaPicAnimBuffer
    call LoadCurrentPikaPicAnimScriptPointer
    call ExecutePikaPicAnimScript
    call PlacePikapicTextBoxBorder
    call RunDefaultPaletteCommand
    call pikapic_window_exit                ; PORT-ONLY presentation
    ret

; ===========================================================================
; ResetPikaPicAnimBuffer — pret :115.
; ===========================================================================
ResetPikaPicAnimBuffer:
    mov esi, wCurPikaMovementData
    mov bx, wCurPikaMovementDataEnd - wCurPikaMovementData
    xor al, al
    call FillMemory
    mov esi, wPikaPicAnimObjectDataBufferSize
    mov bx, wPikaPicAnimObjectDataBufferEnd - wPikaPicAnimObjectDataBufferSize
    xor al, al
    call FillMemory
    call ClearPikaPicUsedGFXBuffer
    mov byte [ebp + wPikaPicAnimTimer], 100      ; ld hl, 100 / ld a, l
    mov byte [ebp + wPikaPicAnimTimer + 1], 0    ;             ld a, h
    ; ; PROJ overworld-ui (pikapic cel draw start): GB(7,6) --(center, X+10, Y+0)--> canvas (17,6)
    ; The cel origin must carry the frame's projection: .GetStartCoords builds its
    ; destination arithmetically from these two bytes, so leaving X at pret's $7
    ; would draw every cel ten columns left of its own frame.
    mov byte [ebp + wPikaPicPikaDrawStartX], 0x7 + 10
    mov byte [ebp + wPikaPicPikaDrawStartY], 0x6
    ret

; ===========================================================================
; PlacePikapicTextBoxBorder — pret :136.  Draw the 7x7 portrait frame.
; ===========================================================================
PlacePikapicTextBoxBorder:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    ; ; PROJ overworld-ui (pikapic frame): GB(6,5) 7x7 --(center, X+10, Y+0)--> wx=135 wy=40 clip=56 max_y=96
    mov esi, PIKAPIC_BOX_OFS                ; pret: hlcoord 6, 5
    mov bh, 5                               ; lb bc, 5, 5 — interior height
    mov bl, 5                               ;             — interior width
    call TextBoxBorder
    call Delay3
    call UpdateSprites
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call pikapic_mirror                     ; PORT-ONLY: the transfer pret just re-enabled
    call Delay3
    ret

; ===========================================================================
; LoadCurrentPikaPicAnimScriptPointer — pret :149.
; ===========================================================================
LoadCurrentPikaPicAnimScriptPointer:
    mov al, [ebp + wPikaPicAnimNumber]
    cmp al, 0x1D                            ; cp $1d
    jb .valid                               ; jr c, .valid
    mov al, 0
.valid:
    movzx eax, al
    mov esi, [PikaPicAnimPointers + eax*4]  ; pret: add hl,de twice then ld a,[hli]/ld h,[hl]
    call UpdatePikaPicAnimPointer
    ret

; ===========================================================================
; ExecutePikaPicAnimScript — pret :203.  The per-frame loop.
; ===========================================================================
ExecutePikaPicAnimScript:
.loop:
    xor al, al
    mov [ebp + hAutoBGTransferEnabled], al
    call RunPikaPicAnimSetupScript
    call DummyFunction_fdad5
    call AnimateCurrentPikaPicAnimFrame
    call DummyFunction_fdad5
    mov byte [ebp + hAutoBGTransferEnabled], 1
    call pikapic_mirror                     ; PORT-ONLY: see the presentation header
    call PikaPicAnimTimerAndJoypad
    test al, al                             ; and a
    jz .loop                                ; jr z, .loop
    ret

; ===========================================================================
; PikaPicAnimTimerAndJoypad — pret :218.  Out: AL != 0 to stop.
; ===========================================================================
PikaPicAnimTimerAndJoypad:
    call Delay3
    call CheckPikaPicAnimTimer
    test al, al                             ; and a
    jnz .done                               ; ret nz
    call JoypadLowSensitivity
    mov al, [ebp + hJoyPressed]
    and al, PAD_A | PAD_B
.done:
    ret

; ===========================================================================
; CheckPikaPicAnimTimer — pret :228.  Out: AL = 1 once the 16-bit timer runs out.
; ===========================================================================
CheckPikaPicAnimTimer:
    dec byte [ebp + wPikaPicAnimTimer]      ; dec [hl] — sets ZF, as on the GB
    jnz .not_done_yet                       ; jr nz, .not_done_yet
    mov al, [ebp + wPikaPicAnimTimer + 1]   ; inc hl / ld a, [hl]
    test al, al                             ; and a
    jz .timer_expired                       ; jr z, .timer_expired
    dec byte [ebp + wPikaPicAnimTimer + 1]  ; dec [hl]
.not_done_yet:
    xor al, al
    ret
.timer_expired:
    mov al, 1
    ret

DummyFunction_fdad5:
    ret

; ===========================================================================
; AnimateCurrentPikaPicAnimFrame — pret :248.  Step all four object slots.
;
; Slot layout (pret ram/wram.asm:682): 0 buffer index, 1 script index,
; 2 frame index, 3 frame timer, 4 vtile offset, 5 x offset, 6 y offset, 7 unused.
; ===========================================================================
AnimateCurrentPikaPicAnimFrame:
    mov ebx, wPikaPicAnimObjectDataBuffer   ; ld bc, wPikaPicAnimObjectDataBuffer
    mov al, PIKAPIC_OBJECT_SLOTS            ; ld a, 4
.loop:
    push eax                                ; push af
    push ebx                                ; push bc
    mov esi, ebx                            ; ld hl, 0 / add hl, bc
    mov al, [ebp + esi]                     ; ld a, [hli]
    inc esi
    test al, al                             ; and a
    jz .skip                                ; jr z, .skip
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectScriptIdx], al
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectFrameIdx], al
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectFrameTimer], al
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectVTileOffset], al
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectXOffset], al
    mov al, [ebp + esi]
    inc esi
    mov [ebp + wCurPikaPicAnimObjectYOffset], al
    mov al, [ebp + esi]
    mov [ebp + wCurPikaPicAnimObject + 6], al
    push ebx                                ; push bc
    call LoadPikaPicAnimObjectData
    pop ebx                                 ; pop bc
    lea esi, [ebx + 1]                      ; ld hl, 1 / add hl, bc
    mov al, [ebp + wCurPikaPicAnimObjectScriptIdx]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObjectFrameIdx]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObjectFrameTimer]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObjectVTileOffset]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObjectXOffset]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObjectYOffset]
    mov [ebp + esi], al
    inc esi
    mov al, [ebp + wCurPikaPicAnimObject + 6]
    mov [ebp + esi], al
.skip:
    pop ebx                                 ; pop bc
    add ebx, PIKAPIC_OBJECT_STRUCT_SIZE     ; ld hl, 8 / add hl, bc / ld b,h / ld c,l
    pop eax                                 ; pop af
    dec al                                  ; dec a — 8-bit, as on the GB
    jnz .loop
    ret

; ===========================================================================
; PikaPicAnimCommand_object — pret :303.  Register an animation object.
; Out: CF set if all four slots are taken.
; ===========================================================================
PikaPicAnimCommand_object:
    mov esi, wPikaPicAnimObjectDataBuffer   ; ld hl, wPikaPicAnimObjectDataBuffer
    mov cl, PIKAPIC_OBJECT_SLOTS            ; ld c, 4
.loop:
    mov al, [ebp + esi]                     ; ld a, [hl]
    test al, al                             ; and a
    jz .found                               ; jr z, .found
    add esi, PIKAPIC_OBJECT_STRUCT_SIZE     ; add hl, de (de = 8)
    dec cl                                  ; dec c
    jnz .loop
    stc                                     ; scf
    ret

.found:
    mov al, [ebp + wPikaPicAnimObjectDataBufferSize]
    inc al
    mov [ebp + wPikaPicAnimObjectDataBufferSize], al
    mov [ebp + esi], al                     ; ld [hli], a
    inc esi
    call GetPikaPicAnimByte
    mov [ebp + esi], al                     ; ld [hli], a
    inc esi
    call GetPikaPicAnimByte
    mov [ebp + esi], al                     ; ld [hl], a — no advance, overwritten below
    xor al, al
    mov [ebp + esi], al                     ; ld [hli], a ; overloads
    inc esi
    mov [ebp + esi], al                     ; ld [hli], a
    inc esi
    call GetPikaPicAnimByte
    mov [ebp + esi], al
    inc esi
    call GetPikaPicAnimByte
    mov [ebp + esi], al
    inc esi
    call GetPikaPicAnimByte
    mov [ebp + esi], al
    inc esi
    and al, al                              ; and a — clears CF (success)
    ret

; ===========================================================================
; PikaPicAnimCommand_deleteobject — pret :338.  Out: CF set if not found.
; ===========================================================================
PikaPicAnimCommand_deleteobject:
    call GetPikaPicAnimByte
    mov bh, al                              ; ld b, a
    mov esi, wPikaPicAnimObjectDataBuffer
    mov cl, PIKAPIC_OBJECT_SLOTS            ; ld c, 4
.search:
    mov al, [ebp + esi]                     ; ld a, [hl]
    cmp al, bh                              ; cp b
    je .delete                              ; jr z, .delete
    add esi, PIKAPIC_OBJECT_STRUCT_SIZE     ; add hl, de
    dec cl
    jnz .search
    stc                                     ; scf
    ret

.delete:
    xor al, al
    mov [ebp + esi], al                     ; ld [hl], a
    ret

; ===========================================================================
; LoadPikaPicAnimObjectData — pret :359.  Advance one object's frame list and
; stamp its current cel.
; ===========================================================================
LoadPikaPicAnimObjectData:
.loop:
    mov al, [ebp + wCurPikaPicAnimObjectScriptIdx]
    cmp al, 0x23                            ; cp $23
    jb .valid                               ; jr c, .valid
    mov al, 0x4                             ; ld a, $4
.valid:
    movzx eax, al                           ; ld e, a / ld d, 0
    ; pret: `ld hl, PikaPicAnimBGFramesPointers / add hl,de / add hl,de` — a dw
    ; table.  Flat `dd` here, so the index scales by 4.
    mov esi, [PikaPicAnimBGFramesPointers + eax*4]
    movzx eax, byte [ebp + wCurPikaPicAnimObjectFrameIdx]
    lea esi, [esi + eax*2]                  ; add hl,de / add hl,de — a 2-byte ENTRY,
                                            ; not a pointer table: stride stays 2
    mov al, [esi]                           ; ld a, [hli] — the cel's tilemap index
    inc esi
    cmp al, 0xE0                            ; cp $e0
    je .end                                 ; jr z, .end
    jmp .init                               ; jr .init

.end:
    xor al, al
    mov [ebp + wCurPikaPicAnimObjectFrameIdx], al
    mov [ebp + wCurPikaPicAnimObjectFrameTimer], al
    jmp .loop                               ; jr .loop

.init:
    push esi                                ; push hl
    call LoadCurPikaPicObjectTilemap        ; AL = tilemap index
    pop esi                                 ; pop hl
    mov al, [esi]                           ; ld a, [hl] — this cel's duration
    test al, al                             ; and a
    jz .not_done                            ; jr z, .not_done — lasts forever
    mov al, [ebp + wCurPikaPicAnimObjectFrameTimer]
    inc al
    mov [ebp + wCurPikaPicAnimObjectFrameTimer], al
    cmp al, [esi]                           ; cp [hl]
    jne .not_done                           ; jr nz, .not_done
    xor al, al
    mov [ebp + wCurPikaPicAnimObjectFrameTimer], al
    mov al, [ebp + wCurPikaPicAnimObjectFrameIdx]
    inc al
    mov [ebp + wCurPikaPicAnimObjectFrameIdx], al
.not_done:
    ret

; ===========================================================================
; LoadCurPikaPicObjectTilemap — pret :412.  Stamp one cel into wTileMap.
; In: AL = tilemap index (0 = nothing to draw).
; ===========================================================================
LoadCurPikaPicObjectTilemap:
    test al, al                             ; and a
    jz .ret                                 ; ret z
    movzx eax, al                           ; ld e, a / ld d, 0
    ; pret: a dw table indexed by 2.  Flat `dd` here, so index by 4.
    mov edx, [PikaPicTilemapPointers + eax*4]   ; ld e,[hl] / inc hl / ld d,[hl]
    mov bl, [edx]                           ; ld a,[de] / ld c,a — rows
    inc edx
    mov bh, [edx]                           ; ld a,[de] / ld b,a — columns
    inc edx
    push edx                                ; push de
    push ebx                                ; push bc
    call .GetStartCoords
    pop ebx                                 ; pop bc
    pop edx                                 ; pop de
.row:
    push ebx                                ; push bc
    push esi                                ; push hl
    mov al, [ebp + wCurPikaPicAnimObjectVTileOffset]
    mov bl, al                              ; ld c, a — the tile id offset
.col:
    mov al, [edx]                           ; ld a, [de] — the cel is flat .data
    inc edx
    cmp al, 0xFF                            ; cp $ff
    je .skip                                ; jr z, .skip — $ff leaves the cell alone
    add al, bl                              ; add c
    mov [ebp + esi], al                     ; ld [hl], a
.skip:
    inc esi                                 ; inc hl
    dec bh                                  ; dec b
    jnz .col                                ; jr nz, .col
    pop esi                                 ; pop hl
    add esi, SCREEN_WIDTH                   ; ld bc, SCREEN_WIDTH / add hl, bc
                                            ; SCREEN_WIDTH is a STRIDE (40), not a
                                            ; coordinate — pret's 20 must NOT be used
    pop ebx                                 ; pop bc
    dec bl                                  ; dec c
    jnz .row                                ; jr nz, .row
.ret:
    ret

.GetStartCoords:
    push ebx                                ; push bc
    mov al, [ebp + wCurPikaPicAnimObjectYOffset]
    mov bh, al                              ; ld b, a
    mov al, [ebp + wPikaPicPikaDrawStartY]  ; already projected — see ResetPikaPicAnimBuffer
    add al, bh                              ; add b
    mov esi, wTileMap                       ; hlcoord 0, 0
    mov bx, SCREEN_WIDTH                    ; ld bc, SCREEN_WIDTH
    call AddNTimes                          ; ESI += BX * AL
    mov al, [ebp + wCurPikaPicAnimObjectXOffset]
    mov bl, al                              ; ld c, a
    mov al, [ebp + wPikaPicPikaDrawStartX]  ; already projected (+10)
    add al, bl                              ; add c
    mov bl, al                              ; ld c, a
    mov bh, 0                               ; ld b, 0
    movzx ecx, bx
    add esi, ecx                            ; add hl, bc
    pop ebx                                 ; pop bc
    ret

; ===========================================================================
; LoadPikaPicAnimGFXHeader — pret :479.
; In:  AL = graphic id.
; Out: BL = size in tiles ($FF = compressed), BH = bank (flat-model bookkeeping),
;      ECX = byte length (port-only field), EDX = flat source pointer.
; ===========================================================================
LoadPikaPicAnimGFXHeader:
    push esi                                ; push hl
    movzx eax, al                           ; ld e, a / ld d, 0
    imul eax, eax, PIKAPIC_GFX_HEADER_STRIDE  ; pret: add hl,de four times (stride 4)
    lea esi, [PikaPicAnimGFXHeaders + eax]
    mov bl, [esi]                           ; ld a,[hli] / ld c,a
    mov bh, [esi + 1]                       ; ld a,[hli] / ld b,a
    movzx ecx, word [esi + 2]               ; port-only: the blob's byte length
    mov edx, [esi + 4]                      ; ld a,[hli] / ld e,a / ld a,[hli] / ld d,a
    pop esi                                 ; pop hl
    ret

; ===========================================================================
; RunPikaPicAnimSetupScript — pret :499.  Run bytecode until a `run`/`ret`.
; ===========================================================================
RunPikaPicAnimSetupScript:
    call .CheckAndAdvanceTimer
    jc .done                                ; ret c
    xor al, al
    mov [ebp + wPikaPicAnimPointerSetupFinished], al
.loop:
    call GetPikaPicAnimByte
    movzx eax, al                           ; ld e, a / ld d, 0
    call [PikaPicAnimSetupJumptable + eax*4]    ; pret: dw table + JumpToAddress
    mov al, [ebp + wPikaPicAnimPointerSetupFinished]
    test al, al                             ; and a
    jz .loop                                ; jr z, .loop
.done:
    ret

.CheckAndAdvanceTimer:
    mov al, [ebp + wPikaPicAnimDelay]
    test al, al                             ; and a — also clears CF, as pret's does
    jz .no_delay                            ; ret z
    dec al
    mov [ebp + wPikaPicAnimDelay], al
    stc                                     ; scf
    ret
.no_delay:
    ret                                     ; CF still clear from the `test`

PikaPicAnimCommand_nop:
    ret

PikaPicAnimCommand_ret:
    mov byte [ebp + wPikaPicAnimTimer], 1
    mov byte [ebp + wPikaPicAnimTimer + 1], 0
    jmp PikaPicAnimCommand_run              ; jr PikaPicAnimCommand_run

PikaPicAnimCommand_setduration:
    call GetPikaPicAnimByte
    mov [ebp + wPikaPicAnimTimer], al
    call GetPikaPicAnimByte
    mov [ebp + wPikaPicAnimTimer + 1], al
    ret

PikaPicAnimCommand_run:
    mov byte [ebp + wPikaPicAnimPointerSetupFinished], 0xFF
    ret

PikaPicAnimCommand_writebyte:
    call GetPikaPicAnimByte
    mov [ebp + wPikaPicAnimDelay], al
    ret

PikaPicAnimCommand_nop4:
PikaPicAnimCommand_nop5:
PikaPicAnimCommand_nop7:
PikaPicAnimCommand_nop8:
    ret

; pret reads a 2-byte GB address here with two GetPikaPicAnimByte calls; the port's
; operand is a 4-byte flat pointer (see the data carrier's jump DEVIATION), so it
; is taken from the cursor in one read.
PikaPicAnimCommand_jump:
    mov esi, [pikapic_anim_ptr]
    mov esi, [esi]
    call UpdatePikaPicAnimPointer
    ret

; ===========================================================================
; GetPikaPicAnimByte / UpdatePikaPicAnimPointer — pret :590 / :601.
; ===========================================================================
GetPikaPicAnimByte:
    push esi                                ; push hl
    mov esi, [pikapic_anim_ptr]             ; ld hl, wPikaPicAnimPointer / ld a,[hli] / ld h,[hl]
    mov al, [esi]                           ; ld a, [hli]
    inc esi
    call UpdatePikaPicAnimPointer           ; preserves AL, as pret's push af does
    pop esi                                 ; pop hl
    ret

UpdatePikaPicAnimPointer:
    push eax                                ; push af
    mov [pikapic_anim_ptr], esi
    mov [ebp + wPikaPicAnimPointer], si     ; pret's named store, write-only shadow
    pop eax                                 ; pop af
    ret

; ===========================================================================
; PikaPicAnimCommand_loadgfx — pret :610.
; ===========================================================================
PikaPicAnimCommand_loadgfx:
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax                                ; push af
    mov byte [ebp + wUpdateSpritesEnabled], 0xFF
    mov al, [ebp + hAutoBGTransferEnabled]
    push eax                                ; push af
    mov byte [ebp + hAutoBGTransferEnabled], 0
    mov al, [ebp + hTileAnimations]
    push eax                                ; push af
    mov byte [ebp + hTileAnimations], 0
    call GetPikaPicAnimByte
    mov [ebp + wPikaPicAnimCurGraphicID], al
    mov al, [ebp + wPikaPicAnimCurGraphicID]
    call LoadPikaPicAnimGFXHeader
    mov al, bl                              ; ld a, c
    cmp al, 0xFF                            ; cp $ff
    je .compressed                          ; jr z, .compressed
    call RequestPikaPicAnimGFX
    jmp .done

.compressed:
    call DecompressRequestPikaPicAnimGFX
.done:
    pop eax
    mov [ebp + hTileAnimations], al
    pop eax
    mov [ebp + hAutoBGTransferEnabled], al
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    ret

; ===========================================================================
; RequestPikaPicAnimGFX — pret :644.  Uncompressed blob straight to VRAM.
; In: BL = size (tiles), BH = bank, EDX = flat source.
; ===========================================================================
RequestPikaPicAnimGFX:
    push edx                                ; push de
    mov al, [ebp + wPikaPicAnimCurGraphicID]
    mov dh, al                              ; ld d, a
    mov dl, bl                              ; ld e, c
    call CheckIfThereIsRoomForPikaPicAnimGFX
    pop edx                                 ; pop de — `pop` touches no flag, so the
                                            ; carry the call returned survives, on
                                            ; both machines
    jc .failed                              ; jr c, .failed
    call GetPikaPicVRAMAddressForNewGFX     ; AL = tile offset -> ESI = VRAM address
    call CopyVideoDataAlternate             ; arms g_tilecache_dirty via CopyVideoData
    and al, al                              ; and a — clear CF
.failed:
    ret

; ===========================================================================
; DecompressRequestPikaPicAnimGFX — pret :658.  Compressed .pic to VRAM.
; In: BH = bank, ECX = byte length, EDX = flat source.
; ===========================================================================
DecompressRequestPikaPicAnimGFX:
    push edx                                ; push de
    push ecx                                ; port-only: keep the staging length
    mov al, [ebp + wPikaPicAnimCurGraphicID]
    mov dh, al                              ; ld d, a
    mov dl, 5 * 5                           ; ld e, 5 * 5
    call CheckIfThereIsRoomForPikaPicAnimGFX
    pop ecx
    pop edx                                 ; pop de
    jc .failed                              ; jr c, .failed
    mov al, bh                              ; ld a, b — the bank; a no-op flat
    call UncompressSpriteFromDE             ; EDX flat src, ECX length
    ; pret's OpenSRAM/CloseSRAM bracket, restored 2026-08-23. The old comment
    ; here said the port "has no bank switch, so the sprite buffers are always
    ; mapped" — still true of ADDRESSING, but no longer the whole story: these
    ; calls now drive the SRAM write-protect latch (src/home/bankswitch2.asm),
    ; and the sprite buffers ARE SRAM bank 0.
    mov al, SRAM_BANK_SPRITE_BUFFERS        ; ld a, BANK("Sprite Buffers")
    call OpenSRAM
    mov esi, sSpriteBuffer1                 ; ld hl, sSpriteBuffer1
    mov edx, sSpriteBuffer0                 ; ld de, sSpriteBuffer0
    mov bx, SPRITEBUFFERSIZE * 2            ; ld bc, SPRITEBUFFERSIZE * 2
    call CopyData
    call CloseSRAM                          ; pret: call CloseSRAM
    mov al, [ebp + wPikaPicAnimCurGraphicID]
    call LookUpTileOffsetForCurrentPikaPicAnimGFX
    call GetPikaPicVRAMAddressForNewGFX     ; ESI = VRAM address
    mov [pic_dest], esi                     ; pret passes the destination in de; the
                                            ; port's InterlaceMergeSpriteBuffers takes
                                            ; it from pic_dest (src/home/pics.asm)
    call InterlaceMergeSpriteBuffers        ; arms g_tilecache_dirty itself
.failed:
    ret

ClearPikaPicUsedGFXBuffer:
    mov esi, wPikaPicUsedGFXCount
    mov bx, wPikaPicUsedGFXEnd - wPikaPicUsedGFXCount
    xor al, al
    call FillMemory
    ret

; ===========================================================================
; GetPikaPicVRAMAddressForNewGFX — pret :691.
; In: AL = tile offset.  Out: ESI = vNPCSprites + offset * 16.
; ===========================================================================
GetPikaPicVRAMAddressForNewGFX:
    mov esi, vNPCSprites                    ; ld hl, vNPCSprites
    push ebx                                ; push bc
    mov bh, al                              ; ld b, a
    and al, 0x0F                            ; and $f
    rol al, 4                               ; swap a
    mov bl, al                              ; ld c, a
    mov al, bh                              ; ld a, b
    and al, 0xF0                            ; and $f0
    rol al, 4                               ; swap a
    mov bh, al                              ; ld b, a
    movzx ecx, bx
    add esi, ecx                            ; add hl, bc
    pop ebx                                 ; pop bc
    ret

; ===========================================================================
; CheckIfThereIsRoomForPikaPicAnimGFX — pret :706.
; In: DH = graphic id, DL = size in tiles.
; Out: AL = the tile offset to load at, CF set on failure.
;
; GLITCH{class=data-model; pret=engine/pikachu/pikachu_pic_animation.asm:CheckIfThereIsRoomForPikaPicAnimGFX; behavior=the table-full and already-loaded exits return without unwinding the two saved registers, so the ret consumes the saved HL as its return address and transfers control to it - reproduced literally here, where the saved ESI is a small GB offset and the transfer faults instead of executing WRAM; evidence=pret's own comment at :709 calls this FATAL and marks both exits execute hl then bc, and the exits are unreachable in practice because ResetPikaPicAnimBuffer clears the used-GFX table before every script and the busiest script PikaPicAnimScript21 loads five distinct graphics against a limit of eight; safety=unreachable on every shipped script, and a fault under DPMI rather than arbitrary execution if it is ever reached; lifetime=permanent, it is the cartridge behaviour}
; ===========================================================================
CheckIfThereIsRoomForPikaPicAnimGFX:
    push ebx                                ; push bc
    push esi                                ; push hl
    mov esi, wPikaPicUsedGFX                ; ld hl, wPikaPicUsedGFX
    mov cl, PIKAPIC_GFX_SLOTS               ; ld c, 8
.loop:
    mov al, [ebp + esi]                     ; ld a, [hl]
    test al, al                             ; and a
    jz .empty                               ; jr z, .empty
    cmp al, dh                              ; cp d
    je .found                               ; jr z, .found
    add esi, 2                              ; inc hl / inc hl
    dec cl                                  ; dec c
    jnz .loop
    stc                                     ; scf
    ret                                     ; the pops are deliberately absent — see this routine's annotation

.found:
    inc esi                                 ; inc hl
    mov al, [ebp + esi]                     ; ld a, [hl]
    ret                                     ; the pops are deliberately absent — see this routine's annotation

.empty:
    mov [ebp + esi], dh                     ; ld [hl], d
    inc esi                                 ; inc hl
    mov al, [ebp + wPikaPicUsedGFXCount]
    add al, 0x80                            ; add $80
    mov [ebp + esi], al                     ; ld [hl], a
    mov al, [ebp + wPikaPicUsedGFXCount]
    add al, dl                              ; add e
    mov [ebp + wPikaPicUsedGFXCount], al
    cmp al, 0x80                            ; cp $80
    je .okay                                ; jr z, .okay
    ja .failed                              ; jr nc, .failed
.okay:
    mov al, [ebp + esi]                     ; ld a, [hl]
    and al, al                              ; and a — clears CF
    jmp .pop_ret
.failed:
    stc                                     ; scf
.pop_ret:
    pop esi                                 ; pop hl
    pop ebx                                 ; pop bc
    ret

; ===========================================================================
; LookUpTileOffsetForCurrentPikaPicAnimGFX — pret :758.
; In: AL = graphic id.  Out: AL = its tile offset, CF set if not found.
; ===========================================================================
LookUpTileOffsetForCurrentPikaPicAnimGFX:
    push ebx                                ; push bc
    push esi                                ; push hl
    mov bh, al                              ; ld b, a
    mov esi, wPikaPicUsedGFX
    mov cl, PIKAPIC_GFX_SLOTS               ; ld c, 8
.loop:
    mov al, [ebp + esi]                     ; ld a, [hli]
    inc esi
    cmp al, bh                              ; cp b
    je .found                               ; jr z, .found
    inc esi                                 ; inc hl
    dec cl                                  ; dec c
    jnz .loop
    stc                                     ; scf
    jmp .pop_ret
.found:
    mov al, [ebp + esi]                     ; ld a, [hl]
    and al, al                              ; and a — clears CF
.pop_ret:
    pop esi                                 ; pop hl
    pop ebx                                 ; pop bc
    ret

; ===========================================================================
; PikaPicAnimCommand_cry — pret :782.
; ===========================================================================
PikaPicAnimCommand_cry:
    call GetPikaPicAnimByte
    cmp al, 0xFF                            ; cp $ff
    je .done                                ; ret z
    mov dl, al                              ; ld e, a
    call PlayPikachuSoundClip               ; pret: callfar
.done:
    ret

; ===========================================================================
; PikaPicAnimCommand_thunderbolt — pret :790.
; ===========================================================================
PikaPicAnimCommand_thunderbolt:
    mov byte [ebp + wMuteAudioAndPauseMusic], 1
    call DelayFrame
    mov al, [ebp + wAudioROMBank]
    push eax                                ; push af
    ; BANK(SFX_Battle_2F): pret audio.asm puts "Sound Effect Headers 2" — and so
    ; SFX_Battle_2F — in the Audio Engine 2 bank.  Not cosmetic: src/home/audio.asm
    ; dispatches the engine on wAudioROMBank.
    mov al, AUDIO_BANK_2                    ; ld a, BANK(SFX_Battle_2F)
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    call .LoadAudio
    call PlaySound
    call .FlashScreen
    call WaitForSoundToFinish
    pop eax                                 ; pop af
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    mov byte [ebp + wMuteAudioAndPauseMusic], 0
    ret

.LoadAudio:
    ; pret: hl = MoveSoundTable + THUNDERBOLT*3, read through GetFarByte.  The port
    ; reads the table flat (the same shape engine/battle/animations.asm:GetMoveSound
    ; uses); the three fields are sound id, frequency modifier, tempo modifier.
    mov esi, MoveSoundTable + THUNDERBOLT * 3
    mov bh, [esi]                           ; ld b, a
    mov al, [esi + 1]
    mov [ebp + wFrequencyModifier], al
    mov al, [esi + 2]
    mov [ebp + wTempoModifier], al
    mov al, bh                              ; ld a, b
    ret

.FlashScreen:
    mov esi, PikaPicAnimThunderboltPals     ; ld hl, PikaPicAnimThunderboltPals
.flash_loop:
    mov al, [esi]                           ; ld a, [hli]
    inc esi
    cmp al, 0xFF                            ; cp $ff
    je .flash_done                          ; ret z
    mov bl, al                              ; ld c, a — the frame count
    mov bh, [esi]                           ; ld b, [hl] — the BGP value
    inc esi                                 ; inc hl
    push esi                                ; push hl
    call .UpdatePal
    pop esi                                 ; pop hl
    jmp .flash_loop                         ; jr .loop
.flash_done:
    ret

.UpdatePal:
    mov al, bh                              ; ld a, b
    mov [ebp + IO_BGP], al                  ; ldh [rBGP], a — live: commit_palette
                                            ; picks a BGP change up from DelayFrame
    call UpdateCGBPal_BGP
    call DelayFrames                        ; BL = frame count
    ret

; ===========================================================================
; PORT-ONLY PRESENTATION.  See this file's header for why these exist and why
; neither canvas ownership nor the retired auto-BG transfer is the answer.
; ===========================================================================

; pikapic_window_enter — take the 7x7 canvas block and open the portrait window.
; All registers preserved.
pikapic_window_enter:
    pushad
    mov eax, [g_window_count]
    mov [pikapic_saved_wincount], eax
    mov eax, [text_row_stride]
    mov [pikapic_saved_stride], eax
    ; TextBoxBorder and the cel stamper both write through the shared runtime row
    ; stride; this box is placed on the 40-wide canvas, so it must be 40 here even
    ; when an overworld dialog left it at 20.
    mov dword [text_row_stride], SCREEN_WIDTH
    ; Save the block we are about to draw over.  On hardware the pikapic box (GB
    ; rows 5-11) and the message box (rows 12-17) are disjoint; in the port the
    ; stride-20 dialog scratch and this stride-40 block share wTileMap bytes, so
    ; without this the box would eat the open dialog's scratch.
    lea esi, [ebp + PIKAPIC_BOX_OFS]
    mov edi, pikapic_saved_block
    mov edx, PIKAPIC_BOX_H
.save_row:
    mov ecx, PIKAPIC_BOX_W
    rep movsb
    add esi, SCREEN_WIDTH - PIKAPIC_BOX_W
    dec edx
    jnz .save_row
    ; Append (do NOT collapse): an emotion script may already have a dialog window
    ; open underneath, and add_window leaves hWY/rWX alone so the dialog-open gate
    ; sync_dialog_window reads is undisturbed.
    mov eax, PIKAPIC_WIN_WX
    mov ebx, PIKAPIC_WIN_WY
    mov ecx, PIKAPIC_WIN_CLIP
    mov edx, PIKAPIC_WIN_MAXY
    mov esi, PIKAPIC_WIN_TILEMAP
    mov edi, PIKAPIC_WIN_SROW
    call add_window
    popad
    ret

; pikapic_mirror — carry the 7x7 block into the window's source tilemap.  This is
; the port's stand-in for the VBlank wTileMap -> BG map transfer pret re-enables
; around each frame.  All registers preserved.
pikapic_mirror:
    pushad
    lea esi, [ebp + PIKAPIC_BOX_OFS]
    lea edi, [ebp + PIKAPIC_WIN_TILEMAP + PIKAPIC_WIN_SROW * TILEMAP_W]
    mov edx, PIKAPIC_BOX_H
.row:
    mov ecx, PIKAPIC_BOX_W
    rep movsb
    add esi, SCREEN_WIDTH - PIKAPIC_BOX_W
    add edi, TILEMAP_W - PIKAPIC_BOX_W
    dec edx
    jnz .row
    popad
    ret

; pikapic_window_exit — restore the window list, the row stride and the block.
; All registers preserved.
pikapic_window_exit:
    pushad
    mov esi, pikapic_saved_block
    lea edi, [ebp + PIKAPIC_BOX_OFS]
    mov edx, PIKAPIC_BOX_H
.restore_row:
    mov ecx, PIKAPIC_BOX_W
    rep movsb
    add edi, SCREEN_WIDTH - PIKAPIC_BOX_W
    dec edx
    jnz .restore_row
    mov eax, [pikapic_saved_stride]
    mov [text_row_stride], eax
    mov eax, [pikapic_saved_wincount]
    mov [g_window_count], eax
    popad
    ret
