// Render our vector source, then encode the Pocket's rotated grayscale asset.
// Usage: node tools/build-platform-image.cjs
// Requires sharp (npm dependency, or provided via NODE_PATH).
// Format reference: https://www.analogue.co/developer/docs/packaging-a-core#graphical-asset-formats
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const asset = path.join(root, 'dist/platforms/_images');
const width = 521, height = 165;
(async () => {
  const {data: pixels, info} = await sharp(path.join(asset, 'virtualboy.svg'), {density: 288})
    .resize(width, height).flatten({background: '#000'}).greyscale()
    .raw().toBuffer({resolveWithObject: true});
  assert.equal(info.channels, 1);
  const packed = Buffer.alloc(width * height * 2);
  // Rotate 90 degrees CCW: rotated rows follow original columns right to left.
  // File bytes are brightness, 0, matching Analogue's template FF 00 pixels.
  for (let x = 0; x < width; x++) for (let y = 0; y < height; y++) {
    packed[2 * ((width - 1 - x) * height + y)] = pixels[y * width + x];
  }
  fs.writeFileSync(path.join(asset, 'virtualboy.bin'), packed);
  // Independent decode of the final file for visual verification and round trip.
  const loaded = fs.readFileSync(path.join(asset, 'virtualboy.bin'));
  const decoded = Buffer.alloc(width * height);
  let offset = 0;
  for (let column = width - 1; column >= 0; column--) {
    for (let row = 0; row < height; row++) {
      decoded[row * width + column] = loaded[offset++];
      assert.equal(loaded[offset++], 0);
    }
  }
  assert.deepEqual(decoded, pixels);
  await sharp(decoded, {raw: {width, height, channels: 1}})
    .png().toFile(path.join(asset, 'virtualboy-preview.png'));
  console.log(`PASS: ${width}x${height}, ${packed.length} bytes, exact BIN round trip.`);
})().catch(error => { console.error(error); process.exitCode = 1; });
