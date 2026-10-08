'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Game, properties } = require('../web/model.js');
const content = JSON.parse(fs.readFileSync(path.join(__dirname, '../shared/content.json'), 'utf8'));
const fresh = () => new Game(content, () => 0);
const accepted = result => assert.equal(result.ok, true, result.reason);
function rejectedWithoutMutation(game, action) {
  const before = game.serialize();
  assert.equal(action().ok, false);
  assert.equal(game.serialize(), before, 'una operación rechazada debe conservar el estado');
}
function advance(game, seconds) {
  for (let i = 0; i < Math.ceil(seconds / 0.1); i++) game.tick(0.1);
}
function walkToNPC(game, id) {
  const npc = content.npcs.find(n => n.id === id);
  const queue = [{ x: game.state.x, y: game.state.y, parent: null }];
  const seen = new Set([`${game.state.x},${game.state.y}`]);
  let destination;
  for (let i = 0; i < queue.length; i++) {
    const current = queue[i];
    if (Math.hypot(current.x - npc.x, current.y - npc.y) < 60) {
      destination = current;
      break;
    }
    for (const [dx, dy] of [[20, 0], [-20, 0], [0, 20], [0, -20]]) {
      const x = current.x + dx, y = current.y + dy, key = `${x},${y}`;
      if (!seen.has(key) && game.canStand(x, y)) {
        seen.add(key);
        queue.push({ x, y, parent: current });
      }
    }
  }
  assert.ok(destination, `debe haber ruta a ${npc.name} con REP ${game.state.rep}`);
  const steps = [];
  while (destination.parent) {
    steps.push(destination);
    destination = destination.parent;
  }
  for (const point of steps.reverse()) {
    const dx = point.x - game.state.x, dy = point.y - game.state.y;
    const speed = game.state.upgrades.includes('zapatillas') ? 250 : 210;
    game.move(dx, dy, 20 / speed);
    assert.ok(Math.hypot(game.state.x - point.x, game.state.y - point.y) < 1e-6);
  }
  assert.equal(game.nearNPC().id, id);
  game.meet(id);
}

test('contenido completo y claves únicas para todas las escenas jugables', () => {
  assert.equal(content.districts.length, 6);
  assert.equal(content.npcs.length, 10);
  assert.equal(content.products.length, 3);
  assert.equal(content.missions.length, 12);
  for (const collection of [content.districts, content.npcs, content.products, content.missions]) {
    assert.equal(new Set(collection.map(item => item.id)).size, collection.length);
  }
  const game = fresh();
  for (const npc of content.npcs) {
    assert.ok(content.districts.includes(game.districtAt(npc.x, npc.y)));
    assert.ok(npc.lines.length >= 3);
  }
});

test('movimiento real normalizado, límites, colisiones y desbloqueo de barrios', () => {
  const game = fresh();
  const start = { x: game.state.x, y: game.state.y };
  assert.ok(game.canStand(start.x, start.y));
  game.move(1, 1, 0.1);
  assert.ok(Math.abs(Math.hypot(game.state.x - start.x, game.state.y - start.y) - 21) < 1e-7);
  assert.equal(game.canStand(0, 0), false);
  assert.equal(game.canStand(2399, 1439), false);
  assert.equal(game.canStand(100, 850), false, 'edificio del Barrio');
  game.state.x = 790;
  game.state.y = 1080;
  game.move(1, 0, 0.1);
  assert.equal(game.state.x, 790, 'Costa Esmeralda requiere reputación');
  game.state.rep = 28;
  game.move(1, 0, 0.1);
  assert.ok(game.state.x > 800);
  assert.ok(game.state.visited.includes('lujo'));
});

test('todos los NPC tienen posición transitable y ruta peatonal desde el apartamento', () => {
  const game = fresh();
  game.state.rep = 100;
  const step = 20;
  const seen = new Set(['320,1040']);
  const queue = [[320, 1040]];
  for (let i = 0; i < queue.length; i++) {
    const [x, y] = queue[i];
    for (const [dx, dy] of [[step, 0], [-step, 0], [0, step], [0, -step]]) {
      const next = [x + dx, y + dy], key = next.join(',');
      if (!seen.has(key) && game.canStand(...next)) {
        seen.add(key);
        queue.push(next);
      }
    }
  }
  for (const npc of content.npcs) {
    assert.ok(game.canStand(npc.x, npc.y), npc.name + ' no debe estar dentro de un edificio');
    assert.ok(queue.some(([x, y]) => Math.hypot(x - npc.x, y - npc.y) < 60), npc.name + ' debe ser accesible caminando');
  }
});

test('compras respetan efectivo, capacidad y cantidades válidas sin mutaciones parciales', () => {
  const game = fresh();
  for (const quantity of [-1, 0, 0.5, 101, NaN, Infinity, '1']) {
    rejectedWithoutMutation(game, () => game.trade('monfe', 'bruma', quantity, true));
  }
  rejectedWithoutMutation(game, () => game.trade('desconocido', 'bruma', 1, true));
  rejectedWithoutMutation(game, () => game.trade('monfe', 'desconocido', 1, true));
  game.state.cash = 0;
  rejectedWithoutMutation(game, () => game.trade('monfe', 'bruma', 1, true));
  game.state.cash = 10000;
  game.state.inventory.sol = 20;
  rejectedWithoutMutation(game, () => game.trade('monfe', 'bruma', 1, true));
  game.state.inventory.sol = 19;
  const price = game.price('bruma', 'monfe', true);
  accepted(game.trade('monfe', 'bruma', 1, true));
  assert.equal(game.count(), 20);
  assert.equal(game.state.cash, 10000 - price);
  assert.equal(game.state.spent, price);
});

test('ventas respetan inventario, presupuesto diario y demanda por producto', () => {
  const game = fresh();
  rejectedWithoutMutation(game, () => game.trade('lola', 'bruma', 1, false));
  game.state.inventory.bruma = 10;
  game.state.budgets.lola = 0;
  rejectedWithoutMutation(game, () => game.trade('lola', 'bruma', 1, false));
  game.state.budgets.lola = 1000;
  game.state.demand['lola:bruma'] = 0;
  rejectedWithoutMutation(game, () => game.trade('lola', 'bruma', 1, false));
  game.state.demand['lola:bruma'] = 5;
  const price = game.price('bruma', 'lola', false);
  accepted(game.trade('lola', 'bruma', 5, false));
  assert.equal(game.state.cash, 500 + 5 * price);
  assert.equal(game.state.budgets.lola, 1000 - 5 * price);
  assert.equal(game.state.demand['lola:bruma'], 0);
  assert.equal(game.state.totalSold, 5);
  assert.equal(game.state.revenue, 5 * price);
  rejectedWithoutMutation(game, () => game.trade('lola', 'bruma', 1, false));
  game.rest();
  assert.ok(game.state.budgets.lola > 0);
  assert.ok(game.state.demand['lola:bruma'] > 0);
});

test('ningún comerciante permite recomprar sus unidades con beneficio infinito', () => {
  const game = fresh();
  game.state.met.push('garcia');
  for (const upgrades of [[], ['negociador']]) {
    game.state.upgrades = upgrades;
    for (let day = 1; day <= 9; day++) {
      game.state.day = day;
      for (let event = -1; event < content.events.length; event++) {
        game.state.eventIndex = event;
        for (const npc of content.npcs) for (const product of content.products) {
          assert.ok(game.price(product.id, npc.id, false) <= game.price(product.id, npc.id, true),
            `${npc.id}/${product.id}, día ${day}, evento ${event}, mejoras ${upgrades.join(',')}`);
        }
      }
    }
  }
});

test('mejoras y propiedades requieren colaboradores, dinero y reputación; se cobran una vez', () => {
  const game = fresh();
  rejectedWithoutMutation(game, () => game.upgrade('mochila'));
  game.meet('scot');
  game.state.cash = 299;
  rejectedWithoutMutation(game, () => game.upgrade('mochila'));
  game.state.cash = 1000;
  accepted(game.upgrade('mochila'));
  assert.equal(game.state.cash, 700);
  assert.equal(game.state.capacity, 36);
  assert.equal(game.state.spent, 300);
  rejectedWithoutMutation(game, () => game.upgrade('mochila'));
  rejectedWithoutMutation(game, () => game.purchaseProperty('kiosco'));
  game.meet('toni');
  rejectedWithoutMutation(game, () => game.purchaseProperty('kiosco'));
  game.state.cash = 10000;
  rejectedWithoutMutation(game, () => game.purchaseProperty('muelle'));
  accepted(game.purchaseProperty('kiosco'));
  assert.equal(game.state.cash, 9100);
  assert.equal(game.state.spent, 1200);
  rejectedWithoutMutation(game, () => game.purchaseProperty('kiosco'));
});

test('reputación de mejoras y propiedades queda limitada a 100 y permite guardar', () => {
  const game = fresh();
  game.state.cash = 10000;
  game.state.rep = 100;
  game.state.met.push('toni', 'soto');
  accepted(game.purchaseProperty('kiosco'));
  accepted(game.upgrade('seguridad'));
  assert.equal(game.state.rep, 100);
  assert.equal(fresh().load(game.serialize()), true);
});

test('inversión conserva patrimonio y bloquea retiradas o depósitos imposibles', () => {
  const game = fresh();
  rejectedWithoutMutation(game, () => game.invest(1000));
  game.state.upgrades.push('finanzas');
  rejectedWithoutMutation(game, () => game.invest(1000));
  rejectedWithoutMutation(game, () => game.invest(-1000));
  rejectedWithoutMutation(game, () => game.invest(999));
  game.state.cash = 2500;
  const wealth = game.wealth();
  accepted(game.invest(1000));
  assert.equal(game.state.cash, 1500);
  assert.equal(game.state.investment, 1000);
  assert.equal(game.wealth(), wealth);
  accepted(game.invest(-1000));
  assert.equal(game.state.cash, 2500);
  assert.equal(game.state.investment, 0);
});

test('patrullas detienen, aplican multa y confiscación con período de inmunidad', () => {
  const game = fresh();
  game.state.inventory.bruma = 10;
  game.state.heat = 60;
  game.police[3].x = game.state.x;
  game.police[3].y = game.state.y;
  game.tick(0.1);
  assert.equal(game.state.cash, 420);
  assert.equal(game.state.fines, 80);
  assert.equal(game.state.inventory.bruma, 7);
  assert.equal(game.state.arrested, 1);
  assert.equal(game.state.heat, 0);
  assert.equal(game.state.x, 320);
  assert.equal(game.state.y, 1040);
  game.detain();
  assert.equal(game.state.arrested, 1);
  game.state.cash = 30;
  game.arrestCooldown = 0;
  game.detain();
  assert.equal(game.state.cash, 0, 'las multas nunca crean saldo negativo');
});

test('ingreso pasivo y calendario funcionan, el descanso recupera mercados', () => {
  const game = fresh();
  game.state.properties.push('kiosco');
  game.state.investment = 1000;
  game.state.heat = 20;
  game.state.incomeClock = 29.95;
  game.tick(0.1);
  assert.equal(game.state.cash, 590);
  assert.equal(game.state.revenue, 90);
  assert.ok(game.state.heat < 20);
  game.state.clock = 179.95;
  game.tick(0.1);
  assert.equal(game.state.day, 2);
  assert.equal(game.state.eventIndex, 0);
  const before = game.state.cash;
  accepted(game.coolDown());
  assert.equal(game.state.cash, before - 75);
  assert.equal(game.state.authority, 1);
});

test('las doce misiones tienen progreso secuencial y se puede alcanzar el final sin trucos de dinero', () => {
  const game = fresh();
  walkToNPC(game, 'monfe');
  accepted(game.trade('monfe', 'bruma', 5, true));
  walkToNPC(game, 'lola');
  accepted(game.trade('lola', 'bruma', 5, false));
  walkToNPC(game, 'scot');
  walkToNPC(game, 'monfe');
  accepted(game.trade('monfe', 'bruma', 7, true));
  walkToNPC(game, 'lola');
  accepted(game.trade('lola', 'bruma', 7, false));
  walkToNPC(game, 'garcia');
  assert.equal(game.state.mission, 5);
  walkToNPC(game, 'toni');
  accepted(game.purchaseProperty('kiosco'));
  walkToNPC(game, 'navarro');
  walkToNPC(game, 'peralta');
  // La entrada caminando al Puerto completa la misión después de Peralta.
  walkToNPC(game, 'soto');
  accepted(game.upgrade('seguridad'));
  walkToNPC(game, 'cristian');
  accepted(game.upgrade('finanzas'));
  assert.equal(game.state.mission, 10);
  accepted(game.purchaseProperty('almacen'));
  game.rest();
  while (game.state.cash < properties.find(p => p.id === 'muelle').cost) advance(game, 30);
  accepted(game.purchaseProperty('muelle'));
  assert.equal(game.state.mission, 11);
  assert.equal(game.state.won, false);
  for (let cycles = 0; cycles < 100 && !game.state.won; cycles++) advance(game, 30);
  assert.equal(game.state.mission, 12);
  assert.equal(game.state.won, true);
  assert.ok(game.wealth() >= 15000);
  assert.ok(game.state.properties.length >= 3);
  const money = game.state.cash;
  game.checkMissions();
  assert.equal(game.state.cash, money, 'las recompensas solo se abonan una vez');
  assert.equal(fresh().load(game.serialize()), true);
});

test('guardar y cargar preserva estado y rechaza datos incompletos, corruptos o no finitos', () => {
  const game = fresh();
  game.meet('monfe');
  accepted(game.trade('monfe', 'bruma', 5, true));
  const clone = fresh();
  assert.equal(clone.load(game.serialize()), true);
  assert.deepEqual(clone.state, game.state);
  assert.equal(clone.load('no es JSON'), false);
  assert.equal(clone.load('null'), false);
  for (const [key, value] of [
    ['version', 999], ['cash', -1], ['cash', NaN], ['heat', Infinity], ['rep', 101],
    ['capacity', 19], ['mission', 13], ['mission', 2.5], ['x', -100], ['y', 5000],
    ['day', 0], ['inventory', { bruma: -1, sol: 0, eco: 0 }],
    ['inventory', { bruma: 21, sol: 0, eco: 0 }], ['budgets', {}], ['demand', {}],
    ['properties', ['no-existe']], ['properties', ['kiosco', 'kiosco']],
    ['upgrades', ['no-existe']], ['met', 'monfe']
  ]) {
    const invalid = JSON.parse(game.serialize());
    invalid[key] = value;
    const before = clone.serialize();
    assert.equal(clone.load(JSON.stringify(invalid)), false, `${key}=${value}`);
    assert.equal(clone.serialize(), before, 'un guardado inválido no sustituye el actual');
  }
});

test('guardados rechazan contadores negativos, flags inválidos y enteros fraccionarios', () => {
  const game = fresh();
  for (const [key, value] of [
    ['investment', -1], ['totalBought', -1], ['totalSold', -1], ['fines', -1],
    ['revenue', -1], ['spent', -1], ['arrested', -1], ['deals', -1],
    ['incomeClock', -1], ['clock', -1], ['day', 1.5], ['capacity', 20.5],
    ['eventIndex', 999], ['won', 'sí'], ['met', ['intruso']], ['visited', ['luna']]
  ]) {
    const invalid = JSON.parse(game.serialize());
    invalid[key] = value;
    assert.equal(fresh().load(JSON.stringify(invalid)), false, `${key}=${value}`);
  }
});
