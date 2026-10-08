class_name EmpireState
extends RefCounted
## Estado y reglas independientes de la interfaz. Todas las mercancías son ficticias.

const SAVE_PATH := "user://imperio_save_v1.json"
const PRODUCTS := [
	{"id": "bruma", "name": "Bruma azul", "base": 24, "color": "b6a0ff"},
	{"id": "sol", "name": "Sol fantasma", "base": 58, "color": "ffd47c"},
	{"id": "eco", "name": "Eco de cristal", "base": 110, "color": "75d9e9"}
]
const DISTRICTS := [
	{"name": "CENTRO", "rep": 0, "buy": 1.0, "sell": 1.45, "color": "a0b2cc"},
	{"name": "RESIDENCIAL", "rep": 4, "buy": 1.16, "sell": 1.8, "color": "81bca0"},
	{"name": "POLÍGONO", "rep": 8, "buy": 0.63, "sell": 0.98, "color": "cf9972"},
	{"name": "EL BARRIO", "rep": 0, "buy": 0.76, "sell": 1.1, "color": "c38ecf"},
	{"name": "LA CORONA · LUJO", "rep": 18, "buy": 1.4, "sell": 2.6, "color": "e5ce89"},
	{"name": "PUERTO", "rep": 10, "buy": 0.8, "sell": 2.0, "color": "79c4d7"}
]
const NPCS := [
	{"id": "monfe", "name": "Monfe", "role": "Socio · mercado del Barrio", "pos": [370, 1030], "color": "eea969", "line": "Tienes 500 euros y cara de lunes. Vamos a convertir ambas cosas en un negocio. Compra Bruma aquí y véndela a Lola en el Centro. Y no confundas beneficio con facturación, que te conozco."},
	{"id": "scot", "name": "Scot", "role": "Tecnología e información", "pos": [1190, 445], "color": "80d8ca", "line": "Mi algoritmo predice el mercado, el tráfico y cuándo Monfe va a pedirte dinero. Lo último acierta siempre. Con mi terminal verás precios antes de cruzar media ciudad."},
	{"id": "garcia", "name": "García", "role": "Rival · comprador del Puerto", "pos": [1940, 1000], "color": "df879d", "line": "Aquí nadie me regatea... salvo tú, por lo visto. Trae producto y hablamos. Navarro presume de cadena de oro; yo presumo de margen neto. Cada uno tiene sus problemas."},
	{"id": "toni", "name": "Toni Escrig", "role": "Propiedades y negocios", "pos": [550, 410], "color": "e6c579", "line": "Local, almacén o club: ladrillo del bueno. Generan ingresos cada veinte segundos. La humedad mediterránea va incluida; eso es lo que yo llamo servicio integral."},
	{"id": "navarro", "name": "Navarro · 50 Cent el Europeo", "role": "Leyenda del barrio · cliente VIP", "pos": [1030, 1090], "color": "e7ba64", "line": "Soy 50 Cent el Europeo. Con la inflación, 65 céntimos. Si quieres un imperio, trae estilo, reputación y Eco de cristal. El chándal no cotiza, pero debería."},
	{"id": "peralta", "name": "Alejandro Peralta", "role": "Suministros y logística", "pos": [2050, 400], "color": "a6bdd9", "line": "Mis cajas llegan antes que mis excusas. El Polígono vende barato; el Puerto compra caro. Si Scot te vende un dron, exige la batería: una vez me mandó un ventilador."},
	{"id": "xoxi", "name": "Xoxi", "role": "Rumores y contactos", "pos": [665, 1020], "color": "9de091", "line": "Yo no cotilleo: distribuyo inteligencia sin factura. Consejo gratis: con cuarenta de sospecha, las patrullas empiezan a mirar tu mochila. Baja el ritmo y busca un callejón."},
	{"id": "soto", "name": "Soto", "role": "Seguridad y protección", "pos": [2160, 1160], "color": "86a3db", "line": "No hay problema que una buena planificación no evite. Te reduzco el riesgo y la multa. Mi currículum dice gestión de conflictos; Monfe dice portero con Excel."},
	{"id": "cristian", "name": "Cristian Martín", "role": "Finanzas e inversiones", "pos": [1300, 1040], "color": "c2a8e3", "line": "No guardes todo bajo el colchón: el somier cobra intereses. Cada inversión de 1.000 euros devuelve 120 por ciclo. Diversifica, que esto es un imperio, no una peña de la lotería."},
	{"id": "lola", "name": "Lola", "role": "Primera clienta · mercado del Centro", "pos": [370, 400], "color": "e18eb5", "line": "Mancebo, dame tres Brumas azules y dime el precio sin hacerte el interesante. Mi presupuesto no es infinito; vuelve mañana si me vacías la cartera."}
]
const PROPERTIES := [
	{"name": "Local del Barrio", "cost": 1500, "income": 90, "district": 3},
	{"name": "Almacén del Puerto", "cost": 3500, "income": 210, "district": 5},
	{"name": "Club La Corona", "cost": 7000, "income": 420, "district": 4}
]
const MISSIONS := [
	{"title": "01 · El lunes de Monfe", "goal": "Habla con Monfe, tu socio inicial.", "reward": 100, "rep": 3},
	{"title": "02 · Stock de bolsillo", "goal": "Compra al menos 3 unidades de Bruma azul.", "reward": 150, "rep": 3},
	{"title": "03 · La primera clienta", "goal": "Vende 3 unidades a Lola en el Centro.", "reward": 250, "rep": 4},
	{"title": "04 · Tecnología de andar por casa", "goal": "Visita a Scot en el Residencial.", "reward": 250, "rep": 4},
	{"title": "05 · Inteligencia sin factura", "goal": "Habla con Xoxi y escucha su rumor.", "reward": 250, "rep": 4},
	{"title": "06 · Logística mediterránea", "goal": "Compra 5 unidades a Alejandro Peralta.", "reward": 500, "rep": 5},
	{"title": "07 · Un rival con calculadora", "goal": "Vende 5 unidades a García en el Puerto.", "reward": 750, "rep": 5},
	{"title": "08 · El primer ladrillo", "goal": "Compra una propiedad a Toni Escrig.", "reward": 500, "rep": 4},
	{"title": "09 · 50 Cent, precio europeo", "goal": "Conoce a Navarro en el barrio de lujo.", "reward": 1000, "rep": 6},
	{"title": "10 · Portero con Excel", "goal": "Contrata a Soto para reducir el riesgo.", "reward": 600, "rep": 5},
	{"title": "11 · El colchón no cotiza", "goal": "Haz una inversión con Cristian Martín.", "reward": 1000, "rep": 6},
	{"title": "12 · Mancebo Robles: el imperio", "goal": "Consigue 3 propiedades y un patrimonio de 15.000 €.", "reward": 0, "rep": 15}
]

var cash := 500
var reputation := 0
var heat := 0.0
var authorities := 50
var capacity := 20
var inventory := [0, 0, 0]
var properties: Array = []
var upgrades := {"tech": false, "security": false, "capacity": 0}
var investments := 0
var mission := 0
var met: Array = []
var bought_bruma := 0
var sold_lola := 0
var bought_peralta := 0
var sold_garcia := 0
var total_bought := 0
var total_sold := 0
var revenues := 0
var expenses := 0
var arrests := 0
var passive_income := 0
var clock := 0.0
var day := 1
var player := Vector2(320, 1040)
var npc_budgets := {}
var stock := {}
var demand := [1.0, 1.0, 1.0]
var market_event := "La ciudad despierta: el Centro busca Bruma azul."
var event_index := 0
var won := false
var settings := {"sound": true, "fullscreen": false}

func _init() -> void:
	reset_markets()

func reset_markets() -> void:
	for npc in NPCS:
		npc_budgets[npc.id] = 3500 if npc.id == "navarro" else 1800
		stock[npc.id] = [100, 70, 50]

func district_at(pos: Vector2) -> int:
	return clampi(int(pos.x / 800), 0, 2) + 3 * clampi(int(pos.y / 720), 0, 1)

func unlocked(district: int) -> bool:
	return reputation >= int(DISTRICTS[district].rep)

func used_capacity() -> int:
	return int(inventory[0]) + int(inventory[1]) + int(inventory[2])

func net_worth() -> int:
	var result := cash + investments * 1000
	for prop in properties:
		result += int(PROPERTIES[int(prop)].cost)
	for i in range(3):
		result += int(inventory[i]) * int(PRODUCTS[i].base)
	return result

func price(product: int, district: int, buying: bool) -> int:
	var multiplier: float = float(DISTRICTS[district].buy if buying else DISTRICTS[district].sell)
	var variation := 1.0 + sin(float(day * 11 + district * 7 + product * 3)) * 0.10
	return maxi(1, int(round(float(PRODUCTS[product].base) * multiplier * variation * float(demand[product]))))

func npc_by_id(id: String) -> Dictionary:
	for npc in NPCS:
		if npc.id == id:
			return npc
	return {}

func meet(id: String) -> void:
	if not met.has(id):
		met.append(id)

func trade(id: String, product: int, amount: int, buying: bool) -> String:
	if amount <= 0 or product < 0 or product > 2:
		return "Cantidad incorrecta."
	# Roles are enforced here, independently of the interface buttons.
	if buying and id not in ["monfe", "peralta"]:
		return "Este contacto no es proveedor. Compra a Monfe o Alejandro Peralta."
	if not buying and id not in ["lola", "garcia", "navarro"]:
		return "Este contacto no es cliente. Vende a Lola, García o Navarro."
	var npc := npc_by_id(id)
	if npc.is_empty():
		return "Ese contacto no está disponible."
	var district := district_at(Vector2(npc.pos[0], npc.pos[1]))
	if not unlocked(district):
		return "Necesitas %d de reputación para comerciar aquí." % DISTRICTS[district].rep
	var unit := price(product, district, buying)
	var total := unit * amount
	if buying:
		if used_capacity() + amount > capacity:
			return "Tu mochila no da para más. Amplíala con Monfe."
		if cash < total:
			return "Te faltan %d € para esta compra." % (total - cash)
		if int(stock[id][product]) < amount:
			return "No queda suficiente stock. Se repone al cambiar de día."
		cash -= total
		inventory[product] += amount
		stock[id][product] -= amount
		expenses += total
		total_bought += amount
		if product == 0:
			bought_bruma += amount
		if id == "peralta":
			bought_peralta += amount
	else:
		if int(inventory[product]) < amount:
			return "No tienes tantas unidades."
		if int(npc_budgets[id]) < total:
			return "%s se ha quedado sin presupuesto. Vuelve el próximo día." % npc.name
		cash += total
		inventory[product] -= amount
		npc_budgets[id] -= total
		revenues += total
		total_sold += amount
		heat = clampf(heat + float(amount) * (0.85 if upgrades.security else 1.5), 0.0, 100.0)
		if id == "lola":
			sold_lola += amount
		if id == "garcia":
			sold_garcia += amount
	return "%s %d × %s · %d €" % ["Compraste" if buying else "Vendiste", amount, PRODUCTS[product].name, total]

func buy_property(index: int) -> String:
	if properties.has(index):
		return "Esta propiedad ya es tuya."
	var prop: Dictionary = PROPERTIES[index]
	if not unlocked(int(prop.district)):
		return "Necesitas %d de reputación para abrir aquí." % DISTRICTS[prop.district].rep
	if cash < int(prop.cost):
		return "Te faltan %d € para %s." % [int(prop.cost) - cash, prop.name]
	cash -= int(prop.cost)
	expenses += int(prop.cost)
	properties.append(index)
	return "Compraste %s. Generará %d € cada 20 segundos." % [prop.name, prop.income]

func upgrade(kind: String) -> String:
	var cost := 0
	match kind:
		"capacity":
			if int(upgrades.capacity) >= 2:
				return "Ya tienes la mochila más grande de la ciudad."
			cost = 500 if int(upgrades.capacity) == 0 else 1500
		"tech":
			if upgrades.tech:
				return "El terminal de Scot ya está instalado."
			cost = 750
		"security":
			if upgrades.security:
				return "Soto ya cuida de tu negocio."
			cost = 1000
		"invest":
			if investments >= 5:
				return "La cartera está completa: cinco inversiones."
			cost = 1000
		_:
			return "Mejora desconocida."
	if cash < cost:
		return "Te faltan %d € para esta mejora." % (cost - cash)
	cash -= cost
	expenses += cost
	match kind:
		"capacity":
			upgrades.capacity += 1
			capacity = 40 if int(upgrades.capacity) == 1 else 70
		"invest": investments += 1
		_: upgrades[kind] = true
	return "Mejora adquirida · %d €" % cost

func progress() -> Array:
	var completed := []
	while mission < MISSIONS.size():
		var done := false
		match mission:
			0: done = met.has("monfe")
			1: done = bought_bruma >= 3
			2: done = sold_lola >= 3
			3: done = met.has("scot")
			4: done = met.has("xoxi")
			5: done = bought_peralta >= 5
			6: done = sold_garcia >= 5
			7: done = properties.size() >= 1
			8: done = met.has("navarro")
			9: done = bool(upgrades.security)
			10: done = investments > 0
			11: done = properties.size() >= 3 and net_worth() >= 15000
		if not done:
			break
		var quest: Dictionary = MISSIONS[mission]
		cash += int(quest.reward)
		reputation += int(quest.rep)
		completed.append("MISIÓN COMPLETA · %s\n+%d € · +%d reputación" % [quest.title, quest.reward, quest.rep])
		mission += 1
	if mission == MISSIONS.size():
		won = true
	return completed

func update(delta: float) -> Array:
	var news := []
	var old_income_cycle := int(clock / 20.0)
	var old_day := int(clock / 90.0)
	clock += delta
	heat = maxf(0.0, heat - delta * (0.62 if upgrades.security else 0.40))
	if int(clock / 20.0) > old_income_cycle:
		var income := investments * 120
		for prop in properties:
			income += int(PROPERTIES[int(prop)].income)
		income *= int(clock / 20.0) - old_income_cycle
		if income > 0:
			cash += income
			passive_income += income
			news.append("Tus negocios han ingresado %d €." % income)
	if int(clock / 90.0) > old_day:
		day += 1
		reset_markets()
		# A bad series of inspections must never strand a penniless player.
		if cash < 100 and used_capacity() == 0 and properties.is_empty() and investments == 0:
			cash += 150
			news.append("Monfe te envía 150 € de ayuda: «El imperio no cierra por un lunes malo». Compra Bruma y vuelve al mercado.")
		event_index = (event_index + randi_range(1, 3)) % 4
		match event_index:
			0:
				demand = [1.0, 1.0, 1.0]
				market_event = "Día tranquilo: los mercados recuperan su precio normal."
			1:
				demand = [1.32, 1.0, 0.86]
				market_event = "Festival en el Centro: sube la Bruma azul, baja Eco de cristal."
			2:
				demand = [0.86, 1.36, 1.0]
				market_event = "Ola de calor: Sol fantasma se dispara un 36%."
			3:
				demand = [1.0, 0.9, 1.3]
				market_event = "Fiesta en La Corona: Eco de cristal sube un 30%."
		news.append("DÍA %d · %s Presupuestos y stock repuestos." % [day, market_event])
	return news

func arrested() -> String:
	var fine := maxi(60, int(cash * (0.08 if upgrades.security else 0.16)))
	fine = mini(fine, cash)
	cash -= fine
	expenses += fine
	arrests += 1
	authorities = maxi(0, authorities - 8)
	for i in range(3):
		inventory[i] = maxi(0, int(inventory[i]) - int(ceil(float(inventory[i]) * 0.25)))
	heat = 18.0
	player = Vector2(320, 1040)
	var message := "INSPECCIÓN · Multa de %d € y 25%% del stock incautado. Soto reduce las multas. Respira y vuelve a empezar." % fine
	if cash < 100 and used_capacity() == 0 and properties.is_empty() and investments == 0:
		message += " Monfe te ayudará con 150 € al próximo día."
	return message

func save_game() -> bool:
	var data := {
		"version": 1, "cash": cash, "reputation": reputation, "heat": heat,
		"authorities": authorities, "capacity": capacity, "inventory": inventory,
		"properties": properties, "upgrades": upgrades, "investments": investments,
		"mission": mission, "met": met, "bought_bruma": bought_bruma,
		"sold_lola": sold_lola, "bought_peralta": bought_peralta, "sold_garcia": sold_garcia,
		"total_bought": total_bought, "total_sold": total_sold, "revenues": revenues,
		"expenses": expenses, "arrests": arrests, "passive_income": passive_income,
		"clock": clock, "day": day, "player": [player.x, player.y],
		"npc_budgets": npc_budgets, "stock": stock, "demand": demand,
		"market_event": market_event, "event_index": event_index, "won": won, "settings": settings
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() > 1048576:
		return false
	var data = JSON.parse_string(file.get_as_text())
	# Validate the entire schema before changing a single live-state value.
	if not valid_save(data):
		return false
	for key in ["cash", "reputation", "heat", "authorities", "capacity", "inventory", "properties", "upgrades", "investments", "mission", "met", "bought_bruma", "sold_lola", "bought_peralta", "sold_garcia", "total_bought", "total_sold", "revenues", "expenses", "arrests", "passive_income", "clock", "day", "npc_budgets", "stock", "demand", "market_event", "event_index", "won", "settings"]:
		if data.has(key):
			set(key, data[key])
	var saved_pos: Array = data.get("player", [320, 1040])
	player = Vector2(float(saved_pos[0]), float(saved_pos[1]))
	return true

func valid_number(value: Variant, minimum: float, maximum: float, integer := false) -> bool:
	if not (value is int or value is float):
		return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum and (not integer or floor(number) == number)

func valid_save(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var required := ["version", "cash", "reputation", "heat", "authorities", "capacity", "inventory", "properties", "upgrades", "investments", "mission", "met", "bought_bruma", "sold_lola", "bought_peralta", "sold_garcia", "total_bought", "total_sold", "revenues", "expenses", "arrests", "passive_income", "clock", "day", "player", "npc_budgets", "stock", "demand", "market_event", "event_index", "won", "settings"]
	for key in required:
		if not data.has(key):
			return false
	if not valid_number(data.version, 1, 1, true):
		return false
	for key in ["cash", "reputation", "bought_bruma", "sold_lola", "bought_peralta", "sold_garcia", "total_bought", "total_sold", "revenues", "expenses", "arrests", "passive_income"]:
		if not valid_number(data[key], 0, 2000000000, true):
			return false
	if not valid_number(data.heat, 0, 100) or not valid_number(data.authorities, 0, 100, true):
		return false
	if not valid_number(data.investments, 0, 5, true) or not valid_number(data.mission, 0, MISSIONS.size(), true):
		return false
	if not valid_number(data.clock, 0, 360000000) or not valid_number(data.day, 1, 4000001, true):
		return false
	if not valid_number(data.event_index, 0, 3, true):
		return false
	if not data.won is bool or data.won != (int(data.mission) == MISSIONS.size()):
		return false
	if not data.market_event is String or data.market_event.length() > 512:
		return false
	if not data.upgrades is Dictionary or not data.settings is Dictionary:
		return false
	for key in ["tech", "security", "capacity"]:
		if not data.upgrades.has(key):
			return false
	if not data.upgrades.tech is bool or not data.upgrades.security is bool or not valid_number(data.upgrades.capacity, 0, 2, true):
		return false
	var capacities := [20, 40, 70]
	if not valid_number(data.capacity, 20, 70, true) or int(data.capacity) != capacities[int(data.upgrades.capacity)]:
		return false
	for key in ["sound", "fullscreen"]:
		if not data.settings.has(key) or not data.settings[key] is bool:
			return false
	if not data.inventory is Array or data.inventory.size() != PRODUCTS.size():
		return false
	var used := 0
	for quantity in data.inventory:
		if not valid_number(quantity, 0, int(data.capacity), true):
			return false
		used += int(quantity)
	if used > int(data.capacity):
		return false
	if not data.player is Array or data.player.size() != 2 or not valid_number(data.player[0], 0, 2400) or not valid_number(data.player[1], 0, 1440):
		return false
	if not data.properties is Array or data.properties.size() > PROPERTIES.size():
		return false
	var seen_properties := {}
	for index in data.properties:
		if not valid_number(index, 0, PROPERTIES.size() - 1, true) or seen_properties.has(int(index)):
			return false
		seen_properties[int(index)] = true
	if not data.met is Array or data.met.size() > NPCS.size():
		return false
	var seen_contacts := {}
	for id in data.met:
		if not id is String or npc_by_id(id).is_empty() or seen_contacts.has(id):
			return false
		seen_contacts[id] = true
	if not data.npc_budgets is Dictionary or not data.stock is Dictionary or data.npc_budgets.size() != NPCS.size() or data.stock.size() != NPCS.size():
		return false
	for npc in NPCS:
		if not data.npc_budgets.has(npc.id) or not valid_number(data.npc_budgets[npc.id], 0, 3500, true):
			return false
		if not data.stock.has(npc.id) or not data.stock[npc.id] is Array or data.stock[npc.id].size() != PRODUCTS.size():
			return false
		for quantity in data.stock[npc.id]:
			if not valid_number(quantity, 0, 100, true):
				return false
	if not data.demand is Array or data.demand.size() != PRODUCTS.size():
		return false
	for multiplier in data.demand:
		if not valid_number(multiplier, 0.5, 2.0):
			return false
	return true
