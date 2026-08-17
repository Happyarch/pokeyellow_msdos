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
%define TX_SOUND_GET_ITEM_1 0x0B
%define TX_DOTS           0x0C
%define TX_WAIT_BUTTON    0x0D
%define TX_FAR            0x17
%define TX_END            0x50

; The TX_SOUND_* family ($0B, $0E-$16), executed by TextCommand_SOUND. pret keeps
; these in the same const_def block as the commands above (macros/scripts/text.asm);
; the port's engine implements the whole family — src/home/text.asm `.cmd_sound`
; carries pret's TextCommandSounds table verbatim — but the constants used to be
; file-local equs there, invisible to any other translation unit. They are shared
; here so text streams can name the command they mean.
%define TX_SOUND_LEVEL_UP TX_SOUND_GET_ITEM_1   ; pret: DEF TX_SOUND_LEVEL_UP EQU TX_SOUND_GET_ITEM_1
%define TX_SOUND_POKEDEX_RATING       0x0E
%define TX_SOUND_GET_ITEM_1_DUPLICATE 0x0F
%define TX_SOUND_GET_ITEM_2           0x10
%define TX_SOUND_GET_KEY_ITEM         0x11
%define TX_SOUND_CAUGHT_MON           0x12
%define TX_SOUND_DEX_PAGE_ADDED       0x13
%define TX_SOUND_CRY_PIKACHU          0x14
%define TX_SOUND_CRY_PIDGEOT          0x15
%define TX_SOUND_CRY_DEWGONG          0x16

; The TX_SCRIPT_* ids ($F5-$FF) are NOT redefined here — they already live in
; gb_constants.inc, which every consumer of this header includes first.

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

; -----------------------------------------------------------------------------
; Sound macros (pret macros/scripts/text.asm). Each emits one command byte and no
; operand; TextCommandProcessor's .cmd_sound looks it up in TextCommandSounds and
; runs PlaySound + WaitForSoundToFinish, or PlayCry for the three cry commands.
; -----------------------------------------------------------------------------

%macro sound_get_item_1 0
    db TX_SOUND_GET_ITEM_1
%endmacro

; pret spells this as an EQUS alias of sound_get_item_1, so it is the same byte.
%macro sound_level_up 0
    db TX_SOUND_LEVEL_UP
%endmacro

%macro sound_pokedex_rating 0
    db TX_SOUND_POKEDEX_RATING
%endmacro

%macro sound_get_item_1_duplicate 0
    db TX_SOUND_GET_ITEM_1_DUPLICATE
%endmacro

%macro sound_get_item_2 0
    db TX_SOUND_GET_ITEM_2
%endmacro

%macro sound_get_key_item 0
    db TX_SOUND_GET_KEY_ITEM
%endmacro

%macro sound_caught_mon 0
    db TX_SOUND_CAUGHT_MON
%endmacro

%macro sound_dex_page_added 0
    db TX_SOUND_DEX_PAGE_ADDED
%endmacro

%macro sound_cry_pikachu 0
    db TX_SOUND_CRY_PIKACHU
%endmacro

%macro sound_cry_pidgeot 0
    db TX_SOUND_CRY_PIDGEOT
%endmacro

%macro sound_cry_dewgong 0
    db TX_SOUND_CRY_DEWGONG
%endmacro

; -----------------------------------------------------------------------------
; Text-script macros (pret macros/scripts/text.asm, "Text script IDs"). One byte,
; no operand, dispatched by DisplayTextID in src/home/text_script.asm — which
; implements all eight. `script_mart` is deliberately absent: its operand is a
; variadic item list, which is Tier-1 data belonging to a generator.
; -----------------------------------------------------------------------------

%macro script_pokecenter_nurse 0
    db TX_SCRIPT_POKECENTER_NURSE
%endmacro

%macro script_bills_pc 0
    db TX_SCRIPT_BILLS_PC
%endmacro

%macro script_players_pc 0
    db TX_SCRIPT_PLAYERS_PC
%endmacro

%macro script_pokecenter_pc 0
    db TX_SCRIPT_POKECENTER_PC
%endmacro

%macro script_prize_vendor 0
    db TX_SCRIPT_PRIZE_VENDOR
%endmacro

%macro script_cable_club_receptionist 0
    db TX_SCRIPT_CABLE_CLUB_RECEPTIONIST
%endmacro

%macro script_vending_machine 0
    db TX_SCRIPT_VENDING_MACHINE
%endmacro

%endif ; GB_TEXT_INC
