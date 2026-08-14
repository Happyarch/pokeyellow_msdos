; gfx_stubs.asm — link-time stand-ins for engine/gfx routines not yet translated.
;
; Retire a stub by deleting it here and repointing the extern comments that name
; this file (tools/label_status --callers <Label>).

bits 32
%include "gb_memmap.inc"

global HandlePartyHPBarAttributes

section .text

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
