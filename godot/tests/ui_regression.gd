extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func contains_control(viewport: Rect2, control: Control) -> bool:
	return viewport.encloses(control.get_global_rect())

func click_button(button: Button) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	root.push_input(click,true)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click,true)

func run_checks() -> void:
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	game.set("persistence_enabled",false)
	root.add_child(game)
	game.set_physics_process(false)
	for window_size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,600)]:
		root.size = window_size
		for i in range(4):
			await process_frame
		game.call("_layout_ui")
		var viewport := root.get_visible_rect()
		game.call("_show_menu")
		await process_frame
		assert(contains_control(viewport,game.get("menu_column")),"Garage must fit at %s" % window_size)
		game.call("_select_car",5)
		game.call("_start")
		game.call("_resume")
		game.set("race_time",25.42)
		game.set("speed",33.333333)
		var heading: float = game.get("heading")
		game.set("velocity",Vector3(sin(heading),0,cos(heading))*33.333333)
		game.call("_update_hud")
		game.call("_layout_ui")
		game.call("_update_camera",1.0,true)
		await process_frame
		for key in ["time_label","objective_label","lap_label","speed_label","gear_label","score_label"]:
			assert(contains_control(viewport,game.get(key)),"%s must fit at %s" % [key,window_size])
		assert(game.get("speed_label").text == "120","Speedometer must display 120 km/h")
		assert(game.get("gear_label").text.ends_with("D3"),"Forward gear should be displayed")
		assert(not game.get("touch_controls").visible,"Desktop should hide touch pedals and their captions")
		assert(not game.get("time_label").get_global_rect().intersects(game.get("objective_label").get_global_rect()),"Timer and objective should not overlap")
		if not DisplayServer.get_name() == "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/fixed-driving-%d.png" % window_size.x)
		var escape := InputEventAction.new()
		escape.action = "pause_game"
		escape.pressed = true
		game.call("_unhandled_input",escape)
		for i in range(3):
			await process_frame
		game.call("_layout_ui")
		assert(game.get("paused").visible,"Escape should open pause")
		assert(contains_control(viewport,game.get("pause_panel")),"Pause panel must fit at %s" % window_size)
		assert(not game.get("hud").visible,"Pause should hide race HUD")
		if not DisplayServer.get_name() == "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/fixed-pause-%d.png" % window_size.x)
		for button in game.get("pause_panel").find_children("*","Button",true,false):
			if button.text == "CONTINUE DRIVE":
				click_button(button)
		await process_frame
		assert(game.get("phase") == "racing","Pause Continue button must respond to pointer input")
		game.call("_finish")
		for i in range(3):
			await process_frame
		game.call("_layout_ui")
		assert(contains_control(viewport,game.get("result_panel")),"Results must fit at %s" % window_size)
		print("UI_LAYOUT_PASS ",window_size," viewport=",viewport.size)
	game.queue_free()
	await process_frame
	print("NEON_UI_PASS")
	quit(0)
