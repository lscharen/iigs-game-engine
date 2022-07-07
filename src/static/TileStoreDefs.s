; Tile storage parameters
TILE_DATA_SPAN        equ  4
TILE_STORE_WIDTH      equ  41
TILE_STORE_HEIGHT     equ  26
MAX_TILES             equ  {26*41}                ; Number of tiles in the code field (41 columns * 26 rows)
TILE_STORE_SIZE       equ  {MAX_TILES*2}          ; The tile store contains a tile descriptor in each slot

TS_TILE_ID            equ  {TILE_STORE_SIZE*0}      ; tile descriptor for this location
TS_DIRTY              equ  {TILE_STORE_SIZE*1}      ; Flag. Used to prevent a tile from being queued multiple times per frame
TS_SPRITE_FLAG        equ  {TILE_STORE_SIZE*2}      ; Bitfield of all sprites that intersect this tile. 0 if no sprites.
TS_TILE_ADDR          equ  {TILE_STORE_SIZE*3}      ; cached value, the address of the tiledata for this tile
TS_CODE_ADDR_LOW      equ  {TILE_STORE_SIZE*4}      ; const value, address of this tile in the code fields
TS_CODE_ADDR_HIGH     equ  {TILE_STORE_SIZE*5}
TS_WORD_OFFSET        equ  {TILE_STORE_SIZE*6}      ; const value, word offset value for this tile if LDA (dp),y instructions re used
;TS_BASE_ADDR          equ  {TILE_STORE_SIZE*7}      ; const value, because there are two rows of tiles per bank, this is set to $0000 or $8000.
TS_JMP_ADDR           equ  {TILE_STORE_SIZE*7}      ; const value, address of the 32-byte snippet space for this tile
TS_SCREEN_ADDR        equ  {TILE_STORE_SIZE*8}      ; cached value of on-screen location of tile. Used for DirtyRender.

; TODO: Move these arrays into the K bank to support direct dispatch via jmp (abs,x)
; TS_BASE_TILE_COPY     equ  {TILE_STORE_SIZE*9}      ; derived from TS_TILE_ID to optimize tile copy to support sprite rendering
; TS_BASE_TILE_DISP     equ  {TILE_STORE_SIZE*10}     ; derived from TS_TILE_ID to optimize base (non-sprite) tile dispatch in the Render function
; TS_DIRTY_TILE_DISP    equ  {TILE_STORE_SIZE*11}     ; derived from TS_TILE_ID to optimize dirty tile dispatch in the Render function

TILE_STORE_NUM        equ  12                     ; Need this many parallel arrays

; Sprite data structures.  We cache quite a few pieces of information about the sprite
; to make calculations faster, so this is hidden from the caller.

MAX_SPRITES            equ 16
SPRITE_REC_SIZE        equ 42

; Mark each sprite as ADDED, UPDATED, MOVED, REMOVED depending on the actions applied to it
; on this frame.  Quick note, the same Sprite ID cannot be removed and added in the same frame.
; A REMOVED sprite if removed from the sprite list during the Render call, so it's ID is not
; available to the AddSprite function until the next frame.

SPRITE_STATUS_EMPTY    equ $0000         ; If the status value is zero, this sprite slot is available
SPRITE_STATUS_OCCUPIED equ $8000         ; Set the MSB to flag it as occupied
SPRITE_STATUS_ADDED    equ $0001         ; Sprite was just added (new sprite)
SPRITE_STATUS_MOVED    equ $0002         ; Sprite's position was changed
SPRITE_STATUS_UPDATED  equ $0004         ; Sprite's non-position attributes were changed
SPRITE_STATUS_REMOVED  equ $0008         ; Sprite has been removed.
SPRITE_STATUS_HIDDEN   equ $0010         ; Sprite is in a hidden state

; These values are set by the user
SPRITE_STATUS        equ {MAX_SPRITES*0}
SPRITE_ID            equ {MAX_SPRITES*2}
SPRITE_X             equ {MAX_SPRITES*4}
SPRITE_Y             equ {MAX_SPRITES*6}
VBUFF_ADDR           equ {MAX_SPRITES*8}         ; Base address of the sprite's stamp in the data/mask banks

; These values are cached / calculated during the rendering process
TS_LOOKUP_INDEX      equ {MAX_SPRITES*10}        ; The index from the TileStoreLookup table that corresponds to the top-left corner of the sprite
TS_COVERAGE_SIZE     equ {MAX_SPRITES*12}        ; Representation of how many TileStore tiles (NxM) are covered by this sprite
SPRITE_DISP          equ {MAX_SPRITES*14}        ; Cached address of the specific stamp based on sprite flags
SPRITE_CLIP_LEFT     equ {MAX_SPRITES*16}
SPRITE_CLIP_RIGHT    equ {MAX_SPRITES*18}
SPRITE_CLIP_TOP      equ {MAX_SPRITES*20}
SPRITE_CLIP_BOTTOM   equ {MAX_SPRITES*22}
IS_OFF_SCREEN        equ {MAX_SPRITES*24}
SPRITE_WIDTH         equ {MAX_SPRITES*26}
SPRITE_HEIGHT        equ {MAX_SPRITES*28}
SPRITE_CLIP_WIDTH    equ {MAX_SPRITES*30}
SPRITE_CLIP_HEIGHT   equ {MAX_SPRITES*32}
TS_VBUFF_BASE        equ {MAX_SPRITES*34}        ; Finalized VBUFF address based on the sprite position and tile offsets
VBUFF_ARRAY_ADDR     equ {MAX_SPRITES*36}        ; Fixed address where this sprite's VBUFF addresses are stores. The array is the same shape as TileStore, but much smaller

; 52 rows by 82 columns + 2 extra rows and columns for sprite sizes
;
; 53 rows = TILE_STORE_HEIGHT + TILE_STORE_HEIGHT + 1
; 83 cols = TILE_STORE_WIDTH + TILE_STORE_WIDTH + 1
;
; TILE_STORE_WIDTH  equ  41
; TILE_STORE_HEIGHT equ  26

TS_LOOKUP_WIDTH   equ 82
TS_LOOKUP_HEIGHT  equ 52
TS_LOOKUP_BORDER  equ 2
TS_LOOKUP_SPAN    equ {TS_LOOKUP_WIDTH+TS_LOOKUP_BORDER}
TS_LOOKUP_ROWS    equ {TS_LOOKUP_HEIGHT+TS_LOOKUP_BORDER}

; Blitter template constants
PER_TILE_SIZE     equ   3
SNIPPET_SIZE      equ   32

;----------------------------------------------------------------------
;
; Timer implementation
;
; The engire provides four timer slot that can be used by one-shot or 
; recurring timers.  Each timer is given an initial tick count, a 
; reset tick count (0 = one-shot), and an action to perform.
;
; The timers handle overflow, so if a recurring timer has a tick count of 3
; and 7 VBL ticks have passed, then the timer will be fired twice and
; a tick count of 2 will be set.
;
; As such, the timers are appropriate to drive physical and other game
; behaviors at a frame-independent rate.
;
; A collection of 4 timers that are triggered when their countdown
; goes below zero.  Each timer takes up 16 bytes
;
; A timer can fire multiple times during a singular evaluation.  For example, if the
; timer delay is set to 1 and 3 VBL ticks happen, then the timer delta is -2, will fire,
; have the delay added and get -1, fire again, increment to zero, first again and then
; finally reset to 1.
;
; +0 counter         decremented by the number of ticks since last run
; +2 reset           copied into counter when triggered. 0 turns off the timer.
; +4 addr            long address of timer routine
; +8 user            8 bytes of user data space for timer state
MAX_TIMERS      equ       4
TIMER_REC_SIZE  equ       16
