; intro_yellow.asm — the Yellow intro's animated-object behavior callbacks.
;
; Faithful translation of the animated-object jumptable + callbacks + sine
; helpers from pret engine/movie/intro_yellow.asm (menu-intro B3.1). These are
; the per-object behaviors ExecuteCurrentAnimatedObjectCallback dispatches to
; (via YellowIntro_AnimatedObjectJumptable). The scene engine (PlayIntroScene,
; InitYellowIntroGFXAndMusic, scene dispatch 0-17, Func_fa06e, gfx/tilemaps)
; rides later B3 increments; this file will grow to hold them.
;
; Register map (as reached from the engine): EBX = current-struct base (pret BC),
; ESI = HL, EDX = DE, AL = A, EBP = GB base. Struct byte offsets are raw literals
; exactly as pret: 4 XCoord, 5 YCoord, 7 YOffset, b FieldB, c FieldC.
;
; Build: nasm -f coff -I include/ -I . -o intro_yellow.o \
;        src/engine/movie/intro_yellow.asm

bits 32

%include "gb_memmap.inc"

global YellowIntro_AnimatedObjectJumptable
global Func_fa007, Func_fa008, Func_fa014, Func_fa02b, Func_fa062
global Func_fa03f, Func_fa051, Func_fa077, Func_fa079, Func_fa08e
global Func_f98a2, Func_f98cb, YellowIntro_NextScene
global LoadYellowIntroObjectAnimationDataPointers
global YellowIntro_SpawnAnimatedObjectAndSavePointer, YellowIntro_MaskCurrentAnimatedObjectStruct
global YellowIntro_SetTimerFor128Frames, YellowIntro_SetTimerFor88Frames
global YellowIntro_CheckFrameTimerDecrement
global YellowIntroScene1, YellowIntroScene5, YellowIntroScene9
global YellowIntroScene13, YellowIntroScene17, YellowIntroScene3
global Func_fa06e, YellowIntroScene0
global YellowIntroScene16, YellowIntro_LoadDMGPalAndIncrementCounter

extern YellowIntroFramesData_GB, YellowIntroOAMData_GB, YellowIntroSpawnData_GB
extern SpawnAnimatedObject, MaskCurrentAnimatedObjectStruct, MaskAllAnimatedObjectStructs
extern DelayFrames
extern UpdateCGBPal_BGP, UpdateCGBPal_OBP0, UpdateCGBPal_OBP1

; wShadowOAM per-sprite attribute bytes (wShadowOAM + N*4 + 3). Pret names kept.
%define wShadowOAMSpriteAttr(n) (W_SHADOW_OAM + (n)*4 + 3)
%define wShadowOAMSprite08Attributes wShadowOAMSpriteAttr(8)
%define wShadowOAMSprite14Attributes wShadowOAMSpriteAttr(14)
%define wShadowOAMSprite16Attributes wShadowOAMSpriteAttr(16)
%define wShadowOAMSprite18Attributes wShadowOAMSpriteAttr(18)
%define wShadowOAMSprite19Attributes wShadowOAMSpriteAttr(19)
%define wShadowOAMSprite20Attributes wShadowOAMSpriteAttr(20)
%define wShadowOAMSprite25Attributes wShadowOAMSpriteAttr(25)
%define wShadowOAMSprite26Attributes wShadowOAMSpriteAttr(26)
%define wShadowOAMSprite28Attributes wShadowOAMSpriteAttr(28)

section .text

; ---------------------------------------------------------------------------
; LoadYellowIntroObjectAnimationDataPointers — point the animated-object engine
; at the Yellow-intro tables. MUST run after ClearObjectAnimationBuffers, which
; zeroes the block these pointers live in. Spawn/OAM/Frames are 16-bit GB
; addresses into the copied blob; the jumptable is a 32-bit flat pointer (B1
; data-model split).
; ---------------------------------------------------------------------------
LoadYellowIntroObjectAnimationDataPointers:
    ; The GB addresses are external absolutes; COFF has no 16-bit relocation, so
    ; load each into EAX (32-bit reloc) and store its low word.
    mov eax, YellowIntroSpawnData_GB
    mov [ebp + wAnimatedObjectSpawnStateDataPointer], ax
    mov dword [ebp + wAnimatedObjectJumptablePointer], YellowIntro_AnimatedObjectJumptable
    mov eax, YellowIntroOAMData_GB
    mov [ebp + wAnimatedObjectOAMDataPointer], ax
    mov eax, YellowIntroFramesData_GB
    mov [ebp + wAnimatedObjectFramesDataPointer], ax
    ret

; ---------------------------------------------------------------------------
; Func_f98a2 — scene-7 hook: set the BG-priority bit (OAM attr bit 0) on the
; surfing-Pikachu OBJ so the wave BG draws over them.
; ---------------------------------------------------------------------------
Func_f98a2:
    mov al, [ebp + wShadowOAMSprite08Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite08Attributes], al
    mov al, [ebp + wShadowOAMSprite14Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite14Attributes], al
    mov al, [ebp + wShadowOAMSprite16Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite16Attributes], al
    mov al, [ebp + wShadowOAMSprite18Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite18Attributes], al
    mov al, [ebp + wShadowOAMSprite19Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite19Attributes], al
    ret

; ---------------------------------------------------------------------------
; Func_f98cb — scene-0xb hook: same BG-priority bit on the flying-Pikachu OBJ.
; ---------------------------------------------------------------------------
Func_f98cb:
    mov al, [ebp + wShadowOAMSprite18Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite18Attributes], al
    mov al, [ebp + wShadowOAMSprite19Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite19Attributes], al
    mov al, [ebp + wShadowOAMSprite20Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite20Attributes], al
    mov al, [ebp + wShadowOAMSprite25Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite25Attributes], al
    mov al, [ebp + wShadowOAMSprite26Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite26Attributes], al
    mov al, [ebp + wShadowOAMSprite28Attributes]
    or al, 0x1
    mov [ebp + wShadowOAMSprite28Attributes], al
    ret

; ---------------------------------------------------------------------------
; YellowIntro_NextScene — advance to the next intro scene.
; ---------------------------------------------------------------------------
YellowIntro_NextScene:
    inc byte [ebp + wYellowIntroCurrentScene]      ; ld hl, .. / inc [hl]
    ; vc_hook Reduce_intro_scene_flashing_0E — VC patch hook, no-op in the port
    ret

; ---------------------------------------------------------------------------
; YellowIntro_SpawnAnimatedObjectAndSavePointer — spawn an object (index AL,
; coords DX) and remember its struct base for the scene to mask later.
; ---------------------------------------------------------------------------
YellowIntro_SpawnAnimatedObjectAndSavePointer:
    call SpawnAnimatedObject                        ; EBX = struct base on success
    mov [ebp + wYellowIntroAnimatedObjectStructPointer], bx  ; ld [ptr],c / ld [ptr+1],b
    ret

; ---------------------------------------------------------------------------
; YellowIntro_MaskCurrentAnimatedObjectStruct — mask the saved object.
; ---------------------------------------------------------------------------
YellowIntro_MaskCurrentAnimatedObjectStruct:
    movzx ebx, word [ebp + wYellowIntroAnimatedObjectStructPointer]  ; bc = saved base
    call MaskCurrentAnimatedObjectStruct
    ret

; ---------------------------------------------------------------------------
; YellowIntro_SetTimerFor128Frames / _SetTimerFor88Frames.
; ---------------------------------------------------------------------------
YellowIntro_SetTimerFor128Frames:
    mov byte [ebp + wYellowIntroSceneTimer], 128
    ret

YellowIntro_SetTimerFor88Frames:
    mov byte [ebp + wYellowIntroSceneTimer], 88
    ret

; ---------------------------------------------------------------------------
; YellowIntro_CheckFrameTimerDecrement — decrement the scene timer; CF set (and
; nothing decremented) once it has reached 0.
; ---------------------------------------------------------------------------
YellowIntro_CheckFrameTimerDecrement:
    mov al, [ebp + wYellowIntroSceneTimer]         ; ld a, [hl]
    test al, al                                    ; and a
    jz .asm_f9e4b                                  ; jr z
    dec byte [ebp + wYellowIntroSceneTimer]        ; dec [hl]
    clc                                            ; and a  (CF = 0)
    ret
.asm_f9e4b:
    ; vc_hook Stop_reducing_intro_scene_flashing_0F — no-op in the port
    stc                                            ; scf
    ret

; ---------------------------------------------------------------------------
; The "wait-last" scenes (odd indices) that only touch the timer/object engine.
; Scenes 3/7/11/15 (hSCX scroll, LY-buffer roll, VBlank cloud copy) and the even
; active scenes ride later B3 increments (HAL). YellowIntro_NextScene advances
; wYellowIntroCurrentScene, so each of these runs once the timer expires.
; ---------------------------------------------------------------------------
YellowIntroScene1:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; ret nc → fall through only when expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

YellowIntroScene5:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

YellowIntroScene9:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    call YellowIntro_MaskCurrentAnimatedObjectStruct
    call YellowIntro_NextScene
    ret

YellowIntroScene13:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired
    ret
.expired:
    mov dh, 0x68                                   ; lb de, $68, $58
    mov dl, 0x58
    mov al, 0x0a
    call SpawnAnimatedObject
    call YellowIntro_NextScene
    ret

YellowIntroScene17:
    mov bl, 64                                     ; ld c, 64
    call DelayFrames
    or byte [ebp + wYellowIntroCurrentScene], 0x80 ; set 7, [hl]  (done flag)
    ret

; Scene 0 — "running Pikachu 1": spawn the object, set scroll/window/palettes to
; the intro defaults, arm a 130-frame timer, advance. (hLCDCPointer=0 disables
; the per-scanline LCDC effect, inert in the port.)
YellowIntroScene0:
    xor al, al
    mov [ebp + H_LCDC_POINTER], al                 ; ldh [hLCDCPointer], a
    mov dh, 0x58                                    ; lb de, $58, $58
    mov dl, 0x58
    mov al, 0x1
    call YellowIntro_SpawnAnimatedObjectAndSavePointer
    xor al, al
    mov [ebp + H_SCX], al                           ; ldh [hSCX], a
    mov [ebp + H_SCY], al                           ; ldh [hSCY], a
    mov al, 0x90
    mov [ebp + H_WY], al                            ; ldh [hWY], a
    mov al, 0xe4
    mov [ebp + IO_BGP], al                          ; ldh [rBGP], a
    mov [ebp + IO_OBP0], al                         ; ldh [rOBP0], a
    mov al, 0xc4
    mov [ebp + IO_OBP1], al                         ; ldh [rOBP1], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    call UpdateCGBPal_OBP1
    mov byte [ebp + wYellowIntroSceneTimer], 130    ; ld a,130 / ld [timer],a
    call YellowIntro_NextScene
    ret

; Scene 3 — hold the "running Pikachu 1" pose while scrolling the BG right to
; hSCX = 0x68, then mask the objects and advance. hSCX is the port's own scroll
; shadow (H_SCX), reconciled to the projected surface by PlayIntroScene.
YellowIntroScene3:
    call YellowIntro_CheckFrameTimerDecrement
    jc .expired                                    ; jr c, .expired
    mov al, [ebp + H_SCX]                          ; ldh a, [hSCX]
    cmp al, 0x68                                   ; cp $68
    je .done                                       ; ret z
    add al, 0x4                                    ; add $4
    mov [ebp + H_SCX], al                          ; ldh [hSCX], a
.done:
    ret
.expired:
    call MaskAllAnimatedObjectStructs
    call YellowIntro_NextScene
    ret

; ---------------------------------------------------------------------------
; Func_fa06e — index a word-pointer table (ESI/HL) by AL and return the entry.
; pret's only caller is the scene dispatcher Func_f98fc, whose table
; (Jumptable_f9906) is a flat 32-bit code-address table in the port.
;
; DEVIATION{class=data-model; pret=engine/movie/intro_yellow.asm:Func_fa06e; behavior=indexes the table at a x4 stride and returns a 32-bit flat entry instead of pret's 2-byte GB pointer at a x2 stride; evidence=its sole caller dispatches the Yellow-intro scene jumptable whose entries are native x86 code addresses (flat link-time labels), same rationale as the animated-object jumptable; lifetime=permanent — intrinsic to running GB code as native x86}
; ---------------------------------------------------------------------------
Func_fa06e:
    movzx eax, al                                  ; ld e,a / ld d,$0  (index)
    mov esi, [esi + eax*4]                          ; hl = table[index]  (flat, x4)
    ret

; ---------------------------------------------------------------------------
; YellowIntro_LoadDMGPalAndIncrementCounter — index a DMG-palette sequence table
; (EDX = flat table ptr) by the scene timer, incrementing it. Out: AL = the
; palette byte, CF set (sequence over) when the byte is 0xff. The pal-sequence
; tables are flat program-image data, so the read is flat (not EBP-relative).
; ---------------------------------------------------------------------------
YellowIntro_LoadDMGPalAndIncrementCounter:
    movzx esi, byte [ebp + wYellowIntroSceneTimer] ; ld a,[hl] / ld l,a / ld h,$0
    inc byte [ebp + wYellowIntroSceneTimer]        ; inc [hl]
    add esi, edx                                   ; add hl, de  (de = flat table)
    mov al, [esi]                                  ; ld a, [hl]  (FLAT read)
    cmp al, 0xff
    je .expired
    clc                                            ; and a
    ret
.expired:
    stc                                            ; scf
    ret

; Scene 16 — "fade to white": step the DMG BGP/OBP0 through YellowIntroPal-
; Sequence_f9e0a one byte per frame until it terminates (0xff), then advance.
YellowIntroScene16:
    mov edx, YellowIntroPalSequence_f9e0a          ; ld de, ...  (flat)
    call YellowIntro_LoadDMGPalAndIncrementCounter
    jc .expired                                    ; jr c, .expired
    mov [ebp + IO_OBP0], al                        ; ldh [rOBP0], a
    mov [ebp + IO_BGP], al                         ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    call UpdateCGBPal_OBP0
    ret
.expired:
    call YellowIntro_NextScene
    ret

; ---------------------------------------------------------------------------
; Func_fa007 — no-op object callback.
; ---------------------------------------------------------------------------
Func_fa007:
    ret

; ---------------------------------------------------------------------------
; Func_fa008 — slide XCoord left toward 0x58, then stop.
; ---------------------------------------------------------------------------
Func_fa008:
    lea esi, [ebx + 4]              ; ld hl,$4/add hl,bc  (XCoord)
    mov al, [ebp + esi]            ; ld a, [hl]
    cmp al, 0x58                   ; cp $58
    je .ret                        ; ret z
    sub al, 0x4                    ; sub $4
    mov [ebp + esi], al            ; ld [hl], a
.ret:
    ret

; ---------------------------------------------------------------------------
; Func_fa014 — slide XCoord right toward 0x58 and YCoord tracks it (A carries
; from the X update into the Y compare, exactly as pret does).
; ---------------------------------------------------------------------------
Func_fa014:
    lea esi, [ebx + 4]             ; XCoord
    mov al, [ebp + esi]
    cmp al, 0x58                   ; cp $58
    je .asm_fa020                  ; jr z
    add al, 0x4                    ; add $4
    mov [ebp + esi], al            ; ld [hl], a  (A stays = XCoord+4)
.asm_fa020:
    lea esi, [ebx + 5]             ; YCoord
    cmp al, 0x58                   ; cp $58  (A from the X path)
    je .ret                        ; ret z
    add al, 0x1                    ; add $1
    mov [ebp + esi], al            ; ld [hl], a
.ret:
    ret

; ---------------------------------------------------------------------------
; Func_fa02b — dispatch on FieldB through the sub-jumptable.
;
; DEVIATION{class=data-model; pret=engine/movie/intro_yellow.asm:Func_fa02b; behavior=the FieldB sub-jumptable Jumptable_fa03b holds 32-bit flat x86 code addresses read at a x4 stride instead of pret's 2-byte GB addresses at a x2 stride; evidence=the jumptable targets are native x86 routines whose addresses are link-time flat labels, same rationale as ExecuteCurrentAnimatedObjectCallback; lifetime=permanent — intrinsic to running GB code as native x86}
; ---------------------------------------------------------------------------
Func_fa02b:
    movzx edx, byte [ebp + ebx + 0x0b]     ; ld hl,$b/add hl,bc/ld e,[hl]/ld d,$0  (FieldB)
    mov esi, [Jumptable_fa03b + edx*4]     ; flat callback address (table + 4*FieldB)
    jmp esi                                ; jp hl

; ---------------------------------------------------------------------------
; Func_fa03f — sub-state 0: slide YCoord up toward 0x58, then advance FieldB and
; fall through into Func_fa051.
; ---------------------------------------------------------------------------
Func_fa03f:
    lea esi, [ebx + 5]             ; YCoord
    mov al, [ebp + esi]
    cmp al, 0x58                   ; cp $58
    je .asm_fa04c                  ; jr z
    sub al, 0x2                    ; sub $2
    mov [ebp + esi], al
    ret
.asm_fa04c:
    inc byte [ebp + ebx + 0x0b]    ; ld hl,$b/add hl,bc/inc [hl]  (FieldB++)
    ; fall through into Func_fa051

; ---------------------------------------------------------------------------
; Func_fa051 — sub-state 1: bob YOffset with a sine of the advancing FieldC.
; ---------------------------------------------------------------------------
Func_fa051:
    lea esi, [ebx + 0x0c]          ; ld hl,$c/add hl,bc  (FieldC)
    mov al, [ebp + esi]           ; ld a, [hl]
    inc byte [ebp + esi]           ; inc [hl]  (FieldC++)
    mov dh, 0x8                    ; ld d, $8  (amplitude)
    call Func_fa079               ; AL = amplitude-scaled sine(FieldC)
    mov [ebp + ebx + 7], al        ; ld hl,$7/add hl,bc/ld [hl],a  (YOffset)
    ret

; ---------------------------------------------------------------------------
; Func_fa062 — XCoord += FieldB.
; ---------------------------------------------------------------------------
Func_fa062:
    mov al, [ebp + ebx + 0x0b]     ; ld hl,$b/add hl,bc/ld a,[hl]  (FieldB)
    lea esi, [ebx + 4]             ; ld hl,$4/add hl,bc  (XCoord)
    add al, [ebp + esi]            ; add [hl]
    mov [ebp + esi], al            ; ld [hl], a
    ret

; ---------------------------------------------------------------------------
; Func_fa077 — cosine entry: phase += 0x10, then sine.
; ---------------------------------------------------------------------------
Func_fa077:                        ; cosine
    add al, 0x10                   ; add $10
    ; fall through into Func_fa079

; ---------------------------------------------------------------------------
; Func_fa079 — sine(AL) scaled by amplitude DH. Out: AL = signed result.
; Phases 0x00-0x1f are the positive half; 0x20-0x3f are negated.
; ---------------------------------------------------------------------------
Func_fa079:
    and al, 0x3f                   ; and $3f
    cmp al, 0x20                   ; cp $20
    jae .asm_fa084                 ; jr nc
    call Func_fa08e               ; ESI = 16-bit product (HL)
    mov eax, esi
    shr eax, 8                     ; ld a, h  (high byte of HL)
    ret
.asm_fa084:
    and al, 0x1f                   ; and $1f
    call Func_fa08e
    mov eax, esi
    shr eax, 8                     ; ld a, h
    xor al, 0xff                   ; xor $ff
    inc al                         ; inc a  (two's-complement negate)
    ret

; ---------------------------------------------------------------------------
; Func_fa08e — 16-bit fixed-point multiply amplitude(DH) * sine_table[AL] via
; shift-add. Out: ESI = 16-bit product (the "HL" pret returns).
; ---------------------------------------------------------------------------
Func_fa08e:
    mov cl, al                     ; ld e, a   (E = phase, stashed)
    mov al, dh                     ; ld a, d   (A = amplitude, the multiplier)
    movzx edx, cl                  ; ld d, $0  (DE = 0:phase)
    mov esi, Unkn_fa0aa            ; ld hl, Unkn_fa0aa (flat sine table)
    lea esi, [esi + edx*2]         ; add hl,de / add hl,de  (hl = table + 2*phase)
    movzx edx, word [esi]          ; ld e,[hl]/inc hl/ld d,[hl]  (DE = sine_table[phase])
    xor edi, edi                   ; ld hl, $0  (HL accumulator)
.asm_fa09d:
    shr al, 1                      ; srl a  (CF = old bit0)
    jnc .asm_fa0a2                 ; jr nc
    add di, dx                     ; add hl, de
.asm_fa0a2:
    shl dx, 1                      ; sla e / rl d  (DE <<= 1, 16-bit)
    test al, al                    ; and a
    jnz .asm_fa09d                 ; jr nz
    movzx esi, di                  ; return HL (product) in ESI
    ret

section .data

; Sub-jumptable for Func_fa02b — flat code addresses (see the DEVIATION above).
Jumptable_fa03b:
    dd Func_fa03f
    dd Func_fa051

; The animated-object callback jumptable — flat 32-bit code addresses, consumed
; by ExecuteCurrentAnimatedObjectCallback (data-model DEVIATION annotated there).
YellowIntro_AnimatedObjectJumptable:
    dd Func_fa007
    dd Func_fa007
    dd Func_fa008
    dd Func_fa014
    dd Func_fa02b
    dd Func_fa062

; Unkn_fa0aa — pret `sine_table 32`: dw sin(x*0.5/32) as RGBDS Q16 fractions,
; i.e. round(sin(pi*x/32) * 65536) & 0xffff for x=0..31. Verified byte-exact
; against rgbasm. (x=16 is 0x0000 — RGBDS truncates sin(0.25turn)=1.0 to the low
; word; faithful to pret.) Read flat by Func_fa08e.
Unkn_fa0aa:
    dw 0x0000, 0x1918, 0x31f1, 0x4a50, 0x61f8, 0x78ad, 0x8e3a, 0xa268
    dw 0xb505, 0xc5e4, 0xd4db, 0xe1c6, 0xec83, 0xf4fa, 0xfb15, 0xfec4
    dw 0x0000, 0xfec4, 0xfb15, 0xf4fa, 0xec83, 0xe1c6, 0xd4db, 0xc5e4
    dw 0xb505, 0xa268, 0x8e3a, 0x78ad, 0x61f8, 0x4a50, 0x31f1, 0x1918

; DMG-palette fade sequences (one byte per frame, 0xff terminates). Flat data,
; read by YellowIntro_LoadDMGPalAndIncrementCounter.
global YellowIntroPalSequence_f9dd6, YellowIntroPalSequence_f9e0a
YellowIntroPalSequence_f9dd6:
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xe4
    db 0xe4, 0xc0, 0xc0, 0xff
YellowIntroPalSequence_f9e0a:
    db 0xe4, 0x90, 0x90, 0x40
    db 0x40, 0x00, 0x00, 0xff

; --- Yellow-intro gfx (B3.2b, gen_intro_gfx_inc.py; verified byte-exact vs the
; pret gfx/intro/*.2bpp). Loaded to VRAM by InitYellowIntroGFXAndMusic (B3.2c);
; the tilemaps are placed by scene 10. Flat program-image data. ---
global YellowIntroGraphics1, YellowIntroGraphics2, YellowIntroCloudGFX
global Unkn_f9b6e, Unkn_f9be6, Unkn_f9bf2
%include "assets/yellow_intro_1_2bpp.inc"       ; YellowIntroGraphics1 (128 tiles)
%include "assets/yellow_intro_2_2bpp.inc"       ; YellowIntroGraphics2 (256 tiles)
%include "assets/yellow_intro_clouds_2bpp.inc"  ; YellowIntroCloudGFX (8 tiles)
%include "assets/yellow_intro_tilemaps.inc"     ; Unkn_f9b6e/be6/bf2
