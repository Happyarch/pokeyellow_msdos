; dsv_io.asm — DOS save-file HAL (.dsv v2 raw SRAM image) for the save layer.
;
; The Game Boy save is a battery-backed SRAM image. Since the resident-SRAM work
; (docs/current_plan_sram_pc_storage.md stages 1-4) the port emulates all four
; SRAM banks in memory, so every pret save/load routine now reads and writes the
; real s* addresses exactly as pret does. What the port still lacks is the
; battery: this file is the whole of it. Two entry points move the 32 KiB image
; between those banks and a host file "POKEMON.DSV" on C:
;
;   SramLoadImage  — POKEMON.DSV -> SRAM banks. Called once at boot
;                    (boot/entry.asm), before anything reads sPlayerName.
;   SramStoreImage — SRAM banks -> POKEMON.DSV. Called at every save-commit
;                    point (SaveGameData, ClearAllSRAMBanks).
;
; A corrupt or absent file leaves the banks exactly as they were (zeroed at
; boot), which is what pret sees in a fresh cartridge: CheckForPlayerNameInSRAM
; finds no '@'-terminated name and the main menu offers NEW GAME only. The game
; needs no separate "does a file exist" probe any more — DsvFileExists survives
; only as the DEBUG_SAVE_ROUNDTRIP harness marker.
;
; File format (.dsv v2, CLAUDE.md "Save File Notes"):
;     offset 0  : "DOSV"                       (4-byte magic)
;     offset 4  : version byte                 (DSV_VERSION = 2)
;     offset 5  : 16-bit additive checksum, LE (sum of all payload bytes, mod 2^16)
;     offset 7  : payload = the raw 32768-byte SRAM image, bank 0 first
;
; The payload is bank-ordered exactly like a real MBC5 .sav, so a future
; .sav <-> .dsv converter is a header strip and nothing else. It is assembled
; from TWO regions because bank 0 stays inside the 16-bit GB window (the pic
; decoder reaches its staging buffer through the 2-byte wSpriteInputPtr) while
; banks 1-3 are resident above it: 8 KiB at $A000 + 24 KiB at $22000.
;
; v1 — the five-WRAM-block payload — is GONE, deliberately and with no migration
; path: this is a pre-release project with no save files worth protecting, so a
; v1 file simply fails the version check and reads as "no save".
;
; Channel: DOS file I/O via the DPMI "Simulate Real Mode Interrupt" service
; (INT 31h AX=0300h), mirroring src/debug/debug_dump.asm. A protected-mode
; `int 21h` with a DS:DX pointer is NOT auto-translated under CWSDPMI, so we
; allocate a conventional (<1 MB) DOS buffer (DPMI fn 0100h), stage the filename
; + contents there, and reflect INT 21h AH=3Ch/3Dh/3Fh/40h/3Eh into real mode
; with the buffer's real-mode segment in DS. dsv_io keeps its own copy of that
; dance because debug_dump.asm is a debug-only translation unit while this file
; links in every build.
; DEVIATION{class=HAL; pret=engine/menus/save.asm:SaveGameData; behavior=persist the emulated SRAM banks to a DOS file through DPMI real-mode INT 21h instead of relying on cartridge battery backup; evidence=pret SRAM writes survive in battery-backed cartridge RAM while the port's banks are ordinary DPMI memory that dies with the process; lifetime=permanent DOS storage HAL boundary}
;
; Exports (all: In EBP = GB memory base; preserve EBP; ES = flat DS invariant):
;   SramLoadImage  — POKEMON.DSV -> SRAM banks. CF=0 loaded / CF=1 absent-or-bad,
;                    and on CF=1 the banks are left untouched.
;   SramStoreImage — SRAM banks -> POKEMON.DSV. CF=0 ok / CF=1 on any DPMI/DOS
;                    failure or short write.
;   DsvFileExists  — CF=1 / AL=1 when a valid "DOSV" save is present on C:,
;                    CF=0 / AL=0 otherwise. DEBUG harness marker only.
;
; Build: nasm -f coff -I include/ -I . -o dsv_io.o src/save/dsv_io.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"
%include "gb_constants.inc"

extern ds_base

global SramLoadImage
global SramStoreImage
global DsvFileExists

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec) ---
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

; --- .dsv layout ---
DSV_VERSION   equ 2                 ; v1 (WRAM-block payload) is retired, no migration
DSV_MAGIC     equ 0x56534F44        ; "DOSV" little-endian (D=44 O=4F S=53 V=56)
HDR_SIZE      equ 7                 ; magic(4) + version(1) + checksum(2)
CONTENTS_OFF  equ 0x10              ; DOS buffer offset of the file contents
PAYLOAD_OFF   equ CONTENTS_OFF + HDR_SIZE

; The raw SRAM image: 4 banks x 8 KiB, bank 0 first (real .sav bank order).
PAYLOAD_TOTAL  equ 4 * GB_SRAM_BANK_SIZE               ; 32768
CONTENTS_TOTAL equ HDR_SIZE + PAYLOAD_TOTAL
NUM_REGIONS    equ 2

; Conventional-buffer paragraphs, derived rather than guessed: the filename sits
; at buffer offset 0 and the file contents at CONTENTS_OFF.
DSV_BUF_PARAS equ (CONTENTS_OFF + CONTENTS_TOTAL + 15) / 16

; ---------------------------------------------------------------------------
section .data
align 4
dsv_fname: db "POKEMON.DSV", 0

; The image is contiguous on disk but lives in two places in memory: bank 0 in
; the 16-bit GB window, banks 1-3 in the resident extension. Each entry:
; dd gb_offset, dd length. Order defines the on-disk bank order.
align 4
sram_regions:
    dd GB_SRAM_BANK0, GB_SRAM_BANK_SIZE                ; bank 0   ($A000)
    dd GB_SRAM_BANK1, GB_SRAM_END - GB_SRAM_BANK1      ; banks 1-3 ($22000)

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
; SramStoreImage — write the resident SRAM banks to POKEMON.DSV.
; CF=0 ok / CF=1 fail.
; ===========================================================================
SramStoreImage:
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

    ; --- gather the SRAM regions into the payload (edi = payload dest cursor) ---
    add edi, HDR_SIZE
    mov esi, sram_regions
    mov edx, NUM_REGIONS                      ; region counter (ecx is the movsb length)
.gather:
    mov eax, [esi]                            ; gb offset
    mov ecx, [esi + 4]                        ; length
    push esi
    lea esi, [ebp + eax]                      ; flat SRAM src
    rep movsb                                 ; DS:ESI(SRAM) -> ES:EDI(buffer)
    pop esi
    add esi, 8
    dec edx
    jnz .gather

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
; SramLoadImage — load POKEMON.DSV into the resident SRAM banks.
; CF=0 loaded / CF=1 absent-or-invalid. On CF=1 the banks are left untouched:
; the file is validated entirely inside the DOS buffer before a single byte is
; scattered, so a corrupt save cannot half-overwrite a live one.
; ===========================================================================
SramLoadImage:
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
    cmp byte [edi + 4], DSV_VERSION            ; a v1 file fails here, by design
    jne .freefail
    ; verify checksum
    call dsv_checksum                          ; AX = recomputed sum
    mov edi, [dsv_flat]
    cmp [edi + CONTENTS_OFF + 5], ax
    jne .freefail

    ; --- scatter the validated image into the SRAM banks ---
    mov esi, [dsv_flat]
    add esi, PAYLOAD_OFF
    mov ebx, sram_regions
    mov edx, NUM_REGIONS
.scatter:
    mov eax, [ebx]                             ; gb offset
    mov ecx, [ebx + 4]                         ; length
    lea edi, [ebp + eax]
    rep movsb                                  ; DS:ESI(buffer) -> ES:EDI(SRAM)
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
; The game no longer probes this — CheckForPlayerNameInSRAM reads the real
; sPlayerName since stage 4 — but the DEBUG_SAVE_ROUNDTRIP harness still marks
; its result with it.
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

; dsv_alloc — DPMI fn 0100h: allocate the conventional DOS buffer.
; Out: dsv_seg/dsv_sel/dsv_flat set. CF=1 on failure. Clobbers EAX/EBX/EDX.
dsv_alloc:
    mov ax, 0x0100
    mov bx, DSV_BUF_PARAS                      ; derived from CONTENTS_TOTAL
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
