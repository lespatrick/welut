import { app, dialog } from 'electron';
import path from 'node:path';
import fs from 'node:fs/promises';
import { randomUUID } from 'node:crypto';

export interface LutItem {
    id: string;
    name: string;
    path: string; // Absolute path to the copy
}

interface StoreData {
    luts: LutItem[];
}

export class Store {
    private dataPath: string;
    private lutsDir: string;
    private data: StoreData = { luts: [] };

    constructor() {
        const userDataPath = app.getPath('userData');
        this.dataPath = path.join(userDataPath, 'luts.json');
        this.lutsDir = path.join(userDataPath, 'luts');
    }

    async init() {
        try {
            await fs.mkdir(this.lutsDir, { recursive: true });
            const content = await fs.readFile(this.dataPath, 'utf-8');
            this.data = JSON.parse(content);
        } catch (error) {
            // If file doesn't exist, start fresh
            this.data = { luts: [] };
        }
        await this.syncDefaultLuts();
    }

    private async syncDefaultLuts() {
        // Look for LUTs in bundled resources
        const bundledLutsDir = app.isPackaged
            ? path.join(process.resourcesPath, 'luts')
            : path.join(app.getAppPath(), 'resources', 'luts');

        try {
            const files = await this.getFilesRecursive(bundledLutsDir);
            let added = false;
            for (const filePath of files) {
                if (filePath.toLowerCase().endsWith('.png')) {
                    const relativePath = path.relative(bundledLutsDir, filePath);
                    const name = path.parse(relativePath).name;
                    const dirName = path.dirname(relativePath);
                    const displayName = dirName === '.' ? name : `${dirName}/${name}`;

                    // Check if already exists in store
                    if (this.data.luts.some(l => l.name === displayName)) {
                        continue;
                    }

                    const id = randomUUID();
                    const destFilename = `${id}.png`;
                    const destPath = path.join(this.lutsDir, destFilename);

                    await fs.copyFile(filePath, destPath);
                    this.data.luts.push({ id, name: displayName, path: destPath });
                    added = true;
                }
            }
            if (added) {
                await this.save();
            }
        } catch (e) {
            console.error('Failed to sync default luts', e);
        }
    }

    private async getFilesRecursive(dir: string): Promise<string[]> {
        const entries = await fs.readdir(dir, { withFileTypes: true });
        const files = await Promise.all(entries.map((entry) => {
            const res = path.resolve(dir, entry.name);
            return entry.isDirectory() ? this.getFilesRecursive(res) : res;
        }));
        return Array.prototype.concat(...files);
    }

    async save() {
        await fs.writeFile(this.dataPath, JSON.stringify(this.data, null, 2));
    }

    getLuts(): LutItem[] {
        return this.data.luts;
    }

    async importLut(): Promise<LutItem | null> {
        const result = await dialog.showOpenDialog({
            properties: ['openFile'],
            filters: [{ name: 'PNG Image', extensions: ['png'] }]
        });

        if (result.canceled || result.filePaths.length === 0) {
            return null;
        }

        const sourcePath = result.filePaths[0];
        const filename = path.basename(sourcePath);
        const name = path.parse(filename).name;
        // Generate unique filename to avoid collisions
        const id = randomUUID();
        const destFilename = `${name}_${id}.png`;
        const destPath = path.join(this.lutsDir, destFilename);

        await fs.copyFile(sourcePath, destPath);

        const newItem: LutItem = {
            id,
            name,
            path: destPath
        };

        this.data.luts.push(newItem);
        await this.save();

        return newItem;
    }

    async deleteLut(id: string): Promise<boolean> {
        const index = this.data.luts.findIndex(l => l.id === id);
        if (index === -1) return false;

        const item = this.data.luts[index];

        try {
            await fs.unlink(item.path);
        } catch (e) {
            console.error(`Failed to delete file ${item.path}`, e);
            // removing from DB anyway
        }

        this.data.luts.splice(index, 1);
        await this.save();
        return true;
    }
}
