const fs = require('fs').promises;
const PNG = require("pngjs").PNG;
const process = require('process');
const { Buffer } = require('buffer');

// Starting color index
let startIndex = 0;

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
                console.warn('Pixel index greater than 15. Skipping...');
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
                console.warn('Pixel index greater than 15. Skipping...');
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
            return fn(argv[i+1]);
        }
    }
    return defaultValue;
}

async function main(argv) {
    const data = await fs.readFile(argv[0]);
    const png = PNG.sync.read(data);
    startIndex = getArg(argv, '--start-index', x => parseInt(x, 10), 0);

    console.info(`startIndex = ${startIndex}`);

    if (png.colorType !== 3) {
        console.warn('PNG must be in palette color type');
        return;
    }

    if (png.palette.length > 16) {
        console.warn('Too many colors.  Must be 16 or less');
        return;
    }

    // Dump the palette in IIgs hex format
    console.log('Palette:');
    const hexCodes = png.palette.map(c => '$' + paletteToIIgs(c));
    console.log(hexCodes.join(','));

    // Just convert a paletted PNG to IIgs memory format
    let buff = null;
    if (png.width === 512) {
        console.log('Converting to BG1 format...');
        buff = pngToIIgsBuff(png);
    }

    if (png.width === 256) {
        console.log('Converting to BG1 format w/repeat...');
        buff = pngToIIgsBuffRepeat(png);
    }

    if (png.width === 328) {
        console.log('Converting to BG0 format...');
        buff = pngToIIgsBuff(png);
    }

    if (buff && argv[1]) {
        console.log(`Writing to output file ${argv[1]}`);
        await fs.writeFile(argv[1], buff);
    }
}

