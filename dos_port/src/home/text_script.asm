; text_script.asm — DisplayTextID dialogue-dispatch tree.
;
; Faithful translation of pret `home/text_script.asm` (Pokémon Yellow):
; DisplayTextID / CloseTextDisplay / HoldTextDisplayOpen and the special-case
; dialogue branches (mart / PokéCenter nurse / fainted / blacked-out / repel /
; Pikachu-emotion / Safari game-over). Plus the general `DisplayTextBoxID`
; dispatcher (pret home/textbox.asm) and `FarPrintText` (pret home/print_num.asm).
;
; This is the M1.3 skeleton of the Wave-1 home rectification (see
; docs/current_plan_home_rectification.md). It is intended to live at
; dos_port/src/home/text_script.asm and be assembled CHECK-ONLY (a *_CHECK_SRCS
; Makefile entry): its non-home dependencies (DisplayTextIDInit, the mart/PC/
; PokéCenter special-case handlers, the map text-pointer subsystem, the event
; flag system) are externed with `; TODO(home-rectify M1.3 follow-up):` markers
; and do not resolve until later waves — so it will not LINK yet, only assemble.
;
; Register map (project convention): A=AL, HL=ESI, BC=BX (B=BH,C=BL),
; DE=DX (D=DH,E=DL), EBP=GB base; GB memory accessed as [EBP + addr].
; GB 16-bit pointers (wCurMapTextPtr, map text tables) are treated as EBP-relative
; GB-space addresses and read little-endian (x86 is LE, matching the GB).
;
;   ── ADDRESSING MODEL CAVEAT (follow-up glue) ──────────────────────────────
;   pret resolves the text address by walking the map's ROM text-pointer table
;   via `wCurMapTextPtr`. The port has no map text-pointer-table subsystem yet
;   (dialogue currently flows through NPC_DIALOG_BUF + per-map script files). The
;   table walk below is translated faithfully assuming wCurMapTextPtr points into
;   EBP GB-space; when the real map-text subsystem lands, reconcile whether these
;   tables live in EBP GB-space or as flat program labels. See SUMMARY.md.
;
; Build (check-only): nasm -f coff -I include/ -I . -o /dev/null text_script.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"                ; BUG_FIX_LEVEL
; TEMPORARY: symbols the root must migrate into the canonical includes, then drop
; this line (see m1_3_pending_symbols.inc header).
%include "m1_3_pending_symbols.inc"

section .text

global DisplayTextID
global AfterDisplayingTextID
global HoldTextDisplayOpen
global CloseTextDisplay
global DisplayPokemartDialogue
global LoadItemList
global DisplayTextBoxID
global FarPrintText

; ── text printers (text/text.asm) ──
extern PrintText_Overworld              ; pret PrintText (window.asm) — general/overworld printer
extern PrintText_NoBox                  ; pret PrintText_NoCreatingTextBox
extern DelayFrame

; ── non-home glue: DEFERRED, resolves in later waves ──────────────────────────
; TODO(home-rectify M1.3 follow-up): DisplayTextIDInit is farcall'd by pret to set
;   up the text box / save regs. Non-home (engine bank-3). Resolve when the text-ID
;   init path is ported. Wave 1/overworld.
extern DisplayTextIDInit
; TODO(home-rectify M1.3 follow-up): overworld/map glue (overworld.asm, map_sprites.asm)
extern SwitchToMapRomBank               ; ld a,[wCurMap]; bankswitch (flat = no-op wrapper)
extern InitMapSprites                   ; reload sprite tile patterns after text
extern LoadCurrentMapView
extern LoadPlayerSpriteGraphics
extern UpdateSprites                    ; movement.asm (already ported) — final jp target
extern Joypad                           ; joypad read (pret Joypad); port uses ISR + wrapper
extern LoadGBPal                        ; palettes/fade (Wave 10)
extern BankswitchCommon                 ; home/bankswitch.asm (Wave 0, no-op flat) — extern
; TODO(home-rectify M1.3 follow-up): the START-menu / Pikachu / Safari handlers are
;   non-home engine routines (Wave 4 menu framework, pikachu FSM Wave 9, safari).
extern DisplayStartMenu
extern TalkToPikachu                    ; callfar (engine/pikachu)
extern PrintSafariGameOverText          ; callfar (engine/safari)
; TODO(home-rectify M1.3 follow-up): mart / PokéCenter / PC / vending / prize / cable
;   special-case bodies are non-home (engine bank routines). Externed here; the
;   home-layer *dispatch* to them is faithful.
extern DisplayPokemartDialogue_         ; homecall (engine/menus)
extern DisplayPokemonCenterDialogue_    ; homecall (engine/menus)
extern TextScript_ItemStoragePC
extern TextScript_BillsPC
extern TextScript_PokemonCenterPC
extern VendingMachineMenu               ; farcall
extern TextScript_GameCornerPrizeMenu
extern CableClubNPC                     ; callfar
; TODO(home-rectify M1.3 follow-up): DisplayTextBoxID_ is the box-drawing worker
;   (pret home/textbox.asm homecall_sf). Non-home (engine). Wave 4-ish.
extern DisplayTextBoxID_
; TODO(home-rectify M1.3 follow-up): far-text labels below are TX_FAR streams whose
;   data lives in ROM banks (M1.1 TX_FAR work). Externed as flat labels; the text
;   data tables are not ported here.
extern _PokemartGreetingText
extern _PokemonFaintedText
extern _PlayerBlackedOutText
extern _RepelWoreOffText

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
.skipSwitchToMapBank:
    ; ld a,30 / ldh [hFrameCounter],a  — used as joypad poll timer (half a second)
    mov al, 30
    mov [ebp + hFrameCounter], al

    ; ld hl, wCurMapTextPtr / ld a,[hli] / ld h,[hl] / ld l,a  → hl = map text pointer
    movzx esi, word [ebp + wCurMapTextPtr]

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
    lea esi, [wMapSpriteData + edx + 1]  ; hl = wMapSpriteData + de + 1
    movzx eax, byte [ebp + esi]          ; a = text ID of the sprite (byte 1 of entry)
    pop esi                              ; pop hl (map text ptr)
.skipSpriteHandling:
    ; ── look up the address of the text in the map's text entries ──
    ; dec a ; ld e,a ; ld d,0 ; add hl,de ; add hl,de ; ld a,[hli]; ld h,[hl]; ld l,a
    dec al
    movzx edx, al                        ; de = (textID-1), d=0
    add esi, edx
    add esi, edx                         ; hl += 2*(textID-1)  (word index into pointer table)
    and esi, 0xFFFF                       ; faithful 16-bit GB-pointer wrap
    ; hl = [hl] (LE 16-bit pointer to the text stream)
    movzx esi, word [ebp + esi]
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
    call PrintText_NoBox
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
    ; call WaitForTextScrollButtonPress — the port's WaitForTextScrollButtonPress is
    ; folded into manual_text_scroll inside the printers; the box was already advanced
    ; by PrintText_NoBox's TX stream. HoldTextDisplayOpen handles the A-held hold-open.
    ; (pret joypad2.asm:WaitForTextScrollButtonPress; see SUMMARY follow-up note.)
    ; fall through

; loop to hold the dialogue box open as long as the player keeps holding A
HoldTextDisplayOpen:
    ; call Joypad ; ldh a,[hJoyHeld]; bit B_PAD_A,a; jr nz,HoldTextDisplayOpen
    call Joypad
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
    call PrintText_Overworld
    pop esi                              ; pop hl
    inc esi                              ; inc hl — skip the TX_SCRIPT_MART byte → item list
    call LoadItemList
    mov al, PRICEDITEMLISTMENU
    mov [ebp + wListMenuID], al
    ; homecall DisplayPokemartDialogue_  (bank switch = no-op flat)
    call DisplayPokemartDialogue_
    jmp AfterDisplayingTextID

PokemartGreetingText:
    ; pret: text_far _PokemartGreetingText / text_end
    db 0x17                              ; TX_FAR
    dd _PokemartGreetingText             ; far pointer (flat label; TX_FAR handling = M1.1)
    db 0x50                              ; text_end (TX_END)

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
    call PrintText_Overworld
    jmp AfterDisplayingTextID

PokemonFaintedText:
    db 0x17                              ; TX_FAR
    dd _PokemonFaintedText
    db 0x50                              ; TX_END

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPlayerBlackedOutText — pret home/text_script.asm:192
; ─────────────────────────────────────────────────────────────────────────────
DisplayPlayerBlackedOutText:
    mov esi, PlayerBlackedOutText
    call PrintText_Overworld
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
    db 0x17                              ; TX_FAR
    dd _PlayerBlackedOutText
    db 0x50                              ; TX_END

; ─────────────────────────────────────────────────────────────────────────────
; DisplayRepelWoreOffText — pret home/text_script.asm:214
; ─────────────────────────────────────────────────────────────────────────────
DisplayRepelWoreOffText:
    mov esi, RepelWoreOffText
    call PrintText_Overworld
    jmp AfterDisplayingTextID

RepelWoreOffText:
    db 0x17                              ; TX_FAR
    dd _RepelWoreOffText
    db 0x50                              ; TX_END

; ─────────────────────────────────────────────────────────────────────────────
; DisplayPikachuEmotion — pret home/text_script.asm:223
; ─────────────────────────────────────────────────────────────────────────────
DisplayPikachuEmotion:
    call TalkToPikachu                   ; callfar
    jmp CloseTextDisplay

; ─────────────────────────────────────────────────────────────────────────────
; DisplayTextBoxID — pret home/textbox.asm. Draw a text box selected by
; [wTextBoxID]; b,c = y,x cursor (TWO_OPTION_MENU only).
;   pret: homecall_sf DisplayTextBoxID_ / ret   (flat memory ⇒ bank switch is a no-op)
; ─────────────────────────────────────────────────────────────────────────────
DisplayTextBoxID:
    ; TODO-HW: homecall_sf bank/stack-frame setup collapses to a plain call under
    ; the flat memory model. DisplayTextBoxID_ is the (non-home) box-drawing worker.
    call DisplayTextBoxID_
    ret

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
    call PrintText_Overworld             ; pret PrintText (general printer)
    pop eax
    call BankswitchCommon
    ret
