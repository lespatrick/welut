import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import sharp from 'sharp';
import path from 'path';
import fs from 'fs/promises';
import { processImage } from '../electron/imageProcessor';

describe('Image Processor', () => {
    const testDir = path.join(__dirname, 'temp');
    const inputPath = path.join(testDir, 'input.png');
    const lutPath = path.join(testDir, 'identity_lut.png');
    const outputPath = path.join(testDir, 'input_lut.jpg');

    beforeAll(async () => {
        await fs.mkdir(testDir, { recursive: true });

        // 1. Create a Level 4 Identity LUT (8x8 image = 64 pixels)
        // Level 4 means 4x4x4 cube.
        // R changes fastest, then G, then B?
        // Let's create a buffer.
        const N = 4;
        const buffer = Buffer.alloc(N * N * N * 3);
        let idx = 0;
        // Standard identity generation
        for (let b = 0; b < N; b++) {
            for (let g = 0; g < N; g++) {
                for (let r = 0; r < N; r++) {
                    buffer[idx++] = Math.round((r / (N - 1)) * 255);
                    buffer[idx++] = Math.round((g / (N - 1)) * 255);
                    buffer[idx++] = Math.round((b / (N - 1)) * 255);
                }
            }
        }

        await sharp(buffer, { raw: { width: N * N, height: N, channels: 3 } }) // 16x4? No. Width*Height = 64. 8x8.
            .raw() // wait, shape must match my processor expectation. 
            // Processor expects LutWidth * LutHeight = N^3.
            // Level 4 => 64 pixels. 8x8 is fine.
            // My generator above produced R-major sequence.
            // My processor maps: lutIndex = r + g*N + b*N*N.
            // This matches r varies fastest (stride 1), g (stride N), b (stride N*N).
            // And expects a 2D image where Y = floor(index/W), X = index%W.
            // So any rectangular shape W*H=64 works if sharp reads strictly linearly.
            .toFormat('png')
            .toFile(lutPath);

        // 2. Create Input Image (Solid Red)
        await sharp({
            create: {
                width: 10,
                height: 10,
                channels: 3,
                background: { r: 255, g: 0, b: 0 }
            }
        }).toFile(inputPath);
    });

    afterAll(async () => {
        // await fs.rm(testDir, { recursive: true, force: true });
    });

    it('should process image with identity LUT and preserve colors', async () => {
        await processImage(inputPath, lutPath, outputPath);

        const outputMetadata = await sharp(outputPath).metadata();
        expect(outputMetadata.width).toBe(10);
        expect(outputMetadata.height).toBe(10);

        // Check pixel color
        const stats = await sharp(outputPath).stats();
        // stats.channels[0].mean should be close to 255
        // JPEG compression might add noise, but Red should be dominant.

        expect(stats.channels[0].mean).toBeGreaterThan(240);
        expect(stats.channels[1].mean).toBeLessThan(20);
        expect(stats.channels[2].mean).toBeLessThan(20);
    });
});
