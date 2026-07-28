; save_stubs.asm — ret-only stage-5 disk-boundary seams for resident SRAM.
;
; The in-memory SRAM realization (engine/menus/save.asm plus the boot loader) calls
; these port-only HAL entry points, but the real DOS .dsv v2 raw-image bodies are
; owned by docs/current_plan_sram_pc_storage.md stage 5.  Keep them here, not in
; dsv_io.asm, so the deferred disk boundary is easy to retire.

bits 32

section .text

; SramLoadImage — stage 5 raw 32 KiB SRAM image load seam.
; TODO(sram_pc_storage stage 5): replace with the real disk body that loads bank 0
; at $A000 and banks 1-3 at $22000..$27FFF.
; DEVIATION{class=stub; pret=engine/menus/save.asm:TryLoadSaveFile; behavior=SramLoadImage is a ret-only port HAL seam so boot keeps the zeroed resident SRAM image until stage 5 supplies raw image I/O; evidence=current_plan_sram_pc_storage assigns SramLoadImage to maintainers and this branch must link before that body exists; lifetime=until stage 5 implements the raw SRAM image loader}
global SramLoadImage
SramLoadImage:
    ret

; SramStoreImage — stage 5 raw 32 KiB SRAM image store seam.
; TODO(sram_pc_storage stage 5): replace with the real disk body that stores bank 0
; at $A000 plus banks 1-3 at $22000..$27FFF as a raw SRAM image.
; DEVIATION{class=stub; pret=engine/menus/save.asm:SaveGameData; behavior=SramStoreImage is a ret-only port HAL seam so save commits update only resident memory until stage 5 supplies raw image I/O; evidence=current_plan_sram_pc_storage assigns SramStoreImage to maintainers and forbids editing dsv_io.asm in stage 4; lifetime=until stage 5 implements the raw SRAM image writer}
global SramStoreImage
SramStoreImage:
    ret
