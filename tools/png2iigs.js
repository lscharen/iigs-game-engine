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
    let mask = true;
    let index = -1;
    for (let i = 0; i < png.palette.length; i += 1) {
        const color = png.palette[i].slice(0, pixel.length); // Handle RGB or RGBA
        if (color.every((c, idx) => c === pixel[idx])) {
            if (i === options.transparentIndex) {
                mask = false;
            }
            index = i + options.startIndex;
        }
    }

    if (index === -1) {
        return [null, mask];
    }

    if (options.paletteMap) {
        index = options.paletteMap[index];
    }

    return [index, mask];
}

function pngToIIgsBuff(options, png) {
    let i = 0;
    const buff = Buffer.alloc(png.height * (png.width / 2), 0);
    const mask = Buffer.alloc(png.height * (png.width / 2), 0);
    for (let y = 0; y < png.height; y += 1) {
        for (let x = 0; x < png.width; x += 1, i += 4) {
            const pixel = png.data.slice(i, i + 4);
            const [index, ismask] = findColorIndex(options, png, pixel);
            const j = y * (png.width / 2) + Math.floor(x / 2);

            if (index > 15) {
                console.warn('; Pixel index greater than 15. Skipping...');
                continue;
            }

            if (x % 2 === 0) {
                buff[j] = 16 * index;
                mask[j] = ismask ? 0 : 240;
            }
            else {
                buff[j] = buff[j] | index;
                mask[j] = mask[j] | (ismask ? 0 : 15);
            }
        }
    }
    
    return [buff, mask];
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

function findClosestColor(color, palette) {
    if (!palette || palette.length === 0) {
        return -1;
    }

    const target = palette.map(p => hexStringToPalette(p));
    const rgb = hexStringToPalette(color);

    const dist = (a, b) => Math.pow(a[0] - b[0], 2) + Math.pow(a[1] - b[1], 2) + Math.pow(a[2] - b[2], 2);
    const diff = target.map(t => dist(rgb, t));

    return diff.indexOf(Math.min(...diff));
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
    options.verbose = getArg(argv, '--verbose', x => true, false);
    options.maxTiles = getArg(argv, '--max-tiles', x => parseInt(x, 10), 511);
    options.transparentIndex = getArg(argv, '--transparent-color-index', x => parseInt(x, 10), -1);
    options.transparentColor = getArg(argv, '--transparent-color', x => x, null);
    options.backgroundColor = getArg(argv, '--background-color', x => x, null);
    options.targetPalette = getArg(argv, '--palette', x => x.split(',').map(c => hexStringToPalette(c)), null);
    options.forceMatch = getArg(argv, '--force-color-match', x => true, false);
    options.forceWordAlignment = getArg(argv, '--force-word-alignment', x => true, false);
    options.format = getArg(argv, '--format', x => x, 'asm65816');  // asm65816 or orcac or rez
    options.varName = getArg(argv, '--var-name', x => x, 'tiles');  // language-specific label to reference tile data

    return options;
}

// Two steps here.
//   First, the transparent color always gets mapped to Index 0 in the target palette
//   Second, if a target palette is not explicit, then we create one based on the source

function getPaletteMap(options, png) {
    // Get the RGB triplets from the palette
    const sourcePalette = png.palette;
    const paletteCSSTripplets = sourcePalette.map(c => paletteToHexString(c));

    if (options.verbose) {
        console.warn('Source palette: ', paletteCSSTripplets.join(', '));
    }

    // Start with an identity map
    const paletteMap = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

    // If there is a transparent color / color index, make sure it gets swapped to index 0
    // If no target palette was passed in, swap the palette from the source copy, too
    if (options.transparentIndex > 0) {
        paletteMap[options.transparentIndex] = 0;
    }
    if (options.transparentColor !== null) {
        const index = paletteCSSTripplets.findIndex(p => p === options.transparentColor);
        if (index !== -1) {
            options.transparentIndex = index;
            paletteMap[index] = 0;
        } else {
            console.warn(`; transparent color defined, ${options.transparentColor}, but not found in image`);
        }
    }

    // If a target palette is not provided, build one from the source and (optional) transparentIndex\
    let targetPalette;
    if (!options.targetPalette) {
        targetPalette = [...sourcePalette];
        if (options.transparentIndex > 0) {
            const tmp = targetPalette[options.transparentIndex];
            targetPalette[options.transparentIndex] = targetPalette[0];
            targetPalette[0] = tmp;
        }
    } else {
        targetPalette = options.targetPalette;
    }

    // Match up the source palette with the target palette
    const targetTriplets = targetPalette.map(c => paletteToHexString(c));
    if (options.verbose) {
        console.warn('Target palette: ', targetTriplets.join(', '));
    }

    paletteCSSTripplets.forEach((color, i) => {
        if (i !== options.transparentIndex) {
            const j = options.forceMatch
            ? findClosestColor(color, targetTriplets)
            : targetTriplets.findIndex(p => p === color);

            if (j !== -1) {
                console.warn(`Assigned color index ${i} (${color}) to the target palette index ${j}`);
                paletteMap[i] = j;
            } else {
                console.warn(`Could not map color index ${i} (${color}) to the target palette`);
            }
        }
    });

    return {
        paletteMap,
        sourcePalette,
        targetPalette
    };
}

function writeComment(options, message, logger=console.log) {
    switch (options.format) {
        case 'orcac':
            logger(`/* ${message} */`);
            break;
        default:
            logger(`; ${message}`);
    }
}

function writePaletteArray(options, palette, logger=console.log) {
    switch (options.format) {
        case 'orcac': {
            const hexCodes = palette.map(c => '0x' + paletteToIIgs(c));
            if (options.backgroundColor !== null) {
                hexCodes[0] = '0x' + paletteToIIgs(hexStringToPalette(options.backgroundColor));
            }
            logger('#include <types.h>');
            logger('');
            logger(`Word ${options.varName}Palette[16] = {`);
            logger(`    ${hexCodes.join(',')}`);
            logger(`};`);
            break;
        }
        default: {
            const hexCodes = palette.map(c => '$' + paletteToIIgs(c));
            // The transparent color is always mapped into color 0, so if a background color is set it goes into index 0
            if (options.backgroundColor !== null) {
                hexCodes[0] = '$' + paletteToIIgs(hexStringToPalette(options.backgroundColor));
            }
            logger('TileSetPalette ENT');
            logger('               dw   ', hexCodes.join(','));
        }
    }
}

async function main(argv) {
    // try {
        const png = await readPNG(argv[0]);
        const options = getOptions(argv);

        writeComment(options, `startIndex = ${options.startIndex}`);
        if (png.colorType !== 3) {
            writeComment(options, `PNG must be in palette color type`, logger.warn);
            return;
        }

        if (png.palette.length > 16) {
            writeComment(options, `Too many colors.  Must be 16 or less`, logger.warn);
            return;
        }

        if (options.palette && options.palette.length > 16) {
            writeComment(options, `Too many colors on command line.  Must be 16 or less`, logger.warn);
            return;
        }

        // Get the RGB triplets from the palette
        const { targetPalette, paletteMap } = getPaletteMap(options, png);
        options.paletteMap = paletteMap;

        // Dump the palette in IIgs hex format
        writeComment(options, `Palette`);
        writePaletteArray(options, targetPalette);

        // Just convert a paletted PNG to IIgs memory format.  We make sure that only a few widths
        // are supported
        let buff = null;
        let mask = null;

        console.log('');
        writeComment(options, `Converting to BG0 format...`);
        [buff, mask] = pngToIIgsBuff(options, png);

        if (buff && argv[1]) {
            if (options.asTileData) {
                writeToTileDataSource(options, buff, mask, png.width / 2);
            }
            else {
                writeComment(options, `Writing to output file ${argv[1]}`);
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
 * 
 * Options: 'force-word-alignment' forces the tile values to have masks of
 *           $FFFF or $0000 only
 */
function buildTile(options, buff, _mask, width, x, y) {
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

        const mask0 = _mask[offset + dy * width + 0];
        const mask1 = _mask[offset + dy * width + 1];
        const mask2 = _mask[offset + dy * width + 2];
        const mask3 = _mask[offset + dy * width + 3];

        const data = [hex0, hex1, hex2, hex3];
        const mask = [mask0, mask1, mask2, mask3]; // raw.map(h => toMask(h, options.transparentIndex));
        // const data = raw.map((h, i) => h & ~mask[i]);

        if (options.forceWordAlignment) {
            if (mask[0] != 255 || mask[1] != 255) {
                mask[0] = 0;
                mask[1] = 0;
            }
            if (mask[2] != 255 || mask[3] != 255) {
                mask[2] = 0;
                mask[3] = 0;
            }
        }

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

        const mask0 = swap(_mask[offset + dy * width + 0]);
        const mask1 = swap(_mask[offset + dy * width + 1]);
        const mask2 = swap(_mask[offset + dy * width + 2]);
        const mask3 = swap(_mask[offset + dy * width + 3]);

        const data = [hex3, hex2, hex1, hex0];
        const mask = [mask3, mask2, mask1, mask0]; // raw.map(h => toMask(h, options.transparentIndex));
        // const data = raw.map((h, i) => h & ~mask[i]);

        if (options.forceWordAlignment) {
            if (mask[0] != 255 || mask[1] != 255) {
                mask[0] = 0;
                mask[1] = 0;
            }
            if (mask[2] != 255 || mask[3] != 255) {
                mask[2] = 0;
                mask[3] = 0;
            }
        }

        tile.flipped.data.push(data);
        tile.flipped.mask.push(mask);
    }

    return tile;
}

function buildTiles(options, buff, mask, width) {
    const tiles = [];

    let count = 0;
    for (let y = 0; ; y += 8) {
        for (let x = 0; x < width; x += 4, count += 1) {
            if (count >= options.maxTiles) {
                return tiles;
            }
            const tile = buildTile(options, buff, mask, width, x, y);

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

function writeTileToStreamORCAC(stream, data) {
    // Output the tile data
    for (const row of data) {
        const hex = row.map(d => toHex(d)).join('');
        stream.write('      0x' + hex + ',\n');
    }
}

function writeTilesToStream(options, stream, tiles, label='tiledata') {
    switch (options.format) {
        case 'orcac':
            writeTilesToStreamORCAC(options, stream, tiles, label);
            break;

        case 'asm65816':
            writeTilesToStreamASM65816(options, stream, tiles, label);
            break;

        default:
            throw `Unknown output format: ${options.format}`;
    }
}

function writeTilesToStreamORCAC(options, stream, tiles, label='tiledata') {
    stream.write(`long ${options.varName}[] = {\n`);
    stream.write('/* Reserved space (tile 0 is special...) */\n');
    for (let i = 0; i < 8; i += 1) {
        stream.write('    0x00000000L,0x00000000L,0x00000000L,0x00000000L,\n');
    }
    stream.write('\n');

    let count = 0;
    for (const tile of tiles.slice(0, options.maxTiles)) {
        stream.write(`/* Tile ID ${count + 1}, isSolid: ${tile.isSolid} */\n`);
        writeTileToStreamORCAC(stream, tile.normal.data);
        writeTileToStreamORCAC(stream, tile.normal.mask);
        writeTileToStreamORCAC(stream, tile.flipped.data);
        writeTileToStreamORCAC(stream, tile.flipped.mask);
        stream.write('\n');

        count += 1;
    }
    stream.write('};\n');
    stream.write('\n');
}

function writeTilesToStreamASM65816(options, stream, tiles, label='tiledata') {
    stream.write(`${options.varName}    ENT\n`);
    stream.write('');
    stream.write('; Reserved space (tile 0 is special...)\n');
    stream.write('            ds 128\n');

    let count = 0;
    for (const tile of tiles.slice(0, options.maxTiles)) {
        stream.write(`; Tile ID ${count + 1}, isSolid: ${tile.isSolid}\n`);
        writeTileToStream(stream, tile.normal.data);
        writeTileToStream(stream, tile.normal.mask);
        writeTileToStream(stream, tile.flipped.data);
        writeTileToStream(stream, tile.flipped.mask);
        stream.write('\n');

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

function writeToTileDataSource(options, buff, mask, width) {
    const stream = process.stdout;

    // Build the tiles
    const tiles = buildTiles(options, buff, mask, width);

    // Write them to the default output stream
    writeTilesToStream(options, stream, tiles, options.varName);
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
    getPaletteMap,
    paletteToIIgs,
    pngToIIgsBuff,
    readPNG,
    toHex,
    writeBinayOutput,
    writeToTileDataSource,
    writeTilesToStream
}