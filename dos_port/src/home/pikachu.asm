; pikachu.asm — pret mirror of home/pikachu.asm.
;
; The overworld Pikachu-follower plumbing pret keeps in the home bank: the state
; flag setters/testers, the SpawnPikachu home wrapper, Pikachu_IsInArray, and the
; movement-script accessors. Consolidated here from
; src/engine/pikachu/pikachu_follow.asm, which keeps the three
; engine/pikachu/pikachu_follow.asm labels (ShouldPikachuSpawn, TrySpawnPikachu,
; ResetPikachuOverworldStateFlag2) and the SpawnPikachu_ body they belong with.
;
; The follower-spawn plumbing is INERT in the live build (nothing enables the
; follower), but the movement-script accessors are NOT: the Poké Center heal
; flow reaches them through PikachuWalksToNurseJoy when the party holds the
; starter Pikachu. See the source file's header for the full deferral note.
;
; Register map (CLAUDE.md): A->AL, HL->ESI, BC->BX (B=BH,C=BL), DE->DX; SM83
; `swap a` = nibble swap = `ror al, 4`. GB memory = [ebp + SYM] (gb_memmap.inc).

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

extern BankswitchCommon                 ; src/home/bankswitch2.asm
extern _SpawnPikachu                    ; src/engine/pikachu/pikachu_follow.asm — pret SpawnPikachu_

global SpawnPikachu
global Func_1510
global Func_151d
global EnablePikachuOverworldSpriteDrawing
global DisablePikachuOverworldSpriteDrawing
global DisablePikachuFollowingPlayer
global EnablePikachuFollowingPlayer
global CheckPikachuFollowingPlayer
global Pikachu_IsInArray
global GetPikachuMovementScriptByte
global ApplyPikachuMovementData

section .text

; BANK() of the engine-bank Pikachu routines. Cosmetic under the flat model:
; BankswitchCommon only records the requested bank in hLoadedROMBank (no MBC),
; so the exact numeric value is bookkeeping. pret assigns the "Overworld Pikachu"
; ROMX section bank $3F. Use a named constant.
BANK_PikachuOverworld                equ 0x3F  ; pret "Overworld Pikachu" bank; flat-model bookkeeping only

; ===========================================================================
; State plumbing — pret home/pikachu.asm
; wPikachuOverworldStateFlags bit meanings (from pret usage):
;   bit 1 = Pikachu is following the player
;   bit 2 = Pikachu moved this frame (Set/ResetPikachuOverworldStateFlag2)
;   bit 3 = overworld sprite drawing disabled
;   bit 5 / bit 7 = hide Pikachu
; The SM83 `push hl/pop hl` in each routine merely preserves HL; here we address
; the flags via [ebp+SYM] and never touch ESI, so no save/restore is needed.
; ===========================================================================

; Func_1510 — pret home/pikachu.asm:Func_1510. Set hide-bit 7 and blank the
; sprite image index ($ff = off screen).
Func_1510:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x80          ; set 7, [hl]
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF   ; ld [hl], $ff
    ret

; Func_151d — pret home/pikachu.asm:Func_151d. Clear hide-bit 7.
Func_151d:
    and byte [ebp + wPikachuOverworldStateFlags], 0x7F          ; res 7, [hl]
    ret

; EnablePikachuOverworldSpriteDrawing — pret home/pikachu.asm. Clear draw-disable bit 3.
EnablePikachuOverworldSpriteDrawing:
    and byte [ebp + wPikachuOverworldStateFlags], 0xF7          ; res 3, [hl]
    ret

; DisablePikachuOverworldSpriteDrawing — pret home/pikachu.asm. Set draw-disable
; bit 3 and blank the image index.
DisablePikachuOverworldSpriteDrawing:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x08          ; set 3, [hl]
    mov byte [ebp + wSpritePikachuStateData1ImageIndex], 0xFF   ; ld [hl], $ff
    ret

; DisablePikachuFollowingPlayer — pret home/pikachu.asm. Set following-disable bit 1.
DisablePikachuFollowingPlayer:
    or  byte [ebp + wPikachuOverworldStateFlags], 0x02          ; set 1, [hl]
    ret

; EnablePikachuFollowingPlayer — pret home/pikachu.asm. Clear bit 1 (Pikachu follows).
EnablePikachuFollowingPlayer:
    and byte [ebp + wPikachuOverworldStateFlags], 0xFD          ; res 1, [hl]
    ret

; CheckPikachuFollowingPlayer — pret home/pikachu.asm. Test bit 1; returns ZF as
; the SM83 `bit 1,[hl]` would (callers branch on jr z/nz). ZF set => not following.
CheckPikachuFollowingPlayer:
    test byte [ebp + wPikachuOverworldStateFlags], 0x02         ; bit 1, [hl]
    ret

; ===========================================================================
; SpawnPikachu — pret home/pikachu.asm:SpawnPikachu (the home wrapper the M6.2
; _UpdateSprites slot-$f0 dispatch calls). On entry hCurrentSpriteOffset == $f0
; (slot 15) and, in pret, HL points at wSpritePikachuStateData2ImageBaseOffset
; ($C2FE). We re-derive that field from hCurrentSpriteOffset (matching the port's
; UpdateNonPlayerSprite convention), compute the VRAM tile group into
; hTilePlayerStandingOn, then homecall the engine-bank body.
;
;   pret:
;     ld a, [hl]                 ; wSpritePikachuStateData2ImageBaseOffset
;     dec a
;     swap a
;     ldh [hTilePlayerStandingOn], a
;     homecall SpawnPikachu_
;     ret
; ===========================================================================
SpawnPikachu:
    movzx esi, byte [ebp + hCurrentSpriteOffset]   ; esi = $f0 (slot 15 base offset)
    mov al, [ebp + esi + wSpriteStateData2 + SPRITESTATEDATA2_IMAGEBASEOFFSET] ; ld a,[hl]
    dec al                                             ; dec a
    ror al, 4                                          ; swap a (nibble swap)
    mov [ebp + hTilePlayerStandingOn], al          ; ldh [hTilePlayerStandingOn], a
    ; --- homecall SpawnPikachu_  (macros/farcall.asm) ---
    mov al, [ebp + hLoadedROMBank]                  ; ldh a,[hLoadedROMBank]
    push eax                                           ; push af
    mov al, BANK_PikachuOverworld                      ; ld a, BANK(SpawnPikachu_)
    call BankswitchCommon
    call _SpawnPikachu                                 ; call SpawnPikachu_
    pop eax                                            ; pop af (AL = saved bank)
    call BankswitchCommon
    ret

; ===========================================================================
; Pikachu_IsInArray — pret home/pikachu.asm:Pikachu_IsInArray.
; Search a $ff-terminated byte array [ESI..] for AL. On found: carry set, ESI at
; the matching entry, BH = 1-based match index. On miss: carry clear, ESI at the
; terminator, BH = count. NOTE: distinct from the linked home global IsInArray —
; this variant walks single bytes (stride 1) and reports the index in B.
; ===========================================================================
Pikachu_IsInArray:
    xor bh, bh                  ; ld b, $0
    mov bl, al                  ; ld c, a  (target)
.loop:
    inc bh                      ; inc b
    mov al, [ebp + esi]         ; ld a, [hli]
    inc esi
    cmp al, 0xFF
    je  .not_in_array           ; jr z, .not_in_array
    cmp al, bl                  ; cp c
    jne .loop                   ; jr nz, .loop
    dec bh                      ; dec b
    dec esi                     ; dec hl
    stc                         ; scf
    ret
.not_in_array:
    dec bh                      ; dec b
    dec esi                     ; dec hl
    clc                         ; and a (carry clear)
    ret

; ===========================================================================
; GetPikachuMovementScriptByte — pret home/pikachu.asm. Fetch the next byte of
; the active Pikachu movement script, advancing the cursor. Returns AL.
; Preserves the emulated BC (BX) and HL (ESI).
;
;   pret:
;     push hl / push bc
;     ldh a,[hLoadedROMBank] / push af
;     ld a,[wPikachuMovementScriptBank] / call BankswitchCommon
;     ld hl, wPikachuMovementScriptAddress
;     ld c,[hl] / inc hl / ld b,[hl]     ; bc = script cursor
;     ld a,[bc] / inc bc                 ; fetch, advance
;     ld [hl],b / dec hl / ld [hl],c     ; store cursor back (LE)
;     ld c,a
;     pop af / call BankswitchCommon
;     ld a,c / pop bc / pop hl / ret
; ===========================================================================
; DEVIATION{class=data-model; pret=home/pikachu.asm:GetPikachuMovementScriptByte; behavior=the movement-script byte is fetched through a port-only flat 32-bit cursor (g_pika_script_ptr, published by ApplyPikachuMovementData_) instead of pret's banked 16-bit wPikachuMovementScriptAddress read through GB space, which is still stored and advanced byte-faithfully; evidence=the movement scripts are flat program-image data (.PikaMovementData1 in engine/pikachu/pikachu_emotions.asm), so the GB-space [ebp+cursor] read fetched WRAM garbage as command bytes and indexed PikachuMovementDatabase out of range - the nurse heal cutscene then jumped through the movement jumptable to a wild EIP (page fault cr2=f0c3fc eip=b0c3ff, measured 2026-08-25), the same flat-vs-banked class the text engine documents in home/text_script.asm; lifetime=permanent while movement scripts live as flat image data}
; The old body's TODO-HW note claimed the GB-space read was "Inert today" —
; that was written before any caller staged a flat script pointer; the nurse
; heal flow (PikachuWalksToNurseJoy) calls this for real and faulted.
; ===========================================================================
GetPikachuMovementScriptByte:
    push esi                                             ; push hl
    push ebx                                             ; push bc
    ; Fetch through the flat cursor (pret: bankswitch + ld a,[bc]).
    mov esi, [g_pika_script_ptr]
    movzx ecx, byte [esi]                                ; hold fetched byte in ECX scratch
    inc esi
    mov [g_pika_script_ptr], esi
    ; Advance the faithful 16-bit WRAM cursor too (pret stores it back; other
    ; readers of the byte pair keep their pret semantics).
    movzx ebx, word [ebp + wPikachuMovementScriptAddress]
    inc bx
    mov [ebp + wPikachuMovementScriptAddress], bx        ; store cursor back (ld[hl],b/ld[hl],c)
    mov al, cl                                           ; ld a, c (result byte)
    pop ebx                                              ; pop bc (caller's BC restored)
    pop esi                                              ; pop hl
    ret

; ===========================================================================
; ApplyPikachuMovementData — pret home/pikachu.asm. Home wrapper that banks to the
; engine routine and applies one step of Pikachu movement data.
;
;   pret:
;     ldh a,[hLoadedROMBank] / ld b,a / push af
;     ld a, BANK(ApplyPikachuMovementData_) / call BankswitchCommon
;     call ApplyPikachuMovementData_
;     pop af / call BankswitchCommon / ret
; ===========================================================================
ApplyPikachuMovementData:
    mov al, [ebp + hLoadedROMBank]                    ; ldh a,[hLoadedROMBank]
    mov bh, al                                           ; ld b, a (pret sets B; unused after)
    push eax                                             ; push af (save current bank)
    mov al, BANK_PikachuOverworld                        ; ld a, BANK(ApplyPikachuMovementData_)
    call BankswitchCommon
    call ApplyPikachuMovementData_
    pop eax                                              ; pop af (AL = saved bank)
    call BankswitchCommon
    ret

; ApplyPikachuMovementData_ (pret engine/pikachu/pikachu_movement.asm) —
; movement-data interpreter (wCurPikaMovementData union, step timers, sprite placement).
extern ApplyPikachuMovementData_        ; src/engine/pikachu/pikachu_movement.asm

; ---------------------------------------------------------------------------
; g_pika_script_ptr — PORT-ONLY flat cursor for the active Pikachu movement
; script (the data-model twin of the text engine's flat-table pointers). pret's
; wPikachuMovementScriptAddress is a 16-bit banked-ROM cursor and stays
; byte-faithful in WRAM, but the scripts themselves are flat program-image
; data, so the fetcher must walk this pointer instead. Published by
; ApplyPikachuMovementData_ (src/engine/pikachu/pikachu_movement.asm) from the
; ESI the caller hands it (.PikaMovementData1/2/3 in pikachu_emotions.asm);
; consumed and advanced by GetPikachuMovementScriptByte above.
; ---------------------------------------------------------------------------
section .data
align 4
global g_pika_script_ptr
g_pika_script_ptr: dd 0
section .text

