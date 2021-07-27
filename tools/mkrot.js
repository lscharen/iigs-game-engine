/**
 * Generated data tables for BG1 rotation
 * 
 * The trickiest issue to address is that, when calculating the rotation indices, at
 * a 45 degree angle, the mapped address for a fixed rectangle can be outside of the
 * pixel buffer.  To fix this we make a compromise.
 * 
 * To keep speed, image data is drawn one word at a time, so the effective width of the
 * rotation is 82 units wide.  Since each work contains 4 pixels, we will only rotate
 * a quarter of the vertical image -- an effective 52 units -- and display the same offset
 * for four consecutive lines.
 * 
 * Further, the image data will be the center of the BG1 buffer, so the middle 52 lines.
 * 
 * When rotating we may still calculate address "outside" of the buffer by a factor of
 * sqrt(2) (~40%) -- or 32 words horizontally and 21 lines vertically.  There is extra
 * data vertically to fill this and, since the BG1 buffer is stored with a stride of
 * 256 bytes (128 words) there are an extra 46 words of empty space that can be zeroed
 * out or filled with content to improve the rotation visuals.
 */
const fs = require('fs').promises;
const process = require('process');
const { Buffer } = require('buffer');

const NUM_ANGLES = 64;

const BUFFER_HEIGHT = 208;
const BUFFER_WIDTH  = 164;
const BUFFER_STRIDE = 256;

const TEXTURE_WIDTH = BUFFER_WIDTH / 2;    // Full width
const TEXTURE_HEIGHT = BUFFER_HEIGHT / 4;  // Quarter height
const TEXTURE_STRIDE = BUFFER_STRIDE;

const BUFFER_START = 0x1800;
const BUFFER_END   = BUFFER_START + BUFFER_STRIDE * BUFFER_HEIGHT;

console.log(`; The BG1 buffer lives at [${toHex(BUFFER_START)}, ${toHex(BUFFER_END)}]`);

// The texture portion of BG starts at  the left edge of line 77 and
// extends down to line 
const TEXTURE_START = BUFFER_STRIDE * (BUFFER_HEIGHT - TEXTURE_HEIGHT) / 2;
const TEXTURE_END   = BUFFER_STRIDE * (BUFFER_HEIGHT + TEXTURE_HEIGHT) / 2;
const TEXTURE_CENTER = BUFFER_START + TEXTURE_START + Math.floor(TEXTURE_HEIGHT / 2) * BUFFER_STRIDE + Math.floor(BUFFER_WIDTH / 2);

console.log(`; The texture is this range of the BG1 buffer [${toHex(TEXTURE_START)}, ${toHex(TEXTURE_END)}]`);

// Define some other constants
const x_half = Math.floor(TEXTURE_WIDTH / 2);
const y_half = Math.floor(TEXTURE_HEIGHT / 2);

// Calculate some bias values to keep everything positive
BIAS_X   = Math.floor(TEXTURE_CENTER / 2) + 0x200;
BIAS_Y   = TEXTURE_CENTER - BIAS_X;

const angles = Array.from({ length: NUM_ANGLES}).map((x, i) => (i * 2 * Math.PI) / NUM_ANGLES);

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function toHex(n) {
    return '$' + n.toString(16).toUpperCase().padStart(4, '0');
}

function f_x(x, angle) {
    // Calculate x in units of bytes
    // return Math.floor(a(x - x_half, angle)) + x_half + BIAS_X;
    return Math.floor(a(x - x_half, angle)) + BIAS_X;
}

function f_y(y, angle) {
    // return Math.floor(b(y - y_half, angle)) + (y_half * TEXTURE_STRIDE) + BIAS_Y;
    return Math.floor(b(y - y_half, angle)) + BIAS_Y;
}

function check_sample(_a, x, y) {
    const angle = angles[_a];

    const degrees = Math.round(360 * angle / (2 * Math.PI));
    const fx = f_x(x, angle);
    const fy = f_y(y, angle);
    const ptr = fx + fy;

    if (fx < 0 || fy < 0 || ptr < 0x1800 || ptr >= 0xE800) {
        console.log(`(a = ${degrees}, x = ${x}, y = ${y}) : f_x = ${toHex(fx)}, f_y = ${toHex(fy)}, p = ${toHex(ptr)}`);
        process.exit();
    }
}
async function main(argv) {

    // Inspired by https://www.youtube.com/watch?v=glWIf0gfWSE&t=1196s
    //
    // We will support 64 rotation angles (~5.5 degree increments) which gives nice
    // power-of-2 values from the common angles or 45, 90, 135, etc.
    
    // Do a brute force check to make sure that we can generate addresses that stay within
    // a proper range
    for (let a = 0; a < NUM_ANGLES; a += 1) {
        for (let x = 0; x < TEXTURE_WIDTH; x += 1) {
            for (let y = 0; y < TEXTURE_HEIGHT; y += 1) {
                check_sample(a, x, y);
            }
        }
        const degrees = Math.round(360 * angles[a] / (2 * Math.PI));
    }

    // Now generate the tables to stdout as merlin source code
    const _ = console.log;

    _("x_angles\t");
    for (let a = 0; a < NUM_ANGLES; a += 1) {
        _(`\tdw\t:x_a_${a}`);
    }
    for (let a = 0; a < NUM_ANGLES; a += 1) {
        const angle = angles[a];
        const label = `:x_a_${a}`;
        const fx = [];
        for (let x = 0; x < TEXTURE_WIDTH; x += 1) {
            fx.push(f_x(x, angle));
        }
        const arr = fx.map(toHex).join(',');

        // Double every array for fast copies
        _(`${label}\tdw\t${arr}`);
        _(`\tdw\t${arr}`);
    }

    _("y_angles\t");
    for (let a = 0; a < NUM_ANGLES; a += 1) {
        _(`\tdw\t:y_a_${a}`);
    }
    for (let a = 0; a < NUM_ANGLES; a += 1) {
        const angle = angles[a];
        const label = `:y_a_${a}`;
        const fy = [];
        for (let y = 0; y < TEXTURE_HEIGHT; y += 1) {
            const value = f_y(y, angle);
            fy.push(value);
        }
        const arr = fy.map(toHex).join(',');
        // Double every array for fast output
        _(`${label}\tdw\t${arr}`);
        _(`\tdw\t${arr}`);
    }
}

function a(x, angle) {
    return Math.floor(x * Math.cos(angle)) + Math.floor(x * Math.sin(angle)) * TEXTURE_STRIDE;
}

function b(y, angle) {
    return Math.floor(y * Math.cos(angle)) * TEXTURE_STRIDE - Math.floor(y * Math.sin(angle));
}
