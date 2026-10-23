/* Local, dependency-free asset preview. No emulator is bundled. */
'use strict';
const assets = window.GBA_ASSETS;
const assetRoot = '../assets/gba-indigo/';
const $ = id => document.getElementById(id);
const presets = {
  wide: {variant:'wide',w:2622,h:1206,points:874,safe:[0,62,21,62]},
  compact: {variant:'wide',w:2340,h:1080,points:780,safe:[0,50,21,50]},
  classic: {variant:'classic',w:1334,h:750,points:667,safe:[0,0,0,0]},
  ipad: {variant:'ipad',w:2752,h:2064,points:1376,safe:[24,0,20,0]},
  ipad11: {variant:'ipad',w:2420,h:1668,points:1210,safe:[24,0,20,0]},
  mini: {variant:'ipad',w:2266,h:1488,points:1133,safe:[24,0,20,0]}
};
const labels = {dpad:'Croix directionnelle',a:'A',b:'B',select:'Select',start:'Start',l:'L',r:'R',up:'Haut',down:'Bas',left:'Gauche',right:'Droite'};
const owners = new Map();
let active = new Set();
let variant, preset, scale = 1, lastPressed = '';
let keys = {};

function updateInput(owner, values) {
  if(values.length) owners.set(owner,values); else owners.delete(owner);
  const next = new Set([...owners.values()].flat());
  for(const key of new Set([...active,...next])) {
    if(active.has(key)!==next.has(key)) window.dispatchEvent(new CustomEvent('gba-input',{detail:{button:key,pressed:next.has(key)}}));
  }
  if(next.has('left')&&next.has('right')){next.delete('left');next.delete('right');}
  if(next.has('up')&&next.has('down')){next.delete('up');next.delete('down');}
  active = next;
  for(const [key,element] of Object.entries(keys)) {
    const down = key==='dpad' ? ['up','down','left','right'].some(k=>active.has(k)) : active.has(key);
    element.classList.toggle('pressed',down);
  }
  if(keys.dpad) {
    const tilt=window.GBAInput.tilt(active),style=keys.dpad.firstElementChild.style;
    style.setProperty('--pad-x',tilt.dx+'px');style.setProperty('--pad-y',tilt.dy+'px');
    style.setProperty('--axis-x',tilt.axisX);style.setProperty('--axis-y',tilt.axisY || (tilt.axisX?0:1));
    style.setProperty('--tilt',tilt.angle+'deg');
  }
  if(active.size)lastPressed=[...active].map(k=>labels[k]).join(' + ');
  $('status').textContent = active.size ? lastPressed+' — enfoncé' : lastPressed ? 'Dernier appui : '+lastPressed+' · relâché' : 'Appuie sur une commande pour essayer.';
}
function releaseAll() { for(const owner of [...owners.keys()]) updateInput(owner,[]); }
function directions(event, element) {
  const box=element.getBoundingClientRect(),graphic=element.firstElementChild;
  // Use the fixed pivot and artwork size, never the tilted bounding rectangle.
  const x=2*(event.clientX-box.left-graphic.offsetLeft*scale)/(graphic.offsetWidth*scale)-1;
  const y=2*(event.clientY-box.top-graphic.offsetTop*scale)/(graphic.offsetHeight*scale)-1;
  return window.GBAInput.directions(x,y);
}
function buildControls() {
  $('controls').replaceChildren(); keys={};
  for(const [key,slot] of Object.entries(variant.openings)) {
    const button=document.createElement('button');
    button.type='button';button.className='key';button.dataset.key=key;
    button.setAttribute('aria-label',labels[key]);
    const graphic=document.createElement('span');graphic.className='graphic';
    const img=document.createElement('img');img.src=assetRoot+assets.sprites[key].file;img.alt='';img.draggable=false;
    graphic.append(img);button.append(graphic);keys[key]=button;
    button.addEventListener('pointerdown',event=>{
      event.preventDefault();button.setPointerCapture(event.pointerId);
      updateInput('p'+event.pointerId,key==='dpad'?directions(event,button):[key]);
    });
    button.addEventListener('pointermove',event=>{
      if(key==='dpad'&&button.hasPointerCapture(event.pointerId)) updateInput('p'+event.pointerId,directions(event,button));
    });
    for(const name of ['pointerup','pointercancel','lostpointercapture']) button.addEventListener(name,event=>updateInput('p'+event.pointerId,[]));
    button.addEventListener('keydown',event=>{if(event.code==='Space'){event.preventDefault();updateInput('space'+key,[key==='dpad'?'up':key]);}});
    button.addEventListener('keyup',event=>{if(event.code==='Space')updateInput('space'+key,[]);});
    button.addEventListener('blur',()=>updateInput('space'+key,[]));
    $('controls').append(button);
  }
}
function layout() {
  if(!variant)return;
  const width=$('viewport').clientWidth,height=$('viewport').clientHeight;
  const probe=getComputedStyle($('safeProbe'));
  let [top,right,bottom,left]=['paddingTop','paddingRight','paddingBottom','paddingLeft'].map(k=>parseFloat(probe[k])||0);
  if($('guides').checked) {
    const simulated=preset.safe.map(v=>v*width/preset.points);
    [top,right,bottom,left]=[top,right,bottom,left].map((v,i)=>Math.max(v,simulated[i]));
  }
  const boxes=[...Object.values(variant.openings),variant.gameRect];
  const minX=Math.min(...boxes.map(r=>r.x))-8,minY=Math.min(...boxes.map(r=>r.y))-8;
  const maxX=Math.max(...boxes.map(r=>r.x+r.width))+8,maxY=Math.max(...boxes.map(r=>r.y+r.height))+8;
  scale=Math.max(.01,Math.min(width/variant.width,height/variant.height,(width-left-right)/(maxX-minX),(height-top-bottom)/(maxY-minY)));
  const clamp=(value,min,max)=>Math.max(min,Math.min(max,value));
  const x=clamp((width-variant.width*scale)/2,left-minX*scale,width-right-maxX*scale);
  const y=clamp((height-variant.height*scale)/2,top-minY*scale,height-bottom-maxY*scale);
  Object.assign($('board').style,{width:variant.width+'px',height:variant.height+'px',transform:`translate(${x}px,${y}px) scale(${scale})`});
  $('board').style.setProperty('--press-offset',2/scale+'px');
  $('viewport').style.backgroundColor=variant.shellColor;
  const game=variant.gameRect;
  Object.assign($('game').style,{left:game.x+'px',top:game.y+'px',width:game.width+'px',height:game.height+'px'});
  for(const [key,slot] of Object.entries(variant.openings)) {
    const button=keys[key],sprite=assets.sprites[key],content=sprite.contentRect;
    // Hit regions are independent from the bitmap. 56 CSS pixels for shoulders, 44 for other controls.
    const minTouch=(key==='l'||key==='r'?56:44)/scale;
    const hitW=Math.max(slot.width+8,minTouch),hitH=Math.max(slot.height+8,minTouch);
    let hitX=slot.x+(slot.width-hitW)/2,hitY=slot.y+(slot.height-hitH)/2;
    hitX=clamp(hitX,(left-x)/scale,(width-right-x)/scale-hitW);
    hitY=clamp(hitY,(top-y)/scale,(height-bottom-y)/scale-hitH);
    Object.assign(button.style,{left:hitX+'px',top:hitY+'px',width:hitW+'px',height:hitH+'px'});
    const graphic=button.firstElementChild;
    Object.assign(graphic.style,{left:slot.x-hitX+'px',top:slot.y-hitY+'px',width:slot.width+'px',height:slot.height+'px'});
    const factor=Math.min(slot.width/content.width,slot.height/content.height);
    Object.assign(graphic.firstElementChild.style,{width:sprite.width*factor+'px',height:sprite.height*factor+'px',left:(slot.width-content.width*factor)/2-content.x*factor+'px',top:(slot.height-content.height*factor)/2-content.y*factor+'px'});
    button.disabled=$('holes').checked;
  }
  Object.assign($('safeGuide').style,{left:left+'px',top:top+'px',right:right+'px',bottom:bottom+'px'});
  Object.assign($('camera').style,{display:$('guides').checked&&preset.variant==='wide'?'block':'none',width:Math.max(8,left*.35)+'px',height:height*.25+'px',left:Math.max(4,left*.18)+'px',top:height*.375+'px'});
  $('gesture').style.display=$('guides').checked&&preset.variant!=='classic'?'block':'none';
}
function chooseDevice() {
  releaseAll();preset=presets[$('device').value];variant=assets.variants[preset.variant];
  $('viewport').style.aspectRatio=`${preset.w} / ${preset.h}`;
  $('face').src=assetRoot+variant.file;
  buildControls();layout();
}
$('device').addEventListener('change',chooseDevice);
for(const id of ['guides','holes']) $(id).addEventListener('change',()=>{
  releaseAll();$('viewport').classList.toggle('show-guides',$('guides').checked);$('viewport').classList.toggle('show-holes',$('holes').checked);layout();
});
$('fullscreen').addEventListener('click',async()=>{
  try {
    if(document.fullscreenElement)await document.exitFullscreen();
    else if($('viewport').requestFullscreen)await $('viewport').requestFullscreen();
    else $('status').textContent='Le plein écran dépend du navigateur. Utilise le mode paysage.';
  } catch { $('status').textContent='Le navigateur ne permet pas le plein écran dans cette vue.'; }
});
const keymap={ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',KeyX:'a',KeyZ:'b',KeyQ:'l',KeyE:'r',Enter:'start',ShiftLeft:'select',ShiftRight:'select'};
window.addEventListener('keydown',event=>{
  if(/INPUT|SELECT|TEXTAREA/.test(event.target.tagName)||$('holes').checked)return;
  const key=keymap[event.code];if(key){event.preventDefault();updateInput('k'+event.code,[key]);}
});
window.addEventListener('keyup',event=>updateInput('k'+event.code,[]));
window.addEventListener('blur',releaseAll);
document.addEventListener('visibilitychange',()=>{if(document.hidden)releaseAll();});
new ResizeObserver(()=>requestAnimationFrame(layout)).observe($('viewport'));
document.addEventListener('fullscreenchange',()=>{releaseAll();layout();});
chooseDevice();
