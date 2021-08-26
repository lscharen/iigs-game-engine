; A simple scripting engine
;
; The scripting engine is driven by the GTE Timers, which are
; driven by the VBL Tick count.
;
; The scripting engine is composed of a sequence of simple commands, defined as follows
;
; COMMAND ARG1 ARG2 ARG3
;
; The COMMAND word has its bits defined as:
;
;   bit 15     = 1 if the end of a sequece
;   bit 14     = 0 proceed to next action, 1 jump
;   bit 13     = 0 (Reserved)
;   bit 12     = 0 (Reserved)
;   bit 11 - 8 = signed jump displacement
;   bit 8  - 0 = command number
;
; The defined commands are
;
; COMMANDS                     ARG1      ARG2      ARG3
; -----------------------------------------------------
; $0002     SET_PALETTE_ENTRY  ADDR      COLOR     ----  : Set the palette entry at ARG1 to the color in ARG2
; $0004     SWAP_PALETTE_ENTRY ADDR1     ADDR2     ----  : Swap the palette entries in ADDR1 <-> ADDR2
; $0010     CALLBACK           LONG_ADDR           PARAM : Call a user-defined function (JSL) with a parameter value in accumulator

; Start a new script
;
;  A = low word of script command array
;  X = high word of script command array
;  Y = number of ticks between each command step
;
; A pointer to the current command instruction is stored in the first 4 bytes of the 
; timer's user data section.
StartScript    ENT
               phb
               phk
               plb

               phx                   ; Save the script array address
               pha

               lda   #_DoScriptSeq   ; Try to create a timer for this script
               ldx   #^_DoScriptSeq
               clc
               jsl   AddTimer
               bcs   :err            ; No timer slots available :(

               tax                   ; Initialize the UserData with the command pointer
               pla
               sta   Timers+8,x
               pla
               sta   Timers+10,x

               plb
               rtl

:err
               pla                   ; Pop the values and return with the carry flag set
               pla
               plb
               rtl

; This routine executes script command until it encounters one with the STOP bit set.  In some
; sense, the stop bit acts like a "yield" in high-levellanguages.
_DoScriptSeq
               phx                   ; save the timer index; will need to update user data at the end
               phb                   ; save the current data bank

               sep   #$20            ; push the bank byte of the command list pointer on the stack
               lda   Timers+10,x
               pha
               rep   #$20

               lda   Timers+8,x      ; get the current address of the command sequence
               tax
               plb                   ; pop the bank

; Now we are ready to process commands until reaching one with the STOP bit set.  Each command
; is 8 bytes, so we just have to do a very simple fetch/execute/increment loop.  The only
; exception is handling the JUMP bit which requires moving the script pc stored in the 
; x-register.

:loop          phx                   ; Save the command address

               lda:  0,x             ; Load the command word
               pha                   ; Stash it

               and   #$001E          ; Only have 16 built-in command.  Use the _UserCallback
               tax                   ; command for custom functionality
               jsr   (:commands,x)

               lda   1,s             ; Reload the command word

; Move to the next instruction.  If the JUMP bit is set, we move the address forward or 
; backward N commands (8 bytes at a time).  If the JUMP bit is not set, then just move 
; to the next entry.
               bit   #$4000          ; Just do a fall through and set the jump offset to
               bne   :move_addr      ; a hard-coded value of 1 if the jump bit is not set
:retry         lda   #$0100
:move_addr     and   #$0F00          ; mask out the number of commands to move
               beq   :retry          ; Don't allow zeros; will cause infinite loop.  Just advance by one.

               xba                   ; put it in the low byte
               cmp   #$0008          ; Sign-extend the 4-bit value
               bcc   *+5
               ora   #$FFF0

               asl                   ; multiply by 8
               asl
               asl
               clc
               adc   3,s             ; add it to the saved command address
               sta   3,s

; Check to see if we stop on this instruction, or continue executing commands

               pla                   ; Reload the command word
               plx                   ; Pop off the update command address

               bit   #$8000          ; If the stop bit is set, we're done with this sequence
               beq   :loop           ; Otherwise, keep going and fetch the next command word

               txa                   ; save the current command address
               plb                   ; restore the data bank and the timer index
               plx
               sta   Timers+8,x      ; store the command address back into the timer user data space

               rtl

:commands      dw    _Null,_SetPalEntry,_SwapPalEntry,_Null,_Null,_Null,_Null,_Null
               dw    _UserCallback,_Null,_Null,_Null,_Null,_Null,_Null,_Null

ARG1           equ   2
ARG2           equ   4
ARG3           equ   6

; Implementation of the built-in commands
_Null          rts

_SetPalEntry
               txy
               ldx:  ARG1,y
               lda:  ARG2,y
               stal  SHR_PALETTES,x
               rts

_SwapPalEntry  txy

               ldx:  ARG1,y          ; Load palette values
               ldal  SHR_PALETTES,x
               pha
               ldx:  ARG2,y
               ldal  SHR_PALETTES,x

               ldx:  ARG1,y          ; and swap
               stal  SHR_PALETTES,x

               ldx:  ARG2,y
               pla
               stal  SHR_PALETTES,x
               rts

_UserCallback  lda:  ARG1,x
               sta   :dispatch+1
               lda:  ARG1+1,x
               sta   :dispatch+2
               lda:  ARG3,x
:dispatch      jsl   $000000
               rts


