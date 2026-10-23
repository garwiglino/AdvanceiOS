'use strict';
const $=id=>document.getElementById(id),root='../assets/ios-outline/svg/';
const presets={wide:{w:874,h:402,safe:[0,62,21,62]},compact:{w:780,h:360,safe:[0,50,21,50]},classic:{w:667,h:375,safe:[0,0,0,0]},ipad:{w:1376,h:1032,safe:[24,0,20,0]},ipad11:{w:1210,h:834,safe:[24,0,20,0]},mini:{w:1133,h:744,safe:[24,0,20,0]}};
const labels={dpad:'Croix',a:'A',b:'B',l:'L',r:'R',select:'Select',start:'Start',menu:'Pause'};
const keymap={ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',KeyX:'a',KeyZ:'b',KeyQ:'l',KeyE:'r',Enter:'start',ShiftLeft:'select',ShiftRight:'select'};
const input=new GBATouch.Input(GBAInput.directions),keyboard=new Map();
let geometry,scale=1,active=new Set(),paused=false,lastKeys='';
function place(el,r){Object.assign(el.style,{left:r.x*scale+'px',top:r.y*scale+'px',width:r.w*scale+'px',height:r.h*scale+'px'});}
for(const name of Object.keys(labels)) {
  const link=document.createElement('a');link.href=root+name+'.svg';link.download=name+'.svg';link.innerHTML=`<img src="${link.href}" alt=""><span>${labels[name]}</span>`;document.querySelector('.asset-strip').append(link);
  if(name==='dpad')continue;
  const button=document.createElement('button');button.className='touch-key';button.dataset.key=name;button.setAttribute('aria-label',labels[name]);button.innerHTML=`<img src="${root+name}.svg" alt="" draggable="false">`;$('buttons').append(button);
  button.addEventListener('keydown',event=>{if(event.code==='Space'){event.preventDefault();if(name==='menu'){if(!event.repeat)setPaused(!paused);}else if(!paused){keyboard.set('Space',name);update();}}});
  button.addEventListener('keyup',event=>{if(event.code==='Space'){keyboard.delete('Space');update();}});
}
function update(){
  const next=new Set([...input.active,...keyboard.values()]);
  for(const [a,b] of [['up','down'],['left','right']])if(next.has(a)&&next.has(b)){next.delete(a);next.delete(b);}
  next.delete('menu');
  for(const key of new Set([...active,...next]))if(active.has(key)!==next.has(key))window.dispatchEvent(new CustomEvent('gba-input',{detail:{button:key,pressed:next.has(key)}}));
  active=next;
  document.querySelectorAll('.touch-key').forEach(el=>el.classList.toggle('pressed',active.has(el.dataset.key)));
  if(active.size)lastKeys=[...active].map(k=>labels[k]||({up:'↑',down:'↓',left:'←',right:'→'})[k]).join(' + ');
  $('status').textContent=active.size?'Appui : '+lastKeys:input.pad?'Centre posé · glisse pour te déplacer.':lastKeys?'Relâché · dernier appui : '+lastKeys:'Pose le doigt à gauche, puis glisse dans une direction.';
  drawPad();
}
function drawPad(){
  if(!geometry)return;
  const pad=input.pad,origin=pad?.origin||geometry.home,size=128*geometry.unit;
  place($('pad'),{x:origin.x-size/2,y:origin.y-size/2,w:size,h:size});
  $('pad').classList.toggle('active',!!pad);
  $('pad').classList.toggle('key-active',['up','down','left','right'].some(k=>active.has(k)));
  let dx=pad?pad.point.x-origin.x:0,dy=pad?pad.point.y-origin.y:0;
  const length=Math.hypot(dx,dy),limit=geometry.radius*.7;
  if(length>limit){dx*=limit/length;dy*=limit/length;}
  $('thumb').style.transform=`translate(${dx*scale}px,${dy*scale}px)`;
}
function clear(){input.clear();keyboard.clear();update();}
function point(event){const r=$('viewport').getBoundingClientRect();return {x:(event.clientX-r.left-$('viewport').clientLeft)/scale,y:(event.clientY-r.top-$('viewport').clientTop)/scale};}
$('viewport').addEventListener('pointerdown',e=>{
  if(paused||e.button!==0)return;
  e.preventDefault();$('viewport').focus({preventScroll:true});input.begin(e.pointerId,point(e),geometry);
  if(input.pointers.get(e.pointerId)?.key==='menu'){input.end(e.pointerId);setPaused(true);return;}
  if(input.pointers.has(e.pointerId))$('viewport').setPointerCapture(e.pointerId);update();
});
$('viewport').addEventListener('pointermove',e=>{input.move(e.pointerId,point(e),geometry);update();});
for(const name of ['pointerup','pointercancel','lostpointercapture'])$('viewport').addEventListener(name,e=>{input.end(e.pointerId);update();});
$('viewport').addEventListener('contextmenu',e=>e.preventDefault());
function setPaused(value){clear();paused=value;$('pause').hidden=!value;if(value)$('resume').focus();}
$('resume').addEventListener('click',()=>setPaused(false));
function layout(){
  clear();const p=presets[$('device').value],view=$('viewport'),full=document.fullscreenElement===view;
  scale=full?1:view.clientWidth/p.w;
  const w=view.clientWidth/scale,h=view.clientHeight/scale,css=getComputedStyle($('safeProbe'));
  const actual=['Top','Right','Bottom','Left'].map(side=>(parseFloat(css['padding'+side])||0)/scale);
  const safe=full?actual:p.safe.map((v,i)=>Math.max(v,actual[i]));
  geometry=GBATouch.layout(w,h,safe);
  place($('game'),geometry.game);place($('moveZone'),geometry.zone);place($('safeGuide'),geometry.safe);
  document.querySelectorAll('.touch-key').forEach(el=>place(el,geometry.keys[el.dataset.key]));
  $('camera').style.display=!full&&p.safe[1]&&p.w/p.h>2?'block':'none';
  place($('camera'),{x:9,y:h/2-36,w:12,h:72});$('gesture').style.display=safe[2]?'block':'none';
  $('sizeInfo').textContent=`Jeu entier · ${Math.round(geometry.game.w)} × ${Math.round(geometry.game.h)} pt · 3:2`;
  drawPad();
}
function choose(){lastKeys='';const p=presets[$('device').value];$('viewport').style.aspectRatio=p.w+'/'+p.h;layout();}
$('device').addEventListener('change',choose);
$('guides').addEventListener('change',()=>{$('viewport').classList.toggle('guides',$('guides').checked);});
$('opacity').addEventListener('input',()=>{$('viewport').style.setProperty('--opacity',$('opacity').value/100);$('opacityValue').textContent=$('opacity').value+' %';});
$('fullscreen').addEventListener('click',async()=>{clear();if(document.fullscreenElement)await document.exitFullscreen();else await $('viewport').requestFullscreen();});
window.addEventListener('keydown',e=>{if(['INPUT','SELECT'].includes(document.activeElement.tagName))return;if(e.code==='Escape'){if(!e.repeat)setPaused(!paused);return;}if(keymap[e.code]&&!paused){e.preventDefault();keyboard.set(e.code,keymap[e.code]);update();}});
window.addEventListener('keyup',e=>{keyboard.delete(e.code);update();});
window.addEventListener('blur',clear);document.addEventListener('visibilitychange',clear);document.addEventListener('fullscreenchange',layout);
new ResizeObserver(layout).observe($('viewport'));choose();
