; events.inc — event-flag accessors over wEventFlags (W_EVENT_FLAGS).
;
; Faithful translation of pret's CheckEvent / SetEvent / ResetEvent
; (macros/scripts/events.asm). An event is a bit index (EVENT_*, from
; assets/event_constants.inc) into the wEventFlags bit array; this header turns an
; index into (byte offset, bit mask) at assembly time.
;
; Requires (include before this): gb_memmap.inc (W_EVENT_FLAGS) and
; assets/event_constants.inc (EVENT_* indices).
;
; Convention: EBP = base of emulated GB memory. All three macros CLOBBER AL.
; CheckEvent additionally sets ZF (and is the only one that reads flags):
;   ZF=1  → event is CLEAR   (use `jz` / `je`)
;   ZF=0  → event is SET     (use `jnz` / `jne`)
; matching pret's `bit n,[hl]` → `jr z` idiom exactly.

%ifndef EVENTS_INC
%define EVENTS_INC

; idx → byte offset within wEventFlags, and the single-bit mask. Modulo is written
; as idx-(idx/8)*8 to avoid NASM's '%' (preprocessor) in expressions.
%define EVENT_BYTE(i)  ((i) / 8)
%define EVENT_MASK(i)  (1 << ((i) - ((i) / 8) * 8))

; CheckEvent EVENT_X — test the flag; sets ZF (see header). Clobbers AL.
%macro CheckEvent 1
    mov al, [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
%endmacro

; SetEvent EVENT_X — set the flag. Clobbers AL.
%macro SetEvent 1
    mov al, [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)]
    or  al, EVENT_MASK(%1)
    mov [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)], al
%endmacro

; ResetEvent EVENT_X — clear the flag. Clobbers AL.
%macro ResetEvent 1
    mov al, [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)]
    and al, ~EVENT_MASK(%1) & 0xFF
    mov [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)], al
%endmacro

%macro CheckAndSetEvent 1
    mov al, [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
    pushfd
    or al, EVENT_MASK(%1)
    mov [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)], al
    popfd
%endmacro

%macro CheckAndResetEvent 1
    mov al, [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)]
    test al, EVENT_MASK(%1)
    pushfd
    and al, ~EVENT_MASK(%1) & 0xFF
    mov [ebp + W_EVENT_FLAGS + EVENT_BYTE(%1)], al
    popfd
%endmacro

%macro SetEvents 1-*
    %rep %0
        SetEvent %1
        %rotate 1
    %endrep
%endmacro

%macro ResetEvents 1-*
    %rep %0
        ResetEvent %1
        %rotate 1
    %endrep
%endmacro

%macro SetEventRange 2
    %assign i %1
    %rep (%2) - (%1) + 1
        SetEvent i
        %assign i i + 1
    %endrep
%endmacro

%macro ResetEventRange 2
    %assign i %1
    %rep (%2) - (%1) + 1
        ResetEvent i
        %assign i i + 1
    %endrep
%endmacro

%macro CheckBothEventsSet 2
    ; Emulates pret's CheckBothEventsSet.
    ; "returns whether both events are set in Z flag.
    ; This sets the Z flag when the event IS set."
    ; Wait, Z flag=1 if BOTH are set.
    ; We can check both by checking each. But it's easier to use a runtime logic that mimics the behavior.
    CheckEvent %1
    jz %%not_set
    CheckEvent %2
    jz %%not_set
    ; both are set -> ZF=1
    cmp al, al
    jmp %%done
%%not_set:
    ; not both set -> ZF=0
    test al, 0
%%done:
%endmacro

%macro CheckEitherEventSet 2
    ; "returns the complement of whether either event is set in Z flag"
    ; "Z flag=0 if either is set."
    ; Wait, the comment says: "Z flag=0 if either is set"
    CheckEvent %1
    jnz %%set
    CheckEvent %2
    jnz %%set
    ; neither is set -> ZF=1
    cmp al, al
    jmp %%done
%%set:
    ; either is set -> ZF=0
    test al, 0
%%done:
%endmacro

; Register-reuse variants as no-op `%define` aliases.
%define CheckEventReuseA CheckEvent
%define CheckEventAfterBranchReuseA CheckEvent
%define CheckEventHL CheckEvent
%define CheckEventReuseHL CheckEvent
%define CheckEventForceReuseHL CheckEvent
%define CheckEventAfterBranchReuseHL CheckEvent
%define CheckAndSetEventA CheckAndSetEvent
%define CheckAndResetEventA CheckAndResetEvent
%define CheckAndSetEventReuseHL CheckAndSetEvent
%define CheckAndResetEventReuseHL CheckAndResetEvent
%define SetEventReuseHL SetEvent
%define SetEventAfterBranchReuseHL SetEvent
%define SetEventForceReuseHL SetEvent
%define ResetEventReuseHL ResetEvent
%define ResetEventAfterBranchReuseHL ResetEvent
%define ResetEventForceReuseHL ResetEvent
%define CheckEitherEventSetReuseA CheckEitherEventSet

%endif ; EVENTS_INC
