const path = require('path');
const fs = require('fs');
const archiver = require('archiver');

const rootDir = path.resolve(__dirname, 'build', 'staging');
const outDir = path.resolve(__dirname, 'out');
const outFile = 'Wholphin.zip';

if (!fs.existsSync(outDir)) { fs.mkdirSync(outDir, { recursive: true }); }

const output = fs.createWriteStream(path.join(outDir, outFile));
const archive = new archiver.ZipArchive({ zlib: { level: 9 } });

output.on('finish', () => {
    console.log('BUILD OK');
    process.exit(0);
});

output.on('error', (e) => {
    console.error('BUILD FAILED:', e.message);
    process.exit(1);
});

archive.on('error', (e) => {
    console.error('BUILD FAILED:', e.message);
    process.exit(1);
});

archive.pipe(output);

// Add all files from staging
archive.directory(rootDir, false);

archive.finalize().catch(e => {
    console.error('BUILD FAILED:', e.message);
    process.exit(1);
});
