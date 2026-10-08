/* Original game rules. Shared by the browser renderer and deterministic tests. */
(function (root) {
  'use strict';
  const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
  const SAVE_VERSION = 1;
  const properties = [
    { id: 'kiosco', name: 'Kiosco La Persiana', district: 'barrio', cost: 900, income: 55, x: 210, y: 1220 },
    { id: 'almacen', name: 'Almacén del Polígono', district: 'poligono', cost: 2200, income: 125, x: 1830, y: 220 },
    { id: 'muelle', name: 'Oficina del Muelle', district: 'puerto', cost: 4200, income: 235, x: 1830, y: 1240 },
    { id: 'club', name: 'Club Medio Euro', district: 'lujo', cost: 6200, income: 350, x: 1030, y: 1240 }
  ];
  class Game {
    constructor(content, random = Math.random) {
      this.content = content;
      this.random = random;
      this.notices = [];
      this.makeCity();
      this.reset();
    }
    reset() {
      this.state = {
        version: SAVE_VERSION, x: 320, y: 1040, cash: 500, rep: 0, heat: 0, authority: 0,
        inventory: Object.fromEntries(this.content.products.map(p => [p.id, 0])), capacity: 20,
        properties: [], upgrades: [], met: [], mission: 0, day: 1, clock: 0,
        incomeClock: 0, totalBought: 0, totalSold: 0, revenue: 0, spent: 0,
        fines: 0, arrested: 0, deals: 0, investment: 0, eventIndex: -1,
        budgets: {}, demand: {}, visited: ['barrio'], won: false, emergencyDay: 0
      };
      this.police = this.content.districts.map((d, i) => ({ x: d.x + 400, y: d.y + 360, phase: i * 1.1, district: d.id }));
      this.notices = [];
      this.arrestCooldown = 0;
      this.refreshMarket();
      return this.state;
    }
    makeCity() {
      this.buildings = [];
      this.content.districts.forEach((d, i) => {
        [[80,100,240,190],[490,100,240,190],[80,470,240,180],[490,470,240,180]].forEach((r,j) => {
          this.buildings.push({x:d.x+r[0],y:d.y+r[1],w:r[2],h:r[3],district:d.id,variant:(i+j)%5});
        });
      });
    }
    districtAt(x = this.state.x, y = this.state.y) {
      return this.content.districts.find(d => x >= d.x && x < d.x+d.w && y >= d.y && y < d.y+d.h) || this.content.districts[3];
    }
    count() { return Object.values(this.state.inventory).reduce((a,b) => a+b, 0); }
    wealth() { return this.state.cash + this.state.investment + properties.filter(p => this.state.properties.includes(p.id)).reduce((a,p)=>a+p.cost,0); }
    announce(text, tone = 'good') { this.notices.push({text,tone}); if (this.notices.length > 12) this.notices.shift(); }
    canStand(x,y) {
      if (x<18 || y<18 || x>2382 || y>1422) return false;
      const d = this.districtAt(x,y);
      if (d.minRep>this.state.rep) return false;
      return !this.buildings.some(b => x>b.x-12 && x<b.x+b.w+12 && y>b.y-12 && y<b.y+b.h+12);
    }
    move(dx,dy,dt) {
      const norm = Math.hypot(dx,dy);
      if (!norm) return;
      const speed = this.state.upgrades.includes('zapatillas') ? 250 : 210;
      const x=this.state.x+dx/norm*speed*dt, y=this.state.y+dy/norm*speed*dt;
      if (this.canStand(x,this.state.y)) this.state.x=x;
      if (this.canStand(this.state.x,y)) this.state.y=y;
      const id=this.districtAt().id;
      if (!this.state.visited.includes(id)) {
        this.state.visited.push(id);
        this.announce('Nuevo barrio: '+this.districtAt().name);
        this.checkMissions();
      }
    }
    nearNPC() {
      return this.content.npcs.filter(n => Math.hypot(n.x-this.state.x,n.y-this.state.y)<80).sort((a,b)=>Math.hypot(a.x-this.state.x,a.y-this.state.y)-Math.hypot(b.x-this.state.x,b.y-this.state.y))[0];
    }
    meet(id) {
      const npc=this.content.npcs.find(n=>n.id===id);
      if (!npc) return false;
      if (!this.state.met.includes(id)) this.state.met.push(id);
      if(id==='xoxi') this.announce('Xoxi: el barrio de lujo paga mejor el Eco de cristal. Pero primero, reputación.');
      this.checkMissions();
      return true;
    }
    refreshMarket() {
      const s=this.state;
      this.content.npcs.forEach(n => {
        const d=this.districtAt(n.x,n.y);
        s.budgets[n.id]=Math.round(350*d.priceMultiplier+140*(s.day%3));
        this.content.products.forEach(p=>s.demand[n.id+':'+p.id]=12+((s.day+p.base+n.x)%9));
      });
    }
    price(productId, npcId, buy) {
      const p=this.content.products.find(p=>p.id===productId), n=this.content.npcs.find(n=>n.id===npcId);
      if (!p || !n) return 0;
      const d=this.districtAt(n.x,n.y);
      const wave=1+Math.sin(this.state.day*1.7+p.base+d.x*.003)*.13;
      const event=this.content.events[this.state.eventIndex];
      const e=event && event.product===p.id ? event.multiplier : 1;
      let factor=buy ? 1.1 : .81;
      if(buy && n.id==='peralta') factor=.65;
      if(buy && n.id==='monfe') factor=.79;
      if(!buy && n.id==='lola') factor=1.12;
      if(!buy && n.id==='garcia' && this.state.met.includes('garcia')) factor=.94;
      if(!buy && this.state.upgrades.includes('negociador')) factor*=1.12;
      const price=Math.max(1,Math.round(p.base*d.priceMultiplier*wave*e*factor));
      return buy ? price : Math.max(1,Math.min(price,this.price(productId,npcId,true)-1));
    }
    trade(npcId,productId,quantity,buy) {
      const s=this.state, npc=this.content.npcs.find(n=>n.id===npcId);
      if(!npc || !Object.hasOwn(s.inventory,productId)) return {ok:false,reason:'Mercancía desconocida.'};
      if(!Number.isInteger(quantity)||quantity<=0||quantity>100) return {ok:false,reason:'Cantidad inválida.'};
      const price=this.price(productId,npcId,buy), amount=price*quantity;
      if(buy) {
        if(s.cash<amount) return {ok:false,reason:'Te faltan euros. Monfe no acepta promesas.'};
        if(this.count()+quantity>s.capacity) return {ok:false,reason:'Mochila llena. Vende o mejora su capacidad.'};
        s.cash-=amount; s.inventory[productId]+=quantity; s.totalBought+=quantity; s.spent+=amount;
      } else {
        if(s.inventory[productId]<quantity) return {ok:false,reason:'No llevas tantas unidades.'};
        if(s.budgets[npcId]<amount) return {ok:false,reason:'El cliente ha agotado su presupuesto. Vuelve mañana.'};
        if(s.demand[npcId+':'+productId]<quantity) return {ok:false,reason:'Demanda cubierta por hoy. Prueba otro producto o cliente.'};
        s.cash+=amount;s.inventory[productId]-=quantity;s.totalSold+=quantity;s.revenue+=amount;
        s.budgets[npcId]-=amount;s.demand[npcId+':'+productId]-=quantity;
        s.rep=Math.min(100,s.rep+Math.max(1,Math.floor(quantity/3)));
      }
      s.deals++;s.heat=clamp(s.heat+(buy?1:2)*quantity*(s.upgrades.includes('seguridad')?.55:1),0,100);
      this.announce((buy?'Compra: −':'Venta: +')+amount+' € · '+quantity+' '+this.content.products.find(p=>p.id===productId).name);
      this.checkMissions();
      return {ok:true,amount};
    }
    purchaseProperty(id) {
      const p=properties.find(p=>p.id===id),s=this.state;
      if(!p || s.properties.includes(id)) return {ok:false,reason:'Ese negocio ya es tuyo.'};
      if(!s.met.includes('toni')) return {ok:false,reason:'Habla con Toni Escrig para desbloquear las propiedades.'};
      const d=this.content.districts.find(d=>d.id===p.district);
      if(s.rep<d.minRep) return {ok:false,reason:'Necesitas '+d.minRep+' de reputación para ese barrio.'};
      if(s.cash<p.cost) return {ok:false,reason:'Necesitas '+p.cost+' €.'};
      s.cash-=p.cost;s.spent+=p.cost;s.properties.push(id);s.rep=Math.min(100,s.rep+5);
      this.announce('¡'+p.name+' abre sus puertas! +'+p.income+' € cada 30 s');
      this.checkMissions();return {ok:true};
    }
    upgrade(id) {
      const items={mochila:{cost:300,npc:'scot'},zapatillas:{cost:240,npc:'scot'},seguridad:{cost:700,npc:'soto'},negociador:{cost:450,npc:'garcia'},finanzas:{cost:500,npc:'cristian'}};
      const item=items[id],s=this.state;
      if(!item||s.upgrades.includes(id)) return {ok:false,reason:'Mejora ya instalada.'};
      if(!s.met.includes(item.npc)) return {ok:false,reason:'Conoce primero a tu colaborador.'};
      if(s.cash<item.cost) return {ok:false,reason:'Necesitas '+item.cost+' €.'};
      s.cash-=item.cost;s.spent+=item.cost;s.upgrades.push(id);
      if(id==='mochila')s.capacity+=16;
      if(id==='seguridad')s.rep=Math.min(100,s.rep+6);
      this.announce('Mejora adquirida: '+id);this.checkMissions();return {ok:true};
    }
    invest(amount) {
      const s=this.state;
      if(!s.upgrades.includes('finanzas'))return {ok:false,reason:'Desbloquea la asesoría de Cristian.'};
      if(amount!==1000 && amount!==-1000)return {ok:false,reason:'Operación inválida.'};
      if(amount>0 && s.cash<amount)return {ok:false,reason:'Necesitas 1.000 € para invertir.'};
      if(amount<0 && s.investment<1000)return {ok:false,reason:'No hay 1.000 € invertidos para retirar.'};
      s.cash-=amount;s.investment+=amount;this.checkMissions();return {ok:true};
    }
    coolDown() {
      if(this.state.cash<75)return {ok:false,reason:'El descanso cuesta 75 €.'};
      this.state.cash-=75;this.state.spent+=75;this.state.heat=Math.max(0,this.state.heat-35);this.state.authority++;
      this.announce('Un café, una siesta y 35 puntos menos de sospecha.');return {ok:true};
    }
    rest() {
      this.state.heat=Math.max(0,this.state.heat-25);
      this.state.day++;this.state.clock=0;
      this.state.eventIndex=Math.floor(this.random()*this.content.events.length);
      this.refreshMarket();
      const e=this.content.events[this.state.eventIndex];
      this.announce('Día '+this.state.day+' · '+e.name+': '+e.description);
      if(this.state.cash<100 && this.count()===0 && this.state.emergencyDay!==this.state.day) {
        this.state.cash+=100;this.state.emergencyDay=this.state.day;
        this.announce('Monfe te presta 100 € para volver a empezar. «Invita al café cuando seas rico».');
      }
    }
    detain() {
      if(this.arrestCooldown>0)return;
      const s=this.state,fine=Math.min(s.cash,Math.max(80,Math.round(s.cash*.12)));
      s.cash-=fine;s.fines+=fine;s.arrested++;s.authority--;
      Object.keys(s.inventory).forEach(id=>s.inventory[id]=Math.floor(s.inventory[id]*.7));
      s.heat=0;s.x=320;s.y=1040;this.arrestCooldown=12;
      this.announce('Inspección: −'+fine+' € y parte del inventario. Vuelves al barrio.','bad');
    }
    tick(dt) {
      dt=clamp(dt,0,.1);const s=this.state;
      s.clock+=dt;s.incomeClock+=dt;this.arrestCooldown=Math.max(0,this.arrestCooldown-dt);
      const home=Math.hypot(s.x-320,s.y-1040)<100;
      s.heat=Math.max(0,s.heat-dt*(home?2:.18)*(s.upgrades.includes('seguridad')?1.5:1));
      if(s.clock>=180)this.rest();
      if(s.incomeClock>=30) {
        s.incomeClock-=30;
        const income=properties.filter(p=>s.properties.includes(p.id)).reduce((a,p)=>a+p.income,0)+Math.floor(s.investment*.035);
        if(income){s.cash+=income;s.revenue+=income;this.announce('Tus negocios ingresan +'+income+' €.');this.checkMissions();}
      }
      this.police.forEach((p,i)=>{
        const d=this.content.districts.find(d=>d.id===p.district);
        let tx=d.x+400+Math.sin(s.clock*.06+i)*300,ty=d.y+360;
        const dist=Math.hypot(p.x-s.x,p.y-s.y);
        if(s.heat>=28 && dist<260){tx=s.x;ty=s.y;}
        const len=Math.hypot(tx-p.x,ty-p.y),speed=s.heat>65?170:135;
        if(len>2){p.x+=(tx-p.x)/len*speed*dt;p.y+=(ty-p.y)/len*speed*dt;}
        if(dist<25 && s.heat>=28)this.detain();
      });
    }
    checkMissions() {
      const s=this.state;
      const conditions=[
        ()=>s.met.includes('monfe'),()=>s.totalBought>=5,()=>s.totalSold>=5,
        ()=>s.met.includes('scot'),()=>s.met.includes('garcia') && s.totalSold>=12,
        ()=>s.properties.length>=1,()=>s.met.includes('navarro'),
        ()=>s.visited.includes('puerto') && s.met.includes('peralta'),
        ()=>s.upgrades.includes('seguridad'),()=>s.met.includes('cristian')&&s.upgrades.includes('finanzas'),
        ()=>s.properties.length>=3,()=>this.wealth()>=15000
      ];
      while(s.mission<conditions.length && conditions[s.mission]()) {
        const q=this.content.missions[s.mission];
        s.cash+=q.reward;s.rep=Math.min(100,s.rep+q.rep);s.mission++;
        this.announce('Misión cumplida: '+q.title+' · +'+q.reward+' € · +'+q.rep+' REP');
      }
      if(s.mission===conditions.length && !s.won) {s.won=true;this.announce('Mancebo Robles: la ciudad ya conoce tu nombre.');}
    }
    serialize() { return JSON.stringify(this.state); }
    load(raw) {
      try {
        const s=JSON.parse(raw);
        if(s.version!==SAVE_VERSION)return false;
        const numbers=['x','y','cash','rep','heat','capacity','mission','day','clock','incomeClock','investment','totalBought','totalSold','revenue','spent','fines','arrested','deals','authority','eventIndex','emergencyDay'];
        if(numbers.some(k=>typeof s[k]!=='number'||!Number.isFinite(s[k])))return false;
        if(numbers.filter(k=>!['authority','eventIndex'].includes(k)).some(k=>s[k]<0))return false;
        if(['capacity','mission','day','totalBought','totalSold','arrested','deals','eventIndex','emergencyDay'].some(k=>!Number.isInteger(s[k])))return false;
        if(s.clock>=180||s.incomeClock>=30||s.eventIndex < -1 || s.eventIndex>=this.content.events.length || typeof s.won!=='boolean')return false;
        if(s.cash<0||s.rep<0||s.rep>100||s.heat<0||s.heat>100||s.capacity<20||s.capacity>100||s.mission<0||s.mission>12||!Number.isInteger(s.mission)||s.day<1||s.x<18||s.x>2382||s.y<18||s.y>1422)return false;
        for(const key of ['properties','upgrades','met','visited'])if(!Array.isArray(s[key])||s[key].some(x=>typeof x!=='string'))return false;
        if(s.met.some(id=>!this.content.npcs.some(n=>n.id===id))||s.visited.some(id=>!this.content.districts.some(d=>d.id===id)))return false;
        if(!s.inventory||this.content.products.some(p=>!Number.isInteger(s.inventory[p.id])||s.inventory[p.id]<0))return false;
        if(Object.keys(s.inventory).length!==this.content.products.length||Object.values(s.inventory).reduce((a,b)=>a+b,0)>s.capacity)return false;
        if(!s.budgets||!s.demand||Object.values(s.budgets).some(v=>!Number.isFinite(v)||v<0)||Object.values(s.demand).some(v=>!Number.isFinite(v)||v<0))return false;
        if(!this.content.npcs.every(n=>Number.isFinite(s.budgets[n.id])&&this.content.products.every(p=>Number.isFinite(s.demand[n.id+':'+p.id]))))return false;
        if(s.properties.some(id=>!properties.some(p=>p.id===id))||s.upgrades.some(id=>!['mochila','zapatillas','seguridad','negociador','finanzas'].includes(id)))return false;
        if(new Set(s.properties).size!==s.properties.length||new Set(s.upgrades).size!==s.upgrades.length)return false;
        this.state=s;
        if(!this.canStand(s.x,s.y)){s.x=320;s.y=1040;}
        this.notices=[];this.arrestCooldown=5;
        return true;
      } catch{return false;}
    }
  }
  const api={Game,properties,clamp,SAVE_VERSION};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;
  root.ImperioModel=api;
})(typeof globalThis!=='undefined'?globalThis:this);
