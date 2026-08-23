; entry.asm — DPMI entry point, GB memory allocation, command-line parsing,
;
; DEVIATION{class=HAL; pret=home/init.asm:Init; behavior=program bring-up allocates the emulated GB address space from DPMI, normalizes the DS and SS selectors to a flat 4 GB model, parses the DOS command line and runs the frame loop, replacing the cartridge reset vector and boot sequence; evidence=the DJGPP coff-go32-exe stub enters here after DPMI setup and the selector bases are not linear 0, so EBP-relative GB memory access requires the explicit rebase this file performs; lifetime=permanent, the DPMI entry boundary is by design}
; and the main 60 Hz frame loop.
;
; The DJGPP coff-go32-exe stub handles DPMI setup before jumping here.
; By the time 'start' executes we are in 32-bit protected mode, BUT:
;
;   IMPORTANT: the DS/CS selectors have their base at the program image,
;   NOT at linear address 0. Raw linear addresses (VGA 0xA0000, DPMI
;   allocation results, PSP segment*16) must be biased by -ds_base before
;   use as DS-relative offsets. We also raise the DS limit to 4 GB
;   (DPMI fn 0008h) so the biased offsets don't fault — this is exactly
;   what DJGPP's __djgpp_nearptr_enable() does.
;
; Build: nasm -f coff -I include/ -I . -o entry.o entry.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

; Total emulated allocation: 64 KB GB window + 8 KB CGB VRAM1 + 320x200
; back buffer + resident SRAM banks 1-3 at $22000..$27FFF.
GB_TOTAL_SIZE   equ GB_SRAM_END                    ; 0x28000 (160 KiB)

; ---------------------------------------------------------------------------
; External symbols from other boot modules
; ---------------------------------------------------------------------------
extern video_init        ; boot/video.asm
extern pit_init          ; boot/timing.asm
extern pit_restore       ; boot/timing.asm
extern joypad_init       ; src/input/joypad.asm
extern joypad_restore    ; src/input/joypad.asm
extern audio_init        ; src/audio/audio_hal.asm
extern NetInit           ; src/net/net_hal.asm — link-cable transport bind
extern NetShutdown       ; src/net/net_hal.asm — UART vector/PIC restore
extern g_net_com_sel     ; src/net/net_hal.asm — /COM1-4 -> 1..4
extern g_net_baud_div    ; src/net/net_hal.asm — /BAUD=n -> 115200/n divisor
extern g_net_linklog     ; src/net/net_hal.asm — /LINKLOG flag
extern g_net_ipx_sel     ; src/net/net_hal.asm — /IPX flag (Stage 6 step 1)
extern g_net_ipx_socket  ; src/net/net_hal.asm — /IPXSOCK=n override
extern g_pkt_int      ; src/net/pktdrv.asm — /PKTINT=0xNN override (Stage 7
                       ; step 1; 0 = auto-scan 0x60-0x80). Not consumed by
                       ; NetInit yet — pktdrv.asm links unreferenced until
                       ; Stage 7 step 2 (net_ip.asm) wires the transport in.
extern g_cfg_partyb      ; src/engine/debug/debug_party.asm — /PARTYB flag (tradecheck harness)
extern audio_shutdown    ; src/audio/audio_hal.asm
extern SramLoadImage     ; src/save/dsv_io.asm — POKEMON.DSV -> SRAM banks at boot
extern g_cfg_nosound     ; src/audio/audio_hal.asm — set by /NOSOUND
extern g_cfg_midi        ; src/audio/mpu401.asm — /MT32 = 1, /GM = 2
extern g_cfg_shim        ; src/audio/audio_hal.asm — /TANDY = 2, /SPK = 3
extern g_cfg_noenh       ; src/audio/audio_hal.asm — set by /NOENH
extern g_cfg_musicloop   ; src/audio/audio_hal.asm — set by /LOOP
extern Init              ; src/home/init.asm — power-on init
%ifdef DEBUG_AUDIO
extern RunAudioTest      ; src/debug/debug_dump.asm — audio-engine gate
%endif
%ifdef DEBUG_CALCSTATS
extern RunCalcStatsTest  ; src/debug/debug_dump.asm — Pokémon CalcStats gate
%endif
%ifdef DEBUG_PARTY
extern RunPartySeedTest  ; src/debug/debug_dump.asm — party/bag runtime-seed gate
%endif

; ---------------------------------------------------------------------------
; Exported symbols
; ---------------------------------------------------------------------------
global start
global ds_base           ; linear base address of our DS selector
global cleanup           ; called by src/home/vblank.asm when pad_quit is set

; ---------------------------------------------------------------------------
; BSS (zeroed by the stub before start)
; ---------------------------------------------------------------------------
section .bss
align 4
ds_base:        resd 1       ; linear base of DS (for linear→offset bias)
gb_mem_base:    resd 1       ; DS-relative base of the GB allocation (= EBP)
dpmi_handle:    resd 1       ; DPMI memory block handle (SI:DI), for fn 0502h

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
section .data
align 4

; Command-line argument tokens (matched case-sensitively as typed)
arg_nosound:  db '/NOSOUND', 0
arg_mt32:     db '/MT32',    0
arg_gm:       db '/GM',      0
arg_tandy:    db '/TANDY',   0
arg_spk:      db '/SPK',     0
arg_noenh:    db '/NOENH',   0
arg_loop:     db '/LOOP',    0
; Link-cable transport selection (docs/current_plan_link_cable.md Stage 2).
arg_com1:     db '/COM1',    0
arg_com2:     db '/COM2',    0
arg_com3:     db '/COM3',    0
arg_com4:     db '/COM4',    0
arg_baud:     db '/BAUD=',   0
arg_linklog:  db '/LINKLOG', 0
arg_ipx:      db '/IPX',     0     ; Stage 6 step 1 (docs/current_plan_link_cable.md)
arg_ipxsock:  db '/IPXSOCK=',0     ; note: this is a literal substring of the
                                    ; token above, so "/IPXSOCK=n" alone (no
                                    ; separate "/IPX") also sets g_net_ipx_sel
                                    ; via find_token's plain substring match —
                                    ; benign (giving a socket override implies
                                    ; IPX intent), same tolerance the existing
                                    ; /MT32 vs /GM ordering note nearby accepts
; DEBUG_TRADECHECK two-instance harness (tools/tradecheck.sh): per-side party/
; identity selection, same clone-of-/LINKLOG pattern.
arg_partyb:   db '/PARTYB',  0
; Packet driver client (Stage 7 step 1, docs/current_plan_link_cable.md) —
; hex vector override, matched with find_token_pos like /BAUD=/IPXSOCK=.
arg_pktint:   db '/PKTINT=', 0

; ---------------------------------------------------------------------------
; Code
; ---------------------------------------------------------------------------
section .text

; ---------------------------------------------------------------------------
; start — program entry point
; ---------------------------------------------------------------------------
start:
    call setup_flat_access   ; get DS base, raise DS/SS limit to 4 GB
    call parse_cmdline       ; audio/debug options; bug-fix level is a BUILD option
    call alloc_gb_memory     ; EBP = DS-relative base of GB address space

    ; Zero-initialise the entire GB allocation (mimics GB power-up state)
    lea edi, [ebp]
    mov ecx, GB_TOTAL_SIZE / 4
    xor eax, eax
    rep stosd

    ; DEVIATION{class=HAL; pret=engine/menus/save.asm:TryLoadSaveFile; behavior=boot loads the raw resident SRAM image through a DOS HAL seam before any save routine reads sPlayerName or sGameData; evidence=current_plan_sram_pc_storage stage 4 seam contract names SramLoadImage and stage 5 owns the disk body; lifetime=until the disk boundary is implemented and this remains the permanent HAL call site}
    call SramLoadImage      ; stage 5 body overlays bank 0 plus banks 1-3, stub returns now

    call video_init          ; set VGA mode 13h
    call pit_init            ; reprogram PIT to ~60 Hz, install tick ISR
    call joypad_init         ; hook IRQ 1 (keyboard) → GB joypad state
    call audio_init          ; enable the engine + GB power-on audio state
    call NetInit             ; bind the /COMx link transport (no flag: no-op)

%ifdef DEBUG_AUDIO
    call RunAudioTest        ; play Pallet Town BGM 120 ticks, dump, exit (never returns)
%endif

%ifdef DEBUG_CALCSTATS
    call RunCalcStatsTest    ; compute known stats, dump DUMP.BIN, exit (never returns)
%endif
%ifdef DEBUG_PARTY
    call RunPartySeedTest    ; seed party+bag, dump DUMP.BIN, exit (never returns)
%endif

    call Init                ; power-on init → title screen (runs game loop)
    ; Execution reaches here only if Init returns without exiting via pad_quit.
    call cleanup
    mov ax, 0x4C00
    int 0x21

; ---------------------------------------------------------------------------
; setup_flat_access — fetch DS linear base and raise segment limits to 4 GB
;
; DPMI fn 0006h: get segment base address  (BX=selector → CX:DX = base)
; DPMI fn 0008h: set segment limit         (BX=selector, CX:DX = limit)
;
; With limit = 0xFFFFFFFF, DS-relative offsets wrap modulo 4 GB, so
; (linear - ds_base) reaches any linear address — the DJGPP nearptr model.
; ---------------------------------------------------------------------------
setup_flat_access:
    push eax
    push ebx
    push ecx
    push edx

    ; Get DS base
    mov ax, 0x0006
    mov bx, ds
    int 0x31
    jc  .fail
    movzx eax, cx
    shl eax, 16
    mov ax, dx
    mov [ds_base], eax

    ; Raise DS limit to 4 GB
    mov ax, 0x0008
    mov bx, ds
    mov cx, 0xFFFF
    mov dx, 0xFFFF
    int 0x31
    jc  .fail

    ; Alias ES to DS — rep movsb / rep stosb writes go to ES:EDI.
    ; If ES is a separate LDT entry it still has the original small limit;
    ; rep movsb to the GB allocation (above the original segment top) would
    ; then write to the wrong linear address silently instead of faulting.
    mov ax, ds
    mov es, ax

    ; Raise SS limit (harmless if SS == DS)
    mov ax, 0x0008
    mov bx, ss
    mov cx, 0xFFFF
    mov dx, 0xFFFF
    int 0x31

    ; Normalize SS to DS selector — [EBP+disp] uses SS by default.
    ; If SS base ≠ DS base, every EBP-relative GB access hits the wrong memory.
    mov ax, 0x0006
    mov bx, ss
    int 0x31
    movzx eax, cx
    shl eax, 16
    mov ax, dx
    sub eax, [ds_base]
    jz .ss_ok
    mov edx, eax
    mov ax, ds
    mov ss, ax
    add esp, edx
.ss_ok:

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

.fail:
    mov ax, 0x4C02
    int 0x21

; ---------------------------------------------------------------------------
; alloc_gb_memory — allocate GB_TOTAL_SIZE bytes via DPMI fn 0501h
; ---------------------------------------------------------------------------
alloc_gb_memory:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi

    mov ax, 0x0501
    mov ebx, GB_TOTAL_SIZE >> 16
    mov ecx, GB_TOTAL_SIZE & 0xFFFF
    int 0x31
    jc .alloc_failed

    movzx eax, si
    shl eax, 16
    movzx edx, di
    or  eax, edx
    mov [dpmi_handle], eax

    movzx eax, bx
    shl eax, 16
    movzx ecx, cx
    or  eax, ecx
    sub eax, [ds_base]
    mov [gb_mem_base], eax

    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax

    mov ebp, [gb_mem_base]
    ret

.alloc_failed:
    mov ax, 0x4C01
    int 0x21

; ---------------------------------------------------------------------------
; parse_cmdline — scan the DOS command line for the audio and debug options:
; /NOSOUND, /MT32, /GM, /TANDY, /SPK, /NOENH, /LOOP.
; ---------------------------------------------------------------------------
parse_cmdline:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    mov ah, 0x62
    int 0x21

    mov ax, bx
    call seg_to_flat         ; PSP: DPMI hosts return a SELECTOR in BX
    lea esi, [eax + 0x81]
    movzx ecx, byte [eax + 0x80]
    test ecx, ecx
    jz .done

    mov edi, arg_nosound
    call find_token
    jnz .no_nosound
    mov byte [g_cfg_nosound], 1
.no_nosound:

    mov edi, arg_mt32
    call find_token
    jnz .no_mt32
    mov byte [g_cfg_midi], 1
.no_mt32:

    ; note: /GM is a substring of nothing else we match, but /MT32 wins
    ; if both are given (checked first, GM only fills an unset flag)
    cmp byte [g_cfg_midi], 0
    jnz .no_gm
    mov edi, arg_gm
    call find_token
    jnz .no_gm
    mov byte [g_cfg_midi], 2
.no_gm:

    mov edi, arg_tandy
    call find_token
    jnz .no_tandy
    mov byte [g_cfg_shim], 2      ; force the SN76489 shim
.no_tandy:

    ; /TANDY wins if both are given (checked first, /SPK only fills unset)
    cmp byte [g_cfg_shim], 0
    jnz .no_spk
    mov edi, arg_spk
    call find_token
    jnz .no_spk
    mov byte [g_cfg_shim], 3      ; force the PC-speaker SFX shim
.no_spk:

    mov edi, arg_noenh
    call find_token
    jnz .no_noenh
    mov byte [g_cfg_noenh], 1     ; disable the tier-1 OPL enhancement layer
.no_noenh:

    mov edi, arg_loop
    call find_token
    jnz .no_loop
    mov byte [g_cfg_musicloop], 1 ; DEBUG_AUDIO: music-only, loop forever
.no_loop:

    ; --- link-cable transport flags (net_hal.asm owns the config bytes) ----
    mov edi, arg_com1
    call find_token
    jnz .no_com1
    mov byte [g_net_com_sel], 1
.no_com1:
    mov edi, arg_com2
    call find_token
    jnz .no_com2
    mov byte [g_net_com_sel], 2
.no_com2:
    mov edi, arg_com3
    call find_token
    jnz .no_com3
    mov byte [g_net_com_sel], 3
.no_com3:
    mov edi, arg_com4
    call find_token
    jnz .no_com4
    mov byte [g_net_com_sel], 4
.no_com4:
    mov edi, arg_linklog
    call find_token
    jnz .no_linklog
    mov byte [g_net_linklog], 1
.no_linklog:
    mov edi, arg_partyb
    call find_token
    jnz .no_partyb
    mov byte [g_cfg_partyb], 1
.no_partyb:
    ; /BAUD=n — parse the decimal rate, store the 115200/n divisor. An
    ; unparsable or out-of-range value is ignored (default 115200 stands).
    mov edi, arg_baud
    call find_token_pos
    jnz .no_baud
    call parse_decimal            ; EAX ptr -> EAX value, CF=1 no digits
    jc .no_baud
    test eax, eax
    jz .no_baud
    cmp eax, 115200
    ja .no_baud
    mov ecx, eax
    mov eax, 115200
    xor edx, edx
    div ecx                       ; divisor = 115200 / baud
    test eax, eax
    jz .no_baud
    cmp eax, 0xFFFF
    ja .no_baud
    mov [g_net_baud_div], ax
.no_baud:
    ; --- IPX transport flag (Stage 6 step 1) ---
    mov edi, arg_ipx
    call find_token
    jnz .no_ipx
    mov byte [g_net_ipx_sel], 1
.no_ipx:
    ; /IPXSOCK=n — decimal socket number override (default 0x869C stands on
    ; a parse failure or an out-of-range value).
    mov edi, arg_ipxsock
    call find_token_pos
    jnz .no_ipxsock
    call parse_decimal            ; EAX ptr -> EAX value, CF=1 no digits
    jc .no_ipxsock
    test eax, eax
    jz .no_ipxsock                ; socket 0 is not a usable override
    cmp eax, 0xFFFF
    ja .no_ipxsock
    mov [g_net_ipx_socket], ax
.no_ipxsock:
    ; --- packet driver client flag (Stage 7 step 1) ---
    ; /PKTINT=0xNN — hex packet-driver interrupt vector override (0 = keep
    ; Pktdrv_Init's auto-scan of 0x60-0x80; an unparsable value, or one past
    ; a single byte, is ignored and the auto-scan default stands).
    mov edi, arg_pktint
    call find_token_pos
    jnz .no_pktint
    call parse_hex                ; EAX ptr -> EAX value, CF=1 no hex digits
    jc .no_pktint
    test eax, eax
    jz .no_pktint                 ; vector 0 is never a usable override
                                   ; (real IVT slot 0 is divide-by-zero)
    cmp eax, 0xFF
    ja .no_pktint
    mov [g_pkt_int], al
.no_pktint:

.done:
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; seg_to_flat — resolve AX, which is either a protected-mode SELECTOR (what a
; DPMI host hands back for the PSP via INT 21h AH=62h, and what it plants in
; the PSP's environment-pointer word at +2Ch) or a raw real-mode segment,
; into a DS-relative flat pointer in EAX. Tries DPMI 0006h (get segment base)
; first; a failed lookup means it was a plain real-mode paragraph — use <<4.
; Preserves all other registers.
; ---------------------------------------------------------------------------
global seg_to_flat
seg_to_flat:
    push ebx
    push ecx
    push edx
    mov bx, ax
    mov ax, 0x0006           ; DPMI: get segment base address of BX
    int 0x31
    jc .rawSegment
    movzx eax, cx            ; base = CX:DX
    shl eax, 16
    mov ax, dx
    jmp .bias
.rawSegment:
    movzx eax, bx
    shl eax, 4
.bias:
    sub eax, [ds_base]
    pop edx
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; find_token — search for null-terminated token in buffer
; In:  ESI = buffer, ECX = length, EDI = token. Out: ZF set if found.
; ---------------------------------------------------------------------------
find_token:
    push eax
    push ebx
    push ecx
    push esi
    push edi

    mov ebx, edi
.tok_len:
    cmp byte [ebx], 0
    je .tok_len_done
    inc ebx
    jmp .tok_len
.tok_len_done:
    sub ebx, edi

.scan_loop:
    cmp ecx, ebx
    jl .not_found
    push ecx
    push esi
    push edi
    mov ecx, ebx
    repe cmpsb
    pop edi
    pop esi
    pop ecx
    je .found
    inc esi
    dec ecx
    jmp .scan_loop

.found:
    xor eax, eax
    jmp .out
.not_found:
    or eax, 1
.out:
    pop edi
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; find_token_pos — find_token variant for `=value` flags (/BAUD=n): same
; inputs (EDI = NUL-terminated token, ESI = command line, ECX = remaining
; length), but on a hit returns ZF=1 AND EAX = flat pointer to the first
; character PAST the token (the value). ZF=0 on miss (EAX undefined).
; Preserves EBX/ECX/ESI/EDI.
; ---------------------------------------------------------------------------
find_token_pos:
    push ebx
    push ecx
    push esi
    push edi

    mov ebx, edi
.tok_len:
    cmp byte [ebx], 0
    je .tok_len_done
    inc ebx
    jmp .tok_len
.tok_len_done:
    sub ebx, edi                 ; EBX = token length

.scan_loop:
    cmp ecx, ebx
    jl .not_found
    push ecx
    push esi
    push edi
    mov ecx, ebx
    repe cmpsb
    pop edi
    pop esi
    pop ecx
    je .found
    inc esi
    dec ecx
    jmp .scan_loop
.found:
    lea eax, [esi + ebx]         ; first char past the token
    cmp eax, eax                 ; ZF=1
    jmp .out
.not_found:
    or esp, 0                    ; ZF=0 (esp is never 0)
.out:
    pop edi
    pop esi
    pop ecx
    pop ebx
    ret

; ---------------------------------------------------------------------------
; parse_decimal — EAX = flat pointer to ASCII digits; parse up to a
; non-digit. Out: CF=0 + EAX = value (clamped at 999999), CF=1 no digits.
; Clobbers EDX. Preserves the rest.
; ---------------------------------------------------------------------------
parse_decimal:
    push esi
    push ecx
    mov esi, eax
    xor eax, eax
    xor ecx, ecx                 ; digit count
.next:
    movzx edx, byte [esi]
    sub dl, '0'
    cmp dl, 9
    ja .done
    imul eax, eax, 10
    movzx edx, dl
    add eax, edx
    cmp eax, 999999
    jbe .no_clamp
    mov eax, 999999
.no_clamp:
    inc esi
    inc ecx
    jmp .next
.done:
    test ecx, ecx
    jz .none
    clc
    jmp .out
.none:
    stc
.out:
    pop ecx
    pop esi
    ret

; ---------------------------------------------------------------------------
; parse_hex — EAX = flat pointer to text, optionally "0x"/"0X" prefixed
; (skipped if present), followed by hex digits (0-9, A-F, a-f); parse up to
; the first non-hex-digit character. Out: CF=0 + EAX = value, CF=1 no hex
; digits found. Clobbers EDX. Preserves the rest. Mirrors parse_decimal's
; shape/contract (added for /PKTINT=0xNN — Stage 7 step 1, no existing hex
; parser in this file; /IPXSOCK= and /BAUD= are both decimal).
; ---------------------------------------------------------------------------
parse_hex:
    push esi
    push ecx
    mov esi, eax

    cmp byte [esi], '0'
    jne .noprefix
    mov al, [esi + 1]
    cmp al, 'x'
    je .skipprefix
    cmp al, 'X'
    jne .noprefix
.skipprefix:
    add esi, 2
.noprefix:

    xor eax, eax
    xor ecx, ecx                  ; digit count
.next:
    mov dl, [esi]
    cmp dl, '0'
    jb .done
    cmp dl, '9'
    jbe .digit
    and dl, 0xDF                  ; fold 'a'-'f' to 'A'-'F'
    cmp dl, 'A'
    jb .done
    cmp dl, 'F'
    ja .done
    sub dl, 'A' - 10
    jmp .accum
.digit:
    sub dl, '0'
.accum:
    shl eax, 4
    movzx edx, dl
    add eax, edx
    inc esi
    inc ecx
    jmp .next
.done:
    test ecx, ecx
    jz .none
    clc
    jmp .out
.none:
    stc
.out:
    pop ecx
    pop esi
    ret

; ---------------------------------------------------------------------------
; cleanup — restore PIT, IRQ0, IRQ1 and return to text mode
; ---------------------------------------------------------------------------
cleanup:
    push eax
    call NetShutdown         ; restore the UART vector/PIC state (no-op if unbound)
    call audio_shutdown
    call joypad_restore
    call pit_restore
    mov ax, 0x0003
    int 0x10
    pop eax
    ret
