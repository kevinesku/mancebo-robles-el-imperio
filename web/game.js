/* Mancebo Robles: El Imperio — original dependency-free HTML edition. */
(() => {
  'use strict';
  const $ = s => document.querySelector(s);
  const content = window.IMPERIO_CONTENT;
  const {Game,properties,clamp} = window.ImperioModel;
  if(!content)throw new Error('No se han cargado los datos del juego.');
  const game = new Game(content);
  window.game = game;
  const canvas=$('#city'), ctx=canvas.getContext('2d',{alpha:false});
  const saveKey='mancebo-robles-save-v1', settingsKey='mancebo-robles-settings-v1';
  let mode='menu', modal='', activeNPC=null, tab='market', quantity=5, line=0, feedback='', feedbackBad=false;
  let width=0,height=0,dpr=1,zoom=1,camX=320,camY=1040,last=0,elapsed=0,saveClock=0,hudClock=0,walk=0,face=1;
  let waypoint=null,endingShown=false,audio=null,storageAvailable=true,confirmNew=false;
  const keys=new Set();
  const settings={sound:true,volume:.35,motion:true};
  try{Object.assign(settings,JSON.parse(localStorage.getItem(settingsKey)||'{}'));}catch{}
  const fmt = n => Math.floor(n).toLocaleString('es-ES')+' €';
  const escape = s => String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function sound(note=440,duration=.08,type='sine',gain=.08){
    if(!settings.sound)return;
    try{
      audio ||= new (window.AudioContext||window.webkitAudioContext)();
      if(audio.state==='suspended')audio.resume();
      const oscillator=audio.createOscillator(),volume=audio.createGain();
      oscillator.type=type;oscillator.frequency.value=note;
      volume.gain.setValueAtTime(gain*settings.volume,audio.currentTime);
      volume.gain.exponentialRampToValueAtTime(.0001,audio.currentTime+duration);
      oscillator.connect(volume);volume.connect(audio.destination);oscillator.start();oscillator.stop(audio.currentTime+duration);
    }catch{}
  }
  function resize(){
    width=innerWidth;height=innerHeight;dpr=Math.min(devicePixelRatio||1,2);
    canvas.width=Math.round(width*dpr);canvas.height=Math.round(height*dpr);
    zoom=clamp(width/1280,.7,1.25);ctx.imageSmoothingEnabled=false;
  }
  addEventListener('resize',resize);resize();
  function saved(){try{return localStorage.getItem(saveKey);}catch{storageAvailable=false;return null;}}
  function refreshContinue(){const raw=saved();const probe=new Game(content);$('#continue-game').disabled=!(raw&&probe.load(raw));}
  refreshContinue();
  function save(notify=false){
    try{localStorage.setItem(saveKey,game.serialize());$('#save-status').textContent='✓ Partida guardada';if(notify)game.announce('Partida guardada. El imperio puede esperar.');}
    catch{storageAvailable=false;$('#save-status').textContent='⚠ Guardado local no disponible';if(notify)game.announce('El navegador no permite guardar. Usa un navegador con almacenamiento local.','bad');}
  }
  function setPlaying(){
    mode='play';modal='';$('#panel-overlay').hidden=true;$('#menu').hidden=true;
    ['hud','dossier','location','controls'].forEach(id=>$('#'+id).hidden=false);
    keys.clear();camX=game.state.x;camY=game.state.y;renderHUD();
  }
  function header(title,eyebrow='PUERTO BRUMA'){
    return '<div class="panel-header"><div><small>'+escape(eyebrow)+'</small><h2>'+escape(title)+'</h2></div><button class="close" aria-label="Cerrar">×</button></div>';
  }
  function openPanel(kind,html){
    modal=kind;mode='modal';keys.clear();$('#panel').innerHTML=html;$('#panel-overlay').hidden=false;
    $('#panel').querySelector('.close')?.addEventListener('click',closePanel);
    $('#panel').querySelector('button:not(:disabled)')?.focus();
  }
  function closePanel(){
    if(modal==='intro'){setPlaying();save();return;}
    if(modal==='settings' && !$('#menu').hidden){$('#panel-overlay').hidden=true;mode='menu';modal='';return;}
    if(!$('#menu').hidden){$('#panel-overlay').hidden=true;mode='menu';modal='';return;}
    setPlaying();save();
  }
  function newGame(){
    if(saved()&&!confirmNew){
      openPanel('confirm',header('¿Empezamos de cero?','NUEVA PARTIDA')+'<p class="modal-note">La partida anterior se sustituirá al entrar en la ciudad.</p><div class="panel-actions"><button class="primary" id="confirm-new">Sí, nueva historia →</button><button class="secondary" id="cancel-new">Conservar partida</button></div>');
      $('#confirm-new').onclick=()=>{confirmNew=true;newGame();};$('#cancel-new').onclick=closePanel;return;
    }
    confirmNew=false;game.reset();endingShown=false;waypoint=null;line=0;
    openPanel('intro',header('Cada imperio empieza en el barrio.','CAPÍTULO 01 · LA PERSIANA')+'<div class="intro-body">'+content.intro.map(p=>'<p>'+escape(p)+'</p>').join('')+'</div><div class="intro-badge"><span>→ 500 €</span><span>◇ Mochila: 20</span><span>⌂ Tu apartamento</span></div><div class="help-grid"><span><kbd>W A S D</kbd> Moverte</span><span><kbd>E</kbd> Hablar y comprar</span><span><kbd>M</kbd> Mapa y ruta</span><span><kbd>Esc</kbd> Pausar</span></div><div class="panel-actions"><button class="primary" id="enter-city">Entrar en Puerto Bruma →</button></div>');
    $('#enter-city').onclick=()=>{setPlaying();save();sound(294,.2,'triangle');game.announce('Monfe te espera junto a casa. Acércate y pulsa E.');};
  }
  $('#new-game').onclick=newGame;
  $('#continue-game').onclick=()=>{
    if(game.load(saved())){endingShown=game.state.won;setPlaying();game.announce('Puerto Bruma sigue aquí. Tu partida también.');}
    else{game.announce('No se pudo leer la partida guardada.','bad');refreshContinue();}
  };
  function pause(){
    if(mode==='menu')return;
    save();
    openPanel('pause',header('La noche puede esperar.','PAUSA')+'<div class="panel-grid"><div class="stat-card"><small>PATRIMONIO</small><strong>'+fmt(game.wealth())+'</strong><small>'+game.state.properties.length+' NEGOCIOS</small></div><div class="stat-card"><small>PROGRESO</small><strong>'+game.state.mission+' / 12</strong><small>DÍA '+game.state.day+'</small></div></div><div class="panel-actions"><button class="primary" id="resume">Seguir jugando →</button><button class="secondary" id="save-game">Guardar</button></div><div class="panel-actions"><button class="text-button" id="pause-settings">⚙ Ajustes y controles</button><button class="text-button" id="to-menu">Volver al menú</button></div>');
    $('#resume').onclick=closePanel;$('#save-game').onclick=()=>{save(true);sound(587);};$('#pause-settings').onclick=openSettings;
    $('#to-menu').onclick=()=>{save();$('#panel-overlay').hidden=true;$('#menu').hidden=false;['hud','dossier','location','controls','interaction-hint'].forEach(id=>$('#'+id).hidden=true);mode='menu';modal='';keys.clear();refreshContinue();};
  }
  $('#pause-button').onclick=pause;
  function openSettings(){
    const html=header('A tu manera.','AJUSTES Y CONTROLES')+'<label class="settings-line"><span>Efectos de sonido<small>Sintetizados, sin música externa</small></span><input id="sound-toggle" type="checkbox" '+(settings.sound?'checked':'')+'></label><label class="settings-line"><span>Volumen</span><input id="volume" type="range" min="0" max="100" value="'+Math.round(settings.volume*100)+'"></label><label class="settings-line"><span>Luces animadas<small>Reduce el movimiento del entorno</small></span><input id="motion-toggle" type="checkbox" '+(settings.motion?'checked':'')+'></label><div class="help-grid"><span><kbd>W A S D</kbd> / flechas · Mover</span><span><kbd>E</kbd> Interactuar</span><span><kbd>I</kbd> Inventario y estadísticas</span><span><kbd>M</kbd> Mapa</span><span><kbd>F5</kbd> Guardar partida</span><span><kbd>Esc</kbd> Cerrar / pausa</span></div><p class="modal-note">La partida se guarda automáticamente y después de las operaciones. El tiempo y las patrullas se detienen mientras lees un diálogo. Cada día dura tres minutos; puedes descansar en tu apartamento para renovar los presupuestos y el mercado.</p><div class="panel-actions"><button class="primary" id="settings-done">Listo →</button></div>';
    openPanel('settings',html);
    const persist=()=>{try{localStorage.setItem(settingsKey,JSON.stringify(settings));}catch{}};
    $('#sound-toggle').onchange=e=>{settings.sound=e.target.checked;persist();sound();};
    $('#volume').oninput=e=>{settings.volume=+e.target.value/100;persist();};
    $('#motion-toggle').onchange=e=>{settings.motion=e.target.checked;persist();};$('#settings-done').onclick=closePanel;
  }
  $('#settings-button').onclick=openSettings;
  function reply(result){feedback=result.ok?'Operación completada.':result.reason;feedbackBad=!result.ok;sound(result.ok?620:140,.12,result.ok?'triangle':'sine');save();renderHUD();}
  function openNPC(n,reset=true){
    if(reset){activeNPC=n;tab='market';feedback='';feedbackBad=false;line=0;game.meet(n.id);sound(392,.09,'triangle');save();}
    const s=game.state;
    let body='';
    if(tab==='market'){
      body='<div class="shop-header"><span>Tu efectivo: <b>'+fmt(s.cash)+'</b> · mochila '+game.count()+'/'+s.capacity+'</span><label>Unidades <select id="quantity" class="quantity">'+[1,5,10].map(v=>'<option value="'+v+'" '+(v===quantity?'selected':'')+'>'+v+'</option>').join('')+'</select></label></div>';
      content.products.forEach(p=>{
        body+='<div class="trade-row"><div class="product-label"><i style="background:'+p.color+'"></i><div>'+escape(p.name)+'<small>Llevas '+s.inventory[p.id]+' · demanda '+s.demand[n.id+':'+p.id]+'</small></div></div><div class="price-cell"><small>COMPRAR</small><strong>'+game.price(p.id,n.id,true)+' €</strong></div><div class="price-cell"><small>VENDER</small><strong>'+game.price(p.id,n.id,false)+' €</strong></div><div class="trade-buttons"><button class="buy" data-trade="buy" data-product="'+p.id+'" aria-label="Comprar '+p.name+'">Comprar '+quantity+'</button><button class="sell" data-trade="sell" data-product="'+p.id+'" aria-label="Vender '+p.name+'">Vender '+quantity+'</button></div></div>';
      });
      body+='<p class="modal-note">Presupuesto de '+escape(n.name.split(' · ')[0])+': '+fmt(s.budgets[n.id])+'. Los precios dependen del barrio y los eventos. Descansa en casa para empezar un nuevo día. Toda la mercancía es imaginaria.</p>';
    }else{
      const offer=(title,desc,label,attrs,disabled=false)=>'<div class="offer"><div><strong>'+title+'</strong><p>'+desc+'</p></div><button class="buy" '+attrs+' '+(disabled?'disabled':'')+'>'+label+'</button></div>';
      if(n.id==='toni'){
        properties.forEach(p=>body+=offer(p.name,'+'+p.income+' € / 30 s · '+content.districts.find(d=>d.id===p.district).name.split(' · ')[0],s.properties.includes(p.id)?'Tu negocio':fmt(p.cost),'data-property="'+p.id+'"',s.properties.includes(p.id)));
      }else if(n.id==='scot'){
        body+=offer('Mochila de bolsillo infinito','Capacidad +16. Scot jura que es física avanzada.','300 €','data-upgrade="mochila"',s.upgrades.includes('mochila'));
        body+=offer('Zapatillas de las buenas','Muévete más rápido. El estilo viene incluido.','240 €','data-upgrade="zapatillas"',s.upgrades.includes('zapatillas'));
      }else if(n.id==='soto')body+=offer('Soto en tu equipo','−45% de sospecha por operación y enfriamiento más rápido.','700 €','data-upgrade="seguridad"',s.upgrades.includes('seguridad'));
      else if(n.id==='garcia')body+=offer('Negociación de márgenes','Mejora el precio de venta un 12%, manteniendo el margen del comerciante.','450 €','data-upgrade="negociador"',s.upgrades.includes('negociador'));
      else if(n.id==='cristian'){
        body+=offer('Asesoría financiera','Desbloquea depósitos. Rentabilidad ficticia del 3,5% cada 30 s.','500 €','data-upgrade="finanzas"',s.upgrades.includes('finanzas'));
        if(s.upgrades.includes('finanzas')){
          body+=offer('Cartera de inversión',fmt(s.investment)+' invertidos. Puedes retirar tu capital en bloques de 1.000 €.','Invertir 1.000 €','data-invest="1000"');
          body+=offer('Retirar capital','Recupera una parte de tus inversiones.','Retirar 1.000 €','data-invest="-1000"',s.investment<1000);
        }
      }else if(n.id==='monfe')body+=offer('Café con discreción','−35 de sospecha. Con un café y cero stories.','75 €','data-cooldown');
      else if(n.id==='xoxi')body+='<div class="stat-card"><small>EL RUMOR DE LA NOCHE</small><p class="modal-note">Peralta vende barato en el Polígono. Costa Esmeralda paga más, pero exige 28 de reputación. Si llevas mucha mercancía, evita las patrullas antes de vender. La información se actualiza cada día.</p></div>';
      else if(n.id==='navarro')body+='<div class="stat-card"><small>ENCARGO DE LEYENDA</small><strong>Domina el puerto.</strong><p class="modal-note">Habla con Peralta, entra en el Puerto y contrata a Soto. «Sin equipo no hay gira, colega». Tu campaña registra los objetivos y paga al completarlos.</p></div>';
      else if(n.id==='peralta')body+='<div class="stat-card"><small>RUTA DE SUMINISTROS</small><p class="modal-note">Mis precios de compra son los más bajos de la ciudad. Lleva la mercancía a otros barrios para ganar margen. Tu mochila limita cada viaje. Descansa para renovar la demanda.</p></div>';
      else body+='<div class="stat-card"><small>CLIENTE DEL BARRIO</small><p class="modal-note">Lola paga mejor que Monfe, hasta agotar su presupuesto diario. Si no le queda dinero, prueba en el Centro o descansa en casa.</p></div>';
    }
    const specialLabel={toni:'Propiedades',scot:'Tecnología',soto:'Seguridad',garcia:'Negociación',cristian:'Finanzas',navarro:'Encargo',monfe:'Un favor',xoxi:'Rumores',peralta:'Logística',lola:'Sobre Lola'}[n.id];
    openPanel('npc',header(n.name,n.role)+'<div class="dialogue"><canvas id="portrait" class="portrait" width="76" height="86"></canvas><div><p>'+escape(n.lines[line%n.lines.length])+'</p><button id="next-line">Seguir hablando →</button></div></div><div class="tabs"><button data-tab="market" class="'+(tab==='market'?'active':'')+'">Mercado</button><button data-tab="special" class="'+(tab==='special'?'active':'')+'">'+specialLabel+'</button></div>'+body+'<div class="feedback '+(feedbackBad?'bad':'')+'" role="status">'+escape(feedback)+'</div>');
    const portrait=$('#portrait').getContext('2d');portrait.imageSmoothingEnabled=false;portrait.fillStyle='#252e3e';portrait.fillRect(0,0,76,86);portrait.scale(2.2,2.2);drawPerson(portrait,17,22,n.color,0,1,n.id);
    $('#next-line').onclick=()=>{line++;openNPC(n,false);};
    document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{tab=b.dataset.tab;feedback='';openNPC(n,false);});
    $('#quantity')?.addEventListener('change',e=>{quantity=+e.target.value;openNPC(n,false);});
    document.querySelectorAll('[data-trade]').forEach(b=>b.onclick=()=>{reply(game.trade(n.id,b.dataset.product,quantity,b.dataset.trade==='buy'));openNPC(n,false);});
    document.querySelectorAll('[data-property]').forEach(b=>b.onclick=()=>{reply(game.purchaseProperty(b.dataset.property));openNPC(n,false);});
    document.querySelectorAll('[data-upgrade]').forEach(b=>b.onclick=()=>{reply(game.upgrade(b.dataset.upgrade));openNPC(n,false);});
    document.querySelectorAll('[data-invest]').forEach(b=>b.onclick=()=>{reply(game.invest(+b.dataset.invest));openNPC(n,false);});
    $('[data-cooldown]')?.addEventListener('click',()=>{reply(game.coolDown());openNPC(n,false);});
    renderHUD();
  }
  function openHome(){
    openPanel('home',header('Piso compacto. Sueños grandes.','TU APARTAMENTO')+'<div class="intro-body"><p>Una persiana torcida, un sofá de segunda mano y un cargador que solo funciona en una postura. Aquí la sospecha baja más rápido.</p><p>Descansar avanza al siguiente día: renueva presupuestos, demanda y eventos; reduce la sospecha 25 puntos. Los ingresos pasivos se generan mientras exploras.</p></div><div class="panel-actions"><button class="primary" id="rest">Descansar · siguiente día →</button><button class="secondary" id="home-save">Guardar partida</button></div>');
    $('#rest').onclick=()=>{game.rest();save();closePanel();sound(262,.2,'triangle');};$('#home-save').onclick=()=>save(true);
  }
  function interact(){
    const n=game.nearNPC();
    if(n){openNPC(n);return;}
    if(Math.hypot(game.state.x-320,game.state.y-1040)<90){openHome();return;}
    game.announce('Acércate a un personaje o a tu apartamento para interactuar.');
  }
  function inventory(){
    const s=game.state;
    const cards=[['VENTAS ACUMULADAS',fmt(s.revenue)],['GASTOS',fmt(s.spent)],['OPERACIONES',s.deals],['DETENCIONES',s.arrested],['REPUTACIÓN CON AUTORIDADES',s.authority],['MULTAS',fmt(s.fines)]];
    openPanel('inventory',header('Lo que llevas. Lo que construyes.','INVENTARIO Y ESTADÍSTICAS')+'<div class="shop-header">Mochila '+game.count()+' / '+s.capacity+' · Efectivo '+fmt(s.cash)+'</div>'+content.products.map(p=>'<div class="offer"><div class="product-label"><i style="background:'+p.color+'"></i><strong>'+p.name+'</strong></div><strong>'+s.inventory[p.id]+' unidades</strong></div>').join('')+'<div class="panel-grid">'+cards.map(([label,value])=>'<div class="stat-card"><small>'+label+'</small><strong>'+value+'</strong></div>').join('')+'</div><p class="modal-note">Mejoras: '+(s.upgrades.map(escape).join(' · ')||'Por estrenar')+'. Negocios: '+(properties.filter(p=>s.properties.includes(p.id)).map(p=>p.name).join(' · ')||'Tu apartamento, de momento')+'.</p>');
  }
  function missionTarget(){
    const id=['monfe','monfe','lola','scot','garcia','toni','navarro','peralta','soto','cristian','toni','navarro'][Math.min(game.state.mission,11)];
    if(game.state.mission===7 && game.state.met.includes('peralta'))return content.npcs.find(n=>n.id==='soto');
    return content.npcs.find(n=>n.id===id);
  }
  function showMap(){
    openPanel('map',header('Puerto Bruma. Tu tablero.','MAPA DE LA CIUDAD')+'<canvas id="map-canvas" class="map-canvas" width="900" height="540" aria-label="Mapa: pulsa para colocar una marca de ruta"></canvas><div class="map-legend"><span style="color:var(--orange)">◆ Tú</span><span style="color:var(--mint)">● Contactos</span><span>▨ Barrio bloqueado</span></div><div class="map-list">'+content.districts.map(d=>'<div class="'+(d.minRep>game.state.rep?'locked':'')+'"><strong>'+escape(d.name.split(' · ')[0])+'</strong>'+(d.minRep>game.state.rep?'Bloqueado · '+d.minRep+' REP':'Abierto · precios ×'+d.priceMultiplier)+'</div>').join('')+'</div><p class="modal-note">Pulsa el mapa para marcar un destino. La marca te orienta mientras caminas; las calles conectan todos los barrios. Necesitas reputación para entrar en las zonas bloqueadas.</p>');
    const mc=$('#map-canvas'),c=mc.getContext('2d');c.scale(.375,.375);
    content.districts.forEach(d=>{
      c.fillStyle=d.color;c.fillRect(d.x+4,d.y+4,d.w-8,d.h-8);c.fillStyle='#0c1624';c.fillRect(d.x,d.y+320,d.w,80);c.fillRect(d.x+360,d.y,80,d.h);
      c.fillStyle='#d0d9e5';c.font='bold 32px sans-serif';c.fillText(d.name.split(' · ')[0].toUpperCase(),d.x+50,d.y+80);
      if(d.minRep>game.state.rep){c.fillStyle='#0c1228b8';c.fillRect(d.x,d.y,d.w,d.h);c.fillStyle='#9aa5b8';c.font='32px sans-serif';c.fillText('BLOQUEADO · '+d.minRep+' REP',d.x+270,d.y+270);}
    });
    game.buildings.forEach(b=>{c.fillStyle='#556176';c.fillRect(b.x,b.y,b.w,b.h);});
    content.npcs.forEach(n=>{if(game.districtAt(n.x,n.y).minRep>game.state.rep)return;c.fillStyle=n.color;c.beginPath();c.arc(n.x,n.y,16,0,7);c.fill();c.fillStyle='#e8ede9';c.font='24px sans-serif';c.fillText(n.name.split(' · ')[0],n.x+20,n.y-15);});
    c.fillStyle='#f7b877';c.beginPath();c.arc(game.state.x,game.state.y,22,0,7);c.fill();
    if(waypoint){c.strokeStyle='#f7b877';c.lineWidth=5;c.strokeRect(waypoint.x-18,waypoint.y-18,36,36);}
    mc.onclick=e=>{const r=mc.getBoundingClientRect();waypoint={x:(e.clientX-r.left)/r.width*2400,y:(e.clientY-r.top)/r.height*1440};closePanel();game.announce('Destino marcado. Sigue la flecha naranja.');};
  }
  $('#map-button').onclick=showMap;$('#track-button').onclick=()=>{const n=missionTarget();waypoint={x:n.x,y:n.y};game.announce('Ruta marcada: '+n.name.split(' · ')[0]);};
  function ending(){
    endingShown=true;save();sound(523,.3,'triangle');setTimeout(()=>sound(659,.3,'triangle'),130);
    openPanel('ending',header('La ciudad ya conoce tu nombre.','CAMPAÑA COMPLETADA · 12 / 12')+'<div class="finale-body">'+content.finale.map(p=>'<p>'+escape(p)+'</p>').join('')+'</div><div class="panel-actions"><button class="primary" id="keep-playing">Seguir construyendo →</button></div>');$('#keep-playing').onclick=closePanel;
  }
  function renderHUD(){
    const s=game.state,q=content.missions[s.mission];
    $('#cash').textContent=fmt(s.cash);$('#rep').innerHTML=Math.floor(s.rep)+' <em>/ 100</em>';
    $('#heat-bar').style.width=s.heat+'%';$('#heat-bar').style.background=s.heat>=28?'#ee8390':'#f7b877';
    $('#heat-label').textContent='SOSPECHA · '+(s.heat>=65?'PERSECUCIÓN':s.heat>=28?'EN EL RADAR':'TRANQUILO');
    $('#mission-count').textContent=String(Math.min(s.mission+1,12)).padStart(2,'0')+' / 12';
    $('#mission-title').textContent=q?q.title:'El imperio es tuyo.';
    $('#mission-description').textContent=q?q.description:'Campaña completada. Sigue explorando, comerciando y ampliando tus negocios.';
    $('#mission-reward').textContent=q?'+'+q.reward+' €  ·  +'+q.rep+' REPUTACIÓN':'✓ HISTORIA COMPLETADA';
    $('#capacity-label').textContent=game.count()+' / '+s.capacity;
    $('#inventory-mini').innerHTML=content.products.map(p=>'<div class="inventory-item"><span class="gem" style="background:'+p.color+'"></span>'+p.name+'<span class="qty">'+s.inventory[p.id]+'</span></div>').join('');
    $('#wealth').textContent=fmt(game.wealth());$('#wealth-bar').style.width=clamp(game.wealth()/15000*100,0,100)+'%';$('#property-count').textContent=s.properties.length;
    const d=game.districtAt();$('#district-name').textContent=d.name.split(' · ')[1]||d.name;
    const hours=(21+Math.floor(s.clock/30))%24,minutes=Math.floor((s.clock%30)*2);
    $('#city-time').textContent='DÍA '+String(s.day).padStart(2,'0')+' · '+String(hours).padStart(2,'0')+':'+String(minutes).padStart(2,'0');
    const target=missionTarget();$('#track-label').textContent=target.name.split(' · ')[0]+' · '+Math.round(Math.hypot(target.x-s.x,target.y-s.y))+' m';
    const near=game.nearNPC(),home=Math.hypot(s.x-320,s.y-1040)<90;
    $('#interaction-hint').hidden=mode!=='play'||(!near&&!home);
    $('#interaction-hint span').textContent=near?'Hablar con '+near.name.split(' · ')[0]:'Entrar en tu apartamento';
    if(!storageAvailable)$('#save-status').textContent='⚠ Guardado local no disponible';
  }
  function notify(){
    while(game.notices.length){const n=game.notices.shift(),el=document.createElement('div');el.className='notice '+(n.tone==='bad'?'bad':'');el.textContent=n.text;$('#notifications').appendChild(el);setTimeout(()=>el.remove(),5600);while($('#notifications').children.length>4)$('#notifications').firstChild.remove();}
  }
  addEventListener('keydown',e=>{
    const key=e.key.toLowerCase();
    if(mode==='play'&&['arrowup','arrowdown','arrowleft','arrowright',' ','tab','f5'].includes(key))e.preventDefault();
    if(e.repeat)return;
    if(key==='escape'){if(mode==='modal')closePanel();else if(mode==='play')pause();return;}
    if(mode!=='play')return;
    if(['w','a','s','d','arrowup','arrowdown','arrowleft','arrowright'].includes(key))keys.add(key);
    if(key==='e')interact();if(key==='i'||key==='tab')inventory();if(key==='m')showMap();if(key==='f5')save(true);
  });
  addEventListener('keyup',e=>keys.delete(e.key.toLowerCase()));
  addEventListener('blur',()=>{keys.clear();if(mode==='play')pause();});
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&mode==='play')pause();});
  addEventListener('beforeunload',()=>{if(mode!=='menu')save();});
  const touch=document.createElement('div');touch.className='mobile-controls';touch.innerHTML='<button data-key="a" aria-label="Izquierda">←</button><div class="vertical"><button data-key="w" aria-label="Arriba">↑</button><button data-key="s" aria-label="Abajo">↓</button></div><button data-key="d" aria-label="Derecha">→</button><button class="mobile-interact" aria-label="Interactuar">E</button>';
  document.body.appendChild(touch);
  touch.querySelectorAll('[data-key]').forEach(b=>{b.onpointerdown=e=>{if(mode!=='play')return;e.preventDefault();b.setPointerCapture(e.pointerId);keys.add(b.dataset.key);};b.onpointerup=b.onpointercancel=()=>keys.delete(b.dataset.key);});touch.querySelector('.mobile-interact').onclick=()=>{if(mode==='play')interact();};

  function rect(c,x,y,w,h,color){c.fillStyle=color;c.fillRect(Math.round(x),Math.round(y),w,h);}
  function text(c,label,x,y,color='#b6c2cf',size=10,align='center'){c.fillStyle=color;c.font=(size>15?'700 ':'600 ')+size+'px monospace';c.textAlign=align;c.fillText(label,Math.round(x),Math.round(y));}
  function glow(x,y,color,r){const g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,color);g.addColorStop(1,'#00000000');ctx.fillStyle=g;ctx.fillRect(x-r,y-r,r*2,r*2);}
  function drawPerson(c,x,y,color,step=0,direction=1,id='player'){
    x=Math.round(x);y=Math.round(y);const gait=Math.sin(step)*2;
    c.fillStyle='#07101a75';c.beginPath();c.ellipse(x,y+13,11,4,0,0,7);c.fill();
    rect(c,x-5,y+6+gait,4,9,'#334367');rect(c,x+2,y+6-gait,4,9,'#293556');
    rect(c,x-6,y+14+gait,6,3,'#101c2a');rect(c,x+1,y+14-gait,6,3,'#101c2a');
    rect(c,x-7,y-4,14,13,color);rect(c,x-10,y-2,3,10,'#d9a889');rect(c,x+7,y-2,3,10,'#d9a889');
    rect(c,x-6,y-15,12,12,'#e0b28e');rect(c,x-7,y-17,14,5,id==='navarro'?'#eee1ba':'#24212c');
    rect(c,x-6,y-13,3,4,'#29232c');rect(c,x+3,y-11,2,2,'#392a2b');
    if(id==='player'){rect(c,x-4,y-3,2,9,'#c58648');rect(c,x+7,y+3,4,6,'#21334c');rect(c,x+8,y+4,2,3,'#8ae1e6');}
    if(id==='navarro'){rect(c,x-4,y-1,8,2,'#f9d15e');rect(c,x-6,y-12,12,3,'#141c27');}
    if(id==='scot'){rect(c,x-7,y-12,14,3,'#272c3d');rect(c,x-4,y-12,3,2,'#70ebea');rect(c,x+2,y-12,3,2,'#70ebea');}
    if(id==='soto'||id==='police'){rect(c,x-7,y-19,14,4,'#647dad');rect(c,x-2,y-18,4,2,'#edc17a');}
    if(direction<0){rect(c,x-5,y-11,2,2,'#392a2b');}
  }
  function palm(x,y){
    rect(ctx,x-2,y,5,29,'#726255');rect(ctx,x,y+7,2,18,'#a18c68');
    ctx.strokeStyle='#163f43';ctx.lineWidth=8;
    [[-20,-8],[18,-9],[-14,11],[15,8],[0,-17]].forEach(([dx,dy])=>{ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(x+dx,y+dy);ctx.stroke();});
    ctx.strokeStyle='#477466';ctx.lineWidth=3;[[-18,-10],[17,-9],[-12,9],[13,5]].forEach(([dx,dy])=>{ctx.beginPath();ctx.moveTo(x,y-3);ctx.lineTo(x+dx,y+dy);ctx.stroke();});
  }
  function drawBuilding(b,i){
    const x=b.x,y=b.y,w=b.w,h=b.h;
    const colors=[['#505063','#3d3f55'],['#4b5b64','#344653'],['#695759','#4b414f'],['#4c576e','#354559'],['#586458','#3b4c4c']][b.variant];
    rect(ctx,x+10,y+12,w,h,'#080d1a66');rect(ctx,x,y,w,h,colors[1]);rect(ctx,x,y,w,h-19,colors[0]);
    rect(ctx,x+6,y+6,w-12,h-31,'#ffffff06');rect(ctx,x,y,w,5,'#ffffff18');rect(ctx,x+6,y+6,w-12,3,'#0c172b45');
    rect(ctx,x+20,y+21,w-40,h-64,'#212b3c55');
    for(let a=0;a<4;a++)for(let r=0;r<2;r++){
      const wx=x+25+a*49,wy=y+28+r*53;
      rect(ctx,wx,wy,28,28,'#152033');
      rect(ctx,wx+2,wy+2,24,23,((i+a+r)%3===0)?'#e0b76b':'#65788a');
      rect(ctx,wx+13,wy+2,2,23,'#293b50');rect(ctx,wx+2,wy+12,24,2,'#293b50');
      if((i+a+r)%3===0)glow(wx+14,wy+15,'#f9c26d10',31);
    }
    rect(ctx,x+90,y+25,45,32,'#67727a');rect(ctx,x+94,y+29,37,24,'#344352');
    for(let k=0;k<4;k++)rect(ctx,x+96,y+33+k*5,32,2,'#899497');
    rect(ctx,x+25,y+h-31,w-50,10,'#1b2639');
    const labels=['CAFÉ SIN PRISA','LA PERSIANA','NAVE 404','COSTA BRUMA','SUPERMERCADO','MEDIO EURO','PENSIÓN NEÓN','BAR POTENCIAL'];
    const label=labels[(i*3+b.variant)%labels.length],neon=i%3===0?'#f3b984':i%3===1?'#83cfbd':'#b3a0e0';
    text(ctx,label,x+w/2,y+h-23,neon,9);glow(x+w/2,y+h-23,neon+'20',80);
    rect(ctx,x+w/2-15,y+h-19,30,19,'#142130');rect(ctx,x+w/2-12,y+h-17,24,13,'#71868a');
    rect(ctx,x+w/2+7,y+h-9,2,2,'#f7b877');
    for(let a=0;a<5;a++){rect(ctx,x+15+a*43,y+h-16,29,9,neon+'80');}
    if(b.district==='barrio'&&i%4===2){text(ctx,'MANCEBO · 3º B',x+w/2,y+h+16,'#e2b378',9);rect(ctx,x+w-32,y+20,20,48,'#687384');}
    if(b.district==='poligono'){rect(ctx,x+18,y+h-40,68,30,'#333743');for(let k=0;k<6;k++)rect(ctx,x+20,y+h-37+k*4,64,1,'#647280');}
  }
  function drawWorld(){
    ctx.setTransform(dpr,0,0,dpr,0,0);ctx.fillStyle='#141d2b';ctx.fillRect(0,0,width,height);
    const drawCamX=clamp(camX,width*.46/zoom,2400-width*.54/zoom);
    const drawCamY=clamp(camY,height*.53/zoom,1440-height*.47/zoom);
    ctx.save();ctx.translate(Math.round(width*.46),Math.round(height*.53));ctx.scale(zoom,zoom);ctx.translate(-Math.round(drawCamX),-Math.round(drawCamY));
    const view={x:drawCamX-width/(2*zoom)-120,y:drawCamY-height/(2*zoom)-120,w:width/zoom+300,h:height/zoom+300};
    content.districts.forEach((d,i)=>{
      rect(ctx,d.x,d.y,d.w,d.h,d.color);rect(ctx,d.x,d.y+320,800,80,'#1b2634');rect(ctx,d.x+360,d.y,80,720,'#1b2634');
      // Continuous perimeter boulevards connect the six neighbourhoods.
      rect(ctx,d.x,d.y,800,58,'#1b2634');rect(ctx,d.x,d.y+670,800,50,'#1b2634');rect(ctx,d.x,d.y,50,720,'#1b2634');rect(ctx,d.x+754,d.y,46,720,'#1b2634');
      rect(ctx,d.x,d.y+310,800,8,'#84909c33');rect(ctx,d.x,d.y+402,800,8,'#84909c33');
      rect(ctx,d.x+350,d.y,8,720,'#84909c33');rect(ctx,d.x+443,d.y,8,720,'#84909c33');
      for(let k=0;k<16;k++){if(k<7||k>9)rect(ctx,d.x+k*50,d.y+358,20,3,'#cfb67735');}
      for(let k=0;k<14;k++){if(k<6||k>8)rect(ctx,d.x+399,d.y+k*50,3,20,'#cfb67735');}
      for(let k=0;k<6;k++){rect(ctx,d.x+365+k*12,d.y+280,6,22,'#aab3bf55');rect(ctx,d.x+365+k*12,d.y+421,6,22,'#aab3bf55');}
      for(let k=0;k<4;k++){
        const lx=d.x+55+k*220,ly=d.y+308;
        rect(ctx,lx,ly,3,23,'#88909b');rect(ctx,lx-5,ly-4,13,5,'#f6c67d');glow(lx+1,ly-1,'#f7ca7830',65);
        if(k!==1)palm(lx+15,d.y+431);
      }
      text(ctx,d.name.split(' · ')[1]?.toUpperCase()||d.name.toUpperCase(),d.x+560,d.y+440,'#9aaabd4d',17);
      text(ctx,'PUERTO BRUMA',d.x+150,d.y+78,'#d0d6dd32',9);
      // Street furniture, a moped, parked cars and bins.
      rect(ctx,d.x+530,d.y+292,45,6,'#a28868');rect(ctx,d.x+535,d.y+298,3,8,'#292d37');rect(ctx,d.x+567,d.y+298,3,8,'#292d37');
      rect(ctx,d.x+334,d.y+510,12,18,'#526e69');rect(ctx,d.x+336,d.y+513,8,3,'#9aa896');
      const carX=d.x+100,carY=d.y+360;
      rect(ctx,carX-3,carY+4,53,23,'#090f1990');rect(ctx,carX,carY,48,24,['#867788','#a97a69','#56838c'][i%3]);rect(ctx,carX+12,carY+3,24,18,'#273c51');rect(ctx,carX+18,carY+5,12,14,'#638097');rect(ctx,carX+43,carY+3,4,5,'#efcea0');rect(ctx,carX+43,carY+17,4,5,'#efcea0');
      rect(ctx,d.x+650,d.y+299,17,7,'#c79e71');rect(ctx,d.x+652,d.y+297,4,4,'#212938');rect(ctx,d.x+662,d.y+297,4,4,'#212938');
    });
    // Mediterranean sea, concrete quay, moving glints.
    rect(ctx,2340,740,60,700,'#173646');
    for(let y=760;y<1440;y+=20)for(let x=2350;x<2390;x+=24)rect(ctx,x+(settings.motion?Math.sin(elapsed*.6+y)*3:0),y,14,2,'#4e849065');
    game.buildings.forEach((b,i)=>{if(b.x+b.w>view.x&&b.x<view.x+view.w&&b.y+b.h>view.y&&b.y<view.y+view.h)drawBuilding(b,i);});
    // Your starting front door and property markers.
    rect(ctx,313,1003,24,7,'#91dabd');text(ctx,'TU CASA',325,994,'#b4e2c8',8);
    properties.forEach(p=>{if(game.state.properties.includes(p.id)){glow(p.x,p.y,'#91dabd18',80);text(ctx,'⌂ TU NEGOCIO',p.x,p.y-4,'#91dabd',10);}});
    if(waypoint){glow(waypoint.x,waypoint.y,'#f7b87724',60);ctx.strokeStyle='#f7b877';ctx.lineWidth=2;ctx.beginPath();ctx.arc(waypoint.x,waypoint.y,18+(settings.motion?Math.sin(elapsed*3)*3:0),0,7);ctx.stroke();text(ctx,'DESTINO',waypoint.x,waypoint.y-26,'#f7b877',9);}
    const actors=content.npcs.map(n=>({x:n.x,y:n.y,color:n.color,id:n.id,npc:n}));
    game.police.forEach(p=>actors.push({...p,color:'#6788b8',id:'police'}));actors.push({x:game.state.x,y:game.state.y,color:'#e4ad6f',id:'player'});actors.sort((a,b)=>a.y-b.y);
    actors.forEach(a=>{
      if(a.x<view.x||a.x>view.x+view.w||a.y<view.y||a.y>view.y+view.h)return;
      if(a.id==='player'){glow(a.x,a.y,'#f7bb6c15',55);ctx.strokeStyle='#e9bf77';ctx.lineWidth=1;ctx.beginPath();ctx.ellipse(a.x,a.y+13,15,6,0,0,7);ctx.stroke();}
      if(a.id==='police'){glow(a.x-5,a.y-12,(settings.motion&&Math.sin(elapsed*6)>0)?'#6fa6ff33':'#e56a8122',26);}
      drawPerson(ctx,a.x,a.y,a.color,a.id==='player'?walk:0,a.id==='player'?face:1,a.id);
      if(a.npc){
        const near=Math.hypot(a.x-game.state.x,a.y-game.state.y)<95;
        text(ctx,a.npc.name.split(' · ')[0],a.x,a.y-28,near?'#e8eedc':'#c2cddd',10);
        if(near){rect(ctx,a.x-7,a.y-47,14,13,'#91dabd');text(ctx,'E',a.x,a.y-37,'#183128',9);}
      }
    });
    content.districts.filter(d=>d.minRep>game.state.rep).forEach(d=>{
      rect(ctx,d.x,d.y,d.w,d.h,'#11162994');
      ctx.strokeStyle='#e8ba6255';ctx.lineWidth=3;ctx.setLineDash([9,12]);ctx.strokeRect(d.x+3,d.y+3,d.w-6,d.h-6);ctx.setLineDash([]);
      text(ctx,d.name.split(' · ')[0].toUpperCase(),d.x+d.w/2,d.y+d.h/2-12,'#9aacc2',22);text(ctx,d.minRep+' REPUTACIÓN PARA ENTRAR',d.x+d.w/2,d.y+d.h/2+16,'#e8ba62',11);
    });
    ctx.restore();
    // A small direction arrow points towards the chosen destination outside the screen.
    if(waypoint&&mode==='play'){
      const dx=(waypoint.x-game.state.x)*zoom,dy=(waypoint.y-game.state.y)*zoom,dist=Math.hypot(dx,dy);
      if(dist>150){const angle=Math.atan2(dy,dx),x=width*.46+(game.state.x-drawCamX)*zoom+Math.cos(angle)*95,y=height*.53+(game.state.y-drawCamY)*zoom+Math.sin(angle)*95;ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.fillStyle='#f7b877';ctx.beginPath();ctx.moveTo(10,0);ctx.lineTo(-5,-5);ctx.lineTo(-5,5);ctx.fill();ctx.restore();}
      else if(dist<28)waypoint=null;
    }
  }
  function frame(t){
    const dt=Math.min((t-last)/1000||0,.05);last=t;elapsed+=dt;
    if(mode==='play'){
      let dx=+(keys.has('d')||keys.has('arrowright'))-+(keys.has('a')||keys.has('arrowleft'));
      let dy=+(keys.has('s')||keys.has('arrowdown'))-+(keys.has('w')||keys.has('arrowup'));
      game.move(dx,dy,dt);game.tick(dt);if(dx||dy){walk+=dt*11;if(dx)face=dx;}else walk=0;
      camX+=(game.state.x-camX)*Math.min(1,dt*8);camY+=(game.state.y-camY)*Math.min(1,dt*8);
      hudClock+=dt;saveClock+=dt;if(hudClock>.15){renderHUD();hudClock=0;}if(saveClock>10){save();saveClock=0;}
      if(game.state.won&&!endingShown)ending();
    }else if(mode==='menu'){
      camX=500+Math.sin(elapsed*.07)*100;camY=1030+Math.cos(elapsed*.05)*60;
    }
    drawWorld();notify();requestAnimationFrame(frame);
  }
  window.__imperio={game,get mode(){return mode;},save};
  requestAnimationFrame(frame);
})();
