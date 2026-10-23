const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const context={window:{}};
for(const file of ['input.js','touch-model.js'])vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../preview',file),'utf8'),context);
const {layout,Input}=context.window.GBATouch;
const center=r=>({x:r.x+r.w/2,y:r.y+r.h/2});
const overlaps=(a,b)=>a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y;
for(const [w,h,safe] of [[874,402,[0,62,21,62]],[780,360,[0,50,21,50]],[667,375,[0,0,0,0]],[568,320,[0,0,0,0]],[1376,1032,[24,0,20,0]],[1210,834,[24,0,20,0]],[1133,744,[24,0,20,0]],[744,1133,[24,0,20,0]],[507,744,[24,0,20,0]]]) {
  const g=layout(w,h,safe),rects=Object.entries(g.keys);
  assert.ok(Math.abs(g.game.w/g.game.h-1.5)<1e-9);
  assert.ok(Math.abs(g.game.w-g.safe.w)<1e-9||Math.abs(g.game.h-g.safe.h)<1e-9,'Game must fill one safe dimension');
  for(const [name,r] of rects) {
    assert.ok(r.w>=44&&r.h>=44, name+' tap target');
    assert.ok(r.x>=g.safe.x&&r.y>=g.safe.y&&r.x+r.w<=g.safe.x+g.safe.w+.001&&r.y+r.h<=g.safe.y+g.safe.h+.001,name+' safe area');
    for(const [other,s] of rects)if(name!==other)assert.ok(!overlaps(r,s),`${w}x${h}: ${name} overlaps ${other}`);
  }
}
const g=layout(874,402,[0,62,21,62]),input=new Input(context.window.GBAInput.directions);
const first={x:80,y:310};
input.begin(1,first,g);
assert.equal(input.pad.origin.x,80,'Exact initial contact near safe edge');
assert.equal(input.active.size,0,'Touch-down is neutral');
input.move(1,{x:84,y:314},g);assert.equal(input.active.size,0,'Small thumb jitter is neutral');
input.move(1,{x:110,y:280},g);assert.deepEqual([...input.active].sort(),['right','up']);
input.begin(2,center(g.keys.a),g);input.begin(3,center(g.keys.r),g);
assert.deepEqual([...input.active].sort(),['a','r','right','up'],'Movement + A + R');
input.begin(4,{x:230,y:300},g);assert.equal(input.pad.id,1,'Second left finger cannot steal movement');
input.end(2);assert.ok(input.active.has('right')&&input.active.has('r')&&!input.active.has('a'));
input.move(1,{x:800,y:250},g);assert.ok(input.active.has('right'),'Captured thumb can leave activation area');
input.end(1);assert.equal(input.pad,null);assert.deepEqual([...input.active],['r']);
input.begin(5,{x:310,y:340},g);assert.equal(input.pad.origin.x,310,'Each new touch relocates the pad');
input.clear();assert.equal(input.active.size,0);assert.equal(input.pad,null,'Cancellation clears all state');
input.begin(6,center(g.keys.l),g);assert.equal(input.pad,null);assert.ok(input.active.has('l'),'L takes priority over movement zone');
input.move(6,{x:400,y:300},g);assert.equal(input.active.size,0,'Sliding out releases a button');
input.move(6,center(g.keys.l),g);assert.ok(input.active.has('l'),'Sliding back in restores the held button');
input.clear();input.begin(7,{x:10,y:200},g);assert.equal(input.pad,null,'Camera margin ignored');
input.begin(8,{x:740,y:300},g);assert.equal(input.pad,null,'Right side does not create a second movement pad');
console.log('PASS: 9 layouts, non-overlapping 44pt targets, full 3:2 image, floating origin, 8-way input, multitouch ownership and cancellation.');
