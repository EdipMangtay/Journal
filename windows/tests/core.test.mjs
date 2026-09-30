import test from 'node:test';
import assert from 'node:assert/strict';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { emptyJournal, newTrade, parseBackup, tradeSchema, net, classification, performance, curve, mergeBackup, importCSV, exportCSV, dateKey, matchesSearch, periodRange, groups, correlation } from '../shared/core.mjs';
import { JournalStorage } from '../electron/storage.mjs';
import { loadImage, imagePipeline } from '../electron/images.mjs';
import sharp from 'sharp';

function trade(pnl, overrides = {}) { return { ...newTrade(), grossPnL: pnl, ...overrides }; }
test('net-of-fees metrics, zero results, missing R and drawdown match the Mac rules', () => {
  const trades = [trade(200, { date: 1, fees: 10, rMultiple: 2 }), trade(-100, { date: 2, fees: 5, rMultiple: -1 }), trade(5, { date: 3, fees: 5 })];
  const p = performance(trades);
  assert.equal(p.netPnL, 85); assert.equal(p.wins, 1); assert.equal(p.losses, 1);
  assert.equal(p.averageR, 0.5); assert.equal(p.rCount, 2); assert.equal(p.maxDrawdown, 105);
  assert.ok(Math.abs(p.winRate - 100 / 3) < 1e-10); assert.equal(classification(trades[2]), 'BREAKEVEN');
  assert.equal(curve(trades).at(-1).equity, 85); assert.equal(performance([]).profitFactor, null);
});
test('positive invalid execution remains invalid', () => {
  const t = trade(200, { followsPlan: false, brokenRules: ['FOMO'] });
  assert.equal(classification(t), 'INVALID WINNER'); assert.equal(performance([t]).compliance, 0);
  assert.throws(() => tradeSchema.parse({ ...t, followsPlan: true }));
});
test('invalid numeric values, times, ranges and emotions are rejected', () => {
  for (const changes of [{ fees: -1 }, { grossPnL: Infinity }, { date: NaN }, { date: 10, exitDate: 9 }, { direction: 'Other' }]) assert.throws(() => tradeSchema.parse(trade(1, changes)));
  const t = trade(1); t.crt.high = 2; t.crt.low = 3; assert.throws(() => tradeSchema.parse(t));
  const e = trade(1); e.emotional.confidence = 0; assert.throws(() => tradeSchema.parse(e));
});
test('backup merge preserves unrelated records and replaces matching IDs', () => {
  const current = emptyJournal(), incoming = emptyJournal(), a = trade(10), b = trade(20);
  current.trades = [a, b]; incoming.trades = [{ ...a, grossPnL: 50 }];
  const merged = mergeBackup(current, incoming);
  assert.equal(merged.trades.length, 2); assert.equal(merged.trades.find(t => t.id === a.id).grossPnL, 50);
  assert.equal(merged.trades.find(t => t.id === b.id).grossPnL, 20);
});
test('duplicate IDs and missing relationships never enter storage', () => {
  const b = emptyJournal(), t = trade(1); b.trades = [t, { ...t }]; assert.throws(() => parseBackup(b));
  b.trades = [{ ...t, setupID: crypto.randomUUID() }]; assert.throws(() => parseBackup(b));
  b.trades = []; b.preferences.timezone = 'Invalid/Zone'; assert.throws(() => parseBackup(b));
});
test('CSV round trips quotes, commas, newlines and complete trade context', () => {
  const t = trade(-250, { rMultiple: -1 }); t.notes.thesis = '=SUM(A1), "test"\nsecond line'; t.qt.enabled = true;
  const restored = importCSV(exportCSV([t]));
  assert.deepEqual(restored[0], t); assert.match(exportCSV([t]), /'=SUM/);
  assert.throws(() => importCSV('instrument,date,gross_pnl\nNQ,invalid,2'));
  assert.throws(() => importCSV('instrument,instrument,date,gross_pnl\nNQ,NQ,2026-01-01,2'));
});
test('journal dates use the configured time zone', () => {
  assert.equal(dateKey(Date.parse('2026-01-01T02:00:00Z'), 'America/New_York'), '2025-12-31');
  assert.equal(dateKey(Date.parse('2026-01-01T02:00:00Z'), 'Europe/Istanbul'), '2026-01-01');
});
test('semantic search distinguishes absent confirmations and profitable mistakes',()=>{
  const t=trade(100,{instrument:'XAUUSD',followsPlan:false,brokenRules:['FOMO']});
  assert.equal(matchesSearch(t,'gold invalid winner no ssmt'),true);assert.equal(matchesSearch(t,'valid winner'),false);assert.equal(matchesSearch(t,'ssmt'),false);
  t.ssmt.confirmation='Yes';t.ssmt.valid=true;assert.equal(matchesSearch(t,'no ssmt'),false);assert.equal(matchesSearch(t,'ssmt gold'),true);
});
test('review periods cross month and year boundaries using the journal zone',()=>{
  const stamp=Date.parse('2026-01-01T02:00:00Z');
  assert.deepEqual(periodRange(stamp,'Daily','America/New_York'),{from:'2025-12-31',to:'2025-12-31'});
  assert.deepEqual(periodRange(stamp,'Weekly','America/New_York'),{from:'2025-12-29',to:'2026-01-04'});
  assert.deepEqual(periodRange(stamp,'Monthly','America/New_York'),{from:'2025-12-01',to:'2025-12-31'});
});
test('multi-label analysis does not count duplicate labels twice',()=>{
  const t=trade(100,{liquidityTaken:['BSL','SSL','BSL']});const values=groups([t],'Liquidity taken');assert.equal(values.length,2);assert.equal(values[0].count,1);
  assert.equal(groups([t],'QT validity')[0].name,'Not valid / aligned');
});
test('correlation requires three varying observations',()=>{
  assert.equal(correlation([[1,2],[2,4]]),null);assert.equal(correlation([[1,2],[2,4],[3,6]]),1);assert.equal(correlation([[1,2],[1,4],[1,6]]),null);
});
test('image imports preserve originals and decode PNG JPEG TIFF',async()=>{
  for(const format of ['png','jpeg','tiff']){
    const bytes=await sharp({create:{width:40,height:20,channels:3,background:'#66d8ad'}}).toFormat(format).toBuffer(),image=await loadImage(`test.${format}`,bytes);
    assert.equal(image.imageData,bytes.toString('base64'));assert.equal((await sharp(Buffer.from(image.thumbnailData,'base64')).metadata()).format,'jpeg');assert.equal((await(await imagePipeline(bytes)).png().toBuffer()).length>0,true);
  }
  await assert.rejects(()=>loadImage('invalid.png',Buffer.from('not an image')));
});
test('atomic writes survive reopening, keep previous state and reject corruption', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'journal-storage-test-'));
  try {
    const store = new JournalStorage(directory), b = emptyJournal(); b.trades = [trade(10)]; await store.write(b);
    const second = structuredClone(b); second.trades[0].grossPnL = 25; await store.write(second);
    assert.equal((await new JournalStorage(directory).read()).trades[0].grossPnL, 25);
    assert.equal(JSON.parse(await fs.readFile(store.file + '.bak', 'utf8')).trades[0].grossPnL, 10);
    await assert.rejects(async () => store.write({ ...second, version: 999 }));
    assert.equal((await store.read()).trades[0].grossPnL, 25);
    await fs.writeFile(store.file, 'invalid'); await assert.rejects(() => store.read(), /preserved/);
    assert.equal(await fs.readFile(store.file, 'utf8'), 'invalid');
  } finally { await fs.rm(directory, { recursive: true, force: true }); }
});
test('concurrent writes are serialized without losing the final state', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'journal-queue-test-'));
  try {
    const store = new JournalStorage(directory);
    await Promise.all([1, 2, 3].map(value => { const b = emptyJournal(); b.trades = [trade(value)]; return store.write(b); }));
    assert.equal(net((await store.read()).trades[0]), 3);
  } finally { await fs.rm(directory, { recursive: true, force: true }); }
});
test('real Swift-generated backup is accepted and analytics match Swift', async () => {
  const backup = parseBackup(JSON.parse(await fs.readFile(new URL('./fixtures/macos-backup.json', import.meta.url), 'utf8')));
  const expected = JSON.parse(await fs.readFile(new URL('./fixtures/macos-metrics.json', import.meta.url), 'utf8'));
  const actual = performance(backup.trades);
  for (const [key, value] of Object.entries(expected)) assert.ok(Math.abs(actual[key] - value) < 0.000001, `${key}: ${actual[key]} != ${value}`);
  const restored = importCSV(exportCSV(backup.trades), backup.setups);
  assert.equal(restored.length, backup.trades.length);
  assert.equal(performance(restored).netPnL, actual.netPnL);
});
