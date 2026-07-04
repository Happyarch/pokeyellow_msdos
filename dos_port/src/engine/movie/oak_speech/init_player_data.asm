; init_player_data.asm — InitPlayerData / InitPlayerData2 + InitializeEmptyList.
; Faithful port of pret engine/movie/oak_speech/init_player_data.asm.
;
; This is the new-game data initializer the base game runs as the very first
; action of OakSpeech (`predef InitPlayerData2`, reached from
; main_menu.asm:StartNewGame). Its load-bearing job for the port: the four
; `InitializeEmptyList` calls seed wPartyCount / wBoxCount / wNumBagItems /
; wNumBoxItems with count=0 AND a $FF terminator. Without it every list scan
; (AddItemToInventory's terminator walk, DisplayListMenuID's count read, the
; party/box menus) runs off the end of an uninitialised, DPMI-garbage inventory
; and loops through memory. See docs/glitch_safety.md ("Uninitialised inventory
; / missing list terminator").
;
; The port's title/SKIP_TITLE boot jumps straight to EnterMap (standing in for
; "new game → OakSpeech → SpecialEnterMap"), so OakSpeech — and therefore this
; routine — is invoked on that shortcut too (see main_menu_stubs.asm:OakSpeech,
; src/init/init.asm, src/movie/title.asm .go_to_main_menu).
;
; Register map (CLAUDE.md): A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base.
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global InitPlayerData
global InitPlayerData2
global InitializeEmptyList

extern Random                              ; home/random.asm
extern FillMemory                          ; home/fill_memory.asm — ESI=dst, BX=count, AL=value
extern InitializeToggleableObjectsFlags    ; overworld_stubs.asm (TODO: toggleable_objects.asm)

START_MONEY equ 0x3000

section .text

; ---------------------------------------------------------------------------
; InitPlayerData / InitPlayerData2 — pret ref: init_player_data.asm.
; In: EBP = GB base.
; ---------------------------------------------------------------------------
InitPlayerData:
InitPlayerData2:
    call Random
    mov al, [ebp + H_RANDOM_SUB]
    mov [ebp + wPlayerID], al               ; ld [wPlayerID], a

    call Random
    mov al, [ebp + H_RANDOM_ADD]
    mov [ebp + wPlayerID + 1], al           ; ld [wPlayerID + 1], a

    mov byte [ebp + wUnusedPlayerDataByte], 0xff

    mov byte [ebp + wPikachuHappiness], 90  ; initialize happiness to 90
    mov byte [ebp + wPikachuMood], 0x80     ; initialize mood

    mov esi, wPartyCount
    call InitializeEmptyList
    mov esi, wBoxCount
    call InitializeEmptyList
    mov esi, wNumBagItems
    call InitializeEmptyList
    mov esi, wNumBoxItems
    call InitializeEmptyList

    ; START_MONEY = $3000, 3-byte big-endian BCD (pret writes hi, then lo bytes)
    mov byte [ebp + wPlayerMoney],     (START_MONEY >> 16) & 0xFF   ; 0x00
    mov byte [ebp + wPlayerMoney + 1], (START_MONEY >>  8) & 0xFF   ; 0x30
    mov byte [ebp + wPlayerMoney + 2],  START_MONEY        & 0xFF   ; 0x00

    xor al, al                              ; the tail below all stores 0
    mov [ebp + wMonDataLocation], al

    mov [ebp + W_OBTAINED_BADGES], al       ; wObtainedBadges = 0
    mov [ebp + wUnusedObtainedBadges], al   ; ASSERT wObtainedBadges + 1 == wUnusedObtainedBadges

    ; wPlayerCoins (2-byte BCD) = 0. NOTE: gb_memmap.inc aliases wPlayerCoins at
    ; 0xD5A4 but origin/symbols reports 0xD5A3 (latent 1-byte port error, flagged
    ; separately). Harmless here — this is a fresh-game zero-fill either way.
    mov word [ebp + wPlayerCoins], 0

    mov esi, wGameProgressFlags
    mov bx, (wGameProgressFlagsEnd - wGameProgressFlags) & 0xFFFF
    xor al, al
    call FillMemory                         ; clear all game progress flags

    jmp InitializeToggleableObjectsFlags    ; jp InitializeToggleableObjectsFlags (tail)

; ---------------------------------------------------------------------------
; InitializeEmptyList — pret ref: init_player_data.asm:InitializeEmptyList.
; In: ESI = list count address (wNumBagItems / wPartyCount / ...).
; Writes count=0 then a $FF terminator. Clobbers AL, ESI.
; ---------------------------------------------------------------------------
InitializeEmptyList:
    xor al, al                              ; count
    mov [ebp + esi], al                     ; ld [hli], a
    inc esi
    dec al                                  ; terminator ($ff)  (inc/dec preserve nothing we read)
    mov [ebp + esi], al                     ; ld [hl], a
    ret
