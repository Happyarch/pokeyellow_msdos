; dos_port/src/engine/pikachu/pikachu_status.asm
; ============================================================
; Starter-Pikachu identity / status predicates — faithful port of pret
; engine/pikachu/pikachu_status.asm.
;
; A mon is "the player's starter Pikachu" iff species == STARTER_PIKACHU AND its
; OT id + OT name match the player's. These drive Yellow-specific behavior
; (Pikachu mood, follow sprite, cry, and evolution's THUNDER/THUNDERBOLT mood
; bump in LearnMoveFromLevelUp).
;
; Register map: A=AL, HL=ESI, DE=EDX (D=DH, E=DL), BC=EBX (B=BH, C=BL).
; WRAM at [ebp+addr]; [hl]/[de]/[bc] -> [ebp+esi]/[ebp+edx]/[ebp+ebx].
; Pointer registers are loaded 32-bit (mov edx,/mov ebx,) rather than 16-bit so
; the high halves stay clean when the value is later used as a flat GB offset.
;
; NOTE (pret quirk, preserved): IsStarterPikachuAliveInOurParty computes the HP
; pointer as OTID_ptr + (wPartyMon1HP - wPartyMon1OTID) = OTID_ptr - 11. pret
; relies on 16-bit `add hl, bc` wraparound; here it is a plain signed add of -11.
;
; pret's IsSurfingStarterPikachuInParty is intentionally omitted (no linked caller
; yet; it would pull in SURF / wPartyMon1Moves deps).

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global IsStarterPikachuAliveInOurParty
global IsThisBoxMonStarterPikachu
global IsThisPartyMonStarterPikachu
global UpdatePikachuMoodAfterBattle
global CheckPikachuStatusCondition

extern AddNTimes                ; src/home/array.asm — ESI += AL*BX (clobbers EAX/ECX)

; ===========================================================================
; IsStarterPikachuAliveInOurParty
; Out: CF set iff the player's starter Pikachu is in the party AND not fainted.
; Pret ref: engine/pikachu/pikachu_status.asm.
; ===========================================================================
IsStarterPikachuAliveInOurParty:
    mov esi, wPartySpecies          ; hl = species list
    mov edx, wPartyMon1OTID         ; de = first mon's OT id
    mov ebx, wPartyMonOT            ; bc = first mon's OT name
    push esi
.loop:
    pop esi
    mov al, [ebp + esi]             ; ld a, [hli]
    inc esi
    push esi
    inc al                          ; $FF sentinel -> 0 (Z)
    jz .noPlayerPikachu
    cmp al, STARTER_PIKACHU + 1     ; al is species+1
    jne .curMonNotPlayerPikachu

    mov esi, edx                    ; ld h,d / ld l,e  (hl = OTID ptr)
    mov al, [ebp + wPlayerID]
    cmp al, [ebp + esi]
    jne .curMonNotPlayerPikachu
    inc esi
    mov al, [ebp + wPlayerID + 1]
    cmp al, [ebp + esi]
    jne .curMonNotPlayerPikachu

    push edx
    push ebx
    mov esi, wPlayerName
    mov dh, NAME_LENGTH_JP          ; ld d, NAME_LENGTH_JP  (counter)
.nameCompareLoop:
    dec dh
    jz .sameOT
    mov al, [ebp + ebx]             ; ld a, [bc]
    inc ebx
    cmp al, [ebp + esi]             ; cp [hl]
    lea esi, [esi + 1]              ; inc hl — lea preserves the cmp ZF (inc would not)
    je .nameCompareLoop
    pop ebx
    pop edx

.curMonNotPlayerPikachu:
    mov esi, wPartyMon2 - wPartyMon1   ; ld hl, stride
    add esi, edx                       ; add hl, de
    mov edx, esi                       ; ld d,h / ld e,l  (de += stride)
    mov esi, NAME_LENGTH               ; ld hl, NAME_LENGTH
    add esi, ebx                       ; add hl, bc
    mov ebx, esi                       ; ld b,h / ld c,l  (bc += NAME_LENGTH)
    jmp .loop

.sameOT:
    pop ebx
    pop edx
    mov esi, edx                       ; ld h,d / ld l,e  (hl = OTID ptr)
    add esi, wPartyMon1HP - wPartyMon1OTID  ; += -11 -> HP ptr (pret: ld bc,neg / add hl)
    mov al, [ebp + esi]                ; ld a, [hli]
    inc esi
    or al, [ebp + esi]                 ; or [hl]
    jz .noPlayerPikachu                ; HP == 0 -> fainted
    pop esi
    stc
    ret

.noPlayerPikachu:
    pop esi
    clc
    ret

; ===========================================================================
; IsThisBoxMonStarterPikachu / IsThisPartyMonStarterPikachu
; In:  [wWhichPokemon] = index. Out: CF set iff that mon is the starter Pikachu.
; Pret ref: engine/pikachu/pikachu_status.asm (shared IsThisMonStarterPikachu).
; ===========================================================================
IsThisBoxMonStarterPikachu:
    mov esi, wBoxMon1
    mov ebx, wBoxMon2 - wBoxMon1     ; stride (AddNTimes reads BX)
    mov edx, wBoxMonOT
    jmp IsThisMonStarterPikachu

IsThisPartyMonStarterPikachu:
    mov esi, wPartyMon1
    mov ebx, wPartyMon2 - wPartyMon1
    mov edx, wPartyMonOT
IsThisMonStarterPikachu:
    mov al, [ebp + wWhichPokemon]
    call AddNTimes                   ; esi = &mon[wWhichPokemon]
    mov al, [ebp + esi]              ; ld a, [hl]  (species)
    cmp al, STARTER_PIKACHU
    jne .notPlayerPikachu

    add esi, wPartyMon1OTID - wPartyMon1  ; ld bc, off / add hl, bc  (+12)
    mov al, [ebp + wPlayerID]
    cmp al, [ebp + esi]
    jne .notPlayerPikachu
    inc esi
    mov al, [ebp + wPlayerID + 1]
    cmp al, [ebp + esi]
    jne .notPlayerPikachu

    mov esi, edx                     ; ld h,d / ld l,e  (hl = OT-name base)
    mov al, [ebp + wWhichPokemon]
    mov ebx, NAME_LENGTH
    call AddNTimes                   ; esi = &OTname[wWhichPokemon]
    mov edx, wPlayerName             ; ld de, wPlayerName
    mov bh, NAME_LENGTH_JP           ; ld b, NAME_LENGTH_JP  (B = BH, counter)
.nameLoop:
    dec bh
    jz .isPlayerPikachu
    mov al, [ebp + edx]              ; ld a, [de]
    inc edx
    cmp al, [ebp + esi]              ; cp [hl]
    lea esi, [esi + 1]               ; inc hl — lea preserves the cmp ZF (inc would not)
    je .nameLoop
.notPlayerPikachu:
    clc                              ; and a
    ret
.isPlayerPikachu:
    stc
    ret

; ===========================================================================
; UpdatePikachuMoodAfterBattle
; Raises the starter Pikachu's mood toward D (always $82 in practice, so a
; floor of ~130). Pret ref: engine/pikachu/pikachu_status.asm.
; ===========================================================================
UpdatePikachuMoodAfterBattle:
    push edx
    call IsStarterPikachuAliveInOurParty
    pop edx
    jnc .ret                          ; ret nc
    mov al, dh                        ; ld a, d
    cmp al, 128
    mov al, [ebp + wPikachuMood]      ; mov preserves flags (ld a, [wPikachuMood])
    jc .d_less_than_128               ; "we never jump" (d is always $82)
    cmp al, dh                        ; cp d
    jc .load_d_into_mood
    ret
.d_less_than_128:
    cmp al, dh                        ; cp d
    jc .ret                           ; ret c
.load_d_into_mood:
    mov al, dh                        ; ld a, d
    mov [ebp + wPikachuMood], al
.ret:
    ret

; ===========================================================================
; CheckPikachuStatusCondition
; Out: CF set iff the starter Pikachu has a non-volatile status condition.
;      (pret also returns D = HP-zero flag, but no caller uses it.)
; Pret ref: engine/pikachu/pikachu_status.asm.
; ===========================================================================
CheckPikachuStatusCondition:
    xor al, al
    mov [ebp + wWhichPokemon], al
    mov esi, wPartyCount
.loop:
    inc esi
    mov al, [ebp + esi]
    cmp al, 0xFF
    je .noAilment
    push esi
    call IsThisPartyMonStarterPikachu
    pop esi
    jnc .next

    mov al, [ebp + wWhichPokemon]
    mov esi, wPartyMon1HP
    mov ebx, wPartyMon2 - wPartyMon1
    call AddNTimes                    ; esi = &mon[wWhichPokemon].HP
    mov al, [ebp + esi]               ; ld a, [hli]
    inc esi
    or al, [ebp + esi]                ; or [hl]  (HP == 0?)
    mov dh, al                        ; ld d, a
    inc esi
    inc esi
    mov al, [ebp + esi]               ; ld a, [hl]  (status)
    test al, al
    jnz .hasAilment
    jmp .noAilment

.next:
    mov al, [ebp + wWhichPokemon]
    inc al
    mov [ebp + wWhichPokemon], al
    jmp .loop

.hasAilment:
    stc
    ret
.noAilment:
    clc
    ret
