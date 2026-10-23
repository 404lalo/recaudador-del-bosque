extends Node3D
## Nivel tutorial (antes del Bosque). Enseña paso a paso: cámara, movimiento, correr, saltar,
## cobrar a un animal (acertijo), el depredador (cultura general) y la tienda de protección.
## Reutiliza player.gd, animal.gd, hud.gd, dialogue_ui.gd y panel_ui.gd.

const NATURE := "res://assets/glTF/%s.gltf"
const CORRIDOR_HALF := 10.0
const PATH_WIDTH := 4.0
const END_Z := -78.0
const ANIMAL_Z := -40.0
const PREDATOR_Z := -56.0
const INTERACT_DIST := 4.5

enum Step { LOOK, WALK, SPRINT, JUMP, TALK, PREDATOR, GATE, DONE }

const STEP_TEXT := {
	Step.LOOK: "Mueve el RATÓN para mirar a tu alrededor.",
	Step.WALK: "Camina con W A S D (o las flechas) hasta el primer cartel.",
	Step.SPRINT: "Mantén SHIFT mientras caminas para correr.",
	Step.JUMP: "Presiona ESPACIO para saltar el tronco.",
	Step.TALK: "Acércate al Perrito Shiba y presiona E para cobrarle.",
	Step.PREDATOR: "Sigue el camino... algo se mueve entre los árboles.",
	Step.GATE: "Cruza el arco dorado para terminar el tutorial.",
	Step.DONE: "¡Tutorial completado!",
}

var step := Step.LOOK
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var hud: CanvasLayer
var dialogue: CanvasLayer
var panel: CanvasLayer
var tutor: Node3D
var objective_label: Label
var step_label: Label
var scene_cache := {}

var _last_yaw := 0.0
var _look_amount := 0.0
var _sprint_time := 0.0
var _talking := false
var pause_menu: CanvasLayer


func _ready() -> void:
	Game.reset()
	rng.seed = 4242
	_build_environment()
	_build_ground()
	_build_props()
	_build_signs()
	_build_log()
	_build_tutor()
	_build_gate()
	_build_ui_and_player()
	_build_objective_ui()
	hud.zone_name = "Tutorial"
	hud.refresh()
	_last_yaw = player.yaw
	Sfx.music("forest")
	_set_step(Step.LOOK)
	hud.toast("¡Bienvenido, recaudador! Antes de salir al bosque, aprendamos lo básico.", 5.0)


# ---------------------------------------------------------------- pasos

func _set_step(s: Step) -> void:
	step = s
	objective_label.text = STEP_TEXT[s]
	step_label.text = "TUTORIAL  ·  Paso %d de %d" % [mini(s + 1, Step.DONE), Step.DONE]


func _process(delta: float) -> void:
	if step == Step.DONE:
		return
	match step:
		Step.LOOK:
			_look_amount += absf(player.yaw - _last_yaw)
			_last_yaw = player.yaw
			if _look_amount > 1.5:
				hud.toast("¡Bien! Si pierdes el ratón, haz clic en la ventana. ESC lo libera.", 4.0)
				_set_step(Step.WALK)
		Step.WALK:
			if player.global_position.z < -8.0:
				hud.toast("Perfecto. Ahora prueba a correr.", 3.0)
				_set_step(Step.SPRINT)
		Step.SPRINT:
			var moving := Vector2(player.velocity.x, player.velocity.z).length() > 8.0
			if moving:
				_sprint_time += delta
			if _sprint_time > 1.2:
				hud.toast("¡Rápido! Correr te ayuda a recorrer los niveles largos.", 3.5)
				_set_step(Step.JUMP)
		Step.JUMP:
			if player.global_position.z < -26.5:
				hud.toast("¡Salto limpio!", 2.5)
				_set_step(Step.TALK)
		Step.TALK:
			_update_talk()
		Step.PREDATOR:
			if player.global_position.z < PREDATOR_Z:
				_run_predator()
		Step.GATE:
			if player.global_position.z < END_Z + 3.0:
				_finish()


func _update_talk() -> void:
	if _talking:
		return
	var d := tutor.global_position.distance_to(player.global_position)
	if d < INTERACT_DIST:
		hud.set_prompt("[E] Hablar con %s" % tutor.species.name)
		if Input.is_action_just_pressed("interact"):
			_start_talk()
	else:
		hud.set_prompt("")


func _start_talk() -> void:
	_talking = true
	hud.set_prompt("")
	player.locked = true
	tutor.face(player.global_position)
	hud.toast("Cada animal te reta con un acertijo. 1er intento = impuesto completo, 2º = 60 %.", 6.0)
	dialogue.start(tutor.species, tutor.tax)
	# Acertijo fijo y fácil solo para el tutorial (se elige después de start()).
	var options := ["Una piedra", "Una nuez", "Una nube", "Un zapato"]
	dialogue.riddle = {
		"q": "Soy pequeña, dura por fuera y rica por dentro. Los animalitos del bosque me guardan para el invierno. ¿Qué soy?",
		"options": options,
		"correct": options.find("Una nuez"),
	}


func _on_dialogue_finished(paid: int, ok: bool, retry: bool) -> void:
	player.locked = false
	_talking = false
	if retry:
		hud.toast("Puedes volver con un animal más tarde, pero debes visitar a todos para avanzar.", 5.0)
		return
	if paid > 0:
		Game.add_money(paid)
		hud.toast("¡Cobraste $%d! Mira tu dinero arriba a la izquierda." % paid, 5.0)
	else:
		hud.toast("Esta vez no pagó. En los niveles reales pierdes ese impuesto, ¡piensa bien!", 5.0)
		Game.add_money(20)  # dinero de práctica para la siguiente lección
	tutor.mark_done(ok)
	_set_step(Step.PREDATOR)


func _run_predator() -> void:
	_set_step(Step.GATE)  # evita volver a disparar el evento
	objective_label.text = "¡Un depredador! Responde su pregunta de cultura general."
	var wolf: Node3D = Node3D.new()
	wolf.set_script(load("res://scripts/animal.gd"))
	wolf.position = player.position + Vector3(-9, 0, -3)
	add_child(wolf)
	wolf.setup({"name": "Lobo", "model": "Wolf", "scale": 1.0}, 0)
	wolf.tag.modulate = Color(1, 0.4, 0.4)
	wolf.face(player.position)
	wolf.play("Gallop")
	player.locked = true
	var tw := create_tween()
	tw.tween_property(wolf, "position", player.position + Vector3(-1.5, 0, -0.5), 1.3)
	await tw.finished
	wolf.face(player.position)
	wolf.play("Idle")
	hud.toast("A mitad de cada nivel aparece un depredador. Si fallas, te roba parte del dinero.\n(Aquí es práctica: no pierdes nada.)", 6.0)
	dialogue.start_trivia("Lobo (práctica)")
	var correct: bool = await dialogue.trivia_finished
	if correct:
		wolf.play("Idle_2")
		hud.toast("¡Correcto! El lobo se va con la cola entre las patas.", 4.0)
	else:
		wolf.play("Attack")
		hud.toast("Fallaste. En un nivel real te habría robado dinero. La protección de la tienda reduce esa pérdida.", 6.0)
	player.locked = false
	objective_label.text = STEP_TEXT[Step.GATE]
	await get_tree().create_timer(2.0).timeout
	wolf.face(wolf.position + Vector3(-50, 0, 0))
	wolf.play("Gallop")
	var tw2 := create_tween()
	tw2.tween_property(wolf, "position", wolf.position + Vector3(-40, 0, 0), 2.5)
	await tw2.finished
	wolf.queue_free()


func _finish() -> void:
	_set_step(Step.DONE)
	Game.mark_tutorial_done()
	player.locked = true
	hud.set_prompt("")
	var body := "Al final de cada zona llegas a la TIENDA.\n\n" + \
		"Ahí puedes gastar lo que cobraste en PROTECCIÓN contra depredadores:\n" + \
		"  · %s ($%d): pierdes menos dinero\n" % [Game.PROT_NAMES[1], Game.PROT_COSTS[1]] + \
		"  · %s ($%d): pierdes mucho menos\n" % [Game.PROT_NAMES[2], Game.PROT_COSTS[2]] + \
		"  · %s ($%d): no pierdes nada\n\n" % [Game.PROT_NAMES[3], Game.PROT_COSTS[3]] + \
		"Recuerda: debes visitar a TODOS los animales de una zona para poder cruzar el arco.\n" + \
		"El dinero del tutorial no se guarda. ¡Buena suerte!"
	panel.show_panel("¡Tutorial completado!", body, [
		{"text": "Empezar: Bosque Susurrante", "cb": _start_game},
		{"text": "Repetir tutorial", "cb": _restart},
		{"text": "Volver al menú", "cb": _to_menu},
	])


func _start_game() -> void:
	if not Api.session_fresh:
		# Vino del botón "Tutorial" (sin partida elegida): que escoja una ranura en el menú.
		Game.open_slots_on_menu = true
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _restart() -> void:
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	# TAB salta el tutorial en cualquier momento.
	if step != Step.DONE and event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_TAB and not dialogue.visible:
		_finish()


# ---------------------------------------------------------------- escenario

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.8, 0.75)
	env.fog_density = 0.008
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	add_child(sun)


func _build_ground() -> void:
	var length := absf(END_Z) + 80.0
	var cz := END_Z / 2.0
	_static_box(Vector3(120, 1, length), Vector3(0, -0.5, cz), Color(0.3, 0.55, 0.25))
	var path := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(PATH_WIDTH, 0.05, absf(END_Z) + 20.0)
	path.mesh = pm
	path.material_override = _color_mat(Color(0.55, 0.42, 0.28))
	path.position = Vector3(0, 0.03, END_Z / 2.0 + 6.0)
	add_child(path)
	_wall(Vector3(1, 10, length), Vector3(-CORRIDOR_HALF - 0.5, 5, cz))
	_wall(Vector3(1, 10, length), Vector3(CORRIDOR_HALF + 0.5, 5, cz))
	_wall(Vector3(CORRIDOR_HALF * 2, 10, 1), Vector3(0, 5, END_Z - 4))
	_wall(Vector3(CORRIDOR_HALF * 2, 10, 1), Vector3(0, 5, 12))


func _build_props() -> void:
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "Pine_1", "Pine_2", "Pine_3"]
	var small := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Flower_3_Group", "Mushroom_Common", "Clover_1"]
	for i in 90:
		var t := _nature(trees[rng.randi() % trees.size()])
		t.position = _random_pos(CORRIDOR_HALF + 2.0, 45.0)
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(0.8, 1.3)
		add_child(t)
	for i in 120:
		var s := _nature(small[rng.randi() % small.size()])
		s.position = _random_pos(PATH_WIDTH / 2.0 + 2.0, 40.0)
		if absf(s.position.z - ANIMAL_Z) < 6.0 and absf(s.position.x) < CORRIDOR_HALF:
			s.position.x = signf(s.position.x) * (CORRIDOR_HALF + 3.0)
		s.rotation.y = rng.randf() * TAU
		s.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
		add_child(s)


func _random_pos(min_x: float, max_x: float) -> Vector3:
	var x := rng.randf_range(min_x, max_x) * (1.0 if rng.randf() > 0.5 else -1.0)
	var z := rng.randf_range(10.0, END_Z - 20.0)
	return Vector3(x, 0, z)


## Carteles de madera con la lección de cada tramo.
func _build_signs() -> void:
	_sign(Vector3(3.2, 0, -4), "WASD / Flechas\npara caminar")
	_sign(Vector3(-3.2, 0, -12), "SHIFT\npara correr")
	_sign(Vector3(3.2, 0, -21), "ESPACIO\npara saltar")
	_sign(Vector3(-3.2, 0, -33), "E\npara hablar")
	_sign(Vector3(3.2, 0, -50), "¡Cuidado!\nDepredadores")


func _sign(pos: Vector3, text: String) -> void:
	var wood := _color_mat(Color(0.45, 0.3, 0.16))
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.08
	cm.height = 2.0
	post.mesh = cm
	post.material_override = wood
	post.position = pos + Vector3(0, 1.0, 0)
	add_child(post)
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 0.9, 0.08)
	board.mesh = bm
	board.material_override = wood
	board.position = pos + Vector3(0, 2.1, 0)
	add_child(board)
	var label := Label3D.new()
	label.text = text
	label.font_size = 40
	label.pixel_size = 0.006
	label.outline_size = 10
	label.position = pos + Vector3(0, 2.1, 0.06)
	add_child(label)


## Tronco atravesado en el camino que obliga a saltar.
func _build_log() -> void:
	var body := StaticBody3D.new()
	body.position = Vector3(0, 0.35, -25.0)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.35
	cm.height = CORRIDOR_HALF * 2.0
	mi.mesh = cm
	mi.material_override = _color_mat(Color(0.4, 0.26, 0.12))
	mi.rotation.z = deg_to_rad(90)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CORRIDOR_HALF * 2.0, 0.7, 0.7)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _build_tutor() -> void:
	var side := -1.0
	var pos := Vector3(side * 6.0, 0, ANIMAL_Z)
	var mound := MeshInstance3D.new()
	mound.mesh = SphereMesh.new()
	mound.material_override = _color_mat(Color(0.35, 0.22, 0.12))
	mound.scale = Vector3(3.0, 1.4, 3.0)
	mound.position = pos + Vector3(side * 2.5, 0, 0)
	add_child(mound)
	var sp: Dictionary = Game.SPECIES["shiba"].duplicate()
	sp["id"] = "shiba"
	sp["name"] = "Shiba Instructor"
	sp["intro"] = "¡Hola, novato! Yo te enseño cómo funciona esto. Así hablarás con cada animal del reino."
	sp["pay_line"] = "¡Eso es! Así se cobra: con ingenio. Toma, mis huesitos de práctica."
	sp["fail_line"] = "No pasa nada, es práctica. Pero en el bosque, si fallas dos veces, el animal no te paga."
	tutor = Node3D.new()
	tutor.set_script(load("res://scripts/animal.gd"))
	tutor.position = pos + Vector3(-side * 1.5, 0, 0)
	add_child(tutor)
	tutor.setup(sp, 20)
	tutor.face(Vector3(0, 0, tutor.position.z))


func _build_gate() -> void:
	var gate_mat := _color_mat(Color(0.95, 0.8, 0.2))
	gate_mat.emission_enabled = true
	gate_mat.emission = Color(0.95, 0.7, 0.1)
	for x in [-3.0, 3.0]:
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.25
		cm.height = 6.0
		post.mesh = cm
		post.material_override = gate_mat
		post.position = Vector3(x, 3.0, END_Z)
		add_child(post)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.5, 0.4, 0.4)
	beam.mesh = bm
	beam.material_override = gate_mat
	beam.position = Vector3(0, 6.0, END_Z)
	add_child(beam)
	var label := Label3D.new()
	label.text = "FIN DEL TUTORIAL"
	label.font_size = 64
	label.outline_size = 14
	label.position = Vector3(0, 7.0, END_Z)
	add_child(label)


# ---------------------------------------------------------------- UI y jugador

func _build_ui_and_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 0.5, 6)
	add_child(player)
	hud = _spawn_layer("res://scripts/hud.gd")
	dialogue = _spawn_layer("res://scripts/dialogue_ui.gd")
	dialogue.finished.connect(_on_dialogue_finished)
	panel = _spawn_layer("res://scripts/panel_ui.gd")
	pause_menu = _spawn_layer("res://scripts/pause_menu.gd")
	pause_menu.host = self
	pause_menu.title_text = "Pausa  ·  Tutorial"
	pause_menu.restart_text = "Reiniciar tutorial"


func _build_objective_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -440
	box.offset_right = -20
	box.offset_top = 20
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	layer.add_child(box)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	box.add_child(margin)
	var vb := VBoxContainer.new()
	margin.add_child(vb)
	step_label = Label.new()
	step_label.add_theme_font_size_override("font_size", 16)
	step_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(step_label)
	objective_label = Label.new()
	objective_label.custom_minimum_size = Vector2(400, 0)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(objective_label)
	var skip := Label.new()
	skip.text = "[TAB] Saltar tutorial"
	skip.add_theme_font_size_override("font_size", 14)
	skip.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(skip)


func _spawn_layer(path: String) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.set_script(load(path))
	add_child(l)
	return l


# ---------------------------------------------------------------- utilidades

func _static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _color_mat(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)


func _color_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _nature(name: String) -> Node3D:
	if not scene_cache.has(name):
		scene_cache[name] = load(NATURE % name)
	return scene_cache[name].instantiate()


# ---------------------------------------------------------------- menú de pausa (pause_menu.gd)

func can_pause() -> bool:
	return step != Step.DONE and not dialogue.visible and not panel.visible


func pause_restart() -> void:
	get_tree().reload_current_scene()


func pause_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
