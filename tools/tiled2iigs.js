/**
 * Read an exported Tiled project in JSON format and produce Merlin32 output files with
 * GTE-compatible setup code wrapped around it.
 */
 const fs = require('fs');
 const path = require('path');
const { abort } = require('process');
 const process = require('process');
const StringBuilder = require('string-builder');
 const parser = require('xml2json');
 const png2iigs = require('./png2iigs');

 main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function toHex(h, width=4) {
    return h.toString(16).padStart(width, '0');
}

function hexToRbg(hex) {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [parseInt(result[1], 16), parseInt(result[2], 16), parseInt(result[3], 16)] : null;
}

async function readTileSet(workdir, tileset) {
    // Load up the PNG image
    const pngfile = path.resolve(path.join(workdir, tileset.image.source));
    console.log(`Reading PNG file from ${pngfile}`);
    const png = await png2iigs.readPNG(pngfile);

    // Find the index of the transparent color (if defined)
    console.log(`Looking for transparency...`);
    let transparentIndex = -1;
    if (tileset.image.trans) {
        const color = hexToRbg(tileset.image.trans);
        console.log(`Found color ${color} as transparent marker`);
        transparentIndex = png2iigs.findColorIndex(png, color);
        if (typeof transparentIndex !== 'number') {
            console.log('Could not find color in palette');
            console.log(png.palette);
            transparentIndex = -1;
        } else {
            console.log(`Transparent color palette index is ${transparentIndex}`);
        }
    }

    console.log(`Converting PNG to IIgs bitmap format...`);
    const buff = png2iigs.pngToIIgsBuff(png);

    console.log(`Building tiles...`);
    const tiles = png2iigs.buildTiles(buff, png.width / 2, transparentIndex);

    // Return the tiles
    return tiles;
}

function emitHeader() {
    const sb = new StringBuilder();
    sb.appendLine('; Tiled Map Export');
    sb.appendLine(';');
    sb.appendLine('; This is a generated file. Do not modify.');
    return sb.toString();
}

async function loadTileset(workdir, tileset) {
    const source = tileset.source;
    const filename = path.isAbsolute(source) ? source : path.join(workdir, source);

    const contents = fs.readFileSync(filename);
    return JSON.parse(parser.toJson(contents));
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

function writeTiles(filename, tiles) {
    const tileSource = png2iigs.buildMerlinCodeForTiles(tiles);
    fs.writeFileSync(filename, tileSource);
}

/**
 * Command line arguments
 * 
 * --output-dir : sets the output folder to write all assets into
 */
async function main(argv) {
    // Read in the JSON data
    const fullpath = path.resolve(argv[0]);
    const workdir = path.dirname(fullpath);

    const outdir = getArg(argv, '--output-dir', x => x, workdir);

    console.log(`Reading Tiled JSON file from ${fullpath}`);
    const raw = fs.readFileSync(fullpath);
    console.log(`Parsing JSON file...`);
    const doc = JSON.parse(raw);

    // Make sure it's a map format we can handle
    if (doc.infinite) {
        throw new Error('Cannot import infinite maps.');
    }

    // Require 8x8 tiles
    if (doc.tileheight !== 8 || doc.tilewidth !== 8) {
        throw new Error('Only 8x8 tiles are supported');
    }

    // The total map size must be less than 32768 tiles because we limit the map to one data bank
    // and the tiles are stored in GTE as 16-bit values.
    if (doc.height * doc.width >= 32768) {
        throw new Error('The tile map must have less than 32,768 tiles');
    }

    // Look at the tile layers.  We support a maximum of two tile layers.
    const tileLayers = doc.layers.filter(l => l.type === 'tilelayer');
    if (tileLayers.length === 0) {
        throw new Error('There must be at least one tile layer defined for the map');
    }

    if (tileLayers.length > 2) {
        throw new Error('The map cannot have more than two tile layers');
    }

    // Sort the tile layers by ID.  The lower ID is considered to be the "front" layer
    tileLayers.sort((first, second) => first.id - second.id);

    // Load up any/all tilesets
    const tileSets = await Promise.all(doc.tilesets.map(tileset => loadTileset(workdir, tileset)));

    // Save all of the tilesets
    let bg0TileSet = null;

    for (const record of tileSets) {
        console.log(`Importing tileset "${record.tileset.name}"`);
        const tiles = await readTileSet(workdir, record.tileset);

        const outputFilename = path.resolve(path.join(outdir, record.tileset.name + '.s'));
        console.log(`Writing tiles to ${outputFilename}`);
        writeTiles(outputFilename, tiles);
        console.log(`Writing complete`);

        bg0TileSet = tiles;
    }

    // Ok, looks good.  Write out the source code for the layers
    console.log('Generating data for front layer (BG0): ' + tileLayers[0].name);
    const header = emitHeader();
    const bg0 = emitBG0Layer(tileLayers[0], bg0TileSet);

    const bg0OutputFilename = path.resolve(path.join(outdir, tileLayers[0].name + '.s'));
    console.log(`Writing BG0 data to ${bg0OutputFilename}`);
    fs.writeFileSync(bg0OutputFilename, header + '\n' + bg0);
    console.log(`Writing complete`);

    if (tileLayers.length > 1) {
        console.log('Generating data for back layer (BG1): ' + tileLayers[1].name);
        const bg1 = emitBG1Layer(tileLayers[1], bg0TileSet);
        const bg1OutputFilename = path.resolve(path.join(outdir, tileLayers[1].name + '.s'));
        console.log(`Writing BG1 data to ${bg1OutputFilename}`);
        fs.writeFileSync(bg1OutputFilename, header + '\n' + bg1);
        console.log(`Writing complete`);
    }
}

function emitBG1Layer(layer, tileset) {
    const sb = new StringBuilder();

    const label = layer.name.split(' ').join('_').split('.').join('_');
    const initCode = `
BG1SetUp
        lda #${layer.width}
        sta BG1TileMapWidth
        lda #${layer.height}
        sta BG1TileMapHeight
        lda #${label}
        sta BG1TileMapPtr
        lda #^${label}
        sta BG1TileMapPtr+2
        rts
    `;
    sb.appendLine(initCode);
    sb.appendLine(`${label}`);
    emitLayerData(sb, layer, tileset);

    return sb.toString();
}

function emitBG0Layer(layer, tileset) {
    const sb = new StringBuilder();

    const label = layer.name.split(' ').join('_').split('.').join('_');
    const initCode = `
BG0SetUp
        lda #${layer.width}
        sta TileMapWidth
        lda #${layer.height}
        sta TileMapHeight
        lda #${label}
        sta TileMapPtr
        lda #^${label}
        sta TileMapPtr+2
        rts
    `;
    sb.appendLine(initCode);
    sb.appendLine(`${label}`);
    emitLayerData(sb, layer, tileset);

    return sb.toString();
}

function emitLayerData(sb, layer, tileset) {
    // Print out the data in groups of N
    const N = 16;
    const chunks = [];
    const tileIDs = layer.data;
    for (let i = 0; i < tileIDs.length; i += N) {
        chunks.push(tileIDs.slice(i, i + N).map(tID => convertTileID(tID, tileset)))
    }
    // Tiled starts numbering its tiles at 1. This is OK since Tile 0 is reserved in
    // GTE, also
    for (const chunk of chunks) {
        sb.appendLine('        dw ' + chunk.map(id => '$' + toHex(id, 4)).join(','));
    }

    return sb;
}

/**
 * Map the bit flags used in Tiled to compatible values in GTE
 */
function convertTileID(tileId, tileset) {
    const GTE_MASK_BIT  = 0x1000;
    const GTE_VFLIP_BIT = 0x0400;
    const GTE_HFLIP_BIT = 0x0200;
    const TILED_VFLIP_BIT = 0x40000000;
    const TILED_HFLIP_BIT = 0x80000000;
    const TILED_DFLIP_BIT = 0x20000000;

    // We don't support the flipped diagonally flag or tile values greater than 511
    if ((tileId & TILED_DFLIP_BIT) !== 0) {
        throw new Error('Diagonally flipped bits are not supported: tileId =  ' + tileId.toString(16));
    }

    const hflip = (tileId & TILED_HFLIP_BIT) !== 0;
    const vflip = (tileId & TILED_VFLIP_BIT) !== 0;

    // Mask out the flip bits
    const tileIndex = tileId & 0x1FFFFFFF;
    if (tileIndex > 511) {
        throw new Error('A maximum of 511 tiles are supported');
    }

    let mask_bit = false;
    try {
        mask_bit = !tileset[tileIndex].isSolid;
    } catch (e) {
        console.log(tileId, tileIndex, tileset.length, tileset[tileIndex]);
        throw e;
    }

    return (tileId & 0x1FFFFFFF) + (mask_bit ? GTE_MASK_BIT : 0) + (hflip ? GTE_HFLIP_BIT : 0) + (vflip ? GTE_VFLIP_BIT : 0);
}