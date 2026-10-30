extends Control
## Menú principal: escena 3D del bosque de fondo (cámara orbitando) + panel con botones.

const NATURE := "res://assets/glTF/%s.gltf"
const GOLD := Color(1.0, 0.82, 0.32)
const CREAM := Color(0.98, 0.94, 0.84)
const DARK_GREEN := Color(0.07, 0.14, 0.09)

var cam: Camera3D
var cam_angle := 0.0
var world: Node3D
var rng := RandomNumberGenerator.new()
var scene_cache := {}
var buttons_box: VBoxContainer
var modal: Control           # ventana abierta encima del menú (nombre / leaderboard)
var first_button: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rng.seed = 777
	_build_background()
	_build_overlay()
	_build_ui()
	_intro_animation()
	Sfx.music("menu")


# ---------------------------------------------------------------- fondo 3D

func _build_background() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_4X
	svc.add_child(sv)
	world = Node3D.new()
	sv.add_child(world)

	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.52, 0.78)
	sky_mat.sky_horizon_color = Color(0.95, 0.78, 0.55)
	sky_mat.ground_horizon_color = Color(0.95, 0.78, 0.55)
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.92, 0.78, 0.58)
	env.fog_density = 0.009
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, -60, 0)  # sol bajo de atardecer
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)

	# Suelo y camino.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	ground.material_override = _mat(Color(0.27, 0.5, 0.22))
	world.add_child(ground)
	var path := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.5, 0.04, 80)
	path.mesh = bm
	path.material_override = _mat(Color(0.55, 0.42, 0.28))
	path.position = Vector3(0, 0.02, -20)
	world.add_child(path)
	for i in 14:
		var r := _nature("RockPath_Round_Small_%d" % (1 + i % 3))
		r.position = Vector3(rng.randf_range(-1.2, 1.2), 0.03, 6 - i * 2.2)
		r.rotation.y = rng.randf() * TAU
		world.add_child(r)

	# Árboles alrededor del claro.
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "Pine_1", "Pine_2",
		"Pine_3", "TwistedTree_1", "TwistedTree_3"]
	for i in 120:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(14.5, 45.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if absf(p.x) < 3.0 and p.z < 0:
			continue  # deja libre el camino
		var t := _nature(trees[rng.randi() % trees.size()])
		t.position = p
		t.rotation.y = rng.randf() * TAU
		t.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
		world.add_child(t)
	var small := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Flower_3_Group", "Flower_4_Group",
		"Mushroom_Common", "Grass_Common_Tall", "Grass_Wispy_Tall", "Clover_1", "Rock_Medium_1", "Plant_1"]
	for i in 160:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(4.5, 30.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		if absf(p.x) < 2.2 or (dist > 8.5 and dist < 13.5):
			continue  # libre el camino y el anillo por donde pasa la cámara
		var s := _nature(small[rng.randi() % small.size()])
		s.position = p
		s.rotation.y = rng.randf() * TAU
		s.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		world.add_child(s)

	# Madriguera.
	var mound := MeshInstance3D.new()
	mound.mesh = SphereMesh.new()
	mound.material_override = _mat(Color(0.35, 0.22, 0.12))
	mound.scale = Vector3(3.0, 1.4, 3.0)
	mound.position = Vector3(-6.5, 0, -1.5)
	world.add_child(mound)

	# El recaudador frente a los animales.
	var collector := _build_collector()
	collector.position = Vector3(0.6, 0, 1.2)
	collector.rotation.y = deg_to_rad(200)
	world.add_child(collector)

	# Animales del bosque en el claro.
	_animal("Fox", 1.0, Vector3(-2.4, 0, -1.2), "Idle_2")
	_animal("ShibaInu", 0.55, Vector3(-4.2, 0, 0.6), "Eating")
	_animal("Husky", 0.6, Vector3(2.8, 0, -1.8), "Idle")
	_animal("Stag", 0.9, Vector3(5.5, 0, -5.0), "Idle_2_HeadLow")
	_animal("Bull", 1.2, Vector3(-5.0, 0, -6.5), "Idle")
	_animal("Wolf", 1.0, Vector3(9.0, 0, -12.0), "Idle", true)

	cam = Camera3D.new()
	cam.fov = 55
	world.add_child(cam)
	_update_camera(0.0)


func _build_collector() -> Node3D:
	var root := Node3D.new()
	var coat := _mat(Color(0.15, 0.25, 0.55))
	var skin := _mat(Color(0.95, 0.8, 0.65))
	var hat := _mat(Color(0.08, 0.08, 0.1))
	var gold := _mat(Color(0.95, 0.75, 0.15))
	gold.metallic = 0.6
	_part(root, CapsuleMesh.new(), coat, Vector3(0, 0.85, 0), Vector3(0.4, 0.8, 0.4))
	_part(root, SphereMesh.new(), skin, Vector3(0, 1.75, 0), Vector3(0.5, 0.5, 0.5))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.38
	brim.bottom_radius = 0.38
	brim.height = 0.05
	_part(root, brim, hat, Vector3(0, 1.95, 0))
	var top := CylinderMesh.new()
	top.top_radius = 0.22
	top.bottom_radius = 0.22
	top.height = 0.35
	_part(root, top, hat, Vector3(0, 2.15, 0))
	_part(root, SphereMesh.new(), gold, Vector3(0.45, 0.9, 0.1), Vector3(0.3, 0.3, 0.3))
	return root


func _part(root: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	root.add_child(mi)


func _animal(model: String, scl: float, pos: Vector3, anim_name: String, look_far := false) -> void:
	var a: Node3D = (load("res://assets/animals/%s.gltf" % model) as PackedScene).instantiate()
	a.scale = Vector3.ONE * scl
	a.position = pos
	var target := Vector3(0, 0, 0) if look_far else Vector3(0.6, 0, 1.2)
	var d := target - pos
	a.rotation.y = atan2(d.x, d.z)
	world.add_child(a)
	var ap := _find_anim(a)
	if ap and ap.has_animation(anim_name):
		ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim_name)
		ap.seek(rng.randf() * 1.5, true)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


func _process(delta: float) -> void:
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	cam_angle += delta * 0.06
	var radius := 11.0
	var ang := cam_angle + 0.6
	cam.position = Vector3(sin(ang) * radius, 3.2 + sin(cam_angle * 0.7) * 0.4, cos(ang) * radius)
	cam.look_at(Vector3(0, 1.0, -1.0))


# ---------------------------------------------------------------- overlay y UI

func _build_overlay() -> void:
	# Viñeta radial para que el texto se lea sobre el fondo.
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0.02, 0.05, 0.03, 0.85))
	g.set_offset(0, 0.25)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.1, 1.1)
	tex.width = 256
	tex.height = 256
	var vig := TextureRect.new()
	vig.texture = tex
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	center.add_child(col)

	var studio := _text("4 T N A T U R E   P R E S E N T A", 17, GOLD.lerp(CREAM, 0.4))
	studio.add_theme_constant_override("outline_size", 8)
	studio.modulate.a = 0.85
	col.add_child(studio)
	var title := _text("Recaudador del Bosque", 76, GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.03))
	title.add_theme_constant_override("outline_size", 22)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 6)
	col.add_child(title)
	var tagline := _text("Cobra impuestos a los animales del reino... si puedes resolver sus acertijos.", 21, CREAM)
	tagline.add_theme_constant_override("outline_size", 10)
	tagline.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.04, 0.95))
	col.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	col.add_child(spacer)

	# Tarjeta con los botones.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(DARK_GREEN, 0.78)
	cs.border_color = Color(GOLD, 0.55)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(18)
	cs.shadow_color = Color(0, 0, 0, 0.45)
	cs.shadow_size = 18
	cs.content_margin_left = 34
	cs.content_margin_right = 34
	cs.content_margin_top = 20
	cs.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", cs)
	col.add_child(card)
	buttons_box = VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 10)
	card.add_child(buttons_box)

	_fill_buttons()

	# Controles al pie de la pantalla.
	var hint_text := "WASD mover   ·   Shift correr   ·   Q dash   ·   Espacio saltar (doble salto)   ·   E interactuar   ·   Ratón cámara"
	if Game.touch_active():
		hint_text = "Joystick mover (a fondo = correr)   ·   SALTAR / DASH / HABLAR   ·   Arrastra a la derecha para mirar"
	var hint := _text(hint_text, 16, CREAM)
	hint.modulate.a = 0.85
	hint.add_theme_constant_override("outline_size", 8)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -34
	hint.offset_bottom = -8
	hint.offset_left = -500
	hint.offset_right = 500
	add_child(hint)



## Botones del menú principal (se vuelven a armar si se borra una partida).
func _fill_buttons() -> void:
	var first: Button = null
	var last := Game.last_slot()
	if last > 0:
		first = _menu_button("Continuar", true)
		first.pressed.connect(_continue_slot.bind(last))
		var ld := Game.peek_save(last)
		var lidx := clampi(int(ld.get("level_index", 0)), 0, Game.LEVELS.size() - 1)
		var detail := _text("Partida %d  ·  %s  ·  %s  ·  $%d" % [last, str(ld.get("player", "")),
			Game.LEVELS[lidx].name, int(ld.get("money", 0))], 15, CREAM)
		detail.modulate.a = 0.8
		buttons_box.add_child(detail)
	var games := _menu_button("Partidas", first == null)
	games.pressed.connect(_show_slots)
	if first == null:
		first = games
	var tut := _menu_button("Tutorial")
	tut.pressed.connect(_play_tutorial)
	var lb := _menu_button("Leaderboard")
	lb.pressed.connect(_show_leaderboard.bind("recaudado"))
	var settings := _menu_button("Ajustes")
	settings.pressed.connect(_show_settings)
	var quit := _menu_button("Salir")
	quit.pressed.connect(_quit)
	first_button = first
	first.grab_focus.call_deferred()
	if Game.open_slots_on_menu:
		Game.open_slots_on_menu = false
		_show_slots.call_deferred()


func _text(t: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _menu_button(t: String, primary := false, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(340, 58 if primary else 50)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 26 if primary else 21)
	var base := Color(0.85, 0.62, 0.16) if primary else Color(0.16, 0.3, 0.19)
	var text_col := Color(0.18, 0.1, 0.02) if primary else CREAM
	b.add_theme_stylebox_override("normal", _btn_style(base, Color(GOLD, 0.7 if primary else 0.35)))
	b.add_theme_stylebox_override("hover", _btn_style(base.lightened(0.15), GOLD, 3))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), GOLD, 3))
	b.add_theme_stylebox_override("pressed", _btn_style(base.darkened(0.2), GOLD, 3))
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.0) if primary else GOLD)
	b.add_theme_color_override("font_pressed_color", text_col)
	(parent if parent else buttons_box).add_child(b)
	b.resized.connect(_center_pivot.bind(b))
	b.mouse_entered.connect(_hover.bind(b, true))
	b.mouse_exited.connect(_hover.bind(b, false))
	b.focus_entered.connect(_hover.bind(b, true))
	b.focus_exited.connect(_hover.bind(b, false))
	return b


func _center_pivot(b: Button) -> void:
	b.pivot_offset = b.size / 2.0


func _btn_style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(12)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


func _hover(b: Button, on: bool) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.12).set_trans(Tween.TRANS_BACK)


func _intro_animation() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)


# ---------------------------------------------------------------- utilidades

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _nature(prop: String) -> Node3D:
	if not scene_cache.has(prop):
		scene_cache[prop] = load(NATURE % prop)
	return scene_cache[prop].instantiate()


# ---------------------------------------------------------------- acciones

# ---------------------------------------------------------------- partidas (ranuras)

## Lista de las ranuras de guardado: cada una con su jugador y su progreso.
func _show_slots() -> void:
	var vb := _open_modal("Partidas")
	for s in range(1, Game.MAX_SLOTS + 1):
		vb.add_child(_slot_row(s))
	var close := _menu_button("Volver", false, vb)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(200, 46)
	close.pressed.connect(_close_modal)
	var focus_target: Button = null
	for b in vb.find_children("*", "Button", true, false):
		focus_target = b
		break
	if focus_target:
		focus_target.grab_focus.call_deferred()


func _slot_row(s: int) -> Control:
	var d := Game.peek_save(s)
	var done := bool(d.get("completed", false))
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.09, 0.05, 0.85)
	st.border_color = Color(GOLD, 0.25 if d.is_empty() else 0.55)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	for side in ["left", "right", "top", "bottom"]:
		st.set("content_margin_" + side, 16)
	card.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var info := VBoxContainer.new()
	info.custom_minimum_size = Vector2(380, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD if not d.is_empty() else Color(CREAM, 0.6))
	var line := Label.new()
	line.add_theme_font_size_override("font_size", 16)
	line.add_theme_color_override("font_color", Color(CREAM, 0.85))
	info.add_child(title)
	info.add_child(line)
	if d.is_empty():
		title.text = "Partida %d  —  vacía" % s
		line.text = "Empieza una aventura nueva aquí."
		_slot_button(row, "Nueva partida", true, _new_game.bind(s))
	else:
		var who := str(d.get("player", "Jugador"))
		title.text = "Partida %d  —  %s" % [s, who]
		line.text = _slot_summary(d)
		if done:
			_slot_button(row, "Jugar de nuevo", false, _confirm.bind(
				"¿Empezar de nuevo?", "Se reemplaza la partida %d (ya completada)." % s, _new_game.bind(s)))
		else:
			_slot_button(row, "Continuar", true, _continue_slot.bind(s))
		_slot_button(row, "Borrar", false, _confirm.bind(
			"¿Borrar la partida %d?" % s, "Se pierde el progreso de %s. Los datos ya enviados a la base de datos se conservan." % who,
			_delete_slot.bind(s)))
	return card


func _slot_button(parent: Node, t: String, primary: bool, cb: Callable) -> Button:
	var b := _menu_button(t, primary, parent)
	b.custom_minimum_size = Vector2(150 if t != "Borrar" else 100, 46)
	b.add_theme_font_size_override("font_size", 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


## Texto corto con el progreso de una ranura.
func _slot_summary(d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var secs := int(d.get("play_time", 0))
	var tiempo := "%d:%02d" % [secs / 60, secs % 60]
	var when := _fecha(float(d.get("updated", 0)))
	if bool(d.get("completed", false)):
		return "¡Recorrido completado!  ·  $%d recaudados  ·  %s  ·  %s" % [int(d.get("total_collected", 0)), tiempo, when]
	var idx := clampi(int(d.get("level_index", 0)), 0, Game.LEVELS.size() - 1)
	return "%s  ·  $%d  ·  %d bellotas  ·  %s  ·  %s" % [
		Game.LEVELS[idx].name, int(d.get("money", 0)), int(d.get("acorns", 0)), tiempo, when]


func _fecha(unix: float) -> String:
	if unix <= 0:
		return ""
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var t := Time.get_datetime_dict_from_unix_time(int(unix) + bias)
	return "%02d/%02d %02d:%02d" % [t.day, t.month, t.hour, t.minute]


func _continue_slot(s: int) -> void:
	if Game.load_game(s):
		get_tree().change_scene_to_file("res://scenes/level.tscn")
	else:
		_new_game(s)


func _delete_slot(s: int) -> void:
	Game.delete_save(s)
	_rebuild_buttons()
	_show_slots()


## Ventana de confirmación genérica (Sí / No).
func _confirm(title: String, body: String, action: Callable) -> void:
	var vb := _open_modal(title)
	var l := _text(body, 18, CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(460, 0)
	vb.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var no := _menu_button("No", false, row)
	no.custom_minimum_size = Vector2(160, 48)
	no.pressed.connect(_show_slots)
	var yes := _menu_button("Sí", true, row)
	yes.custom_minimum_size = Vector2(160, 48)
	yes.pressed.connect(action)
	no.grab_focus.call_deferred()


## Vuelve a armar los botones del menú (por si cambió qué partida se puede continuar).
func _rebuild_buttons() -> void:
	for c in buttons_box.get_children():
		c.queue_free()
	await get_tree().process_frame
	_fill_buttons()


## Nueva partida en la ranura s: primero pide el nombre del jugador.
func _new_game(s: int) -> void:
	var vb := _open_modal("Nueva partida  ·  ranura %d" % s)
	vb.add_child(_text("¿Cómo te llamas, recaudador?\nTu nombre aparecerá en el leaderboard.", 19, CREAM))
	var edit := LineEdit.new()
	edit.text = Api.player_name
	edit.placeholder_text = "Escribe tu nombre"
	edit.max_length = 20
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.custom_minimum_size = Vector2(380, 54)
	edit.add_theme_font_size_override("font_size", 24)
	edit.add_theme_color_override("font_color", CREAM)
	edit.add_theme_stylebox_override("normal", _btn_style(Color(0.04, 0.08, 0.05, 0.9), Color(GOLD, 0.5)))
	edit.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), GOLD, 3))
	edit.select_all_on_focus = true
	vb.add_child(edit)
	# Perfil opcional (por rangos) para las estadísticas del proyecto.
	var nota := _text("Opcional · solo para las estadísticas del proyecto escolar", 14, CREAM)
	nota.modulate.a = 0.65
	vb.add_child(nota)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	var prev := Api.saved_profile()
	var pickers := {}
	for key in PERFIL_OPCIONES:
		var l := _text(PERFIL_TITULOS[key], 18, CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(l)
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(300, 40)
		ob.add_theme_font_size_override("font_size", 17)
		ob.add_theme_color_override("font_color", CREAM)
		ob.add_theme_stylebox_override("normal", _btn_style(Color(0.04, 0.08, 0.05, 0.9), Color(GOLD, 0.35)))
		ob.add_theme_stylebox_override("hover", _btn_style(Color(0.08, 0.14, 0.09, 0.95), GOLD, 2))
		ob.add_theme_stylebox_override("focus", _btn_style(Color(0, 0, 0, 0), GOLD, 2))
		ob.add_theme_stylebox_override("pressed", _btn_style(Color(0.04, 0.08, 0.05, 0.9), GOLD, 2))
		for opt in PERFIL_OPCIONES[key]:
			ob.add_item(opt)
		var sel: int = PERFIL_OPCIONES[key].find(str(prev.get(key, "")))
		ob.select(maxi(sel, 0))
		grid.add_child(ob)
		pickers[key] = ob
	var read_profile := func() -> Dictionary:
		var out := {}
		for k in pickers:
			out[k] = pickers[k].get_item_text(pickers[k].selected)
		return out
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)
	var cancel := _menu_button("Cancelar", false, row)
	cancel.custom_minimum_size = Vector2(170, 50)
	cancel.pressed.connect(_show_slots)
	var go := _menu_button("Empezar", true, row)
	go.custom_minimum_size = Vector2(200, 50)
	go.pressed.connect(func(): _start_new_game(edit.text, s, read_profile.call()))
	edit.text_submitted.connect(func(t: String): _start_new_game(t, s, read_profile.call()))
	edit.grab_focus.call_deferred()


## Borra la ranura e inicia. La primera vez pasa por el tutorial; después va directo al Bosque.
func _start_new_game(player: String, s: int, perfil: Dictionary = {}) -> void:
	Game.slot = s
	Game.reset()
	Game.delete_save(s)
	Api.new_session(player, perfil)
	var next := "res://scenes/level.tscn" if Game.tutorial_done else "res://scenes/tutorial.tscn"
	get_tree().change_scene_to_file(next)


## Opciones del perfil (el primero es el valor por defecto). Deben coincidir con db.py del servidor.
const PERFIL_TITULOS := {"edad": "Edad", "sexo": "Sexo", "lugar": "¿Dónde vives?", "ingresos": "Ingresos al mes"}
const PERFIL_OPCIONES := {
	"edad": ["Prefiero no decir", "Menos de 12", "12–17", "18–24", "25–34", "35–44", "45 o más"],
	"sexo": ["Prefiero no decir", "Mujer", "Hombre", "Otro"],
	"lugar": ["Prefiero no decir", "Aguascalientes", "Baja California", "Baja California Sur", "Campeche",
		"Chiapas", "Chihuahua", "Ciudad de México", "Coahuila", "Colima", "Durango", "Estado de México",
		"Guanajuato", "Guerrero", "Hidalgo", "Jalisco", "Michoacán", "Morelos", "Nayarit", "Nuevo León",
		"Oaxaca", "Puebla", "Querétaro", "Quintana Roo", "San Luis Potosí", "Sinaloa", "Sonora", "Tabasco",
		"Tamaulipas", "Tlaxcala", "Veracruz", "Yucatán", "Zacatecas", "Fuera de México"],
	"ingresos": ["Prefiero no decir", "Sin ingresos propios", "Menos de $5,000", "$5,000–$10,000",
		"$10,000–$20,000", "$20,000–$40,000", "Más de $40,000"],
}


# ---------------------------------------------------------------- leaderboard

const LB_CRITERIOS := {"recaudado": "Más recaudado", "tiempo": "Más rápido", "bellotas": "Más bellotas"}


func _show_leaderboard(criterio: String) -> void:
	var vb := _open_modal("Leaderboard")
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	vb.add_child(tabs)
	for key in LB_CRITERIOS:
		var t := _menu_button(LB_CRITERIOS[key], key == criterio, tabs)
		t.custom_minimum_size = Vector2(170, 42)
		t.add_theme_font_size_override("font_size", 17)
		t.pressed.connect(_show_leaderboard.bind(key))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.custom_minimum_size = Vector2(620, 0)
	vb.add_child(list)
	var status := _text("Cargando...", 18, CREAM)
	vb.add_child(status)
	var link := _text("Más detalle en la web: %s" % Api.base_url, 14, CREAM)
	link.modulate.a = 0.6
	vb.add_child(link)
	var close := _menu_button("Cerrar", false, vb)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(200, 46)
	close.pressed.connect(_close_modal)
	close.grab_focus.call_deferred()
	Api.fetch_leaderboard(criterio, _fill_leaderboard.bind(list, status))


func _fill_leaderboard(ok: bool, rows: Array, list: VBoxContainer, status: Label) -> void:
	if not is_instance_valid(list):
		return  # el usuario ya cerró la ventana
	if not ok:
		status.text = "No se pudo conectar con el servidor.\n¿Está corriendo?  (en la carpeta server:  py run.py)"
		status.add_theme_color_override("font_color", Color(1, 0.6, 0.5))
		return
	if rows.is_empty():
		status.text = "Aún no hay partidas registradas. ¡Sé el primero!"
		return
	status.visible = false
	list.add_child(_lb_row(["#", "Jugador", "Recaudado", "Bellotas", "Tiempo"], true, 0))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var secs := int(r.get("tiempo_seg", 0))
		list.add_child(_lb_row([
			str(i + 1), str(r.get("nombre", "?")), "$%d" % int(r.get("total_recaudado", 0)),
			str(int(r.get("bellotas", 0))), "%d:%02d" % [secs / 60, secs % 60],
		], false, i + 1))


func _lb_row(cells: Array, header: bool, pos: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var widths := [44, 230, 130, 100, 90]
	var podium := [GOLD, Color(0.85, 0.87, 0.9), Color(0.88, 0.6, 0.36)]
	for c in cells.size():
		var l := Label.new()
		l.text = cells[c]
		l.custom_minimum_size = Vector2(widths[c], 0)
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if c == 1 else HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15 if header else 20)
		var col := CREAM
		if header:
			col = Color(CREAM, 0.6)
		elif pos >= 1 and pos <= 3 and (c == 0 or c == 1):
			col = podium[pos - 1]
		elif c == 2:
			col = GOLD
		l.add_theme_color_override("font_color", col)
		row.add_child(l)
	return row


# ---------------------------------------------------------------- ventana modal

func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(center)
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(DARK_GREEN, 0.96)
	cs.border_color = Color(GOLD, 0.6)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(18)
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 20
	for side in ["left", "right", "top", "bottom"]:
		cs.set("content_margin_" + side, 32)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)
	var t := _text(title, 36, GOLD)
	t.add_theme_constant_override("outline_size", 10)
	vb.add_child(t)
	return vb


func _show_settings() -> void:
	var vb := _open_modal("Ajustes")
	SettingsUI.build(vb, _close_modal)


func _close_modal() -> void:
	if modal:
		modal.queue_free()
		modal = null
		if first_button:
			first_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if modal and event.is_action_pressed("ui_cancel"):
		_close_modal()
		get_viewport().set_input_as_handled()


func _play_tutorial() -> void:
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")


func _quit() -> void:
	get_tree().quit()

