class_name EmpireCity
extends Node2D
## Ciudad propia dibujada con primitivas: no necesita assets externos ni servidores.

signal notice(text: String)

var state: EmpireState
var active := false
var direction := Vector2.DOWN
var walking := false
var animation := 0.0
var warning_cooldown := 0.0
var arrest_cooldown := 0.0
var obstacles: Array[Rect2] = []
var buildings: Array = []
var patrols := [Vector2(900, 360), Vector2(1950, 1080), Vector2(1200, 600), Vector2(560, 1080)]
var patrol_targets := [Vector2(1500, 360), Vector2(2270, 1080), Vector2(1200, 1280), Vector2(100, 1080)]
var homes := ["CAFÉ LUZ", "EL IMPERIO", "24 HORAS", "FERRETERÍA", "PAN & PLAN", "HORIZONTE", "ORBITAL", "ESTUDIO 7"]

func _ready() -> void:
	create_buildings()

func create_buildings() -> void:
	for district in range(6):
		var origin := Vector2((district % 3) * 800, int(district / 3) * 720)
		var rects := [Rect2(62, 90, 238, 178), Rect2(508, 88, 230, 185), Rect2(62, 485, 244, 170), Rect2(510, 487, 229, 174)]
		for index in range(rects.size()):
			var rect: Rect2 = rects[index]
			rect.position += origin
			obstacles.append(rect.grow(9))
			buildings.append({"rect": rect, "district": district, "index": index, "name": homes[(district * 3 + index) % homes.size()]})
	# The apartment is the south-west building, with its entrance on the main street.
	buildings[12].name = "APARTAMENTO · MANCEBO"

func _process(delta: float) -> void:
	animation += delta
	if state == null:
		return
	if active:
		warning_cooldown = maxf(0, warning_cooldown - delta)
		arrest_cooldown = maxf(0, arrest_cooldown - delta)
		move_player(delta)
		move_patrols(delta)
	queue_redraw()

func move_player(delta: float) -> void:
	var axis := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	walking = axis.length() > 0.1
	if walking:
		direction = axis.normalized()
	var speed := 265.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 195.0
	var step := axis.normalized() * speed * delta
	try_position(state.player + Vector2(step.x, 0))
	try_position(state.player + Vector2(0, step.y))

func try_position(next: Vector2) -> void:
	next = next.clamp(Vector2(20, 20), Vector2(2380, 1420))
	var district := state.district_at(next)
	if not state.unlocked(district):
		if warning_cooldown <= 0:
			notice.emit("%s requiere %d reputación. Sigue tus misiones para abrir la zona." % [EmpireState.DISTRICTS[district].name, EmpireState.DISTRICTS[district].rep])
			warning_cooldown = 3.0
		return
	for rect in obstacles:
		if rect.has_point(next):
			return
	state.player = next

func move_patrols(delta: float) -> void:
	for i in range(patrols.size()):
		var chasing: bool = state.heat >= 40 and patrols[i].distance_to(state.player) < 430
		var target: Vector2 = state.player if chasing else patrol_targets[i]
		var speed := 145.0 if chasing else 76.0
		var next: Vector2 = patrols[i].move_toward(target, delta * speed)
		var blocked := false
		for rect in obstacles:
			if rect.has_point(next):
				blocked = true
				break
		if not blocked:
			patrols[i] = next
		if not chasing and patrols[i].distance_to(target) < 8:
			if i == 0:
				patrol_targets[i].x = 90 if patrol_targets[i].x > 500 else 2260
			elif i == 1:
				patrol_targets[i].x = 90 if patrol_targets[i].x > 500 else 2260
			elif i == 2:
				patrol_targets[i].y = 110 if patrol_targets[i].y > 700 else 1320
			else:
				patrol_targets[i].x = 2270 if patrol_targets[i].x < 500 else 90
		if chasing and patrols[i].distance_to(state.player) < 26 and arrest_cooldown <= 0:
			notice.emit(state.arrested())
			arrest_cooldown = 12

func nearest() -> Dictionary:
	var result := {}
	var distance := 75.0
	for npc in EmpireState.NPCS:
		var pos := Vector2(npc.pos[0], npc.pos[1])
		var measured := state.player.distance_to(pos)
		if measured < distance:
			distance = measured
			result = npc
	if state.player.distance_to(Vector2(255, 1040)) < distance:
		result = {"id": "home", "name": "Tu apartamento", "role": "Guardar y descansar"}
	return result

func person(pos: Vector2, color: Color, player_character: bool, phase := 0.0, hat := false) -> void:
	draw_ellipse_shadow(pos)
	var gait := int(sin(phase * 10) * 3) if walking and player_character else 0
	draw_rect(Rect2(pos + Vector2(-9, -21), Vector2(18, 16)), color)
	draw_rect(Rect2(pos + Vector2(-7, -5), Vector2(6, 11 + gait)), Color("202a42"))
	draw_rect(Rect2(pos + Vector2(2, -5), Vector2(6, 11 - gait)), Color("202a42"))
	draw_rect(Rect2(pos + Vector2(-8, -32), Vector2(16, 13)), Color("dcac84"))
	draw_rect(Rect2(pos + Vector2(-9, -34), Vector2(18, 5)), Color("24283c"))
	draw_rect(Rect2(pos + Vector2(-13, -18), Vector2(4, 12)), Color("dcac84"))
	draw_rect(Rect2(pos + Vector2(9, -18), Vector2(4, 12)), Color("dcac84"))
	if hat:
		draw_rect(Rect2(pos + Vector2(-12, -38), Vector2(24, 7)), Color("e5bb59"))
		draw_rect(Rect2(pos + Vector2(-5, -20), Vector2(10, 3)), Color("ffe49b"))
	if player_character:
		draw_arc(pos + Vector2(0, 2), 19, 0, TAU, 24, Color("edcd78"), 2)
		draw_rect(Rect2(pos + Vector2(-7, -19), Vector2(14, 3)), Color("f3d18c"))

func draw_ellipse_shadow(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-16, 1), Vector2(32, 8)), Color(0, 0, 0, 0.3))

func _draw() -> void:
	if state == null:
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 2400, 1440), Color("121e2b"))
	for district in range(6):
		var origin := Vector2((district % 3) * 800, int(district / 3) * 720)
		var theme_color := Color(EmpireState.DISTRICTS[district].color)
		draw_rect(Rect2(origin + Vector2(14, 14), Vector2(772, 692)), theme_color.darkened(0.82))
		# Pavement and two wide, connected streets per district.
		draw_rect(Rect2(origin + Vector2(318, 0), Vector2(164, 720)), Color("38404c"))
		draw_rect(Rect2(origin + Vector2(0, 278), Vector2(800, 164)), Color("38404c"))
		draw_rect(Rect2(origin + Vector2(337, 0), Vector2(126, 720)), Color("202936"))
		draw_rect(Rect2(origin + Vector2(0, 297), Vector2(800, 126)), Color("202936"))
		for line in range(0, 720, 70):
			draw_rect(Rect2(origin + Vector2(398, line + 18), Vector2(3, 29)), Color("616b79"))
		for line in range(0, 800, 70):
			draw_rect(Rect2(origin + Vector2(line + 16, 358), Vector2(29, 3)), Color("616b79"))
		for stripe in range(7):
			draw_rect(Rect2(origin + Vector2(325 + stripe * 22, 277), Vector2(10, 18)), Color("85909d"))
			draw_rect(Rect2(origin + Vector2(325 + stripe * 22, 425), Vector2(10, 18)), Color("85909d"))
		draw_string(font, origin + Vector2(52, 55), EmpireState.DISTRICTS[district].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, theme_color)
		if not state.unlocked(district):
			draw_string(font, origin + Vector2(52, 77), "ACCESO · %d REPUTACIÓN" % EmpireState.DISTRICTS[district].rep, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("b7828b"))
		for tree_pos in [Vector2(42, 285), Vector2(759, 460), Vector2(488, 678), Vector2(312, 80)]:
			var tree: Vector2 = origin + tree_pos
			draw_rect(Rect2(tree + Vector2(-3, 2), Vector2(6, 13)), Color("665144"))
			draw_rect(Rect2(tree + Vector2(-13, -18), Vector2(26, 24)), Color("346458"))
			draw_rect(Rect2(tree + Vector2(-8, -22), Vector2(18, 16)), Color("45836d"))
		for lamp_pos in [Vector2(322, 210), Vector2(477, 560), Vector2(145, 435), Vector2(690, 282)]:
			var lamp: Vector2 = origin + lamp_pos
			for radius in range(3, 0, -1):
				draw_circle(lamp, float(radius * 23), Color(0.98, 0.78, 0.44, 0.018))
			draw_rect(Rect2(lamp + Vector2(-3, -12), Vector2(6, 17)), Color("435060"))
			draw_rect(Rect2(lamp + Vector2(-5, -16), Vector2(10, 5)), Color("eec477"))
	for building in buildings:
		var rect: Rect2 = building.rect
		var theme_color := Color(EmpireState.DISTRICTS[building.district].color)
		draw_rect(Rect2(rect.position + Vector2(8, 10), rect.size), Color(0, 0, 0, 0.25))
		draw_rect(rect, theme_color.darkened(0.70))
		draw_rect(Rect2(rect.position + Vector2(5, 5), rect.size - Vector2(10, 20)), theme_color.darkened(0.83))
		draw_rect(Rect2(rect.position + Vector2(14, 14), Vector2(46, 23)), Color("3a4255"))
		draw_rect(Rect2(rect.position + Vector2(75, 15), Vector2(31, 27)), Color("344250"))
		for x in range(17, int(rect.size.x) - 10, 33):
			var lit := int(rect.position.x + x + building.index) % 3 != 0
			draw_rect(Rect2(rect.position + Vector2(x, rect.size.y - 17), Vector2(17, 7)), theme_color.lightened(0.08) if lit else Color("465264"))
		var sign_color := theme_color if state.unlocked(building.district) else Color("777e8c")
		draw_rect(Rect2(rect.position + Vector2(9, rect.size.y - 39), Vector2(rect.size.x - 18, 18)), Color("151b2a"))
		draw_string(font, rect.position + Vector2(17, rect.size.y - 25), building.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sign_color)
		if state.properties.has(building.district % 3):
			draw_rect(Rect2(rect.position + Vector2(rect.size.x - 30, 13), Vector2(18, 13)), Color("e8c47b"))
	# Apartment interaction marker.
	draw_string(font, Vector2(220, 1015), "⌂ CASA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e5cc93"))
	draw_rect(Rect2(240, 1021, 30, 6), Color("c5ab76"))
	# Waterfront and shipping containers frame the south-east skyline.
	draw_rect(Rect2(2290, 790, 110, 650), Color("163845"))
	for y in range(800, 1430, 43):
		draw_line(Vector2(2310, y), Vector2(2390, y - 4), Color("2b5463"), 2)
	for npc in EmpireState.NPCS:
		var pos := Vector2(npc.pos[0], npc.pos[1])
		person(pos, Color(npc.color), false, 0, npc.id == "navarro")
		var near := state.player.distance_to(pos) < 90
		draw_string(font, pos + Vector2(-58, -47), npc.name if near else npc.name.split(" · ")[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0dcc0") if near else Color("aab6cb"))
		if near:
			draw_string(font, pos + Vector2(-28, -67), "[E] HABLAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("edcc80"))
	for i in range(patrols.size()):
		var pos: Vector2 = patrols[i]
		var chasing := state.heat >= 40 and pos.distance_to(state.player) < 430
		if chasing:
			draw_circle(pos, 47, Color(0.94, 0.23, 0.34, 0.08))
		draw_rect(Rect2(pos + Vector2(-13, -22), Vector2(26, 42)), Color("ccd3d6"))
		draw_rect(Rect2(pos + Vector2(-11, -12), Vector2(22, 21)), Color("253c56"))
		draw_rect(Rect2(pos + Vector2(-10, -4), Vector2(10, 5)), Color("f76571") if int(animation * 6) % 2 == 0 else Color("83b9ed"))
		draw_rect(Rect2(pos + Vector2(0, -4), Vector2(10, 5)), Color("83b9ed") if int(animation * 6) % 2 == 0 else Color("f76571"))
	person(state.player, Color("a68cd0"), true, animation)
