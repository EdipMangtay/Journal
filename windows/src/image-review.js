import { catalog } from '../shared/core.mjs';
import { esc, command, options } from './views.js';

export function openImage(original,onSave,decorate,onError){
  const shot=structuredClone(original),dialog=document.createElement('dialog');dialog.className='image-dialog';
  const tools=[['Pan','hand'],['Arrow','move-up-right'],['Rectangle','square'],['Text','type'],['Liquidity marker','align-horizontal-distribute-center']];
  dialog.innerHTML=`<header><h2>${esc(shot.name)}</h2><select aria-label="Review image category">${options(catalog.screenshotCategories,shot.category)}</select><div class="actions">${command('image-cancel','Cancel')}${command('image-save','Save review','','class="primary"')}</div></header><div class="image-toolbar"><div class="segments">${tools.map(([name,icon])=>command('image-tool','',icon,`data-tool="${name}" title="${name}" aria-label="${name}" class="icon ${name==='Pan'?'selected':''}"`)).join('')}</div><input type="text" aria-label="Annotation label" placeholder="Label" hidden>${command('image-undo','','undo-2','class="icon" title="Undo annotation" aria-label="Undo annotation"')}<input type="range" min="0.5" max="4" step="0.1" value="1" aria-label="Zoom"><output>100%</output>${command('image-fullscreen','','maximize','class="icon" title="Full screen" aria-label="Full screen"')}</div><div class="image-scroll"><div class="image-view"><img alt="${esc(shot.name)}"><canvas aria-label="Screenshot annotations"></canvas></div></div><footer class="footer"><span class="caption annotation-count"></span><span class="caption">Original image remains intact.</span></footer>`;
  document.body.append(dialog);const image=dialog.querySelector('img'),canvas=dialog.querySelector('canvas'),container=dialog.querySelector('.image-view'),scroll=dialog.querySelector('.image-scroll'),label=dialog.querySelector('[type=text]');let tool='Pan',zoom=1,pending,start,baseWidth=800,saving=false;
  const draw=()=>{
    const ctx=canvas.getContext('2d'),width=canvas.width,height=canvas.height;ctx.clearRect(0,0,width,height);ctx.strokeStyle='#e9b66d';ctx.fillStyle='#e9b66d';ctx.lineWidth=2;ctx.font='600 14px sans-serif';
    for(const a of [...shot.annotations,...(pending?[pending]:[])]){
      const x=a.x*width,y=a.y*height,ex=a.endX*width,ey=a.endY*height;ctx.beginPath();
      if(a.kind==='Rectangle')ctx.rect(Math.min(x,ex),Math.min(y,ey),Math.abs(ex-x),Math.abs(ey-y));
      if(a.kind==='Arrow'){ctx.moveTo(x,y);ctx.lineTo(ex,ey);const angle=Math.atan2(ey-y,ex-x);for(const offset of [-Math.PI/6,Math.PI/6]){ctx.moveTo(ex,ey);ctx.lineTo(ex-12*Math.cos(angle+offset),ey-12*Math.sin(angle+offset));}}
      if(a.kind==='Liquidity marker'){ctx.moveTo(x,y);ctx.lineTo(ex,y);}ctx.stroke();if(a.kind==='Text'||a.kind==='Liquidity marker')ctx.fillText(a.text,x,Math.max(14,y-12));
    }
    dialog.querySelector('.annotation-count').textContent=`${shot.annotations.length} annotations`;dialog.querySelector('[data-action=image-undo]').disabled=!shot.annotations.length;
  };
  const resize=()=>{container.style.width=`${baseWidth*zoom}px`;container.style.height=`${baseWidth*zoom*image.naturalHeight/image.naturalWidth}px`;canvas.width=Math.round(baseWidth*zoom);canvas.height=Math.round(baseWidth*zoom*image.naturalHeight/image.naturalWidth);draw();};
  image.onload=()=>{baseWidth=Math.min(image.naturalWidth,Math.max(300,scroll.clientWidth-32));resize();};image.onerror=()=>onError(new Error('Unable to display this image.'));
  window.journal.renderImage(shot.imageData).then(data=>image.src=`data:image/png;base64,${data}`).catch(onError);
  const point=e=>{const rect=canvas.getBoundingClientRect(),clamp=x=>Math.max(0,Math.min(1,x));return{x:clamp((e.clientX-rect.left)/rect.width),y:clamp((e.clientY-rect.top)/rect.height)};};
  canvas.onpointerdown=e=>{if(e.button!==0)return;start={...point(e),clientX:e.clientX,clientY:e.clientY,scrollLeft:scroll.scrollLeft,scrollTop:scroll.scrollTop};canvas.setPointerCapture(e.pointerId);if(tool!=='Pan'){pending={id:crypto.randomUUID(),kind:tool,x:start.x,y:start.y,endX:start.x,endY:start.y,text:label.value};draw();}};
  canvas.onpointermove=e=>{if(!start)return;if(tool==='Pan'){scroll.scrollLeft=start.scrollLeft-(e.clientX-start.clientX);scroll.scrollTop=start.scrollTop-(e.clientY-start.clientY);}else{const p=point(e);pending.endX=p.x;pending.endY=p.y;draw();}};
  canvas.onpointerup=()=>{if(pending){shot.annotations.push(pending);pending=undefined;draw();}start=undefined;};canvas.onpointercancel=()=>{start=pending=undefined;draw();};
  dialog.querySelector('[type=range]').oninput=e=>{zoom=Number(e.target.value);dialog.querySelector('output').textContent=Math.round(zoom*100)+'%';resize();};
  dialog.onclick=async e=>{const button=e.target.closest('[data-action]');if(!button||saving)return;const action=button.dataset.action;
    if(action==='image-cancel')dialog.close();else if(action==='image-tool'){tool=button.dataset.tool;dialog.querySelectorAll('[data-tool]').forEach(b=>b.classList.toggle('selected',b===button));label.hidden=!['Text','Liquidity marker'].includes(tool);canvas.style.cursor=tool==='Pan'?'grab':'crosshair';}
    else if(action==='image-undo'){shot.annotations.pop();draw();}else if(action==='image-fullscreen'){dialog.classList.toggle('expanded');if(image.complete)resize();}
    else if(action==='image-save'){saving=true;button.disabled=true;try{shot.category=dialog.querySelector('select').value;await onSave(shot);dialog.close();}catch(error){onError(error);}finally{saving=false;button.disabled=false;}}
  };
  dialog.onclose=()=>dialog.remove();dialog.showModal();decorate();
}
