; debug_dump.asm — runtime ground-truth memory dump (debug builds only).
;
; Exfiltrates selected windows of emulated GB memory to a host file ("DUMP.BIN")
; so they can be hexdumped on the host. This bypasses the PPU/palette/blit
; entirely — the values written are the literal bytes in the GB address space,
; with no visual interpretation.
;
; Channel: DOS file I/O via the DPMI "Simulate Real Mode Interrupt" service
; (INT 31h AX=0300h). Under CWSDPMI a protected-mode `int 21h` with a DS:DX
; pointer is NOT auto-translated, so we allocate a conventional (<1 MB) DOS
; buffer (DPMI fn 0100h), stage the filename + data there, and reflect INT 21h
; AH=3Ch/40h/3Eh into real mode with the buffer's real-mode segment in DS.
;
; Wired in only under -D DEBUG_DUMP (see Makefile + overworld.asm EnterMap).
; After dumping, the program exits via INT 21h AH=4Ch — no game loop runs.
;
; Build: nasm -f coff -I include/ -I . -o debug_dump.o src/debug/debug_dump.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"

extern ds_base
%ifdef DEBUG_CALCSTATS
extern GetMonHeader
extern CalcStats
global RunCalcStatsTest
%endif
%ifdef DEBUG_PARTY
extern PrepareNewGameDebug
global RunPartySeedTest
%endif
%ifdef DEBUG_BAGMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StartMenu_Item
extern text_row_stride          ; text.asm — seeded to 40 to mirror the live path
global RunBagMenuTest
%endif
%ifdef DEBUG_PARTYMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StartMenu_Pokemon
global RunPartyMenuTest
%endif
%ifdef DEBUG_TEXTBOXID
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern DisplayTextBoxID
extern ClearSprites
extern hide_window
extern DelayFrame
global RunTextBoxIDTest
%endif
%ifdef DEBUG_LISTMENU
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern DisplayListMenuID
extern DelayFrame
global RunListMenuTest
%endif
%ifdef DEBUG_ITEMBALL
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
%endif
%ifdef DEBUG_ITEMTM
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern UseItem                  ; home/item.asm — the pret home wrapper for UseItem_
global RunTMHMTest
%endif
%ifdef DEBUG_BATTLE
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern InitBattle
extern DrawBattleIntroBox
extern SlideBattlePicsIn
extern DrawEnemyFrontPic_Stub
extern DrawPlayerRedBackPic_Stub
extern DrawBugCatcherPic_Stub
extern DrawPlayerBackPic_Stub
extern DrawBattleMenu
extern PrintMoveInfoBox
extern MainInBattleLoop          ; core.asm — faithful battle loop (replaces bespoke DisplayBattleMenu loop)
extern SaveBattleScreen
extern RestoreBattleScreen
extern EndBattleScreen
extern EndOfBattle               ; end_of_battle.asm — post-battle evolution + state reset
extern wBattleOver
extern WaitForAPress
extern DrawBattlePokeballs
extern HideBattlePokeballs
extern DrawBattleHUDs
extern DoEnemyAttackDamage
extern LoadWildMonMoves
extern SelectEnemyMove
extern GetCurrentMove
extern GetDamageVarsForPlayerAttack
extern CalculateDamage
extern AdjustDamageForMoveType
extern RandomizeDamage
extern DelayFrame
global RunBattleTest
%endif
%ifdef DEBUG_LEARNMOVE
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern LoadTextBoxTilePatterns
extern InitBattle
extern LearnMoveFromLevelUp
extern DelayFrame
global RunLearnMoveTest
%endif
%ifdef DEBUG_STATUS
extern PrepareNewGameDebug
extern LoadFontTilePatterns
extern StatusScreen
%ifdef DEBUG_STATUS_PAGE2
extern StatusScreen2
%endif
global RunStatusScreenTest
%endif
%ifdef DEBUG_AUDIO
%include "assets/audio_constants.inc"
extern PlayMusic
extern PlaySound
extern DelayFrame
extern opl_dbg_snapshot
extern midi_dbg_snapshot
extern PlayPikachuSoundClip
extern pika_dbg_snapshot
extern hal_dbg_snapshot
extern tandy_dbg_snapshot
extern spk_dbg_snapshot
extern enh_dbg_snapshot
extern g_cfg_musicloop            ; src/audio/audio_hal.asm — /LOOP
global RunAudioTest
%endif

global DebugDumpMemory
global DumpBackbuffer
global DumpGBState
%ifdef DEBUG_NPC_WALK
global DumpNpcLog
global npc_log
global npc_log_n
global dbg_destTile
%endif
%ifdef DEBUG_SEAM
global SeamLogRecord
global DumpSeamLog
%endif

; Each window is WIN_SIZE bytes copied from [EBP + window_offset].
; The host-side layout is simply these windows concatenated in table order.
WIN_SIZE     equ 0x40
NUM_WINDOWS  equ 9
DUMP_TOTAL   equ NUM_WINDOWS * WIN_SIZE          ; 9 * 64 = 576 bytes

; GBSTATE.BIN layout (fidelity harness, Session D): fixed regions after a
; 16-byte header, mirroring the golden dump regions (tools/mgba_harness/lib/
; dump.lua) except the tilemap, which is the port's full 40x25 canvas — the
; differ (golden_diff.py) extracts the 20x18 subwindow per scenario.
;   +0x00  magic "GBST", u8 version=1, u8 scenario id, 10 reserved (0)
;   +0x10  W_TILEMAP   0xC3A0, 1000 B (40x25, stride 40)
;   +0x3F8 VRAM        0x8000, 6144 B (tile data 0x8000-0x97FF)
;   +0x1BF8 OAM        0xFE00, 160 B
GBSTATE_VERSION  equ 1
GBSTATE_HDR_SIZE equ 16
GBSTATE_VRAM_SIZE equ 0x1800
GBSTATE_TOTAL    equ GBSTATE_HDR_SIZE + W_TILEMAP_SIZE + GBSTATE_VRAM_SIZE + GB_OAM_SIZE
; scenario id tag (sanity check only — the differ selects the golden by make
; target; ids: 0 other/unknown, 1 overworld (TRANSITION/BASELINE/WALK_NORTH),
; 2 STARTMENU, 3 STATUS, 4 STATUS_PAGE2, 5 PARTYMENU, 6 BAGMENU, 7 BATTLE)
%ifdef DEBUG_STATUS_PAGE2
GBSTATE_SCENARIO equ 4
%elifdef DEBUG_STATUS
GBSTATE_SCENARIO equ 3
%elifdef DEBUG_STARTMENU
GBSTATE_SCENARIO equ 2
%elifdef DEBUG_PARTYMENU
GBSTATE_SCENARIO equ 5
%elifdef DEBUG_BAGMENU
GBSTATE_SCENARIO equ 6
%elifdef DEBUG_BATTLE
GBSTATE_SCENARIO equ 7
%elifdef DEBUG_TRANSITION
GBSTATE_SCENARIO equ 1
%elifdef DEBUG_WALK_NORTH
GBSTATE_SCENARIO equ 1
%else
GBSTATE_SCENARIO equ 0
%endif

; DPMI real-mode call structure field offsets (DPMI 0.9 spec)
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

; ---------------------------------------------------------------------------
section .data
align 4

fname: db "DUMP.BIN", 0
fbname: db "FRAME.BIN", 0
fgbname: db "GBSTATE.BIN", 0
%ifdef DEBUG_NPC_WALK
fnlog: db "NPCLOG.BIN", 0
%endif
%ifdef DEBUG_SEAM
fseam: db "SEAMLOG.BIN", 0
%endif

; GB-address start of each 64-byte dump window. Host hexdump offsets:
;   0x000  overworld blockset (block 0..3)         — asset copy check
;   0x040  blockset entry for block 0x52           — DrawTileBlock src
;   0x080  PalletTown.blk (map block IDs)          — map asset copy
;   0x0C0  vTileset gfx in VRAM (tile 0,1,...)     — H2: tileset load
;   0x100  wOverworldMap start                     — LoadTileBlockMap
;   0x140  wSurroundingTiles                       — DrawTileBlock out
;   0x180  wTileMap (final view)                   — H1: tilemap
;   0x1C0  map header vars (curmap/dims/dataptr)   — header setup
;   0x200  tileset pointers (bank/blocks/gfx)      — pointer setup
; Addresses are the equs — the ROM window is allocator-packed (rom_window.inc)
; and moves whenever map data changes, so literals here WILL go stale.
%ifdef DEBUG_ITEMBALL
; ItemUseBall gate (items-plan Stage 6): the catch outcome + everything it mutates.
;   $D11B wCapturedMonSpecies (0 = not caught), $D11D wPokeBallAnimData
;         ($10 can't-catch / $20 miss / $61-$63 shakes / $43 caught)
;   $D162 wPartyCount + species list — a capture makes it 6 with the new species last
;   $D2FA party mon 6 struct — the caught mon (species, HP, level, DVs, catch rate)
;   $D31C bag: MASTER_BALL's qty must drop 99 → 98 (and only that slot changes)
;   $DA7F wBoxCount (must stay 0: the party had a free slot)
windows:
    dd 0xD11B    ; wCapturedMonSpecies / wPokeBallAnimData
    dd 0xD162    ; wPartyCount + wPartySpecies
    dd 0xD246    ; party mon 6 struct = wPartyMon1 + 5*44 ($D16A + 220) — the caught mon
    dd 0xD31C    ; wNumBagItems + (id,qty) pairs
    dd 0xDA7F    ; wBoxCount + wBoxSpecies
    dd 0xCFE4    ; wEnemyMon (species/HP/status — LoadEnemyMonData round-trip)
    dd 0xD2F6    ; wPokedexOwned (the caught species' bit must be set)
    dd 0xD309    ; wPokedexSeen
    dd 0xD11B    ; overview repeat
%elifdef DEBUG_ITEMTM
; Items-plan Stage 7 (DEBUG_ITEMTM) — teaching a TM/HM. Expectations:
;   $D16A party mon 1 struct — MON_MOVES (+$08) gains the machine's move; the PP
;         bytes (+$1D) get its base PP
;   $D0DF wMoveNum — the move TMToMove resolved from the machine
;   $D31C bag — a TM is consumed (count drops, slot 0 gone); an HM is NOT
;   $CD6A wActionResultOrTookBattleTurn — 2 = the player said no / it wasn't used
windows:
    dd 0xD16A    ; party mon 1 struct (species, HP, moves at +$08, PP at +$1D)
    dd 0xD31C    ; wNumBagItems + (id,qty) pairs — consumed (TM) or kept (HM)
    dd 0xD0DF    ; wMoveNum (+ wMovesString)
    dd 0xD11B    ; wTempTMHM / wNamedObjectIndex cluster ($D11D)
    dd 0xD162    ; wPartyCount + wPartySpecies
    dd 0xD2B4    ; wPartyMonNicks
    dd 0xCD6A    ; wActionResultOrTookBattleTurn
    dd 0xD035    ; wTempMoveNameBuffer / wLearnMoveMonName
    dd 0xD16A    ; overview repeat
%elifdef DEBUG_CALCSTATS
; CalcStats gate: one 64-byte window over the test scratch at $D1E0 covers the
; scratch mon (DVs at +$1B) and both stat results (L5 at +$20, L100 at +$30).
windows:
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
%elifdef DEBUG_PARTY
; Party-seed gate: party count + species list, the four seeded mon structs
; (44 B each from $D16A), party nicknames, and the bag (count + (id,qty) pairs).
windows:
    dd 0xD162    ; wPartyCount + wPartySpecies (6 + $FF) + start of mon1
    dd 0xD16A    ; party mon 1 struct (Snorlax)
    dd 0xD196    ; party mon 2 struct (Persian)  = $D16A + 44
    dd 0xD1C2    ; party mon 3 struct (Jigglypuff)
    dd 0xD1EE    ; party mon 4 struct (Pikachu)
    dd 0xD2B4    ; wPartyMonNicks (6 x 11)
    dd 0xD31C    ; wNumBagItems + bag (id,qty) pairs
    dd 0xD33C    ; bag items continued
    dd 0xD162    ; overview repeat
%elifdef DEBUG_WALKSPEED
; Walk-speed probe: one 64-byte window over the $D1E0 scratch holds the frame-rate
; measurement — +$00 start tick (dword), +$04 end tick, +$08 DelayFrame count.
; delta (end-start) == count → clean 60 Hz; delta < count → loop free-runs faster.
windows:
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
    dd 0xD1E0
%elifdef DEBUG_AUDIO
; Audio-engine gate: the whole engine RAM block + the virtual APU after 120
; ticks of Pallet Town BGM. Expected (music id $BA on CHAN1-3, tempo 160):
;   win1 $C026-2D = $BA,$BA,$BA,0,...   (wChannelSoundIDs)
;        $C006-0B = 3 in-blob LE pointers in $4000-$7FFF (command pointers)
;   win4 $C0C6 note speeds = 12; $C0E8/E9 wMusicTempo = $00,$A0 (big-endian)
;   win6 $FF10-26 nonzero pulse regs; $FF24 rAUDVOL = $77; $FF25 panning
windows:
    dd 0xC000    ; wSoundID/panning/vol, wChannelCommandPointers, ReturnAddrs, SoundIDs, Flags1/2
    dd 0xC040    ; duty patterns, vibrato arrays, freq low bytes, reload values
    dd 0xC080    ; pitch-slide arrays
    dd 0xC0B0    ; note delays, loop counters, speeds, octaves, volumes, tempos, ids, banks
    dd 0xC0F0    ; frequency/tempo modifiers
    dd 0xFF00    ; virtual APU: rAUD10-26 ($FF10-26) + wave RAM ($FF30-3F)
    dd 0xCFC0    ; fade block ($CFC6-C8) + wLastMusicSoundID ($CFC9)
    dd 0xD1E0    ; opl_dbg_snapshot: present, opl3, voice_state[0..61]
    dd 0xD220    ; SB detect (+0..6) + MIDI driver state (+7..: cfg,
                 ; present, active, on, dw progress, scale, cc7[16]);
                 ; $D240 pika PCM, $D246 shim device, $D248 tandy, $D250 spk, $D258 enh
%elifdef DEBUG_BATTLE
windows:
    dd 0xC468    ; W_TILEMAP row 5 (enemy HP-bar tile IDs, cols 12-20)
    dd 0xC5A8    ; W_TILEMAP row 13 (player HP-bar tile IDs, for comparison)
    dd 0xCFE4    ; wEnemyMon: species, HP hi(+1), HP lo(+2)
    dd 0xD0D6    ; wDamage
    dd 0xCFD1    ; wPlayerMove* (num,effect,power,type)
    dd 0xD014    ; wBattleMonHP (player HP, big-endian) — enemy-hit ground-truth
    dd 0xCFCB    ; wEnemyMove* (num,effect,power,type) — enemy-hit ground-truth
    dd 0xCFE4
    dd 0xD0D6
%else
windows:
    dd OW_BLOCKS_GBADDR             ; blockset blocks 0..3
    dd OW_BLOCKS_GBADDR + 0x52*16   ; blockset entry for block 0x52
    dd OW_PALLET_BLK_GBADDR         ; PalletTown.blk
    dd GB_VCHARS2                   ; vTileset gfx in VRAM
    dd W_OVERWORLD_MAP              ; wOverworldMap start
    dd W_SURROUNDING_TILES          ; wSurroundingTiles
    dd W_TILEMAP                    ; wTileMap
    dd W_CUR_MAP - 5                ; map header vars around wCurMap ($D358)
    dd W_TILESET_BLOCKS_PTR - 0xB   ; tileset header copy block ($D520)
%endif

; ---------------------------------------------------------------------------
section .bss
align 4
rmcs:        resb RMCS_SIZE      ; DPMI real-mode call structure
dos_seg:     resw 1              ; real-mode segment of DOS buffer
dos_sel:     resw 1              ; PM selector of DOS buffer (unused; freed via seg)
dos_flat:    resd 1              ; DS-relative (flat) offset of DOS buffer
file_handle: resw 1
stage:       resb DUMP_TOTAL     ; concatenated window bytes, staged here first
%ifdef DEBUG_NPC_WALK
NPC_LOG_CAP  equ 4096            ; 12-byte records → 341 NPC walk-decisions
npc_log:     resb NPC_LOG_CAP    ; appended by movement.asm:npc_dbg_record
npc_log_n:   resd 1              ; bytes written so far
dbg_destTile: resb 1            ; tile CL at CanWalkOntoTile entry (saved before clobber)
%endif
%ifdef DEBUG_SEAM
SEAM_REC_SIZE equ 12
SEAM_LOG_CAP  equ 24576           ; 12-byte records → 2048 frames (~34 s of play)
seam_log:     resb SEAM_LOG_CAP   ; RING buffer, appended by SeamLogRecord
seam_log_i:   resd 1              ; write cursor (byte offset, wraps at CAP)
seam_log_n:   resd 1              ; total bytes ever written (may exceed CAP)
seam_out_len: resd 1              ; bytes actually staged for the file
%endif

; ---------------------------------------------------------------------------
section .text

%ifdef DEBUG_CALCSTATS
; ---------------------------------------------------------------------------
; RunCalcStatsTest — compute Bulbasaur (internal $99) stats at L5 and L100 with
; DVs=15 / stat-exp=0 into the $D1E0 scratch, then dump to DUMP.BIN. Validates
; GetMonHeader + CalcStat + _Multiply/_Divide end-to-end against canonical values.
; Never returns. Expected (big-endian words, host hexdump):
;   dump +$20 (L5):   HP=0015 Atk=000B Def=000B Spd=000B Spc=000D  (21/11/11/11/13)
;   dump +$30 (L100): HP=00E6 Atk=0085 Def=0085 Spd=007D Spc=00A5  (230/133/133/125/165)
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunCalcStatsTest:
    mov byte [ebp + wCurSpecies], 0x99      ; Bulbasaur internal index
    call GetMonHeader
    mov word [ebp + 0xD1FB], 0xFFFF         ; scratch DVs (all 15) at monbase+MON_DVS
    mov byte [ebp + wCurEnemyLevel], 5      ; --- L5 ---
    xor bh, bh                              ; b=0: ignore stat exp
    mov esi, 0xD1F0                         ; stat-exp base ptr (= monbase + $10)
    mov edx, 0xD200                         ; result dest
    call CalcStats
    mov byte [ebp + wCurEnemyLevel], 100    ; --- L100 ---
    xor bh, bh
    mov esi, 0xD1F0
    mov edx, 0xD210
    call CalcStats
    jmp DebugDumpMemory                     ; writes DUMP.BIN, exits
%endif

%ifdef DEBUG_AUDIO
; ---------------------------------------------------------------------------
; RunAudioTest — the Phase A milestone demo, driven through the real gateway
; (PlayMusic/PlaySound → AudioN_PlaySound → per-tick Audio1_UpdateMusic →
; opl_pass). Sequence: ~5 s of Pallet Town BGM, the A-button menu blip
; (ducks the music, exactly as on the GB), then a Pokémon cry (3-channel
; SFX with frequency/tempo modifiers), ~4 s more music, then dump the audio
; RAM + virtual APU + shim state to DUMP.BIN and exit. Audible when run
; under dos_port/run (DOSBox-X OPL emulation); byte-verifiable headless.
; Never returns. In: EBP = GB memory base.
;
; The auditioned song defaults to Game Corner; override from the make line
; with TRACK=<MUSIC_* name> (any constant in assets/audio_constants.inc) —
; the bank is resolved via the generated <name>_BANK constant, no asm edit.
; ---------------------------------------------------------------------------
%ifndef DEBUG_AUDIO_TRACK
%define DEBUG_AUDIO_TRACK MUSIC_GAME_CORNER
%endif
%define DEBUG_AUDIO_TRACK_BANK DEBUG_AUDIO_TRACK %+ _BANK
RunAudioTest:
    mov bl, DEBUG_AUDIO_TRACK_BANK          ; c = BANK(song)
    mov al, DEBUG_AUDIO_TRACK
    call PlayMusic
    ; /LOOP (audition): play the music only, forever — no SFX, no dump/exit,
    ; so the whole track (and its loop) can be heard clean. DelayFrame still
    ; services the quit key, so the user can exit normally.
    cmp byte [g_cfg_musicloop], 0
    je .withSfx
.musicOnly:
    call DelayFrame                         ; ticks the engine + enh layer
    jmp .musicOnly
.withSfx:
    mov edi, 300                            ; ~5 s of BGM
    call .ticks
    mov al, SFX_PRESS_AB                    ; menu blip over the music
    call PlaySound
    mov edi, 60
    call .ticks
    xor al, al                              ; cry modifiers: neutral pitch/length
    mov [ebp + wFrequencyModifier], al
    mov [ebp + wTempoModifier], al
    mov al, SFX_CRY_00                      ; Nidoran M base cry
    call PlaySound
    mov edi, 240
    call .ticks
    xor dl, dl                              ; PikachuCry1 — Phase C digitized PCM
    call PlayPikachuSoundClip               ; blocks ~0.8 s (SB DSP or speaker PWM)
    mov edi, 60                             ; a beat of music after the clip
    call .ticks
    call opl_dbg_snapshot                   ; shim state -> $D1E0 scratch
    call midi_dbg_snapshot                  ; MIDI driver state -> $D227+
    call pika_dbg_snapshot                  ; PCM player state -> $D240+
    call hal_dbg_snapshot                   ; active shim device -> $D246
    call tandy_dbg_snapshot                 ; SN76489 shim state -> $D248+
    call spk_dbg_snapshot                   ; speaker shim state -> $D250+
    call enh_dbg_snapshot                   ; OPL enh player state -> $D258+
    jmp DebugDumpMemory                     ; writes DUMP.BIN, exits
.ticks:
    push edi
    call DelayFrame                         ; runs audio_tick each frame
    pop edi
    dec edi
    jnz .ticks
    ret
%endif

%ifdef DEBUG_PARTY
; ---------------------------------------------------------------------------
; RunPartySeedTest — zero the party + bag counts, run the full debug new-game
; seed (PrepareNewGameDebug: AddPartyMon ×4, AddItemToInventory ×N, Pokédex,
; money), then dump party + bag WRAM to DUMP.BIN. Validates that _AddPartyMon /
; AddItemToInventory_ run correctly inside the real binary (not just the native
; harnesses). Never returns. In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunPartySeedTest:
    ; Start from an empty party + bag (WRAM is not guaranteed zeroed pre-Init).
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug
    jmp DebugDumpMemory             ; writes DUMP.BIN, exits
%endif

%ifdef DEBUG_BAGMENU
; ---------------------------------------------------------------------------
; RunBagMenuTest — seed the party + bag, load the font, open the bag (ITEM)
; screen over the (already set-up) overworld via the faithful StartMenu_Item →
; DisplayListMenuID path (menus S4). The DEBUG_BAGMENU hook inside
; DisplayListMenuIDLoop (home/list_menu.asm) renders one frame with the staged
; list + cursor and dumps FRAME.BIN. Never returns. In: EBP = GB memory base.
; Call from EnterMap (after the overworld is loaded) so Pallet Town backs the box.
; ---------------------------------------------------------------------------
RunBagMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seed party + bag
%ifdef DEBUG_BAGMENU_EMPTY
    ; Empty-inventory variant (the user's live worst-case symptom): re-zero the
    ; bag after the seed so the list is just CANCEL. make DEBUG_BAGMENU=1
    ; DEBUG_BAGMENU_EMPTY=1
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
%endif
    ; Swap the font into vFont so the list glyphs render (caller contract).
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    mov byte [ebp + wLinkState], 0  ; not in the Cable Club
    mov byte [ebp + wBagSavedMenuItem], 0
    ; Mirror the live START-menu entry path: the canvas stride (40) is what is
    ; live when StartMenu_Item runs from the real START menu. The boot default
    ; of 20 masked the border-before-stride bug in this harness — this seed
    ; makes the harness the permanent regression repro for it.
    mov dword [text_row_stride], 40
    call StartMenu_Item             ; list_menu's DEBUG hook: 1 frame + dump + exit
.hang:
    jmp .hang                       ; unreachable (the list-menu hook dumps + exits)
%endif

%ifdef DEBUG_PARTYMENU
; ---------------------------------------------------------------------------
; RunPartyMenuTest — seed the party, load the font, open the POKéMON screen over
; the overworld. DisplayPartyMenu's DEBUG_PARTYMENU hook renders one frame and
; dumps FRAME.BIN. Never returns. In: EBP = GB memory base.
; ---------------------------------------------------------------------------
RunPartyMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call StartMenu_Pokemon          ; production entry: the S5 dispatcher runs
                                    ; DisplayPartyMenu, whose hook dumps + exits
.hang:
    jmp .hang
%endif

%ifdef DEBUG_ITEMTM
; ---------------------------------------------------------------------------
; RunTMHMTest — items-plan Stage 7 gate. Seeds the party + bag, drops the TM/HM
; under test into bag slot 0, and drives the real UseItem dispatcher at it. The
; bag UI is bypassed the same way DEBUG_ITEMBALL bypasses the battle ITEM menu:
; wCurItem = the machine, wWhichPokemon = its BAG SLOT (RemoveUsedItem removes by
; index). AUTOKEY_APRESS answers the yes/no box, the party menu and the messages.
; Overrides: ITEMTM_ID (the item id), ITEMTM_MON (the party slot to teach).
; Never returns — DebugDumpMemory writes DUMP.BIN and exits.
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
%ifndef ITEMTM_ID
%define ITEMTM_ID 0xCE                  ; TM06 TOXIC — SNORLAX (party slot 0) learns it
%endif
%ifndef ITEMTM_MON
%define ITEMTM_MON 0
%endif
RunTMHMTest:
    mov byte [ebp + wPartyCount], 0
    mov byte [ebp + wPartySpecies], 0xFF
    mov byte [ebp + wNumBagItems], 0
    mov byte [ebp + wBagItems], 0xFF
    call PrepareNewGameDebug
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    ; Bag slot 0 becomes the machine under test (qty 1), so RemoveUsedItem's
    ; consume-vs-keep decision is visible in wNumBagItems / the first pair.
    mov byte [ebp + wBagItems + 0], ITEMTM_ID
    mov byte [ebp + wBagItems + 1], 1
    mov byte [ebp + wWhichPokemon], 0       ; the BAG slot, not the party slot
    mov byte [ebp + wCurItem], ITEMTM_ID
    ; DEBUG_SEED_PARTY gives the target mon four moves, and for slot 0 (SNORLAX)
    ; all four are HMs (FLY/CUT/SURF/STRENGTH) — LearnMove then correctly refuses
    ; every one ("HM techniques can't be deleted!") and re-prompts forever, which
    ; an A-only autokey script can never escape. Free the last three slots so this
    ; test exercises ItemUseTMHM's real path: teach into an empty slot.
    mov esi, wPartyMon1 + ITEMTM_MON * PARTYMON_STRUCT_LENGTH + MON_MOVES
    mov byte [ebp + esi + 1], 0
    mov byte [ebp + esi + 2], 0
    mov byte [ebp + esi + 3], 0
%ifdef ITEMTM_BISECT
    call DebugDumpMemory
%endif
    call UseItem
    call DebugDumpMemory                    ; DUMP.BIN (the windows: table below) + exit
%endif

%ifdef DEBUG_TEXTBOXID
; ---------------------------------------------------------------------------
; RunTextBoxIDTest — menus S2 FRAME.BIN gate (docs/current_plan_menus.md).
; Seeds the debug party (+ a field move so FIELD_MOVE_MON_MENU has content),
; switches to the flat 40×25 canvas render mode (same sequence as InitBattle),
; blanks the canvas, draws text box DEBUG_TEXTBOXID via the real
; DisplayTextBoxID home wrapper, renders 3 frames, dumps FRAME.BIN, exits.
; Never returns. In: EBP = GB base.  make DEBUG_TEXTBOXID=<id>
; NOTE: interactive ids (0x14 TWO_OPTION_MENU, 0x15 BUY_SELL_QUIT_MENU) would
; block in HandleMenuInput — verify 0x15's box via template 0x0E instead.
; ---------------------------------------------------------------------------
RunTextBoxIDTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; party + bag + money (MONEY_BOX reads it)
    ; give party mon 0 a field move and select it, so FIELD_MOVE_MON_MENU (0x04)
    ; lists a real field move above STATS/SWITCH/CANCEL; inert for every other id
    mov byte [ebp + wPartyMon1 + MON_MOVES + 1], 0x0F   ; move slot 2 = CUT
    mov byte [ebp + wWhichPokemon], 0
    ; font glyphs + box-border tiles into vFont
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; flat-canvas render mode (mirrors InitBattle): render_bg decodes W_TILEMAP
    ; directly at screen (0,0), no window overlay, no per-frame OAM rebuild
    call ClearSprites
    mov byte [ebp + W_UPDATE_SPRITES_ENABLED], 0
    mov word [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR], 0
    mov byte [ebp + H_SCX], 0       ; zero the shadows too — commit_shadow_regs
    mov byte [ebp + H_SCY], 0       ; copies them over IO_SCX/SCY each DelayFrame
    mov byte [ebp + IO_SCX], 0
    mov byte [ebp + IO_SCY], 0
    call hide_window
    ; blank the whole canvas to the space tile so only the box under test shows
    lea edi, [ebp + W_TILEMAP]
    mov al, 0x7F                    ; TILE_SPC
    mov ecx, SCREEN_TILES_W * SCREEN_TILES_H
    rep stosb
    mov byte [ebp + wTextBoxID], DEBUG_TEXTBOXID
    call DisplayTextBoxID           ; home wrapper → DisplayTextBoxID_
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer             ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_LISTMENU
; ---------------------------------------------------------------------------
; RunListMenuTest — menus S3 FRAME.BIN gate (docs/current_plan_menus.md).
; Seeds the debug party + bag, then drives the GENERIC list-menu driver
; (home/list_menu.asm:DisplayListMenuID) with NO input: wBattleType != 0 takes
; the Old-Man-battle branch, which force-selects entry 0 and returns without
; touching HandleMenuInput. Renders 3 frames, dumps FRAME.BIN, exits.
;   make DEBUG_LISTMENU=<mode>
;     0 = PCPOKEMONLISTMENU  (party list: nick-base select + LoadMonData +
;         PrintLevel — the S3-completed paths)
;     2 = PRICEDITEMLISTMENU (price column via GetItemPrice/PrintBCDNumber.
;         NB: priced lists are 1-byte mart format; feeding it the 2-byte bag
;         list means qty bytes render as items — deterministic render gate
;         only, not a data-correctness gate)
;     3 = ITEMLISTMENU       (bag list with ×NN quantities + IsKeyItem skip)
;   (1 = MOVESLISTMENU needs a seeded wMoves list; unsupported here.)
; Never returns. In: EBP = GB base.
; ---------------------------------------------------------------------------
RunListMenuTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; party + bag + money
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    ; input-free drive: Old Man battle type → auto-select entry 0
    mov byte [ebp + wBattleType], 1
    mov byte [ebp + wListMenuID], DEBUG_LISTMENU
    mov byte [ebp + wPrintItemPrices], 0
%if DEBUG_LISTMENU = 0
    mov word [ebp + wListPointer], wPartyCount & 0xFFFF
%else
    mov word [ebp + wListPointer], wNumBagItems & 0xFFFF
%endif
%if DEBUG_LISTMENU = 2
    mov byte [ebp + wPrintItemPrices], 1
    mov byte [ebp + hHalveItemPrices], 0
%endif
    xor al, al
    mov [ebp + wListScrollOffset], al
    mov [ebp + wCurrentMenuItem], al
    call DisplayListMenuID          ; box + entries + auto-select entry 0
    mov byte [ebp + wBattleType], 0
    call DelayFrame
    call DelayFrame
    call DelayFrame
    call DumpBackbuffer             ; writes FRAME.BIN + exits (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_BATTLE
; ---------------------------------------------------------------------------
; RunBattleTest — seed party + a wild enemy, load font/textbox tiles, enter
; battle (InitBattle), render one frame, and dump FRAME.BIN. Never returns.
; Stage-0.5 gate: proves the centered battle render mode. In: EBP = GB base.
; ---------------------------------------------------------------------------
RunBattleTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seed party + bag (player mons for later stages)
    ; --- Stage-1b HUD test data: seed enemy + player battle-mon structs so the HUD
    ; has names / levels / HP to render (real path = LoadBattleMonFromParty, Stage 2/3).
    ; Enemy "PIDGEY" L3, HP 14/14 (full bar). Names = charmap bytes, $50-terminated.
    mov byte [ebp + wEnemyMonNick + 0], 0x8F  ; P
    mov byte [ebp + wEnemyMonNick + 1], 0x88  ; I
    mov byte [ebp + wEnemyMonNick + 2], 0x83  ; D
    mov byte [ebp + wEnemyMonNick + 3], 0x86  ; G
    mov byte [ebp + wEnemyMonNick + 4], 0x84  ; E
    mov byte [ebp + wEnemyMonNick + 5], 0x98  ; Y
    mov byte [ebp + wEnemyMonNick + 6], 0x50  ; @
    ; PIDGEY L13 — at this level its real moveset is GUST + SAND-ATTACK (L5) +
    ; QUICK-ATTACK (L12), so the wild random-move AI visibly varies turn to turn.
    ; Stats are L13-appropriate (≈base+DV at L13) so the damage trades read sensibly.
    mov byte [ebp + wEnemyMonLevel], 13
    mov word [ebp + wEnemyMonHP], 0xC800      ; big-endian 200 (TEMP PP-test: survives move depletion
    mov word [ebp + wEnemyMonMaxHP], 0xC800   ; so all 4 moves can hit 0 PP → Struggle. REVERT to 0x2300.)
    mov byte [ebp + wEnemyMonStatus], 0
    ; enemy stats/types for the damage calc (PIDGEY: Normal/Flying)
    mov byte [ebp + wEnemyMonType1], 0x00      ; NORMAL
    mov byte [ebp + wEnemyMonType2], 0x02      ; FLYING
    mov word [ebp + wEnemyMonAttack],  0x1200  ; 18 (big-endian)
    mov word [ebp + wEnemyMonDefense], 0x1100  ; 17
    mov word [ebp + wEnemyMonSpeed],   0x1500  ; 21
    mov word [ebp + wEnemyMonSpecial], 0x1000  ; 16
    mov byte [ebp + wEnemyMonSpecies], 0x24    ; PIDGEY (internal index) — real moveset gen
    ; A real wild encounter sets wEnemyMonSpecies2 + wCurEnemyLevel (TryDoWildEncounter);
    ; this harness seeds wEnemyMon* directly, so mirror them — LoadEnemyMonData keys off
    ; wEnemyMonSpecies2, and ItemUseBall re-runs it on a capture (0 → GetMonLearnset OOB).
    mov byte [ebp + wEnemyMonSpecies2], 0x24
    mov byte [ebp + wCurEnemyLevel], 13
    ; Player "PIKACHU" L18, full 45-HP bar — enough to absorb several enemy turns so
    ; the battle runs long enough to watch the enemy's random move selection vary.
    mov byte [ebp + wBattleMonNick + 0], 0x8F  ; P
    mov byte [ebp + wBattleMonNick + 1], 0x88  ; I
    mov byte [ebp + wBattleMonNick + 2], 0x8A  ; K
    mov byte [ebp + wBattleMonNick + 3], 0x80  ; A
    mov byte [ebp + wBattleMonNick + 4], 0x82  ; C
    mov byte [ebp + wBattleMonNick + 5], 0x87  ; H
    mov byte [ebp + wBattleMonNick + 6], 0x94  ; U
    mov byte [ebp + wBattleMonNick + 7], 0x50  ; @
    mov byte [ebp + wBattleMonLevel], 18
    mov word [ebp + wBattleMonHP], 0x2D00     ; big-endian 45
    mov word [ebp + wBattleMonMaxHP], 0x2D00  ; big-endian 45
    mov byte [ebp + wBattleMonStatus], 0
    ; Pikachu's moves (FIGHT submenu): THUNDERSHOCK, GROWL, TAIL WHIP, QUICK ATTACK
    mov byte [ebp + wBattleMonMoves + 0], 0x54  ; THUNDERSHOCK
    mov byte [ebp + wBattleMonMoves + 1], 0x2D  ; GROWL
    mov byte [ebp + wBattleMonMoves + 2], 0x27  ; TAIL_WHIP
    mov byte [ebp + wBattleMonMoves + 3], 0x62  ; QUICK_ATTACK
    ; TEMP PP-test seed (low PP so 0-PP/Struggle are reachable; REVERT to 30/40/30/30):
    mov byte [ebp + wBattleMonPP + 0], 2       ; THUNDERSHOCK — use twice to watch it hit 0
    mov byte [ebp + wBattleMonPP + 1], 1       ; GROWL
    mov byte [ebp + wBattleMonPP + 2], 1       ; TAIL_WHIP
    mov byte [ebp + wBattleMonPP + 3], 1       ; QUICK_ATTACK
    ; player stats/types for the damage calc (PIKACHU: Electric)
    mov byte [ebp + wBattleMonType1], 0x17     ; ELECTRIC
    mov byte [ebp + wBattleMonType2], 0x17
    mov word [ebp + wBattleMonAttack],  0x1600 ; 22 (big-endian)
    mov word [ebp + wBattleMonDefense], 0x0F00 ; 15
    mov word [ebp + wBattleMonSpeed],   0x2800 ; 40 (faster than PIDGEY → player acts first)
    mov word [ebp + wBattleMonSpecial], 0x0C00 ; 12
    mov byte [ebp + wPlayerMonNumber], 0
    mov byte [ebp + wCriticalHitOrOHKO], 0
    mov byte [ebp + wEnemyBattleStatus3], 0
    mov byte [ebp + wPlayerBattleStatus3], 0   ; reflect/light-screen off (enemy-turn defense)
    ; clean the battle-status / disabled-move bytes SelectEnemyMove inspects, so its
    ; forced-move early-outs and the disabled-slot re-roll behave deterministically.
    mov byte [ebp + wEnemyBattleStatus1], 0
    mov byte [ebp + wEnemyBattleStatus2], 0
    mov byte [ebp + wPlayerBattleStatus1], 0
    mov byte [ebp + wEnemyDisabledMove], 0
    ; Seed the stat-stage modifiers to the neutral default (7) for BOTH battle mons.
    ; A real battle sets these in LoadBattleMonFromParty on send-out; this harness seeds
    ; wBattleMon*/wEnemyMon* directly, so without this the 8 mod bytes stay 0. CalcHitChance
    ; indexes StatModifierRatios by (accuracyMod-1)*2 — with mod 0 that's (0-1)&0xFF*2 = 254,
    ; reading ~228 bytes off the 26-byte table → garbage accuracy → moves "miss". (That
    ; garbage sits at a fixed .data offset, so the failure flips with unrelated code-size
    ; changes — which is why it appeared to come and go across rebuilds.)
    mov ecx, NUM_STAT_MODS
    mov esi, wPlayerMonAttackMod
.seedPMods:
    mov byte [ebp + esi], 7
    inc esi
    dec ecx
    jnz .seedPMods
    mov ecx, NUM_STAT_MODS
    mov esi, wEnemyMonAttackMod
.seedEMods:
    mov byte [ebp + esi], 7
    inc esi
    dec ecx
    jnz .seedEMods
    ; generate the wild enemy's moveset the real way (base moves + level-up learnset
    ; for PIDGEY $24 at its level) — replaces the old hardcoded move seed.
    call LoadWildMonMoves
    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    call InitBattle                 ; setup + clear canvas (no box/HUD yet)
%ifdef DEBUG_BATTLE_TRAINER
    ; --- Bug Catcher trainer test: trainer battle (enemy = trainer + ball row, not a
    ; wild mon), with party-status variety to exercise ok/fainted/status/empty balls. ---
    mov byte [ebp + wIsInBattle], 2
    mov byte [ebp + wEnemyPartyCount], 3
    ; enemy mon0 ok (HP 10), mon1 fainted (HP 0), mon2 statused (HP 10, status set)
    mov word [ebp + wEnemyMons + 0*PARTYMON_STRUCT_LENGTH + MON_HP], 0x0A00
    mov byte [ebp + wEnemyMons + 0*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0
    mov word [ebp + wEnemyMons + 1*PARTYMON_STRUCT_LENGTH + MON_HP], 0
    mov byte [ebp + wEnemyMons + 1*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0
    mov word [ebp + wEnemyMons + 2*PARTYMON_STRUCT_LENGTH + MON_HP], 0x0A00
    mov byte [ebp + wEnemyMons + 2*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0x08
    ; player party variety: mon1 fainted, mon2 statused (PrepareNewGameDebug seeded healthy)
    mov word [ebp + wPartyMons + 1*PARTYMON_STRUCT_LENGTH + MON_HP], 0
    mov byte [ebp + wPartyMons + 2*PARTYMON_STRUCT_LENGTH + MON_STATUS], 0x08
    call DrawBugCatcherPic_Stub     ; decode Bug Catcher trainer sprite → enemy VRAM
%else
    call DrawEnemyFrontPic_Stub     ; decode enemy (wild mon) front pic → VRAM
%endif
    call DrawPlayerRedBackPic_Stub  ; decode player trainer (Red) back pic → VRAM (slides in)
    call SlideBattlePicsIn          ; faithful silhouette slide-in (darkened)
    call DrawBattleIntroBox         ; box + "Wild <nick> appeared!" + enemy HUD
    call SaveBattleScreen           ; snapshot the clean screen (restored on menu re-entry)
%ifdef DEBUG_ITEMBALL
    ; --- items-plan Stage 6 gate: throw a ball at the seeded wild PIDGEY. ---
    ; The in-battle bag UI (BattleItemMenu) is still a battle-plan stub, so this
    ; drives UseItem the way that menu eventually will: wCurItem = the ball,
    ; wWhichPokemon = its BAG SLOT (RemoveItemFromInventory removes by index).
    ; The seeded bag (debug_party.asm) is POTION, ANTIDOTE, MASTER_BALL, … → slot 2.
    ; Party count is dropped to 5 so a capture takes the AddPartyMon path; the box
    ; path (SendNewMonToBox) ends in the interactive naming screen, which a headless
    ; run cannot answer. ITEMBALL_ID/ITEMBALL_SLOT override the ball under test.
%ifndef ITEMBALL_ID
%define ITEMBALL_ID 0x01                ; MASTER_BALL — always captures (deterministic)
%endif
%ifndef ITEMBALL_SLOT
%define ITEMBALL_SLOT 2
%endif
    mov byte [ebp + wIsInBattle], 1     ; wild battle
    mov byte [ebp + wPartyCount], 5     ; leave one party slot free
    mov byte [ebp + wBattleType], 0     ; BATTLE_TYPE_NORMAL
    mov byte [ebp + wWhichPokemon], ITEMBALL_SLOT
    mov byte [ebp + wCurItem], ITEMBALL_ID
    ; PrepareNewGameDebug does not clear the dex bitsets, so they hold uninitialised
    ; WRAM — the "already in the pokédex?" FLAG_TEST would read a garbage 1 and skip
    ; ShowPokedexData. Zero both bitsets so the capture takes the real new-species path
    ; and the dump's owned bit is a meaningful check.
    mov ecx, wPokedexSeenEnd - wPokedexOwned
    mov esi, wPokedexOwned
.zeroDex:
    mov byte [ebp + esi], 0
    inc esi
    dec ecx
    jnz .zeroDex
    call UseItem
    call DebugDumpMemory                ; DUMP.BIN (the windows: table below) + exit
%endif
%ifdef DEBUG_BATTLE_LIVE
    ; Intro: party-status pokéballs + "Wild <nick> appeared!", wait for A/B (blinking
    ; ▼), then the balls give way to the player HP-bar HUD (DisplayBattleMenu draws it).
    call DrawBattlePokeballs
    call WaitForAPress
    call HideBattlePokeballs
    ; send-out: faithfully the player trainer sprite slides OUT, then the mon comes in.
    ; For the starter PIKACHU this is just a SLIDE (it never enters a ball, so there is
    ; no throw/grow animation — Yellow special); every other mon gets the ball-throw +
    ; grow (AnimateSendingOutMon, more involved). TODO(send-out): trainer slide-out +
    ; Pikachu slide-in (easy) / ball+grow for others. For now: straight VRAM swap.
    call DrawPlayerBackPic_Stub     ; decode PIKACHU back pic → VRAM $31 (same tilemap block)
%ifdef DEBUG_BATTLE_TRAINER
    ; enemy send-out: the TRAINER sends out its first mon, so the trainer sprite is
    ; replaced by the enemy mon's front pic (decode over VRAM $00, same tilemap block);
    ; DisplayBattleMenu's DrawBattleHUDs then draws the enemy HP bar (was suppressed for
    ; the trainer intro). TODO(send-out): trainer slide-out + the real enemy-mon throw.
    call DrawEnemyFrontPic_Stub     ; enemy mon (PIDGEY) front → VRAM $00 (replaces Bug Catcher)
%endif
    ; Stage 3 (victory EXP): seed the defeated enemy's base stats + base exp (PIDGEY:
    ; HP40/Atk45/Def40/Spd56/Spc35, base exp 55) for GainExperience's stat-exp + EXP
    ; award, and flag party slot 0 (wPlayerMonNumber=0) to gain EXP. Real battles set
    ; these when the enemy mon is loaded / on send-out; the harness seeds the enemy
    ; battle-mon directly, so they're seeded here too.
    mov byte [ebp + wEnemyMonBaseStats + 0], 40   ; HP
    mov byte [ebp + wEnemyMonBaseStats + 1], 45   ; Attack
    mov byte [ebp + wEnemyMonBaseStats + 2], 40   ; Defense
    mov byte [ebp + wEnemyMonBaseStats + 3], 56   ; Speed
    mov byte [ebp + wEnemyMonBaseStats + 4], 35   ; Special
    mov byte [ebp + wEnemyMonBaseExp], 55
    ; flag the PIKACHU slot (DEBUG_PARTY party: 0=SNORLAX 1=PERSIAN 2=JIGGLYPUFF 3=PIKACHU
    ; L5 4=CHARIZARD 5=LAPRAS) so the gaining/leveling mon matches the on-screen PIKACHU.
    ; PIKACHU L5 + 102 EXP → L6, exercising the level-up display (grew text + stats box).
    or byte [ebp + wPartyGainExpFlags], (1 << 3)  ; party slot 3 (PIKACHU) participates → gains EXP
    mov byte [wBattleOver], 0        ; legacy harness flag (core.asm uses wBattleResult)
    ; Faithful battle loop: core.asm MainInBattleLoop runs the whole battle (menu, move
    ; select, speed-ordered turns, residual damage, faint/EXP/run) and returns on a
    ; terminal outcome (win/lose/ran). Esc quits the process.
    call MainInBattleLoop
    ; Post-battle: pret calls EndOfBattle here (via _InitBattleCommon, right after
    ; StartBattle). On a win it clears wForceEvolution + runs EvolutionAfterBattle
    ; (level-based post-battle evolutions) + UpdatePikachuMoodAfterBattle, then resets
    ; the battle WRAM and whites out. See current_plan_pokemon_behavior Stage 5.
    call EndOfBattle
    call EndBattleScreen            ; clean terminal (clears the battle screen)
.battle_done:
    call DelayFrame                 ; hold the terminal (real exit = overworld, Stage 3)
    jmp .battle_done
%elifdef DEBUG_BATTLE_ENEMYHIT
    ; Stage-2b ground-truth: pick the enemy move via the wild AI (SelectEnemyMove),
    ; run ONE enemy attack (no input waits), and dump battle WRAM. Proves the
    ; generated moveset (wEnemyMonMoves) + DoEnemyAttackDamage drains the player HP.
    call SelectEnemyMove
    call DoEnemyAttackDamage
    jmp DebugDumpMemory             ; writes DUMP.BIN, exits
%elifdef DEBUG_BATTLE_INTRO
    ; Dump the battle INTRO screen (scene + "Wild <nick> appeared!" + the ▼ advance
    ; arrow + the party-status pokéball row), no menu.
    mov byte [ebp + W_TILEMAP + (19 * 40 + 28)], 0xEE   ; ▼ (verify glyph renders)
    call DrawBattlePokeballs        ; player party-status balls (OAM sprites)
    call DelayFrame
    call DumpBackbuffer
.introhang:
    jmp .introhang
%else
    call DrawBattleMenu             ; Stage 2a: FIGHT/PKMN/ITEM/RUN menu (static)
    call DelayFrame
    call DumpBackbuffer             ; dump FRAME.BIN + exit (never returns)
.hang:
    jmp .hang
%endif
%endif

%ifdef DEBUG_LEARNMOVE
; ---------------------------------------------------------------------------
; RunLearnMoveTest — no-input ground truth for current_plan_pokemon_behavior
; Stage 3: does LearnMove's PrintText(LearnedMove1Text) render a legible box
; with the right nick/move-name substitutions in the live battle canvas? Seeds
; a battle-mode canvas (InitBattle, no enemy scene needed) then calls the exact
; src/engine/battle/battle_menu.asm:LearnMoveFromLevelUp entry point the real
; post-battle level-up sequence calls, on PrepareNewGameDebug's real STARTER_
; PIKACHU (party slot 3, level 5) — its moves come from the real WriteMonMoves
; learnset walk (add_party_mon.asm), not hand-picked, so whichever slot is open
; is authentic. Levels it 5->6, which pret's PikachuEvosMoves learns TAIL_WHIP
; at (evos_moves.asm-equivalent assets/evos_moves.inc). wPlayerMonNumber is also
; set to slot 3 so the in-battle wBattleMonMoves/PP sync branch runs too.
; ---------------------------------------------------------------------------
RunLearnMoveTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seeds party incl. slot3 = STARTER_PIKACHU L5

    ; InitBattle reads wEnemyMonSpecies/Level/Nick to load the enemy pic; the
    ; enemy itself is irrelevant here (LearnMoveFromLevelUp never reads it), so
    ; seed a minimal PIDGEY L13 exactly like RunBattleTest above.
    mov byte [ebp + wEnemyMonNick + 0], 0x8F  ; P
    mov byte [ebp + wEnemyMonNick + 1], 0x88  ; I
    mov byte [ebp + wEnemyMonNick + 2], 0x83  ; D
    mov byte [ebp + wEnemyMonNick + 3], 0x86  ; G
    mov byte [ebp + wEnemyMonNick + 4], 0x84  ; E
    mov byte [ebp + wEnemyMonNick + 5], 0x98  ; Y
    mov byte [ebp + wEnemyMonNick + 6], 0x50  ; @
    mov byte [ebp + wEnemyMonLevel], 13
    mov byte [ebp + wEnemyMonSpecies], 0x24   ; PIDGEY (internal index)

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns
    call LoadTextBoxTilePatterns
    mov byte [ebp + wIsInBattle], 1
    call InitBattle                 ; battle-mode canvas (clears screen, no HUD/box yet)

%ifdef DEBUG_LEARNMOVE_FULL
    ; Sub-flag: fill all 4 slots so the all-slots-full (AbandonLearning) branch
    ; runs instead. make DEBUG_LEARNMOVE=1 DEBUG_LEARNMOVE_FULL=1
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 0], 1
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 1], 2
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 2], 3
    mov byte [ebp + wPartyMon1 + 3*PARTYMON_STRUCT_LENGTH + MON_MOVES + 3], SURF
%endif
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wPlayerMonNumber], 3    ; == wWhichPokemon -> exercises battle-sync too
    mov byte [ebp + wCurEnemyLevel], 6
    mov byte [ebp + wPokedexNum], STARTER_PIKACHU

    call LearnMoveFromLevelUp
    call DelayFrame
    call DumpBackbuffer             ; dump FRAME.BIN + exit (never returns)
.hang:
    jmp .hang
%endif

%ifdef DEBUG_STATUS
; RunStatusScreenTest — seed the party, open the status/summary screen page 1 for
; the STARTER_PIKACHU in slot 3, and let StatusScreen's DEBUG_STATUS hook render one
; frame + dump FRAME.BIN before its button-wait. Never returns.
RunStatusScreenTest:
    mov byte [ebp + 0xD162], 0      ; wPartyCount = 0
    mov byte [ebp + 0xD163], 0xFF   ; wPartySpecies sentinel
    mov byte [ebp + 0xD31C], 0      ; wNumBagItems = 0
    mov byte [ebp + 0xD31D], 0xFF   ; wBagItems sentinel
    call PrepareNewGameDebug        ; seeds party incl. slot3 = STARTER_PIKACHU L5

    or byte [ebp + W_FONT_LOADED], (1 << BIT_FONT_LOADED)
    call LoadFontTilePatterns       ; font glyphs ($80+) — StatusScreen loads HP/HUD/box tiles itself
    mov byte [ebp + wWhichPokemon], 3
    mov byte [ebp + wMonDataLocation], 0    ; PLAYER_PARTY_DATA
    call StatusScreen               ; page 1; dumps + exits unless DEBUG_STATUS_PAGE2 (then returns)
%ifdef DEBUG_STATUS_PAGE2
    call StatusScreen2              ; page 2; dumps FRAME.BIN + exits
%endif
.hang:
    jmp .hang
%endif

; ---------------------------------------------------------------------------
; DebugDumpMemory — gather windows, write DUMP.BIN, exit. Never returns.
; In: EBP = GB memory base.
; ---------------------------------------------------------------------------
DebugDumpMemory:
    ; --- 1. Gather each GB window into the staging buffer ---
    mov esi, windows
    mov edi, stage
    mov edx, NUM_WINDOWS
.gather:
    mov eax, [esi]                 ; GB offset of this window
    add esi, 4
    push esi
    push edx
    lea esi, [ebp + eax]           ; flat source = GB base + offset
    mov ecx, WIN_SIZE
    rep movsb                      ; DS:ESI -> ES:EDI, EDI accumulates
    pop edx
    pop esi
    dec edx
    jnz .gather

    ; --- 2. Allocate a 1 KB conventional DOS buffer (DPMI fn 0100h) ---
    mov ax, 0x0100
    mov bx, 0x40                   ; 64 paragraphs = 1024 bytes
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4                     ; linear = seg * 16
    sub eax, [ds_base]             ; flat (wraps under 4 GB limit -> linear)
    mov [dos_flat], eax

    ; --- 3. Stage filename at DOS buffer offset 0 ---
    mov esi, fname
    mov edi, [dos_flat]
    mov ecx, 9                     ; "DUMP.BIN" + NUL
    rep movsb

    ; --- 4. Stage dump data at DOS buffer offset 0x10 ---
    mov esi, stage
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, DUMP_TOTAL
    rep movsb

    ; --- 5. Create file: INT 21h AH=3Ch, CX=0, DS:DX -> filename ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0                 ; filename at offset 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1               ; CF set => error
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- 6. Write data: INT 21h AH=40h, BX=handle, CX=len, DS:DX -> data ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], DUMP_TOTAL
    mov dword [rmcs + RMCS_EDX], 0x10              ; data at offset 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- 7. Close file: INT 21h AH=3Eh, BX=handle ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    ; Free the DOS buffer (DPMI fn 0101h, DX = selector)
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31

.exit:
    mov ax, 0x4C00
    int 0x21

; ---------------------------------------------------------------------------
; DumpGBState — write GBSTATE.BIN (header + W_TILEMAP + VRAM + OAM; layout at
; the GBSTATE_* equates above) so every DEBUG_* scenario emits the GB-state
; twin of the mGBA golden (fidelity harness Stage 1.3). Unlike the other dump
; routines this RETURNS — DumpBackbuffer calls it first, then writes FRAME.BIN
; and exits, so every existing hook gains GBSTATE.BIN with no call-site edits.
; In: EBP = GB memory base. Clobbers caller-saved regs; preserves EBP.
; ---------------------------------------------------------------------------
DumpGBState:
    ; --- Allocate a conventional DOS buffer: 0x10 + GBSTATE_TOTAL bytes ---
    ; 16 + 7320 = 7336 -> 459 paragraphs; round up to 0x200 (8 KB).
    mov ax, 0x0100
    mov bx, 0x200
    int 0x31
    jc .ret
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; --- Stage filename at offset 0 ---
    mov esi, fgbname
    mov edi, [dos_flat]
    mov ecx, 12                    ; "GBSTATE.BIN" + NUL
    rep movsb

    ; --- Header at offset 0x10 ---
    mov edi, [dos_flat]
    add edi, 0x10
    mov dword [edi], 'GBST'        ; little-endian store -> bytes G,B,S,T
    mov byte [edi + 4], GBSTATE_VERSION
    mov byte [edi + 5], GBSTATE_SCENARIO
    xor eax, eax
    mov word [edi + 6], ax         ; reserved
    mov dword [edi + 8], eax
    mov dword [edi + 12], eax
    add edi, GBSTATE_HDR_SIZE

    ; --- Regions: W_TILEMAP (40x25), VRAM tile data, OAM ---
    lea esi, [ebp + W_TILEMAP]
    mov ecx, W_TILEMAP_SIZE
    rep movsb
    lea esi, [ebp + GB_VRAM0]
    mov ecx, GBSTATE_VRAM_SIZE
    rep movsb
    lea esi, [ebp + GB_OAM]
    mov ecx, GB_OAM_SIZE
    rep movsb

    ; --- Create GBSTATE.BIN ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- Write header + regions in one shot ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], GBSTATE_TOTAL
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- Close ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.ret:
    ret

; ---------------------------------------------------------------------------
; DumpBackbuffer — write the full GB_BACKBUF (RENDER_W*RENDER_H = 64000 raw
; palette-indexed bytes) to FRAME.BIN, then exit. Lets the host render the exact
; pixels the software PPU produced under DOSBox-X (no compositor screenshot).
; Allocates a single 64 KB+ conventional buffer so the data goes out in one write.
; First writes GBSTATE.BIN via DumpGBState, so every FRAME.BIN hook also emits
; the GB-state dump the fidelity differ consumes (Stage 1.3).
; In: EBP = GB memory base. Never returns.
; ---------------------------------------------------------------------------
DumpBackbuffer:
    call DumpGBState               ; GBSTATE.BIN alongside every FRAME.BIN
    ; --- Allocate a conventional DOS buffer big enough for 0x10 + 64000 bytes ---
    ; 0x10 + 64000 = 64016 bytes -> 4001 paragraphs; round up to 0x1001 (4097).
    mov ax, 0x0100
    mov bx, 0x1001
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; --- Stage filename at offset 0 ---
    mov esi, fbname
    mov edi, [dos_flat]
    mov ecx, 10                    ; "FRAME.BIN" + NUL
    rep movsb

    ; --- Copy backbuffer directly to buffer offset 0x10 ---
    lea esi, [ebp + GB_BACKBUF]
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, GB_BACKBUF_SIZE
    rep movsb

    ; --- Create FRAME.BIN ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    ; --- Write 64000 bytes ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], GB_BACKBUF_SIZE
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    ; --- Close ---
    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21

.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.exit:
    mov ax, 0x4C00
    int 0x21

%ifdef DEBUG_NPC_WALK
; ---------------------------------------------------------------------------
; DumpNpcLog — write npc_log[0..npc_log_n) to NPCLOG.BIN, then exit.
; In: EBP = GB memory base. Never returns.
; ---------------------------------------------------------------------------
DumpNpcLog:
    mov ax, 0x0100
    mov bx, 0x1001                 ; 64 KB+ buffer (log is <= 4 KB)
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    ; filename at offset 0
    mov esi, fnlog
    mov edi, [dos_flat]
    mov ecx, 11                    ; "NPCLOG.BIN" + NUL
    rep movsb

    ; log bytes at offset 0x10
    mov esi, npc_log
    mov edi, [dos_flat]
    add edi, 0x10
    mov ecx, [npc_log_n]
    rep movsb

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov ecx, [npc_log_n]
    mov [rmcs + RMCS_ECX], ecx
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    call zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21
.free:
    mov ax, 0x0101
    mov dx, [dos_sel]
    int 0x31
.exit:
    mov ax, 0x4C00
    int 0x21
%endif

; ---------------------------------------------------------------------------
; sim_int21 — reflect INT 21h to real mode using the prepared rmcs.
; DPMI fn 0300h: BL=int#, BH=0, CX=0 (no stack words), ES:EDI -> rmcs.
; ---------------------------------------------------------------------------
sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, rmcs                  ; ES already = flat DS selector
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; zero_rmcs — clear the real-mode call structure.
; ---------------------------------------------------------------------------
zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret

%ifdef DEBUG_SEAM
; ===========================================================================
; Seam-crossing trace harness (DEBUG_SEAM). Port-only debug code — no pret
; counterpart. Drives the real movement primitives across a map connection and
; records one 12-byte sample per rendered frame, so the host can see exactly
; when CheckMapConnections fires and whether the player's coordinates, the block
; -map view pointer, the fine scroll and the player's OAM entry stay coherent.
;
; Record layout (12 bytes, little-endian where noted):
;   0  wCurMap
;   1  wXCoord
;   2  wYCoord
;   3  wWalkCounter
;   4  wCurrentTileBlockMapViewPointer low   (5 = high)
;   6  wCurMapWidth
;   7  wCurMapHeight
;   8  hSCX
;   9  hSCY
;  10  OAM[0].Y   (player sprite; $00 => off-screen/hidden)
;  11  OAM[0].X
; ===========================================================================
SeamLogRecord:
    push eax
    push edi
    mov edi, [seam_log_i]               ; ring cursor — never "fills", oldest is overwritten
    add edi, seam_log

    mov al, [ebp + W_CUR_MAP]                          ; 0
    mov [edi + 0], al
    mov al, [ebp + W_X_COORD]                          ; 1
    mov [edi + 1], al
    mov al, [ebp + W_Y_COORD]                          ; 2
    mov [edi + 2], al
    mov al, [ebp + W_WALK_COUNTER]                     ; 3
    mov [edi + 3], al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR]  ; 4
    mov [edi + 4], al
    mov al, [ebp + W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR + 1] ; 5
    mov [edi + 5], al
    mov al, [ebp + W_CUR_MAP_WIDTH]                    ; 6
    mov [edi + 6], al
    mov al, [ebp + W_CUR_MAP_HEIGHT]                   ; 7
    mov [edi + 7], al
    mov al, [ebp + H_SCX]                              ; 8
    mov [edi + 8], al
    mov al, [ebp + H_SCY]                              ; 9
    mov [edi + 9], al
    mov al, [ebp + GB_OAM + 0]                         ; 10 player OAM Y
    mov [edi + 10], al
    mov al, [ebp + GB_OAM + 1]                         ; 11 player OAM X
    mov [edi + 11], al

    add dword [seam_log_n], SEAM_REC_SIZE
    mov eax, [seam_log_i]
    add eax, SEAM_REC_SIZE
    cmp eax, SEAM_LOG_CAP
    jb .stored
    xor eax, eax                        ; wrap
.stored:
    mov [seam_log_i], eax

%ifdef DEBUG_SEAM_LIVE
    ; Live mode: the player drives. Pressing A dumps the trace + the screen and quits.
    mov al, [ebp + H_JOY_PRESSED]
    test al, PAD_A
    jz .done
    pop edi
    pop eax
    call DumpSeamLog                    ; SEAMLOG.BIN (returns)
    jmp DumpBackbuffer                  ; FRAME.BIN, then exits — never returns
%endif
.done:
    pop edi
    pop eax
    ret

; DumpSeamLog — write seam_log to SEAMLOG.BIN and RETURN. Unlike the other dumpers
; this does not terminate: the harness calls DumpBackbuffer afterwards, and that one
; exits. (Ordering matters — DumpBackbuffer never returns.)
DumpSeamLog:
    mov ax, 0x0100
    mov bx, 0x1001                 ; 64 KB+ real-mode buffer (log <= 8 KB)
    int 0x31
    jc .exit
    mov [dos_seg], ax
    mov [dos_sel], dx
    movzx eax, ax
    shl eax, 4
    sub eax, [ds_base]
    mov [dos_flat], eax

    mov esi, fseam                 ; filename at offset 0
    mov edi, [dos_flat]
    mov ecx, 12                    ; "SEAMLOG.BIN" + NUL
    rep movsb

    ; log bytes at offset 0x10, oldest-first. If the ring never wrapped
    ; (total < CAP) it is simply [0, total). Otherwise the oldest record is at the
    ; write cursor, so emit [cursor, CAP) then [0, cursor).
    mov edi, [dos_flat]
    add edi, 0x10
    mov eax, [seam_log_n]
    cmp eax, SEAM_LOG_CAP
    jae .wrapped
    mov [seam_out_len], eax
    mov esi, seam_log
    mov ecx, eax
    rep movsb
    jmp .staged
.wrapped:
    mov dword [seam_out_len], SEAM_LOG_CAP
    mov esi, [seam_log_i]
    mov ecx, SEAM_LOG_CAP
    sub ecx, esi                   ; ECX = CAP - cursor (tail chunk)
    add esi, seam_log
    rep movsb
    mov esi, seam_log              ; head chunk [0, cursor)
    mov ecx, [seam_log_i]
    rep movsb
.staged:

    call zero_rmcs                 ; INT 21h/3Ch — create
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .free
    mov ax, [rmcs + RMCS_EAX]
    mov [file_handle], ax

    call zero_rmcs                 ; INT 21h/40h — write
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    mov ecx, [seam_out_len]
    mov [rmcs + RMCS_ECX], ecx
    mov dword [rmcs + RMCS_EDX], 0x10
    mov ax, [dos_seg]
    mov [rmcs + RMCS_DS], ax
    call sim_int21

    call zero_rmcs                 ; INT 21h/3Eh — close
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [file_handle]
    mov [rmcs + RMCS_EBX], eax
    call sim_int21
.free:
    mov ax, 0x0101                 ; free DOS buffer
    mov dx, [dos_sel]
    int 0x31
.exit:
    ret
%endif

%ifdef DEBUG_AUTOKEY
; ---------------------------------------------------------------------------
; AutoKeyDrive — scripted joypad playback (debug harness).
;
; Called once per rendered frame from frame.asm, immediately after joypad_update,
; so it OVERRIDES the real keyboard state for that frame. Replays a fixed button
; sequence from autokey_script so a keyboard-driven live path (overworld → START
; → a submenu) can be exercised in a headless DOSBox-X run. hJoyPressed is the
; rising edge of hJoyHeld, computed here the same way joypad_update does.
;
; Script entries are `dd first_frame, last_frame, held_mask` (inclusive range),
; terminated by first_frame = -1. Frames outside every range read as "no keys".
;
; In: EBP = GB base. Preserves all registers.
; ---------------------------------------------------------------------------
%ifndef AUTOKEY_PAD
%define AUTOKEY_PAD PAD_UP
%endif
%ifndef AUTOKEY_DOWNS
%define AUTOKEY_DOWNS 1
%endif
%ifndef AUTOKEY_DUMP_FRAME
%define AUTOKEY_DUMP_FRAME 200
%endif
global AutoKeyDrive
AutoKeyDrive:
    pushad
    mov ecx, [autokey_frame]
    inc dword [autokey_frame]
    cmp ecx, AUTOKEY_DUMP_FRAME
    jne .noDump
    call DumpBackbuffer                 ; FRAME.BIN, then exits
.noDump:
    xor edx, edx                        ; DL = held mask for this frame
    lea esi, [autokey_script]
.scan:
    mov eax, [esi]
    cmp eax, -1
    je .apply
    cmp ecx, eax
    jl .next
    cmp ecx, [esi + 4]
    jg .next
    or dl, [esi + 8]
.next:
    add esi, 12
    jmp .scan
.apply:
    mov al, [autokey_prev]
    not al
    and al, dl                          ; pressed = held & ~prev
    mov [ebp + H_JOY_PRESSED], al
    mov [ebp + H_JOY_HELD], dl
    mov [autokey_prev], dl
    popad
    ret

section .data
autokey_frame: dd 0
autokey_prev:  db 0
align 4
; START opens the menu; DOWN moves POKéDEX → POKéMON; A selects it.
; The gaps are release frames (the menu code spins until the button is let go).
autokey_script:
%ifdef AUTOKEY_SEAM
    ; DEBUG_SEAM_LIVE companion: hold AUTOKEY_PAD (default PAD_UP) into the seeded
    ; map's edge with LIVE collision, then press A so SeamLogRecord writes
    ; SEAMLOG.BIN + FRAME.BIN. This is the harness that reproduced the Viridian
    ; Forest "stuck at the gate spawn" bug headlessly.
%ifdef AUTOKEY_MENU_FIRST
    ; open + close the START menu before the walk: reproduces a live session that
    ; verified the menus and then went talking to NPCs (font/VRAM state cycled).
    dd  30,  36, PAD_START
    dd  70,  76, PAD_B
%define AK_SHIFT 90
%else
%define AK_SHIFT 0
%endif
%ifdef AUTOKEY_JOG_RIGHT
    ; hold AUTOKEY_PAD, sidestep one tile right, resume — some warp tiles are not
    ; the tile you arrive on (Viridian Forest South Gate: (4,0) is wall, (5,0) warps)
    dd  30 + AK_SHIFT, 120 + AK_SHIFT, AUTOKEY_PAD
    dd 140 + AK_SHIFT, 155 + AK_SHIFT, PAD_RIGHT
    dd 175 + AK_SHIFT, 400 + AK_SHIFT, AUTOKEY_PAD
%else
    dd  30 + AK_SHIFT, 400 + AK_SHIFT, AUTOKEY_PAD
%endif
    dd 430 + AK_SHIFT, 436 + AK_SHIFT, PAD_A
    ; Extra A presses: page through / dismiss a multi-page NPC dialog reached at
    ; the end of the walk (forest youngster repro). Harmless in the logged
    ; variant — the first A press dumps and exits before these fire.
    dd 490 + AK_SHIFT, 496 + AK_SHIFT, PAD_A
    dd 550 + AK_SHIFT, 556 + AK_SHIFT, PAD_A
    dd 610 + AK_SHIFT, 616 + AK_SHIFT, PAD_A
    dd 670 + AK_SHIFT, 676 + AK_SHIFT, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_TALK
    ; NPC-dialog crash repro: with a DEBUG_START_MAP spawn placed a couple of
    ; tiles below an NPC, walk up into it (collision stops the player adjacent,
    ; facing up), then press A repeatedly to open and page through the dialog.
    ; Reaching AUTOKEY_DUMP_FRAME (default 200 — override to 450 for this
    ; script) proves the dialog survived; a crash leaves no FRAME.BIN.
    dd  30,  90, PAD_UP
    dd 120, 126, PAD_A
    dd 180, 186, PAD_A
    dd 240, 246, PAD_A
    dd 300, 306, PAD_A
    dd 360, 366, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_TITLE
    ; Boot path with the title screen: pulse A through the title + main menu
    ; (NEW GAME) + any intro text, then open START and pick a submenu.
%assign AK_T 60
%rep 12
    dd  AK_T, AK_T + 5, PAD_A
%assign AK_T AK_T + 30
%endrep
    dd 480, 486, PAD_START
%assign AK_I 0
%rep AUTOKEY_DOWNS
    dd  510 + AK_I * 30,  516 + AK_I * 30, PAD_DOWN
%assign AK_I AK_I + 1
%endrep
    dd  510 + AUTOKEY_DOWNS * 30, 516 + AUTOKEY_DOWNS * 30, PAD_A
    dd  -1,  -1, 0
%elifdef AUTOKEY_APRESS
    ; DEBUG_ITEMBALL companion: nothing to navigate, just answer every <PROMPT> /
    ; button wait the capture messages raise. A steady A pulse from frame 30 on.
    ; Keep the train long: a flow that outlives it blocks forever on the next
    ; prompt (the harness has no other input source) and reads as a hang.
%assign AK_A 30
%rep 300
    dd AK_A, AK_A + 5, PAD_A
%assign AK_A AK_A + 20
%endrep
    dd  -1,  -1, 0
%elifdef AUTOKEY_ITEMUSE
    ; items-plan Stage 5 (DEBUG_ITEMUSE): drive the real bag USE path twice.
    ;   START → DOWN DOWN → A          : open the START menu, pick ITEM
    ;   A → A                          : select bag slot 1 (POTION, qty 1) → USE
    ;   A                              : party menu → mon 1 (Snorlax, seeded to 1 HP)
    ;   A                              : dismiss "SNORLAX recovered by N!"
    ; then the bag is back with POTION consumed, so slot 1 is now ANTIDOTE:
    ;   A → A → A                      : ANTIDOTE → USE → mon 1 (no status) → refusal
    ; Pick the moment to look at with AUTOKEY_DUMP_FRAME (380 = the heal message,
    ; 620 = the refusal, 700 = the bag list with POTION gone).
    dd  60,  66, PAD_START
    dd 100, 106, PAD_DOWN
    dd 140, 146, PAD_DOWN
    dd 180, 186, PAD_A          ; ITEM
    dd 220, 226, PAD_A          ; POTION → USE/TOSS submenu
    dd 260, 266, PAD_A          ; USE
    dd 340, 346, PAD_A          ; party menu: mon 1
    dd 420, 426, PAD_A          ; dismiss the heal message
    dd 500, 506, PAD_A          ; ANTIDOTE → USE/TOSS submenu
    dd 540, 546, PAD_A          ; USE
    dd 600, 606, PAD_A          ; party menu: mon 1 (healthy → refusal)
    dd 660, 666, PAD_A          ; dismiss the refusal
    dd  -1,  -1, 0
%else
    dd  60,  66, PAD_START
%assign AK_I 0
%rep AUTOKEY_DOWNS
    dd  90 + AK_I * 30,  96 + AK_I * 30, PAD_DOWN
%assign AK_I AK_I + 1
%endrep
    dd  90 + AUTOKEY_DOWNS * 30, 96 + AUTOKEY_DOWNS * 30, PAD_A
    dd  -1,  -1, 0
%endif
section .text
%endif
