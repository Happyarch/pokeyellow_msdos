%ifndef DATA_MACROS_INC
%define DATA_MACROS_INC

; -----------------------------------------------------------------------------
; data_macros.inc — Constant data macros
; -----------------------------------------------------------------------------

%macro dbw 2
    db %1
    dw %2
%endmacro

%macro dwb 2
    dw %1
    db %2
%endmacro

%macro dn 2-*
    %rep %0 / 2
        db ((%1) << 4) | (%2)
        %rotate 2
    %endrep
%endmacro

%macro dc 4-*
    %rep %0 / 4
        db ((%1) << 6) | ((%2) << 4) | ((%3) << 2) | (%4)
        %rotate 4
    %endrep
%endmacro

%macro bcd2 1
    dn (((%1) / 1000) % 10), (((%1) / 100) % 10)
    dn (((%1) / 10) % 10), ((%1) % 10)
%endmacro

%macro bcd3 1
    dn (((%1) / 100000) % 10), (((%1) / 10000) % 10)
    dn (((%1) / 1000) % 10), (((%1) / 100) % 10)
    dn (((%1) / 10) % 10), ((%1) % 10)
%endmacro

; dba/dab originally emitted bank, offset. 
; In the DOS flat model, a pointer is 32-bit (dd).
%macro dba 1-*
    %rep %0
        dd %1
        %rotate 1
    %endrep
%endmacro

%macro dab 1-*
    %rep %0
        dd %1
        %rotate 1
    %endrep
%endmacro

%macro bigdw 1-*
    %rep %0
        db ((%1) >> 8) & 0xFF, (%1) & 0xFF
        %rotate 1
    %endrep
%endmacro

%macro dname 1-2
    %if %0 == 2
        %assign n %2
    %else
        %assign n 10 ; NAME_LENGTH - 1 (Assuming NAME_LENGTH=11)
    %endif
    %strlen len %1
    db %1
    times (n - len) db '@'
%endmacro

%macro tmhm 0-*
    %assign tm0 0
    %assign tm1 0
    %assign tm2 0
    %assign tm3 0
    %assign tm4 0
    %assign tm5 0
    %assign tm6 0
    %rep %0
        %assign bit_idx (%1 %+ _TMNUM - 1)
        %assign byte_idx (bit_idx / 8)
        %assign bit_shl (1 << (bit_idx % 8))
        %if byte_idx == 0
            %assign tm0 tm0 | bit_shl
        %elif byte_idx == 1
            %assign tm1 tm1 | bit_shl
        %elif byte_idx == 2
            %assign tm2 tm2 | bit_shl
        %elif byte_idx == 3
            %assign tm3 tm3 | bit_shl
        %elif byte_idx == 4
            %assign tm4 tm4 | bit_shl
        %elif byte_idx == 5
            %assign tm5 tm5 | bit_shl
        %elif byte_idx == 6
            %assign tm6 tm6 | bit_shl
        %endif
        %rotate 1
    %endrep
    db tm0, tm1, tm2, tm3, tm4, tm5, tm6
%endmacro

%endif
