; ===========================================================================
; league_pc.asm — POKéMON LEAGUE PC (Hall-of-Fame reader). menus-port Session 6,
; package A. Faithful port of pret engine/menus/league_pc.asm:
;   PKMNLeaguePC / LeaguePCShowTeam / LeaguePCShowMon.
;
; Port model (window compositor, see docs/translation_log.md "menus-port S2-S5"):
; - DEVIATION(text): AccessedHoFPCText is drawn WHOLE (the S4/S5 dialog DEVIATION,
;   pret wording from data/text/text_3.asm _AccessedHoFPCText) into the stride-20
;   scratch + UI_MESSAGE_BOX window; its terminal `prompt` becomes the ▼ + A/B
;   wait (lp_prompt).
; - STUB(S7-save): LoadHallOfFameTeams reads HoF SRAM — the save layer is S7. Until
;   it lands wNumHoFTeams reads 0, so the team loop is GUARDED OFF (a 0-team
;   early-out to .doneShowingTeams). The full loop + LeaguePCShowTeam/
;   LeaguePCShowMon are ported for label parity and become reachable once teams
;   exist. See the STUB tag at the guard.
;   Verified pret semantics of the 0-team case: pret does NOT guard here (it
;   relies on the caller only invoking PKMNLeaguePC when a HoF exists); entering
;   .loop with 0 teams would display a garbage mon. The port's guard makes the
;   0-team path show only AccessedHoFPCText and exit clean, which is the intended
;   user-visible "no teams" behavior.
; - hTileAnimations push/pop and BIT_NO_TEXT_DELAY set/res are LIVE state (kept
;   verbatim, same dance as S5 DisplayPartyMenu).
; - TODO-HW: RunPaletteCommand / RunDefaultPaletteCommand are palette-HAL (Phase 5);
;   no-op here (RunPaletteCommand is already a HAL stub in faint_switch.asm; the
;   whole-screen-mon palette command is a comment-only no-op).
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

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"


global PKMNLeaguePC
global LeaguePCShowTeam
global LeaguePCShowMon

; --- reachable (dialog + exit tail) -----------------------------------------
extern TextBoxBorder            ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern place_flat_str           ; text/text.asm — EAX=flat src, ESI=dest
extern add_window               ; ppu/ppu.asm
extern g_window_count           ; ppu/ppu.asm
extern DelayFrame               ; video/frame.asm
extern GBPalWhiteOutWithDelay3  ; home/fade.asm
extern ClearScreen              ; movie/title.asm
extern GBPalNormal              ; init/init.asm
; --- reachable only inside the S7-gated team loop (globals; link fine) -------
extern WaitForTextScrollButtonPress ; engine/battle/battle_menu.asm
extern CopyData                 ; home/copy_data.asm — ESI=src, DX=dest, BX=count
extern GetMonHeader             ; home/pokemon.asm
extern LoadFrontSpriteByMonIndex ; gfx/pics.asm
extern PlaceString              ; text/text.asm — EAX=flat src, ESI=dest
extern PrintNumber              ; home/print_num.asm — EDX=src addr, BH=flags|bytes, BL=digits, ESI=dest
; --- S7 save-layer / movie (not yet present; unreachable at 0 teams) ---------
extern LoadHallOfFameTeams      ; engine/menus/save.asm (S7)
extern Func_7033f               ; engine/movie/hall_of_fame.asm (HoF mon-info + cry)

%ifdef DEBUG_LEAGUEPC
extern DumpBackbuffer           ; debug/debug_dump.asm — writes FRAME.BIN + exits
extern LoadFontTilePatterns     ; gfx/load_font.asm
global RunLeaguePCTest
%endif

; charmap glyphs (see constants/charmap.asm)
LP_TERM   equ 0x50              ; '@'
LP_DOWN   equ 0xEE             ; ▼
LP_SPC    equ 0x7F             ; blank tile

section .data
align 4
; _AccessedHoFPCText (pret data/text/text_3.asm), page 1 + page 2 (`para`).
; page 1: "Accessed #MON" / "LEAGUE's site."   (# = POKé)
lp_acc_l1: db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D, LP_TERM
lp_acc_l2: db 0x8B,0x84,0x80,0x86,0x94,0x84,0xBD,0x7F,0xB2,0xA8,0xB3,0xA4,0xE8, LP_TERM
; page 2: "Accessed the HALL" / "OF FAME List."
lp_acc2_l1: db 0x80,0xA2,0xA2,0xA4,0xB2,0xB2,0xA4,0xA3,0x7F,0xB3,0xA7,0xA4,0x7F,0x87,0x80,0x8B,0x8B, LP_TERM
lp_acc2_l2: db 0x8E,0x85,0x7F,0x85,0x80,0x8C,0x84,0x7F,0x8B,0xA8,0xB2,0xB3,0xE8, LP_TERM

; HallOfFameNoText — "HALL OF FAME No   @" (pret db string; No + 3 padded digits).
HallOfFameNoText: db 0x87,0x80,0x8B,0x8B,0x7F,0x8E,0x85,0x7F,0x85,0x80,0x8C,0x84,0x7F,0x8D,0xAE,0x7F,0x7F,0x7F, LP_TERM

section .bss
align 4
lp_msg_wc:  resd 1              ; g_window_count before the dialog window

section .text

; ---------------------------------------------------------------------------
; PKMNLeaguePC — pret ref: engine/menus/league_pc.asm:PKMNLeaguePC.
; ---------------------------------------------------------------------------
PKMNLeaguePC:
    ; ld hl, AccessedHoFPCText / call PrintText — DEVIATION(text): drawn whole.
    mov eax, lp_acc_l1
    mov edx, lp_acc_l2
    call lp_draw_msg
    call lp_prompt
    mov eax, lp_acc2_l1
    mov edx, lp_acc2_l2
    call lp_draw_msg
    call lp_prompt

    ; ld hl, wStatusFlags5 / set BIT_NO_TEXT_DELAY,[hl] (+ pret's push hl of the
    ; pointer — the port addresses W_STATUS_FLAGS_5 directly, so no pointer save).
    or byte [ebp + W_STATUS_FLAGS_5], 1 << BIT_NO_TEXT_DELAY
    ; push af (wUpdateSpritesEnabled) / push af (hTileAnimations)
    movzx eax, byte [ebp + W_UPDATE_SPRITES_ENABLED]
    push eax
    movzx eax, byte [ebp + H_TILE_ANIMATIONS]
    push eax
    xor al, al
    mov [ebp + H_TILE_ANIMATIONS], al   ; ldh [hTileAnimations],a
    mov [ebp + wSpriteFlipped], al
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    mov [ebp + wHoFTeamIndex2], al
    mov [ebp + wHoFTeamNo], al
    mov al, [ebp + wNumHoFTeams]
    mov bh, al                          ; ld b,a
    ; STUB(S7-save)/DEVIATION: no save layer -> wNumHoFTeams reads 0; the HoF team
    ; loop below is dead until S7 (see header). pret always enters .loop; the port
    ; guards the 0-team case to a clean exit (no garbage-mon display).
    test bh, bh
    jz .doneShowingTeams
    cmp al, HOF_TEAM_CAPACITY + 1
    jc .loop                            ; jr c
    ; total teams > capacity: first recorded team = teams - capacity
    mov bh, HOF_TEAM_CAPACITY           ; ld b,HOF_TEAM_CAPACITY
    sub al, bh                          ; sub b
    mov [ebp + wHoFTeamNo], al
.loop:
    inc byte [ebp + wHoFTeamNo]         ; ld hl,wHoFTeamNo / inc [hl]
    push ebx                            ; push bc
    mov al, [ebp + wHoFTeamIndex2]
    mov [ebp + wHoFTeamIndex], al
    call LoadHallOfFameTeams            ; farcall (S7 save layer)
    call LeaguePCShowTeam
    pop ebx                             ; pop bc
    jc .doneShowingTeams               ; jr c
    inc byte [ebp + wHoFTeamIndex2]     ; ld hl,wHoFTeamIndex2 / inc [hl]
    mov al, [ebp + wHoFTeamIndex2]      ; ld a,[hl]
    cmp al, bh                          ; cp b
    jnz .loop                          ; jr nz
.doneShowingTeams:
    pop eax                             ; pop af (hTileAnimations)
    mov [ebp + H_TILE_ANIMATIONS], al
    pop eax                             ; pop af (wUpdateSpritesEnabled)
    mov [ebp + W_UPDATE_SPRITES_ENABLED], al
    ; pop hl / res BIT_NO_TEXT_DELAY,[hl]
    and byte [ebp + W_STATUS_FLAGS_5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    call lp_msg_drop                    ; port: drop the AccessedHoFPCText window
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    ; call RunDefaultPaletteCommand — TODO-HW: default palette set (Phase 5), no-op
    jmp GBPalNormal                     ; jp GBPalNormal

; ---------------------------------------------------------------------------
; LeaguePCShowTeam — pret ref: engine/menus/league_pc.asm:LeaguePCShowTeam.
; Shows each of a team's PARTY_LENGTH mons (shifting the team buffer down one mon
; per screen). Out: CF set if the player pressed B (stop), clear if the team ended.
; NOTE: reachable only once the S7 save layer feeds LoadHallOfFameTeams.
; ---------------------------------------------------------------------------
LeaguePCShowTeam:
    mov bl, PARTY_LENGTH                ; ld c,PARTY_LENGTH
.loop:
    push ebx                            ; push bc
    call LeaguePCShowMon
    call WaitForTextScrollButtonPress
    test byte [ebp + H_JOY_HELD], PAD_B ; ldh a,[hJoyHeld] / bit B_PAD_B,a
    jnz .exit                          ; jr nz
    ; shift the remaining mons down one slot (HOF_MON bytes)
    mov esi, wHallOfFame + HOF_MON      ; ld hl,wHallOfFame+HOF_MON
    mov dx, wHallOfFame                 ; ld de,wHallOfFame
    mov bx, HOF_TEAM - HOF_MON          ; ld bc,HOF_TEAM-HOF_MON (count; clobbers c)
    call CopyData
    pop ebx                            ; pop bc (restore the loop counter)
    mov al, [ebp + wHallOfFame + 0]     ; ld a,[wHallOfFame]
    cmp al, 0xFF                        ; cp $ff — end of team?
    jz .done
    dec bl                             ; dec c
    jnz .loop
.done:
    clc                                 ; and a (CF=0 -> team ended normally)
    ret
.exit:
    pop ebx                            ; pop bc
    stc                                 ; scf (CF=1 -> player pressed B)
    ret

; ---------------------------------------------------------------------------
; LeaguePCShowMon — pret ref: engine/menus/league_pc.asm:LeaguePCShowMon.
; Full-screen display of the first mon in wHallOfFame: front pic + "HALL OF FAME
; No" box, then Func_7033f (mon-info box + cry).
; NOTE: reachable only once the S7 save layer / movie HoF routines are present;
; the coord math uses the stride-20 scratch (hlcoord X,Y = W_TILEMAP+Y*20+X),
; UNVERIFIED for this full-screen layout until S7 wires + gates it.
; ---------------------------------------------------------------------------
LeaguePCShowMon:
    call GBPalWhiteOutWithDelay3
    call ClearScreen
    mov esi, wHallOfFame                ; ld hl,wHallOfFame
    mov al, [ebp + esi]                 ; ld a,[hli] — species
    inc esi
    mov [ebp + wHoFMonSpecies], al
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    mov [ebp + wBattleMonSpecies2], al
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    mov al, [ebp + esi]                 ; ld a,[hli] — level
    inc esi
    mov [ebp + wHoFMonLevel], al
    mov dx, wNameBuffer                 ; ld de,wNameBuffer
    mov bx, NAME_LENGTH                 ; ld bc,NAME_LENGTH
    call CopyData                       ; copy the nickname -> wNameBuffer
    ; ld b,SET_PAL_POKEMON_WHOLE_SCREEN / ld c,0 / call RunPaletteCommand —
    ; TODO-HW: whole-screen mon palette (Phase 5), no-op.
    mov esi, W_TILEMAP + 5 * 20 + 12    ; hlcoord 12,5
    call GetMonHeader
    call LoadFrontSpriteByMonIndex
    call GBPalNormal
    mov esi, W_TILEMAP + 13 * 20 + 0    ; hlcoord 0,13
    mov bh, 2                           ; lb bc,2,18
    mov bl, 18
    call TextBoxBorder
    mov esi, W_TILEMAP + 15 * 20 + 1    ; hlcoord 1,15
    mov eax, HallOfFameNoText           ; ld de,HallOfFameNoText
    call PlaceString
    mov esi, W_TILEMAP + 15 * 20 + 16   ; hlcoord 16,15
    mov edx, wHoFTeamNo                 ; ld de,wHoFTeamNo
    mov bh, 1                           ; lb bc,1,3 -> 1 byte
    mov bl, 3                           ; 3 digits
    call PrintNumber
    jmp Func_7033f                      ; farjp Func_7033f

; ===========================================================================
; Dialog plumbing (port; DEVIATION(text), mirrors oaks_pc.asm oak_* helpers).
; ; PROJ menus: GB(0,12) 20x6 --(anchor=center/bottom)--> wx=87 wy=152 clip=160
;   max_y=200 [UI_MESSAGE_BOX_*]
; ---------------------------------------------------------------------------
; In: EAX = line-1 flat str ptr, EDX = line-2 flat str ptr.
lp_draw_msg:
    push eax
    push edx
    mov esi, W_TILEMAP + 12 * 20        ; border into scratch rows 12-17
    mov bl, 18
    mov bh, 4
    call TextBoxBorder
    pop edx
    pop eax
    push edx
    mov esi, W_TILEMAP + 14 * 20 + 1
    call place_flat_str
    pop eax
    mov esi, W_TILEMAP + 16 * 20 + 1
    call place_flat_str
    ; fall through to lp_msg_show

lp_msg_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + 12 * 20]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, LP_SPC
    mov ecx, 12                         ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [g_window_count]
    mov [lp_msg_wc], eax
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

lp_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], LP_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], LP_SPC
    ret

lp_msg_drop:
    push eax
    mov eax, [lp_msg_wc]
    mov [g_window_count], eax
    pop eax
    ret

%ifdef DEBUG_LEAGUEPC
; ---------------------------------------------------------------------------
; RunLeaguePCTest — package-A FRAME.BIN gate. Loads the font, opens PKMNLeaguePC
; over the (already loaded) overworld. With no save layer wNumHoFTeams==0, so the
; team loop is skipped and the AccessedHoFPCText dialog shows; the DEBUG hook
; dumps FRAME.BIN before the first blocking ▼-wait. Never returns.
; In: EBP = GB base. Call from EnterMap after the overworld is set up.
; ---------------------------------------------------------------------------
RunLeaguePCTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    mov byte [ebp + wNumHoFTeams], 0    ; no save layer -> 0 teams (explicit)
    ; draw the first AccessedHoFPCText page, then dump before the blocking wait
    mov eax, lp_acc_l1
    mov edx, lp_acc_l2
    call lp_draw_msg
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                 ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif
