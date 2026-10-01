import { test } from 'node:test';
import assert from 'node:assert/strict';
import { t, message, errorText } from '../shared/i18n.mjs';
import { newTrade, emptyJournal, matchesSearch, wallTime, instantFromWallTime, exportCSV, importCSV } from '../shared/core.mjs';

test('Turkish interface preserves canonical data and free-form text', () => {
  assert.equal(t('Dashboard'), 'Genel Bakış');
  assert.equal(t('RULE COMPLIANCE'), 'KURALLARA UYUM');
  assert.equal(t('16 wins / 28 trades'), '28 işlemde 16 kazanç');
  assert.equal(message('{0} of {1} trades respected your plan. Review the exceptions.', 22, 28), '28 işlemin 22 tanesi planına uygun. İstisnaları incele.');
  const record = newTrade(); record.notes.thesis = 'Long'; record.notes.lesson = 'Türkçe not: ıİğĞüÜşŞöÖçÇ';
  assert.equal(record.direction, 'Long'); assert.equal(record.session, 'NY AM');
  const restored = importCSV(exportCSV([record]))[0];
  assert.deepEqual(restored.notes, record.notes); assert.equal(restored.direction, record.direction);
  for (const field of ['trades', 'setups', 'reviews', 'screenshots']) assert.deepEqual(emptyJournal()[field], []);
  assert.equal(errorText(new Error("Error invoking remote method 'journal:save': Error: Invalid time zone.")), 'Geçersiz saat dilimi.');
});
test('Turkish and English semantic queries preserve process classification', () => {
  const record = newTrade(); record.instrument = 'XAUUSD'; record.grossPnL = 100; record.followsPlan = false; record.brokenRules = ['Early entry']; record.session = 'London';
  for (const query of ['KURALSIZ KAZANÇ', 'kuralsiz kazanc', 'altın Londra', 'erken giriş', 'invalid winner']) assert.equal(matchesSearch(record, query), true, query);
  for (const query of ['kurallı kazanç', 'kuralli', 'kuralsız zarar', 'valid winner']) assert.equal(matchesSearch(record, query), false, query);
});
test('editor timestamps use journal zone, retain minute and reject DST gaps', () => {
  const instant = Date.parse('2026-10-01T13:35:00Z');
  assert.equal(wallTime(instant, 'America/New_York'), '2026-10-01T09:35');
  assert.equal(instantFromWallTime('2026-10-01T09:35', 'America/New_York'), instant);
  assert.equal(wallTime(instant, 'Europe/Istanbul'), '2026-10-01T16:35');
  assert.equal(instantFromWallTime('2026-10-01T16:35', 'Europe/Istanbul'), instant);
  assert.equal(instantFromWallTime('2026-11-01T01:30', 'America/New_York'), Date.parse('2026-11-01T05:30:00Z'));
  assert.throws(() => instantFromWallTime('2026-03-08T02:30', 'America/New_York'), /yaz saati/);
});
