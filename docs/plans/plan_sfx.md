# Sound Effects (SFX) Subsystem Plan — OPL3 Timbre Tuning

Active plan for sound effects in the Pokémon Yellow MS-DOS port.
Focus: 100% OPL3 FM sound quality across all game modes (including `/MT32`), eliminating the harsh static on Channel 8 (noise), and providing fast auditioning with a 2.5s replay delay.

## Stages

- [x] **Stage 1: Infrastructure & Pilot Batch**
  - [x] Add sound-design FM patches in `gen_opl_patches.py` (`noise_soft_whoosh`, `noise_heavy_thud`, `noise_crunch`, `noise_click`, `noise_poof`, `pulse_soft`).
  - [x] Create `dos_port/tools/audio/sfx/README.md` documenting the schema.
  - [x] Update `audition.py` and `opl_renderer.py` with SFX previewing and configurable `--delay` (default: 2.5s).
  - [x] Implement `tools/audio/gen_sfx_data.py` emitting `assets/sfx_data.inc` and wire into `Makefile`.
  - [x] Wire custom SFX patch lookup into `src/audio/opl_shim.asm`.
  - [x] Hand-craft pilot batch in `tools/audio/sfx/`:
    - `SFX_Go_Outside.yaml` (door whoosh)
    - `SFX_Super_Effective.yaml` (Tackle / heavy impact thud)
    - `SFX_Start_Menu.yaml` (clean menu click)
  - [x] Verify pilot batch via `audition.py` and in DOSBox-X (`DEBUG_AUDIO=1`).

- [x] **Stage 2: Batch A — Overworld, Movement & UI (Subagent Delegation)**
  - [x] Doors/Movement: `SFX_Go_Inside`, `SFX_Ledge`, `SFX_Run`, `SFX_Collision`
  - [x] Menu & Interaction: `SFX_Press_AB`, `SFX_Tink`, `SFX_Denied`, `SFX_Save`
  - [x] Environment/PC: `SFX_Turn_On_PC`, `SFX_Turn_Off_PC`, `SFX_Enter_PC`, `SFX_Withdraw_Deposit`, `SFX_Purchase`, `SFX_Swap`
  - [x] Audition and review Batch A.

- [x] **Stage 3: Batch B — Core Combat Impacts & Pokeballs (Subagent Delegation)**
  - [x] Combat damage: `SFX_Damage`, `SFX_Not_Very_Effective`, `SFX_Faint_Fall`, `SFX_Faint_Thud`
  - [x] Pokeballs: `SFX_Ball_Toss`, `SFX_Ball_Poof`, `SFX_Caught_Mon`
  - [x] Audition and review Batch B.

- [x] **Stage 4: Batch C — Specialized Battle Moves (Subagent Delegation)**
  - [x] Physical moves: `SFX_Pound`, `SFX_Doubleslap`, `SFX_Peck`, `SFX_Vine_Whip`
  - [x] Elemental / special moves: `SFX_Horn_Drill`, `SFX_Psybeam`, `SFX_Psychic_M`
  - [x] Audition and review Batch C.
