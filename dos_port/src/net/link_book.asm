; ===========================================================================
; link_book.asm — the link-cable connection book: LINKBOOK.DAT load/save +
; in-memory record accessors (docs/current_plan_link_cable.md Stage 5 step 2).
;
; Port-only, no pret counterpart — a real Game Boy link cable has no concept
; of a saved connection ("the transport IS the connection"); the book only
; exists because the port's transports (UART today, IPX/TCP later) need a
; named place, and that place should survive a reboot. Every routine and
; label here is a bespoke port name (lowercase for routines, matching the
; net_hal.asm convention: NetHAL_* / net_uart_* are the mixed-case HAL
; entry points and their lowercase-prefixed internals; linkbook_* mirrors
; that split).
;
; Modeled VERBATIM on src/save/dsv_io.asm's DPMI transaction-buffer pattern
; (its own header cites this as the reason it keeps its own copy rather than
; sharing debug_dump.asm's): a protected-mode `int 21h` with a DS:DX pointer
; is NOT auto-translated under CWSDPMI, so file I/O goes through the DPMI
; "Simulate Real Mode Interrupt" service (INT 31h AX=0300h) against a
; conventional (<1 MB) DOS buffer allocated once (DPMI fn 0100h) and kept for
; the life of the process — see dsv_io.asm's dsv_ensure_buffer comment for
; the full rationale (size is a build-time constant, filename never changes,
; so alloc-once beats alloc/free-per-call). The routine bodies below are the
; same shape as dsv_io.asm's SramLoadImage/SramStoreImage (read lines ~253-
; 494 of that file for the routines this clones): lb_ensure_buffer =
; dsv_ensure_buffer, lb_open/lb_close = dsv_open/dsv_close, lb_sim_int21 =
; dsv_sim_int21, lb_zero_rmcs = dsv_zero_rmcs, lb_checksum_at = dsv_checksum
; parameterized on a caller-supplied base pointer (dsv_checksum hardcodes its
; own buffer; this file needs the same sum over two different bases — the
; DOS buffer during load-validation, book_image during store — so it takes
; ESI in rather than deriving it).
;
; One simplification the book gets that dsv_io.asm does not: the whole
; document is ONE contiguous region (no SRAM-bank split), so the in-memory
; "book_image" is laid out as an EXACT byte-for-byte mirror of the on-disk
; file — magic/version/checksum header followed by the 10 fixed records —
; and load/store are a single rep movsb between book_image and the DOS
; staging buffer, never a scatter/gather loop.
;
; File format (LINKBOOK.DAT), per the plan-doc spec:
;   offset 0  : magic "LNKB"                (4 bytes)
;   offset 4  : version byte (= LB_VERSION) (1 byte)
;   offset 5  : 16-bit additive checksum, LE, over the record payload
;   offset 7  : payload — 10 fixed LBREC records, 5 TCP (family 0) then
;               5 IPX (family 1), LBREC.size (32) bytes each = 320 bytes
;   total file = LINKBOOK_IMAGE_SIZE = 327 bytes
;
; LBREC layout (32 bytes, shared by both families so one accessor path
; serves either — see the LBREC struc below):
;   .in_use (1)  : 0 = empty slot, 1 = occupied
;   .name   (16) : GB charmap, 0x50 ($LB_TERM, '@') padded to the full width
;   .addr   (10) : family-dependent address payload (see below)
;   .pad    (5)  : reserved, always written zero — pads the record to a round
;                  32 bytes and leaves headroom for a field neither transport
;                  needs yet, without moving NUM_RECORDS math
;
; Address payload byte order — BIG-ENDIAN in both families, matching the
; on-wire / GB convention the rest of this codebase already commits to
; (CLAUDE.md "Data is big-endian"; here it is network/transmission order,
; not GB save-data order, but the same "most significant / first-transmitted
; byte first" rule applies so a hex-dump of the file reads the same way a
; packet trace would):
;   TCP (family LINKBOOK_FAMILY_TCP=0): .addr[0..3] = IPv4 address, most
;     significant octet first (a.b.c.d -> bytes a,b,c,d); .addr[4..5] = TCP
;     port, high byte first; .addr[6..9] unused, written zero.
;   IPX (family LINKBOOK_FAMILY_IPX=1): .addr[0..3] = IPX network number,
;     most significant byte first; .addr[4..9] = IPX node (MAC-shaped)
;     address in its normal transmission order (six bytes, no byte-swap
;     applied by the port — "big-endian" here just means "we do not
;     reorder what the wire gives us").
;
; Corrupt or absent file -> empty book in memory: CF discipline mirrors
; SramLoadImage (CF=1 on absent-or-invalid), but UNLIKE SramLoadImage this
; also ZEROES book_image on failure (the plan-doc spec's explicit
; requirement — "corrupt or absent -> empty book"), rather than leaving
; whatever was there untouched. Every in_use flag reading 0 is what makes an
; all-zero image read as "no entries" to every accessor.
;
; Exports (register contract for all three, matching the NetHAL_*/dsv_io.asm
; convention of preserving EBP; none of these touch GB memory, so EBP is not
; even read):
;   linkbook_load   — LINKBOOK.DAT -> book_image. CF=0 loaded / CF=1
;                      absent-or-corrupt (book_image zeroed either way that
;                      matters: on CF=1 it is explicitly zeroed; on CF=0 it
;                      holds the validated file). Sets linkbook_loaded=1 on
;                      return either way — "the in-memory book reflects a
;                      completed load attempt", not "a file was found". Not
;                      called at boot (see docs/current_plan_link_cable.md
;                      Stage 5): the UI calls this lazily when the book
;                      screen opens, so a player who never links pays
;                      nothing. Preserves all GP registers.
;   linkbook_store  — book_image -> LINKBOOK.DAT (after the UI commits a
;                      NEW/EDIT/DELETE). CF=0 ok / CF=1 on any DPMI/DOS
;                      failure or short write (book_image is left as the
;                      caller set it either way; a failed store does not
;                      roll back the in-memory edit). Preserves all GP
;                      registers.
;   linkbook_record — In: AL = family (LINKBOOK_FAMILY_TCP=0 /
;                      LINKBOOK_FAMILY_IPX=1), AH = slot (0..4). Out: ESI =
;                      flat pointer to that record inside book_image (an
;                      LBREC — index with the .in_use/.name/.addr/.pad
;                      struc offsets). Preserves EAX; clobbers ECX/EDX.
;                      CONTRACT, not a bounds check: the codebase has no
;                      existing cheap debug-assert pattern to hook (grepped
;                      include/gb_macros.inc — none), so this is documented
;                      instead of guarded. AL must be 0 or 1 and AH must be
;                      0..4; out-of-range input computes an out-of-range
;                      flat offset with NO fault and NO clamp (the multiply
;                      is unconditional) — callers must validate their own
;                      family/slot selection before calling this.
;
; Build check: nasm -f coff -I include/ -I . -o /dev/null src/net/link_book.asm
;              (from dos_port/)
; ===========================================================================

bits 32

extern ds_base

global linkbook_load
global linkbook_store
global linkbook_record
global linkbook_loaded
global book_image

; --- DPMI real-mode call structure field offsets (DPMI 0.9 spec) — same
; layout dsv_io.asm uses, duplicated here rather than shared: each file
; keeps its OWN rmcs instance (own in-flight real-mode call), same as
; dsv_io.asm keeps its own copy of debug_dump.asm's dance.
RMCS_EBX     equ 0x10
RMCS_EDX     equ 0x14
RMCS_ECX     equ 0x18
RMCS_EAX     equ 0x1C
RMCS_FLAGS   equ 0x20
RMCS_DS      equ 0x24
RMCS_SIZE    equ 0x32

; --- LINKBOOK.DAT layout ---
LB_MAGIC      equ 0x424B4E4C       ; "LNKB" little-endian (L=4C N=4E K=4B B=42)
LB_VERSION    equ 1
LB_HDR_SIZE   equ 7                ; magic(4) + version(1) + checksum(2)
LB_TERM       equ 0x50             ; '@' — PlaceString terminator / name pad byte

LINKBOOK_FAMILY_TCP       equ 0
LINKBOOK_FAMILY_IPX       equ 1
LINKBOOK_SLOTS_PER_FAMILY equ 5
LINKBOOK_NUM_FAMILIES     equ 2
LINKBOOK_NUM_RECORDS      equ LINKBOOK_SLOTS_PER_FAMILY * LINKBOOK_NUM_FAMILIES ; 10

; One fixed-size record, shared by both families (TCP's 6-byte address and
; IPX's 10-byte address both fit in .addr; TCP's unused tail bytes are
; written zero — see the file header's byte-order note).
struc LBREC
    .in_use: resb 1
    .name:   resb 16
    .addr:   resb 10
    .pad:    resb 5
    .size:
endstruc

LINKBOOK_PAYLOAD_TOTAL equ LBREC.size * LINKBOOK_NUM_RECORDS   ; 320
LINKBOOK_IMAGE_SIZE    equ LB_HDR_SIZE + LINKBOOK_PAYLOAD_TOTAL ; 327

; Conventional-buffer layout: filename at offset 0, contents at CONTENTS_OFF
; (dsv_io.asm's naming, kept identical on purpose — same pattern, same names).
CONTENTS_OFF   equ 0x10
CONTENTS_TOTAL equ LINKBOOK_IMAGE_SIZE
LB_BUF_PARAS   equ (CONTENTS_OFF + CONTENTS_TOTAL + 15) / 16

; ---------------------------------------------------------------------------
section .data
align 4
lb_fname: db "LINKBOOK.DAT", 0

; ---------------------------------------------------------------------------
section .bss
align 4
lb_rmcs:     resb RMCS_SIZE
lb_seg:      resw 1                ; real-mode segment of DOS buffer
lb_sel:      resw 1                ; PM selector of DOS buffer (0 = unallocated)
lb_flat:     resd 1                ; DS-relative (flat) offset of DOS buffer
lb_handle:   resw 1

; The in-memory book: byte-for-byte the on-disk image (header + 10 records).
; linkbook_record indexes straight into the record area, HDR bytes in.
linkbook_loaded: resb 1            ; 1 once linkbook_load has completed (either way)
align 4
book_image: resb LINKBOOK_IMAGE_SIZE

; ---------------------------------------------------------------------------
section .text

; ===========================================================================
; linkbook_load — LINKBOOK.DAT -> book_image. CF=0 loaded / CF=1
; absent-or-invalid, and on CF=1 book_image is explicitly zeroed (an empty
; book), unlike dsv_io.asm's SramLoadImage which leaves banks untouched —
; the plan-doc spec calls for "corrupt or absent -> empty book" here.
; ===========================================================================
linkbook_load:
    push ebx
    push esi
    push edi
    call lb_ensure_buffer
    jc .empty

    call lb_open                       ; CF=1 on absent
    jc .empty

    ; read CONTENTS_TOTAL bytes into buffer @ CONTENTS_OFF (INT 21h AH=3Fh)
    call lb_zero_rmcs
    mov word [lb_rmcs + RMCS_EAX], 0x3F00
    movzx eax, word [lb_handle]
    mov [lb_rmcs + RMCS_EBX], eax
    mov dword [lb_rmcs + RMCS_ECX], CONTENTS_TOTAL
    mov dword [lb_rmcs + RMCS_EDX], CONTENTS_OFF
    mov ax, [lb_seg]
    mov [lb_rmcs + RMCS_DS], ax
    call lb_sim_int21
    mov bx, [lb_rmcs + RMCS_FLAGS]
    mov cx, [lb_rmcs + RMCS_EAX]        ; bytes actually read
    call lb_close
    test bx, 1
    jnz .empty
    cmp cx, CONTENTS_TOTAL              ; full file?
    jne .empty

    ; --- validate header in the DOS buffer ---
    mov edi, [lb_flat]
    add edi, CONTENTS_OFF
    cmp dword [edi], LB_MAGIC
    jne .empty
    cmp byte [edi + 4], LB_VERSION      ; a future version fails here, by design
    jne .empty
    lea esi, [edi + LB_HDR_SIZE]        ; payload start, for the checksum
    call lb_checksum_at                 ; AX = recomputed sum; clobbers ECX/EDX/ESI
    cmp [edi + 5], ax
    jne .empty

    ; --- validated: copy the whole image (header + payload) into book_image ---
    mov esi, edi
    mov edi, book_image
    mov ecx, LINKBOOK_IMAGE_SIZE
    rep movsb

    mov byte [linkbook_loaded], 1
    pop edi
    pop esi
    pop ebx
    clc
    ret
.empty:
    call lb_zero_book
    mov byte [linkbook_loaded], 1
    pop edi
    pop esi
    pop ebx
    stc
    ret

; ===========================================================================
; linkbook_store — book_image -> LINKBOOK.DAT. CF=0 ok / CF=1 fail.
; Canonicalizes the header fields (magic/version/checksum) INSIDE book_image
; before writing, so book_image always holds a self-consistent image after a
; successful call (mirroring dsv_io.asm's "write the header, then the
; already-gathered payload, then checksum" order — here there is nothing to
; gather, book_image already IS the payload).
; ===========================================================================
linkbook_store:
    push ebx
    push esi
    push edi
    call lb_ensure_buffer
    jc .fail

    mov edi, book_image
    mov dword [edi], LB_MAGIC
    mov byte [edi + 4], LB_VERSION
    mov word [edi + 5], 0               ; checksum placeholder

    lea esi, [edi + LB_HDR_SIZE]
    call lb_checksum_at                 ; AX = checksum over book_image's payload
    mov edi, book_image
    mov [edi + 5], ax

    ; --- copy the canonical image into the DOS buffer whole ---
    mov esi, book_image
    mov edi, [lb_flat]
    add edi, CONTENTS_OFF
    mov ecx, LINKBOOK_IMAGE_SIZE
    rep movsb

    ; --- create LINKBOOK.DAT (INT 21h AH=3Ch, CX=0, DS:DX->filename@0) ---
    call lb_zero_rmcs
    mov word [lb_rmcs + RMCS_EAX], 0x3C00
    mov dword [lb_rmcs + RMCS_EDX], 0
    mov ax, [lb_seg]
    mov [lb_rmcs + RMCS_DS], ax
    call lb_sim_int21
    test byte [lb_rmcs + RMCS_FLAGS], 1
    jnz .fail
    mov ax, [lb_rmcs + RMCS_EAX]
    mov [lb_handle], ax

    ; --- write contents (INT 21h AH=40h) ---
    call lb_zero_rmcs
    mov word [lb_rmcs + RMCS_EAX], 0x4000
    movzx eax, word [lb_handle]
    mov [lb_rmcs + RMCS_EBX], eax
    mov dword [lb_rmcs + RMCS_ECX], CONTENTS_TOTAL
    mov dword [lb_rmcs + RMCS_EDX], CONTENTS_OFF
    mov ax, [lb_seg]
    mov [lb_rmcs + RMCS_DS], ax
    call lb_sim_int21
    mov bx, [lb_rmcs + RMCS_FLAGS]
    mov cx, [lb_rmcs + RMCS_EAX]

    ; --- close (INT 21h AH=3Eh) ---
    call lb_close

    test bx, 1                          ; write CF
    jnz .fail
    cmp cx, CONTENTS_TOTAL              ; all bytes written?
    jne .fail

    pop edi
    pop esi
    pop ebx
    clc
    ret
.fail:
    pop edi
    pop esi
    pop ebx
    stc
    ret

; ===========================================================================
; linkbook_record — In: AL = family (0 TCP / 1 IPX), AH = slot (0-4).
; Out: ESI = flat pointer to the LBREC inside book_image. Preserves EAX;
; clobbers ECX/EDX. See the file header for the (documented, unchecked)
; bounds contract.
; ===========================================================================
linkbook_record:
    movzx ecx, al                       ; family (0/1)
    imul ecx, ecx, LINKBOOK_SLOTS_PER_FAMILY
    movzx edx, ah                       ; slot (0-4)
    add ecx, edx                        ; idx = family*5 + slot, 0..9
    imul ecx, ecx, LBREC.size
    lea esi, [book_image + LB_HDR_SIZE + ecx]
    ret

; ---------------------------------------------------------------------------
; Helpers (internal; may clobber EAX/ECX/EDX/ESI/EDI as noted). All modeled
; directly on dsv_io.asm's identically-named-in-spirit helpers.
; ---------------------------------------------------------------------------

; lb_ensure_buffer — DPMI fn 0100h: allocate the conventional DOS buffer ONCE
; and stage the filename in it. Out: lb_seg/lb_sel/lb_flat set. CF=1 on
; failure. Clobbers EAX/EBX/ECX/EDX/ESI/EDI. See dsv_io.asm:dsv_ensure_buffer
; for the full "why alloc-once" rationale — identical here.
lb_ensure_buffer:
    cmp word [lb_sel], 0
    jne .have
    mov ax, 0x0100
    mov bx, LB_BUF_PARAS
    int 0x31
    jc .fail
    mov [lb_seg], ax
    mov [lb_sel], dx
    movzx eax, ax
    shl eax, 4                          ; linear = seg * 16
    sub eax, [ds_base]                  ; flat (DS-relative under 4 GB limit)
    mov [lb_flat], eax
    ; stage "LINKBOOK.DAT\0" at buffer offset 0
    mov esi, lb_fname
    mov edi, eax
    mov ecx, 13                         ; "LINKBOOK.DAT" + NUL
    rep movsb
.have:
    clc
    ret
.fail:
    stc
    ret

; lb_open — INT 21h AH=3Dh AL=0 (open read-only). Filename @ buffer offset 0.
; Out: lb_handle set, CF=0 on success; CF=1 if the file is absent.
lb_open:
    call lb_zero_rmcs
    mov word [lb_rmcs + RMCS_EAX], 0x3D00
    mov dword [lb_rmcs + RMCS_EDX], 0
    mov ax, [lb_seg]
    mov [lb_rmcs + RMCS_DS], ax
    call lb_sim_int21
    test byte [lb_rmcs + RMCS_FLAGS], 1
    jnz .fail
    mov ax, [lb_rmcs + RMCS_EAX]
    mov [lb_handle], ax
    clc
    ret
.fail:
    stc
    ret

; lb_close — INT 21h AH=3Eh (close lb_handle).
lb_close:
    call lb_zero_rmcs
    mov word [lb_rmcs + RMCS_EAX], 0x3E00
    movzx eax, word [lb_handle]
    mov [lb_rmcs + RMCS_EBX], eax
    call lb_sim_int21
    ret

; lb_checksum_at — 16-bit additive sum of LINKBOOK_PAYLOAD_TOTAL bytes
; starting at ESI (caller-supplied base — the DOS buffer during load
; validation, book_image during store; dsv_checksum hardcodes one base,
; this file needs two, hence the parameter). Out: AX = checksum. Clobbers
; ECX/EDX/ESI.
lb_checksum_at:
    mov ecx, LINKBOOK_PAYLOAD_TOTAL
    xor eax, eax
.loop:
    movzx edx, byte [esi]
    add ax, dx
    inc esi
    dec ecx
    jnz .loop
    ret

; lb_zero_book — zero the entire book_image (header AND payload), i.e. an
; empty book: every record's .in_use reads 0. Clobbers ECX/EDI.
lb_zero_book:
    push edi
    mov edi, book_image
    xor al, al
    mov ecx, LINKBOOK_IMAGE_SIZE
    rep stosb
    pop edi
    ret

; lb_sim_int21 — reflect INT 21h to real mode using lb_rmcs (DPMI fn 0300h).
; BL=int#, BH=0, CX=0 stack words, ES:EDI -> lb_rmcs (ES = flat DS invariant).
lb_sim_int21:
    push eax
    push ebx
    push ecx
    push edi
    mov ax, 0x0300
    mov bl, 0x21
    mov bh, 0
    xor cx, cx
    mov edi, lb_rmcs
    int 0x31
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; lb_zero_rmcs — clear the real-mode call structure.
lb_zero_rmcs:
    push eax
    push ecx
    push edi
    mov edi, lb_rmcs
    xor al, al
    mov ecx, RMCS_SIZE
    rep stosb
    pop edi
    pop ecx
    pop eax
    ret
