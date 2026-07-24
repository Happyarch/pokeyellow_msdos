; m8_2_pending_symbols.inc — TEMPORARY scaffold for M8.2 (trainer-header engine)
; so trainer_engine.asm assembles CHECK-ONLY *before* the root migrates these into
; the canonical includes.  Mirrors the m1_3_pending_symbols.inc convention.
;
; ROOT INTEGRATION:
;   1. Move every WRAM/HRAM symbol below into gb_memmap.inc and every constant into
;      gb_constants.inc, then DELETE this include + its %include line from
;      trainer_engine.asm.
;   2. VERIFY every address tagged  ; VERIFY  against the build .sym (pokeyellow
;      clean-pret = link − 0x2EC, per the m1_3 note).  The UNION-region bytes
;      (wTrainerScreen*/wTrainerSpriteOffset/wEmotionBubble*) and the "Main Data"
;      bytes (wCurMapScript, wEndBattle*, wEventFlags) cannot be resolved statically
;      here — their placeholder addresses are structurally-plausible but UNVERIFIED.
;   3. The  (confident)  ones were computed from verified anchors and can be trusted.
;   4. The MUSIC_MEET_* ids are audio-HAL-deferred (PlaySound is a ret-stub), so the
;      numeric value is functionally inert; assign the real music-const value at will.
; ─────────────────────────────────────────────────────────────────────────────

; ---- WRAM: confident (computed from verified anchors) ----------------------
%ifndef wSpriteIndex
wSpriteIndex            equ 0xCF13   ; (confident) = m1_3 anchor, pret wram.asm:1198
%endif
%ifndef wMapSpriteExtraData
wMapSpriteExtraData     equ 0xD503   ; (confident) = wMapSpriteData(0xD4E3)+MAX_OBJECT_EVENTS*2
%endif

; ---- WRAM: aliases onto symbols already in gb_memmap.inc --------------------
%ifndef wJoyIgnore
wJoyIgnore              equ W_JOY_IGNORE   ; (confident) = 0xCCB7
%endif
%ifndef hJoyHeld
hJoyHeld                equ H_JOY_HELD     ; (confident) = 0xFFB4
%endif
%ifndef hSpriteIndex
hSpriteIndex            equ 0xFF8C   ; (confident) = hTextID slot (m1_3: ASSERT ==hTextID)
%endif
%ifndef wStatusFlags3
wStatusFlags3          equ W_STATUS_FLAGS_3   ; (confident) = 0xD72C (canonical alias)
%endif
%ifndef wStatusFlags5
wStatusFlags5          equ W_STATUS_FLAGS_5   ; (confident) = 0xD72F (canonical alias)
%endif
%ifndef hLoadedROMBank
hLoadedROMBank         equ H_LOADED_ROM_BANK  ; (confident) = 0xFFB8 (canonical alias)
%endif
%ifndef wUpdateSpritesEnabled
wUpdateSpritesEnabled  equ W_UPDATE_SPRITES_ENABLED  ; (confident) = 0xCFCA (canonical alias)
%endif

; ---- WRAM: "Main Data" / event region — golden-.sym verified 2026-07-24 ----
; (M8.2 promotion session: every VERIFY placeholder below was resolved against
; the repo's golden pokeyellow.sym. Three of the old guesses were live
; COLLISIONS: wCurMapScript 0xD5F0 sat on wPalletTownCurScript (gb_memmap.inc),
; wGymCityName 0xD35D sat on W_CUR_MAP/W_Y_COORD/W_X_COORD, and
; wEnemyMonOrTrainerClass 0xD058 aliased wCurOpponent — which pret keeps as a
; SEPARATE copy precisely because wCurOpponent is cleared before EndTrainerBattle
; reads the class back.)
%ifndef wCurMapScript
wCurMapScript           equ 0xDA38   ; golden 00:da38 (was 0xD5F0 = wPalletTownCurScript COLLISION)
%endif
%ifndef wTrainerHeaderFlagBit
wTrainerHeaderFlagBit   equ 0xCC55   ; golden 00:cc55 (was 0xCC5C)
%endif
%ifndef wEnemyMonOrTrainerClass
wEnemyMonOrTrainerClass equ 0xD712   ; golden 00:d712 (was 0xD058 = wCurOpponent alias, wrong)
%endif
; The end-battle text slots are flat-adapted (dd, 4 bytes each), so only the win
; pointer keeps its golden base; lose/bank shift by the +2/+4 widening. All three
; land in the golden gap d08b..d094 (port gb_memmap: wOptionsInitialized 0xD089,
; W_SLOT_MACHINE_ALLOW_MATCHES_COUNTER 0xD095 — no overlap).
%ifndef wEndBattleWinTextPointer
wEndBattleWinTextPointer  equ 0xD08B ; golden 00:d08b (dw)  ** flat-adapted: 4 bytes **
%endif
%ifndef wEndBattleLoseTextPointer
wEndBattleLoseTextPointer equ 0xD08F ; golden 00:d08d +2 (win dd widening)  ** flat-adapted: 4 bytes **
%endif
%ifndef wEndBattleTextRomBank
wEndBattleTextRomBank   equ 0xD093   ; golden 00:d091 +2 (was 0xD08C = lose-ptr OVERLAP)
%endif
%ifndef wGymLeaderNo
wGymLeaderNo            equ 0xD05B   ; golden 00:d05b (db)
%endif
%ifndef wGymCityName
wGymCityName           equ 0xCF5E   ; golden 00:cf5e (was 0xD35D = W_CUR_MAP COLLISION)
%endif
%ifndef wGymLeaderName
wGymLeaderName         equ 0xCF6F   ; golden 00:cf6f (was 0xD36E)
%endif
; wMiscFlags is canonical in gb_memmap.inc (menus S2: 0xCD60, derived from the
; verified anchor wActionResultOrTookBattleTurn 0xCD6A − ds 9 − 1 byte).
; The 0xD72E that used to live here was pokered's wd72e — wrong address.
%ifndef wEventFlags
wEventFlags            equ 0xD746   ; golden 00:d746 = W_EVENT_FLAGS (gb_memmap.inc canonical; was 0xD5A6)
%endif
%ifndef wToggleableObjectIndex
wToggleableObjectIndex equ 0xCC4D   ; golden 00:cc4d (was wrongly 0xCC5A, adjacent to wNPCMovementDirections)
%endif
%ifndef wToggleableObjectList
wToggleableObjectList  equ 0xD5CD   ; golden 00:d5cd (ds 16*2+1)
%endif
%ifndef wTrainerPicPointer
; golden 00:d032, but the flat dd widening (4 bytes) would overlap wLearnMoveMonName
; (0xD035); the port keeps its slot in the free d048..d04b gap (wTrainerBaseMoney
; 0xD045 word below, wIsInBattle 0xD056 above — no overlap).
wTrainerPicPointer     equ 0xD048   ; port flat slot ** flat-adapted: 4 bytes **
%endif
%ifndef wNPCMovementDirections2
wNPCMovementDirections2 equ 0xCC97  ; golden sym 00:cc97 (unions with wNPCMovementDirections)
%endif

; ---- WRAM: UNION region (wTrainerScreen*/emotion) — golden-sym verified 2026-07-09.
; The previous guesses (union base at 0xCD37) were uniformly 6/7 bytes low, and
; 0xCD37-0xCD3B collided with wNPCMovementDirections2Index (0xCD37) and the
; sim-joypad control bytes (0xCD38/3A/3B); the golden addresses below sit in the
; shared 0xCD3D+ scratch union (slot-machine/HoF/badges/options) as pret intends.
%ifndef wTrainerSpriteOffset
wTrainerSpriteOffset   equ 0xCD3D   ; golden 00:cd3d
%endif
%ifndef wTrainerEngageDistance
wTrainerEngageDistance equ 0xCD3E   ; golden 00:cd3e
%endif
%ifndef wTrainerFacingDirection
wTrainerFacingDirection equ 0xCD3F  ; golden 00:cd3f
%endif
%ifndef wTrainerScreenY
wTrainerScreenY        equ 0xCD40   ; golden 00:cd40
%endif
%ifndef wTrainerScreenX
wTrainerScreenX        equ 0xCD41   ; golden 00:cd41
%endif
%ifndef wEmotionBubbleSpriteIndex
wEmotionBubbleSpriteIndex equ 0xCD4F ; golden 00:cd4f
%endif
%ifndef wWhichEmotionBubble
wWhichEmotionBubble    equ 0xCD50   ; golden 00:cd50
%endif

; ---- Constants ABSENT from gb_constants.inc --------------------------------
; wMiscFlags bit
%ifndef BIT_SEEN_BY_TRAINER
BIT_SEEN_BY_TRAINER    equ 0        ; ram_constants.asm:8
%endif
; wStatusFlags3 bits
%ifndef BIT_TALKED_TO_TRAINER
BIT_TALKED_TO_TRAINER  equ 6
%endif
%ifndef BIT_PRINT_END_BATTLE_TEXT
BIT_PRINT_END_BATTLE_TEXT equ 7
%endif
; wStatusFlags4 bit
%ifndef BIT_UNKNOWN_4_1
BIT_UNKNOWN_4_1        equ 1
%endif
; wStatusFlags5 bit
%ifndef BIT_UNKNOWN_5_4
BIT_UNKNOWN_5_4        equ 4
%endif
; wStatusFlags7 bits
%ifndef BIT_TRAINER_BATTLE
BIT_TRAINER_BATTLE     equ 3
%endif
%ifndef BIT_USE_CUR_MAP_SCRIPT
BIT_USE_CUR_MAP_SCRIPT equ 4
%endif
; wCurrentMapScriptFlags bits (const_def 5)
%ifndef BIT_CUR_MAP_LOADED_1
BIT_CUR_MAP_LOADED_1   equ 5
%endif
%ifndef BIT_CUR_MAP_LOADED_2
BIT_CUR_MAP_LOADED_2   equ 6
%endif
; joypad mask
%ifndef PAD_CTRL_PAD
PAD_CTRL_PAD           equ 0xF0     ; hardware.inc:96 (%1111_0000)
%endif
; misc
%ifndef GYM_CITY_LENGTH
GYM_CITY_LENGTH        equ 17       ; text_constants.asm:7
%endif
%ifndef POWER_PLANT
POWER_PLANT            equ 0x53     ; map_constants.asm:143
%endif

; ---- Trainer-class opponent ids (OPP_x = OPP_ID_OFFSET + class) -------------
%ifndef OPP_ID_OFFSET
OPP_ID_OFFSET          equ 200      ; trainer_constants.asm:1
%endif
%ifndef ROCKET
ROCKET                 equ 0x1E     ; trainer class $1E (IsFightingJessieJames)
%endif
%ifndef OPP_RIVAL1
OPP_RIVAL1             equ 225      ; 200+0x19
%endif
%ifndef OPP_RIVAL2
OPP_RIVAL2             equ 242      ; 200+0x2A
%endif
%ifndef OPP_RIVAL3
OPP_RIVAL3             equ 243      ; 200+0x2B
%endif
%ifndef OPP_LANCE
OPP_LANCE              equ 247      ; 200+0x2F (plays gym leader battle theme)
%endif
%ifndef OPP_LASS
OPP_LASS               equ 203
%endif
%ifndef OPP_JR_TRAINER_F
OPP_JR_TRAINER_F       equ 206
%endif
%ifndef OPP_BEAUTY
OPP_BEAUTY             equ 218
%endif
%ifndef OPP_COOLTRAINER_F
OPP_COOLTRAINER_F      equ 232
%endif
%ifndef OPP_UNUSED_JUGGLER
OPP_UNUSED_JUGGLER     equ 213
%endif
%ifndef OPP_GAMBLER
OPP_GAMBLER            equ 217
%endif
%ifndef OPP_ROCKER
OPP_ROCKER             equ 220
%endif
%ifndef OPP_JUGGLER
OPP_JUGGLER            equ 221
%endif
%ifndef OPP_CHIEF
OPP_CHIEF              equ 227
%endif
%ifndef OPP_SCIENTIST
OPP_SCIENTIST          equ 228
%endif
%ifndef OPP_GIOVANNI
OPP_GIOVANNI           equ 229
%endif
%ifndef OPP_ROCKET
OPP_ROCKET             equ 230
%endif

; ---- Music ids -------------------------------------------------------------
; The nominal MUSIC_MEET_* placeholders that lived here were WRONG ($1f/$20/
; $21; true ids $f5/$f8/$fb) and are retired: the generated
; assets/audio_constants.inc is the single source of music/SFX ids now that
; PlaySound is real (audio plan Phase A). %include it where they're needed.
