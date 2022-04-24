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