/**
 * Read an exported Tiled project in JSON format and produce Merlin32 output files with
 * GTE-compatible setup code wrapped around it.
 */
const fs = require('fs');
const path = require('path');
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
        transparentIndex = png2iigs.findColorIndex(GLOBALS.options, png, color);
        if (typeof transparentIndex !== 'number') {
            console.log('Could not find color in palette');
            console.log(png.palette);
            transparentIndex = -1;
        } else {
            console.log(`Transparent color palette index is ${transparentIndex}`);
        }
    }

    console.log(`Converting PNG to IIgs bitmap format...`);
    const buff = png2iigs.pngToIIgsBuff(GLOBALS.options, png);

    console.log(`Building tiles...`);
    const tiles = png2iigs.buildTiles(GLOBALS.options, buff, png.width / 2, transparentIndex);

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

function writeTileAnimations(filename, animations) {
    const init = new StringBuilder();
    const scripts = new StringBuilder();

    // First step is some initialization code that copies the first animated
    // tile data into the dynamic tile space
    const initLabel = 'TileAnimInit';
    init.appendLine(`${initLabel}    ENT`);
    init.appendLine();
    for (const animation of animations) {
        // Get the first tile of the animation
        const firstTileId = animation.frames[0].tileId;

        // Create code to copy it into the dynamic tile index location
        init.appendLine('            ldx #' + firstTileId);
        init.appendLine('            ldy #' + animation.dynTileId);
        init.appendLine('            jsl CopyTileToDyn');
    }

    // Next, create the scripts to change the tile data based on the configured ticks delays. 
    for (const animation of animations) {
        // Get the animation frames
        const frames = animation.frames;

        // Look at the frames and get the number of ticks.  We only support a uniform animation period.
        const numTicks = frames.map(f => f.ticks).reduce((x, y) => Math.min(x, y),Infinity);
        if (frames.some(f => f.ticks !== numTicks)) {
            console.warn(`Animated tiles must have a uniform animation delay. Setting ticks to ${numTicks}`);
        }

        const label = `TileAnim_${animation.tileId}`;
        init.appendLine(`            lda #${label}`);
        init.appendLine(`            ldx #^${label}`);
        init.appendLine(`            ldy #${numTicks}`);
        init.appendLine(`            jsl StartScript`);

        //    bit 15     = 1 if the end of a sequence
        //    bit 14     = 0 proceed to next action, 1 jump
        //    bit 13     = 0 (Reserved)
        //    bit 12     = 0 (Reserved)
        //    bit 11 - 8 = signed jump displacement  F = -1, E = -2, D = -3, C = -4, B = -5, A = -6, 9 = -7, 8 = -8, 7 = 7, 6 = 6, ....
        //    bit 8  - 0 = command number
        const YIELD = 0x8000;
        const JUMP  = 0x4000;
        const SET_DYN_TILE = 0x0006;  // Command number

        scripts.appendLine(label);
        const lastValidIndex = frames.length - 1;
        for (let i = 0; i < frames.length ; i += 1) {
            const isLast = (i === lastValidIndex);
            let command = YIELD | SET_DYN_TILE;
            if (isLast) {
                command |=  JUMP;
                const offset = ((0x0010 - lastValidIndex) & 0x000F) * 256;
                command |= offset;
            }
            command = '$' + toHex(command, 4);

            // scripts.appendLine(`            ScriptStep #${command};#${frames[i].tileId};#${animation.dynTileId};#0`);
            scripts.appendLine(`            dw ${command},${frames[i].tileId},${animation.dynTileId},0`);
        }
    }

    init.appendLine('            rts');

    fs.writeFileSync(filename, init.toString() + scripts.toString());
}

function writeTiles(filename, tiles) {
    const tileSource = png2iigs.buildMerlinCodeForTiles(GLOBALS.options, tiles);
    fs.writeFileSync(filename, tileSource);
}

function findAnimatedTiles(tileset) {
    const animations = [];
    let dynTileId = 0;

    if (tileset.tile) {
        for (const tile of tileset.tile) {
            if (!tile.animation) {
                continue;
            }

            const tileId = parseInt(tile.id, 10);
            const frames = tile.animation.frame.map(f => {
                const millis = parseInt(f.duration, 10);
                const ticksPerMillis = 60. / 1000.;
                return {
                    tileId: parseInt(f.tileid, 10) + 1,         // The IDs in the XML file appear to be zero-based.  The JSON files appear to be one-based
                    ticks: Math.round(millis * ticksPerMillis),
                    millis
                };
            });

            animations.push({
                tileId,
                dynTileId,
                frames
            });

            dynTileId += 1;
            if (dynTileId > 31) {
                console.warn('Only 32 animated tiles are supported');
                break;
            }
        }
    }

    return animations;
}

// Global reference object
let GLOBALS = {
    options: {
        startIndex: 0,
        asTileData: true,
        maxTiles: 360,
        transparentColor: 'FF00FF',
        backgroundColor: '6B8CFF'
    }
};

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

    // Create a global reference object
    GLOBALS = {
        ...GLOBALS,
        outdir,
        tileSets,
        tileLayers
    };

    // Save all of the tilesets
    let bg0TileSet = null;

    for (const record of tileSets) {
        console.log('Looking for animated tiles...');
        const animations = findAnimatedTiles(record.tileset);
        console.log(`Importing tileset "${record.tileset.name}"`);
        const tiles = await readTileSet(workdir, record.tileset);

        const outputFilename = path.resolve(path.join(outdir, record.tileset.name + '.s'));
        console.log(`Writing tiles to ${outputFilename}`);
        writeTiles(outputFilename, tiles);
        console.log(`Writing complete`);

        // Look for tiles with animation sequences.  If found, this information need to be propagated
        // to the tilemap export to mark those tile IDs as Dynamic Tiles.
        //
        // Exporting the "animations" actually creates two code stubs; one to copy the first
        // tile of the animation into the dynamic tile space during initialization and a second
        // that created the timer callbacks that replace the tile data based on the time animation
        // rate.  We only have a VBL timer, so the animation time is rounded to the nearest
        // 1/60 of a second.
        if (animations.length > 0) {
            console.log('Writing tile animation ');
            const animationFilename = path.resolve(path.join(outdir, record.tileset.name + 'Anim.s'));
            writeTileAnimations(animationFilename, animations);
            console.log(`Writing complete`);

            // Modify the entries in the tileset that are animated
            for (const animation of animations) {
                tiles[animation.tileId].animation = animation;
            }
        }

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
    //
    // Merlin32 errors out with errno 3221226505 is the line is too long (>1047 characters)
    const N = 64;
    const rows = [];
    const tileIDs = layer.data;

    // Create cunks of chunks so we can put a break between logical rows
    for (let j = 0; j < tileIDs.length; j += layer.width) {
        const row = tileIDs.slice(j, j + layer.width);
        const chunks = [];
        for (let i = 0; i < row.length; i += N) {
            chunks.push(row.slice(i, i + N).map(tID => convertTileID(tID, tileset)))
        }
        rows.push(chunks);
    }

    // Tiled starts numbering its tiles at 1. This is OK since Tile 0 is reserved in
    // GTE, also
    for (const row of rows) {
        for (const chunk of row) {
            sb.appendLine('        dw ' + chunk.map(id => '$' + toHex(id, 4)).join(','));
        }
        sb.appendLine('');
    }

    return sb;
}

/**
 * Map the bit flags used in Tiled to compatible values in GTE
 * 
 * tileID is a value from the exported TileD data.  It starts at index 1.
 */
function convertTileID(tileId, tileset) {
    const GTE_MASK_BIT  = 0x1000;
    const GTE_DYN_BIT = 0x0800;
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
    if (tileIndex >= 512) {
        throw new Error('A maximum of 511 tiles are supported');
    }

    if (tileIndex === 0) {
        // This should be a warning
        return 0;
    }

    // The tileId starts at one, but the tile set starts at zero.  It's ok when we export,
    // because a special zero tile is inserted, but we have to manually adjust here
    if (!tileset[tileIndex - 1]) {
        throw new Error(`Tileset for tileId ${tileIndex} is underinfed`);
    }
    const mask_bit = (!tileset[tileIndex - 1].isSolid) && (GLOBALS.tileLayers.length !== 1);

    // Build up a partial set of control bits
    let control_bits = (mask_bit ? GTE_MASK_BIT : 0) + (hflip ? GTE_HFLIP_BIT : 0) + (vflip ? GTE_VFLIP_BIT : 0);

    // Check if this is an animated tile.  If so, substitute the index of the animation slot for
    // the tile ID
    if (tileset[tileIndex - 1].animation) {
        const animation = tileset[tileIndex - 1].animation;
        tileId = animation.dynTileId;
        control_bits = GTE_DYN_BIT;
    }

    return (tileId & 0x1FFFFFFF) + control_bits;
}