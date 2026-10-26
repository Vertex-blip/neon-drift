extends Node3D
class_name CoastTrack

const ROAD_HALF := 6.8
const SAMPLE_COUNT := 1024
const GATE_COUNT := 24
var samples: Array[Vector4] = []
var track_length := 950.0
var rocks: Node3D
var gates: Node3D
var checkpoint_markers: Array[Node3D] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1994
	var file := FileAccess.open("res://data/track.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	track_length = float(data["length"])
	for item in data["samples"]:
		samples.append(Vector4(float(item[0]), float(item[1]), float(item[2]), float(item[3])))
	_make_environment()
	_make_track()
	_make_scenery()
	_make_landmarks()
	_make_checkpoints()

func point(index: int) -> Vector3:
	var s: Vector4 = samples[posmod(index, samples.size())]
	return Vector3(s.x, 0.0, s.y)

func tangent(index: int) -> Vector3:
	var s: Vector4 = samples[posmod(index, samples.size())]
	return Vector3(s.z, 0.0, s.w).normalized()

func normal(index: int) -> Vector3:
	var t := tangent(index)
	return Vector3(t.z, 0.0, -t.x)

func nearest(position: Vector3) -> Dictionary:
	var best_index := 0
	var best_distance := INF
	for i in range(samples.size()):
		var s := samples[i]
		var d := (position.x - s.x) ** 2 + (position.z - s.y) ** 2
		if d < best_distance:
			best_distance = d
			best_index = i
	var n := normal(best_index)
	var offset := (position - point(best_index)).dot(n)
	return {"index":best_index,"distance":sqrt(best_distance),"offset":offset,"normal":n,"point":point(best_index)}

func gate_index(gate: int) -> int:
	return int(round(float(gate) / float(GATE_COUNT) * samples.size())) % samples.size()

func _mat(color: Color, roughness := 0.7, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _make_environment() -> void:
	var env := Environment.new()
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/sunset.hdr")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_energy_multiplier = 0.55
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.58
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = false
	env.fog_light_color = Color("acaba2")
	env.fog_density = 0.00025
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 128, 0)
	light.light_color = Color("ffd3a8")
	light.light_energy = 1.7
	light.shadow_enabled = false
	add_child(light)
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000,12000)
	ocean.mesh = plane
	ocean.position.y = -7.0
	var water := _mat(Color("507989"),0.28,0.1)
	water.albedo_color = Color("467384")
	water.uv1_scale = Vector3(50,50,1)
	ocean.material_override = water
	add_child(ocean)

func _add_ribbon(name: String, left: float, right: float, height: float, mat: Material, uv_scale: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(samples.size()):
		var j := (i+1) % samples.size()
		var a := point(i) + normal(i)*left + Vector3.UP*height
		var b := point(i) + normal(i)*right + Vector3.UP*height
		var c := point(j) + normal(j)*left + Vector3.UP*height
		var d := point(j) + normal(j)*right + Vector3.UP*height
		var u := float(i)/samples.size()*track_length/uv_scale
		var v := float(i+1)/samples.size()*track_length/uv_scale
		for item in [[a,Vector2(0,u)],[c,Vector2(0,v)],[b,Vector2(1,u)],[b,Vector2(1,u)],[c,Vector2(0,v)],[d,Vector2(1,v)]]:
			surface.set_uv(item[1])
			surface.add_vertex(item[0])
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = surface.commit()
	instance.material_override = mat
	if mat is BaseMaterial3D:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _make_track() -> void:
	var asphalt := _mat(Color("b7b8b5"),0.87)
	asphalt.albedo_texture = load("res://assets/asphalt-color.jpg")
	asphalt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	asphalt.normal_enabled = true
	asphalt.normal_texture = load("res://assets/asphalt-normal.jpg")
	asphalt.uv1_scale = Vector3(1,1,1)
	_add_ribbon("Asphalt",-ROAD_HALF,ROAD_HALF,0.11,asphalt,4.0)
	var white := _mat(Color("e9e6d8"))
	var yellow := _mat(Color("d5a667"))
	_add_ribbon("Left edge",-6.3,-6.16,0.13,white,40)
	_add_ribbon("Right edge",6.16,6.3,0.13,white,40)
	_add_ribbon("Centre left",-0.11,-0.04,0.14,yellow,40)
	_add_ribbon("Centre right",0.04,0.11,0.14,yellow,40)
	var ground := _mat(Color("7eac86"),0.95)
	ground.albedo_texture = load("res://assets/grass-rock-color.jpg")
	ground.normal_enabled = true
	ground.normal_texture = load("res://assets/grass-rock-normal.jpg")
	ground.uv1_scale = Vector3(0.5,0.5,1)
	_add_ribbon("Sea shoulder",-45,-6.8,-0.4,ground,12)
	_add_ribbon("Inner shoulder",6.8,55,-0.35,ground,12)
	# The whole island interior is a continuous bank beneath the scanned rocks.
	var interior := SurfaceTool.new()
	interior.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 22
	for j in range(rings):
		var r0 := float(j)/rings
		var r1 := float(j+1)/rings
		for i in range(samples.size()):
			var k := (i+1)%samples.size()
			var a := _interior_point(i,r0)
			var b := _interior_point(k,r0)
			var c := _interior_point(i,r1)
			var d := _interior_point(k,r1)
			for p in [a,b,c,c,b,d]:
				interior.set_uv(Vector2(p.x/8,p.z/8))
				interior.add_vertex(p)
	interior.generate_normals()
	var interior_mesh := MeshInstance3D.new()
	interior_mesh.mesh = interior.commit()
	interior_mesh.material_override = ground
	add_child(interior_mesh)
	var rail_mat := _mat(Color("bfc5bd"),0.38,0.64)
	for side in [-1.0,1.0]:
		for y in [0.48,0.88]:
			var path := Curve3D.new()
			for i in range(0,samples.size()+1,3):
				var k := i % samples.size()
				path.add_point(point(k)+normal(k)*side*7.15+Vector3.UP*y)
			var rail := Path3D.new()
			rail.curve = path
			add_child(rail)
			# Short metal segments follow the curve without creating hundreds of scene nodes.
			var rail_surface := SurfaceTool.new()
			rail_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in range(0,samples.size(),3):
				var a: Vector3 = point(i)+normal(i)*side*7.15+Vector3.UP*y
				var j := (i+3)%samples.size()
				var b: Vector3 = point(j)+normal(j)*side*7.15+Vector3.UP*y
				var dir: Vector3 = (b-a).normalized()
				var across: Vector3 = dir.cross(Vector3.UP)*0.035
				for tri in [[a-across,b-across,a+across],[a+across,b-across,b+across]]:
					for p in tri:
						rail_surface.add_vertex(p)
			var rail_mesh := MeshInstance3D.new()
			rail_mesh.mesh = rail_surface.commit()
			rail_mesh.material_override = rail_mat
			rail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(rail_mesh)
	var finish := _mat(Color("f0ede3"),0.85)
	for x in range(14):
		for y in range(3):
			if (x+y)%2 == 0:
				continue
			var marker := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.9,0.01,0.7)
			marker.mesh = box
			marker.material_override = finish
			marker.position = point(0)+normal(0)*(float(x)-6.5)+tangent(0)*(float(y)-1.0)*0.8+Vector3.UP*0.145
			marker.rotation.y = atan2(tangent(0).x,tangent(0).z)
			add_child(marker)

func _interior_point(index: int, radius: float) -> Vector3:
	var edge := point(index)-normal(index)*7.0
	var x := edge.x*radius
	var z := -5+(edge.z+5)*radius
	var y := pow(1-radius,2)*23.0+sin(radius*PI)*2.0+sin(x*0.025)*cos(z*0.021)*sin(radius*PI)*3.0-0.5
	return Vector3(x,y,z)

func _make_scenery() -> void:
	var rock_scene: PackedScene = load("res://assets/rock_07.glb")
	rocks = Node3D.new()
	rocks.name = "Coastal boulders"
	add_child(rocks)
	for i in range(180):
		var k := rng.randi_range(0,samples.size()-1)
		var side := -1.0 if rng.randf()<0.48 else 1.0
		var distance := rng.randf_range(20.0,43.0)
		var obj: Node3D = rock_scene.instantiate()
		obj.position = point(k)+normal(k)*side*distance+Vector3.UP*(-0.8)
		obj.scale = Vector3.ONE*rng.randf_range(8.0,20.0)
		obj.rotation.y = rng.randf_range(0,TAU)
		rocks.add_child(obj)
	for variant in range(3):
		var pine := load("res://assets/pine-%d.webp" % variant)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = pine
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.16
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for i in range(95):
			var k := rng.randi_range(0,samples.size()-1)
			var side := -1.0 if rng.randf()<0.65 else 1.0
			var h := rng.randf_range(3.5,6.5)
			var tree := Node3D.new()
			tree.position = point(k)+normal(k)*side*rng.randf_range(11,16)+Vector3.UP*(h*0.5-0.5)
			add_child(tree)
			for angle in [0.0,PI*0.5]:
				var panel := MeshInstance3D.new()
				var panel_mesh := QuadMesh.new()
				panel_mesh.size = Vector2(h,h)
				panel.mesh = panel_mesh
				panel.material_override = mat
				panel.rotation.y = angle+rng.randf_range(-0.12,0.12)
				tree.add_child(panel)

func _make_landmarks() -> void:
	var station_scene: PackedScene = load("res://assets/scenery/gas-station.glb")
	var station: Node3D = station_scene.instantiate()
	station.name = "Coast service station"
	add_child(station)
	var bounds := AABB()
	var first := true
	for node in station.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var raw := instance.get_aabb()
		var transform: Transform3D = station.global_transform.affine_inverse()*instance.global_transform
		for dx in [0.0,1.0]:
			for dy in [0.0,1.0]:
				for dz in [0.0,1.0]:
					var vertex: Vector3 = transform*(raw.position+raw.size*Vector3(dx,dy,dz))
					if first:
						bounds = AABB(vertex,Vector3.ZERO)
						first = false
					else:
						bounds = bounds.expand(vertex)
	var scale_factor := 24.0/maxf(bounds.size.x,bounds.size.z)
	station.scale = Vector3.ONE*scale_factor
	station.position = point(150)-normal(150)*37.0-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*scale_factor+Vector3.UP*7.0
	var finish_group := Node3D.new()
	finish_group.name = "Start finish gantry"
	finish_group.position = point(0)
	finish_group.rotation.y = atan2(tangent(0).x,tangent(0).z)
	add_child(finish_group)
	var steel := _mat(Color("253238"),0.36,0.7)
	for side in [-1.0,1.0]:
		var upright := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.height = 6.8
		cylinder.top_radius = 0.12
		cylinder.bottom_radius = 0.16
		upright.mesh = cylinder
		upright.position = Vector3(side*7.4,3.4,0)
		upright.material_override = steel
		finish_group.add_child(upright)
	var crossbar := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(15,1.4,0.6)
	crossbar.mesh = bar
	crossbar.position.y = 6.35
	crossbar.material_override = steel
	finish_group.add_child(crossbar)
	var sign := Label3D.new()
	sign.text = "NEON DRIFT   /   COAST RUN"
	sign.font = load("res://assets/fonts/font-2.ttf")
	sign.font_size = 80
	sign.pixel_size = 0.006
	sign.modulate = Color("f1eee2")
	sign.position = Vector3(0,6.35,0.33)
	finish_group.add_child(sign)

func _make_checkpoints() -> void:
	gates = Node3D.new()
	add_child(gates)
	var glow := _mat(Color("ffad7a"),0.25)
	glow.emission_enabled = true
	glow.emission = Color("ff8750")
	glow.emission_energy_multiplier = 2.0
	for gate in range(GATE_COUNT):
		var k := gate_index(gate)
		var group := Node3D.new()
		group.position = point(k)
		group.rotation.y = atan2(tangent(k).x,tangent(k).z)
		gates.add_child(group)
		checkpoint_markers.append(group)
		for side in [-1.0,1.0]:
			var post := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.06
			cylinder.bottom_radius = 0.06
			cylinder.height = 2.6
			post.mesh = cylinder
			post.material_override = glow
			post.position = Vector3(side*5.8,1.3,0)
			group.add_child(post)
		group.visible = false

func show_gate(index: int, enabled: bool) -> void:
	for i in range(checkpoint_markers.size()):
		checkpoint_markers[i].visible = enabled and i == index
