import Chart from 'chart.js/auto';
import { catalog, net, compliant, classification, execution, performance, curve, groups, dateKey, flags, correlation } from '../shared/core.mjs';

export const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
export const glyph = name => `<i data-lucide="${name}" aria-hidden="true"></i>`;
export const command = (action, label, icon = '', extra = '') => `<button type="button" data-action="${action}" ${extra}>${icon ? glyph(icon) : ''}${label}</button>`;
const iconCommand = (action, label, icon, extra = '') => command(action, '', icon, `class="icon" aria-label="${label}" title="${label}" ${extra}`);
export const options = (values, selected, empty) => (empty !== undefined ? `<option value="">${esc(empty)}</option>` : '') + values.map(o => { const [v, label] = Array.isArray(o) ? o : [o, o]; return `<option value="${esc(v)}" ${v === selected ? 'selected' : ''}>${esc(label)}</option>`; }).join('');
export const field = (name, label, value = '', type = 'text', extra = '') => `<label><span>${esc(label)}</span><input aria-label="${esc(label)}" name="${esc(name)}" type="${type}" value="${esc(value)}" ${extra}></label>`;
export const pick = (name, label, values, selected, empty) => `<label class="inline-label"><span>${esc(label)}</span><select aria-label="${esc(label)}" name="${esc(name)}">${options(values, selected, empty)}</select></label>`;
export const toggle = (name, label, checked, extra = '') => `<label class="check"><input type="checkbox" name="${name}" ${checked ? 'checked' : ''} ${extra}><span>${esc(label)}</span></label>`;
export const note = (name, label, value = '') => `<label class="note"><span>${esc(label)}</span><textarea aria-label="${esc(label)}" name="${name}">${esc(value)}</textarea></label>`;
const num = (name, label, value, extra = '') => field(name, label, value ?? '', 'number', `step="any" ${extra}`);
const n = (value, digits = 2) => value == null ? '\u2014' : Number(value).toLocaleString('en-US', { minimumFractionDigits: digits, maximumFractionDigits: digits });
const r = value => value == null ? '\u2014' : (value > 0 ? '+' : '') + n(value) + 'R';
const pct = value => n(value, 1) + '%';
const tone = value => value > 0 ? 'positive' : value < 0 ? 'negative' : 'muted';
const classTone = t => !compliant(t) && Math.abs(net(t)) >= .005 ? 'warning' : classification(t) === 'VALID LOSER' ? 'blue' : tone(net(t));
const badge = (label, color = 'muted') => `<span class="badge ${color}">${esc(label)}</span>`;
const money = (value, data) => new Intl.NumberFormat('en-US', { style: 'currency', currency: data.preferences.currency }).format(value);
const factor = p => p.profitFactor == null ? p.grossProfit > 0 ? '\u221e' : '\u2014' : n(p.profitFactor);
const shortDate = (timestamp, data, time = false) => new Intl.DateTimeFormat('en-US', { dateStyle: 'medium', ...(time ? { timeStyle: 'short' } : {}), timeZone: data.preferences.timezone }).format(timestamp);
const header = (eyebrow, title, subtitle, trailing = '') => `<header class="page-header"><div><p class="eyebrow">${eyebrow}</p><h1>${title}</h1><p class="subtitle">${subtitle}</p></div>${trailing}</header>`;
const panel = (title, body, subtitle = '', extra = '') => `<section class="panel" ${extra}>${title ? `<div class="panel-heading"><h2>${title}</h2>${subtitle ? `<small>${subtitle}</small>` : ''}</div>` : ''}${body}</section>`;
const metric = (title, value, footnote = '', color = '') => `<article class="metric"><h3>${title}</h3><strong class="${color}">${value}</strong>${footnote ? `<p>${footnote}</p>` : ''}</article>`;
const segments = (name, values, selected, label) => `<div class="segments" role="group" aria-label="${label}">${values.map(v => `<button data-${name}="${esc(v)}" class="${selected === v ? 'selected' : ''}" aria-pressed="${selected === v}">${esc(v)}</button>`).join('')}</div>`;
const empty = (title, subtitle, action = '') => `<div class="empty">${glyph('chart-no-axes-combined')}<h2>${title}</h2><p>${subtitle}</p>${action}</div>`;
export const navigation = [['Dashboard', 'layout-grid'], ['Trades', 'table-properties'], ['New Trade', 'square-plus'], ['Calendar', 'calendar-days'], ['Analytics', 'chart-no-axes-combined'], ['Setup Analysis', 'layers'], ['Playbook', 'book'], ['Mistakes', 'shield-alert'], ['Screenshots', 'images'], ['Statistics', 'chart-column-increasing'], ['Review', 'square-check'], ['Settings', 'sliders-horizontal']];
const dimensions = ['Setup', 'Instrument', 'Session', 'Day of week', 'Hour', 'Direction', 'QT quarter', 'MMXM', 'SSMT', 'TSMO', 'CRT', 'Liquidity taken', 'HTF alignment', 'Entry timeframe', 'Grade', 'Rule compliance', 'Emotion', 'Classification', 'QT validity', 'Draw on liquidity'];
export function filterBar(data, state) {
  const f = state.filters, count = Object.entries(f).filter(([key, value]) => key !== 'search' && value).length + Object.values(state.facets).filter(Boolean).length;
  return `<section class="filter-bar"><div class="filter-search">${glyph('search')}<input type="search" id="search" aria-label="Search trades" data-filter="search" value="${esc(f.search)}" placeholder="Search instrument, model, emotion, notes...">${command('toggle-filters', `Filters ${count}`, 'list-filter')}${command('reset-filters', 'Reset', '', 'class="plain"')}</div>${state.advanced ? `<div class="form-grid filter-options">${[['instrument', 'Instrument', [...new Set(data.trades.map(t => t.instrument))]], ['session', 'Session', data.preferences.sessions], ['compliance', 'Rule compliance', [['valid', 'Valid'], ['invalid', 'Rule break']]]].map(([key, label, values]) => `<label class="inline-label"><span>${label}</span><select data-filter="${key}" aria-label="${label}">${options(values, f[key], 'All')}</select></label>`).join('')}${dimensions.filter(d => !['Instrument','Session','Rule compliance'].includes(d)).map(d => `<label class="inline-label"><span>${d}</span><select data-facet="${esc(d)}">${options(groups(data.trades, d, data.preferences.timezone).map(g => g.name), state.facets[d] || '', 'All')}</select></label>`).join('')}<label>From<input data-filter="from" type="date" value="${esc(f.from)}"></label><label>Through<input data-filter="to" type="date" value="${esc(f.to)}"></label></div>` : ''}</section>`;
}
export function tradeRows(rows, data) {
  return `<div class="trade-rows"><div class="trade-row headings"><span>INSTRUMENT / SETUP</span><span>PROCESS</span><span>NET PNL</span><span>R</span></div>${rows.map(t => `<button class="trade-row" data-trade="${t.id}" aria-label="Open ${esc(t.instrument)} trade"><span class="instrument-cell"><span class="direction-icon">${glyph(t.direction === 'Long' ? 'arrow-up-right' : 'arrow-down-right')}</span><span class="trade-label"><span><b>${esc(t.instrument)}</b><small>${esc(t.direction.toUpperCase())}</small><small>${shortDate(t.date, data)}</small></span><small>${esc(t.setupName)} &middot; ${esc(t.session)}</small></span></span><span>${badge(classification(t), classTone(t))}</span><span class="${tone(net(t))}">${money(net(t), data)}</span><span class="${tone(t.rMultiple || 0)}">${r(t.rMultiple)}</span></button>`).join('')}</div>`;
}
function metricGrid(p, data) {
  return `<div class="metrics">${[
    ['Profit factor', factor(p)], ['Expectancy / trade', money(p.expectancy, data)], ['Average winner', money(p.averageWinner, data)], ['Average loser', money(p.averageLoser, data)],
    ['Average R', r(p.averageR)], ['Best trade', money(p.bestTrade, data)], ['Worst trade', money(p.worstTrade, data)], ['Max drawdown', money(p.maxDrawdown, data)],
    ['Current win streak', p.currentWinStreak], ['Current loss streak', p.currentLossStreak], ['Rule compliance', pct(p.compliance)], ['Total trades', p.count],
    ['Loss rate', pct(p.lossRate)], ['Recovery factor', n(p.recoveryFactor)], ['Realized payoff ratio', n(p.payoffRatio)], ['Average duration', p.averageDuration == null ? '\u2014' : n(p.averageDuration / 60, 0) + ' min']
  ].map(([title, value]) => metric(title, value)).join('')}</div>`;
}
function chart(id, height = 260, extra = '') { return `<div class="chart" style="height:${height}px"><canvas id="${id}" ${extra}></canvas></div>`; }
function heatmap(rows, data) {
  const buckets = new Map();
  const formatter = new Intl.DateTimeFormat('en-US', { weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23', timeZone: data.preferences.timezone });
  for (const t of rows) { const parts = formatter.formatToParts(t.date), part = name => parts.find(p => p.type === name).value; const key = `${part('weekday')}-${+part('hour') * 2 + (+part('minute') >= 30 ? 1 : 0)}`; if (!buckets.has(key)) buckets.set(key, []); buckets.get(key).push(t); }
  const slots = Array.from({ length: 14 }, (_, i) => i + 19);
  return `<div class="heatmap-scroll"><div class="heatmap"><span class="muted">DAY</span>${slots.map(s => `<span class="muted">${String(Math.floor(s / 2)).padStart(2, '0')}:${s % 2 ? '30' : '00'}</span>`).join('')}${['Mon', 'Tue', 'Wed', 'Thu', 'Fri'].map(day => `<span class="day-label">${day}</span>${slots.map(s => { const p = performance(buckets.get(`${day}-${s}`) || []); return `<span class="heat-cell ${p.averageR == null ? '' : tone(p.averageR)}" title="${day}: n = ${p.count}, ${r(p.averageR)}">${p.averageR == null ? '&middot;' : n(p.averageR, 1)}</span>`; }).join('')}`).join('')}</div></div><p class="caption">Average R &middot; half-hour entry buckets &middot; ${esc(data.preferences.timezone)}</p>`;
}
function dashboard(data, state, rows) {
  const p = performance(rows), selected = state.curveMode === 'R' ? r(p.totalR) : state.curveMode === '%' ? pct(p.netPnL / data.preferences.accountSize * 100) : money(p.netPnL, data);
  return header('Performance overview', 'Process is the edge.', 'Professional Trading Performance Journal', segments('period', ['TODAY', 'THIS WEEK', 'THIS MONTH', 'ALL TIME'], state.period, 'Dashboard period')) +
    `<div class="discipline">${glyph('shield-check')}<div><strong>Discipline before dollars.</strong><p>${rows.length ? `${rows.filter(compliant).length} of ${rows.length} trades respected your plan. Review the exceptions.` : 'Your process is measured independently of your PnL.'}</p></div>${badge(pct(p.compliance) + ' COMPLIANCE', p.compliance >= 80 ? 'positive' : 'warning')}</div>` +
    (!rows.length ? empty('Your edge starts with one trade.', 'Log the setup, record the process, and let your own data tell the story.', command('new-trade', 'New trade', '', 'class="primary"')) :
      `<div class="metrics">${metric('Net PnL', money(p.netPnL, data), 'After commissions & fees', tone(p.netPnL))}${metric('Total R', r(p.totalR), `${p.rCount} trades with recorded R`, tone(p.totalR))}${metric('Win rate', pct(p.winRate), `${p.wins} wins / ${p.count} trades`)}${metric('Expectancy', r(p.averageR), 'Expected R per recorded trade', tone(p.averageR || 0))}</div>` +
      panel('EQUITY CURVE', `<div class="curve-summary"><strong>${selected}</strong>${segments('curve-mode', ['$', 'R', '%'], state.curveMode, 'Equity curve unit')}</div>${chart('equity')}<div class="chart-footer"><span>${glyph('circle-dashed')}Starting balance ${money(data.preferences.accountSize, data)}</span><span>${p.count} observations</span></div>`, 'CLOSED TRADES &middot; NET OF FEES') +
      `<div class="quality-grid">${panel('EXECUTION QUALITY', `<div class="quality-score"><strong>${n(p.executionScore, 0)}</strong><span>/ 100</span>${glyph('crosshair')}</div><progress value="${p.executionScore}" max="100"></progress><div class="line"><span>A+ setup win rate</span><span>${p.aPlusWinRate == null ? '\u2014' : pct(p.aPlusWinRate)}</span></div>`)}${panel('PROCESS / OUTCOME', `<div class="outcomes">${['VALID WINNER', 'VALID LOSER', 'INVALID WINNER', 'INVALID LOSER'].map((type, i) => `<div class="line"><span class="outcome-label"><i class="dot ${['positive', 'blue', 'warning', 'warning'][i]}"></i>${type}</span><span>${rows.filter(t => classification(t) === type).length}</span></div>`).join('')}</div>`)}</div>` +
      panel('WHEN YOUR EDGE SHOWS UP', heatmap(rows, data), 'AVERAGE R') + `<div class="two-columns">${panel('CUMULATIVE R', chart('cumulative-r', 160))}${panel('DRAWDOWN', chart('drawdown', 160))}</div>` +
      panel('ROLLING WIN RATE', chart('rolling', 150), 'LAST 20 TRADES &middot; SHORTER WINDOW UNTIL 20') + panel('RECENT EXECUTIONS', tradeRows([...rows].sort((a, b) => b.date - a.date).slice(0, 6), data), 'PROCESS > OUTCOME') + metricGrid(p, data));
}
function groupTable(cohorts, data) {
  return `<div class="table-wrap"><table class="group-table"><thead><tr>${['COHORT', 'N', 'WR', 'AVG R', 'NET PNL', 'EXPECTANCY', 'PF'].map(c => `<th>${c}</th>`).join('')}</tr></thead><tbody>${cohorts.map(p => `<tr><td>${esc(p.name)}</td><td>${p.count}</td><td>${pct(p.winRate)}</td><td class="${tone(p.averageR || 0)}">${r(p.averageR)}</td><td>${money(p.netPnL, data)}</td><td>${money(p.expectancy, data)}</td><td>${factor(p)}</td></tr>`).join('')}</tbody></table></div>`;
}
function comparisons(rows) {
  const definitions = [
    ['SSMT contribution', 'With valid SSMT', 'Without valid SSMT', t => flags(t).SSMT, t => !flags(t).SSMT],
    ['TSMO contribution', 'With valid TSMO', 'Without valid TSMO', t => flags(t).TSMO, t => !flags(t).TSMO],
    ['Quarter alignment', 'QT aligned', 'QT not aligned', t => t.qt.enabled && t.qt.aligned, t => t.qt.enabled && !t.qt.aligned],
    ['Liquidity sweep', 'Valid sweep', 'No valid sweep', t => t.sweepValid, t => !t.sweepValid],
    ['CRT \u00d7 SSMT', 'CRT + SSMT', 'CRT without SSMT', t => flags(t).CRT && flags(t).SSMT, t => flags(t).CRT && !flags(t).SSMT],
    ['MMXM \u00d7 QT', 'MMXM + QT', 'MMXM without QT', t => flags(t).MMXM && flags(t).QT, t => flags(t).MMXM && !flags(t).QT],
    ['Process advantage', 'Fully valid trades', 'Rule break trades', compliant, t => !compliant(t)]
  ];
  return `<h2 class="section-label">CONFIRMATION CONTRIBUTION</h2><div class="two-columns">${definitions.map(([title, a, b, left, right]) => panel(title.toUpperCase(), [[a, left], [b, right]].map(([name, filter]) => { const p = performance(rows.filter(filter)); return `<div class="comparison-row"><div><strong>${name}</strong><small>n = ${p.count} &middot; ${pct(p.winRate)} WR</small></div><b class="${tone(p.averageR || 0)}">${r(p.averageR)}</b></div>`; }).join('') + '<p class="caption">Descriptive comparison; cohorts can differ in setup and execution.</p>')).join('')}</div>`;
}
function edges(rows) {
  const buckets = new Map(), names = ['QT', 'MMXM', 'SSMT', 'TSMO', 'CRT'];
  for (const t of rows) {
    const f = flags(t), active = names.filter(name => f[name]);
    const add = name => { if (!buckets.has(name)) buckets.set(name, []); buckets.get(name).push(t); };
    if (active.length === 1) add(active[0] + ' Only');
    for (let mask = 1; mask < 32; mask++) { const selected = names.filter((_, i) => mask & (1 << i)); if (selected.length >= 2 && selected.every(name => f[name])) add(selected.join(' + ')); }
  }
  return [...buckets].map(([name, rows]) => ({ name, ...performance(rows) })).sort((a, b) => b.count - a.count || a.name.localeCompare(b.name));
}
function analytics(data, state, rows) {
  const p = performance(rows), cohorts = groups(rows, state.analysis, data.preferences.timezone), stats = state.view === 'Statistics';
  const title = state.view === 'Setup Analysis' ? 'Find the combinations that matter.' : stats ? 'Your performance, precisely.' : 'Evidence over intuition.';
  const top = header('Research desk', title, 'Measure confirmations against your own execution history.') + filterBar(data, state);
  if (!rows.length) return top + empty('No observations yet.', 'Add trades or adjust filters to begin your analysis.');
  const months = new Map(); for (const t of rows) { const key = dateKey(t.date, data.preferences.timezone).slice(0, 7); if (!months.has(key)) months.set(key, []); months.get(key).push(t); }
  const relationship = correlation([...months.values()].map(trades => performance(trades)).filter(p => p.averageR != null).map(p => [p.compliance, p.averageR]));
  return top + (stats ? metricGrid(p, data) : `<div class="metrics">${metric('Sample', `n = ${p.count}`)}${metric('Win rate', pct(p.winRate))}${metric('Expectancy', r(p.averageR))}${metric('Compliance', pct(p.compliance))}</div>`) +
    panel('PERFORMANCE BREAKDOWN', `<div class="line pickers"><label class="inline-label">Group by<select id="dimension">${options(dimensions, state.analysis)}</select></label><label class="inline-label">Metric<select id="group-metric">${options(['Average R', 'Win rate', 'Net PnL', 'Expectancy', 'Profit factor'], state.groupMetric)}</select></label></div>${chart('group-bars', Math.max(160, cohorts.length * 33))}${groupTable(cohorts, data)}`) +
    (stats ? '' : comparisons(rows) + panel('EDGE MATRIX', edges(rows).map(e => `<div class="edge-row"><div><strong>${e.name}</strong>${badge(e.count < 30 ? 'LOW SAMPLE' : e.count < 50 ? 'REASONABLE SAMPLE' : 'MORE EVIDENCE', e.count < 30 ? 'warning' : 'positive')}</div><div><p>${pct(e.winRate)} WR &middot; ${r(e.averageR)} expectancy</p><small>Avg winning R ${r(e.averageWinningR)} &middot; n = ${e.count}</small></div></div>`).join('') + '<p class="caption">Combinations include trades with additional confirmations. Sample count alone does not establish statistical confidence or a durable edge.</p>', 'CONFIRMED MODEL COMBINATIONS')) +
    panel('DISCIPLINE OVER TIME', chart('discipline-chart', 170) + [...months].sort().map(([month, trades]) => { const stats = performance(trades); return `<div class="line"><span>${month}</span><span>${pct(stats.compliance)} &nbsp; ${r(stats.averageR)}</span></div>`; }).join('') + `<p class="caption">${relationship == null ? 'Correlation needs at least three months with recorded R and variation in both metrics.' : `Monthly compliance / expectancy Pearson r = ${n(relationship)}. Association is not causation; ${months.size} monthly observations.`}</p>`, 'MONTHLY RULE COMPLIANCE') +
    panel('SESSION PERFORMANCE', groupTable(groups(rows, 'Session', data.preferences.timezone), data)) + panel('ENTRY TIME HEATMAP', heatmap(rows, data)) + panel('METRIC DEFINITIONS', '<p class="caption">All PnL metrics use gross PnL minus fees. Win/loss rates include breakeven trades in the denominator. Expectancy is net PnL divided by trades; expectancy in R and average R both equal total recorded R divided by trades with R. Average winning R uses winners only. Profit factor is gross net winners divided by absolute net losers. Drawdown starts from zero cumulative PnL. Percentage equity uses the configured starting account size, without deposits or withdrawals. Streaks reset on breakeven. Session labels are recorded manually; time buckets use the configured trading time zone. Multi-label groups can overlap.</p>');
}
function calendar(data, state) {
  const year = state.month.getFullYear(), month = state.month.getMonth(), first = new Date(year, month, 1), count = new Date(year, month + 1, 0).getDate(), offset = (first.getDay() + 6) % 7;
  const prefix = `${year}-${String(month + 1).padStart(2, '0')}`, rows = data.trades.filter(t => dateKey(t.date, data.preferences.timezone).startsWith(prefix)), p = performance(rows);
  const dayRows = key => rows.filter(t => dateKey(t.date, data.preferences.timezone) === key), today = dateKey(Date.now(), data.preferences.timezone);
  return header('Session by session', 'The rhythm of your trading.', 'Daily outcomes, with the process one click away.', `<label class="check">Show R<input id="show-r" type="checkbox" ${state.showR ? 'checked' : ''}></label>`) +
    `<div class="metrics">${metric('Monthly PnL', money(p.netPnL, data))}${metric('Monthly R', r(p.totalR))}${metric('Win rate', pct(p.winRate))}${metric('Trades', p.count)}</div>` +
    panel('', `<div class="line month-controls"><div>${iconCommand('month-prev', 'Previous month', 'chevron-left')}<strong>${first.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}</strong>${iconCommand('month-next', 'Next month', 'chevron-right')}</div>${command('month-today', 'This month')}</div><div class="calendar">${['MON','TUE','WED','THU','FRI','SAT','SUN'].map(d => `<span class="weekday">${d}</span>`).join('')}${Array.from({ length: offset }, () => '<span></span>').join('')}${Array.from({ length: count }, (_, i) => {
      const key = `${prefix}-${String(i + 1).padStart(2, '0')}`, trades = dayRows(key), stats = performance(trades), value = state.showR ? stats.totalR : stats.netPnL;
      return `<button class="day ${trades.length ? tone(value) : ''} ${state.selectedDay === key ? 'selected' : ''}" data-day="${key}"><span>${i + 1}${key === today ? '<i class="dot positive"></i>' : ''}</span>${trades.length ? `<strong>${state.showR ? r(value) : money(value, data)}</strong><small>${trades.length} trades</small>` : ''}</button>`;
    }).join('')}</div>`) + (state.selectedDay ? panel(state.selectedDay, dayRows(state.selectedDay).length ? tradeRows(dayRows(state.selectedDay), data) : '<p class="muted">No trades on this day.</p>') : '');
}
function playbook(data) {
  return header('Your models', 'Define it. Execute it. Refine it.', 'A living playbook, linked to the performance of your actual trades.', command('new-setup', 'New setup', '', 'class="primary"')) +
    (data.setups.length ? [...data.setups].sort((a,b) => a.name.localeCompare(b.name)).map((s, index) => { const p = performance(data.trades.filter(t => t.setupID === s.id)); return panel('', `<div class="model-head"><div><p class="eyebrow positive">MODEL ${String(index + 1).padStart(2, '0')}</p><h2>${esc(s.name)}</h2><p class="subtitle">${esc(s.summary)}</p></div><div class="actions">${command('edit-setup', 'Edit', '', `data-id="${s.id}"`)}${iconCommand('delete-setup', 'Delete setup', 'trash-2', `data-id="${s.id}"`)}</div></div><div class="model-metrics">${[['SAMPLES', p.count], ['WIN RATE', pct(p.winRate)], ['AVG R', r(p.averageR)], ['EXPECTANCY', money(p.expectancy, data)], ['COMPLIANCE', pct(p.compliance)]].map(([label, value]) => `<div><small>${label}</small><strong>${value}</strong></div>`).join('')}</div><details><summary>Conditions & execution rules</summary><div class="details-body">${['conditions', 'entry', 'invalidation', 'target', 'risk'].map(key => `<div class="read-note"><small>${key.toUpperCase()}</small><p>${esc(s[key] || 'Not recorded')}</p></div>`).join('')}${imageGallery(s.images)}</div></details>`); }).join('') : empty('Codify your first setup.', 'Write the conditions, invalidation and risk rules that make an execution valid.', command('new-setup', 'Create setup', '', 'class="primary"')));
}
function mistakes(data) {
  const mistakes = groups(data.trades, 'Mistakes').sort((a,b) => b.count - a.count);
  return header('Process audit', 'The cost of breaking your rules.', 'Profitable mistakes are still mistakes. Learn from the process.') +
    (mistakes.length ? mistakes.map(m => panel('', `<div class="line"><div><h2 class="regular-title">${esc(m.name)}</h2><p class="subtitle">${m.count} trades &middot; ${pct(m.winRate)} win rate</p></div><strong class="warning large-number">${r(m.totalR)}</strong><span class="muted large-number">${money(m.netPnL, data)}</span></div>${m.netPnL > 0 ? '<p class="warning">Positive outcome, poor process</p>' : ''}`)).join('') + '<p class="caption">A trade can break multiple rules; counts and PnL overlap between mistakes.</p>' : empty('No rule violations recorded.', 'Honest process reviews are the foundation of a useful journal.'));
}
function reviews(data) {
  return header('Deliberate practice', 'Turn experience into improvement.', 'Daily, weekly and monthly reviews anchored in your trade data.', command('new-review', 'New review', '', 'class="primary"')) +
    (data.reviews.length ? [...data.reviews].sort((a,b) => b.date - a.date).map(item => panel('', `<div class="line"><div>${badge(item.period.toUpperCase(), 'positive')}<h2 class="regular-title">${shortDate(item.date, data)}</h2><p class="subtitle">${esc(item.adjustment || item.worked || 'No adjustment recorded.')}</p></div><div class="actions">${command('edit-review', 'Open review', '', `data-id="${item.id}"`)}${iconCommand('delete-review', 'Delete review', 'trash-2', `data-id="${item.id}"`)}</div></div>`)).join('') : empty('Build a review habit.', 'Capture what worked, what did not, and one adjustment for your next session.'));
}
export function imageGallery(images, editable = false) {
  return `<div class="gallery">${images.map(s => `<article class="shot"><button class="image-button" data-shot="${s.id}" type="button"><img src="data:image/jpeg;base64,${esc(s.thumbnailData)}" alt="${esc(s.name)}"></button><footer>${editable ? `<select aria-label="Image category" data-shot-category="${s.id}">${options(catalog.screenshotCategories, s.category)}</select>${iconCommand('remove-shot', 'Remove image', 'trash-2', `data-id="${s.id}"`)}` : badge(s.category)}<small>${esc(s.name)}</small></footer></article>`).join('')}</div>`;
}
function screenshots(data, state) {
  const shots = data.screenshots.filter(s => !state.imageCategory || s.screenshot.category === state.imageCategory);
  return header('Visual memory', 'Build your pattern library.', 'Context, entry and review images linked to real executions.') + `<div class="line"><label class="inline-label">Category<select id="image-category">${options(catalog.screenshotCategories, state.imageCategory, 'All screenshots')}</select></label><small>${shots.length} images</small></div>` +
    (shots.length ? `<div class="gallery">${shots.map(({tradeID,screenshot:s})=>{const t=data.trades.find(t=>t.id===tradeID);return `<article class="panel shot"><button class="image-button" data-shot="${s.id}"><img src="data:image/jpeg;base64,${esc(s.thumbnailData)}" alt="${esc(s.name)}"></button><div class="line"><strong>${esc(t?.instrument)}</strong>${badge(s.category)}<span class="${tone(t?net(t):0)}">${r(t?.rMultiple)}</span></div><button data-trade="${tradeID}" class="plain">Open trade ${glyph('arrow-right')}</button></article>`;}).join('')}</div>` : empty('Your visual library is empty.', 'Attach screenshots to a trade. Review them here by stage.'));
}
function settings(data, state) {
  const p = data.preferences;
  return header('Workspace preferences', 'Make it your journal.', 'Local storage, clear defaults and data you control.') +
    `<form id="preferences" class="stack">${panel('ACCOUNT & APPEARANCE', `<div class="form-grid account-fields">${num('accountSize', 'Account size', p.accountSize, 'required min="0.01"')}${num('defaultRiskPercent', 'Default risk %', p.defaultRiskPercent, 'required min="0" max="100"')}${field('currency', 'Currency', p.currency, 'text', 'maxlength="3" required pattern="[A-Z]{3}"')}</div><div class="line">${pick('theme', 'Theme', ['Dark','Light','System'], p.theme)}${toggle('animations', 'Animations', p.animations)}</div>${field('timezone', 'Time zone', p.timezone, 'text', 'required')}<p class="caption">Use an IANA time zone, such as America/New_York or Europe/Istanbul. Calendar and hourly analytics use this zone; timestamps are stored as absolute instants. Currency changes display units and does not convert values.</p><div><button type="submit">Save preferences</button></div>`)}
    ${panel('TRADING SESSIONS', `<div id="session-fields">${p.sessions.map(s => `<div class="session-row"><span>${esc(s)}</span><input name="session:${esc(s)}" aria-label="${esc(s)} session hours" value="${esc(p.sessionHours[s] || '')}">${iconCommand('remove-session', 'Remove session', 'circle-minus', `data-id="${esc(s)}"`)}</div>`).join('')}</div><div class="line"><input id="custom-session" aria-label="Custom session" placeholder="Custom session">${command('add-session', 'Add session')}</div><input type="hidden" name="sessions" value="${esc(p.sessions.join(', '))}"><p class="caption">Session hours are your reference schedule. Choose the session explicitly on each trade. Save preferences to apply changes.</p>`)}</form>` +
    panel('ALLOWED INSTRUMENTS', `<form id="instruments"><div class="checklist">${data.instruments.map(i => toggle('enabled-instrument', i.symbol, i.enabled, `value="${esc(i.symbol)}"`)).join('')}</div><div class="line"><input name="new-symbol" aria-label="Custom symbol" placeholder="Custom symbol"><button type="submit">Add instrument / Save</button></div></form>`) +
    panel('CUSTOM RULES', `<form id="rules"><div class="line"><input name="new-rule" aria-label="Rule name" placeholder="Rule name"><button type="submit">Add rule</button></div>${data.rules.map(item => `<div class="line"><span>${esc(item.name)}</span>${iconCommand('remove-rule', 'Remove rule', 'circle-minus', `data-id="${item.id}"`)}</div>`).join('')}</form>`) +
    panel('BACKUP & PORTABILITY', `<div class="actions">${command('export-backup', 'Export JSON backup', 'download')}${command('import-backup', 'Restore JSON backup', 'upload')}${command('export-csv', 'Export CSV', 'file-down')}${command('import-csv', 'Import CSV', 'file-up')}</div><p class="caption" id="data-path"></p>`) +
    panel('WORKSPACE', `<div class="line"><span>${state.demo ? 'Demo workspace' : 'Your personal journal'}</span>${command(state.demo ? 'exit-demo' : 'demo', state.demo ? 'Start My Journal' : 'Open Demo')}</div>`);
}
export function workspaceView(data, state, rows) {
  let content;
  if (state.view === 'Dashboard') content = dashboard(data, state, rows);
  else if (state.view === 'Trades') content = header('Execution log', 'Every trade tells a story.', `${rows.length} trades &middot; Search, inspect and refine your process.`, `<label class="inline-label">Sort<select id="trade-sort">${options(['Newest','Oldest','Best R','Best PnL'], state.tradeSort)}</select></label>`) + filterBar(data, state) + (rows.length ? panel('', tradeRows([...rows].sort((a,b) => state.tradeSort === 'Oldest' ? a.date - b.date : state.tradeSort === 'Best R' ? (b.rMultiple ?? -Infinity) - (a.rMultiple ?? -Infinity) : state.tradeSort === 'Best PnL' ? net(b) - net(a) : b.date - a.date), data)) : empty('Your journal is ready.', 'Start with a quick entry. Add context when you review.', command('new-trade','New trade','','class="primary"')));
  else if (['Analytics','Setup Analysis','Statistics'].includes(state.view)) content = analytics(data, state, rows);
  else if (state.view === 'Calendar') content = calendar(data, state);
  else if (state.view === 'Playbook') content = playbook(data);
  else if (state.view === 'Mistakes') content = mistakes(data);
  else if (state.view === 'Review') content = reviews(data);
  else if (state.view === 'Screenshots') content = screenshots(data,state);
  else content = settings(data, state);
  return `<aside class="sidebar ${state.collapsed ? 'collapsed' : ''}"><div class="brand"><span class="brand-mark">${glyph('audio-lines')}</span><div><strong>LIQUIDITY</strong><span>EDGE</span></div></div><span class="workspace-label">WORKSPACE</span><nav class="nav">${navigation.map(([name, icon]) => `${['Analytics','Review'].includes(name) ? '<hr>' : ''}<button ${name === 'New Trade' ? 'data-action="new-trade"' : `data-view="${name}"`} class="${state.view === name ? 'active' : ''}" title="${name}">${glyph(icon)}<span>${name}</span>${name === 'New Trade' ? '<small>Ctrl N</small>' : ''}</button>`).join('')}</nav><div class="sidebar-bottom"><strong>PROCESS > OUTCOME</strong><p>Protect your process.<br>The edge follows.</p></div>${iconCommand('collapse-sidebar', 'Toggle sidebar', 'panel-left')}</aside>
    <div class="workspace ${state.collapsed ? 'collapsed' : ''}"><div class="topbar"><div class="breadcrumb"><span>WORKSPACE</span><span>/</span><strong>${state.view}</strong></div><div class="actions"><span class="local"><i class="dot positive"></i>LOCAL &middot; PRIVATE</span>${command('search-command', `${glyph('search')}Search <small>Ctrl K</small>`, '', 'class="search-command"')}${command('new-trade','New trade','plus','class="primary"')}</div></div>${state.demo ? `<div class="demo-banner">${badge('DEMO WORKSPACE','warning')}<span>Explore 28 sample trades. Your real journal stays separate.</span>${command('exit-demo','Start My Journal')}</div>` : ''}<main>${content}</main></div>`;
}
export function drawCharts(data, state, rows) {
  const charts = [], points = curve(rows), colors = { green:'#66d8ad', red:'#f17f85', blue:'#85aef2', muted:'#a0aab7' };
  Chart.defaults.color = colors.muted; Chart.defaults.font.family = '-apple-system, Segoe UI, sans-serif'; Chart.defaults.font.size = 10;
  const addLine = (id, values, labels, color, y = {}) => {
    const canvas = document.getElementById(id); if (!canvas) return;
    const context = canvas.getContext('2d'), gradient = context.createLinearGradient(0,0,0,canvas.parentElement.clientHeight); gradient.addColorStop(0,color+'24'); gradient.addColorStop(1,color+'01');
    charts.push(new Chart(canvas,{ type:'line',data:{ labels, datasets:[{data:values,borderColor:color,backgroundColor:gradient,fill:true,borderWidth:2,pointRadius:0,pointHitRadius:12,cubicInterpolationMode:'monotone',tension:.2}] },options:{ responsive:true,maintainAspectRatio:false,animation:data.preferences.animations?{duration:180}:false,plugins:{legend:{display:false}},scales:{x:{grid:{display:false},border:{display:false},ticks:{maxTicksLimit:5,maxRotation:0}},y:{position:'right',grid:{color:colors.muted+'19'},border:{display:false},...y}}} }));
  };
  const labels = points.map((p,i) => i ? new Intl.DateTimeFormat('en',{month:'short',day:'numeric',timeZone:data.preferences.timezone}).format(p.date) : '');
  addLine('equity',points.map(p=>state.curveMode==='R'?p.r:state.curveMode==='%'?p.equity/data.preferences.accountSize*100:p.equity),labels,colors.green);
  addLine('cumulative-r',points.map(p=>p.r),labels,colors.green); addLine('drawdown',points.map(p=>p.drawdown),labels,colors.red);
  const ordered = [...rows].sort((a,b)=>a.date-b.date);
  addLine('rolling',ordered.map((_,i)=>{const window=ordered.slice(Math.max(0,i-19),i+1);return window.filter(t=>net(t)>=.005).length/window.length*100;}),labels.slice(1),colors.blue,{min:0,max:100});
  const canvas=document.getElementById('group-bars'); if(canvas) {
    const cohorts=groups(rows,state.analysis,data.preferences.timezone), key={'Average R':'averageR','Win rate':'winRate','Net PnL':'netPnL','Expectancy':'expectancy','Profit factor':'profitFactor'}[state.groupMetric];
    charts.push(new Chart(canvas,{type:'bar',data:{labels:cohorts.map(g=>g.name),datasets:[{data:cohorts.map(g=>g[key]),backgroundColor:cohorts.map(g=>g[key]<0?colors.red+'cc':colors.green+'cc'),borderRadius:3,barThickness:14}]},options:{indexAxis:'y',responsive:true,maintainAspectRatio:false,animation:false,plugins:{legend:{display:false}},scales:{x:{grid:{color:colors.muted+'19'},border:{display:false}},y:{grid:{display:false},border:{display:false}}}}}));
  }
  const months=new Map();for(const t of rows){const key=dateKey(t.date,data.preferences.timezone).slice(0,7);if(!months.has(key))months.set(key,[]);months.get(key).push(t);}const monthly=[...months].sort();
  addLine('discipline-chart',monthly.map(([,trades])=>performance(trades).compliance),monthly.map(([key])=>key),colors.green,{min:0,max:100});
  return charts;
}
