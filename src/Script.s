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
StartScript    ENT
               phb
               phk
               plb

               phx                    ; Save the script array address
               pha

               lda   #_DoScriptStep   ; Try to create a timer for this script
               ldx   #^_DoScriptStep
               clc
               jsl   AddTimer
               bcs   :err             ; No timer slots available :(

               tax                    ; Initialize the UeerData with the command array and PC
               pla
               sta   Timers+8,x
               pla
               sta   Timers+10,x
               stz   Timers+12,x      ; Index of the commands

               plb
               rtl

:err
               pla                    ; Pop the values and return with the carry flag set
               pla
               plb
               rtl

_DoScriptStep
               lda   Timers+8,x
               lda   Timers+10,x
               ldy   Timers+12,y
               lda   [CmdList],y
               pha                    ; save the full command word

               and   #$001E
               tax
               jsr   (:commands,x)

               pla                    ; restore the command word
               bit   #$4000           ; If the branch bit is set, change the command pointer
               beq   :no_jump

:no_jump
               bit   #$8000           ; If the terminate bit is set, remove this handler
               beq   :no_term
               txa
               jsl   RemoveTimer
:no_term
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

               ldx   ARG1,y           ; Load palette values
               ldal  SHR_PALETTES,x
               pha
               ldx   ARG2,y
               ldal  SHR_PALETTES,x

               ldx   ARG1,y           ; and swap
               stal  SHR_PALETTES,x

               ldx   ARG2,y
               pla
               stal  SHR_PALETTES,x
               rts

_UserCallback  lda   ARG1,x
               sta   :dispatch+1
               lda   ARG1+1,x
               sta   :dispatch+2
               lda   ARG3,x
:dispatch      jsl   $000000
               rts
























