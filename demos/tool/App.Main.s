                REL
                DSK   MAINSEG

                use   Locator.Macs
                use   Load.Macs
                use   Mem.Macs
                use   Misc.Macs
                use   Util.Macs
                use   EDS.GSOS.Macs

_GTEStartUp     MAC
                UserTool  $02A0
                <<<

; Typical init
                phk
                plb

                jsr   ToolStartUp             ; Start up the basic tools: Locator, Memory Manager, Misc
                jsr   GTEStartUp

                _QuitGS qtRec

                bcs        Fatal
Fatal           brk        $00
qtRec           adrl       $0000
                da         $00

ToolStartUp
                _TLStartUp                    ; normal tool initialization
                pha
                _MMStartUp
                pla
                sta   MasterId                ; our master handle references the memory allocated to us
                ora   #$0100                  ; set auxID = $01  (valid values $01-0f)
                sta   UserId                  ; any memory we request must use our own id 

                _MTStartUp
                rts

; Load the GTE User Tool and register it
GTEStartUp
                pea   $0000
                pea   $0000
                pea   $0000
                pea   $0000
                pea   $0000                   ; result space

                lda   UserId
                pha

                pea   #^ToolPath
                pea   #ToolPath
                pea   $0001                   ; do not load into special memory
                pea   $0001                   ; GS/OS string for the argument
                _InitialLoad2
                
                ply
                pla                           ; Address of the loaded tool
                plx
                ply
                ply

                pea   $8000                   ; User toolset
                pea   $00A0                   ; Set the tool set number
                phx
                pha                           ; Address of function pointer table
                _SetTSPtr

                clc                           ; Give GTE a page of direct page memory
                tdc
                adc   #$0100
                pha
                lda   UserId
                pha
                _GTEStartUp

                rts


MasterId        ds    2
UserId          ds    2
ToolPath        strl  '9:GTETool'