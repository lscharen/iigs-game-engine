; Direct page locations used by the engine
ScreenHeight      equ   0           ; Height of the playfield in scan lines
ScreenWidth       equ   2           ; Width of the playfield in bytes
ScreenY0          equ   4           ; First vertical line on the physical screen of the playfield
ScreenY1          equ   6           ; End of playfield on the physical screen. If the height is 20 and Y0 is
ScreenX0          equ   8           ; 100, then ScreenY1 = 120.
ScreenX1          equ   10
ScreenTileHeight  equ   12          ; Height of the playfield in 8x8 blocks
ScreenTileWidth   equ   14          ; Width of the playfield in 8x8 blocks

StartY            equ   16          ; Which code buffer line displays first on screen. Range = 0 to 207
EngineMode        equ   18          ; Defined the mode/capabilities that are enabled
                                    ;  bit 0: 0 = Single Background, 1 = Parallax
DirtyBits         equ   20          ; Identify values that have changed between frames

BG1DataBank       equ   22          ; Data bank that holds BG1 layer data
BlitterDP         equ   23          ; Direct page address the holder blitter data

bstk              equ   224         ; 16-byte stack to push bank addresses

tmp0              equ   240         ; 16 bytes of temporary space to be used as scratch 
tmp1              equ   242
tmp2              equ   244
tmp3              equ   246
tmp4              equ   248
tmp5              equ   250
tmp6              equ   252
tmp7              equ   254

DIRTY_BIT_BG0_X   equ   $0001
DIRTY_BIT_BG0_Y   equ   $0002






