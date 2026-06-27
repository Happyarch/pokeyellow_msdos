%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

; ---------------------------------------------------------------------------
; FormatMovesString
; ---------------------------------------------------------------------------
global FormatMovesString

extern wMoves
extern wMovesString
extern GetName
; BANK_MoveNames (gb_constants.inc), wPredefBank/wNameListType/wNameBuffer
; (gb_memmap.inc), and the *_NAME type ids (gb_constants.inc) come from the
; includes now — externing them would collide with the equ definitions.

FormatMovesString:
    mov esi, wMoves
    mov edx, wMovesString
    mov bh, 0
.printMoveNameLoop:
    mov al, [ebp + esi]
    inc esi
    test al, al
    jz .printDashLoop
    push esi
    mov [ebp + wNameListIndex], al
    mov eax, BANK_MoveNames
    mov [ebp + wPredefBank], al
    mov eax, MOVE_NAME
    mov [ebp + wNameListType], al
    call GetName
    mov esi, wNameBuffer
.copyNameLoop:
    mov al, [ebp + esi]
    inc esi
    cmp al, 0x50 ; '@'
    jz .doneCopyingName
    mov [ebp + edx], al
    inc edx
    jmp .copyNameLoop
.doneCopyingName:
    mov al, bh
    mov [ebp + wNumMovesMinusOne], al
    inc bh
    mov al, 0x4E ; '<NEXT>'
    mov [ebp + edx], al
    inc edx
    pop esi
    mov cl, bh
    mov eax, NUM_MOVES
    cmp cl, al
    jz .done
    jmp .printMoveNameLoop
.printDashLoop:
    mov al, '-'
    mov [ebp + edx], al
    inc edx
    inc bh
    mov cl, bh
    mov eax, NUM_MOVES
    cmp cl, al
    jz .done
    mov al, 0x4E ; '<NEXT>'
    mov [ebp + edx], al
    inc edx
    jmp .printDashLoop
.done:
    mov al, 0x50 ; '@'
    mov [ebp + edx], al
    ret

; ---------------------------------------------------------------------------
; InitList
; ---------------------------------------------------------------------------
global InitList

extern wInitListType
extern INIT_ENEMYOT_LIST
extern wEnemyMonOT
extern INIT_PLAYEROT_LIST
extern INIT_MON_LIST
extern wItemList
extern MonsterNames
extern INIT_BAG_ITEM_LIST
extern ItemNames
extern wListPointer
extern ItemPrices
extern wItemPrices
; *_NAME type ids (MONSTER_NAME/ITEM_NAME/PLAYEROT_NAME/ENEMYOT_NAME) and
; wUnusedNamePointer now come from the includes.


InitList:
    mov al, byte [ebp + wInitListType]

    mov ebx, INIT_ENEMYOT_LIST
    cmp al, bl
    jne .notEnemy
    mov esi, wEnemyPartyCount
    mov edx, wEnemyMonOT
    mov ebx, ENEMYOT_NAME
    mov al, bl
    jmp .done
.notEnemy:
    mov ebx, INIT_PLAYEROT_LIST
    cmp al, bl
    jne .notPlayer
    mov esi, wPartyCount
    mov edx, W_PARTY_MON_OT
    mov ebx, PLAYEROT_NAME
    mov al, bl
    jmp .done
.notPlayer:
    mov ebx, INIT_MON_LIST
    cmp al, bl
    jne .notMonster
    mov esi, wItemList
    mov edx, MonsterNames
    mov ebx, MONSTER_NAME
    mov al, bl
    jmp .done
.notMonster:
    mov ebx, INIT_BAG_ITEM_LIST
    cmp al, bl
    jne .notBag
    mov esi, W_NUM_BAG_ITEMS
    mov edx, ItemNames
    mov ebx, ITEM_NAME
    mov al, bl
    jmp .done
.notBag:
    mov esi, wItemList
    mov edx, ItemNames
    mov ebx, ITEM_NAME
    mov al, bl
.done:
    mov byte [ebp + wNameListType], al

    mov eax, esi
    mov byte [ebp + wListPointer], al
    shr eax, 8
    mov byte [ebp + wListPointer + 1], al

    mov al, dl
    mov byte [ebp + wUnusedNamePointer], al
    mov al, dh
    mov byte [ebp + wUnusedNamePointer + 1], al

    mov ebx, ItemPrices
    mov al, bl
    mov byte [ebp + wItemPrices], al
    mov al, bh
    mov byte [ebp + wItemPrices + 1], al
    ret
