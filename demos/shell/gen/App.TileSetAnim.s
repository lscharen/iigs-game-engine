
TileAnimInit    ENT

            ldx #168
            ldy #0
            jsl CopyTileToDyn
            ldx #169
            ldy #1
            jsl CopyTileToDyn
            ldx #208
            ldy #2
            jsl CopyTileToDyn
            ldx #209
            ldy #3
            jsl CopyTileToDyn
            lda #TileAnim_168
            ldx #^TileAnim_168
            ldy #15
            jsl StartScript
            lda #TileAnim_169
            ldx #^TileAnim_169
            ldy #15
            jsl StartScript
            lda #TileAnim_208
            ldx #^TileAnim_208
            ldy #15
            jsl StartScript
            lda #TileAnim_209
            ldx #^TileAnim_209
            ldy #15
            jsl StartScript
            rts
TileAnim_168
            dw $8006,168,0,0
            dw $8006,170,0,0
            dw $8006,172,0,0
            dw $cd06,174,0,0
TileAnim_169
            dw $8006,169,1,0
            dw $8006,171,1,0
            dw $8006,173,1,0
            dw $cd06,175,1,0
TileAnim_208
            dw $8006,208,2,0
            dw $8006,210,2,0
            dw $8006,212,2,0
            dw $cd06,214,2,0
TileAnim_209
            dw $8006,209,3,0
            dw $8006,211,3,0
            dw $8006,213,3,0
            dw $cd06,215,3,0