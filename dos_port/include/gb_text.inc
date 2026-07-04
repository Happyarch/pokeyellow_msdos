%ifndef GB_TEXT_INC
%define GB_TEXT_INC

; Text command byte values
%define TX_START          0x00
%define TX_RAM            0x01
%define TX_BCD            0x02
%define TX_MOVE           0x03
%define TX_BOX            0x04
%define TX_LOW            0x05
%define TX_PROMPT_BUTTON  0x06
%define TX_SCROLL         0x07
%define TX_START_ASM      0x08
%define TX_NUM            0x09
%define TX_PAUSE          0x0A
%define TX_DOTS           0x0C
%define TX_WAIT_BUTTON    0x0D
%define TX_FAR            0x17
%define TX_END            0x50

; Control characters
%define CHAR_NEXT         0x4E
%define CHAR_LINE         0x4F
%define CHAR_PARA         0x51
%define CHAR_CONT         0x55
%define CHAR_DONE         0x57
%define CHAR_PROMPT       0x58
%define CHAR_PAGE         0x49
%define CHAR_DEXEND       0x5F

; -----------------------------------------------------------------------------
; Control-flow macros
; -----------------------------------------------------------------------------

%macro text 0
    db TX_START
%endmacro

%macro text_start 0
    db TX_START
%endmacro

%macro next 0
    db CHAR_NEXT
%endmacro

%macro line 0
    db CHAR_LINE
%endmacro

%macro para 0
    db CHAR_PARA
%endmacro

%macro cont 0
    db CHAR_CONT
%endmacro

%macro done 0
    db CHAR_DONE
%endmacro

%macro prompt 0
    db CHAR_PROMPT
%endmacro

%macro page 0
    db CHAR_PAGE
%endmacro

%macro dex 0
    db CHAR_DEXEND, TX_END
%endmacro

%macro text_end 0
    db TX_END
%endmacro

; -----------------------------------------------------------------------------
; Format command macros
; -----------------------------------------------------------------------------

%macro text_ram 1
    db TX_RAM
    dw %1
%endmacro

%macro text_bcd 2
    db TX_BCD
    dw %1
    db %2
%endmacro

%macro text_decimal 3
    db TX_NUM
    dw %1
    db ((%2) << 4) | (%3)
%endmacro

%macro text_dots 1
    db TX_DOTS
    db %1
%endmacro

%macro text_pause 0
    db TX_PAUSE
%endmacro

%macro text_waitbutton 0
    db TX_WAIT_BUTTON
%endmacro

%macro text_promptbutton 0
    db TX_PROMPT_BUTTON
%endmacro

%macro text_scroll 0
    db TX_SCROLL
%endmacro

%macro text_low 0
    db TX_LOW
%endmacro

%macro text_move 1
    db TX_MOVE
    dw %1
%endmacro

%macro text_box 3
    db TX_BOX
    dw %1
    db %2, %3
%endmacro

%macro text_asm 0
    db TX_START_ASM
%endmacro

; The flat port uses a 32-bit (flat) pointer for text_far instead of GB bank/addr (dab).
%macro text_far 1
    db TX_FAR
    dd %1
%endmacro

%endif ; GB_TEXT_INC
