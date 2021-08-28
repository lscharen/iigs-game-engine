// Utility to convert fatdog's palette-encoded images 
//
// The image has an extra 17 columns on the right=hand side.
//
//  1. The first column encodes SCB bytes values using a mapping from the Dreamgrafix palette
//     (black)     $000000 -> $0
//     (red)       $FF0000 -> $1
//     (dk. blue)  $001177 -> $2
//     (purple)    $AA11DD -> $3
//     (dk. green) $007711 -> $4
//     (dk. grey)  $554444 -> $5
//     (blue)      $0000FF -> $6
//     (lt. blue)  $3399EE -> $7
//     (brown)     $664400 -> $8
//     (orange)    $FF6600 -> $9
//     (lt. grey)  $AA9999 -> $A
//     (pink)      $FF9988 -> $B
//     (green)     $00FF00 -> $C
//     (yellow)    $FFDD00 -> $D
//     (lt. green) $44FF99 -> $E
//     (white)     $FFFFFF -> $F
//
//  2. The 16 columns of the top row encode the mapping of pcture colors to palette indexes
//  3. A 16x16 block of color in the lower-right represents the actual IIgs palette data

const fs = require('fs').promises;
const PNG = require("pngjs").PNG;
const process = require('process');
const { Buffer } = require('buffer');
const StringBuilder  = require('string-builder');

const DreamgraphixPalette = [
    // Red, Green, Blue
    [0x00, 0x00, 0x00],
    [0xF0, 0x00, 0x00],
    [0x00, 0x10, 0x70],
    [0xB0, 0x10, 0xE0],
    [0x00, 0x70, 0x10],
    [0x50, 0x40, 0x40],
    [0x00, 0x00, 0xF0],
    [0x30, 0xA0, 0xF0],
    [0x60, 0x40, 0x00],
    [0xF0, 0x60, 0x00],
    [0xB0, 0xA0, 0xA0],
    [0xF0, 0xA0, 0x80],
    [0x00, 0xF0, 0x00],
    [0xF0, 0xE0, 0x00],
    [0x40, 0xF0, 0xA0],
    [0xF0, 0xF0, 0xF0]
];

const DreamgraphixPalette2 = [
    // Red, Green, Blue
    [0x00, 0x00, 0x00],
    [0xFF, 0x00, 0x00],
    [0x00, 0x11, 0x77],
    [0xAA, 0x11, 0xDD],
    [0x00, 0x77, 0x11],
    [0x55, 0x44, 0x44],
    [0x00, 0x00, 0xFF],
    [0x33, 0x99, 0xEE],
    [0x66, 0x44, 0x00],
    [0xFF, 0x66, 0x00],
    [0xAA, 0x99, 0x99],
    [0xFF, 0x99, 0x88],
    [0x00, 0xFF, 0x00],
    [0xFF, 0xDD, 0x00],
    [0x44, 0xFF, 0x99],
    [0xFF, 0xFF, 0xFF]
];

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function findColorIndexInPalette(pixel, palette) {
    for (let i = 0; i < palette.length; i += 1) {
        const bands = 3;
        const color = palette[i].slice(0, bands); // Handle RGB or RGBA
        if (color[0] === pixel.red && color[1] === pixel.green && color[2] === pixel.blue) {
            return i;
        }
    }

    return -1;
}

function findColorIndex(png, pixel) {
    const index = findColorIndexInPalette(pixel, png.palette);
    return index + (index > -1) ? startIndex : 0;
}

/**
 * Convert PNG to IIgs memory order; arbitrary size
 */
function pngRectToIIgsBuff(png, x0, y0, width, height, colorTable) {
    const buff = Buffer.alloc(height * (width / 2), 0);
    for (let y = 0; y < height; y += 1) {
        for (let x = 0; x < width; x += 1) {
            // Index into the IIgs memory buffer
            const j = y * (width / 2) + Math.floor(x / 2);
            
            let index = 0;

            // Make sure the source pixel is in bounds
            if ((y + y0) < png.height && (x + x0) < png.width) {
                const pixel = getPixel(png, x + x0, y + y0);
                index = findColorIndexInPalette(pixel, colorTable);
            }

            if (index > 15) {
                console.warn('; Pixel index greater than 15. Skipping...');
                continue;
            }

            if (x % 2 === 0) {
                buff[j] = 16 * index;
            }
            else {
                buff[j] = buff[j] | index;
            }
        }
    }
    
    return buff;
}

function paletteToIIgs(palette) {
    const r = Math.round(palette[0] / 17);
    const g = Math.round(palette[1] / 17);
    const b = Math.round(palette[2] / 17);

    return '0' + r.toString(16).toUpperCase() + g.toString(16).toUpperCase() + b.toString(16).toUpperCase();
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

async function readPNG(filename) {
    const data = await fs.readFile(filename);
    return PNG.sync.read(data);
}

function getPixel(png, x, y) {
    if (x < 0 || x >= png.width) throw new Error(`x is out of range`);
    if (y < 0 || y >= png.height) throw new Error(`y is out of range`);

    const index = 4 * (png.width * y + x);
    const rgba  = png.data.slice(index, index + 4);
    return {
        red: rgba[0],
        green: rgba[1],
        blue: rgba[2],
        toString: function() {
            return [this.red, this.green, this.blue].map(c => toHex(c).toUpperCase());
        }
    };
}

function extractScanControlBytes(png) {
    const data = png.data;
    const column = png.width - 17;
    const controlBytes = [];

    const size = png.width * png.height;
    comment(`Image size:   ${size} pixels`);
    comment(`Data size:   ${data.length} bytes`);
    for (let row = 0; row < png.height; row += 1) {
        const pixel = getPixel(png, column, row);
        const index = findColorIndexInPalette(pixel, DreamgraphixPalette);

        if (index == -1) {
            console.warn(`Could not find match for color: ${pixel.toString()}`);
        }

        controlBytes.push(index);
    }

    return controlBytes;
}

function extractColorToIndexMap(png) {
    const column = png.width - 16;
    const color2index = {};

    for (let i = 0; i < 16; i += 1) {
        const pixel = getPixel(png, column + i, 0);
        const color = (pixel.red << 16) + (pixel.green << 8) + pixel.blue;
        color2index[color] = i;
    }

    return color2index;
}

function extractPalettes(png) {
    const column = png.width - 16;
    const row = png.height - 16;
    const palettes = [];

    for (let y = 0; y < 16; y += 1) {
        const palette = [];
        for (let x = 0; x < 16; x += 1) {
            const pixel = getPixel(png, column + x, row + y);
            const { red, green, blue } = pixel;
            const fourBitColor = ((red & 0xF0) << 4) | (green & 0xF0) | ((blue & 0xF0) >> 4);
            palette.push(fourBitColor);
        }
        palettes.push(palette);
    }

    return palettes;
}

const PNGColorTypes = {
    0: 'grayscale, no alpha',
    2: 'color, no alpha',
    4: 'grayscale, w/alpha',
    6: 'color w/alpha'
}

function dumpPNGInfo(filename, png) {
    comment(`Loaded PNG file from ${filename}`);
    comment(`  Width:       ${png.width}`);
    comment(`  Height:      ${png.height}`);
    comment(`  Color Type : ${PNGColorTypes[png.colorType] || png.colorType}`);
    comment(`  Bit Depth:   ${png.bitDepth}`);
    comment(`  Palette:     ${png.palette ? 'Yes' : 'No'}`);
}

async function main(argv) {
    try {
        const filename = argv[0];

        const outputFile = getArg(argv, '--output', x => x, 'output.bin');

        const png = await readPNG(filename);
        dumpPNGInfo(filename, png);

        // Get the SCB encoded bytes
        const SCBs = extractScanControlBytes(png);
        writeScanControlBytes(SCBs);

        // Get the greyscale map
        const color2index = extractColorToIndexMap(png);
        writeIndexMap(color2index);

        // Get the palette data
        const iigsPalettes = extractPalettes(png);
        writePalettes(iigsPalettes);

        // Run through the actual PNG image data and map using the colo2index map
        const targetWidth = png.width - 17;
        const targetHeight = png.height;
        const buffer = pngRectToIIgsBuff(png, 0, 0, targetWidth, targetHeight, color2index);

        await writeBinaryImageOutput(outputFile, buffer, targetWidth, targetHeight);
    } catch (e) {
        console.log(`; ${e}`);
        process.exit(1);
    }
}

function writePalettes(iigsPalettes) {
    console.log('palettes');
    for (let i = 0; i < iigsPalettes.length; i += 1) {
        console.log(`palette_${i} dw ${iigsPalettes[i].map(p => '$' + toHex(p, 4))}`);
    }
}
function writeIndexMap(color2index) {
    comment('Color to 4-bit color index mapping');
    for (const color of Object.keys(color2index)) {
        comment('$' + Number(color).toString(16).padStart(6, '0') + ' -> ' + color2index[color]);
    }
}

function writeScanControlBytes(SCBs) {
    console.log('SCB');
    for (let i = 0; i < SCBs.length; i += 8) {
        console.log('\tdw\t' + SCBs.slice(i, i+8).map(n => '$' + toHex(n)).join(','));
    }

}

function comment(str) {
    console.log(`; ${str}`);
}

function reverse(str) {
    return [...str].reverse().join(''); // use [...str] instead of split as it is unicode-aware.
}

function toHex(h, len=2) {
    return h.toString(16).padStart(len, '0');
}

function swap(hex) {
    const high = hex & 0xF0;
    const low = hex & 0x0F;

    return (high >> 4) | (low << 4);
}

function toMask(hex, transparentIndex) {
    if (transparentIndex === -1) {
        return 0;
    }

    const indexHigh = (transparentIndex & 0xF) << 4;
    const indexLow = (transparentIndex & 0xF);
    let mask = 0;
    if ((hex & 0xF0) === indexHigh) {
        mask = mask | 0xF0;
    }
    if ((hex & 0x0F) === indexLow) {
        mask = mask | 0x0F;
    }
    return mask;
}

async function writeBinaryImageOutput(filename, buff, width, height) {
    // Write a small header.  This is useful and avoids triggering a sparse file load
    // bug when the first block of the file on the GS/OS drive is sparse.

    // Put the ASCII text of "GTERAW" in the first 6 bytes followed by a transparency
    // indicator and then the width of the image (in bytes) and the height (in lines)
    const header = Buffer.alloc(12);
    header.write('GTERAW', 'latin1');

    // Use the special value $A5A5 to identify no transparency
    if (typeof transparentColor !== 'number') {
        header.writeUInt16LE(0xA5A5);
    } else {
        header.writeUInt16LE(0x1111 * transparentColor, 6);
    }
    header.writeUInt16LE(width);
    header.writeUInt16LE(height);

    await fs.writeFile(filename, Buffer.concat([header, buff]));
}
