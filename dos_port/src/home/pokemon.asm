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
; DIVERGENCE FROM GB: the data tables (BaseStats, IndexToPokedex) live in the
; program image as flat labels, not in EBP-relative GB memory, so we index them
; directly and `rep movsb` into [ebp+wMonHeader] instead of going through the
; GB CopyData/AddNTimes (which assume EBP-relative source).
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
extern LoadHpBarAndStatusTilePatterns   ; src/gfx/load_font.asm
extern GBPalWhiteOutWithDelay3          ; src/home/fade.asm
extern ClearSprites                     ; src/gfx/sprites.asm
extern DrawPartyMenu_                   ; src/engine/menus/party_menu.asm
extern RedrawPartyMenu_
extern HandleMenuInput_                 ; src/home/window.asm — loop entry that does NOT
                                        ; clear wPartyMenuAnimMonEnabled (pret's underscore entry)
extern PlaceUnfilledArrowMenuCursor
extern menu_item_step
extern menu_redraw_cb
extern text_row_stride                  ; src/text/text.asm
extern ErasePartyMenuCursors            ; src/engine/menus/start_sub_menus.asm
extern SwitchPartyMon
extern PartyMenuMirror                  ; src/engine/menus/party_menu.asm — scratch→window blit
extern PrintStatusAilment               ; src/engine/pokemon/status_ailments.asm
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
    ; TODO-HW: front-pic pointer (FossilKabutops/Ghost/FossilAerodactylPic) —
    ; battle sprites not ported yet; write 0 so the OOB BaseStats read is skipped.
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
    mov byte [ebp + wPartyMenuAnimMonEnabled], 0
    mov al, [ebp + wCurrentMenuItem]
    mov [ebp + wPartyAndBillsPCSavedMenuItem], al
    ; STUB(pikachu-follow): pret checks IsThisPartyMonStarterPikachu +
    ; CheckPikachuFollowingPlayer here (the sleeping-Pikachu refusal path,
    ; .asm_128f). The follower system is not ported; every mon takes the
    ; .asm_1258 path, as any non-follower mon does in pret.
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
.noPokemonChosen:
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
    ; fainted: "FNT"
    mov byte [ebp + esi], 0x85                  ; F
    mov byte [ebp + esi + 1], 0x8D              ; N
    mov byte [ebp + esi + 2], 0x93              ; T
    add esi, 3                                  ; ld_hli_a_string advances hl
    clc                                         ; and a
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
