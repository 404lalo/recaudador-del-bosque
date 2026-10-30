extends CanvasLayer
## Autoload "Touch": controles táctiles para celular.
##
##   - Pulgar izquierdo: joystick virtual flotante (aparece donde pones el dedo).
##     Convierte el desplazamiento en acciones con Input.action_press("move_right", fuerza).
##     Empujarlo hasta el borde también presiona "sprint" (correr).
##   - Pulgar derecho: botones TouchScreenButton con su propiedad "action" (jump, dash, interact).
##   - Arrastrar en el resto de la mitad derecha gira la cámara (player.look_drag()).
##   - Botón de pausa arriba a la derecha (acción "pause").
##
## Cada dedo se sigue por su índice, así que moverse + saltar + mirar al mismo tiempo funciona
## (multitouch). El personaje nunca lee este script: solo ve las acciones del Input Map.
##
## Se muestra solo si Game.touch_active() (pantalla táctil, o modo depuración con F3 / Ajustes),
## hay un jugador en escena, no está en un diálogo y el juego no está en pausa.

# Tamaños base en pixeles del viewport (1280x720); se multiplican por Game.touch_scale.
const JOY_RADIUS := 100.0
const KNOB_RADIUS := 44.0
const JUMP_SIZE := 140.0
const ACTION_SIZE := 108.0
const PAUSE_SIZE := 96.0
const EDGE := 28.0       # separación mínima con el borde (además de la safe area)
const GAP := 18.0        # separación entre botones
const SPRINT_AT := 0.92  # joystick a fondo = correr
const TEX := 256         # resolución de las texturas generadas

var root: Node2D
var joy_node: Node2D
var buttons := {}        # acción -> {slot, button, label, size}
var _tex_normal: ImageTexture
var _tex_pressed: ImageTexture

var joy_index := -1      # dedo que controla el joystick (-1 = ninguno)
var joy_center := Vector2.ZERO
var joy_home := Vector2.ZERO  # dónde se dibuja el joystick en reposo
var joy_vec := Vector2.ZERO
var cam_index := -1      # dedo que gira la cámara
var shown := false
var _screen := Vector2(1280, 720)
var _margins := {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tex_normal = _circle_texture(Color(0.05, 0.1, 0.07, 0.55), Color(1, 1, 1, 0.85))
	_tex_pressed = _circle_texture(Color(1.0, 0.82, 0.32, 0.75), Color(1, 1, 1, 1))
	root = Node2D.new()
	add_child(root)
	joy_node = Node2D.new()
	joy_node.draw.connect(_draw_joystick)
	root.add_child(joy_node)
	_add_button("jump", "SALTAR")
	_add_button("dash", "DASH")
	_add_button("interact", "HABLAR")
	_add_button("pause", "II")
	Game.settings_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_set_shown(false)


# ---------------------------------------------------------------- construcción

func _add_button(action: String, text: String) -> void:
	var slot := Node2D.new()
	root.add_child(slot)
	var b := TouchScreenButton.new()
	b.texture_normal = _tex_normal
	b.texture_pressed = _tex_pressed
	b.action = action  # el botón dispara directamente la acción del Input Map
	var shape := CircleShape2D.new()
	shape.radius = TEX / 2.0
	b.shape = shape
	b.shape_centered = true
	b.pressed.connect(func(): Game.vibrate(15, 0.3))
	slot.add_child(b)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(l)
	buttons[action] = {"slot": slot, "button": b, "label": l, "size": 0.0}


func _circle_texture(fill: Color, ring: Color) -> ImageTexture:
	var img := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var c := TEX / 2.0
	var r := c - 2.0
	var ring_w := 7.0
	for y in TEX:
		for x in TEX:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var col := Color(0, 0, 0, 0)
			if d <= r:
				col = ring if d > r - ring_w else fill
				col.a *= clampf(r - d + 0.5, 0.0, 1.0)  # borde suavizado
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Ubica todo según el tamaño de pantalla, la safe area y el tamaño elegido en Ajustes.
func _layout() -> void:
	_screen = get_viewport().get_visible_rect().size
	_margins = Game.safe_margins()
	var k := Game.touch_scale
	var left: float = _margins.left + EDGE
	var right: float = _screen.x - _margins.right - EDGE
	var top: float = _margins.top + EDGE
	var bottom: float = _screen.y - _margins.bottom - EDGE
	var jr := JOY_RADIUS * k
	joy_home = Vector2(left + jr + 20, bottom - jr - 20)
	var js := JUMP_SIZE * k
	var asz := ACTION_SIZE * k
	var jump_c := Vector2(right - js / 2, bottom - js / 2)
	_place("jump", jump_c, js)
	_place("dash", Vector2(jump_c.x - js / 2 - GAP - asz / 2, bottom - asz / 2), asz)
	_place("interact", Vector2(jump_c.x, jump_c.y - js / 2 - GAP - asz / 2), asz)
	var ps := PAUSE_SIZE * k
	_place("pause", Vector2(right - ps / 2, top + ps / 2), ps)
	root.modulate.a = Game.touch_opacity
	joy_node.queue_redraw()
	if shown and not Game.touch_active():
		_set_shown(false)


func _place(action: String, center: Vector2, size: float) -> void:
	var d: Dictionary = buttons[action]
	d.size = size
	d.slot.position = center
	var b: TouchScreenButton = d.button
	b.scale = Vector2.ONE * (size / TEX)
	b.position = -Vector2.ONE * size / 2
	var l: Label = d.label
	l.size = Vector2(size, size)
	l.position = -l.size / 2
	l.add_theme_font_size_override("font_size", int(size * (0.3 if action == "pause" else 0.17)))


# ---------------------------------------------------------------- visibilidad

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var want: bool = Game.touch_active() and player != null and not player.locked and not get_tree().paused
	if want != shown:
		_set_shown(want)
	if not shown:
		return
	# HABLAR se ilumina cuando hay un animal cerca (el HUD muestra el aviso).
	var hud := get_tree().get_first_node_in_group("hud")
	var can_talk: bool = hud != null and hud.has_prompt()
	buttons.interact.slot.modulate = Color(1, 0.9, 0.5, 1.0) if can_talk else Color(1, 1, 1, 0.45)
	# DASH se ve apagado mientras recarga.
	var cd: float = player.dash_cooldown if "dash_cooldown" in player else 0.0
	buttons.dash.slot.modulate.a = 0.45 if cd > 0.0 else 1.0


func _set_shown(v: bool) -> void:
	shown = v
	root.visible = v
	if not v:
		_release_joystick()
		cam_index = -1
		for a in buttons:
			Input.action_release(a)


# ---------------------------------------------------------------- entrada táctil

func _input(event: InputEvent) -> void:
	if not shown:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			if event.index == joy_index:
				_release_joystick()
			elif event.index == cam_index:
				cam_index = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_index:
			_update_joystick(event.position)
		elif event.index == cam_index:
			var player := get_tree().get_first_node_in_group("player")
			if player:
				player.look_drag(event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if _over_button(pos):
		return  # lo maneja el TouchScreenButton
	if pos.x < _screen.x * 0.45 and pos.y > _screen.y * 0.25:
		if joy_index == -1:
			joy_index = index
			# El joystick aparece donde cae el pulgar, sin salirse de la pantalla.
			var jr := JOY_RADIUS * Game.touch_scale
			joy_center = Vector2(
				maxf(pos.x, _margins.left + EDGE + jr * 0.5),
				minf(pos.y, _screen.y - _margins.bottom - EDGE - jr * 0.5))
			_update_joystick(pos)
	elif cam_index == -1:
		cam_index = index


func _over_button(pos: Vector2) -> bool:
	for a in buttons:
		var d: Dictionary = buttons[a]
		if pos.distance_to(d.slot.position) <= d.size / 2 + 6:
			return true
	return false


func _update_joystick(pos: Vector2) -> void:
	var jr := JOY_RADIUS * Game.touch_scale
	joy_vec = ((pos - joy_center) / jr).limit_length(1.0)
	# Fuerza analógica cruda: la zona muerta la aplica el Input Map (Game.deadzone), igual que
	# a los sticks del gamepad, y player.gd la lee con Input.get_vector().
	_set_axis("move_left", "move_right", joy_vec.x)
	_set_axis("move_forward", "move_back", joy_vec.y)
	if joy_vec.length() >= SPRINT_AT:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")
	joy_node.queue_redraw()


func _set_axis(neg: String, pos_action: String, v: float) -> void:
	if v > 0.0:
		Input.action_press(pos_action, v)
		Input.action_release(neg)
	elif v < 0.0:
		Input.action_press(neg, -v)
		Input.action_release(pos_action)
	else:
		Input.action_release(neg)
		Input.action_release(pos_action)


func _release_joystick() -> void:
	joy_index = -1
	joy_vec = Vector2.ZERO
	for a in ["move_left", "move_right", "move_forward", "move_back", "sprint"]:
		Input.action_release(a)
	joy_node.queue_redraw()


func _draw_joystick() -> void:
	var k := Game.touch_scale
	var jr := JOY_RADIUS * k
	var active := joy_index != -1
	var c := joy_center if active else joy_home
	var a := 1.0 if active else 0.6
	joy_node.draw_circle(c, jr, Color(0.05, 0.1, 0.07, 0.45 * a), true, -1.0, true)
	joy_node.draw_arc(c, jr, 0, TAU, 64, Color(1, 1, 1, 0.8 * a), 4.0, true)
	# Zona muerta (anillo interior tenue) para que se vea el ajuste.
	joy_node.draw_arc(c, jr * Game.deadzone, 0, TAU, 32, Color(1, 1, 1, 0.25 * a), 2.0, true)
	var knob := c + joy_vec * jr
	var kc := Color(1.0, 0.82, 0.32, 0.9) if active else Color(1, 1, 1, 0.6)
	joy_node.draw_circle(knob, KNOB_RADIUS * k, kc, true, -1.0, true)
