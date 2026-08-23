; ===========================================================================
; hall_of_fame.asm — the Hall of Fame sequence. Faithful mirror of pret
; engine/movie/hall_of_fame.asm, all 17 of its labels.
;
; The file was entirely unported until now (0 of 17 translated), and it had a LIVE
; consumer waiting on it: LeaguePCShowMon (engine/menus/league_pc.asm) farjps to
; Func_7033f, which was a ret-only seam stub in league_pc_stubs.asm. That stub is
; retired by this file — the POKéMON LEAGUE PC's per-mon screen now draws its info
; box and plays the cry, as pret does.
;
; Every callee this file needs was already translated; nothing new is stubbed.
;
; ---------------------------------------------------------------------------
; SCREEN PROJECTION — this is an engine/movie/ screen, so it uses the CINEMATIC
; SURFACE, not a bare canvas layout. MovieBeginSurface publishes a 160x144 GB
; window centred at canvas tile (10,3) with a colour-zero matte around it;
; MovieMirrorSurface copies the drawn rectangle from the stride-40 canvas into the
; stride-32 GB tilemap the compositor samples; MovieSyncScroll presents hSCX/hSCY
; as the window's fine source offset, which is what makes the pic slide read as a
; GB scroll instead of the whole canvas moving. All of that lives in
; engine/movie/movie_projection.asm, whose own class=projection annotation covers
; every cinematic screen, this one included — see its header.
;
; scoord() below is that same (+10,+3) origin, so what this file draws lands
; inside the published window. Do NOT copy engine/menus/league_pc.asm's stride-20
; form: it writes wTileMap + y*20 + x, which on a 40-wide canvas walks diagonally,
; and its own header records the result as UNVERIFIED.
;
; MEASURED, because the first cut of this file got it wrong: without the surface
; the ceremony composes a perfectly correct wTileMap that is never displayed —
; render_bg keeps compositing the overworld from wSurroundingTiles, and since
; LoadFrontSpriteByMonIndex / LoadMonBackPic overwrite vChars2 $9000-$9620 (which
; is vTileset on the overworld) the result is the map drawn with pic bytes for
; tiles. The GBSTATE tilemap read correct while the pixels were garbage; only
; rendering FRAME.BIN showed it. A correct tilemap is not a displayed screen.
;
; The port publishes text_row_stride = SCREEN_WIDTH for the ceremony and restores
; 20 on exit: TextBoxBorder, PlaceString and PrintMonType take their row step from
; that runtime value where pret uses a fixed SCREEN_WIDTH literal. Leaving it at
; 20 shears every box — also measured here.
;
; NOT COVERED BY ANY GOLDEN SCENARIO, and that is stated rather than glossed: the
; Hall of Fame is reachable only after beating the Champion, and no scenario gets
; there. DEBUG_HOF=1 (RunHallOfFameTest at the end of this file) is the runtime
; evidence available for it.
;
; Register map (CLAUDE.md): A=AL, BC=BX (B=BH, C=BL), DE=EDX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;        src/engine/movie/hall_of_fame.asm
; ===========================================================================
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"
%include "gb_text.inc"
%include "assets/event_constants.inc"   ; EVENT_* bit indices
%include "events.inc"                   ; CheckEvent/SetEvent/ResetEvent over wEventFlags
%include "assets/audio_constants.inc"   ; MUSIC_HALL_OF_FAME + its bank

%define FW SCREEN_WIDTH                             ; 40 — wTileMap row stride
%define scoord(x,y) (wTileMap + ((y)+3)*FW + ((x)+10))

RED_PIC_LEN    equ 255               ; gfx/player/red.pic byte length (as oak_speech.asm)

global AnimateHallOfFame
global HoFShowMonOrPlayer
global HoFDisplayAndRecordMonInfo
global Func_7033f
global HoFDisplayMonInfo
global HoFLoadPlayerPics
global HoFLoadMonPlayerPicTileIDs
global HoFDisplayPlayerStats
global HoFPrintTextAndDelay
global HoFRecordMonInfo
global HoFFadeOutScreenAndMusic

%ifdef DEBUG_HOF
global RunHallOfFameTest
%endif

extern ClearScreen                  ; home/copy2.asm
extern DelayFrame                   ; home/vblank.asm
extern DelayFrames                  ; home/delay.asm — BL = frame count
extern LoadFontTilePatterns         ; home/load_font.asm
extern LoadTextBoxTilePatterns      ; home/load_font.asm
extern DisableLCD                   ; home/lcd.asm
extern EnableLCD                    ; home/lcd.asm
extern FillMemory                   ; home/copy2.asm — ESI=dest, BX=count, AL=value
extern PlayMusic                    ; home/audio.asm
extern AddNTimes                    ; home/array.asm
extern TextBoxBorder                ; home/textbox.asm — ESI=top-left, BH=int_h, BL=int_w
extern PlaceString                  ; home/text.asm — EAX=flat src, ESI=dest
extern text_row_stride              ; home/text.asm — live wTileMap row stride
extern MovieBeginSurface            ; engine/movie/movie_projection.asm — take the screen
extern MovieEndSurface              ;   hand it back
extern MovieMirrorSurface           ;   stride-40 canvas -> stride-32 GB tilemap
extern MovieSyncScroll              ;   hSCX/hSCY -> the window's fine source offset
extern PrintText                    ; home/window.asm — ESI = flat text stream
extern PrintNumber                  ; home/print_num.asm
extern PrintBCDNumber               ; home/print_bcd.asm
extern PrintLevelCommon             ; home/pokemon.asm
extern GBFadeOutToWhite             ; home/fade.asm
extern GetMonHeader                 ; home/pokemon.asm
extern GetPartyMonName              ; home/pokemon.asm
extern LoadFrontSpriteByMonIndex    ; home/pokemon.asm
extern LoadMonBackPic               ; engine/battle/init_battle.asm (pret predef)
extern ScaleSpriteByTwo             ; engine/battle/scale_sprites.asm (pret predef)
extern CopyTileIDsFromList          ; engine/battle/animations.asm (pret predef_jump)
extern PrintMonType                 ; engine/battle/print_type.asm (pret predef)
extern DisplayDexRating             ; engine/events/pokedex_rating.asm (pret predef)
extern RunPaletteCommand            ; home/palettes.asm — BH = palette command
extern UpdateCGBPal_BGP             ; home/cgb_palettes.asm
extern PlayCry                      ; home/pokemon.asm
extern IsThisPartyMonStarterPikachu ; engine/pikachu/pikachu_status.asm
extern PlayPikachuSoundClip         ; audio/pikachu_pcm.asm — DL = 0-based clip index
extern UncompressSpriteFromDE       ; home/tilemap.asm
extern InterlaceMergeSpriteBuffers  ; home/pics.asm
extern OpenSRAM                     ; home/bankswitch2.asm
extern CloseSRAM                    ; home/bankswitch2.asm
extern CopyData                     ; home/copy.asm — ESI=src, EDX=dest, BX=count
extern SaveHallOfFameTeams          ; engine/menus/save.asm
extern RedPicFront                  ; data/trainer_pics.asm (= PlayerPicFront)
extern RedPicBack                   ; engine/battle/core.asm — the pret gfx/pics.asm
extern RedPicBack_len               ;   blob, shared with LoadPlayerBackPic

section .data
align 4
; Tier-1 DATA: the four PlaceString literals and the two text_far streams.
%include "assets/hall_of_fame_text.inc"

section .text

; ---------------------------------------------------------------------------
; AnimateHallOfFame — pret engine/movie/hall_of_fame.asm:1. The whole ceremony:
; fade out, clear, show each party mon with its info box, record the team to
; wHallOfFame, save it, then show the player and the dex rating.
; ---------------------------------------------------------------------------
AnimateHallOfFame:
    call HoFFadeOutScreenAndMusic
    call ClearScreen
    ; PUBLISH THE CANVAS STRIDE. TextBoxBorder, PlaceString and PrintMonType all
    ; step rows by the runtime [text_row_stride] — 20 for the GB-shaped menu
    ; scratch, 40 for the flat canvas — and this screen is laid out on the canvas
    ; via scoord(). Leaving it at 20 does not merely shift the layout: the box
    ; borders wrap mid-row and the whole screen shears. Measured 2026-08-23 with
    ; the DEBUG_HOF harness before this line existed. pret has no counterpart;
    ; its stride is the fixed SCREEN_WIDTH literal. Restored to 20 on the way out.
    mov dword [text_row_stride], FW
    call MovieBeginSurface              ; PORT: cinematic surface + matte + clip
    call MovieMirrorSurface             ; PORT: publish what has been drawn
    mov bl, 100                         ; ld c, 100
    call DelayFrames
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call DisableLCD
    mov esi, vBGMap0                    ; ld hl, vBGMap0
    mov bx, 2 * TILEMAP_AREA            ; ld bc, 2 * TILEMAP_AREA
    mov al, 0x7F                        ; ld a, ' '
    call FillMemory
    call EnableLCD
    or byte [ebp + IO_LCDC], LCDC_BG_MAP    ; set B_LCDC_BG_MAP, [hl]
    xor al, al
    mov esi, wHallOfFame                ; ld hl, wHallOfFame
    mov bx, HOF_TEAM                    ; ld bc, HOF_TEAM
    call FillMemory                     ; clear the team record
    xor al, al
    mov [ebp + wUpdateSpritesEnabled], al
    mov [ebp + hTileAnimations], al
    mov [ebp + wSpriteFlipped], al
    mov [ebp + wLetterPrintingDelayFlags], al   ; no delay
    mov [ebp + wHoFMonOrPlayer], al             ; mon
    inc al
    mov [ebp + hAutoBGTransferEnabled], al
    ; pret: ld hl, wNumHoFTeams / ld a,[hl] / inc a / jr z,.skipInc / inc [hl].
    ; The `inc a` is a SATURATION TEST, not a store — it checks for $FF so the
    ; count does not wrap to 0. A is discarded either way.
    mov al, [ebp + wNumHoFTeams]
    inc al
    jz .skipInc                         ; don't wrap around to 0
    inc byte [ebp + wNumHoFTeams]
.skipInc:
    mov byte [ebp + hWY], 0x90          ; window off-screen
    mov bl, MUSIC_HALL_OF_FAME_BANK     ; ld c, BANK(Music_HallOfFame)
    mov al, MUSIC_HALL_OF_FAME
    call PlayMusic
    mov esi, wPartySpecies              ; ld hl, wPartySpecies
    mov bl, 0xFF                        ; ld c, $ff  (pre-increment sentinel)
.partyMonLoop:
    mov al, [ebp + esi]                 ; ld a, [hli]
    inc esi
    cmp al, 0xFF
    je .doneShowingParty
    inc bl                              ; inc c — party index
    push esi                            ; push hl
    push ebx                            ; push bc
    mov [ebp + wHoFMonSpecies], al
    mov al, bl                          ; ld a, c
    mov [ebp + wHoFPartyMonIndex], al
    mov esi, wPartyMon1Level            ; ld hl, wPartyMon1Level
    mov bx, PARTYMON_STRUCT_LENGTH      ; ld bc, PARTYMON_STRUCT_LENGTH
    call AddNTimes
    mov al, [ebp + esi]                 ; ld a, [hl]
    mov [ebp + wHoFMonLevel], al
    call HoFShowMonOrPlayer
    call HoFDisplayAndRecordMonInfo
    call MovieMirrorSurface             ; PORT: the info box just landed
    mov bl, 80                          ; ld c, 80
    call DelayFrames
    mov esi, scoord(2, 13)              ; hlcoord 2, 13
    mov bh, 3                           ; lb bc, 3, 14
    mov bl, 14
    call TextBoxBorder
    mov esi, scoord(4, 15)              ; hlcoord 4, 15
    mov eax, HallOfFameText             ; ld de, HallOfFameText
    call PlaceString
    call MovieMirrorSurface             ; PORT: the HALL OF FAME banner just landed
    mov bl, 180                         ; ld c, 180
    call DelayFrames
    call GBFadeOutToWhite
    pop ebx                             ; pop bc
    pop esi                             ; pop hl
    jmp .partyMonLoop
.doneShowingParty:
    mov al, bl                          ; ld a, c
    inc al
    mov esi, wHallOfFame                ; ld hl, wHallOfFame
    mov bx, HOF_MON                     ; ld bc, HOF_MON
    call AddNTimes
    mov byte [ebp + esi], 0xFF          ; ld [hl], $ff — terminate the team record
    call SaveHallOfFameTeams            ; callfar (useless since in same bank)
    xor al, al
    mov [ebp + wHoFMonSpecies], al
    inc al
    mov [ebp + wHoFMonOrPlayer], al     ; player
    call HoFShowMonOrPlayer
    call HoFDisplayPlayerStats
    call MovieMirrorSurface             ; PORT: the player-stats screen just landed
    call HoFFadeOutScreenAndMusic
    mov byte [ebp + hWY], 0
    and byte [ebp + IO_LCDC], ~LCDC_BG_MAP & 0xFF   ; res B_LCDC_BG_MAP, [hl]
    mov dword [text_row_stride], 20     ; restore the menu/dialog scratch stride
    call MovieEndSurface                ; PORT: hand the screen to the next owner
    ret

; ---------------------------------------------------------------------------
; HoFShowMonOrPlayer — pret :96. Load the mon (or the player's) front and back
; pics and slide them on. wHoFMonOrPlayer picks which.
; ---------------------------------------------------------------------------
HoFShowMonOrPlayer:
    call ClearScreen
    mov byte [ebp + hSCY], 0xD0
    mov byte [ebp + hSCX], 0xC0
    mov al, [ebp + wHoFMonSpecies]
    mov [ebp + wCurPartySpecies], al
    mov [ebp + wCurSpecies], al
    mov [ebp + wBattleMonSpecies2], al
    mov [ebp + wWholeScreenPaletteMonSpecies], al
    mov al, [ebp + wHoFMonOrPlayer]
    test al, al
    jz .showMon
    call HoFLoadPlayerPics              ; show player
    jmp .next1
.showMon:
    mov esi, scoord(12, 5)              ; hlcoord 12, 5
    call GetMonHeader
    call LoadFrontSpriteByMonIndex
    call LoadMonBackPic                 ; predef LoadMonBackPic
.next1:
    mov bh, SET_PAL_POKEMON_WHOLE_SCREEN
    mov bl, 0
    call RunPaletteCommand
    mov byte [ebp + IO_BGP], 0xE4       ; ld a, %11100100 / ldh [rBGP], a
    call UpdateCGBPal_BGP
    mov bl, 0x31                        ; ld c, $31 — back pic base tile ID
    call HoFLoadMonPlayerPicTileIDs
    mov dh, 0xA0                        ; ld d, $a0 — stop offset
    mov dl, 4                           ; ld e, 4  — step
    mov al, [ebp + wOnSGB]
    test al, al
    jz .next2
    shl dl, 1                           ; sla e — scroll more slowly on SGB
.next2:
    call .ScrollPic                     ; scroll back pic left
    xor al, al
    mov [ebp + hSCY], al
    mov bl, al                          ; ld c, a — front pic base tile ID 0
    call HoFLoadMonPlayerPicTileIDs
    mov dh, 0                           ; ld d, 0
    mov dl, -4                          ; ld e, -4
    ; fall through — scroll front pic right

.ScrollPic:
    ; Mirror inside the loop, not once before it: HoFLoadMonPlayerPicTileIDs has
    ; just rewritten the pic's tile ids into the canvas, and ClearScreen wiped the
    ; canvas earlier in this routine. One memcpy of the 32x18 GB rectangle per
    ; frame is cheap and removes the question of which mutation happened last.
    call MovieMirrorSurface
    call DelayFrame
    mov al, [ebp + hSCX]
    add al, dl                          ; add e  (DL is a SIGNED step: +4 or -4)
    mov [ebp + hSCX], al
    call MovieSyncScroll                ; PORT: hSCX/hSCY -> the window source offset,
                                        ;   with the GB's own mod-256 wrap semantics
    cmp al, dh                          ; cp d
    jne .ScrollPic
    ret

; ---------------------------------------------------------------------------
; HoFDisplayAndRecordMonInfo — pret :146. Info box + cry, then record the mon.
; ---------------------------------------------------------------------------
HoFDisplayAndRecordMonInfo:
    mov al, [ebp + wHoFPartyMonIndex]
    mov esi, wPartyMonNicks             ; ld hl, wPartyMonNicks
    call GetPartyMonName
    call HoFDisplayMonInfo
    mov al, [ebp + wHoFPartyMonIndex]
    mov [ebp + wWhichPokemon], al
    call IsThisPartyMonStarterPikachu   ; callfar — CF set = it is Pikachu
    jnc .asm_70336
    ; ldpikacry e, PikachuCry35 lowers to a literal: pret's macro is
    ; `(X_id - PikachuCriesPointerTable) / 3`, a cross-object-file difference NASM
    ; cannot fold, and the table is strictly ordinal, so PikachuCryN is index N-1.
    ; Same lowering src/scripts/OaksLab.asm already uses for PikachuCry2 -> 1.
    mov dl, 34                          ; ldpikacry e, PikachuCry35
    call PlayPikachuSoundClip           ; callfar PlayPikachuSoundClip
    jmp .asm_7033c
.asm_70336:
    mov al, [ebp + wHoFMonSpecies]
    call PlayCry
.asm_7033c:
    jmp HoFRecordMonInfo

; ---------------------------------------------------------------------------
; Func_7033f — pret :164. The LEAGUE PC's per-mon half of the above: info box and
; cry, no recording. RETIRES the ret-only seam stub that stood in
; engine/menus/league_pc_stubs.asm; LeaguePCShowMon jmps here.
; ---------------------------------------------------------------------------
Func_7033f:
    call HoFDisplayMonInfo
    mov al, [ebp + wHoFMonSpecies]
    jmp PlayCry

; ---------------------------------------------------------------------------
; HoFDisplayMonInfo — pret :169. The nickname / LEVEL / TYPE1 / TYPE2 box.
; ---------------------------------------------------------------------------
HoFDisplayMonInfo:
    mov esi, scoord(0, 2)               ; hlcoord 0, 2
    mov bh, 9                           ; lb bc, 9, 10
    mov bl, 10
    call TextBoxBorder
    mov esi, scoord(2, 6)               ; hlcoord 2, 6
    mov eax, HoFMonInfoText             ; ld de, HoFMonInfoText
    call PlaceString
    mov esi, scoord(1, 4)               ; hlcoord 1, 4
    mov eax, ebp
    add eax, wNameBuffer                ; ld de, wNameBuffer — a WRAM string, so it
    call PlaceString                    ;   is named as a flat pointer for PlaceString
    mov al, [ebp + wHoFMonLevel]
    mov esi, scoord(8, 7)               ; hlcoord 8, 7
    call PrintLevelCommon
    mov al, [ebp + wHoFMonSpecies]
    mov [ebp + wCurSpecies], al
    mov esi, scoord(3, 9)               ; hlcoord 3, 9
    call PrintMonType                   ; predef PrintMonType
    ret

; ---------------------------------------------------------------------------
; HoFLoadPlayerPics — pret :196. Red's front and back pics into vFrontPic/vBackPic.
; Falls through into HoFLoadMonPlayerPicTileIDs with c = $1, as pret does.
; ---------------------------------------------------------------------------
HoFLoadPlayerPics:
    ; UncompressSpriteFromDE takes the flat pointer in EDX and, unlike pret, also a
    ; byte LENGTH in ECX — it stages the stream into the PIC_STAGE GB scratch first
    ; (see its data-model DEVIATION in src/home/tilemap.asm). pret needs no length
    ; because its stream is already GB-addressable.
    mov edx, RedPicFront                ; ld de, RedPicFront
    mov ecx, RED_PIC_LEN
    xor al, al                          ; ld a, BANK(RedPicFront) — flat: ignored
    call UncompressSpriteFromDE
    mov al, SRAM_BANK_SPRITE_BUFFERS    ; ld a, BANK("Sprite Buffers")
    call OpenSRAM
    mov esi, sSpriteBuffer1             ; ld hl, sSpriteBuffer1
    mov edx, sSpriteBuffer0             ; ld de, sSpriteBuffer0
    mov bx, 2 * SPRITEBUFFERSIZE        ; ld bc, 2 * SPRITEBUFFERSIZE
    call CopyData
    call CloseSRAM
    mov edx, vFrontPic                  ; ld de, vFrontPic
    call InterlaceMergeSpriteBuffers
    mov edx, RedPicBack                 ; ld de, RedPicBack
    mov ecx, RedPicBack_len
    xor al, al                          ; ld a, BANK(RedPicBack) — flat: ignored
    call UncompressSpriteFromDE
    call ScaleSpriteByTwo               ; predef ScaleSpriteByTwo
    mov edx, vBackPic                   ; ld de, vBackPic
    call InterlaceMergeSpriteBuffers
    mov bl, 0x01                        ; ld c, $1
    ; fall through

; ---------------------------------------------------------------------------
; HoFLoadMonPlayerPicTileIDs — pret :215. BL (c) = base tile ID.
; ---------------------------------------------------------------------------
HoFLoadMonPlayerPicTileIDs:
    mov bh, TILEMAP_MON_PIC             ; ld b, TILEMAP_MON_PIC
    mov esi, scoord(12, 5)              ; hlcoord 12, 5
    jmp CopyTileIDsFromList             ; predef_jump CopyTileIDsFromList

; ---------------------------------------------------------------------------
; HoFDisplayPlayerStats — pret :221. Name / play time / money box, then the two
; pokédex-rating messages and the rating itself.
; ---------------------------------------------------------------------------
HoFDisplayPlayerStats:
    SetEvent EVENT_HALL_OF_FAME_DEX_RATING
    call DisplayDexRating               ; predef DisplayDexRating
    mov esi, scoord(0, 4)               ; hlcoord 0, 4
    mov bh, 6                           ; lb bc, 6, 10
    mov bl, 10
    call TextBoxBorder
    mov esi, scoord(5, 0)               ; hlcoord 5, 0
    mov bh, 2                           ; lb bc, 2, 9
    mov bl, 9
    call TextBoxBorder
    mov esi, scoord(7, 2)               ; hlcoord 7, 2
    mov eax, ebp
    add eax, wPlayerName                ; ld de, wPlayerName (WRAM string -> flat ptr)
    call PlaceString
    mov esi, scoord(1, 6)               ; hlcoord 1, 6
    mov eax, HoFPlayTimeText            ; ld de, HoFPlayTimeText
    call PlaceString
    mov esi, scoord(5, 7)               ; hlcoord 5, 7
    mov edx, wPlayTimeHours             ; ld de, wPlayTimeHours
    mov bh, 1                           ; lb bc, 1, 3
    mov bl, 3
    call PrintNumber
    mov byte [ebp + esi], 0x6D          ; ld [hl], $6d — the ':' between h and m
    inc esi
    mov edx, wPlayTimeMinutes           ; ld de, wPlayTimeMinutes
    mov bh, LEADING_ZEROES | 1          ; lb bc, LEADING_ZEROES | 1, 2
    mov bl, 2
    call PrintNumber
    mov esi, scoord(1, 9)               ; hlcoord 1, 9
    mov eax, HoFMoneyText               ; ld de, HoFMoneyText
    call PlaceString
    mov esi, scoord(4, 10)              ; hlcoord 4, 10
    mov edx, wPlayerMoney               ; ld de, wPlayerMoney
    mov bl, 3 | LEADING_ZEROES | MONEY_SIGN ; ld c, 3 | LEADING_ZEROES | MONEY_SIGN
    call PrintBCDNumber
    mov esi, DexSeenOwnedText           ; ld hl, DexSeenOwnedText
    call HoFPrintTextAndDelay
    mov esi, DexRatingText              ; ld hl, DexRatingText
    call HoFPrintTextAndDelay
    ; pret: ld hl, wDexRatingText / fall through. That stream lives in WRAM —
    ; DisplayDexRating stages the whole flattened band text there (see the
    ; data-model DEVIATION in engine/events/pokedex_rating.asm) — so it is named
    ; as a flat pointer, which is what PrintText's In: contract takes.
    lea esi, [ebp + wDexRatingText]
    ; fall through

; ---------------------------------------------------------------------------
; HoFPrintTextAndDelay — pret :266. Print ESI, then hold for 120 frames.
; ---------------------------------------------------------------------------
HoFPrintTextAndDelay:
    call PrintText
    mov bl, 120                         ; ld c, 120
    jmp DelayFrames                     ; jp DelayFrames

; ---------------------------------------------------------------------------
; HoFRecordMonInfo — pret :287. Write species, level and nickname into the
; wHallOfFame slot for this party index.
; ---------------------------------------------------------------------------
HoFRecordMonInfo:
    mov esi, wHallOfFame                ; ld hl, wHallOfFame
    mov bx, HOF_MON                     ; ld bc, HOF_MON
    mov al, [ebp + wHoFPartyMonIndex]
    call AddNTimes
    mov al, [ebp + wHoFMonSpecies]
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    mov al, [ebp + wHoFMonLevel]
    mov [ebp + esi], al                 ; ld [hli], a
    inc esi
    mov edx, esi                        ; ld e, l / ld d, h
    mov esi, wNameBuffer                ; ld hl, wNameBuffer
    mov bx, NAME_LENGTH                 ; ld bc, NAME_LENGTH
    jmp CopyData                        ; jp CopyData

; ---------------------------------------------------------------------------
; HoFFadeOutScreenAndMusic — pret :301.
; ---------------------------------------------------------------------------
HoFFadeOutScreenAndMusic:
    mov al, 10
    mov [ebp + wAudioFadeOutCounterReloadValue], al
    mov [ebp + wAudioFadeOutCounter], al
    mov byte [ebp + wAudioFadeOutControl], 0xFF
    jmp GBFadeOutToWhite                ; jp GBFadeOutToWhite

%ifdef DEBUG_HOF
; ---------------------------------------------------------------------------
; RunHallOfFameTest — the only runtime evidence this file has, because no golden
; scenario reaches the Hall of Fame (it is behind the Champion).
;
; Seeds the font, then runs the real AnimateHallOfFame over whatever party
; DEBUG_SEED_PARTY built. AutoKeyDrive photographs the canvas at
; AUTOKEY_DUMP_FRAME and exits, so pick the frame for the moment you want:
; the ceremony spends 100 frames on the opening delay, then per mon roughly
; 80 frames on the info box + 180 on the "HALL OF FAME" banner.
;
;   dos_port/tools/run_headless.sh "DEBUG_HOF=1 AUTOKEY_DUMP_FRAME=<n>" /tmp/hof
;
; It does NOT return: AnimateHallOfFame ends by fading out, and there is no
; overworld to fall back into from here.
; In: EBP = GB base. Called from EnterMap once the overworld is set up.
; ---------------------------------------------------------------------------
RunHallOfFameTest:
    or byte [ebp + wFontLoaded], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call AnimateHallOfFame
    ; The ceremony ENDS — it is a movie, not a screen that waits for input — so
    ; park in the frame pipeline rather than a bare spin. A bare `jmp $` never calls
    ; DelayFrame, so the frame counter freezes and AutoKeyDrive's dump never fires;
    ; measured, on the first run of this harness.
.hang:
    call DelayFrame
    jmp .hang
%endif
