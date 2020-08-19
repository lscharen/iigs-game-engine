; Initialize the system for fun!
;
; Mostly memory allocation
;
; * 13 banks of memory for the blitter
; *  1 bank of memory for the second background
; *  1 bank of memory for the second background mask
;
; * $01/2000 - $01/9FFF for the shadow screen
; * $00/2000 - $00/9FFF for the fixed background
;
; * 10 pages of direct page in Bank $00
;   - 1 page for scratch space
;   - 1 page for pointer to the second background
;   - 8 pages for the dynamic tiles

            mx        %00

MemInit     PushLong  #0                   ; space for result
            PushLong  #$008000             ; size (32k)
            PushWord  UserId
            PushWord  #%11000000_00010111  ; Fixed location
            PushLong  #$002000
            _NewHandle                     ; returns LONG Handle on stack
            plx                            ; base address of the new handle
            pla                            ; high address 00XX of the new handle (bank)
            _Deref
            sta       Buff00+2
            stx       Buff00

            PushLong  #0                   ; space for result
            PushLong  #$008000             ; size (32k)
            PushWord  UserId
            PushWord  #%11000000_00010111  ; Fixed location
            PushLong  #$012000
            _NewHandle                     ; returns LONG Handle on stack
            plx                            ; base address of the new handle
            pla                            ; high address 00XX of the new handle (bank)
            _Deref
            sta       Buff01+2
            stx       Buff01

            PushLong  #0                   ; space for result
            PushLong  #$000A00             ; size (10 pages)
            PushWord  UserId
            PushWord  #%11000000_00010101  ; Page-aligned, fixed bank
            PushLong  #$000000
            _NewHandle                     ; returns LONG Handle on stack
            plx                            ; base address of the new handle
            pla                            ; high address 00XX of the new handle (bank)
            _Deref
            sta       ZeroPage+2
            stx       ZeroPage

            rts

Buff00      ds        4
Buff01      ds        4
ZeroPage    ds        4














