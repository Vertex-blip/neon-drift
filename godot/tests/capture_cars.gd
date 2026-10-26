extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	for i in range(10):
		game.call("_select_car",i)
		for frame in range(4):
			await process_frame
		root.get_texture().get_image().save_png("res://docs/car-%02d.png" % i)
		print("CAPTURE_CAR ",i)
	quit(0)
