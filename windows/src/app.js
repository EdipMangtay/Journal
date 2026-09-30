import './theme.css';
import { createIcons, icons } from 'lucide';
import demoFixture from '../assets/demo.json';
import { newTrade, parseBackup, tradeSchema, net, compliant, execution, groups, dateKey, matchesSearch, periodRange } from '../shared/core.mjs';
import { esc, glyph, command, toggle, imageGallery, workspaceView, drawCharts, navigation } from './views.js';
import { tradeEditor, setupEditor, reviewEditor, reviewSnapshot, detailView, processPreview } from './editors.js';
import { openImage } from './image-review.js';

const api=window.journal, $=selector=>document.querySelector(selector), editor=$('#editor');
const emptyFilters=()=>({search:'',instrument:'',session:'',compliance:'',from:'',to:''});
const state={view:'Dashboard',filters:emptyFilters(),facets:{},advanced:false,period:'ALL TIME',curveMode:'$',analysis:'Setup',groupMetric:'Average R',month:new Date(),selectedDay:'',showR:false,imageCategory:'',tradeSort:'Newest',demo:false,collapsed:false};
let data,charts=[],draft,draftKind,draftShots=[],busy=false;
const decorate=()=>createIcons({icons});
function notify(message,error=false){$('#toast').textContent=message;$('#toast').classList.toggle('warning',error);clearTimeout(notify.timer);notify.timer=setTimeout(()=>$('#toast').textContent='',error?10000:4000);}
const report=error=>notify(error.issues?error.issues.map(i=>i.message).join('\n'):error.message,true);
function filtered(){
  const f=state.filters,zone=data.preferences.timezone,range=state.view==='Dashboard'&&state.period!=='ALL TIME'?periodRange(Date.now(),{TODAY:'Daily','THIS WEEK':'Weekly','THIS MONTH':'Monthly'}[state.period],zone):null;
  return data.trades.filter(t=>{const day=dateKey(t.date,zone);return matchesSearch(t,f.search)&&(!f.instrument||t.instrument===f.instrument)&&(!f.session||t.session===f.session)&&(!f.compliance||compliant(t)===(f.compliance==='valid'))&&(!f.from||day>=f.from)&&(!f.to||day<=f.to)&&(!range||day>=range.from&&day<=range.to)&&Object.entries(state.facets).every(([key,value])=>!value||groups([t],key,zone).some(g=>g.name===value));});
}
function render(){
  charts.forEach(c=>c.destroy());const p=data.preferences;
  document.documentElement.classList.toggle('light',p.theme==='Light'||p.theme==='System'&&matchMedia('(prefers-color-scheme: light)').matches);document.documentElement.classList.toggle('no-motion',!p.animations);
  const rows=filtered();$('#app').innerHTML=workspaceView(data,state,rows);decorate();charts=drawCharts(data,state,rows);
  if(state.view==='Settings')api.dataPath().then(path=>{if($('#data-path'))$('#data-path').textContent=path;}).catch(report);
}
async function persist(next){const valid=parseBackup({...next,started:true});data=state.demo?valid:await api.save(valid);render();}
function showEditor(html,kind){draftKind=kind;editor.innerHTML=html;editor.style.width=kind==='detail'?'min(1000px,calc(100vw - 40px))':'';if(!editor.open)editor.showModal();decorate();}
function editTrade(id){const record=data.trades.find(t=>t.id===id);draft=structuredClone(record||newTrade());draftShots=structuredClone(data.screenshots.filter(s=>s.tradeID===id).map(s=>s.screenshot));showEditor(tradeEditor(draft,data,draftShots,!record),'trade');updateTradePreview();}
function showTrade(id){draft=structuredClone(data.trades.find(t=>t.id===id));if(draft){draftShots=[];showEditor(detailView(draft,data),'detail');}}
const blankSetup=name=>({id:crypto.randomUUID(),playbookID:crypto.randomUUID(),name,summary:'',conditions:'',entry:'',invalidation:'',target:'',risk:'',images:[]});
function editSetup(id){draft=structuredClone(data.setups.find(s=>s.id===id)||blankSetup(''));draftShots=structuredClone(draft.images);showEditor(setupEditor(draft,draftShots),'setup');}
function editReview(id){draft=structuredClone(data.reviews.find(r=>r.id===id)||{id:crypto.randomUUID(),period:'Weekly',date:Date.now(),worked:'',didNot:'',repeatNext:'',stop:'',adjustment:''});draftShots=[];showEditor(reviewEditor(draft,data),'review');}
function confirmAction(message){const dialog=$('#confirm');dialog.returnValue='cancel';dialog.innerHTML=`<p>${esc(message)}</p><form method="dialog" class="footer"><button value="cancel" autofocus>Cancel</button><button value="confirm" class="danger">Delete</button></form>`;dialog.showModal();return new Promise(resolve=>dialog.addEventListener('close',()=>resolve(dialog.returnValue==='confirm'),{once:true}));}
function gatherTrade(form,validate=true){
  const result=structuredClone(draft),values=new FormData(form),lists=['contextTimeframes','liquidityTaken','confirmations','brokenRules','emotional.emotions','ssmt.markets'],optional=['entryPrice','stopLoss','takeProfit','exitPrice','positionSize','riskDollars','riskPercent','rMultiple','crt.high','crt.low'];
  for(const input of form.querySelectorAll('[name]')){
    const name=input.name;if(lists.includes(name)||['attachment-category','record-exit'].includes(name))continue;
    let value=input.type==='checkbox'?input.checked:input.value;
    if(input.type==='number'||input.type==='range')value=value===''&&optional.includes(name)?undefined:Number(value);
    if(['date','exitDate'].includes(name))value=value?new Date(value).getTime():undefined;
    if(name==='tags')value=value.split(',').map(v=>v.trim()).filter(Boolean);
    const[head,tail]=name.split('.');if(tail)result[head][tail]=value;else result[head]=value;
  }
  for(const name of lists){const[head,tail]=name.split('.');if(tail)result[head][tail]=values.getAll(name);else result[head]=values.getAll(name);}
  if(!values.has('record-exit'))delete result.exitDate;
  const setup=data.setups.find(s=>s.id===result.setupID);if(setup)result.setupID=setup.id;else delete result.setupID;result.setupName=setup?.name||'Unassigned';
  return validate?tradeSchema.parse(result):result;
}
function updateTradePreview(){
  if(draftKind!=='trade'||!$('#edit-form'))return;const t=gatherTrade($('#edit-form'),false);$('#process-preview').innerHTML=processPreview(t);$('#overall-score').textContent=`${execution(t).toFixed(0)} / 100`;
  const planned=t.entryPrice!=null&&t.stopLoss!=null&&t.takeProfit!=null&&t.entryPrice!==t.stopLoss?Math.abs(t.takeProfit-t.entryPrice)/Math.abs(t.entryPrice-t.stopLoss):null;
  $('#price-preview').textContent=`Net PnL ${net(t).toFixed(2)} / Planned RR ${planned==null?'Not recorded':planned.toFixed(2)}`;
  $('#broken-rule-fields').hidden=t.followsPlan&&!t.brokenRules.length;$('#exit-time-field').hidden=!$('#edit-form [name="record-exit"]').checked;
  for(const element of editor.querySelectorAll('[data-conditional]')){const[head,key]=element.dataset.conditional.split('.');element.hidden=key==='model'?t[head][key]==='None':!t[head][key];}
}
function refreshShots(){$('#draft-shots').innerHTML=imageGallery(draftShots,true);decorate();}
async function addImages(files){
  if(!['trade','setup'].includes(draftKind))return;
  const images=files?await api.dropImages(await Promise.all([...files].map(async f=>({name:f.name,bytes:new Uint8Array(await f.arrayBuffer())})))):await api.pickImages();
  const category=editor.querySelector('[name="attachment-category"]').value;images.forEach(s=>s.category=category);draftShots.push(...images);refreshShots();
}
function showImage(id){const shot=[...draftShots,...data.screenshots.map(s=>s.screenshot),...data.setups.flatMap(s=>s.images)].find(s=>s.id===id);if(!shot)return;openImage(shot,async updated=>{
  if(['trade','setup'].includes(draftKind)&&editor.open&&draftShots.some(s=>s.id===id)){draftShots=draftShots.map(s=>s.id===id?updated:s);refreshShots();return;}
  const next=structuredClone(data);next.screenshots=next.screenshots.map(s=>s.screenshot.id===id?{...s,screenshot:updated}:s);next.setups.forEach(s=>s.images=s.images.map(image=>image.id===id?updated:image));await persist(next);if(editor.open&&draftKind==='detail')showTrade(draft.id);
},decorate,report);}
function searchCommand(){
  const dialog=document.createElement('dialog');dialog.className='command-palette';dialog.innerHTML=`<header><input type="search" aria-label="Search workspace" placeholder="Search trades or navigate...">${command('dismiss','Close')}</header><div class="body"></div>`;document.body.append(dialog);const input=dialog.querySelector('input'),body=dialog.querySelector('.body');
  function results(){const q=input.value;body.innerHTML=navigation.filter(([name])=>!q||name.toLowerCase().includes(q.toLowerCase())).map(([name,icon])=>`<button data-destination="${name}">${glyph(icon)}${name}</button>`).join('')+data.trades.filter(t=>matchesSearch(t,q)).sort((a,b)=>b.date-a.date).slice(0,12).map(t=>`<button data-result="${t.id}">${esc(t.instrument)} / ${esc(t.setupName)}<small>${dateKey(t.date,data.preferences.timezone)}</small></button>`).join('');decorate();}
  input.oninput=results;dialog.onclick=e=>{const b=e.target.closest('button');if(!b)return;dialog.close();if(b.dataset.destination==='New Trade')editTrade();else if(b.dataset.destination){state.view=b.dataset.destination;render();}else if(b.dataset.result)showTrade(b.dataset.result);};dialog.onclose=()=>dialog.remove();results();dialog.showModal();input.focus();
}
function dayInstant(day){
  // Resolve noon in the journal zone rather than the computer's current zone.
  let stamp=Date.parse(day+'T12:00:00Z');const formatter=new Intl.DateTimeFormat('en-CA',{timeZone:data.preferences.timezone,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
  for(let i=0;i<2;i++){const p=formatter.formatToParts(stamp),get=k=>p.find(x=>x.type===k).value,wall=Date.UTC(+get('year'),+get('month')-1,+get('day'),+get('hour'),+get('minute'));stamp+=Date.parse(day+'T12:00:00Z')-wall;}return stamp;
}
async function deleteRecord(kind,id){if(!await confirmAction(`Delete this ${kind}? This cannot be undone.`))return;const next=structuredClone(data),key={trade:'trades',setup:'setups',review:'reviews'}[kind];next[key]=next[key].filter(item=>item.id!==id);if(kind==='trade')next.screenshots=next.screenshots.filter(s=>s.tradeID!==id);if(kind==='setup')next.trades.forEach(t=>{if(t.setupID===id){delete t.setupID;t.setupName='Unassigned';}});await persist(next);if(editor.open)editor.close();notify('Deleted.');}
document.addEventListener('click',async event=>{
  const target=event.target.closest('button,.drop-zone');if(!target||busy||target.closest('.image-dialog,.command-palette,#confirm'))return;
  try{
    if(target.dataset.view){state.view=target.dataset.view;render();return;}if(target.dataset.trade){showTrade(target.dataset.trade);return;}if(target.dataset.shot){showImage(target.dataset.shot);return;}
    for(const[key,stateKey]of[['period','period'],['curveMode','curveMode'],['day','selectedDay']])if(target.dataset[key]){state[stateKey]=target.dataset[key];render();return;}
    const action=target.dataset.action;
    if(target.classList.contains('drop-zone')||action==='add-images'){await addImages();return;}
    if(action==='new-trade')editTrade();else if(action==='edit-trade')editTrade(draft.id);else if(action==='close-editor')editor.close();
    else if(action==='new-setup'||action==='edit-setup')editSetup(target.dataset.id);else if(action==='new-review'||action==='edit-review')editReview(target.dataset.id);
    else if(action==='delete-setup'||action==='delete-review')await deleteRecord(action.slice(7),target.dataset.id);else if(action==='delete-record')await deleteRecord('trade',draft.id);
    else if(action==='collapse-sidebar'){state.collapsed=!state.collapsed;render();}else if(action==='search-command')searchCommand();
    else if(action==='toggle-filters'){state.advanced=!state.advanced;render();}else if(action==='reset-filters'){state.filters=emptyFilters();state.facets={};render();}
    else if(action?.startsWith('month-')){state.month=action==='month-today'?new Date():new Date(state.month.getFullYear(),state.month.getMonth()+(action==='month-next'?1:-1),1);state.selectedDay='';render();}
    else if(action==='demo'){state.demo=true;data=structuredClone(demoFixture);render();}else if(action==='exit-demo'){data=await api.load();state.demo=false;await persist(data);}
    else if(action==='remove-shot'){draftShots=draftShots.filter(s=>s.id!==target.dataset.id);refreshShots();}
    else if(action==='calculate-r'){const t=gatherTrade($('#edit-form'),false);if(!(t.riskDollars>0))throw new Error('Enter positive dollar risk to calculate net R.');editor.querySelector('[name="rMultiple"]').value=net(t)/t.riskDollars;updateTradePreview();}
    else if(action==='add-broken-rule'||action==='add-market'){
      const rule=action==='add-broken-rule',input=$(rule?'#custom-broken-rule':'#custom-market'),value=input.value.trim(),name=rule?'brokenRules':'ssmt.markets';if(!value)return;const list=$(rule?'#broken-rule-fields .checklist':'#market-checklist .checklist'),existing=[...list.querySelectorAll('input')].find(i=>i.value===value);if(existing)existing.checked=true;else list.insertAdjacentHTML('beforeend',toggle(name,value,true,`value="${esc(value)}"`));if(rule)editor.querySelector('[name="followsPlan"]').checked=false;input.value='';updateTradePreview();
    }else if(action==='quick-setup'){
      const name=$('#quick-setup').value.trim();if(!name)return;const t=gatherTrade($('#edit-form'),false),s=blankSetup(name);await persist({...data,setups:[...data.setups,s]});draft={...t,setupID:s.id,setupName:s.name};showEditor(tradeEditor(draft,data,draftShots,true),'trade');updateTradePreview();
    }else if(action==='add-session'){
      const input=$('#custom-session'),name=input.value.trim();if(!name)return;const hidden=$('#preferences [name=sessions]'),names=hidden.value.split(',').map(v=>v.trim()).filter(Boolean);if(name.includes(','))throw new Error('Session names cannot contain commas.');if(names.includes(name))return;names.push(name);hidden.value=names.join(', ');$('#session-fields').insertAdjacentHTML('beforeend',`<div class="session-row"><span>${esc(name)}</span><input name="session:${esc(name)}" aria-label="${esc(name)} session hours">${command('remove-session','', 'circle-minus',`class="icon" title="Remove session" aria-label="Remove session" data-id="${esc(name)}"`)}</div>`);input.value='';decorate();
    }else if(action==='remove-session'){const hidden=$('#preferences [name=sessions]');hidden.value=hidden.value.split(',').map(v=>v.trim()).filter(v=>v!==target.dataset.id).join(', ');target.closest('.session-row').remove();}
    else if(action==='remove-rule')await persist({...data,rules:data.rules.filter(r=>r.id!==target.dataset.id)});
    else if(['export-backup','import-backup','export-csv','import-csv'].includes(action)){busy=true;const result=await api[{'export-backup':'exportBackup','import-backup':'importBackup','export-csv':'exportCSV','import-csv':'importCSV'}[action]](data,state.demo);if(result&&action.startsWith('import')){data=result;render();notify('Import complete.');}else if(result)notify('Export complete.');}
  }catch(error){report(error);}finally{busy=false;}
});
document.addEventListener('change',event=>{
  const input=event.target;if(input.closest('.image-dialog'))return;
  if(input.dataset.filter){state.filters[input.dataset.filter]=input.value;render();}if(input.dataset.facet){state.facets[input.dataset.facet]=input.value;render();}
  const keys={'dimension':'analysis','group-metric':'groupMetric','trade-sort':'tradeSort','image-category':'imageCategory','show-r':'showR'};if(keys[input.id]){state[keys[input.id]]=input.type==='checkbox'?input.checked:input.value;render();}
  if(input.dataset.shotCategory){const shot=draftShots.find(s=>s.id===input.dataset.shotCategory);if(shot)shot.category=input.value;}
  if(input.id==='choose-instrument'&&input.value)editor.querySelector('[name=instrument]').value=input.value;if(input.id==='liquidity-reference')editor.querySelector('[name=drawOnLiquidity]').value=input.value;
  if(input.name==='followsPlan'&&input.checked)editor.querySelectorAll('[name=brokenRules]').forEach(i=>i.checked=false);if(input.name==='brokenRules'&&input.checked)editor.querySelector('[name=followsPlan]').checked=false;
  if(input.closest('#edit-form')){updateTradePreview();if(draftKind==='review'){const form=$('#edit-form');if(form.elements.date.value)$('#review-snapshot').innerHTML=reviewSnapshot(data,form.elements.period.value,dayInstant(form.elements.date.value));}}
});
document.addEventListener('input',event=>{
  const input=event.target;if(input.closest('.image-dialog'))return;if(input.type==='range'&&input.nextElementSibling?.tagName==='OUTPUT')input.nextElementSibling.textContent=input.value;
  if(input.id==='search'){state.filters.search=input.value;const position=input.selectionStart;clearTimeout(notify.searchTimer);notify.searchTimer=setTimeout(()=>{render();$('#search')?.focus();$('#search')?.setSelectionRange(position,position);},160);}if(input.closest('#edit-form'))updateTradePreview();
});
for(const name of ['dragover','dragleave','drop'])document.addEventListener(name,event=>{const zone=event.target.closest('.drop-zone');if(!zone)return;event.preventDefault();zone.classList.toggle('dragging',name==='dragover');if(name==='drop')addImages(event.dataTransfer.files).catch(report);});
document.addEventListener('keydown',event=>{if((event.ctrlKey||event.metaKey)&&!document.querySelector('dialog[open]')){const key=event.key.toLowerCase();if(key==='n'||key==='k'){event.preventDefault();if(key==='n')editTrade();else searchCommand();}}if(event.key==='Enter'&&event.target.classList.contains('drop-zone')){event.preventDefault();addImages().catch(report);}});
document.addEventListener('submit',async event=>{
  const form=event.target;if(form.closest('#confirm'))return;event.preventDefault();if(busy)return;busy=true;const submit=form.querySelector('[type=submit]');if(submit)submit.disabled=true;
  try{
    const next=structuredClone(data),fields=new FormData(form);
    if(form.id==='edit-form'){
      let record;if(draftKind==='trade'){record=gatherTrade(form);next.screenshots=[...next.screenshots.filter(s=>s.tradeID!==record.id),...draftShots.map(screenshot=>({tradeID:record.id,screenshot}))];}
      else if(draftKind==='review')record={...draft,...Object.fromEntries(fields),date:dayInstant(fields.get('date'))};
      else{record={...draft,images:draftShots};for(const key of ['name','summary','conditions','entry','invalidation','target','risk'])record[key]=fields.get(key);}
      const key={trade:'trades',setup:'setups',review:'reviews'}[draftKind],index=next[key].findIndex(x=>x.id===record.id);if(index<0)next[key].push(record);else next[key][index]=record;
      if(draftKind==='setup')next.trades.forEach(t=>{if(t.setupID===record.id)t.setupName=record.name;});await persist(next);editor.close();notify('Saved.');
    }else if(form.id==='preferences'){
      const sessions=fields.get('sessions').split(',').map(v=>v.trim()).filter(Boolean);next.preferences={...next.preferences,accountSize:Number(fields.get('accountSize')),defaultRiskPercent:Number(fields.get('defaultRiskPercent')),currency:fields.get('currency'),timezone:fields.get('timezone'),theme:fields.get('theme'),animations:fields.has('animations'),sessions,sessionHours:Object.fromEntries(sessions.map(s=>[s,fields.get('session:'+s)||'']))};await persist(next);notify('Preferences saved.');
    }else if(form.id==='instruments'){
      const enabled=fields.getAll('enabled-instrument');next.instruments.forEach(i=>i.enabled=enabled.includes(i.symbol));const symbol=fields.get('new-symbol').trim().toUpperCase();if(symbol&&!next.instruments.some(i=>i.symbol===symbol))next.instruments.push({id:crypto.randomUUID(),symbol,enabled:true});await persist(next);notify('Instruments saved.');
    }else if(form.id==='rules'){const name=fields.get('new-rule').trim();if(name&&!next.rules.some(r=>r.name===name))next.rules.push({id:crypto.randomUUID(),name});await persist(next);notify('Rules saved.');}
  }catch(error){const message=error.issues?error.issues.map(i=>i.message).join('\n'):error.message;if($('#form-error')&&editor.open){$('#form-error').textContent=message;$('#form-error').scrollIntoView({block:'nearest'});}else report(error);}finally{busy=false;if(submit)submit.disabled=false;}
});
editor.addEventListener('close',()=>{draftShots=[];draftKind=undefined;});
matchMedia('(prefers-color-scheme: light)').addEventListener('change',()=>{if(data?.preferences.theme==='System')render();});
async function start(){try{if(!api)throw new Error('Open Liquidity Edge from the installed application.');data=await api.load();if(!data.started&&!data.trades.length&&!data.setups.length&&!data.reviews.length){state.demo=true;data=structuredClone(demoFixture);}render();}catch(error){$('#app').innerHTML=`<main><h1>Unable to open your journal</h1><p class="error">${esc(error.message)}</p>${command('retry','Retry')}${api?command('recover','Restore JSON backup'):''}</main>`;$('[data-action=retry]').onclick=start;const recover=$('[data-action=recover]');if(recover)recover.onclick=async()=>{try{const restored=await api.importBackup();if(restored){data=restored;state.demo=false;render();}}catch(e){report(e);}};}}
start();
