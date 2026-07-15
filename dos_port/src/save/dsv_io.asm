; dsv_io.asm — DOS save-file HAL (.dsv read/write) for the menus save flow.
;
; The Game Boy save is a battery-backed SRAM image (pret save.asm writes it via
; the MBC banking regs rRAMG/rBMODE/rRAMB). The DOS port has no such hardware, so
; every SRAM access in pret collapses to one of the three calls exported here,
; which serialize the equivalent WRAM to a host file "POKEMON.DSV" on C:.
;
; File format (.dsv, CLAUDE.md "Save File Notes"):
;     offset 0  : "DOSV"                       (4-byte magic)
;     offset 4  : version byte                 (DSV_VERSION; bump for new layouts)
;     offset 5  : 16-bit additive checksum, LE (sum of all payload bytes, mod 2^16)
;     offset 7  : payload                       (the WRAM blocks below, in order)
;
; Payload ("minimal real"): exactly the WRAM ranges pret's SaveMainData /
; SaveCurrentBoxData / SavePartyAndDexData serialize — NOT yet a faithful 32 KB
; SRAM bank image (no other-box banks / HoF banks). The version byte gates a
; future faithful-SRAM format. Block order (see payload_blocks):
;     wPlayerName      (NAME_LENGTH = 11)        player name
;     wMainDataStart.. (1929)  pokédex/badges/money/options/play time/current box
;     wSpriteDataStart.(512)   sprite state block
;     wBoxDataStart..  (1122)  current PC box
;     wPartyDataStart..(404)   party + nicknames
;
; Channel: DOS file I/O via the DPMI "Simulate Real Mode Interrupt" service
; (INT 31h AX=0300h), mirroring src/debug/debug_dump.asm. A protected-mode
; `int 21h` with a DS:DX pointer is NOT auto-translated under CWSDPMI, so we
; allocate a conventional (<1 MB) DOS buffer (DPMI fn 0100h), stage the filename
; + contents there, and reflect INT 21h AH=3Ch/3Dh/3Fh/40h/3Eh into real mode
; with the buffer's real-mode segment in DS. dsv_io keeps its own copy of that
; dance because debug_dump.asm is a debug-only translation unit while this file
; links in every build.
; DEVIATION{class=HAL; pret=engine/menus/save.asm:SaveGameData; behavior=use self-contained DPMI DOS file I/O for production DSV persistence instead of cartridge SRAM access; evidence=pret SRAM save path plus port DsvReadSave and DsvWriteSave INT 21h reflection; lifetime=permanent DOS storage HAL boundary}
; Self-contained DPMI file I/O is not shared with
; the debug-only debug_dump.asm) so the production save path never depends on a
; debug object.
;
; Exports (all: In EBP = GB memory base; preserve EBP; ES = flat DS invariant):
;   DsvFileExists — CF=1 / AL=1 when a valid "DOSV" save is present on C:,
;                   CF=0 / AL=0 otherwise (mirrors pret's scf "found" path).
;   DsvWriteSave  — serialize the WRAM payload + header + checksum → POKEMON.DSV.
;                   CF=0 on success, CF=1 on any DPMI/DOS failure.
;   DsvReadSave   — load POKEMON.DSV back into the payload WRAM ranges.
;                   CF=0 on success, CF=1 if absent / bad magic / bad checksum
;                   (mirrors pret's corrupt-save `scf` branch).
;
; Build: nasm -f coff -I include/ -I . -o dsv_io.o src/save/dsv_io.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"

extern ds_base

global DsvFileExists
global DsvWriteSave
global DsvReadSave

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec) ---
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

; --- .dsv layout ---
DSV_VERSION   equ 1
DSV_MAGIC     equ 0x56534F44        ; "DOSV" little-endian (D=44 O=4F S=53 V=56)
HDR_SIZE      equ 7                 ; magic(4) + version(1) + checksum(2)
CONTENTS_OFF  equ 0x10              ; DOS buffer offset of the file contents
PAYLOAD_OFF   equ CONTENTS_OFF + HDR_SIZE

PAYLOAD_TOTAL equ NAME_LENGTH \
              + (wMainDataEnd - wMainDataStart) \
              + (wSpriteDataEnd - wSpriteDataStart) \
              + (wBoxDataEnd - wBoxDataStart) \
              + (wPartyDataEnd - wPartyDataStart)
CONTENTS_TOTAL equ HDR_SIZE + PAYLOAD_TOTAL
NUM_BLOCKS    equ 5

; ---------------------------------------------------------------------------
section .data
align 4
dsv_fname: db "POKEMON.DSV", 0

; Each entry: dd gb_offset, dd length. Order defines the on-disk payload layout.
align 4
payload_blocks:
    dd wPlayerName,      NAME_LENGTH
    dd wMainDataStart,   wMainDataEnd  - wMainDataStart
    dd wSpriteDataStart, wSpriteDataEnd - wSpriteDataStart
    dd wBoxDataStart,    wBoxDataEnd   - wBoxDataStart
    dd wPartyDataStart,  wPartyDataEnd - wPartyDataStart

; ---------------------------------------------------------------------------
section .bss
align 4
rmcs:        resb RMCS_SIZE
dsv_seg:     resw 1                 ; real-mode segment of DOS buffer
dsv_sel:     resw 1                 ; PM selector of DOS buffer
dsv_flat:    resd 1                 ; DS-relative (flat) offset of DOS buffer
dsv_handle:  resw 1

; ---------------------------------------------------------------------------
section .text

; ===========================================================================
; DsvWriteSave — write the payload WRAM to POKEMON.DSV. CF=0 ok / CF=1 fail.
; ===========================================================================
DsvWriteSave:
    push ebx
    push esi
    push edi
    call dsv_alloc
    jc .fail
    call dsv_stage_filename

    ; --- build header at CONTENTS_OFF ---
    mov edi, [dsv_flat]
    add edi, CONTENTS_OFF
    mov dword [edi], DSV_MAGIC
    mov byte [edi + 4], DSV_VERSION
    mov word [edi + 5], 0                     ; checksum placeholder

    ; --- copy payload blocks WRAM -> buffer (edi = payload dest cursor) ---
    add edi, HDR_SIZE
    mov esi, payload_blocks
    mov edx, NUM_BLOCKS                       ; block counter (ecx is the movsb length)
.copyblk:
    mov eax, [esi]                            ; gb offset
    mov ecx, [esi + 4]                        ; length
    push esi
    lea esi, [ebp + eax]                      ; flat WRAM src
    rep movsb                                 ; DS:ESI(WRAM) -> ES:EDI(buffer)
    pop esi
    add esi, 8
    dec edx
    jnz .copyblk

    ; --- 16-bit additive checksum over the payload just written ---
    call dsv_checksum                         ; AX = checksum
    mov edi, [dsv_flat]
    mov [edi + CONTENTS_OFF + 5], ax

    ; --- create POKEMON.DSV (INT 21h AH=3Ch, CX=0, DS:DX->filename@0) ---
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3C00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dsv_seg]
    mov [rmcs + RMCS_DS], ax
    call dsv_sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .freefail
    mov ax, [rmcs + RMCS_EAX]
    mov [dsv_handle], ax

    ; --- write contents (INT 21h AH=40h) ---
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x4000
    movzx eax, word [dsv_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], CONTENTS_TOTAL
    mov dword [rmcs + RMCS_EDX], CONTENTS_OFF
    mov ax, [dsv_seg]
    mov [rmcs + RMCS_DS], ax
    call dsv_sim_int21
    ; treat a short/failed write as failure (checked after close)
    mov bx, [rmcs + RMCS_FLAGS]
    mov cx, [rmcs + RMCS_EAX]

    ; --- close (INT 21h AH=3Eh) ---
    call dsv_close

    test bx, 1                                ; write CF
    jnz .freefail
    cmp cx, CONTENTS_TOTAL                     ; all bytes written?
    jne .freefail

    call dsv_free
    pop edi
    pop esi
    pop ebx
    clc
    ret
.freefail:
    call dsv_free
.fail:
    pop edi
    pop esi
    pop ebx
    stc
    ret

; ===========================================================================
; DsvReadSave — load POKEMON.DSV into the payload WRAM. CF=0 ok / CF=1 fail.
; ===========================================================================
DsvReadSave:
    push ebx
    push esi
    push edi
    call dsv_alloc
    jc .fail
    call dsv_stage_filename

    call dsv_open                             ; CF=1 on absent
    jc .freefail

    ; read CONTENTS_TOTAL bytes into buffer @ CONTENTS_OFF (INT 21h AH=3Fh)
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3F00
    movzx eax, word [dsv_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], CONTENTS_TOTAL
    mov dword [rmcs + RMCS_EDX], CONTENTS_OFF
    mov ax, [dsv_seg]
    mov [rmcs + RMCS_DS], ax
    call dsv_sim_int21
    mov bx, [rmcs + RMCS_FLAGS]
    mov cx, [rmcs + RMCS_EAX]                  ; bytes actually read
    call dsv_close
    test bx, 1
    jnz .freefail
    cmp cx, CONTENTS_TOTAL                     ; full file?
    jne .freefail

    ; --- validate header ---
    mov edi, [dsv_flat]
    add edi, CONTENTS_OFF
    cmp dword [edi], DSV_MAGIC
    jne .freefail
    cmp byte [edi + 4], DSV_VERSION
    jne .freefail
    ; verify checksum
    call dsv_checksum                          ; AX = recomputed sum
    mov edi, [dsv_flat]
    cmp [edi + CONTENTS_OFF + 5], ax
    jne .freefail

    ; --- scatter payload buffer -> WRAM ---
    mov esi, [dsv_flat]
    add esi, PAYLOAD_OFF
    mov ebx, payload_blocks
    mov edx, NUM_BLOCKS
.scatter:
    mov eax, [ebx]                             ; gb offset
    mov ecx, [ebx + 4]                         ; length
    lea edi, [ebp + eax]
    rep movsb                                  ; DS:ESI(buffer) -> ES:EDI(WRAM)
    add ebx, 8
    dec edx
    jnz .scatter

    call dsv_free
    pop edi
    pop esi
    pop ebx
    clc
    ret
.freefail:
    call dsv_free
.fail:
    pop edi
    pop esi
    pop ebx
    stc
    ret

; ===========================================================================
; DsvFileExists — CF/AL = a valid "DOSV" file is present on C:.
;   Out: CF=1, AL=1 if present+valid magic/version; CF=0, AL=0 otherwise.
; Mirrors pret CheckForPlayerNameInSRAM's scf "found" path.
; ===========================================================================
DsvFileExists:
    push ebx
    push esi
    push edi
    call dsv_alloc
    jc .notfound
    call dsv_stage_filename
    call dsv_open
    jc .freenotfound

    ; read the 7-byte header
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3F00
    movzx eax, word [dsv_handle]
    mov [rmcs + RMCS_EBX], eax
    mov dword [rmcs + RMCS_ECX], HDR_SIZE
    mov dword [rmcs + RMCS_EDX], CONTENTS_OFF
    mov ax, [dsv_seg]
    mov [rmcs + RMCS_DS], ax
    call dsv_sim_int21
    mov bx, [rmcs + RMCS_FLAGS]
    mov cx, [rmcs + RMCS_EAX]
    call dsv_close
    test bx, 1
    jnz .freenotfound
    cmp cx, HDR_SIZE
    jne .freenotfound
    mov edi, [dsv_flat]
    add edi, CONTENTS_OFF
    cmp dword [edi], DSV_MAGIC
    jne .freenotfound
    cmp byte [edi + 4], DSV_VERSION
    jne .freenotfound

    call dsv_free
    pop edi
    pop esi
    pop ebx
    mov al, 1
    stc                                        ; found
    ret
.freenotfound:
    call dsv_free
.notfound:
    pop edi
    pop esi
    pop ebx
    xor al, al
    clc                                        ; not found
    ret

; ---------------------------------------------------------------------------
; Helpers (internal; preserve EBP; may clobber EAX/ECX/EDX/ESI/EDI as noted).
; ---------------------------------------------------------------------------

; dsv_alloc — DPMI fn 0100h: allocate a 16 KB conventional DOS buffer.
; Out: dsv_seg/dsv_sel/dsv_flat set. CF=1 on failure. Clobbers EAX/EBX/EDX.
dsv_alloc:
    mov ax, 0x0100
    mov bx, 0x400                              ; 1024 paragraphs = 16 KB (> CONTENTS_TOTAL)
    int 0x31
    jc .fail
    mov [dsv_seg], ax
    mov [dsv_sel], dx
    movzx eax, ax
    shl eax, 4                                 ; linear = seg * 16
    sub eax, [ds_base]                         ; flat (DS-relative under 4 GB limit)
    mov [dsv_flat], eax
    clc
    ret
.fail:
    stc
    ret

; dsv_free — DPMI fn 0101h: free the DOS buffer. Clobbers EAX/EDX.
dsv_free:
    mov ax, 0x0101
    mov dx, [dsv_sel]
    int 0x31
    ret

; dsv_stage_filename — copy "POKEMON.DSV\0" to DOS buffer offset 0.
; Clobbers ESI/EDI/ECX.
dsv_stage_filename:
    mov esi, dsv_fname
    mov edi, [dsv_flat]
    mov ecx, 12                                ; "POKEMON.DSV" + NUL
    rep movsb
    ret

; dsv_open — INT 21h AH=3Dh AL=0 (open read-only). Filename @ buffer offset 0.
; Out: dsv_handle set, CF=0 on success; CF=1 if the file is absent.
dsv_open:
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3D00
    mov dword [rmcs + RMCS_EDX], 0
    mov ax, [dsv_seg]
    mov [rmcs + RMCS_DS], ax
    call dsv_sim_int21
    test byte [rmcs + RMCS_FLAGS], 1
    jnz .fail
    mov ax, [rmcs + RMCS_EAX]
    mov [dsv_handle], ax
    clc
    ret
.fail:
    stc
    ret

; dsv_close — INT 21h AH=3Eh (close dsv_handle).
dsv_close:
    call dsv_zero_rmcs
    mov word [rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [dsv_handle]
    mov [rmcs + RMCS_EBX], eax
    call dsv_sim_int21
    ret

; dsv_checksum — 16-bit additive sum over the payload in the DOS buffer.
; Out: AX = checksum. Clobbers ECX/EDX/ESI (not EAX high half used).
dsv_checksum:
    mov esi, [dsv_flat]
    add esi, PAYLOAD_OFF
    mov ecx, PAYLOAD_TOTAL
    xor eax, eax
.loop:
    movzx edx, byte [esi]
    add ax, dx
    inc esi
    dec ecx
    jnz .loop
    ret

; dsv_sim_int21 — reflect INT 21h to real mode using rmcs (DPMI fn 0300h).
; BL=int#, BH=0, CX=0 stack words, ES:EDI -> rmcs (ES = flat DS invariant).
dsv_sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; dsv_zero_rmcs — clear the real-mode call structure.
dsv_zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret
