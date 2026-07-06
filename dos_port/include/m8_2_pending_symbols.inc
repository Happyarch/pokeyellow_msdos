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

; ---- WRAM: "Main Data" / event region — VERIFY via build .sym --------------
%ifndef wCurMapScript
wCurMapScript           equ 0xD5F0   ; VERIFY  pret wram.asm:2456 (db)
%endif
%ifndef wTrainerHeaderFlagBit
wTrainerHeaderFlagBit   equ 0xCC5C   ; VERIFY  pret wram.asm:477 (db)
%endif
%ifndef wEnemyMonOrTrainerClass
wEnemyMonOrTrainerClass equ 0xD058   ; VERIFY  pret wram.asm:2324 (db) (aliases wCurOpponent region)
%endif
%ifndef wEndBattleTextRomBank
wEndBattleTextRomBank   equ 0xD08C   ; VERIFY  pret wram.asm:1602 (db)
%endif
%ifndef wEndBattleWinTextPointer
wEndBattleWinTextPointer  equ 0xD088 ; VERIFY  pret wram.asm:1599 (dw)  ** flat-adapted: 4 bytes **
%endif
%ifndef wEndBattleLoseTextPointer
wEndBattleLoseTextPointer equ 0xD08C ; VERIFY  pret wram.asm:1600 (dw)  ** flat-adapted: 4 bytes **
%endif
%ifndef wGymLeaderNo
wGymLeaderNo            equ 0xD05B   ; VERIFY  pret wram.asm:1440 (db)
%endif
%ifndef wGymCityName
wGymCityName           equ 0xD35D   ; VERIFY  pret wram.asm:1261 (ds GYM_CITY_LENGTH)
%endif
%ifndef wGymLeaderName
wGymLeaderName         equ 0xD36E   ; VERIFY  pret wram.asm:1263 (ds NAME_LENGTH)
%endif
; wMiscFlags is canonical in gb_memmap.inc (menus S2: 0xCD60, derived from the
; verified anchor wActionResultOrTookBattleTurn 0xCD6A − ds 9 − 1 byte).
; The 0xD72E that used to live here was pokered's wd72e — wrong address.
%ifndef wEventFlags
wEventFlags            equ 0xD5A6   ; VERIFY  pret wram.asm:2400 (flag_array NUM_EVENTS)
%endif
%ifndef wToggleableObjectIndex
wToggleableObjectIndex equ 0xCC5A   ; VERIFY  pret wram.asm:470 (db)
%endif
%ifndef wToggleableObjectList
wToggleableObjectList  equ 0xD5CD   ; VERIFY  pret wram.asm:2177 (ds 16*2+1)
%endif
%ifndef wTrainerPicPointer
wTrainerPicPointer     equ 0xD048   ; VERIFY  pret wram.asm (dw) ** flat-adapted: 4 bytes **
%endif
%ifndef wNPCMovementDirections2
wNPCMovementDirections2 equ 0xCF08  ; VERIFY  pret wram.asm (movement scratch buffer)
%endif

; ---- WRAM: UNION region (wTrainerScreen*/emotion) — VERIFY (union base unknown) --
%ifndef wTrainerSpriteOffset
wTrainerSpriteOffset   equ 0xCD37   ; VERIFY  pret wram.asm:942 (union byte 0)
%endif
%ifndef wTrainerEngageDistance
wTrainerEngageDistance equ 0xCD38   ; VERIFY  pret wram.asm:943 (union byte 1)
%endif
%ifndef wTrainerFacingDirection
wTrainerFacingDirection equ 0xCD39  ; VERIFY  pret wram.asm:944 (union byte 2)
%endif
%ifndef wTrainerScreenY
wTrainerScreenY        equ 0xCD3A   ; VERIFY  pret wram.asm:945 (union byte 3)
%endif
%ifndef wTrainerScreenX
wTrainerScreenX        equ 0xCD3B   ; VERIFY  pret wram.asm:946 (union byte 4)
%endif
%ifndef wEmotionBubbleSpriteIndex
wEmotionBubbleSpriteIndex equ 0xCD48 ; VERIFY  pret wram.asm:994 (union+18)
%endif
%ifndef wWhichEmotionBubble
wWhichEmotionBubble    equ 0xCD49   ; VERIFY  pret wram.asm:995 (union+19)
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
