; Init

sound_control           =   $3c                     ;really at $e1c03c
sound_data              =   $3d                     ;really at $e1c03d
sound_address           =   $3e                     ;really at $e1c03e

sound_interrupt_ptr     =   $e1002c
irq_volume              =   $e100ca
osc_interrupt           =   $e100cc


                        mx %10

access_doc_registers    = *
                        ldal irq_volume
                        sta sound_control
                        rts

access_doc_ram          = *
                        ldal irq_volume
                        ora #%0110_0000
                        sta sound_control
                        rts

access_doc_ram_no_inc   = *
                        ldal irq_volume
                        ora #%0100_0000
                        sta sound_control
                        rts

                        mx  %00

APUStartUp
                        sei
                        phd
                        pea $c000
                        pld
                        jsr copy_instruments_to_doc
                        jsr setup_doc_registers
                        jsr setup_interrupt
                        pld
                        cli
                        rts

APUShutDown             = *
                        sei
                        phd

                        lda   #$c000
                        tcd

                        jsr   stop_playing

                        lda   backup_interrupt_ptr      ; restore old interrupt ptr
                        stal  sound_interrupt_ptr
                        lda   backup_interrupt_ptr+2
                        stal  sound_interrupt_ptr+2

                        cli
                        pld
                        clc
                        rts

stop_playing            = *

                        ldy   #7                        ; Number of oscillators

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        lda   #$a0                      ; stop all oscillators in use
                        sta   sound_address
                        lda   #%11
]loop                   sta   sound_data
                        inc   sound_address
                        dey
                        bne   ]loop

                        lda   #$a0+interrupt_oscillator ; stop interrupt oscillator
                        sta   sound_address
                        lda   #3
                        sta   sound_data

                        rep   #$20
                        mx    %00
                        rts

; Copy in 4 different square wave duty cycles and a triangle wave
copy_instruments_to_doc
                        jsr setup_docram

                        lda #$0100
                        jsr make_eigth_pulse

                        lda #$0200
                        jsr make_quarter_pulse

                        lda #$0300
                        jsr make_half_pulse

                        lda #$0400
                        jsr make_inv_quarter_pulse

                        lda #$0500
                        jsr copy_triangle
                        rts

;--------------------------

setup_docram
                        sep #$20
                        mx  %10

                        jsr access_doc_ram

                        stz sound_address

                        lda #$80
                        ldx #256                    ;make sure that page 00 has nonzero data for interrupt
:loop                   sta sound_data
                        dex
                        bne :loop

                        rep #$20
                        mx  %00
                        rts

;--------------------------
make_eigth_pulse
                        ldy #32
                        jmp make_pulse

make_quarter_pulse
                        ldy #64
                        jmp make_pulse

make_half_pulse
                        ldy #128
                        jmp make_pulse

make_inv_quarter_pulse
                        ldy #192
                        jmp make_pulse

make_pulse
                        sep #$30
                        mx  %11

                        stz sound_address
                        xba
                        sta sound_address+1

                        ldx #0

:loop1
                        lda #$01
                        sta sound_data
                        inx
                        dey
                        bne :loop1

:loop2
                        lda #$FF
                        sta sound_data
                        inx
                        bne :loop2

                        rep #$30
                        mx  %00
                        rts

copy_triangle
                        sep #$30
                        mx  %11

                        stz sound_address
                        xba
                        sta sound_address+1

                        ldx #0
:loop
                        lda triangle_wave,x
                        sta sound_data
                        inx
                        bne :loop

                        rep #$30
                        mx  %00
                        rts

;--------------------------

triangle_wave
    hex 80828486888a8c8e90929496989a9c9e
    hex a0a2a4a6a8aaacaeb0b2b4b6b8babcbe
    hex c0c1c3c5c7c9cbcdcfd1d3d5d7d9dbdd
    hex dfe1e3e5e7e9ebedeff1f3f5f7f9fbfd
    hex fffdfbf9f7f5f3f1efedebe9e7e5e3e1
    hex dfdddbd9d7d5d3d1cfcdcbc9c7c5c3c1
    hex c0bebcbab8b6b4b2b0aeacaaa8a6a4a2
    hex a09e9c9a98969492908e8c8a88868482
    hex 807e7c7a78767472706e6c6a68666462
    hex 605e5c5a58565452504e4c4a48464442
    hex 413f3d3b39373533312f2d2b29272523
    hex 211f1d1b19171513110f0d0b09070503
    hex 01030507090b0d0f11131517191b1d1f
    hex 21232527292b2d2f31333537393b3d3f
    hex 41424446484a4c4e50525456585a5c5e
    hex 60626466686a6c6e70727476787a7c7e

;--------------------------

setup_doc_registers
                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        ldx   #pulse1_sound_settings
                        jsr   copy_register_config

                        ldx   #pulse2_sound_settings
                        jsr   copy_register_config

                        ldx   #triangle_sound_settings
                        jsr   copy_register_config

                        rep #$20
                        mx  %00

                        rts
copy_register_config
                        ldy   #0
:loop                   lda:  0,x                                  ; Set DOC registers for the NES channels
                        sta   sound_address
                        inx
                        lda:  0,x
                        sta   sound_data
                        inx
                        iny
                        cpy   #6                                   ; 6 pairs to describe this oscillator
                        bne   :loop
                        rts

;--------------------------

setup_interrupt         = *
                        ldal  sound_interrupt_ptr
                        sta   backup_interrupt_ptr
                        ldal  sound_interrupt_ptr+2
                        sta   backup_interrupt_ptr+2

                        lda   #$5c
                        stal  sound_interrupt_ptr
                        phk
                        phk
                        pla
                        stal  sound_interrupt_ptr+2
                        lda   #interrupt_handler
                        stal  sound_interrupt_ptr+1

                        sep   #$20
                        mx    %10

                        jsr   access_doc_registers

                        ldy   #0
:loop                   lda   timer_sound_settings,y               ; Set DOC registers for the interrupt oscillator
                        sta   sound_address
                        iny
                        lda   timer_sound_settings,y
                        sta   sound_data
                        iny
                        cpy   #7*2
                        bne   :loop

                        rep #$20
                        mx  %00

                        rts

interrupt_oscillator    =     31
reference_freq          =     1195                  ; interrupt frequence (240Hz)
timer_sound_settings    =     *                     ; set up oscillator 30 for interrupts
                        dfb   $00+interrupt_oscillator,reference_freq     ; frequency low register
                        dfb   $20+interrupt_oscillator,reference_freq/256 ; frequency high register
                        dfb   $40+interrupt_oscillator,0                  ; volume register, volume = 0
                        dfb   $80+interrupt_oscillator,0                  ; wavetable pointer register, point to 0
                        dfb   $c0+interrupt_oscillator,0                  ; wavetable size register, 256 byte length
                        dfb   $e1,$3e                                     ; oscillator enable register
                        dfb   $a0+interrupt_oscillator,$08                ; mode register, set to free run

pulse1_oscillator       =     0
pulse2_oscillator       =     2
triangle_oscillator     =     4
default_freq            =     5000
pulse1_sound_settings   =     *
                        dfb   $00+pulse1_oscillator,default_freq      ; frequency low register
                        dfb   $20+pulse1_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+pulse1_oscillator,0                 ; volume register, volume = 0
                        dfb   $80+pulse1_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c0+pulse1_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+pulse1_oscillator,0                 ; mode register, set to free run

pulse2_sound_settings   =     *
                        dfb   $00+pulse2_oscillator,default_freq      ; frequency low register
                        dfb   $20+pulse2_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+pulse2_oscillator,0                 ; volume register, volume = 0
                        dfb   $80+pulse2_oscillator,3                 ; wavetable pointer register, point to $0300 by default (50% duty cycle)
                        dfb   $c0+pulse2_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+pulse2_oscillator,0                 ; mode register, set to free run

triangle_sound_settings =     *
                        dfb   $00+triangle_oscillator,default_freq      ; frequency low register
                        dfb   $20+triangle_oscillator,default_freq/256  ; frequency high register
                        dfb   $40+triangle_oscillator,128               ; volume register, volume = 0
                        dfb   $80+triangle_oscillator,5                 ; wavetable pointer register, point to $0500
                        dfb   $c0+triangle_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+triangle_oscillator,0                 ; mode register, set to free run

backup_interrupt_ptr    ds  4

;-----------------------------------------------------------------------------------------
; interupt handler
;-----------------------------------------------------------------------------------------

interrupt_handler       = *

                        phb
                        phd

                        phk
                        plb

                        clc
                        xce
                        rep #$30
                        mx  %00

                        lda #$c000
                        tcd

                        sep #$30
                        mx  %11

                        jsr   access_doc_registers

                        ldal  osc_interrupt             ; which oscillator generated the interrupt?
                        and   #%00111110
                        lsr
                        cmp   #interrupt_oscillator
                        beq   *+5
                        brl   :not_timer                ; Only service timer interrupts

; Set the parameters for the first square wave channel

                        lda   #$80+pulse1_oscillator
                        sta   sound_address
                        lda   APU_PULSE1_REG1           ; Get the cycle duty bits
                        jsr   set_pulse_duty_cycle

                        lda   #$40+pulse1_oscillator
                        sta   sound_address
                        lda   APU_PULSE1_REG1
                        jsr   set_pulse_volume

                        rep   #$30
                        lda   APU_PULSE1_REG3
                        jsr   get_pulse_freq                  ; return freq in 16-bic accumulator
                        sep   #$30

                        ldx   #$00+pulse1_oscillator
                        stx   sound_address
                        sta   sound_data
                        ldx   #$20+pulse1_oscillator
                        stx   sound_address
                        xba
                        sta   sound_data

; Now do the second square wave

                        lda   #$80+pulse2_oscillator
                        sta   sound_address
                        lda   APU_PULSE2_REG1           ; Get the cycle duty bits
                        jsr   set_pulse_duty_cycle

                        lda   #$40+pulse2_oscillator
                        sta   sound_address
                        lda   APU_PULSE2_REG1
                        jsr   set_pulse_volume

                        rep   #$30
                        lda   APU_PULSE2_REG3
                        jsr   get_pulse_freq                  ; return freq in 16-bic accumulator
                        sep   #$30

                        ldx   #$00+pulse2_oscillator
                        stx   sound_address
                        sta   sound_data
                        ldx   #$20+pulse2_oscillator
                        stx   sound_address
                        xba
                        sta   sound_data

; Now the triangle wave.  This wave needs linear counter support to be silenced

                        rep   #$30
                        lda   APU_TRIANGLE_REG3
                        jsr   get_pulse_freq                  ; return freq in 16-bic accumulator
                        lsr
                        sep   #$30

                        ldx   #$00+triangle_oscillator
                        stx   sound_address
                        sta   sound_data
                        ldx   #$20+triangle_oscillator
                        stx   sound_address
                        xba
                        sta   sound_data

;                        lda   border_color
;                        inc
;                        and   #$03
;                        sta   border_color
;                        jsr   setborder

:not_timer
                        sep   #$30
                        pld
                        plb
                        clc
                        rtl

set_pulse_duty_cycle
                        mx    %11
                        rol
                        rol
                        rol
                        and   #$03
                        tax

                        lda   duty_cycle_page,x
                        sta   sound_data
                        rts

set_pulse_volume
                        and   #$0F
                        asl
                        asl
                        asl
                        asl
                        sta   sound_data
                        rts

; NES freq = f_CPU / (16 * (t + 1))
;          = 1.789773 MHz / (16 * (t + 1))
;          = 111860.812 Hz / (t + 1)
;
; IIgs freq = 0.200807 * F_HL (for 32 oscillators with DOC RES = 0)
;
; Solving for F_HL = (1 / 0.200807) * 111860.812 / (t + 1)
;                  = 557056.338 / (t + 1)
;
; if t < 8 this value is out of range and the scillator should be silenced
;
; otherwise, break apart the ratio
;
; f_HL = 10 * (55706 / (t + 1))
; 
get_pulse_freq
                        mx %00
                        and   #$07FF                    ; Load the timer value (11-bits); freq = 1.79MHz / (16 * (t - 1)) = 111860Hz / (t-1)
                        cmp   #8
                        bcc   :no_sound
                        inc
                        sta   divisor
                        lda   #55706
                        sta   dividend

                        lda   #0
                        ldx   #16                       ; 16 bits of division
                        asl   dividend
:dl1                    rol
                        cmp   divisor
                        bcc   :dl2
                        sbc   divisor
:dl2                    rol   dividend
                        dex
                        bne   :dl1

                        lda   dividend
                        sta   dividend
                        asl
                        asl
                        clc
                        adc   dividend                  ; multiple by 10 to get the approx DOC value (0.2Hz per + post-multiple)
                        asl

;                        sta   dividend
                        rts
:no_sound
                        lda   #0
                        rts

turn_off_interrupts
                        php
                        sep   #$20
                        lda   #$a0+interrupt_oscillator
                        sta   sound_address
                        lda   #0
                        sta   sound_data
                        plp
                        rts

duty_cycle_page dfb $01,$02,$03,$04     ; Page of DOC RAM that holds the different duty cycle wavforms
border_color    dw 0
dividend        dw 0
divisor         dw 0

last_phase1_duty_cycle dfb $ff
last_phase2_duty_cycle dfb $ff
; 8-bit mode
; A = register number
; X = register value
    mx  %00
SetDOCReg
    stal $E0C03E
    txa
    stal $E0C03D
    rts

_SetDOCReg mac
    lda  ]1       ; Select the oscillator enable registers
    ldx  ]2
    jsr  SetDOCReg
    <<<

; Pulse Channel 1
APU_PULSE1
APU_PULSE1_REG1 ds 1    ; DDLC NNNN - Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_PULSE1_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE1_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE1_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_PULSE2
APU_PULSE2_REG1 ds 1    ; DDLC NNNN - Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_PULSE2_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE2_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE2_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_TRIANGLE
APU_TRIANGLE_REG1 ds 1    ; DDLC NNNN - Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_TRIANGLE_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_TRIANGLE_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_TRIANGLE_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_STATUS      ds 1

    mx %11
APU_PULSE1_REG1_WRITE ENT
    stal  APU_PULSE1_REG1
    rtl

APU_PULSE1_REG2_WRITE ENT
    stal  APU_PULSE1_REG2
    rtl

APU_PULSE1_REG3_WRITE ENT
    stal  APU_PULSE1_REG3
    rtl

APU_PULSE1_REG4_WRITE ENT
    stal  APU_PULSE1_REG4
    rtl


APU_PULSE2_REG1_WRITE ENT
    stal  APU_PULSE2_REG1
    rtl

APU_PULSE2_REG2_WRITE ENT
    stal  APU_PULSE2_REG2
    rtl

APU_PULSE2_REG3_WRITE ENT
    stal  APU_PULSE2_REG3
    rtl

APU_PULSE2_REG4_WRITE ENT
    stal  APU_PULSE2_REG4
    rtl


APU_TRIANGLE_REG1_WRITE ENT
    stal  APU_TRIANGLE_REG1
    rtl

APU_TRIANGLE_REG2_WRITE ENT
    stal  APU_TRIANGLE_REG2
    rtl

APU_TRIANGLE_REG3_WRITE ENT
    stal  APU_TRIANGLE_REG3
    rtl

APU_TRIANGLE_REG4_WRITE ENT
    stal  APU_TRIANGLE_REG4
    rtl


APU_STATUS_WRITE ENT
    stal  APU_STATUS
    pha

; Pulse 1 is OSC 0
    bit  #$01
    beq  :pulse1_off
;    _SetDOCReg #$40+pulse1_oscillator;#128
    bra  :pulse1_end
:pulse1_off
;    _SetDOCReg #$40+pulse1_oscillator;#0
:pulse1_end

; Pulse 2 is OSC 2
    bit  #$02
    beq  :pulse2_off
;    _SetDOCReg #$40+pulse2_oscillator;#128
    bra  :pulse2_end
:pulse2_off
;    _SetDOCReg #$40+pulse2_oscillator;#0
:pulse2_end

; Triangle is OSC 4
;    bit  #$03
;    beq  :triangle_off
;    _SetDOCReg #$40+triangle_oscillator;#128
;    bra  :triangle_end
;:triangle_off
;    _SetDOCReg #$40+triangle_oscillator;#0
;:triangle_end

    pla
    rtl
