; gfx_stubs.asm — link-time stand-ins for engine/gfx routines not yet translated.
;
; Retire a stub by deleting it here and repointing the extern comments that name
; this file (tools/label_status --callers <Label>).

bits 32
%include "gb_memmap.inc"

global HandleBadgeFaceAttributes
global HandlePartyHPBarAttributes

section .text

; ---------------------------------------------------------------------------
; HandleBadgeFaceAttributes — pret engine/gfx/bg_map_attributes.asm
;
; Zeroes the trainer card's per-badge attribute cells for badges the player has
; not earned, reading wTrainerCardBadgeAttributes. Reached from
; LoadBGMapAttributes when c == 4 (the trainer card).
;
; TODO(cgb-colour Stage 4): needs wTrainerCardBadgeAttributes, a WRAM buffer the
; port does not model yet, and a per-cell attribute channel to zero — the port
; resolves attributes per tile id, so "blank this cell" has no representation
; while a badge's tiles are shared with an earned badge. Live in the build: the
; trainer card is reachable, so this IS called; it currently leaves every badge
; face at its earned-badge palette.
;
; TRACED 2026-08-14. Two of the three things that looked like blockers are not.
;
;   * PLANE: the WINDOW one. StartMenu_TrainerInfo -> trainer_card_present, which
;     mirrors via tc_mirror and shows GB_TILEMAP1 as one window. The publisher is
;     SetBGCellAttrWin (ppu.asm), not SetBGCellAttrFlat.
;
;   * pret's LITERAL OFFSETS TRANSFER. tc_mirror is 1:1 -- W_TILEMAP row r at
;     stride TCSCR_W becomes GB_TILEMAP1 + r*32, columns 0-19 -- so a GB
;     coordinate IS a GB_TILEMAP1 offset and vBGMap1 + $183 is GB_TILEMAP1 + $183.
;     (An earlier note here warned that the port re-origins the rect. That is
;     true only of BadgesTestMirror, which serves the TEST gate RunDrawBadgesTest
;     and moves rows 11-16/cols 2-17 to rows 0-5/col 0. It is NOT the live path.)
;
;   * GEOMETRY AGREES. pret zeroes a 2x2 box per badge at vBGMap1 $183 $187 $18b
;     $18f $1e3 $1e7 $1eb $1ef = rows 12 and 15, columns 3/7/11/15.
;     ZeroOutCurrentBadgeAttributes writes base, base+1, base+32, base+33 -- a
;     clean 2x2 (the `ld bc,$1f` reads like a staircase until you notice the
;     second store does not post-increment). The port draws its grid at scratch
;     rows 11 and 14 from column 2, so each badge's FACE cell lands exactly there.
;
; *** AND THE BUFFER THIS WAS WAITING FOR IS NEVER WRITTEN BY PRET. ***
; Measured tree-wide: wTrainerCardBadgeAttributes appears ONLY as the eight reads
; inside HandleBadgeFaceAttributes plus its ram/wram.asm declaration. Nothing
; populates it. (Control: the same grep over wPartyMenuBlkPacket does find its
; writers, so the search shape is sound.) So the `ld a,[de] / and a / call z`
; test is not driven by badge state at all, and pret's own comment -- "zero out
; the attributes if the player doesn't have the respective badge" -- describes
; INTENT, not behaviour. With the buffer reading zero, the call fires for every
; badge and ALL eight faces are zeroed regardless of what the player earned.
;
; *** ANSWERED, AND IT IS NOT ZERO: THE BUFFER IS A UNION ALIAS. ***
; wTrainerCardBadgeAttributes is $CC5D (pokeyellow.sym) and sits inside a UNION
; in ram/wram.asm. The same 55 bytes are also the misc battle-data block
; (wEnemyBideAccumulatedDamage / wEnemyNumHits, ending at wMiscBattleDataEnd) and
; wPikaPicUsedGFXCount / wPikaPicUsedGFX. So "nothing writes it" is true only OF
; THE NAME: those bytes are written constantly under the aliases, and what
; HandleBadgeFaceAttributes reads is whatever the battle engine or the Pikachu
; pic animator last left there. The earlier guess that it reads zero -- and the
; tidy conclusion that the faithful port is an unconditional publish -- are both
; WITHDRAWN.
;
; Consequence for pret: the routine's own comment ("zero out the attributes if
; the player doesn't have the respective badge") cannot be what it does. The test
; is driven by stale unrelated data, so which badge faces get zeroed depends on
; what happened before the card was opened, not on which badges were earned.
;
; Consequence for the port: this is CHEAP to reproduce exactly, because the port
; models the GB address space FLAT -- the union aliasing happens for free, the
; same byte at the same address. A literal translation would be faithful garbage
; and all, needing no new buffer.
;
; SO WHAT IS LEFT IS A JUDGEMENT, NOT AN UNKNOWN, and it wants the maintainer:
; faithfully reproducing a read of aliased stale data is arguably porting an
; upstream defect, which is what the structured defect annotation and
; BUG_FIX_LEVEL exist for. NOT TRACED: which alias is
; actually live when the card opens. Pikachu-pic data is the plausible one (the
; card is reached from the START menu in the overworld, where Pikachu follows the
; player), and if it is non-zero the faces are NOT zeroed -- which is what this
; stub already does, though by accident rather than by construction.
;
; STUB{class=stub; label=HandleBadgeFaceAttributes; pret=engine/gfx/bg_map_attributes.asm:HandleBadgeFaceAttributes; behavior=unearned badge faces keep the earned palette instead of being zeroed, because the port has no per-cell attribute channel to clear and does not model wTrainerCardBadgeAttributes; evidence=pret zeroes individual vBGMap1 cells at fixed offsets, which the port's per-tile-id tile_pal cannot express; lifetime=mechanism and geometry are fully traced and a literal translation would be faithful for free because the port models GB memory flat so the buffer's UNION aliasing reproduces itself, leaving only a maintainer judgement on whether reproducing pret's read of aliased stale battle or Pikachu-pic data is porting a defect that wants a BUG annotation}
HandleBadgeFaceAttributes:
    ret

; ---------------------------------------------------------------------------
; HandlePartyHPBarAttributes — pret engine/gfx/bg_map_attributes.asm
;
; Writes per-cell attributes over each party member's HP bar so the six bars can
; show green/yellow/red independently, reading wPartyHPBarAttributes. Reached
; from LoadBGMapAttributes when c == 5 (the party menu).
;
; THE OBSERVABLE DEFECT THIS STUB USED TO CAUSE IS FIXED (3975ae039). The six
; party HP bars DO now show per-mon green/yellow/red: SetPartyMenuHPBarColor
; publishes each bar's six gauge cells into the window per-cell attribute plane
; (ppu.asm win_cell_attr / SetBGCellAttrWin). Measured at pixel level, including
; a per-row control in which the six bars take three different palette slots.
;
; So what remains here is STRUCTURAL, not visible: the port reaches the result
; through the CALLER, where pret reaches it through this routine plus the
; wPartyHPBarAttributes buffer. The split is forced by addressing — pret's
; per-cell writes are indexed by ROW INDEX, the port's plane by SCREEN CELL, and
; only SetPartyMenuHPBarColor holds the live bar coordinate.
;
; Do NOT "fix" this by also publishing from here: that would colour the same six
; cells twice from two sources of truth for the party menu's layout.
;
; STUB{class=stub; label=HandlePartyHPBarAttributes; pret=engine/gfx/bg_map_attributes.asm:HandlePartyHPBarAttributes; behavior=this routine does nothing where pret writes 7 attribute cells per bar, so the port models no wPartyHPBarAttributes buffer, though the per-mon HP-bar colours it exists to produce ARE produced by SetPartyMenuHPBarColor publishing into the window per-cell attribute plane; evidence=pixelcheck partymenu shows the six bars taking three different palette slots under a per-row control, and pret's writes are indexed by row where the port's plane is indexed by screen cell so only the caller holds the live coordinate; lifetime=retire if the port ever grows a row-indexed party-menu layout table that would let the publish live here as pret has it}
HandlePartyHPBarAttributes:
    ret
