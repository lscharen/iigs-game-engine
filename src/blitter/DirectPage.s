; Direct page locations used by the engine
ScreenHeight           equ   0           ; Height of the playfield in scan lines
ScreenWidth            equ   2           ; Width of the playfield in bytes
ScreenY0               equ   4           ; First vertical line on the physical screen of the playfield
ScreenY1               equ   6           ; End of playfield on the physical screen. If the height is 20 and Y0 is
ScreenX0               equ   8           ; 100, then ScreenY1 = 120.
ScreenX1               equ   10
ScreenTileHeight       equ   12          ; Height of the playfield in 8x8 blocks
ScreenTileWidth        equ   14          ; Width of the playfield in 8x8 blocks

StartX                 equ   16          ; Which code buffer byte is the left edge of the screen. Range = 0 to 167
StartY                 equ   18          ; Which code buffer line is the top of the screen. Range = 0 to 207
EngineMode             equ   20          ; Defined the mode/capabilities that are enabled
                                         ;  bit 0: 0 = Single Background, 1 = Parallax
DirtyBits              equ   22          ; Identify values that have changed between frames

BG1DataBank            equ   24          ; Data bank that holds BG1 layer data
BG1AltBank             equ   26          ; Alternate BG1 bank

BlitterDP              equ   28          ; Direct page address the holder blitter data

OldStartX              equ   30
OldStartY              equ   32

LastPatchOffset        equ   34          ; Offset into code field that was patched with BRA instructions
StartXMod164           equ   36
StartYMod208           equ   38

BG1StartX              equ   40          ; Logical offset of the second background
BG1StartXMod164        equ   42

BG1StartY              equ   44
BG1StartYMod208        equ   46

OldBG1StartX           equ   48
OldBG1StartY           equ   50

BG1OffsetIndex         equ   52

BG0TileOriginX         equ   54          ; Coordinate in the tile map that corresponds to the top-left corner
BG0TileOriginY         equ   56
OldBG0TileOriginX      equ   58
OldBG0TileOriginY      equ   60

BG1TileOriginX         equ   62          ; Coordinate in the tile map that corresponds to the top-left corner
BG1TileOriginY         equ   64
OldBG1TileOriginX      equ   66
OldBG1TileOriginY      equ   68

TileMapWidth           equ   70
TileMapHeight          equ   72
TileMapPtr             equ   74

BG1TileMapWidth        equ   78
BG1TileMapHeight       equ   80
BG1TileMapPtr          equ   82

Next                   equ   86

BankLoad               equ   128

tiletmp                equ   186         ; 8 bytes of temp storage for the tile renderers
blttmp                 equ   192         ; 32 bytes of local cache/scratch space

tmp8                   equ   224
tmp9                   equ   226
tmp10                  equ   228
tmp11                  equ   230
tmp12                  equ   232
tmp13                  equ   234
tmp14                  equ   236
tmp15                  equ   238

tmp0                   equ   240         ; 16 bytes of temporary space to be used as scratch 
tmp1                   equ   242
tmp2                   equ   244
tmp3                   equ   246
tmp4                   equ   248
tmp5                   equ   250
tmp6                   equ   252
tmp7                   equ   254

DIRTY_BIT_BG0_X        equ   $0001
DIRTY_BIT_BG0_Y        equ   $0002
DIRTY_BIT_BG1_X        equ   $0004
DIRTY_BIT_BG1_Y        equ   $0008
DIRTY_BIT_BG0_REFRESH  equ   $0010
DIRTY_BIT_BG1_REFRESH  equ   $0020



