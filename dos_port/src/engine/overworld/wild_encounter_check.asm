; wild_encounter_check.asm — StepCountCheck / NewBattle / AllPokemonFainted /
; AnyPartyAlive (Wave 7, M7.1 — overworld wild-encounter + step counting).
;
; Faithful translation of the three step/encounter routines in pret
; home/overworld.asm:
;   StepCountCheck::      (home/overworld.asm:298-314) — per-step counter decrement
;   AllPokemonFainted::   (home/overworld.asm:316-320) — blackout jump target
;   NewBattle::           (home/overworld.asm:324-336) — wild/trainer encounter gate
; plus the party-HP scan helper AnyPartyAlive (pret engine, `callfar AnyPartyAlive`
; at home/overworld.asm:289) that NewBattle's blackout decision reads.
;
; --------------------------------------------------------------------------
; SAFETY / GATING (read before enabling the live encounter)
; --------------------------------------------------------------------------
; StepCountCheck and AnyPartyAlive are self-contained (they only touch WRAM) and
; are ALWAYS compiled + LINKED. StepCountCheck is wired unconditionally into
; OverworldLoop: it merely decrements wStepCounter / the no-random-battle cooldown
; and nothing in the current port reads wStepCounter, so it has zero visible effect
; on the default build — it just starts keeping the step books faithfully.
;
; NewBattle + AllPokemonFainted are compiled ONLY under -D WILD_ENCOUNTERS_LIVE
; because they are not safe to run live yet:
;   * NewBattle calls TryDoWildEncounter, which is itself CHECK-only in the tree
;     (wild_encounters.asm externs the still-deferred overworld helpers
;     IsPlayerStandingOnDoorTileOrWarpTile / IsPlayerJustOutsideMap), so pulling
;     NewBattle into a linked object would drag those unresolved externs and break
;     the whole EXE link.
;   * The faithful post-battle return path (pret .battleOccurred -> EnterMap, a full
;     map reload) is not built into the port's OverworldLoop yet, so a live battle
;     would leave the player stranded on return.
;   * IsPlayerCharacterBeingControlledByGame and HandleBlackOut do not exist in the
;     port yet (follow-up members).
; So NewBattle is "wired but gated": OverworldLoop's `call NewBattle` is behind the
; same WILD_ENCOUNTERS_LIVE guard. Default build = StepCountCheck only.
;
; NAMING NOTE (important divergence): pret's NewBattle does `farjp InitBattle`, and
; pret's InitBattle (engine/battle/init_battle.asm) is the ENCOUNTER GATE — it runs
; DetermineWildOpponent -> TryDoWildEncounter before falling into the battle-screen
; setup. The PORT's `InitBattle` (dos_port/src/engine/battle/init_battle.asm) is
; ONLY the battle-screen setup (the DEBUG_BATTLE path) and does NOT roll an
; encounter. So a faithful port NewBattle cannot just call the port InitBattle
; (that would always start a battle with no roll). Instead NewBattle here inlines
; pret InitBattle's DetermineWildOpponent gate (wCurOpponent / no-random-steps /
; TryDoWildEncounter) and only then calls the port InitBattle for the screen.
;
; Register map: a=AL, hl=ESI, bc=BX, de=DX (d=DH); EBP = GB memory base;
; GB memory = [EBP + addr].
;
; Build (default, LINK):  nasm -f coff -I include/ -I . -o wild_encounter_check.o \
;                             wild_encounter_check.asm
; Build (gated, CHECK):   nasm -f coff -I include/ -I . -D WILD_ENCOUNTERS_LIVE \
;                             -o /dev/null wild_encounter_check.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

; --------------------------------------------------------------------------
; Symbols missing from gb_memmap.inc / gb_constants.inc (see SUMMARY "missing
; symbols"). Defined locally here because those shared files are outside this
; member's lane. Addresses derived from W_IGNORE_INPUT_COUNTER = 0xD139
; (pret wIgnoreInputCounter, ram/wram.asm:1848); wStepCounter and
; wNumberOfNoRandomBattleStepsLeft are the next two db's (ram/wram.asm:1851,1854).
; Bit values from constants/ram_constants.asm:87,95,106. NOTE: NASM %ifndef does
; NOT detect `equ` labels, so these cannot be %ifndef-guarded against a future
; memmap definition — at integration, add them to gb_memmap.inc/gb_constants.inc
; and DELETE these local defs (do not keep both, or NASM redefinition-errors).
wStepCounter                    equ 0xD13A
wNumberOfNoRandomBattleStepsLeft equ 0xD13B
BIT_WILD_ENCOUNTER_COOLDOWN     equ 0        ; wStatusFlags2 bit 0
BIT_ON_DUNGEON_WARP             equ 4        ; wStatusFlags3 bit 4
BIT_NO_BATTLES                  equ 4        ; wStatusFlags4 bit 4

section .text

global StepCountCheck
global AnyPartyAlive

%ifdef WILD_ENCOUNTERS_LIVE
global NewBattle
global AllPokemonFainted
extern TryDoWildEncounter                    ; wild_encounters.asm (CHECK-only today)
extern InitBattle                            ; battle-screen setup (NOT the pret gate)
extern IsPlayerCharacterBeingControlledByGame ; MISSING — follow-up dep
extern RunMapScript                          ; run_map_script.asm (exists)
extern HandleBlackOut                        ; MISSING — follow-up dep
%endif

; --------------------------------------------------------------------------
; StepCountCheck — decrement the per-step counters (pret home/overworld.asm:298).
; If simulated joypad input is active (scripted movement) it does nothing, so
; scripted door-exit steps don't count. Otherwise it decrements wStepCounter, and
; — only while the post-battle "no random battle" cooldown is armed — decrements
; wNumberOfNoRandomBattleStepsLeft, clearing the cooldown bit when it hits 0.
; Touches WRAM only; safe to call unconditionally.
; --------------------------------------------------------------------------
StepCountCheck:
    test byte [ebp + W_STATUS_FLAGS_5], (1 << BIT_SCRIPTED_MOVEMENT_STATE)
    jnz .doneStepCounting                     ; jr nz — inputs simulated, don't count
    dec byte [ebp + wStepCounter]             ; dec [hl] (wStepCounter)
    test byte [ebp + W_STATUS_FLAGS_2], (1 << BIT_WILD_ENCOUNTER_COOLDOWN)
    jz .doneStepCounting                      ; cooldown not armed
    dec byte [ebp + wNumberOfNoRandomBattleStepsLeft]
    jnz .doneStepCounting                     ; still counting down
    and byte [ebp + W_STATUS_FLAGS_2], (~(1 << BIT_WILD_ENCOUNTER_COOLDOWN)) & 0xFF
.doneStepCounting:
    ret

; --------------------------------------------------------------------------
; AnyPartyAlive — OR together every party mon's 2-byte HP. Returns the OR in DH
; (pret returns it in d): DH == 0 => all party mons fainted; DH != 0 => at least
; one is alive. This is pret's `callfar AnyPartyAlive` (home/overworld.asm:289),
; the scan NewBattle's blackout decision consumes. Self-contained; LINK-clean.
; Guard: pret assumes wPartyCount >= 1; the port adds a count==0 -> DH=0 guard so
; an empty/uninitialised party can't spin the loop 2^32 times.
; --------------------------------------------------------------------------
AnyPartyAlive:
    movzx ecx, byte [ebp + wPartyCount]       ; e = party count
    xor al, al
    test ecx, ecx
    jz .done                                  ; port safety: empty party => all fainted
    lea esi, [ebp + wPartyMon1 + MON_HP]      ; hl = &wPartyMon1HP (0xD16B)
.partyLoop:
    or al, [esi]                              ; HP high byte
    or al, [esi + 1]                          ; HP low byte
    add esi, PARTYMON_STRUCT_LENGTH           ; next party mon (44 bytes)
    dec ecx
    jnz .partyLoop
.done:
    mov dh, al                                ; d = OR of all HP bytes
    ret

%ifdef WILD_ENCOUNTERS_LIVE
; --------------------------------------------------------------------------
; NewBattle — determine whether a battle happens this step and, if so, run it.
; Sets CF if a battle occurred, clears CF otherwise (pret home/overworld.asm:324).
; See the NAMING NOTE at the top: this inlines pret InitBattle's DetermineWildOpponent
; gate because the port's InitBattle is screen-setup only.
; --------------------------------------------------------------------------
NewBattle:
    test byte [ebp + W_STATUS_FLAGS_3], (1 << BIT_ON_DUNGEON_WARP)
    jnz .noBattle                             ; on a dungeon warp — no battle
    call IsPlayerCharacterBeingControlledByGame
    jnz .noBattle                             ; player under game control — no battle
    test byte [ebp + W_STATUS_FLAGS_4], (1 << BIT_NO_BATTLES)
    jnz .noBattle                             ; battles suppressed — no battle
    ; --- pret InitBattle / DetermineWildOpponent gate (engine/battle/init_battle.asm) ---
    mov al, [ebp + wCurOpponent]
    test al, al
    jnz .forcedOpponent                       ; wCurOpponent != 0 => forced (InitOpponent)
    ; DetermineWildOpponent:
    mov al, [ebp + wNumberOfNoRandomBattleStepsLeft]
    test al, al
    jnz .noBattle                             ; ret nz — still in no-battle window
    call TryDoWildEncounter                    ; ZF set => encounter, ZF clear => none
    jnz .noBattle                             ; ret nz — no wild encounter this step
    jmp .startBattle
.forcedOpponent:
    mov [ebp + wCurPartySpecies], al          ; InitOpponent: wCurPartySpecies = opponent
    mov [ebp + wEnemyMonSpecies2], al
.startBattle:
    call InitBattle                            ; port InitBattle = battle-screen setup
    ; TODO(M7.1 follow-up): faithful flow returns through _InitBattleCommon and the
    ; caller does the post-battle EnterMap (full map reload). That re-entry is not
    ; built into OverworldLoop yet — hence the WILD_ENCOUNTERS_LIVE gate.
    stc                                        ; scf — a battle occurred
    ret
.noBattle:
    clc                                        ; and a — CF=0, no battle
    ret

; --------------------------------------------------------------------------
; AllPokemonFainted — the whole party fainted mid-overworld: flag "battle lost"
; and hand off to the blackout handler (pret home/overworld.asm:316).
; --------------------------------------------------------------------------
AllPokemonFainted:
    mov byte [ebp + wIsInBattle], 0xFF         ; wIsInBattle = $ff (lost)
    call RunMapScript
    jmp HandleBlackOut
%endif  ; WILD_ENCOUNTERS_LIVE
