import { app, BrowserWindow, dialog, ipcMain, session, Menu } from 'electron';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { imagePipeline, loadImage, validateImages } from './images.mjs';
import { JournalStorage } from './storage.mjs';
import { parseBackup, mergeBackup, exportCSV, importCSV } from '../shared/core.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
app.setName('Liquidity Edge');
if (process.env.JOURNAL_TEST_DATA_DIR) app.setPath('userData', path.resolve(process.env.JOURNAL_TEST_DATA_DIR));
else app.setPath('userData', path.join(app.getPath('appData'), 'Liquidity Edge'));
if (!app.requestSingleInstanceLock()) app.quit();
else {
  let window;
  app.on('second-instance', () => { if (window) { if (window.isMinimized()) window.restore(); window.focus(); } });
  app.whenReady().then(() => {
    const storage = new JournalStorage(app.getPath('userData'));
    const index = path.join(root, '../dist/index.html');
    const allowedURL = pathToFileURL(index).href;
    window = new BrowserWindow({ width: 1440, height: 960, minWidth: 800, minHeight: 600, title: 'LIQUIDITY EDGE', backgroundColor: '#101215', icon: path.join(root, '../assets/icon.png'),
      webPreferences: { preload: path.join(root, 'preload.cjs'), contextIsolation: true, nodeIntegration: false, sandbox: true, webSecurity: true } });
    Menu.setApplicationMenu(null);
    session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) => callback(false));
    session.defaultSession.setPermissionCheckHandler(() => false);
    window.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
    window.webContents.on('will-navigate', event => event.preventDefault());
    const handle = (name, action) => ipcMain.handle(name, async (event, ...args) => {
      if (event.sender !== window.webContents || event.senderFrame !== window.webContents.mainFrame || event.senderFrame.url !== allowedURL) throw new Error('Untrusted request.');
      return action(...args);
    });
    const readLimited = async filename => {
      if ((await fs.stat(filename)).size > 512000000) throw new Error('File exceeds the 512 MB import limit.');
      return fs.readFile(filename, 'utf8');
    };
    handle('journal:load', () => storage.read());
    handle('journal:path', () => storage.file);
    handle('journal:save', async value => storage.write(await validateImages(parseBackup(value))));
    handle('journal:export', async value => {
      const backup = value ? await validateImages(parseBackup(value)) : await storage.read();
      const { canceled, filePath } = await dialog.showSaveDialog(window, { defaultPath: `LiquidityEdge-${new Date().toISOString().slice(0, 10)}.json`, filters: [{ name: 'Journal backup', extensions: ['json'] }] });
      if (canceled) return false;
      await fs.writeFile(filePath, JSON.stringify({ ...backup, createdAt: Date.now() }, null, 2)); return true;
    });
    handle('journal:import', async (value, demo = false) => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: 'Journal backup', extensions: ['json'] }] });
      if (canceled) return null;
      const incoming = await validateImages(parseBackup(JSON.parse(await readLimited(filePaths[0]))));
      const { response } = await dialog.showMessageBox(window, { type: 'question', title: 'Import backup', message: `Merge ${incoming.trades.length} trades, ${incoming.setups.length} setups and ${incoming.reviews.length} reviews?`, detail: 'Matching IDs will be replaced. Unrelated records remain. Imported preferences will be applied.', buttons: ['Cancel', 'Import'], defaultId: 0, cancelId: 0 });
      if (response !== 1) return null;
      if (demo) return mergeBackup(parseBackup(value), incoming);
      let current;
      try { current = await storage.read(); }
      catch {
        const result = await dialog.showMessageBox(window, { type: 'warning', message: 'The current journal is unreadable. Restore this validated backup?', detail: 'The unreadable original will be preserved in journal.json.bak.', buttons: ['Cancel', 'Restore'], defaultId: 0, cancelId: 0 });
        if (result.response !== 1) return null;
        return storage.write(incoming);
      }
      return storage.write(mergeBackup(current, incoming));
    });
    handle('journal:csv-export', async value => {
      const backup = value ? parseBackup(value) : await storage.read();
      const { canceled, filePath } = await dialog.showSaveDialog(window, { defaultPath: 'LiquidityEdge-trades.csv', filters: [{ name: 'CSV', extensions: ['csv'] }] });
      if (canceled) return false;
      await fs.writeFile(filePath, exportCSV(backup.trades)); return true;
    });
    handle('journal:csv-import', async (value, demo = false) => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile'], filters: [{ name: 'CSV', extensions: ['csv'] }] });
      if (canceled) return null;
      const current = demo ? parseBackup(value) : await storage.read(), records = importCSV(await readLimited(filePaths[0]), current.setups);
      const result = await dialog.showMessageBox(window, { type: 'question', message: `Import ${records.length} trades?`, buttons: ['Cancel', 'Import'], defaultId: 0, cancelId: 0 });
      if (result.response !== 1) return null;
      const byID = new Map(current.trades.map(t => [t.id.toLowerCase(), t])); records.forEach(t => byID.set(t.id.toLowerCase(), t));
      const merged = parseBackup({ ...current, trades: [...byID.values()] });
      return demo ? merged : storage.write(merged);
    });
    handle('journal:images', async () => {
      const { canceled, filePaths } = await dialog.showOpenDialog(window, { properties: ['openFile', 'multiSelections'], filters: [{ name: 'Images', extensions: ['png', 'jpg', 'jpeg', 'heic', 'heif', 'tif', 'tiff', 'webp'] }] });
      if (canceled) return [];
      if (filePaths.length > 20) throw new Error('Choose at most 20 images at a time.');
      return Promise.all(filePaths.map(async filename => {
        if ((await fs.stat(filename)).size > 30000000) throw new Error('Images must be smaller than 30 MB.');
        return loadImage(filename, await fs.readFile(filename));
      }));
    });
    handle('journal:drop-images', async files => {
      if (!Array.isArray(files) || files.length > 20) throw new Error('Choose at most 20 images at a time.');
      const images = [];
      for (const file of files) images.push(await loadImage(file.name, Buffer.from(file.bytes)));
      return images;
    });
    handle('journal:render-image', async data => {
      if (typeof data !== 'string' || data.length > 40000000) throw new Error('Invalid image.');
      const pipeline = await imagePipeline(Buffer.from(data, 'base64'));
      return (await pipeline.png().toBuffer()).toString('base64');
    });
    window.loadFile(index);
  }).catch(error => { dialog.showErrorBox('Liquidity Edge could not start', error.message); app.quit(); });
  app.on('window-all-closed', () => app.quit());
}
