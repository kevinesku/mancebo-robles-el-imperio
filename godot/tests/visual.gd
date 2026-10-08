extends SceneTree
## Rendering smoke test, requires an X11 display (or Windows desktop).

func _initialize() -> void:
	call_deferred("run")

func shot(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/imperio-" + filename + ".png")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(0.5).timeout
	await shot("menu")
	game.new_game()
	game.close_modal()
	await create_timer(0.5).timeout
	await shot("city")
	var initial: Vector2 = game.state.player
	var movement := InputEventKey.new()
	movement.physical_keycode = KEY_D
	movement.pressed = true
	Input.parse_input_event(movement)
	await create_timer(0.2).timeout
	movement.pressed = false
	Input.parse_input_event(movement)
	assert(game.state.player.x > initial.x + 15, "WASD input moves the real player")
	game.state.player = Vector2(340, 1030)
	await process_frame
	assert(game.city.nearest().id == "monfe", "proximity interaction finds Monfe")
	game.show_interaction("monfe")
	await shot("dialogue")
	game.show_map()
	await shot("map")
	game.close_modal()
	game.show_main_menu()
	game.new_game()
	game.close_modal()
	assert(game.state.cash == 500 and game.state.mission == 0, "new game resets progression")
	print("GODOT VISUAL PASS: menu, world, real WASD, proximity, dialog, map, new game.")
	game.sound.stop()
	game.sound.stream = null
	await create_timer(0.25).timeout
	game.queue_free()
	await process_frame
	quit(0)
