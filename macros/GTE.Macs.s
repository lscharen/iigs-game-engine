* Generic Tile Engine Macros
*   by Lucas Scharenbroich

GTEToolNum           equ   $A0

_GTEBootInit         MAC
                     UserTool  $0100+GTEToolNum
                     <<<
_GTEStartUp          MAC
                     UserTool  $0200+GTEToolNum
                     <<<
_GTEShutDown         MAC
                     UserTool  $0300+GTEToolNum
                     <<<
_GTEVersion          MAC
                     UserTool  $0400+GTEToolNum
                     <<<
_GTEReset            MAC
                     UserTool  $0500+GTEToolNum
                     <<<
_GTEStatus           MAC
                     UserTool  $0600+GTEToolNum
                     <<<
_GTEReadControl      MAC
                     UserTool  $0900+GTEToolNum
                     <<<
_GTESetScreenMode    MAC
                     UserTool  $0A00+GTEToolNum
                     <<<
_GTESetTile          MAC
                     UserTool  $0B00+GTEToolNum
                     <<<
_GTESetBG0Origin     MAC
                     UserTool  $0C00+GTEToolNum
                     <<<
_GTERender           MAC
                     UserTool  $0D00+GTEToolNum
                     <<<
_GTELoadTileSet      MAC
                     UserTool  $0E00+GTEToolNum
                     <<<
_GTECreateSpriteStamp MAC
                     UserTool  $0F00+GTEToolNum
                     <<<
_GTEAddSprite        MAC
                     UserTool  $1000+GTEToolNum
                     <<<
_GTEMoveSprite       MAC
                     UserTool  $1100+GTEToolNum
                     <<<
_GTEUpdateSprite     MAC
                     UserTool  $1200+GTEToolNum
                     <<<
_GTERemoveSprite     MAC
                     UserTool  $1300+GTEToolNum
                     <<<
_GTEGetSeconds       MAC
                     UserTool  $1400+GTEToolNum
                     <<<
_GTECopyTileToDynamic MAC
                      UserTool  $1500+GTEToolNum
                      <<<