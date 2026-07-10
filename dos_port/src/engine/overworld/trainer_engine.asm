; ============================================================================
; trainer_engine.asm — overworld trainer-header engine  (home-rectify M8.2)
;
; Intended repo path: dos_port/src/engine/overworld/trainer_engine.asm
;
; Faithful translation of:
;   home/trainers.asm    — StoreTrainerHeaderPointer, ExecuteCurMapScriptInTable,
;                          LoadGymLeaderAndCityName, ReadTrainerHeaderInfo,
;                          TrainerFlagAction, TalkToTrainer, CheckFightingMapTrainers,
;                          DisplayEnemyTrainerTextAndStartBattle, TrainerWalkUpToPlayer_Bank0,
;                          CheckForEngagingTrainers, SaveEndBattleTextPointers,
;                          EngageMapTrainer, PrintEndBattleText, GetSavedEndBattleTextPointer,
;                          TrainerEndBattleText, PlayTrainerMusic
;   home/trainers2.asm   — GetTrainerInformation, IsFightingJessieJames, GetTrainerName
;   engine/overworld/trainer_sight.asm  — TrainerWalkUpToPlayer, ReadTrainerScreenPosition,
;                          TrainerEngage, CheckSpriteCanSeePlayer, CheckPlayerIsInFrontOfSprite
;   engine/overworld/emotion_bubbles.asm — EmotionBubble
;   data/trainers/encounter_types.asm    — FemaleTrainerList / EvilTrainerList
;
; Register map (SM83 -> x86): A->AL, HL->ESI, B->BH, C->BL, D->DH, E->DL.
; RAM is EBP-relative: emulated GB byte X is [ebp + X].  Tier-1 asset data (trainer
; headers, pic/money tables, text) are FLAT 32-bit host pointers (like MapScriptPointers,
; w_map_text_table_ptr, TrainerPicPointers) — read as [flat_ptr] WITHOUT ebp.
;
; ----------------------------------------------------------------------------
; FLAT-POINTER MODEL (the load-bearing adaptation — read this).
; ----------------------------------------------------------------------------
; pret trainer headers live in banked ROM addressed by 16-bit GB pointers, and
; wTrainerHeaderPtr is a 2-byte GB address.  The port addresses all overworld asset
; data with FLAT 32-bit host pointers.  So this engine stores the header pointer as a
; FLAT dword in `w_trainer_header_ptr` (BSS), NOT in emulated wTrainerHeaderPtr.  This
; supersedes pret's wTrainerHeaderPtr — matching the port precedent w_map_text_table_ptr
; (map_sprites.asm) which is likewise a flat .bss dword, not emulated WRAM.
;
; The generated (Tier-1) trainer-header blob a future `tools/gen_trainer_headers.py`
; must emit has this FLAT per-entry layout (stride TH_SIZE=22, replacing pret's $c):
;   +0  db   flag_bit            (0..7 within its wEventFlags byte)
;   +1  db   view_range << 4     (pret packs it shifted; kept verbatim)
;   +2  dd   flag_ptr            GB WRAM OFFSET into wEventFlags  (used by FlagAction,
;                                which does [ebp+ESI]; so this is an emulated offset,
;                                NOT a flat pointer)
;   +6  dd   before_battle_text  FLAT text ptr
;   +10 dd   after_battle_text   FLAT text ptr
;   +14 dd   end_battle_win_text FLAT text ptr   (pret \4)
;   +18 dd   end_battle_lose_text FLAT text ptr  (pret \4 again — same value in Gen1)
; A per-map table `dd`-indexes these; the map's _Script passes its header table's flat
; base to StoreTrainerHeaderPointer (exactly as pret map scripts pass `hl, Headers`).
;
; ReadTrainerHeaderInfo keeps pret's caller ABI (selector 0/2/4/6/8/$a) and maps each
; selector to the flat field above, so every caller in this file is byte-faithful.
;
; ----------------------------------------------------------------------------
; npc_beaten_flags -> TrainerFlagAction CONVERGENCE  (see SUMMARY.md).
; ----------------------------------------------------------------------------
; The bespoke port keeps trainers-beaten state in map_sprites.asm's `npc_beaten_flags`
; (a 16-bit BSS reset every InitMapSprites => NON-persistent: trainers un-beat on every
; map reload).  This engine's persistent `TrainerFlagAction` is the faithful replacement:
; it drives the home global `FlagAction` against the header's flag_ptr => wEventFlags
; (persistent across warps).  ROOT FOLLOW-UP: once trainer-header DATA exists, delete
; npc_beaten_flags and route map_sprites.asm's CheckTrainerSight / TrainerEncounterFlow
; beaten-gate through TrainerFlagAction(FLAG_TEST/FLAG_SET).  (This worker does NOT edit
; map_sprites.asm.)
;
; STATUS: CHECK-ONLY.  Many cross-subsystem deps are unported (extern + TODO below); the
; trainer-header DATA layer + generator do not exist yet, so nothing calls this at runtime
; until M8.1 (sight->battle) + the data generator land.  Root wires the call sites.
;
; Build (check):
;   nasm -f coff -I dos_port/include/ -I dos_port/ -o trainer_engine.o \
;        dos_port/src/engine/overworld/trainer_engine.asm
; ============================================================================

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "m8_2_pending_symbols.inc"   ; ROOT: fold into gb_memmap/gb_constants, then delete
%include "assets/audio_constants.inc" ; MUSIC_MEET_* ids (generated, Tier-1)

; ----------------------------------------------------------------------------
; Flat trainer-header struct offsets (Tier-1 layout described above)
; ----------------------------------------------------------------------------
TH_FLAG_BIT    equ 0
TH_VIEW_RANGE  equ 1
TH_FLAG_PTR    equ 2      ; dd, GB WRAM offset
TH_BEFORE_TXT  equ 6      ; dd, flat
TH_AFTER_TXT   equ 10     ; dd, flat
TH_END_WIN     equ 14     ; dd, flat
TH_END_LOSE    equ 18     ; dd, flat
TH_SIZE        equ 22

; ----------------------------------------------------------------------------
; Externs
; ----------------------------------------------------------------------------
; --- home globals already ported (link targets exist) ---
extern FlagAction               ; src/engine/flag_action.asm (persistent flag array)
extern CallFunctionInTable      ; src/engine/overworld/run_map_script.asm
extern CopyData                 ; src/home/copy_data.asm
extern AddNTimes                ; src/home/array.asm
extern IsInArray                ; src/home/array.asm
extern BankswitchHome           ; src/home/bankswitch.asm (no-op flat)
extern BankswitchBack           ; src/home/bankswitch.asm (no-op flat)
extern CalcDifference           ; src/engine/overworld/pathfinding.asm
extern MoveSprite_              ; src/engine/overworld/pathfinding.asm
extern FillMemory               ; src/home/fill_memory.asm  (ESI unchanged on return!)
extern WriteOAMBlock            ; src/home/oam.asm
extern DelayFrame               ; src/video/frame.asm
extern DelayFrames              ; src/video/frame.asm
extern UpdateSprites            ; src/engine/overworld/movement.asm
extern PrintText                ; battle printer (src/engine/battle/move_effect_helpers.asm)
extern PlaySound                ; src/home/audio.asm (real gateway)
extern GetTrainerName_          ; src/engine/battle/get_trainer_name.asm
extern DisplayTextID            ; src/home/text_script.asm

; --- Tier-1 asset data (generated; already in the port tree) ---
extern TrainerPicPointers       ; src/data/trainer_pics.asm  (flat dd, index=class-1)
extern TrainerBaseMoney         ; src/data/trainer_pics.asm  (bcd3 per class, index=class-1)
extern PlayerPicFront           ; src/data/trainer_pics.asm  (== pret RedPicFront)

; --- UNPORTED deps: extern + TODO(M8.2 follow-up); root supplies or stubs ---
extern StartTrainerBattle       ; TODO(M8.2 follow-up): M8.1 owns (home/trainers.asm)
extern InitBattleEnemyParameters; TODO(M8.2 follow-up): M8.1 owns (home/trainers.asm)
extern ResetButtonPressedAndMapScript ; TODO(M8.2 follow-up): M8.1 (home/trainers.asm)
extern StopAllMusic             ; src/home/audio.asm (real gateway)
extern WaitForSoundToFinish     ; src/home/audio.asm (real gateway)
extern SaveTrainerName          ; TODO(M8.2 follow-up): engine/battle/*, unported
extern SetEnemyTrainerToStayAndFaceAnyDirection ; TODO(M8.2 follow-up): unported
extern TextCommandProcessor     ; TODO(M8.2 follow-up): text.asm has it; verify global name
extern TextScriptEnd            ; TODO(M8.2 follow-up): text_script, unported
extern HideObject               ; TODO(M8.2 follow-up): hidden_events, unported
extern CopyVideoData            ; src/home/copy2.asm (ported): ESI=dst VRAM offset, EDX=flat src, BL=tile count
; EmotionBubbleGfx is now defined here via %include "assets/emotes.inc" (gen_emotes.py).
extern _TrainerNameText         ; TODO(M8.2 follow-up): Tier-1 text (data/text) — NOT in port
extern JessieJamesPic           ; TODO(M8.2 follow-up): Tier-1 pic not in port TrainerPicPointers

; ----------------------------------------------------------------------------
; Globals
; ----------------------------------------------------------------------------
global StoreTrainerHeaderPointer
global ExecuteCurMapScriptInTable
global LoadGymLeaderAndCityName
global ReadTrainerHeaderInfo
global TrainerFlagAction
global TalkToTrainer
global CheckFightingMapTrainers
global DisplayEnemyTrainerTextAndStartBattle
global TrainerWalkUpToPlayer_Bank0
global TrainerWalkUpToPlayer
global ReadTrainerScreenPosition
global TrainerEngage
global CheckForEngagingTrainers
global SaveEndBattleTextPointers
global GetSavedEndBattleTextPointer
global EngageMapTrainer
global PrintEndBattleText
global PlayTrainerMusic
global GetTrainerInformation
global GetTrainerName
global w_trainer_header_ptr

; ============================================================================
section .bss
; Flat header pointer (supersedes pret's emulated wTrainerHeaderPtr — see header note).
w_trainer_header_ptr:  resd 1
; CheckForEngagingTrainers scans with a flat header cursor; b/c are consumed by
; FlagAction, so the cursor can't live in EBX. Keep it here.
cef_header_cursor:     resd 1

section .data
; ---- data/trainers/encounter_types.asm (Tier-1: trainer-music class lists) ----
; small, deterministic, class-id membership lists — inlined as flat data.
FemaleTrainerList:
    db OPP_LASS
    db OPP_JR_TRAINER_F
    db OPP_BEAUTY
    db OPP_COOLTRAINER_F
    db 0xFF                         ; end
EvilTrainerList:
    db OPP_UNUSED_JUGGLER
    db OPP_GAMBLER
    db OPP_ROCKER
    db OPP_JUGGLER
    db OPP_CHIEF
    db OPP_SCIENTIST
    db OPP_GIOVANNI
    db OPP_ROCKET
    db 0xFF                         ; end

; EmotionBubble OAM block (tile id, attributes) — pret EmotionBubblesOAMBlock
EmotionBubblesOAMBlock:
    db 0xF8, 0
    db 0xF9, 0
    db 0xFA, 0
    db 0xFB, 0

; Overworld emotion-bubble tiles (pret gfx/emotes/*.2bpp). Defines EmotionBubbles /
; EmotionBubbleGfx + EMOTE_TILE_BYTES/EMOTE_TILES_PER_BUBBLE/EMOTE_BUBBLE_BYTES/NUM_EMOTES.
%include "assets/emotes.inc"

; ============================================================================
section .text

; ----------------------------------------------------------------------------
; StoreTrainerHeaderPointer — [w_trainer_header_ptr] = ESI (flat header base)
; pret: home/trainers.asm:StoreTrainerHeaderPointer (stores hl in wTrainerHeaderPtr)
; In: ESI = flat header base.  All else preserved.
; ----------------------------------------------------------------------------
StoreTrainerHeaderPointer:
    mov [w_trainer_header_ptr], esi
    ret

; ----------------------------------------------------------------------------
; ExecuteCurMapScriptInTable — run the current map sub-script from a jumptable.
; pret: home/trainers.asm:ExecuteCurMapScriptInTable
; In:  AL  = map-script index (unless overridden by wStatusFlags7 BIT_USE_CUR_MAP_SCRIPT)
;      ESI = flat trainer-header base (stored for the map's trainers)
;      EDI = flat function-pointer jumptable (pret's `de`)
; Out: AL  = wCurMapScript after dispatch
; ----------------------------------------------------------------------------
ExecuteCurMapScriptInTable:
    push eax                        ; save script index
    call StoreTrainerHeaderPointer  ; [w_trainer_header_ptr] = ESI
    ; test-and-reset BIT_USE_CUR_MAP_SCRIPT (capture bit before clearing it)
    mov cl, [ebp + wStatusFlags7]
    and byte [ebp + wStatusFlags7], ~(1 << BIT_USE_CUR_MAP_SCRIPT)
    pop eax
    test cl, (1 << BIT_USE_CUR_MAP_SCRIPT)
    jz .useProvidedIndex            ; not overridden: use caller's index
    mov al, [ebp + wCurMapScript]   ; overridden: use the stored current index
.useProvidedIndex:
    mov [ebp + wCurMapScript], al
    mov esi, edi                    ; ESI = flat jumptable for CallFunctionInTable
    call CallFunctionInTable        ; calls table[AL] (flat dd)
    mov al, [ebp + wCurMapScript]
    ret

; ----------------------------------------------------------------------------
; LoadGymLeaderAndCityName — copy gym city + leader names.
; pret: home/trainers.asm:LoadGymLeaderAndCityName
; In (pret ABI, register-mapped): ESI (hl) = city-name source GB offset,
;                                 EDX (de) = leader-name source GB offset.
; CopyData is src(ESI)->dst(EDX), BX=count; dst must be a GB OFFSET in DX
; (CopyData does movzx edi,dx / lea edi,[ebp+edi]), NOT an [ebp+..] lea.
; OW-A.9 fix: two ABI bugs corrected — (1) dst was in EDI (CopyData ignores EDI,
; reads dst from DX) → wrote to garbage; (2) the entry `push esi/pop esi` restored
; the CITY src as the leader src (would copy the city name into wGymLeaderName).
; Now push edx/pop esi, matching pret's push de / pop hl (leader src arrives in DE).
; ----------------------------------------------------------------------------
LoadGymLeaderAndCityName:
    ; --- city name: src ESI, dst wGymCityName, len GYM_CITY_LENGTH ---
    push edx                        ; pret: push de — save leader-name src
    mov edx, wGymCityName           ; dst GB offset (DX), pret: ld de, wGymCityName
    mov ebx, GYM_CITY_LENGTH        ; count (BX)
    call CopyData                   ; [ebp+ESI] -> [ebp+wGymCityName]
    ; --- leader name: src ESI = leader src, dst wGymLeaderName, len NAME_LENGTH ---
    pop esi                         ; pret: pop hl — ESI = leader-name src
    mov edx, wGymLeaderName         ; dst GB offset (DX)
    mov ebx, NAME_LENGTH
    call CopyData                   ; [ebp+ESI] -> [ebp+wGymLeaderName]
    ret

; ----------------------------------------------------------------------------
; ReadTrainerHeaderInfo — read a field from the current trainer header.
; pret: home/trainers.asm:ReadTrainerHeaderInfo.  Selector ABI preserved.
; In:  AL = selector: 0->flag bit, 2->flag ptr, 4->before, 6->after, 8->end-win, $a->end-lose
; Out: sel 0 : wTrainerHeaderFlagBit = flag_bit ; ESI = flat header base
;      sel 2 : ESI = flag_ptr (GB WRAM offset)
;      sel 4/6/8 : ESI = flat text ptr
;      sel $a : EDX = flat text ptr (pret's `de`)
; Preserves EDX except on sel $a (by design).  Clobbers AL (pret restores; callers reload).
; ----------------------------------------------------------------------------
ReadTrainerHeaderInfo:
    push edi
    movzx eax, al
    mov edi, [w_trainer_header_ptr] ; flat header base
    test al, al
    jnz .nonZero
    ; sel 0
    mov cl, [edi + TH_FLAG_BIT]     ; FLAT read
    mov [ebp + wTrainerHeaderFlagBit], cl
    mov esi, edi                    ; return base in ESI (CheckForEngagingTrainers needs it)
    pop edi
    ret
.nonZero:
    cmp al, 2
    je .pFlag
    cmp al, 4
    je .pBefore
    cmp al, 6
    je .pAfter
    cmp al, 8
    je .pEndWin
    cmp al, 0x0a
    je .pEndLose
    pop edi                         ; other selectors: no-op (pret .done)
    ret
.pFlag:
    mov esi, [edi + TH_FLAG_PTR]
    pop edi
    ret
.pBefore:
    mov esi, [edi + TH_BEFORE_TXT]
    pop edi
    ret
.pAfter:
    mov esi, [edi + TH_AFTER_TXT]
    pop edi
    ret
.pEndWin:
    mov esi, [edi + TH_END_WIN]
    pop edi
    ret
.pEndLose:
    mov edx, [edi + TH_END_LOSE]    ; into "de"
    pop edi
    ret

; ----------------------------------------------------------------------------
; TrainerFlagAction — persistent trainer-beaten flag op (FLAG_TEST/SET/RESET).
; pret: home/trainers.asm:TrainerFlagAction  (predef_jump FlagActionPredef)
; The port calls the FlagAction leaf directly (regs set by hand) — same faithful
; equivalent used elsewhere (see item_predicates.asm note).  This is the PERSISTENT
; replacement for map_sprites.asm's non-persistent npc_beaten_flags (see header).
; In:  ESI = flag array base (GB WRAM offset, e.g. wEventFlags+N), CL = bit, BH = action.
; Out: CL = result (FLAG_TEST).
; ----------------------------------------------------------------------------
TrainerFlagAction:
    jmp FlagAction

; ----------------------------------------------------------------------------
; TalkToTrainer — player talks to (or is engaged by) a trainer.
; pret: home/trainers.asm:TalkToTrainer
; In: ESI = flat trainer header base.
; ----------------------------------------------------------------------------
TalkToTrainer:
    call StoreTrainerHeaderPointer  ; [ptr] = ESI
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: flag bit -> wTrainerHeaderFlagBit
    mov al, 2
    call ReadTrainerHeaderInfo      ; sel 2: ESI = flag_ptr
    mov cl, [ebp + wTrainerHeaderFlagBit]
    mov bh, FLAG_TEST
    call TrainerFlagAction          ; CL = beaten bit (ESI = flag_ptr from sel 2)
    test cl, cl
    jz .trainerNotYetFought
    ; already fought -> print after-battle text
    mov al, 6
    call ReadTrainerHeaderInfo      ; sel 6: ESI = after-battle text (flat)
    jmp PrintText
.trainerNotYetFought:
    mov al, 4
    call ReadTrainerHeaderInfo      ; sel 4: ESI = before-battle text (flat)
    call PrintText
    mov al, 0x0a
    call ReadTrainerHeaderInfo      ; sel $a: EDX = end-lose text
    push edx                        ; pret: push de
    mov al, 8
    call ReadTrainerHeaderInfo      ; sel 8: ESI = end-win text (hl)
    pop edx                         ; pret: pop de (lose)
    call SaveEndBattleTextPointers  ; hl=ESI(win), de=EDX(lose)
    or byte [ebp + wStatusFlags7], (1 << BIT_USE_CUR_MAP_SCRIPT) ; arm map-script override
    ; if already engaged (trainer saw the player) return; the sight flow drives battle.
    test byte [ebp + wMiscFlags], (1 << BIT_SEEN_BY_TRAINER)
    jnz .done
    ; player talked of his own volition:
    call EngageMapTrainer
    inc byte [ebp + wCurMapScript]  ; advance map script (next = EndTrainerBattle)
    jmp StartTrainerBattle          ; TODO(M8.2 follow-up): M8.1 owns StartTrainerBattle
.done:
    ret

; ----------------------------------------------------------------------------
; CheckFightingMapTrainers — any trainer seeing the player and wanting to fight?
; pret: home/trainers.asm:CheckFightingMapTrainers (_DEBUG B-skip omitted — no _DEBUG)
; This is the faithful, persistent replacement for map_sprites.asm's bespoke
; CheckTrainerSight (root rewires OverworldLoop's sight hook here later — see SUMMARY).
; ----------------------------------------------------------------------------
CheckFightingMapTrainers:
    call CheckForEngagingTrainers
    mov al, [ebp + wSpriteIndex]
    cmp al, 0xff
    jne .trainerEngaging
    ; none engaging: clear state
    xor al, al
    mov [ebp + wSpriteIndex], al
    mov [ebp + wTrainerHeaderFlagBit], al
    ret
.trainerEngaging:
    or byte [ebp + wStatusFlags7], (1 << BIT_TRAINER_BATTLE)
    mov [ebp + wEmotionBubbleSpriteIndex], al    ; a = engaging sprite index
    xor al, al                                   ; EXCLAMATION_BUBBLE (0)
    mov [ebp + wWhichEmotionBubble], al
    call EmotionBubble                           ; pret: predef EmotionBubble
    mov al, PAD_CTRL_PAD
    mov [ebp + wJoyIgnore], al
    xor al, al
    mov [ebp + hJoyHeld], al
    call TrainerWalkUpToPlayer_Bank0
    inc byte [ebp + wCurMapScript]  ; next = DisplayEnemyTrainerTextAndStartBattle
    ret

; ----------------------------------------------------------------------------
; DisplayEnemyTrainerTextAndStartBattle — after the trainer has walked up.
; pret: home/trainers.asm:DisplayEnemyTrainerTextAndStartBattle (falls into StartTrainerBattle)
; ----------------------------------------------------------------------------
DisplayEnemyTrainerTextAndStartBattle:
    mov al, [ebp + wStatusFlags5]
    and al, (1 << BIT_SCRIPTED_NPC_MOVEMENT)
    jz .doneWalking
    ret                             ; trainer still walking to the player
.doneWalking:
    mov [ebp + wJoyIgnore], al      ; a = 0 here
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    call DisplayTextID
    jmp StartTrainerBattle          ; TODO(M8.2 follow-up): M8.1 owns StartTrainerBattle

; ----------------------------------------------------------------------------
; TrainerWalkUpToPlayer_Bank0 — pret farjp TrainerWalkUpToPlayer (flat: direct jmp).
; ----------------------------------------------------------------------------
TrainerWalkUpToPlayer_Bank0:
    jmp TrainerWalkUpToPlayer

; ----------------------------------------------------------------------------
; TrainerWalkUpToPlayer — make the engaging trainer walk up to the player.
; pret: engine/overworld/trainer_sight.asm:TrainerWalkUpToPlayer
; Uses the port scripted-movement primitive MoveSprite_ (EDI=flat stream,
; H_CURRENT_SPRITE_OFFSET=slot*0x10).
; ----------------------------------------------------------------------------
TrainerWalkUpToPlayer:
    mov al, [ebp + wSpriteIndex]
    shl al, 4                       ; swap-nibble equiv for a<16 (slot*0x10)
    mov [ebp + wTrainerSpriteOffset], al
    call ReadTrainerScreenPosition
    mov al, [ebp + wTrainerFacingDirection]
    test al, al
    jz .facingDown                  ; SPRITE_FACING_DOWN
    cmp al, SPRITE_FACING_UP
    je .facingUp
    cmp al, SPRITE_FACING_LEFT
    je .facingLeft
    jmp .facingRight
.facingDown:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c                    ; fixed player screen Y
    call CalcDifference             ; AL = |screenY - 0x3c|
    cmp al, 0x10
    je .retEarly                    ; already right above player
    shr al, 4                       ; pret: swap a. Here AL is a block-aligned pixel
                                    ; distance (multiple of $10 from CalcDifference), so
                                    ; swap DIVIDES by 16 → block/step count. (Was shl,
                                    ; which overflowed AL to 0 → dec → $FF steps → 255-byte
                                    ; FillMemory into the 10-byte wNPCMovementDirections2.)
    dec al
    mov bl, al                      ; c = steps to go
    mov al, NPC_MOVEMENT_DOWN       ; 0x00
    jmp .writeWalkScript
.facingUp:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_UP
    jmp .writeWalkScript
.facingRight:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40                    ; fixed player screen X
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_RIGHT
    jmp .writeWalkScript
.facingLeft:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40
    call CalcDifference
    cmp al, 0x10
    je .retEarly
    shr al, 4                       ; pret: swap a = divide (block-aligned distance); see .facingDown
    dec al
    mov bl, al
    mov al, NPC_MOVEMENT_LEFT
.writeWalkScript:
    ; pret: fill wNPCMovementDirections2 with `a` for `c` bytes, then $ff sentinel.
    ; Port FillMemory: In ESI=dst GB offset, BX=count, AL=value; ESI unchanged on return.
    ; So BL already holds the step count (c); BH still holds the CalcDifference operand —
    ; save the direction, set up regs.
    push eax                        ; save direction byte (AL)
    movzx ebx, bl                   ; count -> full BX (BH cleared)
    mov esi, wNPCMovementDirections2
    pop eax                         ; AL = direction
    call FillMemory                 ; fill BX dir bytes at [ebp+ESI]
    ; end-of-list sentinel. ESI==wNPCMovementDirections2 (const) here and is
    ; unchanged by FillMemory, so fold it into the displacement (x86 allows only
    ; base+index, not base+index+index).
    mov byte [ebp + ebx + wNPCMovementDirections2], 0xff
    mov al, [ebp + wSpriteIndex]
    shl al, 4
    mov [ebp + H_CURRENT_SPRITE_OFFSET], al  ; port MoveSprite_ selector (pret hSpriteIndex)
    lea edi, [ebp + wNPCMovementDirections2] ; flat stream ptr for MoveSprite_
    ; TODO(M8.2 follow-up): confirm MoveSprite_ EDI/hCurrentSpriteOffset contract at wiring.
    jmp MoveSprite_
.retEarly:
    ret

; ----------------------------------------------------------------------------
; ReadTrainerScreenPosition — wTrainerScreenY/X from the trainer's sprite slot.
; pret: engine/overworld/trainer_sight.asm:ReadTrainerScreenPosition
; Reads wSpriteStateData1[offset + YPIXELS/XPIXELS], offset = wTrainerSpriteOffset.
; ----------------------------------------------------------------------------
ReadTrainerScreenPosition:
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    mov [ebp + wTrainerScreenY], al
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + wTrainerScreenX], al
    ret

; ----------------------------------------------------------------------------
; TrainerEngage — is this trainer lined up + able to see the player? engage if so.
; pret: engine/overworld/trainer_sight.asm:TrainerEngage (predef in pret; direct call here)
; In: wTrainerSpriteOffset (slot*0x10), wTrainerEngageDistance set by caller.
; Out: wTrainerSpriteOffset = $ff if engaging, 0 otherwise.
; ----------------------------------------------------------------------------
TrainerEngage:
    ; sprite on screen? (IMAGEINDEX != $ff)
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_IMAGEINDEX]
    cmp al, 0xff
    je .noEngage                    ; sprite off screen
    ; facing dir
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_FACINGDIRECTION]
    mov [ebp + wTrainerFacingDirection], al
    call ReadTrainerScreenPosition
    ; lined up on Y? (screenY == $3c)
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    je .linedUpY
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    je .linedUpX
    jmp .noEngage
.linedUpY:
    mov al, [ebp + wTrainerScreenX]
    mov bh, al
    mov al, 0x40
    call CalcDifference             ; AL = distance, ZF if equal
    jz .noEngage
    call CheckSpriteCanSeePlayer    ; CF=1 => can see
    jc .engage
    jmp .noEngage
.linedUpX:
    mov al, [ebp + wTrainerScreenY]
    mov bh, al
    mov al, 0x3c
    call CalcDifference
    jz .noEngage
    call CheckSpriteCanSeePlayer
    jc .engage
    jmp .noEngage
.engage:
    call CheckPlayerIsInFrontOfSprite  ; sets wTrainerSpriteOffset ($ff/0)
    mov al, [ebp + wTrainerSpriteOffset]
    test al, al
    jz .noEngage
    or byte [ebp + wMiscFlags], (1 << BIT_SEEN_BY_TRAINER)
    call EngageMapTrainer
    mov byte [ebp + wTrainerSpriteOffset], 0xff
    ret
.noEngage:
    mov byte [ebp + wTrainerSpriteOffset], 0
    ret

; ----------------------------------------------------------------------------
; CheckSpriteCanSeePlayer — lined-up + within engage distance?
; pret: engine/overworld/trainer_sight.asm:CheckSpriteCanSeePlayer
; In: AL = distance player<->sprite.  Out: CF=1 if in line & in range.
; ----------------------------------------------------------------------------
CheckSpriteCanSeePlayer:
    mov bh, al                      ; b = distance
    mov al, [ebp + wTrainerEngageDistance]
    cmp al, bh                      ; engageDist >= dist?  (CF=0 => can reach)
    jc .notInLine                   ; engageDist < dist => too far
    mov al, [ebp + wTrainerFacingDirection]
    cmp al, SPRITE_FACING_DOWN
    je .checkXCoord
    cmp al, SPRITE_FACING_UP
    je .checkXCoord
    cmp al, SPRITE_FACING_LEFT
    je .checkYCoord
    cmp al, SPRITE_FACING_RIGHT
    je .checkYCoord
    jmp .notInLine
.checkXCoord:
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    je .inLine
    jmp .notInLine
.checkYCoord:
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jne .notInLine
.inLine:
    stc
    ret
.notInLine:
    clc
    ret

; ----------------------------------------------------------------------------
; CheckPlayerIsInFrontOfSprite — is the player in front of (not behind) the sprite?
; pret: engine/overworld/trainer_sight.asm:CheckPlayerIsInFrontOfSprite
; Out: wTrainerSpriteOffset = $ff (engage) or 0 (no engage).
; ----------------------------------------------------------------------------
CheckPlayerIsInFrontOfSprite:
    mov al, [ebp + wCurMap]
    cmp al, POWER_PLANT
    je .engage                      ; Power Plant bypass (fake-item Voltorbs)
    movzx esi, byte [ebp + wTrainerSpriteOffset]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    cmp al, 0xfc                    ; topmost tile special-case
    jne .notOnTopmostTile
    mov al, 0x0c
.notOnTopmostTile:
    mov [ebp + wTrainerScreenY], al
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    mov [ebp + wTrainerScreenX], al
    mov al, [ebp + wTrainerFacingDirection]
    cmp al, SPRITE_FACING_DOWN
    jne .notFacingDown
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jb .engage                      ; sprite above player
    jmp .noEngage
.notFacingDown:
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    mov al, [ebp + wTrainerScreenY]
    cmp al, 0x3c
    jae .engage                     ; sprite below player
    jmp .noEngage
.notFacingUp:
    cmp al, SPRITE_FACING_LEFT
    jne .notFacingLeft
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    jae .engage                     ; sprite right of player
    jmp .noEngage
.notFacingLeft:
    ; facing right
    mov al, [ebp + wTrainerScreenX]
    cmp al, 0x40
    jae .noEngage                   ; sprite right of player
.engage:
    mov byte [ebp + wTrainerSpriteOffset], 0xff
    ret
.noEngage:
    mov byte [ebp + wTrainerSpriteOffset], 0
    ret

; ----------------------------------------------------------------------------
; CheckForEngagingTrainers — scan the map's trainer headers for one engaging.
; pret: home/trainers.asm:CheckForEngagingTrainers
; Requires w_trainer_header_ptr already set to the map's header table (map _Script does
; this).  Iterates flat headers by TH_SIZE; per header runs TrainerEngage.
; Out: wSpriteIndex = engaging trainer's flag bit, or unchanged $-1 sentinel on none.
; ----------------------------------------------------------------------------
CheckForEngagingTrainers:
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: ESI = flat header base
    mov [cef_header_cursor], esi    ; de = header base (flat cursor)
.trainerLoop:
    mov esi, [cef_header_cursor]
    call StoreTrainerHeaderPointer  ; [ptr] = current header (ESI)
    mov edi, [cef_header_cursor]
    mov al, [edi + TH_FLAG_BIT]     ; flag bit (FLAT read via cursor = pret ld a,[de])
    mov [ebp + wSpriteIndex], al
    mov [ebp + wTrainerHeaderFlagBit], al
    cmp al, 0xff                    ; -1 terminator
    je .doneNone
    mov al, 2
    call ReadTrainerHeaderInfo      ; sel 2: ESI = flag_ptr
    mov bh, FLAG_TEST
    mov cl, [ebp + wTrainerHeaderFlagBit]
    call TrainerFlagAction          ; CL = beaten?
    test cl, cl
    jnz .continue                   ; already defeated -> skip
    ; not defeated: set up engage distance + sprite offset, run TrainerEngage
    xor eax, eax
    call ReadTrainerHeaderInfo      ; sel 0: ESI = header base
    ; view range at header+1 (pret: inc hl; ld a,[hl])
    mov al, [esi + TH_VIEW_RANGE]
    mov [ebp + wTrainerEngageDistance], al
    mov al, [ebp + wSpriteIndex]
    shl al, 4                       ; pret: swap a (slot*0x10)
    mov [ebp + wTrainerSpriteOffset], al
    call TrainerEngage              ; pret: predef TrainerEngage
    mov al, [ebp + wTrainerSpriteOffset]
    test al, al
    jnz .engaging                   ; nonzero ($ff) -> engaging: stop
.continue:
    add dword [cef_header_cursor], TH_SIZE   ; pret: hl=$c; add hl,de; de=hl
    jmp .trainerLoop
.engaging:
    ret
.doneNone:
    ret

; ----------------------------------------------------------------------------
; SaveEndBattleTextPointers — stash win/lose end-battle text pointers + bank.
; pret: home/trainers.asm:SaveEndBattleTextPointers
; In: ESI = win text (flat), EDX = lose text (flat).  (flat-adapted: 4-byte slots)
; ----------------------------------------------------------------------------
SaveEndBattleTextPointers:
    mov al, [ebp + hLoadedROMBank]  ; TODO-HW: bank meaningless under flat model; kept faithful
    mov [ebp + wEndBattleTextRomBank], al
    mov [ebp + wEndBattleWinTextPointer], esi
    mov [ebp + wEndBattleLoseTextPointer], edx
    ret

; ----------------------------------------------------------------------------
; GetSavedEndBattleTextPointer — pick win/lose text by battle result.
; pret: home/trainers.asm:GetSavedEndBattleTextPointer
; Out: ESI = flat text ptr for the outcome.
; ----------------------------------------------------------------------------
GetSavedEndBattleTextPointer:
    mov al, [ebp + wBattleResult]
    test al, al
    jnz .lost
    mov esi, [ebp + wEndBattleWinTextPointer]
    ret
.lost:
    mov esi, [ebp + wEndBattleLoseTextPointer]
    ret

; ----------------------------------------------------------------------------
; EngageMapTrainer — load the engaged trainer's class/set + play battle music.
; pret: home/trainers.asm:EngageMapTrainer
; In: wSpriteIndex = engaged trainer's sprite id.  Reads wMapSpriteExtraData[(idx-1)*2].
; NOTE: wMapSpriteExtraData is populated by M8.1 (InitMapSprites currently discards
;       trainer class/num) — until M8.1 lands this reads zeros. (root wiring note)
; ----------------------------------------------------------------------------
EngageMapTrainer:
    movzx eax, byte [ebp + wSpriteIndex]
    dec eax
    add eax, eax                    ; (idx-1)*2
    lea esi, [ebp + eax + wMapSpriteExtraData]
    mov al, [esi]                   ; trainer class
    mov [ebp + wEngagedTrainerClass], al
    mov al, [esi + 1]               ; trainer mon set
    mov [ebp + wEngagedTrainerSet], al
    jmp PlayTrainerMusic

; ----------------------------------------------------------------------------
; PrintEndBattleText — print the saved end-battle text (once), after a trainer battle.
; pret: home/trainers.asm:PrintEndBattleText
; ----------------------------------------------------------------------------
PrintEndBattleText:
    test byte [ebp + wStatusFlags3], (1 << BIT_PRINT_END_BATTLE_TEXT)
    jz .noText
    and byte [ebp + wStatusFlags3], ~(1 << BIT_PRINT_END_BATTLE_TEXT)
    ; TODO-HW: bank save/restore is a no-op under the flat model (kept structurally).
    call SaveTrainerName            ; TODO(M8.2 follow-up): unported
    mov esi, TrainerEndBattleText   ; flat text-script
    call PrintText
    call SetEnemyTrainerToStayAndFaceAnyDirection ; TODO(M8.2 follow-up): unported
    jmp WaitForSoundToFinish        ; pret: jp WaitForSoundToFinish (real, OW-A.14)
.noText:
    and byte [ebp + wStatusFlags3], ~(1 << BIT_PRINT_END_BATTLE_TEXT)
    ret

; ----------------------------------------------------------------------------
; TrainerEndBattleText — text-script: trainer name, then the saved end-battle text.
; pret: home/trainers.asm:TrainerEndBattleText  (text_far _TrainerNameText / text_asm)
; Encoded as a flat text-script: $17 (TX_FAR) <dd flat ptr>, $08 (TX_ASM) marker
; meant to run the TrainerEndBattleText_asm callback below.
;
; OW-A.9 KNOWN-BROKEN, DEFERRED (file is check-only; not on any live path today):
;   1. The port's TextCommandProcessor treats $08 (TX_ASM) as a silent no-operand
;      SKIP (text.asm:959) — it does NOT dispatch the callback. So TrainerEndBattleText_asm
;      is DEAD, and after the skip the processor parses into the callback's machine-code
;      bytes as if they were text opcodes (garbage run-on). Cross-cutting with the same
;      TX_ASM gap in charge.asm.
;   2. TX_FAR here points at _TrainerNameText, which is Tier-1 text NOT yet generated
;      into the port (extern, unresolved as data).
; Two unblock paths (pick when the deps land): (a) add real TX_ASM ($08) dispatch to
; TextCommandProcessor, or (b) bypass the script — have PrintEndBattleText call the
; trainer-name print + GetSavedEndBattleTextPointer/PrintText directly. Both need the
; _TrainerNameText Tier-1 text generated first. Left as-is until then.
; ----------------------------------------------------------------------------
TrainerEndBattleText:
    db 0x17                         ; TX_FAR
    dd _TrainerNameText             ; flat far-text ptr (extern; Tier-1 text — NOT in port)
    db 0x08                         ; TX_ASM (run the routine below)
TrainerEndBattleText_asm:
    call GetSavedEndBattleTextPointer   ; ESI = outcome text
    call TextCommandProcessor
    jmp TextScriptEnd

; ----------------------------------------------------------------------------
; PlayTrainerMusic — pick + play the pre-battle trainer music.
; pret: home/trainers.asm:PlayTrainerMusic
; ----------------------------------------------------------------------------
PlayTrainerMusic:
    mov al, [ebp + wEngagedTrainerClass]
    cmp al, OPP_RIVAL1
    je .retNow
    cmp al, OPP_RIVAL2
    je .retNow
    cmp al, OPP_RIVAL3
    je .retNow
    cmp byte [ebp + wGymLeaderNo], 0
    jne .retNow                     ; gym leaders keep the gym music
    xor al, al                              ; pret: xor a
    mov [ebp + wAudioFadeOutControl], al    ;   ld [wAudioFadeOutControl], a
    call StopAllMusic
    ; pret: ld a, BANK(Music_MeetEvilTrainer) / ld [wAudioROMBank],a /
    ;       ld [wAudioSavedROMBank],a. The real engine selects the song table by
    ; wAudioROMBank (home/audio.asm:PlaySound), so this IS load-bearing now (OW-A.14).
    mov al, MUSIC_MEET_EVIL_TRAINER_BANK
    mov [ebp + wAudioROMBank], al
    mov [ebp + wAudioSavedROMBank], al
    mov bh, [ebp + wEngagedTrainerClass]   ; b = class to search
    mov esi, EvilTrainerList
.evilLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .noEvil
    cmp al, bh
    jne .evilLoop
    mov al, MUSIC_MEET_EVIL_TRAINER
    jmp .play
.noEvil:
    mov esi, FemaleTrainerList
.femaleLoop:
    mov al, [esi]
    inc esi
    cmp al, 0xff
    je .male
    cmp al, bh
    jne .femaleLoop
    mov al, MUSIC_MEET_FEMALE_TRAINER
    jmp .play
.male:
    mov al, MUSIC_MEET_MALE_TRAINER
.play:
    ; pret: ld [wNewSoundID], a; jp PlaySound.  Port PlaySound takes the id in AL.
    jmp PlaySound
.retNow:
    ret

; ============================================================================
; home/trainers2.asm
; ============================================================================

; ----------------------------------------------------------------------------
; GetTrainerInformation — load the trainer's name + battle pic pointer + prize money.
; pret: home/trainers2.asm:GetTrainerInformation
; Adapted to the port's SPLIT flat tables (TrainerPicPointers / TrainerBaseMoney),
; not pret's interleaved TrainerPicAndMoneyPointers (5 bytes/entry).
; ----------------------------------------------------------------------------
GetTrainerInformation:
    call GetTrainerName
    mov al, [ebp + wLinkState]
    test al, al
    jnz .linkBattle
    ; class index = wTrainerClass - 1
    movzx eax, byte [ebp + wTrainerClass]
    dec eax
    ; wTrainerPicPointer (flat dword) = TrainerPicPointers[idx]
    mov edi, [TrainerPicPointers + eax*4]
    mov [ebp + wTrainerPicPointer], edi
    ; wTrainerBaseMoney (2-byte dw, pret ram/wram.asm:1400 `wTrainerBaseMoney:: dw`)
    ; = the TOP 2 BCD bytes of this class's bcd3 base money. OW-A.9: pret
    ; GetTrainerInformation (home/trainers2.asm) copies exactly 2 bytes — the low BCD
    ; byte (always $00 for the shipped values, e.g. 1500 = $00 $15 $00) is DELIBERATELY
    ; dropped (Gen-1 money-width quirk). The port previously copied all 3, which BOTH
    ; diverged from pret's value AND overflowed the 2-byte field by 1 byte into
    ; wTrainerBaseMoney+2 (a foreign WRAM cell). Copy 2 now, matching pret.
    lea esi, [eax + eax*2]                      ; idx*3 (bcd3 stride into the split table)
    add esi, TrainerBaseMoney
    mov al, [esi]                               ; high BCD byte
    mov [ebp + wTrainerBaseMoney + 0], al
    mov al, [esi + 1]                           ; second BCD byte (pret keeps 2, drops [esi+2])
    mov [ebp + wTrainerBaseMoney + 1], al
    call IsFightingJessieJames
    ret
.linkBattle:
    mov edi, PlayerPicFront         ; pret RedPicFront
    mov [ebp + wTrainerPicPointer], edi
    ret

; ----------------------------------------------------------------------------
; IsFightingJessieJames — override the pic for the Jessie&James Rocket duo.
; pret: home/trainers2.asm:IsFightingJessieJames
; ----------------------------------------------------------------------------
IsFightingJessieJames:
    mov al, [ebp + wTrainerClass]
    cmp al, ROCKET
    jne .ret
    mov al, [ebp + wTrainerNo]
    cmp al, 0x2a
    jb .ret                         ; below the Jessie&James range
    ; both the <$2e and >=$2e pret branches use JessieJamesPic (the second is a no-op dup)
    mov edi, JessieJamesPic         ; TODO(M8.2 follow-up): pic not in port table yet
    mov [ebp + wTrainerPicPointer], edi
.ret:
    ret

; ----------------------------------------------------------------------------
; GetTrainerName — pret farjp GetTrainerName_ (flat: direct jmp).
; pret: home/trainers2.asm:GetTrainerName
; ----------------------------------------------------------------------------
GetTrainerName:
    jmp GetTrainerName_

; ============================================================================
; engine/overworld/emotion_bubbles.asm
; ============================================================================

; ----------------------------------------------------------------------------
; EmotionBubble — draw an emotion bubble (e.g. "!") above a sprite for a beat.
; pret: engine/overworld/emotion_bubbles.asm:EmotionBubble
; In: wWhichEmotionBubble = which bubble, wEmotionBubbleSpriteIndex = target sprite.
; CopyVideoData is ported (copy2.asm); EmotionBubbleGfx is now generated
; (assets/emotes.inc). The gfx load below is fully wired; the only remaining gap is
; the WriteOAMBlock call further down (flat OAM block vs EBP-relative src — see there).
; ----------------------------------------------------------------------------
EmotionBubble:
    ; source tiles: EmotionBubbleGfx + (wWhichEmotionBubble & $f) * EMOTE_BUBBLE_BYTES.
    ; pret: `swap a` (*16) then four `add hl,bc` = *64 (each emote is 4 tiles = 64 bytes).
    mov al, [ebp + wWhichEmotionBubble]
    and al, 0x0f
    movzx ebx, al
    shl ebx, 6                      ; * EMOTE_BUBBLE_BYTES (64); was *16 (wrong stride)
    ; CopyVideoData ABI (copy2.asm:62): ESI = dst VRAM offset, EDX = flat src, BL = tiles.
    lea edx, [EmotionBubbleGfx + ebx]    ; EDX = flat source (was wrongly in ESI)
    mov esi, GB_VCHARS1_TILE78           ; ESI = dst VRAM offset (was wrongly in EDI)
    mov bl, EMOTE_TILES_PER_BUBBLE       ; BL = tile count 4 (was wrongly BH; BH = bank, flat no-op)
    call CopyVideoData
    ; force sprite updates on while the bubble shows
    mov al, [ebp + wUpdateSpritesEnabled]
    push eax
    mov byte [ebp + wUpdateSpritesEnabled], 0xff
    ; shift shadow-OAM forward 16 bytes to make room for the 4 bubble sprites.
    ; last-4-OAM reserved for shadow/rod if BIT_LEDGE_OR_FISHING set.
    test byte [ebp + wMovementFlags], (1 << BIT_LEDGE_OR_FISHING)
    jnz .reserved
    ; wShadowOAMSprite35Attributes -> wShadowOAMSprite39Attributes
    mov esi, W_SHADOW_OAM + 35*4 + 3
    mov edi, W_SHADOW_OAM + 39*4 + 3
    jmp .shift
.reserved:
    mov esi, W_SHADOW_OAM + 31*4 + 3
    mov edi, W_SHADOW_OAM + 35*4 + 3
.shift:
    mov ecx, 0x90
.shiftLoop:
    mov al, [ebp + esi]
    mov [ebp + edi], al
    dec esi
    dec edi
    dec ecx
    jnz .shiftLoop
    ; screen coords of the target sprite (YPIXELS -> b, XPIXELS+8 -> c)
    movzx esi, byte [ebp + wEmotionBubbleSpriteIndex]
    shl esi, 4                      ; slot*0x10
    mov bh, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_YPIXELS]
    mov al, [ebp + esi + W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS]
    add al, 8
    mov bl, al                      ; c = x+8
    ; WriteOAMBlock now takes the tile/attr source as a FLAT pointer in EDX
    ; (home/oam.asm — the OAM-block tables are flat .data labels, not GB offsets;
    ; the prior DX-as-GB-offset model was wrong for every caller). pret: ld de, block.
    mov edx, EmotionBubblesOAMBlock ; de = OAM block (flat)
    xor al, al
    call WriteOAMBlock
    mov bl, 60
    call DelayFrames                ; c = 60 frames
    pop eax
    mov [ebp + wUpdateSpritesEnabled], al
    call DelayFrame
    call UpdateSprites
    ret

; VRAM target for the emotion bubble tiles (vChars1 tile $78).
; TODO(M8.2 follow-up): confirm the port's vChars1 base + tile-$78 byte offset symbol.
; pret `vChars1 tile $78`: vChars1 = GB_VFONT ($8800), tile $78 → +$780 = $8F80.
; That is OBJ tile $F8 ($8000 + $F8*$10), matching EmotionBubblesOAMBlock's $F8-$FB ids.
; (Was 0x8000+0x780 = $8780 = OBJ tile $78 — wrong base; the OAM block reads tiles $F8+.)
GB_VCHARS1_TILE78 equ GB_VFONT + 0x780

; ============================================================================
; trainer_sight accessors (pret: engine/overworld/trainer_sight.asm)
; ============================================================================
; OW-1.7. The sight-line logic itself (TrainerEngage, CheckSpriteCanSeePlayer,
; CheckPlayerIsInFrontOfSprite, TrainerWalkUpToPlayer, ReadTrainerScreenPosition)
; is already ported above (M8.2). This section adds only the 5 pure position
; accessors: _GetSpritePosition1/2, _SetSpritePosition1/2, GetSpriteDataPointer.
; None pre-existed in this file before this section.
;
; Register map: A->AL, HL->ESI, DE->EDX (asm-translation skill). Every pret body
; here is straight-line loads/stores ending in `ret` — no branch reads a flag
; out of any of these, so no ZF/CF preservation concern applies.
;
; New symbols added here (none were already available via this file's includes):
;
;   WRAM (confident — derived the same way this file's existing wSpriteIndex
;   anchor was: assembled a truncated copy of ram/wram.asm (through the end of
;   its "WRAM" SECTION, i.e. through pret line 1894) with rgbasm/rgblink and
;   read the linked addresses. That relink reproduced wSpriteIndex at exactly
;   0xD1FF = 0xCF13 + 0x2EC — i.e. the same "clean = link − 0x2EC" correction
;   documented in m1_3_pending_symbols.inc for this working tree's over-budget
;   WRAM link. Applying that identical correction to the 3 sibling bytes
;   immediately follow wSavedSpriteScreenY at pret ram/wram.asm:1837-1840
;   (all plain `db`, no intervening UNION) gives:
;     wSavedSpriteScreenY  = 0xD12F  (pret ram/wram.asm:1837)
;     wSavedSpriteScreenX  = 0xD130  (pret ram/wram.asm:1838)
;     wSavedSpriteMapY     = 0xD131  (pret ram/wram.asm:1839)
;     wSavedSpriteMapX     = 0xD132  (pret ram/wram.asm:1840)
;   No collision with gb_memmap.inc or m8_2/m1_3_pending_symbols.inc (checked).
;
;   HRAM (new port allocation). Pret's hSpriteScreenYCoord/XCoord/MapYCoord/
;   MapXCoord union (ram/hram.asm:367-371) sits at a pret address the port does
;   NOT reuse — the port already remaps this exact HRAM neighborhood for other
;   symbols (hTextID/hSpriteIndex live at the port's own 0xFF8C, not pret's
;   0xFF82; see m1_3_pending_symbols.inc's "port REMAPS HRAM" note). So these 4
;   bytes are a fresh port-private scratch allocation (pret's original union is
;   likewise pure scratch — reused by unrelated systems between calls — so a
;   new home is behaviorally equivalent, just not byte-address-identical).
;   0xFF82-0xFF85 are the first 4 contiguous bytes free of any claim across
;   gb_memmap.inc / m8_2_pending_symbols.inc / m1_3_pending_symbols.inc
;   (verified by grep across dos_port/include and dos_port/src):
;     hSpriteScreenYCoord = 0xFF82
;     hSpriteScreenXCoord = 0xFF83
;     hSpriteMapYCoord    = 0xFF84
;     hSpriteMapXCoord    = 0xFF85
;   TODO(root): fold into gb_memmap.inc when the canonical HRAM map lands;
;   re-verify no collision once a full faithful HRAM re-layout exists.
; ----------------------------------------------------------------------------
%ifndef wSavedSpriteScreenY
wSavedSpriteScreenY equ 0xD12F
%endif
%ifndef wSavedSpriteScreenX
wSavedSpriteScreenX equ 0xD130
%endif
%ifndef wSavedSpriteMapY
wSavedSpriteMapY    equ 0xD131
%endif
%ifndef wSavedSpriteMapX
wSavedSpriteMapX    equ 0xD132
%endif
%ifndef hSpriteScreenYCoord
hSpriteScreenYCoord equ 0xFF82
%endif
%ifndef hSpriteScreenXCoord
hSpriteScreenXCoord equ 0xFF83
%endif
%ifndef hSpriteMapYCoord
hSpriteMapYCoord    equ 0xFF84
%endif
%ifndef hSpriteMapXCoord
hSpriteMapXCoord    equ 0xFF85
%endif

; Delta to hop from array1's XPIXELS[slot] to array2's MAPY[slot] (same slot).
; pret: `ld de, wSpritePlayerStateData2MapY - wSpritePlayerStateData1XPixels`
; — a 16-bit HL-wraparound trick specific to SM83 (wSpriteStateData2 is exactly
; wSpriteStateData1 + 0x100, page-aligned; see pret ram/wram.asm:139-142 ASSERTs).
; The port computes the identical byte delta as a plain positive x86 add
; (0x100 + SPRITESTATEDATA2_MAPY - SPRITESTATEDATA1_XPIXELS = 0xFE); no
; wraparound needed since ESI holds the full linear GB offset, not a 16-bit HL.
; PROJ: this replaces pret's two-instruction "ld de,const / add hl,de" with a
; single "add esi,const" (flags-neutral either way; nothing here branches on
; the result) — a 386+ simplification, not a behavior change.
SPRITE_XPIXELS_TO_MAPY_DELTA equ (W_SPRITE_STATE_DATA_2 + SPRITESTATEDATA2_MAPY) - (W_SPRITE_STATE_DATA_1 + SPRITESTATEDATA1_XPIXELS)

global _GetSpritePosition1
global _GetSpritePosition2
global _SetSpritePosition1
global _SetSpritePosition2
global GetSpriteDataPointer
global GetSpritePosition1
global GetSpritePosition2
global SetSpritePosition1
global SetSpritePosition2

; ----------------------------------------------------------------------------
; Get/SetSpritePosition1/2 — pret bank-wrapper trampolines (home/trainers.asm:246-262)
; around the byte-verified _Get/_SetSpritePosition1/2 below. pret loads the target
; into hl then `ld b, BANK("Trainer Sight") / jp Bankswitch`; under the port's flat
; model banking is a no-op, so each is a direct tail-jump. Called by
; scripts/OaksLab.asm (Oak cutscene, not yet ported) — provided so the pret labels
; resolve. OW-A.9.
; ----------------------------------------------------------------------------
GetSpritePosition1:
    jmp _GetSpritePosition1
GetSpritePosition2:
    jmp _GetSpritePosition2
SetSpritePosition1:
    jmp _SetSpritePosition1
SetSpritePosition2:
    jmp _SetSpritePosition2

; ----------------------------------------------------------------------------
; GetSpriteDataPointer — form a pointer into a sprite's wSpriteStateData1/2
; entry from a caller-supplied member offset + [hSpriteIndex] (raw slot 0-15,
; set by the caller just before this call — NOT pre-shifted).
; pret: engine/overworld/trainer_sight.asm:GetSpriteDataPointer
; In:  ESI = base (e.g. W_SPRITE_STATE_DATA_1), EDX = member offset within entry
;      [ebp+hSpriteIndex] = raw slot (0-15)
; Out: ESI = base + member + slot*0x10
; ----------------------------------------------------------------------------
GetSpriteDataPointer:
    push edx                        ; pret: push de
    add esi, edx                    ; pret: add hl, de   (hl = base + member)
    mov al, [ebp + hSpriteIndex]    ; pret: ldh a, [hSpriteIndex]
    shl al, 4                       ; pret: swap a       (slot<16 => *0x10)
    movzx edx, al                   ; pret: ld d,0 / ld e,a
    add esi, edx                    ; pret: add hl, de   (hl = base+member+slot*0x10)
    pop edx                         ; pret: pop de
    ret

; ----------------------------------------------------------------------------
; _GetSpritePosition1 — read [wSpriteIndex]'s screen Y/X + map Y/X into the
; hSprite*Coord HRAM scratch bytes.
; pret: engine/overworld/trainer_sight.asm:_GetSpritePosition1
; ----------------------------------------------------------------------------
_GetSpritePosition1:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer         ; ESI -> array1[slot].YPIXELS
    mov al, [ebp + esi]               ; SPRITESTATEDATA1_YPIXELS
    mov [ebp + hSpriteScreenYCoord], al
    mov al, [ebp + esi + 2]           ; SPRITESTATEDATA1_XPIXELS (YPIXELS+2)
    mov [ebp + hSpriteScreenXCoord], al
    add esi, 2                        ; ESI -> array1[slot].XPIXELS (pret's hl there)
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA  ; ESI -> array2[slot].MAPY (same slot)
    mov al, [ebp + esi]               ; SPRITESTATEDATA2_MAPY
    mov [ebp + hSpriteMapYCoord], al
    mov al, [ebp + esi + 1]           ; SPRITESTATEDATA2_MAPX (MAPY+1)
    mov [ebp + hSpriteMapXCoord], al
    ret

; ----------------------------------------------------------------------------
; _GetSpritePosition2 — same as _GetSpritePosition1 but into the wSavedSprite*
; WRAM scratch (stash a position, e.g. across a scripted-movement detour).
; pret: engine/overworld/trainer_sight.asm:_GetSpritePosition2
; ----------------------------------------------------------------------------
_GetSpritePosition2:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + esi]               ; SPRITESTATEDATA1_YPIXELS
    mov [ebp + wSavedSpriteScreenY], al
    mov al, [ebp + esi + 2]           ; SPRITESTATEDATA1_XPIXELS
    mov [ebp + wSavedSpriteScreenX], al
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + esi]               ; SPRITESTATEDATA2_MAPY
    mov [ebp + wSavedSpriteMapY], al
    mov al, [ebp + esi + 1]           ; SPRITESTATEDATA2_MAPX
    mov [ebp + wSavedSpriteMapX], al
    ret

; ----------------------------------------------------------------------------
; _SetSpritePosition1 — write hSprite*Coord back into [wSpriteIndex]'s entry.
; pret: engine/overworld/trainer_sight.asm:_SetSpritePosition1
; ----------------------------------------------------------------------------
_SetSpritePosition1:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + hSpriteScreenYCoord]
    mov [ebp + esi], al               ; SPRITESTATEDATA1_YPIXELS
    mov al, [ebp + hSpriteScreenXCoord]
    mov [ebp + esi + 2], al           ; SPRITESTATEDATA1_XPIXELS
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + hSpriteMapYCoord]
    mov [ebp + esi], al               ; SPRITESTATEDATA2_MAPY
    mov al, [ebp + hSpriteMapXCoord]
    mov [ebp + esi + 1], al           ; SPRITESTATEDATA2_MAPX
    ret

; ----------------------------------------------------------------------------
; _SetSpritePosition2 — write wSavedSprite* back into [wSpriteIndex]'s entry.
; pret: engine/overworld/trainer_sight.asm:_SetSpritePosition2
; ----------------------------------------------------------------------------
_SetSpritePosition2:
    mov al, [ebp + wSpriteIndex]
    mov [ebp + hSpriteIndex], al
    mov esi, W_SPRITE_STATE_DATA_1
    mov edx, SPRITESTATEDATA1_YPIXELS
    call GetSpriteDataPointer
    mov al, [ebp + wSavedSpriteScreenY]
    mov [ebp + esi], al               ; SPRITESTATEDATA1_YPIXELS
    mov al, [ebp + wSavedSpriteScreenX]
    mov [ebp + esi + 2], al           ; SPRITESTATEDATA1_XPIXELS
    add esi, 2
    add esi, SPRITE_XPIXELS_TO_MAPY_DELTA
    mov al, [ebp + wSavedSpriteMapY]
    mov [ebp + esi], al               ; SPRITESTATEDATA2_MAPY
    mov al, [ebp + wSavedSpriteMapX]
    mov [ebp + esi + 1], al           ; SPRITESTATEDATA2_MAPX
    ret
