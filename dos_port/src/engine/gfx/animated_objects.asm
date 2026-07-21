; animated_objects.asm — the Yellow intro's animated-object engine.
;
; Faithful translation of engine/gfx/animated_objects.asm (pret/pokeyellow).
; This is the sprite-animation VM the Game-Freak/Yellow intro (menu-intro Phase
; B) runs on: a fixed pool of 10 animated-object structs (wAnimatedObject0..9),
; each stepping a per-frameset frame script that stamps OBJ into shadow OAM.
;
; Register map (this file):
;   EBX = the "current struct" base pointer (pret BC) — persists across a whole
;         object's per-frame update; all values are 0xF6xx (< 0x10000).
;   ESI = HL scratch pointer.   EDX = DE (shadow-OAM write cursor / scratch).
;   AL  = A.   ECX = loop counter (pret's `ld e, N`).   EBP = GB memory base.
;
; Struct (16 B), byte offsets used as raw literals exactly as pret does:
;   0 Index  1 FramesetID  2 AnimSeqID(callback)  3 TileID(VTileOffset)
;   4 XCoord 5 YCoord      6 XOffset  7 YOffset    8 Duration
;   9 DurationOffset  a FrameIndex  b..f FieldB..FieldF
;
; Pointer model (see gb_memmap.inc): Spawn/Frames/OAMData tables are GB-space
; data blobs (16-bit GB pointers, arithmetic byte-identical to pret); the
; callback jumptable holds 32-bit flat x86 code addresses (data-model DEVIATION
; on ExecuteCurrentAnimatedObjectCallback).
;
; Shadow OAM is at wShadowOAM (0xC300, kept at the pret address). The frame
; pipeline / scene driver publishes it projected via PublishProjectedOAM.
;
; Build: nasm -f coff -I include/ -I . -o animated_objects.o \
;        src/engine/gfx/animated_objects.asm

bits 32

%include "gb_memmap.inc"

extern FillMemory

global ClearObjectAnimationBuffers
global RunObjectAnimations
global SpawnAnimatedObject
global MaskCurrentAnimatedObjectStruct
global MaskAllAnimatedObjectStructs
global UpdateCurrentAnimatedObjectFrame
global GetCurrentAnimatedObjectTileYCoordinate
global GetCurrentAnimatedObjectTileXCoordinate
global SetCurrentAnimatedObjectOAMAttributes
global GetCurrentAnimatedObjectOAMDataPointer
global SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters
global UpdateDurationTimerAndFrameStateForCurrentAnimatedObject
global GetPointerToCurrentAnimatedObjectFrameScript
global ExecuteCurrentAnimatedObjectCallback

section .text

; ---------------------------------------------------------------------------
; ClearObjectAnimationBuffers — zero the whole animated-object WRAM block.
; ---------------------------------------------------------------------------
ClearObjectAnimationBuffers:
    mov esi, W_ANIMATED_OBJECTS_DATA          ; ld hl, wAnimatedObjectsData
    mov bx, W_ANIMATED_OBJECTS_DATA_SIZE      ; ld bc, End - Data
    xor al, al                                ; xor a → fill value 0
    call FillMemory                           ; FillMemory: ESI=dst, BX=count, AL=val
    ret

; ---------------------------------------------------------------------------
; RunObjectAnimations — step every active animated object this frame, then zero
; the shadow-OAM slots the objects did not fill.
; ---------------------------------------------------------------------------
RunObjectAnimations:
    mov esi, wAnimatedObjectDataStructs       ; ld hl, wAnimatedObjectDataStructs
    mov ecx, 10                               ; ld e, 10
.loop:
    mov al, [ebp + esi]                       ; ld a, [hl]  (struct Index)
    test al, al                               ; and a
    jz .next                                  ; jr z, .next
    mov ebx, esi                              ; ld c, l / ld b, h  (bc = struct base)
    push esi                                  ; push hl
    push ecx                                  ; push de (loop counter)
    call ExecuteCurrentAnimatedObjectCallback
    call UpdateCurrentAnimatedObjectFrame
    pop ecx                                   ; pop de
    pop esi                                   ; pop hl
    jc .quit                                  ; jr c, .quit  (OAM full)
.next:
    add esi, 0x10                             ; ld bc, $10 / add hl, bc
    dec ecx                                   ; dec e
    jnz .loop                                 ; jr nz, .loop
    ; zero the shadow-OAM tail from the last object's cursor to the end
    movzx esi, byte [ebp + wCurrentAnimatedObjectOAMBufferOffset] ; ld a,[..]/ld l,a
    add esi, W_SHADOW_OAM                     ; ld h, HIGH(wShadowOAM)
.deinit_unused_oam_loop:
    cmp esi, W_SHADOW_OAM_END                 ; cp LOW(wShadowOAMEnd)
    jae .quit                                 ; jr nc, .quit
    mov byte [ebp + esi], 0                   ; xor a / ld [hli], a
    inc esi
    jmp .deinit_unused_oam_loop
.quit:
    ret

; ---------------------------------------------------------------------------
; SpawnAnimatedObject — allocate the first free struct and initialise it.
;   In:  AL = spawn-state index, DX = spawn coords (DL=X, DH=Y).
;   Out: CF set if the pool is full (no struct allocated).
; ---------------------------------------------------------------------------
SpawnAnimatedObject:
    push edx                                  ; push de  (spawn coords)
    push eax                                  ; push af  (spawn index)
    mov esi, wAnimatedObjectDataStructs       ; ld hl, wAnimatedObjectDataStructs
    mov ecx, 10                               ; ld e, 10
.loop:
    mov al, [ebp + esi]                       ; ld a, [hl]
    test al, al                               ; and a
    jz .init                                  ; jr z, .init
    add esi, 0x10                             ; ld bc, $10 / add hl, bc
    dec ecx                                   ; dec e
    jnz .loop                                 ; jr nz, .loop
    pop eax                                   ; pop af
    pop edx                                   ; pop de
    stc                                       ; scf
    ret

.init:
    pop eax                                   ; pop af  (AL = spawn index)
    mov ebx, esi                              ; ld c, l / ld b, h  (bc = struct base)
    inc byte [ebp + wNumLoadedAnimatedObjects]; ld hl, wNumLoadedAnimatedObjects / inc [hl]
    movzx edx, al                             ; ld e, a / ld d, $0  (de = index)
    movzx esi, word [ebp + wAnimatedObjectSpawnStateDataPointer] ; hl = spawn table (GB ptr)
    lea esi, [esi + edx*2]                     ; add hl,de / add hl,de / add hl,de
    add esi, edx                               ;   → hl = table + 3*index (3-byte entries)
    mov edx, esi                              ; ld e, l / ld d, h  (de = &entry)
    mov esi, ebx                              ; ld hl, $0 / add hl, bc  (hl = struct+0)
    mov al, [ebp + wNumLoadedAnimatedObjects] ; ld a, [wNumLoadedAnimatedObjects]
    mov [ebp + esi], al                       ; ld [hli], a   struct[0] Index = count
    inc esi
    mov al, [ebp + edx]                       ; ld a, [de]
    mov [ebp + esi], al                       ; ld [hli], a   struct[1] FramesetID
    inc esi
    inc edx                                   ; inc de
    mov al, [ebp + edx]                       ; ld a, [de]
    mov [ebp + esi], al                       ; ld [hli], a   struct[2] AnimSeqID
    inc esi
    xor al, al                                ; xor a
    mov [ebp + esi], al                       ; ld [hli], a   struct[3] TileID = 0
    inc esi
    pop edx                                   ; pop de  (spawn coords)
    lea esi, [ebx + 4]                        ; ld hl, $4 / add hl, bc  (hl = struct+4)
    mov al, dl                                ; ld a, e
    mov [ebp + esi], al                       ; ld [hli], a   struct[4] XCoord = X
    inc esi
    mov al, dh                                ; ld a, d
    mov [ebp + esi], al                       ; ld [hli], a   struct[5] YCoord = Y
    inc esi
    xor al, al                                ; xor a
    mov [ebp + esi], al                       ; ld [hli], a   struct[6] XOffset = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hli], a   struct[7] YOffset = 0
    inc esi
    xor al, al                                ; xor a
    mov [ebp + esi], al                       ; ld [hli], a   struct[8] Duration = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hli], a   struct[9] DurationOffset = 0
    inc esi
    dec al                                    ; dec a  → 0xff
    mov [ebp + esi], al                       ; ld [hli], a   struct[a] FrameIndex = 0xff
    inc esi
    xor al, al                                ; xor a
    mov [ebp + esi], al                       ; ld [hli], a   struct[b] = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hli], a   struct[c] = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hli], a   struct[d] = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hli], a   struct[e] = 0
    inc esi
    mov [ebp + esi], al                       ; ld [hl], a    struct[f] = 0
    ret

; ---------------------------------------------------------------------------
; MaskCurrentAnimatedObjectStruct — mark the current struct (EBX) inactive.
; ---------------------------------------------------------------------------
MaskCurrentAnimatedObjectStruct:
    mov byte [ebp + ebx], 0                   ; ld hl,$0 / add hl,bc / ld [hl],$0
    ret

; ---------------------------------------------------------------------------
; MaskAllAnimatedObjectStructs — mark all 10 structs inactive.
; ---------------------------------------------------------------------------
MaskAllAnimatedObjectStructs:
    mov esi, wAnimatedObjectDataStructs       ; ld hl, wAnimatedObjectDataStructs
    mov ecx, 10                               ; ld e, 10
.loop:
    mov byte [ebp + esi], 0                   ; ld [hl], $0
    add esi, 0x10                             ; ld bc, $10 / add hl, bc
    dec ecx                                   ; dec e
    jnz .loop                                 ; jr nz, .loop
    ret

; ---------------------------------------------------------------------------
; UpdateCurrentAnimatedObjectFrame — advance the current object's frame script
; and stamp its OBJ into shadow OAM.  In: EBX = struct base.  Out: CF if OAM full.
; ---------------------------------------------------------------------------
UpdateCurrentAnimatedObjectFrame:
    xor al, al
    mov [ebp + wCurAnimatedObjectOAMAttributes], al  ; xor a / ld [..], a
    lea esi, [ebx + 3]                        ; ld hl, $3 / add hl, bc
    mov al, [ebp + esi]                       ; ld a, [hli]
    mov [ebp + wCurrentAnimatedObjectVTileOffset], al ;   struct[3] → VTileOffset
    inc esi
    mov al, [ebp + esi]                       ; ld a, [hli]
    mov [ebp + wCurrentAnimatedObjectXCoord], al      ;   struct[4] → XCoord
    inc esi
    mov al, [ebp + esi]                       ; ld a, [hli]
    mov [ebp + wCurrentAnimatedObjectYCoord], al      ;   struct[5] → YCoord
    inc esi
    mov al, [ebp + esi]                       ; ld a, [hli]
    mov [ebp + wCurrentAnimatedObjectXOffset], al     ;   struct[6] → XOffset
    inc esi
    mov al, [ebp + esi]                       ; ld a, [hl]
    mov [ebp + wCurrentAnimatedObjectYOffset], al     ;   struct[7] → YOffset
    call UpdateDurationTimerAndFrameStateForCurrentAnimatedObject ; AL = frame control byte
    cmp al, 0xfd                              ; cp $fd
    je .finish                                ; jr z, .finish
    cmp al, 0xfc                              ; cp $fc
    je .delete_animation                      ; jr z, .delete_animation
    call GetCurrentAnimatedObjectOAMDataPointer ; ESI = &oamdata entry (3-byte)
    mov al, [ebp + wCurrentAnimatedObjectVTileOffset]
    add al, [ebp + esi]                       ; add [hl]  (+ tile-offset delta)
    mov [ebp + wCurrentAnimatedObjectVTileOffset], al
    inc esi                                   ; inc hl
    movzx esi, word [ebp + esi]               ; ld a,[hli]/ld h,[hl]/ld l,a → OAM template ptr
    push ebx                                  ; push bc  (save struct base)
    movzx edx, byte [ebp + wCurrentAnimatedObjectOAMBufferOffset] ; ld a,[..]/ld e,a
    add edx, W_SHADOW_OAM                     ; ld d, HIGH(wShadowOAM)  → shadow-OAM cursor
    movzx ecx, byte [ebp + esi]               ; ld a,[hli]/ld c,a  (template OBJ count)
    inc esi
.loop:
    mov al, [ebp + wCurrentAnimatedObjectYCoord] ; ld a,[YCoord]/ld b,a
    add al, [ebp + wCurrentAnimatedObjectYOffset]; ld a,[YOffset]/add b/ld b,a
    add al, [ebp + wAnimatedObjectGlobalYOffset] ; ld a,[GlobalYOffset]/add b/ld b,a
    mov bl, al                                ; b = accumulated Y base
    call GetCurrentAnimatedObjectTileYCoordinate ; AL = template Y (flipped if yflip)
    add al, bl                                ; add b
    mov [ebp + edx], al                       ; ld [de], a  (OAM Y)
    inc esi                                   ; inc hl
    inc edx                                   ; inc de
    mov al, [ebp + wCurrentAnimatedObjectXCoord] ; ld a,[XCoord]/ld b,a
    add al, [ebp + wCurrentAnimatedObjectXOffset]; ld a,[XOffset]/add b/ld b,a
    add al, [ebp + wAnimatedObjectGlobalXOffset] ; ld a,[GlobalXOffset]/add b/ld b,a
    mov bl, al                                ; b = accumulated X base
    call GetCurrentAnimatedObjectTileXCoordinate ; AL = template X (flipped if xflip)
    add al, bl                                ; add b
    mov [ebp + edx], al                       ; ld [de], a  (OAM X)
    inc esi                                   ; inc hl
    inc edx                                   ; inc de
    mov al, [ebp + wCurrentAnimatedObjectVTileOffset]
    add al, [ebp + esi]                       ; add [hl]  (+ template tile)
    mov [ebp + edx], al                       ; ld [de], a  (OAM tile)
    inc esi                                   ; inc hl
    inc edx                                   ; inc de
    call SetCurrentAnimatedObjectOAMAttributes ; AL = merged attr byte
    mov bl, al                                ; ld b, a
    mov al, [ebp + wc634]                     ; ld a, [wc634]
    cmp al, 0x7                               ; cp $7
    mov al, bl                                ; ld a, b
    je .skip_load                             ; jr z, .skip_load  (scene 7: don't write attr)
    mov [ebp + edx], al                       ; ld [de], a  (OAM attr)
.skip_load:
    inc esi                                   ; inc hl
    inc edx                                   ; inc de
    mov al, dl                                ; ld a, e
    mov [ebp + wCurrentAnimatedObjectOAMBufferOffset], al ; ld [..], a  (save cursor low byte)
    cmp al, W_SHADOW_OAM_END & 0xff           ; cp LOW(wShadowOAMEnd)
    jae .oam_is_full                          ; jr nc, .oam_is_full
    dec ecx                                   ; dec c
    jnz .loop                                 ; jr nz, .loop
    pop ebx                                   ; pop bc
    jmp .finish

.delete_animation:
    call MaskCurrentAnimatedObjectStruct
.finish:
    clc                                       ; and a  (clear CF)
    ret

.oam_is_full:
    pop ebx                                   ; pop bc
    stc                                       ; scf
    ret

; ---------------------------------------------------------------------------
; GetCurrentAnimatedObjectTileYCoordinate — read template Y at [ESI], negate for
; a vertical flip.  Preserves ESI.  Out: AL.
; ---------------------------------------------------------------------------
GetCurrentAnimatedObjectTileYCoordinate:
    push esi                                  ; push hl
    mov al, [ebp + esi]                       ; ld a, [hl]
    test byte [ebp + wCurAnimatedObjectOAMAttributes], OAM_YFLIP ; bit B_OAM_YFLIP,[hl]
    jz .no_flip                               ; jr z, .no_flip
    add al, 0x8                               ; add $8
    xor al, 0xff                              ; xor $ff
    inc al                                    ; inc a
.no_flip:
    pop esi                                   ; pop hl
    ret

; ---------------------------------------------------------------------------
; GetCurrentAnimatedObjectTileXCoordinate — same, horizontal flip.
; ---------------------------------------------------------------------------
GetCurrentAnimatedObjectTileXCoordinate:
    push esi                                  ; push hl
    mov al, [ebp + esi]                       ; ld a, [hl]
    test byte [ebp + wCurAnimatedObjectOAMAttributes], OAM_XFLIP ; bit B_OAM_XFLIP,[hl]
    jz .no_flip                               ; jr z, .no_flip
    add al, 0x8                               ; add $8
    xor al, 0xff                              ; xor $ff
    inc al                                    ; inc a
.no_flip:
    pop esi                                   ; pop hl
    ret

; ---------------------------------------------------------------------------
; SetCurrentAnimatedObjectOAMAttributes — merge the frame's flip/prio/pal state
; (wCurAnimatedObjectOAMAttributes) with the template attr byte at [ESI].
; Out: AL = OAM attribute byte.  Preserves ESI/EDX/ECX; clobbers BL.
; ---------------------------------------------------------------------------
SetCurrentAnimatedObjectOAMAttributes:
    mov bl, [ebp + wCurAnimatedObjectOAMAttributes] ; ld a,[..]/ld b,a
    mov al, [ebp + esi]                       ; ld a, [hl]
    xor al, bl                                ; xor b
    and al, OAM_XFLIP | OAM_YFLIP | OAM_PRIO  ; and OAM_XFLIP|OAM_YFLIP|OAM_PRIO
    mov bl, al                                ; ld b, a
    mov al, [ebp + esi]                       ; ld a, [hl]
    and al, OAM_PAL1                          ; and OAM_PAL1
    or al, bl                                 ; or b
    test al, OAM_PAL1                         ; bit B_OAM_PAL1, a
    jz .ret                                   ; ret z
    or al, OAM_HIGH_PALS                      ; or OAM_HIGH_PALS
.ret:
    ret

; ---------------------------------------------------------------------------
; GetCurrentAnimatedObjectOAMDataPointer — In: AL = OAM template id.
; Out: ESI = &(wAnimatedObjectOAMDataPointer table)[id]  (3-byte entries).
; ---------------------------------------------------------------------------
GetCurrentAnimatedObjectOAMDataPointer:
    movzx edx, al                             ; ld e, a / ld d, $0
    movzx esi, word [ebp + wAnimatedObjectOAMDataPointer] ; hl = table ptr (GB, little-endian)
    lea esi, [esi + edx*2]                    ; add hl,de / add hl,de / add hl,de
    add esi, edx                              ;   → hl = table + 3*id
    ret

; ---------------------------------------------------------------------------
; SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters —
;   In: AL = new value for struct[1]; EBX = struct base.  Resets timer state.
; ---------------------------------------------------------------------------
SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters:
    mov [ebp + ebx + 1], al                   ; ld hl,$1/add hl,bc/ld [hl],a
    mov byte [ebp + ebx + 8], 0               ; ld hl,$8/add hl,bc/ld [hl],$0
    mov byte [ebp + ebx + 9], 0               ; ld hl,$9/add hl,bc/ld [hl],$0
    mov byte [ebp + ebx + 0x0a], 0xff         ; ld hl,$a/add hl,bc/ld [hl],$ff
    ret

; ---------------------------------------------------------------------------
; UpdateDurationTimerAndFrameStateForCurrentAnimatedObject — the frame-script
; interpreter.  In: EBX = struct base.  Out: AL = frame control/tile byte, and
; wCurAnimatedObjectOAMAttributes updated from the frame flags.
; ---------------------------------------------------------------------------
UpdateDurationTimerAndFrameStateForCurrentAnimatedObject:
.loop:
    lea esi, [ebx + 8]                        ; ld hl,$8/add hl,bc  (&Duration)
    mov al, [ebp + esi]                       ; ld a, [hl]
    test al, al                               ; and a
    jz .next_frame                            ; jr z, .next_frame
    dec byte [ebp + esi]                      ; dec [hl]  (--Duration)
    call GetPointerToCurrentAnimatedObjectFrameScript ; ESI → frame entry
    mov al, [ebp + esi]                       ; ld a, [hli]  (byte0)
    inc esi
    push eax                                  ; push af  (save byte0)
    jmp .finish

.next_frame:
    lea esi, [ebx + 0x0a]                     ; ld hl,$a/add hl,bc  (&FrameIndex)
    inc byte [ebp + esi]                      ; inc [hl]  (++FrameIndex)
    call GetPointerToCurrentAnimatedObjectFrameScript
    mov al, [ebp + esi]                       ; ld a, [hli]  (byte0)
    inc esi
    cmp al, 0xfe                              ; cp $fe
    je .restart_anim                          ; jr z, .restart_anim
    cmp al, 0xff                              ; cp $ff
    je .hold_last_frame_state                 ; jr z, .hold_last_frame_state
    push eax                                  ; push af  (save byte0)
    mov al, [ebp + esi]                       ; ld a, [hl]  (byte1)
    push esi                                  ; push hl
    and al, 0x3f                              ; and $3f  (base duration)
    add al, [ebp + ebx + 9]                   ; ld hl,$9/add hl,bc/add [hl]  (+ DurationOffset)
    mov [ebp + ebx + 8], al                   ; ld hl,$8/add hl,bc/ld [hl],a  (Duration = a)
    pop esi                                   ; pop hl
.finish:
    mov al, [ebp + esi]                       ; ld a, [hl]  (byte1 = flags)
    and al, 0xc0                              ; and $c0
    shr al, 1                                 ; srl a
    mov [ebp + wCurAnimatedObjectOAMAttributes], al ; ld [..], a
    pop eax                                   ; pop af  (restore byte0 → AL)
    ret

.hold_last_frame_state:
    mov byte [ebp + ebx + 8], 0               ; xor a / ld hl,$8/add hl,bc/ld [hl],a
    dec byte [ebp + ebx + 0x0a]               ; ld hl,$a/add hl,bc/dec [hl]
    dec byte [ebp + ebx + 0x0a]               ; dec [hl]  (FrameIndex -= 2)
    jmp .loop

.restart_anim:
    mov byte [ebp + ebx + 8], 0               ; xor a / ld hl,$8/add hl,bc/ld [hl],a
    mov byte [ebp + ebx + 0x0a], 0xff         ; dec a / ld hl,$a/add hl,bc/ld [hl],a
    jmp .loop

; ---------------------------------------------------------------------------
; GetPointerToCurrentAnimatedObjectFrameScript — In: EBX = struct base.
; Out: ESI → the current frame entry (script base + 2*FrameIndex).
; ---------------------------------------------------------------------------
GetPointerToCurrentAnimatedObjectFrameScript:
    movzx edx, byte [ebp + ebx + 1]           ; ld hl,$1/add hl,bc/ld e,[hl]/ld d,$0
    movzx esi, word [ebp + wAnimatedObjectFramesDataPointer] ; hl = frames table (GB ptr)
    lea esi, [esi + edx*2]                     ; add hl,de / add hl,de  (2-byte entries)
    movzx edx, word [ebp + esi]               ; ld e,[hl]/inc hl/ld d,[hl]  (script pointer)
    movzx esi, byte [ebp + ebx + 0x0a]        ; ld hl,$a/add hl,bc/ld l,[hl]/ld h,$0
    lea esi, [edx + esi*2]                     ; add hl,hl / add hl,de  (script + 2*FrameIndex)
    ret

; ---------------------------------------------------------------------------
; ExecuteCurrentAnimatedObjectCallback — dispatch through the per-set callback
; jumptable.  In: EBX = struct base.  Tail-jumps to the callback (which returns
; to RunObjectAnimations, exactly as pret's `jp hl` trampoline does).
;
; DEVIATION{class=data-model; pret=engine/gfx/animated_objects.asm:ExecuteCurrentAnimatedObjectCallback; behavior=jumptable entries are 32-bit flat x86 code addresses read at a x4 stride instead of pret's 2-byte GB addresses at a x2 stride, and wAnimatedObjectJumptablePointer is a flat pointer, not an EBP-relative GB pointer; evidence=callbacks are native x86 routines whose addresses are link-time flat labels and cannot live in a GB-space data blob like the Frames/OAM/Spawn tables do; lifetime=permanent — intrinsic to running GB code as native x86}
; ---------------------------------------------------------------------------
ExecuteCurrentAnimatedObjectCallback:
    movzx edx, byte [ebp + ebx + 2]           ; ld hl,$2/add hl,bc/ld e,[hl]/ld d,$0  (AnimSeqID)
    mov esi, [ebp + wAnimatedObjectJumptablePointer] ; flat jumptable base (32-bit)
    mov esi, [esi + edx*4]                    ; flat callback address (table + 4*id)
    jmp esi                                   ; jp hl  (trampoline: callback rets to caller)
