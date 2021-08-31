; Animation helpers
;
; These provide animation sequencing and pathing support for animations.  Some function are
; sprite-specific, but the functions are generally applicable to any kind of animation support
; by the engine, such as swapping tiles or even just having an asynchronous method of updating
; game data.
;
; Depends on the Timers and Script sub-systems


; AnimatePath
;
; Moves a sprite between two keyframe point over a specificed number of steps
;
; X = YYXX       ; start position
; A = YYXX       ; end position
; Y = duration   ; number of steps from start to end (must be > 0)
AnimatePath

             pha                 ; Store the starting point
             and   #$00FF
             sta   AnimX0
             pla
             xba
             and   #$00FF
             sta   AnimY0

             txa                 ; Store the ending point
             and   #$00FF
             sta   AnimX1
             txa
             xba
             and   #$00FF
             sta   AnimY1

             sty   AnimDuration

; Calculate the steps for the X and Y positions. This is line drawing two lines
; at a time .  The slope of the lines are (X1 - X0) / Duration and (Y1 - Y0) / Duration.
;
; The tricky bit is that we *always* single-step in the "Y" direction (duration), so we
; actaully need to use two differenct algorithms.
;
; If |X1 - X0| <= Duration, use a standard line-drawing approach (Bresenham's, DDA, etc.)
; If |X1 - X0|  > Duration, use the Run-Length Slice algorithm (https://www.phatcode.net/res/224/files/html/ch36/36-02.html)

             lda   AnimY

:stepx       lda


             cmp   AnimDuration  ; Handle the two cases














