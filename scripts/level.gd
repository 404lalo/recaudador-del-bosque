extends Node3D
## Nivel lineal: camino con madrigueras de animales a los lados, un evento de depredador
## a mitad de camino y una puerta al final. Todo se construye por código según Game.LEVELS.

const NATURE := "res://assets/glTF/%s.gltf"
const PATH_WIDTH := 4.0
const CORRIDOR_HALF := 14.0
const BURROW_START := 22.0
const BURROW_SPACING := 24.0
const INTERACT_DIST := 4.5

## Biomas: árboles, plantas, colores, niebla, cielo, plataformas y música de cada tipo de nivel.
const THEMES := {
	"forest": {
		"trees": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5",
			"Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"],
		"small": ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Grass_Common_Tall", "Grass_Wispy_Tall",
			"Flower_3_Group", "Flower_4_Group", "Mushroom_Common", "Rock_Medium_1", "Rock_Medium_2", "Clover_1"],
		"ground": Color(0.25, 0.5, 0.2), "path": Color(0.5, 0.38, 0.25),
		"fog": Color(0.6, 0.75, 0.7), "fog_density": 0.006,
		"rock_desert": false, "tree_count": 170, "music": "forest",
		"plat": Color(0.45, 0.4, 0.35), "plat_top": Color(0.3, 0.6, 0.25),
	},
	"desert": {
		"trees": ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"],
		"small": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_1", "Pebble_Round_3",
			"Pebble_Square_2", "Grass_Wispy_Short", "Plant_7"],
		"ground": Color(0.82, 0.68, 0.4), "path": Color(0.68, 0.52, 0.32),
		"fog": Color(0.95, 0.8, 0.6), "fog_density": 0.006,
		"sky_top": Color(0.4, 0.6, 0.9), "sky_horizon": Color(0.95, 0.8, 0.6),
		"rock_desert": true, "tree_count": 45, "music": "desert",
		"plat": Color(0.72, 0.5, 0.3), "plat_top": Color(0.85, 0.7, 0.4),
	},
	"swamp": {
		"trees": ["TwistedTree_1", "TwistedTree_2", "TwistedTree_3", "TwistedTree_4", "TwistedTree_5",
			"DeadTree_1", "DeadTree_2"],
		"small": ["Fern_1", "Mushroom_Laetiporus", "Mushroom_Common", "Grass_Wispy_Tall", "Plant_1_Big",
			"Plant_7_Big", "Rock_Medium_1", "Grass_Common_Tall"],
		"ground": Color(0.2, 0.3, 0.17), "path": Color(0.32, 0.26, 0.18),
		"fog": Color(0.45, 0.55, 0.45), "fog_density": 0.02,
		"sky_top": Color(0.35, 0.45, 0.4), "sky_horizon": Color(0.5, 0.58, 0.5),
		"rock_desert": false, "tree_count": 150, "music": "forest",
		"plat": Color(0.3, 0.32, 0.25), "plat_top": Color(0.25, 0.45, 0.2),
	},
	"meadow": {
		"trees": ["CommonTree_1", "CommonTree_2", "CommonTree_3"],
		"small": ["Flower_3_Group", "Flower_4_Group", "Flower_3_Single", "Flower_4_Single", "Grass_Common_Tall",
			"Grass_Common_Short", "Clover_1", "Clover_2", "Bush_Common_Flowers"],
		"ground": Color(0.48, 0.62, 0.25), "path": Color(0.62, 0.5, 0.3),
		"fog": Color(0.9, 0.85, 0.65), "fog_density": 0.004,
		"sky_top": Color(0.3, 0.55, 0.95), "sky_horizon": Color(0.95, 0.9, 0.7),
		"rock_desert": false, "tree_count": 40, "music": "forest",
		"plat": Color(0.55, 0.45, 0.3), "plat_top": Color(0.55, 0.7, 0.3),
	},
	"autumn": {
		"trees": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5", "TwistedTree_3"],
		"small": ["Bush_Common", "Fern_1", "Mushroom_Common", "Mushroom_Laetiporus", "Rock_Medium_2",
			"Grass_Wispy_Short", "Grass_Wispy_Tall"],
		"ground": Color(0.55, 0.4, 0.18), "path": Color(0.45, 0.3, 0.18),
		"fog": Color(0.85, 0.6, 0.4), "fog_density": 0.008,
		"sky_top": Color(0.38, 0.5, 0.75), "sky_horizon": Color(0.95, 0.65, 0.4),
		"rock_desert": false, "tree_count": 150, "music": "forest",
		"plat": Color(0.45, 0.33, 0.22), "plat_top": Color(0.8, 0.45, 0.15),
	},
	"canyon": {
		"trees": ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"],
		"small": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_2", "Pebble_Round_4",
			"Pebble_Square_3", "Pebble_Square_5", "Plant_7"],
		"ground": Color(0.66, 0.33, 0.2), "path": Color(0.55, 0.3, 0.18),
		"fog": Color(0.85, 0.55, 0.4), "fog_density": 0.007,
		"sky_top": Color(0.35, 0.5, 0.85), "sky_horizon": Color(0.95, 0.65, 0.45),
		"rock_desert": true, "tree_count": 30, "music": "desert",
		"plat": Color(0.6, 0.3, 0.2), "plat_top": Color(0.75, 0.45, 0.28),
	},
	"tundra": {
		"trees": ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"],
		"small": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Round_2", "Grass_Wispy_Short"],
		"ground": Color(0.88, 0.92, 0.96), "path": Color(0.7, 0.75, 0.82),
		"fog": Color(0.9, 0.93, 0.98), "fog_density": 0.012,
		"sky_top": Color(0.55, 0.68, 0.85), "sky_horizon": Color(0.92, 0.95, 1.0),
		"rock_desert": false, "tree_count": 120, "music": "forest",
		"plat": Color(0.7, 0.75, 0.8), "plat_top": Color(0.95, 0.97, 1.0),
	},
	"summit": {
		"trees": ["Pine_1", "Pine_2", "Pine_3", "DeadTree_3"],
		"small": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3", "Pebble_Square_1", "Pebble_Square_4",
			"Grass_Wispy_Short"],
		"ground": Color(0.45, 0.47, 0.5), "path": Color(0.55, 0.52, 0.5),
		"fog": Color(0.75, 0.78, 0.85), "fog_density": 0.01,
		"sky_top": Color(0.25, 0.4, 0.75), "sky_horizon": Color(0.85, 0.8, 0.75),
		"rock_desert": false, "tree_count": 60, "music": "desert",
		"plat": Color(0.5, 0.5, 0.52), "plat_top": Color(0.85, 0.85, 0.9),
	},
}

var info: Dictionary
var theme: Dictionary
var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var hud: CanvasLayer
var dialogue: CanvasLayer
var panel: CanvasLayer
var animals: Array = []
var end_z := 0.0
var current_animal: Node3D
var predator_done := false
var finished_level := false
var scene_cache := {}
var last_near: Node3D
var coins: Array = []
var coins_taken := 0
var coins_total := 0
var elapsed := 0.0
# Bellotas doradas (coleccionables escondidos) y datos para la base de datos.
const ACORNS_PER_LEVEL := 5
var acorns: Array = []
var acorns_taken := 0
var blockers: Array = []   # troncos con colisión dentro del corredor
var level_time := 0.0
var money_in := 0
var paid_count := 0
var pause_menu: CanvasLayer
# Recorrido del jugador (una posición por segundo) y plano del nivel, para el mapa del dashboard.
var traj: Array = []
var traj_timer := 0.0
var platforms_info: Array = []
var predator_z := 0.0
var failed_count := 0


func _ready() -> void:
	info = Game.LEVELS[Game.level_index]
	if Api.session_id != "":  # al probar la escena suelta (F6) no se toca ninguna partida guardada
		Game.save_game()  # checkpoint al entrar a la zona (con el dinero/protección actuales)
	theme = THEMES.get(info.get("theme", info.id), THEMES["forest"])
	rng.seed = hash(info.id)
	end_z = -(BURROW_START + BURROW_SPACING * info.animals.size() + 10.0)
	_build_environment()
	_build_ground()
	_build_props()
	_build_burrows()
	_build_end_gate()
	_build_predator_event()
	_build_platforms()
	_build_acorns()
	_build_ui_and_player()
	hud.level_acorns_total = ACORNS_PER_LEVEL
	hud.refresh()
	for arg in OS.get_cmdline_user_args():  # atajo de desarrollo: -- --z=-20
		if arg.begins_with("--z="):
			player.position.z = float(arg.substr(4))
	Sfx.music(theme.get("music", "forest"))
	money_in = Game.money
	Game.level_time = 0.0
	Game.player_pos = Vector2(player.global_position.x, player.global_position.z)
	Api.track("nivel_inicio", {
		"nivel_idx": Game.level_index,
		"nivel_nombre": info.name,
		"dinero_entrada": money_in,
		"plano": _plano(),
	})
	_sample_position()
	var tier := int(info.get("riddle_tier", 1))
	var hint: String = ["", "", "Los acertijos ahora son más difíciles.", "¡Acertijos de lógica! Piensa antes de responder."][clampi(tier, 0, 3)]
	hud.toast("Nivel %d/%d · %s: cobra a los %d animales. %s" % [
		Game.level_index + 1, Game.LEVELS.size(), info.name, info.animals.size(), hint], 6.0)


# ---------------------------------------------------------------- escenario

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	if theme.has("sky_top"):
		sky_mat.sky_top_color = theme.sky_top
		sky_mat.sky_horizon_color = theme.sky_horizon
		sky_mat.ground_horizon_color = theme.sky_horizon
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = theme.fog
	env.fog_density = theme.get("fog_density", 0.006)
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
	var length := absf(end_z) + 120.0
	var cz := end_z / 2.0
	_static_box(Vector3(160, 1, length), Vector3(0, -0.5, cz), theme.ground)
	var path := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(PATH_WIDTH, 0.05, absf(end_z) + 30.0)
	path.mesh = pm
	path.material_override = _color_mat(theme.path)
	path.position = Vector3(0, 0.03, end_z / 2.0 + 10.0)
	add_child(path)
	# Muros invisibles que mantienen al jugador en el corredor.
	_wall(Vector3(1, 10, length), Vector3(-CORRIDOR_HALF - 0.5, 5, cz))
	_wall(Vector3(1, 10, length), Vector3(CORRIDOR_HALF + 0.5, 5, cz))
	_wall(Vector3(CORRIDOR_HALF * 2, 10, 1), Vector3(0, 5, end_z - 4))
	_wall(Vector3(CORRIDOR_HALF * 2, 10, 1), Vector3(0, 5, 12))


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
	var inst: Node3D = scene_cache[name].instantiate()
	if theme.rock_desert and name.begins_with("Rock"):
		_apply_desert_rock(inst)
	return inst


func _apply_desert_rock(n: Node) -> void:
	if n is MeshInstance3D:
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/glTF/Rocks_Desert_Diffuse.png")
		n.material_override = m
	for c in n.get_children():
		_apply_desert_rock(c)


func _build_props() -> void:
	var length := absf(end_z) + 60.0
	var tree_count: int = theme.tree_count
	var small_count := 220
	for i in tree_count:
		var pos := _random_pos(length)
		var t := _nature(theme.trees[rng.randi() % theme.trees.size()])
		t.position = pos
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(0.8, 1.4)
		add_child(t)
		if absf(pos.x) < CORRIDOR_HALF:
			blockers.append(pos)
			var body := StaticBody3D.new()
			body.position = pos
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.7
			cyl.height = 6.0
			cs.shape = cyl
			cs.position.y = 3.0
			body.add_child(cs)
			add_child(body)
	for i in small_count:
		var s := _nature(theme.small[rng.randi() % theme.small.size()])
		s.position = _random_pos(length)
		s.rotation.y = rng.randf() * TAU
		s.scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
		add_child(s)


func _random_pos(length: float) -> Vector3:
	# Evita el camino, el punto de inicio (la cámara queda atrás) y la zona de cada madriguera.
	var pos := Vector3.ZERO
	for attempt in 30:
		var x := rng.randf_range(PATH_WIDTH / 2.0 + 2.5, 55.0) * (1.0 if rng.randf() > 0.5 else -1.0)
		var z := rng.randf_range(10.0, -length)
		pos = Vector3(x, 0, z)
		if _prop_position_ok(pos):
			break
	return pos


func _prop_position_ok(pos: Vector3) -> bool:
	if pos.z > -6.0 and absf(pos.x) < CORRIDOR_HALF + 2.0:
		return false
	for i in info.animals.size():
		var bz: float = -(BURROW_START + BURROW_SPACING * i)
		if absf(pos.z - bz) < 7.0 and absf(pos.x) < CORRIDOR_HALF:
			return false
	for i in _platform_zone_count():
		if absf(pos.z - _platform_zone_z(i)) < 12.0 and absf(pos.x) < CORRIDOR_HALF + 1.0:
			return false
	return true


func _build_burrows() -> void:
	var brown := _color_mat(Color(0.35, 0.22, 0.12))
	var dark := _color_mat(Color(0.03, 0.02, 0.02))
	for i in info.animals.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * 8.0, 0, -(BURROW_START + BURROW_SPACING * i))
		# Madriguera: montículo + boca oscura.
		var mound := MeshInstance3D.new()
		var sm := SphereMesh.new()
		mound.mesh = sm
		mound.material_override = brown
		mound.scale = Vector3(3.0, 1.4, 3.0)
		mound.position = pos + Vector3(side * 2.5, 0.0, 0)
		add_child(mound)
		var hole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.8
		cm.bottom_radius = 0.8
		cm.height = 0.05
		hole.mesh = cm
		hole.material_override = dark
		hole.position = pos + Vector3(side * 0.6, 0.05, 0)
		hole.rotation.z = deg_to_rad(90)
		hole.position.y = 0.6
		add_child(hole)
		# Animal.
		var sp: Dictionary = Game.SPECIES[info.animals[i]].duplicate()
		sp["id"] = info.animals[i]
		var a := Node3D.new()
		a.set_script(load("res://scripts/animal.gd"))
		a.position = pos + Vector3(-side * 1.5, 0, 0)
		add_child(a)
		a.setup(sp, int(round(sp.tax * info.tax_mult)))
		a.face(Vector3(0, 0, a.position.z))
		animals.append(a)


func _build_end_gate() -> void:
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
		post.position = Vector3(x, 3.0, end_z)
		add_child(post)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.5, 0.4, 0.4)
	beam.mesh = bm
	beam.material_override = gate_mat
	beam.position = Vector3(0, 6.0, end_z)
	add_child(beam)
	var label := Label3D.new()
	label.text = "SIGUIENTE ZONA" if Game.level_index < Game.LEVELS.size() - 1 else "FIN DEL RECORRIDO"
	label.font_size = 64
	label.outline_size = 14
	label.position = Vector3(0, 7.0, end_z)
	add_child(label)


func _build_predator_event() -> void:
	var area := Area3D.new()
	area.position = Vector3(0, 2, -(BURROW_START + BURROW_SPACING * (info.animals.size() - 1) / 2.0 + 12.0))
	predator_z = area.position.z
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(CORRIDOR_HALF * 2, 4, 2)
	cs.shape = bs
	area.add_child(cs)
	area.body_entered.connect(_on_predator_zone)
	add_child(area)


func _on_predator_zone(body: Node) -> void:
	if body != player or predator_done:
		return
	predator_done = true
	var wolf: Node3D = Node3D.new()
	wolf.set_script(load("res://scripts/animal.gd"))
	wolf.position = player.position + Vector3(-10, 0, -3)
	add_child(wolf)
	var sp := {"name": info.predator, "model": "Wolf", "scale": 1.0}
	wolf.setup(sp, 0)
	wolf.tag.modulate = Color(1, 0.4, 0.4)
	wolf.face(player.position)
	wolf.play("Gallop")
	Sfx.play("alarm")
	hud.toast("¡Un %s se acerca!" % info.predator.to_lower(), 2.0)
	var tw := create_tween()
	tw.tween_property(wolf, "position", player.position + Vector3(-1.5, 0, -0.5), 1.4)
	await tw.finished
	wolf.face(player.position)
	wolf.play("Idle")
	Sfx.play("growl")
	Game.shake(0.65)
	player.locked = true
	hud.toast("¡Un %s te corta el paso! Responde su pregunta o te robará." % info.predator.to_lower(), 3.0)
	dialogue.start_trivia(info.predator)
	var correct: bool = await dialogue.trivia_finished
	player.locked = false
	var stolen := 0
	if correct:
		Sfx.play("good")
		wolf.play("Idle_2")
		hud.toast("%s: \"%s\"" % [info.predator, Game.PREDATOR_DEFEATS.pick_random()], 4.5)
	else:
		Sfx.play("bad")
		wolf.play("Attack")
		Game.shake(1.0 if Game.money > 0 else 0.7)
		var loss := int(Game.money * float(info.get("steal", 0.4)) * Game.PROT_LOSS[Game.protection])
		var taunt: String = Game.PREDATOR_TAUNTS.pick_random()
		if Game.money == 0:
			hud.toast("%s: \"%s\" (Menos mal que no llevas dinero.)" % [info.predator, taunt], 5.0)
		elif loss == 0:
			hud.toast("%s: \"%s\" ...pero tu %s lo ahuyenta. No pierdes nada." % [
				info.predator, taunt, Game.PROT_NAMES[Game.protection].to_lower()], 5.5)
		else:
			Game.add_money(-loss)
			stolen = loss
			hud.toast("%s: \"%s\" Te roba $%d." % [info.predator, taunt, loss], 5.5)
	var t: Dictionary = dialogue.trivia
	Api.track("depredador", {
		"depredador": info.predator,
		"pregunta": t.get("q", ""),
		"respuesta": t.options[dialogue.trivia_choice] if dialogue.trivia_choice >= 0 else "",
		"correcta": correct,
		"perdida": stolen,
	})
	await get_tree().create_timer(2.5).timeout
	wolf.face(player.position + Vector3(-50, 0, 0))
	wolf.play("Gallop")
	var tw2 := create_tween()
	tw2.tween_property(wolf, "position", wolf.position + Vector3(-40, 0, 0), 2.5)
	await tw2.finished
	wolf.queue_free()


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
	pause_menu.title_text = "Pausa  ·  %s" % info.name


func _spawn_layer(path: String) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.set_script(load(path))
	add_child(l)
	return l


func _process(delta: float) -> void:
	_animate_coins(delta)
	_animate_acorns(delta)
	if not finished_level:
		level_time += delta
		Game.play_time += delta
		Game.level_time = level_time
		Game.player_pos = Vector2(player.global_position.x, player.global_position.z)
		traj_timer += delta
		if traj_timer >= 1.0:
			traj_timer -= 1.0
			_sample_position()
	if finished_level or dialogue.visible:
		return
	current_animal = null
	var best := INTERACT_DIST
	for a in animals:
		if a.done:
			continue
		var d: float = a.global_position.distance_to(player.global_position)
		if d < best:
			best = d
			current_animal = a
	if current_animal:
		hud.set_prompt("[E] Hablar con %s" % current_animal.species.name)
		if current_animal != last_near:
			Sfx.play("blip", 1.4)
		last_near = current_animal
		if Input.is_action_just_pressed("interact"):
			_start_dialogue(current_animal)
	else:
		hud.set_prompt("")
		last_near = null
	if player.global_position.z < end_z + 4.0:
		_try_finish_level()


func _start_dialogue(a: Node3D) -> void:
	hud.set_prompt("")
	player.locked = true
	a.face(player.global_position)
	dialogue.start(a.species, a.tax)


func _on_dialogue_finished(paid: int, ok: bool, retry: bool) -> void:
	player.locked = false
	var a := current_animal
	if retry:
		Api.track("cobro_pospuesto", {"animal": a.species.name})
		return
	Api.track("cobro", {"animal": a.species.name, "impuesto": a.tax, "pagado": paid, "ok": ok})
	if paid > 0:
		paid_count += 1
	else:
		failed_count += 1
	if paid > 0:
		Game.add_money(paid)
		hud.toast("Cobraste $%d" % paid)
		Sfx.play("bigcoin")
		Game.vibrate(Game.VIBRATION_MS.media, 0.6)
	elif not ok:
		Sfx.play("bad")
	a.mark_done(ok)


func _try_finish_level() -> void:
	for a in animals:
		if not a.done:
			if not hud.toast_label.text.begins_with("Aún"):
				hud.toast("Aún te faltan animales por visitar en este nivel.", 3.0)
			return
	finished_level = true
	player.locked = true
	hud.set_prompt("")
	Sfx.play("win")
	_send_trajectory()
	Api.track("nivel_fin", {
		"nivel_idx": Game.level_index,
		"nivel_nombre": info.name,
		"duracion_seg": snappedf(level_time, 0.1),
		"dinero_entrada": money_in,
		"dinero_salida": Game.money,
		"animales_pagaron": paid_count,
		"animales_fallaron": failed_count,
		"bellotas": acorns_taken,
		"monedas": coins_taken,
	})
	Api.flush()
	_show_shop()


func _show_shop() -> void:
	var has_next := Game.level_index < Game.LEVELS.size() - 1
	var cost := Game.next_protection_cost()
	var body := "Dinero: $%d\nProtección actual: %s\n\nUn depredador te pone una prueba de cultura general a mitad de camino; si fallas, te roba parte del dinero. Mejorar tu protección reduce la pérdida." % [
		Game.money, Game.PROT_NAMES[Game.protection]]
	var items := []
	if cost >= 0:
		items.append({
			"text": "Comprar: %s ($%d)" % [Game.PROT_NAMES[Game.protection + 1], cost],
			"disabled": Game.money < cost,
			"cb": _buy,
		})
	items.append({
		"text": "Siguiente zona" if has_next else "Terminar recorrido",
		"cb": _continue if has_next else _show_ending,
	})
	panel.show_panel("Zona completada: %s" % info.name, body, items)


func _buy() -> void:
	var cost := Game.next_protection_cost()
	if Game.buy_protection():
		Api.track("compra", {"nombre": Game.PROT_NAMES[Game.protection], "costo": cost, "proteccion": Game.protection})
	Sfx.play("shop")
	_show_shop()


func _continue() -> void:
	Game.level_index += 1
	get_tree().change_scene_to_file("res://scenes/level.tscn")


func _show_ending() -> void:
	Game.save_game(true)  # la ranura queda marcada como recorrido completado
	Api.track("partida_fin", {"completada": true})
	Api.flush()
	var body := "Recaudaste en total $%d.\nDinero en mano: $%d.\n\nGracias por jugar el prototipo." % [
		Game.total_collected, Game.money]
	panel.show_panel("¡Recorrido completado!", body, [
		{"text": "Volver al menú", "cb": _to_menu},
	])


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ---------------------------------------------------------------- plataformas y monedas

## Zonas de plataformas: una entre cada par de madrigueras (y una tras la última).
func _platform_zone_count() -> int:
	return info.animals.size()


func _platform_zone_z(i: int) -> float:
	return -(BURROW_START + BURROW_SPACING * (i + 0.5))


func _build_platforms() -> void:
	var rock := _color_mat(theme.plat)
	var moss := _color_mat(theme.plat_top)
	for i in _platform_zone_count():
		var side := 1.0 if i % 2 == 0 else -1.0  # al revés que la madriguera cercana
		var z := _platform_zone_z(i)
		var variant := i % 3
		# Escalera de plataformas paralela al camino, cada una ~1.3 m más alta que la anterior.
		var steps := 3 + variant
		var z0 := z + (steps - 1) * 3.4 / 2.0
		for s in steps:
			var h := 1.3 * (s + 1)
			var pos := Vector3(side * 7.0, h, z0 - s * 3.4)
			var moving := variant == 2 and s == steps - 2
			_platform(pos, Vector3(2.6, 0.5, 2.6), rock, moss, moving)
			if s < steps - 1:
				_add_coin(pos + Vector3(0, 1.2, 0), 5)
			else:
				# Cima: moneda grande de bonus y un cartel.
				_add_coin(pos + Vector3(0, 1.6, 0), 25, true)
				var lbl := Label3D.new()
				lbl.text = "¡BONUS!"
				lbl.font_size = 48
				lbl.outline_size = 10
				lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				lbl.position = pos + Vector3(0, 2.8, 0)
				add_child(lbl)
		# Tira de monedas en el camino para guiar al jugador.
		for k in 5:
			_add_coin(Vector3(0, 0.9, z + 6.0 - k * 3.0), 2)
		# Arco de monedas que invita al doble salto sobre el camino.
		for k in 5:
			var t := k / 4.0
			_add_coin(Vector3(side * -2.0, 1.0 + sin(t * PI) * 2.6, z - 8.0 - k * 1.4), 3)


func _platform(pos: Vector3, size: Vector3, mat: Material, top_mat: Material, moving: bool) -> Node3D:
	var body: Node3D
	if moving:
		var ab := AnimatableBody3D.new()
		ab.sync_to_physics = true
		body = ab
	else:
		body = StaticBody3D.new()
	body.position = pos
	platforms_info.append({"x": snappedf(pos.x, 0.01), "z": snappedf(pos.z, 0.01), "w": size.x, "d": size.z,
		"h": snappedf(pos.y, 0.01), "movil": moving})
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(size.x + 0.1, 0.12, size.z + 0.1)
	cap.mesh = cm
	cap.material_override = top_mat
	cap.position.y = size.y / 2.0
	body.add_child(cap)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	if moving:
		var tw := create_tween().set_loops()
		tw.tween_property(body, "position:x", pos.x + 2.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(body, "position:x", pos.x - 2.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return body


func _add_coin(pos: Vector3, value: int, big := false) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_meta("value", value)
	area.set_meta("base_y", pos.y)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.45 if big else 0.28
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 0.08
	mi.mesh = cyl
	mi.rotation.x = deg_to_rad(90)
	var m := _color_mat(Color(1.0, 0.8, 0.15))
	m.metallic = 0.8
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.1)
	m.emission_energy_multiplier = 0.8
	mi.material_override = m
	area.add_child(mi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.9 if big else 0.7
	cs.shape = ss
	area.add_child(cs)
	area.body_entered.connect(_on_coin_entered.bind(area))
	add_child(area)
	coins.append(area)
	coins_total += 1


func _on_coin_entered(body: Node, coin: Area3D) -> void:
	if body != player or not coin.visible:
		return
	var value: int = coin.get_meta("value")
	coin.visible = false
	coin.set_deferred("monitoring", false)
	coins.erase(coin)
	coins_taken += 1
	Game.coins += 1
	Game.add_money(value)
	Api.track("moneda", {"valor": value, "bonus": value >= 25})
	if value >= 25:
		Sfx.play("bigcoin")
		Game.vibrate(Game.VIBRATION_MS.media, 0.6)
		hud.toast("¡Bonus! +$%d  (monedas: %d/%d)" % [value, coins_taken, coins_total], 2.5)
	else:
		Sfx.play("coin", 1.0 + minf(coins_taken, 10) * 0.02, -4.0)
		Game.vibrate(Game.VIBRATION_MS.suave, 0.35)
	coin.queue_free()


func _animate_coins(delta: float) -> void:
	elapsed += delta
	for c in coins:
		if is_instance_valid(c):
			c.rotation.y += delta * 3.0
			c.position.y = c.get_meta("base_y") + sin(elapsed * 2.5 + c.position.x) * 0.12


# ---------------------------------------------------------------- bellotas doradas (coleccionables)

## 5 bellotas por nivel, escondidas en las orillas del corredor (lejos del camino),
## repartidas a lo largo del recorrido. Su posición es fija para cada nivel.
func _build_acorns() -> void:
	var arng := RandomNumberGenerator.new()
	arng.seed = hash(info.id + "_bellotas")
	var length := absf(end_z) - 16.0
	for i in ACORNS_PER_LEVEL:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3.ZERO
		for attempt in 40:
			var z := -8.0 - length * (i + arng.randf_range(0.2, 0.8)) / ACORNS_PER_LEVEL
			var x := side * arng.randf_range(CORRIDOR_HALF - 3.0, CORRIDOR_HALF - 1.0)
			pos = Vector3(x, 0.55, z)
			if _acorn_spot_ok(pos):
				break
		_add_acorn("%s_%d" % [info.id, i], pos)


func _acorn_spot_ok(pos: Vector3) -> bool:
	for b in blockers:
		if Vector2(b.x - pos.x, b.z - pos.z).length() < 2.2:
			return false
	for a in animals:
		if a.position.distance_to(pos) < 4.0:
			return false
	return true


func _add_acorn(id: String, pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.set_meta("id", id)
	area.set_meta("base_y", pos.y)
	var gold := _color_mat(Color(0.95, 0.68, 0.18))
	gold.metallic = 0.7
	gold.roughness = 0.35
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.6, 0.1)
	gold.emission_energy_multiplier = 1.2
	var cap_mat := _color_mat(Color(0.45, 0.28, 0.1))
	cap_mat.emission_enabled = true
	cap_mat.emission = Color(0.35, 0.2, 0.05)
	var model := Node3D.new()
	model.scale = Vector3.ONE * 1.3
	area.add_child(model)
	var nut := MeshInstance3D.new()
	nut.mesh = SphereMesh.new()
	nut.scale = Vector3(0.42, 0.52, 0.42)
	nut.material_override = gold
	model.add_child(nut)
	var cap := MeshInstance3D.new()
	cap.mesh = SphereMesh.new()
	cap.scale = Vector3(0.48, 0.22, 0.48)
	cap.position.y = 0.17
	cap.material_override = cap_mat
	model.add_child(cap)
	var stem := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.04
	cm.height = 0.14
	stem.mesh = cm
	stem.position.y = 0.32
	stem.material_override = cap_mat
	model.add_child(stem)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.3)
	glow.light_energy = 0.8
	glow.omni_range = 2.2
	area.add_child(glow)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.9
	cs.shape = ss
	area.add_child(cs)
	area.body_entered.connect(_on_acorn_entered.bind(area))
	add_child(area)
	acorns.append(area)


func _on_acorn_entered(body: Node, acorn: Area3D) -> void:
	if body != player or not acorn.visible:
		return
	acorn.visible = false
	acorn.set_deferred("monitoring", false)
	acorns.erase(acorn)
	acorns_taken += 1
	Game.acorns += 1
	hud.level_acorns = acorns_taken
	hud.refresh()
	Sfx.play("bigcoin", 1.35)
	Game.vibrate(Game.VIBRATION_MS.media, 0.7)
	if acorns_taken == ACORNS_PER_LEVEL:
		hud.toast("¡Encontraste todas las bellotas doradas de esta zona!", 3.5)
	else:
		hud.toast("¡Bellota dorada! %d/%d" % [acorns_taken, ACORNS_PER_LEVEL], 2.5)
	Api.track("bellota", {"id": acorn.get_meta("id"), "en_nivel": acorns_taken, "total_nivel": ACORNS_PER_LEVEL})
	acorn.queue_free()


func _animate_acorns(delta: float) -> void:
	for a in acorns:
		if is_instance_valid(a):
			a.rotation.y += delta * 1.8
			a.position.y = a.get_meta("base_y") + sin(elapsed * 2.0 + a.position.z) * 0.15


# ---------------------------------------------------------------- menú de pausa (pause_menu.gd)

func can_pause() -> bool:
	return not finished_level and not dialogue.visible and not panel.visible


## Reinicia la zona desde el checkpoint (dinero/protección con los que se entró).
func pause_restart() -> void:
	_send_trajectory()
	Api.track("nivel_reinicio", {"nivel_nombre": info.name, "segundos_en_nivel": snappedf(level_time, 0.1)})
	var keep_time := Game.play_time  # el tiempo jugado no se pierde al reiniciar
	if Game.load_game():
		Game.play_time = keep_time
	get_tree().reload_current_scene()


## Sale al menú principal. La partida queda guardada desde el inicio de esta zona.
func pause_quit() -> void:
	_send_trajectory()
	Api.track("salida_menu", {"nivel_nombre": info.name, "segundos_en_nivel": snappedf(level_time, 0.1)})
	Api.flush()
	Game.update_save_time()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")



# ---------------------------------------------------------------- datos para el mapa del dashboard

## Guarda la posición actual; cada 10 posiciones las manda al servidor.
func _sample_position() -> void:
	var p := player.global_position
	traj.append([snappedf(level_time, 0.1), snappedf(p.x, 0.01), snappedf(p.z, 0.01)])
	if traj.size() >= 10:
		_send_trajectory()


func _send_trajectory() -> void:
	if traj.is_empty():
		return
	Api.track("trayectoria", {"puntos": traj.duplicate()})
	traj.clear()


## Plano del nivel: posición de lo importante, para que la web lo dibuje sin conocer el código.
func _plano() -> Dictionary:
	var animales := []
	for a in animals:
		animales.append({"id": a.species.id, "nombre": a.species.name,
			"x": snappedf(a.position.x, 0.01), "z": snappedf(a.position.z, 0.01)})
	var bellotas := []
	for b in acorns:
		bellotas.append({"id": b.get_meta("id"), "x": snappedf(b.position.x, 0.01), "z": snappedf(b.position.z, 0.01)})
	return {
		"start_z": 6.0, "end_z": end_z, "half": CORRIDOR_HALF, "path_w": PATH_WIDTH,
		"depredador_z": predator_z, "animales": animales, "bellotas": bellotas, "plataformas": platforms_info,
	}
