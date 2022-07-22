/**
 * Generated data tables for BG1 scaling
 */
const RATIOS = [0.5, 0.63, 0.75, 0.87, 1.0, 1.125, 1.25, 1.375, 1.5, 1.66, 1.83, 2.0, 2.5, 3.0, 3.5, 4.0];
const NUM_SCALES = RATIOS.length;

main(process.argv.slice(2)).then(
    () => process.exit(0), 
    (e) => {
        console.error(e);
        process.exit(1);
    }
);

function toHex(n) {
    return '$' + n.toString(16).toUpperCase().padStart(4, '0');
}

async function main(argv) {

    const _ = console.log;

    for (let i = 0; i < NUM_SCALES; i += 1) {
        const arr = gen_scale_table(RATIOS[i]).map(n => toHex(n)).join(',');
        _(`Scale${i}   dw ${arr}`);
    }
}

function gen_scale_table(ratio) {
    // Take a bunch of values from 0 to 162 (82 total). Use the middle as a reference
    // and scale out based on the (inverse) ratio, e.g. a ratio of 2 will double the pixels
    const ref = Array.from({ length: 82 }, (_, i) => i * 2);
    const center = 40.5;
    const factor = 1. / ratio;

    const table = [];
    for (let i = 0; i < 82; i++) {

        let index = 2 * Math.floor(center + (factor * (i - center)));
        while (index < 0) {
            index += 162;
        }
        while (index > 162) {
            index -= 162;
        }
        table.push(index);
    }

    return table;
}
