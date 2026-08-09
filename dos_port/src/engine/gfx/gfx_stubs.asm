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
; STUB{class=stub; label=HandleBadgeFaceAttributes; pret=engine/gfx/bg_map_attributes.asm:HandleBadgeFaceAttributes; behavior=unearned badge faces keep the earned palette instead of being zeroed, because the port has no per-cell attribute channel to clear and does not model wTrainerCardBadgeAttributes; evidence=pret zeroes individual vBGMap1 cells at fixed offsets, which the port's per-tile-id tile_pal cannot express; lifetime=retire with the per-cell attribute layer and the wTrainerCardBadgeAttributes buffer}
HandleBadgeFaceAttributes:
    ret

; ---------------------------------------------------------------------------
; HandlePartyHPBarAttributes — pret engine/gfx/bg_map_attributes.asm
;
; Writes per-cell attributes over each party member's HP bar so the six bars can
; show green/yellow/red independently, reading wPartyHPBarAttributes. Reached
; from LoadBGMapAttributes when c == 5 (the party menu).
;
; TODO(cgb-colour Stage 4): this is the one screen whose attributes are per-cell
; BY CONSTRUCTION — the six bars share one set of HP-bar tile ids under three
; different palettes, so it cannot be expressed per tile id at all and is not a
; candidate for the Stage 1 resolve-at-load-time path. It needs the per-cell
; attribute layer plus the wPartyHPBarAttributes buffer.
;
; STUB{class=stub; label=HandlePartyHPBarAttributes; pret=engine/gfx/bg_map_attributes.asm:HandlePartyHPBarAttributes; behavior=all six party HP bars render in one palette instead of per-mon green/yellow/red, because the six bars reuse the same HP-bar tile ids and the port resolves palette per tile id; evidence=pret writes 7 attribute cells per bar from wPartyHPBarAttributes, a per-cell assignment with no per-tile-id equivalent; lifetime=retire with the per-cell attribute layer and the wPartyHPBarAttributes buffer}
HandlePartyHPBarAttributes:
    ret
