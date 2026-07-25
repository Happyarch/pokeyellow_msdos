; reload_tiles.asm — ReloadMapData / ReloadTilesetTilePatterns (SM83 -> x86).
;
; Source: home/reload_tiles.asm:ReloadMapData / ReloadTilesetTilePatterns /
;         ChooseFlyDestination (pret/pokeyellow).
; Intended path: dos_port/src/home/reload_tiles.asm
;
; Thin wrappers around the already-ported tile loaders. The VRAM writes (and the
; g_tilecache_dirty flag) are done by the callees (LoadTextBoxTilePatterns,
; LoadCurrentMapView, LoadTilesetTilePatternData), so these wrappers only
; sequence them under the LCD-off bracket, exactly like pret.
;
; Bankswitching: faithful bookkeeping only. Under the flat model SwitchToMapRomBank
; and BankswitchCommon record the requested ROM bank but perform no physical
; MBC write (see src/home/bankswitch.asm). hLoadedROMBank is saved/restored to
; keep the value any later reader would observe consistent with pret.
;
; Build: nasm -f coff -I include/ -o reload_tiles.o reload_tiles.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global ReloadMapData
global ReloadTilesetTilePatterns
global ChooseFlyDestination

extern DisableLCD                   ; src/video/lcd_control.asm
extern EnableLCD                    ; src/video/lcd_control.asm
extern LoadTextBoxTilePatterns      ; src/home/load_font.asm
extern LoadCurrentMapView           ; src/engine/overworld/overworld.asm
extern LoadTilesetTilePatternData   ; src/engine/overworld/overworld.asm
extern SwitchToMapRomBank           ; flat-model bank bookkeeping (see note)
extern BankswitchCommon             ; src/home/bankswitch2.asm
extern LoadTownMap_Fly              ; src/engine/items/town_map.asm

section .text

; ---------------------------------------------------------------------------
; ReloadMapData — reload text-box tiles, current map view, and tileset tiles.
;   No inputs. Registers clobbered (faithful to pret).
; ---------------------------------------------------------------------------
ReloadMapData:
    mov al, [ebp + H_LOADED_ROM_BANK]   ; ldh a,[hLoadedROMBank]
    push eax                            ; push af
    mov al, [ebp + W_CUR_MAP]           ; ld a,[wCurMap]
    call SwitchToMapRomBank             ; select map bank (flat: bookkeeping)

    call DisableLCD
    call LoadTextBoxTilePatterns
    call LoadCurrentMapView
    call LoadTilesetTilePatternData
    call EnableLCD

    pop eax                             ; pop af
    call BankswitchCommon               ; restore original bank
    ret

; ---------------------------------------------------------------------------
; ChooseFlyDestination — show the Town Map and let the player pick a Fly target.
;   No inputs. Clears BIT_NO_BATTLES (so the arrival map does not suppress wild
;   battles), then tail-jumps into the linked Fly destination selector. On
;   return LoadTownMap_Fly has armed wDestinationMap + BIT_FLY_WARP (or left them
;   clear on a B-cancel), and its ret returns to ChooseFlyDestination's caller.
; DEVIATION{class=banking; pret=home/reload_tiles.asm:ChooseFlyDestination; behavior=flat jmp LoadTownMap_Fly instead of farjp via Bankswitch; evidence=port is a single flat address space so BANK(LoadTownMap_Fly)/Bankswitch is a no-op and the tail jump preserves the same caller-return contract; lifetime=permanent flat-memory boundary}
; ---------------------------------------------------------------------------
ChooseFlyDestination:
    ; ld hl, wStatusFlags4 / res BIT_NO_BATTLES, [hl]
    and byte [ebp + W_STATUS_FLAGS_4], ~(1 << BIT_NO_BATTLES) & 0xFF
    jmp LoadTownMap_Fly                 ; farjp LoadTownMap_Fly (tail — its ret → caller)

; ---------------------------------------------------------------------------
; ReloadTilesetTilePatterns — reload only the tileset tile patterns.
;   No inputs. Registers clobbered (faithful to pret).
; ---------------------------------------------------------------------------
ReloadTilesetTilePatterns:
    mov al, [ebp + H_LOADED_ROM_BANK]   ; ldh a,[hLoadedROMBank]
    push eax                            ; push af
    mov al, [ebp + W_CUR_MAP]           ; ld a,[wCurMap]
    call SwitchToMapRomBank             ; select map bank (flat: bookkeeping)

    call DisableLCD
    call LoadTilesetTilePatternData
    call EnableLCD

    pop eax                             ; pop af
    call BankswitchCommon               ; restore original bank
    ret
