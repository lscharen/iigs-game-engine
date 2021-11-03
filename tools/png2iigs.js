const fs = require('fs').promises;
const PNG = require("pngjs").PNG;
const process = require('process');
const { Buffer } = require('buffer');
const StringBuilder  = require('string-builder');

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function findColorIndex(options, png, pixel) {
    for (let i = 0; i < png.palette.length; i += 1) {
        const color = png.palette[i].slice(0, pixel.length); // Handle RGB or RGBA
        if (color.every((c, idx) => c === pixel[idx])) {
            return i + options.startIndex;
        }
    }

    return null;
}

function pngToIIgsBuff(options, png) {
    let i = 0;
    const buff = Buffer.alloc(png.height * (png.width / 2), 0);
    for (let y = 0; y < png.height; y += 1) {
        for (let x = 0; x < png.width; x += 1, i += 4) {
            const pixel = png.data.slice(i, i + 4);
            const index = findColorIndex(options, png, pixel);
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

function pngToIIgsBuffRepeat(options, png) {
    let i = 0;
    const buff = Buffer.alloc(png.height * png.width, 0);
    for (let y = 0; y < png.height; y += 1) {
        for (let x = 0; x < png.width; x += 1, i += 4) {
            const pixel = png.data.slice(i, i + 4);
            const index = findColorIndex(options, png, pixel);
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

function hexStringToPalette(hex) {
    return [
        parseInt(hex.slice(0,2), 16),
        parseInt(hex.slice(2,4), 16),
        parseInt(hex.slice(4,6), 16)
    ];
}

function paletteToHexString(palette) {
    const r = Math.round(palette[0]);
    const g = Math.round(palette[1]);
    const b = Math.round(palette[2]);

    return (
        r.toString(16).toUpperCase().padStart(2, '0') + 
        g.toString(16).toUpperCase().padStart(2, '0') + 
        b.toString(16).toUpperCase().padStart(2, '0')
    );
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
    const png = PNG.sync.read(data);

    if (png.colorType !== 3) {
        throw new Error('PNG must be in palette color type');
    }

    if (png.palette.length > 16) {
        throw new Error(`Too many colors.  Must be 16 or less. Found ${png.palette.length}`);
    }

    return png;
}

function getOptions(argv) {
    const options = {};
    options.startIndex = getArg(argv, '--start-index', x => parseInt(x, 10), 0);
    options.asTileData = getArg(argv, '--as-tile-data', x => true, false);
    options.maxTiles = getArg(argv, '--max-tiles', x => parseInt(x, 10), 511);
    options.transparentIndex = getArg(argv, '--transparent-color-index', x => parseInt(x, 10), -1);
    options.transparentColor = getArg(argv, '--transparent-color', x => x, null);
    options.backgroundColor = getArg(argv, '--background-color', x => x, null);

    return options;
}

async function main(argv) {
    // try {
        const png = await readPNG(argv[0]);
        const options = getOptions(argv);
        
        console.info(`; startIndex = ${options.startIndex}`);

        if (png.colorType !== 3) {
            console.warn('; PNG must be in palette color type');
            return;
        }

        if (png.palette.length > 16) {
            console.warn('; Too many colors.  Must be 16 or less');
            return;
        }

        // Get the RGB triplets from the palette
        const palette = png.palette;
        const paletteCSSTripplets = palette.map(c => paletteToHexString(c));

        // If there is a transparent color / color index, make sure it gets shuffled
        // into index 0
        if (options.transparentIndex > 0) {
            [palette[0], palette[options.transparentIndex]] = [palette[options.transparentIndex], palette[0]];
            options.transparentIndex = 0;
        }
        if (options.transparentColor !== null) {
            const index = paletteCSSTripplets.findIndex(p => p === options.transparentColor);
            if (index !== -1) {
                options.transparentIndex = 0;
                [palette[0], palette[index]] = [palette[index], palette[0]];
            } else {
                console.warn(`; transparent color defined, ${options.transparentColor}, but not found in image`);
            }
        }

        // Dump the palette in IIgs hex format
        console.log('; Palette:');
        const hexCodes = palette.map(c => '$' + paletteToIIgs(c));
        if (options.backgroundColor !== null) {
            hexCodes[options.transparentIndex] = '$' + paletteToIIgs(hexStringToPalette(options.backgroundColor));
        }
        console.log(';', hexCodes.join(','));

        // Just convert a paletted PNG to IIgs memory format.  We make sure that only a few widths
        // are supported
        let buff = null;

        console.log('; Converting to BG0 format...');
        buff = pngToIIgsBuff(options, png);

        if (buff && argv[1]) {
            if (options.asTileData) {
                writeToTileDataSource(options, buff, png.width / 2);
            }
            else {
                console.log(`; Writing to output file ${argv[1]}`);
                await writeBinayOutput(options, argv[1], buff);
            }
        }
    //} 
    // catch (e) {
    //     console.log(`; ${e}`);
    //    process.exit(1);
    //}
}

function reverse(str) {
    return [...str].reverse().join(''); // use [...str] instead of split as it is unicode-aware.
}

function toHex(h) {
    return h.toString(16).padStart(2, '0');
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

/**
 * Return all four 32 byte chunks of data for a single 8x8 tile
 */
function buildTile(options, buff, width, x, y) {
    const tile = {
        isSolid: true,
        normal: {
            data: [],
            mask: []
        },
        flipped: {
            data: [],
            mask: []
        }
    };

    const offset = y * width + x;
    for (dy = 0; dy < 8; dy += 1) {
        const hex0 = buff[offset + dy * width + 0];
        const hex1 = buff[offset + dy * width + 1];
        const hex2 = buff[offset + dy * width + 2];
        const hex3 = buff[offset + dy * width + 3];

        const raw = [hex0, hex1, hex2, hex3];
        const mask = raw.map(h => toMask(h, options.transparentIndex));
        const data = raw.map((h, i) => h & ~mask[i]);

        tile.normal.data.push(data);
        tile.normal.mask.push(mask);

        // If we run across any non-zero mask value, then the tile is not solid
        if (mask.some(h => h != 0)) {
            tile.isSolid = false;
        }
    }

    for (dy = 0; dy < 8; dy += 1) {
        const hex0 = swap(buff[offset + dy * width + 0]);
        const hex1 = swap(buff[offset + dy * width + 1]);
        const hex2 = swap(buff[offset + dy * width + 2]);
        const hex3 = swap(buff[offset + dy * width + 3]);

        const raw = [hex3, hex2, hex1, hex0];
        const mask = raw.map(h => toMask(h, options.transparentIndex));
        const data = raw.map((h, i) => h & ~mask[i]);

        tile.flipped.data.push(data);
        tile.flipped.mask.push(mask);
    }

    return tile;
}

function buildTiles(options, buff, width) {
    const tiles = [];

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= options.maxTiles) {
                return tiles;
            }
            const tile = buildTile(options, buff, width, x, y);

            // Tiled TileIDs start at 1
            tile.tileId = count + 1;
            tiles.push(tile);
        }
    }
}

function writeTileToStream(stream, data) {
    // Output the tile data
    for (const row of data) {
        const hex = row.map(d => toHex(d)).join('');
        stream.write('            hex   ' + hex + '\n');
    }
}

function writeTilesToStream(options, stream, tiles, label='tiledata') {
    stream.write(`${label}    ENT\n`);
    stream.write('');
    stream.write('; Reserved space (tile 0 is special...)\n');
    stream.write('            ds 128\n');

    let count = 0;
    for (const tile of tiles.slice(0, options.maxTiles)) {
        console.log(`Writing tile ${count + 1}`);
        stream.write(`; Tile ID ${count + 1}, isSolid: ${tile.isSolid}\n`);
        writeTileToStream(stream, tile.normal.data);
        writeTileToStream(stream, tile.normal.mask);
        writeTileToStream(stream, tile.flipped.data);
        writeTileToStream(stream, tile.flipped.mask);
        stream.write('');

        count += 1;
    }
}

function buildMerlinCodeForTile(data) {
    const sb = new StringBuilder();

    // Output the tile data
    for (const row of data) {
        const hex = row.map(d => toHex(d)).join('');
        sb.appendLine('            hex   ' + hex);
    }

    return sb.toString();
}

function buildMerlinCodeForTiles(options, tiles, label='tiledata') {
    const sb = new StringBuilder();
    sb.appendLine(`${label}    ENT`);
    sb.appendLine();
    sb.appendLine('; Reserved space (tile 0 is special...)');
    sb.appendLine('            ds 128');

    let count = 0;
    for (const tile of tiles.slice(0, options.maxTiles)) {
        console.log(`Writing tile ${count + 1}`);
        sb.appendLine(`; Tile ID ${count + 1}, isSolid: ${tile.isSolid}`);
        sb.append(buildMerlinCodeForTile(tile.normal.data));
        sb.append(buildMerlinCodeForTile(tile.normal.mask));
        sb.append(buildMerlinCodeForTile(tile.flipped.data));
        sb.append(buildMerlinCodeForTile(tile.flipped.mask));
        sb.appendLine();

        count += 1;
    }

    return sb.toString();
}

function writeToTileDataSource(options, buff, width) {
    console.log('tiledata    ENT');
    console.log();
    console.log('; Reserved space (tile 0 is special...');
    console.log('            ds 128');

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= options.maxTiles) {
                return;
            }
            console.log('; Tile ID ' + (count + 1));
            console.log('; From image coordinates ' + (x * 2) + ', ' + y);

            const tile = buildTile(options, buff, width, x, y);

            // Output the tile data
            for (const row of tile.normal.data) {
                const hex = row.map(d => toHex(d)).join('');
                console.log('            hex   ' + hex);
            }
            console.log();

            // Output the tile mask
            for (const row of tile.normal.mask) {
                const hex = row.map(d => toHex(d)).join('');
                console.log('            hex   ' + hex);
            }
            console.log();

            // Output the flipped tile data
            for (const row of tile.flipped.data) {
                const hex = row.map(d => toHex(d)).join('');
                console.log('            hex   ' + hex);
            }
            console.log();

            // Output the flipped tile data
            for (const row of tile.flipped.mask) {
                const hex = row.map(d => toHex(d)).join('');
                console.log('            hex   ' + hex);
            }
            console.log();
        }
    }
}

async function writeBinayOutput(options, filename, buff) {
    // Write a small header.  This is useful and avoids triggering a sparse file load
    // bug when the first block of the file on the GS/OS drive is sparse.

    // Put the ASCII text of "GTERAW" in the first 6 bytes
    const header = Buffer.alloc(8);
    header.write('GTERAW', 'latin1');

    // Use the special value $A5A5 to identify no transparency
    if (options.transparentIndex < 0) {
        header.writeUInt16LE(0xA5A5);
    } else {
        header.writeUInt16LE(0x1111 * options.transparentIndex, 6);
    }

    await fs.writeFile(filename, Buffer.concat([header, buff]));
}

module.exports = {
    buildTile,
    buildTiles,
    buildMerlinCodeForTiles,
    buildMerlinCodeForTile,
    findColorIndex,
    paletteToIIgs,
    pngToIIgsBuff,
    readPNG,
    toHex,
    writeBinayOutput,
    writeToTileDataSource,
    writeTilesToStream
}