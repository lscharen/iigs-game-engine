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
                        dfb   $40+triangle_oscillator,0               ; volume register, volume = 0
                        dfb   $80+triangle_oscillator,5                 ; wavetable pointer register, point to $0500
                        dfb   $c0+triangle_oscillator,0                 ; wavetable size register, 256 byte length
                        dfb   $a0+triangle_oscillator,0                 ; mode register, set to free run

backup_interrupt_ptr    ds  4

;-----------------------------------------------------------------------------------------
; APU internals
;-----------------------------------------------------------------------------------------
                        mx  %11
clock_length_counter    mac
                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}
                        bit   ]2
                        bne   no_count
                        lda   ]1+{APU_PULSE1_LENGTH_COUNTER-APU_PULSE1}
                        beq   no_count
                        dec
                        sta   ]1+{APU_PULSE1_LENGTH_COUNTER-APU_PULSE1}
no_count                <<<

clock_linear_counter    mac
                        lda   ]1+{APU_TRIANGLE_START_FLAG-APU_TRIANGLE}
                        beq   do_clock
                        lda   ]1+{APU_TRIANGLE_REG1-APU_TRIANGLE}
                        and   #$7F
                        sta   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}
                        bra   check_reset

do_clock                lda   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}
                        beq   check_reset
                        dec
                        sta   ]1+{APU_TRIANGLE_LINEAR_COUNTER-APU_TRIANGLE}

check_reset
                        lda   ]1+{APU_TRIANGLE_REG1-APU_TRIANGLE}
                        bmi   no_reset
                        stz   ]1+{APU_TRIANGLE_START_FLAG-APU_TRIANGLE}
no_reset                <<<

clock_sweep             mac
                        lda   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
                        dec
                        sta   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
                        bpl   no_sweep

                        lda   #1
                        sta   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1}

                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1} ; get the barrel shift argument from the register
                        bpl   no_sweep                 ; if sweep is not enabled, do nothing
                        and   #$07
                        beq   no_sweep                 ; shift must be != 0
                        asl
                        tax

                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1}  ; put the negate flag in the y register
                        and   #$08
                        tay

                        rep   #$20
                        lda   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
                        cmp   #8
                        bcc   no_sweep0                 ; current period must be >= 8

                        lda   ]1+{APU_PULSE1_REG3-APU_PULSE1}  ; raw period stored in the register
                        and   #$7FF
                        jmp   (bitshift,x)                     ; shift it by the shifter amount
bitshift                da    bitshift_0,bitshift_1,bitshift_2,bitshift_3,bitshift_4,bitshift_5,bitshift_6,bitshift_7
bitshift_7              lsr
bitshift_6              lsr
bitshift_5              lsr
bitshift_4              lsr
bitshift_3              lsr
bitshift_2              lsr
bitshift_1              lsr
bitshift_0
                        cpy   #0                            ; check if the negate flag was set
                        beq   no_negate
                        eor   #$FFFF                        ; pulse 1 uses 1's complement
                        DO    ]2
                        inc
                        FIN
no_negate               clc
                        adc   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
                        sta   ]1+{APU_PULSE1_TARGET_PERIOD-APU_PULSE1}

                        stz   ]1+{APU_PULSE1_MUTE-APU_PULSE1}
                        ldy   #1
                        cmp   #$800
                        bcc   *+5
                        sty   ]1+{APU_PULSE1_MUTE-APU_PULSE1}  ; mute the output is the period is too large
                        bcs   *+5
                        sta   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1} ; set the current period if the target is within a valid range

                        lda   ]1+{APU_PULSE1_CURRENT_PERIOD-APU_PULSE1}
                        cmp   #8
                        bcs   *+5
                        sty   ]1+{APU_PULSE1_MUTE-APU_PULSE1}  ; mute the output if the period is too small

no_sweep0
                        sep   #$20
no_sweep
                        lda   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1} ; check if we need to reload the sweep delay
                        beq   no_reload
                        stz   ]1+{APU_PULSE1_RELOAD_FLAG-APU_PULSE1}
                        lda   ]1+{APU_PULSE1_REG2-APU_PULSE1}
                        lsr
                        lsr
                        lsr
                        lsr
                        and   #7
                        sta   ]1+{APU_PULSE1_SWEEP_DIVIDER-APU_PULSE1}
no_reload               <<<

clock_envelope          mac
                        lda   ]1+{APU_PULSE1_START_FLAG-APU_PULSE1}
                        beq   no_start
                        stz   ]1+{APU_PULSE1_START_FLAG-APU_PULSE1} ; clear the start flag
                        lda   #15
                        sta   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1} ; reset the envelope saw wave decay value
                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}
                        and   #$0F
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1} ; reset the divider value
                        bra   envelope_out        ; nothing else to do

no_start
                        lda   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1} ; clock the divider
                        dec
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1}
                        bpl   envelope_out        ; as long as divider is >=0, nothing to do

                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1}         ; reset the divider to the volume/envelope value
                        and   #$0F
                        sta   ]1+{APU_PULSE1_ENVELOPE_DIVIDER-APU_PULSE1}

                        lda   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1}
                        bne   tick_envelope

                        lda   ]1+{APU_PULSE1_REG1-APU_PULSE1} ; if decay level counter is 0, check the loop bit and set counter to 15 if loop bit is set
                        bit   #PULSE_HALT_FLAG
                        beq   envelope_out
                        lda   #16                         ; Set to 15
tick_envelope
                        dec
                        sta   ]1+{APU_PULSE1_ENVELOPE-APU_PULSE1}
envelope_out            <<<

;-----------------------------------------------------------------------------------------
; interupt handler
;-----------------------------------------------------------------------------------------

apu_frame_steps      equ 5
PULSE_HALT_FLAG      equ $20
PULSE_CONST_VOL_FLAG equ $10
TRIANGLE_HALT_FLAG   equ $80

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

; Update the frame counter.  We double-count so that frame counter can be used directly to dispatch to the
; appropriate tick handler

                        ldx   apu_frame_counter
                        inx
                        inx
                        cpx   #2*apu_frame_steps          ; TODO: This is set by MSB in $4017 (4 or 5).  4 = PAL, 5 = NTSC.
                        bcc   *+4
                        ldx   #0
                        stx   apu_frame_counter
                        jmp   (:frame_counter_proc,x)
:frame_counter_proc     da    :quarter_frame,:half_frame,:quarter_frame,:no_frame,:half_frame
:half_frame

; clock the length counters
                        clock_length_counter APU_PULSE1;#PULSE_HALT_FLAG
                        clock_length_counter APU_PULSE2;#PULSE_HALT_FLAG
                        clock_length_counter APU_TRIANGLE;#TRIANGLE_HALT_FLAG

; clock the sweep units
                        clock_sweep  APU_PULSE1;0
                        clock_sweep  APU_PULSE2;1

; quarter frame updates run every APU frame (for 4-cycle)
:quarter_frame

; clock the envelopes and triangle linear counter
                        clock_linear_counter APU_TRIANGLE

                        clock_envelope APU_PULSE1
                        clock_envelope APU_PULSE2

:no_frame
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
                        lda   APU_PULSE1_REG1                ; Get the cycle duty bits
                        jsr   set_pulse_duty_cycle

                        lda   #$40+pulse1_oscillator
                        sta   sound_address

                        lda   APU_PULSE1_MUTE                ; If the sweep muted the channel, no output
                        beq   :no_mute_pulse1
                        lda   #0
                        bra   :set_volume_pulse1
:no_mute_pulse1
                        lda   APU_PULSE1_LENGTH_COUNTER      ; If the length counter is zero, no output
                        beq   :set_volume_pulse1
                        lda   APU_PULSE1_REG1
                        bit   #PULSE_CONST_VOL_FLAG           ; Check the constant volume bit
                        bne   :set_volume_pulse1
                        lda   APU_PULSE1_ENVELOPE
:set_volume_pulse1
                        jsr   set_pulse_volume

                        rep   #$30
                        lda   APU_PULSE1_CURRENT_PERIOD
                        jsr   get_pulse_freq                  ; return freq in 16-bit accumulator
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

                        lda   APU_PULSE2_MUTE           ; If the sweep muted the channel, no output
                        beq   :no_mute_pulse2
                        lda   #0
                        bra   :set_volume_pulse2
:no_mute_pulse2
                        lda   APU_PULSE2_LENGTH_COUNTER ; If the length counter is zero, no output
                        beq   :set_volume_pulse2
                        lda   APU_PULSE2_REG1
                        bit   #PULSE_CONST_VOL_FLAG      ; Check the constant volume bit
                        bne   :set_volume_pulse2
                        lda   APU_PULSE2_ENVELOPE
:set_volume_pulse2
                        jsr   set_pulse_volume

                        rep   #$30
                        lda   APU_PULSE2_CURRENT_PERIOD
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
;                        brl   :not_timer

                        lda   #$40+triangle_oscillator
                        sta   sound_address
                        lda   APU_TRIANGLE_LENGTH_COUNTER     ; If the length counter is zero, no output
                        beq   :set_volume_triangle
                        lda   APU_TRIANGLE_LENGTH_COUNTER
                        beq   :set_volume_triangle
                        lda   #12                             ; Triangle is a bit softer than pulse channels
:set_volume_triangle
                        jsr   set_pulse_volume

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
; if t < 8 this value is out of range and the oscillator should be silenced
;
; otherwise, break apart the ratio
;
; f_HL = 10 * (55706 / (t + 1))
; 
get_pulse_freq
                        mx %00
                        and   #$7FF                     ; prevent overflow...
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
                        adc   dividend                  ; multiple by 10 to get the DOC value
                        asl
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

; Internal APU registers.
;
; These variables track the internal flags, counters and other status bits that make up 
; the core functionality of the different channel hardware

apu_frame_counter dw 0                  ; frame counter, clocked at 240Hz from the interrupt handler

; Internal APU register offsets
;length_counter_halt  equ 0
;length_counter       equ 1
;constant_volume_flag equ 2
;volume               equ 3
;current_period       equ 4
;target_period        equ 6

; Internal APU registers for channel 1
;apu_pulse1 ds 8
;apu_pulse2 ds 8

;apu_pulse1_length_counter dfb 0
;apu_pulse1_decay_level dfb 0
;apu_pulse1_current_period dw 0

;apu_pulse2_length_counter dfb 0
;apu_pulse2_decay_level dfb 0
;apu_pulse2_current_period dw 0

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
APU_PULSE1_REG1 ds 1    ; DDLC NNNN - Duty, length counter halt, constant volume/evelope, envelope period/volume
APU_PULSE1_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE1_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE1_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_PULSE1_LENGTH_COUNTER   dfb 0 ; internal register for the length counter
APU_PULSE1_RELOAD_FLAG      dfb 0 ; internal register to reload the sweep divider value
APU_PULSE1_SWEEP_DIVIDER    dfb 0 ; internal register to track the sweep divider value
APU_PULSE1_TARGET_PERIOD    dw  0 ; internal register to hold the sweep unit target period
APU_PULSE1_CURRENT_PERIOD   dw  0 ; internal register to hold the current period driving the oscillator
APU_PULSE1_MUTE             dfb 0
APU_PULSE1_START_FLAG       dfb 0 
APU_PULSE1_ENVELOPE_DIVIDER dfb 0
APU_PULSE1_ENVELOPE         dfb 0

_apu_pulse1_last_period     dw  0 ; optimization


APU_PULSE2
APU_PULSE2_REG1 ds 1    ; DDLC NNNN - Duty, length counter halt, constant volume/evelope, envelope period/volume
APU_PULSE2_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_PULSE2_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_PULSE2_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_PULSE2_LENGTH_COUNTER dfb 0 ; internal register for the length counter
APU_PULSE2_RELOAD_FLAG    dfb 0 ; internal register to reload the sweep divider value
APU_PULSE2_SWEEP_DIVIDER  dfb 0 ; internal register to track the sweep divider value
APU_PULSE2_TARGET_PERIOD  dw  0 ; internal register to hold the sweep unit target period
APU_PULSE2_CURRENT_PERIOD dw  0 ; internal register to hold the current period driving the oscillator
APU_PULSE2_MUTE             dfb 0
APU_PULSE2_START_FLAG       dfb 0 
APU_PULSE2_ENVELOPE_DIVIDER dfb 0
APU_PULSE2_ENVELOPE         dfb 0

_apu_pulse2_last_period   dw  0 ; optimization


APU_TRIANGLE
APU_TRIANGLE_REG1 ds 1    ; DDLC NNNN - Duty, loop envelope/disable length counter, constant volume, envelope period/volume
APU_TRIANGLE_REG2 ds 1    ; EPPP NSSS - Sweep unit: enabled, period, negative, shift count
APU_TRIANGLE_REG3 ds 1    ; LLLL LLLL - Timer Low
APU_TRIANGLE_REG4 ds 1    ; llll lHHH - Length counter load, timer high (also resets duty and starts envelope)

APU_TRIANGLE_LENGTH_COUNTER dfb 0
APU_TRIANGLE_CURRENT_PERIOD dw 0
APU_TRIANGLE_START_FLAG dfb 0
APU_TRIANGLE_LINEAR_COUNTER dfb 0

APU_STATUS      ds 1

    mx %11
APU_PULSE1_REG1_WRITE ENT
    stal  APU_PULSE1_REG1
    rtl

APU_PULSE1_REG2_WRITE ENT
    php
    pha
    stal  APU_PULSE1_REG2
    lda   #1
    stal  APU_PULSE1_RELOAD_FLAG      ; mark that this register was written to
    pla
    plp
    rtl

APU_PULSE1_REG3_WRITE ENT
    stal  APU_PULSE1_CURRENT_PERIOD
    stal  APU_PULSE1_REG3
    rtl

APU_PULSE1_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_PULSE1_REG4
    and   #$07
    stal  APU_PULSE1_CURRENT_PERIOD+1

; If the APU_STATUS bit is enabled, then load the length counter
    ldal  APU_STATUS
    bit   #$01
    beq   :no_reload

    ldal  APU_PULSE1_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_PULSE1_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_PULSE1_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl

; From https://www.nesdev.org/wiki/APU_Length_Counter
LengthTable
    db    10,254, 20,  2, 40,  4, 80,  6, 160,  8, 60, 10, 14, 12, 26, 14
    db    12, 16, 24, 18, 48, 20, 96, 22, 192, 24, 72, 26, 16, 28, 32, 30

APU_PULSE2_REG1_WRITE ENT
    stal  APU_PULSE2_REG1
    rtl

APU_PULSE2_REG2_WRITE ENT
    php
    pha
    stal  APU_PULSE2_REG2
    lda   #1
    stal  APU_PULSE2_RELOAD_FLAG
    pla
    plp
    rtl

APU_PULSE2_REG3_WRITE ENT
    stal  APU_PULSE2_CURRENT_PERIOD
    stal  APU_PULSE2_REG3
    rtl

APU_PULSE2_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_PULSE2_REG4
    and   #$07
    stal  APU_PULSE2_CURRENT_PERIOD+1

    ldal  APU_STATUS
    bit   #$01
    beq   :no_reload

    ldal  APU_PULSE2_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_PULSE2_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_PULSE2_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl


APU_TRIANGLE_REG1_WRITE ENT
    stal  APU_TRIANGLE_REG1
    rtl

APU_TRIANGLE_REG2_WRITE ENT
    stal  APU_TRIANGLE_REG2
    rtl

APU_TRIANGLE_REG3_WRITE ENT
    stal  APU_TRIANGLE_CURRENT_PERIOD
    stal  APU_TRIANGLE_REG3
    rtl

APU_TRIANGLE_REG4_WRITE ENT
    php
    phx
    pha

    stal  APU_TRIANGLE_REG4
    and   #$07
    stal  APU_TRIANGLE_CURRENT_PERIOD+1

    ldal  APU_STATUS
    bit   #$04
    beq   :no_reload

    ldal  APU_TRIANGLE_REG4
    and   #$F8
    lsr
    lsr
    lsr
    tax
    ldal  LengthTable,x
    stal  APU_TRIANGLE_LENGTH_COUNTER  ; Immediately start the counter
    lda   #1
    stal  APU_TRIANGLE_START_FLAG

:no_reload
    pla
    plx
    plp
    rtl


APU_STATUS_WRITE ENT
    stal  APU_STATUS
    pha

; From NESDev Wiki: When the enabled bit is cleared (via $4015), the length counter is forced to 0
;             and cannot be changed until enabled is set again (the length counter's previous value is lost).
;             There is no immediate effect when enabled is set.

; Pulse 1
    bit  #$01
    bne  :pulse1_on
    stz  APU_PULSE1_LENGTH_COUNTER
:pulse1_on

; Pulse 2
    bit  #$02
    bne  :pulse2_on
    stz  APU_PULSE2_LENGTH_COUNTER
:pulse2_on

; Triangle
    bit  #$04
    bne  :triangle_on
    stz  APU_TRIANGLE_LENGTH_COUNTER
:triangle_on

    pla
    rtl
