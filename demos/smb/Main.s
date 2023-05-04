            REL

            use   Locator.Macs
            use   Load.Macs
            use   Mem.Macs
            use   Misc.Macs
            use   Util.Macs
            use   EDS.GSOS.Macs
            use   GTE.Macs
            use   Externals.s

            mx    %00

; Direct page space
MyUserId    equ   0

            phk
            plb
            sta   MyUserId                ; GS/OS passes the memory manager user ID for the application into the program

            _MTStartUp                    ; GTE requires the miscellaneous toolset to be running

            pea  $00A0                    ; Load from System:Tools
            pea  $0100                    ; Tool160, version 1.0
            _LoadOneTool

            clc                           ; Give GTE a page of direct page memory
            tdc
            adc   #$0100
            pha
            pea   $0000                   ; Default fast mode
            lda   MyUserId                ; Pass the userId for memory allocation
            pha
            _GTEStartUp

; Initialize the graphics screen playfield (256x160).  The NES is 240 lines high, so 160
; is a reasonable compromise.

            pea   #160
            pea   #200
            _GTESetScreenMode

; Convert the CHR ROM from the cart into GTE tiles

;            jsr  LoadTilesFromROM


            _GTEShutDown
            _QuitGS    qtRec
qtRec       adrl  $0000
            da    $00