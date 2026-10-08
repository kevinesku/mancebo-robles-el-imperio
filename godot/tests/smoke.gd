extends SceneTree
## Run: godot --headless --path godot --script res://tests/smoke.gd

const State = preload("res://scripts/state.gd")
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error("FAIL: " + message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = State.new()
	check(state.cash == 500 and state.capacity == 20, "initial economy")
	check(State.NPCS.size() == 10 and State.MISSIONS.size() == 12, "ten NPCs / twelve missions")
	check(state.price(2, 2, true) < state.price(2, 4, false), "profitable regional route")
	check(not state.unlocked(4), "luxury initially locked")
	var initial_cash: int = state.cash
	var rejected: String = state.trade("lola", 0, 1, true)
	check(rejected.contains("proveedor") and state.cash == initial_cash and state.used_capacity() == 0 and state.stock.lola[0] == 100, "customer cannot supply products and failure is atomic")
	state.inventory[0] = 2
	rejected = state.trade("monfe", 0, 1, false)
	check(rejected.contains("cliente") and state.cash == initial_cash and state.inventory[0] == 2 and state.npc_budgets.monfe == 1800, "supplier cannot buy products and failure is atomic")
	state.inventory[0] = 0
	rejected = state.trade("scot", 0, 1, true)
	check(rejected.contains("proveedor") and state.cash == initial_cash, "non-trader cannot supply products")
	state.trade("monfe", 2, 20, true)
	check(state.cash == initial_cash and state.used_capacity() == 0, "insufficient funds are atomic")
	state.meet("monfe")
	state.progress()
	check(state.mission == 1, "contact mission")
	state.trade("monfe", 0, 5, true)
	state.progress()
	check(state.mission == 2 and state.inventory[0] == 5, "purchase mission")
	state.meet("lola")
	state.trade("lola", 0, 5, false)
	state.progress()
	check(state.mission == 3 and state.inventory[0] == 0, "first client mission")
	state.meet("scot")
	state.progress()
	state.meet("xoxi")
	state.progress()
	check(state.mission == 5 and state.unlocked(2), "supply zone unlocked without deadlock")
	state.meet("peralta")
	state.trade("peralta", 1, 5, true)
	state.progress()
	state.meet("garcia")
	state.trade("garcia", 1, 5, false)
	state.progress()
	check(state.mission == 7, "supply and rival missions")
	state.meet("toni")
	state.buy_property(0)
	state.progress()
	check(state.mission == 8 and state.properties.size() == 1, "first property attainable")
	state.meet("navarro")
	state.progress()
	state.meet("soto")
	state.upgrade("security")
	state.progress()
	state.meet("cristian")
	state.upgrade("invest")
	state.progress()
	check(state.mission == 11, "VIP, security and finance missions")
	check(state.met.size() == 10, "all required NPCs participate")
	var old_cash: int = state.cash
	state.update(40)
	check(state.cash == old_cash + (90 + 120) * 2, "passive income for each elapsed cycle")
	state.update(50)
	check(state.day == 2, "economy event and market reset")
	check(state.npc_budgets.lola == 1800, "customer budget regenerates")
	# Simulate a repeatable profitable route with the real economy and customer budgets.
	for _cycle in range(14):
		state.trade("peralta", 2, 10, true)
		state.trade("navarro", 2, 10, false)
		state.update(90)
		if state.cash >= 10500:
			break
	check(state.cash >= 10500, "profitable trade reaches expansion capital")
	state.buy_property(1)
	state.buy_property(2)
	state.update(90)
	state.progress()
	check(state.properties.size() == 3 and state.net_worth() >= 15000, "three properties and target fortune attainable")
	check(state.won and state.mission == 12, "narrative victory")
	state.heat = 80
	state.inventory = [8, 8, 8]
	old_cash = state.cash
	state.arrested()
	check(state.cash < old_cash and state.inventory[0] == 6 and state.heat == 18, "police consequences")
	check(state.save_game(), "save writes")
	var loaded = State.new()
	check(loaded.load_game(), "save loads")
	check(loaded.cash == state.cash and loaded.properties.size() == 3 and loaded.mission == 12, "save roundtrip")
	corrupt_save_checks()
	emergency_help_checks()
	state.save_game()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game.menu != null and not game.playing, "main menu boot")
	game.new_game()
	await process_frame
	check(game.playing and game.modal != null, "new game introduction")
	game.close_modal()
	game.show_interaction("monfe")
	await process_frame
	check(game.current_contact == "monfe" and game.state.mission == 1, "interaction and UI mission")
	var purchase_buttons: Array[Button] = []
	find_buttons(game.modal, "Comprar", purchase_buttons)
	check(purchase_buttons.size() == 3, "three product purchase buttons")
	purchase_buttons[0].pressed.emit()
	await process_frame
	check(game.state.inventory[0] == 3 and game.state.mission == 2, "actual UI buy button applies the correct product")
	game.show_interaction("lola")
	await process_frame
	var sale_buttons: Array[Button] = []
	find_buttons(game.modal, "Vender", sale_buttons)
	sale_buttons[0].pressed.emit()
	await process_frame
	check(game.state.inventory[0] == 0 and game.state.mission == 3, "actual UI sale button advances the first client")
	for contact in State.NPCS:
		game.show_interaction(contact.id)
		await process_frame
	check(game.current_contact == "lola", "all ten dialog panels render")
	game.show_inventory()
	await process_frame
	game.show_map()
	await process_frame
	game.show_missions()
	await process_frame
	game.show_settings()
	await process_frame
	game.show_home()
	await process_frame
	game.show_pause()
	await process_frame
	game.show_victory()
	await process_frame
	check(game.current_contact == "victory", "final panel renders")
	print("GODOT SMOKE PASS: %d checks (economy, progression, police, saves, ten dialogs, all screens)." % checks)
	purchase_buttons.clear()
	sale_buttons.clear()
	game.sound.stop()
	game.sound.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.05).timeout
	quit(0)

func find_buttons(node: Node, text: String, result: Array[Button]) -> void:
	if node is Button and node.text == text:
		result.append(node)
	for child in node.get_children():
		find_buttons(child, text, result)

func corrupt_save_checks() -> void:
	var victim = State.new()
	victim.cash = 777
	victim.reputation = 2
	victim.inventory = [1, 2, 3]
	victim.player = Vector2(340, 1040)
	check(victim.save_game(), "valid baseline saved for corruption tests")
	var baseline_text := FileAccess.get_file_as_string(State.SAVE_PATH)
	var baseline: Dictionary = JSON.parse_string(baseline_text)
	var cases := [
		{"field": "player", "value": []},
		{"field": "player", "value": ["bad", 1040]},
		{"field": "player", "value": [2500, 1040]},
		{"field": "properties", "value": [999]},
		{"field": "properties", "value": [0, 0]},
		{"field": "inventory", "value": [-1, 0, 0]},
		{"field": "inventory", "value": [1, 2]},
		{"field": "inventory", "value": [20, 20, 20]},
		{"field": "cash", "value": "500"},
		{"field": "cash", "value": -1},
		{"field": "cash", "value": 2.5},
		{"field": "mission", "value": 99},
		{"field": "heat", "value": 101},
		{"field": "clock", "value": -1},
		{"field": "authorities", "value": 101},
		{"field": "day", "value": 0},
		{"field": "investments", "value": 6},
		{"field": "upgrades", "value": {"tech": false, "security": false, "capacity": 99}},
		{"field": "upgrades", "value": {"tech": "false", "security": false, "capacity": 0}},
		{"field": "capacity", "value": 70},
		{"field": "npc_budgets", "value": {}},
		{"field": "stock", "value": {"monfe": []}},
		{"field": "demand", "value": [1.0]},
		{"field": "demand", "value": [1.0, "bad", 1.0]},
		{"field": "settings", "value": {}},
		{"field": "won", "value": "yes"},
		{"field": "won", "value": true},
		{"field": "version", "value": 99},
		{"field": "met", "value": ["monfe", "monfe"]},
		{"field": "met", "value": ["unknown"]}
	]
	for item in cases:
		var corrupted: Dictionary = baseline.duplicate(true)
		corrupted[item.field] = item.value
		write_json_save(corrupted)
		check(not victim.load_game(), "reject corrupt field " + item.field)
		victim.save_game()
		check(FileAccess.get_file_as_string(State.SAVE_PATH) == baseline_text, "invalid save never partly applies " + item.field)
	var missing: Dictionary = baseline.duplicate(true)
	missing.erase("player")
	write_json_save(missing)
	check(not victim.load_game(), "missing required core key rejected")
	write_json_save([1, 2, 3])
	check(not victim.load_game(), "wrong root container rejected")
	var broken_stock: Dictionary = baseline.duplicate(true)
	broken_stock.stock.monfe = [100, 70]
	write_json_save(broken_stock)
	check(not victim.load_game(), "nested stock shape rejected")
	var broken_budget: Dictionary = baseline.duplicate(true)
	broken_budget.npc_budgets.monfe = -5
	write_json_save(broken_budget)
	check(not victim.load_game(), "nested negative budget rejected")
	victim.save_game()
	check(FileAccess.get_file_as_string(State.SAVE_PATH) == baseline_text, "all corruption cases preserve complete live state")

func write_json_save(data: Variant) -> void:
	var file := FileAccess.open(State.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func emergency_help_checks() -> void:
	var stranded = State.new()
	stranded.cash = 0
	var news: Array = stranded.update(90)
	check(stranded.cash == 150 and str(news).contains("Monfe"), "zero-capital rescue provides cash and notification next day")
	var low_cash = State.new()
	low_cash.cash = 50
	low_cash.update(90)
	check(low_cash.cash == 200, "rescue supplements low cash below threshold")
	var solvent = State.new()
	solvent.cash = 100
	solvent.update(90)
	check(solvent.cash == 100, "no rescue when cash reaches threshold")
	var stocked = State.new()
	stocked.cash = 0
	stocked.inventory = [1, 0, 0]
	stocked.update(90)
	check(stocked.cash == 0, "no rescue while inventory can generate capital")
	var owner = State.new()
	owner.cash = 0
	owner.properties = [0]
	owner.update(90)
	check(owner.cash == 360 and owner.passive_income == 360, "property owner only receives genuine business income")
	var investor = State.new()
	investor.cash = 0
	investor.investments = 1
	investor.update(90)
	check(investor.cash == 480 and investor.passive_income == 480, "investor only receives genuine investment income")
	var arrested_player = State.new()
	arrested_player.cash = 0
	check(arrested_player.arrested().contains("Monfe te ayudará"), "inspection explains the recovery path")
