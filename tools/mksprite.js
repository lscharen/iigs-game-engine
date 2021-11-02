/**
 * Basic sprite compiler
 * 
 * GTE has some specific needs that makes existing tools (like MrSprite) inappropriate. GTE
 * sprites need to reference some internal data structures and have slightly different code
 * in order to handle clipping to the playfield bounds.
 * 
 * The core sprite drawing approach is the same (set up Bank 1 direct page and stack), but
 * the setup and dispatch are a bit different.
 * 
 * A Note on Clipping
 * 
 * GTE supports two clipping buffers for sprites to use.  The first one is a static buffer
 * that is aligned with the playfield and is used to clip the sprite when crossing the
 * left and right boundaries, but since it's a static image, mask data can be put anywhere
 * that the sprites should not show through, so irregular borders and sprite punch-outs
 * on the playfield are possible.
 * 
 * The second buffer matches the current tiles in the playfield and can be used as a 
 * dynamic mask of the playfield.  Since the sprite code itself must use this data,
 * different variations of the same sprite can be created to stand in "front" and "behind"
 * different screen elements.
 * 
 * The sprite requires the X and Y registers for this.  The most general code that
 * should be used for each sprite word is this:
 * 
 *   Example: DATA = $5670, MASK = $000F, screen_mask = $FF00, field_mask = $F0FF
 *   lda DP                 ; A = $1234
 *   eor #DATA              ; A = $4444
 *   and #~MASK             ; A = $4440
 *   and screen_mask,y      ; A = $4400
 *   and >field_mask,x      ; A = $4000
 *   eor DP                 ; A = $5234  <-- Only the high nibble is set to the sprite data
 *   sta DP
 * 
 * It is not *required* that sprites use this approach, any compiled sprites code can be used,
 * so if a sprite does not need to be masked, than any of the fast sprite approaches can be
 * used.
 *
 * For clipping vertically, we pass in the starting and finishing lines in a register and
 * a sprite record is set up to allow the sprite to be entered in the middle and exited
 * before the last line of the sprite.
 */
const { readPNG, pngToIIgsBuff } = require('./png2iigs');
const process = require('process');

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

async function main(argv) {
    const png = await readPNG(argv[0]);
    const buff = pngToIIgsBuff(png);

    const options = {
        staticClip: true,
        label: 'Sprite001'
    };

    startIndex = getArg(argv, '--start-index', x => parseInt(x, 10), 0);
    asTileData = getArg(argv, '--as-tile-data', null, 0);
    maxTiles = getArg(argv, '--max-tiles', x => parseInt(x, 10), 64);
}

function getArg(argv, arg, fn, defaultValue) {
    for (let i = 0; i < argv.length; i += 1) {
        if (argv[i] === arg) {
            if (fn) {
                return fn(argv[i+1]);
            }
            return true;   // Return true if the argument was found
        }
    }
    return defaultValue;
}


function buildMerlinCodeForSprite(sprite, options) {
    const { label, staticClip } = options;
    const rtnOpCode = options.longReturn ? 'rtl' : 'rts';

    const sb = new StringBuilder();
    sb.appendLine(`${label}       ENT`);
    sb.appendLine(`               cpx  #${sprite.height * 2}`);
    sb.appendLine(`               bcc  *+3`);
    sb.appendLine(`               ${rtnOpCode}`);
    sb.appendLine(`               sei`);
    sb.appendLine(`               tcs`);
    sb.appendLine(`               jmp  (${label}_jtbl,x)`);
    sb.appendLine(`${label}_jtbl`);
    for (let line = 0; line < sprite.rows.length; line += 1) {
        lda DP                 ; A = $1234
 *   eor #DATA              ; A = $4444
 *   and #~MASK             ; A = $4440
 *   and screen_mask,y      ; A = $4400
 *   and >field_mask,x      ; A = $4000
 *   eor DP                 ; A = $5234  <-- Only the high nibble is set to the sprite data
 *   sta DP
        sb.appendLine(`               dw  ${label}_${line}`);
    }

    // Implement each line to draw the sprite data
    //
    // label_XX   tdc
    //            clc
    //            adc   #160*line
    //            tcd
    // main_XX    lda   00
    //            and   #
    //            ora   #
    //            
    for (let line = 0; line < sprite.rows.length; line += 1) {

    }

    return sb.toString();
}