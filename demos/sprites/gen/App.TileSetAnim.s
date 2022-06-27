
TileAnimInit
            pea #137
            pea #0
            _GTECopyTileToDynamic
            pea #138
            pea #1
            _GTECopyTileToDynamic
            pea #169
            pea #2
            _GTECopyTileToDynamic
            pea #170
            pea #3
            _GTECopyTileToDynamic
            rts

            pea #15
            pea #^TileAnim
            pea #TileAnim
            _GTEStartScript
            rts
TileAnim
            dw $0006,137,0,0
            dw $0006,138,1,0
            dw $0006,169,2,0
            dw $8006,170,3,0

            dw $0006,139,0,0
            dw $0006,140,1,0
            dw $0006,171,2,0
            dw $8006,172,3,0

            dw $0006,141,0,0
            dw $0006,142,1,0
            dw $0006,173,2,0
            dw $8006,174,3,0

            dw $0006,143,0,0
            dw $0006,144,1,0
            dw $0006,175,2,0
            dw $cc46,176,3,0          ; STOP; JUMP(-15)  -15 = $31 (6 bit) = %110001 = 1100 0100 = C4
