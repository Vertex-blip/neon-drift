extends Node3D

const TRACK_SCRIPT = preload("res://scripts/track.gd")
const ACCELERATION := 19.0
const DRAG := 1.5
const BRAKE_FORCE := 32.0
const MAX_SPEED := 64.0
const RACE_GATES := 24

var track: CoastTrack
var car_root: Node3D
var car_body: Node3D
var vehicle_model: Node3D
var paint_material: StandardMaterial3D
var cars: Array = []
var car_index := 8
var car_name_label: Label
var car_stats_label: Label
var tyre_smoke: Array[CPUParticles3D] = []
var brake_lights: Array[OmniLight3D] = []
var wheel_nodes: Array[Node3D] = []
var camera: Camera3D
var heading := 0.0
var velocity := Vector3.ZERO
var speed := 0.0
var steering := 0.0
var slip := 0.0
var drifting := false
var collision_cooldown := 0.0
var camera_style := 0
var garage_orbit := 0.0
var garage_dragging := false
var garage_touch_index := -1
var mode_buttons: Dictionary = {}
var garage_hint: Label
var shake := 0.0
var phase := "menu"
var mode := "sprint"
var countdown := 3.3
var race_time := 0.0
var penalty := 0.0
var lap := 1
var passed := 0
var next_gate := 1
var last_lap := 0.0
var lap_times: Array[float] = []
var score := 0.0
var combo := 1.0
var drift_time := 0.0
var best_time := 0.0
var best_coast := 0.0
var best_drift := 0
var selected_paint := Color("f06b37")
var ui: CanvasLayer
var menu: Control
var hud: Control
var paused: Control
var results: Control
var time_label: Label
var speed_label: Label
var lap_label: Label
var objective_label: Label
var score_label: Label
var countdown_label: Label
var result_label: Label
var menu_best_label: Label
var touch_controls: Node2D
var audio_player: AudioStreamPlayer
var audio_playback: AudioStreamGeneratorPlayback
var audio_enabled := true
var audio_phase := 0.0
var audio_sample_rate := 22050.0
var last_gear := 1
var gear_shift := 0.0
var font_bold: Font
var font_regular: Font
var gpu_notice := false

func _ready() -> void:
	_rng_seed()
	_load_save()
	cars = JSON.parse_string(FileAccess.get_file_as_string("res://data/cars-source.json"))
	car_index = clampi(car_index,0,cars.size()-1)
	font_bold = load("res://assets/fonts/font-2.ttf")
	font_regular = load("res://assets/fonts/font-4.ttf")
	track = TRACK_SCRIPT.new()
	track.name = "The Last Light"
	add_child(track)
	_make_car()
	_make_camera()
	_make_ui()
	_make_audio()
	_reset_car(14)
	_show_menu()
	get_viewport().size_changed.connect(_layout_touch)

func _rng_seed() -> void:
	seed(1994)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://neon-drift.cfg") == OK:
		best_time = float(cfg.get_value("records","time",0.0))
		best_coast = float(cfg.get_value("records","coast",0.0))
		best_drift = int(cfg.get_value("records","drift",0))
		selected_paint = Color(str(cfg.get_value("garage","paint","#f06b37")))
		car_index = int(cfg.get_value("garage","car",0))
		audio_enabled = bool(cfg.get_value("settings","audio",true))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records","time",best_time)
	cfg.set_value("records","coast",best_coast)
	cfg.set_value("records","drift",best_drift)
	cfg.set_value("garage","paint",selected_paint.to_html())
	cfg.set_value("garage","car",car_index)
	cfg.set_value("settings","audio",audio_enabled)
	cfg.save("user://neon-drift.cfg")

func _make_car() -> void:
	car_root = Node3D.new()
	car_root.name = "Playable car"
	add_child(car_root)
	car_body = Node3D.new()
	car_root.add_child(car_body)
	paint_material = StandardMaterial3D.new()
	paint_material.albedo_color = selected_paint
	paint_material.metallic = 0.62
	paint_material.roughness = 0.26
	paint_material.clearcoat_enabled = true
	paint_material.clearcoat = 1.0
	paint_material.clearcoat_roughness = 0.12
	_select_car(car_index)
	for side in [-1.0,1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(side*0.7,0.65,1.9)
		lamp.rotation_degrees.x = -4
		lamp.light_color = Color("fff2d7")
		lamp.light_energy = 2.0
		lamp.spot_range = 22
		lamp.spot_angle = 26
		car_root.add_child(lamp)
	_make_road_effects()

func _make_road_effects() -> void:
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var r := Vector2(x-31.5,y-31.5).length()/31.5
			image.set_pixel(x,y,Color(0.84,0.86,0.83,pow(maxf(0,1-r),2)*0.45))
	var smoke_texture := ImageTexture.create_from_image(image)
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_texture = smoke_texture
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_mat.vertex_color_use_as_albedo = true
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.9,0.9)
	smoke_mesh.material = smoke_mat
	for side in [-1.0,1.0]:
		var smoke := CPUParticles3D.new()
		smoke.position = Vector3(side*0.72,0.3,-1.55)
		smoke.amount = 32
		smoke.lifetime = 0.8
		smoke.explosiveness = 0
		smoke.direction = Vector3(-side*0.2,1,-0.35)
		smoke.spread = 27
		smoke.gravity = Vector3(0,0.45,0)
		smoke.initial_velocity_min = 0.5
		smoke.initial_velocity_max = 1.4
		smoke.mesh = smoke_mesh
		smoke.emitting = false
		car_root.add_child(smoke)
		tyre_smoke.append(smoke)
		var tail := OmniLight3D.new()
		tail.position = Vector3(side*0.68,0.65,-1.9)
		tail.light_color = Color("ff2f20")
		tail.light_energy = 0
		tail.omni_range = 3.2
		car_root.add_child(tail)
		brake_lights.append(tail)

func _bounds(root: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var inverse := root.global_transform.affine_inverse()
	for node in root.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		var raw := instance.get_aabb()
		var transform := inverse * instance.global_transform
		var box := AABB(transform * raw.position,Vector3.ZERO)
		for dx in [0.0,1.0]:
			for dy in [0.0,1.0]:
				for dz in [0.0,1.0]:
					box = box.expand(transform * (raw.position+raw.size*Vector3(dx,dy,dz)))
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	return aabb

func _select_car(index: int) -> void:
	car_index = posmod(index,cars.size())
	if vehicle_model != null:
		vehicle_model.queue_free()
		car_body.remove_child(vehicle_model)
	wheel_nodes.clear()
	var car: Dictionary = cars[car_index]
	vehicle_model = (load("res://assets/cars/%s.glb" % car["id"]) as PackedScene).instantiate()
	car_body.add_child(vehicle_model)
	var bounds := _bounds(vehicle_model)
	var size := bounds.size
	var length_axis := size.x > size.z
	var model_yaw := PI * 0.5 if length_axis else PI
	vehicle_model.rotation.y = model_yaw
	var factor: float = 4.6 / maxf(size.x,size.z)
	vehicle_model.scale = Vector3.ONE * factor
	var horizontal_offset := Basis(Vector3.UP,model_yaw) * Vector3(-bounds.get_center().x,0,-bounds.get_center().z)
	vehicle_model.position = horizontal_offset*factor + Vector3.UP*(-bounds.position.y*factor)
	_apply_paint()
	if car_name_label != null:
		car_name_label.text = "%02d / 10   %s %s" % [car_index+1,car["brand"],car["model"]]
		car_stats_label.text = "%s  ·  %d KM/H TOP SPEED" % [str(car["category"]).to_upper(),int((MAX_SPEED+car_index*0.6)*3.6)]
	_save()

func _apply_paint() -> void:
	if vehicle_model == null:
		return
	var car: Dictionary = cars[car_index]
	var paint: Dictionary = car["paint"] if car["paint"] != null else {}
	var names: Array = paint.get("materials",[])
	for node in vehicle_model.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var original := instance.mesh.surface_get_material(surface)
			if original != null and original.resource_name in names and original is StandardMaterial3D:
				var finish := original.duplicate() as StandardMaterial3D
				finish.albedo_color = selected_paint
				if bool(paint.get("textured",false)):
					finish.albedo_texture = null
				finish.metallic = maxf(finish.metallic,0.35)
				finish.roughness = minf(finish.roughness,0.3)
				finish.clearcoat_enabled = true
				finish.clearcoat = 0.8
				instance.set_surface_override_material(surface,finish)

func _make_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 52
	camera.current = true
	add_child(camera)

func _ui_label(parent: Node, caption: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_override("font",font_bold if bold else font_regular)
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, caption: String, callback: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(245,54)
	b.add_theme_font_override("font",font_regular)
	b.add_theme_font_size_override("font_size",17)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ff754e") if accent else Color("1b2b30")
	style.border_color = Color("ff754e") if accent else Color("536468")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("30434b") if not accent else Color("ff9373")
	b.add_theme_stylebox_override("hover",hover)
	b.add_theme_stylebox_override("pressed",hover)
	b.add_theme_color_override("font_color",Color("152023") if accent else Color("ecede5"))
	parent.add_child(b)
	b.pressed.connect(callback)
	return b

func _panel(parent: Node, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045,0.079,0.092,0.91)
	style.border_color = Color(0.43,0.53,0.50,0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

func _make_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.015,0.04,0.05,0.13)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	var sidebar := ColorRect.new()
	sidebar.color = Color(0.016,0.032,0.039,0.76)
	sidebar.custom_minimum_size = Vector2(520,900)
	sidebar.size = Vector2(520,900)
	sidebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(sidebar)
	var menu_column := VBoxContainer.new()
	menu_column.position = Vector2(52,55)
	menu_column.add_theme_constant_override("separation",8)
	menu.add_child(menu_column)
	_ui_label(menu_column,"VERTEX INTERACTIVE   /   THE COAST IS YOURS",14,Color("ff9b72"))
	_ui_label(menu_column,"NEON DRIFT.",91,Color("fff3e6"),true)
	_ui_label(menu_column,"COASTAL MOTORSPORT  /  10 CARS  /  4 MODES",15,Color("e0e2da"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	menu_column.add_child(spacer)
	_ui_label(menu_column,"SELECT EVENT",12,Color("ff9b72"),true)
	mode_buttons["sprint"] = _button(menu_column,"01  /  TIME ATTACK             TWO LAPS",func(): _set_mode("sprint"))
	mode_buttons["drift"] = _button(menu_column,"02  /  DRIFT SESSION           90 SECONDS",func(): _set_mode("drift"))
	mode_buttons["coast"] = _button(menu_column,"03  /  COAST RUN                  24 GATES",func(): _set_mode("coast"))
	mode_buttons["free"] = _button(menu_column,"04  /  FREE DRIVE                 OPEN ROAD",func(): _set_mode("free"))
	for key in mode_buttons:
		mode_buttons[key].custom_minimum_size.y = 47
	_button(menu_column,"TAKE THE WHEEL  ↗",_start,true)
	menu_best_label = _ui_label(menu_column,"",17,Color("cad2c7"))
	_ui_label(menu_column,"WASD / ARROWS  ·  S REVERSE  ·  SPACE DRIFT  ·  R RESET",12,Color("b9c4b9"))
	var garage_row := HBoxContainer.new()
	garage_row.add_theme_constant_override("separation",8)
	menu_column.add_child(garage_row)
	var previous := _button(garage_row,"‹",func(): _select_car(car_index-1))
	previous.custom_minimum_size = Vector2(48,42)
	car_name_label = _ui_label(garage_row,"",20,Color("fff3e6"),true)
	car_name_label.custom_minimum_size = Vector2(360,42)
	var next := _button(garage_row,"›",func(): _select_car(car_index+1))
	next.custom_minimum_size = Vector2(48,42)
	car_stats_label = _ui_label(menu_column,"",13,Color("ff9b72"))
	var paint_row := HBoxContainer.new()
	paint_row.add_theme_constant_override("separation",8)
	menu_column.add_child(paint_row)
	for item in [["PAPAYA","f06b37"],["GLACIER","d8dfd9"],["FOREST","335c54"],["OXBLOOD","762d34"]]:
		var paint := Color("#"+item[1])
		var button := _button(paint_row,item[0],func(): _set_paint(paint))
		button.custom_minimum_size = Vector2(100,40)
	var sound_button := _button(menu_column,"SOUND ON / OFF",_toggle_audio)
	sound_button.custom_minimum_size = Vector2(150,38)
	garage_hint = _ui_label(menu,"GARAGE  /  DRAG TO ROTATE",18,Color("fff3e6"),true)
	garage_hint.position = Vector2(922,44)
	_select_car(car_index)
	_refresh_mode_buttons()
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	time_label = _ui_label(hud,"00:00.00",32,Color("fff5e9"),true)
	time_label.position = Vector2(35,36)
	objective_label = _ui_label(hud,"THE LAST LIGHT  /  TIME ATTACK",19,Color("fff5e9"))
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position.y = 35
	lap_label = _ui_label(hud,"01 / 02",32,Color("fff5e9"),true)
	lap_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lap_label.position = Vector2(-205,35)
	score_label = _ui_label(hud,"",23,Color("ffa77a"),true)
	score_label.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	score_label.position = Vector2(-230,0)
	speed_label = _ui_label(hud,"000\nKM/H",68,Color("fff5e9"),true)
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position = Vector2(-200,-160)
	countdown_label = _ui_label(hud,"3",130,Color("fff7e8"),true)
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	paused = Control.new()
	paused.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(paused)
	var pause_panel := _panel(paused,370)
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-185,-180)
	var pause_column := VBoxContainer.new()
	pause_panel.add_child(pause_column)
	_ui_label(pause_column,"ON YOUR TIME.",50,Color("f4eadb"),true)
	_button(pause_column,"CONTINUE DRIVE",_resume,true)
	_button(pause_column,"RECOVER TO ROAD",_recover)
	_button(pause_column,"RESTART",_start)
	_button(pause_column,"RETURN TO GARAGE",_show_menu)
	results = Control.new()
	results.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(results)
	var result_panel := _panel(results,440)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.position = Vector2(-220,-180)
	var result_column := VBoxContainer.new()
	result_panel.add_child(result_column)
	_ui_label(result_column,"SESSION COMPLETE",16,Color("ff9b72"))
	result_label = _ui_label(result_column,"",46,Color("fff1e2"),true)
	_button(result_column,"ONE MORE RUN",_start,true)
	_button(result_column,"RETURN TO GARAGE",_show_menu)
	touch_controls = Node2D.new()
	ui.add_child(touch_controls)
	_make_touch()
	_show_ui()

func _make_touch() -> void:
	var image := Image.create(96,96,false,Image.FORMAT_RGBA8)
	image.fill(Color(0.07,0.14,0.16,0.78))
	var texture := ImageTexture.create_from_image(image)
	for action in ["steer_left","steer_right","handbrake","brake","accelerate"]:
		var button := TouchScreenButton.new()
		button.name = action
		button.action = action
		button.texture_normal = texture
		button.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		var circle := CircleShape2D.new()
		circle.radius = 48
		button.shape = circle
		button.shape_centered = true
		var caption := Label.new()
		caption.text = {"steer_left":"←","steer_right":"→","handbrake":"◒","brake":"↓","accelerate":"↑"}[action]
		caption.position = Vector2(-19,-29)
		caption.add_theme_font_size_override("font_size",42)
		caption.add_theme_color_override("font_color",Color("fff5df"))
		button.add_child(caption)
		touch_controls.add_child(button)
	_layout_touch()

func _layout_touch() -> void:
	if touch_controls == null:
		return
	var size := get_viewport().get_visible_rect().size
	var positions := {"steer_left":Vector2(75,size.y-88),"steer_right":Vector2(195,size.y-88),"handbrake":Vector2(size.x-325,size.y-88),"brake":Vector2(size.x-205,size.y-88),"accelerate":Vector2(size.x-75,size.y-88)}
	for key in positions:
		touch_controls.get_node(key).position = positions[key]

func _show_ui() -> void:
	menu.visible = phase == "menu"
	hud.visible = phase in ["countdown","racing","paused"]
	paused.visible = phase == "paused"
	results.visible = phase == "finished"
	touch_controls.visible = phase == "racing"
	if garage_hint != null:
		garage_hint.visible = phase == "menu"
	if track != null:
		track.show_gate(next_gate,phase == "racing" or phase == "countdown")

func _set_mode(new_mode: String) -> void:
	mode = new_mode
	_refresh_mode_buttons()
	match mode:
		"sprint": menu_best_label.text = "TIME ATTACK  /  TWO LAPS  /  BEST %s" % ("—" if best_time <= 0 else _format_time(best_time))
		"drift": menu_best_label.text = "DRIFT SESSION  /  90 SECONDS  /  BEST %d" % best_drift
		"coast": menu_best_label.text = "COAST RUN  /  ONE LAP  /  BEST %s" % ("—" if best_coast <= 0 else _format_time(best_coast))
		"free": menu_best_label.text = "FREE DRIVE  /  NO CLOCK  /  EXPLORE"
	_show_ui()

func _refresh_mode_buttons() -> void:
	for key in mode_buttons:
		var button: Button = mode_buttons[key]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("304148") if key == mode else Color("1b2b30")
		style.border_color = Color("ff835d") if key == mode else Color("536468")
		style.set_border_width_all(1)
		style.border_width_left = 4 if key == mode else 1
		style.set_corner_radius_all(3)
		style.set_content_margin_all(12)
		button.add_theme_stylebox_override("normal",style)
		button.add_theme_color_override("font_color",Color("fff3e6") if key == mode else Color("cad2d0"))

func _set_paint(color: Color) -> void:
	selected_paint = color
	paint_material.albedo_color = color
	_apply_paint()
	_save()

func _show_menu() -> void:
	phase = "menu"
	_reset_car(14)
	_set_mode(mode)
	_show_ui()

func _start() -> void:
	phase = "countdown"
	countdown = 3.3
	race_time = 0
	penalty = 0
	lap = 1
	passed = 0
	next_gate = 1
	last_lap = 0
	lap_times.clear()
	score = 0
	combo = 1
	drift_time = 0
	_reset_car(0)
	_show_ui()
	if audio_player != null and not audio_player.playing:
		audio_player.play()
		audio_playback = audio_player.get_stream_playback()

func _resume() -> void:
	phase = "racing"
	_show_ui()

func _recover() -> void:
	if phase not in ["racing","paused"]:
		return
	var near := track.nearest(car_root.position)
	_reset_car(int(near["index"]))
	if mode == "sprint":
		penalty += 3
	combo = 1
	drift_time = 0
	phase = "racing"
	_show_ui()

func _reset_car(index: int) -> void:
	car_root.position = track.point(index)+Vector3.UP*0.15
	var dir := track.tangent(index)
	heading = atan2(dir.x,dir.z)
	car_root.rotation.y = heading
	velocity = Vector3.ZERO
	speed = 0
	steering = 0
	slip = 0
	drifting = false
	_update_camera(1.0,true)

func _input(event: InputEvent) -> void:
	if phase != "menu":
		garage_dragging = false
		garage_touch_index = -1
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			garage_dragging = event.position.x > 520
		else:
			garage_dragging = false
	elif event is InputEventMouseMotion and garage_dragging:
		garage_orbit = wrapf(garage_orbit-event.relative.x*0.009,-PI,PI)
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x > 520 and garage_touch_index < 0:
			garage_touch_index = event.index
		elif not event.pressed and event.index == garage_touch_index:
			garage_touch_index = -1
	elif event is InputEventScreenDrag and event.index == garage_touch_index:
		garage_orbit = wrapf(garage_orbit-event.relative.x*0.009,-PI,PI)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if phase == "racing":
			phase = "paused"
		elif phase == "paused":
			phase = "racing"
		_show_ui()
	elif event.is_action_pressed("recover"):
		_recover()
	elif event.is_action_pressed("camera_switch"):
		camera_style = (camera_style+1)%2

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "racing":
		phase = "paused"
		_show_ui()

func _physics_process(delta: float) -> void:
	if phase == "countdown":
		countdown -= delta
		countdown_label.text = "GO" if countdown < 0.5 else str(maxi(1,int(ceil(countdown))))
		if countdown <= 0:
			phase = "racing"
			_show_ui()
	elif phase == "racing":
		_step_car(delta)
		_step_race(delta)
	_update_camera(delta,false)
	if phase == "racing" or phase == "countdown":
		_update_hud()
	elif phase == "menu":
		car_body.rotation.z = sin(Time.get_ticks_msec()*0.0006)*0.006
	_update_audio(delta)

func _step_car(delta: float) -> void:
	var forward := Vector3(sin(heading),0,cos(heading))
	var right := Vector3(forward.z,0,-forward.x)
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var steer_input := Input.get_action_strength("steer_left")-Input.get_action_strength("steer_right")
	var throttle := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var handbrake := Input.is_action_pressed("handbrake")
	steering = lerpf(steering,steer_input,1.0-exp(-5.5*delta))
	var car_power := 0.92+float(car_index)*0.025
	if throttle > 0:
		longitudinal += (ACCELERATION*car_power if longitudinal >= 0 else BRAKE_FORCE)*throttle*delta
	if brake > 0:
		longitudinal -= (BRAKE_FORCE if longitudinal > 0.8 else 11.0)*brake*delta
	if absf(longitudinal) > 0.05:
		longitudinal -= signf(longitudinal)*(DRAG+longitudinal*longitudinal*0.0038)*delta
	else:
		longitudinal = 0
	if handbrake:
		longitudinal = move_toward(longitudinal,0,5.0*delta)
	longitudinal = clampf(longitudinal,-12.0,MAX_SPEED+car_index*0.6)
	var grip := 2.0 if handbrake else (6.0+float(car_index%3)*0.7)
	lateral *= exp(-grip*delta)
	var yaw := steering*(0.30+minf(absf(longitudinal),38)*0.022)*(1.65 if handbrake else 1.0)
	if absf(longitudinal) > 0.25:
		heading += yaw*signf(longitudinal)*delta
	velocity = forward*longitudinal+right*lateral
	car_root.position += velocity*delta
	speed = velocity.length()
	var velocity_heading := atan2(velocity.x,velocity.z)
	slip = wrapf(velocity_heading-heading,-PI,PI) if longitudinal >= 0 else 0.0
	drifting = longitudinal > 11 and absf(slip) > 0.11
	for smoke in tyre_smoke:
		smoke.emitting = drifting or (handbrake and speed > 8)
	for tail in brake_lights:
		tail.light_energy = 1.7 if brake > 0 else 0.18
	collision_cooldown = maxf(0,collision_cooldown-delta)
	var near := track.nearest(car_root.position)
	if absf(float(near["offset"])) > 6.05:
		var side := signf(float(near["offset"]))
		var barrier_normal: Vector3 = near["normal"]*side
		car_root.position = near["point"]+barrier_normal*6.04+Vector3.UP*0.15
		var impact := velocity.dot(barrier_normal)
		if impact > 0:
			velocity -= barrier_normal*impact*1.4
		velocity *= 0.7
		if collision_cooldown <= 0:
			collision_cooldown = 0.8
			combo = 1
			drift_time = 0
			shake = 1
	car_root.rotation.y = heading
	car_body.rotation.z = lerpf(car_body.rotation.z,-steering*speed*0.0018,0.11)
	car_body.rotation.x = lerpf(car_body.rotation.x,0.018 if brake > 0 else -0.006,0.09)
	for wheel in wheel_nodes:
		wheel.rotate_x(-longitudinal*delta/0.34)
	shake = maxf(0,shake-delta*3)

func _step_race(delta: float) -> void:
	race_time += delta
	if drifting:
		drift_time += delta
		combo = clampf(1+drift_time/2,1,5)
		score += speed*absf(slip)*combo*delta*30
	else:
		drift_time = maxf(0,drift_time-delta*2)
		combo = clampf(1+drift_time/2,1,5)
	var index := track.gate_index(next_gate)
	var gp := track.point(index)
	if car_root.position.distance_to(gp) < 8 and velocity.dot(track.tangent(index)) > 1:
		passed += 1
		var finished_gate := next_gate
		next_gate = (next_gate+1)%RACE_GATES
		track.show_gate(next_gate,true)
		if finished_gate == 0:
			lap_times.append(race_time-last_lap)
			last_lap = race_time
			if mode == "coast":
				_finish()
				return
			if mode == "sprint" and lap == 2:
				_finish()
				return
			lap += 1
	if mode == "drift" and race_time >= 90:
		race_time = 90
		_finish()

func _finish() -> void:
	phase = "finished"
	var is_best := false
	if mode == "sprint":
		var total := race_time+penalty
		if best_time <= 0 or total < best_time:
			best_time = total
			is_best = true
	elif mode == "coast":
		var total := race_time+penalty
		if best_coast <= 0 or total < best_coast:
			best_coast = total
			is_best = true
	else:
		if int(score) > best_drift:
			best_drift = int(score)
			is_best = true
	_save()
	result_label.text = (("TIME ATTACK" if mode == "sprint" else "COAST RUN")+"\n"+_format_time(race_time+penalty) if mode in ["sprint","coast"] else "DRIFT SESSION\n"+str(int(score))+" POINTS")+"\n"+("NEW PERSONAL BEST" if is_best else "CHASE THE NEXT RUN")
	_show_ui()

func _format_time(seconds: float) -> String:
	var centiseconds := int(round(seconds*100))
	return "%02d:%02d.%02d" % [centiseconds/6000,(centiseconds/100)%60,centiseconds%100]

func _update_hud() -> void:
	countdown_label.visible = phase == "countdown"
	time_label.text = "FREE DRIVE" if mode == "free" else (_format_time(maxf(0,90-race_time)) if mode == "drift" else _format_time(race_time+penalty))
	lap_label.text = "%02d / 02" % lap if mode == "sprint" else (str(int(score))+" PTS" if mode == "drift" else "OPEN COAST")
	objective_label.text = "THE LAST LIGHT  /  %s" % {"sprint":"TIME ATTACK","drift":"DRIFT SESSION","coast":"COAST RUN","free":"FREE DRIVE"}[mode]
	speed_label.text = "%03d\nKM/H  %s" % [int(speed*3.6),"R" if velocity.dot(Vector3(sin(heading),0,cos(heading))) < -0.5 else "D"]
	score_label.text = "DRIFT +%d  × %.1f" % [int(score),combo] if drifting else ("CHECKPOINT %d / %d" % [RACE_GATES if next_gate == 0 else next_gate,RACE_GATES] if mode != "free" else "EXPLORE THE COAST")

func _update_camera(delta: float, instant: bool) -> void:
	if camera == null or car_root == null:
		return
	var forward := Vector3(sin(heading),0,cos(heading))
	var desired: Vector3
	var target: Vector3
	if phase == "menu":
		var right := Vector3(forward.z,0,-forward.x)
		var orbit_basis := Basis(Vector3.UP,garage_orbit)
		desired = car_root.position+orbit_basis*(forward*5.7+right*5.5)+Vector3.UP*2.8
		var look_direction := (car_root.position-desired).normalized()
		var view_right := look_direction.cross(Vector3.UP).normalized()
		target = car_root.position-view_right*2.4+Vector3.UP*0.9
	else:
		var distance := 7.7 if camera_style == 0 else 4.9
		desired = car_root.position-forward*(distance+speed/MAX_SPEED*1.6)+Vector3.UP*(3.4 if camera_style == 0 else 1.8)
		target = car_root.position+forward*(7+speed/MAX_SPEED*3)+Vector3.UP*0.9
	if shake > 0:
		desired.x += sin(Time.get_ticks_msec()*0.09)*shake*0.12
		desired.y += cos(Time.get_ticks_msec()*0.07)*shake*0.08
	camera.position = desired if instant else camera.position.lerp(desired,1-exp(-6*delta))
	camera.look_at(target,Vector3.UP)
	camera.fov = lerpf(camera.fov,43.0 if phase == "menu" else 55.0+speed/MAX_SPEED*10.0,0.05)

func _make_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = audio_sample_rate
	generator.buffer_length = 0.15
	audio_player.stream = generator
	audio_player.volume_db = -8.0
	add_child(audio_player)

func _toggle_audio() -> void:
	audio_enabled = not audio_enabled
	_save()

func _update_audio(delta: float) -> void:
	if not audio_enabled or phase not in ["racing","countdown"] or audio_playback == null:
		return
	var gear := clampi(1+int(speed/12),1,5)
	if gear != last_gear:
		last_gear = gear
		gear_shift = 0.14
	gear_shift = maxf(0,gear_shift-delta)
	var rpm := 950+fmod(speed,12.0)/12.0*4200.0+(900.0 if Input.is_action_pressed("accelerate") else 0.0)
	var frequency := rpm/60.0*2.0*(0.7 if gear_shift > 0 else 1.0)
	var frames := mini(audio_playback.get_frames_available(),int(audio_sample_rate*delta)+256)
	for i in range(frames):
		audio_phase += TAU*frequency/audio_sample_rate
		if audio_phase > TAU:
			audio_phase -= TAU
		var engine := sin(audio_phase)*0.26+sin(audio_phase*0.5)*0.17+sin(audio_phase*2.0)*0.08
		var wind := randf_range(-1,1)*speed/MAX_SPEED*0.11
		var tyre := randf_range(-1,1)*minf(absf(slip)*0.25,0.2) if drifting else 0.0
		var sample := clampf(engine+wind+tyre,-0.85,0.85)
		audio_playback.push_frame(Vector2(sample,sample))
