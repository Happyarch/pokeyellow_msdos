; ===========================================================================
; save.asm — the SAVE / LOAD / CHANGE-BOX / Hall-of-Fame save layer.
; menus-port Session 7, package H. Faithful port of pret engine/menus/save.asm.
;
; This provides the START->SAVE flow, the LOAD side package E depends on
; (TryLoadSaveFile), Bill's PC box-storage back end, and the in-memory SRAM image.
;
; PORT MODEL (CLAUDE.md + current_plan_sram_pc_storage stages 1-4):
;  * SM83->x86: A=AL, BC=BX, DE=DX, HL=ESI, EBP = GB base; GB memory at [EBP+sym].
;  * SRAM is resident and flat. Bank 0 remains at $A000-$BFFF for the pic decoder's
;    16-bit wSpriteInputPtr contract; banks 1-3 live at $22000, $24000, $26000.
;    rRAMB/rRAMG/rBMODE writes are annotated no-ops, and any copy touching the
;    extended banks uses SramCopyData32 rather than widening pret CopyData.
;  * The stage-5 disk boundary is deliberately only a seam here: boot calls
;    SramLoadImage, and SaveGameData/ClearAllSRAMBanks call SramStoreImage after
;    updating resident memory. The ret-stubs live in src/save/save_stubs.asm and
;    dsv_io.asm is left untouched for the maintainers.
;  * Checksums are faithful SRAM checksums: sMainDataCheckSum covers sGameData,
;    box-bank all-box checksums cover the six box payloads in that bank, and the
;    individual checksum arrays hold one checksum per box.
;  * TEXT (row 19 part 1, M-97): the SAVE/LOAD messages are pret's own text_far
;    streams (Tier-1 data in assets/save_text.inc, generated from data/text/
;    text_4.asm) printed by PrintText through the msgbox_dialog projection.
;  * The "Would you like to SAVE?" yes/no is pret's own TWO_OPTION_MENU box:
;    wTextBoxID = TWO_OPTION_MENU + DisplayTextBoxID, at pret's own hlcoord 0,7 /
;    lb bc,8,1, projected through yn_box state.
;  * SFX_SAVE / PlaySoundWaitForCurrent / WaitForSoundToFinish are REAL in the port
;    (src/home/audio.asm + assets/audio_constants.inc; pc.asm plays its PC jingles
;    through them). The save jingle is restored.
;  * CHANGE-BOX TEXT (row 19 part 2, M-101): WhenYouChangeBoxText / ChooseABoxText /
;    BoxNames / BoxNoText are pret's own labels with pret's own bodies (Tier-1 data
;    in assets/save_text.inc). _WhenYouChangeBoxText's `para` page break is executed
;    by the text engine.
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
extern DelayFrame               ; src/home/vblank.asm
extern DelayFrames              ; src/home/delay.asm — BL = frame count (pret's ld c,n)
extern PrintText                ; home/window.asm — In: ESI = text stream
extern text_msgbox              ; home/text.asm — the active msgbox projection
extern msgbox_dialog            ; home/text.asm — the standard bottom dialog box
extern DisplayTextBoxID         ; home/textbox.asm — [wTextBoxID] box (TWO_OPTION_MENU)
extern PlaySoundWaitForCurrent  ; src/home/delay.asm — In: AL = sound id
extern WaitForSoundToFinish     ; src/home/delay.asm
; --- generic engine seams ---------------------------------------------------
; (pret's CopyData / AddNTimes SRAM operations are realized locally with
;  SramCopyData32 and direct address arithmetic, so neither helper is externed.)
extern UpdateSprites            ; src/home/update_sprites.asm
extern SetMapTextPointer        ; home/predef_text.asm
extern RestoreMapTextPointer    ; home/predef_text.asm
extern ClearScreen              ; home/copy2.asm
extern LoadFontTilePatterns     ; gfx/load_font.asm
extern LoadTextBoxTilePatterns  ; gfx/load_font.asm
; --- the S3 YES/NO driver (home/yes_no.asm) --------------------------------
extern YesNoChoice              ; home/yes_no.asm — ChangeBox's confirm
extern yn_box_col               ; home/yes_no.asm — two-option box top-left, GB X
extern yn_box_row               ; home/yes_no.asm — two-option box top-left, GB Y
extern yn_proj_mode             ; home/yes_no.asm — 0 = overworld anchor
; --- raw SRAM image seam (stage 5 body, stage 4 ret-stub) -------------------
extern SramStoreImage           ; src/save/dsv_io.asm — SRAM banks -> POKEMON.DSV
; --- legacy .dsv debug harness helpers (not used by the pret save routines) ---
extern DsvFileExists            ; src/save/dsv_io.asm — DEBUG_SAVE_ROUNDTRIP marker
extern FillMemory               ; src/home/copy2.asm — ESI dest, BX count, AL value

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

%ifdef DEBUG_CONTINUE_SEED
; ---------------------------------------------------------------------------
; RunContinueSeedTest — menu-intro A3 continue_seed gate.
;
; Proves the CONTINUE path PRESERVES loaded state and does not re-seed. It seeds
; the deterministic debug save (matching seed.lua), writes it to disk, ZEROES the
; live save WRAM, then loads it back with TryLoadSaveFile -- the exact load
; MainMenu's save-present branch runs before .choseContinue. The clobber is what
; makes this a real load test: without it the "loaded" bytes could be leftover
; seed. If the dumped WRAM matches the seed spec, the load repopulated every
; saved region from the file.
;
; It deliberately calls NEITHER OakSpeech NOR InitPlayerData2 -- the continue path
; calls neither, and re-seeding would defeat the test. TryLoadSaveFile is the
; whole flow.
;
; In: EBP = GB base. Called from EnterMap (SKIP_TITLE boot).
; ---------------------------------------------------------------------------
extern PrepareNewGameDebug          ; engine/debug/debug_party.asm
extern SeedDeterministicPlayerIdentity ; engine/debug/debug_party.asm — "RED"/id 0 (seed.lua)
extern DumpBackbuffer               ; debug/debug_dump.asm
global RunContinueSeedTest

RunContinueSeedTest:
    ; 1. Seed the deterministic save (party+bag+money+badges+dex, then RED/id 0).
    call PrepareNewGameDebug
    call SeedDeterministicPlayerIdentity

    ; 2. Commit it through the real save path: WRAM -> resident SRAM banks
    ;    (SaveMainData/SaveCurrentBoxData/SavePartyAndDexData) and on to
    ;    POKEMON.DSV via SramStoreImage. That is what a player's SAVE does, so
    ;    the load below reads exactly what a real save wrote.
    call SaveGameData

    ; 3. Clobber the WRAM the save owns, so a successful load has to restore it
    ;    rather than finding it already correct.
    lea edi, [ebp + wPlayerName]
    mov ecx, NAME_LENGTH
    xor al, al
    rep stosb
    lea edi, [ebp + wMainDataStart]
    mov ecx, wMainDataEnd - wMainDataStart
    rep stosb
    lea edi, [ebp + wBoxDataStart]
    mov ecx, wBoxDataEnd - wBoxDataStart
    rep stosb
    lea edi, [ebp + wPartyDataStart]
    mov ecx, wPartyDataEnd - wPartyDataStart
    rep stosb

    ; 4. Load it back the way CONTINUE does: TryLoadSaveFile reads the resident
    ;    SRAM banks step 2 wrote and verifies their checksums.
    call TryLoadSaveFile

    ; 5. Photograph the loaded WRAM.
    call DumpBackbuffer                 ; never returns
.hang:
    jmp .hang
%endif

%ifdef DEBUG_REAL_SAVE
; ---------------------------------------------------------------------------
; RunRealSaveTest — save_real_load gate.
;
; The counterpart to RunContinueSeedTest, with a REAL cartridge save in place of
; the synthetic seed. goldencheck.sh converts tests/fixtures/yellow_100.sav into
; POKEMON.DSV and stages it in the disk image, so by the time this runs boot has
; already scattered that 32 KiB image into the resident SRAM banks
; (entry.asm -> SramLoadImage). Nothing here writes a save: the whole point is
; that the data originates OUTSIDE the port, on a real Game Boy.
;
; That makes it a different proof from continue_seed, which can only show the
; port round-trips its own bytes. This shows the port reads a save a real
; cartridge wrote -- a full 6-mon party, 151/151 Pokedex, a populated current
; box -- and lands every field where pret puts it. A byte-order or offset error
; that continue_seed cannot see (because it would be made and unmade
; symmetrically) diverges here against the mGBA golden.
;
; The stored boxes in the fixture are near-empty, so this is NOT box-bank
; coverage; the stage-6 deposit/withdraw scenario is still required.
;
; In: EBP = GB base. Called from EnterMap (SKIP_TITLE boot).
; ---------------------------------------------------------------------------
extern DumpBackbuffer               ; debug/debug_dump.asm
global RunRealSaveTest

RunRealSaveTest:
    ; 1. Clobber the WRAM the save owns. Boot loaded the fixture into the SRAM
    ;    banks, not into WRAM, but zeroing first is what makes the dump below
    ;    provably the product of the load rather than of anything earlier.
    lea edi, [ebp + wPlayerName]
    mov ecx, NAME_LENGTH
    xor al, al
    rep stosb
    lea edi, [ebp + wMainDataStart]
    mov ecx, wMainDataEnd - wMainDataStart
    rep stosb
    lea edi, [ebp + wBoxDataStart]
    mov ecx, wBoxDataEnd - wBoxDataStart
    rep stosb
    lea edi, [ebp + wPartyDataStart]
    mov ecx, wPartyDataEnd - wPartyDataStart
    rep stosb

    ; 2. Load it the way CONTINUE does: TryLoadSaveFile reads the resident SRAM
    ;    banks and verifies the checksums the real cartridge wrote.
    call TryLoadSaveFile

    ; 3. Photograph the loaded WRAM.
    call DumpBackbuffer                 ; never returns
.hang:
    jmp .hang
%endif

%ifdef DEBUG_BOX_SAVE
; ---------------------------------------------------------------------------
; RunBoxSaveTest — save_boxes_load gate.
;
; Same shape as RunRealSaveTest, pointed at a save whose PC boxes are FULL
; (tests/fixtures/yellow_boxes_full.sav: 20 mons in every one of the 12 boxes,
; built by tools/savegen from the real save). What it adds is the wBoxData
; comparison: the current-box block is the one save region the suite has never
; compared, so the whole box_struct layout -- the 33-byte stride, the species
; list and its $FF sentinel, the 20 OT names and 20 nicknames -- has had ZERO
; coverage until now.
;
; SCOPE, precisely: this proves the current-box block loads correctly from an
; externally-authored save. It does NOT exercise SRAM banks 2 and 3, because a
; CONTINUE load copies sCurBoxData (bank 1) into WRAM and never touches sBoxN.
; Reaching those needs ChangeBox, which needs the PC UI -- still stage 6's job.
;
; In: EBP = GB base. Called from EnterMap (SKIP_TITLE boot).
; ---------------------------------------------------------------------------
extern DumpBackbuffer               ; debug/debug_dump.asm
global RunBoxSaveTest

RunBoxSaveTest:
    lea edi, [ebp + wPlayerName]
    mov ecx, NAME_LENGTH
    xor al, al
    rep stosb
    lea edi, [ebp + wMainDataStart]
    mov ecx, wMainDataEnd - wMainDataStart
    rep stosb
    lea edi, [ebp + wBoxDataStart]
    mov ecx, wBoxDataEnd - wBoxDataStart
    rep stosb
    lea edi, [ebp + wPartyDataStart]
    mov ecx, wPartyDataEnd - wPartyDataStart
    rep stosb

    call TryLoadSaveFile
    call DumpBackbuffer                 ; never returns
.hang:
    jmp .hang
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
; Verifies sGameData's checksum, copies the saved name/main/sprite/current-box
; blocks from resident SRAM to WRAM, restores hTileAnimations, and marks the map
; tileset as freshly loaded. The GB rRAMB bank-select writes are no-ops in the
; flat resident SRAM model.
; DEVIATION{class=banking; pret=engine/menus/save.asm:LoadMainData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM sources above FFFF and ignore the rRAMB bank-select write; evidence=CopyData truncates DE destinations through DX and the resident SRAM design stores bank 1 at 22000; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
LoadMainData:
    call EnableSRAM
    ; ld a,BANK("Save Data") / ld [rRAMB],a — resident SRAM has fixed addresses.
    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    cmp al, [ebp + sMainDataCheckSum]
    jz .checkSumMatched

    ; If the computed checksum didn't match the saved one, try again.
    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    cmp al, [ebp + sMainDataCheckSum]
    jnz CheckSumFailed

.checkSumMatched:
    mov esi, sPlayerName
    mov edx, wPlayerName
    mov bx, NAME_LENGTH
    call SramCopyData32

    mov esi, sMainData
    mov edx, wMainDataStart
    mov bx, wMainDataEnd - wMainDataStart
    call SramCopyData32

    ; ld hl,wCurMapTileset / set BIT_NO_PREVIOUS_MAP,[hl]
    or byte [ebp + wCurMapTileset], 1 << BIT_NO_PREVIOUS_MAP

    mov esi, sSpriteData
    mov edx, wSpriteDataStart
    mov bx, wSpriteDataEnd - wSpriteDataStart
    call SramCopyData32

    ; ld a,[sTileAnimations] / ldh [hTileAnimations],a
    mov al, [ebp + sTileAnimations]
    mov [ebp + hTileAnimations], al

    ; this part is redundant, LoadCurrentBoxData is always called next
    mov esi, sCurBoxData
    mov edx, wBoxDataStart
    mov bx, wBoxDataEnd - wBoxDataStart
    call SramCopyData32

    clc
    jmp GoodCheckSum

; ---------------------------------------------------------------------------
; LoadCurrentBoxData — pret ref: engine/menus/save.asm:LoadCurrentBoxData.
; Re-verifies sGameData and copies sCurBoxData -> wBoxDataStart.
; DEVIATION{class=banking; pret=engine/menus/save.asm:LoadCurrentBoxData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM and ignore the rRAMB bank-select write; evidence=resident SRAM bank 1 lives at 22000 and CopyData is intentionally not widened; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
LoadCurrentBoxData:
    call EnableSRAM
    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    cmp al, [ebp + sMainDataCheckSum]
    jnz CheckSumFailed

    mov esi, sCurBoxData
    mov edx, wBoxDataStart
    mov bx, wBoxDataEnd - wBoxDataStart
    call SramCopyData32

    clc
    jmp GoodCheckSum

; ---------------------------------------------------------------------------
; LoadPartyAndDexData — pret ref: engine/menus/save.asm:LoadPartyAndDexData.
; Re-verifies sGameData, copies sPartyData -> wPartyDataStart, then restores the
; pokédex slice from sMainData.
; DEVIATION{class=banking; pret=engine/menus/save.asm:LoadPartyAndDexData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM and ignore the rRAMB bank-select write; evidence=resident SRAM bank 1 lives at 22000 and CopyData is intentionally not widened; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
LoadPartyAndDexData:
    call EnableSRAM
    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    cmp al, [ebp + sMainDataCheckSum]
    jnz CheckSumFailed

    mov esi, sPartyData
    mov edx, wPartyDataStart
    mov bx, wPartyDataEnd - wPartyDataStart
    call SramCopyData32

    mov esi, sMainData
    mov edx, wPokedexOwned
    mov bx, wPokedexSeenEnd - wPokedexOwned
    call SramCopyData32

    clc
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
    call DisableSRAM                             ; flat SRAM no-op, preserves CF
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
    ; The port's DisplayTwoOptionMenu (engine/menus/text_box.asm)
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
; engine/menus/save.asm. Each copies its WRAM slice into the resident SRAM save
; layout and refreshes sMainDataCheckSum. Disk persistence is the stage-5
; SramStoreImage seam called once by SaveGameData after all three slices commit.
; ---------------------------------------------------------------------------
SaveMainData:
    call EnableSRAM
    ; ld a,BANK("Save Data") / ld [rRAMB],a — resident SRAM has fixed addresses.
    ; DEVIATION{class=banking; pret=engine/menus/save.asm:SaveMainData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM destinations above FFFF and ignore the rRAMB bank-select write; evidence=CopyData truncates DE destinations through DX and sPlayerName through sCurBoxData live in bank 1 at 22598 and above; lifetime=permanent flat SRAM model}
    mov esi, wPlayerName
    mov edx, sPlayerName
    mov bx, NAME_LENGTH
    call SramCopyData32

    mov esi, wMainDataStart
    mov edx, sMainData
    mov bx, wMainDataEnd - wMainDataStart
    call SramCopyData32

    mov esi, wSpriteDataStart
    mov edx, sSpriteData
    mov bx, wSpriteDataEnd - wSpriteDataStart
    call SramCopyData32

    ; this part is redundant, SaveCurrentBoxData is always called next
    mov esi, wBoxDataStart
    mov edx, sCurBoxData
    mov bx, wBoxDataEnd - wBoxDataStart
    call SramCopyData32

    ; ldh a,[hTileAnimations] / ld [sTileAnimations],a
    mov al, [ebp + hTileAnimations]
    mov [ebp + sTileAnimations], al

    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    mov [ebp + sMainDataCheckSum], al
    call DisableSRAM
    ret

SaveCurrentBoxData:
    call EnableSRAM
    ; DEVIATION{class=banking; pret=engine/menus/save.asm:SaveCurrentBoxData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM destination sCurBoxData and ignore the rRAMB bank-select write; evidence=sCurBoxData lives at 230C0 above the 16-bit GB window and CopyData is intentionally not widened; lifetime=permanent flat SRAM model}
    mov esi, wBoxDataStart
    mov edx, sCurBoxData
    mov bx, wBoxDataEnd - wBoxDataStart
    call SramCopyData32

    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    mov [ebp + sMainDataCheckSum], al
    call DisableSRAM
    ret

SavePartyAndDexData:
    call EnableSRAM
    ; DEVIATION{class=banking; pret=engine/menus/save.asm:SavePartyAndDexData; behavior=use SramCopyData32 instead of pret CopyData for resident SRAM destination sPartyData and ignore the rRAMB bank-select write; evidence=sPartyData lives at 22F2C above the 16-bit GB window and CopyData is intentionally not widened; lifetime=permanent flat SRAM model}
    mov esi, wPartyDataStart
    mov edx, sPartyData
    mov bx, wPartyDataEnd - wPartyDataStart
    call SramCopyData32

    ; pokédex only: wPokedexOwned..wPokedexSeenEnd -> start of sMainData.
    mov esi, wPokedexOwned
    mov edx, sMainData
    mov bx, wPokedexSeenEnd - wPokedexOwned
    call SramCopyData32

    ; Preserve the two-byte Pikachu happiness field at its main-data offset.
    mov al, [ebp + wPikachuHappiness]
    mov [ebp + sMainData + (wPikachuHappiness - wMainDataStart)], al
    mov al, [ebp + wPikachuHappiness + 1]
    mov [ebp + sMainData + (wPikachuHappiness - wMainDataStart) + 1], al

    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    mov [ebp + sMainDataCheckSum], al
    call DisableSRAM
    ret

; ---------------------------------------------------------------------------
; SaveGameData — pret ref: engine/menus/save.asm:SaveGameData.
; DEVIATION{class=HAL; pret=engine/menus/save.asm:SaveGameData; behavior=after faithfully updating resident SRAM call SramStoreImage as the DOS disk-boundary seam instead of writing the disk from the pret-labeled slice routines; evidence=current_plan_sram_pc_storage stage 4 seam contract assigns SramStoreImage to the save-commit point and forbids editing dsv_io.asm; lifetime=until stage 5 supplies the raw SRAM image writer behind this seam}
; ---------------------------------------------------------------------------
SaveGameData:
    ; ld a,2 / ld [wSaveFileStatus],a
    mov byte [ebp + wSaveFileStatus], 2
    call SaveMainData
    call SaveCurrentBoxData
    call SavePartyAndDexData
    call SramStoreImage
    ret

; ---------------------------------------------------------------------------
; CalcCheckSum — pret ref: engine/menus/save.asm:CalcCheckSum.
; 8-bit additive fold, complemented. In: ESI=GB offset (HL), BX=length (BC).
; Out: AL. The source pointer is full 32-bit so resident SRAM above $FFFF is safe.
; ---------------------------------------------------------------------------
CalcCheckSum:
    movzx ecx, bx
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

; ---------------------------------------------------------------------------
; SramCopyData32 — port-only copy helper for resident SRAM endpoints.
; In: ESI=source GB offset, EDX=dest GB offset, BX=count. Out: ESI and EDX advanced.
; This deliberately does NOT widen pret CopyData, whose DE destination is 16-bit.
; ---------------------------------------------------------------------------
SramCopyData32:
    push edi
    movzx ecx, bx
    lea esi, [ebp + esi]
    lea edi, [ebp + edx]
    rep movsb
    sub esi, ebp
    mov edx, edi
    sub edx, ebp
    pop edi
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
    call GetBoxSRAMLocation                        ; BH=bank, ESI=SRAM ptr
    mov edx, esi                                   ; ld e,l / ld d,h -> DX(de)=SRAM dest
    mov esi, wBoxDataStart                         ; ld hl,wBoxDataStart
    call CopyBoxToOrFromSRAM                        ; copy old box WRAM -> SRAM
    ; ld a,[wCurrentMenuItem] / set BIT_HAS_CHANGED_BOXES,a / ld [wCurrentBoxNum],a
    mov al, [ebp + wCurrentMenuItem]
    or al, 1 << 7                                  ; set BIT_HAS_CHANGED_BOXES
    mov [ebp + wCurrentBoxNum], al
    ; --- copy new box (SRAM) -> WRAM ---
    call GetBoxSRAMLocation                        ; ESI=SRAM src
    mov edx, wBoxDataStart                          ; ld de,wBoxDataStart
    call CopyBoxToOrFromSRAM                        ; copy new box SRAM -> WRAM
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
; Copy a full box between ESI(HL) and EDX(DE), mark the source box empty, then
; refresh the selected SRAM bank's all-box and individual-box checksums.
; DEVIATION{class=banking; pret=engine/menus/save.asm:CopyBoxToOrFromSRAM; behavior=use full 32-bit resident SRAM pointers and SramCopyData32 instead of MBC bank switching plus pret CopyData; evidence=box banks live at 24000 and 26000 so CopyData would truncate SRAM destinations through DX; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
CopyBoxToOrFromSRAM:
    push esi                                      ; source box to mark empty after copy
    push ebx                                      ; BH = selected SRAM bank 2 or 3
    call EnableSRAM
    ; ld a,b / ld [rRAMB],a — resident SRAM has fixed addresses.
    mov bx, wBoxDataEnd - wBoxDataStart
    call SramCopyData32
    pop ebx                                       ; restore BH bank selector
    pop esi                                       ; restore source box start

    ; mark the source box as an empty box: count 0, species sentinel $ff.
    xor al, al
    mov [ebp + esi], al
    dec al
    mov [ebp + esi + 1], al

    call calc_box_bank_checksums
    call DisableSRAM
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
; engine/menus/save.asm. Mark every saved box empty and refresh bank checksums.
; The rRAMB bank-select writes become BH=2/BH=3 in the resident model.
; DEVIATION{class=banking; pret=engine/menus/save.asm:EmptyAllSRAMBoxes; behavior=select resident box banks with BH instead of rRAMB and update their fixed EBP-relative storage; evidence=sBox1 through sBox12 are flat labels in gb_memmap.inc and no switchable SRAM window exists; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
EmptyAllSRAMBoxes:
    call EnableSRAM
    mov bh, 2
    call EmptySRAMBoxesInBank
    mov bh, 3
    call EmptySRAMBoxesInBank
    call DisableSRAM
    ret

EmptySRAMBoxesInBank:
    ; marks every box in BH's resident SRAM bank as empty.
    ; DEVIATION{class=banking; pret=engine/menus/save.asm:EmptySRAMBoxesInBank; behavior=derive the six box addresses from BH instead of the selected rRAMB window; evidence=resident SRAM gives bank 2 and bank 3 distinct full 32-bit addresses; lifetime=permanent flat SRAM model}
    call select_box_bank_base
    mov ecx, NUM_BOXES / 2
.emptyLoop:
    push ecx
    push esi
    call EmptySRAMBox
    pop esi
    add esi, wBoxDataEnd - wBoxDataStart
    pop ecx
    dec ecx
    jnz .emptyLoop
    call calc_box_bank_checksums
    ret

EmptySRAMBox:
    ; count 0, species sentinel $ff. The rest of the box payload is left as-is,
    ; matching pret's two-byte initialization.
    xor al, al
    mov [ebp + esi], al
    dec al
    mov [ebp + esi + 1], al
    ret

; ---------------------------------------------------------------------------
; GetMonCountsForAllBoxes — pret ref: engine/menus/save.asm.
; Fill wBoxMonCounts[0..NUM_BOXES-1] from resident SRAM, then overwrite the
; current box's slot from WRAM because the active box lives in wBoxDataStart.
; ---------------------------------------------------------------------------
GetMonCountsForAllBoxes:
    mov esi, wBoxMonCounts
    call EnableSRAM
    mov bh, 2
    call GetMonCountsForBoxesInBank
    mov bh, 3
    call GetMonCountsForBoxesInBank
    call DisableSRAM

    ; copy the count for the current box from WRAM.
    movzx eax, byte [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov cl, [ebp + wBoxCount]
    mov [ebp + eax + wBoxMonCounts], cl
    ret

GetMonCountsForBoxesInBank:
    ; In: ESI = destination wBoxMonCounts cursor, BH = resident bank 2 or 3.
    ; Out: ESI advanced by six counts.
    ; DEVIATION{class=banking; pret=engine/menus/save.asm:GetMonCountsForBoxesInBank; behavior=read counts from fixed resident bank addresses selected by BH instead of the current rRAMB window; evidence=sBox1 and sBox7 have distinct addresses in gb_memmap.inc; lifetime=permanent flat SRAM model}
    push esi                                      ; preserve destination cursor
    call select_box_bank_base                         ; ESI = first box in selected bank
    pop edi                                       ; EDI = destination cursor
    mov ecx, NUM_BOXES / 2
.countLoop:
    mov al, [ebp + esi]
    mov [ebp + edi], al
    inc edi
    add esi, wBoxDataEnd - wBoxDataStart
    dec ecx
    jnz .countLoop
    mov esi, edi                                  ; faithful HL cursor advance
    ret

; ---------------------------------------------------------------------------
; GetBoxSRAMLocation — pret ref: engine/menus/save.asm:GetBoxSRAMLocation.
; Out: BH = box SRAM bank, ESI = full 32-bit resident pointer to the box slot.
; DEVIATION{class=data-model; pret=engine/menus/save.asm:GetBoxSRAMLocation; behavior=BoxSRAMPointerTable stores dword EBP-relative addresses and GetBoxSRAMLocation loads the full dword instead of rebuilding a 16-bit HL pointer; evidence=resident boxes in banks 2 and 3 live at 24000 and 26000 above the GB 16-bit address range; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
GetBoxSRAMLocation:
    movzx eax, byte [ebp + wCurrentBoxNum]
    and al, 0x7F                                  ; BOX_NUM_MASK
    mov bh, 2                                      ; ld b,2
    cmp al, NUM_BOXES / 2
    jc .haveBank
    inc bh                                         ; inc b -> bank 3
    sub al, NUM_BOXES / 2
.haveBank:
    movzx eax, al
    mov esi, [BoxSRAMPointerTable + eax * 4]
    cmp bh, 3
    jne .ret
    add esi, sBox7 - sBox1                         ; same in-bank slot in bank 3
.ret:
    ret

section .data
align 4
BoxSRAMPointerTable:
    dd sBox1                                      ; sBox7 when BH=3
    dd sBox2                                      ; sBox8 when BH=3
    dd sBox3                                      ; sBox9 when BH=3
    dd sBox4                                      ; sBox10 when BH=3
    dd sBox5                                      ; sBox11 when BH=3
    dd sBox6                                      ; sBox12 when BH=3

section .text

; ---------------------------------------------------------------------------
; CalcIndividualBoxCheckSums — pret ref: engine/menus/save.asm.
; In: BH = resident SRAM bank 2 or 3. Computes the six per-box checksums for
; that bank. The all-box checksum is handled by calc_box_bank_checksums.
; DEVIATION{class=banking; pret=engine/menus/save.asm:CalcIndividualBoxCheckSums; behavior=select the bank 2 or bank 3 checksum destination from BH instead of relying on the current rRAMB window; evidence=flat SRAM has no banked A000 view and stores both checksum arrays at fixed addresses; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
CalcIndividualBoxCheckSums:
    call select_box_bank_regions                      ; ESI=first box, EDI=individual checksum array
    mov ecx, NUM_BOXES / 2
.loop:
    push ecx
    push esi
    push edi
    mov bx, wBoxDataEnd - wBoxDataStart
    call CalcCheckSum
    pop edi
    mov [ebp + edi], al
    inc edi
    pop esi
    add esi, wBoxDataEnd - wBoxDataStart
    pop ecx
    dec ecx
    jnz .loop
    ret

; calc_box_bank_checksums — port-only helper carrying the checksum tail pret
; writes inline in BOTH CopyBoxToOrFromSRAM and EmptySRAMBoxesInBank (the same
; four lines: all-box CalcCheckSum, store, CalcIndividualBoxCheckSums).
;
; The factoring is forced by the flat model, not chosen for tidiness: pret's two
; copies are textually identical because rRAMB makes sBox1/sBank2AllBoxesChecksum
; resolve to the same window addresses in either bank, while the port's banks
; have distinct 32-bit addresses and must select them from BH. Duplicating that
; selection at both sites is what this avoids. Lowercase by the port-local helper
; convention — it is NOT a pret label.
; In: BH = 2 or 3. Clobbers EAX/ECX/EDX/ESI/EDI.
calc_box_bank_checksums:
    push ebx                                      ; preserve BH for individual checksums
    call select_box_bank_regions                  ; ESI=first box, EDI=individual, EDX=all checksum
    push edx                                      ; CalcCheckSum uses DL as accumulator
    mov bx, sBank2AllBoxesChecksum - sBox1
    call CalcCheckSum
    pop edx
    mov [ebp + edx], al
    pop ebx
    jmp CalcIndividualBoxCheckSums

; select_box_bank_base — In BH=2/3, Out ESI=sBox1 or sBox7.
select_box_bank_base:
    cmp bh, 3
    je .bank3
    mov esi, sBox1
    ret
.bank3:
    mov esi, sBox7
    ret

; select_box_bank_regions — In BH=2/3, Out ESI=first box, EDI=individual sums, EDX=all sum.
select_box_bank_regions:
    cmp bh, 3
    je .bank3
    mov esi, sBox1
    mov edi, sBank2IndividualBoxChecksums
    mov edx, sBank2AllBoxesChecksum
    ret
.bank3:
    mov esi, sBox7
    mov edi, sBank3IndividualBoxChecksums
    mov edx, sBank3AllBoxesChecksum
    ret

; ---------------------------------------------------------------------------
; CheckPreviousSaveFile — pret ref: engine/menus/save.asm:CheckPreviousSaveFile.
; Returns Z set for no saved player name or a matching saved wPlayerID, Z clear
; when a valid save belongs to a different playthrough.
; DEVIATION{class=banking; pret=engine/menus/save.asm:CheckPreviousSaveFile; behavior=read sPlayerName and the saved player ID from resident SRAM bank 1 instead of selecting BANK Save Data through rRAMB; evidence=sPlayerName and sMainData are fixed 32-bit labels in gb_memmap.inc and no switchable SRAM window exists; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
CheckPreviousSaveFile:
    call EnableSRAM
    ; ld a,BANK("Save Data") / ld [rRAMB],a — resident SRAM has fixed addresses.
    mov al, [ebp + sPlayerName]
    test al, al
    jz .next                                      ; no save data -> Z set

    mov esi, sGameData
    mov bx, sGameDataEnd - sGameData
    call CalcCheckSum
    cmp al, [ebp + sMainDataCheckSum]
    jnz .next                                     ; checksum mismatch -> NZ, matching pret branch flags

    ; saved player ID is big-endian in sMainData at the wPlayerID offset.
    mov al, [ebp + sMainData + (wPlayerID - wMainDataStart)]
    cmp al, [ebp + wPlayerID]
    jne .next
    mov al, [ebp + sMainData + (wPlayerID - wMainDataStart) + 1]
    cmp al, [ebp + wPlayerID + 1]
.next:
    call DisableSRAM                              ; preserves ZF
    ret

; ###########################################################################
; # HALL OF FAME
; ###########################################################################

; ---------------------------------------------------------------------------
; SaveHallOfFameTeams — pret ref: engine/menus/save.asm:SaveHallOfFameTeams.
; Append wHallOfFame as the next HoF team, or shift the resident sHallOfFame
; ring down and overwrite the last slot when full.
; DEVIATION{class=banking; pret=engine/menus/save.asm:SaveHallOfFameTeams; behavior=compute sHallOfFame slot addresses directly in flat resident SRAM instead of using AddNTimes in a selected SRAM bank; evidence=sHallOfFame remains at pret bank 0 address A598 and the port has no switchable SRAM window; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
SaveHallOfFameTeams:
    movzx eax, byte [ebp + wNumHoFTeams]
    dec al
    cmp al, HOF_TEAM_CAPACITY
    jnc .shiftHOFTeams

    movzx eax, al
    imul edx, eax, HOF_TEAM
    add edx, sHallOfFame
    mov esi, wHallOfFame
    mov bx, HOF_TEAM
    jmp HallOfFame_Copy

.shiftHOFTeams:
    ; if the space designated for HOF teams is full, shift all HOF teams to the
    ; next slot, making space for the new HOF team and deleting the oldest.
    mov esi, sHallOfFame + HOF_TEAM
    mov edx, sHallOfFame
    mov bx, HOF_TEAM * (HOF_TEAM_CAPACITY - 1)
    call HallOfFame_Copy
    mov esi, wHallOfFame
    mov edx, sHallOfFame + HOF_TEAM * (HOF_TEAM_CAPACITY - 1)
    mov bx, HOF_TEAM
    jmp HallOfFame_Copy

; ---------------------------------------------------------------------------
; LoadHallOfFameTeams — pret ref: engine/menus/save.asm:LoadHallOfFameTeams.
; Load the wHoFTeamIndex'th HoF team from resident sHallOfFame into wHallOfFame.
; DEVIATION{class=banking; pret=engine/menus/save.asm:LoadHallOfFameTeams; behavior=compute the sHallOfFame source slot directly in flat resident SRAM instead of using AddNTimes in bank 0; evidence=sHallOfFame is a fixed EBP-relative bank 0 label and CopyData is not widened for SRAM endpoints; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
LoadHallOfFameTeams:
    movzx eax, byte [ebp + wHoFTeamIndex]
    imul esi, eax, HOF_TEAM
    add esi, sHallOfFame
    mov edx, wHallOfFame
    mov bx, HOF_TEAM
    ; fallthrough

; ---------------------------------------------------------------------------
; HallOfFame_Copy — pret ref: engine/menus/save.asm:HallOfFame_Copy.
; In: ESI=source, EDX=dest, BX=len. One or both endpoints may be SRAM.
; DEVIATION{class=banking; pret=engine/menus/save.asm:HallOfFame_Copy; behavior=copy through full 32-bit resident SRAM addresses with SramCopyData32 instead of selecting bank 0 and calling pret CopyData; evidence=sHallOfFame is in SRAM and future bank 1 through 3 labels exceed FFFF while CopyData remains 16-bit for DE; lifetime=permanent flat SRAM model}
; ---------------------------------------------------------------------------
HallOfFame_Copy:
    call EnableSRAM
    ; xor a / ld [rRAMB],a — bank 0 is resident at $A000.
    call SramCopyData32
    call DisableSRAM
    ret

; ---------------------------------------------------------------------------
; ClearAllSRAMBanks — pret ref: engine/menus/save.asm:ClearAllSRAMBanks.
; Fill all four SRAM banks with $ff, then call the stage-5 store seam so a real
; disk body can persist the erase.
; DEVIATION{class=HAL; pret=engine/menus/save.asm:ClearAllSRAMBanks; behavior=after erasing resident SRAM call SramStoreImage as the DOS disk-boundary seam; evidence=current_plan_sram_pc_storage stage 4 owns in-memory SRAM and stage 5 owns raw image persistence; lifetime=until stage 5 supplies the raw SRAM image writer behind this seam}
; ---------------------------------------------------------------------------
ClearAllSRAMBanks:
    call EnableSRAM
    ; pret loops the four banks through rRAMB and jp FillMemory's each one. The
    ; port keeps FillMemory (its destination is HL/ESI, 32-bit, so the resident
    ; banks are reachable) and needs only two calls: bank 0 in the GB window,
    ; then banks 1-3 contiguous above it.
    mov al, 0xFF                                  ; ld a,$ff
    mov esi, GB_SRAM_BANK0                        ; ld hl, STARTOF(SRAM)
    mov bx, GB_SRAM_BANK_SIZE                     ; ld bc, SIZEOF(SRAM)
    call FillMemory
    mov al, 0xFF
    mov esi, GB_SRAM_BANK1
    mov bx, GB_SRAM_END - GB_SRAM_BANK1
    call FillMemory
    call DisableSRAM
    call SramStoreImage
    ret

; ---------------------------------------------------------------------------
; EnableSRAM / DisableSRAM — pret ref: engine/menus/save.asm.
; DEVIATION{class=banking; pret=engine/menus/save.asm:EnableSRAM; behavior=flat resident SRAM has no MBC RAM gate so EnableSRAM is a no-op; evidence=all SRAM bank labels are fixed EBP-relative addresses in gb_memmap.inc and no switchable A000 window exists; lifetime=permanent flat SRAM model}
; DEVIATION{class=banking; pret=engine/menus/save.asm:DisableSRAM; behavior=flat resident SRAM has no MBC RAM gate so DisableSRAM is a flag-preserving no-op; evidence=all SRAM bank labels are fixed EBP-relative addresses in gb_memmap.inc and no switchable A000 window exists; lifetime=permanent flat SRAM model}
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
    call SaveGameData                               ; WRAM -> SRAM -> POKEMON.DSV
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
