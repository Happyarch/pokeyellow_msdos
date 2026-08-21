; poison.asm — Out-of-battle poison damage and Pikachu happiness/mood updates.
;
; Faithful translation of pret engine/events/poison.asm.
;
; Register map: A=AL, B=BH, C=BL, D=DH, E=DL, HL=ESI; GB memory at [EBP + addr].
;
; POINTER MODEL inside ApplyOutOfBattlePoisonDamage: pret's hl and de are both
; WRAM walkers, so ESI and the FULL EDX carry them (32-bit GB offsets, read as
; [ebp + reg]). EDX therefore doubles as pret's de pair: the two places that use
; DH/DL as the 8-bit d/e registers (the ldpikacry/ModifyPikachuHappiness arguments
; and the .countPoisonedLoop counters) are each either inside pret's own
; push de / pop de, or past the point where the de walker is dead.
;
; NOT YET WIRED: pret calls this from home/overworld.asm:260
; (`predef ApplyOutOfBattlePoisonDamage`) inside OverworldLoopLessDelay. The port's
; OverworldLoop has that seam marked "poison/safari, deferred"
; (src/home/overworld.asm:1492) and does not call it, so the routine is defined and
; linked but not reached. Wiring it is an overworld-loop change, not a change to
; this file.
;
; Build: nasm -f coff -I include/ -I . -o poison.o src/engine/events/poison.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "assets/script_constants.inc"
%include "assets/audio_constants.inc"

global ApplyOutOfBattlePoisonDamage
global UpdatePikachuHappinessAndMood

extern IncrementDayCareMonExp           ; src/engine/overworld/daycare_exp.asm
extern GetPartyMonName                  ; src/home/pokemon.asm
extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern DisplayTextID                    ; src/home/text_script.asm
extern IsThisPartyMonStarterPikachu     ; src/engine/pikachu/pikachu_status.asm
extern PlayPikachuSoundClip             ; src/audio/pikachu_pcm.asm
extern ModifyPikachuHappiness           ; src/engine/events/pikachu_happiness.asm
extern DelayFrames                      ; src/home/delay.asm — BL = frame count
extern UpdateCGBPal_BGP                 ; src/home/cgb_palettes.asm
extern PlaySound                        ; src/home/audio.asm
extern AnyPartyAlive                    ; src/engine/battle/core.asm
extern Random                           ; src/home/random.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; ApplyOutOfBattlePoisonDamage — pret engine/events/poison.asm:ApplyOutOfBattlePoisonDamage
; ─────────────────────────────────────────────────────────────────────────────
ApplyOutOfBattlePoisonDamage:
    mov al, [ebp + wStatusFlags5]
    ; ASSERT BIT_SCRIPTED_MOVEMENT_STATE == 7
    add al, al                          ; overflows scripted movement state bit into carry flag
    jc .noBlackOut                      ; no black out if joypad states are being simulated
    test byte [ebp + wPikachuMapScriptFlags], 1 << BIT_PIKACHU_MAP_SCRIPT_ACTIVE
    jnz .noBlackOut
    test byte [ebp + wStatusFlags4], 1 << BIT_LINK_CONNECTED
    jnz .noBlackOut
    mov al, [ebp + wPartyCount]
    test al, al
    jz .noBlackOut
    call IncrementDayCareMonExp
    call UpdatePikachuHappinessAndMood
    mov al, [ebp + wStepCounter]
    and al, 0x03                        ; is the counter a multiple of 4?
    jnz .skipPoisonEffectAndSound       ; only apply poison damage every fourth step
    mov [ebp + wWhichPokemon], al
    mov esi, wPartyMon1Status
    mov edx, wPartySpecies
.applyDamageLoop:
    mov al, [ebp + esi]
    test al, 1 << PSN
    jz .nextMon2                        ; not poisoned
    sub esi, 2                          ; dec hl / dec hl -> points to HP low byte
    mov al, [ebp + esi]                 ; ld a, [hld] -> HP low byte
    dec esi                             ; hl -> HP high byte
    mov bh, al                          ; ld b, a
    mov al, [ebp + esi]                 ; ld a, [hli] -> HP high byte
    inc esi                             ; hl -> HP low byte
    or al, bh
    jz .nextMon                         ; already fainted
; subtract 1 from HP
    mov al, [ebp + esi]                 ; ld a, [hl]
    dec al
    mov [ebp + esi], al                 ; ld [hld], a -> store HP low byte
    dec esi                             ; hl -> HP high byte
    inc al
    jnz .noBorrow
; borrow 1 from upper byte of HP
    dec byte [ebp + esi]                ; dec [hl] -> HP high byte
    inc esi                             ; inc hl -> HP low byte
    jmp .nextMon
.noBorrow:
    mov al, [ebp + esi]                 ; ld a, [hli] -> HP high byte
    inc esi                             ; hl -> HP low byte
    or al, [ebp + esi]                  ; or [hl]
    jnz .nextMon                        ; didn't faint from damage
; the mon fainted from the damage
    push esi                            ; push hl (HP low byte)
    add esi, 2                          ; inc hl / inc hl -> Status byte
    mov [ebp + esi], al                 ; ld [hl], a (al is 0 from `or [hl]`)
    mov al, [ebp + edx]                 ; ld a, [de]
    mov [ebp + wPokedexNum], al
    push edx                            ; push de
    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMonNicks
    call GetPartyMonName
    xor al, al
    mov [ebp + wJoyIgnore], al
    call EnableAutoTextBoxDrawing
    mov al, TEXT_MON_FAINTED
    mov [ebp + hTextID], al
    call DisplayTextID
    call IsThisPartyMonStarterPikachu
    jnc .curMonNotPlayerPikachu
    mov dl, 3                           ; ldpikacry e, PikachuCry4 (0-based)
    call PlayPikachuSoundClip
    mov dh, PIKAHAPPY_PSNFNT
    call ModifyPikachuHappiness
.curMonNotPlayerPikachu:
    pop edx                             ; pop de
    pop esi                             ; pop hl (HP low byte)
.nextMon:
    add esi, 2                          ; inc hl / inc hl -> Status byte
.nextMon2:
    inc edx                             ; inc de
    mov al, [ebp + edx]
    cmp al, 0xFF                        ; inc a / jr z .applyDamageLoopDone
    jz .applyDamageLoopDone
    add esi, PARTYMON_STRUCT_LENGTH     ; ld bc, PARTYMON_STRUCT_LENGTH / add hl, bc
    inc byte [ebp + wWhichPokemon]      ; inc [hl] on wWhichPokemon
    jmp .applyDamageLoop
.applyDamageLoopDone:
    mov esi, wPartyMon1Status
    mov al, [ebp + wPartyCount]
    mov dh, al                          ; ld d, a
    xor dl, dl                          ; ld e, 0
.countPoisonedLoop:
    mov al, [ebp + esi]
    and al, 1 << PSN
    or dl, al                           ; or e / ld e, a
    add esi, PARTYMON_STRUCT_LENGTH     ; add hl, bc
    ; 8-BIT counter, deliberately: pret is `dec d / jr nz`, so d = 0 on entry
    ; would run 256 times and stop. It cannot be 0 here (the wPartyCount == 0
    ; early-out above guarantees it), but the width stays pret's regardless —
    ; widening to `dec edx` would turn that bound into ~4 billion iterations.
    dec dh                              ; dec d
    jnz .countPoisonedLoop
    test dl, dl                         ; ld a, e / and a
    jz .skipPoisonEffectAndSound
    mov bh, 0x02                        ; ld b, $2 — pret's predef argument, which
                                        ; the callee never reads (its opening
                                        ; `call GetPredefRegisters` is, in pret's
                                        ; own words, a red/blue leftover). Kept so
                                        ; the call site matches pret line for line.
; pret: predef ChangeBGPalColor0_4Frames ; change BG white to dark gray for 4 frames
;
; The callee's body is spelled out here, line for line against pret
; engine/gfx/screen_effects.asm:ChangeBGPalColor0_4Frames, because that routine has
; no port body yet and its mirror file is outside this change's file allow-list.
; It is written to be LIFTED verbatim: when the routine lands at
; src/engine/gfx/screen_effects.asm, delete these six lines and put back
; `call ChangeBGPalColor0_4Frames`.
;
; DEVIATION{class=temporary; pret=engine/events/poison.asm:ApplyOutOfBattlePoisonDamage; behavior=the body of ChangeBGPalColor0_4Frames is spelled out at the call site instead of being called, so faithdiff reports it as a DROPPED call; evidence=grep of dos_port/src finds no definition of ChangeBGPalColor0_4Frames and its mirror file src/engine/gfx/screen_effects.asm is outside this change's allow-list, the inlined sequence is byte-for-byte pret's including the UpdateCGBPal_BGP calls; lifetime=until ChangeBGPalColor0_4Frames is ported at src/engine/gfx/screen_effects.asm and this call site becomes a call}
    mov al, [ebp + IO_BGP]              ; ldh a, [rBGP]
    xor al, 0xFF                        ; xor $ff
    mov [ebp + IO_BGP], al              ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov bl, 4                           ; ld c, 4
    call DelayFrames
    mov al, [ebp + IO_BGP]              ; ldh a, [rBGP]
    xor al, 0xFF                        ; xor $ff
    mov [ebp + IO_BGP], al              ; ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov al, SFX_POISONED
    call PlaySound
.skipPoisonEffectAndSound:
; DEVIATION{class=banking; pret=engine/events/poison.asm:ApplyOutOfBattlePoisonDamage; behavior=predef dispatch replaced by a direct call to AnyPartyAlive; evidence=the port's AnyPartyAlive does not open with GetPredefRegisters and takes no predef argument, so the flat direct call is the documented port convention, see src/home/predef.asm; lifetime=permanent, flat memory model}
    call AnyPartyAlive                  ; predef AnyPartyAlive — returns the HP OR in DH
    mov al, dh                          ; ld a, d
    test al, al
    jnz .noBlackOut
    call EnableAutoTextBoxDrawing
    mov al, TEXT_BLACKED_OUT
    mov [ebp + hTextID], al
    call DisplayTextID
    or byte [ebp + wStatusFlags4], 1 << BIT_BATTLE_OVER_OR_BLACKOUT
    mov al, 0xFF
    jmp .done
.noBlackOut:
    xor al, al
.done:
    mov [ebp + wOutOfBattleBlackout], al
    ret

; ─────────────────────────────────────────────────────────────────────────────
; UpdatePikachuHappinessAndMood — pret engine/events/poison.asm:UpdatePikachuHappinessAndMood
; ─────────────────────────────────────────────────────────────────────────────
UpdatePikachuHappinessAndMood:
    mov al, [ebp + wStepCounter]
    test al, al                         ; and a
    jnz .noWalkingHappinessIncrease     ; only increase Pikachu's happiness every 256 steps
    call Random
    and al, 1                           ; 50% chance to increase happiness
    jz .noWalkingHappinessIncrease
    mov dh, PIKAHAPPY_WALKING
    call ModifyPikachuHappiness
.noWalkingHappinessIncrease:
; every step, mood converges by 1 unit towards the central value of 128:
; if it's lower than 128 it increases by 1, if it's higher, it decreases
    mov al, [ebp + wPikachuMood]
    cmp al, 128                         ; central value
    jz .clearEmotionModifier            ; mood == 128, don't modify it
    jb .increaseMood                    ; mood < 128, must increase by 1
    ; mood > 128, must decrease by 1 (so decrease by 2 and then increase by 1)
    dec al
    dec al
.increaseMood:
    inc al
    mov [ebp + wPikachuMood], al
; if the mood has reached its "stable" central value, do not update the emotion modifier
    cmp al, 128
    jnz .done
.clearEmotionModifier:
    xor al, al
    mov [ebp + wPikachuEmotionModifier], al ; variable used in other mood-related functions, to keep track if the mood was "stable"
.done:
    ret
