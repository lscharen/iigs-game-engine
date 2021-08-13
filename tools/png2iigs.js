const fs = require('fs').promises;
const PNG = require("pngjs").PNG;
const process = require('process');
const { Buffer } = require('buffer');

// Starting color index
let startIndex = 0;
let transparentColor = 0;

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function findColorIndex(png, pixel) {
    for (let i = 0; i < png.palette.length; i += 1) {
        const color = png.palette[i];
        if (color.every((c, idx) => c === pixel[idx])) {
            return i + startIndex;
        }
    }

    return null;
}

function pngToIIgsBuff(png) {
    let i = 0;
    const buff = Buffer.alloc(png.height * (png.width / 2), 0);
    for (let y = 0; y < png.height; y += 1) {
        for (let x = 0; x < png.width; x += 1, i += 4) {
            const pixel = png.data.slice(i, i + 4);
            const index = findColorIndex(png, pixel);
            const j = y * (png.width / 2) + Math.floor(x / 2);

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

function shiftImage(src) {
    const { width, height, colorType, bitDepth } = src;
    const dst = new PNG({ width, height, colorType, bitDepth });

    PNG.bitblt(src, dst, 1, 0, width - 1, height, 0, 0);
    PNG.bitblt(src, dst, 0, 0, 1, height, width - 1, 0);

    return dst;
}

function pngToIIgsBuffRepeat(png) {
    let i = 0;
    const buff = Buffer.alloc(png.height * png.width, 0);
    for (let y = 0; y < png.height; y += 1) {
        for (let x = 0; x < png.width; x += 1, i += 4) {
            const pixel = png.data.slice(i, i + 4);
            const index = findColorIndex(png, pixel);
            const j = y * png.width + Math.floor(x / 2);

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

            buff[j + (png.width / 2)] = buff[j];
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
            return true;   // REturn true if the argument was found
        }
    }
    return defaultValue;
}

async function main(argv) {
    const data = await fs.readFile(argv[0]);
    const png = PNG.sync.read(data);
    startIndex = getArg(argv, '--start-index', x => parseInt(x, 10), 0);
    asTileData = getArg(argv, '--as-tile-data', null, 0);

    transparentColor = getArg(argv, '--transparent-color-index', x => parseInt(x, 10), 0);

    console.info(`; startIndex = ${startIndex}`);

    if (png.colorType !== 3) {
        console.warn('; PNG must be in palette color type');
        return;
    }

    if (png.palette.length > 16) {
        console.warn('; Too many colors.  Must be 16 or less');
        return;
    }

    // Dump the palette in IIgs hex format
    console.log('; Palette:');
    const hexCodes = png.palette.map(c => '$' + paletteToIIgs(c));
    console.log(';', hexCodes.join(','));

    // Just convert a paletted PNG to IIgs memory format.  We make sute that only a few widths
    // are supported
    let buff = null;

    if (png.width === 512) {
        console.log('; Converting to BG1 format...');
        buff = pngToIIgsBuff(png);
    }

    if (png.width === 256) {
        console.log('; Converting to BG1 format w/repeat...');
        buff = pngToIIgsBuffRepeat(png);
    }

    if (png.width === 328 || png.width == 320) {
        console.log('; Converting to BG0 format...');
        buff = pngToIIgsBuff(png);
    }

    if (buff && argv[1]) {
        if (asTileData) {
            writeToTileDataSource(buff, png.width / 2);
        }
        else {
            console.log(`; Writing to output file ${argv[1]}`);
            await writeBinayOutput(argv[1], buff);
        }
    }
}

function reverse(str) {
    return [...str].reverse().join(''); // use [...str] instead of split as it is unicode-aware.
}

function writeToTileDataSource(buff, width) {
    console.log('tiledata    ENT');
    console.log();
    console.log('; Reserved space (tile 0 is special...');
    console.log('            ds 128');

    const MAX_TILES = 64;

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= MAX_TILES) {
                return;
            }
            console.log('; Tile ID ' + (count + 1));
            console.log('; From image coordinates ' + (x * 2) + ', ' + y);

            // Output the tile data
            const offset = y * width + x;
            for (dy = 0; dy < 8; dy += 1) {
                const hex0 = buff[offset + dy * width + 0].toString(16).padStart(2, '0');
                const hex1 = buff[offset + dy * width + 1].toString(16).padStart(2, '0');
                const hex2 = buff[offset + dy * width + 2].toString(16).padStart(2, '0');
                const hex3 = buff[offset + dy * width + 3].toString(16).padStart(2, '0');
                console.log('            hex   ' + hex0 + hex1 + hex2 + hex3);
            }
            console.log();

            // Output the tile mask
            for (dy = 0; dy < 8; dy += 1) {
                //const hex0 = buff[offset + dy * width + 0].toString(16).padStart(2, '0');
                //const hex1 = buff[offset + dy * width + 1].toString(16).padStart(2, '0');
                //const hex2 = buff[offset + dy * width + 2].toString(16).padStart(2, '0');
                //const hex3 = buff[offset + dy * width + 3].toString(16).padStart(2, '0');
                console.log('            hex   00000000');
            }
            console.log();

            // Output the flipped tile data
            for (dy = 0; dy < 8; dy += 1) {
                const hex0 = reverse(buff[offset + dy * width + 0].toString(16).padStart(2, '0'));
                const hex1 = reverse(buff[offset + dy * width + 1].toString(16).padStart(2, '0'));
                const hex2 = reverse(buff[offset + dy * width + 2].toString(16).padStart(2, '0'));
                const hex3 = reverse(buff[offset + dy * width + 3].toString(16).padStart(2, '0'));
                console.log('            hex   ' + hex3 + hex2 + hex1 + hex0);
            }
            console.log();

            // Output the flipped tile mask
            for (dy = 0; dy < 8; dy += 1) {
                //const hex0 = buff[offset + dy * width + 0].toString(16).padStart(2, '0');
                //const hex1 = buff[offset + dy * width + 1].toString(16).padStart(2, '0');
                //const hex2 = buff[offset + dy * width + 2].toString(16).padStart(2, '0');
                //const hex3 = buff[offset + dy * width + 3].toString(16).padStart(2, '0');
                console.log('            hex   00000000');
            }
            console.log();

        }
    }
}

async function writeBinayOutput(filename, buff) {
    // Write a small header.  This is useful and avoids triggering a sparse file load
    // bug when the first block of the file on the GS/OS drive is sparse.

    // Put the ASCII text of "GTERAW" in the first 6 bytes
    const header = Buffer.alloc(8);
    header.write('GTERAW', 'latin1');

    // Use the special value $A5A5 to identify no transparency
    if (typeof transparentColor !== 'number') {
        header.writeUInt16LE(0xA5A5);
    } else {
        header.writeUInt16LE(0x1111 * transparentColor, 6);
    }

    await fs.writeFile(filename, Buffer.concat([header, buff]));
}

