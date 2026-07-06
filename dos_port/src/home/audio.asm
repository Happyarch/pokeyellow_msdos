; audio.asm — pret home/audio.asm translated to x86, plus the sound-wait
; helpers from pret home/delay.asm (PlaySoundWaitForCurrent,
; WaitForSoundToFinish) and FadeOutAudio from pret home/fade_audio.asm.
; All pret labels preserved.
;
; This is the gateway between game code and the banked sound engine. Banking
; collapses in the port: the four GB audio banks ($02/$08/$1F/$20) live in the
; AudioRom blob (assets/audio_rom.inc, slot 0/1/2/3), so GetNextMusicByte
; indexes the blob by wAudioROMBank instead of pret's hLoadedROMBank push /
; BankswitchCommon dance, and the homecall wrappers become plain calls.
;
; Register map (asm-translation skill): A=AL, BC=BX (B=BH, C=BL), DE=DX
; (D=DH, E=DL), HL=ESI, EBP = GB memory base; ECX/EDI port scratch.
;
; Helper-clobber contract (engine_1.asm relies on this):
;   GetNextMusicByte            clobbers EAX EDX ESI; preserves EBX ECX EDI
;   InitMusicVariables/InitSFXVariables/StopAllAudio preserve all but EAX
;   DetermineAudioFunction      clobbers EAX ECX EDX ESI EDI; preserves EBX

%include "gb_memmap.inc"
%include "assets/audio_constants.inc"

global PlayDefaultMusic
global PlayDefaultMusicFadeOutCurrent
global PlayDefaultMusicCommon
global CheckForNoBikingMusicMap
global UpdateMusic6Times
global UpdateMusicCTimes
global CompareMapMusicBankWithCurrentBank
global PlayMusic
global Func_2223
global StopAllMusic
global PlaySound
global GetNextMusicByte
global InitMusicVariables
global InitSFXVariables
global StopAllAudio
global DetermineAudioFunction
global PlaySoundWaitForCurrent
global WaitForSoundToFinish
global FadeOutAudio
global g_audio_engine_online

extern Audio1_UpdateMusic         ; src/audio/engine_1.asm
extern Audio1_PlaySound           ; src/audio/engine_1.asm
extern Audio2_PlaySound           ; src/audio/engine_2.asm
extern Audio3_PlaySound           ; src/audio/engine_3.asm
extern Audio4_PlaySound           ; src/audio/engine_4.asm
extern Audio2_InitMusicVariables  ; src/audio/engine_2.asm
extern Audio2_InitSFXVariables    ; src/audio/engine_2.asm
extern Audio2_StopAllAudio        ; src/audio/engine_2.asm
extern AudioRom                   ; src/data/audio_data.asm
extern DelayFrame                 ; src/video/frame.asm

section .text

; ---------------------------------------------------------------------------
PlayDefaultMusic:
    call WaitForSoundToFinish
    xor al, al
    mov bl, al                          ; c = 0 (no fade)
    mov dh, al                          ; d = 0
    mov [ebp + wLastMusicSoundID], al
    jmp PlayDefaultMusicCommon

PlayDefaultMusicFadeOutCurrent:
; Fade out the current music and then play the default music.
    mov bl, 10
    mov dh, 0
    mov al, [ebp + W_STATUS_FLAGS_4]
    test al, 1 << BIT_BATTLE_OVER_OR_BLACKOUT
    jz PlayDefaultMusicCommon
    xor al, al
    mov [ebp + wLastMusicSoundID], al
    mov bl, 8
    mov dh, bl
    ; fall through

PlayDefaultMusicCommon:
    mov al, [ebp + W_WALK_BIKE_SURF_STATE]
    test al, al
    jz .walking
    cmp al, 2
    jz .surfing
    call CheckForNoBikingMusicMap
    jc .walking
    mov al, MUSIC_BIKE_RIDING
    jmp .next

.surfing:
    mov al, MUSIC_SURFING

.next:
    mov bh, al                          ; b = music id
    mov al, dh
    test al, al                         ; should current music be faded out first?
    mov al, AUDIO_BANK_3                ; = BANK(Music_BikeRiding), $1f
    jnz .next2

; Only change the audio ROM bank if the current music isn't going to be faded
; out before the default music begins.
    mov [ebp + wAudioROMBank], al

.next2:
; [wAudioSavedROMBank] will be copied to [wAudioROMBank] after fading out the
; current music (if the current music is faded out).
    mov [ebp + wAudioSavedROMBank], al
    jmp .next3

.walking:
    mov al, [ebp + wMapMusicSoundID]
    mov bh, al
    call CompareMapMusicBankWithCurrentBank
    jc .next4

.next3:
    mov al, [ebp + wLastMusicSoundID]
    cmp al, bh                          ; is the default music already playing?
    jz .done                            ; if so, do nothing

.next4:
    mov al, bl
    mov [ebp + wAudioFadeOutControl], al
    mov al, bh
    mov [ebp + wLastMusicSoundID], al
    mov [ebp + wNewSoundID], al
    jmp PlaySound
.done:
    ret

CheckForNoBikingMusicMap:
; probably used to not change music upon getting on bike
    mov al, [ebp + W_CUR_MAP]
    cmp al, MAP_ID_ROUTE_23
    jz .found
    cmp al, MAP_ID_VICTORY_ROAD_1F
    jz .found
    cmp al, MAP_ID_VICTORY_ROAD_2F
    jz .found
    cmp al, MAP_ID_VICTORY_ROAD_3F
    jz .found
    cmp al, MAP_ID_INDIGO_PLATEAU
    jz .found
    test al, al                         ; and a — clear carry
    ret
.found:
    stc
    ret

; ---------------------------------------------------------------------------
UpdateMusic6Times:
    mov bl, 6
UpdateMusicCTimes:
.loop:
    push ebx
    push esi
    call Audio1_UpdateMusic             ; pret farcall — direct in the port
    pop esi
    pop ebx
    dec bl
    jnz .loop
    ret

; ---------------------------------------------------------------------------
CompareMapMusicBankWithCurrentBank:
; Compares the map music's audio ROM bank with the current audio ROM bank
; and updates the audio ROM bank variables.
; Returns whether the banks are different in carry.
    mov al, [ebp + wMapMusicROMBank]
    mov dl, al
    mov al, [ebp + wAudioROMBank]
    cmp al, dl
    jnz .differentBanks
    mov [ebp + wAudioSavedROMBank], al
    test al, al                         ; and a — clear carry
    ret
.differentBanks:
    mov al, bl                          ; this is a fade-out counter value and it's always non-zero
    test al, al
    mov al, dl
    jnz .next
; If the fade-counter is non-zero, we don't change the audio ROM bank because
; it's needed to keep playing the music as it fades out. The FadeOutAudio
; routine will take care of copying [wAudioSavedROMBank] to [wAudioROMBank]
; when the music has faded out.
    mov [ebp + wAudioROMBank], al
.next:
    mov [ebp + wAudioSavedROMBank], al
    stc
    ret

; ---------------------------------------------------------------------------
PlayMusic:
    mov bh, al
    mov [ebp + wNewSoundID], al
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    mov al, bl                          ; c = audio ROM bank
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    mov al, bh
    jmp PlaySound

Func_2223:
    xor al, al
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al
    mov [ebp + rAUD1SWEEP], al
    ret

StopAllMusic:
    mov al, SFX_STOP_ALL_MUSIC
    mov [ebp + wNewSoundID], al
; plays music specified by a. If value is $ff, music is stopped
PlaySound:
    ; TEMPORARY SCAFFOLD (retired by Task 5 audio_init): until the DelayFrame
    ; audio tick is installed, a started sound would never advance or end, so
    ; wChannelSoundIDs would stay non-zero forever and WaitForSoundToFinish
    ; would spin for good. Swallow requests while the engine is offline,
    ; keeping wNewSoundID consistent with "nothing playing".
    cmp byte [g_audio_engine_online], 0
    jnz .engineOnline
    mov byte [ebp + wNewSoundID], 0
    ret
.engineOnline:
    push esi
    push edx
    push ebx
    mov bh, al                          ; b = sound id
    mov al, [ebp + wNewSoundID]
    test al, al
    jz .next
    xor al, al
    mov [ebp + wChannelSoundIDs + CHAN5], al
    mov [ebp + wChannelSoundIDs + CHAN6], al
    mov [ebp + wChannelSoundIDs + CHAN7], al
    mov [ebp + wChannelSoundIDs + CHAN8], al
.next:
    mov al, [ebp + wAudioFadeOutControl]
    test al, al                         ; has a fade-out length been specified?
    jz .noFadeOut
    mov al, [ebp + wNewSoundID]
    test al, al                         ; is the new sound ID 0?
    jz .done                            ; if so, do nothing
    xor al, al
    mov [ebp + wNewSoundID], al
    mov al, [ebp + wLastMusicSoundID]
    cmp al, 0xFF                        ; has the music been stopped?
    jnz .fadeOut                        ; if not, fade out the current music
; If it has been stopped, start playing the new music immediately.
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
.noFadeOut:
    xor al, al
    mov [ebp + wNewSoundID], al
    call DetermineAudioFunction
    jmp .done

.fadeOut:
    mov al, bh
    mov [ebp + wLastMusicSoundID], al
    mov al, [ebp + wAudioFadeOutControl]
    mov [ebp + wAudioFadeOutCounterReloadValue], al
    mov [ebp + wAudioFadeOutCounter], al
    mov al, bh
    mov [ebp + wAudioFadeOutControl], al
.done:
    pop ebx
    pop edx
    pop esi
    ret

; ---------------------------------------------------------------------------
; c (BL) = software channel. Fetches the channel's next bytecode byte from the
; AudioRom blob and advances the command pointer. Returns the byte in AL.
; pret pushes hLoadedROMBank and switches to wAudioROMBank around the read;
; the port maps the bank to its blob slot instead (invalid banks default to
; slot 3, matching DetermineAudioFunction's default-to-audio-4 MissingNo. path).
GetNextMusicByte:
    movzx edx, bl
    movzx esi, word [ebp + wChannelCommandPointers + edx*2]  ; GB ptr (LE)
    lea eax, [esi + 1]
    mov [ebp + wChannelCommandPointers + edx*2], ax          ; ptr++
    mov al, [ebp + wAudioROMBank]
    xor edx, edx                        ; slot 0: bank $02
    cmp al, AUDIO_BANK_1
    jz .haveSlot
    inc edx                             ; slot 1: bank $08
    cmp al, AUDIO_BANK_2
    jz .haveSlot
    inc edx                             ; slot 2: bank $1f
    cmp al, AUDIO_BANK_3
    jz .haveSlot
    inc edx                             ; slot 3: bank $20 (and any invalid bank)
.haveSlot:
    shl edx, 14                         ; slot * 0x4000
    mov al, [AudioRom - 0x4000 + edx + esi]
    ret

; ---------------------------------------------------------------------------
; pret realizes these three as homecall wrappers (bankswitch to engine 2);
; the port keeps the push/pop shell so they preserve all registers but EAX —
; AudioCommon_PlaySound keeps live state in EBX/ECX/EDX/ESI/EDI across them.
InitMusicVariables:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call Audio2_InitMusicVariables
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

InitSFXVariables:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call Audio2_InitSFXVariables
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

StopAllAudio:
    push ebx
    push ecx
    push edx
    push esi
    push edi
    call Audio2_StopAllAudio
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; b (BH) = sound id. Selects the engine by wAudioROMBank (pret bankswitches;
; the port's engines are always resident).
DetermineAudioFunction:
    push ebx
    mov al, [ebp + wAudioROMBank]
    cmp al, AUDIO_BANK_1
    jnz .checkForAudio2
; audio 1
    mov al, bh
    call Audio1_PlaySound
    jmp .done

.checkForAudio2:
    cmp al, AUDIO_BANK_2
    jnz .checkForAudio3
; audio 2
    mov al, bh
    call Audio2_PlaySound
    jmp .done

.checkForAudio3:
    cmp al, AUDIO_BANK_3
    jnz .audio4
; audio 3
    mov al, bh
    call Audio3_PlaySound
    jmp .done

.audio4:
; invalid banks will default to audio 4
; this is seen when encountering Missingno,
; as its sprite dimensions overflow to wAudioROMBank
    mov al, bh
    call Audio4_PlaySound

.done:
    pop ebx
    ret

; ---------------------------------------------------------------------------
; pret home/delay.asm
PlaySoundWaitForCurrent:
    push eax
    call WaitForSoundToFinish
    pop eax
    jmp PlaySound

; Wait for sound to finish playing
WaitForSoundToFinish:
    mov al, [ebp + wLowHealthAlarm]
    and al, 0x80
    jnz .done
.waitLoop:
    xor al, al
    or al, [ebp + wChannelSoundIDs + CHAN5]
    or al, [ebp + wChannelSoundIDs + CHAN6]
    or al, [ebp + wChannelSoundIDs + CHAN8]  ; pret skips CHAN7 (inc hl x2)
    jz .done
    ; On the GB the VBlank ISR advanced the engine during this spin; in the
    ; port the audio tick lives in DelayFrame (Task 5), so pump it here —
    ; a bare spin would never see the sound IDs clear.
    call DelayFrame
    jmp .waitLoop
.done:
    ret

; ---------------------------------------------------------------------------
; pret home/fade_audio.asm — called once per audio tick, before the engine
; update, to step the volume fade driven by wAudioFadeOutControl.
FadeOutAudio:
    mov al, [ebp + wAudioFadeOutControl]
    test al, al                         ; currently fading out audio?
    jnz .fadingOut
    mov al, [ebp + wStatusFlags2]
    test al, 1 << BIT_NO_AUDIO_FADE_OUT
    jnz .ret
    mov byte [ebp + rAUDVOL], 0x77
.ret:
    ret
.fadingOut:
    mov al, [ebp + wAudioFadeOutCounter]
    test al, al
    jz .counterReachedZero
    dec al
    mov [ebp + wAudioFadeOutCounter], al
    ret
.counterReachedZero:
    mov al, [ebp + wAudioFadeOutCounterReloadValue]
    mov [ebp + wAudioFadeOutCounter], al
    mov al, [ebp + rAUDVOL]
    test al, al                         ; has the volume reached 0?
    jz .fadeOutComplete
    mov bh, al
    and al, 0x0F
    dec al
    mov bl, al                          ; c = right volume - 1
    mov al, bh
    and al, 0xF0
    ror al, 4                           ; swap a
    dec al                              ; left volume - 1 (in the low nibble)
    rol al, 4                           ; swap a
    or al, bl
    mov [ebp + rAUDVOL], al
    ret
.fadeOutComplete:
    mov al, [ebp + wAudioFadeOutControl]
    mov bh, al
    xor al, al
    mov [ebp + wAudioFadeOutControl], al
    call StopAllMusic
    mov al, [ebp + wAudioSavedROMBank]
    mov [ebp + wAudioROMBank], al
    mov al, bh
    mov [ebp + wNewSoundID], al
    jmp PlaySound

section .data

; 0 until audio_init (Task 5) installs the DelayFrame audio tick and device
; shim, then 1. Gates PlaySound (see the scaffold note there).
g_audio_engine_online:
    db 0
