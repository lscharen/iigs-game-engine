; Wrapper around the SMB ROM code.  This takes care of setting any memory locations
; in the SMB ROM address space that interact with the system (like controller inputs).
;
; We also shim many of the LDA/STA instruction that modify the NES I/O to be
; JSRs to small subroutines that enqueue any changes that are handled once 
; control returns.  The queues are important, because we try to run the game
; logic at 60 fps, but the screen will update significantly slower than that.
;
; By queuing the changes, we can "catch up" to the game logic and prioritize
; audio output at 60 fps since audio stutter is much more disruptive that slow
; FPS.

