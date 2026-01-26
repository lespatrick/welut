import path from 'node:path';
import fs from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import os from 'node:os';
import { nativeImage } from 'electron';

const execFileAsync = promisify(execFile);

let sharpModule: any = null;
async function getSharp() {
    if (process.platform === 'darwin') return null; // Don't use sharp on Mac
    if (!sharpModule) {
        try {
            sharpModule = (await import('sharp')).default;
        } catch (e) {
            console.error('Failed to load sharp:', e);
        }
    }
    return sharpModule;
}

// Helper to interact with the main process or purely logical
// This runs in the Main process (Node.js environment)

async function convertWithSips(inputPath: string): Promise<string> {
    const tempDir = os.tmpdir();
    const tempFile = path.join(tempDir, `welut_temp_${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`);

    try {
        await execFileAsync('sips', ['-s', 'format', 'jpeg', inputPath, '--out', tempFile]);
        return tempFile;
    } catch (error) {
        console.error('sips conversion failed:', error);
        throw new Error('Failed to convert RAW image using sips (macOS).');
    }
}

async function convertWithDcraw(inputPath: string): Promise<string> {
    const tempDir = os.tmpdir();
    // dcraw writes to stdout by default with -c, or we can use -T to write TIFF to same dir.
    // Let's use -c -T -w to write TIFF to stdout, then pipe to file? 
    // Actually execFile is easier if we let dcraw write to a file, but dcraw isn't great at specifying output path directly in CLI without piping.
    // Standard dcraw usage: `dcraw -T input.orf` -> creates `input.tiff` in same dir.
    // To avoid messing with user dir, let's copy input to temp, run dcraw there, return temp tiff.

    const tempInput = path.join(tempDir, `welut_raw_${Date.now()}_${Math.random().toString(36).slice(2)}${path.extname(inputPath)}`);

    try {
        await fs.copyFile(inputPath, tempInput);
        // -w: Use camera white balance
        // -T: Write TIFF instead of PPM
        // -6: Write 16-bit
        await execFileAsync('dcraw', ['-w', '-T', '-6', tempInput]);

        // Output will be same filename but .tiff
        const outputTiff = tempInput.replace(path.extname(tempInput), '.tiff');

        // Check if exists
        try {
            await fs.access(outputTiff);
        } catch {
            throw new Error('dcraw output file not found');
        }

        // Verify we can read it, then clean up input
        return outputTiff; // Caller responsible for cleanup
    } catch (error) {
        console.error('dcraw conversion failed:', error);
        // Try to clean up temp input if it exists
        try { await fs.unlink(tempInput); } catch { }
        throw new Error('Failed to convert RAW image using dcraw (Windows).');
    }
}

async function convertRaw(inputPath: string): Promise<string> {
    if (process.platform === 'darwin') {
        return convertWithSips(inputPath);
    } else if (process.platform === 'win32') {
        return convertWithDcraw(inputPath);
    } else {
        throw new Error(`Platform ${process.platform} not supported for RAW conversion fallback.`);
    }
}

// Helper to apply LUT buffer to Image buffer
function applyLutToBuffer(
    imgData: Buffer,
    imgChannels: number,
    lutData: Buffer,
    lutWidth: number,
    lutChannels: number,
    level: number,
    isBGRA: boolean = false
): Buffer {
    const outputBuffer = Buffer.alloc(imgData.length);
    const N = level;
    const N2 = N * N;

    for (let i = 0; i < imgData.length; i += imgChannels) {
        let r, g, b, a;
        if (isBGRA) {
            b = imgData[i];
            g = imgData[i + 1];
            r = imgData[i + 2];
            a = imgData[i + 3];
        } else {
            r = imgData[i];
            g = imgData[i + 1];
            b = imgData[i + 2];
            a = imgChannels === 4 ? imgData[i + 3] : 255;
        }

        const rNorm = (r / 255) * (N - 1);
        const gNorm = (g / 255) * (N - 1);
        const bNorm = (b / 255) * (N - 1);

        const rBase = Math.floor(rNorm);
        const gBase = Math.floor(gNorm);
        const bBase = Math.floor(bNorm);

        const r0 = Math.max(0, Math.min(N - 1, rBase));
        const g0 = Math.max(0, Math.min(N - 1, gBase));
        const b0 = Math.max(0, Math.min(N - 1, bBase));

        const lutIndex = r0 + g0 * N + b0 * N2;
        const lutY = Math.floor(lutIndex / lutWidth);
        const lutX = lutIndex % lutWidth;
        const lutPixelIndex = (lutY * lutWidth + lutX) * lutChannels;

        if (isBGRA) {
            outputBuffer[i] = lutData[lutPixelIndex]; // B
            outputBuffer[i + 1] = lutData[lutPixelIndex + 1]; // G
            outputBuffer[i + 2] = lutData[lutPixelIndex + 2]; // R
            outputBuffer[i + 3] = a;
        } else {
            outputBuffer[i] = lutData[lutPixelIndex];
            outputBuffer[i + 1] = lutData[lutPixelIndex + 1];
            outputBuffer[i + 2] = lutData[lutPixelIndex + 2];
            if (imgChannels === 4) {
                outputBuffer[i + 3] = a;
            }
        }
    }
    return outputBuffer;
}

async function processImageMac(inputPath: string, lutPath: string, outputPath: string): Promise<void> {
    let tempInputPath: string | null = null;
    try {
        // 1. Load LUT
        const lutImg = nativeImage.createFromPath(lutPath);
        if (lutImg.isEmpty()) throw new Error('Failed to load LUT image');
        const lutData = lutImg.toBitmap();
        const lutSize = lutImg.getSize();
        const level = Math.round(Math.pow(lutSize.width * lutSize.height, 1 / 3));

        // 2. Load Input
        let inputImg = nativeImage.createFromPath(inputPath);
        if (inputImg.isEmpty()) {
            console.log(`Input image empty, trying sips conversion: ${inputPath}`);
            // Try sips conversion for RAW
            tempInputPath = await convertWithSips(inputPath);
            console.log(`Sips conversion success: ${tempInputPath}`);
            inputImg = nativeImage.createFromPath(tempInputPath);
            if (inputImg.isEmpty()) {
                const stats = await fs.stat(tempInputPath);
                throw new Error(`Failed to load image after sips conversion. Temp file size: ${stats.size} bytes`);
            }
        }

        const imgData = inputImg.toBitmap();
        const imgSize = inputImg.getSize();

        // 3. Apply (nativeImage toBitmap is BGRA)
        const outputBuffer = applyLutToBuffer(imgData, 4, lutData, lutSize.width, 4, level, true);

        // 4. Save
        const resultImg = nativeImage.createFromBitmap(outputBuffer, { width: imgSize.width, height: imgSize.height });
        await fs.writeFile(outputPath, resultImg.toJPEG(90));
    } finally {
        if (tempInputPath) { try { await fs.unlink(tempInputPath); } catch (e) { } }
    }
}

export async function processImage(inputPath: string, lutPath: string, outputPath: string): Promise<void> {
    if (process.platform === 'darwin') {
        return processImageMac(inputPath, lutPath, outputPath);
    }

    const sharp = await getSharp();
    if (!sharp) throw new Error('Sharp not available');

    let tempInputPath: string | null = null;
    try {
        // 1. Load LUT
        const { data: lutData, info: lutInfo } = await sharp(lutPath).raw().toBuffer({ resolveWithObject: true });
        const lutWidth = lutInfo.width;
        const lutHeight = lutInfo.height;
        const level = Math.round(Math.pow(lutWidth * lutHeight, 1 / 3));

        if (Math.abs(level * level * level - lutWidth * lutHeight) > 10) { throw new Error('Invalid LUT'); }

        // 2. Load Input
        let imgData: Buffer, imgInfo: any;
        try {
            // Direct load attempt
            const image = sharp(inputPath);
            await image.metadata();
            const res = await image.raw().toBuffer({ resolveWithObject: true });
            imgData = res.data;
            imgInfo = res.info;
        } catch (e) {
            // Fallback to platform-specific converter
            try {
                tempInputPath = await convertRaw(inputPath);
                const res = await sharp(tempInputPath).raw().toBuffer({ resolveWithObject: true });
                imgData = res.data;
                imgInfo = res.info;
            } catch (conversionError) {
                // If conversion also fails, throw original or new error
                console.error('Fallback conversion failed:', conversionError);
                throw e;
            }
        }

        // 3. Apply
        const outputBuffer = applyLutToBuffer(imgData, imgInfo.channels, lutData, lutWidth, lutInfo.channels, level);

        // 4. Save
        await sharp(outputBuffer, { raw: { width: imgInfo.width, height: imgInfo.height, channels: imgInfo.channels } })
            .toFormat('jpeg', { quality: 90 })
            .toFile(outputPath);

    } catch (error) {
        console.error('Processing error:', error);
        throw error;
    } finally {
        if (tempInputPath) { try { await fs.unlink(tempInputPath); } catch (e) { } }
    }
}

async function generatePreviewSips(inputPath: string, width: number): Promise<string> {
    const tempDir = os.tmpdir();
    const tempFile = path.join(tempDir, `welut_preview_${Date.now()}_${Math.random().toString(36).slice(2)}.jpg`);
    try {
        // -Z: Resample image so that its larger dimension (width or height) is no larger than the given value.
        await execFileAsync('sips', ['-Z', width.toString(), inputPath, '--out', tempFile, '-s', 'format', 'jpeg']);
        const buffer = await fs.readFile(tempFile);
        return `data:image/jpeg;base64,${buffer.toString('base64')}`;
    } catch (error) {
        console.error('sips preview failed:', error);
        // Fallback to nativeImage if sips fails (might happen for some JPEG variants sips doesn't like)
        const img = nativeImage.createFromPath(inputPath);
        if (img.isEmpty()) throw error;
        return img.resize({ width }).toDataURL();
    } finally {
        try { await fs.unlink(tempFile); } catch { }
    }
}

export async function generatePreview(inputPath: string, width: number = 800): Promise<string> {
    if (process.platform === 'darwin') {
        const ext = path.extname(inputPath).toLowerCase();
        const isRaw = ['.orf', '.cr2', '.nef', '.arw', '.dng'].includes(ext);
        if (isRaw) {
            return generatePreviewSips(inputPath, width);
        } else {
            const img = nativeImage.createFromPath(inputPath);
            if (img.isEmpty()) return generatePreviewSips(inputPath, width);
            return img.resize({ width }).toDataURL();
        }
    }

    const sharp = await getSharp();
    if (!sharp) throw new Error('Sharp not available');

    let tempInputPath: string | null = null;
    let image: any;

    try {
        try {
            image = sharp(inputPath);
            await image.metadata(); // Check if readable
        } catch (e) {
            try {
                const converted = await convertRaw(inputPath);
                tempInputPath = converted;
                image = sharp(converted);
            } catch (conversionError) {
                throw e;
            }
        }

        const buffer = await image
            .resize(width, null, { fit: 'inside', withoutEnlargement: true }) // custom preview size
            .jpeg({ quality: 80 })
            .toBuffer();

        return `data:image/jpeg;base64,${buffer.toString('base64')}`;

    } catch (error) {
        console.error('Error generating preview:', error);
        throw error;
    } finally {
        if (tempInputPath) {
            try { await fs.unlink(tempInputPath); } catch (e) { }
        }
    }
}

async function generateLutPreviewMac(inputPath: string, lutPath: string): Promise<string> {
    let tempInputPath: string | null = null;
    try {
        // 1. Load LUT
        const lutImg = nativeImage.createFromPath(lutPath);
        if (lutImg.isEmpty()) throw new Error('Failed to load LUT');
        const lutData = lutImg.toBitmap();
        const lutSize = lutImg.getSize();
        const level = Math.round(Math.pow(lutSize.width * lutSize.height, 1 / 3));

        // 2. Load Input (Resize FIRST for speed)
        let inputImg = nativeImage.createFromPath(inputPath);
        if (inputImg.isEmpty()) {
            console.log(`Input image empty for preview, trying sips: ${inputPath}`);
            tempInputPath = await convertWithSips(inputPath);
            console.log(`Sips conversion success for preview: ${tempInputPath}`);
            inputImg = nativeImage.createFromPath(tempInputPath);
            if (inputImg.isEmpty()) {
                const stats = await fs.stat(tempInputPath);
                throw new Error(`Failed to load image for preview. Temp file size: ${stats.size} bytes`);
            }
        }

        // Resize
        const resizedImg = inputImg.resize({ width: 800 });
        const imgData = resizedImg.toBitmap();
        const imgSize = resizedImg.getSize();

        // 3. Apply
        const outputBuffer = applyLutToBuffer(imgData, 4, lutData, lutSize.width, 4, level, true);

        // 4. Return as Data URL
        const resultImg = nativeImage.createFromBitmap(outputBuffer, { width: imgSize.width, height: imgSize.height });
        return resultImg.toDataURL();
    } finally {
        if (tempInputPath) { try { await fs.unlink(tempInputPath); } catch (e) { } }
    }
}

export async function generateLutPreview(inputPath: string, lutPath: string): Promise<string> {
    if (process.platform === 'darwin') {
        return generateLutPreviewMac(inputPath, lutPath);
    }

    const sharp = await getSharp();
    if (!sharp) throw new Error('Sharp not available');

    let tempInputPath: string | null = null;
    try {
        // 1. Load LUT
        const { data: lutData, info: lutInfo } = await sharp(lutPath).raw().toBuffer({ resolveWithObject: true });
        const level = Math.round(Math.pow(lutInfo.width * lutInfo.height, 1 / 3));

        // 2. Load Input (Resize FIRST for speed)
        let image: any;
        try {
            image = sharp(inputPath);
            await image.metadata();
        } catch (e) {
            try {
                tempInputPath = await convertRaw(inputPath);
                image = sharp(tempInputPath);
            } catch (conversionError) { throw e; }
        }

        // Resize to small preview buffer
        const { data: imgData, info: imgInfo } = await image
            .resize(800, null, { fit: 'inside', withoutEnlargement: true })
            .raw()
            .toBuffer({ resolveWithObject: true });

        // 3. Apply LUT
        const outputBuffer = applyLutToBuffer(imgData, imgInfo.channels, lutData, lutInfo.width, lutInfo.channels, level, false);

        // 4. Save to Buffer (JPEG)
        const jpgBuffer = await sharp(outputBuffer, { raw: { width: imgInfo.width, height: imgInfo.height, channels: imgInfo.channels } })
            .jpeg({ quality: 80 })
            .toBuffer();

        return `data:image/jpeg;base64,${jpgBuffer.toString('base64')}`;
    } catch (error) {
        console.error('LUT Preview error:', error);
        throw error;
    } finally {
        if (tempInputPath) { try { await fs.unlink(tempInputPath); } catch (e) { } }
    }
}
