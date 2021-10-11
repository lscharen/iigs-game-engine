; An overlay is a callback from the render to shadow in a range of lines.  At a minimum, the overlay
; code needs to LDA/STA or TSB slam the data, but an overlay is typically used to draw some graphic
; on top of the rendered playfield, such as a status bar or in-game message
;
; This overlay implementation is for a status bar that is 8-lines height that will be used to display some
; status information.  The interesting bit of this implementation is that it's split into two pieces,
; a left and right section in order to be able to use the same code for different screen widths, but
; still keep the content in the cornders while covering the full screen.
;
; There are two subroutines that need to be implemented -- one to update the overlay content and a 
; second to actually render to the screen

; Initialize the overlay be drawin gin static content that will not change over time

CHAR_TILE_BASE equ 241     ; set this to the real tile id that starts an ASCII run starting at '0' through 'Z'

; Define the sized of the left and right overlay buffers
R_CHAR_COUNT equ   9       ; "TICK:XXX"
L_CHAR_COUNT equ   8       ; "FPS:XXX"

; Allocate a single buffer for holding both the left and right overlay characters + masks
OVRLY_SPAN  equ   {L_CHAR_COUNT+R_CHAR_COUNT}*4
CHAR_WIDTH  equ   4

ovrly_buff  ds    OVRLY_SPAN*8
ovrly_mask  ds    OVRLY_SPAN*8

r_line      equ   ovrly_buff+{L_CHAR_COUNT*4}
l_line      equ   ovrly_buff
r_mask      equ   ovrly_mask+{L_CHAR_COUNT*4}
l_mask      equ   ovrly_mask

MASK_OFFSET equ   {ovrly_mask-ovrly_buff}

InitOverlay
             lda    #'F'-'0'
             ldy    #l_line+{CHAR_WIDTH*0}
             jsr    _DrawChar
             lda    #'P'-'0'
             ldy    #l_line+{CHAR_WIDTH*1}
             jsr    _DrawChar
             lda    #'S'-'0'
             ldy    #l_line+{CHAR_WIDTH*2}
             jsr    _DrawChar
             lda    #':'-'0'
             ldy    #l_line+{CHAR_WIDTH*3}
             jsr    _DrawChar

             lda    #'T'-'0'
             ldy    #r_line+{CHAR_WIDTH*0}
             jsr    _DrawChar
             lda    #'I'-'0'
             ldy    #r_line+{CHAR_WIDTH*1}
             jsr    _DrawChar
             lda    #'C'-'0'
             ldy    #r_line+{CHAR_WIDTH*2}
             jsr    _DrawChar
             lda    #'K'-'0'
             ldy    #r_line+{CHAR_WIDTH*3}
             jsr    _DrawChar
             lda    #':'-'0'
             ldy    #r_line+{CHAR_WIDTH*4}
             jsr    _DrawChar
             rts

; Update the dynamic content of the overlay
_num2ascii
             and   #$000F
             cmp   #$000A
             bcc   :out
             clc
             adc   #'A'-10
:out         rts

UdtOverlay
             lda   frameCount                       ; reder the FPS value
             xba
             jsr   _num2ascii
             ldy   #l_line+{CHAR_WIDTH*4}
             jsr    _DrawChar

             lda   frameCount
             lsr
             lsr
             lsr
             lsr
             jsr   _num2ascii
             ldy   #l_line+{CHAR_WIDTH*5}
             jsr    _DrawChar

             lda   frameCount
             jsr   _num2ascii
             ldy   #l_line+{CHAR_WIDTH*6}
             jsr    _DrawChar

             lda   OneSecondCounter                   ; reder the number of remaining seconds
             xba
             jsr   _num2ascii
             ldy   #r_line+{CHAR_WIDTH*5}
             jsr    _DrawChar

             lda   OneSecondCounter
             lsr
             lsr
             lsr
             lsr
             jsr   _num2ascii
             ldy   #r_line+{CHAR_WIDTH*6}
             jsr    _DrawChar

             lda   OneSecondCounter
             jsr   _num2ascii
             ldy   #l_line+{CHAR_WIDTH*7}
             jsr    _DrawChar

             rts

; Draw the overlay
;  A = address of the left edge of the screen
Overlay      ENT
             phb                                     ; Called via JSL
             phk
             plb

             phd                                     ; save the direct page register

             sta   l_addr                            ; save this value (will go into D-reg later)
             clc
             adc   #L_CHAR_COUNT*CHAR_WIDTH          ; advance past the left characters
             sta   m_addr                            ; this is the DP for the TSB slam

             lda   ScreenWidth
             sec
             sbc   #R_CHAR_COUNT*CHAR_WIDTH          ; calculate the left edge of the right side
             clc
             adc   l_addr                            ; add to the left edge
             dec
             sta   r_addr                            ; this is the DP for the right side

; Calculate the TSB slam entry point

             lda   ScreenWidth                       ; subtract the width of all the characters to figure
             sec                                     ; out what need to be shadowed in the middle
             sbc   #{R_CHAR_COUNT+L_CHAR_COUNT}*CHAR_WIDTH                                  
             eor   #$FFFF
             inc                                     ; get the negative value
             clc
             adc   #m_end
             sta   m_patch+1

             sei
             _R1W1

             ldy   #8                                ; count the line we're on
             ldx   #0
ovrly_loop
             lda   r_addr
             tcd                                     ; set the direct page for the right side
             jmp   r_ovrly                           ; render that line
r_ovrly_rtn

             lda   m_addr
             tcd                                     ; set the direct page for the slam in the middle
             lda   #0                                ; set to zero for TSB slam
m_patch      jmp   $0000                             ; jump into the slam field  
m_ovrly_rtn

             lda   l_addr                            ; set the direct page for the left side
             tcd
             jmp   l_ovrly
l_ovrly_rtn
             clc
             tdc
             adc   #160                              ; advance to the next screen line
             sta   l_addr
             adc   #{L_CHAR_COUNT*CHAR_WIDTH}
             sta   m_addr
             lda   r_addr
             adc   #160
             sta   r_addr

             txa
             adc   #OVRLY_SPAN
             tax

             dey
             bne  ovrly_loop

             _R0W0
             cli

:exit
             pld                                     ; restore the direct page and bank and return
             plb
             rtl

l_addr       ds   2
m_addr       ds    2
r_addr       ds    2


r_ovrly
]idx        equ   0
            lup   16
            lda   r_line+]idx,x
            sta   ]idx
]idx        equ   ]idx+2
            --^
            jmp   r_ovrly_rtn                       ; In R1W1, so can't use the stack

l_ovrly
]idx        equ   0
            lup   20
            lda   l_line+]idx,x
            sta   ]idx
]idx        equ   ]idx+2
            --^
            jmp   l_ovrly_rtn
 
; Single TSB slam
m_line
]idx        equ   $9E
            lup   80                    ; 80 words max for a full-width screen
            tsb   ]idx
]idx        equ   ]idx-2
            --^
m_end
            jmp      m_ovrly_rtn


; Draw a character (tile) into a location of the overlay
;
; A = Tile ID
; Y = overlay address location
tiledata     EXT

_DrawChar
            jsl             GetTileAddr
            tax

]idx        equ             0
            lup             8
            ldal            tiledata+32+{]idx*4},x
            sta:            {]idx*OVRLY_SPAN}+MASK_OFFSET,y
            ldal            tiledata+{]idx*4},x
            sta:            {]idx*OVRLY_SPAN},y
            ldal            tiledata+32+{]idx*4}+2,x
            sta:            {]idx*OVRLY_SPAN}+MASK_OFFSET+2,y
            ldal            tiledata+{]idx*4}+2,x
            sta:            {]idx*OVRLY_SPAN}+2,y
]idx        equ             ]idx+1
            --^
            rts