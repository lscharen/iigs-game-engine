; Test driver to exercise graphics routines.

                    REL
                    DSK        MAINSEG

                    use        Locator.Macs.s
                    use        Misc.Macs.s
                    use        EDS.GSOS.MACS.s
                    use        Tool222.Macs.s
                    use        Util.Macs.s
                    use        CORE.MACS.s
                    use        ../../src/GTE.s
                    use        ../../src/Defs.s

                    mx         %00

; Feature flags
NO_INTERRUPTS       equ        0                       ; turn off for crossrunner debugging
NO_MUSIC            equ        1                       ; turn music + tool loading off

; Keycodes
LEFT_ARROW          equ        $08
RIGHT_ARROW         equ        $15
UP_ARROW            equ        $0B
DOWN_ARROW          equ        $0A

; Typical init
                    phk
                    plb

                    jsl        EngineStartUp

                    lda        #^MyPalette
                    ldx        #MyPalette
                    ldy        #0
                    jsl        SetPalette

                    ldx        #0
                    jsl        SetScreenMode

; Set up our level data
                    jsr        BG0SetUp
                    jsr        TileAnimInit

; Allocate room to load data

                    jsl        AllocBank               ; Alloc 64KB for Load/Unpack
                    sta        BankLoad                ; Store "Bank Pointer"

                    jsr        MovePlayerToOrigin      ; Put the player at the beginning of the map

                    lda        #DIRTY_BIT_BG0_REFRESH  ; Redraw all of the tiles on the next Render
                    ora        #DIRTY_BIT_BG1_REFRESH
                    tsb        DirtyBits

                    lda        #$FFFF
                    jsl        Render
EvtLoop
                    jsl        DoTimers
                    jsl        Render

                    jsl        ReadControl
                    and        #$007F                  ; Ignore the buttons for now

                    cmp        #'q'
                    bne        :7
                    brl        Exit

:7                  cmp        #LEFT_ARROW
                    bne        :8
                    brl        EvtLoop

:8                  cmp        #RIGHT_ARROW
                    bne        :9
                    brl        EvtLoop

:9
                    brl        EvtLoop

; Exit code
Exit
                    jsl        EngineShutDown

                    _QuitGS    qtRec

                    bcs        Fatal
Fatal               brk        $00

MyPalette           dw         $0000,$0777,$0F31,$0E51,$00A0,$02E3,$0BF1,$0FA4,$0FD7,$0EE6,$0F59,$068F,$01CE,$09B9,$0EDA,$0EEE

; Position the screen with the botom-left corner of the tilemap visible
MovePlayerToOrigin
                    lda        #0                      ; Set the player's position
                    jsl        SetBG0XPos
                    lda        #0
                    jsl        SetBG1XPos

                    lda        TileMapHeight
                    asl
                    asl
                    asl
                    sec
                    sbc        ScreenHeight
                    pha
                    jsl        SetBG0YPos
                    pla
                    jsl        SetBG1YPos

                    rts

qtRec               adrl       $0000
                    da         $00

                    PUT        gen/App.TileMapBG0.s
                    PUT        gen/App.TileSetAnim.s

Overlay             ENT
                    rtl

ANGLEBNK            ENT