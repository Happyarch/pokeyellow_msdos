; pokemon.asm — GetMonHeader / GetPartyMonName + the party-menu home driver
; (menus-port Session 5).
;
; Source: home/pokemon.asm:GetMonHeader, GetPartyMonName2, GetPartyMonName,
;         DisplayPartyMenu, GoBackToPartyMenu, PartyMenuInit,
;         HandlePartyMenuInput, PrintStatusCondition, DrawHPBar, PrintLevel* +
;         engine/menus/pokedex.asm:IndexToPokedex (pret/pokeyellow).
;
; GetMonHeader copies the 28-byte base-stats record for the internal species
; index in [wCurSpecies] into wMonHeader, then overwrites byte 0 (the dex id)
; with the internal index — matching the original.
;
; DEVIATION{class=data-model; pret=home/pokemon.asm:GetMonHeader; behavior=index flat BaseStats directly and copy into wMonHeader while eliding bank switches and the net-neutral IndexToPokedex predef; evidence=pret GetMonHeader push/pop wPokedexNum flow plus port flat generated tables; lifetime=permanent flat-data and banking boundary}
; The data tables (BaseStats, IndexToPokedex) live in the
; program image as flat labels, not in EBP-relative GB memory, so GetMonHeader
; indexes them directly and `rep movsb`s into [ebp+wMonHeader] instead of going
; through GB AddNTimes/CopyData (which assume an EBP-relative source), and drops
; pret's BankswitchCommon pair (no banks here). It also drops the `predef
; IndexToPokedex` CALL: that predef's whole contract is wPokedexNum := dex(
; wPokedexNum), and pret saves wPokedexNum on entry and restores it at .done — so
; the routine's only NET effect on GB memory is the wMonHeader copy plus wMonHIndex,
; which is exactly what the port produces. IndexToPokedex is a flat TABLE here, read
; in place. Nothing observable is lost; verified against pret's push/pop af pair.
;
; FOSSIL/GHOST GUARD (M5.2): pret GetMonHeader special-cases the three sprite-only
; indices FOSSIL_KABUTOPS ($B6), FOSSIL_AERODACTYL ($B7) and MON_GHOST ($B8) —
; they have NO BaseStats entry, so it skips the copy and instead writes the sprite
; dimensions + front-pic pointer into wMonHSpriteDim. Without this guard the port
; would index BaseStats out of bounds (dex lookup returns 0) and copy garbage. The
; front-pic pointer is written as 0 for now — the fossil/ghost battle sprites are
; not ported yet (no battle sprite loader); TODO-HW below.
;
; Build: nasm -f coff -I include/ -I . -o pokemon.o pokemon.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern BaseStats
extern IndexToPokedex
extern SkipFixedLengthTextEntries
extern CopyData
extern PrintNumber
; --- party-menu home driver (menus S5) ---
extern LoadHpBarAndStatusTilePatterns   ; src/home/load_font.asm
extern GBPalWhiteOutWithDelay3          ; src/home/fade.asm
extern ClearSprites                     ; src/home/sprites.asm
extern DrawPartyMenu_                   ; src/engine/menus/party_menu.asm
extern RedrawPartyMenu_
extern HandleMenuInput_                 ; src/home/window.asm — loop entry that does NOT
                                        ; clear wPartyMenuAnimMonEnabled (pret's underscore entry)
extern PlaceUnfilledArrowMenuCursor
extern menu_item_step
extern menu_redraw_cb
extern text_row_stride                  ; src/home/text.asm
extern ErasePartyMenuCursors            ; src/engine/menus/start_sub_menus.asm
extern SwitchPartyMon
extern PartyMenuMirror                  ; src/engine/menus/party_menu.asm — scratch→window blit
extern PartyMenuPrintText               ; src/engine/menus/party_menu.asm — PrintText via msgbox_party
extern PrintStatusAilment               ; src/engine/pokemon/status_ailments.asm
extern IsThisPartyMonStarterPikachu     ; src/engine/pikachu/pikachu_status.asm
extern CheckPikachuFollowingPlayer      ; src/engine/overworld/pikachu.asm
extern PartyMenuText_12cc               ; assets/item_text.inc (_SleepingPikachuText1)
%ifdef DEBUG_PARTYMENU
extern DelayFrame
extern DumpBackbuffer
extern PlaceMenuCursor                  ; src/home/window.asm — ▶ at the current item
%endif

global GetMonHeader
global GetPartyMonName
global GetPartyMonName2
global PrintLevel
global PrintLevelFull
global PrintLevelCommon
global DisplayPartyMenu
global GoBackToPartyMenu
global PartyMenuInit
global HandlePartyMenuInput
global DrawPartyMenu
global RedrawPartyMenu
global PrintStatusCondition
global DrawHPBar

CHAR_LV        equ 0x6E     ; '<LV>' ":L" tile (constants/charmap.asm:67)

; "FNT" (PrintStatusCondition) — Tier-1 data, charmap-encoded by
; tools/gen_menu_strings.py. Unterminated: pret writes it with ld_hli_a_string.
%include "assets/home_pokemon_strings.inc"

section .text

; copies the base-stat data of a pokemon to wMonHeader
; INPUT: [wCurSpecies] = internal species index
GetMonHeader:
    pushad

    movzx eax, byte [ebp + wCurSpecies]

    ; --- fossil/ghost special sprite IDs (pret GetMonHeader .specialID) ---
    cmp al, FOSSIL_KABUTOPS
    je .kabutops
    cmp al, MON_GHOST
    je .ghost
    cmp al, FOSSIL_AERODACTYL
    je .aerodactyl

    ; normal path: src = BaseStats + (dex - 1) * BASE_DATA_SIZE
    ; dex = IndexToPokedex[wCurSpecies - 1]   (internal index -> national dex)
    dec eax
    movzx eax, byte [IndexToPokedex + eax]
    dec eax
    imul eax, eax, BASE_DATA_SIZE
    lea esi, [BaseStats + eax]        ; flat (program-image) source
    lea edi, [ebp + wMonHeader]       ; flat dest in GB memory
    mov ecx, BASE_DATA_SIZE
    rep movsb
    jmp .writeIndex

.kabutops:
    mov bl, 0x66                      ; size of Kabutops fossil sprite
    jmp .specialID
.ghost:
    mov bl, 0x66                      ; size of Ghost sprite
    jmp .specialID
.aerodactyl:
    mov bl, 0x77                      ; size of Aerodactyl fossil sprite
.specialID:
    mov [ebp + wMonHSpriteDim], bl    ; write sprite dimensions
    ; TODO-HW: front-pic pointer (FossilKabutopsPic / GhostPic / FossilAerodactylPic).
    ; Verified 2026-07-13 (row 11): none of the three exists in the port — no symbol
    ; in pkmn.sym, no data blob, no generator emits them — so there is nothing to point
    ; at. 0 is written so the guard still skips the out-of-bounds BaseStats read.
    mov word [ebp + wMonHFrontSprite], 0

.writeIndex:
    ; wMonHIndex = wCurSpecies (write internal index back over the dex byte)
    mov al, [ebp + wCurSpecies]
    mov [ebp + wMonHIndex], al

    popad
    ret

; copy party pokemon's name to wNameBuffer
; INPUT: [wWhichPokemon] = index within party
GetPartyMonName2:
    mov al, [ebp + wWhichPokemon]     ; index within party
    mov esi, wPartyMonNicks

; this is called more often; INPUT: AL = index, ESI (hl) = name list base
GetPartyMonName:
    push esi
    push ebx
    call SkipFixedLengthTextEntries   ; esi += NAME_LENGTH * al
    mov edx, wNameBuffer
    push edx
    mov bx, NAME_LENGTH
    call CopyData                      ; esi=src, edx=dest, bx=count
    pop edx                            ; edx = wNameBuffer (output)
    pop ebx
    pop esi
    ret

; prints the level of a mon, with the ":L" prefix dropped at level >= 100
; INPUT: ESI (hl) = destination tile-buffer cursor (EBP-relative),
;        [wLoadedMonLevel] = level
; pret ref: home/pokemon.asm:PrintLevel
PrintLevel:
    mov byte [ebp + esi], CHAR_LV      ; ld a, '<LV>' / ld [hli], a
    inc esi
    mov bl, 2                          ; c = 2 digits
    mov al, [ebp + wLoadedMonLevel]
    cmp al, 100
    jc PrintLevelCommon
    ; if level at least 100, write over the ":L" tile
    dec esi
    inc bl                             ; 3 digits
    jmp PrintLevelCommon

; prints the level without leaving off ":L" regardless of level
; pret ref: home/pokemon.asm:PrintLevelFull
PrintLevelFull:
    mov byte [ebp + esi], CHAR_LV
    inc esi
    mov bl, 3                          ; c = 3 digits
    mov al, [ebp + wLoadedMonLevel]
    ; fall through

; pret ref: home/pokemon.asm:PrintLevelCommon
PrintLevelCommon:
    mov [ebp + wTempByteValue], al
    mov edx, wTempByteValue            ; de = wTempByteValue
    mov bh, (1 << BIT_LEFT_ALIGN) | 1  ; b = LEFT_ALIGN | 1 byte
    jmp PrintNumber

; ===========================================================================
; Party-menu home driver (menus-port Session 5).
; pret ref: home/pokemon.asm:DisplayPartyMenu..HandlePartyMenuInput.
; The pret code pushes hTileAnimations in DisplayPartyMenu/GoBackToPartyMenu
; and pops it in HandlePartyMenuInput's non-swap exit — that cross-routine
; stack discipline is kept verbatim (the swap paths re-enter HandlePartyMenuInput
; without popping, exactly as pret's `jp`s do).
; Return contract (pret): CF=0 = mon chosen (wWhichPokemon/wCurPartySpecies set),
; CF=1 = no mon chosen (B pressed / empty party).
; ===========================================================================
DisplayPartyMenu:
    movzx eax, byte [ebp + hTileAnimations] ; ldh a,[hTileAnimations]
    push eax                                ; push af
    mov byte [ebp + hTileAnimations], 0     ; xor a / ldh [hTileAnimations],a
    call GBPalWhiteOutWithDelay3
    call ClearSprites
    call PartyMenuInit
    call DrawPartyMenu
%ifdef DEBUG_PARTYMENU
    ; deterministic pixel gate: place the ▶ cursor exactly as the first
    ; HandleMenuInput iteration would (the golden dumps inside that loop, so
    ; its cursor is placed), mirror the scratch to the panel window, render
    ; one frame, dump FRAME.BIN, exit (DumpBackbuffer never returns).
    call PlaceMenuCursor
    call PartyMenuMirror
    call DelayFrame
    call DumpBackbuffer
%endif
    jmp HandlePartyMenuInput                ; jp HandlePartyMenuInput

GoBackToPartyMenu:
    movzx eax, byte [ebp + hTileAnimations]
    push eax                                ; push af
    mov byte [ebp + hTileAnimations], 0
    call PartyMenuInit
    call RedrawPartyMenu
    jmp HandlePartyMenuInput                ; jp HandlePartyMenuInput

; pret DrawPartyMenu/RedrawPartyMenu are Bankswitch trampolines onto the
; engine bank (DrawPartyMenuCommon); flat memory collapses them to jumps.
DrawPartyMenu:
    jmp DrawPartyMenu_
RedrawPartyMenu:
    jmp RedrawPartyMenu_

PartyMenuInit:
    ; ld a,1 / call BankswitchHome — flat memory: no bank to switch
    call LoadHpBarAndStatusTilePatterns
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY ; set BIT_NO_TEXT_DELAY,[hl]
    xor al, al                              ; xor a ; PLAYER_PARTY_DATA
    mov [ebp + wMonDataLocation], al
    mov [ebp + wMenuWatchMovingOutOfBounds], al
    mov byte [ebp + wTopMenuItemY], 1       ; inc a / ld [hli],a — top menu item Y
    mov byte [ebp + wTopMenuItemX], 0       ; xor a / ld [hli],a — top menu item X
    mov ah, [ebp + wPartyAndBillsPCSavedMenuItem] ; push af analog (kept for old id)
    mov [ebp + wCurrentMenuItem], ah        ; ld [hli],a — current menu item ID
    mov al, [ebp + wPartyCount]
    test al, al                             ; and a
    jz .storeMaxMenuItemID
    dec al                                  ; max menu item ID = count - 1
.storeMaxMenuItemID:
    mov [ebp + wMaxMenuItem], al            ; ld [hli],a
    mov al, [ebp + wForcePlayerToChooseMon]
    test al, al
    mov al, PAD_A | PAD_B
    jz .next
    mov byte [ebp + wForcePlayerToChooseMon], 0
    mov al, PAD_A                           ; xor a / … / inc a ; a = PAD_A
.next:
    mov [ebp + wMenuWatchedKeys], al        ; ld [hli],a — menu watched keys
    mov [ebp + wLastMenuItem], ah           ; pop af / ld [hl],a — old menu item ID
    ; port(menus model): pret PlaceMenuCursor hardcodes the party spacing; the
    ; generic driver takes it from menu_item_step on the stride-20 scratch.
    mov dword [text_row_stride], 20
    mov dword [menu_item_step], 2 * 20
    ret

HandlePartyMenuInput:
    mov byte [ebp + wMenuWrappingEnabled], 1    ; ld a,1 / ld [wMenuWrappingEnabled],a
    mov byte [ebp + wPartyMenuAnimMonEnabled], 0x40 ; ld a,$40
    ; The icon bob itself is pret's: HandleMenuInput_'s .loop2 calls
    ; AnimatePartyMon while wPartyMenuAnimMonEnabled is set (just above).
    ; menu_redraw_cb only carries the port-only bit: the cursor the generic
    ; driver just drew on the stride-20 scratch has to reach the panel window.
    mov dword [menu_redraw_cb], PartyMenuMirror
    call HandleMenuInput_                       ; call HandleMenuInput_
    mov dword [menu_redraw_cb], 0
    push eax                                    ; push af — pressed keys
    test al, PAD_B                              ; bit B_PAD_B,a — was B pressed?
    ; the three `mov`s below are pret's flag-neutral `ld`s: ZF above survives to the
    ; `jnz` (x86 mov, like SM83 ld, does not touch flags)
    mov byte [ebp + wPartyMenuAnimMonEnabled], 0
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    jnz .asm_1258                               ; jr nz, .asm_1258 — B cancels, no refusal
    mov [ebp + wWhichPokemon], al               ; ld a,[wCurrentMenuItem] / ld [wWhichPokemon],a
    call IsThisPartyMonStarterPikachu           ; callfar — CF set iff it's OUR Pikachu
    jnc .asm_1258
    call CheckPikachuFollowingPlayer            ; ZF=1 iff it is NOT following us
    jnz .asm_128f                               ; awake-and-following → refuse to pick it
.asm_1258:
    pop eax                                     ; pop af — pressed keys
    call PlaceUnfilledArrowMenuCursor
    call PartyMenuMirror                        ; port: push the ▷ to the panel window
    mov bl, al                                  ; ld b,a
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF ; res BIT_NO_TEXT_DELAY,[hl]
    mov al, [ebp + wMenuItemToSwap]
    test al, al                                 ; and a
    jnz .swappingPokemon
    pop eax                                     ; pop af — saved hTileAnimations
    mov [ebp + hTileAnimations], al             ; ldh [hTileAnimations],a
    test bl, PAD_B                              ; bit B_PAD_B,b
    jnz .noPokemonChosen
    mov al, [ebp + wPartyCount]
    test al, al                                 ; and a
    jz .noPokemonChosen
    movzx eax, byte [ebp + wCurrentMenuItem]
    mov [ebp + wWhichPokemon], al
    mov al, [ebp + eax + wPartySpecies]         ; ld hl,wPartySpecies / add hl,bc
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wBattleMonSpecies2], al
    ; call BankswitchBack — flat memory: nothing to restore
    clc                                         ; and a
    ret
.asm_128f:
    ; The starter Pikachu is walking with us — it can't be selected from the menu.
    ; "There isn't any response..." (_SleepingPikachuText1).
    pop eax                                     ; pop af — drop the pressed keys
    mov esi, PartyMenuText_12cc                 ; ld hl, PartyMenuText_12cc
    ; DEVIATION{class=projection; pret=home/pokemon.asm:HandlePartyMenuInput; behavior=route the sleeping-Pikachu text through the party message-box projection; evidence=pret bare PrintText call plus port party screen stride-20 window ownership; lifetime=permanent window-compositor boundary}
    ; pret's bare `call PrintText` lands in the GB dialog
    ; rows, which ARE this screen's message area. The port draws the party screen on
    ; a stride-20 scratch behind two windows, so the message has to be projected —
    ; same msgbox_party record .printItemUseMessage prints through, and the same one
    ; that keeps manual_text_scroll from stamping the dialog over the mon-list panel
    ; (M-29). PartyMenuPrintText selects it and restores msgbox_dialog after.
    call PartyMenuPrintText                     ; call PrintText
    mov byte [ebp + wMenuItemToSwap], 0         ; xor a / ld [wMenuItemToSwap],a
    pop eax                                     ; pop af — saved hTileAnimations
    mov [ebp + hTileAnimations], al             ; ldh [hTileAnimations],a
.noPokemonChosen:
    ; call BankswitchBack — flat memory: nothing to restore
    stc                                         ; scf
    ret
.swappingPokemon:
    test bl, PAD_B                              ; bit B_PAD_B,b
    jz .handleSwap
.cancelSwap:                                    ; the B button was pressed
    call ErasePartyMenuCursors
    xor al, al
    mov [ebp + wMenuItemToSwap], al
    mov [ebp + wPartyMenuTypeOrMessageID], al
    call RedrawPartyMenu
    jmp HandlePartyMenuInput                    ; jp (hTileAnimations stays pushed)
.handleSwap:
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wWhichPokemon], al
    call SwitchPartyMon                         ; farcall SwitchPartyMon
    jmp HandlePartyMenuInput

; ---------------------------------------------------------------------------
; PrintStatusCondition — 3-letter status ("FNT" when HP is 0, else the ailment).
; pret ref: home/pokemon.asm:PrintStatusCondition.
; In: EDX (de) = EBP-rel address of the status byte (MON_STATUS field);
;     ESI (hl) = dest tile cursor (EBP-rel). Out: ESI advanced if printed.
; ---------------------------------------------------------------------------
PrintStatusCondition:
    push edx                                    ; push de
    dec edx
    dec edx                                     ; de = current HP low byte
    mov al, [ebp + edx]                         ; ld a,[de] / ld b,a
    dec edx
    or al, [ebp + edx]                          ; or b — is HP zero?
    pop edx                                     ; pop de
    jnz PrintStatusConditionNotFainted
    ; fainted: ld_hli_a_string "FNT" (macros/code.asm:13). The macro emits
    ; `ld [hli], a` for every char BUT the last and a plain `ld [hl], 'T'` for it —
    ; so HL ends up advanced by 2, pointing AT the 'T', and A is left holding 'N'.
    ; (The port used to `add esi, 3` and leave A = 'T': both were wrong.) `and a`
    ; then returns ZF=0 (A = $8D) / CF=0.
    mov al, [hp_str_fnt]                        ; 'F'
    mov [ebp + esi], al
    inc esi
    mov al, [hp_str_fnt + 1]                    ; 'N' — stays in A
    mov [ebp + esi], al
    inc esi
    push eax
    mov al, [hp_str_fnt + 2]                    ; ld [hl], 'T' — no hl advance, no A
    mov [ebp + esi], al
    pop eax
    and al, al                                  ; and a
    ret
PrintStatusConditionNotFainted:
    jmp PrintStatusAilment                      ; homejp_sf PrintStatusAilment

; ---------------------------------------------------------------------------
; DrawHPBar — draw an HP bar DH (d) tiles long, filled to DL (e) pixels.
; If BL (c) is nonzero, show at least a sliver. Right cap from [wHPBarType]
; (1 = status screen / battle $6d, else pokemon menu $6c).
; pret ref: home/pokemon.asm:DrawHPBar.
; In: ESI (hl) = dest tile cursor (EBP-rel). ESI/EDX preserved (pret push/pop).
; ---------------------------------------------------------------------------
DrawHPBar:
    push esi                                    ; push hl
    push edx                                    ; push de
    ; Left
    mov byte [ebp + esi], 0x71                  ; "HP:"
    inc esi
    mov byte [ebp + esi], 0x62
    inc esi
    push esi                                    ; push hl
    ; Middle
    mov al, 0x63                                ; empty
.draw:
    mov [ebp + esi], al
    inc esi
    dec dh                                      ; dec d
    jnz .draw
    ; Right
    mov al, [ebp + wHPBarType]
    dec al                                      ; dec a (mov below keeps flags)
    mov al, 0x6d                                ; status screen and battle
    jz .ok
    dec al                                      ; $6c — pokemon menu
.ok:
    mov [ebp + esi], al
    pop esi                                     ; pop hl
    mov al, dl                                  ; ld a,e
    test al, al                                 ; and a
    jnz .fill
    ; If c is nonzero, draw a pixel anyway.
    mov al, bl                                  ; ld a,c
    test al, al
    jz .done
    mov dl, 1                                   ; ld e,1
.fill:
    mov al, dl                                  ; ld a,e
    sub al, 8
    jc .partial
    mov dl, al                                  ; ld e,a
    mov byte [ebp + esi], 0x6b                  ; full
    inc esi
    mov al, dl                                  ; ld a,e
    test al, al                                 ; and a
    jz .done
    jmp .fill
.partial:
    ; Fill remaining pixels at the end if necessary.
    mov al, 0x63                                ; empty
    add al, dl                                  ; add e — $63 + n-pixel partial
    mov [ebp + esi], al
.done:
    pop edx                                     ; pop de
    pop esi                                     ; pop hl
    ret
