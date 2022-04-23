
; Graphic screen initialization
InitGraphics
                 jsr   _ShadowOn
                 jsr   _GrafOn
                 lda   #0
                 jsr   _ClearToColor
                 lda   #0
                 jsr   _SetSCBs
                 ldx   #DefaultPalette
                 lda   #0
                 jsr   _SetPalette

                 jsr   _InitBG0             ; Initialize the background layers
                 jsr   _InitBG1

                 lda   #0
                 jsr   _ClearBG1Buffer

                 rts

DefaultPalette   dw    $0000,$007F,$0090,$0FF0
                 dw    $000F,$0080,$0f70,$0FFF
                 dw    $0fa9,$0ff0,$00e0,$04DF
                 dw    $0d00,$078f,$0ccc,$0FFF


; Allow the user to dynamically select one of the pre-configured screen sizes, or pass
; in a specific width and height.  The screen is automatically centered.  If this is
; not desired, then SetScreenRect should be used directly
;
;  0. Full Screen           : 40 x 25   320 x 200 (32,000 bytes (100.0%)) 
;  1. Sword of Sodan        : 34 x 24   272 x 192 (26,112 bytes ( 81.6%))
;  2. ~NES                  : 32 x 25   256 x 200 (25,600 bytes ( 80.0%))
;  3. Task Force            : 32 x 22   256 x 176 (22,528 bytes ( 70.4%))
;  4. Defender of the World : 35 x 20   280 x 160 (22,400 bytes ( 70.0%))
;  5. Rastan                : 32 x 20   256 x 160 (20,480 bytes ( 64.0%))
;  6. Game Boy Advanced     : 30 x 20   240 x 160 (19,200 bytes ( 60.0%))
;  7. Ancient Land of Y's   : 36 x 16   288 x 128 (18,432 bytes ( 57.6%))
;  8. Game Boy Color        : 20 x 18   160 x 144 (11,520 bytes ( 36.0%))
;  9. Agony (Amiga)         : 36 x 24   288 x 192 (27,648 bytes ( 86.4%))
; 10. Atari Lynx            : 20 x 13   160 x 102 (8,160 bytes  ( 25.5%))
;
;  X = mode number OR width in pixels (must be multiple of 2)
;  Y = height in pixels (if X > 8)

ScreenModeWidth   dw        320,272,256,256,280,256,240,288,160,288,160,320
ScreenModeHeight  dw        200,192,200,176,160,160,160,128,144,192,102,1

SetScreenMode     ENT
                  phb
                  phk
                  plb
                  jsr       _SetScreenMode
                  plb
                  rtl

_SetScreenMode
                  cpx       #11
                  bcs       :direct             ; if x > 10, then assume X and Y are the dimensions

                  txa
                  asl
                  tax

                  ldy       ScreenModeHeight,x
                  lda       ScreenModeWidth,x
                  tax

:direct           cpy       #201
                  bcs       :exit

                  cpx       #321
                  bcs       :exit

                  txa
                  lsr
                  pha                           ; Save X (width / 2) and Y (height)
                  phy

                  lda       #160                ; Center the screen
                  sec
                  sbc       3,s
                  lsr
                  xba
                  pha                           ; Save half the origin coordinate

                  lda       #200
                  sec
                  sbc       3,s                 ; This is now Y because of the PHA above
                  lsr
                  ora       1,s

                  plx                           ; Throw-away to pop the stack
                  ply
                  plx

                  jsr       SetScreenRect
                  jmp       FillScreen          ; tail return
:exit
                  rts

; Return the current border color ($0 - $F) in the accumulator
_GetBorderColor  lda   #0000
                 sep   #$20
                 ldal  BORDER_REG
                 and   #$0F
                 rep   #$20
                 rts

; Set the border color to the accumulator value.
SetBorderColor   ENT
                 jsr   _SetBorderColor
                 rtl

_SetBorderColor  sep   #$20                 ; ACC = $X_Y, REG = $W_Z
                 eorl  BORDER_REG           ; ACC = $(X^Y)_(Y^Z)
                 and   #$0F                 ; ACC = $0_(Y^Z)
                 eorl  BORDER_REG           ; ACC = $W_(Y^Z^Z) = $W_Y
                 stal  BORDER_REG
                 rep   #$20
                 rts

; Clear to SHR screen to a specific color
_ClearToColor
                 ldx   #$7D00               ;start at top of pixel data! ($2000-9D00)
:clearloop       dex
                 dex
                 stal  SHR_SCREEN,x         ;screen location
                 bne   :clearloop           ;loop until we've worked our way down to 0
                 rts

; Set a palette values
; A = high word of palette data pointer, X = low word of palette data pointer, Y = palette number
SetPalette       ENT
                 phb                        ; save old data bank
                 pha                        ; push 16-bit value
                 plb                        ; pop 8-bit bank register
                 tya
                 jsr   _SetPalette
                 plb                        ; pop the other half of the 16-bit push off
                 plb                        ; restore the original data bank
                 rtl

; A = palette number, X = palette address
_SetPalette
                 and   #$000F               ; palette values are 0 - 15 and each palette is 32 bytes
                 asl
                 asl
                 asl
                 asl
                 asl
                 txy
                 tax

]idx             equ   0
                 lup   16
                 lda:  $0000+]idx,y
                 stal  SHR_PALETTES+]idx,x
]idx             equ   ]idx+2
                 --^
                 rts

; Initialize the SCB
_SetSCBs
                 ldx   #$0100               ;set all $100 scbs to A
:scbloop         dex
                 dex
                 stal  SHR_SCB,x
                 bne   :scbloop
                 rts

; Turn SHR screen On/Off
_GrafOn
                 sep   #$20
                 lda   #$81
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

_GrafOff
                 sep   #$20
                 lda   #$01
                 stal  NEW_VIDEO_REG
                 rep   #$20
                 rts

; Enable/Disable Shadowing.
_ShadowOn
                 sep   #$20
                 ldal  SHADOW_REG
                 and   #$F7
                 stal  SHADOW_REG
                 rep   #$20
                 rts

_ShadowOff
                 sep   #$20
                 ldal  SHADOW_REG
                 ora   #$08
                 stal  SHADOW_REG
                 rep   #$20
                 rts

GetVerticalCounter ENT
                 jsr   _GetVBL
                 rtl
_GetVBL
                 sep   #$20
                 ldal  VBL_HORZ_REG
                 asl
                 ldal  VBL_VERT_REG
                 rol                        ; put V5 into carry bit, if needed. See TN #39 for details.
                 rep   #$20
                 and   #$00FF
                 rts

_WaitForVBL
                 sep   #$20
:wait1           ldal  VBL_STATE_REG        ; If we are already in VBL, then wait
                 bmi   :wait1
:wait2           ldal  VBL_STATE_REG
                 bpl   :wait2               ; spin until transition into VBL
                 rep   #$20
                 rts







