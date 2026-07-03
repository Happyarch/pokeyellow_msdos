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
;  * TEXT: pret prints each message with PrintText (the battle/menu printer that
;    keeps the current window list). The port's PrintText_Overworld collapses the
;    window list to the dialog alone, so — as in S4/S5/S6 — each message is DRAWN
;    WHOLE into the stride-20 W_TILEMAP scratch (rows 12-17), mirrored to
;    GB_TILEMAP1, shown as a window at UI_MESSAGE_BOX, with pret wording
;    (data/text/text_4.asm, GB charmap) and the terminal `prompt` reproduced as a
;    ▼ + A/B wait.  DEVIATION(text) — same precedent as players_pc.asm.
;  * The "Would you like to SAVE?" yes/no uses the S3 two-option driver
;    (home/yes_no.asm) via InitYesNoTextBoxParameters + DisplayYesNoChoice;
;    wCurrentMenuItem holds the result (0=Yes,1=No). ; DEVIATION(geometry): pret
;    positions the box at hlcoord 0,7 directly; the driver owns the projected
;    (top-right) placement, so the save yes/no lands at the standard UI YES/NO
;    anchor. Carry contract preserved (CF=0/AL=0 -> Yes).
;  * CHANGE-BOX box swap: the port has WRAM for only the CURRENT box
;    (wBoxDataStart..End); the other 11 boxes live in SRAM banks pret has and the
;    port does not. So CopyBoxToOrFromSRAM / the per-bank mon-count reads / the
;    empty-box init all collapse to ; TODO-HW: SRAM no-ops that PRESERVE the live
;    current box (they must not erase it). Net stopgap: the ChangeBox UI + flow +
;    SaveGameData all run, but the box contents do not actually swap and the other
;    boxes read empty — exactly the wNumHoFTeams==0 kind of degraded-but-safe
;    behavior, retired when a box-storage WRAM region / faithful .dsv lands.
;  * PlaySoundWaitForCurrent / WaitForSoundToFinish (SFX_SAVE) are ; TODO-HW:
;    audio HAL (Phase 3) — no-ops.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/menus/save.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

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
; --- CHANGE BOX ------------------------------------------------------------
global ChangeBox
global CopyBoxToOrFromSRAM
global DisplayChangeBoxMenu
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
extern TextBoxBorder            ; text/text.asm — ESI=top-left, BL=int_w, BH=int_h
extern place_flat_str           ; text/text.asm — EAX=flat '@'-term src, ESI=dest
extern add_window               ; ppu/ppu.asm — EAX=wx EBX=wy ECX=clip EDX=max_y ESI=tm EDI=row
extern g_window_count           ; ppu/ppu.asm
extern text_row_stride          ; text/text.asm — active W_TILEMAP row stride
extern menu_item_step           ; home/window.asm — per-item cursor row step
extern menu_redraw_cb           ; home/window.asm — per-frame redraw cb (0=none)
extern HandleMenuInput          ; home/window.asm — Out: AL = watched keys pressed
extern DelayFrame               ; video/frame.asm
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
extern InitYesNoTextBoxParameters
extern DisplayYesNoChoice
extern YesNoChoice
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

; wChangeBoxSavedMapTextPointer (pret ram/wram.asm:998, union alias @ 0xCD3D).
; NEEDED in gb_memmap.inc — reported to root; local fallback until then.
%ifndef wChangeBoxSavedMapTextPointer
wChangeBoxSavedMapTextPointer equ 0xCD3D
%endif

; ===========================================================================
section .data
align 4
; --- pret data/text/text_4.asm wording, GB charmap, '@'-terminated -----------
; _WouldYouLikeToSaveText: "Would you like to" / "SAVE the game?"
sv_would_l1: db 0x96,0xAE,0xB4,0xAB,0xA3,0x7F,0xB8,0xAE,0xB4,0x7F,0xAB,0xA8,0xAA,0xA4,0x7F,0xB3,0xAE, CHAR_TERM
sv_would_l2: db 0x92,0x80,0x95,0x84,0x7F,0xB3,0xA7,0xA4,0x7F,0xA6,0xA0,0xAC,0xA4,0xE6, CHAR_TERM
; _SavingText: "Saving..."
sv_saving_l1: db 0x92,0xA0,0xB5,0xA8,0xAD,0xA6,0xE8,0xE8,0xE8, CHAR_TERM
; _GameSavedText: "<PLAYER> saved" / "the game!"  (player name placed at runtime)
sv_saved_tail: db 0x7F,0xB2,0xA0,0xB5,0xA4,0xA3, CHAR_TERM               ; " saved"
sv_saved_l2:   db 0xB3,0xA7,0xA4,0x7F,0xA6,0xA0,0xAC,0xA4,0xE7, CHAR_TERM ; "the game!"
; _OlderFileWillBeErasedText: "The older file" / "will be erased to" / "save. Okay?"
sv_older_l1: db 0x93,0xA7,0xA4,0x7F,0xAE,0xAB,0xA3,0xA4,0xB1,0x7F,0xA5,0xA8,0xAB,0xA4, CHAR_TERM
sv_older_l2: db 0xB6,0xA8,0xAB,0xAB,0x7F,0xA1,0xA4,0x7F,0xA4,0xB1,0xA0,0xB2,0xA4,0xA3,0x7F,0xB3,0xAE, CHAR_TERM
sv_older_l3: db 0xB2,0xA0,0xB5,0xA4,0xE8,0x7F,0x8E,0xAA,0xA0,0xB8,0xE6, CHAR_TERM
; _FileDataDestroyedText: "The file data is" / "destroyed!"
sv_destroyed_l1: db 0x93,0xA7,0xA4,0x7F,0xA5,0xA8,0xAB,0xA4,0x7F,0xA3,0xA0,0xB3,0xA0,0x7F,0xA8,0xB2, CHAR_TERM
sv_destroyed_l2: db 0xA3,0xA4,0xB2,0xB3,0xB1,0xAE,0xB8,0xA4,0xA3,0xE7, CHAR_TERM
; _WhenYouChangeBoxText page1: "When you change a" / "#MON BOX, data" / "will be saved."
; (# = POKé, spelled P,O,K,é,M,O,N as league_pc.asm does; drawn-whole DEVIATION)
sv_chgbox_l1: db 0x96,0xA7,0xA4,0xAD,0x7F,0xB8,0xAE,0xB4,0x7F,0xA2,0xA7,0xA0,0xAD,0xA6,0xA4,0x7F,0xA0, CHAR_TERM
sv_chgbox_l2: db 0x8F,0x8E,0x8A,0xBA,0x8C,0x8E,0x8D,0x7F,0x81,0x8E,0x97,0xF4,0x7F,0xA3,0xA0,0xB3,0xA0, CHAR_TERM
sv_chgbox_l3: db 0xB6,0xA8,0xAB,0xAB,0x7F,0xA1,0xA4,0x7F,0xB2,0xA0,0xB5,0xA4,0xA3,0xE8, CHAR_TERM
; page2: "Is that okay?"
sv_chgbox_p2: db 0x88,0xB2,0x7F,0xB3,0xA7,0xA0,0xB3,0x7F,0xAE,0xAA,0xA0,0xB8,0xE6, CHAR_TERM
; _ChooseABoxText: "Choose a" / "<PKMN> BOX." (<PKMN> = PK/MN ligature tiles E1,E2)
sv_choose_l1: db 0x82,0xA7,0xAE,0xAE,0xB2,0xA4,0x7F,0xA0, CHAR_TERM
sv_choose_l2: db 0xE1,0xE2,0x7F,0x81,0x8E,0x97,0xE8, CHAR_TERM
; BoxNoText: "BOX No.@"  (pret label kept for parity; drawn-whole so not text_far)
BoxNoText:
sv_boxno: db 0x81,0x8E,0x97,0x7F,0x8D,0xAE,0xE8, CHAR_TERM

; BoxNames — 12 '@'-terminated single-box names, "BOX 1".."BOX12".
; (pret splits these with `next`; here each is its own '@'-terminated string so
; DisplayChangeBoxMenu can PlaceString one per scratch row.)
align 4
BoxNames:
sv_boxnames:
    db 0x81,0x8E,0x97,0x7F,0xF7, CHAR_TERM   ; "BOX 1"
    db 0x81,0x8E,0x97,0x7F,0xF8, CHAR_TERM   ; "BOX 2"
    db 0x81,0x8E,0x97,0x7F,0xF9, CHAR_TERM   ; "BOX 3"
    db 0x81,0x8E,0x97,0x7F,0xFA, CHAR_TERM   ; "BOX 4"
    db 0x81,0x8E,0x97,0x7F,0xFB, CHAR_TERM   ; "BOX 5"
    db 0x81,0x8E,0x97,0x7F,0xFC, CHAR_TERM   ; "BOX 6"
    db 0x81,0x8E,0x97,0x7F,0xFD, CHAR_TERM   ; "BOX 7"
    db 0x81,0x8E,0x97,0x7F,0xFE, CHAR_TERM   ; "BOX 8"
    db 0x81,0x8E,0x97,0x7F,0xFF, CHAR_TERM   ; "BOX 9"
    db 0x81,0x8E,0x97,0xF7,0xF6, CHAR_TERM   ; "BOX10"
    db 0x81,0x8E,0x97,0xF7,0xF7, CHAR_TERM   ; "BOX11"
    db 0x81,0x8E,0x97,0xF7,0xF8, CHAR_TERM   ; "BOX12"
; per-name stride into sv_boxnames (5 glyphs + terminator)
CBOX_NAME_LEN equ 6

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
    mov dword [text_row_stride], MSG_STRIDE      ; drawn-whole messages stage stride-20
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
    call SV_FileDataDestroyed                    ; PrintText FileDataDestroyedText (whole, prompt)
    ; ld c,100 / call DelayFrames
    mov ecx, 100
.delay:
    call DelayFrame
    dec ecx
    jnz .delay
    ; res BIT_NO_TEXT_DELAY,[hl]
    and byte [ebp + wStatusFlags5], (~(1 << BIT_NO_TEXT_DELAY)) & 0xFF
    mov al, 1                                    ; bad checksum
.done:
    mov [ebp + wSaveFileStatus], al
    ret

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
    ; ld a,[sTileAnimations] / ldh [hTileAnimations],a — TODO-HW: SRAM
    ; (sTileAnimations is NOT part of the .dsv payload; skip the restore).
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
    mov dword [text_row_stride], MSG_STRIDE
    ; farcall PrintSaveScreenText (package E)
    call PrintSaveScreenText
    ; ld c,10 / call DelayFrames
    mov ecx, 10
    call sv_delay
    ; ld hl,WouldYouLikeToSaveText / call SaveTheGame_YesOrNo
    mov eax, SV_WouldYouLikeToSave
    call SaveTheGame_YesOrNo
    test al, al                                  ; and a  (0=Yes,1=No)
    jnz .no                                      ; ret nz
    mov ecx, 10
    call sv_delay
    ; ld a,[wSaveFileStatus] / cp 1 / jr z,.save
    mov al, [ebp + wSaveFileStatus]
    cmp al, 1
    jz .save
    call CheckPreviousSaveFile
    jz .save
    ; ld hl,OlderFileWillBeErasedText / call SaveTheGame_YesOrNo
    mov eax, SV_OlderFileErased
    call SaveTheGame_YesOrNo
    test al, al
    jnz .no                                      ; ret nz
.save:
    call SaveGameData
    ; ld hl,SavingText / call PrintText
    call SV_Saving
    ; ld c,128 / call DelayFrames
    mov ecx, 128
    call sv_delay
    call sv_msg_drop                             ; drop "SAVING..." before "saved!"
    ; ld hl,GameSavedText / call PrintText
    call SV_GameSaved
    ; ld c,10 / call DelayFrames
    mov ecx, 10
    call sv_delay
    ; ld a,SFX_SAVE / call PlaySoundWaitForCurrent / call WaitForSoundToFinish —
    ; TODO-HW: audio HAL (Phase 3), no-op.
    ; ld c,30 / call DelayFrames
    mov ecx, 30
    call sv_delay
    call sv_msg_drop
    ret
.no:
    ret

; ---------------------------------------------------------------------------
; SaveTheGame_YesOrNo — pret ref: engine/menus/save.asm:SaveTheGame_YesOrNo.
; In: EAX = drawn-whole message routine (port: pret's hl=text ptr for PrintText).
; Out: AL = wCurrentMenuItem (0=Yes,1=No).
; pret: PrintText / hlcoord 0,7 / lb bc,8,1 / wTextBoxID=TWO_OPTION_MENU /
; DisplayTextBoxID / ld a,[wCurrentMenuItem].
; ---------------------------------------------------------------------------
SaveTheGame_YesOrNo:
    call eax                                     ; draw the question whole (persists)
    ; ; PROJ/DEVIATION(geometry): pret hlcoord 0,7 lb bc,8,1 -> the S3 YES/NO
    ; driver's standard top-right anchor (InitYesNoTextBoxParameters GB(14,7)).
    call InitYesNoTextBoxParameters
    call DisplayYesNoChoice                      ; CF/wCurrentMenuItem = choice
    call sv_msg_drop                             ; drop the question window
    mov al, [ebp + wCurrentMenuItem]
    ret

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
; Out: AL. ; DEVIATION: the file-level checksum is dsv_io's (16-bit additive over
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
    mov dword [text_row_stride], MSG_STRIDE
    ; ld hl,WhenYouChangeBoxText / call PrintText  (2-page, prompt)
    call SV_WhenYouChangeBox
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
    ; ld a,SFX_SAVE / PlaySoundWaitForCurrent / WaitForSoundToFinish — TODO-HW: audio HAL
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
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 0
    ; ld a,PAD_A|PAD_B / ld [wMenuWatchedKeys],a
    mov byte [ebp + wMenuWatchedKeys], PAD_A | PAD_B
    ; ld a,11 / ld [wMaxMenuItem],a  (12 boxes, 0..11)
    mov byte [ebp + wMaxMenuItem], 11
    ; ld a,1 / ld [wTopMenuItemY],a
    mov byte [ebp + wTopMenuItemY], 1
    ; ld a,12 / ld [wTopMenuItemX],a  -> box col 11 + 1 = box-rel col 1
    ; ; DEVIATION(geometry): box-relative scratch (list box at scratch col 0), so
    ; the cursor X is box-rel 1, not GB-absolute 12.
    mov byte [ebp + wTopMenuItemX], 1
    ; xor a / ld [wMenuWatchMovingOutOfBounds],a
    mov byte [ebp + wMenuWatchMovingOutOfBounds], 0
    ; ld a,[wCurrentBoxNum] / and BOX_NUM_MASK / ld [wCurrentMenuItem],a / ld [wLastMenuItem],a
    mov al, [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov [ebp + wCurrentMenuItem], al
    mov [ebp + wLastMenuItem], al

    ; --- "BOX No." indicator box (pret hlcoord 0,0 lb bc,2,9) -----------------
    ; ; PROJ menus: GB(0,0) 11x4 --> needs a dedicated UI element. Report:
    ; UI_CHANGE_BOX_INFO — GB rect (0,0) 11 wide x 4 tall (interior 9x2), anchor
    ; matching the top-left of the change-box screen. Root adds the equate; until
    ; then the info box is staged into the scratch but not shown as its own window.
    ; (Drawn into a separate scratch band so it does not collide with the list.)
    ; hlcoord 1,2 -> "BOX No." ; the box number digit is placed at hlcoord 8/9,2.
    ; Staged for parity; the window append is guarded on UI_CHANGE_BOX_INFO_WX.
%ifdef UI_CHANGE_BOX_INFO_WX
    ; (root-provided) — draw + add the info box window here.
%endif

    ; --- box-name list box (pret hlcoord 11,0 lb bc,12,7) --------------------
    ; TextBoxBorder into the scratch at box origin (col 0, row 0).
    mov esi, W_TILEMAP
    mov bl, CBOX_INT_W                            ; interior width 7
    mov bh, CBOX_INT_H                            ; interior height 12
    call TextBoxBorder
    ; ChooseABoxText — pret prints it into the info region; drawn-whole for parity
    ; (its two lines land in the info box; staged, shown when UI_CHANGE_BOX_INFO
    ; exists). Not blocking the list.
    ; place each BoxNames[i] at scratch (row 1+i, box-rel col 2) single-spaced.
    mov ebx, 0                                    ; box index
.namerow:
    ; ESI = W_TILEMAP + (1+ebx)*20 + 2
    lea eax, [ebx + 1]
    imul eax, eax, CBOX_STRIDE
    lea esi, [eax + W_TILEMAP + 2]
    mov eax, ebx
    imul eax, eax, CBOX_NAME_LEN
    lea eax, [sv_boxnames + eax]                  ; &BoxNames[i]
    call place_flat_str
    inc ebx
    cmp ebx, NUM_BOXES
    jb .namerow

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

    ; --- mirror the list box -> GB_TILEMAP0 and show it at UI_CHANGE_BOX --------
    call cbox_show_window
    ; ld a,1 / ldh [hAutoBGTransferEnabled],a
    mov byte [ebp + H_AUTO_BG_TRANSFER_EN], 1
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
; SaveMenu caller already short-circuits the no-save/new-game case via
; wSaveFileStatus==1, so in practice the on-disk save is this same playthrough.
; ; TODO-HW/DEVIATION(SRAM): treat a present valid file as same-playthrough
; (Z set) — the "older file erased" second yes/no is kept for label parity but is
; not reached until a partial-read seam / multi-slot .dsv exists.
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
; # Port plumbing — drawn-whole messages (DEVIATION(text); players_pc precedent)
; ###########################################################################

; sv_delay — DelayFrames(ECX). (DelayFrame may clobber ECX -> save/restore.)
sv_delay:
.loop:
    push ecx
    call DelayFrame
    pop ecx
    dec ecx
    jnz .loop
    ret

; draw the empty message border into scratch rows 12-17 (interior 18x4)
sv_msg_box:
    mov esi, W_TILEMAP + MSG_SROW * MSG_STRIDE
    mov bl, 18
    mov bh, 4
    call TextBoxBorder
    ret

; mirror scratch rows 12-17 -> GB_TILEMAP1 rows 0-5 (pad cols 20-31), append the
; dialog window at UI_MESSAGE_BOX, remember g_window_count for sv_msg_drop.
sv_msg_show:
    pushad
    mov ecx, 6
    lea esi, [ebp + W_TILEMAP + MSG_SROW * MSG_STRIDE]
    lea edi, [ebp + GB_TILEMAP1]
.row:
    push ecx
    push edi
    mov ecx, 20
    rep movsb
    mov al, TILE_SPC
    mov ecx, 12                                    ; pad cols 20-31
    rep stosb
    pop edi
    pop ecx
    add edi, 32
    dec ecx
    jnz .row
    mov eax, [g_window_count]
    mov [sv_msg_wc], eax
    mov eax, UI_MESSAGE_BOX_WX
    mov ebx, UI_MESSAGE_BOX_WY
    mov ecx, UI_MESSAGE_BOX_CLIP
    mov edx, UI_MESSAGE_BOX_MAXY
    mov esi, GB_TILEMAP1
    xor edi, edi
    call add_window
    popad
    ret

; ▼ + wait for an A/B press cycle (a text's terminal `prompt`), clear the ▼.
sv_msg_prompt:
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], CHAR_DOWN
.release:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jnz .release
.press:
    call DelayFrame
    test byte [ebp + H_JOY_HELD], PAD_A | PAD_B
    jz .press
    mov byte [ebp + GB_TILEMAP1 + DIALOG_ARROW_TILEMAP_OFFSET], TILE_SPC
    ret

; drop the dialog window (restore the count sv_msg_show saved). Clobbers EAX.
sv_msg_drop:
    push eax
    mov eax, [sv_msg_wc]
    mov [g_window_count], eax
    pop eax
    ret

; --- specific message drawers (pret text_4.asm wording) --------------------
; WouldYouLikeToSaveText (done — persists; the yes/no box follows)
SV_WouldYouLikeToSave:
    call sv_msg_box
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_would_l1
    call place_flat_str
    mov esi, W_TILEMAP + 16 * MSG_STRIDE + 1
    mov eax, sv_would_l2
    call place_flat_str
    call sv_msg_show
    ret

; SavingText (done — persists)
SV_Saving:
    call sv_msg_box
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_saving_l1
    call place_flat_str
    call sv_msg_show
    ret

; GameSavedText (done — "<PLAYER> saved" / "the game!")
SV_GameSaved:
    call sv_msg_box
    lea eax, [ebp + W_PLAYER_NAME]
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    call place_flat_str                            ; name; ESI advances past it
    mov eax, sv_saved_tail
    call place_flat_str
    mov esi, W_TILEMAP + 16 * MSG_STRIDE + 1
    mov eax, sv_saved_l2
    call place_flat_str
    call sv_msg_show
    ret

; OlderFileWillBeErasedText (done — 3 lines; the yes/no box follows)
SV_OlderFileErased:
    call sv_msg_box
    mov esi, W_TILEMAP + 13 * MSG_STRIDE + 1
    mov eax, sv_older_l1
    call place_flat_str
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_older_l2
    call place_flat_str
    mov esi, W_TILEMAP + 15 * MSG_STRIDE + 1
    mov eax, sv_older_l3
    call place_flat_str
    call sv_msg_show
    ret

; FileDataDestroyedText (prompt — ▼ + A/B wait, then drop)
SV_FileDataDestroyed:
    call sv_msg_box
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_destroyed_l1
    call place_flat_str
    mov esi, W_TILEMAP + 16 * MSG_STRIDE + 1
    mov eax, sv_destroyed_l2
    call place_flat_str
    call sv_msg_show
    call sv_msg_prompt
    jmp sv_msg_drop

; WhenYouChangeBoxText (2 pages, prompt after each)
SV_WhenYouChangeBox:
    call sv_msg_box
    mov esi, W_TILEMAP + 13 * MSG_STRIDE + 1
    mov eax, sv_chgbox_l1
    call place_flat_str
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_chgbox_l2
    call place_flat_str
    mov esi, W_TILEMAP + 15 * MSG_STRIDE + 1
    mov eax, sv_chgbox_l3
    call place_flat_str
    call sv_msg_show
    call sv_msg_prompt
    ; page 2 ("Is that okay?")
    call sv_msg_box
    mov esi, W_TILEMAP + 14 * MSG_STRIDE + 1
    mov eax, sv_chgbox_p2
    call place_flat_str
    call sv_msg_show
    ret

; ###########################################################################
; # DEBUG harnesses
; ###########################################################################
%ifdef DEBUG_SAVE
; ---------------------------------------------------------------------------
; RunSaveTest — package-H FRAME.BIN gate. Seed a new game, write the .dsv via
; SaveGameData, draw the "SAVING..." + "<PLAYER> saved the game!" messages, dump
; FRAME.BIN. Never returns. In: EBP = GB base. Call from EnterMap after overworld.
; ---------------------------------------------------------------------------
RunSaveTest:
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call PrepareNewGameDebug                        ; seed party+bag+badges
    mov dword [text_row_stride], MSG_STRIDE
    call SaveGameData                               ; writes POKEMON.DSV
    call SV_Saving
    call DelayFrame
    call DelayFrame
    call sv_msg_drop
    call SV_GameSaved
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer                             ; writes FRAME.BIN + exits
.hang:
    jmp .hang
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
%endif
