import { app, BrowserWindow, ipcMain, dialog, Menu } from 'electron'
import fs from 'node:fs'

import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { processImage, generatePreview, generateLutPreview } from './imageProcessor'
import { Store } from './store'


const __dirname = path.dirname(fileURLToPath(import.meta.url))

// The built directory structure
process.env.APP_ROOT = path.join(__dirname, '..')

// 🚧 Use ['ENV_NAME'] avoid vite:define plugin - Vite@2.x
export const VITE_DEV_SERVER_URL = process.env['VITE_DEV_SERVER_URL']
export const MAIN_DIST = path.join(process.env.APP_ROOT, 'dist-electron')
export const RENDERER_DIST = path.join(process.env.APP_ROOT, 'dist')

process.env.VITE_PUBLIC = VITE_DEV_SERVER_URL ? path.join(process.env.APP_ROOT, 'public') : RENDERER_DIST

let win: BrowserWindow | null

function createWindow() {
  win = new BrowserWindow({
    icon: path.join(process.env.VITE_PUBLIC, 'electron-vite.svg'),
    width: 1024,
    height: 768,
    webPreferences: {
      preload: path.join(__dirname, 'preload.mjs'),
    },
  })

  // Test active push message to Renderer-process.
  win.webContents.on('did-finish-load', () => {
    win?.webContents.send('main-process-message', (new Date).toLocaleString())
  })

  if (VITE_DEV_SERVER_URL) {
    win.loadURL(VITE_DEV_SERVER_URL)
  } else {
    // win.loadFile('dist/index.html')
    win.loadFile(path.join(RENDERER_DIST, 'index.html'))
  }

  createMenu();
}

function showLicenseDialog() {
  const licensePath = path.join(process.env.APP_ROOT, 'LICENSE_ALL.txt');
  let licenseText = 'License information not available.';
  try {
    licenseText = fs.readFileSync(licensePath, 'utf-8');
  } catch (err) {
    console.error('Failed to read license file', err);
  }

  dialog.showMessageBox({
    type: 'info',
    title: 'License Information',
    message: 'Welut - License Information',
    detail: licenseText,
    buttons: ['OK']
  });
}

function createMenu() {
  const template: Electron.MenuItemConstructorOptions[] = [
    ...(process.platform === 'darwin' ? [{
      label: app.name,
      submenu: [
        { role: 'about' as const },
        { type: 'separator' as const },
        { label: 'License Information', click: showLicenseDialog },
        { type: 'separator' as const },
        { role: 'services' as const },
        { type: 'separator' as const },
        { role: 'hide' as const },
        { role: 'hideOthers' as const },
        { role: 'unhide' as const },
        { type: 'separator' as const },
        { role: 'quit' as const }
      ]
    }] : []),
    {
      label: 'File',
      submenu: [
        { role: 'quit' as const }
      ]
    },
    {
      label: 'Edit',
      submenu: [
        { role: 'undo' as const },
        { role: 'redo' as const },
        { type: 'separator' as const },
        { role: 'cut' as const },
        { role: 'copy' as const },
        { role: 'paste' as const }
      ]
    },
    {
      label: 'View',
      submenu: [
        { role: 'reload' as const },
        { role: 'forceReload' as const },
        { role: 'toggleDevTools' as const },
        { type: 'separator' as const },
        { role: 'resetZoom' as const },
        { role: 'zoomIn' as const },
        { role: 'zoomOut' as const },
        { type: 'separator' as const },
        { role: 'togglefullscreen' as const }
      ]
    },
    {
      label: 'Window',
      submenu: [
        { role: 'minimize' as const },
        { role: 'zoom' as const },
        ...(process.platform === 'darwin' ? [
          { type: 'separator' as const },
          { role: 'front' as const },
          { type: 'separator' as const },
          { role: 'window' as const }
        ] : [
          { role: 'close' as const }
        ])
      ]
    },
    {
      role: 'help',
      submenu: [
        {
          label: 'Learn More',
          click: async () => {
            const { shell } = await import('electron')
            await shell.openExternal('https://electronjs.org')
          }
        },
        ...(process.platform !== 'darwin' ? [
          { label: 'License Information', click: showLicenseDialog }
        ] : [])
      ]
    }
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
}

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit()
    win = null
  }
})

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow()
  }
})

app.whenReady().then(async () => {
  const store = new Store();
  await store.init();

  // IPC Handlers
  ipcMain.handle('lut:get-all', () => store.getLuts());
  ipcMain.handle('lut:import', () => store.importLut());
  ipcMain.handle('lut:delete', (_, id) => store.deleteLut(id));

  ipcMain.handle('select-files', async () => {
    if (!win) return [];
    const result = await dialog.showOpenDialog(win, {
      properties: ['openFile', 'multiSelections'],
      filters: [
        { name: 'Images', extensions: ['orf', 'jpg', 'jpeg'] },
        { name: 'All Files', extensions: ['*'] }
      ]
    });
    return result.filePaths;
  });

  ipcMain.handle('select-lut', async () => {
    if (!win) return null;
    const result = await dialog.showOpenDialog(win, {
      properties: ['openFile'],
      filters: [{ name: 'PNG Image', extensions: ['png'] }]
    });
    return result.filePaths[0] || null;
  });

  ipcMain.handle('process-image', async (_, inputPath: string, lutPath: string) => {
    try {
      const parsedPath = path.parse(inputPath);
      const outputPath = path.join(parsedPath.dir, `${parsedPath.name}_lut.jpg`);
      // Actually, let's just append _lut.jpg
      await processImage(inputPath, lutPath, outputPath);
      return { success: true, outputPath };
    } catch (error: any) {
      console.error(error);
      return { success: false, error: error.message };
    }
  });

  ipcMain.handle('get-preview', async (_, inputPath: string, width?: number) => {
    try {
      return await generatePreview(inputPath, width);
    } catch (error) {
      console.error('Preview error', error);
      return null;
    }
  });

  ipcMain.handle('get-lut-preview', async (_, inputPath, lutPath) => {
    try {
      return await generateLutPreview(inputPath, lutPath);
    } catch (error) {
      console.error('LUT Preview error', error);
      return null;
    }
  });

  createWindow();
})
