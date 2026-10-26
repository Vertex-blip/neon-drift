extends SceneTree

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var game: Node3D = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for i in range(10):
		game.call("_select_car",i)
		var car: Dictionary = game.get("cars")[i]
		var names: Array = car["paint"]["materials"]
		var found: Array = []
		for node in game.get("vehicle_model").find_children("*","MeshInstance3D",true,false):
			var instance := node as MeshInstance3D
			for surface in range(instance.mesh.get_surface_count()):
				var mat := instance.mesh.surface_get_material(surface)
				if mat != null and mat.resource_name in names:
					found.append(mat.resource_name)
		print(car["id"]," paint materials found=",found.size()," names=",found)
	quit(0)
