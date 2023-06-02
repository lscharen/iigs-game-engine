// Generate seizzle tables
//
// Maps an 8-bit value of wwxxyyzz to a lookup table that takes each 2-bit
// value to a 16-bit pixel index.  Zero always maps to zero.  The input 
// is three 4-bit values that define the targets for 1, 2, and 3.

// Run as: node swizzle.js label val1 val2 val3
if (process.argv.length !== 6) {
    console.log(process.argv);
    process.exit(1);
}

const output = process.stdout;

const values = [
    0,
    Number(process.argv[3]),
    Number(process.argv[4]),
    Number(process.argv[5]),
];

output.write(process.argv[2] + '\n');
for (let w = 0; w < 4; w++) {
    for (let x = 0; x < 4; x++) {
        output.write('     dw  ');
        const row = [];
        for (let y = 0; y < 4; y++) {
            for (let z = 0; z < 4; z++) {
                // Because the NES PPU bits define the pixel order from high bit to low bit, but the
                // 65816 is little endian, we need to swap the byte order in the mapping
                /*
                const target =
                    (values[w] * 4096) +
                    (values[x] * 256) +
                    (values[y] * 16) +
                    values[z];
                */
                const target =
                    (values[w] * 16) +
                    (values[x] * 1) +
                    (values[y] * 4096) +
                    (values[z] * 256);

                row.push(target);
            }
        }
        // Output the values
        output.write(row.map(s => '$' + s.toString(16).padStart(4, '0')).join(','));

        // Line break
        output.write('\n');
    }
}

