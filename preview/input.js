/* The same equal 45-degree sectors and neutral radius as MGBAInput.c. */
'use strict';
window.GBAInput = {
  directions(x,y) {
    if(!Number.isFinite(x)||!Number.isFinite(y)||Math.hypot(x,y)<.25)return [];
    const sectors=[['right'],['right','down'],['down'],['down','left'],['left'],['left','up'],['up'],['up','right']];
    return sectors[(Math.floor(Math.atan2(y,x)/(Math.PI/4)+.5)+8)%8];
  },
  tilt(active) {
    const dx=Number(active.has('right'))-Number(active.has('left'));
    const dy=Number(active.has('down'))-Number(active.has('up'));
    return {dx,dy,axisX:-dy,axisY:dx,angle:dx||dy?10:0};
  }
};
