extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene: PackedScene = load("res://scenes/game.tscn")
	var game: Node3D = scene.instantiate()
	game.set("persistence_enabled",false)
	root.add_child(game)
	game.call("_select_car",8)
	for i in range(90):
		await process_frame
	var img := root.get_texture().get_image()
	var result := img.save_png("res://docs/godot-garage.png")
	print("CAPTURE_RESULT ",result," ",img.get_size())
	game.set("garage_orbit",PI)
	game.call("_update_camera",1.0,true)
	for i in range(36):
		await process_frame
	root.get_texture().get_image().save_png("res://docs/godot-garage-orbit.png")
	quit(0)
