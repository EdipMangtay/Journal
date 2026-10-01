import translations from './tr.json' with { type: 'json' };

const uppercase = new Map(Object.entries(translations).map(([key, value]) => [key.toUpperCase(), value.toLocaleUpperCase('tr-TR')]));
const patterns = Object.entries(translations).filter(([key]) => key.includes('{0}')).sort(([a], [b]) => b.length - a.length).map(([key, value]) => [new RegExp('^' + key.split(/\{\d+\}/).map(part => part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('(.+?)') + '$'), value]);
// Only call this for interface labels or built-in catalog values, never free-form notes.
export function t(key) {
  if (typeof key !== 'string') return key;
  const exact = translations[key] ?? uppercase.get(key);
  if (exact !== undefined) return exact;
  for (const [pattern, translated] of patterns) {
    const match = key.match(pattern);
    if (match) return translated.replace(/\{(\d+)\}/g, (_, index) => match[Number(index) + 1]);
  }
  return key;
}
export function message(key, ...values) {
  return t(key).replace(/\{(\d+)\}/g, (_, index) => String(values[Number(index)] ?? ''));
}
export function errorText(error) {
  if (error.issues) return error.issues.map(issue => {
    const translated = t(issue.message);
    if (translated !== issue.message) return translated;
    return `Geçersiz değer: ${issue.path.join('.')}. Lütfen alanı kontrol et.`;
  }).join('\n');
  const message = error.message || String(error);
  return t(message.replace(/^Error invoking remote method '[^']+': (?:Error: )?/, ''));
}
