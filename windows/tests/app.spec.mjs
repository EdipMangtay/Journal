import { test, expect, _electron as electron } from '@playwright/test';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import os from 'node:os';

test('complete offline journal, all screens, images, backup and persistence',async()=>{
  test.setTimeout(180000);
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'journal-ui-test-'));
  const options=process.env.JOURNAL_E2E_EXECUTABLE?{executablePath:process.env.JOURNAL_E2E_EXECUTABLE,args:[]}:{args:['.']};
  const launch=()=>electron.launch({...options,env:{...process.env,JOURNAL_TEST_DATA_DIR:directory},timeout:30000});
  let app=await launch(),page=await app.firstWindow();const errors=[];
  const watch=()=>page.on('pageerror',error=>errors.push(error.message));watch();
  const nav=async name=>page.locator('.nav').getByRole('button',{name,exact:true}).click();
  const press=async name=>page.getByRole('button',{name,exact:true}).click();
  try{
    await expect(page.getByRole('heading',{name:'Process is the edge.'})).toBeVisible();
    await expect(page.locator('.demo-banner')).toBeVisible();
    await page.screenshot({path:'test-results/desktop-dashboard.png',fullPage:true});
    await page.screenshot({path:'test-results/dashboard-viewport.png'});
    expect(await page.locator('#equity').evaluate(c=>Array.from(c.getContext('2d').getImageData(0,0,c.width,c.height).data).some((v,i)=>i%4===3&&v>0))).toBe(true);
    for(const name of ['Trades','Calendar','Analytics','Setup Analysis','Playbook','Mistakes','Screenshots','Statistics','Review','Settings']){
      await nav(name);await expect(page.locator('main h1')).toBeVisible();await page.screenshot({path:`test-results/${name.toLowerCase().replaceAll(' ','-')}.png`,fullPage:true});
    }
    await nav('Dashboard');await page.setViewportSize({width:390,height:844});
    expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:'test-results/narrow-dashboard.png',fullPage:true});
    await page.setViewportSize({width:1440,height:1000});await page.locator('.demo-banner').getByRole('button',{name:'Start My Journal'}).click();
    await expect(page.locator('.demo-banner')).toHaveCount(0);
    await nav('Playbook');await press('New setup');await page.getByLabel('Setup name',{exact:true}).fill('Test setup');await page.getByLabel('Ideal conditions').fill('Sweep and displacement');await press('Save setup');
    await expect(page.getByRole('heading',{name:'Test setup',exact:true})).toBeVisible();
    await page.locator('.topbar').getByRole('button',{name:'New trade'}).click();
    await page.getByLabel('Setup',{exact:true}).selectOption({label:'Test setup'});await page.getByLabel('Gross PnL USD',{exact:true}).fill('250');await page.getByLabel('R multiple',{exact:true}).fill('2');
    await page.screenshot({path:'test-results/trade-editor.png'});
    await page.getByText('Prices, risk & duration',{exact:true}).click();await page.getByLabel('Fees',{exact:true}).fill('5');await page.getByLabel('Risk USD',{exact:true}).fill('100');await press('Calculate R from net PnL');await expect(page.getByLabel('R multiple',{exact:true})).toHaveValue('2.45');
    await page.getByText('Quarterly Theory · QT',{exact:true}).click();await page.getByLabel('QT enabled',{exact:true}).check();await page.getByLabel('QT model valid',{exact:true}).check();await page.getByLabel('QT bias aligned',{exact:true}).check();
    await page.getByText('SSMT & TSMO confirmations',{exact:true}).click();await page.getByLabel('SSMT confirmation',{exact:true}).selectOption('Yes');await page.getByLabel('Valid SSMT',{exact:true}).check();await page.locator('#market-checklist').getByLabel('ES',{exact:true}).check();
    await page.getByText('Trade thesis & review notes',{exact:true}).click();await page.getByLabel('Trade thesis',{exact:true}).fill('Offline persistence <script>alert(1)</script>');await page.getByLabel('Key lesson',{exact:true}).fill('Wait for displacement');
    const icon=path.resolve('assets/icon.png');await app.evaluate(({dialog},file)=>{dialog.showOpenDialog=async()=>({canceled:false,filePaths:[file]});},icon);await press('Add images...');await expect(page.locator('#draft-shots img')).toHaveCount(1);
    await page.locator('#draft-shots [data-shot]').click();const viewer=page.locator('.image-dialog');await expect(viewer.locator('img')).toBeVisible();
    await expect.poll(()=>viewer.locator('img').evaluate(i=>i.naturalWidth)).toBeGreaterThan(0);
    await viewer.getByRole('button',{name:'Arrow',exact:true}).click();const box=await viewer.locator('canvas').boundingBox();await page.mouse.move(box.x+box.width*.2,box.y+box.height*.2);await page.mouse.down();await page.mouse.move(box.x+box.width*.7,box.y+box.height*.7);await page.mouse.up();
    await expect(viewer.locator('.annotation-count')).toHaveText('1 annotations');await viewer.getByRole('button',{name:'Save review',exact:true}).click();await press('Save trade');await expect(page.locator('#editor')).not.toBeVisible();
    await nav('Trades');await expect(page.locator('.trade-rows')).toContainText('$245.00');await page.locator('[data-trade]').click();await expect(page.locator('#editor')).toContainText('Offline persistence <script>alert(1)</script>');await press('Edit trade');await page.getByLabel('Gross PnL USD',{exact:true}).fill('999');await press('Cancel');await expect(page.locator('.trade-rows')).toContainText('$245.00');
    await page.getByLabel('Search trades').fill('valid qt');await expect(page.locator('[data-trade]')).toHaveCount(1);await press('Reset');
    await nav('Review');await press('New review');await page.getByLabel('What worked?',{exact:true}).fill('Patient execution');await page.getByLabel('What is one adjustment for the next period?').fill('Patient execution');await expect(page.locator('#review-snapshot')).toContainText('$245.00');await press('Save review');await expect(page.getByText('Patient execution',{exact:true})).toBeVisible();
    await nav('Settings');await page.getByLabel('Time zone',{exact:true}).fill('Europe/Istanbul');await press('Save preferences');await expect(page.getByLabel('Time zone',{exact:true})).toHaveValue('Europe/Istanbul');
    const saved=await page.evaluate(()=>window.journal.load());expect(saved.trades).toHaveLength(1);expect(saved.trades[0].ssmt.markets).toEqual(['ES']);expect(saved.screenshots[0].screenshot.annotations).toHaveLength(1);expect(saved.trades[0].qt.valid).toBe(true);
    const backup=path.join(directory,'export.json');await app.evaluate(({dialog},file)=>{dialog.showSaveDialog=async()=>({canceled:false,filePath:file});},backup);await press('Export JSON backup');await expect.poll(async()=>{try{return JSON.parse(await fs.readFile(backup,'utf8')).trades.length;}catch{return 0;}}).toBe(1);
    await fs.copyFile(backup,'test-results/windows-backup.json');
    await app.close();app=await launch();page=await app.firstWindow();watch();await nav('Trades');await expect(page.locator('[data-trade]')).toHaveCount(1);await expect(page.locator('.trade-rows')).toContainText('$245.00');
    await nav('Settings');await expect(page.getByLabel('Time zone',{exact:true})).toHaveValue('Europe/Istanbul');await press('Open Demo');await nav('Trades');await expect(page.locator('[data-trade]')).toHaveCount(28);await page.locator('.demo-banner').getByRole('button',{name:'Start My Journal'}).click();await expect(page.locator('[data-trade]')).toHaveCount(1);
    await page.locator('[data-trade]').click();await press('Delete');await page.locator('#confirm').getByRole('button',{name:'Delete',exact:true}).click();await expect(page.locator('[data-trade]')).toHaveCount(0);
    await app.evaluate(({dialog},file)=>{dialog.showOpenDialog=async()=>({canceled:false,filePaths:[file]});dialog.showMessageBox=async()=>({response:1});},backup);await nav('Settings');await press('Restore JSON backup');await nav('Trades');await expect(page.locator('[data-trade]')).toHaveCount(1);
    expect(errors).toEqual([]);
  }finally{await app.close();await fs.rm(directory,{recursive:true,force:true});}
});
