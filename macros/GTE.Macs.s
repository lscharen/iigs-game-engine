* Generic Tile Engine Macros
*   by Lucas Scharenbroich

GTEToolNum           equ   $A0

_GTEBootInit         MAC
                     UserTool  $100+GTEToolNum
                     <<<
_GTEStartUp          MAC
                     UserTool  $200+GTEToolNum
                     <<<
_GTEShutDown         MAC
                     UserTool  $300+GTEToolNum
                     <<<
_GTEVersion          MAC
                     UserTool  $400+GTEToolNum
                     <<<
_GTEReset            MAC
                     UserTool  $500+GTEToolNum
                     <<<
_GTEStatus           MAC
                     UserTool  $600+GTEToolNum
                     <<<
_GTEReadControl      MAC
                     UserTool  $900+GTEToolNum
                     <<<
_GTESetScreenMode    MAC
                     UserTool  $A00+GTEToolNum
                     <<<
_GTESetTile          MAC
                     UserTool  $B00+GTEToolNum
                     <<<
_GTESetBG0Origin     MAC
                     UserTool  $C00+GTEToolNum
                     <<<
_GTERender           MAC
                     UserTool  $D00+GTEToolNum
                     <<<
