; trainers2.asm — trainer name / pic / prize-money lookup, at the pret mirror
; of home/trainers2.asm.
;
; Moved here verbatim from the legacy trainer_engine.asm bundle (relocated-labels
; grind, 2026-07-24). Labels in pret's in-file order: GetTrainerInformation,
; IsFightingJessieJames, GetTrainerName. No fallthroughs (matches pret).
;
; STATUS: LINKED. InitBattle's trainer branch calls GetTrainerInformation before
; ReadTrainer so the class name, production picture pointer, and prize base are
; ready before the first enemy party mon is selected.
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
;
; Build (check): nasm -f coff -I include/ -I . -o /dev/null src/home/trainers2.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern GetTrainerName_          ; src/engine/battle/get_trainer_name.asm
extern TrainerPicPointers       ; src/data/trainer_pics.asm  (flat dd, index=class-1)
extern TrainerPicLengths        ; src/data/trainer_pics.asm  (word lengths, index=class-1)
extern TrainerBaseMoney         ; src/data/trainer_pics.asm  (bcd3 per class, index=class-1)
extern PlayerPicFront           ; src/data/trainer_pics.asm  (== pret RedPicFront)
extern PlayerPicFrontLength     ; src/data/trainer_pics.asm  (compressed-byte length word)
extern JessieJamesPic           ; src/data/trainer_pics.asm — generated Jessie/James picture
extern JessieJamesPicLength     ; src/data/trainer_pics.asm — compressed-byte length word

global GetTrainerInformation
global IsFightingJessieJames
global GetTrainerName
global trainer_pic_ptr
global trainer_pic_len

section .bss
align 4
; Port-only flat replacement for pret's 16-bit wTrainerPicPointer. Keeping a
; dword at the pret address would overlap wTrainerName at $D049.
trainer_pic_ptr: resd 1
trainer_pic_len: resw 1

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
    ; port flat trainer picture pointer = TrainerPicPointers[idx]
    mov edi, [TrainerPicPointers + eax*4]
    mov [trainer_pic_ptr], edi
    mov dx, [TrainerPicLengths + eax*2]
    mov [trainer_pic_len], dx
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
    mov [trainer_pic_ptr], edi
    mov dx, [PlayerPicFrontLength]
    mov [trainer_pic_len], dx
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
    mov edi, JessieJamesPic
    mov [trainer_pic_ptr], edi
    mov dx, [JessieJamesPicLength]
    mov [trainer_pic_len], dx
.ret:
    ret

; ----------------------------------------------------------------------------
; GetTrainerName — pret farjp GetTrainerName_ (flat: direct jmp).
; pret: home/trainers2.asm:GetTrainerName
; ----------------------------------------------------------------------------
GetTrainerName:
    jmp GetTrainerName_
