_TBSolidBG1_00
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4},x
                 sta:            $0000+{]line*$0100},y
                 ldal            tiledata+{]line*4}+2,x
                 sta:            $0002+{]line*$0100},y
]line            equ             ]line+1
                 --^
                 rts

_TBSolidBG1_0H
]line            equ             0
                 lup             8
                 ldal            tiledata+{]line*4}+64,x
                 sta:            $0000+{]line*$0100},y
                 ldal            tiledata+{]line*4}+64+2,x
                 sta:            $0002+{]line*$0100},y
]line            equ             ]line+1
                 --^
                 rts

_TBSolidBG1_V0
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4},x
                 sta:            $0000+{]dest*$0100},y
                 ldal            tiledata+{]src*4}+2,x
                 sta:            $0002+{]dest*$0100},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts

_TBSolidBG1_VH
]src             equ             7
]dest            equ             0
                 lup             8
                 ldal            tiledata+{]src*4}+64,x
                 sta:            $0000+{]dest*$0100},y
                 ldal            tiledata+{]src*4}+64+2,x
                 sta:            $0002+{]dest*$0100},y
]src             equ             ]src-1
]dest            equ             ]dest+1
                 --^
                 rts
