/**
 * Read an exported Tiled project in JSON format and produce Merlin32 output files with
 * GTE-compatible setup code wrapped around it.
 */
 const fs = require('fs').promises;
 const process = require('process');
 const { Buffer } = require('buffer');
 
 main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function emitHeader() {
    console.log('; Tiled Map Export');
    console.log(';');
    console.log('; This is a generated file. Do not modify.');
}

async function main(argv) {
    // Read in the JSON data
    const doc = JSON.parse(await fs.readFile(argv[0]));

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
    tileLayers.sort((first, second) => first.id <= second.id);

    // Ok, looks good.  Write out the source code
    emitHeader();
    emitBG0Layer(tileLayers[0]);
    if (tileLayers.length > 1) {
        emigBG1Layer(tileLayers[1]);
    }
}

function emitBG0Layer(layer) {
    const label = layer.name.split(' ').join('_');
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
    console.log(initCode);
    console.log(`${label}`);

    // Print out the data in groups of N
    const N = 16;
    const chunks = [];
    const tileIDs = layer.data;
    for (let i = 0; i < tileIDs.length; i += N) {
        chunks.push(tileIDs.slice(i, i + N))
    }
    for (const chunk of chunks) {
        console.log('        dw ' + chunk.join(','));
    }
}