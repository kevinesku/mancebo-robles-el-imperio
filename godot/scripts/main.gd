extends Node2D
## Escena, interfaz y controles. La economía reside en state.gd y la ciudad en city.gd.

const StateScript = preload("res://scripts/state.gd")
const CityScript = preload("res://scripts/city.gd")
const GOLD := Color("edcd85")
const MUTED := Color("9aaec9")
const INK := Color("101b2c")
const WHITE := Color("edf1f6")

var state: EmpireState
var city: EmpireCity
var camera: Camera2D
var overlay: Control
var hud: Control
var modal: Control
var menu: Control
var stats_label: Label
var mission_label: Label
var area_label: Label
var hint_label: Label
var heat_bar: ProgressBar
var map_control: Control
var toast_box: VBoxContainer
var playing := false
var trade_amount := 3
var autosave_clock := 0.0
var hud_clock := 0.0
var current_contact := ""
var sound: AudioStreamPlayer

func _ready() -> void:
	get_window().title = "Mancebo Robles: El Imperio"
	state = StateScript.new()
	city = CityScript.new()
	city.state = state
	city.notice.connect(notify)
	add_child(city)
	camera = Camera2D.new()
	camera.position = state.player
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9
	camera.zoom = Vector2(1.05, 1.05)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 2400
	camera.limit_bottom = 1440
	add_child(camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.theme = make_theme()
	sound = AudioStreamPlayer.new()
	add_child(sound)
	build_hud()
	show_main_menu()
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if playing:
			state.save_game()
		get_tree().quit()

func _exit_tree() -> void:
	if is_instance_valid(sound):
		sound.stop()
		sound.stream = null

func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 16
	result.set_color("font_color", "Label", WHITE)
	result.set_color("font_color", "Button", WHITE)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_disabled_color", "Button", Color("566982"))
	for kind in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("22334d") if kind == "hover" else Color("18273c")
		if kind == "pressed":
			style.bg_color = Color("38435a")
		style.border_color = GOLD if kind == "focus" else Color("38516a")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		result.set_stylebox(kind, "Button", style)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.09, 0.15, 0.97)
	panel_style.border_color = Color("3a4c66")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(10)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	result.set_stylebox("panel", "PanelContainer", panel_style)
	return result

func label(text: String, font_size := 16, color := WHITE) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node

func button(text: String, action: Callable, disabled := false) -> Button:
	var node := Button.new()
	node.text = text
	node.disabled = disabled
	node.pressed.connect(action)
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node

func panel_at(parent: Control, rect: Rect2) -> PanelContainer:
	var node := PanelContainer.new()
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node

func column(parent: Node, spacing := 12) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", spacing)
	parent.add_child(node)
	return node

func clear_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null

func close_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	current_contact = ""
	city.active = playing and not is_instance_valid(menu)
	refresh_hud()

func modal_column(title: String, subtitle: String = "") -> VBoxContainer:
	close_modal()
	city.active = false
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.045, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel := panel_at(modal, Rect2(260, 68, 760, 665))
	var outer := column(panel, 12)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var heading := label(title, 27, GOLD)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header.add_child(button("Cerrar  [Esc]", close_modal))
	if subtitle != "":
		outer.add_child(label(subtitle, 14, MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var body := column(scroll, 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body

func show_main_menu() -> void:
	close_modal()
	clear_menu()
	playing = false
	city.active = false
	hud.hide()
	camera.position = Vector2(450, 1030)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.035, 0.07, 0.77)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var panel := panel_at(menu, Rect2(150, 102, 980, 590))
	var content := column(panel, 18)
	content.add_child(label("UNA CIUDAD. 500 EUROS. MUCHAS MALAS IDEAS.", 15, MUTED))
	content.add_child(label("MANCEBO ROBLES", 55, WHITE))
	content.add_child(label("EL IMPERIO", 43, GOLD))
	content.add_child(label("La noche mediterránea no espera a nadie. Comercia con mercancías ficticias, esquiva las patrullas y convierte un piso pequeño en un imperio.", 20))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	content.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	content.add_child(row)
	row.add_child(button("NUEVA PARTIDA", new_game))
	row.add_child(button("CONTINUAR", continue_game, not FileAccess.file_exists(EmpireState.SAVE_PATH)))
	row.add_child(button("AJUSTES", show_settings))
	row.add_child(button("SALIR", func(): get_tree().quit()))
	content.add_child(label("WASD · moverte     E · hablar     Shift · correr     I · inventario     M · mapa     J · misiones", 15, MUTED))
	content.add_child(label("Personajes caricaturescos ficticios. Productos inventados. Recursos gráficos y sonidos originales.", 13, MUTED))

func new_game() -> void:
	var previous_settings: Dictionary = state.settings.duplicate()
	state = StateScript.new()
	state.settings = previous_settings
	city.state = state
	city.patrols = [Vector2(900, 360), Vector2(1950, 1080), Vector2(1200, 600), Vector2(560, 1080)]
	clear_menu()
	playing = true
	hud.show()
	camera.position = state.player
	refresh_hud()
	var body := modal_column("Bienvenido al lunes, Mancebo.", "Día 1 · El Barrio · 500 € · mochila de 20 unidades")
	body.add_child(label("Tu apartamento huele a café y a planes demasiado grandes. Monfe te espera al lado de casa. Dice que conoce a una clienta en el Centro y que esto es más rentable que vender pulseras en agosto.", 21))
	body.add_child(label("Tu objetivo: 3 propiedades y 15.000 € de patrimonio. Sigue las doce misiones del HUD para abrir barrios, conocer a todos los contactos y aprender la economía.", 19, GOLD))
	body.add_child(label("Compra barato en el Barrio o el Polígono y vende donde la demanda sea alta. Cada contacto tiene stock y presupuesto; se renuevan cada 90 segundos. Las propiedades y las inversiones generan ingresos cada 20 segundos.", 17))
	body.add_child(label("Si tu sospecha alcanza 40, las patrullas cercanas te perseguirán. Corre, mantén distancia y espera a que se calme el ambiente. Las inspecciones cuestan dinero y mercancía.", 17, MUTED))
	body.add_child(button("BAJAR A LA CALLE  [E para hablar con Monfe]", func():
		close_modal()
		state.save_game()
		notify("Monfe está a tu derecha. Acércate y pulsa E.")))

func continue_game() -> void:
	var candidate: EmpireState = StateScript.new()
	if not candidate.load_game():
		notify("No se pudo leer la partida. Puedes empezar una nueva.")
		return
	state = candidate
	city.state = state
	clear_menu()
	playing = true
	city.active = true
	hud.show()
	camera.position = state.player
	apply_settings()
	refresh_hud()
	notify("Partida recuperada. El imperio sigue abierto.")

func show_settings() -> void:
	var body := modal_column("Ajustes", "Los ajustes se guardan con tu partida.")
	var check := CheckButton.new()
	check.text = "Efectos de sonido originales"
	check.button_pressed = bool(state.settings.sound)
	check.toggled.connect(func(value: bool):
		state.settings.sound = value
		if playing: state.save_game())
	body.add_child(check)
	var fullscreen := CheckButton.new()
	fullscreen.text = "Pantalla completa"
	fullscreen.button_pressed = bool(state.settings.fullscreen)
	fullscreen.toggled.connect(func(value: bool):
		state.settings.fullscreen = value
		apply_settings()
		if playing: state.save_game())
	body.add_child(fullscreen)
	body.add_child(label("Controles\nWASD / flechas: caminar · Shift: correr\nE: hablar o entrar a casa · I / Tab: inventario\nM: mapa y mercados · J: misiones\nF5: guardar · Esc: cerrar ventanas o pausar", 20))
	body.add_child(label("Las ventanas de diálogo pausan la ciudad. Puedes pensar tus compras sin que una patrulla te estropee la calculadora.", 16, MUTED))

func apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if state.settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(hud)
	var top := panel_at(hud, Rect2(18, 16, 1244, 66))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 17)
	top.add_child(row)
	var logo := label("MR / EL IMPERIO", 19, GOLD)
	logo.custom_minimum_size.x = 170
	logo.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(logo)
	stats_label = label("", 18)
	stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stats_label)
	row.add_child(button("Inventario [I]", show_inventory))
	row.add_child(button("Mapa [M]", show_map))
	row.add_child(button("Pausa", show_pause))
	var quest := panel_at(hud, Rect2(18, 97, 450, 118))
	mission_label = label("", 16)
	quest.add_child(mission_label)
	var police := panel_at(hud, Rect2(1000, 97, 262, 90))
	var police_col := column(police, 6)
	police_col.add_child(label("SOSPECHA POLICIAL · 40 = ALERTA", 12, MUTED))
	heat_bar = ProgressBar.new()
	heat_bar.custom_minimum_size.y = 20
	heat_bar.max_value = 100
	heat_bar.show_percentage = true
	police_col.add_child(heat_bar)
	var mini_panel := panel_at(hud, Rect2(1024, 207, 238, 167))
	map_control = Control.new()
	map_control.custom_minimum_size = Vector2(198, 135)
	map_control.draw.connect(func(): draw_minimap(map_control, Vector2(192, 115)))
	mini_panel.add_child(map_control)
	var bottom := panel_at(hud, Rect2(18, 714, 710, 68))
	var bottom_col := column(bottom, 4)
	area_label = label("", 14, GOLD)
	hint_label = label("", 14, MUTED)
	bottom_col.add_child(area_label)
	bottom_col.add_child(hint_label)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(380, 555)
	toast_box.size = Vector2(520, 140)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(toast_box)

func refresh_hud() -> void:
	if not is_instance_valid(stats_label):
		return
	stats_label.text = "%s €   REP %d   MOCHILA %d/%d" % [money(state.cash), state.reputation, state.used_capacity(), state.capacity]
	heat_bar.value = state.heat
	if state.mission < EmpireState.MISSIONS.size():
		var quest: Dictionary = EmpireState.MISSIONS[state.mission]
		mission_label.text = "%s\n%s\nRecompensa: %d € · +%d reputación" % [quest.title, quest.goal, quest.reward, quest.rep]
	else:
		mission_label.text = "IMPERIO CONSTRUIDO\nLa ciudad conoce tu nombre. Sigue ampliando tu fortuna."
	area_label.text = "%s  ·  DÍA %d  ·  Patrimonio %s €" % [EmpireState.DISTRICTS[state.district_at(state.player)].name, state.day, money(state.net_worth())]
	var nearest := city.nearest()
	hint_label.text = "[E] %s  ·  Shift: correr  ·  J: misiones" % nearest.name if not nearest.is_empty() else "WASD: caminar · Shift: correr · E: hablar · F5: guardar"
	map_control.queue_redraw()

func money(value: int) -> String:
	var raw := str(value)
	var result := ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0:
			result += "."
		result += raw[i]
	return result

func _process(delta: float) -> void:
	if playing:
		camera.position = state.player
	if playing and city.active:
		for message in state.update(delta):
			notify(message)
		autosave_clock += delta
		if autosave_clock >= 20:
			state.save_game()
			autosave_clock = 0
		hud_clock += delta
		if hud_clock >= 0.15:
			refresh_hud()
			hud_clock = 0
		check_progress()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_ESCAPE:
		if is_instance_valid(modal): close_modal()
		elif playing: show_pause()
		get_viewport().set_input_as_handled()
		return
	if not playing or is_instance_valid(menu):
		return
	if is_instance_valid(modal):
		return
	match key:
		KEY_E:
			var nearest := city.nearest()
			if not nearest.is_empty():
				show_interaction(nearest.id)
		KEY_I, KEY_TAB: show_inventory()
		KEY_M: show_map()
		KEY_J: show_missions()
		KEY_F5:
			notify("Partida guardada." if state.save_game() else "No se pudo guardar la partida.")
		_: return
	get_viewport().set_input_as_handled()

func show_interaction(id: String) -> void:
	if id == "home":
		show_home()
		return
	var npc := state.npc_by_id(id)
	state.meet(id)
	check_progress()
	if state.won and is_instance_valid(modal) and current_contact == "victory":
		return
	var body := modal_column(npc.name, "%s · %s" % [npc.role, EmpireState.DISTRICTS[state.district_at(Vector2(npc.pos[0], npc.pos[1]))].name])
	current_contact = id
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 18)
	body.add_child(portrait_row)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(80, 92)
	portrait.draw.connect(func():
		portrait.draw_rect(Rect2(0, 0, 80, 92), Color(npc.color).darkened(0.75))
		portrait.draw_rect(Rect2(18, 44, 44, 46), Color(npc.color))
		portrait.draw_rect(Rect2(23, 12, 34, 35), Color("dca985"))
		portrait.draw_rect(Rect2(21, 8, 38, 12), Color("24283c"))
		portrait.draw_rect(Rect2(30, 26, 4, 4), INK)
		portrait.draw_rect(Rect2(47, 26, 4, 4), INK)
		if id == "navarro":
			portrait.draw_rect(Rect2(12, 6, 55, 10), GOLD)
			portrait.draw_rect(Rect2(28, 58, 25, 5), GOLD))
	portrait_row.add_child(portrait)
	var dialogue := label("“%s”" % npc.line, 18)
	dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(dialogue)
	if id in ["monfe", "peralta", "lola", "garcia", "navarro"]:
		trade_panel(body, id)
	match id:
		"monfe":
			body.add_child(button("Ampliar mochila · %d €" % (500 if int(state.upgrades.capacity) == 0 else 1500), func(): do_upgrade("capacity", id), int(state.upgrades.capacity) >= 2))
		"scot":
			body.add_child(button("Terminal de mercados · 750 €", func(): do_upgrade("tech", id), bool(state.upgrades.tech)))
			body.add_child(label("El terminal permite consultar todos los precios en el mapa. Comprar barato y vender caro: hasta el algoritmo de Monfe entiende eso.", 17, MUTED))
		"toni":
			for i in range(EmpireState.PROPERTIES.size()):
				var prop: Dictionary = EmpireState.PROPERTIES[i]
				var owned := state.properties.has(i)
				body.add_child(button("%s · %s € · +%d €/20s%s" % [prop.name, money(prop.cost), prop.income, " · TUYA" if owned else ""], func():
					notify(state.buy_property(i))
					after_action(id), owned))
		"soto":
			body.add_child(button("Contratar seguridad · 1.000 €", func(): do_upgrade("security", id), bool(state.upgrades.security)))
			body.add_child(label("Soto reduce la sospecha que generan las ventas, acelera su descenso y rebaja las multas al 8% del efectivo.", 18, MUTED))
		"cristian":
			body.add_child(button("Invertir 1.000 € · +120 €/20s · %d/5 inversiones" % state.investments, func(): do_upgrade("invest", id), state.investments >= 5))
			body.add_child(label("Patrimonio: %s €\nIngresos comerciales: %s €\nGastos: %s €\nIngresos pasivos: %s €" % [money(state.net_worth()), money(state.revenues), money(state.expenses), money(state.passive_income)], 18))
		"xoxi":
			body.add_child(label("RUMOR DEL DÍA\n%s\n\nRuta sugerida: compra a Peralta en el Polígono y vende a Navarro en La Corona. No lleves la sospecha por encima de 40 delante de una patrulla.", 19, GOLD))
			body.get_child(body.get_child_count() - 1).text = body.get_child(body.get_child_count() - 1).text % state.market_event
	state.save_game()
	refresh_hud()

func trade_panel(body: VBoxContainer, id: String) -> void:
	var npc := state.npc_by_id(id)
	var district := state.district_at(Vector2(npc.pos[0], npc.pos[1]))
	var buying_allowed := id in ["monfe", "peralta"]
	var amount_row := HBoxContainer.new()
	amount_row.add_theme_constant_override("separation", 12)
	body.add_child(amount_row)
	var amount_title := label("Cantidad por operación", 16, MUTED)
	amount_title.custom_minimum_size.x = 195
	amount_title.size_flags_horizontal = Control.SIZE_FILL
	amount_row.add_child(amount_title)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = state.capacity
	amount.value = trade_amount
	amount.custom_minimum_size.x = 100
	amount.value_changed.connect(func(value: float): trade_amount = int(value))
	amount_row.add_child(amount)
	amount_row.add_child(label("Saldo: %s € · mochila %d/%d" % [money(state.cash), state.used_capacity(), state.capacity], 16, GOLD))
	if not buying_allowed:
		body.add_child(label("Presupuesto del cliente: %s € · se repone cada nuevo día" % money(int(state.npc_budgets[id])), 14, MUTED))
	for i in range(3):
		var product: Dictionary = EmpireState.PRODUCTS[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		body.add_child(row)
		var quote := "Tienes %d · stock %d · compra %d €" % [state.inventory[i], state.stock[id][i], state.price(i, district, true)] if buying_allowed else "Tienes %d · venta %d €" % [state.inventory[i], state.price(i, district, false)]
		var text := label("%s\n%s" % [product.name, quote], 16, Color(product.color))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if buying_allowed:
			row.add_child(button("Comprar", func():
				notify(state.trade(id, i, trade_amount, true))
				after_action(id)))
		else:
			row.add_child(button("Vender", func():
				notify(state.trade(id, i, trade_amount, false))
				after_action(id), int(state.inventory[i]) == 0))
			row.add_child(button("Todo", func():
				notify(state.trade(id, i, int(state.inventory[i]), false))
				after_action(id), int(state.inventory[i]) == 0))
	body.add_child(label("%s\nCada venta genera sospecha. Los precios cambian con el barrio y los eventos diarios." % state.market_event, 14, MUTED))

func do_upgrade(kind: String, contact: String) -> void:
	notify(state.upgrade(kind))
	after_action(contact)

func after_action(contact: String) -> void:
	check_progress()
	state.save_game()
	refresh_hud()
	if current_contact == "victory":
		return
	show_interaction(contact)

func check_progress() -> void:
	var was_won := state.won
	for text in state.progress():
		notify(text)
	if state.won and not was_won:
		show_victory()
		state.save_game()

func show_home() -> void:
	var body := modal_column("Tu apartamento", "El único sitio donde Monfe no te pide una inversión.")
	body.add_child(label("Guardado automático cada 20 segundos y después de cada operación. La partida también se guarda al cerrar el juego por la ventana.", 19))
	body.add_child(button("GUARDAR PARTIDA", func(): notify("Partida guardada." if state.save_game() else "Error al guardar.")))
	body.add_child(button("Descansar · 25 € · -35 sospecha", func():
		if state.cash < 25:
			notify("Necesitas 25 € para café, persianas y tranquilidad.")
			return
		state.cash -= 25
		state.expenses += 25
		state.heat = maxf(0, state.heat - 35)
		for message in state.update(30): notify(message)
		state.save_game()
		notify("Media hora de siesta narrativa. Treinta segundos de ciudad. La policía mira hacia otro lado.")
		refresh_hud()))

func show_inventory() -> void:
	var body := modal_column("Inventario y negocios", "Mancebo Robles · lo que cabe en la mochila y lo que ya tiene escrituras")
	body.add_child(label("Efectivo: %s €     Patrimonio: %s €\nCapacidad: %d/%d     Reputación: %d     Autoridades: %d/100" % [money(state.cash), money(state.net_worth()), state.used_capacity(), state.capacity, state.reputation, state.authorities], 21, GOLD))
	for i in range(3):
		body.add_child(label("%s      × %d" % [EmpireState.PRODUCTS[i].name, state.inventory[i]], 21, Color(EmpireState.PRODUCTS[i].color)))
	body.add_child(label("PROPIEDADES", 17, MUTED))
	if state.properties.is_empty():
		body.add_child(label("Aún ninguna. Toni Escrig vende locales en el Centro.", 17))
	for prop in state.properties:
		body.add_child(label("%s · +%d €/20s" % [EmpireState.PROPERTIES[int(prop)].name, EmpireState.PROPERTIES[int(prop)].income], 18))
	body.add_child(label("Inversiones: %d/5 · +%d €/20s\nMejoras: terminal %s · seguridad %s\nComprado: %d u. · vendido: %d u. · inspecciones: %d" % [state.investments, state.investments * 120, "sí" if state.upgrades.tech else "no", "sí" if state.upgrades.security else "no", state.total_bought, state.total_sold, state.arrests], 17, MUTED))

func draw_minimap(control: Control, dimensions: Vector2) -> void:
	var scale := dimensions / Vector2(2400, 1440)
	for i in range(6):
		var origin := Vector2((i % 3) * 800, int(i / 3) * 720) * scale
		var tint := Color(EmpireState.DISTRICTS[i].color).darkened(0.55 if state.unlocked(i) else 0.86)
		control.draw_rect(Rect2(origin + Vector2(1, 1), Vector2(800, 720) * scale - Vector2(2, 2)), tint)
		control.draw_line(origin + Vector2(0, 360) * scale, origin + Vector2(800, 360) * scale, Color("526579"), 3)
		control.draw_line(origin + Vector2(400, 0) * scale, origin + Vector2(400, 720) * scale, Color("526579"), 3)
	for npc in EmpireState.NPCS:
		var pos := Vector2(npc.pos[0], npc.pos[1]) * scale
		control.draw_circle(pos, 2.7, Color(npc.color))
	for patrol in city.patrols:
		control.draw_circle(patrol * scale, 2.2, Color("e77887"))
	control.draw_circle(state.player * scale, 4.8, GOLD)
	control.draw_circle(state.player * scale, 2.3, WHITE)

func show_map() -> void:
	var body := modal_column("Mapa · Costa del Imperio", "Puntos de color: contactos · blanco: tú · rojo: patrullas · zonas oscuras: bloqueadas")
	var map := Control.new()
	map.custom_minimum_size = Vector2(690, 365)
	map.draw.connect(func():
		draw_minimap(map, Vector2(690, 350))
		for i in range(6):
			var pos := Vector2((i % 3) * 230 + 10, int(i / 3) * 175 + 21)
			map.draw_string(ThemeDB.fallback_font, pos, EmpireState.DISTRICTS[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, WHITE)
			if not state.unlocked(i):
				map.draw_string(ThemeDB.fallback_font, pos + Vector2(0, 17), "REP %d" % EmpireState.DISTRICTS[i].rep, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD))
	body.add_child(map)
	body.add_child(label("CONTACTOS\nBarrio: Monfe / Xoxi · Centro: Lola / Toni\nResidencial: Scot · Polígono: Alejandro Peralta\nPuerto: García / Soto · Lujo: Navarro / Cristian Martín", 16))
	if state.upgrades.tech:
		body.add_child(label("TERMINAL SCOT · PRECIOS DE VENTA", 17, GOLD))
		for district in range(6):
			body.add_child(label("%s: Bruma %d € / Sol %d € / Eco %d €" % [EmpireState.DISTRICTS[district].name, state.price(0, district, false), state.price(1, district, false), state.price(2, district, false)], 15, MUTED))
	else:
		body.add_child(label("Scot instala un terminal por 750 € para consultar todos los precios aquí.", 15, GOLD))

func show_missions() -> void:
	var body := modal_column("Misiones · de lunes a leyenda", "%d/12 completadas. Puedes hablar con contactos antes de su misión: el juego recuerda tus avances." % state.mission)
	for i in range(EmpireState.MISSIONS.size()):
		var quest: Dictionary = EmpireState.MISSIONS[i]
		body.add_child(label("%s %s\n%s" % ["✓" if i < state.mission else "→" if i == state.mission else "○", quest.title, quest.goal], 18, GOLD if i == state.mission else MUTED if i > state.mission else Color("92d3ad")))

func show_pause() -> void:
	var body := modal_column("La ciudad puede esperar", "Partida pausada")
	body.add_child(button("SEGUIR JUGANDO", close_modal))
	body.add_child(button("GUARDAR PARTIDA", func(): notify("Partida guardada." if state.save_game() else "Error al guardar.")))
	body.add_child(button("AJUSTES", show_settings))
	body.add_child(button("MENÚ PRINCIPAL · guardar y salir", func():
		state.save_game()
		show_main_menu()))
	body.add_child(button("CERRAR JUEGO · guardar", func():
		state.save_game()
		get_tree().quit()))

func show_victory() -> void:
	var body := modal_column("EL IMPERIO LLEVA TU NOMBRE", "12 misiones completadas · Mancebo Robles domina Costa del Imperio")
	current_contact = "victory"
	body.add_child(label("Monfe asegura que todo fue idea suya. Scot lo desmiente con una hoja de cálculo. García pide una reunión. Toni trae otra escritura. Xoxi ya lo había contado ayer.", 23, GOLD))
	body.add_child(label("Navarro se sube a una mesa: «¡50 Cent el Europeo presenta a Mancebo Robles!». Peralta pregunta quién paga el transporte. Soto vigila la puerta. Cristian revisa los números. Lola, por fin, consigue su descuento.", 20))
	body.add_child(label("Tres propiedades, doce historias y una ciudad entera de posibilidades. Puedes seguir jugando, ampliar tus inversiones y aumentar tu patrimonio.", 19))
	body.add_child(label("Patrimonio: %s €\nReputación: %d · unidades vendidas: %d\nIngresos pasivos: %s € · inspecciones: %d" % [money(state.net_worth()), state.reputation, state.total_sold, money(state.passive_income), state.arrests], 20, GOLD))
	body.add_child(button("SEGUIR CONSTRUYENDO EL IMPERIO", close_modal))

func notify(text: String) -> void:
	if not is_instance_valid(toast_box):
		return
	while toast_box.get_child_count() > 2:
		toast_box.get_child(0).free()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(panel)
	panel.add_child(label(text, 15, GOLD if text.begins_with("MISIÓN") else WHITE))
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	panel.add_child(timer)
	timer.timeout.connect(func():
		if is_instance_valid(panel): panel.queue_free())
	timer.start()
	play_sound(680 if text.begins_with("MISIÓN") else 440)

func play_sound(frequency: int) -> void:
	if not state.settings.sound:
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(4400)
	for i in range(2200):
		var fade := 1.0 - float(i) / 2200
		var sample := int(sin(float(i) * float(frequency) * TAU / 22050) * 2600 * fade)
		samples.encode_s16(i * 2, sample)
	stream.data = samples
	sound.stream = stream
	sound.volume_db = -10
	sound.play()
