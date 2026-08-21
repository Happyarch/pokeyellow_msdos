; screen_effects.asm — mirror of pret engine/gfx/screen_effects.asm.
;
; battle_animations Stage 3b (docs/plans/battle_animations.md): the two
; screen-shake predefs that the battle animation engine's shake family jumps to.
; ChangeBGPalColor0_4Frames (the third routine in pret's file) is now ported here
; too — engine/events/poison.asm's ApplyOutOfBattlePoisonDamage calls it for the
; overworld poison flash. It landed with the events fan-out: that batch had this
; file outside its allow-list, so it inlined the body at the call site under a
; class=temporary DEVIATION and left instructions to lift it. This is the lift.
;
; ---------------------------------------------------------------------------
; THE PROJECTION (why these write hSCX/hSCY and not rWX/rWY)
;
; On the Game Boy the whole battle screen IS the window layer: engine/battle/
; core.asm sets rWY = 0 on battle entry, so the window covers the screen from
; the top-left down. That is why pret shakes the screen by mutating rWX/rWY —
; moving the window moves everything the player can see — and why
; AnimationWavyScreen has to turn the window OFF (hWY = SCREEN_HEIGHT_PX) before
; it can wobble rSCX against the BG.
;
; The port does not work that way. Its battle screen is drawn on the BG layer
; (render_bg's flat path decodes the 40x25 wTileMap into bg_surface) and its
; window layer is only the descriptor-driven dialog/menu boxes. So the port's
; equivalent of "displace the entire visible screen" is the BG blit offset,
; which render_bg reads from IO_SCX/IO_SCY — and those are overwritten from
; hSCX/hSCY by commit_shadow_regs every DelayFrame, so the SHADOWS are what a
; multi-frame effect must write. Maintainer directive, 2026-08-07: screen shake
; is whole-canvas displacement through the existing hSCX/hSCY path, with the
; matte moving with the scene; no frame-only shake HAL.
;
; The unsigned range is sufficient, which is not obvious and was measured rather
; than assumed: both pret shakes are UNIDIRECTIONAL from neutral. .MutateWX
; zeroes a negative value BEFORE `add 7`, so rWX only ever spans 7..7+b, and
; rWY only ever spans 0..b. Neither ever goes below its neutral, so the port
; never needs a negative offset — which matters because render_bg reads the
; scroll shadows with `movzx` (unsigned 0..255).
;
; Mapping: port hSCX = pret rWX - 7 (both neutral at their own zero point),
; port hSCY = pret rWY. The axis SENSE is inverted — a larger bg_scx/bg_scy
; samples further into bg_surface, moving content the opposite way from a window
; move — which is cosmetically irrelevant for a symmetric jolt but is recorded
; in the DEVIATIONs below rather than left for a reader to rediscover.
;
; DIRECT CALL, NOT predef. pret reaches both routines via `predef_jump`, and
; each therefore opens with `call GetPredefRegisters` to recover the b it was
; invoked with. The port has no predef dispatcher populating wPredefBC/DE/HL, so
; that call would load garbage OVER the b its callers just set; the callers in
; animations.asm jump here directly with b already in BH. This is the same
; direct-call convention ReadTrainer uses for AddBCD in place of pret's
; `predef AddBCDPredef`. faithdiff therefore reports GetPredefRegisters as a
; justified DROPPED call on both routines.
;
; Register map: A=AL, B=BH, C=BL, EBP = GB base.
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"

global ChangeBGPalColor0_4Frames
global PredefShakeScreenVertically
global PredefShakeScreenHorizontally

extern DelayFrames                     ; src/home/delay.asm — BL = frame count
extern UpdateCGBPal_BGP                ; src/home/cgb_palettes.asm

section .text

; ---------------------------------------------------------------------------
; PredefShakeScreenVertically — moves the screen down and then back in a
; sequence of progressively smaller numbers of pixels, starting at b.
; In: BH = pret b (magnitude). Clobbers AL, BH, BL.
;
; DEVIATION{class=projection; pret=engine/gfx/screen_effects.asm:PredefShakeScreenVertically; behavior=displaces the whole canvas by writing the BG scroll shadow hSCY instead of the window register rWY, and the displacement sense is inverted; evidence=on GB the battle screen is the window layer (core.asm sets rWY=0 on battle entry) so moving the window moves the visible screen, but the port draws battle on the BG layer and reserves the window for dialog boxes, and render_bg takes its blit offset from IO_SCY which commit_shadow_regs rewrites from hSCY every DelayFrame, so the shadow is the only channel a multi-frame effect can use; lifetime=permanent, part of the port's BG-layer battle-screen model}
; ---------------------------------------------------------------------------
PredefShakeScreenVertically:
    ; pret: call GetPredefRegisters — omitted, see the DIRECT CALL note above.
    mov byte [ebp + wDisableVBlankWYUpdate], 1
    xor al, al
.loop:
    mov [ebp + hMutateWY], al
    call .MutateWY
    call .MutateWY
    dec bh                                   ; dec b — 8-bit, as on the GB
    mov al, bh                               ; ld a,b — flag-neutral, ZF from dec
    jnz .loop
    xor al, al
    mov [ebp + wDisableVBlankWYUpdate], al
    ; Park the canvas back at neutral. This store has NO pret counterpart and is
    ; load-bearing — do not "simplify" it away as redundant.
    ;
    ; pret does not exit with rWY = 0. Traced with b = 8, the xor-walk leaves
    ; rWY = 1 on the final iteration (at b = 1 the two .MutateWY calls land on
    ; 0 then 1, and the loop exits immediately after). pret gets away with it
    ; because clearing wDisableVBlankWYUpdate on the line above re-enables
    ; VBlank's WY commit, which rewrites rWY from hWY on the very next frame —
    ; the window register has a backing shadow that restores it for free.
    ;
    ; hSCY has no such backer: in the port it IS the source of truth that
    ; commit_shadow_regs copies into IO_SCY. Leaving it at 1 would offset the
    ; whole battle canvas by one pixel permanently, so the neutral must be
    ; written explicitly here.
    mov [ebp + hSCY], al
    ret

.MutateWY:
    mov al, [ebp + hMutateWY]
    xor al, bh                               ; xor b
    mov [ebp + hMutateWY], al
    mov [ebp + hSCY], al                    ; ldh [rWY],a  → canvas Y displacement
    mov bl, 3                                ; ld c,3
    jmp DelayFrames                          ; jp DelayFrames

; ---------------------------------------------------------------------------
; PredefShakeScreenHorizontally — moves the screen right and then back in a
; sequence of progressively smaller numbers of pixels, starting at b.
; In: BH = pret b (magnitude). Clobbers AL, BH, BL.
;
; DEVIATION{class=projection; pret=engine/gfx/screen_effects.asm:PredefShakeScreenHorizontally; behavior=displaces the whole canvas by writing the BG scroll shadow hSCX instead of the window register rWX, drops pret's +7 WX bias so neutral is 0 rather than 7, and the displacement sense is inverted; evidence=on GB the battle screen is the window layer and WX=7 is its neutral left edge, so pret adds 7 to every displacement, whereas the port draws battle on the BG layer whose neutral blit offset is 0 and whose only multi-frame-safe channel is hSCX because commit_shadow_regs rewrites IO_SCX from it each DelayFrame; lifetime=permanent, part of the port's BG-layer battle-screen model}
; ---------------------------------------------------------------------------
PredefShakeScreenHorizontally:
    ; pret: call GetPredefRegisters — omitted, see the DIRECT CALL note above.
    xor al, al
.loop:
    mov [ebp + hMutateWX], al
    call .MutateWX
    mov bl, 1                                ; ld c,1
    call DelayFrames
    call .MutateWX
    dec bh                                   ; dec b
    mov al, bh                               ; ld a,b — flag-neutral, ZF from dec
    jnz .loop

; restore the neutral position (pret: ld a,7 / ldh [rWX],a — WX 7 is its neutral;
; the port's neutral canvas offset is 0)
    mov byte [ebp + hSCX], 0
    ret

.MutateWX:
    mov al, [ebp + hMutateWX]
    xor al, bh                               ; xor b
    mov [ebp + hMutateWX], al
    test al, 0x80                            ; bit 7,a — negative?
    jz .skipZeroing
    xor al, al                               ; zero a if it's negative
.skipZeroing:
    ; pret: add 7 / ldh [rWX],a — the +7 is the GB window's neutral left edge and
    ; is dropped here (see the DEVIATION); the clamped magnitude IS the offset.
    mov [ebp + hSCX], al
    mov bl, 4                                ; ld c,4
    jmp DelayFrames                          ; jp DelayFrames

; ---------------------------------------------------------------------------
; ChangeBGPalColor0_4Frames — pret engine/gfx/screen_effects.asm:2.
; Invert BGP, hold it for 4 frames, invert it back: the white->dark-grey flash
; the overworld poison tick shows. Called by ApplyOutOfBattlePoisonDamage.
;
; pret opens with `call GetPredefRegisters`, which its own comment calls a
; "leftover of red/blue, has no use here" — the routine reads no argument (its
; caller's `ld b, $2` is dead). The port therefore calls it directly, the same
; register-passing-predef convention used at every other predef site here.
;
; No TODO-HW is owed for the rBGP writes: a write to [ebp + IO_BGP] IS the whole
; effect, because commit_palette re-reads the three DMG palette registers every
; DelayFrame (see the asm-translation skill, "Hardware I/O Boundary").
; ---------------------------------------------------------------------------
ChangeBGPalColor0_4Frames:
    mov al, [ebp + IO_BGP]                   ; ldh a, [rBGP]
    xor al, 0xFF                             ; xor $ff
    mov [ebp + IO_BGP], al                   ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov bl, 4                                ; ld c, 4
    call DelayFrames
    mov al, [ebp + IO_BGP]                   ; ldh a, [rBGP]
    xor al, 0xFF                             ; xor $ff
    mov [ebp + IO_BGP], al                   ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    ret
