/* Geometry is in logical points, not device pixels. Also exercised in Node. */
(function(root) {
  'use strict';
  const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
  const rect=(x,y,w,h)=>({x,y,w,h});
  const inside=(p,r)=>p.x>=r.x&&p.x<=r.x+r.w&&p.y>=r.y&&p.y<=r.y+r.h;
  function layout(w,h,insets=[0,0,0,0]) {
    const [t,r,b,l]=insets;
    const safe=rect(l,t,Math.max(1,w-l-r),Math.max(1,h-t-b));
    const gh=Math.min(safe.h,safe.w/1.5),gw=gh*1.5;
    const game=rect(safe.x+(safe.w-gw)/2,safe.y+(safe.h-gh)/2,gw,gh);
    const tablet=Math.min(w,h)>600;
    const unit=tablet?1.12:1;
    const bottom=safe.y+safe.h-18*unit;
    // Keep the buttons in thumb reach while overlapping the game edge.
    const right=Math.min(safe.x+safe.w-16*unit,game.x+game.w+36*unit);
    const left=Math.max(safe.x+16*unit,game.x-36*unit);
    const center=(cx,cy,rw,rh)=>rect(cx-rw/2,cy-rh/2,rw,rh);
    const keys={
      a:center(right-32*unit,bottom-91*unit,64*unit,64*unit),
      b:center(right-100*unit,bottom-44*unit,64*unit,64*unit),
      l:center(left+44*unit,bottom-209*unit,88*unit,48*unit),
      r:center(right-44*unit,bottom-209*unit,88*unit,48*unit),
      select:center(safe.x+safe.w/2-74,safe.y+30,64,44),
      start:center(safe.x+safe.w/2+74,safe.y+30,64,44),
      menu:center(safe.x+safe.w/2,safe.y+30,44,44)
    };
    for(const r of Object.values(keys)) {
      r.x=clamp(r.x,safe.x,safe.x+safe.w-r.w);
      r.y=clamp(r.y,safe.y,safe.y+safe.h-r.h);
    }
    return {safe,game,keys,unit,zone:rect(safe.x,safe.y,safe.w*.5,safe.h),home:{x:left+64*unit,y:bottom-75*unit},radius:44*unit};
  }
  class Input {
    constructor(direction) { this.direction=direction;this.pointers=new Map();this.pad=null; }
    begin(id,p,geometry) {
      if(this.pointers.has(id))return;
      // Buttons have priority over the large invisible movement area.
      const key=Object.keys(geometry.keys).find(k=>inside(p,geometry.keys[k]));
      if(key){this.pointers.set(id,{key,keys:[key]});return;}
      if(this.pad===null&&inside(p,geometry.zone)) {
        this.pad={id,origin:{...p},point:{...p},radius:geometry.radius};
        this.pointers.set(id,{key:'dpad',keys:[]});
      }
    }
    move(id,p,geometry) {
      const owner=this.pointers.get(id);if(!owner)return;
      if(owner.key==='dpad') {
        this.pad.point={...p};
        owner.keys=this.direction((p.x-this.pad.origin.x)/this.pad.radius,(p.y-this.pad.origin.y)/this.pad.radius);
      } else owner.keys=inside(p,geometry.keys[owner.key])?[owner.key]:[];
    }
    end(id) {this.pointers.delete(id);if(this.pad?.id===id)this.pad=null;}
    clear(){this.pointers.clear();this.pad=null;}
    get active(){return new Set([...this.pointers.values()].flatMap(p=>p.keys));}
  }
  root.GBATouch={layout,Input,inside};
})(typeof window==='undefined'?globalThis:window);
