; text_script.asm — DisplayTextID dialogue-dispatch tree.
;
; Faithful translation of pret `home/text_script.asm` (Pokémon Yellow):
; DisplayTextID / CloseTextDisplay / HoldTextDisplayOpen and the special-case
; dialogue branches (mart / PokéCenter nurse / fainted / blacked-out / repel /
; Pikachu-emotion / Safari game-over). Plus the general `DisplayTextBoxID`
; dispatcher (pret home/textbox.asm) and `FarPrintText` (pret home/print_num.asm).
;
; This file is linked in the default build. The ordinary map-text path uses the
; port's generated flat map table, while the TEXT_PREDEF path preserves pret's
; wCurMapTextPtr lookup. The service-dialog tails below are intentionally owned
; by their subsystems; unresolved behavior lives behind structured stubs there,
; not behind a DisplayTextID link-time stand-in.
;
; Register map (project convention): A=AL, HL=ESI, BC=BX (B=BH,C=BL),
; DE=DX (D=DH,E=DL), EBP=GB base; GB memory accessed as [EBP + addr].
; GB 16-bit pointers are treated as EBP-relative GB-space addresses and read
; little-endian (x86 is LE, matching the GB) only for the TEXT_PREDEF path.
; Ordinary map text uses the port's generated flat MapTextTablePointers table.
;
;   ── ADDRESSING MODEL CAVEAT (follow-up glue) ──────────────────────────────
;   pret resolves the text address by walking the map's ROM text-pointer table
;   via `wCurMapTextPtr`. The port's live map text subsystem is generated as flat
;   {dd stream, dd size} rows and published as w_map_text_table_ptr. The ordinary
;   map path therefore uses that flat table, while the TEXT_PREDEF path keeps the
;   faithful 16-bit GB pointer walk used by PrintPredefTextID.
;
; Build: nasm -f coff -I include/ -I . -o text_script.o text_script.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"                ; BUG_FIX_LEVEL
%include "gb_text.inc"                  ; text_far / text_end wrappers

section .text

global DisplayTextID
global AfterDisplayingTextID
global HoldTextDisplayOpen
global CloseTextDisplay
global DisplayPokemartDialogue
global LoadItemList
global FarPrintText

; ── text printers (text/text.asm) ──
extern PrintText                    ; pret PrintText (window.asm) — ESI = FLAT TX stream ptr
extern PrintText_NoCreatingTextBox                  ; pret PrintText_NoCreatingTextBox
extern DelayFrame
extern WaitForTextScrollButtonPress ; engine/battle/battle_menu.asm — relocated joypad2 routine

; ── non-home glue ─────────────────────────────────────────────────────────────
; RESOLVED (menus S2): DisplayTextIDInit is now a real linked routine
; (src/engine/menus/display_text_id_init.asm).
extern DisplayTextIDInit
extern SwitchToMapRomBank               ; ld a,[wCurMap]; bankswitch (flat = no-op wrapper)
extern InitMapSprites                   ; reload sprite tile patterns after text
extern LoadCurrentMapView
extern LoadPlayerSpriteGraphics
extern UpdateSprites                    ; movement.asm (already ported) — final jp target
extern LoadGBPal                        ; palettes/fade (Wave 10)
extern BankswitchCommon                 ; home/bankswitch.asm (Wave 0, no-op flat) — extern
extern w_map_text_table_ptr             ; map_sprites.asm — flat ptr to current map TextTable
extern wMapSpriteData                   ; map_sprites.asm — flat [movbyte2,textid] per slot
extern DisplayStartMenu
extern TalkToPikachu                    ; callfar (engine/pikachu)
extern PrintSafariGameOverText          ; callfar (engine/safari)
; The home-layer dispatch to these non-home service bodies is faithful. Some
; service bodies remain structured stubs in their owning subsystem.
extern DisplayPokemartDialogue_         ; homecall (engine/menus)
extern DisplayPokemonCenterDialogue_    ; homecall (engine/menus)
extern TextScript_ItemStoragePC
extern TextScript_BillsPC
extern TextScript_PokemonCenterPC
extern VendingMachineMenu               ; farcall
extern TextScript_GameCornerPrizeMenu
extern CableClubNPC                     ; callfar
; RESOLVED (menus S2): the DisplayTextBoxID home wrapper now lives canonically in
;   src/home/textbox.asm (linked), calling the real DisplayTextBoxID_
;   (src/engine/menus/text_box.asm). The interim definition here is gone.
extern DisplayTextBoxID
extern msgbox_dialog                    ; src/home/text.asm — overworld dialog projection
extern text_msgbox                      ; src/home/text.asm — active msgbox projection (msgbox.inc)

; ─────────────────────────────────────────────────────────────────────────────
; DisplayTextID — display sign messages, sprite dialog, etc.
; INPUT: [hSpriteIndex]==[hTextID] = sprite ID or text ID (same HRAM slot).
; pret home/text_script.asm:DisplayTextID
; ─────────────────────────────────────────────────────────────────────────────
DisplayTextID:
    ; ldh a,[hLoadedROMBank] / push af   (save bank around the whole routine)
    movzx eax, byte [ebp + hLoadedROMBank]
    push eax

    ; farcall DisplayTextIDInit — box setup / reg save (non-home, deferred)
    call DisplayTextIDInit

    ; ld hl, wTextPredefFlag / bit BIT_TEXT_PREDEF,[hl] / res BIT_TEXT_PREDEF,[hl]
    ; jr nz,.skipSwitchToMapBank
    xor edi, edi                         ; 0 = flat map TextTable, 1 = GB pointer table
    mov al, [ebp + wTextPredefFlag]
    mov ah, al                          ; save original for the bit test (below)
    ; res BIT_TEXT_PREDEF,[hl] (clear regardless — pret does `res` after `bit`).
    ; NOTE: `and` sets x86 flags, so it must precede the deciding `test`.
    and al, ~(1 << BIT_TEXT_PREDEF) & 0xFF
    mov [ebp + wTextPredefFlag], al
    ; bit BIT_TEXT_PREDEF,[hl] / jr nz — branch on the ORIGINAL flag value
    test ah, (1 << BIT_TEXT_PREDEF)
    jnz .skipSwitchToMapBank
    ; ld a,[wCurMap] / call SwitchToMapRomBank
    mov al, [ebp + wCurMap]
    call SwitchToMapRomBank
    xor edi, edi                         ; ordinary map table: flat {ptr,size} rows
    jmp .selectMapTextTable
.skipSwitchToMapBank:
    mov edi, 1                           ; TEXT_PREDEF keeps the GB pointer-table path
.selectMapTextTable:
    ; ld a,30 / ldh [hFrameCounter],a  — used as joypad poll timer (half a second)
    mov al, 30
    mov [ebp + hFrameCounter], al

    ; ld hl, wCurMapTextPtr / ld a,[hli] / ld h,[hl] / ld l,a  → hl = map text pointer.
    ; Port ordinary maps use w_map_text_table_ptr (flat {ptr,size} rows) instead.
    test edi, edi
    jnz .loadPredefTextPtr
    mov esi, [w_map_text_table_ptr]
    test esi, esi
    jnz .haveTextTable
    jmp AfterDisplayingTextID
.loadPredefTextPtr:
    movzx esi, word [ebp + wCurMapTextPtr]
.haveTextTable:

    ; ld d,$00 / ldh a,[hTextID] / ld [wSpriteIndex],a
    xor edx, edx                        ; d = 0 (de high byte)
    movzx eax, byte [ebp + hTextID]
    mov [ebp + wSpriteIndex], al

    ; dict TEXT_START_MENU, DisplayStartMenu   (and a / jp z since id==0)
    test al, al
    jz DisplayStartMenu
    ; dict TEXT_PIKACHU_ANIM, DisplayPikachuEmotion
    cmp al, TEXT_PIKACHU_ANIM
    jz DisplayPikachuEmotion
    ; dict TEXT_SAFARI_GAME_OVER, DisplaySafariGameOverText
    cmp al, TEXT_SAFARI_GAME_OVER
    jz DisplaySafariGameOverText
    ; dict TEXT_MON_FAINTED, DisplayPokemonFaintedText
    cmp al, TEXT_MON_FAINTED
    jz DisplayPokemonFaintedText
    ; dict TEXT_BLACKED_OUT, DisplayPlayerBlackedOutText
    cmp al, TEXT_BLACKED_OUT
    jz DisplayPlayerBlackedOutText
    ; dict TEXT_REPEL_WORE_OFF, DisplayRepelWoreOffText
    cmp al, TEXT_REPEL_WORE_OFF
    jz DisplayRepelWoreOffText

    ; ── sprite-vs-textID branch: if hSpriteIndex >= wNumSprites → skip sprite path ──
    ; ld a,[wNumSprites]/ld e,a ; ldh a,[hSpriteIndex]; cp e; jr z .spriteHandling;
    ; jr nc,.skipSpriteHandling
    mov dl, [ebp + wNumSprites]          ; e = wNumSprites
    movzx eax, byte [ebp + hSpriteIndex] ; a = sprite ID (restore a, clobbered above)
    cmp al, dl
    je .spriteHandling
    ja .skipSpriteHandling
.spriteHandling:
    ; get the text ID of the sprite:
    ;   push hl ; ld hl,wMapSpriteData ; ldh a,[hSpriteIndex]; dec a; add a; ld e,a;
    ;   ld d,0 ; add hl,de ; inc hl ; ld a,[hl] ; pop hl
    push esi                             ; push hl (preserve map text ptr)
    movzx eax, byte [ebp + hSpriteIndex]
    dec al
    add al, al                           ; a = (spriteID-1)*2
    movzx edx, al                        ; de = a (d=0)
    movzx eax, byte [wMapSpriteData + edx + 1] ; a = text ID of the sprite (byte 1 of entry)
    pop esi                              ; pop hl (map text ptr)
.skipSpriteHandling:
    ; ── look up the address of the text in the map's text entries ──
    ; dec a ; ld e,a ; ld d,0 ; add hl,de ; add hl,de ; ld a,[hli]; ld h,[hl]; ld l,a
    dec al
    movzx edx, al                        ; de = (textID-1), d=0
    test edi, edi
    jnz .lookupGbPointerTable
    lea edx, [edx * 8]                   ; flat rows are {dd stream, dd size}
    mov ebx, [esi + edx + 4]             ; 0xFFFFFFFF marks text_asm script entry
    mov esi, [esi + edx]                 ; flat pointer to TX stream
    test esi, esi
    jnz .gotTextPtr
    jmp AfterDisplayingTextID
.gotTextPtr:
    cmp ebx, 0xFFFFFFFF
    jne .readFirstByte
    call esi                             ; text_asm routine owns its own text stream
    jmp AfterDisplayingTextID
.lookupGbPointerTable:
    add esi, edx
    add esi, edx                         ; hl += 2*(textID-1)  (word index into pointer table)
    and esi, 0xFFFF                       ; faithful 16-bit GB-pointer wrap
    ; hl = [hl] (LE 16-bit pointer to the text stream)
    movzx esi, word [ebp + esi]
.readFirstByte:
    ; ld a,[hl] — a = first byte of text
    movzx eax, byte [ebp + esi]

    ; ── check first byte of text for special cases (pret `dict`/`dict2`) ──
    ; dict  TX_SCRIPT_MART,             DisplayPokemartDialogue
    cmp al, TX_SCRIPT_MART
    jz DisplayPokemartDialogue
    ; dict  TX_SCRIPT_POKECENTER_NURSE, DisplayPokemonCenterDialogue
    cmp al, TX_SCRIPT_POKECENTER_NURSE
    jz DisplayPokemonCenterDialogue
    ; dict  TX_SCRIPT_PLAYERS_PC,       TextScript_ItemStoragePC
    cmp al, TX_SCRIPT_PLAYERS_PC
    jz TextScript_ItemStoragePC
    ; dict  TX_SCRIPT_BILLS_PC,         TextScript_BillsPC
    cmp al, TX_SCRIPT_BILLS_PC
    jz TextScript_BillsPC
    ; dict  TX_SCRIPT_POKECENTER_PC,    TextScript_PokemonCenterPC
    cmp al, TX_SCRIPT_POKECENTER_PC
    jz TextScript_PokemonCenterPC
    ; dict2 TX_SCRIPT_VENDING_MACHINE,  farcall VendingMachineMenu
    cmp al, TX_SCRIPT_VENDING_MACHINE
    jnz .notVending
    call VendingMachineMenu              ; farcall (bank switch = no-op flat)
    jmp AfterDisplayingTextID
.notVending:
    ; dict  TX_SCRIPT_PRIZE_VENDOR,     TextScript_GameCornerPrizeMenu
    cmp al, TX_SCRIPT_PRIZE_VENDOR
    jz TextScript_GameCornerPrizeMenu
    ; dict2 TX_SCRIPT_CABLE_CLUB_RECEPTIONIST, callfar CableClubNPC
    cmp al, TX_SCRIPT_CABLE_CLUB_RECEPTIONIST
    jnz .notCableClub
    call CableClubNPC                    ; callfar
    jmp AfterDisplayingTextID
.notCableClub:

    ; call PrintText_NoCreatingTextBox   (ESI already = text stream)
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText_NoCreatingTextBox
    ; ld a,[wDoNotWaitForButtonPressAfterDisplayingText]; and a; jr nz,HoldTextDisplayOpen
    mov al, [ebp + wDoNotWaitForButtonPressAfterDisplayingText]
    test al, al
    jnz HoldTextDisplayOpen
    ; fall through to AfterDisplayingTextID

AfterDisplayingTextID:
    ; ld a,[wEnteringCableClub]; and a; jr nz,HoldTextDisplayOpen
    mov al, [ebp + wEnteringCableClub]
    test al, al
    jnz HoldTextDisplayOpen
    call WaitForTextScrollButtonPress
    ; fall through to hold-open

; loop to hold the dialogue box open as long as the player keeps holding A
HoldTextDisplayOpen:
    ; call Joypad ; ldh a,[hJoyHeld]; bit B_PAD_A,a; jr nz,HoldTextDisplayOpen.
    ; The port's ISR-backed joypad state is refreshed by DelayFrame.
    call DelayFrame
    mov al, [ebp + hJoyHeld]
    test al, PAD_A
    jnz HoldTextDisplayOpen
    ; fall through to CloseTextDisplay

CloseTextDisplay:
    ; ld a,[wCurMap]; call SwitchToMapRomBank
    mov al, [ebp + wCurMap]
    call SwitchToMapRomBank
    ; ld a,$90; ldh [hWY],a   — move the window off screen
    ; TODO-HW: software PPU window register (hWY shadow of rWY)
    mov al, 0x90
    mov [ebp + hWY], al
    call DelayFrame
    call LoadGBPal
    ; xor a; ldh [hAutoBGTransferEnabled],a — disable continuous WRAM→VRAM transfer
    xor eax, eax
    mov [ebp + hAutoBGTransferEnabled], al

    ; ── restore each sprite's original facing direction (walk 15 structs) ──
    ; ld hl, wSprite01StateData2OrigFacingDirection ; ld c, NUM_SPRITESTATEDATA_STRUCTS-1
    ; ld de, SPRITESTATEDATA1_LENGTH
    ; .loop: ld a,[hl]; dec h; ld [hl],a; inc h; add hl,de; dec c; jr nz,.loop
    ; Flat port: OrigFacing is in StateData2 ($C2xx); FacingDirection is the same
    ; low byte one page lower in StateData1 ($C1xx) — pret's `dec h`/`inc h` = -0x100.
    mov esi, wSprite01StateData2OrigFacingDirection
    mov cl, NUM_SPRITESTATEDATA_STRUCTS - 1
.restoreSpriteFacingDirectionLoop:
    mov al, [ebp + esi]                  ; a = SPRITESTATEDATA2_ORIGFACINGDIRECTION
    mov [ebp + esi - 0x100], al          ; dec h → StateData1 FACINGDIRECTION
    add esi, SPRITESTATEDATA1_LENGTH      ; add hl, de (0x10)
    dec cl
    jnz .restoreSpriteFacingDirectionLoop

    ; call InitMapSprites — reload sprite tiles (text overwrote some)
    call InitMapSprites
    ; ld hl, wFontLoaded ; res BIT_FONT_LOADED,[hl]
    and byte [ebp + wFontLoaded], ~(1 << BIT_FONT_LOADED) & 0xFF
    ; ld a,[wStatusFlags6]; bit BIT_FLY_WARP,a; call z, LoadPlayerSpriteGraphics
    mov al, [ebp + wStatusFlags6]
    test al, (1 << BIT_FLY_WARP)
    jnz .skipLoadPlayerGfx
    call LoadPlayerSpriteGraphics
.skipLoadPlayerGfx:
    call LoadCurrentMapView
    ; pop af / call BankswitchCommon — restore the entry ROM bank (no-op flat)
    pop eax
    call BankswitchCommon
    ; jp UpdateSprites
    jmp UpdateSprites

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPokemartDialogue — pret home/text_script.asm:136
; ─────────────────────────────────────────────────────────────────────────────
DisplayPokemartDialogue:
    push esi                             ; push hl (text ptr → points at TX_SCRIPT_MART byte)
    mov esi, PokemartGreetingText        ; ld hl, PokemartGreetingText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    pop esi                              ; pop hl
    inc esi                              ; inc hl — skip the TX_SCRIPT_MART byte → item list
    call LoadItemList
    mov al, PRICEDITEMLISTMENU
    mov [ebp + wListMenuID], al
    ; homecall DisplayPokemartDialogue_  (bank switch = no-op flat)
    call DisplayPokemartDialogue_
    jmp AfterDisplayingTextID

PokemartGreetingText:
    text_far _PokemartGreetingText
    text_end

; ─────────────────────────────────────────────────────────────────────────────
; LoadItemList — pret home/text_script.asm:152. Copies the $ff-terminated item id
; list at HL into wItemList and records the source pointer in wItemListPointer.
; ─────────────────────────────────────────────────────────────────────────────
LoadItemList:
    mov al, 1
    mov [ebp + wUpdateSpritesEnabled], al
    ; ld a,h; ld [wItemListPointer],a ; ld a,l; ld [wItemListPointer+1],a
    ; NOTE (faithful quirk): pret stores H then L, i.e. BIG-endian into wItemListPointer.
    mov eax, esi
    mov [ebp + wItemListPointer], ah     ; high byte first
    mov [ebp + wItemListPointer + 1], al ; low byte second
    ; ld de, wItemList ; .loop: ld a,[hli]; ld [de],a; inc de; cp $ff; jr nz,.loop
    mov edx, wItemList
.loop:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    cmp al, 0xFF
    jne .loop
    ret

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPokemonCenterDialogue — pret home/text_script.asm:168
; ─────────────────────────────────────────────────────────────────────────────
DisplayPokemonCenterDialogue:
    ; zero hItemPrice (3 bytes) — pret notes this serves no purpose but is faithful
    xor eax, eax
    mov [ebp + hItemPrice], al
    mov [ebp + hItemPrice + 1], al
    mov [ebp + hItemPrice + 2], al
    inc esi                              ; inc hl
    ; homecall DisplayPokemonCenterDialogue_
    call DisplayPokemonCenterDialogue_
    jmp AfterDisplayingTextID

; ─────────────────────────────────────────────────────────────────────────────
; DisplaySafariGameOverText — pret home/text_script.asm:179
; ─────────────────────────────────────────────────────────────────────────────
DisplaySafariGameOverText:
    call PrintSafariGameOverText         ; callfar
    jmp AfterDisplayingTextID

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPokemonFaintedText — pret home/text_script.asm:183
; ─────────────────────────────────────────────────────────────────────────────
DisplayPokemonFaintedText:
    mov esi, PokemonFaintedText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    jmp AfterDisplayingTextID

PokemonFaintedText:
    text_far _PokemonFaintedText
    text_end

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPlayerBlackedOutText — pret home/text_script.asm:192
; ─────────────────────────────────────────────────────────────────────────────
DisplayPlayerBlackedOutText:
    mov esi, PlayerBlackedOutText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    ; ld a,[wStatusFlags6]; res BIT_ALWAYS_ON_BIKE,a; ld [wStatusFlags6],a
    mov al, [ebp + wStatusFlags6]
    and al, ~(1 << BIT_ALWAYS_ON_BIKE) & 0xFF
    mov [ebp + wStatusFlags6], al
    ; CheckEvent EVENT_IN_SAFARI_ZONE ; jr z,.didnotblackoutinsafari
    ; TODO(home-rectify M1.3 follow-up): the event-flag system (CheckEvent /
    ;   EventFlagAddressA over wEventFlags) is non-home. The Safari-zone cleanup
    ;   below is gated on EVENT_IN_SAFARI_ZONE; until the event system lands, treat
    ;   the event as clear (skip cleanup) — faithful for the common (non-safari)
    ;   blackout, and the safari cleanup is logged as follow-up glue.
    jmp .didnotblackoutinsafari
    ; --- faithful safari-blackout cleanup (currently unreachable; kept for the port) ---
    ; xor a
    ; mov [ebp + wNumSafariBalls], al
    ; mov [ebp + wSafariSteps], al
    ; mov [ebp + wSafariSteps + 1], al
    ; EventFlagAddressA EVENT_IN_SAFARI_ZONE →
    ;   mov [ebp + wNextSafariZoneGateScript], al
    ;   mov [ebp + wSafariZoneGateCurScript], al
.didnotblackoutinsafari:
    jmp HoldTextDisplayOpen

PlayerBlackedOutText:
    text_far _PlayerBlackedOutText
    text_end

; ─────────────────────────────────────────────────────────────────────────────
; DisplayRepelWoreOffText — pret home/text_script.asm:214
; ─────────────────────────────────────────────────────────────────────────────
DisplayRepelWoreOffText:
    mov esi, RepelWoreOffText
    mov dword [text_msgbox], msgbox_dialog     ; overworld dialog projection
    call PrintText
    jmp AfterDisplayingTextID

RepelWoreOffText:
    text_far _RepelWoreOffText
    text_end

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPikachuEmotion — pret home/text_script.asm:223
; ─────────────────────────────────────────────────────────────────────────────
DisplayPikachuEmotion:
    call TalkToPikachu                   ; callfar
    jmp CloseTextDisplay

; ─────────────────────────────────────────────────────────────────────────────
; DisplayTextBoxID — moved to its canonical pret home, src/home/textbox.asm
; (menus S2). Externed above.
; ─────────────────────────────────────────────────────────────────────────────

; ─────────────────────────────────────────────────────────────────────────────
; FarPrintText — pret home/print_num.asm:1. Print far text b:hl at (1,14).
; In: ESI = text stream (HL). B (BH) = source ROM bank (ignored — flat memory).
;   pret: push bank; a=b; BankswitchCommon; PrintText; pop; BankswitchCommon; ret
; ─────────────────────────────────────────────────────────────────────────────
FarPrintText:
    ; TODO-HW: bank switch is a no-op under flat EBP memory; the far bank in BH is
    ; ignored (all ROM is flat-addressable). Faithful call structure preserved.
    movzx eax, byte [ebp + hLoadedROMBank]
    push eax
    mov al, bh                           ; a = b (target bank)
    call BankswitchCommon
    call PrintText             ; pret PrintText (general printer)
    pop eax
    call BankswitchCommon
    ret

%include "assets/text_script_text.inc"
