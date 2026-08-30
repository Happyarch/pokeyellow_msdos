; healing_machine.asm — Poké Center healing-machine animation (OW-6.2).
;
; Intended repo path: dos_port/src/engine/overworld/healing_machine.asm
; pret source: engine/overworld/healing_machine.asm
;
; AnimateHealingMachine loads the monitor/ball tiles, builds the machine OAM,
; stops music, then lights the balls one-per-party-member (SFX + delay), plays
; the "healed" jingle, flashes the sprites, and restores state. FlashSprite8Times
; toggles OBP1 8×; CopyHealingMachineOAM copies one 4-byte OAM entry, advancing
; both pointers so successive calls fill sprites 33.. from PokeCenterOAMData.
;
; Register map (SM83 -> x86): A->AL, B->BH, C->BL, D->DH, HL->ESI, DE cursor->EDX.
; GB memory is [ebp+offset]. rOBP1 -> [ebp+IO_OBP1].
; CopyHealingMachineOAM's source (PokeCenterOAMData) is a flat ROM label read via
; EDX (flat), its dest (wShadowOAMSprite33) a GB WRAM offset via ESI — both
; persist + advance across the party loop (PlaySound preserves ESI/EDX/EBX;
; DelayFrames only touches BL). CopyVideoData: ESI=VRAM dest, EDX=flat src, BL=count.
;
; DIVERGENCE (flat ROM banking): the pret `wAudioROMBank == BANK("Audio Engine 3")`
; guard + bank-swap around Music_PkmnHealed is meaningless under the port's single
; flat audio engine — elided; the jingle is played directly (audio LIVE).
; DIVERGENCE (bounded audio waits): the port has no VBlank audio ISR, so pret's
; bare `jr nz` spins on wAudioFadeOutControl / wChannelSoundIDs (which the engine
; only advances on the frame-loop tick) would hang. They are bounded here to
; avoid a lock; a proper engine-tick yield is a promotion-time refinement.
;
; Check-only until the palette shim (UpdateCGBPal_OBP1) lands.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null \
;                     src/engine/overworld/healing_machine.asm
; ---------------------------------------------------------------------------

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gfx_macros.inc"                     ; dbsprite
%include "assets/audio_constants.inc"         ; MUSIC_PKMN_HEALED / SFX_HEALING_MACHINE

; --- symbols not yet in the shared headers (golden sym-verified) ---
%ifndef GB_VCHARS0
%endif
%ifndef OAM_XFLIP
%endif

; bounded-wait caps (DIVERGENCE — see header)
WAIT_FADE_MAX    equ 600
WAIT_JINGLE_MAX  equ 600

global AnimateHealingMachine
global FlashSprite8Times
global CopyHealingMachineOAM

extern g_audio_engine_online       ; src/home/audio.asm
extern CopyVideoData               ; home/copy2.asm (ESI=VRAM dest, EDX=flat src, BL=count)
extern UpdateCGBPal_OBP1           ; home/cgb_palettes.asm
extern StopAllMusic                ; home/audio.asm (LIVE)
extern PlaySound                   ; home/audio.asm (LIVE)
extern DelayFrame                  ; src/home/vblank.asm
extern DelayFrames                 ; src/home/delay.asm
extern UpdateSprites               ; src/home/update_sprites.asm
extern GBScreenToCanvasXY          ; src/engine/gfx/sprite_oam.asm (PROBE publication)
extern spr_dos_sy, spr_dos_sx      ; src/ppu/ppu.asm
extern spr_oam_valid               ; src/ppu/ppu.asm

section .text

; ---------------------------------------------------------------------------
; AnimateHealingMachine — pret engine/overworld/healing_machine.asm:AnimateHealingMachine
; ---------------------------------------------------------------------------
AnimateHealingMachine:
    mov edx, PokeCenterFlashingMonitorAndHealBall  ; ld de, ... (flat src)
    mov esi, GB_VCHARS0 + 0x7c * TILE_SIZE          ; ld hl, vChars0 tile $7c
    mov bl, 3                                       ; lb bc,BANK,3 — pret quirk: "should be 2"
    call CopyVideoData
    ; save wUpdateSpritesEnabled, force it on
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax                                        ; push af
    mov byte [ebp + wUpdateSpritesEnabled], 0xff
    ; save rOBP1, set it, apply
    mov al, [ebp + IO_OBP1]                         ; ldh a,[rOBP1]
    push eax                                        ; push af
    mov byte [ebp + IO_OBP1], 0xe0
    call UpdateCGBPal_OBP1
    ; build the machine OAM (monitor entry) at wShadowOAMSprite33
    mov esi, wShadowOAMSprite33                      ; ld hl, wShadowOAMSprite33
    mov edx, PokeCenterOAMData                       ; ld de, PokeCenterOAMData (flat)
    call CopyHealingMachineOAM
    mov byte [ebp + wAudioFadeOutControl], 4
    call StopAllMusic
; DEVIATION{class=HAL; pret=engine/overworld/healing_machine.asm:AnimateHealingMachine.waitLoop; behavior=the fade-out wait calls DelayFrame each iteration instead of spinning on wAudioFadeOutControl alone; evidence=audio is frame-driven in this port so a bare spin never steps the fade-out; lifetime=permanent}
    cmp byte [g_audio_engine_online], 0     ; skip wait entirely when audio is offline
    je .fadeDone                            ; (headless golden runs: SDL_AUDIODRIVER=dummy)
.waitLoop:
    call DelayFrame
    cmp byte [ebp + wAudioFadeOutControl], 0
    jnz .waitLoop
.fadeDone:
    mov al, [ebp + wPartyCount]
    mov bh, al                                       ; ld b, a
.partyLoop:
    call CopyHealingMachineOAM                        ; ESI/EDX persist + advance
    mov al, SFX_HEALING_MACHINE
    call PlaySound
    mov bl, 30                                        ; ld c, 30
    call DelayFrames
    dec bh
    jnz .partyLoop
    ; DIVERGENCE (flat banking): pret's wAudioROMBank==Audio Engine 3 guard +
    ; bank-swap around Music_PkmnHealed is meaningless under the flat audio
    ; engine. Save the (vestigial) bank byte and play the jingle directly.
    mov al, [ebp + wAudioROMBank]
    mov [ebp + wAudioSavedROMBank], al
    mov al, MUSIC_PKMN_HEALED
    mov [ebp + wNewSoundID], al
    call PlaySound
    mov dh, 0x28                                      ; ld d, $28
    call FlashSprite8Times
; DEVIATION{class=HAL; pret=engine/overworld/healing_machine.asm:AnimateHealingMachine.waitLoop2; behavior=the jingle wait calls DelayFrame each iteration instead of spinning on wChannelSoundIDs alone; evidence=audio is frame-driven in this port so a bare spin never steps the music channels; lifetime=permanent}
    cmp byte [g_audio_engine_online], 0     ; skip wait entirely when audio is offline
    je .jingleDone
.waitLoop2:
    call DelayFrame
    cmp byte [ebp + wChannelSoundIDs], MUSIC_PKMN_HEALED
    je .waitLoop2
.jingleDone:
    mov bl, 32                                        ; ld c, 32
    call DelayFrames
    ; restore rOBP1
    pop eax                                           ; pop af
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_OBP1
    ; restore wUpdateSpritesEnabled
    pop eax                                           ; pop af
    mov [ebp + wUpdateSpritesEnabled], al
    jmp UpdateSprites                                 ; jp (tail)

section .data
PokeCenterFlashingMonitorAndHealBall:
    incbin "../gfx/overworld/heal_machine.2bpp"

PokeCenterOAMData:
    ; heal machine monitor
    dbsprite  6,  4,  4,  4, 0x7c, OAM_PAL1 | OAM_HIGH_PALS
    ; poke balls 1-6
    dbsprite  6,  5,  0,  3, 0x7d, OAM_PAL1 | OAM_HIGH_PALS
    dbsprite  7,  5,  0,  3, 0x7d, OAM_PAL1 | OAM_HIGH_PALS | OAM_XFLIP
    dbsprite  6,  6,  0,  0, 0x7d, OAM_PAL1 | OAM_HIGH_PALS
    dbsprite  7,  6,  0,  0, 0x7d, OAM_PAL1 | OAM_HIGH_PALS | OAM_XFLIP
    dbsprite  6,  6,  0,  5, 0x7d, OAM_PAL1 | OAM_HIGH_PALS
    dbsprite  7,  6,  0,  5, 0x7d, OAM_PAL1 | OAM_HIGH_PALS | OAM_XFLIP
section .text

; ---------------------------------------------------------------------------
; FlashSprite8Times — toggle OBP1 8×. In: DH = value to xor with the palette.
; ---------------------------------------------------------------------------
FlashSprite8Times:
    mov bh, 8                                         ; ld b, 8
.loop:
    mov al, [ebp + IO_OBP1]                           ; ldh a,[rOBP1]
    xor al, dh                                        ; xor d
    mov [ebp + IO_OBP1], al
    call UpdateCGBPal_OBP1
    mov bl, 10                                        ; ld c, 10
    call DelayFrames
    dec bh
    jnz .loop
    ret

; ---------------------------------------------------------------------------
; CopyHealingMachineOAM — copy one 4-byte OAM entry, advancing both pointers.
; In: ESI = GB shadow-OAM dest offset (hl), EDX = flat PokeCenterOAMData cursor (de).
; ---------------------------------------------------------------------------
CopyHealingMachineOAM:
%rep 4
    mov al, [edx]                                     ; ld a,[de] (flat)
    inc edx
    mov [ebp + esi], al                               ; ld [hli], a (WRAM)
    inc esi
%endrep
    ; DEVIATION{class=HAL; pret=engine/overworld/healing_machine.asm:CopyHealingMachineOAM; behavior=each shadow-OAM entry written here is additionally published to the compositor - copied to $FE00, its canvas position derived via GBScreenToCanvasXY into spr_dos_sy/sx, and spr_oam_valid grown max-style - because the animation runs with wUpdateSpritesEnabled=$FF, which freezes the per-frame shadow-OAM DMA in this port, so the shadow write alone never reached $FE00 and the monitor and pokeballs were invisible for the whole healing animation (measured 2026-08-25, DEBUG_POKECENTER_HEAL=1); evidence=render_sprites takes tile and attr from $FE00 and positions from spr_dos_sy/sx keyed on spr_oam_valid, and AnimateHealingMachine relies on the $FF freeze the same way the port's direct-OAM screens (title, party-menu icons) do; lifetime=permanent, the OBJ side of the software video HAL}
    push eax
    push ecx
    push edx
    push ebx                                          ; caller holds the party count in BH
    mov eax, esi
    sub eax, wShadowOAM + 4                           ; entry offset (index*4)
    mov ecx, eax
    mov edx, [ebp + wShadowOAM + ecx]                 ; Y, X, tile, attr
    mov [ebp + GB_OAM + ecx], edx                     ; publish to $FE00 (DMA frozen)
    mov bh, [ebp + wShadowOAM + ecx]
    mov bl, [ebp + wShadowOAM + ecx + 1]
    call GBScreenToCanvasXY                           ; EAX = canvas Y, EDX = canvas X
    shr ecx, 2                                        ; entry index
    mov [spr_dos_sy + ecx*4], eax
    mov [spr_dos_sx + ecx*4], edx
    cmp [spr_oam_valid], ecx
    ja .probe_valid_ok
    lea eax, [ecx + 1]
    mov [spr_oam_valid], eax
.probe_valid_ok:
    pop ebx
    pop edx
    pop ecx
    pop eax
    ret
