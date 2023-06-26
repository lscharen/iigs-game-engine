; This is the method that is most useful from the high-level code.  We want the
; freedom to blit a range of lines.  This subroutine can assume that all of the
; data in the code fields is set up properly.
;
; X = first line (inclusive), valid range of 0 to 199
; Y = last line  (exclusive), valid range >X up to 200
;
; The lines are based on the appearance of lines in the play field, so blitting lines 0 through
; 19 will draw the first 20 lines on the play field, regardless of where the playfield is physically
; on the SHR screen or the current value of StartY
_BltRange

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2

                sty   :jmp_low_save  ; Steal some temp space and check for empty ranges
                cpx   :jmp_low_save  ; This makes it simpler for some callers
                bcc   *+3
                rts

; If the background is disabled, jump to a specialized BG routine

                lda   GTEControlBits
                bit   #CTRL_BKGND_DISABLE
                beq   :normal
                brl   DisabledBG
:normal

; If we are in "lite" mode, defer to that implementation
                lda  EngineMode
                bit  #ENGINE_MODE_TWO_LAYER+ENGINE_MODE_DYN_TILES
                bne  :dark
                jmp  _BltRangeLite

:dark
                phb                  ; preserve the bank register
                clc

                dey
                tya                  ; Get the address of the line that we want to return from
                adc   StartYMod208   ; and create a pointer to it
                asl
                tay
                lda   BTableLow,y
                sta   :exit_ptr
                lda   BTableHigh,y
                sta   :exit_ptr+2

                txa                  ; get the first line (0 - 199)
                adc   StartYMod208   ; add in the virtual offset (0, 207) -- max value of 406
                asl
                tax                  ; this is the offset into the blitter table

                sep   #$20           ; 8-bit Acc
                lda   BTableHigh,x   ; patch in the bank
                stal  blt_entry+3

                lda   BTableLow+1,x  ; patch in the page
                stal  blt_entry+2

; The way we patch the exit code is subtle, but very fast.  The CODE_EXIT offset points to
; an JMP/JML instruction that transitions to the next line after all of the code has been
; executed.
;
; The trick we use is to patch the low byte to force the code to jump to a special return
; function (jml blt_return) in the *next* code field line.

                ldy   #CODE_EXIT+1   ; this is a JMP or JML instruction that points to the next line.
                lda   [:exit_ptr],y
                sta   :jmp_low_save
                lda   #FULL_RETURN   ; this is the offset of the return code
                sta   [:exit_ptr],y  ; patch out the low byte of the JMP/JML

; Now we need to set up the Bank, Stack Pointer and Direct Page registers for calling into 
; the code field

                lda   EngineMode
                bit   #ENGINE_MODE_TWO_LAYER
                beq   :skip_bank

; Load the BG1 data bank

                lda   BG1DataBank
                pha
                plb

:skip_bank
                rep   #$20

                phd                  ; Save the application direct page
                lda   BlitterDP      ; Set the direct page to the blitter data
                tcd

                php                  ; save the current processor flags
                sei                  ; disable interrupts
                _R0W1
                tsc                  ; save the stack pointer
                stal  stk_save+1
                
blt_entry       jml   $000000        ; Jump into the blitter code $XX/YY00

blt_return      _R0W0
stk_save        lda   #0000          ; load the stack
                tcs
                plp                  ; re-enable interrupts (maybe, if interrupts disabled when we are called, they are not re-endabled)
                pld                  ; restore the direct page

:exit_ptr       equ   tmp0
:jmp_low_save   equ   tmp2

                sep   #$20
                ldy   #CODE_EXIT+1
                lda   :jmp_low_save
                sta   [:exit_ptr],y
                rep   #$20

                plb                  ; restore the bank
                rts

; Specialize routine that just slams a bunch of PHA instructions when background rendering is disabled
DisabledBG
                stx  tmp15
                tya
                sec
                sbc  tmp15
                tay                  ; Put the count in the y register

                lda  ScreenWidth     ; Screen width in bytes (0 - 159)
                lsr                  ; Convert to number of word
                eor  #$FFFF
                adc  #:blkend        ; subtract from the end of the PHA array
                stal :patch+1

                lda  #8              ; Enable interrups at least this many lines
                sta  tmp14

                txa                  ; multiply starting line by 2 for indexing
                asl
                tax

                php                  ; save the current processor flags
                sei                  ; disable interrupts
                tsc                  ; save the stack pointer
                sta  tmp15
                _R0W1

:loop
                lda  RTable,x        ; Load the screen right edge
                tcs
                lda  #0
:patch          jmp  $0000
                lup  80
                pha
                --^
:blkend
                dec   tmp14
                bmi   :enable_int

:next
                inx
                inx
                dey
                bne  :loop

                _R0W0
                lda  tmp15
                tcs
                plp
                rts

:enable_int
                lda   #8             ; Reset the counter
                sta   tmp14

                lda   tmp15         ; restore the stack
                tcs

                sep   #$30                       ; 8-bit mode
                lda   STATE_REG_OFF              ; Could be on the direct page....
                stal  STATE_REG
                cli
                sei
                lda   STATE_REG_BLIT             ; External values 
                stal  STATE_REG
                rep   #$30
                bra   :next

; External entry point.  Can be called directly from another bank
BltRange
                phd
                phb

                ldal   tool_direct_page
                tcd
                jsr    _SetDataBank             ; only affects accumulator
                jsr    _BltRange
                plb
                pld
                rtl