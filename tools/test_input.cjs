const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const context={window:{}};
vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../preview/input.js'),'utf8'),context);
const input=context.window.GBAInput;
const expected=[['right'],['right','down'],['down'],['down','left'],['left'],['left','up'],['up'],['up','right']];
for(let sector=0;sector<8;sector++)for(let offset=-21;offset<=21;offset++) {
  const angle=(sector*45+offset)*Math.PI/180;
  assert.equal(JSON.stringify(input.directions(Math.cos(angle),Math.sin(angle))),JSON.stringify(expected[sector]));
}
assert.equal(input.directions(.17,.17).length,0);
assert.equal(input.directions(NaN,1).length,0);
for(const keys of expected) {
  const tilt=input.tilt(new Set(keys));
  assert.equal(tilt.angle,10);
  assert.equal(tilt.axisX,-tilt.dy);
  assert.equal(tilt.axisY,tilt.dx);
}
assert.equal(input.tilt(new Set()).angle,0);
console.log('PASS: eight D-pad sectors, centre and directional tilt in the preview.');
