; _TBMaskedTile
;
; These tile renderes are for "normal" tiles that also apply their mask data.  If the case of the second
; background being disabled, the optimized variants are the same as Tile00000
;
; Y register  = address of code field tile
; X register  = tile address
; Accumulator = logical word offset of the tile (0, 2, 4, ..., 82)
;
; Need to slightly remap these register inputs to save into the direct page cached values
_TBMaskedTile_00
                 sta             _X_REG                            ; Save these values as we will need to reload them
                 sty             _Y_REG                            ; at certain points
                 stx             _T_PTR

; Do the left column first

                 CopyMaskedWord  tiledata+0;tiledata+32+0;$0003
                 CopyMaskedWord  tiledata+4;tiledata+32+4;$1003
                 CopyMaskedWord  tiledata+8;tiledata+32+8;$2003
                 CopyMaskedWord  tiledata+12;tiledata+32+12;$3003
                 CopyMaskedWord  tiledata+16;tiledata+32+16;$4003
                 CopyMaskedWord  tiledata+20;tiledata+32+20;$5003
                 CopyMaskedWord  tiledata+24;tiledata+32+24;$6003
                 CopyMaskedWord  tiledata+28;tiledata+32+28;$7003

; Move the index for the JTableOffset array.  This is the same index used for transparent words,
; so, if _X_REG is zero, then we would be patching out the last word in the code field with LDA (0),y
; and then increment _X_REG by two to patch the next-to-last word in the code field with LDA (2),y

                 inc             _X_REG
                 inc             _X_REG

; Do the right column

                 CopyMaskedWord  tiledata+2;tiledata+32+2;$0000
                 CopyMaskedWord  tiledata+6;tiledata+32+6;$1000
                 CopyMaskedWord  tiledata+10;tiledata+32+10;$2000
                 CopyMaskedWord  tiledata+14;tiledata+32+14;$3000
                 CopyMaskedWord  tiledata+18;tiledata+32+18;$4000
                 CopyMaskedWord  tiledata+22;tiledata+32+22;$5000
                 CopyMaskedWord  tiledata+26;tiledata+32+26;$6000
                 CopyMaskedWord  tiledata+30;tiledata+32+30;$7000

                 rts

_TBMaskedTile_0H
                 sta             _X_REG
                 sty             _Y_REG
                 stx             _T_PTR

                 CopyMaskedWord  tiledata+64+0;tiledata+64+32+0;$0003
                 CopyMaskedWord  tiledata+64+4;tiledata+64+32+4;$1003
                 CopyMaskedWord  tiledata+64+8;tiledata+64+32+8;$2003
                 CopyMaskedWord  tiledata+64+12;tiledata+64+32+12;$3003
                 CopyMaskedWord  tiledata+64+16;tiledata+64+32+16;$4003
                 CopyMaskedWord  tiledata+64+20;tiledata+64+32+20;$5003
                 CopyMaskedWord  tiledata+64+24;tiledata+64+32+24;$6003
                 CopyMaskedWord  tiledata+64+28;tiledata+64+32+28;$7003

                 inc             _X_REG
                 inc             _X_REG

                 CopyMaskedWord  tiledata+64+2;tiledata+64+32+2;$0000
                 CopyMaskedWord  tiledata+64+6;tiledata+64+32+6;$1000
                 CopyMaskedWord  tiledata+64+10;tiledata+64+32+10;$2000
                 CopyMaskedWord  tiledata+64+14;tiledata+64+32+14;$3000
                 CopyMaskedWord  tiledata+64+18;tiledata+64+32+18;$4000
                 CopyMaskedWord  tiledata+64+22;tiledata+64+32+22;$5000
                 CopyMaskedWord  tiledata+64+26;tiledata+64+32+26;$6000
                 CopyMaskedWord  tiledata+64+30;tiledata+64+32+30;$7000

                 rts

_TBMaskedTile_V0
                 sta             _X_REG
                 sty             _Y_REG
                 stx             _T_PTR

                 CopyMaskedWord  tiledata+0;tiledata+32+0;$7003
                 CopyMaskedWord  tiledata+4;tiledata+32+4;$6003
                 CopyMaskedWord  tiledata+8;tiledata+32+8;$5003
                 CopyMaskedWord  tiledata+12;tiledata+32+12;$4003
                 CopyMaskedWord  tiledata+16;tiledata+32+16;$3003
                 CopyMaskedWord  tiledata+20;tiledata+32+20;$2003
                 CopyMaskedWord  tiledata+24;tiledata+32+24;$1003
                 CopyMaskedWord  tiledata+28;tiledata+32+28;$0003

                 inc             _X_REG
                 inc             _X_REG

                 CopyMaskedWord  tiledata+2;tiledata+32+2;$7000
                 CopyMaskedWord  tiledata+6;tiledata+32+6;$6000
                 CopyMaskedWord  tiledata+10;tiledata+32+10;$5000
                 CopyMaskedWord  tiledata+14;tiledata+32+14;$4000
                 CopyMaskedWord  tiledata+18;tiledata+32+18;$3000
                 CopyMaskedWord  tiledata+22;tiledata+32+22;$2000
                 CopyMaskedWord  tiledata+26;tiledata+32+26;$1000
                 CopyMaskedWord  tiledata+30;tiledata+32+30;$0000

                 rts

_TBMaskedTile_VH
                 sta             _X_REG
                 sty             _Y_REG
                 stx             _T_PTR

                 CopyMaskedWord  tiledata+64+0;tiledata+64+32+0;$7003
                 CopyMaskedWord  tiledata+64+4;tiledata+64+32+4;$6003
                 CopyMaskedWord  tiledata+64+8;tiledata+64+32+8;$5003
                 CopyMaskedWord  tiledata+64+12;tiledata+64+32+12;$4003
                 CopyMaskedWord  tiledata+64+16;tiledata+64+32+16;$3003
                 CopyMaskedWord  tiledata+64+20;tiledata+64+32+20;$2003
                 CopyMaskedWord  tiledata+64+24;tiledata+64+32+24;$1003
                 CopyMaskedWord  tiledata+64+28;tiledata+64+32+28;$0003

                 inc             _X_REG
                 inc             _X_REG

                 CopyMaskedWord  tiledata+64+2;tiledata+64+32+2;$7000
                 CopyMaskedWord  tiledata+64+6;tiledata+64+32+6;$6000
                 CopyMaskedWord  tiledata+64+10;tiledata+64+32+10;$5000
                 CopyMaskedWord  tiledata+64+14;tiledata+64+32+14;$4000
                 CopyMaskedWord  tiledata+64+18;tiledata+64+32+18;$3000
                 CopyMaskedWord  tiledata+64+22;tiledata+64+32+22;$2000
                 CopyMaskedWord  tiledata+64+26;tiledata+64+32+26;$1000
                 CopyMaskedWord  tiledata+64+30;tiledata+64+32+30;$0000

                 rts
