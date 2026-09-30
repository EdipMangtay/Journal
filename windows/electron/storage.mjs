import { promises as fs } from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { emptyJournal, parseBackup } from '../shared/core.mjs';

export class JournalStorage {
  constructor(directory) { this.directory = directory; this.file = path.join(directory, 'journal.json'); this.queue = Promise.resolve(); }
  async read() {
    try { return parseBackup(JSON.parse(await fs.readFile(this.file, 'utf8'))); }
    catch (error) {
      if (error.code === 'ENOENT') return emptyJournal();
      throw new Error(`The journal could not be read. Your files have been preserved. Restore a JSON backup from Settings. ${error.message}`);
    }
  }
  write(value) {
    const snapshot = parseBackup(value);
    const operation = this.queue.then(async () => {
      await fs.mkdir(this.directory, { recursive: true });
      const temporary = `${this.file}.${randomUUID()}.tmp`;
      try {
        const handle = await fs.open(temporary, 'wx', 0o600);
        try { await handle.writeFile(JSON.stringify(snapshot)); await handle.sync(); } finally { await handle.close(); }
        try { await fs.copyFile(this.file, `${this.file}.bak`); } catch (error) { if (error.code !== 'ENOENT') throw error; }
        await fs.rename(temporary, this.file);
      } finally { await fs.rm(temporary, { force: true }); }
      return snapshot;
    });
    this.queue = operation.catch(() => {});
    return operation;
  }
}
