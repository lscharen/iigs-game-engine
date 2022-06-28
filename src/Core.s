                  use       Util.Macs.s
                  use       Load.Macs.s
                  use       Locator.Macs.s
                  use       Mem.Macs.s
                  use       Misc.Macs.s
                  use       Tool222.MACS.s
                  use       Core.MACS.s

                  use       .\Defs.s

EngineStartUp     ENT
                  phb
                  phk
                  plb

                  jsr       ToolStartUp         ; Start up the toolbox tools we rely on
                  jsr       _CoreStartUp
                  jsr       SoundStartUp        ; Start up any sound/music tools

                  plb
                  rtl

EngineShutDown    ENT
                  phb
                  phk
                  plb

                  jsr       SoundShutDown
                  jsr       _CoreShutDown
                  jsr       ToolShutDown

                  plb
                  rtl

ToolStartUp
                  _TLStartUp                    ; normal tool initialization
                  pha
                  _MMStartUp
                  _Err                          ; should never happen
                  pla
                  sta       MasterId            ; our master handle references the memory allocated to us
                  ora       #$0100              ; set auxID = $01  (valid values $01-0f)
                  sta       UserId              ; any memory we request must use our own id 

                  _MTStartUp
                  rts

MasterId          ds        2

; Fatal error handler invoked by the _Err macro
PgmDeath          tax
                  pla
                  inc
                  phx
                  phk
                  pha
                  bra       ContDeath
PgmDeath0         pha
                  pea       $0000
                  pea       $0000
ContDeath         ldx       #$1503
                  jsl       $E10000

; Use Tool222 (NinjaTrackerPlus) for music playback
SoundStartUp
                  lda       #NO_MUSIC
                  bne       :no_music

                  pea       $00DE
                  pea       $0000
                  _LoadOneTool
                  _Err

                  lda       UserId
                  pha
                  _NTPStartUp
:no_music
                  rts

SoundShutDown
                  lda       #NO_MUSIC
                  bne       :no_music
                  _NTPShutDown
:no_music
                  rts

ToolShutDown
                  rts

                  put       CoreImpl.s
                  put       blitter/Template.s

                  put       Memory.s
                  put       Graphics.s
                  put       Sprite.s
                  put       blitter/Tiles.s
                  put       Sprite2.s
                  put       SpriteRender.s
                  put       Render.s
                  put       Timer.s
                  put       Script.s
                  put       blitter/Blitter.s
                  put       blitter/Horz.s
                  put       blitter/PEISlammer.s
                  put       blitter/Tables.s
                  put       blitter/Tiles00000.s      ; normal tiles
                  put       blitter/Tiles00001.s      ; dynamic tiles
                  put       blitter/Tiles00010.s      ; normal masked tiles
                  put       blitter/Tiles00011.s      ; dynamic masked tiles

                  put       blitter/Tiles10000.s      ; normal tiles + sprites
                  put       blitter/Tiles10001.s      ; dynamic tiles + sprites
                  put       blitter/Tiles10010.s      ; normal masked tiles + sprites
                  put       blitter/Tiles10011.s      ; dynamic masked tiles + sprites

                  put       blitter/Tiles11000.s      ; normal high priority tiles + sprites
                  put       blitter/Tiles11001.s      ; dynamic high priority tiles + sprites
                  put       blitter/Tiles11010.s      ; normal high priority masked tiles + sprites
                  put       blitter/Tiles11011.s      ; dynamic high priority masked tiles + sprites

                  put       blitter/TilesBG1.s
                  put       blitter/Vert.s
                  put       blitter/BG0.s
                  put       blitter/BG1.s
                  put       blitter/SCB.s
                  put       TileMap.s
