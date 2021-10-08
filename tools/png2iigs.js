const fs = require('fs').promises;
const PNG = require("pngjs").PNG;
const process = require('process');
const { Buffer } = require('buffer');
const StringBuilder  = require('string-builder');

// Starting color index
let startIndex = 0;
let transparentColor = 0;
let transparentIndex = -1;

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function findColorIndex(png, pixel) {
    for (let i = 0; i < png.palette.length; i += 1) {
        const color = png.palette[i].slice(0, pixel.length); // Handle RGB or RGBA
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

async function main(argv) {
    try {
        const png = await readPNG(argv[0]);
        
        startIndex = getArg(argv, '--start-index', x => parseInt(x, 10), 0);
        asTileData = getArg(argv, '--as-tile-data', null, 0);
        maxTiles = getArg(argv, '--max-tiles', x => parseInt(x, 10), 64);

        transparentColor = getArg(argv, '--transparent-color-index', x => parseInt(x, 10), -1);
        transparentIndex = transparentColor;

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

        // Just convert a paletted PNG to IIgs memory format.  We make sure that only a few widths
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
                writeToTileDataSource(buff, png.width / 2, maxTiles);
            }
            else {
                console.log(`; Writing to output file ${argv[1]}`);
                await writeBinayOutput(argv[1], buff);
            }
        }
    } catch (e) {
        console.log(`; ${e}`);
        process.exit(1);
    }
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
function buildTile(buff, width, x, y, transparentIndex = -1) {
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
        const mask = raw.map(h => toMask(h, transparentIndex));
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
        const mask = raw.map(h => toMask(h, transparentIndex));
        const data = raw.map((h, i) => h & ~mask[i]);

        tile.flipped.data.push(data);
        tile.flipped.mask.push(mask);
    }

    return tile;
}

function buildTiles(buff, width, transparentIndex = -1) {
    const tiles = [];

    const MAX_TILES = 240;

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= MAX_TILES) {
                return tiles;
            }
            const tile = buildTile(buff, width, x, y, transparentIndex);

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

function writeTilesToStream(stream, tiles, label='tiledata') {
    stream.write(`${label}    ENT\n`);
    stream.write('');
    stream.write('; Reserved space (tile 0 is special...)\n');
    stream.write('            ds 128\n');

    const MAX_TILES = 511;
    let count = 0;
    for (const tile of tiles.slice(0, MAX_TILES)) {
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

function buildMerlinCodeForTiles(tiles, label='tiledata') {
    const sb = new StringBuilder();
    sb.appendLine(`${label}    ENT`);
    sb.appendLine();
    sb.appendLine('; Reserved space (tile 0 is special...)');
    sb.appendLine('            ds 128');

    const MAX_TILES = 511;
    let count = 0;
    for (const tile of tiles.slice(0, MAX_TILES)) {
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

function writeToTileDataSource(buff, width, MAX_TILES = 64) {
    console.log('tiledata    ENT');
    console.log();
    console.log('; Reserved space (tile 0 is special...');
    console.log('            ds 128');

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= MAX_TILES) {
                return;
            }
            console.log('; Tile ID ' + (count + 1));
            console.log('; From image coordinates ' + (x * 2) + ', ' + y);

            const tile = buildTile(buff, width, x, y, transparentIndex);

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