
TileAnimInit    ENT

            ldx #137
            ldy #0
            jsl CopyTileToDyn
            ldx #138
            ldy #1
            jsl CopyTileToDyn
            ldx #169
            ldy #2
            jsl CopyTileToDyn
            ldx #170
            ldy #3
            jsl CopyTileToDyn
            lda #TileAnim_136
            ldx #^TileAnim_136
            ldy #15
            jsl StartScript
            lda #TileAnim_137
            ldx #^TileAnim_137
            ldy #15
            jsl StartScript
            lda #TileAnim_168
            ldx #^TileAnim_168
            ldy #15
            jsl StartScript
            lda #TileAnim_169
            ldx #^TileAnim_169
            ldy #15
            jsl StartScript
            rts
TileAnim_136
            dw $8006,137,0,0
            dw $8006,139,0,0
            dw $8006,141,0,0
            dw $cd06,143,0,0
TileAnim_137
            dw $8006,138,1,0
            dw $8006,140,1,0
            dw $8006,142,1,0
            dw $cd06,144,1,0
TileAnim_168
            dw $8006,169,2,0
            dw $8006,171,2,0
            dw $8006,173,2,0
            dw $cd06,175,2,0
TileAnim_169
            dw $8006,170,3,0
            dw $8006,172,3,0
            dw $8006,174,3,0
            dw $cd06,176,3,0