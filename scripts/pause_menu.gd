extends CanvasLayer
## Menú de pausa (tecla P). Lo agregan level.gd y tutorial.gd.
##
## El nodo que lo crea (host) debe tener:
##   - player (CharacterBody3D) con la propiedad "locked"
##   - can_pause() -> bool   : si en este momento se permite pausar
##   - pause_restart()       : reinicia la zona / el tutorial
##   - pause_quit()          : sale al menú principal

const GOLD := Color(1.0, 0.82, 0.32)
const CREAM := Color(0.98, 0.94, 0.84)
const DARK_GREEN := Color(0.07, 0.14, 0.09)

var host: Node
var title_text := "Pausa"
var restart_text := "Reiniciar zona"
var info_label: Label
var box: VBoxContainer
var root: Control
var hint: Label
var _first: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue funcionando con el juego pausado
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(DARK_GREEN, 0.95)
	cs.border_color = Color(GOLD, 0.6)
	cs.set_border_width_all(2)
	cs.set_corner_radius_all(18)
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 20
	for side in ["left", "right", "top", "bottom"]:
		cs.set("content_margin_" + side, 34)
	card.add_theme_stylebox_override("panel", cs)
	center.add_child(card)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	card.add_child(box)
	root.visible = false
	# Recordatorio discreto en la esquina.
	hint = Label.new()
	hint.text = "P  ·  Pausa"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(CREAM, 0.7))
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 5)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -120
	hint.offset_top = -36
	hint.offset_right = -18
	hint.offset_bottom = -12
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		if root.visible and event.is_action_pressed("ui_cancel"):
			resume()
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if root.visible:
		resume()
	elif host and host.can_pause():
		open()


func open() -> void:
	get_tree().paused = true
	root.visible = true
	hint.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()
	Api.track("pausa", {})


func resume() -> void:
	root.visible = false
	hint.visible = true
	get_tree().paused = false
	if host and is_instance_valid(host.player) and not host.player.locked:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------- pantallas

func _show_main() -> void:
	_clear()
	box.add_child(_text(title_text, 40, GOLD))
	info_label = _text(_info(), 17, Color(CREAM, 0.8))
	box.add_child(info_label)
	box.add_child(_spacer(6))
	_first = _button("Continuar", true, resume)
	_button(restart_text, false, _confirm.bind(
		"¿%s?" % restart_text,
		"Vuelves al inicio con el dinero que tenías al entrar.",
		_do_restart))
	_button("Salir al menú principal", false, _confirm.bind(
		"¿Salir al menú?",
		"Tu partida queda guardada desde el inicio de esta zona.\nPodrás retomarla con \"Continuar\".",
		_do_quit))
	var tip := _text("P o Esc para volver al juego", 14, Color(CREAM, 0.5))
	box.add_child(tip)
	_first.grab_focus.call_deferred()


func _confirm(title: String, body: String, action: Callable) -> void:
	_clear()
	box.add_child(_text(title, 34, GOLD))
	box.add_child(_text(body, 18, CREAM))
	box.add_child(_spacer(6))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var no := _button("No, volver", false, _show_main, row)
	no.custom_minimum_size = Vector2(170, 50)
	var yes := _button("Sí", true, action, row)
	yes.custom_minimum_size = Vector2(170, 50)
	no.grab_focus.call_deferred()


func _do_restart() -> void:
	get_tree().paused = false
	host.pause_restart()


func _do_quit() -> void:
	get_tree().paused = false
	host.pause_quit()


func _info() -> String:
	var secs := int(Game.play_time)
	return "$%d   ·   Bellotas: %d   ·   Monedas: %d   ·   Tiempo: %d:%02d" % [
		Game.money, Game.acorns, Game.coins, secs / 60, secs % 60]


# ---------------------------------------------------------------- utilidades de UI

func _clear() -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s


func _text(t: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _button(t: String, primary: bool, cb: Callable, parent: Node = null) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(360, 54 if primary else 48)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 24 if primary else 20)
	var base := Color(0.85, 0.62, 0.16) if primary else Color(0.16, 0.3, 0.19)
	var text_col := Color(0.18, 0.1, 0.02) if primary else CREAM
	b.add_theme_stylebox_override("normal", _style(base, Color(GOLD, 0.7 if primary else 0.35)))
	b.add_theme_stylebox_override("hover", _style(base.lightened(0.15), GOLD, 3))
	b.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), GOLD, 3))
	b.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), GOLD, 3))
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_focus_color", text_col)
	b.add_theme_color_override("font_hover_color", Color(0.12, 0.06, 0.0) if primary else GOLD)
	b.add_theme_color_override("font_pressed_color", text_col)
	b.pressed.connect(cb)
	(parent if parent else box).add_child(b)
	return b


func _style(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(12)
	s.content_margin_left = 18
	s.content_margin_right = 18
	return s
