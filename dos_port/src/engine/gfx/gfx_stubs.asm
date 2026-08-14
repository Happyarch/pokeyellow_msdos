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
; TRACED 2026-08-14, so the next attempt starts here rather than re-deriving it:
;   * PLANE: the WINDOW one. The trainer card mirrors its badge rect into
;     GB_TILEMAP1 and shows it through UI_TRAINER_CARD_BADGES, so the publisher
;     is SetBGCellAttrWin (ppu.asm), not SetBGCellAttrFlat.
;   * LIVE, not harness-only: DrawBadges is called from StartMenu_TrainerInfo
;     (engine/menus/start_sub_menus.asm), as well as from two test gates.
;   * GEOMETRY AGREES. pret zeroes a 2x2 attribute box per badge at vBGMap1
;     offsets $183 $187 $18b $18f $1e3 $1e7 $1eb $1ef -- rows 12 and 15, columns
;     3, 7, 11, 15. The port draws its badge grid at scratch rows 11 and 14 from
;     column 2, so each badge's FACE cell lands exactly on pret's coordinates.
;   * THE CATCH, and it is why this is not a five-line change: the port
;     RE-ORIGINS the rect when mirroring. BadgesTestMirror copies scratch rows
;     11-16 / columns 2-17 to GB_TILEMAP1 rows 0-5 / column 0, so pret's literal
;     vBGMap1 offsets do NOT transfer -- they must have the mirror's transform
;     applied. NOT VERIFIED: whether the LIVE StartMenu_TrainerInfo path uses
;     that same mirror or a different presentation. Check that first.
;   * Still unmodelled either way: the wTrainerCardBadgeAttributes buffer, which
;     is what says whether a badge is earned.
;
; STUB{class=stub; label=HandleBadgeFaceAttributes; pret=engine/gfx/bg_map_attributes.asm:HandleBadgeFaceAttributes; behavior=unearned badge faces keep the earned palette instead of being zeroed, because the port has no per-cell attribute channel to clear and does not model wTrainerCardBadgeAttributes; evidence=pret zeroes individual vBGMap1 cells at fixed offsets, which the port's per-tile-id tile_pal cannot express; lifetime=the per-cell layer exists and the plane is now traced as the WINDOW one so the remaining blockers are the wTrainerCardBadgeAttributes buffer and the fact that the port re-origins the badge rect when mirroring it to GB_TILEMAP1 which means pret's literal vBGMap1 offsets cannot be reused verbatim}
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
