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
R_CHAR_COUNT equ   8       ; "TICK:XXX"
L_CHAR_COUNT equ   7       ; "FPS:XXX"

; Allocate a single buffer for holding both the left and right overlay characters + masks
CHAR_WIDTH  equ   4
OVRLY_SPAN  equ   {{L_CHAR_COUNT+R_CHAR_COUNT}*CHAR_WIDTH}

ovrly_buff  ds    OVRLY_SPAN*8
ovrly_mask  ds    OVRLY_SPAN*8

r_line      equ   ovrly_buff+{L_CHAR_COUNT*CHAR_WIDTH}
l_line      equ   ovrly_buff
r_mask      equ   ovrly_mask+{L_CHAR_COUNT*CHAR_WIDTH}
l_mask      equ   ovrly_mask

MASK_OFFSET equ   {ovrly_mask-ovrly_buff}

InitOverlay
             lda    #'F'
             ldy    #l_line+{CHAR_WIDTH*0}
             jsr    _DrawChar
             lda    #'P'
             ldy    #l_line+{CHAR_WIDTH*1}
             jsr    _DrawChar
             lda    #'S'
             ldy    #l_line+{CHAR_WIDTH*2}
             jsr    _DrawChar
             lda    #':'
             ldy    #l_line+{CHAR_WIDTH*3}
             jsr    _DrawChar

             lda    #'T'
             ldy    #r_line+{CHAR_WIDTH*0}
             jsr    _DrawChar
             lda    #'I'
             ldy    #r_line+{CHAR_WIDTH*1}
             jsr    _DrawChar
             lda    #'C'
             ldy    #r_line+{CHAR_WIDTH*2}
             jsr    _DrawChar
             lda    #'K'
             ldy    #r_line+{CHAR_WIDTH*3}
             jsr    _DrawChar
             lda    #':'
             ldy    #r_line+{CHAR_WIDTH*4}
             jsr    _DrawChar
             rts

; Update the dynamic content of the overlay
_num2ascii
             and   #$000F
             cmp   #$000A
             bcc   :out
             clc
             adc   #'A'-'0'-10

:out         clc
             adc   #'0'
             rts

UdtOverlay
             lda   frameCount                       ; render the FPS value
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

             ldal  OneSecondCounter                   ; reder the number of remaining seconds
             xba
             jsr   _num2ascii
             ldy   #r_line+{CHAR_WIDTH*5}
             jsr    _DrawChar

             ldal  OneSecondCounter
             lsr
             lsr
             lsr
             lsr
             jsr   _num2ascii
             ldy   #r_line+{CHAR_WIDTH*6}
             jsr    _DrawChar

             ldal  OneSecondCounter
             jsr   _num2ascii
             ldy   #r_line+{CHAR_WIDTH*7}
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

             lda   l_addr
             clc
             adc   ScreenWidth
             sec
             sbc   #{R_CHAR_COUNT*CHAR_WIDTH}
             sta   r_addr                            ; this is the DP for the right side

; Calculate the TSB slam entry point

             sec
             sbc   m_addr                            ; calculate the number of words between the two ends
             and   #$FFFE
             pha
             lda   #m_end
             sec
             sbc   1,s
             sta   m_patch+1
             pla

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

l_addr       ds    2
m_addr       ds    2
r_addr       ds    2


r_ovrly
]idx        equ   0
            lup   R_CHAR_COUNT
            lda   ]idx
            and   r_line+MASK_OFFSET+]idx,x
            ora   r_line+]idx,x
            sta   ]idx
            lda   ]idx+2
            and   r_line+MASK_OFFSET+]idx+2,x
            ora   r_line+]idx+2,x
            sta   ]idx+2
]idx        equ   ]idx+4
            --^
            jmp   r_ovrly_rtn                       ; In R1W1, so can't use the stack

l_ovrly
]idx        equ   0
            lup   L_CHAR_COUNT
            lda   ]idx
            and   l_line+MASK_OFFSET+]idx,x
            ora   l_line+]idx,x
            sta   ]idx
            lda   ]idx+2
            and   l_line+MASK_OFFSET+]idx+2,x
            ora   l_line+]idx+2,x
            sta   ]idx+2
]idx        equ   ]idx+4
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

_DCOut      rts

_DrawChar
            cmp             #'0'
            bcc             _DCOut
            cmp             #'Z'+1
            bcs             _DCOut

            sec
            sbc             #'0'
            clc
            adc             #CHAR_TILE_BASE
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