; ===========================================================================
; league_pc.asm — POKéMON LEAGUE PC (Hall-of-Fame reader). Faithful port of pret
; engine/menus/league_pc.asm: PKMNLeaguePC / LeaguePCShowTeam / LeaguePCShowMon.
;
; AccessedHoFPCText is pret's own text_far stream (Tier-1 data in
; assets/league_pc_text.inc, generated from data/text/text_3.asm) printed by
; PrintText, and HallOfFameNoText is generated the same way; the `para` page break
; and the terminal `prompt` are executed by the text engine. (Until menu-fidelity
; row 17 part 4 this file drew the two pages itself from hand-encoded charmap bytes
; and re-implemented the prompt as a ▼-blink loop — see ledger M-89.)
;
; Three claims this header used to make, all of them false by the time they were
; read (ledger M-90/M-91):
;   - "STUB(S7-save): LoadHallOfFameTeams reads HoF SRAM — the save layer is S7 …
;     the team loop is GUARDED OFF": the save layer LANDED. LoadHallOfFameTeams is
;     real and linked (src/engine/menus/save.asm). The port-invented 0-team guard is
;     gone; the loop is pret's, unconditional, and live.
;   - "TODO-HW: RunPaletteCommand / RunDefaultPaletteCommand are palette-HAL
;     (Phase 5); no-op here": both are real, exported and linked (home/palettes.asm
;     → engine/gfx/palettes.asm:_RunPaletteCommand; naming_screen.asm). Both calls
;     restored.
;   - "RunPaletteCommand is already a HAL stub in faint_switch.asm": it is not in
;     faint_switch.asm at all, and it is not a stub.
;
; DEVIATION(window-compositor): the dialog is an entry in the port's window list,
; which pret's ClearScreen (a wTileMap wipe) cannot drop — hence hide_window on the
; exit path. Same reason, same shape as pc.asm:ActivatePC / oaks_pc.asm.
; DEVIATION(canvas): LeaguePCShowMon lays its full screen out in the stride-20
; W_TILEMAP scratch (hlcoord X,Y = W_TILEMAP + Y*20 + X) and publishes no window —
; UNVERIFIED, and stated as such in the ledger: reaching it needs a save with a
; recorded Hall of Fame plus the HoF movie routine Func_7033f (still a stub).
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH,C=BL), DE=DX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/league_pc.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"          ; text_far / text_end

global PKMNLeaguePC
global LeaguePCShowTeam
global LeaguePCShowMon
global AccessedHoFPCText
global HallOfFameNoText         ; body generated into assets/league_pc_text.inc

extern PrintText                ; home/window.asm — In: ESI = text stream
extern text_msgbox              ; home/text.asm — the active msgbox projection
extern msgbox_dialog            ; home/text.asm — the standard bottom dialog box
extern hide_window              ; ppu/ppu.asm — drop the dialog window layer
extern TextBoxBorder            ; home/textbox.asm — ESI=top-left, BL=int_w, BH=int_h
extern GBPalWhiteOutWithDelay3  ; home/fade.asm
extern ClearScreen              ; movie/title.asm
extern GBPalNormal              ; home/init.asm
extern RunPaletteCommand        ; home/palettes.asm — In: BH = palette command
extern RunDefaultPaletteCommand ; engine/menus/naming_screen.asm
extern WaitForTextScrollButtonPress ; engine/battle/battle_menu.asm
extern CopyData                 ; home/copy_data.asm — ESI=src, DX=dest, BX=count
extern GetMonHeader             ; home/pokemon.asm
extern LoadFrontSpriteByMonIndex ; home/pics.asm
extern PlaceString              ; home/text.asm — EAX=flat src, ESI=dest
extern PrintNumber              ; home/print_num.asm — EDX=src addr, BH=flags|bytes, BL=digits, ESI=dest
extern LoadHallOfFameTeams      ; engine/menus/save.asm
extern Func_7033f               ; league_pc_stubs.asm SEAM (engine/movie/hall_of_fame.asm)

%ifdef DEBUG_LEAGUEPC
extern LoadFontTilePatterns     ; home/load_font.asm
global RunLeaguePCTest
%endif

; ===========================================================================
; Tier-1 DATA: HallOfFameNoText + the AccessedHoFPCText stream body.
%include "assets/league_pc_text.inc"

; ===========================================================================
section .text

; ---------------------------------------------------------------------------
; PKMNLeaguePC — pret ref: engine/menus/league_pc.asm:PKMNLeaguePC.
; In: EBP = GB base.
; ---------------------------------------------------------------------------
PKMNLeaguePC:
    mov dword [text_msgbox], msgbox_dialog  ; port: publish the box projection
    mov esi, AccessedHoFPCText              ; ld hl, AccessedHoFPCText
    call PrintText
    ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY,[hl] (+ pret's push hl of the
    ; pointer — the port addresses W_STATUS_FLAGS_5 directly, so no pointer save).
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY
    movzx eax, byte [ebp + W_UPDATE_SPRITES_ENABLED]  ; push af
    push eax
    movzx eax, byte [ebp + H_TILE_ANIMATIONS]         ; push af
    push eax
    xor al, al
    mov [ebp + H_TILE_ANIMATIONS], al       ; ldh [hTileAnimations],a
    mov [ebp + wSpriteFlipped], al
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    mov [ebp + wHoFTeamIndex2], al
    mov [ebp + wHoFTeamNo], al
    mov al, [ebp + wNumHoFTeams]
    mov bh, al                              ; ld b,a
    cmp al, HOF_TEAM_CAPACITY + 1
    jc .loop                                ; jr c
    ; teams > capacity: the first team still recorded is teams - capacity
    mov bh, HOF_TEAM_CAPACITY               ; ld b,HOF_TEAM_CAPACITY
    sub al, bh                              ; sub b
    mov [ebp + wHoFTeamNo], al
.loop:
    inc byte [ebp + wHoFTeamNo]             ; ld hl,wHoFTeamNo / inc [hl]
    push ebx                                ; push bc
    mov al, [ebp + wHoFTeamIndex2]
    mov [ebp + wHoFTeamIndex], al
    call LoadHallOfFameTeams                ; farcall LoadHallOfFameTeams
    call LeaguePCShowTeam
    pop ebx                                 ; pop bc
    jc .doneShowingTeams                    ; jr c
    inc byte [ebp + wHoFTeamIndex2]         ; ld hl,wHoFTeamIndex2 / inc [hl]
    mov al, [ebp + wHoFTeamIndex2]          ; ld a,[hl]
    cmp al, bh                              ; cp b
    jnz .loop                               ; jr nz
.doneShowingTeams:
    pop eax                                 ; pop af (hTileAnimations)
    mov [ebp + H_TILE_ANIMATIONS], al
    pop eax                                 ; pop af (wUpdateSpritesEnabled)
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    ; pop hl / res BIT_NO_TEXT_DELAY,[hl]
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    call hide_window                        ; DEVIATION(window-compositor): ClearScreen
                                            ; wipes wTileMap, not the window LIST.
    call RunDefaultPaletteCommand
    jmp GBPalNormal                         ; jp GBPalNormal

; ---------------------------------------------------------------------------
; LeaguePCShowTeam — pret ref: engine/menus/league_pc.asm:LeaguePCShowTeam.
; Shows each of a team's PARTY_LENGTH mons (shifting the team buffer down one mon
; per screen). Out: CF set if the player pressed B (stop), clear if the team ended.
; ---------------------------------------------------------------------------
LeaguePCShowTeam:
    mov bl, PARTY_LENGTH                    ; ld c,PARTY_LENGTH
.loop:
    push ebx                                ; push bc
    call LeaguePCShowMon
    call WaitForTextScrollButtonPress
    test byte [ebp + H_JOY_HELD], PAD_B     ; ldh a,[hJoyHeld] / bit B_PAD_B,a
    jnz .exit                               ; jr nz
    ; shift the remaining mons down one slot (HOF_MON bytes)
    mov esi, wHallOfFame + HOF_MON          ; ld hl,wHallOfFame+HOF_MON
    mov dx, wHallOfFame                     ; ld de,wHallOfFame
    mov bx, HOF_TEAM - HOF_MON              ; ld bc,HOF_TEAM-HOF_MON (count; clobbers c)
    call CopyData
    pop ebx                                 ; pop bc (restore the loop counter)
    mov al, [ebp + wHallOfFame + 0]         ; ld a,[wHallOfFame]
    cmp al, 0xFF                            ; cp $ff — end of team?
    jz .done
    dec bl                                  ; dec c
    jnz .loop
.done:
    clc                                     ; and a (CF=0 -> team ended normally)
    ret
.exit:
    pop ebx                                 ; pop bc
    stc                                     ; scf (CF=1 -> player pressed B)
    ret

; ---------------------------------------------------------------------------
; LeaguePCShowMon — pret ref: engine/menus/league_pc.asm:LeaguePCShowMon.
; Full-screen display of the first mon in wHallOfFame: front pic + "HALL OF FAME
; No" box, then Func_7033f (mon-info box + cry — still a SEAM stub).
; DEVIATION(canvas): the layout is built in the stride-20 scratch and no window is
; published, so this screen is UNVERIFIED (see the header).
; ---------------------------------------------------------------------------
LeaguePCShowMon:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    mov esi, wHallOfFame                    ; ld hl,wHallOfFame
    mov al, [ebp + esi]                     ; ld a,[hli] — species
    inc esi
    mov [ebp + wHoFMonSpecies], al
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    mov [ebp + wBattleMonSpecies2], al
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    mov al, [ebp + esi]                     ; ld a,[hli] — level
    inc esi
    mov [ebp + wHoFMonLevel], al
    mov dx, wNameBuffer                     ; ld de,wNameBuffer
    mov bx, NAME_LENGTH                     ; ld bc,NAME_LENGTH
    call CopyData                           ; copy the nickname -> wNameBuffer
    mov bh, SET_PAL_POKEMON_WHOLE_SCREEN    ; ld b,SET_PAL_POKEMON_WHOLE_SCREEN
    mov bl, 0                               ; ld c,0
    call RunPaletteCommand
    mov esi, W_TILEMAP + 5 * 20 + 12        ; hlcoord 12,5
    call GetMonHeader
    call LoadFrontSpriteByMonIndex
    call GBPalNormal
    mov esi, W_TILEMAP + 13 * 20 + 0        ; hlcoord 0,13
    mov bh, 2                               ; lb bc,2,18
    mov bl, 18
    call TextBoxBorder
    mov esi, W_TILEMAP + 15 * 20 + 1        ; hlcoord 1,15
    mov eax, HallOfFameNoText               ; ld de,HallOfFameNoText
    call PlaceString
    mov esi, W_TILEMAP + 15 * 20 + 16       ; hlcoord 16,15
    mov edx, wHoFTeamNo                     ; ld de,wHoFTeamNo
    mov bh, 1                               ; lb bc,1,3 -> 1 byte
    mov bl, 3                               ; 3 digits
    call PrintNumber
    jmp Func_7033f                          ; farjp Func_7033f

; --- the LEAGUE PC's one dialog (pret ref: engine/menus/league_pc.asm, same
; position). Tier-2 wrapper over the Tier-1 stream in assets/league_pc_text.inc.
AccessedHoFPCText:
    text_far _AccessedHoFPCText
    text_end

%ifdef DEBUG_LEAGUEPC
; ---------------------------------------------------------------------------
; RunLeaguePCTest — FRAME.BIN gate for the LEAGUE PC (menu-fidelity row 17 part 4).
; No golden covers this screen. PKMNLeaguePC PrintTexts AccessedHoFPCText and blocks
; in the stream's page-break prompt; the harness runs with AUTOKEY_QUIET (no
; presses), so AutoKeyDrive photographs the open dialog at AUTOKEY_DUMP_FRAME and
; exits — the RunPCTest pattern. (The old harness dumped from a DumpBackbuffer hook
; after hand-drawing the first page itself, which tested the harness, not the code.)
; The Hall-of-Fame team loop past the dialog needs a save with a recorded HoF and
; the HoF movie routine (Func_7033f, still a stub); it is not exercised here.
; In: EBP = GB base. Called from EnterMap after the overworld is set up.
; ---------------------------------------------------------------------------
RunLeaguePCTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call PKMNLeaguePC
.hang:
    jmp .hang
%endif
