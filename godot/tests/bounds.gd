extends SceneTree
func _initialize() -> void:
	call_deferred("inspect")
func inspect() -> void:
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in range(10):
		game.call("_select_car",i)
		var model: Node3D = game.get("vehicle_model")
		print(i," ",game.call("_bounds",model)," pos=",model.position," scale=",model.scale)
	quit(0)
