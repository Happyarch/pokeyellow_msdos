; ===========================================================================
; save.asm — the SAVE / LOAD / CHANGE-BOX / Hall-of-Fame save layer.
; menus-port Session 7, package H. Faithful port of pret engine/menus/save.asm.
;
; This turns the START->SAVE stub (menus S4) and the .dsv layer real, and
; provides the LOAD side package E depends on (TryLoadSaveFile).
;
; PORT MODEL (CLAUDE.md + translation_log "menus-port S2-S6"):
;  * SM83->x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * NO SRAM HARDWARE. The GB save is a battery-backed SRAM image; pret drives it
;    through the MBC banking regs (rRAMG/rBMODE/rRAMB) and reads/writes s* SRAM
;    labels. The DOS port has none of that: EVERY SRAM byte copy collapses onto
;    the src/save/dsv_io.asm HAL —
;       DsvWriteSave — serialize the save WRAM payload -> POKEMON.DSV + header +
;                      16-bit file checksum (dsv OWNS the payload/header/checksum).
;       DsvReadSave  — load POKEMON.DSV back into that WRAM. CF=1 if absent / bad
;                      magic / bad checksum -> maps onto pret's CheckSumFailed path.
;       DsvFileExists— CF=1/AL=1 if a valid "DOSV" file is present.
;    Every such site is tagged ; TODO-HW: SRAM. EnableSRAM/DisableSRAM become
;    flag-preserving no-ops (kept for label parity + control flow).
;  * The payload dsv_io serializes is EXACTLY pret's SaveMainData /
;    SaveCurrentBoxData / SavePartyAndDexData set: wPlayerName + wMainDataStart..End
;    (which already covers wPokedexOwned..wPokedexSeenEnd AND wPikachuHappiness,
;    both inside 0xD2F6..0xDA7F) + wSpriteDataStart..End + wBoxDataStart..End +
;    wPartyDataStart..End. So the pokédex + pikachu-happiness tail pret copies
;    separately need no special handling here — they ride in the main-data block.
;  * TEXT (row 19 part 1, M-97): the SAVE/LOAD messages are pret's own text_far
;    streams (Tier-1 data in assets/save_text.inc, generated from data/text/
;    text_4.asm) printed by PrintText through the msgbox_dialog projection — the
;    `line`/`cont` breaks, the terminal `prompt` and _GameSavedText's TX_RAM
;    player-name splice are executed by the text engine. Until row 19 this file
;    hand-encoded every LINE as a charmap `db` run and drew them whole with bespoke
;    SV_* routines, claiming "the port's dialog projection collapses the window list
;    to the dialog alone" — false: PrintText is what pc.asm/players_pc.asm/
;    oaks_pc.asm/league_pc.asm all use, and the drawn-whole imitation is what those
;    rows deleted.
;  * The "Would you like to SAVE?" yes/no is pret's own TWO_OPTION_MENU box:
;    wTextBoxID = TWO_OPTION_MENU + DisplayTextBoxID, at pret's own hlcoord 0,7 /
;    lb bc,8,1 (the learn_move.asm precedent). wCurrentMenuItem holds the result
;    (0=Yes,1=No). The former InitYesNoTextBoxParameters/DisplayYesNoChoice
;    substitution moved the box to the standard top-right YES/NO anchor — a
;    geometry change pret does not make (M-98).
;  * SFX_SAVE / PlaySoundWaitForCurrent / WaitForSoundToFinish are REAL in the port
;    (src/home/audio.asm + assets/audio_constants.inc; pc.asm plays its PC jingles
;    through them). The "TODO-HW: audio HAL (Phase 3), no-op" comments that used to
;    sit here were stale (M-99); the save jingle is restored.
;  * CHANGE-BOX TEXT (row 19 part 2, M-101): WhenYouChangeBoxText / ChooseABoxText /
;    BoxNames / BoxNoText are pret's own labels with pret's own bodies (Tier-1 data
;    in assets/save_text.inc). _WhenYouChangeBoxText's `para` page break is executed
;    by the text engine — the port used to hand-drive the two pages, hand-encode
;    every line, split BoxNames into 12 separately-terminated strings (which is what
;    forced its per-row placement loop), and never draw the box number at all.
;  * CHANGE-BOX box swap: the port has WRAM for only the CURRENT box
;    (wBoxDataStart..End); the other 11 boxes live in SRAM banks pret has and the
;    port does not. So CopyBoxToOrFromSRAM / the per-bank mon-count reads / the
;    empty-box init all collapse to ; TODO-HW: SRAM no-ops that PRESERVE the live
;    current box (they must not erase it). Net stopgap: the ChangeBox UI + flow +
;    SaveGameData all run, but the box contents do not actually swap and the other
;    boxes read empty — exactly the wNumHoFTeams==0 kind of degraded-but-safe
;    behavior, retired when a box-storage WRAM region / faithful .dsv lands.
;  * TWO THINGS THE .dsv PAYLOAD CANNOT CARRY (row 19 part 3), both filed against
;    src/save/dsv_io.asm and both stated honestly at their sites rather than waved
;    through as "SRAM parity":
;      - hTileAnimations (M-106): HRAM, not in the WRAM payload, so pret's
;        save+restore of it through sTileAnimations is dropped on BOTH sides. The
;        flag is LIVE in the port, so the setting does not survive a save/load.
;      - the saved player ID (M-107): unreachable without DsvReadSave clobbering the
;        live game, so CheckPreviousSaveFile always answers "same playthrough" and a
;        NEW GAME saved over an existing file overwrites it with no confirmation.
;    The HoF routines, ClearAllSRAMBanks and the box-swap copies are also SRAM no-ops,
;    but those are DEAD in the port (their callers — the HoF movie, clear_save.asm —
;    are unported), so they cost nothing today.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/save.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"                  ; text_far / text_end
%include "assets/audio_constants.inc"   ; SFX_SAVE

%define UI_LAYOUT_EQUATES_ONLY 1
%include "assets/ui_layout_menus.inc"

; --- SAVE / LOAD -----------------------------------------------------------
global TryLoadSaveFile
global LoadMainData
global LoadCurrentBoxData
global LoadPartyAndDexData
global CheckSumFailed
global GoodCheckSum
global SaveMenu
global SaveTheGame_YesOrNo
global SaveMainData
global SaveCurrentBoxData
global SavePartyAndDexData
global SaveGameData
global CalcCheckSum
global CalcIndividualBoxCheckSums
global GetBoxSRAMLocation
global CheckPreviousSaveFile
; --- SAVE/LOAD message streams (pret labels; bodies in assets/save_text.inc) ---
global FileDataDestroyedText
global WouldYouLikeToSaveText
global SavingText
global GameSavedText
global OlderFileWillBeErasedText
; --- CHANGE BOX ------------------------------------------------------------
global ChangeBox
global CopyBoxToOrFromSRAM
global DisplayChangeBoxMenu
; --- CHANGE-BOX strings (pret labels; bodies in assets/save_text.inc) ---------
global WhenYouChangeBoxText
global ChooseABoxText
global BoxNames
global BoxNoText
global EmptyAllSRAMBoxes
global EmptySRAMBoxesInBank
global EmptySRAMBox
global GetMonCountsForAllBoxes
global GetMonCountsForBoxesInBank
; --- HALL OF FAME ----------------------------------------------------------
global TryLoadSaveFileIgnoreChecksum
global SaveHallOfFameTeams
global LoadHallOfFameTeams
global HallOfFame_Copy
global ClearAllSRAMBanks
global EnableSRAM
global DisableSRAM

; --- window compositor / text (see players_pc.asm precedent) ---------------
extern TextBoxBorder            ; home/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern PlaceString              ; home/text.asm — EAX=flat src, ESI=dest (pret de/hl)
extern add_window               ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tm EDI=row
extern g_window_count           ; ppu/ppu.asm
extern text_row_stride          ; text/text.asm — active W_TILEMAP row stride
extern menu_item_step           ; home/window.asm — per-item cursor row step
extern menu_redraw_cb           ; home/window.asm — per-frame redraw cb (0=none)
extern HandleMenuInput          ; home/window.asm — Out: AL = watched keys pressed
extern DelayFrame               ; video/frame.asm
extern DelayFrames              ; video/frame.asm — BL = frame count (pret's ld c,n)
extern PrintText                ; home/window.asm — In: ESI = text stream
extern text_msgbox              ; home/text.asm — the active msgbox projection
extern msgbox_dialog            ; home/text.asm — the standard bottom dialog box
extern DisplayTextBoxID         ; home/textbox.asm — [wTextBoxID] box (TWO_OPTION_MENU)
extern PlaySoundWaitForCurrent  ; home/audio.asm — In: AL = sound id
extern WaitForSoundToFinish     ; home/audio.asm
; --- generic engine seams ---------------------------------------------------
; (pret's CopyData / AddNTimes SRAM copies collapse to no-ops here — see the
;  TODO-HW: SRAM sites — so neither is externed.)
extern UpdateSprites            ; engine/overworld/movement.asm
extern SetMapTextPointer        ; home/predef_text.asm
extern RestoreMapTextPointer    ; home/predef_text.asm
extern ClearScreen              ; movie/title.asm
extern LoadFontTilePatterns     ; gfx/load_font.asm
extern LoadTextBoxTilePatterns  ; gfx/load_font.asm
; --- the S3 YES/NO driver (home/yes_no.asm) --------------------------------
extern YesNoChoice              ; home/yes_no.asm — ChangeBox's confirm
extern yn_box_col               ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row               ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode             ; home/yes_no.asm — 0 = overworld anchor
; --- the .dsv HAL (src/save/dsv_io.asm) ------------------------------------
extern DsvWriteSave             ; CF=0 ok / CF=1 fail
extern DsvReadSave              ; CF=0 ok / CF=1 absent/bad
extern DsvFileExists            ; CF=1/AL=1 present

; --- package E (main_menu.asm) ---------------------------------------------
; PrintSaveScreenText draws the SAVE info screen (player name / badges / #dex /
; play time). Lives in main_menu.asm (package E). Referenced by SaveMenu; report
; the extern so root wires main_menu.asm into the link set alongside this file.
extern PrintSaveScreenText

%ifdef DEBUG_SAVE
%define SAVE_HARNESS 1
%endif
%ifdef DEBUG_SAVE_ROUNDTRIP
%define SAVE_HARNESS 1
%endif
%ifdef DEBUG_CHANGEBOX
%define SAVE_HARNESS 1
%endif
%ifdef SAVE_HARNESS
extern PrepareNewGameDebug      ; engine/debug/debug_party.asm
extern DumpBackbuffer           ; debug/debug_dump.asm — writes FRAME.BIN + exits
global RunSaveTest
%endif

; ---------------------------------------------------------------------------
; charmap glyphs (constants/charmap.asm). NOT GB-memory symbols.
CHAR_TERM  equ 0x50             ; '@'
CHAR_DOWN  equ 0xEE             ; ▼
TILE_SPC   equ 0x7F             ; blank tile
TILE_BALL  equ 0x78             ; pokéball indicator tile

; drawn-whole message box: scratch rows 12-17 (stride 20) -> GB_TILEMAP1 rows 0-5
MSG_SROW   equ 12
MSG_STRIDE equ 20

; ChangeBox list box (box-relative into the stride-20 scratch, mirrored to
; GB_TILEMAP0). pret: hlcoord 11,0 / lb bc,12,7 -> interior 7w x 12h (total 9x14),
; matching UI_CHANGE_BOX GB(11,0) 9x14.
CBOX_INT_W equ 7
CBOX_INT_H equ 12
CBOX_TOT_W equ CBOX_INT_W + 2   ; 9
CBOX_TOT_H equ CBOX_INT_H + 2   ; 14
CBOX_STRIDE equ 20
CBOX_SROW  equ 0                 ; GB_TILEMAP0 mirror start row

; ChangeBox "BOX No." indicator box. pret: hlcoord 0,0 / lb bc,2,9 -> interior
; 9w x 2h (total 11x4) = UI_CHANGE_BOX_INFO GB(0,0) 11x4. Staged into its own
; scratch band (below the list box) and mirrored to its own GB_TILEMAP0 rows, so
; the two windows of this screen do not share a mirror region.
CBOXI_INT_W equ 9
CBOXI_INT_H equ 2
CBOXI_TOT_W equ CBOXI_INT_W + 2  ; 11
CBOXI_TOT_H equ CBOXI_INT_H + 2  ; 4
; Scratch band: rows 0..13 are the list box and rows 12..17 are the DIALOG the
; ChooseABoxText PrintText draws (msgbox_dialog's MB_BOX_OFS/MB_LINE2 land there),
; so the info box must start at 18 — at 16 it overlapped the dialog and mirrored
; the dialog's second text line into the info window (observed in FRAME.BIN).
CBOXI_SROW  equ 18               ; scratch band start row (list 0..13, dialog 12..17)
CBOXI_MROW  equ 16               ; GB_TILEMAP0 mirror start row

; charmap digits (constants/charmap.asm: "0" = $F6 .. "9" = $FF)
CHAR_0     equ 0xF6
CHAR_1     equ 0xF7

; wChangeBoxSavedMapTextPointer (pret ram/wram.asm:998, union alias @ 0xCD3D).
; NEEDED in gb_memmap.inc — reported to root; local fallback until then.
%ifndef wChangeBoxSavedMapTextPointer
wChangeBoxSavedMapTextPointer equ 0xCD3D
%endif

; ===========================================================================
section .data
align 4
; Tier-1 DATA: the five SAVE/LOAD text_far streams (row 19 part 1, M-97) AND the
; four CHANGE-BOX strings — WhenYouChangeBoxText / ChooseABoxText / BoxNames /
; BoxNoText (row 19 part 2, M-101). Nothing in this file is hand-encoded.
%include "assets/save_text.inc"

; ===========================================================================
section .bss
align 4
sv_msg_wc:   resd 1             ; g_window_count before the current message window
cbox_wc:     resd 1             ; g_window_count before the change-box list window

; ===========================================================================
section .text

; ###########################################################################
; # LOAD SIDE (package E depends on TryLoadSaveFile)
; ###########################################################################

; ---------------------------------------------------------------------------
; TryLoadSaveFile — pret ref: engine/menus/save.asm:TryLoadSaveFile.
; Loads the save into WRAM, sets wSaveFileStatus (2 good / 1 bad). CF from each
; Load* branches to .badsum exactly as pret's `jr c,.badsum`.
; ---------------------------------------------------------------------------
TryLoadSaveFile:
    call ClearScreen
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call LoadMainData
    jc .badsum
    call LoadCurrentBoxData
    jc .badsum
    call LoadPartyAndDexData
    jc .badsum
    mov al, 2                                    ; good checksum
    jmp .done
.badsum:
    ; ld hl,wStatusFlags5 / set BIT_NO_TEXT_DELAY,[hl]
    or byte [ebp + wStatusFlags5], 1 << BIT_NO_TEXT_DELAY
    mov dword [text_msgbox], msgbox_dialog       ; port: publish the box projection
    mov esi, FileDataDestroyedText               ; ld hl, FileDataDestroyedText
    call PrintText                               ; stream ends in `prompt`
    mov bl, 100                                  ; ld c, 100
    call DelayFrames
    ; res BIT_NO_TEXT_DELAY,[hl]
    and byte [ebp + wStatusFlags5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    mov al, 1                                    ; bad checksum
.done:
    mov [ebp + wSaveFileStatus], al
    ret

; pret ref: engine/menus/save.asm:FileDataDestroyedText — Tier-2 wrapper over the
; Tier-1 stream in assets/save_text.inc.
FileDataDestroyedText:
    text_far _FileDataDestroyedText
    text_end

; ---------------------------------------------------------------------------
; LoadMainData — pret ref: engine/menus/save.asm:LoadMainData.
; pret verifies sMainDataCheckSum (twice) then CopyData's sPlayerName/sMainData/
; sSpriteData/sCurBoxData -> WRAM. dsv_io.asm loads the whole payload atomically
; and owns the file-level checksum, so the SRAM verify + all the CopyData slices
; collapse into one DsvReadSave. CF=1 (absent/bad magic/bad checksum) maps onto
; pret's `jp nz,CheckSumFailed`.
; ---------------------------------------------------------------------------
LoadMainData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; ld a,BANK("Save Data") / ld [rRAMB],a — TODO-HW: SRAM banking no-op
    ; TODO-HW: SRAM — sMainDataCheckSum verify + sPlayerName/sMainData/sSpriteData/
    ; sCurBoxData CopyData slices collapse into the atomic file read.
    call DsvReadSave
    jc CheckSumFailed
    ; WRAM side-effects pret does after the copies:
    ; ld hl,wCurMapTileset / set BIT_NO_PREVIOUS_MAP,[hl]
    or byte [ebp + wCurMapTileset], 1 << 7       ; BIT_NO_PREVIOUS_MAP = 7
    ; ld a,[sTileAnimations] / ldh [hTileAnimations],a
    ; ; TODO-HW: SRAM — dropped, and this one is NOT harmless (M-106): hTileAnimations
    ; is LIVE in the port (home/player_gfx.asm gates the walk animation on it, and
    ; home/pokemon.asm saves/restores it around the party menu). pret persists it
    ; through sTileAnimations; the .dsv payload has no slot for it (it is HRAM, and
    ; dsv_io.asm serializes WRAM ranges only), so SaveMainData cannot store it and
    ; there is nothing to restore here. Net: the tile-animation setting does not
    ; survive a save/load. Fixing it means adding the byte to the .dsv payload —
    ; src/save/dsv_io.asm, filed as a finding, not this file's scope.
    ; and a / jp GoodCheckSum
    jmp GoodCheckSum

; ---------------------------------------------------------------------------
; LoadCurrentBoxData — pret ref: engine/menus/save.asm:LoadCurrentBoxData.
; pret re-verifies the main checksum then CopyData's sCurBoxData -> wBoxDataStart.
; Collapses to DsvReadSave (idempotent re-load + file-checksum verify).
; ---------------------------------------------------------------------------
LoadCurrentBoxData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; TODO-HW: SRAM — checksum verify + sCurBoxData CopyData -> DsvReadSave.
    call DsvReadSave
    jc CheckSumFailed
    jmp GoodCheckSum

; ---------------------------------------------------------------------------
; LoadPartyAndDexData — pret ref: engine/menus/save.asm:LoadPartyAndDexData.
; pret re-verifies then CopyData's sPartyData -> wPartyDataStart and the pokédex
; slice -> wPokedexOwned. Both ranges ride in the same atomic .dsv payload.
; ---------------------------------------------------------------------------
LoadPartyAndDexData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; TODO-HW: SRAM — checksum verify + sPartyData/pokédex CopyData -> DsvReadSave.
    call DsvReadSave
    jc CheckSumFailed
    jmp GoodCheckSum

; ---------------------------------------------------------------------------
; CheckSumFailed / GoodCheckSum — pret ref: engine/menus/save.asm.
; CheckSumFailed sets CF then falls into GoodCheckSum, which DisableSRAM's
; (flag-preserving) and returns — so CF decides the caller's `jr c`.
; ---------------------------------------------------------------------------
CheckSumFailed:
    stc
    ; fallthrough
GoodCheckSum:
    call DisableSRAM                             ; TODO-HW: SRAM no-op (preserves CF)
    ret

; ---------------------------------------------------------------------------
; TryLoadSaveFileIgnoreChecksum — pret ref: engine/menus/save.asm (unreferenced).
; Load without updating wSaveFileStatus / without the corrupt-save warning.
; ---------------------------------------------------------------------------
TryLoadSaveFileIgnoreChecksum:
    call LoadMainData
    call LoadCurrentBoxData
    jmp LoadPartyAndDexData                       ; jp LoadPartyAndDexData

; ###########################################################################
; # SAVE SIDE
; ###########################################################################

; ---------------------------------------------------------------------------
; SaveMenu — pret ref: engine/menus/save.asm:SaveMenu.
; The START->SAVE flow: info screen, "Would you like to SAVE?" yes/no, optional
; "older file erased" second yes/no, SaveGameData, "SAVING..."/"saved!" messages.
; ---------------------------------------------------------------------------
SaveMenu:
    ; farcall PrintSaveScreenText (package E)
    call PrintSaveScreenText
    mov bl, 10                                   ; ld c, 10
    call DelayFrames
    mov esi, WouldYouLikeToSaveText              ; ld hl, WouldYouLikeToSaveText
    call SaveTheGame_YesOrNo
    test al, al                                  ; and a  (0=Yes,1=No)
    jnz .no                                      ; ret nz
    mov bl, 10
    call DelayFrames
    ; ld a,[wSaveFileStatus] / cp 1 / jr z,.save
    mov al, [ebp + wSaveFileStatus]
    cmp al, 1
    jz .save
    call CheckPreviousSaveFile
    jz .save
    mov esi, OlderFileWillBeErasedText           ; ld hl, OlderFileWillBeErasedText
    call SaveTheGame_YesOrNo
    test al, al
    jnz .no                                      ; ret nz
.save:
    call SaveGameData
    mov dword [text_msgbox], msgbox_dialog
    mov esi, SavingText                          ; ld hl, SavingText
    call PrintText                               ; ends in `done` — the box stays up
    mov bl, 128                                  ; ld c, 128
    call DelayFrames
    mov dword [text_msgbox], msgbox_dialog
    mov esi, GameSavedText                       ; ld hl, GameSavedText
    call PrintText                               ; TX_RAM splices in wPlayerName
    mov bl, 10                                   ; ld c, 10
    call DelayFrames
    mov al, SFX_SAVE                             ; ld a, SFX_SAVE
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    mov bl, 30                                   ; ld c, 30
    call DelayFrames
    ret
.no:
    ret

; ---------------------------------------------------------------------------
; SaveTheGame_YesOrNo — pret ref: engine/menus/save.asm:SaveTheGame_YesOrNo.
; In: ESI = text stream (pret's hl). Out: AL = wCurrentMenuItem (0=Yes,1=No).
; pret: PrintText / hlcoord 0,7 / lb bc,8,1 / wTextBoxID=TWO_OPTION_MENU /
; DisplayTextBoxID / ld a,[wCurrentMenuItem] — reproduced call for call (the
; learn_move.asm:AbandonLearning precedent for the TWO_OPTION_MENU box).
; ---------------------------------------------------------------------------
SaveTheGame_YesOrNo:
    mov dword [text_msgbox], msgbox_dialog       ; port: publish the box projection
    call PrintText                               ; the question ends in `done`
    ; hlcoord 0, 7 / lb bc, 8, 1.
    ; DEVIATION{class=projection; pret=engine/menus/save.asm:SaveTheGame_YesOrNo; behavior=pass projected yes-no box geometry through yn_box state instead of the pret HL/BC triple; evidence=pret SaveTheGame_YesOrNo hlcoord/lb setup plus port DisplayTwoOptionMenu private geometry contract; lifetime=until DisplayTwoOptionMenu accepts explicit geometry}
    ; The port's DisplayTwoOptionMenu (home/yes_no.asm)
    ; draws the box as a compositor window, so it takes the top-left from
    ; yn_box_col/row (GB coords, projected) instead of pret's HL, and derives the
    ; cursor from the box rather than from B/C — the HL/BC triple is dead here.
    ; These are pret's coords: GB column 0, row 7, overworld anchor.
    mov dword [yn_box_col], 0
    mov dword [yn_box_row], 7
    mov dword [yn_proj_mode], 0
    mov byte [ebp + wTextBoxID], TWO_OPTION_MENU
    call DisplayTextBoxID
    mov al, [ebp + wCurrentMenuItem]
    ret

; --- the four SAVE-flow dialogs (pret ref: engine/menus/save.asm, same position).
; Tier-2 wrappers over the Tier-1 streams in assets/save_text.inc.
WouldYouLikeToSaveText:
    text_far _WouldYouLikeToSaveText
    text_end

SavingText:
    text_far _SavingText
    text_end

GameSavedText:
    text_far _GameSavedText
    text_end

OlderFileWillBeErasedText:
    text_far _OlderFileWillBeErasedText
    text_end

; ---------------------------------------------------------------------------
; SaveMainData / SaveCurrentBoxData / SavePartyAndDexData — pret ref:
; engine/menus/save.asm. Each copies its WRAM slice to SRAM + rechecksums; all
; collapse to a full atomic .dsv write (dsv owns payload+header+checksum). Kept
; as separate routines for label parity AND so any standalone caller of one of
; them still persists the game. The WRAM the caller wants saved is already final
; by the time any of these runs, so writing the whole payload is faithful in net
; effect (mirrors pret's own "this part is redundant" copies).
; ---------------------------------------------------------------------------
SaveMainData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; TODO-HW: SRAM — wPlayerName/wMainData/wSpriteData/wBoxData -> s* slices +
    ; sMainDataCheckSum. Collapses to the atomic file write.
    ; ALSO dropped here: pret's `ldh a,[hTileAnimations] / ld [sTileAnimations],a`.
    ; The .dsv payload has no slot for that HRAM byte, so the setting is not
    ; persisted (and LoadMainData has nothing to restore) — see M-106 there.
    call DsvWriteSave                            ; CF=0 ok / CF=1 fail
    call DisableSRAM                             ; TODO-HW: SRAM no-op
    ret

SaveCurrentBoxData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; TODO-HW: SRAM — wBoxDataStart -> sCurBoxData + rechecksum. Atomic write.
    call DsvWriteSave
    call DisableSRAM
    ret

SavePartyAndDexData:
    call EnableSRAM                              ; TODO-HW: SRAM no-op
    ; TODO-HW: SRAM — wPartyData/pokédex/wPikachuHappiness -> s* + rechecksum.
    ; (all three ranges ride in the .dsv main-data payload). Atomic write.
    call DsvWriteSave
    call DisableSRAM
    ret

; ---------------------------------------------------------------------------
; SaveGameData — pret ref: engine/menus/save.asm:SaveGameData.
; ---------------------------------------------------------------------------
SaveGameData:
    ; ld a,2 / ld [wSaveFileStatus],a
    mov byte [ebp + wSaveFileStatus], 2
    call SaveMainData
    call SaveCurrentBoxData
    jmp SavePartyAndDexData                       ; jp SavePartyAndDexData (tail)

; ---------------------------------------------------------------------------
; CalcCheckSum — pret ref: engine/menus/save.asm:CalcCheckSum.
; 8-bit additive fold, complemented. In: ESI=GB offset (HL), CX=length (BC).
; Out: AL.
; DEVIATION{class=data-model; pret=engine/menus/save.asm:CalcCheckSum; behavior=retain the Gen-1 checksum routine only for label parity while DSV I/O uses a 16-bit payload checksum; evidence=project_state reports CalcCheckSum linked with zero callers and dsv_io owns the live file checksum; lifetime=until a faithful SRAM-layout compatibility path uses CalcCheckSum}
; The file-level checksum is dsv_io's (16-bit additive over
; the payload); CalcCheckSum is kept for label parity / a future faithful-SRAM
; layout and is currently unused by the collapsed save/load paths.
; ---------------------------------------------------------------------------
CalcCheckSum:
    movzx ecx, cx
    xor dl, dl                                   ; ld d,0
.loop:
    test ecx, ecx
    jz .done
    mov al, [ebp + esi]                          ; ld a,[hli]
    inc esi
    add dl, al                                   ; add d / ld d,a (8-bit wrap)
    dec ecx                                      ; dec bc / or check
    jmp .loop
.done:
    mov al, dl                                   ; ld a,d
    not al                                       ; cpl
    ret

; ###########################################################################
; # CHANGE BOX (Bill's PC deposit-box switch)
; ###########################################################################

; ---------------------------------------------------------------------------
; ChangeBox — pret ref: engine/menus/save.asm:ChangeBox.
; ---------------------------------------------------------------------------
ChangeBox:
    ; ld hl,WhenYouChangeBoxText / call PrintText — the stream carries its own
    ; `para` page break and terminal `done`; the text engine runs both (row 19
    ; part 2, M-101: the port used to drive the two pages by hand).
    mov dword [text_msgbox], msgbox_dialog
    mov esi, WhenYouChangeBoxText
    call PrintText
    ; call YesNoChoice / ld a,[wCurrentMenuItem] / and a / ret nz
    call YesNoChoice
    mov al, [ebp + wCurrentMenuItem]
    test al, al
    jnz .ret                                     ; return if No was chosen
    ; ld hl,wCurrentBoxNum / bit BIT_HAS_CHANGED_BOXES,[hl] / call z,EmptyAllSRAMBoxes
    test byte [ebp + wCurrentBoxNum], 1 << 7     ; BIT_HAS_CHANGED_BOXES = 7
    jnz .alreadyChanged
    call EmptyAllSRAMBoxes                        ; first box change: init SRAM boxes
.alreadyChanged:
    call DisplayChangeBoxMenu
    call UpdateSprites
    ; ld hl,hUILayoutFlags / set BIT_DOUBLE_SPACED_MENU,[hl]
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << 1     ; BIT_DOUBLE_SPACED_MENU = 1
    call HandleMenuInput                          ; AL = watched keys pressed
    mov dword [menu_redraw_cb], 0
    ; port cleanup: drop the change-box list window (pret's caller reloads the
    ; screen; here restore the window list DisplayChangeBoxMenu appended to).
    push eax
    mov eax, [cbox_wc]
    mov [g_window_count], eax
    pop eax
    ; ld hl,hUILayoutFlags / res BIT_DOUBLE_SPACED_MENU,[hl]
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << 1)) & 0xFF
    ; bit B_PAD_B,a / ret nz
    test al, PAD_B
    jnz .cancel
    ; ld a,SFX_SAVE / call PlaySoundWaitForCurrent / call WaitForSoundToFinish
    ; (M-99: the audio HAL is real — the "TODO-HW: audio (Phase 3)" that stood here
    ;  was stale, exactly as in SaveMenu.)
    mov al, SFX_SAVE
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    ; --- copy old box (WRAM) -> SRAM ---
    call GetBoxSRAMLocation                        ; BH=bank, ESI=SRAM ptr (0 in port)
    mov edx, esi                                   ; ld e,l / ld d,h -> DX(de)=SRAM dest
    mov esi, wBoxDataStart                         ; ld hl,wBoxDataStart
    call CopyBoxToOrFromSRAM                        ; copy old box WRAM -> SRAM (no-op)
    ; ld a,[wCurrentMenuItem] / set BIT_HAS_CHANGED_BOXES,a / ld [wCurrentBoxNum],a
    mov al, [ebp + wCurrentMenuItem]
    or al, 1 << 7                                  ; set BIT_HAS_CHANGED_BOXES
    mov [ebp + wCurrentBoxNum], al
    ; --- copy new box (SRAM) -> WRAM ---
    call GetBoxSRAMLocation                        ; ESI=SRAM src (0 in port)
    mov edx, wBoxDataStart                          ; ld de,wBoxDataStart
    call CopyBoxToOrFromSRAM                        ; copy new box SRAM -> WRAM (no-op)
    ; save + restore the map text pointer around SaveGameData
    ; ld hl,wCurMapTextPtr / ld de,wChangeBoxSavedMapTextPointer / copy 2 bytes
    mov al, [ebp + W_CUR_MAP_TEXT_PTR]
    mov [ebp + wChangeBoxSavedMapTextPointer], al
    mov al, [ebp + W_CUR_MAP_TEXT_PTR + 1]
    mov [ebp + wChangeBoxSavedMapTextPointer + 1], al
    call RestoreMapTextPointer
    call SaveGameData
    ; ld hl,wChangeBoxSavedMapTextPointer / call SetMapTextPointer
    mov esi, wChangeBoxSavedMapTextPointer
    call SetMapTextPointer
.cancel:
.ret:
    ret

; ---------------------------------------------------------------------------
; CopyBoxToOrFromSRAM — pret ref: engine/menus/save.asm:CopyBoxToOrFromSRAM.
; pret: copy a full box (wBoxDataEnd-wBoxDataStart bytes) between hl and de with
; b as the SRAM bank, mark the source box empty, then rechecksum the SRAM boxes.
; PORT: the port has WRAM for only the CURRENT box; the other boxes have no
; storage, so the copy + the "mark source empty" (which would ERASE the live
; current box) + the checksums all collapse to a ; TODO-HW: SRAM no-op that
; leaves the live box intact. Retired when a box-storage region / faithful .dsv
; lands. In: ESI (hl) / EDX (de) / bank in B — ignored here.
; ---------------------------------------------------------------------------
CopyBoxToOrFromSRAM:
    ; TODO-HW: SRAM — no box storage for non-current boxes; the swap is a no-op
    ; and the source-empty marking is skipped so the live current box survives.
    ret

; --- the two CHANGE-BOX text streams (pret ref: engine/menus/save.asm, same
; positions). Tier-2 wrappers over the Tier-1 bodies in assets/save_text.inc.
WhenYouChangeBoxText:
    text_far _WhenYouChangeBoxText
    text_end

ChooseABoxText:
    text_far _ChooseABoxText
    text_end

; ---------------------------------------------------------------------------
; DisplayChangeBoxMenu — pret ref: engine/menus/save.asm:DisplayChangeBoxMenu.
; Draws the "BOX No." indicator box + the 12-box name list with per-box pokéball
; indicators, and sets up the vertical menu. Rendered into the stride-20 scratch
; (box-relative), mirrored to GB_TILEMAP0, shown at UI_CHANGE_BOX.
; NOTE: not yet reached by a live caller this session (Bill's PC deposit is the
; caller, a later stage), so the port geometry is UNVERIFIED.
; ---------------------------------------------------------------------------
DisplayChangeBoxMenu:
    ; xor a / ldh [hAutoBGTransferEnabled],a — canvas auto-transfer off (window model)
    mov byte [ebp + hAutoBGTransferEnabled], 0
    ; ld a,PAD_A|PAD_B / ld [wMenuWatchedKeys],a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    ; ld a,11 / ld [wMaxMenuItem],a  (12 boxes, 0..11)
    mov byte [ebp + wMaxMenuItem], 11
    ; ld a,1 / ld [wTopMenuItemY],a
    mov byte [ebp + wTopMenuItemY], 1
    ; ld a,12 / ld [wTopMenuItemX],a  -> box col 11 + 1 = box-rel col 1
    ; DEVIATION{class=projection; pret=engine/menus/save.asm:DisplayChangeBoxMenu; behavior=store cursor X relative to the projected list-box scratch rather than GB-absolute column 12; evidence=pret wTopMenuItemX store plus port UI_CHANGE_BOX projected box origin; lifetime=permanent widescreen projection}
    ; Box-relative scratch (list box at scratch col 0), so
    ; the cursor X is box-rel 1, not GB-absolute 12.
    mov byte [ebp + wTopMenuItemX], 1
    ; xor a / ld [wMenuWatchMovingOutOfBounds],a
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 0
    ; ld a,[wCurrentBoxNum] / and BOX_NUM_MASK / ld [wCurrentMenuItem],a / ld [wLastMenuItem],a
    mov al, [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al

    ; --- "BOX No." indicator box (pret hlcoord 0,0 / lb bc,2,9) ---------------
    ; The UI element EXISTS (UI_CHANGE_BOX_INFO_*, assets/ui_layout_menus.inc):
    ; GB(0,0) 11x4, interior 9x2. The comment that used to stand here claimed root
    ; had not provided the equate yet and left the box undrawn — stale (M-102).
    ; Staged box-relative into the scratch band at CBOXI_SROW, mirrored to
    ; GB_TILEMAP0 row CBOXI_MROW, shown as its own window by cboxi_show_window.
    mov esi, W_TILEMAP + CBOXI_SROW * CBOX_STRIDE
    mov bl, CBOXI_INT_W                           ; lb bc, 2, 9 -> c = int_w = 9
    mov bh, CBOXI_INT_H                           ;                b = int_h = 2
    call TextBoxBorder

    ; ld hl,ChooseABoxText / call PrintText — pret's PrintText draws MESSAGE_BOX
    ; and prints at hlcoord 1,14, i.e. the BOTTOM dialog (NOT this info box); the
    ; info box holds only "BOX No. <n>".
    mov dword [text_msgbox], msgbox_dialog
    mov esi, ChooseABoxText
    call PrintText

    ; --- box-name list box (pret hlcoord 11,0 / lb bc,12,7) -------------------
    ; TextBoxBorder into the scratch at box origin (col 0, row 0).
    mov esi, W_TILEMAP
    mov bl, CBOX_INT_W                            ; interior width 7
    mov bh, CBOX_INT_H                            ; interior height 12
    call TextBoxBorder

    ; set BIT_SINGLE_SPACED_LINES / ld de,BoxNames / hlcoord 13,1 / PlaceString /
    ; res BIT_SINGLE_SPACED_LINES. ONE PlaceString: BoxNames is a single <NEXT>-
    ; separated string and the port's PlaceString honours $4E + the single-spaced
    ; flag, so pret's own shape works — the 12-strings-and-a-loop the port had was
    ; forced only by its hand-split data (M-101).
    ; DEVIATION{class=projection; pret=engine/menus/save.asm:DisplayChangeBoxMenu; behavior=place BoxNames at projected list-box-relative column 2 instead of GB-absolute column 13; evidence=pret hlcoord 13 placement plus port UI_CHANGE_BOX scratch origin; lifetime=permanent widescreen projection}
    ; GB col 13 is list-box col 2 (list box at GB col 11).
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << BIT_SINGLE_SPACED_LINES
    mov esi, W_TILEMAP + 1 * CBOX_STRIDE + 2
    mov eax, BoxNames
    call PlaceString
    and byte [ebp + H_UI_LAYOUT_FLAGS], (~(1 << BIT_SINGLE_SPACED_LINES)) & 0xFF

    ; --- the box-number digits in the info box (pret hlcoord 8,2 / ldcoord_a 9,2)
    ; The port never drew these at all — the indicator box read "BOX No." with no
    ; number (M-101).
    mov al, [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    cmp al, 9
    jc .singleDigitBoxNum
    sub al, 9                                     ; sub 9
    ; hlcoord 8, 2 / ld [hl], '1'
    mov byte [ebp + W_TILEMAP + CBOXI_SROW * CBOX_STRIDE + 2 * CBOX_STRIDE + 8], CHAR_1
    add al, CHAR_0                                ; add '0'
    jmp .next
.singleDigitBoxNum:
    add al, CHAR_1                                ; add '1'
.next:
    ; ldcoord_a 9, 2
    mov [ebp + W_TILEMAP + CBOXI_SROW * CBOX_STRIDE + 2 * CBOX_STRIDE + 9], al
    ; hlcoord 1,2 / ld de,BoxNoText / call PlaceString
    mov esi, W_TILEMAP + CBOXI_SROW * CBOX_STRIDE + 2 * CBOX_STRIDE + 1
    mov eax, BoxNoText
    call PlaceString

    ; --- pokéball indicators (pret hlcoord 18,1 stepping SCREEN_WIDTH) --------
    call GetMonCountsForAllBoxes                  ; fill wBoxMonCounts[0..11]
    xor ebx, ebx                                  ; box index
.ballrow:
    movzx eax, byte [ebp + wBoxMonCounts + ebx]
    test al, al                                   ; is the box empty?
    jz .noball
    ; place pokéball tile at scratch (row 1+ebx, box-rel col 7)
    lea eax, [ebx + 1]
    imul eax, eax, CBOX_STRIDE
    mov byte [ebp + eax + W_TILEMAP + 7], TILE_BALL
.noball:
    inc ebx
    cmp ebx, NUM_BOXES
    jb .ballrow

    ; --- mirror the two boxes -> GB_TILEMAP0 and show them as windows ----------
    call cbox_show_window
    call cboxi_show_window
    ; ld a,1 / ldh [hAutoBGTransferEnabled],a
    mov byte [ebp + hAutoBGTransferEnabled], 1
    ; menu cursor stepping (single-spaced list: 1 scratch row per item)
    mov dword [menu_item_step], CBOX_STRIDE
    mov dword [menu_redraw_cb], cbox_mirror
    ret

; --- change-box list window plumbing ---------------------------------------
cbox_show_window:
    mov eax, [g_window_count]
    mov [cbox_wc], eax
    call cbox_mirror
    mov eax, UI_CHANGE_BOX_WX
    mov ebx, UI_CHANGE_BOX_WY
    mov ecx, UI_CHANGE_BOX_CLIP
    mov edx, UI_CHANGE_BOX_MAXY
    mov esi, GB_TILEMAP0
    mov edi, CBOX_SROW
    call add_window
    ret

; blit the list rect (scratch cols 0..8, rows 0..13, stride 20) -> GB_TILEMAP0
; (stride 32). Preserves all registers (menu_redraw_cb).
cbox_mirror:
    pushad
    xor ebx, ebx
.row:
    mov esi, ebx
    imul esi, esi, CBOX_STRIDE
    lea esi, [ebp + esi + W_TILEMAP]
    mov edi, ebx
    shl edi, 5                                    ; row*32
    lea edi, [ebp + edi + GB_TILEMAP0 + CBOX_SROW * 32]
    mov ecx, CBOX_TOT_W
    rep movsb
    inc ebx
    cmp ebx, CBOX_TOT_H
    jb .row
    popad
    ret

; --- "BOX No." info-box window plumbing ------------------------------------
; The info box is a SECOND window on the same screen, so it needs its own mirror
; region: GB_TILEMAP0 rows CBOXI_MROW.. (the list occupies rows 0..13).
cboxi_show_window:
    call cboxi_mirror
    mov eax, UI_CHANGE_BOX_INFO_WX
    mov ebx, UI_CHANGE_BOX_INFO_WY
    mov ecx, UI_CHANGE_BOX_INFO_CLIP
    mov edx, UI_CHANGE_BOX_INFO_MAXY
    mov esi, GB_TILEMAP0
    mov edi, CBOXI_MROW
    call add_window
    ret

; blit the info rect (scratch rows CBOXI_SROW.., cols 0..10) -> GB_TILEMAP0 rows
; CBOXI_MROW... Preserves all registers.
cboxi_mirror:
    pushad
    xor ebx, ebx
.row:
    mov esi, ebx
    imul esi, esi, CBOX_STRIDE
    lea esi, [ebp + esi + W_TILEMAP + CBOXI_SROW * CBOX_STRIDE]
    mov edi, ebx
    shl edi, 5
    lea edi, [ebp + edi + GB_TILEMAP0 + CBOXI_MROW * 32]
    mov ecx, CBOXI_TOT_W
    rep movsb
    inc ebx
    cmp ebx, CBOXI_TOT_H
    jb .row
    popad
    ret

; ---------------------------------------------------------------------------
; EmptyAllSRAMBoxes / EmptySRAMBoxesInBank / EmptySRAMBox — pret ref:
; engine/menus/save.asm. Mark every SRAM box empty (first box-change init).
; PORT: no SRAM box storage -> ; TODO-HW: SRAM no-ops (label parity + flow).
; ---------------------------------------------------------------------------
EmptyAllSRAMBoxes:
    call EnableSRAM                               ; TODO-HW: SRAM no-op
    ; ld a,BANK("Saved Boxes 1")/2 / rRAMB / EmptySRAMBoxesInBank ×2 — TODO-HW: SRAM
    call EmptySRAMBoxesInBank
    call EmptySRAMBoxesInBank
    call DisableSRAM                              ; TODO-HW: SRAM no-op
    ret

EmptySRAMBoxesInBank:
    ; TODO-HW: SRAM — pret EmptySRAMBox's the 6 boxes in the bank + rechecksums;
    ; no SRAM box storage in the port -> no-op.
    ret

EmptySRAMBox:
    ; TODO-HW: SRAM — pret marks the box empty (count 0, next $ff). No-op here.
    ret

; ---------------------------------------------------------------------------
; GetMonCountsForAllBoxes — pret ref: engine/menus/save.asm.
; Fill wBoxMonCounts[0..NUM_BOXES-1] with each box's mon count, then overwrite
; the current box's slot from WRAM (wBoxCount). PORT: the per-bank SRAM reads
; have no source -> the non-current boxes read empty (0); only the current box's
; count is real (from WRAM). Same degraded-but-safe shape as wNumHoFTeams==0.
; ---------------------------------------------------------------------------
GetMonCountsForAllBoxes:
    call EnableSRAM                               ; TODO-HW: SRAM no-op
    ; ld a,BANK("Saved Boxes 1")/2 / rRAMB / GetMonCountsForBoxesInBank ×2 —
    ; TODO-HW: SRAM. With no SRAM the counts stay 0; zero the scratch explicitly.
    lea edi, [ebp + wBoxMonCounts]
    mov ecx, NUM_BOXES
    xor al, al
    rep stosb
    call GetMonCountsForBoxesInBank
    call GetMonCountsForBoxesInBank
    call DisableSRAM                              ; TODO-HW: SRAM no-op
    ; copy the count for the current box from WRAM:
    ; ld a,[wCurrentBoxNum] / and BOX_NUM_MASK / ld c,a / add hl,bc / ld a,[wBoxCount] / ld [hl],a
    movzx eax, byte [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov cl, [ebp + wBoxCount]
    mov [ebp + eax + wBoxMonCounts], cl
    ret

GetMonCountsForBoxesInBank:
    ; TODO-HW: SRAM — pret reads sBox1..sBox6 count bytes into wBoxMonCounts.
    ; No SRAM box storage -> no-op (the slots stay 0 from the caller's clear).
    ret

; ---------------------------------------------------------------------------
; GetBoxSRAMLocation — pret ref: engine/menus/save.asm:GetBoxSRAMLocation.
; pret: out b=box SRAM bank, hl=pointer to start of box. PORT: no SRAM pointers.
; Returns BH=bank (2/3 as pret computes) for parity, ESI=0 (no SRAM address);
; CopyBoxToOrFromSRAM (its only caller) ignores the address (no-op). ; TODO-HW: SRAM
; ---------------------------------------------------------------------------
GetBoxSRAMLocation:
    ; ld a,[wCurrentBoxNum] / and BOX_NUM_MASK / cp NUM_BOXES/2 / ld b,2 / jr c / inc b / sub NUM_BOXES/2
    movzx eax, byte [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov bh, 2                                      ; ld b,2
    cmp al, NUM_BOXES / 2
    jc .haveBank
    inc bh                                         ; inc b
    sub al, NUM_BOXES / 2
.haveBank:
    ; TODO-HW: SRAM — pret indexes BoxSRAMPointerTable by the in-bank box index;
    ; no SRAM pointer table in the port. ESI (hl) = 0.
    xor esi, esi
    ret

; ---------------------------------------------------------------------------
; CalcIndividualBoxCheckSums — pret ref: engine/menus/save.asm.
; PORT: per-box SRAM checksums have no source -> ; TODO-HW: SRAM no-op (parity).
; ---------------------------------------------------------------------------
CalcIndividualBoxCheckSums:
    ; TODO-HW: SRAM — no SRAM box banks; no-op.
    ret

; ---------------------------------------------------------------------------
; CheckPreviousSaveFile — pret ref: engine/menus/save.asm:CheckPreviousSaveFile.
; pret: return Z set if (no valid save) OR (saved playerID == current wPlayerID);
; Z clear -> a DIFFERENT playthrough's save exists ("older file will be erased").
; PORT: dsv is single-slot (POKEMON.DSV) and reading the saved player ID would
; require loading the file — clobbering the LIVE game we are about to save. The
; SaveMenu caller short-circuits the no-save case via wSaveFileStatus==1.
; ; TODO-HW/DEVIATION(SRAM): this ALWAYS returns Z ("same playthrough"), and the
; consequence is real, not theoretical (M-107): the case pret's check exists for is
; NEW GAME started on top of an existing save — there wSaveFileStatus is still 2, the
; player IDs differ, and pret asks "the OLDER FILE will be erased, OK?" before
; overwriting. The port asks nothing and overwrites silently. Deciding it honestly
; needs the SAVED player ID, and the only way to reach it today is DsvReadSave, which
; loads the payload over the LIVE game we are about to save — so the check cannot be
; made faithful from this file. It needs a header/field peek in src/save/dsv_io.asm
; (filed). OlderFileWillBeErasedText + its yes/no are kept wired and correct, so the
; day that peek exists this becomes a one-line branch.
; Out: ZF set (SaveMenu's `jr z,.save`).
; ---------------------------------------------------------------------------
CheckPreviousSaveFile:
    call EnableSRAM                               ; TODO-HW: SRAM no-op
    call DsvFileExists                            ; CF=1/AL=1 if a valid file present
    ; (result deliberately not branched on — see DEVIATION above.)
    call DisableSRAM                              ; TODO-HW: SRAM no-op
    xor al, al                                    ; force Z set (pret's same-file path)
    ret

; ###########################################################################
; # HALL OF FAME
; ###########################################################################

; ---------------------------------------------------------------------------
; SaveHallOfFameTeams — pret ref: engine/menus/save.asm:SaveHallOfFameTeams.
; Append wHallOfFame as the next HoF team (shifting teams down if the capacity is
; full, deleting the oldest). PORT: the sHallOfFame SRAM writes are ; TODO-HW:
; SRAM. wNumHoFTeams stays 0 until the HoF-movie writer, so the append is unused
; for now; kept for label parity + faithful control flow.
; ---------------------------------------------------------------------------
SaveHallOfFameTeams:
    ; ld a,[wNumHoFTeams] / dec a / cp HOF_TEAM_CAPACITY / jr nc,.shiftHOFTeams
    mov al, [ebp + wNumHoFTeams]
    dec al
    cmp al, HOF_TEAM_CAPACITY
    jnc .shiftHOFTeams
    ; ld hl,sHallOfFame / ld bc,HOF_TEAM / call AddNTimes / ld e,l / ld d,h
    ; ld hl,wHallOfFame / ld bc,HOF_TEAM / jr HallOfFame_Copy
    ; TODO-HW: SRAM — sHallOfFame is an SRAM region; AddNTimes into it has no port
    ; address. wHallOfFame -> (SRAM slot) copy collapses to a no-op HallOfFame_Copy.
    mov bx, HOF_TEAM
    mov edx, 0                                     ; de = SRAM dest (none) — TODO-HW: SRAM
    mov esi, wHallOfFame
    jmp HallOfFame_Copy
.shiftHOFTeams:
    ; TODO-HW: SRAM — shift all HoF teams down one slot in sHallOfFame (deletes the
    ; oldest), then copy wHallOfFame into the freed top slot. No SRAM -> no-op copy.
    mov esi, wHallOfFame
    mov edx, 0
    mov bx, HOF_TEAM
    jmp HallOfFame_Copy

; ---------------------------------------------------------------------------
; LoadHallOfFameTeams — pret ref: engine/menus/save.asm:LoadHallOfFameTeams.
; Load the wHoFTeamIndex'th HoF team from sHallOfFame into wHallOfFame. This is
; the REAL routine that REPLACES the ret-stub in league_pc_stubs.asm.
; PORT: the sHallOfFame source is ; TODO-HW: SRAM (no port HoF SRAM region yet);
; AddNTimes computes the source slot (kept for parity), then CopyData into
; wHallOfFame collapses to a no-op until an in-memory HoF region / .dsv exists.
; Reached only inside PKMNLeaguePC's team loop, which is dead while wNumHoFTeams==0.
; ---------------------------------------------------------------------------
LoadHallOfFameTeams:
    ; ld hl,sHallOfFame / ld bc,HOF_TEAM / ld a,[wHoFTeamIndex] / call AddNTimes
    ; TODO-HW: SRAM — sHallOfFame has no port address; the AddNTimes source-slot
    ; math and the CopyData below collapse. Provide wHallOfFame's contract (leave
    ; it as-is; the caller loop is dead at wNumHoFTeams==0).
    mov edx, wHallOfFame                           ; ld de,wHallOfFame
    mov bx, HOF_TEAM                               ; ld bc,HOF_TEAM
    ; fallthrough

; ---------------------------------------------------------------------------
; HallOfFame_Copy — pret ref: engine/menus/save.asm:HallOfFame_Copy.
; pret: EnableSRAM / bank 0 / CopyData / DisableSRAM. In: ESI=src, DX=dest, BX=len.
; PORT: the SRAM endpoint (source or dest) has no port address, so the copy is a
; ; TODO-HW: SRAM no-op. Kept for label parity + control flow.
; ---------------------------------------------------------------------------
HallOfFame_Copy:
    call EnableSRAM                                ; TODO-HW: SRAM no-op
    ; xor a / ld [rRAMB],a — TODO-HW: SRAM banking no-op
    ; call CopyData — TODO-HW: SRAM (one endpoint is SRAM; no-op)
    call DisableSRAM                               ; TODO-HW: SRAM no-op
    ret

; ---------------------------------------------------------------------------
; ClearAllSRAMBanks — pret ref: engine/menus/save.asm:ClearAllSRAMBanks.
; Fill SRAM with $ff (erase save data; used by DoClearSaveDialogue). PORT: the
; port's "SRAM" is the POKEMON.DSV file. ; TODO-HW: SRAM — erasing collapses to
; (a future) delete of POKEMON.DSV; no-op for now (label parity + flow).
; ---------------------------------------------------------------------------
ClearAllSRAMBanks:
    call EnableSRAM                                ; TODO-HW: SRAM no-op
    ; ld a,4 / .loop dec a / FillMemory SRAM with $ff / jr nz — TODO-HW: SRAM
    call DisableSRAM                               ; TODO-HW: SRAM no-op
    ret

; ---------------------------------------------------------------------------
; EnableSRAM / DisableSRAM — pret ref: engine/menus/save.asm.
; pret drives the MBC banking regs (rBMODE/rRAMG) to gate the SRAM window. The
; port has no SRAM window -> flag-preserving no-ops. DisableSRAM MUST preserve
; flags (pret's comment: "preserve flags"; GoodCheckSum's CF survives it).
; ; TODO-HW: SRAM
; ---------------------------------------------------------------------------
EnableSRAM:
    ret
DisableSRAM:
    ret

; ###########################################################################
; # DEBUG harnesses
; ###########################################################################
%ifdef DEBUG_CHANGEBOX
; ---------------------------------------------------------------------------
; RunSaveTest (CHANGE BOX mode) — row 19 part 2 FRAME.BIN gate. The port has NO
; live ChangeBox caller yet (pret's is BillsPCChangeBox, and the port's bills_pc
; does not wire it — see the ledger finding), so the screen is otherwise
; unobservable. Seeds a new game and calls ChangeBox: the two-page "When you
; change a #MON BOX..." text, the YES/NO, then DisplayChangeBoxMenu's box list +
; "BOX No." indicator. ChangeBox blocks in HandleMenuInput; AUTOKEY drives the
; YES and photographs the list at AUTOKEY_DUMP_FRAME.
; ---------------------------------------------------------------------------
RunSaveTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call PrepareNewGameDebug
    ; DisplayChangeBoxMenu, not ChangeBox: ChangeBox's tail is HandleMenuInput,
    ; which accepts the same A press that resolved ChooseABoxText's <PROMPT> and
    ; tears the list back down in the very next frame — the list is on screen for
    ; one frame and can't be photographed. Calling the screen directly leaves it
    ; up. (ChangeBox's own two-page text + YES/NO were observed with the ChangeBox
    ; call in its place; see the ledger's row-19 part-2 verification note.)
    call DisplayChangeBoxMenu
    or byte [ebp + H_UI_LAYOUT_FLAGS], 1 << 1       ; BIT_DOUBLE_SPACED_MENU, as ChangeBox does
    call HandleMenuInput                            ; the real menu loop (cursor + blink)
.hang:
    call DelayFrame                                 ; keep frames flowing so AUTOKEY can dump
    jmp .hang
; NOTE the branch order: the DEBUG_SAVE_ROUNDTRIP and DEBUG_CHANGEBOX builds each
; define DEBUG_SAVE too (they reuse the overworld's DEBUG_SAVE harness hook), so the
; more specific modes MUST be tested first — with DEBUG_SAVE first, as this chain
; used to be, the roundtrip harness was silently unreachable.
%elifdef DEBUG_SAVE_ROUNDTRIP
; ---------------------------------------------------------------------------
; RunSaveTest (roundtrip mode) — write the .dsv, then prove it round-trips:
; DsvWriteSave -> DsvFileExists. Stash the AL result (1 = present/valid) into the
; back-buffer top-left pixel and dump FRAME.BIN so the host can read it.
; ---------------------------------------------------------------------------
RunSaveTest:
    call PrepareNewGameDebug
    call DsvWriteSave                               ; CF=0 ok
    call DsvFileExists                              ; CF=1/AL=1 if present+valid
    mov [ebp + GB_BACKBUF], al                      ; marker pixel (1 = round-trip ok)
    call DumpBackbuffer
.hang:
    jmp .hang
%elifdef DEBUG_SAVE
; ---------------------------------------------------------------------------
; RunSaveTest — row 19 part 1 FRAME.BIN gate for the SAVE flow. Seeds a new game,
; then runs the REAL SaveMenu: the save-info panel, "Would you like to SAVE?"
; through PrintText, and pret's TWO_OPTION_MENU YES/NO box at hlcoord 0,7.
; SaveMenu blocks in that menu's HandleMenuInput; the harness runs with
; AUTOKEY_QUIET (no presses), so AutoKeyDrive photographs the open question +
; YES/NO at AUTOKEY_DUMP_FRAME and exits. (The RunPCTest/RunOaksPCTest pattern.)
; In: EBP = GB base. Called from EnterMap after the overworld is set up.
; ---------------------------------------------------------------------------
RunSaveTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call PrepareNewGameDebug                        ; seed party+bag+badges
    call SaveMenu
.hang:
    jmp .hang
%endif
