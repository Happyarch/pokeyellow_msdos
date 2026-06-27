%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global GetTrainerName_

extern wLinkEnemyTrainerName
extern wTrainerName
extern TrainerNames
extern GetName
extern CopyData
; wNameListType / wPredefBank / wNameBuffer come from gb_memmap.inc;
; TRAINER_NAME from gb_constants.inc (was a local equ — would now collide).

RIVAL1              equ 0x19
RIVAL2              equ 0x2A
RIVAL3              equ 0x2B
TRAINER_NAME_LENGTH equ 13

GetTrainerName_:
    mov esi, wLinkEnemyTrainerName
    mov al, byte [ebp + wLinkState]
    and al, al
    jnz .foundName
    mov esi, W_RIVAL_NAME
    mov al, byte [ebp + wTrainerClass]
    cmp al, RIVAL1
    jz .foundName
    cmp al, RIVAL2
    jz .foundName
    cmp al, RIVAL3
    jz .foundName
    mov byte [ebp + wNameListIndex], al
    mov al, TRAINER_NAME
    mov byte [ebp + wNameListType], al
    mov al, 0 ; BANK(TrainerNames) stub
    mov byte [ebp + wPredefBank], al
    call GetName
    mov esi, wNameBuffer
.foundName:
    mov edx, wTrainerName
    mov bx, TRAINER_NAME_LENGTH
    jmp CopyData
