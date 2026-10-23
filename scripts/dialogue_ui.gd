extends CanvasLayer
## Diálogo de opción múltiple con un animal. Emite finished(paid, ok, retry).

signal finished(paid: int, ok: bool, retry: bool)
signal trivia_finished(correct: bool)

var species: Dictionary
var riddle: Dictionary
var disabled_options: Array = []
var tax := 0
var riddle_shown_at := 0   # ms, para medir cuánto tarda en responder
var trivia: Dictionary      # pregunta actual del depredador
var trivia_choice := -1
var name_label: Label
var text_label: Label
var opts: VBoxContainer
var panel: PanelContainer


func _ready() -> void:
	layer = 10
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -120
	panel.offset_bottom = -30
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # crece hacia arriba y nunca tapa los botones
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(name_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(text_label)
	opts = VBoxContainer.new()
	opts.add_theme_constant_override("separation", 6)
	vb.add_child(opts)
	visible = false


func start(sp: Dictionary, tax_amount: int) -> void:
	species = sp
	tax = tax_amount
	riddle = Game.pick_riddle(sp.id, int(Game.level_setting("riddle_tier", 1)))
	disabled_options.clear()
	name_label.text = "%s  —  impuesto: $%d" % [sp.name, tax]
	visible = true
	text_label.text = sp.intro + "

\"Si quieres que te pague, resuelve mi acertijo.\""
	_clear_opts()
	_add_button("Escuchar el acertijo", _show_riddle.bind(""))
	_add_button("Volver más tarde", _finish.bind(0, false, true))


func _clear_opts() -> void:
	for c in opts.get_children():
		opts.remove_child(c)
		c.queue_free()


func _add_button(txt: String, cb: Callable, disabled := false) -> void:
	var b := Button.new()
	b.text = txt
	b.disabled = disabled
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	opts.add_child(b)
	if opts.get_child_count() == 1 and not disabled:
		b.grab_focus.call_deferred()  # Espacio/Enter activan el primer botón


## Muestra el acertijo. Tienes 2 intentos: acertar al primero paga el impuesto completo, al segundo el 60 %.
func _show_riddle(prefix: String) -> void:
	text_label.text = prefix + riddle.q
	riddle_shown_at = Time.get_ticks_msec()
	_clear_opts()
	for i in riddle.options.size():
		_add_button(riddle.options[i], _answer.bind(i), disabled_options.has(i))


func _answer(i: int) -> void:
	Api.track("acertijo", {
		"animal": species.name,
		"pregunta": riddle.q,
		"respuesta": riddle.options[i],
		"correcta": i == riddle.correct,
		"intento": disabled_options.size() + 1,
		"segundos": snappedf((Time.get_ticks_msec() - riddle_shown_at) / 1000.0, 0.1),
	})
	if i == riddle.correct:
		var mult: float = 1.0 if disabled_options.is_empty() else float(Game.level_setting("second_try", 0.6))
		var paid: int = int(round(tax * mult))
		_clear_opts()
		text_label.text = "¡Correcto!

%s

(+$%d)" % [species.pay_line, paid]
		_add_button("Continuar", _finish.bind(paid, true, false))
	else:
		disabled_options.append(i)
		if disabled_options.size() >= 2:
			_clear_opts()
			var right: String = riddle.options[riddle.correct]
			text_label.text = "Incorrecto. La respuesta era: %s.

%s" % [right, species.fail_line]
			_add_button("Continuar", _finish.bind(0, false, false))
		else:
			_show_riddle("Incorrecto... te doy una última oportunidad (pagaré menos).

")


func _finish(paid: int, ok: bool, retry: bool) -> void:
	visible = false
	finished.emit(paid, ok, retry)


## Prueba de cultura general del depredador: un solo intento.
func start_trivia(predator_name: String) -> void:
	var t := Game.pick_trivia()
	trivia = t
	trivia_choice = -1
	name_label.text = "%s  —  ¡Responde o pagas!" % predator_name
	name_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	text_label.text = t.q
	visible = true
	_clear_opts()
	for i in t.options.size():
		_add_button(t.options[i], _trivia_answer.bind(i))


func _trivia_answer(i: int) -> void:
	trivia_choice = i
	var correct: bool = i == trivia.correct
	visible = false
	name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	trivia_finished.emit(correct)
