; trainers2.asm — trainer name / pic / prize-money lookup, at the pret mirror
; of home/trainers2.asm.
;
; Moved here verbatim from the legacy trainer_engine.asm bundle (relocated-labels
; grind, 2026-07-24). Labels in pret's in-file order: GetTrainerInformation,
; IsFightingJessieJames, GetTrainerName. No fallthroughs (matches pret).
;
; STATUS: CHECK-ONLY (Makefile HOME_CHECK_SRCS) — nothing calls these at runtime
; until the M8.2 trainer-header engine wires the battle front-end.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/trainers2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "m8_2_pending_symbols.inc"   ; ROCKET, OPP_ID_OFFSET-era symbols

extern GetTrainerName_          ; src/engine/battle/get_trainer_name.asm
extern TrainerPicPointers       ; src/data/trainer_pics.asm  (flat dd, index=class-1)
extern TrainerBaseMoney         ; src/data/trainer_pics.asm  (bcd3 per class, index=class-1)
extern PlayerPicFront           ; src/data/trainer_pics.asm  (== pret RedPicFront)
extern JessieJamesPic           ; TODO(M8.2 follow-up): Tier-1 pic not in port TrainerPicPointers

global GetTrainerInformation
global IsFightingJessieJames
global GetTrainerName

section .text

; ----------------------------------------------------------------------------
; GetTrainerInformation — load the trainer's name + battle pic pointer + prize money.
; pret: home/trainers2.asm:GetTrainerInformation
; Adapted to the port's SPLIT flat tables (TrainerPicPointers / TrainerBaseMoney),
; not pret's interleaved TrainerPicAndMoneyPointers (5 bytes/entry).
; ----------------------------------------------------------------------------
GetTrainerInformation:
    call GetTrainerName
    mov al, [ebp + wLinkState]
    test al, al
    jnz .linkBattle
    ; class index = wTrainerClass - 1
    movzx eax, byte [ebp + wTrainerClass]
    dec eax
    ; wTrainerPicPointer (flat dword) = TrainerPicPointers[idx]
    mov edi, [TrainerPicPointers + eax*4]
    mov [ebp + wTrainerPicPointer], edi
    ; wTrainerBaseMoney (2-byte dw, pret ram/wram.asm:1400 `wTrainerBaseMoney:: dw`)
    ; = the TOP 2 BCD bytes of this class's bcd3 base money. OW-A.9: pret
    ; GetTrainerInformation (home/trainers2.asm) copies exactly 2 bytes — the low BCD
    ; byte (always $00 for the shipped values, e.g. 1500 = $00 $15 $00) is DELIBERATELY
    ; dropped (Gen-1 money-width quirk). The port previously copied all 3, which BOTH
    ; diverged from pret's value AND overflowed the 2-byte field by 1 byte into
    ; wTrainerBaseMoney+2 (a foreign WRAM cell). Copy 2 now, matching pret.
    lea esi, [eax + eax*2]                      ; idx*3 (bcd3 stride into the split table)
    add esi, TrainerBaseMoney
    mov al, [esi]                               ; high BCD byte
    mov [ebp + wTrainerBaseMoney + 0], al
    mov al, [esi + 1]                           ; second BCD byte (pret keeps 2, drops [esi+2])
    mov [ebp + wTrainerBaseMoney + 1], al
    call IsFightingJessieJames
    ret
.linkBattle:
    mov edi, PlayerPicFront         ; pret RedPicFront
    mov [ebp + wTrainerPicPointer], edi
    ret

; ----------------------------------------------------------------------------
; IsFightingJessieJames — override the pic for the Jessie&James Rocket duo.
; pret: home/trainers2.asm:IsFightingJessieJames
; ----------------------------------------------------------------------------
IsFightingJessieJames:
    mov al, [ebp + wTrainerClass]
    cmp al, ROCKET
    jne .ret
    mov al, [ebp + wTrainerNo]
    cmp al, 0x2a
    jb .ret                         ; below the Jessie&James range
    ; both the <$2e and >=$2e pret branches use JessieJamesPic (the second is a no-op dup)
    mov edi, JessieJamesPic         ; TODO(M8.2 follow-up): pic not in port table yet
    mov [ebp + wTrainerPicPointer], edi
.ret:
    ret

; ----------------------------------------------------------------------------
; GetTrainerName — pret farjp GetTrainerName_ (flat: direct jmp).
; pret: home/trainers2.asm:GetTrainerName
; ----------------------------------------------------------------------------
GetTrainerName:
    jmp GetTrainerName_
